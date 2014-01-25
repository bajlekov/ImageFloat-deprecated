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
ffi.cdef[[
	int SDL_Init(uint32_t flags);
	typedef struct SDL_Window SDL_Window;
	SDL_Window* SDL_CreateWindow(const char *title, int x, int y, int w, int h, uint32_t flags);
	void SDL_DestroyWindow(SDL_Window * window);
	void SDL_Quit(void);
	void SDL_Delay(uint32_t ms);
]]
local sdl = ffi.load("SDL2")
print("library loaded")
local SDL_INIT_VIDEO = 0x00000020
local SDL_WINDOW_SHOWN = 0x00000004
print(sdl.SDL_Init(SDL_INIT_VIDEO))
local window = sdl.SDL_CreateWindow(
	"An SDL2 window",
	0, 0,
	640, 480,
	SDL_WINDOW_SHOWN
)
print(window)
sdl.SDL_Delay(300)
sdl.SDL_DestroyWindow(window)
sdl.SDL_Quit()
print("end")

--print(0x00000001 + 0x00000010 + 0x00000020 + 0x00000200 + 0x00001000 + 0x00002000 + 0x00004000 + 0x00100000)

