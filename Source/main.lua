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

print([[
ImageFloat  Copyright (C) 2011-2012 G.Bajlekov
This program comes WITHOUT ANY WARRANTY.
This is free software, and you are welcome to redistribute it under the conditions of the GNU General Public License version 3.
]])

-- setup paths if not loading bytecode
require("path")
local ffi = require("ffi")
__global = require("global")
local __global = __global -- local reference to global table
__global.loadFile = arg and arg[1] or __global.loadFile
collectgarbage("setpause", 100) -- force quicker garbage collection to prevent heaping up
math.randomseed(os.time())

-- TODO internal console for debugging etc.
-- TODO	currently not working with luaJIt 2.1 alpha
-- FIXME memory consumption rises above 300MB, leads to unpredicted behaviour and crashes

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
sdl.init()
sdl.setScreen(__global.setup.windowSize[1], __global.setup.windowSize[2], 32)
sdl.caption("ImageFloat...loading", "ImageFloat");

-- TODO refactor draw
require("draw")
local mouse = sdl.input()
local interface = require("interface")
interface.setInput(mouse)
mouse.interrupt = lua.threadDone -- interface refresh call on thread done ...

-- TODO: move to fonttools, local font reference
font = {}
font.normal = sdl.font(__global.ttfPath.."UbuntuR.ttf", 11)
font.mono = sdl.font(__global.ttfPath.."dejavuM.ttf", 10)
font.big = sdl.font(__global.ttfPath.."UbuntuR.ttf", 15)
local font = font

local node = require("node")
__node = node

--move to node?
require("nodeCreate")(node, img)

node:add("Input")
node:add("Rotate")
node:add("Mixer")
node:add("Add")
node:add("Split")
node:add("DecomposeLCH")
node:add("DecomposeRGB")
node:add("WhiteBalance")
node:add("ComposeLCH")
node:add("ComposeRGB")
node:add("ColorSpace")
node:add("Output")
node:add("Color RGB")
node:add("Color HSV")
node:add("GradientRot")
node:add("Merge")
node:add("Gaussian")
node:add("Gamma")

node:setInput(mouse)

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
local bufZoom
do
	local crop = false
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
local function bufSet(size)
	if size=="S" then
		__global.preview = true
		buf = bufS
		bufout = bufoutS
		surf = surfS
		__global.imageSize = {buf.x, buf.y}
	else
		__global.preview = false
		buf = bufL
		bufout = bufoutL
		surf = surfL
		__global.imageSize = {buf.x, buf.y}
	end
end

bufSet("L")

--use a coroutine which interrupts for interface updates
local cp
local coProcess
local funProcess
local calcUpdate

local hist = require("histogram")
interface.setHistogram(hist)
interface.setBuffer(bufout)
local currentNode = 0

function funProcess()	
	cp=1							-- reset processing coroutine
	node[1].bufIn = buf 			-- initialise input node, move to other location!

	-- find output node, make selector for this.../one fixed output node
	local outNode for k, v in ipairs(node) do if v.procFlags.output then outNode=k end end
	if outNode==nil then error("no output node! FIXME") end --error if no output node found
	node[outNode].bufOut = buf:new()	-- place black screen if output node is not connected
	
	for k, v in ipairs(node.execOrder) do
		node[v]:processRun(k)	-- run processes
		currentNode = k
	end
	currentNode = 0
	
	-- put output buffer to screen buffer
	bufout = node[outNode].bufOut
	if __global.preview then
		img.toSurfaceQuad(bufout, surf)
	else
		img.toSurface(bufout, surf)
		bufoutS = img.scaleDownHQ(bufout, 4) --if full process then also update preview buffer
		img.toSurfaceQuad(bufoutS, surfS)
	end
	
	-- calculate histograms
	hist.calculate(bufout)
	interface.setBuffer(bufout) -- from globals??
	
	toc("Loop total") tic()
	
	coroutine.yield(-1)
end


local function imageProcess(flag)
	if (flag=="process" and (lua.threadDone() or cp==-1)) or cp=="pass" then
		if cp==-1 then
			coProcess=coroutine.wrap(funProcess)
		end -- if processing is done then start again
		cp = coProcess() -- go to next step
	end
	
	interface.draw(surf)
end
--register imageProcess
node:setImageProcess(imageProcess)


--eventually move to node lib with callbacks for some functions
function node:click()
	local nodeClicked = false
	for i, n in ipairs(self.drawOrder) do --for each node on the list
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
				if (not self[n].ui.noClose) and -- prevent closing of non-closable items
				self.mouse.x>=self[n].ui.x+130 and --delete node
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
					-- missing
				elseif type=="enum" then
					-- missing
				elseif type=="bool" then
					-- missing
				elseif type=="text" then
					self:draw()
				end
			end
			nodeClicked = true
			break
		end
	end
	if not nodeClicked then
		interface.click() 
	end
end

-- register key actions
do
	local writeFunTable = {
			PPM = ppm.writeFile,
			IM = ppm.writeIM,
		}
	local writeFun = writeFunTable[__global.setup.imageSaveType]
	
	interface.keyRegister("s", function()
		print("Saving image: "..__global.saveFile)
		local d = ppm.fromBuffer(bufout)
		d.name = __global.saveFile
		writeFun(d, __global.setup.imageSaveParams)
	end)
	interface.keyRegister("z", function()
		bufZoom()
		lua.threadStop() -- stop processing		
		calcUpdate = true
		bufSet("L")
		coProcess=coroutine.wrap(funProcess) -- reset coroutine
		coProcess()
		node:draw()
	end)
	interface.keyRegister("i", function()
		__global.info = not __global.info
		node:draw()
	end)
	interface.keyRegister("q", function()
		lua.threadStop()
		node:cleanup()
		lua.threadQuit()
		sdl.quit()
		os.exit()
	end)
	interface.keyRegister(" ", function()
		print("whee, space!")
	end)
end

--main loop
calcUpdate = true
node:calcLevels() --!! setup working levels in node setup allready!!
node:draw()
sdl.flip()
while true do
	mouse:update()
	interface.keyPress()
	
	if mouse.click[1] then
		node:click() --run mouse updating loop till mouse released
	else
		--draw progress bar
		if calcUpdate then
			local size = buf.x
			local nodeProgress = lua.threadGetProgress()
			local maxNodes = #node.execOrder - 1
			local fullProgress = math.floor((currentNode+nodeProgress-1)/maxNodes*size-1)
			fullProgress = fullProgress>size and size or fullProgress 
			if fullProgress>1 then
				boxFill(350,20,350+fullProgress,27,192,192,192)
			end
			--boxFill(350+progress,8,350+size,12,32,32,32)
			sdl.flip()
		end

		--force one last update before quitting
		--not called after input-output connection!!!
		if (lua.threadDone() or (calcUpdate and cp==-1)) or cp=="pass" then
			if cp==-1 then
				lua.threadStop()
				calcUpdate = false
				node:draw()
			else
				if cp~="pass" then lua.threadWait() end
				cp = coProcess()
			end
		end
	end
	if mouse.quit then
		lua.threadStop()
		node:cleanup()
		lua.threadQuit()
		sdl.quit()
		os.exit()
	end
end

