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

local ffi = require "ffi"
ffi.cdef(io.open('SDL.h', 'r'):read('*a'))

local SDL = ffi.load('sdl')

-- Define some constants that were in declares
local SDL_INIT_VIDEO = 0x20

-- Create the window
SDL.SDL_Init(SDL_INIT_VIDEO)
SDL.SDL_WM_SetCaption("SDL Test", "SDL Test");
local screen = SDL.SDL_SetVideoMode(320, 320, 32, 0x00000011)

colour = ffi.metatype("SDL_Color", {}) -- r, g, b, a
rectangle = ffi.metatype("SDL_Rect", {}) -- x, y, w, h

--pixbuf = screen.pixels
--pixbuf = ffi.cast("Uint32*", pixbuf)

--pixbuf[320*10+10]=255*256
--SDL.SDL_Flip(screen)

timer = SDL.SDL_GetTicks
print(timer())

SDL.SDL_Delay(5000)
SDL.SDL_Quit()

print("Thanks for Playing!")
