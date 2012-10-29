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