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

-- setup paths if not loading bytecode
package.path = 	"./?.lua;"..
"./Setup/?.lua;"..
"./Build/?.lua;"..
"./Draw/?.lua;"..
"./Include/?.lua;"..
"./Interop/?.lua;"..
"./Math/?.lua;"..
"./Node/?.lua;"..
"./Ops/?.lua;"..
"./Threads/?.lua;"..
"./Tools/?.lua;"..package.path

local ffi = require("ffi")

-- TODO internal console for debugging etc.
-- TODO	currently not working with luaJIt 2.1 alpha
-- FIXME nodes with undefined inputs crash!!!!!!!!!
-- FIXME segfault with GC on

print([[
ImageFloat  Copyright (C) 2011-2012 G.Bajlekov
This program comes WITHOUT ANY WARRANTY.
This is free software, and you are welcome to redistribute it under the conditions of the GNU General Public License version 3.
]])

--load required libraries
__global = {preview = true, error=false, info=true}
local __global = __global
__global.setup = require("IFsetup")
__global.setup.bufferPrecision = __global.setup.bufferPrecision or {"float", 4}

-- setup paths for libraries and resources (do that for threads too!!)
__global.libPath = __global.setup.libPath or "../Libraries/"..ffi.os.."_"..ffi.arch.."/"
__global.imgPath = __global.setup.imgPath or "../Resources/Images/"
__global.ttfPath = __global.setup.ttfPath or "../Resources/Fonts/"

math.randomseed(os.time())

local sdl = require("sdltools")
local lua = require("luatools")
local dbg = require("dbgtools")
local ppm = require("ppmtools")
local img = require("imgtools")

--put often-used libs in a global namespace and index from there, not as independent globals
__dbg = dbg
__img = img

lua.threadInit(arg and arg[2] or __global.setup.numThreads, __global.setup.threadPath)

print(arg and arg[2] or __global.setup.numThreads, __global.setup.threadPath)

__global.loadFile = arg and arg[1] or __global.setup.imageLoadPath..__global.setup.imageLoadName
__global.saveFile = __global.setup.imageSavePath..__global.setup.imageSaveName

-- load image

print("Loading image: "..__global.setup.imageLoadName)
local readFunTable = {
	PPM = ppm.readFile,
	IM = ppm.readIM,
	RAW = ppm.readRAW,
}
local readFun = readFunTable[__global.setup.imageLoadType]

local bufI = ppm.toBuffer(readFun(__global.loadFile, __global.setup.imageLoadParams))
local bufO = bufI:new()
print(bufI.x, bufI.y)

print(collectgarbage("setpause", 100))
print(collectgarbage("setstepmul"))

for i = 1, 10000 do
-- calling threaded code itself does not cause memory leaks... restructure coroutine code!
bufI = bufI:copy() -- issue is in slow garbage collection, lots of garbage created from new buffers
bufO = bufI:new()
lua.threadSetup({bufI, bufO})
lua.threadRun("ops", "copy")
lua.threadWait()
-- dbg.gc() -- reduces memory usage significantly, somehow otherwise something is not properly cleaned
-- however, memory increases even when garbage collection in main program is enabled!
print(collectgarbage("count"))
end

print(collectgarbage("setpause"))
print(collectgarbage("setstepmul"))

-- after tuning the garbage collector, problems with memory in main app persist

print("Done")
print(bufI:get(1,2,2), bufO:get(1,2,2))







