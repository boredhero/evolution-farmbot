-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Clipped terminal framebuffer. Only changed rows are sent to a monitor.
local F={};F.__index=F
function F.new(w,h)
  local f=setmetatable({w=w,h=h,text={},fg={},bg={}},F)
  for y=1,h do f.text[y]={};f.fg[y]={};f.bg[y]={}
    for x=1,w do f.text[y][x]=' ';f.fg[y][x]='0';f.bg[y][x]='f' end
  end
  return f
end
function F:write(x,y,text,fg,bg)
  if y<1 or y>self.h then return end
  text=tostring(text)
  for i=1,#text do local at=x+i-1
    if at>=1 and at<=self.w then
      self.text[y][at]=text:sub(i,i);self.fg[y][at]=fg or '0';self.bg[y][at]=bg or 'f'
    end
  end
end
function F:fill(x,y,w,h,char,fg,bg)
  for row=math.max(1,y),math.min(self.h,y+h-1) do self:write(x,row,string.rep(char or ' ',math.max(0,w)),fg,bg) end
end
function F:box(x,y,w,h,title)
  if w<2 or h<2 then return end
  self:write(x,y,'+'..string.rep('-',w-2)..'+','9')
  self:write(x,y+h-1,'+'..string.rep('-',w-2)..'+','9')
  for row=y+1,y+h-2 do self:write(x,row,'|','9');self:write(x+w-1,row,'|','9') end
  if title then self:write(x+2,y,' '..title:sub(1,w-6)..' ','3') end
end
function F:row(y) return table.concat(self.text[y]),table.concat(self.fg[y]),table.concat(self.bg[y]) end
function F:flush(mon,previous)
  local cache={w=self.w,h=self.h,rows={}}
  local valid=previous and previous.w==self.w and previous.h==self.h
  for y=1,self.h do
    local t,f,b=self:row(y);local key=t..f..b;cache.rows[y]=key
    if not valid or previous.rows[y]~=key then mon.setCursorPos(1,y);mon.blit(t,f,b) end
  end
  return cache
end
return F
