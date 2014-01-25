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



    Adapted from: Chuan-kai Lin, Portland State University (2004). "Pixel Grouping for Color Filter Array Demosaicing"
    (https://sites.google.com/site/chklin/demosaic/)

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
local bufh = img.newGS(bufi)

local i = bufi.data
local g = bufg.data
local h = bufh.data

print(xmax, ymax)

local function getCh(x, y)
  return (x%2==1 and y%2==0 and "G") or
	 (x%2==0 and y%2==1 and "G") or
	 (x%2==0 and y%2==0 and "B") or
	 (x%2==1 and y%2==1 and "R")
end

--convert to bayer matrix
for x = 0, xmax-1 do
  for y = 0, ymax-1 do
    local ch = getCh(x, y)
    g[x][y][0] = (ch=="R" and i[x][y][0]) or
	(ch=="G" and i[x][y][1]) or
	(ch=="B" and i[x][y][2])
  end
end

bufi = nil
i = nil
local bufo = img.newColor(bufg)
local o = bufo.data

local abs = math.abs

function ppg_green(g, o)
  local D = ffi.new("double[4]")
  local V = function(n, x, y)
    return n==0 and (g[x][y-1][0] + g[x][y][0] + 3*g[x][y+1][0] - g[x][y+2][0])/4 or
	   n==1 and (g[x-1][y][0] + g[x][y][0] + 3*g[x+1][y][0] - g[x+2][y][0])/4 or
	   n==2 and (g[x+1][y][0] + g[x][y][0] + 3*g[x-1][y][0] - g[x-2][y][0])/4 or
	   n==3 and (g[x][y+1][0] + g[x][y][0] + 3*g[x][y-1][0] - g[x][y-2][0])/4
  end
  
  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      
      if getCh(x, y)~="G" then
	-- directions: N E W S
	D[0] = 2*abs(g[x][y][0] - g[x][y+2][0]) + abs(g[x][y-1][0] - g[x][y+1][0])
	D[1] = 2*abs(g[x][y][0] - g[x+2][y][0]) + abs(g[x-1][y][0] - g[x+1][y][0])
	D[2] = 2*abs(g[x][y][0] - g[x-2][y][0]) + abs(g[x-1][y][0] - g[x+1][y][0])
	D[3] = 2*abs(g[x][y][0] - g[x][y-2][0]) + abs(g[x][y-1][0] - g[x][y+1][0])
	
	D[0] = D[0] + abs(g[x+1][y][0] - g[x+1][y+2][0]) + abs(g[x-1][y][0] - g[x-1][y+2][0])
	D[1] = D[1] + abs(g[x][y+1][0] - g[x+2][y+1][0]) + abs(g[x][y-1][0] - g[x+2][y-1][0])
	D[2] = D[2] + abs(g[x][y+1][0] - g[x-2][y+1][0]) + abs(g[x][y-1][0] - g[x-2][y-1][0])
	D[3] = D[3] + abs(g[x+1][y][0] - g[x+1][y-2][0]) + abs(g[x-1][y][0] - g[x-1][y-2][0])
	  
	local Dmin = math.min(D[0], D[1], D[2], D[3])
	local Dthr = Dmin * 2  --threshold for averaging gradients
	local Dnum =  (D[0]<=Dthr and 1 or 0) +
		      (D[1]<=Dthr and 1 or 0) +
		      (D[2]<=Dthr and 1 or 0) +
		      (D[3]<=Dthr and 1 or 0)
	local Vtot = 0
	Vtot = (D[0]<=Dthr) and (Vtot + V(0,x,y)) or Vtot
	Vtot = (D[1]<=Dthr) and (Vtot + V(1,x,y)) or Vtot
	Vtot = (D[2]<=Dthr) and (Vtot + V(2,x,y)) or Vtot
	Vtot = (D[3]<=Dthr) and (Vtot + V(3,x,y)) or Vtot
	
	o[x][y][1] = Vtot/Dnum
      else
	o[x][y][1] = g[x][y][0]
      end --if
    end --for
  end --for
end --function


function ppg_redblue(g, o)
  local function hue_transit(g1, g2, g3, x1, x3)
    -- make hue_transit less sensitive on noisy greens?
    return ((g1<g2 and g2<g3) or (g1>g2 and g2>g3)) and
	(x1 + (g2-g1) * (x3-x1)/(g3-g1))
      or
	((x1+x3)/2 + (g2*2-g1-g3)/2) --* (x3+x1)/(g3+g1)) --causes noise with low green values
  end --function

  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      if getCh(x, y)=="G" then
	if getCh(x-1, y)=="R" then --check which color is in row
	  o[x][y][0] = hue_transit(o[x-1][y][1], o[x][y][1], o[x+1][y][1], g[x-1][y][0], g[x+1][y][0])
	  o[x][y][2] = hue_transit(o[x][y-1][1], o[x][y][1], o[x][y+1][1], g[x][y-1][0], g[x][y+1][0])
	else
	  o[x][y][2] = hue_transit(o[x-1][y][1], o[x][y][1], o[x+1][y][1], g[x-1][y][0], g[x+1][y][0])
	  o[x][y][0] = hue_transit(o[x][y-1][1], o[x][y][1], o[x][y+1][1], g[x][y-1][0], g[x][y+1][0])
	end --if
      else
	local DR =  abs(g[x+1][y+1][0]-g[x-1][y-1][0]) + 
		    abs(g[x][y][0]-g[x+2][y+2][0]) +
		    abs(g[x][y][0]-g[x-2][y-2][0]) +
		    abs(o[x][y][1]-o[x+1][y+1][1]) +
		    abs(o[x][y][1]-o[x-1][y-1][1])
	local DL =  abs(g[x+1][y-1][0]-g[x-1][y+1][0]) + 
		    abs(g[x][y][0]-g[x+2][y-2][0]) +
		    abs(g[x][y][0]-g[x-2][y+2][0]) +
		    abs(o[x][y][1]-o[x+1][y-1][1]) +
		    abs(o[x][y][1]-o[x-1][y+1][1])
	
	local tot = DR<DL and
		hue_transit(o[x-1][y-1][1], o[x][y][1], o[x+1][y+1][1], g[x-1][y-1][0], g[x+1][y+1][0])
	    or
		hue_transit(o[x-1][y+1][1], o[x][y][1], o[x+1][y-1][1], g[x-1][y+1][0], g[x+1][y-1][0])
	
	if getCh(x, y)=="R" then
	  o[x][y][2] = tot
	  o[x][y][0] = g[x][y][0]
	else
	  o[x][y][0] = tot
	  o[x][y][2] = g[x][y][0]
	end --if
      end --if
    end --for
  end --for
end --function

tic()
ppg_green(g, o)
ppg_redblue(g, o)
toc()

local median
do
  local pix = ffi.new("double[9]")
  local A = ffi.new("short[19]", 1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4)
  local B = ffi.new("short[19]", 2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2)
  
local function sort(a, b)
	if pix[a]>pix[b] then
		pix[a], pix[b] = pix[b], pix[a]
	end
end
  
  median = function(o, x, y)

    pix[0] = o[x-1][y-1][0]
    pix[1] = o[x-1][y][0]
    pix[2] = o[x-1][y+1][0]
    pix[3] = o[x][y-1][0]
    pix[4] = o[x][y][0]
    pix[5] = o[x][y+1][0]
    pix[6] = o[x+1][y-1][0]
    pix[7] = o[x+1][y][0]
    pix[8] = o[x+1][y+1][0]
    
    for i = 0, 18 do
      sort(A[i],B[i])
    end
    
    return pix[4]
  end
end

--presort data into dense buffer (per line?), use memcopy to move data to local buffer for median filter

function medfilter()
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      g[x][y][0] = o[x][y][0] - o[x][y][1]
    end
  end
  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      o[x][y][0] = median(g, x, y) + o[x][y][1]
    end
  end
  
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      g[x][y][0] = o[x][y][2] - o[x][y][1]
    end
  end
  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      o[x][y][2] = median(g, x, y) + o[x][y][1]
    end
  end
  ---[[
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      g[x][y][0] = o[x][y][1] - o[x][y][0]
    end
  end
  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      h[x][y][0] = median(g, x, y)
    end
  end
  
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      g[x][y][0] = o[x][y][1] - o[x][y][2]
    end
  end
  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      h[x][y][0] = h[x][y][0] + median(g, x, y)
    end
  end
  
  for x = 2, xmax-3 do
    for y = 2, ymax-3 do
      o[x][y][1] = (h[x][y][0] + o[x][y][0] + o[x][y][2])/2
    end
  end
  --]]
end


--collectgarbage("collect")
tic()
medfilter()
medfilter()
medfilter()
toc()

g = nil
bufg = nil
d = ppm.fromBuffer(bufo)
o = nil
bufo = nil
collectgarbage("collect")
d.name = "ppg_out.png"
ppm.writeIM(d)
d = nil
print("Done!")