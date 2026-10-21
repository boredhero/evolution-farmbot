-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Verified single-item conversions in FTB Evolution 1.45.1 (jars + KubeJS).
local R={}
R.recipes={
 ['minecraft:wheat_seeds']={{item='minecraft:wheat',count=1}},
 ['minecraft:beetroot_seeds']={{item='minecraft:beetroot',count=1}},
 ['farmersdelight:cabbage_seeds']={{item='farmersdelight:cabbage',count=1}},
 ['immersiveengineering:seed']={{item='immersiveengineering:hemp_fiber',count=1}},
 ['farmersdelight:tomato_seeds']={{item='farmersdelight:tomato',count=1},{item='farmersdelight:rotten_tomato',count=1}},
 ['actuallyadditions:canola_seeds']={{item='actuallyadditions:canola',count=1}},
 ['actuallyadditions:rice_seeds']={{item='actuallyadditions:rice',count=1}},
 ['silentgear:fluffy_seeds']={{item='silentgear:fluffy_puff',count=1}},
 ['minecraft:melon_seeds']={{item='minecraft:melon_slice',count=1}},
 ['minecraft:pumpkin_seeds']={{item='minecraft:pumpkin',count=4},{item='farmersdelight:pumpkin_slice',count=1}},
 ['biomeswevegone:pale_pumpkin_seeds']={{item='biomeswevegone:pale_pumpkin',count=4}},
}
function R.find(seed,inventory)
  for _,r in ipairs(R.recipes[seed] or {}) do if (inventory[r.item] or 0)>0 then return r end end
end
return R
