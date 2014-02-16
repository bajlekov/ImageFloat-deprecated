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

-- this library provides tools for storing and accessing structured data
-- it is intended to replace the imgtools library


math.randomseed(os.time())
local ffi = require("ffi")
require("global")

local sdl = require("Include.sdl")
local unroll = require("Tools.unroll")

-- memory allocation handling
local prec = {"float",4} 
print("Using "..(prec[2]*8).."bit precision buffers...")
ffi.cdef[[
	void * malloc ( size_t size );
	void * calloc ( size_t num, size_t size );
	void * realloc ( void * ptr, size_t size );
	void free ( void * ptr );
	typedef float float_a __attribute__ ((aligned (16)));
	typedef double double_a __attribute__ ((aligned (16)));
]] -- allocate aligned memory for use with SSE
local allocCount = 0
local allocTable = {}
setmetatable(allocTable, {__mode="k"})
local function free(p)
	allocCount = allocCount - 1
	allocTable[p] = nil
	ffi.C.free(ffi.gc(p, nil))
end
local function allocF(size)
	allocCount = allocCount + 1
	local t = ffi.cast("float_a*", ffi.C.calloc(size, 4))
	allocTable[t] = size * 4
	return ffi.gc(t, free)
end
local function allocD(size)
	allocCount = allocCount + 1
	local t = ffi.cast("double_a*", ffi.C.calloc(size, 8))
	allocTable[t] = size * 8
	return ffi.gc(t, free)
end
local function getAllocCount() return allocCount end
local function getAllocSize()
	local sum = 0
	for _, v in pairs(allocTable) do sum = sum + v end
	return sum/1024/1024
end

local data = {__type="data"}
data.alloc = prec[2]==4 and allocF or allocD
data.meta = {__index = data}

data.meta.__tostring = function(a)
	return "Image buffer ["..a.x..", "..a.y..", "..a.z.."], CS: "..a.color.cs.."."
end

function data:new(x, y, z)
	x = x or self.x or 1
	y = y or self.y or 1
	z = z or self.z or 1
	local size = x*y*z
	
	local o = {
		data = self.alloc(size),
		color = self.cs or {cs = "MAP",
							gamma = nil,
							wp = nil,
							xyz = nil,
							},
		x = x, y = y, z = z,
		layout = {pack = "AoS", order = "XY", slice = nil}
	}
	setmetatable(o, self.meta)
	return o
end

local function ABC(d, x, y, z)
	if d.x==1 then x=0 end -- cast
	if d.y==1 then y=0 end -- cast
	if d.z==1 then z=0 end -- cast
	if x>=d.x or x<0 then error("x out of bounds")
	elseif y>=d.y or y<0 then error("y out of bounds")
	elseif z>=d.z or z<0 then error("z out of bounds")
	else return x, y, z end
end

local function AC(d, n)
	if n>=d.x*d.y*d.z or n<0 then error("element out of bounds: "..n..">"..(d.x*d.y*d.z-1))
	else return n end
end

local hybridSize = 1024

local function toSoA(data)
	if data.layout.pack=="SoA" or data.z==1 then
		return data
	elseif data.layout.pack=="AoS" then
		local size = data.x*data.y
		local sz = data.z
		local t = data.alloc(size*sz)
		local d = data.data
		local function fun (z, i)
			t[i+z*size] = d[i*sz+z] 
		end
		for i = 0, size-1 do
			unroll[sz](fun, i)
		end
		free(data.data)
		data.data = t
		data.layout.pack = "SoA"
		return data
	elseif data.layout.pack=="Hybrid" then
		local size = data.x*data.y
		local sz = data.z
		local t = data.alloc(size*sz)
		local d = data.data
		local rem = size%hybridSize
		
		local function fun (z, i, j)
			t[(i+j)+z*size] = d[j*sz+i+z*hybridSize]
		end
		local function funrem (z, i, j)
			t[(i+j)+z*size] = d[j*sz+i+z*rem]
		end
		
		for j = 0, size-hybridSize, hybridSize do
			for i = 0, hybridSize-1 do
				unroll[sz](fun, i, j)
			end
		end
		for i = 0, rem-1 do
			unroll[sz](funrem, i, size-rem)
		end
		
		free(data.data)
		data.data = t
		data.layout.pack = "SoA"
		return data
	else
		error("Unrecognised layout!")
	end
end

local function toAoS(data)
	if data.layout.pack=="AoS" or data.z==1 then
		return data
	elseif data.layout.pack=="SoA" then
		local size = data.x*data.y
		local sz = data.z
		local t = data.alloc(size*sz)
		local d = data.data
		local function fun (z, i)
			t[i*sz+z] = d[i+z*size] 
		end
		for i = 0, size-1 do
			unroll[sz](fun, i)
		end
		free(data.data)
		data.data = t
		data.layout.pack = "AoS"
		return data
	elseif data.layout.pack=="Hybrid" then
		local size = data.x*data.y
		local sz = data.z
		local t = data.alloc(size*sz)
		local d = data.data
		local rem = size%hybridSize
		
		local function fun (z, i, j)
			t[(i+j)*sz+z] = d[j*sz+i+z*hybridSize]
		end
		local function funrem (z, i, j)
			t[(i+j)*sz+z] = d[j*sz+i+z*rem]
		end
		
		for j = 0, size-hybridSize, hybridSize do
			for i = 0, hybridSize-1 do
				unroll[sz](fun, i, j)
			end
		end
		for i = 0, rem-1 do
			unroll[sz](funrem, i, size-rem)
		end
		
		free(data.data)
		data.data = t
		data.layout.pack = "AoS"
		return data
	else
		error("Unrecognised layout!")
	end
end

local function toHybrid(data)
	if data.layout.pack=="Hybrid" or data.z==1 then
		return data
	elseif data.layout.pack=="AoS" then
		local size = data.x*data.y
		local sz = data.z
		local t = data.alloc(size*sz)
		local d = data.data
		local rem = size%hybridSize
		
		local function fun (z, i, j)
			t[j*sz+i+z*hybridSize] = d[(j+i)*sz+z]
		end
		local function funrem (z, i, j)
			t[j*sz+i+z*rem] = d[(j+i)*sz+z]
		end
		
		for j = 0, size-hybridSize, hybridSize do
			for i = 0, hybridSize-1 do
				unroll[sz](fun, i, j)
			end
		end
		for i = 0, rem-1 do
			unroll[sz](funrem, i, size-rem)
		end
		
		free(data.data)
		data.data = t
		data.layout.pack = "Hybrid"
		return data
	elseif data.layout.pack=="SoA" then
		local size = data.x*data.y
		local sz = data.z
		local t = data.alloc(size*sz)
		local d = data.data
		local rem = size%hybridSize
		
		local function fun (z, i, j)
			t[j*sz+i+z*hybridSize] = d[(i+j)+z*size] 
		end
		local function funrem (z, i, j)
			t[j*sz+i+z*rem] = d[(i+j)+z*size]
		end
		
		for j = 0, size-hybridSize, hybridSize do
			for i = 0, hybridSize-1 do
				unroll[sz](fun, i, j)
			end
		end
		for i = 0, rem-1 do
			unroll[sz](funrem, i, size-rem)
		end
		
		free(data.data)
		data.data = t
		data.layout.pack = "Hybrid"
		return data
	else
		error("Unrecognised layout!")
	end
end

local function pos(d, x, y, z)
	if d.layout.pack=="AoS" then
		return (x*d.y*d.z+y*d.z+z)
	elseif d.layout.pack=="SoA" then
		return (z*d.x*d.y+x*d.y+y)
	elseif d.layout.pack=="Hybrid" then
		local n = (x+1)*(y+1)-1
		local m = hybridSize
		local size = d.x*d.y
		local sz = d.z
		local thr = size-size%m
		local t = n<thr
		local rem = t and n%m or n-thr
		local off = t and n-rem or thr
		local m = t and m or size-thr
		return (off*sz+z*m+rem)
	else
		error("Unrecognised layout!")
	end
end

local function get(d, x, y, z)
	return d.data[pos(d, x, y, z)]
end
local function set(d, x, y, z, v)
	d.data[pos(d, x, y, z)] = v
end
local function getABC(d, x, y, z)
	return d.data[pos(d, ABC(d, x, y, z))]
end
local function setABC(d, x, y, z, v)
	d.data[pos(d, ABC(d, x, y, z))] = v
end

-- test

local d = data:new(6000,4000,3)

-- warmup
toHybrid(d)
toSoA(d)
toAoS(d)

toHybrid(d)
sdl.tic()
for i = 0, d.x-1 do
	for j = 0, d.y-1 do
		set(d, i, j, 0, i+1000)
		set(d, i, j, 1, i+2000)
	end
end
sdl.toc("assign")

toAoS(d)
sdl.tic()
toHybrid(d)
sdl.toc("aos->hybrid")
sdl.tic()
toSoA(d)
sdl.toc("hybrid->soa")
sdl.tic()
toAoS(d)
sdl.toc("soa->aos")
sdl.tic()
toSoA(d)
sdl.toc("aos->soa")
sdl.tic()
toHybrid(d)
sdl.toc("soa->hybrid")
sdl.tic()
toAoS(d)
sdl.toc("hybrid->aos")

sdl.tic()
for i = 0, d.x-1 do
	for j = 0, d.y-1 do
		local a, b = get(d, i, j, 0), get(d, i, j, 1)
		--print(a,b)
	end
end
sdl.toc("index")

print(d.layout.pack)
