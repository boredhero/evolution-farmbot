-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local N=require('farm.lib.network')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local clock=1000
os={epoch=function() return clock*1000 end,getComputerID=function() return 4 end}
peripheral={getNames=function() return {'back'} end,hasType=function() return true end,
  call=function() return true end}
local sent,broadcast={},{}
local inbox={}
rednet={open=function() end,
  broadcast=function(m,p) broadcast[#broadcast+1]={m=m,p=p} end,
  send=function(id,m,p) sent[#sent+1]={id=id,m=m,p=p} end,
  receive=function(p,timeout)
    local next=table.remove(inbox,1)
    if not next then clock=clock+(timeout or 0);return nil end
    clock=clock+0.1;return next.id,next.m
  end}
eq(N.protocol({group='autofarm'}),'evolution-farmbot-v1:autofarm')
assert(N.DISCOVERY and not N.DISCOVERY:find('autofarm',1,true),'discovery must not depend on the farm name')
inbox={{id=4,m={kind='controller',group='autofarm',center={x=1,y=2,z=3}}},
       {id=9,m={kind='who'}},
       {id=4,m={kind='controller',group='autofarm'}}}
local found=N.discover(3)
eq(#found,1);eq(found[1].controller,4);eq(found[1].group,'autofarm')
eq(broadcast[1].p,N.DISCOVERY);eq(broadcast[1].m.kind,'who')
print('PASS discovery broadcasts on a name-independent protocol and ignores peers and duplicates')
inbox={{id=7,m={kind='controller',group='b'}},{id=4,m={kind='controller',group='a'}}}
local many=N.discover(3)
eq(#many,2);eq(many[1].controller,4);eq(many[2].controller,7)
print('PASS several controllers are all reported, ordered by computer ID')
sent={}
inbox={{id=11,m={kind='who'}}}
N.answer({group='autofarm',center={x=1,y=2,z=3}})
eq(#sent,1);eq(sent[1].id,11);eq(sent[1].p,N.DISCOVERY)
eq(sent[1].m.group,'autofarm');eq(sent[1].m.controller,4)
sent={};inbox={{id=11,m={kind='controller',group='other'}}}
N.answer({group='autofarm'})
eq(#sent,0)
print('PASS a controller answers pairing probes with its real farm name and ignores other answers')
local wrongName=N.mismatch({group='noah-farm',controller=4},{{controller=4,group='autofarm'}})
assert(wrongName:find('autofarm',1,true));assert(wrongName:find('noah-farm',1,true))
assert(wrongName:find('farm setup worker',1,true))
local wrongId=N.mismatch({group='autofarm',controller=9},{{controller=4,group='autofarm'}})
assert(wrongId:find('#4',1,true));assert(wrongId:find('#9',1,true))
eq(N.mismatch({group='autofarm',controller=4},{{controller=4,group='autofarm'}}),nil)
eq(N.mismatch({group='autofarm',controller=4},{}),nil)
print('PASS a name or ID mismatch is reported with both values and the command that fixes it')
