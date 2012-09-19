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
buf = img.scaleUpQuad(buf)
dbg.gc()
print("***")

---[[
tic()
buf:saveHD("test.buf")
toc("save")
tic()
buf:loadHD("test.buf")
toc("load")
---[[
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


local f = io.open("img16.ppm")

ffi.cdef[[
	size_t fread ( void * ptr, size_t size, size_t count, FILE * stream );
	size_t fwrite ( const void * ptr, size_t size, size_t count, FILE * stream );
]]
