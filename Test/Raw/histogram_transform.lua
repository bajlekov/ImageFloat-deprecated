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

--]]

--demosaic using adapted ppg method
math.randomseed(os.time())

local ffi = require("ffi")
local sdl = require("sdltools")
local dbg = require("dbgtools")

local ppm = require("ppmtools")
local img = require("imgtools")

local d = ppm.readFile("img.ppm")

local bufi = ppm.toBuffer(d)
local i = bufi.data
local bufo = img.newColor(bufi)
local o = bufo.data

d = nil

local xmax = bufi.x
local ymax = bufi.y

--create histogram
local n = 2^16
local X = ffi.new("double[?]", n)
local Y = ffi.new("double[?]", n)

local floor = math.floor

-- add noise to prevent banding
for x = 0, xmax-1 do
  for y = 0, ymax-1 do
    i[x][y][1] = i[x][y][1] + math.random()/2^8
  end
end


for x = 0, xmax-1 do
  for y = 0, ymax-1 do
    --for z = 0, 2 do
      --hist of all channels
      local bin = floor((i[x][y][1])*n)
      bin = (bin<0 and 0) or (bin>(n-1) and (n-1)) or bin
      X[bin] = X[bin] + 1
    --end
  end
end

--create equal distribution histogram for Y
for i = 0, n-1 do
  Y[i] = 1 --input y function
end
-- normalise Y
do
  local sum = 0
  for i = 0, n-1 do
    sum = sum + Y[i]
  end
  local norm = xmax*ymax/sum
  for i = 0, n-1 do
    Y[i] = Y[i]*norm
  end
end

tic()
--cumulative histograms
local XC = ffi.new("int[?]", n)
local YC = ffi.new("int[?]", n)
XC[0] = X[0]
YC[0] = Y[0]
for i = 1, n-1 do
  XC[i] = X[i] + XC[i-1]
  YC[i] = Y[i] + YC[i-1]
end
--check sums
print(XC[n-1])
print(YC[n-1])
print(xmax*ymax*3)

-- calculate transformed bounds -> providing the actual transformation specifics
local XB = ffi.new("double[?]", n) -- upper bound in 0..1
do
  local x = 0
  local y = 0
  while (x<n and y<n) do 
    --print(X[x], Y[y])
    if XC[x]>YC[y] then
      y = y+1
    else
      -- determine relevant transformation
      --print(x, y, XC[x], YC[y], ((XC[x] - (y==0 and 0 or YC[y-1])) / Y[y] + y))
      XB[x] = ((XC[x] - (y==0 and 0 or YC[y-1])) / Y[y] + y)
      -- perhaps use a smoothed simpson's method? may overexaggerate features
      x = x+1
    end
  end
end

--calculate transform probability from XB, store in XA
local XA = ffi.new("double[?]", n)
XA[0] = XB[0]
for i = 1, n-1 do
  XA[i] = XB[i] - XB[i-1]
end
toc()

--apply transform:
for x = 0, xmax-1 do
  for y = 0, ymax-1 do
    --for z = 0, 2 do
      --hist of all channels
      local c = i[x][y][1] * n
      local bin = floor(c)
      bin = (bin<0 and 0) or (bin>(n-1) and (n-1)) or bin
      local off = c-bin
      
      c = (XB[bin] + off*XA[bin])/n
      
      c = (c<0 and 0) or (c>1 and 1) or c
      
      o[x][y][0] = c
      o[x][y][1] = c
      o[x][y][2] = c
    --end
  end
end




toc()
d = ppm.fromBuffer(bufo)
d.name = "hist_out.png"
ppm.writeFile(d)
d = nil
print("Done!")



