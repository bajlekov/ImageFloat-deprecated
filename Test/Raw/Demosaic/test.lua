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

-- framework for testing demosaicing algorithms

-- setup stuff

math.randomseed(os.time())
local ffi = require("ffi")
require("global")

local sdl = require("Include.sdl")
local ppm = require("Tools.ppmtools")
local img = require("Tools.imgtools")

-- write/set demosaic function
package.path =  "./?.lua;"..package.path

local demosaic = require("Test.Raw.Demosaic.dlmmse")

-- load image
local i = ppm.toBuffer(ppm.readIM("~/test.png"))
local original = i:copy()
sdl.screen.set(i.x, i.y)

local function imshow(i)
	i:toSurface(sdl.screen.surf)
	sdl.update()

	while not sdl.input.key.any do
		sdl.input.update()
	end
end

imshow(i)

-- mosaic image
local function getC(x, y)
	return (x%2==1 and y%2==1 and "G") or
		(x%2==0 and y%2==0 and "G") or
		(x%2==0 and y%2==1 and "B") or
		(x%2==1 and y%2==0 and "R")
end

for x = 0, i.x-1 do
	for y = 0, i.y-1 do
		local c = getC(x, y)
		if c~="R" then i:a(x,y,0,0) end
		if c~="G" then i:a(x,y,1,0) end
		if c~="B" then i:a(x,y,2,0) end
	end
end

i = i:copyG()*3

imshow(i)

-- demosaic image
local j = demosaic(i)
sdl.tic()
local j = demosaic(i)
sdl.toc()

-- show result
imshow(j)
imshow(original)
imshow((j-original)*10+0.5)

-- output
ppm.writeIM(ppm.fromBuffer(j, "~/test_out.png"))