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

-- Bilateral filter for denoising 

local ffi = require("ffi")

local function f(a, b, d, c1, c2) -- lookup table with noise distribution
	return math.exp(-(a-b)^2/c1)*math.exp(-d/c2)
	--return (math.abs(a-b)<c1 and 1 or 0)*math.exp(-d/c2)
end

local function bilateral(i, p1, p2)
	local o = i:new()
	
	local nr = 16 -- kernel
	for x = nr, i.x-nr-1 do
		for y = nr, i.y-nr-1 do
			
			local s = 0
			local c = 0
			
			for xr = -nr,nr,2 do
				for yr = -nr,nr,2 do
					local t = f(i:i(x,y,0), i:i(x+xr,y+yr,0), xr^2+yr^2, p1, p2) -- precompute kernel weights
					s = s + i:i(x+xr,y+yr,0)*t
					c = c + t
				end
			end
			
			o:a(x,y,0, s/c)
		end
	end
	
	return o
end

return bilateral
