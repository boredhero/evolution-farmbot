-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Transport corruption check, NOT a cryptographic signature. Trust comes from
-- HTTPS to our fixed GitHub repository and release-tagged source URLs.
return function(data)
  local a,b=1,0
  for i=1,#data do a=(a+data:byte(i))%65521;b=(b+a)%65521 end
  return string.format('%08x',b*65536+a)
end
