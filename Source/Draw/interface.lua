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

-- add interface
--[[
		main goals:
			- main menu loop
				- file
					- open (switch to full-screen sub-process)
					- save
				- edit
				- settings
				- help
				
				- add node menu
					- input/output
					- generators
					- color space
					- effects
					- geometry
					- masks
			
			- on-click callbacks
			- region loops				
--]]

local sdl = __sdl
local __global = __global
local ffi = require("ffi")
local interface = {}

-- put in resources table
local backgrounds = {}
backgrounds.window = sdl.loadImage(__global.imgPath.."background.png")

-- drawing is all over the place...
function interface.draw(surf)
	sdl.blit(backgrounds.window, nil, sdl.screen, nil)	--background
	sdl.screenPut(surf, 350, 20)						-- image preview
	
	interface.drawFPS()				-- frame counter
	interface.drawHist()			-- histogram
	interface.drawHelp()			-- info/help
	interface.drawMenu()			-- draw menu skeleton
end



--function updating the image and checking when processing should be advanced
local t = sdl.ticks()
local vLineAdd = vLineAdd
local hLineAdd = hLineAdd
local fpsSmooth = 128 -- smoothing parameter
local fpsData = ffi.new("double[?]", fpsSmooth)
local fpsCounter = 0
local fpsAverage = 0
function interface.drawFPS()
	-- fps averaging
	local tt = sdl.ticks()-t
	t = sdl.ticks()
	if tt<250 then -- filter outliers!
		fpsAverage = fpsAverage + tt - fpsData[fpsCounter]
		fpsData[fpsCounter] = tt 
		fpsCounter = fpsCounter + 1
		fpsCounter = fpsCounter==fpsSmooth and 0 or fpsCounter
	else
		print("*** slow screen refresh ***")
	end
	sdl.text(math.floor(fpsSmooth/fpsAverage*1000).."FPS", font.normal, 10, 20)
end



local helpText = {
	"ImageFloat",
	"Copyright (C) 2011-2012 G.Bajlekov",
	"This program comes WITHOUT",
	"ANY WARRANTY. This is free",
	"software, and you are welcome to",
	"redistribute it under the conditions",
	"of the GNU General Public License",
	"version 3 or later.",
	" ",
	"Instructions:",
	"I - toggle this message",
	"Z - toggle crop view",
	"S - save preview",
	"Q - quit",
	" ",
	"Mouse:",
	"Ctrl - step adjust",
	"Shift - precise adjust",
	"Alt - reset to default",
}
function interface.drawHelp()
	--help text
	if __global.info then
		for k, v in ipairs(helpText) do
			sdl.text(v, font.normal, __global.setup.windowSize[1] - 220, 10 + k*10, 128, 64, 64)
		end
	end
end



local hist
function interface.setHistogram(h) hist = h end
function interface.drawHist()
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

	sdl.text("Hue", font.normal, 12, __global.setup.windowSize[2]-405)
	sdl.text("Chroma", font.normal, 12, __global.setup.windowSize[2]-305)
	sdl.text("Luma", font.normal, 12, __global.setup.windowSize[2]-205)
	sdl.text("RGB", font.normal, 12, __global.setup.windowSize[2]-105)
end


local input
function interface.setInput(i)
	input = i
end
local buffer
function interface.setBuffer(b)
	buffer = b
end

local menuList = {"File", "Edit", "Process", "Settings", "Help", "Close"}
local menuDx = {}
local nodeList = {"Input", "Generate", "Color", "Effect", "Geometry", "Mask", " ", " ", " ", " ", " "}
function interface.drawMenu()
	boxFill(1,1,__global.setup.windowSize[1]-2,18,64,64,64)
	local x = 10
	for k, v in ipairs(menuList) do
		local dx = sdl.text(v, font.normal, x, 3)
		menuDx[k] = dx -- keep track of widths! 
		boxLine(x-4,2,x+dx+4,17,32,32,32)
		x = x + dx + 10
		
	end
	for k, v in ipairs(nodeList) do
		boxFill(350+(k-1)*80,2,350+(k-1)*80+78,17,128, 128, 128)
		sdl.text(v, font.normal, 350+(k-1)*80+4, 3)
		boxLine(350+(k-1)*80,2,350+(k-1)*80+78,17,32,32,32)
	end
	vLineAdd(340, 0, __global.setup.windowSize[2], 128, 128, 128)
end
local max = math.max
local min = math.min
local function luma(r, g, b) return 0.2126 * r + 0.7152 * g + 0.0722 * b end --Rec709
local function chroma(r, g, b) return max(r, g, b)-min(r, g, b) end
local function hue(r, g, b)
	local c = chroma(r, g, b)
	if c==0 then return 0 end
	local hue
	local m = max(r, g, b)
	if m==r then hue = ((g - b) / c) end
	if m==g then hue = (2 + (b - r) / c) end
	if m==b then hue = (4 + (r - g) / c) end
	return hue<0 and hue/6+1 or hue/6
end
function interface.click()
	if input.y<20 then
		print("menu clicked")
	end
	local x, y = input.x-350, input.y-20
	if x>=0 and x<buffer.x and y>=0 and y<buffer.y then
		print("image clicked")
		-- loop
		while input.button[1] do
			input:update()
			local x, y = input.x-350, input.y-20
			if x>=0 and x<buffer.x and y>=0 and y<buffer.y then
				__node:draw("nonode") -- FIXME: fix this!!! fix all drawing code in node!
				-- get pixel values
				local r, g, b = buffer:get3(x,y)
				local textRGB = string.format("| R:%.2f | G:%.2f | B:%.2f |", r, g, b)
				local textHSV = string.format("| L:%.2f | C:%.2f | H:%.2f |", luma(r,g,b), chroma(r,g,b), hue(r,g,b))
				boxFill(x+365,y+15,x+365+179,y+53,r*256, g*256, b*256)
				local d = ((r+g+b)/3+0.5)*256
				sdl.text(textRGB, font.mono, x+370,y+20, d, d, d)
				sdl.text(textHSV, font.mono, x+370,y+35, d, d, d)
				sdl.flip()
			else
				__node:draw("nonode")
				sdl.flip()
			end
		end
		__node:draw()
	end
end


-- keyboard callbacks
local keyPressFun = {}
function interface.getKeyFunTable() return keyPressFun end -- easy replacing of callback table
function interface.setKeyFunTable(kf) keyPressFun = kf end
function interface.keyRegister(k, f)
	keyPressFun[k] = f
end
function interface.keyPress()
	local k = input.key.num
	if not k then return end
	local s = string.char(tonumber(k))
	local f = keyPressFun[s] or keyPressFun[k] or nil
	if type(f)=="function" then return f() end
end

return interface

