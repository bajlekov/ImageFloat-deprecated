--[[
	Copyright (C) 2011-2012 G. Bajlekov

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

-- new buffer class with c memory allocation

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
local function allocF(size)
	return ffi.gc(ffi.cast("float_a*", ffi.C.calloc(size, 4)), ffi.C.free)
end

-- allocate aligned doubles
local function allocD(size)
	return ffi.gc(ffi.cast("double_a*", ffi.C.calloc(size, 8)), ffi.C.free)
end

-- set default allocator
local alloc = allocF

local buffer = {}
buffer.meta={}
buffer.metaDebug={}

-- indexing with array bounds checking
function buffer.metaDebug.__newindex(t, k, v) --set
	if k>(t.x*t.y*t.z-1) or k<0 then
		print(debug.traceback("WARNING: Assignment outside array bounds, element "..k.." of "..t.x*t.y*t.z.."."))
		-- automatic resizing for array lib
	else
		t.data[k] = v
	end
end

function buffer.meta.__newindex(t, k, v) --set
	k = type(k)=="table" and (k[1]*t.y*t.z + k[2]*t.z + k[3]) or k
	t.data[k] = v
end

function buffer:get(x,y,z)
	return self.data[x*self.y*self.z + y*self.z + z]
end

function buffer:set(x,y,z, v)
	self.data[x*self.y*self.z + y*self.z + z] = v
end


function buffer.metaDebug.__index(t, k) --get
	if k>(t.x*t.y*t.z-1) or k<0 then
		print(debug.traceback("WARNING: Index outside array bounds, element "..k.." of "..t.x*t.y*t.z.."."))
		return 0
		-- automatic resizing for array lib
	else
		return t.data[k]
	end
end

function buffer.meta.__index(t, k) --get
	return t.data[k]
end

function buffer:clean()
	ffi.C.realloc(self.data, 1)
	self.x=0
	self.y=0
	self.z=0
end

function buffer:new(x, y, z, ...)
	x = x or self.x or 1
	y = y or self.y or 1
	z = z or self.z or 1
	
	local size = x*y*z
	
	local o = {
		__type = "buffer",
		data = alloc(size),
		cs = z==3 and "SRGB" or "MAP",
		x = x,
		y = y,
		z = z,		-- derive buffer type from coordinates
		
		xoff = 0,	-- sub-regions for partial processing
		yoff = 0,
		xlen = x,
		ylen = y,
		
		new = buffer.new,		-- overload with grayscale/color
		copy = buffer.copy,		-- overload with grayscale/color
		free = buffer.clean,
		i = buffer.get,			-- simple getter
		a = buffer.set,			-- simple setter
			
			--toScreen
			--toScreenQ
			--saveHD
			--loadHD
			--save		-- from image file, generic
			--load		-- to image file, generic
			
			--pixelOp
			-- other ops:
				-- add (+)
				-- sub (-)
				-- mul (*)
				-- div (/)
				-- inv (-)
				-- concat (..) ??
				-- compare (create map)
				-- threshold (%)
				-- pow (^)
				-- call ()
				-- tostring method
				-- other useful methods
			--csConv
		}
	setmetatable(o, buffer.meta)
	return o
end

local b = buffer:new(128,128,128)

local t = os.clock()
for i = 1, 25 do
	for x=0,127 do
		for y=0,127 do
			for z=0,127 do
				b[x*b.y*b.z + y*b.z + z] = x+y+z
			end
		end
	end
end
print((os.clock() - t)*4, "array assignment")

local t = os.clock()
for i = 1, 100 do
	for x=0,127 do
		for y=0,127 do
			for z=0,127 do
				--b[{x,y,z}] = x+y+z
				b:a(x,y,z,x+y+z)
			end
		end
	end
end
print((os.clock() - t), "array assignment with table index")

local t = os.clock()
for i = 1, 100 do
	for x=0,127 do
		for y=0,127 do
			for z=0,127 do
				b.data[x*b.y*b.z + y*b.z + z] = x+y+z
			end
		end
	end
end
print(os.clock() - t, "raw data assignment")

--implement:
--[==[
	- creation:
		- :new()								(size from parent)
		- :new(old)								(size from old)
		- :new(sizeX, sizeY, size.Z, c1...cZ)	(any dim)
		- :newI(sizeX, sizeY, c1, c2, c3)		(image)
		- :newM(sizeX, sizeY, v1)				(map)
		- :newC(c1, c2, c3)						(color)
		- :newV(v1)								(value)
		- :newA(sizeX, v1...vX)							(array)
	- coercion:
		- :convert(source, "target") (with realloc, correctly interlaced RGB)
		- I>M, M>I
		- C>V, V>C
		- C>I, V>M
	- copy:
		- :copy
		- :copy("target")
		- :copyI(I/M)
		- :copyG(I/M)
`		- :copyC(C/V)
		- :copyV(C/V)
	- data:
		- .rawData		(pointer to original allocated mem)
		- .data			(pointer to cast data)
		- .precision	("single" or "double")
		- .type			(I/M/C/V/A/"empty")
		- :clean()		(manually realloc to 1 element)	
		- array bounds checking optional -- no significant effect on indexing
	
	- indexing:	-- setting/getting is up to 4 times slower than raw access, but is convenient for prototyping
				-- indexing with arrays is up to 50 times slower!!!
				-- shorthand i indexing function, a assignment function? assignment is more difficult -> yields same performance as direct raw indexing/assignment, yay!
		- [{ X, Y, Z}] = V
		- [{ {minX, maxX}, Y, Z}] = I/G
		- [{ {minX}, Y, Z}]
		- [{ {0, maxX}, Y, Z}]
		- [{ X, Y }] = {}/C/V
		- [{Z}] => copyG
		- also functional getters and setters:
			- set(x,y,z,v)
			- set3(x,y,z,c1,c2,c3)
			- get(x,y,z)
			- get3(x,y)
			-- check performance difference when overloading
--]==]

-- tests alloc/collect tests
--[[
local p
local size = 1024*1024*1024
local n = 100000

local t = os.clock()
for i = 1, n do
	p = allocd(size/8)
	ffi.C.realloc(p, 16)
end
print(os.clock() - t, "C GC callback")
collectgarbage()

local t = os.clock()
for i = 1, n do
	p = ffi.cast("double*", ffi.C.calloc(size, 1))
	ffi.C.realloc(p, 16)
	ffi.C.free(p)
end
print(os.clock() - t, "C explicit free")
collectgarbage()

local t = os.clock()
for i = 1, n do
	p = ffi.cast("double*", ffi.gc(ffi.C.calloc(size, 1), ffi.C.free))
	ffi.C.realloc(p, 16)
end
print(os.clock() - t, "C GC callback")
collectgarbage()
--]]
