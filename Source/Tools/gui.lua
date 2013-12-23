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

-- graphic ui toolkit accomodating for the desired interface (nodes, stacks, layout management etc.)

--[[
		frames manager:
		(frames = manually structured areas containing automatically positioned elements)
		
		- sub-frames of a frame are positioned in order, according to size preferences
		- global properties:
			- name
			- size (none or number)
			- unit ("px", "ln", "%", "cm", "in")
		- direction of parent (fields are always full-size in one direction)
--]]

package.path = 	"./?.lua;"..package.path

-- use the new SDL bindings
local sdl = require"Source.Include.sdl"
sdl.init()

sdl.screen.set(1400, 700)
sdl.screen.caption("GUI test")

local frameFun = {}

local function new(table, h, w)
	return setmetatable(table or {direction = "H", x = 0, y = 0, h = h or 700, w = w or 1400 }, {__index=frameFun})
end

function frameFun:split(name, size, unit)
	local n = #self
	name = name or "frame_"..(n+1)
	size = size or "fill"
	unit = unit or "px"
	self[n+1] = new{name = name, size = size, unit = unit, parent = self}
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
		return self
	end
end
function frameFun:getElem(x, y)
	local fr = self:getFrame()
	
	if fr.elements and #(fr.elements)>0 then
		-- get element position -> needs size, tiling etc...
	end
end
function frameFun:vertical() self.direction="V" return self end
function frameFun:horizontal() self.direction="H" return self end
function frameFun:addElem(name, eltype, value)
	value = value or {}
	eltype = eltype or "float"
	if not self.elements then self.elements = {parent = self} end
	local e = self.elements
	local n = #e
	
	local data = self:getData()
	if data then
		-- TODO: parse values
		e[n+1] = {name = name, type=eltype, value = value}
		data[name] = e[n+1]
	else
		error("no data storage set up for elements")
	end
end


-- construct table further, move to different process which is not repeated on resize
--[[
table.elements = {}
table.data = {}

table.onAction = nil --left click				fun(input)
table.onContext = nil -- right click			fun(input)
table.onHover = nil -- mouse over				fun(input) -> tooltip/expand??
table.onDrag = nil -- mouse dragged				fun(input)
table.onWheel = nil -- wheel change				fun(input)
table.onKey = nil -- key press					fun(input)
table.onChange = nil -- widget data change		fun(data)
--]]

--> parse structure to defined sizes
local function parseFrames(table)
	-- initial sizes:
	local w = table.w or 1400
	local h = table.h or 700
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
		elseif v.unit=="ln" then width[k] = v.size*12
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
local gui = new():vertical()
	local top = gui:split(nil, 20)
		local menu = top:split("Menu", 300)
		local toolbox = top:split("Toolbox")
	local main = gui:split()
		local left = main:split(nil, 300)
			local input = left:split("Input")
			local hist = left:split("Histogram", 200)
		local right = main:split()
			local temp = right:split()
				local view = temp:split("View")
				local output = temp:split("Output", 200)
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
view:addElem("Test10", "float", {1, 0.1234, 5})
view:addElem("Test11")
view:addElem("Test12")
output:addElem("Test13")

-- get data values
print(data2.Test10.value[2])

-- change ui values
view.elements[5].value[2] = 0.2345

-- get new data values
print(data2.Test10.value[2])


-- draw ui
local function rnd() return 0.5+math.random()*0.5 end
local fl = math.floor
math.randomseed(os.time())

local level = 0
local function drawElems(table, num)
--[[
	keep all elements position-independent due to scrolling
	- off-screen rendering and pasting to allow partial rendering (top and bottom incomplete elements only)
	- have element list offset and additional on-screen offset (or always align top element?)
	- overscroll (elastic)
--]]
	local x = table.x
	local y = table.y
	local w = table.w
	local e = table.elements
	local n = #e
	if num then
		if num<=n then
			local k, v = num, e[num]
			sdl.draw.box(x+2, y+2+k*10, x+w-4, y+10+10*k)
			sdl.draw.text(x+3, y+k*10, v.name)
		else
			return
		end
	else
		for k, v in ipairs(e) do
			sdl.draw.box(x+2, y+2+k*10, x+w-4, y+10+10*k)
			sdl.draw.text(x+3, y+k*10, v.name)
		end
	end
end
local function drawFrames(table)
	if #table>0 then
		for k, v in ipairs(table) do
			sdl.draw.fill(255*rnd(), 255*rnd(), 255*rnd(), fl(v.x), fl(v.y), fl(v.w), fl(v.h))
			sdl.draw.text(v.x+10, v.y, v.name)
			if #v>0 then drawFrames(v)
			elseif v.elements then drawElems(v) end
		end
	else
		sdl.draw.fill(255*rnd(), 255*rnd(), 255*rnd(), fl(table.x), fl(table.y), fl(table.w), fl(table.h))
		sdl.draw.text(table.x+10, table.y, table.name)
		if #table>0 then drawFrames(table)
		elseif table.elements then drawElems(table) end
	end
end

sdl.font.type("Resources/Fonts/UbuntuR.ttf", 10)
sdl.font.color(0,128,0)

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

while not sdl.input.quit do
	sdl.update()
	drawFrames(gui:getFrame(sdl.input.x, sdl.input.y))
end

sdl.quit()
print("done")
