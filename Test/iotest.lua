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


ffi = require("ffi")
local sdl = require("sdltools")
local dbg = require("dbgtools")

local ppm = require("ppmtools")
local img = require("imgtools")

local buf = ppm.toBuffer(ppm.readFile("img16.ppm"))
dbg.gc()
print("*")
buf = img.scaleDownHQ(buf,1.6)
dbg.gc()
print("**")
--buf = img.scaleUpQuad(buf)
dbg.gc()
print("***")

tic()
buf:saveIM("test1.jpg")
print("*")
img.processIM(buf, "-colorspace HSL -channel lightness -equalize -colorspace RGB")
--buf:loadIM("test1.jpg")
buf:saveIM("test2.jpg")
toc()

--[[
tic()
buf:saveHD("test.buf")
toc("save")
tic()
buf:loadHD("test.buf")
toc("load")
tic()
buf:saveHD("test.buf")
toc("save")
tic()
buf:loadHD("test.buf")
toc("load")
tic()
buf:saveHD("test.buf")
toc("save")
--]]

--[[
os.execute("mkfifo test")

local f = io.open("test")

ffi.cdef[=[
	size_t fread ( void * ptr, size_t size, size_t count, FILE * stream );
	size_t fwrite ( const void * ptr, size_t size, size_t count, FILE * stream );
]=]

d = ffi.new("char[4]")

ffi.C.fread(d, 1, 8, f)

print(d[0], d[1], d[2], d[3])

os.execute("rm test")
--]]