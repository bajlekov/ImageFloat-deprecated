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

-- setup
math.randomseed(os.time())
local ffi = require("ffi")
require("global")

local unroll = require("Tools.unroll")
local alloc = require("Test.Data.alloc")

local prec = 32 -- precision of buffers
print("Using "..prec.."bit precision buffers...")
local dataAlloc = prec==32 and alloc.float32 or alloc.float64

local data = {__type="data"}
data.meta = {__index = data}

local function printBuffer(a)
  return "Image["..a.x..", "..a.y..", "..a.z.."] ("..a.cs..", "..a.pack..", "..a.order..", "..prec.."bit)"
end
data.meta.__tostring = printBuffer

local pos = {}

function data:new(x, y, z)				-- new image data
  x = x or self.x or 1				-- default dimensions or inherit
  y = y or self.y or 1
  z = z or self.z or 1

  local o = {
    data = dataAlloc(x*y*z),		-- allocate data
    x = x, y = y, z = z,			-- set dimensions
    cs = self.cs or "MAP",			-- default CS or inherit
    pack = self.pack or "AoS",		-- default packing or inherit
    order = self.order or "XY",		-- default order or inherit
  }
  o.pos = pos[o.pack][o.order]
  return setmetatable(o, self.meta)	-- inherit data methods
end

local function ABC(d, x, y, z) -- array bounds checking
  assert(x<d.x and x>=0, "x out of bounds")
  assert(y<d.y and y>=0, "y out of bounds")
  assert(z<d.z and z>=0, "z out of bounds")
  return d, x, y, z
end

local function AC(d, n)
  assert(n<d.x*d.y*d.z and n>=0, "index out of bounds")
  return n
end

-- dedicated position functions
pos.AoS = {}
pos.SoA = {}
function pos.AoS.XY(d, x, y, z) return (x*d.y*d.z+y*d.z+z) end
function pos.AoS.YX(d, x, y, z) return (y*d.x*d.z+x*d.z+z) end
function pos.SoA.XY(d, x, y, z) return (z*d.x*d.y+x*d.y+y) end
function pos.SoA.YX(d, x, y, z) return (z*d.y*d.x+y*d.x+x) end
data.pos = pos.AoS.XY -- standard layout

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
  data.__get = __getPad
  data.__set = __setPad
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
    assert(d.cs==CS or d.cs=="MAP", "CS mismatch")
    return d:__get(x, y, z)
  end
  function data.set(d, x, y, z, v)
    assert(d.cs==CS or d.cs=="MAP", "CS mismatch")
    d:__set(x, y, z, v)
  end
  function data.get3(d, x, y)
    -- TODO: implicit color space switch!
    return d:get(x, y, 0), d:get(x, y, 1), d:get(x, y, 2)
  end
  function data.set3(d, x, y, a, b, c)
    b = b or a
    c = c or a
    -- TODO: implicit color space switch!
    d:set(x, y, 0, a)
    d:set(x, y, 1, b)
    d:set(x, y, 2, c)
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
    if t.order=="YX" then		-- use loops aligned with the target for better performance
      for y = 0, t.y-1 do
        for x = 0, t.x-1 do
          unroll.fixed(t.z, 2)(fun, x, y)
        end
    end
    else
      for x = 0, t.x-1 do
        for y = 0, t.y-1 do
          unroll.fixed(t.z, 2)(fun, x, y)
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

function data:toAoS() return self:layout("AoS") end
function data:toSoA() return self:layout("SoA") end
function data:toXY() return self:layout(nil, "XY") end
function data:toYX() return self:layout(nil, "YX") end

function data:checkTarget(t) -- check if data can be broadcasted to buffer t
  assert(self.x==t.x or self.x==1, "Incompatible x dimension")
  assert(self.y==t.y or self.y==1, "Incompatible y dimension")
  assert(self.z==t.z or self.z==1, "Incompatible z dimension")
end
function data:checkSuper(...) -- create new buffer to accomodate all argument buffers by broadcasting
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
  return self:new(x, y, z)
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
  --function o.layout(d, pack, order, cs) return self.layout(self, pack, order, cs) end
  return setmetatable(o, {__index=self, __newindex=locked, __tostring = printBuffer})	-- inherit data methods
end
function data.copy(d, x, y, z, pack, order, cs)
  pack = pack or d.pack
  order = order or d.order
  cs = cs or d.cs

  jit.flush(true)
  local t = d:new(x, y, z)
  d:checkTarget(t)
  t.cs = cs 
  t.pack = pack
  t.order = order
  t.pos = pos[pack][order]

  local function fun(z, x, y)
    t:__set(x, y, z, d:__get(x, y, z))
  end
  if t.order=="YX" then		-- use loops aligned with the target for better performance
    for y = 0, t.y-1 do
      for x = 0, t.x-1 do
        unroll.fixed(t.z, 2)(fun, x, y)
      end
  end
  else
    for x = 0, t.x-1 do
      for y = 0, t.y-1 do
        unroll.fixed(t.z, 2)(fun, x, y)
      end
    end
  end
  return t
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
  if self.x>1 or self.y>1 then error("deprecated use, see color") end
  return self:copy(1, 1, 3)
end

function data:type()
  -- TODO: debug/warning/developer mode
  -- print("Deprecated buffer property \"type\".")
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
