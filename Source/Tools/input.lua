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
return function(SDL)
	local event = ffi.new("SDL_Event")

	SDL.SDL_EnableUNICODE(1)

	local input = {
		x 	= 0,					-- x-location
		y 	= 0,					-- y-location
		dx 	= 0,					-- x-movement
		dy 	= 0,					-- y-movement
		cx 	= 0,					-- x-click LMB
		cy 	= 0,					-- y-click LMB
		button 		= {},			-- pressed button
		click 		= {},			-- clicked button
		release 	= {},			-- released button
		quit 		= false,		-- closed window
		key 		= {sym = "", num = nil},		--keyboard input
		mod 		= {
			alt = false,
			ctrl = false,
			shift = false,
			tab = false,
			space = false,
			up = false,
			down = false,
			left = false,
			right = false,
			}				-- modifier keys
	}

	--refresh callback
	input.interrupt = function() return false end

	local refreshDelay = 1000/60
	local startTime = 0

	function input:update()
		self.click = {false, false, false, false, false} --reset clicks
		self.release = {false, false, false, false, false}
		self.dx=0
		self.dy=0
		self.old_x = self.x
		self.old_y = self.y
		self.key = {sym = "", num = nil}
		
		while SDL.SDL_PollEvent(event)==1 do --loop until all events are cleared, otherwise delays occur
		--if SDL.SDL_PollEvent(event)==1 then
			if event.type==SDL.SDL_MOUSEMOTION then
				self.dx = event.motion.x - self.old_x
				self.dy = event.motion.y - self.old_y
				self.x = event.motion.x
				self.y = event.motion.y
				self.b = event.motion.state
			elseif event.type==SDL.SDL_MOUSEBUTTONDOWN then
				self.button[event.button.button] = true --update state
				self.click[event.button.button] = true
				if self.click[1] then --set the drag position if LMB is clicked
					self.cx = event.button.x
					self.cy = event.button.y
				end
			elseif event.type==SDL.SDL_MOUSEBUTTONUP then
				self.button[event.button.button] = false
				self.release[event.button.button] = true
			elseif event.type==SDL.SDL_KEYDOWN then
				self.key.sym = event.key.keysym.unicode
				self.key.num = event.key.keysym.sym
			elseif event.type==SDL.SDL_QUIT then
				self.quit=true
			end
		end

		local key = SDL.SDL_GetKeyState(nil)
		if key[273]==1 then self.mod.up=true else self.mod.up=false end
		if key[274]==1 then self.mod.down=true else self.mod.down=false end
		if key[276]==1 then self.mod.left=true else self.mod.left=false end
		if key[275]==1 then self.mod.right=true else self.mod.right=false end

		if key[303]==1 or key[304]==1 then self.mod.shift=true else self.mod.shift=false end
		if key[305]==1 or key[306]==1 then self.mod.ctrl=true else self.mod.ctrl=false end
		if key[307]==1 or key[308]==1 then self.mod.alt=true else self.mod.alt=false end

		if key[32]==1 then self.mod.space=true else self.mod.space=false end

		--debug keyboard
		--if self.key.num then print(self.key.num==115) end

		--[[from sdl_keysym.h:
		SDLK_UP			= 273,
		SDLK_DOWN		= 274,
		SDLK_RIGHT		= 275,
		SDLK_LEFT		= 276,
		SDLK_RSHIFT		= 303,
		SDLK_LSHIFT		= 304,
		SDLK_RCTRL		= 305,
		SDLK_LCTRL		= 306,
		SDLK_RALT		= 307,
		SDLK_LALT		= 308,
		SDLK_RMETA		= 309,
		SDLK_LMETA		= 310,
		SDLK_LSUPER		= 311,		/**< Left "Windows" key */
		SDLK_RSUPER		= 312,		/**< Right "Windows" key */
		SDLK_MODE		= 313,
		--]]

		--[[
		SDLK_a = 97,
		SDLK_b = 98,
		SDLK_c = 99,
		SDLK_d = 100,
		SDLK_e = 101,
		SDLK_f = 102,
		SDLK_g = 103,
		SDLK_h = 104,
		SDLK_i = 105,
		SDLK_j = 106,
		SDLK_k = 107,
		SDLK_l = 108,
		SDLK_m = 109,
		SDLK_n = 110,
		SDLK_o = 111,
		SDLK_p = 112,
		SDLK_q = 113,
		SDLK_r = 114,
		SDLK_s = 115,
		SDLK_t = 116,
		SDLK_u = 117,
		SDLK_v = 118,
		SDLK_w = 119,
		SDLK_x = 120,
		SDLK_y = 121,
		SDLK_z = 122,
		]]

		--timer delay for 60fps
		if __sdl.ticks()-startTime < 1.25*refreshDelay then 
			while true do
				if __sdl.ticks()-startTime > refreshDelay then
					startTime = startTime + refreshDelay
					break
				end
				if input.interrupt() then
					startTime = __sdl.ticks()
					break
				end
				SDL.SDL_Delay(0.1)
			end
		else
			startTime = __sdl.ticks()
		end

		--help in detecting unreferenced cdata
		--collectgarbage("collect")
	end

	return input
end
