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
]]

--all functions depend on existence of pixbuf pointer to screen buffer
local __dimX = __sdl.screenWidth
local __dimY = __sdl.screenHeight
local pixbuf = __sdl.pixbuf()

global("setPixel") -- FIXME
global("getPixel") -- FIXME
global("addPixel") -- FIXME

function setPixel(x,y,r,g,b)
  if x>=0 and x<__dimX and y>=0 and y<__dimY then
  	pixbuf[(x + __dimX*y)*4+2] = r
  	pixbuf[(x + __dimX*y)*4+1] = g
  	pixbuf[(x + __dimX*y)*4] = b
  end
end

function getPixel(x,y)
  local r = pixbuf[(x + __dimX*y)*4+2]
  local g =pixbuf[(x + __dimX*y)*4+1]
  local b =pixbuf[(x + __dimX*y)*4]
  return r, g, b
end

function addPixel(x,y,r,g,b)
  if x>=0 and x<__dimX and y>=0 and y<__dimY then
  	if pixbuf[(x + __dimX*y)*4+2] + r>255 then pixbuf[(x + __dimX*y)*4+2] = 255 elseif pixbuf[(x + __dimX*y)*4+2] + r<0 then pixbuf[(x + __dimX*y)*4+2] = 0 else pixbuf[(x + __dimX*y)*4+2] = pixbuf[(x + __dimX*y)*4+2] + r end
  	if pixbuf[(x + __dimX*y)*4+1] + g>255 then pixbuf[(x + __dimX*y)*4+1] = 255 elseif pixbuf[(x + __dimX*y)*4+1] + r<0 then pixbuf[(x + __dimX*y)*4+1] = 0 else pixbuf[(x + __dimX*y)*4+1] = pixbuf[(x + __dimX*y)*4+1] + g end
  	if pixbuf[(x + __dimX*y)*4+0] + b>255 then pixbuf[(x + __dimX*y)*4+0] = 255 elseif pixbuf[(x + __dimX*y)*4+0] + r<0 then pixbuf[(x + __dimX*y)*4+0] = 0 else pixbuf[(x + __dimX*y)*4+0] = pixbuf[(x + __dimX*y)*4+0] + b end
  end
end
local pixelAdd = addPixel
local setPixel = setPixel
local setPixeladd = setPixeladd

global("boxFill") -- FIXME
global("boxLine") -- FIXME
global("boxAdd") -- FIXME
local _SDL = _SDL
local __sdl = __sdl
function boxFill(x1,y1,x2,y2,r,g,b)
	_SDL.SDL_FillRect(__sdl.screen, __sdl.rect(x1,y1,x2-x1,y2-y1), b+g*256+r*256*256)
	--for x = x1, x2 do
	--	for y = y1, y2 do
	--		setPixel(x,y,r,g,b)
	--	end
	--end
end

global("hLine") -- FIXME
global("vLine") -- FIXME
global("hLineAdd") -- FIXME
global("vLineAdd") -- FIXME
local boxFill = boxFill
function hLine(x,y,l,r,g,b)
	boxFill(x,y,x+l,y+1,r,g,b)
	--for x = x, x+l-1 do
	--	setPixel(x,y,r,g,b)
	--end
end
function vLine(x,y,l,r,g,b)
	boxFill(x,y,x+1,y+l,r,g,b)
	--for y = y, y+l-1 do
	--	setPixel(x,y,r,g,b)
	--end
end

function boxLine(x1,y1,x2,y2,r,g,b)
	for x = x1, x2 do
		for y = y1, y2, y2-y1 do
			setPixel(x,y,r,g,b)
		end
	end
	for x = x1, x2, x2-x1 do
		for y = y1, y2 do
			setPixel(x,y,r,g,b)
		end
	end
end
function boxAdd(x1,y1,x2,y2,r,g,b)
	for x = x1, x2 do
		for y = y1, y2 do
			setPixeladd(x,y,r,g,b)
		end
	end
end
function vLineAdd(x,y,l,r,g,b)
  for y = y, y+l-1 do
    pixelAdd(x,y,r,g,b)
  end
end
function hLineAdd(x,y,l,r,g,b)
  for x = x, x+l-1 do
    pixelAdd(x,y,r,g,b)
  end
end

local abs = math.abs
local function drawLine_fast(x0, y0, x1, y1, r, g, b)	
	local steep = abs(y1-y0) > abs(x1-x0)
	if steep then x0, y0, x1, y1 = y0, x0, y1, x1 end
	if x0>x1 then x0, x1, y0, y1 = x1, x0, y1, y0 end
	
	local dx = x1-x0
	local dy = abs(y1-y0)
	local err = dx/2
	local y = y0
	local ystep = y0<y1 and 1 or -1
	
	for x = x0, x1 do
		setPixel(steep and y or x, steep and x or y, r, g, b)
		err = err - dy
		y = err<0 and y+ystep or y
		err = err<0 and err + dx or err
	end
end
    
do

    local floor = math.floor
    --local function ipart(x) return floor(x) end
    --local function round(x) return floor(x+0.5) end
    local function fpart(x) return x-floor(x) end
    local function rfpart(x) return 1-x+floor(x) end
    local function invpixeladd(x,y,r,g,b) return pixelAdd(y,x,r,g,b) end


	local function drawLine(x1, y1, x2, y2, r, g, b)
		--TODO: handle overlap of connected vertices in endpoint code
		--TODO: implement connected vertices draw (polyline)
	    --AA line drawing
	    
	    --avoid zero-length lines
	    if x1==x2 and y1==y2 then return end 
	
	    local dx = x2 - x1
	    local dy = y2 - y1
	    
	    local pixeladd = pixelAdd
	    
	    if math.abs(dx) < math.abs(dy) then
	      x1, y1 = y1, x1
	      x2, y2 = y2, x2
	      dx, dy = dy, dx
	      pixeladd = invpixeladd
	  end
	
	  if x2 < x1 then
	      x1, x2 = x2, x1
	      y1, y2 = y2, y1
	  end
	
	  local gradient = dy / dx
	
	    -- handle first endpoint
	    local xend = floor(x1 + 0.5)
	    local yend = y1 + gradient * (xend - x1)
	    local xgap = rfpart(x1 + 0.5)
	    local xpxl1 = xend --this will be used in the main loop
	    local ypxl1 = floor(yend)
	    pixeladd(xpxl1, ypxl1, rfpart(yend)*xgap*r, rfpart(yend)*xgap*g, rfpart(yend)*xgap*b)
	    pixeladd(xpxl1, ypxl1+1, fpart(yend)*xgap*r, fpart(yend)*xgap*g, fpart(yend)*xgap*b)
	    
	    local intery = yend + gradient --first y-intersection for the main loop
	    
	    -- handle second endpoint
	    xend = floor(x2 + 0.5)
	    yend = y2 + gradient * (xend - x2)
	    xgap = fpart(x2 + 0.5)
	    local xpxl2 = xend -- this will be used in the main loop
	    local ypxl2 = floor(yend)
	    pixeladd(xpxl2, ypxl2, rfpart(yend)*xgap*r, rfpart(yend)*xgap*g, rfpart(yend)*xgap*b)
	    pixeladd(xpxl2, ypxl2+1, fpart(yend)*xgap*r, fpart(yend)*xgap*g, fpart(yend)*xgap*b)
	    
	    --main loop
	    for x = xpxl1+1, xpxl2-1 do
	        pixeladd(x, floor(intery), rfpart(intery)*r, rfpart(intery)*g, rfpart(intery)*b) -- NYI: register coalescing too complex at draw.lua:195
	        pixeladd(x, floor(intery)+1, fpart(intery)*r, fpart(intery)*g, fpart(intery)*b)
	        --pixeladd(x, ipart (intery)+1, -rfpart(intery)*r, -rfpart(intery)*g, -rfpart(intery)*b)
	        --pixeladd(x, ipart (intery)+2, -fpart(intery)*r, -fpart(intery)*g, -fpart(intery)*b)
	        intery = intery + gradient
	    end
	end

-- use fast line drawing (about 2x faster, another 3x faster due to pixelset instead of pixeladd)
if __global.setup.fastDraw then
	global("drawLine", drawLine_fast)
else
	global("drawLine", drawLine)
end

end

--colour definitions
global("o") -- FIXME
global("dg") -- FIXME
global("mg") -- FIXME
global("lg") -- FIXME

function o() return 255,128,0 end
function dg() return 64,64,64 end
function mg() return 128,128,128 end
function lg() return 192,192,192 end
