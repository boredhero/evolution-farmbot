-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local checksum=require('farm.lib.checksum')
local Up={}
local BASE='https://raw.githubusercontent.com/boredhero/evolution-farmbot/'
local JOURNAL='farm/update-pending.json'
local VERSION='farm/version.json'
local function readFile(path)
  local h=fs.open(path,'r');if not h then return nil end
  local data=h.readAll();h.close();return data
end
local function writeFile(path,data)
  fs.makeDir(fs.getDir(path))
  local h=assert(fs.open(path,'w'),'Cannot write '..path);h.write(data);h.close()
end
local function decode(raw)
  if not raw then return nil end
  local ok,value=pcall(textutils.unserializeJSON,raw)
  if ok and type(value)=='table' then return value end
end
local function parts(v)
  if type(v)~='string' then return end
  local a,b,c=v:match('^(%d+)%.(%d+)%.(%d+)$')
  if a then return {tonumber(a),tonumber(b),tonumber(c)} end
end
function Up.newer(a,b)
  local aa,bb=parts(a),parts(b);assert(aa,'Invalid release version')
  if not bb then return true end
  for i=1,3 do if aa[i]~=bb[i] then return aa[i]>bb[i] end end
  return false
end
local roots={['farm.lua']=true,['update.lua']=true,['check.lua']=true,
  ['startup.lua']=true,['LICENSE']=true,['NOTICE']=true}
function Up.safePath(path)
  if type(path)~='string' or #path>160 or path:find('..',1,true) or path:find('//',1,true) then return false end
  if roots[path] then return true end
  -- Only program modules, never farm/config, data, backups, or updater state.
  if not path:match('^farm/[%w_/-]+%.lua$') then return false end
  if path:match('^farm/data/') or path:match('^farm/config/') or path:match('^farm/install%-backups/')
    or path:match('^farm/update%-') then return false end
  return true
end
function Up.validate(m)
  assert(type(m)=='table' and m.schema==1 and parts(m.version),'Invalid release manifest')
  assert(m.ref=='v'..m.version,'Release must use its version tag')
  assert(type(m.notes)=='string' and #m.notes<=4000,'Invalid release notes')
  assert(type(m.files)=='table' and #m.files>0 and #m.files<=256,'Invalid release file list')
  local seen,total={},0
  for _,file in ipairs(m.files) do
    assert(type(file)=='table' and Up.safePath(file.path),'Unsafe release file path')
    assert(not seen[file.path],'Duplicate release file');seen[file.path]=true
    assert(type(file.size)=='number' and file.size>=0 and file.size%1==0 and file.size<=2097152,'Invalid file size')
    assert(type(file.adler32)=='string' and #file.adler32==8 and not file.adler32:find('[^0-9a-f]'),'Invalid checksum')
    total=total+file.size
  end
  assert(total<=8388608,'Release too large')
  for _,p in ipairs({'farm.lua','farm/updater.lua','farm/lib/checksum.lua','startup.lua','update.lua','check.lua','LICENSE','NOTICE'}) do
    assert(seen[p],'Release missing '..p)
  end
  return total
end
local function fetch(url,limit)
  assert(http and http.get,'HTTP is disabled on this computer')
  local h,err,bad=http.get({url=url,binary=true,redirect=false,timeout=20})
  if not h then if bad then bad.close() end;error('Download failed: '..tostring(err),0) end
  local ok,data=pcall(function()
    assert(h.getResponseCode()==200,'Unexpected HTTP response')
    local chunks,n={},0
    while true do
      local chunk=h.read(math.min(8192,limit-n+1));if not chunk then break end
      n=n+#chunk;assert(n<=limit,'Download exceeds declared size');chunks[#chunks+1]=chunk
    end
    return table.concat(chunks)
  end)
  h.close();if not ok then error(data,0) end;return data
end
function Up.recover()
  if not fs.exists(JOURNAL) then return false end
  local tx=decode(readFile(JOURNAL));assert(tx and tx.schema==1 and type(tx.entries)=='table','Invalid update journal; retain it for recovery')
  assert(type(tx.backup)=='string' and tx.backup:match('^farm/install%-backups/update%-%d+%-%d+$'),'Invalid recovery backup')
  -- Validate every target before touching any files.
  for _,entry in ipairs(tx.entries) do
    assert(Up.safePath(entry.path) or entry.path==VERSION,'Unsafe recovery path')
    assert(type(entry.existed)=='boolean','Invalid recovery entry')
  end
  for i=#tx.entries,1,-1 do
    local entry=tx.entries[i];local copy=tx.backup..'/'..entry.path
    if entry.existed then
      assert(fs.exists(copy),'Missing rollback copy: '..entry.path)
      writeFile(entry.path,assert(readFile(copy)))
    elseif fs.exists(entry.path) then fs.delete(entry.path) end
  end
  fs.delete(JOURNAL)
  print('Interrupted update rolled back. Backup retained: '..tx.backup)
  return true
end
function Up.install(m)
  local total=Up.validate(m)
  assert(not fs.exists(JOURNAL),'Recover the previous update first')
  local suffix=tostring(os.epoch('utc'))..'-'..tostring(os.getComputerID())
  local stage='farm/update-stage-'..suffix
  local backup='farm/install-backups/update-'..suffix
  assert(not fs.exists(stage) and not fs.exists(backup),'Update directory already exists; retry')
  local oldBytes=0
  for _,file in ipairs(m.files) do
    assert(not fs.isDir(file.path),'Program target is a directory: '..file.path)
    if fs.exists(file.path) then oldBytes=oldBytes+fs.getSize(file.path) end
  end
  local free=fs.getFreeSpace('/')
  assert(type(free)~='number' or free>=total*2+oldBytes+65536,'Not enough disk space for staging and backups')
  local tx={schema=1,backup=backup,entries={}}
  local ok,err=pcall(function()
    for i,file in ipairs(m.files) do
      print(('Downloading %d/%d: %s'):format(i,#m.files,file.path))
      local data=fetch(BASE..m.ref..'/'..file.path,file.size)
      assert(#data==file.size and checksum(data)==file.adler32,'Integrity check failed: '..file.path)
      if file.path:match('%.lua$') then assert(load(data,'@'..file.path,'t',{}),'Invalid Lua: '..file.path) end
      writeFile(stage..'/'..file.path,data)
    end
    writeFile(stage..'/'..VERSION,textutils.serializeJSON({version=m.version,ref=m.ref}))
    local paths={};for _,file in ipairs(m.files) do paths[#paths+1]=file.path end;paths[#paths+1]=VERSION
    -- Back up the complete prior program before any replacement, including the updater.
    for _,path in ipairs(paths) do
      local existed=fs.exists(path);tx.entries[#tx.entries+1]={path=path,existed=existed}
      if existed then fs.makeDir(fs.getDir(backup..'/'..path));fs.copy(path,backup..'/'..path) end
    end
    writeFile(JOURNAL,textutils.serializeJSON(tx))
    for _,path in ipairs(paths) do writeFile(path,assert(readFile(stage..'/'..path))) end
    fs.delete(JOURNAL)
  end)
  if not ok and fs.exists(JOURNAL) then
    local restored,why=pcall(Up.recover)
    if not restored then error(tostring(err)..' | Rollback needs attention: '..tostring(why),0) end
  end
  if fs.exists(stage) then fs.delete(stage) end
  if not ok then error(err,0) end
  print('Installed '..m.version..'. Config, farm memory and statistics preserved.')
  print('Previous program: '..backup)
  return true
end
function Up.run(options)
  options=options or {}
  local ok,result=pcall(function()
    if Up.recover() then print('Reboot this computer before continuing.');return false end
    print('Checking FarmBot releases...')
    local m=decode(fetch(BASE..'main/release.json',262144));Up.validate(m)
    local current=decode(readFile(VERSION));local version=current and current.version or 'unversioned'
    print('Installed: '..version..' | Available: '..m.version)
    if not Up.newer(m.version,version) then
      print('Already up to date; no files changed.')
      -- raw.githubusercontent serves the manifest through a CDN with a five
      -- minute TTL, and it honours neither a query string nor no-cache.
      print('A release published in the last ~5 minutes may not be visible yet; retry shortly.')
      return false
    end
    print(m.notes)
    print('Updates THIS computer only. New release modules are included.')
    print('Config/data are preserved. Successful installation reboots this computer.')
    write('Install '..m.version..'? [y/N] ')
    local answer=read():lower();if answer~='y' and answer~='yes' then print('Cancelled; no files changed.');return false end
    if options.beforeInstall then
      local ready,why=options.beforeInstall();if not ready then print(why);return false end
    end
    Up.install(m)
    if options.beforeReboot then options.beforeReboot() end
    print('Rebooting this computer...');os.reboot();return true
  end)
  if not ok then printError('Update stopped: '..tostring(result));return false end
  return result
end
return Up
