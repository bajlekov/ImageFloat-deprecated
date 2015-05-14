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
local lut = require("Tools.lut")
lut.linear = true

local l = 2
local k = (l*2+1)^2

local P = ffi.new("double[?]", k)
local Q = ffi.new("double[?]", k)
local N = ffi.new("double[?]", k)
local O = ffi.new("double[?]", k)

local function d2(a, b)
	local sum = 0
	for i = 0, k-1 do
		sum = sum + (a[i]-b[i])^2
	end
	return sum/k
end

-- unrolling does not help!
local function getP(P, i, x, y)
	local c = 0
	for k = -l, l do
		for m = -l, l do
			--P[(k+l)*(2*l+1)+(m+l)] = i:i(x+k,y+m)
			P[c] = i:i(x+k,y+m)
			c = c+1
		end
	end
end

local exp = math.exp
-- implement larger patches for raw denoising
local function nlmeans(i, sigma, ii)	-- use ii as a predictor if available
	local o = i:new()
	sigma = 1/(sigma or 0.05)^2
	local ll = l
	local kk = 1/k
	local l = 16 -- *2+1
	local mid = (k-1)/2
	
	local explut = lut.create(function(x) return exp(-x*sigma) end, 0, 2, 1024, 0) -- TODO: possibly tune, too tricky at present
	
	for x = l+ll, i.x-l-ll-1 do -- optional step of patch size for speedup
		for y = l+ll, i.y-l-ll-1 do
			
			getP(P, i, x, y)
			
			--local Phat = 0
			local Chat = 0
			
			for i = 0, k-1 do
				N[i] = 0
			end
			
			for px = -l, l, 2 do
				for py = -l, l, 2 do
					
					getP(Q, i, x+px, y+py)
					if ii then
						getP(O, ii, x+px, y+py)
					end
					
					local t
					if ii then
						t = exp(-d2(P, O)*sigma)
						--local t = explut(d2(P, O))
					else
						t = exp(-d2(P, Q)*sigma)
						--local t = explut(d2(P, Q))
					end
					
					--Phat = Phat + Q[mid]*t
					Chat = Chat + t
					
					for i = 0, k-1 do
						N[i] = N[i] + Q[i]*t
					end
					
				end
			end
			
			Chat = 1/Chat
			
			do
				local c = 0
				for k = -ll, ll do
					for m = -ll, ll do
						o:a(x+k,y+m,0, o:i(x+k,y+m,0) + N[c]*Chat*kk)
						--o:a(x+k,y+m,0, o:i(x+k,y+m,0) + N[c]*Chat)
						c = c+1
					end
				end
			end
			
			--o:a(x,y,0, Phat*Chat)
			
		end
		--io.write(x)
	end
	
	return o
end

return nlmeans

