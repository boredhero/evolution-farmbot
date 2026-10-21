-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local G=require('farm.lib.growth')
local job={name='minecraft:wheat',seed='minecraft:wheat_seeds',age=7,mode='replant'}
local models={};local h={observed={name=job.name,state={age=0}},observedAt=100}
assert(not G.estimate(models,job,h,110))
G.record(models,h,job,{outcome='harvested',after={name=job.name,state={age=0}}},700)
assert(models[job.seed].samples==1 and models[job.seed].seconds==600 and h.growthStart==700)
h.observedAt=700
assert(G.estimate(models,job,h,1000)==300)
assert(G.estimate(models,job,h,1400)==0)
assert(h.observed.state.age==0,'estimation cannot mutate inspected maturity')
G.record(models,h,job,{outcome='growing',after=h.observed},1500)
assert(models[job.seed].samples==1,'unripe inspections do not fabricate completed cycles')
print('PASS farm-learned growth estimates remain explicitly approximate and never invent ripe observations')
