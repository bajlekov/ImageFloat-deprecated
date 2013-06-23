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



    Adapted from: Jacek Góźdź and Luis Sanz Rodríguez (cuniek@kft.umcs.lublin.pl, luis.sanz.rodriguez@gmail.com)
    http://www.linuxphoto.org/html/algorithms.html

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

bufo = img.new(bufi)
local o = bufo.data
bufi = nil


local s = "float["..xmax.."]["..ymax.."]"

local A = ffi.new(s)
for x = 0, xmax-1 do
  for y = 0, ymax-1 do
    A[x][y]=bufg.data[x][y][0]
  end
end

local abs = math.abs

tic()
-- interpolate green channel
for x = 5, xmax-6 do
  for y = 5, ymax-6 do
    if getCh(x,y)~="G" then
      local fn, fe, fs, fw
      fn = 1/(1 + abs(A[x][y+1]-A[x][y+3]) + abs(A[x][y+3]-A[x][y+5]))
      fe = 1/(1 + abs(A[x+1][y]-A[x+3][y]) + abs(A[x+3][y]-A[x+5][y]))
      fs = 1/(1 + abs(A[x][y-1]-A[x][y-3]) + abs(A[x][y-3]-A[x][y-5]))
      fw = 1/(1 + abs(A[x-1][y]-A[x-3][y]) + abs(A[x-3][y]-A[x-5][y]))
      
      local gn, ge, gs, gw
      gn = (23*A[x][y+1] + 23*A[x][y+3] + 2*A[x][y+5] + 40*(A[x][y]-A[x][y+2]) + 8*(A[x][y+2]-A[x][y+4]))/48
      ge = (23*A[x+1][y] + 23*A[x+3][y] + 2*A[x+5][y] + 40*(A[x][y]-A[x+2][y]) + 8*(A[x+2][y]-A[x+4][y]))/48
      gs = (23*A[x][y-1] + 23*A[x][y-3] + 2*A[x][y-5] + 40*(A[x][y]-A[x][y-2]) + 8*(A[x][y-2]-A[x][y-4]))/48
      gw = (23*A[x-1][y] + 23*A[x-3][y] + 2*A[x-5][y] + 40*(A[x][y]-A[x-2][y]) + 8*(A[x-2][y]-A[x-4][y]))/48
      
      o[x][y][1] = (fn*gn + fe*ge + fs*gs + fw*gw)/(fn + fe + fs + fw)
    else
      o[x][y][1] = A[x][y]
    end
  end
end

-- calculate chroma channels
for x = 5, xmax-6 do
  for y = 5, ymax-6 do
    local c = getCh(x,y)
    o[x][y][c=="R" and 0 or 2] = A[x][y] - o[x][y][1]
  end
end

-- interpolate chroma channels diagonally
for x = 5, xmax-6 do
  for y = 5, ymax-6 do
    local c = getCh(x,y)
    if c~="G" then
      local cc = c=="R" and 2 or 0
      
      local fn, fe, fs, fw
      fn = 1/(1 + abs(o[x-1][y-1][cc] - o[x+1][y+1][cc]) + abs(o[x-1][y-1][cc] - o[x+3][y+3][cc]) + abs(o[x+1][y+1][cc] - o[x+3][y+3][cc])) -- ++
      fe = 1/(1 + abs(o[x-1][y+1][cc] - o[x+1][y-1][cc]) + abs(o[x-1][y+1][cc] - o[x+3][y-3][cc]) + abs(o[x+1][y-1][cc] - o[x+3][y-3][cc])) -- +-
      fs = 1/(1 + abs(o[x-1][y-1][cc] - o[x+1][y+1][cc]) + abs(o[x+1][y+1][cc] - o[x-3][y-3][cc]) + abs(o[x-1][y-1][cc] - o[x-3][y-3][cc])) -- --
      fw = 1/(1 + abs(o[x-1][y+1][cc] - o[x+1][y-1][cc]) + abs(o[x+1][y-1][cc] - o[x-3][y+3][cc]) + abs(o[x-1][y+1][cc] - o[x-3][y+3][cc])) -- -+
      
      local gn, ge, gs, gw
      gn = 1.325*o[x+1][y+1][cc] - 0.175*o[x+3][y+3][cc] - 0.075*o[x+1][y+3][cc] - 0.075*o[x+3][y+1][cc] -- ++
      ge = 1.325*o[x+1][y-1][cc] - 0.175*o[x+3][y-3][cc] - 0.075*o[x+1][y-3][cc] - 0.075*o[x+3][y-1][cc] -- +-
      gs = 1.325*o[x-1][y-1][cc] - 0.175*o[x-3][y-3][cc] - 0.075*o[x-1][y-3][cc] - 0.075*o[x-3][y-1][cc] -- --
      gw = 1.325*o[x-1][y+1][cc] - 0.175*o[x-3][y+3][cc] - 0.075*o[x-1][y+3][cc] - 0.075*o[x-3][y+1][cc] -- -+
      
      o[x][y][cc] = (fn*gn + fe*ge + fs*gs + fw*gw)/(fn + fe + fs + fw)
    end
  end
end

-- interpolate chroma channels hor/ver
for x = 5, xmax-6 do
  for y = 5, ymax-6 do
    local c = getCh(x,y)
    if c=="G" then
      for cc = 0, 2, 2 do --for each color
	local fn, fe, fs, fw
	fn = 1/(1 + abs(o[x][y+1][cc] - o[x][y-1][cc]) + abs(o[x][y+1][cc] - o[x][y+3][cc]) + abs(o[x][y-1][cc] - o[x][y+3][cc]))
	fe = 1/(1 + abs(o[x+1][y][cc] - o[x-1][y][cc]) + abs(o[x+1][y][cc] - o[x+3][y][cc]) + abs(o[x-1][y][cc] - o[x+3][y][cc]))
	fs = 1/(1 + abs(o[x][y+1][cc] - o[x][y-1][cc]) + abs(o[x][y+1][cc] - o[x][y-3][cc]) + abs(o[x][y-1][cc] - o[x][y-3][cc]))
	fw = 1/(1 + abs(o[x+1][y][cc] - o[x-1][y][cc]) + abs(o[x+1][y][cc] - o[x-3][y][cc]) + abs(o[x-1][y][cc] - o[x-3][y][cc]))
	
	local gn, ge, gs, gw
	gn = 0.875*o[x][y+1][cc] + 0.125*o[x][y+3][cc]
	ge = 0.875*o[x+1][y][cc] + 0.125*o[x+3][y][cc]
	gs = 0.875*o[x][y-1][cc] + 0.125*o[x][y-3][cc]
	gw = 0.875*o[x-1][y][cc] + 0.125*o[x-3][y][cc]
	
	o[x][y][cc] = (fn*gn + fe*ge + fs*gs + fw*gw)/(fn + fe + fs + fw)
      end
    end
  end
end

-- return interpolated chroma to RB
for x = 5, xmax-6 do
  for y = 5, ymax-6 do
    o[x][y][0] = o[x][y][0] + o[x][y][1]
    o[x][y][2] = o[x][y][2] + o[x][y][1]
  end
end

local min = math.min
local max = math.max

local function lim(x, l, h)
  return (x<l and l) or (x>h and h) or x
end

-- clamp all channels to neighbors
for x = 5, xmax-6 do
  for y = 5, ymax-6 do
    for z = 0, 2 do
      local c = o[x][y][z]
      
      local c1, c2, c3, c4
      c1 = o[x+1][y][z]
      c2 = o[x-1][y][z]
      c3 = o[x][y+1][z]
      c4 = o[x][y-1][z]
      
      local l = min(c1, c2, c3, c4)
      local h = max(c1, c2, c3, c4)
      
      
      -- put threshold on change?
      o[x][y][z] = lim(c, l, h) -- visualise using abs(lim(c, l, h)-c)
    end
  end
end


-- possible further denoising




toc()
d = ppm.fromBuffer(bufo)
d.name = "fbdd_out.png"
ppm.writeIM(d)
d = nil
print("Done!")