-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Console help text. Kept out of controller.lua so tests/help.lua can read the
-- dispatcher and assert that every command it accepts is documented here.
local Help={}
Help.width=51 -- advanced computer terminal is 51 columns
-- names[] must list every token consoleLoop dispatches on; usage[] is what the
-- overview prints, grouped by group in the order the topics appear here.
Help.topics={
{names={'status'},group='Watch',usage={'status'},detail={
  'Running or paused, crop and worker counts,',
  'remembered replant gaps, the age of the last',
  'survey, and any scanner or display error.',
  'Reports what is left to drain during a stop.'}},
{names={'hardware'},group='Watch',usage={'hardware'},detail={
  'Every peripheral this controller can see, with',
  'anything required that is missing named MISSING.',
  'Shows monitor roles, the detected dimension,',
  'players in range, GPS position and the version.'}},
{names={'crops'},group='Watch',usage={'crops'},detail={
  'Counts each crop type found by the last survey.',
  'Something you just planted shows up after the',
  'next survey; run scan to look immediately.'}},
{names={'history'},group='Watch',usage={'history'},detail={
  'One line per remembered position: coordinates,',
  'crop name, last outcome and detail. A position',
  'unseen for seven days is forgotten.'}},
{names={'inventories'},group='Watch',usage={'inventories'},detail={
  'Wired inventory names this controller can reach.',
  'Use these names for the shared seed bank and the',
  'dock seed buffers when running farm setup.'}},
{names={'start'},group='Run',usage={'start'},detail={
  'Enable the workers. They take jobs as soon as a',
  'fresh survey exists. Also cancels a pending stop.'}},
{names={'pause'},group='Run',usage={'pause'},detail={
  'Hand out no new work. A worker finishes a replant',
  'it already started, then returns to its dock.',
  'Remembered replant gaps survive a pause.'}},
{names={'stop','exit','quit'},group='Run',usage={'stop'},detail={
  'Pause, wait for every worker to finish and dock,',
  'save, then return to the CraftOS prompt.',
  'Run start to cancel while it is still draining.',
  'Run farm start to launch the controller again.'}},
{names={'scan'},group='Run',usage={'scan'},detail={
  'Queue a survey now instead of waiting for the',
  'next scheduled one. Use it after planting or',
  'after clearing a blocked route.'}},
{names={'screens'},group='Screens',usage={'screens'},detail={
  'Lists each attached monitor and whether it is',
  'showing the map or the statistics view.'}},
{names={'screen'},group='Screens',
  usage={'screen NAME map|stats','screen NAME scale 0.5|1|1.5|2'},detail={
  'Assign a monitor wall a role, or set its text',
  'size. NAME is a name printed by screens, such as',
  'monitor_0. Both settings survive a reboot.',
  'Scale 0.5 fits the whole survey on a 6x6 wall.'}},
{names={'allow'},group='Farm',usage={'allow ID'},detail={
  'Pair a worker turtle by its computer ID. An',
  'unpaired turtle has every request refused. The ID',
  'is the number farm start prints on that turtle.'}},
{names={'exclude'},group='Farm',usage={'exclude X Y Z'},detail={
  'Never work the crop at these block coordinates.',
  'It stays on the map, marked excluded.'}},
{names={'include'},group='Farm',usage={'include X Y Z'},detail={
  'Undo exclude for these block coordinates.'}},
{names={'check'},group='Update',usage={'check update'},detail={
  'Compare the installed version against the',
  'published release and show its notes. Installs',
  'nothing. GitHub caches that manifest for up to',
  'five minutes, so a release published moments ago',
  'can still read as up to date.'}},
{names={'update'},group='Update',usage={'update system'},detail={
  'Pause, wait for the workers to dock, download the',
  'published release, install it and reboot.',
  'Config, crop memory, replant debts and statistics',
  'are kept.'}},
{names={'help'},group='Help',usage={'help [command]'},detail={
  'help alone lists every console command.',
  'help scan explains one command in full.'}},
}
function Help.find(word)
  for _,t in ipairs(Help.topics) do
    for _,n in ipairs(t.names) do if n==word then return t end end
  end
end
local function label(text,pad) return text..':'..string.rep(' ',math.max(1,pad-#text)) end
local function overview()
  local out={'FarmBot console commands (help NAME for detail)'}
  local pad=0
  for _,t in ipairs(Help.topics) do pad=math.max(pad,#t.group+1) end
  local order,seen={},{}
  for _,t in ipairs(Help.topics) do
    if not seen[t.group] then seen[t.group]=true;order[#order+1]=t.group end
  end
  for _,group in ipairs(order) do
    local head=label(group,pad);local line=nil
    local function flush() if line then out[#out+1]=line;line=nil end end
    for _,t in ipairs(Help.topics) do
      if t.group==group then
        for _,form in ipairs(t.usage) do
          if not line then line=head..form
          elseif #line+2+#form<=Help.width then line=line..'  '..form
          else flush();line=string.rep(' ',#head)..form end
        end
      end
    end
    flush()
  end
  return out
end
-- Returns printable lines: the whole list, or one command explained.
function Help.lines(word)
  if not word or word=='' then return overview() end
  local t=Help.find(word)
  if not t then return {"No command called '"..tostring(word).."'.",'Type help for the full list.'} end
  local out={}
  for _,form in ipairs(t.usage) do out[#out+1]=form end
  for _,line in ipairs(t.detail) do out[#out+1]='  '..line end
  if #t.names>1 then
    local rest={}
    for i=2,#t.names do rest[#rest+1]=t.names[i] end
    out[#out+1]='  Same command: '..table.concat(rest,', ')
  end
  return out
end
return Help
