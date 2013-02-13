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
-- TODO: mixed precision handling??

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


local buffer = {__type = "buffer"}
buffer.alloc = allocF
buffer.meta={__index = buffer}

function buffer.meta.__tostring(a)
	return "Image buffer ["..a.x..", "..a.y..", "..a.z.."], CS: "..a.cs.."."
end

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

function buffer:get3(x,y)
	local c = x*self.y*self.z + y*self.z
	return self.data[c], self.data[c+1], self.data[c+2] 
end

function buffer:set3(x,y, v1,v2,v3)
	local c = x*self.y*self.z + y*self.z
	self.data[c] = v1
	self.data[c+1] = v2
	self.data[c+2] = v3
end


function buffer:newI(x, y, c1, c2, c3)
	x = x or self.x or 1
	y = y or self.y or 1
	local o = self:new(x, y, 3)
	if c1 then
		c2 = c2 or c1
		c3 = c3 or c1
		for i = 0, x-1 do
			for j = 0, y-1 do
				o:set3(i,j, c1,c2,c3)
			end
		end
	end
	return o
end

function buffer:newM(x, y, v1)
	x = x or self.x or 1
	y = y or self.y or 1
	local o = self:new(x, y, 1)
	if v1 then
		for i = 0, x-1 do
			for j = 0, y-1 do
				o:set(i,j,0, v1)
			end
		end
	end
	return o
end
function buffer:getM(x,y) return self.data[x*self.y*self.z + y*self.z] end
function buffer:setM(x,y, v) self.data[x*self.y*self.z + y*self.z] = v end

function buffer:newC(c1, c2, c3)
	local o = self:new(1, 1, 3)
	if c1 then
		c2 = c2 or c1
		c3 = c3 or c1
		o:set3(0,0, c1,c2,c3)
	end
	return o
end
function buffer:getC(i) return self.data[i-1] end
function buffer:setC(i, v) self.data[i-1] = v end
function buffer:getC3() return self.data[0], self.data[1], self.data[2] end
function buffer:setC3(c1, c2, c3)
	self.data[0] = c1
	self.data[1] = c2
	self.data[2] = c3
end

function buffer:newV(v1)
	local o = self:new(1, 1, 1)
	if v1 then o:set(0,0,0, v1) end
	return o
end
function buffer:getV() return self.data[0] end
function buffer:setV(v) self.data[0] = v end

function buffer:newA(a)
	local l = #a
	local o = self:new(l, 1, 1)
	for i = 0, l-1 do
		o:set(i,0,0, a[i+1])
	end
	return o
end
function buffer:getA(i) return self.data[i] end
function buffer:setA(i, v) self.data[i] = v end

function buffer:new(x, y, z)
	x = x or self.x or 1
	y = y or self.y or 1
	z = z or self.z or 1	
	local size = x*y*z
	
	local o = {
		data = self.alloc(size),
		cs = "MAP",
		x = x, y = y, z = z,	-- derive buffer type from coordinates
		xoff = 0, yoff = 0,		-- sub-regions for partial processing
		xlen = x, ylen = y,
	}
	setmetatable(o, buffer.meta)	
	return o
end

function buffer:copy(t)
	if t then
		if self.x==t.x and self.y==t.y and self.z==t.z then
			ffi.copy(self.data, t.data, self.x*self.y*self.z*4)
		else
			print(debug.traceback("WARNING: Buffer size mismatch! Target: ["..self.x..", "..self.y..", "..self.z.."], source: ["..t.x..", "..t.y..", "..t.z.."]."))
		end
	else
		local o = self:new()	
		ffi.copy(o.data, self.data, self.x*self.y*self.z*4) -- switch to 8 for double		
		return o
	end
end

local function mean(c1, c2, c3) return (c1+c2+c3)/3 end
function buffer:copyG() -- only from image data!
	if self.z==3 then
		local o = self:new(self.x, self.y, 1)	
		for i = 0, self.x-1 do
			for j = 0, self.y-1 do
				o:setM(i,j, mean(self:get3(i, j)))
			end
		end
		return o
	elseif self.z==1 then
		return self:copy()
	else
		local o = self:new(self.x, self.y, 1)
		for i = 0, self.x-1 do
			for j = 0, self.y-1 do
				local s = 0
				for k = 0, self.z-1 do
					s = s + self:get(i, j, k)
				end
				o:setM(i,j, s/self.z)
			end
		end
		return o
	end
end

function buffer:copyC()
	if self.z==1 then
		local o = self:new(self.x, self.y, 3)
		for i = 0, self.x-1 do
			for j = 0, self.y-1 do
				local m = self:getM(i, j)
				o:set3(i,j, m,m,m)
			end
		end 
		return o
	elseif self.z==3 then
		return self:copy()
	else
		print(debug.traceback("WARNING: Non-standard Z dimension of "..self.z..", converting through grayscale"))
		return self:copyG():copyC()
	end
end

function buffer:clean()
	ffi.C.realloc(self.data, 1)
	self.x=1
	self.y=1
	self.z=1
end


---[[
local b = buffer:newI(6000,4000,5)
b:set(1,3,2, 4)

-- FIXME: weird delay if jit is not flushed!!
jit.flush()
local t = os.clock()
local c = b:copy()
print((os.clock() - t), "copy")

jit.flush()
local t = os.clock()
local d = b+c
print((os.clock() - t), "add")
assert(d:get(1,3,2)==8)

jit.flush()
local t = os.clock()
local d = b-c
print((os.clock() - t), "sub")
assert(d:get(1,3,2)==0)

jit.flush()
local t = os.clock()
local d = b*c
print((os.clock() - t), "mul")
assert(d:get(1,3,2)==16)

jit.flush()
local t = os.clock()
local d = b/c
print((os.clock() - t), "div")
assert(d:get(1,3,2)==1)

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


-- TODO buffer methods:
--[==[
	- coercion:
		- :convert(source, "target") (with realloc, correctly interlaced RGB)
		- I>M, M>I
		- C>V, V>C
		- C>I, V>M
	- data:
		- .precision	("single" or "double")	
	
	- indexing:
		- shorthand :get(x,y,z) indexing function, :set(x,y,z,v) assignment function
		- use temporaries for assignment readability
		- optional bounds checking wit :getABC, :setABC
		
	- methods
		- toScreen	-- put to screen (portion?)
		- toScreenQ	-- put to screen scaled down
		- saveHD	-- direct save buffer
		- loadHD	-- direct read buffer
		- save		-- from image file, generic interface for ppmtools
		- load		-- to image file, generic interface for ppmtools
			
		- pixelOp
		- pixelOp!
		- csConv
		- csConv!
		
		- other ops:
			- inv (-)		??
			- concat (..) 	??
			- compare		(create map)
			- threshold (%)
			- pow (^)
			- call ()		??
			
		- other useful methods
--]==]

-- alloc/collect tests
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
