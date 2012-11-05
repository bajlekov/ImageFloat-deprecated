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

local ffi = ffi

-- setup paths if not loading bytecode
package.path = 	"./Build/?.lua;"..
				"./Draw/?.lua;"..
				"./Include/?.lua;"..
				"./Interop/?.lua;"..
				"./Math/?.lua;"..
				"./Node/?.lua;"..
				"./Ops/?.lua;"..
				"./Threads/?.lua;"..
				"./Tools/?.lua;"..package.path

local ffi = require("ffi")
_G.ffi = ffi

--	refactor code
--	fix add-node

-- 		segfault on just HCLAB color input to output!! only parallel processing in output node ?? still
-- 		connect color HCLAB to output, then switch to split directly ?? still

--	check efficiency of passing processing arguments in buffers?


print([[
ImageFloat  Copyright (C) 2011-2012 G.Bajlekov
This program comes WITHOUT ANY WARRANTY.
This is free software, and you are welcome to redistribute it under the conditions of the GNU General Public License version 3.
]])

--load required libraries
__global = {preview = true, error=false, info=true}
local __global = __global
__global.setup = require("IFsetup")

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

--local function file_exists(name)
--   local f=io.open(name,"r")
--   if f~=nil then io.close(f) return true else return false end
--end

--if running source code then build bytecode, otherwise don't
--check whether running source or bytecode
--if arg[0]:sub(#arg[0]-3, #arg[0])==".lua" then os.execute("./build.sh") end
lua.threadInit(arg and arg[2] or __global.setup.numThreads, __global.setup.threadPath)

--initialise threads, display, input, fonts
--print("using "..lua.numCores.." threads...")
sdl.init()
--create init file
sdl.setScreen(__global.setup.windowSize[1], __global.setup.windowSize[2], 32)
sdl.caption("ImageFloat...loading", "ImageFloat");
require("draw")

__global.loadFile = arg and arg[1] or __global.setup.imageLoadPath..__global.setup.imageLoadName
__global.saveFile = __global.setup.imageSavePath..__global.setup.imageSaveName

local mouse = sdl.input()
mouse.interrupt = lua.threadDone -- interface refresh call on thread done ...
local node = require("node")

--move to node?
require("nodeCreate")(node, img)
node:add("Input")
node:add("Rotate")
node:add("Mixer")
node:add("Add")
node:add("Split")
node:add("Decompose")
node:add("WhiteBalance")
node:add("Compose")
--node:add("ColorSpace")
node:add("Output")
node:add("Color RGB")
node:add("Color LCH")

node:setInput(mouse)

-- move to fonttools?
font = {}
font.normal = sdl.font(__global.ttfPath.."UbuntuR.ttf", 11)
font.big = sdl.font(__global.ttfPath.."UbuntuR.ttf", 15)

--draw initial
node:draw()
sdl.flip()

--read file
print("Loading image: "..__global.setup.imageLoadName)
local readFunTable = {
	PPM = ppm.readFile,
	IM = ppm.readIM,
	RAW = ppm.readRAW,
}
local readFun = readFunTable[__global.setup.imageLoadType]

local imageTemp = ppm.toBuffer(readFun(__global.loadFile, __global.setup.imageLoadParams))
local reduceFactor = (math.max(math.ceil(imageTemp.x/(__global.setup.windowSize[1]-390)),
	math.ceil(imageTemp.y/(__global.setup.windowSize[2]-40))))
local bufO = img.scaleDownHQ(imageTemp, reduceFactor)
local bufZ = ppm.toBufferCrop(readFun(__global.loadFile, __global.setup.imageLoadParams), bufO.x, bufO.y)
sdl.caption("ImageFloat [ "..__global.loadFile.." ]", "ImageFloat");
imageTemp = nil

print(bufO.x, bufO.y)
print(bufZ.x, bufZ.y)

--working buffer pointers
local buf
local bufout
local surf

--allocating buffers for fast or regular preview
local bufS = img.scaleDownHQ(bufO,4)
local bufoutS = bufS:new()
local surfS = img.toSurface(img.scaleUpQuad(bufS:new()))

local bufL = bufO
local bufoutL = bufL:new()
local surfL = img.toSurface(bufL:new())


--toggles buffers between cropped and scaled
do
	crop = false
	function bufZoom(zoom)
		if zoom==nil then
			crop = not crop
		else
			crop = zoom
		end
		if crop then
			bufS = img.scaleDownHQ(bufZ, 4)
			bufL = bufZ
			crop = true
		else
			bufS = img.scaleDownHQ(bufO, 4)
			bufL = bufO
			crop = false
		end
	end
end

--set desired working buffers
function bufSet(size)
	if size=="S" then
		__global.preview = true
		buf = bufS
		bufout = bufoutS
		surf = surfS
	else
		__global.preview = false
		buf = bufL
		bufout = bufoutL
		surf = surfL
	end
end

bufSet("L")

--use a coroutine which interrupts for interface updates
local cp
local coProcess
local funProcess
local calcUpdate

local hist = require("histogram")

function funProcess()
	cp=1							-- reset processing coroutine
	node[1].bufIn = buf 					--initialise node, move to other location!
	
	-- find output node, make selector for this.../one fixed output node
	local outNode for k, v in ipairs(node) do if v.procFlags.output then outNode=k end end
	
	if outNode==nil then error("no output node! FIXME") end --error if no output node found
	
	node[outNode].bufOut = buf:new()	-- place black screen if output node is not connected
	
	for k, v in ipairs(node.execOrder) do
		if not __global.preview then print("Op "..k..", Node "..v.." - "..node[v].ui.name) end
		node[v]:processRun(k)
		--print("node:", k, v)
	end

	bufout = node[outNode].bufOut

	--update previews
	---[[
	if __global.preview then
		img.toSurfaceQuad(bufout, surf)
	else
		img.toSurface(bufout, surf)
		bufoutS = img.scaleDownHQ(bufout,4) --if full process then also update preview buffer
		img.toSurfaceQuad(bufoutS, surfS)
		-- why is bufoutL not used??
	end
	--]]


	hist.calculate(bufout)

	toc("Process in ")
	tic()
	coroutine.yield(-1)
end

--function updating the image and checking when processing should be advanced
local function imageProcess(flag)
	if (flag=="process" and (lua.threadDone() or cp==-1)) or cp=="pass" then
		if cp==-1 then coProcess=coroutine.wrap(funProcess) end -- if processing is done then start again
		cp = coProcess() -- go to next step
	end

	sdl.screenPut(surf, 350, 20)

	-- put histogram buffer
	for i=1, 255 do
	--wrap graphics
		--dbg.warn("HISTOGRAM DRAWING")
		-- hist to buffer after calc, only put to screen here!!
		-- why isn't background always drawn below histogram??
		vLineAdd(i+10, __global.setup.windowSize[2]-10 - math.floor(hist.r[i]), math.floor(hist.r[i]), 128, 32, 32)
		vLineAdd(i+10, __global.setup.windowSize[2]-10 - math.floor(hist.g[i]), math.floor(hist.g[i]), 32, 128, 32)
		vLineAdd(i+10, __global.setup.windowSize[2]-10 - math.floor(hist.b[i]), math.floor(hist.b[i]), 32, 32, 128)

		vLineAdd(i+10, __global.setup.windowSize[2]-110 - math.floor(hist.l[i]), math.floor(hist.l[i]), 128, 128, i/2)
		vLineAdd(i+10, __global.setup.windowSize[2]-210 - math.floor(hist.c[i]), math.floor(hist.c[i]), 128, i/2, 128)
		local r, g, b = HtoRGB(i/255)
		vLineAdd(i+10, __global.setup.windowSize[2]-310 - math.floor(hist.h[i]), math.floor(hist.h[i]), r*128, g*128, b*128)
	end

		vLineAdd(266, __global.setup.windowSize[2]-410, 400, 64, 64, 64)
		vLineAdd(10, __global.setup.windowSize[2]-410, 400, 64, 64, 64)

		vLineAdd(197, __global.setup.windowSize[2]-310, 300, 16, 16, 16)
		vLineAdd(147, __global.setup.windowSize[2]-310, 300, 16, 16, 16)
		vLineAdd(110, __global.setup.windowSize[2]-310, 300, 16, 16, 16)
		vLineAdd(83, __global.setup.windowSize[2]-310, 300, 16, 16, 16)
		vLineAdd(64, __global.setup.windowSize[2]-310, 300, 16, 16, 16)
		vLineAdd(49, __global.setup.windowSize[2]-310, 300, 16, 16, 16)

		vLineAdd(53, __global.setup.windowSize[2]-410, 100, 16, 16, 16)
		vLineAdd(95, __global.setup.windowSize[2]-410, 100, 16, 16, 16)
		vLineAdd(138, __global.setup.windowSize[2]-410, 100, 16, 16, 16)
		vLineAdd(180, __global.setup.windowSize[2]-410, 100, 16, 16, 16)
		vLineAdd(223, __global.setup.windowSize[2]-410, 100, 16, 16, 16)

		hLineAdd(10, __global.setup.windowSize[2]-411, 257, 64, 64, 64)
		hLineAdd(10, __global.setup.windowSize[2]-10, 257, 64, 64, 64)

		__sdl.text("Hue", font.normal, 12, __global.setup.windowSize[2]-405)
		__sdl.text("Chroma", font.normal, 12, __global.setup.windowSize[2]-305)
		__sdl.text("Luma", font.normal, 12, __global.setup.windowSize[2]-205)
		__sdl.text("RGB", font.normal, 12, __global.setup.windowSize[2]-105)
end

--register imageProcess
node:setImageProcess(imageProcess)

--eventually move to node lib with callbacks for some functions
function node:click()
	for i, n in ipairs(self.order) do --for each node on the list
		if self[n].ui:click("node") then --if node is clicked
			if i~=1 then self:focus(n) end --if node is not first then focus
			local p, t = self[n].ui:click() --get info on click

			if t=="connL" then
				if self[n].conn_i[p]~=nil then --if port exists
					if self[n].conn_i[p].node~=nil then --if allready connected
						local nn = self[n].conn_i[p].node --find source node and port
						local pp = self[n].conn_i[p].port
						self:focus(nn)	--focus source node
						self:noodleDrag(nn, pp) --noodle-drag from source node
					end
					lua.threadStop() -- stop processing
					self:calcLevels()
					calcUpdate = true
					bufSet("L")
					coProcess=coroutine.wrap(funProcess) -- reset coroutine
					coProcess()
					self:draw()
				end
			elseif t=="connR" then
				if self[n].conn_o[p]~=nil then --if port exists
					self:noodleDrag(n, p)
					lua.threadStop() -- stop processing
					self:calcLevels()
					
					calcUpdate = true
					bufSet("L")
					coProcess=coroutine.wrap(funProcess) -- reset coroutine
					coProcess()
					self:draw()
				end
			elseif t=="title" then
				if self.mouse.x>=self[n].ui.x+130 and --delete node
						self.mouse.x<=self[n].ui.x+146 and
						self.mouse.y>=self[n].ui.y+2 and
						self.mouse.y<=self[n].ui.y+18 then
					self:remove(n)
					self:draw()
					self:calcLevels()
					bufSet("L")
					coProcess=coroutine.wrap(funProcess) -- reset coroutine
					coProcess()
				else
					self:nodeDrag(n)
				end
			elseif t=="params" then
				local type = self[n].param[p].type
				if type=="value" then
					lua.threadStop() --stops all processing threads and returns after they have stopped (in case processing is still going on)
					bufSet("S")
					coProcess=coroutine.wrap(funProcess) --create coroutine process
					cp = coProcess()	--start coroutine process
					
					self:paramDrag(n, p) --loop while dragging slider
					
					lua.threadStop() -- stop processing
					calcUpdate = true
					bufSet("L")
					coProcess=coroutine.wrap(funProcess) -- reset coroutine
					coProcess()
				elseif type=="int" then

				elseif type=="enum" then

				elseif type=="bool" then

				elseif type=="text" then
					self:draw()
				end
			end
			break
		end
	end
end

--main loop

calcUpdate = true
node:calcLevels() --!! setup working levels in node setup allready!!
node:draw()
sdl.flip()
while true do
	mouse:update()
	
	-- some simple interface handling, move to separate function!
	if mouse.key.num==115 then--"S"
		print("Saving image: "..__global.saveFile)
		-- why is bufoutL never filled? use bufout as it's always set to bufoutL?
		local writeFunTable = {
			PPM = ppm.writeFile,
			IM = ppm.writeIM,
		}
		local writeFun = writeFunTable[__global.setup.imageSaveType]

		d = ppm.fromBuffer(bufout)
		d.name = __global.saveFile
		writeFun(d, __global.setup.imageSaveParams)
		d = nil
	end
	if mouse.key.num==122 then--"Z"
		bufZoom()
		lua.threadStop() -- stop processing		
		calcUpdate = true
		bufSet("L")
		coProcess=coroutine.wrap(funProcess) -- reset coroutine
		coProcess()
		node:draw()
	end
	if mouse.key.num==105 then--"I"
		__global.info = not __global.info
		node:draw()
	end
	if mouse.key.num==113 then--"Q"
		os.exit()
	end



	if mouse.click[1] then
		node:click() --run mouse updating loop till mouse released
	else
		--draw progress bar
		if calcUpdate then
		 	local size = buf.x
			local progress = math.floor(size*lua.threadGetProgress())
			boxFill(350,8,350+progress,12,128,128,128)
			boxFill(350+progress,8,350+size,12,32,32,32)
			sdl.flip()
		end

		--force one last update before quitting
		--not called after input-output connection!!!
		if (lua.threadDone() or (calcUpdate and cp==-1)) or cp=="pass" then
			if cp==-1 then
				lua.threadStop()
				calcUpdate = false
				--Histogram
				--slow hist calc...multithreaded and in separate instance + interruptable!
				--effect of partly slow cpu speedup and inefficient compilation. flushing compiled code avoids 1000ms+ times
				--still, perform non-blocking and possibly threaded!
					--improve interface for non-blocking ops with extra data passing!
					--additional non-MT thread for non-blocking ops?
				--img.toSurface(bufout, surf)
				node:draw() -- does not redraw automatically
				--node:draw()
			else
				if cp~="pass" then lua.threadWait() end
				cp = coProcess()
			end
		end
	end
	if mouse.quit then break end
end


--cleanup
lua.threadStop()
sdl.destroyFont(font.normal)
sdl.destroyFont(font.big)
node:cleanup()

lua.threadQuit()
sdl.quit()

