--[[
	Copyright (C) 2011-2012 G. Bajlekov

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

if not __global then
	__global = {}
	__global.libPath = "./Libraries/"..ffi.os.."_"..ffi.arch.."/"
	__global.setup = {}
	__global.setup.incPath = "./Source/Include/"
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

_SDL = loadlib('SDL')
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

SDL.colour = ffi.metatype("SDL_Color", {}) -- r, g, b, a
SDL.rectangle = ffi.metatype("SDL_Rect", {}) -- x, y, w, h

function SDL.font(name, size)
	local t = _TTF.TTF_OpenFont(name, size)
	return ffi.gc(t, _TTF.TTF_CloseFont) -- regiter for GC
end

function SDL.init()
	_SDL.SDL_Init(20)
	_TTF.TTF_Init()
	_IMG.IMG_Init(7)
end
function SDL.setScreen(x, y, b)
	SDL.screen = _SDL.SDL_SetVideoMode(x, y, b or 32, 40000000 + 1 + 4)
	SDL.screenWidth = x
	SDL.screenHeight = y
	return SDL.screen
end
function SDL.quit()
	_SDL.SDL_Quit()
	_TTF.TTF_Quit()
	_IMG.IMG_Quit()
end
function SDL.caption(t1, t2) _SDL.SDL_WM_SetCaption(t1, t2) end
function SDL.pixbuf() return ffi.cast("uint8_t*", SDL.screen.pixels) end

function SDL.flip() _SDL.SDL_Flip(SDL.screen) end
function SDL.flipRect(x, y, w, h) _SDL.SDL_UpdateRect(SDL.screen, x, y, w, h) end
function SDL.destroySurface(surf) _SDL.SDL_FreeSurface(ffi.gc(surf, nil)) end
function SDL.createSurface(width, height, flags)
	local fmt = SDL.screen.format
	local t =_SDL.SDL_CreateRGBSurface(flags, width, height,
	fmt.BitsPerPixel, fmt.Rmask, fmt.Gmask, fmt.Bmask, fmt.Amask)
	return ffi.gc(t, _SDL.SDL_FreeSurface) -- register for GC
end

function SDL.screenSurface()
	local t = SDL.createSurface(SDL.screen.w, SDL.screen.h, 0)
	return ffi.gc(t, _SDL.SDL_FreeSurface)
end
function SDL.blit(buf1, rect1, buf2, rect2) _SDL.SDL_UpperBlit(buf1, rect1, buf2, rect2) end
function SDL.screenCopy(buffer) SDL.blit(SDL.screen, nil, buffer, nil) end
function SDL.screenPaste(buffer) SDL.blit(buffer, nil, SDL.screen, nil) end
function SDL.screenPut(buffer, x, y)
	SDL.blit(buffer, nil, SDL.screen, SDL.rectangle(x, y, 0, 0))
end
function SDL.screenGet(buffer, x, y, w, h)
	SDL.blit(SDL.screen, SLD.rectangle(x, y, w or buffer.w, h or buffer.h), buffer, nil)
end

function SDL.destroyMutex(m) _SDL.SDL_DestroyMutex(m) end
function SDL.createMutex()
	-- handle mutexes manually!!
	return _SDL.SDL_CreateMutex()
	--return ffi.gc(t, _SDL.SDL_DestroyMutex) 
end

function SDL.lockMutex(m) _SDL.SDL_mutexP(m) end
function SDL.unlockMutex(m) _SDL.SDL_mutexV(m) end
function SDL.createThread(fun, ptr) 
	local t = _SDL.SDL_CreateThread(fun, ptr) 
	return ffi.gc(t, _SDL.SDL_KillThread)
end
function SDL.waitThread(t) _SDL.SDL_WaitThread(ffi.gc(t, nil), NULL) end

function SDL.input() return require("input")(_SDL) end
-- same for draw library to acces sdl!
function SDL.ticks() return _SDL.SDL_GetTicks() end
function SDL.wait(x) _SDL.SDL_Delay(x) end

-- FIXME: text allocation memory not cleaned! use automatic c cleaning!

function SDL.text(text, font, x, y, r, g, b, a)
	local ttf_text = _TTF.TTF_RenderText_Blended(font, text, SDL.colour(r or 255, g or 255, b or 255, a or 255));
	SDL.screenPut(ttf_text, x, y)
	local x, y = ttf_text.w, ttf_text.h
	_SDL.SDL_FreeSurface(ttf_text)
	return x, y
end

function SDL.textCreate(text, font, r, g, b, a)
	local t = _TTF.TTF_RenderText_Blended(font, text, SDL.colour(r or 255, g or 255, b or 255, a or 255));
	return ffi.gc(t, _SDL.SDL_FreeSurface)
end

function SDL.textPut(textObj, x, y)
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
	local li = _IMG.IMG_Load(file)
	local oi = _SDL.SDL_DisplayFormatAlpha( li )
	SDL.blit( oi, nil, SDL.screen, SDL.rectangle(x, y, 0, 0))
	_SDL.SDL_FreeSurface(li)
	_SDL.SDL_FreeSurface(oi)
end

function SDL.fillRect(buf, rect, col) _SDL.SDL_FillRect(buf, rect, col) end
function SDL.blankScreen() _SDL.SDL_FillRect(SDL.screen, nil, 0) end
function SDL.mapRGBA(surf, r, g, b, a)
	return _SDL.SDL_MapRGBA(surf.format, r, g, b, a)
end

__sdl = SDL --create global sdl table 
print("SDL loaded")
return SDL
