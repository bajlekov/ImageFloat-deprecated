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


--]]




--pyramid decomposition and composition

-- method works for decimating image using gaussian filtering
-- due to downsampling, reconstruction is correct but deltas are not circularly symmetric

-- todo:
--	adjusting kernel size and function width!!
--	increasing kernel width prevents the downscaling to affect output, but kernel gets clipped!!!
--	small width has artistic use, mostly binning

-- better binning function/binning reconstruction function?

-- simple box resampling??



math.randomseed(os.time())

local ffi = require("ffi")
--local sdl = require("sdltools")
--local dbg = require("dbgtools")

do
  local t
  function tic()
    t = os.clock()
  end
  function toc()
    print(os.clock()-t)
  end
end

local ppm = require("ppmtools")
local img = require("imgtools")

require("mathtools")

local d = ppm.readIM("img.ppm")
local bufi = ppm.toBuffer(d)
d = nil

local xmax = bufi.x
local ymax = bufi.y

local bufo = img.copyGS(bufi)

local o = bufo.data
local i = bufi.data

print(xmax, ymax)

--create kernel
local f = ffi.new("double[6][6]")
local sum = 0
for x = 0, 5 do
  for y = 0, 5 do 
    f[x][y] = math.func.gauss(math.sqrt((x-2.5)^2 + (y-2.5)^2), 1.5)
    sum = sum + f[x][y]
  end
end

--normalise
for x = 0, 5 do
  for y = 0, 5 do 
    f[x][y] = f[x][y]/sum
  end
end

function downscale(ibuf)
  local xmax = ibuf.x
  local ymax = ibuf.y
  local zmax = ibuf.z
  
  local obuf = img.newBuffer(math.floor(xmax/2), math.floor(ymax/2), zmax)
  
  local i = ibuf.data
  local o = obuf.data
  
  for z = 0, zmax-1 do
    for x = 2, xmax-3, 2 do
      for y = 2, ymax-3, 2 do
	local t = 0
	
	for xc = 0, 5 do
	  for yc = 0, 5 do
	    t = t + f[xc][yc]*i[x-2+xc][y-2+yc][z] 
	  end
	end
    
	o[x/2][y/2][z] = t
      end
    end
  end
  
  return obuf
end

function upscale(ibuf)
  local xmax = ibuf.x
  local ymax = ibuf.y
  local zmax = ibuf.z
  
  local obuf = img.newBuffer(math.floor(xmax*2), math.floor(ymax*2), zmax)
  
  local i = ibuf.data
  local o = obuf.data
  
  for z = 0, zmax-1 do
    for x = 2, xmax-3 do
      for y = 2, ymax-3 do
	o[x*2][y*2][z] = (i[x][y][z]*f[2][2] +
	    (i[x-1][y][z]+i[x][y-1][z])*f[1][2] +
	    (i[x+1][y][z]+i[x][y+1][z])*f[0][2] +
	    (i[x+1][y-1][z]+i[x-1][y+1][z])*f[0][1] +
	    i[x-1][y-1][z]*f[1][1] + i[x+1][y+1][z]*f[0][0])*4
	    
	o[x*2+1][y*2][z] = (i[x][y][z]*f[2][2] +
	    (i[x+1][y][z]+i[x][y-1][z])*f[1][2] +
	    (i[x-1][y][z]+i[x][y+1][z])*f[0][2] +
	    (i[x+1][y+1][z]+i[x-1][y-1][z])*f[0][1] +
	    i[x+1][y-1][z]*f[1][1] + i[x-1][y+1][z]*f[0][0])*4
	    
	o[x*2][y*2+1][z] = (i[x][y][z]*f[2][2] +
	    (i[x-1][y][z]+i[x][y+1][z])*f[1][2] +
	    (i[x+1][y][z]+i[x][y-1][z])*f[0][2] +
	    (i[x+1][y+1][z]+i[x-1][y-1][z])*f[0][1] +
	    i[x-1][y+1][z]*f[1][1] + i[x+1][y-1][z]*f[0][0])*4
	    
	o[x*2+1][y*2+1][z] = (i[x][y][z]*f[2][2] +
	    (i[x-1][y][z]+i[x][y-1][z])*f[0][2] +
	    (i[x+1][y][z]+i[x][y+1][z])*f[1][2] +
	    (i[x+1][y-1][z]+i[x-1][y+1][z])*f[0][1] +
	    i[x-1][y-1][z]*f[0][0] + i[x+1][y+1][z]*f[1][1])*4
      end
    end
  end
  
  return obuf
end

function pyramid(ibuf)
  local xmax = ibuf.x
  local ymax = ibuf.y
  local zmax = ibuf.z
  
  local dbuf = img.newBuffer(xmax, ymax, zmax)
  
  local i = ibuf.data
  local d = dbuf.data
  
  local obuf = downscale(ibuf)
  local tbuf = upscale(obuf)
  
  local t = tbuf.data
  
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      for z = 0, zmax-1 do
	d[x][y][z] = i[x][y][z] - t[x][y][z]
      end
    end
  end
  
  
  return obuf, dbuf
end

function reverse(obuf, dbuf, fac)
  fac = fac or 1
  local ibuf = upscale(obuf)
  
  local xmax = ibuf.x
  local ymax = ibuf.y
  local zmax = ibuf.z
  
  local i = ibuf.data
  local d = dbuf.data
  
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      for z = 0, zmax-1 do
	i[x][y][z] = i[x][y][z] + fac*d[x][y][z]
      end
    end
  end
  
  return ibuf
end

local l = {}
local d = {}

l[0] = bufi

local n = 7

for i = 1,n do
  tic()
  l[i], d[i] = pyramid(l[i-1])
  toc()
end

local fac = {0, 1, 0, 0, 0, 1, 0}

local r = l[n]
for i = n, 1, -1 do
  tic()
  r = reverse(r, d[i], fac[i] or 1)
  toc()
end

bufo = r

---[[
d = ppm.fromBuffer(bufo)
o = nil
bufo = nil
collectgarbage("collect")
d.name = "pyramid_out.png"
ppm.writeIM(d)
d = nil
print("Done!")
--]]