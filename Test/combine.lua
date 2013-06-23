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

-- combining operations in a single function in order to perform multiple operations within a single loop
-- removes temporaries as they become single values instead of whole buffers

local function add(a, b)
	return a+b
end

local function mul(a, b)
	return a*b
end

-- programatically create function that describes for example: add(mul(a, b), c)
local function c(a, b, c)
	return add(mul(a, b), c)
end

-- simple chaining of functions
-- branching and variables
-- based on parts of nodetree containing only pixel ops

-- example network
--[[
	-f-	F --- G -o1-
		 \   /
		   H --- I -o2-
		   
	F: split
	G: combine
	I: pass
		
	best bet is to write the function and compile it on the fly, check performance??
	- use temporary allocation of return values (functions can return more than one value!!)
	- call functions sequentially
	- keep track of input parameters in locals or tables?
	
	example:
	
	function combined(i1, i2, i3, i4)				-- input parameters
		local o1_1, o1_2, o1_3 = f1(i1, i2)			-- temporary output from functions
		local o2_1, o2_2 = f2(o1_3, i3)
		local o3_1, o3_2 = f3(o2_2, i4, o1_3)
		...
		return o3_1, o2_2, o1_3						-- return parameters
	end
	
--]]

-- compile combined function
-- how does compiling turn out?
--[=[
f = {add, mul}
local fun = [[
local f = f -- everything used in function must be local!!!!!!
return function(i1, i2)
	local o1_1 = f[1](i1, i2)
	local o2_1 = f[2](i1, o1_1)
	return o2_1
end
]]
local combined = loadstring(fun)() -- returns function definition
print(combined(3,6))
--]=]

---[[
-- test whether function calling and temporaries adds overhead!
local ffi = require("ffi")
local size = 1024000
local dataInA = ffi.new("float[?]", size+1)
local dataInB = ffi.new("float[?]", size+1)
local dataTemp = ffi.new("float[?]", size+1)
local dataOut = ffi.new("float[?]", size+1)
local t

for i=1,size do
	dataInA[i] = math.random()
	dataInB[i] = math.random()
end

--plain direct: basic functions as used now
jit.flush()
collectgarbage("collect")
t = os.clock()
for n = 1, 1000 do
	for i=1,size do
		dataTemp[i] = dataInA[i] + dataInB[i]
	end
	for i=1,size do
		dataOut[i] = dataInA[i] * dataTemp[i]
	end
end
print(os.clock()-t)

-- no penalty for function calls or storage in temporaries before assignment to buffer

--combined direct: reducing loops yields ~10% reduction
jit.flush()
collectgarbage("collect")
t = os.clock()
for n = 1, 1000 do
	for i=1,size do
		dataTemp[i] = dataInA[i] + dataInB[i]
		dataOut[i] = dataInA[i] * dataTemp[i]
	end
end
print(os.clock()-t)

--combined direct temp: using local temporaries reduces load significantly
jit.flush()
collectgarbage("collect")
t = os.clock()
for n = 1, 1000 do
	for i=1,size do
		local t = dataInA[i] + dataInB[i]
		dataOut[i] = dataInA[i] * t
	end
end
print(os.clock()-t)

--combined func temps: same performance
jit.flush()
collectgarbage("collect")
t = os.clock()
local f1, f2 = add, mul
for n = 1, 1000 do
	for i=1,size do
		local i1, i2 = dataInA[i], dataInB[i]
		local o1_1 = f1(i1, i2)
		local o2_1 = f2(i1, o1_1)
		dataOut[i] = o2_1
	end
end
print(os.clock()-t)

--ultimate func temps: same performance
jit.flush()
collectgarbage("collect")
t = os.clock()
do
	local f = {add, mul}
	local function combined(i1, i2)
		local o1_1 = f[1](i1, i2)
		local o2_1 = f[2](i1, o1_1)
		return o2_1
	end
	
	for n = 1, 1000 do
		for i=1, size do
			dataOut[i] = combined(dataInA[i], dataInB[i])
		end
	end
end
print(os.clock()-t)

-- ultimate compiled func temp
jit.flush()
collectgarbage("collect")
t = os.clock()

-- compile combined function
_G.__funcTable = {add, mul} -- add f to global space
local fun = [[
local f = __funcTable -- create local copy of functions table
return function(i1, i2)
	local o1_1 = f[1](i1, i2)
	local o2_1 = f[2](i1, o1_1)
	return o2_1
end
]]
local c = assert(loadstring(fun))() -- returns function definition
_G.__funcTable = nil -- clean up global space

for n = 1, 1000 do
	for i=1,size do
		dataOut[i] = c(dataInA[i], dataInB[i])
	end
end
print(os.clock()-t)

--]]
