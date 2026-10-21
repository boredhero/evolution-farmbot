-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local A=require('farm.lib.crop_access')
local W=require('farm.lib.world')
local U=require('farm.lib.util')
local base={pos={x=0,y=0,z=0},name='minecraft:wheat',seed='minecraft:wheat_seeds',mode='replant'}
local child={pos={x=1,y=0,z=0},key='1,0,0',name=base.name,seed=base.seed,mode='replant'}
local plots={[child.key]={live=true,version=4,job=child}}
local batch={pending={[child.key]=child.name},visited={}}
local world=W.new({x=0,y=0,z=0},3)
local scan={{x=1,y=1,z=0,name='minecraft:wall_torch'},{x=2,y=0,z=0,name='minecraft:wheat'},
 {x=1,y=0,z=1,name='minecraft:wheat'},{x=1,y=0,z=-1,name='minecraft:stone'}}
world:ingest(scan)
local function get(leases,excluded) return A.candidates(base,world,plots,batch,leases or {},excluded or {}) end
local found=get();assert(#found==1 and found[1].version==4 and found[1].key==child.key)
assert(#get({[child.key]={}})==0);assert(#get(nil,{[child.key]=true})==0)
batch.visited[child.key]=true;assert(#get()==0);batch.visited={}
batch.pending={};assert(#get()==0);batch.pending={[child.key]=child.name}
child.name='minecraft:carrots';assert(#get()==0);child.name=base.name
child.half='lower';assert(#get()==0);child.half=nil
world:observe({x=1,y=1,z=0},false);assert(#get()==0)
world:observe({x=1,y=1,z=0},{name='minecraft:wall_torch'})
world:observe({x=1,y=0,z=1},false);assert(#get()==0)
assert(world:name({x=1,y=1,z=0})=='minecraft:wall_torch')
print('PASS crop access selects only blocked single-block neighbors in the same unfinished round, respecting leases, exclusions and alternate air approaches')
