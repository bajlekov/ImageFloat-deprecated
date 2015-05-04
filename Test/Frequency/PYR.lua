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

-- General implementation of pyramids

local ffi = require("ffi")
local unroll = require("Tools.unroll")
local pyr = {}


-- GB is the source buffer
local function g(x, y, z, gb) -- get, mirrored out of bounds: handle bounds in separate loop? (partly done)
	x = x>=0 and x or -x
	x = x<gb.x and x or 2*gb.x-x-2
	y = y>=0 and y or -y
	y = y<gb.y and y or 2*gb.y-y-2
	--z = z>=0 and z or -z
	--z = z<gb.z and z or 2*gb.z-z-2
	return gb:i(x,y,z)
end
local function s(x, y, z, v, gb) -- set/add if within bounds
	local check = (x>=0 and x<gb.x and y>=0 and y<gb.y)
	if check then
		gb:a(x,y,z, gb:i(x,y,z)+v)
	end
end


-- construct kernel
local a = 0.4
local k = ffi.new("double[5]", 1/4-a/2, 1/4, a, 1/4, 1/4-a/2)
pyr.kernel = k

local function convXG(z,x,y, h, gb) -- gather 
	local xi = x*2
	local t =
		k[0]*g(xi-2, y, z, gb) + k[1]*g(xi-1, y, z, gb) +
		k[2]*g(xi  , y, z, gb) + k[3]*g(xi+1, y, z, gb) +
		k[4]*g(xi+2, y, z, gb)
	h:a(x, y, z, t)
end
local function convYG(z,x,y, h, gb) -- gather
	local yi = y*2
	local t =
		k[0]*g(x, yi-2, z, gb) + k[1]*g(x, yi-1, z, gb) +
		k[2]*g(x, yi  , z, gb) + k[3]*g(x, yi+1, z, gb) +
		k[4]*g(x, yi+2, z, gb)
	h:a(x, y, z, t)
end
local function convXS(z,x,y, lo, gb) -- scatter
	local xi = x*2
	local t = lo:i(x, y, z)*2
	s(xi-2, y, z, t*k[0], gb)
	s(xi-1, y, z, t*k[1], gb)
	s(xi  , y, z, t*k[2], gb)
	s(xi+1, y, z, t*k[3], gb)
	s(xi+2, y, z, t*k[4], gb)
end
local function convYS(z,x,y, lo, gb) -- scatter
	local yi = y*2
	local t = lo:i(x, y, z)*2
	s(x, yi-2, z, t*k[0], gb)
	s(x, yi-1, z, t*k[1], gb)
	s(x, yi  , z, t*k[2], gb)
	s(x, yi+1, z, t*k[3], gb)
	s(x, yi+2, z, t*k[4], gb)
end

function pyr.reduce(hi)
	local lo = hi:new(math.floor(hi.x/2)+1, math.floor(hi.y/2)+1, hi.z)
	local h = hi:new(lo.x, hi.y, hi.z)
	for x = 1, h.x-1 do
		for y = 0, h.y-1 do
			unroll[h.z](convXG, x, y, h, hi)
		end
	end
	for y = 0, h.y-1 do
		unroll[h.z](convXG, 0, y, h, hi)
	end
	for x = 0, lo.x-1 do
		for y = 0, lo.y-1 do
			unroll[lo.z](convYG, x, y, lo, h)
		end
	end
	return lo
end

function pyr.expand(lo) -- check whether scatter is effective?
	local hi = lo:new(lo.x*2, lo.y*2, lo.z)
	local h = lo:new(hi.x, lo.y, lo.z)
	for x = 1, lo.x-1 do
		for y = 0, lo.y-1 do
			unroll[h.z](convXS, x, y, lo, h)
		end
	end
	for y = 0, lo.y-1 do
		unroll[h.z](convXS, 0, y, lo, h)
	end
	for x = 0, h.x-1 do
		for y = 0, h.y-1 do
			unroll[h.z](convYS, x, y, h, hi)
		end
	end
	return hi
end

local function subFun(z, x, y, a, b, c)
	c:a(x,y,z, a:i(x, y, z) - b:i(x, y, z))
end
local function addFun(z, x, y, a, b, c)
	c:a(x,y,z, a:i(x, y, z) + b:i(x, y, z))
end

function pyr.down(hi)
	local lo = pyr.reduce(hi) -- possibly combine steps?
	local rec = pyr.expand(lo)
	local diff = hi:new()
	for x = 0, hi.x-1 do
		for y = 0, hi.y-1 do
			unroll[hi.z](subFun, x, y, hi, rec, diff)
		end
	end
	return lo, diff
end

function pyr.up(lo, diff)
	local rec = pyr.expand(lo)
	local hi = diff:new()
	for x = 0, hi.x-1 do
		for y = 0, hi.y-1 do
			unroll[hi.z](addFun, x, y, rec, diff, hi)
		end
	end
	return hi
end

function pyr.construct(i, lvl)
	lvl = lvl or 5
	local G, L= {}, {}
	G[0] = i:copy()
	for i = 1, lvl do
		G[i], L[i-1] = pyr.down(G[i-1])
	end
	L[lvl] = G[lvl]:copy()
	return L, G
end

function pyr.collapse(L, top)
	top = top or 1
	local lvl = #L
	local G = L[lvl]
	for i = lvl, top, -1 do
		G = pyr.up(G, L[i-1])
	end
	return G
end

return pyr