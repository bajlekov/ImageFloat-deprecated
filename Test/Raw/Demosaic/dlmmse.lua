--[[
Copyright (C) 2011-2013 G. Bajlekov

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

--[[
Adapted from:
L. Zhang and X. Wu,
“Color demosaicking via directional linear minimum mean square-error estimation,”
IEEE Trans. on Image Processing, vol. 14, pp. 2167-2178, Dec. 2005.
--]]

local unroll = require("Tools.unroll")
local ffi = require("ffi")

local function getCh(x, y)
	return (x%2==1 and y%2==1 and "G") or
		(x%2==0 and y%2==0 and "G") or
		(x%2==0 and y%2==1 and "B") or
		(x%2==1 and y%2==0 and "R")
end

local function convH5fun(i, x, y, bi, bo, k)
	bo:a(x,y, bo:i(x,y) + bi:i(x+i-2,y)*k[i])
end
local function convV5fun(i, x, y, bi, bo, k)
	bo:a(x,y, bo:i(x,y) + bi:i(x,y+i-2)*k[i])
end
local function convH9fun(i, x, y, bi, bo, k)
	bo:a(x,y, bo:i(x,y) + bi:i(x+2*i-8,y)*k[i])
end
local function convV9fun(i, x, y, bi, bo, k)
	bo:a(x,y, bo:i(x,y) + bi:i(x,y+2*i-8)*k[i])
end

local function convH5(bi, bo, k)
	for x = 2, bi.x-3 do
		for y = 0, bi.y-1 do
			unroll[5](convH5fun, x, y, bi, bo, k)
		end
	end
end

local function convV5(bi, bo, k)
	for x = 0, bi.x-1 do
		for y = 2, bi.y-3 do
			unroll[5](convV5fun, x, y, bi, bo, k)
		end
	end
end

local function convH9(bi, bo, k)
	for x = 8, bi.x-9 do
		for y = 0, bi.y-1 do
			for i = 0, 8 do -- unrolling slows this down
				convH9fun(i, x, y, bi, bo, k)
			end
		end
	end
end

local function convV9(bi, bo, k)
	for x = 0, bi.x-1 do
		for y = 8, bi.y-9 do
			for i = 0, 8 do -- unrolling slows this down
				convV9fun(i, x, y, bi, bo, k)
			end
		end
	end
end

local function copyH9(bi, bo, x, y)
	for i = 0, 8 do
		bo[i] = bi:i(x+i-4, y)
	end
end
local function copyV9(bi, bo, x, y)
	for i = 0, 8 do
		bo[i] = bi:i(x, y+i-4)
	end
end

local function sum9(bi)
	local o = 0
	for i = 0, 8 do
		o = o + bi[i]
	end
	return o
end

local function mean9(bi)
	return sum9(bi)/9
end

local function cov9(bi)
	local o = 0
	local m = mean9(bi)
	for i = 0, 8 do
		o = o + (bi[i]-m)^2
	end
	return o/9
end

local function calcR9(at, t)
	local o = 0
	for i = 0, 8 do
		o = o + (at[i]-t[i])^2
	end
	return o/9
end

local f5 = ffi.new("double[5]", -1/4, 1/2, 1/2, 1/2, -1/4)
local f9 = ffi.new("double[9]", 4/128, 9/128, 15/128, 23/128, 26/128, 23/128, 15/128, 9/128, 4/128) -- variable filters!

local function demosaic(i)
	local ih = i:new()
	local iv = i:new()
	convH5(i, ih, f5)
	convV5(i, iv, f5)

	local dh = i:new()
	local dv = i:new()
	for x = 0, i.x-1 do
		for y = 0, i.y-1 do
			local c = getCh(x, y)
			if c=="G" then
				dh:i(x,y, i:i(x,y)-ih:i(x,y))
				dv:i(x,y, i:i(x,y)-iv:i(x,y))
			else
				dh:a(x,y, ih:i(x,y)-i:i(x,y))
				dv:a(x,y, iv:i(x,y)-i:i(x,y))
			end
		end
	end

	local adh = i:new()
	local adv = i:new()

	convH9(dh, adh, f9)
	convV9(dv, adv, f9)

	local o = i:newI()

	local t = ffi.new("double[9]")
	local at = ffi.new("double[9]")

	for x = 4, i.x-5 do
		for y = 4, i.y-5 do
			if getCh(x, y)~="G" then
				copyH9(dh, t, x, y)
				copyH9(adh, at, x, y)

				local m = at[4]
				local p = cov9(at)
				local R = calcR9(at, t)

				local h = m + p*(t[4]-m)/(p+R)
				local H = p - p^2/(p+R)

				copyV9(dv, t, x, y)
				copyV9(adv, at, x, y)

				local m = at[4]
				local p = cov9(at)
				local R = calcR9(at, t)

				local v = m + p*(t[4]-m)/(p+R)
				local V = p - p^2/(p+R)

				local t = (V*h + H*v)/(H + V)
				o:a(x,y,1, i:i(x, y) + t) -- reconstruct missing green values
			else
				o:a(x,y,1, i:i(x,y))
			end
		end
	end

	--simple delta-R/B interpolation
	for x = 1, i.x-2 do
		for y = 1, i.y-2 do
			local c = getCh(x, y)
			if c~="G" then
				local t = o:i(x,y,1) + (
					i:i(x-1,y-1) - o:i(x-1,y-1,1) +
					i:i(x-1,y+1) - o:i(x-1,y+1,1) +
					i:i(x+1,y-1) - o:i(x+1,y-1,1) +
					i:i(x+1,y+1) - o:i(x+1,y+1,1)
					)/4
				if c=="R" then
					o:a(x,y,2, t)
					o:a(x,y,0, i:i(x,y))
				elseif c=="B" then
					o:a(x,y,0, t)
					o:a(x,y,2, i:i(x,y))
				end
			end
		end
	end

	for x = 1, i.x-2 do
		for y = 1, i.y-2 do
			if getCh(x, y)=="G" then
				local tneg = o:i(x+1,y,1) +
					o:i(x,y+1,1) +
					o:i(x-1,y,1) +
					o:i(x,y-1,1)

				if getCh(x+1,y)=="R" then
					local t0 = i:i(x,y) + (
						i:i(x+1,y) + o:i(x,y+1,0) +
						i:i(x-1,y) + o:i(x,y-1,0) -
						tneg)/4
					local t2 = i:i(x,y) + (
						o:i(x+1,y,2) + i:i(x,y+1) +
						o:i(x-1,y,2) + i:i(x,y-1) -
						tneg)/4
					o:a(x,y,0, t0)
					o:a(x,y,2, t2)
				else
					local t2 = i:i(x,y) + (
						i:i(x+1,y) + o:i(x,y+1,2) +
						i:i(x-1,y) + o:i(x,y-1,2) -
						tneg)/4
					local t0 = i:i(x,y) + (
						o:i(x+1,y,0) + i:i(x,y+1) +
						o:i(x-1,y,0) + i:i(x,y-1) -
						tneg)/4
					o:a(x,y,0, t0)
					o:a(x,y,2, t2)
				end
			end
		end
	end

	return o
end

return demosaic