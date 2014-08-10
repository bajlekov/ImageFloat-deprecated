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

jit.opt.start("sizemcode=512")

--require("jit.v").start("verbose.txt")
require("jit.dump").start("tT", "dump.txt")
--require("jit.p").start("vfi1m10", "profile.txt")

math.randomseed(os.time())
local ffi = require("ffi")
require("global")

local sdl = require("Include.sdl2")
local unroll = require("Tools.unroll")
local alloc = require("Test.Data.alloc")

local prec = {"float",4} --TODO: get desired bit depth
print("Using "..(prec[2]*8).."bit precision buffers...")
local dataAlloc = prec[2]==4 and alloc.float32 or alloc.float64

local data = {__type="data"}
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
		data = dataAlloc(size),
		x = x, y = y, z = z,
		
		layout = {pack = "AoS", order = "XY", slice = nil}
	}
	setmetatable(o, self.meta)
	return o
end

local function ABC(d, x, y, z)
	if x>=d.x or x<0 then error("x out of bounds")
	elseif y>=d.y or y<0 then error("y out of bounds")
	elseif z>=d.z or z<0 then error("z out of bounds")
	else return x, y, z end
end

local function AC(d, n)
	if n>=d.x*d.y*d.z or n<0 then error("element out of bounds: "..n..">"..(d.x*d.y*d.z-1))
	else return n end
end

local hybridSize = 128
-- TODO: unroll loops over hybrid chunks for small sizes!

local function toSoA(data)
	jit.flush(true)
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
	jit.flush(true)
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
	jit.flush(true)
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
	if d.x==1 then x=0 end -- broadcast
	if d.y==1 then y=0 end -- broadcast
	if d.z==1 then z=0 end -- broadcast
	
	local xx, yy, zz = d.x, d.y, d.z
	
	if d.layout.order=="YX" then
		x, y = y, x
		xx, yy = yy, xx
	elseif d.layout.order~="XY" then
		error("Unrecognised layout!")
	end
	
	if d.layout.pack=="AoS" then
		return (x*yy*zz+y*zz+z)
	elseif d.layout.pack=="SoA" then
		return (z*xx*yy+x*yy+y)
	elseif d.layout.pack=="Hybrid" then
		local size = xx*yy
		local m = hybridSize
		local thr = size-size%m
		local n = x*yy+y
		local t = n<thr
		local rem = t and n%m or n-thr
		local off = t and n-rem or thr
		local m = t and m or size-thr
		return (off*zz+z*m+rem)
	else
		error("Unrecognised layout!")
	end
end

-- hybrid layout only useful when whole chunks are processed at once

-- every getter/setter should be implemented in terms of the get/set functions!
local function __get(d, x, y, z)
	return d.data[pos(d, x, y, z)]
end
local function __set(d, x, y, z, v)
	d.data[pos(d, x, y, z)] = v
end


local get, set, setWorkingCS, getWorkingCS
do
	local workingCS = "MAP"
	function setWorkingCS(s)
		assert(type(s)=="string")
		workingCS = s
	end
	function getWorkingCS()
		return workingCS
	end
	
	function get(d, x, y, z)
		if d.color.cs==workingCS then
			return d.data[pos(d, x, y, z)]
		else
			error("Wrong CS!")
		end
	end
	function set(d, x, y, z, v)
		if d.color.cs==workingCS then
			d.data[pos(d, x, y, z)] = v
		else
			error("Wrong CS!")
		end
	end
end
-- introduce switchable XY / YX loops based on layout

local function getABC(d, x, y, z)
	get(d, ABC(d, x, y, z))
end
local function setABC(d, x, y, z, v)
	set(d, ABC(d, x, y, z), v)
end

local function get3(d, x, y)
	if d.z==3 then
		-- implicit color space switch!
		return get(d, x, y, 0), get(d, x, y, 1), get(d, x, y, 2)
	elseif d.z==1 then -- broadcast
		local t = get(d, x, y, 0)
		return t, t, t
	else
		error("wrong z-size")
	end
end
local function set3(d, x, y, a, b, c)
	b = b or a
	c = c or a
	if d.z==3 then
		-- implicit color space switch!
		set(d, x, y, 0, a)
		set(d, x, y, 1, b)
		set(d, x, y, 2, c)
	elseif d.z==1 then -- compress
		set(d, x, y, 0, (a+b+c)/3)
	else
		error("wrong z-size")
	end
end

local function toXY(d)
	if d.layout.order=="XY" then
		return d
	elseif d.layout.order=="YX" then
		local t = d:new()
		t.layout.order = "XY"
		t.layout.pack = d.layout.pack
		local function fun(z, x, y)
			__set(t, x, y, z, __get(d, x, y, z))
		end
		for x = 0, d.x-1 do
			for y = 0, d.y-1 do
				unroll[d.z](fun, x, y)
			end
		end
		free(d.data)
		d.data = t.data
		d.layout.order = t.layout.order
		return d
	else
		error("Unrecognised layout!")
	end
end

local function toYX(d)
	if d.layout.order=="YX" then
		return d
	elseif d.layout.order=="XY" then
		local t = d:new()
		t.layout.order = "YX"
		t.layout.pack = d.layout.pack
		local function fun(z, x, y)
			__set(t, x, y, z, __get(d, x, y, z))
		end
		for y = 0, d.y-1 do
			for x = 0, d.x-1 do
				unroll[d.z](fun, x, y)
			end
		end
		free(d.data)
		d.data = t.data
		d.layout.order = t.layout.order
		return d
	else
		error("Unrecognised layout!")
	end
end

-- test

local d = data:new(6000,4000,3)

-- warmup
toHybrid(d)
toSoA(d)
toAoS(d)

toSoA(d)
sdl.tic()
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local t = x*10+y
		set3(d, x, y, t+100, t+200, t+300)
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
toYX(d)
sdl.toc("Flip")
sdl.tic()
toXY(d)
sdl.toc("Flop")

toSoA(d)
sdl.tic()
--print("====================")
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local a, b, c = get(d, x, y, 0), get(d, x, y, 1), get(d, x, y, 2) 
		--print(a,b,c)
	end
	--print("====================")
end
sdl.toc("index")

---[[
toSoA(d)
sdl.tic()
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local a, b, c = get3(d, x, y)
		set3(d, x, y, a+b+c)
	end
end
sdl.toc("add")
--]]

print(d.layout.pack)
