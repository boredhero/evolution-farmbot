-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local Up=require('farm.updater')
local checksum=require('farm.lib.checksum')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function encode(v)
  if type(v)=='table' then local p={};for k,x in pairs(v) do p[#p+1]='['..encode(k)..']='..encode(x) end;return '{'..table.concat(p,',')..'}' end
  if type(v)=='string' then return string.format('%q',v) end;return tostring(v)
end
textutils={serializeJSON=encode,unserializeJSON=function(s) local f=load('return '..s,'JSON mock','t',{});return f and f() end}
local files,dirs,requests,messages,downloads,failWrite,answer,reboots
local realPrint=print
print=function(s) messages[#messages+1]=tostring(s) end;printError=print;write=print
read=function() return answer end
os.epoch=function() return 123456 end;os.getComputerID=function() return 4 end
os.reboot=function() reboots=reboots+1 end
fs={exists=function(p) return files[p]~=nil or dirs[p] or false end,
  isDir=function(p) return dirs[p] or false end,
  getDir=function(p) return p:match('^(.*)/') or '' end,
  makeDir=function(p) dirs[p]=true end,
  getFreeSpace=function() return 10000000 end,
  getSize=function(p) return #(files[p] or '') end,
  copy=function(a,b) assert(files[a] and not files[b]);files[b]=files[a] end,
  delete=function(p) files[p]=nil;dirs[p]=nil;for k in pairs(files) do if k:sub(1,#p+1)==p..'/' then files[k]=nil end end end,
  open=function(p,mode)
    if mode=='r' then if not files[p] then return nil end;return {readAll=function() return files[p] end,close=function() end} end
    if failWrite==p then failWrite=nil;return nil end
    return {write=function(s) files[p]=s end,close=function() end}
  end}
http={get=function(opts)
  requests[#requests+1]=opts.url
  assert(opts.redirect==false);local content=downloads[opts.url]
  if not content then return nil,'404' end
  local index=1
  return {getResponseCode=function() return 200 end,close=function() end,read=function(n)
    if index>#content then return nil end;local s=content:sub(index,index+n-1);index=index+#s;return s
  end}
end}
local base='https://raw.githubusercontent.com/boredhero/evolution-farmbot/'
local function reset()
  files={['farm.lua']='old program',['startup.lua']='old startup',['farm/config']='precious config',
    ['farm/data/controller']='precious crop memory',['farm/data/harvest']='unfinished replant',
    ['farm/version.json']=encode({version='0.1.0'})}
  dirs={};requests={};messages={};downloads={};failWrite=nil;answer='yes';reboots=0
  local m={schema=1,version='0.2.0',ref='v0.2.0',notes='New version',files={}}
  for _,path in ipairs({'LICENSE','NOTICE','farm.lua','farm/updater.lua','farm/lib/checksum.lua','startup.lua','update.lua','check.lua','farm/new_module.lua'}) do
    local data=path:match('%.lua$') and 'return "new program"\n' or 'license text\n'
    m.files[#m.files+1]={path=path,size=#data,adler32=checksum(data)}
    downloads[base..'v0.2.0/'..path]=data
  end
  downloads[base..'main/release.json']=encode(m)
  return m
end
eq(checksum('Wikipedia'),'11e60398');assert(Up.newer('0.10.0','0.2.0'));assert(not Up.newer('0.2.0','0.10.0'))
realPrint('PASS numeric version comparison and known Adler-32 vector')
local m=reset()
for _,path in ipairs({'../farm/config','farm/data/evil.lua','farm/config/evil.lua','farm/install-backups/evil.lua',
  '/farm.lua','farm//evil.lua','farm/../evil.lua','https://evil/x.lua','farm/version.json','farm/update-stage-123/evil.lua'}) do
  assert(not Up.safePath(path),path)
end
local original=m.files[1].path;m.files[1].path='farm/config';assert(not pcall(Up.validate,m));m.files[1].path=original
m.ref='main';assert(not pcall(Up.validate,m))
realPrint('PASS manifest rejects unsafe paths, state overwrites, and mutable main source URLs')
m=reset();answer='n';assert(not Up.run());eq(#requests,1);eq(files['farm.lua'],'old program');eq(reboots,0)
assert(not files['farm/new_module.lua'])
realPrint('PASS decline checks manifest only, leaves all program/config files unchanged')
m=reset();files['farm/version.json']=encode({version='0.2.0'});assert(not Up.run());eq(#requests,1);eq(reboots,0)
realPrint('PASS up-to-date check performs no installation or reboot')
m=reset();assert(Up.run());eq(reboots,1)
eq(files['farm/config'],'precious config');eq(files['farm/data/controller'],'precious crop memory')
eq(files['farm/data/harvest'],'unfinished replant');assert(files['farm/new_module.lua'])
eq(files['farm/install-backups/update-123456-4/farm.lua'],'old program')
eq(textutils.unserializeJSON(files['farm/version.json']).version,'0.2.0')
assert(not files['farm/update-pending.json'])
realPrint('PASS confirmed update downloads every tagged file, including new modules, preserves state, backs up and reboots')
m=reset();downloads[base..'v0.2.0/farm/new_module.lua']='return "bad program"\n'
assert(not Up.run());eq(files['farm.lua'],'old program');eq(reboots,0)
eq(textutils.unserializeJSON(files['farm/version.json']).version,'0.1.0')
realPrint('PASS corrupt/truncated download never changes the running installation')
m=reset();downloads[base..'v0.2.0/farm/new_module.lua']=nil
assert(not Up.run());eq(files['farm.lua'],'old program');eq(reboots,0)
realPrint('PASS unavailable release file leaves installed programs untouched')
m=reset();failWrite='startup.lua';assert(not Up.run());eq(files['farm.lua'],'old program')
eq(files['startup.lua'],'old startup');assert(not files['farm/new_module.lua']);eq(reboots,0)
eq(textutils.unserializeJSON(files['farm/version.json']).version,'0.1.0')
assert(not files['farm/update-pending.json'])
realPrint('PASS mid-install disk failure restores old programs and removes only newly installed program files')
m=reset();local before=false
assert(not Up.run({beforeInstall=function() before=true;return false,'Worker busy' end}))
assert(before);eq(#requests,1);eq(files['farm.lua'],'old program');eq(reboots,0)
realPrint('PASS busy-worker gate blocks installation after confirmation and before downloads')
m=reset();local backup='farm/install-backups/update-123456-4'
files[backup..'/farm.lua']='old program';files['farm.lua']='partial program';files['farm/new_module.lua']='partial new module'
files['farm/update-pending.json']=encode({schema=1,backup=backup,entries={{path='farm.lua',existed=true},{path='farm/new_module.lua',existed=false}}})
assert(Up.recover());eq(files['farm.lua'],'old program');assert(not files['farm/new_module.lua'])
eq(files['farm/config'],'precious config');assert(files[backup..'/farm.lua'])
realPrint('PASS interrupted transaction recovery is idempotent, preserves backups and farm data')
print=realPrint
