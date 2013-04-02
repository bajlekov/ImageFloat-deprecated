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
--]]


-- setup paths if not loading bytecode
require("path")
local ffi = require("ffi")
__global = require("global")
local __global = __global -- local reference to global table
__global.loadFile = arg and arg[1] or __global.loadFile
collectgarbage("setpause", 120)
math.randomseed(os.time())

-- TODO internal console for debugging etc.
-- TODO	currently not working with luaJIt 2.1 alpha
-- FIXME memory consumption rises above 300MB, leads to unpredicted behaviour and crashes

local sdl = require("sdltools")
local lua = require("luatools")
local dbg = require("dbgtools")
local ppm = require("ppmtools")
local img = require("imgtools")

--put often-used libs in a global namespace and index from there, not as independent globals
__dbg = dbg
__img = img


--[[
    Adapted from: L. Zhang and X. Wu, Color demosaicking via directional linear minimum mean square-error estimation,
    IEEE Trans. on Image Processing, vol. 14, pp. 2167-2178, Dec. 2005.
--]]

local d = ppm.readIM(__global.loadFile)
local bufi = ppm.toBuffer(d)
d = nil

local xmax = bufi.x
local ymax = bufi.y

local bufg = bufi:newM()

local function getCh(x, y)
  return (x%2==1 and y%2==1 and "G") or
	 (x%2==0 and y%2==0 and "G") or
	 (x%2==0 and y%2==1 and "B") or
	 (x%2==1 and y%2==0 and "R")
end

do
  --local i = bufi
  --local g = bufg
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      local ch = getCh(x, y)
      bufg:a(x,y,
      	(ch=="R" and bufi:i(x,y,0)) or
	  	(ch=="G" and bufi:i(x,y,1)) or
	  	(ch=="B" and bufi:i(x,y,2)))
    end
  end
end

bufi = nil
local s = "float["..xmax.."]["..ymax.."]"

local A = ffi.new(s)
for x = 0, xmax-1 do
  for y = 0, ymax-1 do
    A[x][y]=bufg:i(x,y,0)
  end
end

local function convH5(bi, bo, k) -- input, output, kernel
  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      for i = 0, 4 do
		bo[x][y] = bo[x][y] + bi[x+i-2][y]*k[i]
      end
    end
  end
end

local function convV5(bi, bo, k) -- input, output, kernel
  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      for i = 0, 4 do
		bo[x][y] = bo[x][y] + bi[x][y+i-2]*k[i]
      end
    end
  end
end

local f = ffi.new("float[5]", -1/4, 1/2, 1/2, 1/2, -1/4)
-- calculate dh, dv (full GS images)
local Ah = ffi.new(s)
local Av = ffi.new(s)
convH5(A, Ah, f)
convV5(A, Av, f)
local dh = ffi.new(s)
local dv = ffi.new(s)
for x = 2, xmax-3 do
  for y = 2, ymax-3 do
    local c = getCh(x, y)
    if c=="G" then
      dh[x][y] = A[x][y]-Ah[x][y]
      dv[x][y] = A[x][y]-Av[x][y]
    else
      dh[x][y] = Ah[x][y]-A[x][y]
      dv[x][y] = Av[x][y]-A[x][y]
    end
  end
end
--Ah = nil
--Av = nil

local function convH9(bi, bo, k) -- input, output, kernel
  for x = 4, xmax-5 do
    for y = 4, ymax-5 do
      for i = 0, 8 do
	bo[x][y] = bo[x][y] + bi[x+i-4][y]*k[i]
      end
    end
  end
end

local function convV9(bi, bo, k) -- input, output, kernel
  for x = 4, xmax-5 do
    for y = 4, ymax-5 do
      for i = 0, 8 do
	bo[x][y] = bo[x][y] + bi[x][y+i-4]*k[i]
      end
    end
  end
end

local f = ffi.new("double[9]", 4/128, 9/128, 15/128, 23/128, 26/128, 23/128, 15/128, 9/128, 4/128)
--calculate adh, adv(full GS images)
local adh = ffi.new(s)
local adv = ffi.new(s)
convH9(dh, adh, f)
convV9(dv, adv, f)

local function copyH9(bi, bo, x, y)
  for i = 0, 8 do
    bo[i] = bi[x+i-4][y]
  end
end
local function copyV9(bi, bo, x, y)
  for i = 0, 8 do
    bo[i] = bi[x][y+i-4]
  end
end

local function sum9(bi)
  local o = 0
  for i = 0, 8 do
    o = o + bi[i]
  end
  return o
end

local function mean9(bi)
  return sum9(bi)/9
end

local function cov9(bi)
  local o = 0
  local m = mean9(bi)
  for i = 0, 8 do
    o = o + (bi[i]-m)^2
  end
  return o/8
end

local function calcR9(at, t)
  local o = 0
  for i = 0, 8 do
    o = o + (at[i]-t[i])^2
  end
  return o/9
end

-- fill in rAg, rAr, rAb (single color image (output))
local bufo = bufg:newI()
local o = bufo

local t = ffi.new("float[9]")
local at = ffi.new("float[9]")

jit.flush() -- needed to consistently perform well

tic()
for x = 4, xmax-5 do
  for y = 4, ymax-5 do
    if getCh(x, y)~="G" then
      copyH9(dh, t, x, y)
      copyH9(adh, at, x, y)
      
      local m = at[4]
      local p = cov9(at)
      local R = calcR9(at, t)
      
      local h = m + p*(t[4]-m)/(p+R)
      local H = p - p^2/(p+R)
      
      copyV9(dv, t, x, y)
      copyV9(adv, at, x, y)
      
      local m = at[4]
      local p = cov9(at)
      local R = calcR9(at, t)
      
      local v = m + p*(t[4]-m)/(p+R)
      local V = p - p^2/(p+R)
      
      bufo:a(x,y,1, A[x][y] + (V*h + H*v)/(H + V)) -- set green channel
    else
      bufo:a(x,y,1, A[x][y])
    end
  end
end
toc()

--simple RB interpolation, mix 'n' match?

print(xmax, ymax)

for x = 4, xmax-5 do
  for y = 4, ymax-5 do
    local c = getCh(x, y)
    if c=="R" then -- fill in blue channel
      	local oB = o:i(x,y,1) + (
			A[x-1][y-1] - o:i(x-1,y-1,1) +
			A[x-1][y+1] - o:i(x-1,y+1,1) +
			A[x+1][y-1] - o:i(x+1,y-1,1) +
			A[x+1][y+1] - o:i(x+1,y+1,1)
			)/4
		
		o:a(x,y,2, oB)
    	o:a(x,y,0, A[x][y])
    elseif c=="B" then --fill in red channel
    	local oR = o:i(x,y,1) + (
			A[x-1][y-1] - o:i(x-1,y-1,1) +
			A[x-1][y+1] - o:i(x-1,y+1,1) +
			A[x+1][y-1] - o:i(x+1,y-1,1) +
			A[x+1][y+1] - o:i(x+1,y+1,1)
			)/4
		
		o:a(x,y,0, oR)
    	o:a(x,y,2, A[x][y])
    end
  end
end

for x = 4, xmax-5 do
  for y = 4, ymax-5 do
    if getCh(x, y)=="G" then
      local rr = getCh(x+1,y)=="R" -- red row
      if rr then
		local oR = A[x][y] + (
		  A[x+1][y] - o:i(x+1,y,1) +
		  o:i(x,y+1,0) - o:i(x,y+1,1) +
		  A[x-1][y] - o:i(x-1,y,1) +
		  o:i(x,y-1,0) - o:i(x,y-1,1)
		  )/4
		local oB = A[x][y] + (
		  o:i(x+1,y,2) - o:i(x+1,y,1) +
		  A[x][y+1] - o:i(x,y+1,1) +
		  o:i(x-1,y,2) - o:i(x-1,y,1) +
		  A[x][y-1] - o:i(x,y-1,1)
		  )/4
		  o:set(x,y,0, oR)
		  o:set(x,y,2, oB)
	else
		local oB = A[x][y] + (
		  A[x+1][y] - o:i(x+1,y,1) +
		  o:i(x,y+1,2) - o:i(x,y+1,1) +
		  A[x-1][y] - o:i(x-1,y,1) +
		  o:i(x,y-1,2) - o:i(x,y-1,1)
		  )/4
		local oR = A[x][y] + (
		  o:i(x+1,y,0) - o:i(x+1,y,1) +
		  A[x][y+1] - o:i(x,y+1,1) +
		  o:i(x-1,y,0) - o:i(x-1,y,1) +
		  A[x][y-1] - o:i(x,y-1,1)
		  )/4
		  o:set(x,y,0, oR)
		  o:set(x,y,2, oB)
      end
    end
  end
end

-- possibly implement post-hoc green channel patterning detection??

d = ppm.fromBuffer(bufo)
d.name = "dlmmse_out.png"
ppm.writeIM(d)
d = nil
print("Done!")
