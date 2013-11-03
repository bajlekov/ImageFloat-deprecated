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
	self[n+1] = new{name = name, size = size, unit = unit}
	self[n+1].direction = self.direction=="H" and "V" or "H" 
	return self[n+1]
end
function frameFun:vertical() self.direction="V" return self end
function frameFun:horizontal() self.direction="H" return self end
function frameFun:addElem(type, name, value)
	value = value or 0
	if not self.elements then self.elements = {parent = self} end
	local e = self.elements
	local n = #e
	e[n+1] = {type = type, name = name, value = value}
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


--test
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

input:addElem("float", "Test 1", 4)
input:addElem("float", "Test 2", 3)
input:addElem("float", "Test 2", 3)
input:addElem("float", "Test 2", 3)
input:addElem("float", "Test 2", 3)
view:addElem("float", "Test 2", 3)
view:addElem("float", "Test 2", 3)
view:addElem("float", "Test 2", 3)
view:addElem("float", "Test 2", 3)
view:addElem("float", "Test 2", 3)
view:addElem("float", "Test 2", 3)
view:addElem("float", "Test 2", 3)
output:addElem("float", "Test 2", 3)

local function rnd() return 0.5+math.random()*0.5 end
local fl = math.floor
math.randomseed(os.time())

local level = 0
local function drawElems(table)
	local x = table.x
	local y = table.y
	local w = table.w
	local e = table.elements
	local n = #e
	for k, v in ipairs(e) do
		sdl.draw.box(x+2, y-8+k*10, x+w-4, y+10*k)
	end
	print("draw elements")
end
local function drawFrames(table)
	for k, v in ipairs(table) do
		sdl.draw.fill(255*rnd(), 255*rnd(), 255*rnd(), fl(v.x+level*2), fl(v.y+level*2), fl(v.w-level*4), fl(v.h-level*4))
		sdl.draw.text(v.x+5, v.y+5, v.name)
	end
	level = level + 1
	for k, v in ipairs(table) do
		if #v>0 then drawFrames(v)
		elseif v.elements then drawElems(v) end
	end
	level = level - 1
end

sdl.font.type("Resources/Fonts/UbuntuR.ttf", 12)
sdl.font.color(0,128,0)

t = sdl.time()
for i = 1, 1 do
parseFrames(gui)
end
print(sdl.time()-t)
drawFrames(gui)

while not sdl.input.quit do
	sdl.wait(1)
	sdl.update()
end

sdl.quit()
print("done")
