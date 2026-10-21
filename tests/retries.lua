-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local N=require('farm.lib.network')
local U=require('farm.lib.util')
local now=0;local sent={};U.now=function() return now end;U.openModem=function() end
N.discover=function() return {} end
rednet={send=function(_,m) sent[#sent+1]=m end,receive=function(_,timeout) now=now+timeout end}
local request=N.client({controller=4,group='test',session='boot'})
assert(not request('job'));assert(now==4 and #sent==4)
for i=2,4 do assert(sent[i].seq==sent[1].seq and sent[i].session=='boot') end
now=0;sent={};assert(not request('step'));assert(now==2 and #sent==4)
print('PASS one-second request retries and half-second movement retries reuse original sequence/session')
now=0;sent={};local delays=0;local discoveries=0
sleep=function(n)assert(n==0.25);now=now+n;delays=delays+1 end
N.discover=function()discoveries=discoveries+1;return {}end
rednet.receive=function()
 local m=sent[#sent];return 4,{seq=m.seq,session=m.session,busy=#sent<3,data={ok=true}}
end
assert(request('job').ok and #sent==3 and delays==2 and discoveries==0)
for i=2,#sent do assert(sent[i].seq==sent[1].seq) end
sent={};rednet.receive=function()local m=sent[#sent];return 4,{seq=m.seq,session=m.session,busy=true}end
local result,err=request('job');assert(not result and err:find('busy') and #sent==4 and discoveries==0)
print('PASS busy replies back off and retry the same sequence; overload is not misdiagnosed as lost connectivity')
