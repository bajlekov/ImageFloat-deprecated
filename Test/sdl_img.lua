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

ffi = require("ffi")

--setup
ffi.cdef(io.open("SDL.h", "r"):read("*a"))

SDL = ffi.load("./libsdl.so")
IMG = ffi.load("SDL_image")

SDL_INIT_VIDEO = 0x20

SDL.SDL_Init(SDL_INIT_VIDEO)

screen = SDL.SDL_SetVideoMode(720, 480, 32, 0x40000000 + 0x00000001 + 0x00000004) -- + 0x80000000)
pixbuf = ffi.cast("uint8_t*", screen.pixels)

SDL.SDL_WM_SetCaption("Test UI", "Test UI");

imload = IMG.IMG_Load("out_test.png")

print(imload.format.BitsPerPixel)
image = SDL.SDL_DisplayFormat(imload)
print(image.format.BitsPerPixel)

SDL.SDL_UpperBlit(imload, nil, screen, nil)
SDL.SDL_Flip(screen)
SDL.SDL_Delay(2000)

SDL.SDL_Quit()

