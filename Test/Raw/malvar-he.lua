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



    Adapted from: Getreuer, Pascal. “Malvar-He-Cutler Linear Image Demosaicking.”
	Image Processing On Line 2011 (2011). http://dx.doi.org/10.5201/ipol.2011.g_mhcd

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
local s = "double["..xmax.."]["..ymax.."]"

local A = ffi.new(s)
for x = 0, xmax-1 do
  for y = 0, ymax-1 do
    A[x][y]=bufg.data[x][y][0]
  end
end

local bufo = img.newColor(bufg)
local o = bufo.data
bufg = nil

tic()
for x = 2, xmax-3 do
  for y = 2, ymax-3 do
    local c = getCh(x, y)
    local rr = getCh(x+1, y)=="R"
    if c~="G" then
      o[x][y][1] = ( A[x][y]*4 + (
	A[x][y+1] + A[x+1][y] + A[x][y-1] + A[x-1][y])*2 - (
	A[x][y+2] + A[x+2][y] + A[x][y-2] + A[x-2][y]) )/8
      o[x][y][c=="R" and 2 or 0] = (A[x][y]*6 + (
	A[x+1][y+1] + A[x+1][y-1] + A[x-1][y-1] + A[x-1][y+1])*2 -(
	A[x][y+2] + A[x+2][y] + A[x][y-2] + A[x-2][y])*3/2 )/8
      o[x][y][c=="R" and 0 or 2] = A[x][y]
    else
      local gg = A[x][y]*5 - A[x+1][y+1] - A[x-1][y-1] - A[x+1][y-1] - A[x-1][y+1]
      o[x][y][rr and 0 or 2] = ( gg + 4*(A[x-1][y] + A[x+1][y]) +
	A[x][y-2]/2 + A[x][y+2]/2 - A[x-2][y] - A[x+2][y])/8
      o[x][y][rr and 2 or 0] = ( gg + 4*(A[x][y-1] + A[x][y+1]) +
	A[x-2][y]/2 + A[x+2][y]/2 - A[x][y-2] - A[x][y+2])/8
      o[x][y][1] = A[x][y]
    end
  end
end
toc()

d = ppm.fromBuffer(bufo)
d.name = "mhc_out.png"
ppm.writeIM(d)
d = nil
print("Done!")