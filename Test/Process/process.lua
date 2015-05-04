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

local ffi = require("ffi")

local m, n = 100, 1000*1000
local d1 = ffi.new("float[?]", n)
local d2 = ffi.new("float[?]", n)
local d3 = ffi.new("float[?]", n)
local d4 = ffi.new("float[?]", n)
local p = {1,2,3}

local function fun1(i, o, p)
	o[1] = p[1]*i[1]+p[2]*i[2]
end
local function process1(i, o, p, nmax)
	local ii = {}
	local oo = {}
	for n = 0, nmax-1 do
		ii[1] = i[1][n]
		ii[2] = i[2][n]
		fun1(ii, oo, p)
		o[1][n] = oo[1]
	end
end

local function process2(i, o, p, nmax)
	for n = 0, nmax-1 do
		o[1][n] = p[1]*i[1][n]+p[2]*i[2][n]
	end
end

-- process automatically
--[[

function definition:
local function fun(i, o, p)
  o[1] = p[1]*i[1]+p[2]*i[2]
end

converted function
local function process(i, o, p, xmax, ymax, zmax, ...)
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      -- write function, unroll z
      local v = p[1]*i[1]:get(x,y,z) + p[2]i[2]:get(x,y,z)
      o[1]:set(x,y,z, v)
    end
  end
end

--]]

local function fun3(i, o, p)
	o(1, p(1)*i(1)+p(2)*i(2))
end
local function process3(i, o, p)
	local idx
	local function ii(a) return i[a][idx] end
	local function oo(a, b) o[a][idx] = b end
	local function pp(a) return p[a] end
	return function(fun, nmax)
		for n = 1, nmax-1 do
			idx = n
			fun(ii, oo, pp)
		end
	end
end

--[[ textual substitution to inline representation:

function(i, o, p)
	o[1,:] = i[1,b], i[1,g], i[1,r]
	
end




--]]



-- tests:

local t = os.clock()
for i = 1, m do
	process1({d1, d2}, {d4}, p, n)
end
print("arrays: "..(os.clock()-t))

local t = os.clock()
for i = 1, m do
	process2({d1, d2}, {d4}, p, n)
end
print("inline: "..(os.clock()-t))

local t = os.clock()
local f = process3({d1, d2}, {d4}, p)
for i = 1, m do
	f(fun3, n)
end
print("functs: "..(os.clock()-t))

local t = os.clock()
local f = process3({d1, d2}, {d4}, p)
for i = 1, m do
	f(fun3, n)
end
print("functs: "..(os.clock()-t))

local t = os.clock()
local f = process3({d1, d2}, {d4}, p)
for i = 1, m do
	f(fun3, n)
end
print("functs: "..(os.clock()-t))
