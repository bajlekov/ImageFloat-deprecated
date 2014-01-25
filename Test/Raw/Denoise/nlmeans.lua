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

-- NL-means denoising algorithm 
-- implemented from Secrets of image denoising cuisine

local ffi = require("ffi")
local unroll = require("Tools.unroll")

local l = 2
local k = (l*2+1)^2-1

local function d2(a, b)
	local sum = 0
	for i = 0, k do
		sum = sum + (a[i]-b[i])^2
	end
	return sum/(k+1)
end

local P = ffi.new("double[?]", k+1)
local Q = ffi.new("double[?]", k+1)

local unroll = unroll.construct(-l, l, -l, l)

local function getPfun(k, l, i, x, y, c)
	P[c] = i:i(x+k,y+l)
end
local function getQfun(k, l, i, x, y, c)
	Q[c] = i:i(x+k,y+l)
end

local function getP(i, x, y)
	local c = 0
	for k = -l, l do
		for l = -l, l do
			P[c] = i:i(x+k,y+l)
			c = c+1
		end
	end
end

local function getQ(i, x, y)
	local c = 0
	for k = -l, l do
		for l = -l, l do
			Q[c] = i:i(x+k,y+l)
			c = c+1
		end
	end
end

-- implement larger patches for raw denoising

local function nlmeans(i, sigma)
	local o = i:new()
	sigma = sigma or 0.05
	local l = 8 -- *2+1
	local sigma = sigma^2
	
	for x = l+2, i.x-l-3 do
		for y = l+2, i.y-l-3 do
			
			getP(i, x, y)
			
			local Phat = 0
			local Chat = 0
			
			for px = -l, l, 2 do
				for py = -l, l, 2 do
					getQ(i, x+px, y+py)
					
					local t = math.exp(-d2(P, Q)/sigma)
					Phat = Phat + Q[k/2]*t
					Chat = Chat + t
				end
			end
			
			o:a(x, y, Phat/Chat)
			
		end
		print(x)
	end
	
	return o
end

return nlmeans

