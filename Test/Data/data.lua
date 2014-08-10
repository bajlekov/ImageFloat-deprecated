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
--require("jit.dump").start("tT", "dump.txt")
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
	return "Image buffer ["..a.x..", "..a.y..", "..a.z.."], CS: "..a.cs().."."
end

-- having layout as object properties is dangerous, but using hidden upvalues incurs a significant overhead
function data:new(x, y, z)
	x = x or self.x or 1
	y = y or self.y or 1
	z = z or self.z or 1
	local size = x*y*z
	
	local o = {
		data = dataAlloc(size),
		x = x, y = y, z = z,
		cs = self.cs or "MAP",
		pack = self.pack or "AoS",
		order = self.order or "XY",
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

-- dedicated position functions
local pos = {}
pos.AoS = {}
pos.SoA = {}
local function broadcast(d, x, y, z)
	x = d.x==1 and 0 or x -- broadcast
	y = d.y==1 and 0 or y -- broadcast
	z = d.z==1 and 0 or z -- broadcast
	return d, x, y, z
end
function pos.AoS.XY(d, x, y, z) return (x*d.y*d.z+y*d.z+z) end
function pos.AoS.YX(d, y, x, z) return (x*d.x*d.z+y*d.z+z) end
function pos.SoA.XY(d, x, y, z) return (z*d.x*d.y+x*d.y+y) end
function pos.SoA.YX(d, y, x, z) return (z*d.y*d.x+x*d.x+y) end
data.pos = pos.AoS.XY -- standard layout

-- every getter/setter should be implemented in terms of the get/set functions!
local function __get(d, x, y, z)
	return d.data[d:pos(x, y, z)]
end
local function __set(d, x, y, z, v)
	d.data[d:pos(x, y, z)] = v
end
local function __getABC(d, x, y, z)
	return d.data[d:pos(ABC(d, x, y, z))]
end
local function __setABC(d, x, y, z, v)
	d.data[d:pos(ABC(d, x, y, z))] = v
end
-- overridable getters and setters
data.__get = __get
data.__set = __set

local workingCS
do
	local CS = "MAP"
	function workingCS(s)
		assert(type(s)=="string")
		workingCS = s
		return workingCS
	end
	
	function data.get(d, x, y, z)
		if d.cs==CS or D.CS=="MAP" then
			return d:__get(x, y, z)
		else
			error("Wrong CS!")
		end
	end
	function data.set(d, x, y, z, v)
		if d.cs==CS or d.cs=="MAP" then
			d:__set(x, y, z, v)
		else
			error("Wrong CS!")
		end
	end
	function data.get3(d, x, y)
		if d.z==3 then
			-- implicit color space switch!
			return d:get(x, y, 0), d:get(x, y, 1), d:get(x, y, 2)
		elseif d.z==1 then -- broadcast
			local t = d:get(x, y, 0)
			return t, t, t
		else
			error("wrong z-size")
		end
	end
	function data.set3(d, x, y, a, b, c)
		b = b or a
		c = c or a
		if d.z==3 then
			-- implicit color space switch!
			d:set(x, y, 0, a)
			d:set(x, y, 1, b)
			d:set(x, y, 2, c)
		elseif d.z==1 then -- compress (TODO: overridable!)
			d:set(x, y, 0, (a+b+c)/3)
		else
			error("wrong z-size")
		end
	end
end
-- introduce switchable XY / YX loops based on layout


function data.layout(d, pack, order, cs) -- add any parameters that might change frequently
	-- set to default if not supplied
	pack = pack or d.pack
	order = order or d.order
	cs = cs or d.cs
	
	if d.pack==pack and d.order==order and d.cs==cs then
		return d
	else
		jit.flush(true)
		local t = d:new()
		t.cs = cs 
		t.pack = pack
		t.order = order
		t.pos = pos[pack][order]
		
		-- definition of inner function is faster
		local function fun(z, x, y)
			t:__set(x, y, z, d:__get(x, y, z))
		end
		if t.order=="YX" then
			for y = 0, d.y-1 do
				for x = 0, d.x-1 do
					unroll.fixed(d.z, 2)(fun, x, y)
				end
			end
		else
			for x = 0, d.x-1 do
				for y = 0, d.y-1 do
					unroll.fixed(d.z, 2)(fun, x, y)
				end
			end
		end
		alloc.free(d.data)
		d.data = t.data
		
		d.cs = cs
		d.pack = pack
		d.order = order
		d.pos = pos[pack][order]
		return d
	end
end

local function toAoS(d) return d:layout("AoS") end
local function toSoA(d) return d:layout("SoA") end
local function toXY(d) return d:layout(nil, "XY") end
local function toYX(d) return d:layout(nil, "YX") end



----------
-- TEST --
----------

local d = data:new(6000,4000,3)
local f = data:new(6000,4000,3)

-- warmup
toSoA(d)
toAoS(d)
toYX(f)
toXY(f)

toSoA(d)
sdl.tic()
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local t = x*10+y
		f:set3(x, y, t+100, t+200, t+300)
	end
end
sdl.toc("SoA assign")

toAoS(d)
sdl.tic()
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local t = x*10+y
		f:set3(x, y, t+100, t+200, t+300)
	end
end
sdl.toc("AoS assign")

sdl.tic()
toSoA(d)
sdl.toc("aos->soa")
sdl.tic()
toAoS(d)
sdl.toc("soa->aos")
sdl.tic()
toSoA(d)
sdl.toc("aos->soa")
sdl.tic()
toAoS(d)
sdl.toc("soa->aos")

sdl.tic()
toYX(d)
sdl.toc("Flip")
sdl.tic()
toXY(d)
sdl.toc("Flop")
sdl.tic()
toYX(d)
sdl.toc("Flip")
sdl.tic()
toXY(d)
sdl.toc("Flop")

sdl.tic()
d:layout("SoA", "YX")
sdl.toc("Combined")
sdl.tic()
d:layout("AoS", "XY")
sdl.toc("Combined")

toSoA(d)
toSoA(f)
sdl.tic()
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local a, b, c = f:get3(x, y)
		f:set3(x, y, a+b+c)
	end
end
sdl.toc("add XY "..d.pack)

toAoS(d)
toAoS(f)
sdl.tic()
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local a, b, c = f:get3(x, y)
		f:set3(x, y, a+b+c)
	end
end
sdl.toc("add XY "..d.pack)

toYX(d)
toYX(f)

toSoA(d)
toSoA(f)
sdl.tic()
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local a, b, c = f:get3(x, y)
		f:set3(x, y, a+b+c)
	end
end
sdl.toc("add YX "..d.pack)

toAoS(d)
toAoS(f)
sdl.tic()
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		local a, b, c = f:get3(x, y)
		f:set3(x, y, a+b+c)
	end
end
sdl.toc("add YX "..d.pack)

collectgarbage("setpause", 100)
print(alloc.count(), collectgarbage("count"))
sdl.tic()
local b=0
for i = 1, 100000 do
	local a = d:new(6000,4000,3)
	a:set(1,1,1,1)
	b = b + a:get(1,1,1)
end
sdl.toc("constructor "..b)
print(alloc.count(), collectgarbage("count"))
collectgarbage("collect")
print(alloc.count(), collectgarbage("count"))