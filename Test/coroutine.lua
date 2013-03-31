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

--load required libraries
__global = {preview = true, error=false, info=true}
local __global = __global
__global.setup = require("IFsetup")
__global.setup.bufferPrecision = __global.setup.bufferPrecision or {"float", 4}
__global.libPath = __global.setup.libPath or "../Libraries/"..ffi.os.."_"..ffi.arch.."/"
__global.imgPath = __global.setup.imgPath or "../Resources/Images/"
__global.ttfPath = __global.setup.ttfPath or "../Resources/Fonts/"

math.randomseed(os.time())

local sdl = require("sdltools")
local lua = require("luatools")
local dbg = require("dbgtools")
local ppm = require("ppmtools")
local img = require("imgtools")

local mouse = sdl.input()

print(sdl.ticks()) -- ms

local tRef = sdl.ticks()
local tDelay = 1000/60

local state = {
	interrupt	= true,		-- interrupt timer loop (for processing steps) 
	preview		= false,	-- preview or full processing
	process		= true,		-- is processing
	update		= true,		-- need a refreshed view
	coroutine	= "reset",	-- state of coroutine
	abort		= false		-- quit processing
}

--put all processing in a table

local function funProcess()
	coroutine.yield("pass")
	sdl.wait(20)
	print("1")
	coroutine.yield(1)
	sdl.wait(20)
	print("2")
	coroutine.yield(2)
	sdl.wait(20)
	print("3")
	coroutine.yield(3)
	sdl.wait(20)
	print("4")
	coroutine.yield("reset")
end

local function postProcess()
	-- put buffer to texture
	-- calc histogram
end

local coProcess = coroutine.wrap(funProcess)
local coCounter = "reset"
local function process()
	-- check threadDone() or coCounter=="pass" ?? only called when threadDone is true, not necessary to check!
	-- threadWait()
	
	if state.process then
		state.coroutine = coProcess()
		
		if state.coroutine=="reset" then -- reset if params updated
			coProcess = coroutine.wrap(funProcess)
			if state.update then -- handle resuming only if needed
				state.coroutine = coProcess()
			else
				state.process = false
			end
			postProcess()
		end
	end
end

local function processHalt() -- halt process cleanly
	-- set abort threads flag
	-- threadWait()
	coProcess = coroutine.wrap(funProcess)
	state.process = flase
end

local function processNew(type) -- new full/preview processing
	processHalt()									-- halt old process
	state.preview = type=="full" and false or true	-- set preview state
	coProcess = coroutine.wrap(funProcess)			-- reset coroutine
	
	state.coroutine = coProcess()					--resume processing
	state.process = true
end

local function draw()
	--print("*** draw UI")
end

local function input()
	-- input calling processNew??
	--print("*** get input")
	-- if parameters changed then state.abort = true
end

local function refreshFun()
	input()
	draw()
end

-- timer function calling regular updates and allowing for interrupts
local function timer(refreshFun)
	if sdl.ticks()-tRef < 1.25*tDelay then 
		while true do
			if sdl.ticks()-tRef > tDelay  then
				tRef = tRef + tDelay
				refreshFun()
			end
			if state.interrupt then
				break
			end
			sdl.wait(1)
		end
	else 
		tRef = sdl.ticks()
		refreshFun()
	end
end

while true do
	timer(draw)
	input()
	process()
end


--[[
-- required functions:
	- main loop
		- check timer, wait if no pending actions (draw/process etc.)
			- branch into following code...
		- if processing step needed then go to processing coroutine
			- call when a stage is done and a new one needs to be started
				- possibly detect before frame is done, so wait can be optimal and no delay is introduced
					- check delay and performance between direct calls and calling coroutine in loop
			- call when processing needs to start
		- if preview processing needed then run preview update
			- call if processing has completed, calculate histograms, copy output buffer
			- check if no output buffer processing is running (otherwise wait...? or pass through?)
		- if control/ui is needed then run that (60 times per second, find good method to keep timing consistent)
			- get input
			- update UI
			- draw UI
		- abort processing if needed, based on changes in state
		
	- process loop
		- start processing
		- call parallel processes
		- pass until stage is complete
	- draw function
		- draw ui
		- refresh data (histogram)
		- refresh preview (image)
	- input function
		- updates states
	- timer function
		- maintains framerate
		- wait can be interrupted if processing is required
--]]

