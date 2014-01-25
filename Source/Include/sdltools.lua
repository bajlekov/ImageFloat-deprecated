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

local ffi = require("ffi")

-- TODO: move lib loading to separate package!!!

do
  function global(k, v) -- assign new global
    rawset(_G, k, v or false)
  end
  local function newGlobal(t, k, v) -- disable globals
    error("global assignment not allowed: "..k)
  end
  setmetatable(_G, {__newindex=newGlobal})
end


if not __global then
	global("__global", {})
	__global.libPath = "./Libraries/"..ffi.os.."_"..ffi.arch.."/"
	__global.setup = {}
	__global.setup.incPath = "./Source/Include/"
	--__global.setup.incPath = "./Include/"
	__global.setup.optDraw = {}
	__global.setup.optDraw.fast = false
end

local function loadlib(lib)
	--DBprint("Deprecated, missing!")
	
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
	DBprint("Deprecated!")
	local t = _TTF.TTF_OpenFont(name, size)
	return ffi.gc(t, _TTF.TTF_CloseFont) -- regiter for GC
end

-- initialise SDL, check parameters
function SDL.init()
	DBprint("Deprecated!")
	_SDL.SDL_Init(20)
	_TTF.TTF_Init()
	_IMG.IMG_Init(7) -- load JPG, PNG and TIFF support
end
function SDL.quit()
	DBprint("Deprecated!")
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
	DBprint("Deprecated!")
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

function SDL.setCaption(title, toolbar) DBprint("Deprecated!") _SDL.SDL_WM_SetCaption(title, toolbar) end
function SDL.setIcon(file) DBprint("Deprecated!") _SDL.SDL_WM_SetIcon(_IMG.IMG_Load(file), null) end
function SDL.pixbuf() DBprint("Deprecated!") return ffi.cast("uint8_t*", SDL.screen.pixels) end

function SDL.flip() DBprint("Deprecated!") _SDL.SDL_Flip(SDL.screen) end
function SDL.flipRect(x, y, w, h) DBprint("Deprecated!") _SDL.SDL_UpdateRect(SDL.screen, x, y, w, h) end
function SDL.destroySurface(surf) DBprint("Deprecated!") _SDL.SDL_FreeSurface(ffi.gc(surf, nil)) end

function SDL.createSurface(width, height, flags)
	DBprint("Deprecated!")
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

function SDL.screenSurface()
	DBprint("Deprecated!")
	return SDL.createSurface(SDL.screen.w, SDL.screen.h)
end

function SDL.blit(buf1, rect1, buf2, rect2) DBprint("Deprecated!") _SDL.SDL_UpperBlit(buf1, rect1, buf2, rect2) end

function SDL.screenCopy(buffer) DBprint("Deprecated!") SDL.blit(SDL.screen, nil, buffer, nil) end
function SDL.screenPaste(buffer) DBprint("Deprecated!") SDL.blit(buffer, nil, SDL.screen, nil) end
function SDL.screenPut(buffer, x, y)
	DBprint("Deprecated!")
	SDL.blit(buffer, nil, SDL.screen, SDL.rect(x, y, 0, 0))
end
function SDL.screenGet(buffer, x, y, w, h)
	DBprint("Deprecated!")
	SDL.blit(SDL.screen, _SDL.rect(x, y, w or buffer.w, h or buffer.h), buffer, nil)
end

function SDL.destroyMutex(m) DBprint("Deprecated!") _SDL.SDL_DestroyMutex(ffi.gc(m, nil)) end
function SDL.createMutex()
	DBprint("Deprecated!")
	local t = _SDL.SDL_CreateMutex()
	return ffi.gc(t, _SDL.SDL_DestroyMutex) 
end

function SDL.lockMutex(m) _SDL.SDL_mutexP(m) end
function SDL.unlockMutex(m) _SDL.SDL_mutexV(m) end

function SDL.createThread(fun, ptr)
	DBprint("Deprecated!")
	-- NYI: unsupported C type conversion at sdltools.lua:198
	local t = _SDL.SDL_CreateThread(fun, ptr) 
	return ffi.gc(t, _SDL.SDL_KillThread)
end
function SDL.waitThread(t) _SDL.SDL_WaitThread(ffi.gc(t, nil), nil) end

function SDL.input() return require("Tools.input")(_SDL) end
function SDL.ticks() return _SDL.SDL_GetTicks() end
function SDL.wait(x) _SDL.SDL_Delay(x) end

local ttfRenderText
if __global.setup.optDraw.fast then
	ttfRenderText = _TTF.TTF_RenderText_Solid
else
	ttfRenderText = _TTF.TTF_RenderText_Blended
end

function SDL.text(text, font, x, y, r, g, b, a)
	DBprint("Deprecated!")
	local ttf_text = ttfRenderText(font, text, (r or 255)+256*(g or 255)+256*256*(b or 255)+256*256*256*(a or 255)) -- possibly not compiled due to complex struct??
	SDL.screenPut(ttf_text, x, y)
	local x, y = ttf_text.w, ttf_text.h
	_SDL.SDL_FreeSurface(ttf_text)
	return x, y
end

function SDL.textCreate(text, font, r, g, b, a)
	DBprint("Deprecated!")
	local t = ttfRenderText(font, text, (r or 255)+256*(g or 255)+256*256*(b or 255)+256*256*256*(a or 255)) -- possibly not compiled due to complex struct??
	return ffi.gc(t, _SDL.SDL_FreeSurface)
end

function SDL.loadImage(file)
	DBprint("Deprecated!")
	local li = _IMG.IMG_Load(file)
	local oi = _SDL.SDL_DisplayFormatAlpha(li)
	_SDL.SDL_FreeSurface(li)
	return ffi.gc(oi, _SDL.SDL_FreeSurface)
end

function SDL.icon(file, x, y)
	DBprint("Deprecated!")
	local li = _IMG.IMG_Load(file) -- replace with BMP load, not requiring SDL_image??
	local oi = _SDL.SDL_DisplayFormatAlpha( li )
	SDL.blit( oi, nil, SDL.screen, SDL.rect(x, y, 0, 0))
	_SDL.SDL_FreeSurface(li)
	_SDL.SDL_FreeSurface(oi)
end

function SDL.fillRect(buf, rect, col) DBprint("Deprecated!") _SDL.SDL_FillRect(buf, rect, col) end -- better interface with actual coordinates
function SDL.blankScreen() DBprint("Deprecated!") _SDL.SDL_FillRect(SDL.screen, nil, 0) end

global("__sdl", SDL) --create global sdl table
print("SDL loaded")
return SDL
