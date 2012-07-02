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

--require('debugger')

print[[
ImageFloat  Copyright (C) 2011-2012 G.Bajlekov
This program comes WITHOUT ANY WARRANTY.
This is free software, and you are welcome to redistribute it under the conditions of the GNU General Public License version 3.
]]

--load required libraries
__global = {preview = true, error=false}

--local ffi = require("ffi")
local sdl = require("sdltools")
local lua = require("luatools")
local dbg = require("dbgtools")
local ppm = require("ppmtools")
local img = require("imgtools")

__dbg = dbg
--local function file_exists(name)
--   local f=io.open(name,"r")
--   if f~=nil then io.close(f) return true else return false end
--end

--if running source code then build bytecode, otherwise don't
local release = true
if release then
	if arg[0]:sub(#arg[0]-3, #arg[0])==".lua" then os.execute("./build.sh") end
	lua.threadInit(arg[2] or 8, "Thread")
else
	lua.threadInit(arg and arg[2] or 8, "thread_func.lua")
end

--general debugging notes:
--SOLVED - check buffer locations if errors occur! wine gives access violation locations!
--possible sdl error, doesn't occur in wine @ thread 1 with rotate node?? -> SDL updated, no issue @ 1 core rotate
--still faults in rotate at high threadcounts!!! > error on read/write from buffer...sometimes invalid buffers!


--initialise threads, display, input, fonts
print("using "..lua.numCores.." threads...")
sdl.init()
--create init file
sdl.setScreen(1650, 900, 32)
sdl.caption("ImageFloat 2 ...loading", "ImageFloat 2");
require("draw")

local fileName = arg and arg[1] or "img.ppm"

local mouse = sdl.input()
mouse.interrupt = lua.threadDone -- interface refresh call on thread done
local node = require("node")

--move to node?
require("nodeCreate")(node, img)
node:add()

node:setInput(mouse)
-- move to fonttools?
font = {}
font.normal = sdl.font("UbuntuR.ttf", 11)
font.big = sdl.font("UbuntuR.ttf", 15)

--draw initial
node:draw()
sdl.flip()

--read file
print(fileName)
local imageTemp = ppm.toBuffer(ppm.readIM(fileName))
local bufO = img.scaleDownHQ(imageTemp, math.max(math.ceil(imageTemp.x/1200), math.ceil(imageTemp.y/750)))
sdl.caption("ImageFloat 2 [ "..fileName.." ]", "ImageFloat 2");
imageTemp = nil

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

--node[1]:connect(2,2,0)
--[[
--	===	Testing ===
	node[1]:connect(2,5,1)
	node[5]:connect(2,3,2)
	node[5]:connect(3,4,2)
	node[5]:connect(1,2,0)
	node[2]:connect(0,3,0)
	node[3]:connect(0,6,0)
	node[7]:connect(0,4,2)
	node[6]:connect(0,4,1)
	node[4]:connect(1,7,0)
--]]


function node:calcLevels()
	calcUpdate = true

	local current = {}
	local level = 1
	local tree = {}
	local error = false

	local c = require("boolops")
	local collect = c.collect
	local negate = c.cNot
	local list = c.list
	
	--return nodes connected to node n
	function connected(n, flag)
		local o = {}
		for _, v in ipairs(self[n][flag and "conn_i" or "conn_o"].list) do
			if v.node then o[v.node] = true end
		end
		return list(o), o
	end

	--add all nodes that can be used as generators
	table.insert(current, 1)

	--fix to generate tree from output backwards, avoiding dead ends

	local allProc = {}
	local noProc

	while true do
		tree[level] = current
		local c = {}
		for _, v in ipairs(tree[level]) do
			local t = connected(v)
			c = collect(t, c)
		end

		collect(current, allProc)

		current = list(c)
		level = level + 1

		if level>#self+1 then dbg.warn("Loop detected! Wrong node connections.") error = true break end
		if #current==0 then break end
	end

	noProc = c.cNot(c.new(1,#self),allProc)

	if not error then
		level = level - 1

		-- filter only last occurrence of each node:
		local early = {}
		for i = level,1, -1 do
			tree[i] = list(negate(collect(tree[i]), early))
			early = collect(tree[i],early)
		end

		--[[
		-- display node tree
		for i = 1, level do
			print("level "..i..":")
			print(unpack(tree[i]))
		end
		print("---")
		--]]
	end

	self.levels = tree
	self.execOrder = {}
	for _, v in ipairs(self.levels) do
		for _, v in ipairs(v) do
			table.insert(self.execOrder, v)
		end
	end
	self.exec = allProc
	self.noExec = list(noProc)
	for _, v in pairs(self.noExec) do
		generic_clean(v)
	end

	for _, v in ipairs(self) do
		v.ui.draw=true
	end
	__sdl.flip()
end

function funProcess()
	cp=1

	node[1].bufIn = buf
	
	local outNode
	for k, v in ipairs(node) do
		if v.procFlags.output then outNode=k end
	end
	node[outNode].bufOut = buf:new()

	-- keep track of output node when nodes get removed
	for k, v in ipairs(node.execOrder) do
		--print("DB: starting node "..tostring(v).."/"..tostring(k))
		node[v]:processRun(k)
	end

	bufout = node[outNode].bufOut

	if __global.preview then
		img.toSurfaceQuad(bufout, surf)
		sdl.screenPut(surf, 50, 20)
	else
		img.toSurface(bufout, surf)
		bufoutS = img.scaleDownHQ(bufout,4)
		img.toSurfaceQuad(bufoutS, surfS)
		sdl.screenPut(surf, 50, 20)
	end

	--hist.calculate(bufout)
	node:draw()
	coroutine.yield(-1)
end


--calculate histograms


--function updating the image and controling processing
--processing control should be located in a different area which is being looped through!...or called from the input module
local function imageProcess(flag)
	-- no threadDone because there's no thread running for simple ops!
	if flag=="process" and (lua.threadDone() or cp==-1) then
		if cp==-1 then
			toc("Process in")
			tic()
			coProcess=coroutine.wrap(funProcess)
		end
		lua.threadWait()
		cp = coProcess()
	end

	if __global.preview then
		sdl.screenPut(surf, 50, 20)
	else
		sdl.screenPut(surf, 50, 20)
	end
	
	--[[
	for i=1, 255 do
	--wrap graphics
		--dbg.warn("HISTOGRAM DRAWING")
		-- hist to buffer after calc, only put to screen here!!
		-- why isn't background always drawn below histogram??
		vLineAdd(i+10, 790 - math.floor(hist.r[i]), math.floor(hist.r[i]), 128, 32, 32)
		vLineAdd(i+10, 790 - math.floor(hist.g[i]), math.floor(hist.g[i]), 32, 128, 32)
		vLineAdd(i+10, 790 - math.floor(hist.b[i]), math.floor(hist.b[i]), 32, 32, 128)

		vLineAdd(i+310, 790 - math.floor(hist.l[i]), math.floor(hist.l[i]), 255, 255, i)
		vLineAdd(i+610, 790 - math.floor(hist.c[i]), math.floor(hist.c[i]), 255, i, 255)
		local r, g, b = HtoRGB(i/255)
		vLineAdd(i+910, 790 - math.floor(hist.h[i]), math.floor(hist.h[i]), r*255, g*255, b*255)
	end
	--]]
end

--register imageDraw
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
					bufSet("L")
					coProcess=coroutine.wrap(funProcess) -- reset coroutine
					coProcess()
				end
			elseif t=="connR" then
				if self[n].conn_o[p]~=nil then --if port exists
					self:noodleDrag(n, p)
					lua.threadStop() -- stop processing
					self:calcLevels()
					bufSet("L")
					coProcess=coroutine.wrap(funProcess) -- reset coroutine
					coProcess()
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
					coProcess()	--start coroutine process
					calcUpdate = true
					self:paramDrag(n, p)
					lua.threadStop() -- stop processing
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
	if mouse.click[1] then
		node:click() --run mouse updating loop till mouse released
	else
		
		--draw progress bar
		if calcUpdate then
		 	local size = buf.x
			local progress = math.floor(size*lua.threadGetProgress())
			boxFill(50,8,50+progress,12,128,128,128)
			boxFill(50+progress,8,50+size,12,32,32,32)
			sdl.flip()
		end

		--force one last update before quitting
		--not called after input-output connection!!!
		if lua.threadDone() or (calcUpdate and cp==-1) then
			if cp==-1 then
				lua.threadStop()
				calcUpdate = false
				--Histogram
				--slow hist calc...multithreaded and in separate instance + interruptable!
				--effect of partly slow cpu speedup and inefficient compilation. flushing compiled code avoids 1000ms+ times
				--still, perform non-blocking and possibly threaded!
					--improve interface for non-blocking ops with extra data passing!
					--additional non-MT thread for non-blocking ops?
				--node:draw()
			else
				lua.threadWait()
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

