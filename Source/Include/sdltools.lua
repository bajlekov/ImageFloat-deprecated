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

local ffi = require("ffi")

-- TODO: move lib loading to separate package!!!

if not __global then
	__global = {}
	__global.libPath = "./Libraries/"..ffi.os.."_"..ffi.arch.."/"
	__global.setup = {}
	__global.setup.incPath = "./Source/Include/"
	__global.setup.fastDraw = false
end

--check native libs
--check user folder with libs
--check supplied libs (errs sometimes)

--set local paths!! different between packaged and developer versions!
local function loadlib(lib)
	
	local path = __global.libPath
		
	local libname
	if ffi.os=="Linux" then libname = "lib"..lib..".so" end
	if ffi.os=="Windows" then libname = lib..".dll" end
	local t
	local p
	p, t = pcall(ffi.load, lib)
	if not p then
		print("no native library found, trying user library "..lib)
		p, t = pcall(ffi.load, "./lib/usr/"..libname)
	end
	if not p then
		print("no user library found, trying supplied library "..lib)
		p, t = pcall(ffi.load, path..libname)
	end
	
	if p then
		return t
	else
		print("failed loading "..lib)
		return false
	end
end

--load libraries
if ffi.os=="Windows" then --maybe fix this?
	loadlib('libjpeg-8')
	loadlib('zlib1')
	loadlib('libfreetype-6')
	loadlib('libpng15-15')
	loadlib('libtiff-5')
end

global("_SDL", loadlib('SDL'))
local _SDL = _SDL
local _TTF = loadlib("SDL_ttf")
local _IMG = loadlib("SDL_image")

--[[
os.execute([=[echo '#include <SDL.h> \n #include <SDL_ttf.h> \n #include <SDL_image.h>' > stub.c]=])
os.execute([=[gcc -I /usr/include/SDL -E stub.c | grep -v '^#' > SDL.h]=])
--]]

ffi.cdef(io.open(__global.setup.incPath.."SDL.h", "r"):read('*a'))
io.close()

ffi.cdef([[
	SDL_mutex *SDL_CreateMutex();
	void SDL_DestroyMutex(SDL_mutex *mutex);
]])

local SDL = {}
local screen

SDL.color = ffi.typeof("SDL_Color") -- r, g, b, a
SDL.rect = ffi.typeof("SDL_Rect") -- x, y, w, h

function SDL.font(name, size)
	local t = _TTF.TTF_OpenFont(name, size)
	return ffi.gc(t, _TTF.TTF_CloseFont) -- regiter for GC
end

-- initialise SDL, check parameters
function SDL.init()
	_SDL.SDL_Init(20)
	_TTF.TTF_Init()
	_IMG.IMG_Init(7) -- load JPG, PNG and TIFF support
end
function SDL.quit()
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

-- create new screen of x, y dimensions
function SDL.setScreen(x, y, b)
	if b then
		-- FIXME
		debug.traceback()
		error("DEPRECATED PARAMETER B IN SDL.setScreen")
	end
	SDL.screen = _SDL.SDL_SetVideoMode(x, y, 32, SDL_DOUBLEBUF + SDL_HWSURFACE)
	SDL.screenWidth = x
	SDL.screenHeight = y
	return SDL.screen
end

-- set window caption and toolbar caption
function SDL.setCaption(title, toolbar) _SDL.SDL_WM_SetCaption(title, toolbar) end
-- set window icon
function SDL.setIcon(file) _SDL.SDL_WM_SetIcon(_IMG.IMG_Load(file), null) end
-- get pixel buffer location -> move to property of SDL?
function SDL.pixbuf() return ffi.cast("uint8_t*", SDL.screen.pixels) end

-- refresh full screen
function SDL.flip() _SDL.SDL_Flip(SDL.screen) end
-- refresh rectangle
function SDL.flipRect(x, y, w, h) _SDL.SDL_UpdateRect(SDL.screen, x, y, w, h) end
-- destroy surface
function SDL.destroySurface(surf) _SDL.SDL_FreeSurface(ffi.gc(surf, nil)) end

-- create surface
function SDL.createSurface(width, height, flags)
	if flags then
		-- FIXME
		debug.traceback()
		error("DEPRECATED PARAMETER FLAGS IN SDL.createSurface")
	end
	local fmt = SDL.screen.format
	local t =_SDL.SDL_CreateRGBSurface(SDL_SWSURFACE, width, height,
	fmt.BitsPerPixel, fmt.Rmask, fmt.Gmask, fmt.Bmask, fmt.Amask)
	return ffi.gc(t, _SDL.SDL_FreeSurface) -- register for GC
end

-- create new surface matching screen size
function SDL.screenSurface()
	return SDL.createSurface(SDL.screen.w, SDL.screen.h)
	-- surface is already registered in GC
	
	--local t = SDL.createSurface(SDL.screen.w, SDL.screen.h)
	--return ffi.gc(t, _SDL.SDL_FreeSurface)
end

-- copy portion of buffer to portion of second buffer (check sizes, simplify interface)
function SDL.blit(buf1, rect1, buf2, rect2) _SDL.SDL_UpperBlit(buf1, rect1, buf2, rect2) end

-- copy screen to buffer (whole)
function SDL.screenCopy(buffer) SDL.blit(SDL.screen, nil, buffer, nil) end
-- paste screen from buffer (whole)
function SDL.screenPaste(buffer) SDL.blit(buffer, nil, SDL.screen, nil) end
-- put buffer on screen at x,y
function SDL.screenPut(buffer, x, y)
	SDL.blit(buffer, nil, SDL.screen, SDL.rect(x, y, 0, 0))
end
-- get buffer from screen at x,y
function SDL.screenGet(buffer, x, y, w, h)
	SDL.blit(SDL.screen, _SDL.rect(x, y, w or buffer.w, h or buffer.h), buffer, nil)
end

-- garbage-collected mutexes
function SDL.destroyMutex(m) _SDL.SDL_DestroyMutex(ffi.gc(m, nil)) end
function SDL.createMutex()
	local t = _SDL.SDL_CreateMutex()
	return ffi.gc(t, _SDL.SDL_DestroyMutex) 
end

-- lock and unlock mutex
function SDL.lockMutex(m) _SDL.SDL_mutexP(m) end
function SDL.unlockMutex(m) _SDL.SDL_mutexV(m) end

-- garbage-collected thread creation
<<<<<<< HEAD
-- FIXME: currently not all threads are correctly closed, properly manage threads and avoid garbage collection need for threads!
function SDL.createThread(fun, ptr)
	local t = _SDL.SDL_CreateThread(fun, ptr) 
	return ffi.gc(t, _SDL.SDL_KillThread)
end
function SDL.waitThread(t) _SDL.SDL_WaitThread(ffi.gc(t, nil), nil) end
=======
function SDL.createThread(fun, ptr) 
	return _SDL.SDL_CreateThread(fun, ptr)
	--local t = _SDL.SDL_CreateThread(fun, ptr) 
	--return ffi.gc(t, _SDL.SDL_KillThread)
end
--function SDL.waitThread(t) _SDL.SDL_WaitThread(ffi.gc(t, nil), NULL) end
function SDL.waitThread(t) _SDL.SDL_WaitThread(t, nil) end
>>>>>>> 06b5c0e41895d01e58fff2a11a564ab171bb2d33

function SDL.input() return require("input")(_SDL) end
-- same for draw library to access sdl!

-- time functions
function SDL.ticks() return _SDL.SDL_GetTicks() end
function SDL.wait(x) _SDL.SDL_Delay(x) end

local ttfRenderText
if __global.setup.fastDraw then
	ttfRenderText = _TTF.TTF_RenderText_Solid
else
	ttfRenderText = _TTF.TTF_RenderText_Blended
end
-- _TTF.TTF_RenderText_Solid
-- _TTF.TTF_RenderText_Shaded
-- _TTF.TTF_RenderText_Blended

-- render text and put on screen
function SDL.text(text, font, x, y, r, g, b, a)
	local ttf_text = ttfRenderText(font, text, SDL.color(r or 255, g or 255, b or 255, a or 255));
	SDL.screenPut(ttf_text, x, y)
	local x, y = ttf_text.w, ttf_text.h
	_SDL.SDL_FreeSurface(ttf_text)
	return x, y
end

-- render text and save to buffer
function SDL.textCreate(text, font, r, g, b, a)
	local t = ttfRenderText(font, text, SDL.color(r or 255, g or 255, b or 255, a or 255));
	return ffi.gc(t, _SDL.SDL_FreeSurface)
end
-- paste rendered text, use screenput directly instead
function SDL.textPut(textObj, x, y)
	debug.traceback()
	error("DEPRECATED FUNCTION SDL.textPut")
	SDL.screenPut(textObj, x, y)
end

function SDL.loadImage(file)
	local li = _IMG.IMG_Load(file)
	local oi = _SDL.SDL_DisplayFormatAlpha(li)
	_SDL.SDL_FreeSurface(li)
	return ffi.gc(oi, _SDL.SDL_FreeSurface)
end

--buffer to new surface
--surface to new buffer

function SDL.icon(file, x, y)
	local li = _IMG.IMG_Load(file) -- replace with BMP load, not requiring SDL_image??
	local oi = _SDL.SDL_DisplayFormatAlpha( li )
	SDL.blit( oi, nil, SDL.screen, SDL.rect(x, y, 0, 0))
	_SDL.SDL_FreeSurface(li)
	_SDL.SDL_FreeSurface(oi)
end

function SDL.fillRect(buf, rect, col) _SDL.SDL_FillRect(buf, rect, col) end -- better interface with actual coordinates
function SDL.blankScreen() _SDL.SDL_FillRect(SDL.screen, nil, 0) end

--FIXME: deprecated
function SDL.mapRGBA(surf, r, g, b, a) -- create color in surface format
	debug.traceback()
	error("DEPRECATED FUNCTION SDL.mapRGBA")
	return _SDL.SDL_MapRGBA(surf.format, r, g, b, a)
end

global("__sdl", SDL) --create global sdl table
print("SDL loaded")
return SDL
