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

-- library providing tools to generate and access lookup tables for various functions
-- TODO: move map allocation to GC-managed C arrays

-- LUT
local lut = {linear=true}

local ffi = require("ffi")
local floor = math.floor
local abs = math.abs

lut.size = "double"

function lut.create(fun, start, len, res)
  local map = ffi.new(lut.size.."[?]", res+1) -- keep map externally!!
  local step = len/res
  local step_1 = 1/step
  
  --fill map
  for i = 0, res do
    map[i] = fun(start+i*step)
  end
  
  if lut.linear then     
    -- linear interpolation
    return function(n)
      if n<start or n>start+len then
        return fun(n)
      else
        local x = (n-start)*step_1
        local a1 = floor(x)
        local a2 = a1+1
        local w2 = x-a1
        local w1 = 1-w2
        return w1*map[a1]+w2*map[a2]
      end
    end
    
  else
    -- rounding
    return function(n)
      if n<start or n>start+len then
        return fun(n)
      else
        return map[floor((n-start)*step_1+0.5)]
      end
    end
    
  end
end

function lut.createSymmetric(fun, len, res)
  local map = ffi.new(lut.size.."[?]", res+1) -- keep map externally!!
  local step = len/res
  local step_1 = 1/step
  
  --fill map
  for i = 0, res do
    map[i] = fun(i*step)
  end
  
  if lut.linear then 
    -- linear interpolation
    return function(n)
      n = abs(n)
      if n>len then
        return fun(n)
      else
        local x = n*step_1
        local a1 = floor(x)
        local a2 = a1+1
        local w2 = x-a1
        local w1 = 1-w2
        return w1*map[a1]+w2*map[a2]
      end
    end
    
  else
    -- rounding
    return function(n)
      n = abs(n)
      if n>len then
        return fun(n)
      else
        return map[floor(n*step_1+0.5)]
      end
    end
    
  end
end

function lut.createPeriodic(fun, len, res)
  local map = ffi.new(lut.size.."[?]", res+1) -- keep map externally!!
  local step = len/res
  local step_1 = 1/step
  
  --fill map
  for i = 0, res do
    map[i] = fun(i*step)
  end
  
  if lut.linear then 
    -- linear interpolation
    return function(n)
      local x = (n%len)*step_1
      local a1 = floor(x)
      local a2 = a1+1
      local w2 = x-a1
      local w1 = 1-w2
      return w1*map[a1]+w2*map[a2]
    end
    
  else
    -- rounding
    return function(n)
      return map[floor((n%len)*step_1+0.5)]
    end
    
  end
end

lut.testsize = 1000000

do
  local __time = 0
  local function tic() __time = os.clock() end
  local function toc() return os.clock()-__time end
  
  function lut.test(fun, start, len, res)  
    tic()
    local lutfun = lut.create(fun,start,len,res)
    local t_create = toc()
    
    local n = lut.testsize
    local test = ffi.new("double[?]", n+1)
    local o_native = ffi.new("double[?]", n+1)
    local o_sample = ffi.new("double[?]", n+1)
    
    math.randomseed(os.clock())
    for i = 0, n do
      test[i] = start+math.random()*len
    end
    
    tic()
    for i = 0, n do
      o_native[i] = fun(test[i])
    end
    local t_native = toc()
    
    tic()
    for i = 0, n do
      o_sample[i] = lutfun(test[i])
    end
    local t_sample = toc()
    
    local err_max = -math.huge
    local err_mean = 0
    for i = 0, n do
      local diff = math.abs(o_sample[i]-o_native[i])
      if diff>err_max then err_max=diff end
      err_mean = err_mean+diff
    end
    err_mean = err_mean/(n+1)
    
    print("Memory:")
    print("  Map:    "..(res*(lut.size=="float" and 4 or 8)/1024/1024).."MB")
    print("Timing:")
    print("  Create: "..(t_create*1000).."ms")
    print("  Sample: "..(t_sample*1000).."ms")
    print("  Native: "..(t_native*1000).."ms")
    print("Error:")
    print("  Max:    "..err_max)
    print("  Mean:   "..err_mean)
    print("  32bit:  "..(2^-23))
    print("  64bit:  "..(2^-52))
  end
end

function lut.memoize(fun)
  local map = {}
  return function(n)
    if map[n]==nil then
      map[n] = fun(n)
    end
    return map[n]
  end
end

--test
lut.test(math.atan,0,math.pi,2^16)
lut.test(function(a) return a^2.2 end,0,math.pi,2^12)

return lut