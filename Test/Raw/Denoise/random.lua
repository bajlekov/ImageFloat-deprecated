--[[
Copyright (C) 2011-2014 G. Bajlekov

ImageFloat is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ImageFloat is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- random noise generators

local dist = require("sci.dist")
local prng = require("sci.prng")

math.randomseed(os.clock())

local d = dist.normal(0, 1)
local r = prng.std()

local function rnorm(m, s)
	m = m or 0
	s = s or 1
	return d:sample(r)*s+m
end

return rnorm