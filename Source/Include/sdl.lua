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

-- collection of SDL-dependent utilities

local ffi = require("ffi")

-- TODO: load relevant SDL libs
local function loadlib(lib)	return ffi.load("lib"..lib..".so") end
local _SDL = loadlib('SDL')
local _TTF = loadlib("SDL_ttf")
local _IMG = loadlib("SDL_image")

-- read SDL header
ffi.cdef(io.open("./Source/Include/SDL.h", "r"):read('*a')) io.close()
-- TODO: put definitions into corresponding lua file

local sdl = {}

--sdl.color = ffi.typeof("SDL_Color") -- r, g, b, a
sdl.rect = ffi.typeof("SDL_Rect") -- x, y, w, h

function sdl.init()
	_SDL.SDL_Init(20)
	_TTF.TTF_Init()
	_IMG.IMG_Init(7) -- load JPG, PNG and TIFF support
end
function sdl.quit()
	_SDL.SDL_Quit()
	_TTF.TTF_Quit()
	_IMG.IMG_Quit()
end

local SDL_SWSURFACE = 0x00000000
local SDL_HWSURFACE = 0x00000001
local SDL_ASYNCBLIT = 0x00000004
local SDL_DOUBLEBUF = 0x40000000
local SDL_RESIZABLE = 0x00000010
local SDL_NOFRAME	= 0x00000020

local SDL_SRCALPHA	= 0x00010000

sdl.screen = {}
function sdl.screen.set(x, y)
	sdl.screen.surf = _SDL.SDL_SetVideoMode(x, y, 32, SDL_DOUBLEBUF + SDL_HWSURFACE)
	sdl.screen.width = x
	sdl.screen.height = y
	sdl.surf.attach(sdl.screen.surf)
	_SDL.SDL_EnableUNICODE(1) -- enable unicode support
	return sdl.screen.surf
end
-- TODO: function for resizing the screen
function sdl.screen.caption(title, toolbar) _SDL.SDL_WM_SetCaption(title, toolbar) end
function sdl.screen.icon(file) _SDL.SDL_WM_SetIcon(_IMG.IMG_Load(file), null) end
function sdl.screen.pixbuf() return ffi.cast("uint8_t*", sdl.screen.surf.pixels) end
function sdl.screen.update(x, y, w, h)
	if x then _SDL.SDL_UpdateRect(sdl.screen.surf, x, y, w, h)
	else _SDL.SDL_Flip(sdl.screen.surf) end
end

function sdl.time() return _SDL.SDL_GetTicks() end
function sdl.wait(x) _SDL.SDL_Delay(x) end

-- surface
sdl.surf = {current=nil, pixels=nil}
function sdl.surf.new(w, h)
	w = w or sdl.screen.width
	h = h or sdl.screen.height
	local fmt = sdl.screen.surf.format
	local t =_SDL.SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, -- + SDL_SRCALPHA
	fmt.BitsPerPixel, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
	return ffi.gc(t, _SDL.SDL_FreeSurface) -- register for GC
end

local function blit(buf1, rect1, buf2, rect2) _SDL.SDL_UpperBlit(buf1, rect1, buf2, rect2) end

function sdl.surf.copy(buf1, buf2, rect1, rect2)
	blit(buf1, rect1, buf2, rect2)
end
function sdl.surf.get(x, y, w, h)
	w = w or sdl.surf.current.w
	h = h or sdl.surf.current.h
	local buf = sdl.surf.new(w, h)
	sdl.surf.copy(sdl.surf.current, buf, sdl.rect(x or 0,y or 0,w,h), nil)
	return buf
end
function sdl.surf.put(buf, x, y, w, h)
	sdl.surf.copy(buf, sdl.surf.current, nil, sdl.rect(x or 0,y or 0,w or 0,h or 0))
end
function sdl.surf.pixbuf(buf)
	return ffi.cast("uint8_t*", buf and buf.pixels or sdl.surf.current.pixels)
end
function sdl.surf.attach(buf)
	if buf then sdl.surf.current = buf
	else sdl.surf.current = sdl.screen.surf end
	sdl.surf.pixels = sdl.surf.pixbuf()
end
function sdl.surf.image(file)
	local li = _IMG.IMG_Load(file)
	--local oi = _SDL.SDL_DisplayFormatAlpha(li)
	--_SDL.SDL_FreeSurface(li)
	return ffi.gc(li, _SDL.SDL_FreeSurface)
end
function sdl.surf.__image(file)
	return _IMG.IMG_Load(file)
end
function sdl.surf.__free(buf)
	_SDL.SDL_FreeSurface(buf)
end


-- thread
sdl.thread = {}
do
	local count
	function sdl.thread.new(fun, ptr)
		count = count+1
		return _SDL.SDL_CreateThread(fun, ptr) 
	end
	function sdl.thread.wait(th)
		count = count-1
		_SDL.SDL_WaitThread(th, nil)
	end
	function sdl.thread.count() return count end
end
function sdl.thread.mutex()
	local t = _SDL.SDL_CreateMutex()
	return ffi.gc(t, _SDL.SDL_DestroyMutex)
end
function sdl.thread.lock(mut) _SDL.SDL_mutexP(mut) end
function sdl.thread.unlock(mut) _SDL.SDL_mutexV(mut) end

--font
sdl.font = {f=nil, t=nil, s=12, c=255+255*256+255*256*256}
do
	local fonts = {}
	local function font(name, size)
		print("register new font: "..name.."["..size.."]")
		local t = _TTF.TTF_OpenFont(name, size)
		return ffi.gc(t, _TTF.TTF_CloseFont)
	end
	function sdl.font.type(name, size)
		if type(name)=="string" then
			if not fonts[name] then
				fonts[name] = {}
			end
			if not fonts[name][size] then
				fonts[name][size] = font(name, size)
				print()
			end
			sdl.font.f = fonts[name][size]
		else
			sdl.font.f = name
		end
	end -- optional size, create new font if not present
	function sdl.font.size(size)
		local type = sdl.font.t
		if not fonts[type][size] then
			fonts[type][size] = font(type, size)
			print("register new font: "..type.."["..size.."]")
		end
		sdl.font.f = fonts[type][size]
	end
end
function sdl.font.color(r, g, b)
	sdl.font.c = r+g*256+b*256*256
end
do
	local renderer =  _TTF.TTF_RenderText_Blended
	function sdl.font.quality(q)
		renderer = q=="high" and _TTF.TTF_RenderText_Blended or _TTF.TTF_RenderText_Solid
	end
	function sdl.font.text(str)
		local t = renderer(sdl.font.f, str, sdl.font.c)
		return ffi.gc(t, _SDL.SDL_FreeSurface)
	end
	function sdl.font.__text(str)
		return renderer(sdl.font.f, str, sdl.font.c)
	end
end

-- draw
-- TODO: check alpha handling
sdl.draw = {r=255,g=255,b=255,a=255, q="high"}
function sdl.draw.color(r, g, b, a)
	sdl.draw.r = r or 0
	sdl.draw.g = g or 0
	sdl.draw.b = b or 0
	sdl.draw.a = a or 255
end
function sdl.draw.quality(q) sdl.draw.q = q end
function sdl.draw.pGet(x, y)
	local p = sdl.surf.pixels
	local xmax = sdl.surf.current.w
	local ymax = sdl.surf.current.h
	if x>=0 and x<xmax and y>=0 and y<ymax then
		local b = p[(x + xmax*y)*4]
		local g = p[(x + xmax*y)*4+1]
		local r = p[(x + xmax*y)*4+2]
		local a = p[(x + xmax*y)*4+3]
		return r, g, b, a
	else
		return 0, 0, 0, 0
	end
end
function sdl.draw.pSet(x, y, r, g, b, a)
	local p = sdl.surf.pixels
	local xmax = sdl.surf.current.w
	local ymax = sdl.surf.current.h
	if x>=0 and x<xmax and y>=0 and y<ymax then
		p[(x + xmax*y)*4] = b or sdl.draw.b
		p[(x + xmax*y)*4+1] = g or sdl.draw.g
		p[(x + xmax*y)*4+2] = r or sdl.draw.r
		p[(x + xmax*y)*4+3] = a or sdl.draw.a
	end
end
function sdl.draw.pMix(x, y, r, g, b, a) -- not setting alpha
	local p = sdl.surf.pixels
	local a = (a or sdl.draw.a)/255
	local xmax = sdl.surf.current.w
	local ymax = sdl.surf.current.h
	if x>=0 and x<xmax and y>=0 and y<ymax then
		local b = (b or sdl.draw.b)*a + p[(x + xmax*y)*4]*(1-a)
		local g = (g or sdl.draw.g)*a + p[(x + xmax*y)*4+1]*(1-a)
		local r = (r or sdl.draw.r)*a + p[(x + xmax*y)*4+2]*(1-a)
		p[(x + xmax*y)*4] = (b>255 and 255) or (b<0 and 0) or b
		p[(x + xmax*y)*4+1] = (g>255 and 255) or (g<0 and 0) or g
		p[(x + xmax*y)*4+2] = (r>255 and 255) or (r<0 and 0) or r
	end
end
function sdl.draw.pAdd(x, y, r, g, b, a) -- not setting alpha
	local p = sdl.surf.pixels
	local a = (a or sdl.draw.a)/255
	local xmax = sdl.surf.current.w
	local ymax = sdl.surf.current.h
	if x>=0 and x<xmax and y>=0 and y<ymax then
		local b = (b or sdl.draw.b)*a + p[(x + xmax*y)*4]
		local g = (g or sdl.draw.g)*a + p[(x + xmax*y)*4+1]
		local r = (r or sdl.draw.r)*a + p[(x + xmax*y)*4+2]
		p[(x + xmax*y)*4] = (b>255 and 255) or (b<0 and 0) or b
		p[(x + xmax*y)*4+1] = (g>255 and 255) or (g<0 and 0) or g
		p[(x + xmax*y)*4+2] = (r>255 and 255) or (r<0 and 0) or r
	end
end
function sdl.draw.alpha(x, y, a)
	local xmax = sdl.surf.current.w
	local ymax = sdl.surf.current.h
	if y then
		local p = sdl.surf.pixels
		if x>=0 and x<xmax and y>=0 and y<ymax then
			p[(x + xmax*y)*4+3] = a
		end
	else
		_SDL.SDL_FillRect(sdl.surf.current, nil, x*256*256*256)
	end
end
function sdl.draw.fill(r, g, b, x, y, w, h)
	r = math.floor(r or sdl.draw.r)
	g = math.floor(g or sdl.draw.g)
	b = math.floor(b or sdl.draw.b)
	local a = sdl.draw.a
	w = w or sdl.surf.current.w
	h = h or sdl.surf.current.h
	_SDL.SDL_FillRect(sdl.surf.current, sdl.rect(x or 0,y or 0,w,h), b+g*256+r*256*256+a*256*256*256)
end
do
	local abs = math.abs
	local floor = math.floor
	local pAdd = sdl.draw.pAdd
	local function drawLine(x0, y0, x1, y1, r, g, b, a)	
		local steep = abs(y1-y0) > abs(x1-x0)
		if steep then x0, y0, x1, y1 = y0, x0, y1, x1 end
		if x0>x1 then x0, x1, y0, y1 = x1, x0, y1, y0 end
		
		local dx = x1-x0
		local dy = abs(y1-y0)
		local err = dx/2
		local y = y0
		local ystep = y0<y1 and 1 or -1
		
		for x = x0, x1 do
			pAdd(steep and y or x, steep and x or y, r, g, b, a)
			err = err - dy
			y = err<0 and y+ystep or y
			err = err<0 and err + dx or err
		end
	end
	local function ipart(x) return floor(x) end
	local function round(x) return ipart(x+0.5) end
	local function fpart(x) return x-floor(x) end
	local function rfpart(x) return 1-fpart(x) end
	local function invpixeladd(x,y,r,g,b,a) return pAdd(y,x,r,g,b,a) end
	local function drawLineHQ(x1, y1, x2, y2, r, g, b, a)
		--TODO: handle overlap of connected vertices in endpoint code
		--TODO: implement connected vertices draw (polyline)
		if x1==x2 and y1==y2 then return end 
		local dx = x2 - x1
		local dy = y2 - y1
		local pixeladd = pAdd
		if abs(dx) < abs(dy) then
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
		local xend = round(x1)
		local yend = y1 + gradient * (xend - x1)
		local xgap = rfpart(x1 + 0.5)
		local xpxl1 = xend --this will be used in the main loop
		local ypxl1 = ipart(yend)
		pixeladd(xpxl1, ypxl1, r, g, b, rfpart(yend)*xgap*a)
		pixeladd(xpxl1, ypxl1+1, r, g, b, fpart(yend)*xgap*a)
		local intery = yend + gradient --first y-intersection for the main loop
		xend = round (x2)
		yend = y2 + gradient * (xend - x2)
		xgap = fpart(x2 + 0.5)
		local xpxl2 = xend -- this will be used in the main loop
		local ypxl2 = ipart (yend)
		pixeladd(xpxl2, ypxl2, r, g, b, rfpart(yend)*xgap*a)
		pixeladd(xpxl2, ypxl2+1, r, g, b, fpart(yend)*xgap*a)
		for x = xpxl1+1, xpxl2-1 do
			pixeladd(x, ipart(intery), r, g, b, rfpart(intery)*a)
			pixeladd(x, ipart(intery)+1, r, g, b, fpart(intery)*a)
			intery = intery + gradient
		end
	end
	function sdl.draw.line(x1, y1, x2, y2)
		local r, g, b, a = sdl.draw.r, sdl.draw.g, sdl.draw.b, sdl.draw.a
		if x1==x2 then
			sdl.draw.fill(r,g,b,x1,y1,1,y2-y1+1)
		elseif y1==y2 then
			sdl.draw.fill(r,g,b,x1,y1,x2-x1+1,1)
		elseif sdl.draw.q=="high" then
			drawLineHQ(x1, y1, x2, y2, r, g, b, a)
		else
			drawLine(x1, y1, x2, y2, r, g, b, a)
		end
	end
end
function sdl.draw.box(x1, y1, x2, y2)
	sdl.draw.line(x1,y1,x1,y2)
	sdl.draw.line(x1,y1,x2,y1)
	sdl.draw.line(x1,y2,x2,y2)
	sdl.draw.line(x2,y1,x2,y2)
end
function sdl.draw.clear()
	_SDL.SDL_FillRect(sdl.surf.current, nil, 0)
end
function sdl.draw.text(x, y, str)
	local ttf_text = sdl.font.__text(str)
	sdl.surf.put(ttf_text, x, y)
	local x, y = ttf_text.w, ttf_text.h
	_SDL.SDL_FreeSurface(ttf_text)
	return x, y
end
function sdl.draw.image(x, y, file)
	local image = sdl.surf.__image(file)
	sdl.surf.put(image, x, y)
	local w, h = image.w, image.h
	_SDL.SDL_FreeSurface(image)
	return w, h
end

-- input
sdl.input = {refreshDelay = 1000/60}
sdl.input.x 	= 0				-- x-location
sdl.input.y 	= 0				-- y-location
sdl.input.dx 	= 0				-- x-movement
sdl.input.dy 	= 0				-- y-movement
sdl.input.cx 	= 0				-- x-click LMB
sdl.input.cy 	= 0				-- y-click LMB
sdl.input.button	= {}		-- pressed button
sdl.input.press		= {}		-- clicked button
sdl.input.release 	= {}		-- released button
sdl.input.quit 		= false		-- closed window
sdl.input.key 		= {sym = "", num = nil}		--keyboard input
sdl.input.mod 		= {			-- modifier keys
	alt = false,
	ctrl = false,
	shift = false,
	tab = false,
	space = false,
	up = false,
	down = false,
	left = false,
	right = false,
	}
sdl.input.interrupt = function() return false end --interrupt callback

do
	local event = ffi.new("SDL_Event")
	local startTime = 0
	function sdl.input.update(force)
		local self = sdl.input
		self.click = {false, false, false, false, false}
		self.release = {false, false, false, false, false}
		self.dx=0
		self.dy=0
		self.old_x = self.x
		self.old_y = self.y
		self.key = {sym = 0, num = nil}	
		while _SDL.SDL_PollEvent(event)==1 do
			if event.type==_SDL.SDL_MOUSEMOTION then
				self.dx = event.motion.x - self.old_x
				self.dy = event.motion.y - self.old_y
				self.x = event.motion.x
				self.y = event.motion.y
				self.b = event.motion.state
			elseif event.type==_SDL.SDL_MOUSEBUTTONDOWN then
				self.button[event.button.button] = true --update state
				self.click[event.button.button] = true
				if self.click[1] then --set the drag position if LMB is clicked
					self.cx = event.button.x
					self.cy = event.button.y
				end
			elseif event.type==_SDL.SDL_MOUSEBUTTONUP then
				self.button[event.button.button] = false
				self.release[event.button.button] = true
			elseif event.type==_SDL.SDL_KEYDOWN then
				self.key.sym = event.key.keysym.unicode
				self.key.num = event.key.keysym.sym
			elseif event.type==_SDL.SDL_QUIT then
				self.quit=true
			end
		end
	
		local key = _SDL.SDL_GetKeyState(nil)
		if key[273]==1 then self.mod.up=true else self.mod.up=false end
		if key[274]==1 then self.mod.down=true else self.mod.down=false end
		if key[276]==1 then self.mod.left=true else self.mod.left=false end
		if key[275]==1 then self.mod.right=true else self.mod.right=false end
		if key[303]==1 or key[304]==1 then self.mod.shift=true else self.mod.shift=false end
		if key[305]==1 or key[306]==1 then self.mod.ctrl=true else self.mod.ctrl=false end
		if key[307]==1 or key[308]==1 then self.mod.alt=true else self.mod.alt=false end
		if key[32]==1 then self.mod.space=true else self.mod.space=false end
	
		if sdl.time()-startTime < 1.25*sdl.input.refreshDelay then 
			while true do
				if sdl.time()-startTime > sdl.input.refreshDelay then
					startTime = startTime + sdl.input.refreshDelay
					break
				end
				if sdl.input.interrupt() or force=="force" then
					startTime = sdl.time()
					break
				end
				sdl.wait(0.1)
			end
		else
			startTime = sdl.time()
		end
	end
end

function sdl.update(x,y,w,h,force)
	if x and y then 
		sdl.screen.update(x,y,w,h)
		sdl.input.update(force)
	elseif x=="force" then
		sdl.screen.update()
		sdl.input.update("force")
	else
		sdl.screen.update()
		sdl.input.update()
	end
end

-- TODO: comprehensive tests

return sdl