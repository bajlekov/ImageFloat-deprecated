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


local function f(x)
	if x<-0.5 then return x+0.25 end
	if x>0.5 then return x-0.25 end
	if x<=0 then return -x^2 end
	if x>0 then return x^2 end
end

local function filter(i, t)
	-- remove coefficients close to 0
	
	for x = 0, i.x-1 do
		for y = 0, i.y-1 do
			for z = 0, i.z-1 do
				local v = i:i(x, y, z)
				i:a(x, y, z, f(v/t)*t)
			end
		end
	end
	
end

for x = 0, i.x-1 do
	for y = 0, i.y-1 do
		i:a(x,y,0, i:i(x,y,0)+math.random()*0.1)
		i:a(x,y,1, i:i(x,y,1)+math.random()*0.1)
		i:a(x,y,2, i:i(x,y,2)+math.random()*0.1)
	end
end

sdl.screen.set(i.x, i.y)
imshow(i)

local L, G = pyr.construct(i)
filter(L[0], 0.07)
filter(L[1], 0.03)
filter(L[2], 0.01)
local i = pyr.collapse(L)

imshow(i)
imshow(original)
imshow(i)
imshow(original)
imshow(i)
imshow(original)

--[[
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
filter(L[0], 0.005)
local i = pyr.collapse(L)

sdl.screen.set(i.x, i.y)
imshow(i)
--]]

