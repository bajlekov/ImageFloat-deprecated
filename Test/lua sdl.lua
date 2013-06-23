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

-- load the luajit ffi module
local ffi = require "ffi"

os.execute([[echo '#include <SDL.h> \n #include <SDL_ttf.h>' > stub.c]])
os.execute([[gcc -I /usr/include/SDL -E stub.c | grep -v '^#' > SDL.h]])

-- Parse the C API header
-- It's generated with:
--
-- echo '#include <SDL.h>' > stub.c
-- gcc -I /usr/include/SDL -E stub.c | grep -v '^#' > ffi_SDL.h

ffi.cdef(io.open('SDL.h', 'r'):read('*a'))

-- Load the shared object
local SDL = ffi.load('SDL')

-- Define some constants that were in declares
local SDL_INIT_VIDEO = 0x20

-- Make an easy constructor metatype
local rect = ffi.metatype("SDL_Rect", {})

-- Create the window
SDL.SDL_Init(SDL_INIT_VIDEO)
SDL.SDL_WM_SetCaption("SDL Test", "SDL Test");
local screen = SDL.SDL_SetVideoMode(800, 600, 0, 0)

-- Set up our event loop
local gameover = false
local event = ffi.new("SDL_Event")
while not gameover do
  -- Draw 8192 randomly colored rectangles to the screen
  for i = 0,800*600 do
    local r = rect(math.random(screen.w)-10, math.random(screen.h)-10,20,20)
    local color = math.random(0x1000000)
    SDL.SDL_FillRect(screen, r, color)
  end
  
  -- Flush the output
  SDL.SDL_Flip(screen)
  
  -- Check for escape keydown or quit events to stop the loop
  if (SDL.SDL_PollEvent(event)) then

    local etype=event.type
    
    if etype == SDL.SDL_QUIT then
      -- close button clicked
      gameover = true
      break
    end

    if etype == SDL.SDL_KEYDOWN then
      local sym = event.key.keysym.sym
      if sym == SDL.SDLK_ESCAPE then
        -- Escape is pressed
        gameover = true
        break
      end
    end

  end

end

-- When the loop finishes, clean up, print a message, and exit
SDL.SDL_Quit();
print("Thanks for Playing!");
