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

-- setup stuff
math.randomseed(os.time())
local ffi = require("ffi")
require("global")

local sdl = require("Include.sdl")
local ppm = require("Tools.ppmtools")
local img = require("Tools.imgtools")

package.path =  "./?.lua;"..package.path

local pyr = require("Test.Frequency.PYR")

-- load image
local i = ppm.toBuffer(ppm.readIM("~/test.png"))
local original = i:copy()

local function imshow(i)
	i:toSurface(sdl.screen.surf)
	sdl.update()

	while not sdl.input.key.any do
		sdl.input.update()
	end
end

local n = 6
local L, G = pyr.construct(i,n)
--L[n] = L[n]:new()+1/2
L[n-1] = L[n-1]*3
L[0] = L[0]*1/3
L[1] = L[1]*2/3
L[2] = L[2]*4/3
local i = pyr.collapse(L)

sdl.screen.set(i.x, i.y)
imshow(i)

local n = 6
local L, G = pyr.construct(i,n)
L[n-1] = L[n-1]/3
L[0] = L[0]*3
L[1] = L[1]*3/2
L[2] = L[2]*3/4
local i = pyr.collapse(L)

sdl.screen.set(i.x, i.y)
imshow(i)


