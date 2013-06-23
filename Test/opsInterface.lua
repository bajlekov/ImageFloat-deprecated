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

-- Structure of operation functions for pixel ops:
-- - implement abstract function with buffer set/getter table
-- - abstraction does not impact performance, adding over 100 Mpix/s
-- - not significantly different from current implementation
-- - independent on number of input variables or their type

local ffi = require "ffi"
ffi.cdef[[
	void * malloc ( size_t size );
	void * calloc ( size_t num, size_t size );
	void * realloc ( void * ptr, size_t size );
	void free ( void * ptr );
	typedef float float_a __attribute__ ((aligned (16)));
	typedef double double_a __attribute__ ((aligned (16)));
]] -- allocate aligned memory for use with SSE

-- allocate aligned floats
local function alloc(size)
	return ffi.gc(ffi.cast("float_a*", ffi.C.calloc(size, 4)), ffi.C.free)
end

-- add example

local xSize = 6000
local ySize = 4000
local zSize = 3

local bufData1 = alloc(xSize*ySize*zSize)	-- C
local bufData2 = alloc(xSize*ySize)			-- GS
local bufData3 = alloc(xSize*ySize*zSize)	-- C

for i = 0, xSize*ySize*zSize-1 do
	bufData1[i] = math.random()
end
for i = 0, xSize*ySize-1 do
	bufData2[i] = math.random()
end


local bufIO = {}
bufIO.get = {}
bufIO.set = {}

-- create custom setters and getters for the datatype, do this programatically
bufIO.get[1] = function(x, y, z) return bufData1[x*ySize*zSize + y*zSize + z] end
bufIO.get[2] = function(x, y, z) return bufData2[x*ySize + y] end
bufIO.get[3] = function(x, y, z) return bufData3[x*ySize*zSize + y*zSize + z] end

bufIO.set[1] = function(x, y, z, v)	bufData1[x*ySize*zSize + y*zSize + z] = v end
bufIO.set[2] = function(x, y, z, v)	bufData2[x*ySize + y] = v end
bufIO.set[3] = function(x, y, z, v)	bufData3[x*ySize*zSize + y*zSize + z] = v end 

-- add operation, abstract combination through text replacement?
local function add(bt, x, y, z)
	bt.set[3](x,y,z, bt.get[1](x,y,z) + bt.get[2](x,y,z))
end

local function pixelOp(bt, fun, x, y, zSize)
	if zSize==nil then
		fun(bt, x, y, 0)
		fun(bt, x, y, 1)
		fun(bt, x, y, 2)
	elseif zSize==1 then
		fun(bt, x, y, 0)
	elseif zSize==2 then
		fun(bt, x, y, 0)
		fun(bt, x, y, 1)
	elseif zSize==3 then
		fun(bt, x, y, 0)
		fun(bt, x, y, 1)
		fun(bt, x, y, 2)
	else
		for z = 0, zSize-1 do
			fun(bufIO, x, y, z)
		end
	end
end

-- loop can be problematic to optimize sometimes?
-- nested loops or short loops inside long loops can show probabilistic changes in performance due to different order of optimization dependent on memory structure
local function pixelOpLoop(bt, fun, x, y, zSize)
	for z = 0, zSize-1 do
		fun(bufIO, x, y, z)
	end
end

-- move z-loop outside
local function pixelOpSingle(bt, fun, x, y, z)
	fun(bufIO, x, y, z)
end

-- safest solution: create inlined functions for common sizes of Z

---[[
-- warmup
for i = 1, 10 do
	for xPos = 0, xSize-1 do -- adapt for parallel execution
		for yPos = 0, ySize-1 do
			pixelOp(bufIO, add, xPos, yPos)
		end
	end
end

local t = os.clock()
for i = 1, 10 do
	for xPos = 0, xSize-1 do
		for yPos = 0, ySize-1 do
			bufData3[xPos*ySize*zSize + yPos*zSize + 0] = bufData1[xPos*ySize*zSize + yPos*zSize + 0] + bufData2[xPos*ySize + yPos]
			bufData3[xPos*ySize*zSize + yPos*zSize + 1] = bufData1[xPos*ySize*zSize + yPos*zSize + 1] + bufData2[xPos*ySize + yPos]
			bufData3[xPos*ySize*zSize + yPos*zSize + 2] = bufData1[xPos*ySize*zSize + yPos*zSize + 2] + bufData2[xPos*ySize + yPos]
		end
	end
end
print(os.clock()-t, "naive add")

local t = os.clock()
for i = 1, 10 do
	for xPos = 0, xSize-1 do
		for yPos = 0, ySize-1 do
			for z = 0, zSize-1 do
				bufData3[xPos*ySize*zSize + yPos*zSize + z] = bufData1[xPos*ySize*zSize + yPos*zSize + z] + bufData2[xPos*ySize + yPos]
			end
		end
	end
end
print(os.clock()-t, "naive add z-loop")

local t = os.clock()
for i = 1, 10 do
	for xPos = 0, xSize-1 do -- adapt for parallel execution
		for yPos = 0, ySize-1 do 
			pixelOp(bufIO, add, xPos, yPos)
		end
	end
end
print(os.clock()-t, "abstract add")
--]]

local function pixelOp(bt, fun, x, y)
	fun(bt, x, y, 0)
	fun(bt, x, y, 1)
	fun(bt, x, y, 2)
end

local t = os.clock()
for i = 1, 10 do
	for xPos = 0, xSize-1 do -- adapt for parallel execution
		for yPos = 0, ySize-1 do 
			pixelOp(bufIO, add, xPos, yPos)
		end
	end
end
print(os.clock()-t, "abstract add no branch")