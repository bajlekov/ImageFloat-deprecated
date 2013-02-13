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


local buffer = {}
buffer.alloc = allocF
buffer.meta={__index = buffer}

function buffer.meta.__add(a, b)
	if a.x~=b.x or a.y~=b.y or a.z~=b.z then
		print(debug.traceback("WARNING: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
		return nil
	else
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) + b:get(i,j,k) )				
				end
			end
		end
		return o
	end
end

function buffer.meta.__sub(a, b)
	if a.x~=b.x or a.y~=b.y or a.z~=b.z then
		print(debug.traceback("WARNING: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
		return nil
	else
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) - b:get(i,j,k) )				
				end
			end
		end
		return o
	end
end

function buffer.meta.__mul(a, b)
	if a.x~=b.x or a.y~=b.y or a.z~=b.z then
		print(debug.traceback("WARNING: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
		return nil
	else
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) * b:get(i,j,k) )				
				end
			end
		end
		return o
	end
end

function buffer.meta.__div(a, b)
	if a.x~=b.x or a.y~=b.y or a.z~=b.z then
		print(debug.traceback("WARNING: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
		return nil
	else
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) / b:get(i,j,k) )				
				end
			end
		end
		return o
	end
end

-- use metatable to call methods from base table
			-- new
			-- copy
			-- clean
			-- set
			-- get
			
		--toScreen
		--toScreenQ
		--saveHD
		--loadHD
		--save		-- from image file, generic
		--load		-- to image file, generic
			
		--pixelOp
		-- other ops:
			-- inv (-)
			-- concat (..) ??
			-- compare (create map)
			-- threshold (%)
			-- pow (^)
			-- call ()
			-- tostring method
			-- other useful methods
			--csConv



function buffer:getABC(x,y,z)
	if x>=self.x or y>=self.y or z>=self.z or x<0 or y<0 or z<0 then
		print(debug.traceback("WARNING: Index outside array bounds, element ["..x..", "..y..", "..z.."] of ["..self.x..", "..self.y..", "..self.z.."]."))
		return 0
	else
		return self.data[x*self.y*self.z + y*self.z + z]
	end
end

function buffer:setABC(x,y,z, v)
	if x>=self.x or y>=self.y or z>=self.z or x<0 or y<0 or z<0 then
		print(debug.traceback("WARNING: Index outside array bounds, element ["..x..", "..y..", "..z.."] of ["..self.x..", "..self.y..", "..self.z.."]."))
		return nil
	else
		self.data[x*self.y*self.z + y*self.z + z] = v
	end
end

function buffer:get(x,y,z)
	return self.data[x*self.y*self.z + y*self.z + z]
end

function buffer:set(x,y,z, v)
	self.data[x*self.y*self.z + y*self.z + z] = v
end

function buffer:get3(x,y,z)
	local c = x*self.y*self.z + y*self.z
	return self.data[c], self.data[c+1], self.data[c+2] 
end

function buffer:set3(x,y,z, v1,v2,v3)
	local c = x*self.y*self.z + y*self.z
	self.data[c] = v1
	self.data[c+1] = v2
	self.data[c+2] = v3
end


function buffer:new(x, y, z)
	x = x or self.x or 1
	y = y or self.y or 1
	z = z or self.z or 1	
	local size = x*y*z
	
	local o = {
		__type = "buffer",
		data = self.alloc(size),
		cs = "MAP",
		x = x, y = y, z = z,	-- derive buffer type from coordinates
		
		xoff = 0, yoff = 0,		-- sub-regions for partial processing
		xlen = x, ylen = y,
	}
	setmetatable(o, buffer.meta)	
	return o
end

function buffer:copy()
	local x = self.x
	local y = self.y
	local z = self.z	
	local size = x*y*z
	
	local o = {
		__type = "buffer",
		data = self.alloc(size),
		cs = self.cs,
		x = x, y = y, z = z,	-- derive buffer type from coordinates
		
		xoff = 0, yoff = 0,		-- sub-regions for partial processing
		xlen = x, ylen = y,
	}
	setmetatable(o, buffer.meta)	
	ffi.copy(o.data, self.data, size*4) -- switch to 8 for double		
	return o
end

function buffer:clean()
	ffi.C.realloc(self.data, 1)
	self.x=1
	self.y=1
	self.z=1
end


---[[
local b = buffer:new(6000,4000,3)
b:set(1,2,3,4)

local t = os.clock()
local c = b:copy()
print((os.clock() - t), "copy")

local t = os.clock()
local d = b+c
print((os.clock() - t), "add")
assert(d:get(1,2,3)==8)

local t = os.clock()
local d = b-c
print((os.clock() - t), "sub")
assert(d:get(1,2,3)==0)

local t = os.clock()
local d = b*c
print((os.clock() - t), "mul")
assert(d:get(1,2,3)==16)

local t = os.clock()
local d = b/c
print((os.clock() - t), "div")
assert(d:get(1,2,3)==1)


local b = buffer:new(128,128,128)

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
print((os.clock() - t), "array assignment")


local t = os.clock()
for i = 1, 100 do
	for x=0,127 do
		for y=0,127 do
			for z=0,127 do
				local t = x+y+z
				b:set(x,y,z, t)
			end
		end
	end
end
print(os.clock() - t, "setter function")

--]]


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
	
	- indexing:
		- shorthand :get(x,y,z) indexing function, :set(x,y,z,v) assignment function
		- use temporaries for assignment readability
		- optional bounds checking wit :getABC, :setABC
		
		-- indexing using __index and __newindex is prohibitively slow for efficient work with buffers
		- [{ X, Y, Z}] = V
		
		-- also:
		- :set3(x,y,z,c1,c2,c3)
		- :get3(x,y)
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
