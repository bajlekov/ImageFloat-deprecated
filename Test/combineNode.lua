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

-- Tests regarding the performance of combining and compiling multiple nodes

-- idea: merge operations within a loop, resulting in better memory locality

local function fAdd(a, b) return a+b end 
local function fSub(a, b) return a-b end
local function fMul(a, b) return a*b end
local function fDiv(a, b) return a/b end
local function fPow(a, b) return a^b end

-- composite function
local function fMerge(a, b, c)
	local t1 = fAdd(a, fSub(b, c))
	local t2 = fAdd(fSub(a, b), c)
	return fSub(t1, t2)
end

local ffi = require "ffi"

local n = 1000*1000*12

local a = ffi.new("float[?]", n)
local b = ffi.new("float[?]", n)
local c = ffi.new("float[?]", n)
-- initialize inputs with useful data
for i = 0, n-1 do
	a[i] = math.random(4096)
	b[i] = math.random(4096)
	c[i] = math.random(4096)
end

local function apply3(fun, a, b, c)
	local o = ffi.new("float[?]", n)
	for i = 0, n-1 do
		o[i] = fun(a[i], b[i], c[i])
	end
	return o
end

local function apply2(fun, a, b)
	local o = ffi.new("float[?]", n)
	for i = 0, n-1 do
		o[i] = fun(a[i], b[i])
	end
	return o
end

local t = os.clock()
for i = 1, 10 do
	local t1 = apply2(fAdd, a, apply2(fSub, b, c))
	local t2 = apply2(fAdd, apply2(fSub, a, b), c)
	local o2 = apply2(fSub, t1, t2)
	collectgarbage("collect")
end

local t = os.clock()
for i = 1, 10 do
	local o1 = apply3(fMerge, a, b, c)
	collectgarbage("collect")
end
print(os.clock()-t, "merged")

local t = os.clock()
for i = 1, 10 do
	local t1 = apply2(fAdd, a, apply2(fSub, b, c))
	local t2 = apply2(fAdd, apply2(fSub, a, b), c)
	local o2 = apply2(fSub, t1, t2)
	collectgarbage("collect")
end
print(os.clock()-t, "sequential")

-- test only allocating all temporary outputs?
collectgarbage("setpause", 100)

local t = os.clock()
for i = 1, 10 do
	local o = ffi.new("float[?]", n)
	local o = ffi.new("float[?]", n)
	local o = ffi.new("float[?]", n)
	local o = ffi.new("float[?]", n)
	local o = ffi.new("float[?]", n)
	collectgarbage("collect")
end
print(os.clock()-t, "mem alloc temp")

local t = os.clock()
for i = 1, 10 do
	local o = ffi.new("float[?]", n)
	collectgarbage("collect")
end
print(os.clock()-t, "mem alloc none")

-- memory locality helps significantly, especially for fast operations <- want!!! would probably solve great delays with simple ops, eliminating overhead
-- temporary memory allocation saves time

local aa = loadstring("print'a'")
aa()

print("end")

