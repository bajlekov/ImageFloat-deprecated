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

-- setup
math.randomseed(os.time())
local ffi = require("ffi")
require("global")

local unroll = require("Tools.unroll")
local alloc = require("Test.Data.alloc")

local prec = __global.setup.bufferPrecision[2]*8
print("Using "..prec.."bit precision buffers...")
local dataAlloc = prec==32 and alloc.float32 or alloc.float64

local data = {__type="data"}
data.meta = {__index = data}

local function printBuffer(a)
	return "Image["..a.x..", "..a.y..", "..a.z.."] ("..a.cs..", "..a.order..", "..prec.."bit)"
end
data.meta.__tostring = printBuffer
data.order = "XYZ"
data.cs = "MAP"

function data:new(x, y, z)				-- new image data
	x = x or self.x or 1				-- default dimensions or inherit
	y = y or self.y or 1
	z = z or self.z or 1

	local o = {
		data = dataAlloc(x*y*z),		-- allocate data
		x = x, y = y, z = z,			-- set dimensions
		sx = y*z, sy = z, sz = 1, -- set strides
		cs = self.cs,			-- default CS or inherit
		order = self.order,		-- default order or inherit
	}
	setmetatable(o, self.meta) -- inherit data methods
	o:setStride()
	return o
end

do
	ffi.cdef[[
		typedef struct{
			void *data;			// buffer data
			int size;				// 32/64bit
			int dim[3];			// dimensions
			int stride[3];	// strides
			int order[3];		// order (1 = x, 2 = y, 3 = z)
			int cs;					// color space (0 = "MAP")
		} imageDataStruct;
	]]
	local ids = ffi.typeof("imageDataStruct")
	
	function data:toStruct()
		return ids(self.data, prec, {self.x, self.y, self.z}, {self.sx, self.sy, self.sz}, { self:getOrder() }, 0)
	end
	
	local order = {"X", "Y", "Z"}
	local function orderString(v)
		order[v[0]] = "X"
		order[v[1]] = "Y"
		order[v[2]] = "Z"
		return order[1]..order[2]..order[3]
	end
	
	local dataCS = {[0]="MAP"}
	local dataType = prec==32 and "float_a*" or "double_a*"
	function data.fromStruct(str)
		local o = {
			data = ffi.cast(dataType, str.data),
			x = str.dim[0],
			y = str.dim[1],
			z = str.dim[2],			-- set dimensions
			sx = str.stride[0],
			sy = str.stride[1],
			sz = str.stride[2], -- set strides
			order = orderString(str.order),		-- default order or inherit
			cs = dataCS[str.cs],			-- default CS or inherit
		}
		setmetatable(o, data.meta) -- inherit data methods
		return o
	end
end

function data:pos(x, y, z) return (x*self.sx+y*self.sy+z*self.sz) end

do
	local order = {x = 0, y = 0, z = 0}
	function data:getOrder()
		local layout = self.order
		local a = layout:sub(1,1):lower()
		local b = layout:sub(2,2):lower()
		local c = layout:sub(3,3):lower()
		order[a]=1
		order[b]=2
		order[c]=3
		return order.x, order.y, order.z
	end
end

do
	local stride = {x = 0, y = 0, z = 0}
	function data:getStride()
		local layout = self.order
		local a = layout:sub(1,1):lower()
		local b = layout:sub(2,2):lower()
		local c = layout:sub(3,3):lower()
		stride[a]=self[b]*self[c]
		stride[b]=self[c]
		stride[c]=1
		return stride.x, stride.y, stride.z
	end
end

function data:setStride()
	self.sx, self.sy, self.sz = self:getStride()
end

local function ABC(d, x, y, z) -- array bounds checking
	assert(x<d.x, "x out of bounds")
	assert(x>=0, "x out of bounds")
	assert(y<d.y, "y out of bounds")
	assert(y>=0, "y out of bounds")
	assert(z<d.z, "z out of bounds")
	assert(z>=0, "z out of bounds")
	return d, x, y, z
end

local function AC(d, n)
	assert(n<d.x*d.y*d.z, "index out of bounds")
	assert(n>=0, "index out of bounds")
	return n
end

local function broadcast(d, x, y, z) -- helper function
	x = d.x==1 and 0 or x
	y = d.y==1 and 0 or y
	z = d.z==1 and 0 or z
	return d, x, y, z
end

local function offset(d, x, y, z)
	return d,
		x+d.offset.x,
		y+d.offset.y,
		z+d.offset.z
end

-- every getter/setter should be implemented in terms of the data.__get/__set functions!
do
	local function __get(d, x, y, z)
		return d.data[d.pos(broadcast(d, x, y, z))]
	end
	local function __set(d, x, y, z, v)
		d.data[d.pos(d, x, y, z)] = v
	end
	local function __getABC(d, x, y, z)
		return d.data[d.pos(ABC(broadcast(d, x, y, z)))]
	end
	local function __setABC(d, x, y, z, v)
		d.data[d.pos(ABC(d, x, y, z))] = v
	end

	-- TODO: fix great delays in in-bounds getters/setters for mixed cases
	local function __getPad(d, x, y, z)
		local _
		_, x, y, z = broadcast(d, x, y, z)
		if x<d.x and x>=0 and y<d.y and y>=0 then
			return d.data[d.pos(broadcast(d, x, y, z))]
		else
			return 0
		end
	end
	local function __setPad(d, x, y, z, v)
		local _
		_, x, y, z = broadcast(d, x, y, z)
		if x<d.x and x>=0 and y<d.y and y>=0 then
			d.data[d.pos(d, x, y, z)] = v
		end
	end
	local function __getExtend(d, x, y, z)
		local _
		_, x, y, z = broadcast(d, x, y, z)
		x = (x<0 and 0) or (x>=d.x and d.x-1) or x
		y = (y<0 and 0) or (y>=d.y and d.y-1) or y
		return d.data[d.pos(broadcast(d, x, y, z))]
	end
	local __setExtend = __setPad
	local function __getMirror(d, x, y, z)
		local _
		_, x, y, z = broadcast(d, x, y, z)
		-- FIXME: indexing is incorrect
		x = (x<0 and -x) or (x>=d.x and 2*d.x - x - 1) or x
		y = (y<0 and -y) or (y>=d.y and 2*d.y - y - 1) or y
		return d.data[d.pos(broadcast(d, x, y, z))]
	end
	local __setMirror = __setPad


	-- overridable getters and setters, possibly implementing ABC
	data.__get = __get
	data.__set = __set
end


local workingCS
do
	-- TODO: flush cache when changing working CS??
	local CS = "MAP"
	function workingCS(s)
		assert(type(s)=="string")
		workingCS = s
		return workingCS
	end

	function data.get(d, x, y, z)
		z = z or 0 -- use first channel if not specified
		assert(d.cs==CS, "CS mismatch")
		return d:__get(x, y, z)
	end
	function data.set(d, x, y, z, v)
		assert(z)
		assert(v)
		assert(d.cs==CS, "CS mismatch")
		d:__set(x, y, z, v)
	end
	function data.get3(d, x, y)
		-- TODO: implicit color space switch!
		assert(d.cs==CS, "CS mismatch")
		return d:get(x, y, 0), d:get(x, y, 1), d:get(x, y, 2)
	end
	function data.set3(d, x, y, a, b, c)
		b = b or a
		c = c or a
		-- TODO: implicit color space switch!
		assert(d.cs==CS, "CS mismatch")
		d:set(x, y, 0, a)
		d:set(x, y, 1, b)
		d:set(x, y, 2, c)
	end
end

-- convenience functions
function data:toXYZ() return self:layout("XYZ") end
function data:toXZY() return self:layout("XZY") end
function data:toYXZ() return self:layout("YXZ") end
function data:toYZX() return self:layout("YZX") end
function data:toZXY() return self:layout("ZXY") end
function data:toZYX() return self:layout("ZYX") end

function data:checkTarget(t) -- check if data can be broadcasted to buffer t
	assert(self.x==t.x or self.x==1, "Incompatible x dimension")
	assert(self.y==t.y or self.y==1, "Incompatible y dimension")
	assert(self.z==t.z or self.z==1, "Incompatible z dimension")
end
function data.checkSuper(...) -- create new buffer to accomodate all argument buffers by broadcasting
	local buffers = {...}
	local x, y, z = 1, 1, 1
	for _, t in ipairs(buffers) do
		assert(t.x==x or t.x==1 or x==1, "Incompatible x dimension")
		assert(t.y==y or t.y==1 or y==1, "Incompatible y dimension")
		assert(t.z==z or t.z==1 or z==1, "Incompatible z dimension")
		if t.x>x then x = t.x end
		if t.y>y then y = t.y end
		if t.z>z then z = t.z end
	end
	return x, y, z
end
function data:newSuper(...) -- create new buffer to accomodate all argument buffers by broadcasting
	return self:new(self.checkSuper(...))
end

local function locked(t, k, v)
	error("Property acces through subarray is limited: "..k)
end
function data:linkedCopy() -- provides a reference to the original data with a different CS -> needed??
	return setmetatable({cs = self.cs}, {__index=self, __newindex=locked, __tostring = printBuffer})	-- inherit data methods
end
function data:sub(xoff, yoff, xmax, ymax)
	xoff = xoff or 0
	yoff = yoff or 0
	xmax = xmax or self.x-xoff
	ymax = ymax or self.y-yoff
	local o = {x = xmax, y = ymax}
	-- TODO: implement proper ABC for subs!!
	function o.__get(_, x, y, z) return self.__get(self, x+xoff, y+yoff, z) end
	function o.__set(_, x, y, z, v) return self.__set(self, x+xoff, y+yoff, z, v) end
	return setmetatable(o, {__index=self, __newindex=locked, __tostring = printBuffer})	-- inherit data methods
end

function data.copy(d, x, y, z, order, cs)
	x = x or d.x
	y = y or d.y
	z = z or d.z
	order = order or d.order
	cs = cs or d.cs
	
	jit.flush(true)
	local t = d:new(x, y, z)
	d:checkTarget(t)
	t.cs = cs 
	t.order = order
	t:setStride()
	
	local function fun(z, x, y)
		t:__set(x, y, z, d:__get(x, y, z))
	end
	
	local a, b, c = t:getOrder() -- find best loop layout for each transformation
	if a<b then
		for x = 0, t.x-1 do
			for y = 0, t.y-1 do
				unroll.fixed(t.z, 2)(fun, x, y)
			end
		end
	else
		for y = 0, t.y-1 do
			for x = 0, t.x-1 do
				unroll.fixed(t.z, 2)(fun, x, y)
			end
		end
	end
	
	return t
end

function data.layout(d, order, cs) -- add any parameters that might change frequently
	order = order or d.order
	cs = cs or d.cs
	if d.order==order and d.cs==cs then
		return d
	else
		local t = d:copy(d.x, d.y, d.z, order, cs)
		alloc.free(d.data)
		d.data = t.data
		d.cs = cs
		d.order = order
		d:setStride()
		return d
	end
end

function data:newI(x, y) return self:new(x, y, 3) end
function data:newM(x, y) return self:new(x, y, 1) end
function data:newC(c1, c2, c3)
	local o = self:new(1, 1, 3)
	if c1 then
		c2 = c2 or c1
		c3 = c3 or c1
		o:set3(0,0, c1,c2,c3)
	end
	return o
end
function data:newV(v1)
	local o = self:new(1, 1, 1)
	if v1 then o:set(0,0,0, v1) end
	return o
end
function data:copyC()
	assert(self.x==1 and self.y==1, "deprecated use, see color")
	return self:copy(1, 1, 3)
end

function data:i(...) return self:get(...) end
function data:a(...) return self:set(...) end
function data:i3(...) return self:get3(...) end
function data:a3(...) return self:set3(...) end

function data:type()
	print("Deprecated buffer property \"type\".")
	local x, y, z = self.x, self.y, self.z
	if		  x==1 and y==1 and z==1 then		return 1
	elseif	x==1 and y==1 and z==3 then		return 2
	elseif	z==1 then						return 3
	elseif	z==3 then						return 4
	else
		print(debug.traceback("WARNING: type is undefined"))
		return 0
	end
end
require("Test.Data.ops")(data)

--require("Test.Data.test")(data)
return data
