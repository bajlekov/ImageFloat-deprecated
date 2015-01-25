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

-- collection of SDL-dependent utilities
-- make available a C/ISPC library containing same functions with light lua wrappers
	-- prevents passing color and rect structs by value (not compiled)
	-- allows for compiled custom renderers using SIMD instructions

local ffi = require("ffi")
--local compile = require("Tools.compile")

-- TODO: load relevant SDL libs
--local _SDL = ffi.load("./Libraries/"..jit.os.."_"..jit.arch.."/SDL2.dll")

local function loadlib(lib)
	local path = "./Libraries/"..jit.os.."_"..jit.arch.."/"
	local file = lib
	if jit.os=="Windows" then
		file = file..".dll"
	elseif jit.os=="Linux" then
		file = "lib"..file..".so"
	end
	local p, l = pcall(ffi.load, file)
	if p then
		return l
	else
		local p, l = pcall(ffi.load, path..file)
		if p then
			return l
		else
			error(l)
		end
	end
end
if _G.global then
	global("loadlib", loadlib)
end

if jit.os=="Windows" then
	-- either load libraries or put them in the root directory
	loadlib("zlib1")
	loadlib("libfreetype-6")
	loadlib("libjpeg-9")
	loadlib("libpng16-16")
	loadlib("libtiff-5")
	loadlib("libwebp-4")
end

local _SDL = loadlib("SDL2")
local _TTF = loadlib("SDL2_ttf")
local _IMG = loadlib("SDL2_image")

-- read SDL header
local f = io.open("./Source/Include/ffi_SDL2.h", "r")
f = f or io.open("./Include/ffi_SDL2.h", "r")
f = f or io.open("/home/galin/Dropbox/ImageFloat lua recode/Source/Include/ffi_SDL2.h", "r")
ffi.cdef(f:read('*a'))
f:close()
-- TODO: put definitions into corresponding lua file

local sdl = {}

--- Rectangle structure
sdl.rect = ffi.typeof("SDL_Rect") -- x, y, w, h

--- Initialise SDL system
function sdl.init()
	_SDL.SDL_Init(29233)
	_TTF.TTF_Init()
	_IMG.IMG_Init(7) -- load JPG, PNG and TIFF support
end
--- Quit SDL system 
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

local SDL_INIT_VIDEO = 32
local SDL_WINDOW_SHOWN = 4
local SDL_PIXELFORMAT_ARGB8888 = 372645892
local SDL_TEXTUREACCESS_STREAMING = 1
local SDL_TEXTUREACCESS_STATIC = 0

--- Screen management functions
sdl.screen = {}
function sdl.screen.set(x, y)
	sdl.screen.window = ffi.gc(
		_SDL.SDL_CreateWindow("SDL2 Window", 0, 0, x, y, SDL_WINDOW_SHOWN),
		_SDL.SDL_DestroyWindow)
	sdl.screen.renderer = ffi.gc(
		_SDL.SDL_CreateRenderer(sdl.screen.window, -1, 0),
		_SDL.SDL_DestroyRenderer)
	sdl.screen.texture = ffi.gc(
		_SDL.SDL_CreateTexture(sdl.screen.renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, x, y),
		_SDL.SDL_DestroyTexture)
	
	sdl.screen.surf = sdl.surf.new(x, y)
	sdl.screen.width = x
	sdl.screen.height = y
	sdl.surf.attach(sdl.screen.surf)
	return sdl.screen.surf
end

-- TODO: function for resizing the screen

function sdl.screen.caption(title) _SDL.SDL_SetWindowTitle(sdl.screen.window, title) end
function sdl.screen.icon(file) _SDL.SDL_SetWindowIcon(sdl.screen.window, _IMG.IMG_Load(file)) end
function sdl.screen.pixbuf() return ffi.cast("uint8_t*", sdl.screen.surf.pixels) end
function sdl.screen.update(x, y, w, h)
	--if x then _SDL.SDL_UpdateRect(sdl.screen.surf, x, y, w, h)
	--else _SDL.SDL_Flip(sdl.screen.surf) end
	_SDL.SDL_UpdateTexture(sdl.screen.texture, NULL, sdl.screen.surf.pixels, sdl.screen.width*4)
	_SDL.SDL_RenderClear(sdl.screen.renderer)
	_SDL.SDL_RenderCopy(sdl.screen.renderer, sdl.screen.texture, NULL, NULL)
	_SDL.SDL_RenderPresent(sdl.screen.renderer)
end

function sdl.time() return _SDL.SDL_GetTicks() end
function sdl.wait(x) _SDL.SDL_Delay(x) end
do
	local time
	function sdl.tic() time = sdl.time() end
	function sdl.toc(str)
		print((str and str..": " or "")..(sdl.time()-time).."ms") 
	end
end
-- surface
sdl.surf = {current=nil, pixels=nil}
function sdl.surf.new(w, h)
	w = w or sdl.screen.width
	h = h or sdl.screen.height
	local t =_SDL.SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
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
	-- optional offset of origin buffer
	sdl.surf.copy(buf, sdl.surf.current, nil, sdl.rect(x or 0,y or 0,w or 0,h or 0))
end
function sdl.surf.pixbuf(buf)
	return ffi.cast("uint8_t*", buf and buf.pixels or sdl.surf.current.pixels)
end

function sdl.screen.get(x, y, w, h)
	w = w or sdl.screen.width
	h = h or sdl.screen.height
	local buf = sdl.surf.new(w, h)
	sdl.surf.copy(sdl.screen.surf, buf, sdl.rect(x or 0,y or 0,w,h), nil)
	return buf
end
function sdl.screen.put(buf, x, y, w, h)
	-- optional offset of origin buffer
	sdl.surf.copy(buf, sdl.screen.surf, nil, sdl.rect(x or 0,y or 0,w or 0,h or 0))
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
	local count = 0
	function sdl.thread.new(fun, ptr)
		count = count+1
		return _SDL.SDL_CreateThread(fun, "thread", ptr) 
	end
	function sdl.thread.wait(th)
		count = count-1
		
		--FIXME!!! wait thread fails on windows
		if jit.os=="Windows" then th = NULL end
		
		return _SDL.SDL_WaitThread(th, nil)
	end
	function sdl.thread.count() return count end
end
function sdl.thread.mutex()
	local t = _SDL.SDL_CreateMutex()
	return ffi.gc(t, _SDL.SDL_DestroyMutex)
end
function sdl.thread.lock(mut) return _SDL.SDL_mutexP(mut) end
function sdl.thread.unlock(mut) return _SDL.SDL_mutexV(mut) end
function sdl.thread.cond()
	local t = _SDL.SDL_CreateCond()
	return ffi.gc(t, _SDL.SDL_DestroyCond)
end
function sdl.thread.condSignal(cond) return _SDL.SDL_CondSignal(cond) end
function sdl.thread.condWait(cond, mut) return _SDL.SDL_CondWait(cond, mut) end
function sdl.thread.sem(n)
	local t = _SDL.SDL_CreateSemaphore(n or 0)
	return ffi.gc(t, _SDL.SDL_DestroySemaphore)
end
function sdl.thread.semPost(sem) return _SDL.SDL_SemPost(sem) end
function sdl.thread.semWait(sem) return _SDL.SDL_SemWait(sem) end


--font
sdl.font = {f=nil, t=nil, s=12, c=255+255*256+255*256*256}
do
	local fonts = {}
	local function font(name, size)
		-- discriminate between file name and font name!!
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
			end
			sdl.font.f = fonts[name][size]
			sdl.font.t = name
		else
			sdl.font.f = name
			sdl.font.t = name
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
	-- error thrown or hook called during recording
	function sdl.font.__text(str)
		return renderer(sdl.font.f, str, sdl.font.c)
	end
end

-- draw
-- TODO: check alpha handling
sdl.draw = {r=255,g=255,b=255,a=255, q="high"}
function sdl.draw.color(r, g, b, a)
	sdl.draw.r = math.floor(r or 0)
	sdl.draw.g = math.floor(g or 0)
	sdl.draw.b = math.floor(b or 0)
	sdl.draw.a = math.floor(a or 255)
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
function sdl.draw.fill(x, y, w, h)
	local r = sdl.draw.r
	local g = sdl.draw.g
	local b = sdl.draw.b
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
	local function invpixeladd(x,y,r,g,b,a) return sdl.draw.pMix(y,x,r,g,b,a) end
	local function drawLineHQ(x1, y1, x2, y2, r, g, b, a)
		--TODO: handle overlap of connected vertices in endpoint code
		--TODO: implement connected vertices draw (polyline)
		if x1==x2 and y1==y2 then return end 
		local dx = x2 - x1
		local dy = y2 - y1
		local pixeladd = sdl.draw.pMix
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
	function sdl.draw.line(x1, y1, w, h)
		local x2, y2 = x1+w, y1+h
		local r, g, b, a = sdl.draw.r, sdl.draw.g, sdl.draw.b, sdl.draw.a
		if x1==x2 then
			if y1>y2 then y2, y1 = y1, y2 end
			sdl.draw.fill(x1,y1,1,y2-y1+1)
		elseif y1==y2 then
			if x1>x2 then x2, x1 = x1, x2 end
			sdl.draw.fill(x1,y1,x2-x1+1,1)
		elseif sdl.draw.q=="high" then
			drawLineHQ(x1, y1, x2, y2, r, g, b, a)
		else
			drawLine(x1, y1, x2, y2, r, g, b, a)
		end
	end
end
function sdl.draw.box(x, y, w, h)
	sdl.draw.line(x,y,0,h)
	sdl.draw.line(x,y,w,0)
	sdl.draw.line(x,y+h,w,0)
	sdl.draw.line(x+w,y,0,h)
end
function sdl.draw.clear(surf)
	_SDL.SDL_FillRect(surf or sdl.surf.current, nil, 0)
end
function sdl.draw.text(x, y, str)
	local ttf_text = sdl.font.__text(str)
	sdl.surf.put(ttf_text, x, y)
	local x, y = ttf_text.w, ttf_text.h
	_SDL.SDL_FreeSurface(ttf_text)
	return x, y
end
function sdl.draw.textR(x, y, str) -- align text to right side
	local ttf_text = sdl.font.__text(str)
	sdl.surf.put(ttf_text, x-ttf_text.w, y)
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

-- TODO: rather deprecate cx, cy
sdl.input.cx 	= 0				-- x-click LMB
sdl.input.cy 	= 0				-- y-click LMB

sdl.input.wheel 	= {x=0, y=0}-- mouse wheel
sdl.input.pressure	= 0			-- touch input pressure
sdl.input.button	= {}		-- pressed button
sdl.input.click		= {}		-- clicked button
sdl.input.release 	= {}		-- released button
sdl.input.quit 		= false		-- closed window
sdl.input.key 		= false		--keyboard input
sdl.input.anykey	= false
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
function sdl.input.fps(x) sdl.input.refreshDelay = 1000/x end

do
	local floor = math.floor
	local xOld, yOld = 0, 0
	local function updateToudhPosition(input, event)
		input.x = floor(event.tfinger.x*sdl.screen.width)
		input.y = floor(event.tfinger.y*sdl.screen.height)
		input.pressure = event.tfinger.pressure
	end
	local event = ffi.new("SDL_Event")
	local startTime = 0
	function sdl.input.update(force)
		local input = sdl.input
		xOld = input.x
		yOld = input.y
		
		input.click[1] = false
		input.click[2] = false
		input.click[3] = false
		input.click[4] = false
		input.click[5] = false
		input.release[1] = false
		input.release[2] = false
		input.release[3] = false
		input.release[4] = false
		input.release[5] = false
		
		input.wheel.x = 0
		input.wheel.y = 0
		input.key = false
		input.anykey = false
		while _SDL.SDL_PollEvent(event)==1 do
			if event.type==_SDL.SDL_MOUSEMOTION then
				input.x = event.motion.x
				input.y = event.motion.y
			elseif event.type==_SDL.SDL_MOUSEBUTTONDOWN then
				local button = event.button.button
				input.button[button] = true
				input.click[button] = true
				if button==1 then
					input.cx = input.x
					input.cy = input.y
				end
			elseif event.type==_SDL.SDL_MOUSEBUTTONUP then
				local button = event.button.button
				input.button[button] = false
				input.release[button] = true
			elseif event.type==_SDL.SDL_MOUSEWHEEL then
				input.wheel.x = event.wheel.x
				input.wheel.y = event.wheel.y
			elseif event.type==_SDL.SDL_FINGERMOTION then
				updateToudhPosition(input, event)
			elseif event.type==_SDL.SDL_FINGERDOWN then
				input.button[1] = true
				input.click[1] = true
				updateToudhPosition(input, event)
				input.cx = input.x
				input.cy = input.y
			elseif event.type==_SDL.SDL_FINGERUP then
				input.button[1] = false
				input.release[1] = true
				updateToudhPosition(input, event)
			elseif event.type==_SDL.SDL_KEYDOWN then
				input.key = event.key.keysym.sym
				input.anykey = true
				-- print(ffi.string(_SDL.SDL_GetKeyName(self.key))..": "..tostring(event.key.keysym.scancode))
			elseif event.type==_SDL.SDL_QUIT then
				input.quit=true
			end
			-- TODO: efficient text editing
			-- TODO: add multi-finger support, map everything to LMB for now
			-- TODO: check wacom tablet support
			-- TODO: export doubleclick events
			-- TODO: joystick/controller events
			-- TODO: drag/drop support
			-- TODO: clipboard events
			-- TODO: window resize events
		end
		
		input.dx = input.x-xOld
		input.dy = input.y-yOld
		
		-- TODO: improve handling of modifiers!!! 
		local key = _SDL.SDL_GetKeyboardState(nil)
		if key[82]==1 then input.mod.up=true else input.mod.up=false end
		if key[81]==1 then input.mod.down=true else input.mod.down=false end
		if key[80]==1 then input.mod.left=true else input.mod.left=false end
		if key[79]==1 then input.mod.right=true else input.mod.right=false end
		if key[225]==1 or key[229]==1 then input.mod.shift=true else input.mod.shift=false end
		if key[224]==1 or key[228]==1 then input.mod.ctrl=true else input.mod.ctrl=false end
		if key[226]==1 or key[230]==1 then input.mod.alt=true else input.mod.alt=false end
		if key[44]==1 then input.mod.space=true else input.mod.space=false end
		
		if sdl.time()-startTime < 1.5*sdl.input.refreshDelay then 
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

-- keep input update separate as input and display processing are separate
function sdl.update(x,y,w,h)
	if x and y then 
		sdl.screen.update(x,y,w,h)
	else
		sdl.screen.update()
	end
end

-- TODO: comprehensive tests

return sdl