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

-- graphic ui toolkit accomodating for the desired interface (nodes, stacks, layout management etc.)


package.path = 	"./?.lua;"..package.path

-- use the new SDL bindings
local sdl = require"Source.Include.sdl2"
sdl.init()
sdl.screen.set(1400, 700)
sdl.screen.caption("GUI test")

-- params for interface
local elemHeight = 14
sdl.font.type("Resources/Fonts/UbuntuR.ttf", 12)
sdl.font.color(0,128,0)


local frameFun = {}
local function newGui(table, h, w)
	return setmetatable(table or {direction = "H", x = 0, y = 0, h = h or sdl.screen.height, w = w or sdl.screen.width }, {__index=frameFun})
end

function frameFun:split(name, size, unit)
	local n = #self
	name = name or "frame_"..(n+1)
	size = size or "fill"
	unit = unit or "px"
	self[n+1] = newGui{name = name, size = size, unit = unit, parent = self}
	self[n+1].direction = self.direction=="H" and "V" or "H"
	return self[n+1]
end
function frameFun:addData() self.data = {} return self.data end
function frameFun:getData()
	if self.data then
		return self.data
	elseif self.parent then
		return self.parent:getData()
	else
		return false
	end
end

function frameFun:getFrame(x, y)
	if #self>0 then
		for k, v in ipairs(self) do
			if x>=v.x and x<v.x+v.w and y>=v.y and y<v.y+v.h then
				return v:getFrame(x,y)
			end
		end
	else
		return self, x-self.x, y-self.y
	end
end
function frameFun:getElem(x, y)
	local fr = self:getFrame(x, y)
	if fr.elements and #(fr.elements)>0 then
		local n = #(fr.elements)
		
		y = y + (fr.scroll or 0)
		
		local x = x-fr.x-2 -- 0
		local y = y-fr.y-2 -- k*elemHeight
		local k = math.floor(y/elemHeight)
		y = y - k*elemHeight
		if k==0 or k>n or y>=elemHeight-2 or
			x<0 or x>fr.w-5 or
			fr.elements[k].visible==false then return nil end
		return fr.elements[k], x, y
	end
end

local drawFunctions = {}
drawFunctions.elem = {}
drawFunctions.frame = {} -- TODO: use for frame drawing
function drawFunctions.elem.text(elem)
	local x, y = elem.frame.x, elem.frame.y
	local w, h = elem.frame.w, elem.frame.h
	local k = elem.num
	
	local yp = k*elemHeight-(elem.frame.scroll or 0)
	
	if yp>elemHeight-3 and yp+elemHeight<h-2 then
		sdl.draw.color(224, 224, 224)
		sdl.draw.fill(x+2, y+2+yp, w-4, elemHeight-2)
		sdl.font.color(32,32,32)
		sdl.draw.text(x+4, y+yp, elem.name)
		elem.visible = true
	else
		elem.visible = false
	end
end
function drawFunctions.elem.float(elem)
	local x, y = elem.frame.x, elem.frame.y
	local w, h = elem.frame.w, elem.frame.h
	local k = elem.num
	
	local yp = k*elemHeight-(elem.frame.scroll or 0)
	
	if yp>elemHeight-3 and yp+elemHeight<h-2 then
		local f = elem.value[1]/(elem.value[4]-elem.value[3])
		sdl.draw.color(224, 224, 224)
		sdl.draw.fill(x+2, y+2+yp, w-4, elemHeight-2)
		sdl.draw.color(192,192,192)
		sdl.draw.fill(x+2, y+2+yp, math.floor((w-4)*f), elemHeight-2)
		sdl.font.color(32,32,32)
		sdl.draw.text(x+4, y+yp, elem.name)
		sdl.draw.textR(x+w-20, y+yp, string.format("%.2f", elem.value[1]))
		elem.visible = true
	else
		elem.visible = false
	end
end

local function drawFrame(frame)
	local f = frame
	local t = 192
	sdl.draw.color(96, 96, 96)
	sdl.draw.fill(f.x, f.y, f.w, f.h)
	
	sdl.draw.color(255, 255, 255)
	sdl.draw.line(f.x+2, f.y+elemHeight-1, f.w-5, 0)
	sdl.draw.line(f.x+2, f.y+f.h-3, f.w-5, 0)
	sdl.font.color(255,255,255)
	sdl.draw.text(f.x+10, f.y-2, f.name)
end

--[[
	eltype can be:
		empty
		text
		slider
		toggle
		fill -> single element with own handler
--]]
local function pass() end

function frameFun:elem(name, eltype, value)
	value = value or {}
	eltype = eltype or "text"
	if not self.elements then self.elements = {parent = self} end
	local e = self.elements
	local n = #e
	
	local data = self:getData()
	if data then
		e[n+1] = {
			name	= name,
			type	= eltype,
			value	= value,
			draw	= drawFunctions.elem[eltype] or drawFunctions.elem.text,
			event	= {
				onAction	= pass,
				onContext	= pass,
				onHover		= pass,
				onDrag		= pass,
				onWheel		= pass,
				onKey		= pass,
				onUpdate	= pass, -- when update = true, check on every draw cycle (sensible?)
			},
			frame	= self,
			num		= n+1,
			update	= false,
		}
		data[name] = e[n+1]
	else
		error("no data storage set up for elements")
	end
end

--> parse structure to defined sizes
local function parseFrames(table)
	-- initial sizes:
	local w = table.w or sdl.screen.width
	local h = table.h or sdl.screen.height
	local x = table.x or 0
	local y = table.y or 0
	
	local size = table.direction=="V" and h or w
	local width = {}
	local fill = 0
	local totwidth = 0
	local lastdir
	for k, v in ipairs(table) do
		if v.size=="fill" then
			width[k] = "fill"
			fill = fill+1
		elseif v.unit=="px" then width[k] = v.size
		elseif v.unit=="ln" then width[k] = v.size*elemHeight
		elseif v.unit=="%" then width[k] = v.size/100*w
		else error("wrong specification") end
		
		if type(width[k])=="number" then totwidth = totwidth + width[k] end
	end
	if totwidth>size then error("exceeding size") end
	local fillwidth = (size-totwidth)/fill
	for k, v in ipairs(table) do
		if width[k]=="fill" then width[k]=fillwidth end
		if table.direction=="V" then
			v.w, v.h = w, width[k]
			v.x, v.y = x, y
			y = y + width[k]
		else
			v.w, v.h = width[k], h
			v.x, v.y = x, y
			x = x + width[k]
		end
		v.scroll = 0
		if #v>0 then parseFrames(v) end -- recurse over sub-frames
		v.parent = table -- convenience parent link
	end
end
-- TODO:
--[[
	- tabs, collapsible frames, popups etc are all frames that need to be inplemented
		- tabs are switchable frames depending on top tab list
		- collapsible frames provide their space to their neighbors, needs recalculation, limit to pairs of frames for easier management and no distortion
		- popups gain focus, are presented as single frame on top of others. clicking outside of area dismisses popup
		- nodes are implemented individually as a layer, their specifics are not close to the frame system
		- stacks are implemented as elements due to the dynamic nature of their content
	- resizing of window area
		- forces recalculation of frames (otherwise recalculate as little as possible)
		- forces redraws
	- dynamic frames passing control to other functions (ex: navigation buttons)
	- warnings for incompatible behaviour
--]]

--test
-- setup structure
local gui = newGui():vertical()
	local top = gui:split(nil, 30)
		local menu = top:split("Menu", 300)
		local toolbox = top:split("Toolbox")
	local main = gui:split()
		local left = main:split(nil, 300)
			local input = left:split("Input")
			local hist = left:split("Histogram", 200)
		local right = main:split()
			local temp = right:split()
				local view = temp:split("View")
				local output = temp:split("Output", 200) -- collapsible!
			local browser = right:split("Browser", 200)
	local status = gui:split("Status", 20)

-- setup data storage
local data1 = input:addData()
local data2 = right:addData()

-- setup elements
input:addElem("Test1")
input:addElem("Test2")
input:addElem("Test3")
input:addElem("Test4")
input:addElem("Test5")
view:addElem("Test6")
view:addElem("Test7")
view:addElem("Test8")
view:addElem("Test9")
view:addElem("Test10", "float", {1, 1, 0, 5})
view:addElem("Test11")
view:addElem("Test12")
output:addElem("Test13")

-- get data values
print(data2.Test10.value[2])

local function onDragFloat(elem, input)
	local x = elem.value[1]
	local min, max = elem.value[3], elem.value[4]
	x = x + input.dx/(elem.frame.w-4)*(max-min)
	if x<min then x = min elseif x>max then x = max end
	elem.value[1] = x
end
data2.Test10.event.onDrag = onDragFloat


-- change ui values
view.elements[5].value[2] = 0.2345

-- get new data values
print(data2.Test10.value[2])


-- draw ui
local function rnd() return 0.5+math.random()*0.5 end
math.randomseed(os.time())

local level = 0
local function drawElems(table, num)
	local e = table.elements
	local n = #e
	if num then
		if num<=n and num>0 then -- draw specific element if exists
			e[num]:draw()
		else
			return
		end
	else -- draw all elements
		for k, v in ipairs(e) do
			v:draw()
		end
	end
end
local function drawFrames(table)
	if #table>0 then
		for k, v in ipairs(table) do
			local t = rnd()
			sdl.draw.color(t*128, t*128, t*128)
			sdl.draw.fill(v.x, v.y, v.w, v.h)
			
			sdl.draw.color(255, 255, 255)
			sdl.draw.line(v.x+2, v.y+elemHeight-1, v.w-5, 0)
			sdl.draw.line(v.x+2, v.y+v.h-3, v.w-5, 0)
			sdl.font.color(255,255,255)
			sdl.draw.text(v.x+10, v.y, v.name)
			if #v>0 then drawFrames(v)
			elseif v.elements then drawElems(v) end
		end
	else
		sdl.draw.color(128, 128, 128)
		sdl.draw.fill(table.x, table.y, table.w, table.h)
		
		sdl.draw.color(255, 255, 255)
		sdl.draw.line(table.x+2, table.y+elemHeight-1, table.w-5, 0)
		sdl.draw.line(table.x+2, table.y+table.h-3, table.w-5, 0)
		sdl.font.color(255,255,255)
		sdl.draw.text(table.x+10, table.y, table.name)
		if #table>0 then drawFrames(table)
		elseif table.elements then drawElems(table) end
	end
end

local t = sdl.time()
for i = 1, 1000 do
parseFrames(gui)
end
print(sdl.time()-t)

local t = sdl.time()
for i = 1, 10 do
drawFrames(gui)
end
print(sdl.time()-t)


--function updating the image and checking when processing should be advanced
local t = sdl.time()
local fpsSmooth = 128 -- smoothing parameter
local fpsData = ffi.new("double[?]", fpsSmooth)
local fpsCounter = 0
local fpsAverage = 0


sdl.input.fps(120)
local scroll = false
local fscroll
local drag = false
local fdrag
while not sdl.input.quit do
	sdl.input.update(true)
	sdl.update()
	
	--drawFrames(gui:getFrame(sdl.input.x, sdl.input.y))
	
	--if sdl.input.click[1] then
	--	print(sdl.input.x, sdl.input.y)
	--end
	
	if sdl.input.click[1] then
		drag = true
		fdrag = gui:getElem(sdl.input.x, sdl.input.y)
	end
	if sdl.input.release[1] then drag = false end
	if drag and sdl.input.dx~=0 then
		fdrag.event.onDrag(fdrag, sdl.input)
		fdrag:draw()
	end

	if sdl.input.mod.down or sdl.input.wheel.y~=0 then
		local f = gui:getFrame(sdl.input.x, sdl.input.y)
		f.scroll = f.scroll + sdl.input.wheel.y*5
	end

	if sdl.input.click[2] then
		scroll = true
		fscroll = gui:getFrame(sdl.input.x, sdl.input.y)
	end
	if sdl.input.release[2] then scroll = false end
	if scroll and sdl.input.dy~=0 then
		fscroll.scroll = fscroll.scroll - sdl.input.dy
		drawFrames(fscroll)
	end
	
	-- timer
	local tt = sdl.time()-t
	t = sdl.time()

	if tt<250 then -- filter outliers!
		fpsAverage = fpsAverage + tt - fpsData[fpsCounter]
		fpsData[fpsCounter] = tt
		fpsCounter = fpsCounter + 1
		fpsCounter = fpsCounter==fpsSmooth and 0 or fpsCounter
	else
		print("*** slow screen refresh ***")
	end
	if math.floor(fpsSmooth/fpsAverage*1000)<100 then print(math.floor(fpsSmooth/fpsAverage*1000)) end
end

sdl.quit()
print("done")
