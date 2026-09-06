-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Produces previews from the actual renderer with clearly labeled synthetic data.
package.path='./?.lua;'..package.path
local D=require('farm.dashboard')
local fixture=require('tests.dashboard_fixture')
local palette={'f0f0f0','f2b233','e57fd8','99b2f2','dede6c','7fcc19','f2b2cc','1f242b',
 '999999','4c99b2','b266e5','3366cc','7f664c','57a64e','cc4c4c','111111'}
local function escape(s) return s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;') end
for _,role in ipairs({'map','stats'}) do
  local frame=D.new():render(fixture(),{role=role,zoom=2,cache=true},60,role=='map' and 40 or 34)
  local file=assert(io.open('dashboard-'..role..'-preview.html','w'))
  file:write('<!doctype html><meta charset="utf-8"><title>FarmBot '..role..' preview - simulated data</title><style>body{margin:0;background:#111;color:#aaa;font:14px monospace}header{padding:10px}svg{display:block;width:960px;height:auto}text{font:12px monospace;white-space:pre}</style><header>FARMBOT '..role:upper()..' / SIMULATED DEMO DATA / scale 1 on 6-wide monitors</header><svg xmlns="http://www.w3.org/2000/svg" width="'..(frame.w*8)..'" height="'..(frame.h*12)..'" viewBox="0 0 '..(frame.w*8)..' '..(frame.h*12)..'">')
  for y=1,frame.h do
    local text,fg,bg=frame:row(y)
    for x=1,frame.w do
      local px,py=(x-1)*8,(y-1)*12
      local b=palette[tonumber(bg:sub(x,x),16)+1];local f=palette[tonumber(fg:sub(x,x),16)+1]
      file:write(('<rect x="%d" y="%d" width="8" height="12" fill="#%s"/>'):format(px,py,b))
      local ch=text:sub(x,x)
      if ch~=' ' then file:write(('<text x="%d" y="%d" fill="#%s">%s</text>'):format(px,py+10,f,escape(ch))) end
    end
  end
  file:write('</svg>');file:close()
end
print('Built map/statistics HTML previews using simulated data')
