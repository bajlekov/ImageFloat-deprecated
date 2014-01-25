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

--prerequisites
local ffi = require("ffi")
local SDL = ffi.load('./libsdl.so')
ffi.cdef(io.open('SDL.h', 'r'):read('*a'))

-- globals (hidden)
local col = {r=255,g=255,b=255}

local t={x=360, y=240, r=0, pen=true}
function t:draw() end

SDL_INIT_VIDEO = 0x20

SDL.SDL_Init(SDL_INIT_VIDEO)

screen = SDL.SDL_SetVideoMode(720, 480, 32, 0x40000000 + 0x00000001 + 0x00000004) -- + 0x80000000)

local function SDL_CreateSurface(width, height, flags)
	local fmt = screen.format
	return SDL.SDL_CreateRGBSurface(flags, width, height,
	fmt.BitsPerPixel, fmt.Rmask, fmt.Gmask, fmt.Bmask, fmt.Amask)
end

local function SDL_DestroySurface(surf)
	SDL.SDL_FreeSurface(surf)
end

pixbuf = ffi.cast("uint8_t*", screen.pixels)
buf = SDL_CreateSurface(720, 480, 0)

SDL.SDL_WM_SetCaption("Test UI", "Test UI");

local function scr_upd()
	SDL.SDL_UpperBlit(screen, nil, buf, nil)
	t:draw()
	SDL.SDL_Flip(screen)
	SDL.SDL_UpperBlit(buf, nil, screen, nil)
end

function color(r, g, b)
	col.r = r*255
	col.g = g*255
	col.b = b*255
	scr_upd()
end

function quit()
	print("Bye!")
	SDL.SDL_Quit()
	os.exit()
end

local function px(x,y)
	pixbuf[(x + 720*y)*4+2] = col.r
	pixbuf[(x + 720*y)*4+1] = col.g
	pixbuf[(x + 720*y)*4] = col.b
end

function pixel(x,y)
	px(x,y)
	scr_upd()
end

function box(x1, y1, x2, y2, f)
	if f then
		for x = x1, x2 do
			for y = y1, y2 do
				px(x,y)
			end
		end
	else
		for x = x1, x2 do
			for y = y1, y2, y2-y1 do
				px(x,y)
			end
		end
		for x = x1, x2, x2-x1 do
			for y = y1, y2 do
				px(x,y)
			end
		end
	end
	scr_upd()
end

local function pxadd(x,y,r,g,b,f)
	pixbuf[(x + 720*y)*4+2] = pixbuf[(x + 720*y)*4+2]*(1-f) + r*f
	pixbuf[(x + 720*y)*4+1] = pixbuf[(x + 720*y)*4+1]*(1-f) + g*f
	pixbuf[(x + 720*y)*4+0] = pixbuf[(x + 720*y)*4+0]*(1-f) + b*f
end

function fill()
	box(0,0,719,479,true)
	scr_upd()
end

function clear()
	local r, g, b
	r=col.r g=col.g b=col.b
	col.r=0 col.g=0 col.b=0
	box(0,0,719,479, true)
	col.r=r col.g=g col.b=b
	scr_upd()
end

--AA line drawing
local function ipart(x) return math.floor(x) end
local function round(x) return ipart(x+0.5) end
local function fpart(x) return x-math.floor(x) end
local function rfpart(x) return 1-fpart(x) end
local function invpxadd(x,y,r,g,b,f) return pxadd(y,x,r,g,b,f) end

local function drawline(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local r, g, b
    r, g, b = col.r, col.g, col.b
    
    local pixeladd = pxadd
    
    if math.abs(dx) < math.abs(dy) then
      x1, y1 = y1, x1
      x2, y2 = y2, x2
      dx, dy = dy, dx
      pixeladd = invpxadd
    end
    
    if x2 < x1 then
      x1, x2 = x2, x1
      y1, y2 = y2, y1
    end
    
    local gradient = dy / dx
    
    -- handle first endpoint
    local xend = round(x1)
    local yend = y1 + gradient * (xend - x1)
    local xgap = rfpart(x1 + 0.5)
    local xpxl1 = xend --this will be used in the main loop
    local ypxl1 = ipart(yend)
    --plot(xpxl1, ypxl1, rfpart(yend) * xgap)
    --plot(xpxl1, ypxl1 + 1, fpart(yend) * xgap)
    pixeladd(xpxl1, ypxl1, r, g, b, rfpart(yend)*xgap)
    pixeladd(xpxl1, ypxl1+1, r, g, b, fpart(yend)*xgap)
    
    local intery = yend + gradient --first y-intersection for the main loop
    
    -- handle second endpoint
    xend = round (x2)
    yend = y2 + gradient * (xend - x2)
    xgap = fpart(x2 + 0.5)
    local xpxl2 = xend -- this will be used in the main loop
    local ypxl2 = ipart (yend)
    --plot (xpxl2, ypxl2, rfpart (yend) * xgap)
    --plot (xpxl2, ypxl2 + 1, fpart (yend) * xgap)
    pixeladd(xpxl2, ypxl2, r, g, b, rfpart(yend)*xgap)
    pixeladd(xpxl2, ypxl2+1, r, g, b, fpart(yend)*xgap)
    
    --main loop
    for x = xpxl1+1, xpxl2-1 do
        pixeladd(x, ipart (intery), r, g, b, rfpart(intery))
        pixeladd(x, ipart (intery)+1, r, g, b, fpart(intery))
        intery = intery + gradient
    end
end

function line(x1,y1,x2,y2)
	drawline(x1, y1, x2, y2)
	scr_upd()
end


--turtle
function t:draw()
	local x1,y1,x2,y2,x3,y3,r
	r = (self.r+90)*math.pi/180
	x1 = self.x + math.cos(r)*20 + math.sin(r)*5
	y1 = self.y - math.cos(r)*5 + math.sin(r)*20
	
	x2 = self.x + math.cos(r)*20 - math.sin(r)*5
	y2 = self.y + math.cos(r)*5 + math.sin(r)*20
	
	x3 = self.x + math.cos(r)*10
	y3 = self.y + math.sin(r)*10
	
	drawline(self.x, self.y, x1,y1)
	drawline(self.x, self.y, x2,y2)
	drawline(x3, y3, x1,y1)
	drawline(x3, y3, x2,y2)
end

scr_upd()

function left(x)
	if x==nil then x = 90 end
	t.r = t.r - x
	scr_upd()
end

function right(x)
	if x==nil then x = 90 end
	t.r = t.r + x
	scr_upd()
end

function penup() t.pen=false end
function pendown() t.pen=true end

function move(x)
	if x==nil then x = 10 end
	local tx,ty,r
	r = (t.r+90)*math.pi/180
	tx = t.x - math.cos(r)*x
	ty = t.y - math.sin(r)*x
	if t.pen==true then
		drawline(tx,ty,t.x,t.y)
	end
	t.x, t.y = tx, ty
	
	scr_upd()
end

