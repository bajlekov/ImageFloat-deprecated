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
	ffi.C.free(p)
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

local hybridSize = 128

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
		local t = data.alloc(size*sz) -- errs for hybridSize=34, size=small
		local d = data.data
		local function fun (z, i, j)
			t[(i+j)+z*size] = d[j*sz+i+z*hybridSize]
		end
		for j = 0, size-1, hybridSize do
			local max = hybridSize<size-j and hybridSize or size-j
			for i = 0, hybridSize-1 do
				unroll[sz](fun, i, j)
			end
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
		local function fun (z, i, j)
			t[(i+j)*sz+z] = d[j*sz+i+z*hybridSize]
		end
		for j = 0, size-1, hybridSize do
			local max = hybridSize<size-j and hybridSize or size-j
			for i = 0, max-1 do
				unroll[sz](fun, i, j)
			end
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
		local function fun (z, i, j)
			t[j*sz+i+z*hybridSize] = d[(j+i)*sz+z]
		end
		for j = 0, size-1, hybridSize do
			local max = hybridSize<size-j and hybridSize or size-j
			for i = 0, max-1 do
				unroll[sz](fun, i, j)
			end
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
		local function fun (z, i, j)
			t[j*sz+i+z*hybridSize] = d[(i+j)+z*size] 
		end
		for j = 0, size-1, hybridSize do
			local max = hybridSize<size-j and hybridSize or size-j
			for i = 0, max-1 do
				unroll[sz](fun, i, j)
			end
		end
		free(data.data)
		data.data = t
		data.layout.pack = "Hybrid"
		return data
	else
		error("Unrecognised layout!")
	end
end

local d = data:new(6000,8000,12)


for i = 0, 63 do
	d.data[i] = i
end


toHybrid(d)
toSoA(d)
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

for i = 0, 63 do
	--print(d.data[i])
end

print(d.layout.pack)
