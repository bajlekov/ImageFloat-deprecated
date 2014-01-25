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

--setup libs
local ffi = require("ffi")
local sdl = require("sdltools")
local lua = require("luatools")
local dbg = require("dbgtools")
local ppm = require("ppmtools")
local img = require("imgtools")


sdl.init()
lua.threadInit(8, "thread_func.lua")
print("using "..lua.numCores.." threads...")

local d = ppm.readFile("img16.ppm")
local buf = ppm.toBuffer(d)
sdl.caption("LuaImage ["..d.name.."]", "LuaImage")
buf = img.scaleDownHQ(buf,3)
local bufout = buf:new()
local buffac = buf:new()
buffac:pixelOp(	function(a,b,c,x,y)
	return x/buffac.x, 1-(y/buffac.y), 0
end )

--create nodetree-to-script compiler!!
for i=1,100 do
	lua.threadSetup({buf, bufout}, 1, 1)
	lua.threadRunWait("ops", "copy")
	
	tic()
	bufout:csConvert("LRGB")
	toc()
	tic()
	--lua.threadSetup({bufout, img.newBuffer{1,0,0}, buffac, img.newBuffer{0,0,1}, bufout}, 4, 1)
	--lua.threadRunWait("ops", "mixer")
	lua.threadSetup({buf, bufout}, 1, 1, {5})
	lua.threadRunWait("ops", "transform", "rot")
	toc("rot")
	tic()
	bufout:csConvert("SRGB")
	toc()
end



--Prototype:
--lua.threadSetup({buf, img.newBuffer({1,0,0}), img.newBuffer({0,1,0}), img.newBuffer({0,1,0}), bufout}, 4, 1)
--lua.threadRunWait("ops", "mixer")

d = ppm.fromBuffer(bufout, 16)
d.name = "out_test.ppm"
ppm.writeFile(d)

sdl.setScreen(buf.x, buf.y, 32)
bufout:toScreen()
sdl.flip()

input = sdl.input()
while not input.quit do
	input:update()
end
lua.threadQuit()
sdl.quit()