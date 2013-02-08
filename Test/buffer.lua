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
]]


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
		- array bounds checking optional
	
	- indexing:
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
--]==]


-- tests alloc/collect tests
local p
local size = 1024*1024*1024
local n = 100000

local t = os.clock()
for i = 1, n do
	p = ffi.cast("double*", ffi.gc(ffi.C.calloc(size, 1), ffi.C.free))
	ffi.C.realloc(p, 1)
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

--local buffer = {}

--function buffer:new()

