 --[[
	Copyright (C) 2011-2013 G. Bajlekov

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



    Adapted from: L. Zhang and X. Wu, Color demosaicking via directional linear minimum mean square-error estimation,
    IEEE Trans. on Image Processing, vol. 14, pp. 2167-2178, Dec. 2005.

--]]

--demosaic using adapted ppg method
math.randomseed(os.time())

local ffi = require("ffi")
local sdl = require("sdltools")
local dbg = require("dbgtools")

local ppm = require("ppmtools")
local img = require("imgtools")

local d = ppm.readIM("test.png")
local bufi = ppm.toBuffer(d)
d = nil

local xmax = bufi.x
local ymax = bufi.y

local bufg = img.newGS(bufi)

local function getCh(x, y)
  return (x%2==1 and y%2==1 and "G") or
	 (x%2==0 and y%2==0 and "G") or
	 (x%2==0 and y%2==1 and "B") or
	 (x%2==1 and y%2==0 and "R")
end

do
  local i = bufi.data
  local g = bufg.data
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      local ch = getCh(x, y)
      g[x][y][0] = (ch=="R" and i[x][y][0]) or
	  (ch=="G" and i[x][y][1]) or
	  (ch=="B" and i[x][y][2])
    end
  end
end

bufi = nil
local s = "float["..xmax.."]["..ymax.."]"

local A = ffi.new(s)
for x = 0, xmax-1 do
  for y = 0, ymax-1 do
    A[x][y]=bufg.data[x][y][0]
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

local f = ffi.new("double[5]", -1/4, 1/2, 1/2, 1/2, -1/4)
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
local bufo = img.newColor(bufg)
local o = bufo.data

local t = ffi.new("double[9]")
local at = ffi.new("double[9]")

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
      
      o[x][y][1] = A[x][y] + (V*h + H*v)/(H + V) -- set green channel
    else
      o[x][y][1] = A[x][y]
    end
  end
end
toc()

--simple RB interpolation, mix 'n' match?

for x = 4, xmax-5 do
  for y = 4, ymax-5 do
    local c = getCh(x, y)
    if c=="R" then -- fill in blue channel
      o[x][y][2] = o[x][y][1] + (
	A[x-1][y-1] - o[x-1][y-1][1] +
	A[x-1][y+1] - o[x-1][y+1][1] +
	A[x+1][y-1] - o[x+1][y-1][1] +
	A[x+1][y+1] - o[x+1][y+1][1])/4
      o[x][y][0] = A[x][y]
    elseif c=="B" then --fill in red channel
      o[x][y][0] = o[x][y][1] + (
	A[x-1][y-1] - o[x-1][y-1][1] +
	A[x-1][y+1] - o[x-1][y+1][1] +
	A[x+1][y-1] - o[x+1][y-1][1] +
	A[x+1][y+1] - o[x+1][y+1][1])/4
      o[x][y][2] = A[x][y]
    end
  end
end

for x = 4, xmax-5 do
  for y = 4, ymax-5 do
    if getCh(x, y)=="G" then
      local rr = getCh(x+1,y)=="R" -- red row
      if rr then
	o[x][y][0] = A[x][y] + (
	  A[x+1][y] - o[x+1][y][1] +
	  o[x][y+1][0] - o[x][y+1][1] +
	  A[x-1][y] - o[x-1][y][1] +
	  o[x][y-1][0] - o[x][y-1][1])/4
	o[x][y][2] = A[x][y] + (
	  o[x+1][y][2] - o[x+1][y][1] +
	  A[x][y+1] - o[x][y+1][1] +
	  o[x-1][y][2] - o[x-1][y][1] +
	  A[x][y-1] - o[x][y-1][1])/4
      else
	o[x][y][2] = A[x][y] + (
	  A[x+1][y] - o[x+1][y][1] +
	  o[x][y+1][2] - o[x][y+1][1] +
	  A[x-1][y] - o[x-1][y][1] +
	  o[x][y-1][2] - o[x][y-1][1])/4
	o[x][y][0] = A[x][y] + (
	  o[x+1][y][0] - o[x+1][y][1] +
	  A[x][y+1] - o[x][y+1][1] +
	  o[x-1][y][0] - o[x-1][y][1] +
	  A[x][y-1] - o[x][y-1][1])/4
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
