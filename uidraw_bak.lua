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

local ffi = require("ffi")
local sdl = require("sdltools")
local lua = require("luatools")
local dbg = require("dbgtools")
local ppm = require("ppmtools")
local img = require("imgtools")

lua.threadInit(3, "thread_func.lua")
print("using "..lua.numCores.." threads...")

sdl.init()
sdl.setScreen(1280, 800, 32)
sdl.caption("Test UI", "Test UI");

--create fonts
ttf_font = sdl.font("UbuntuR.ttf", 11)
ttf_font_big = sdl.font("UbuntuR.ttf", 16)

require("dbgtools")
require("draw")
local mouse = sdl.input()
local node = require("node")
node:setInput(mouse)


--node creation
do
	local n=node:add("Input 1")
	n.ui.x=100
	n.ui.y=100
	n.conn_o:add(0)
end

do
	local n=node:add("Input 2")
	n.ui.x=100
	n.ui.y=200
	n.conn_o:add(0)
end

do
	local n=node:add("Mixer")
	n.ui.x=500
	n.ui.y=200
	n.param:add("R -> R",-3,3,1)
	n.param:add("R -> G",-3,3,0)
	n.param:add("R -> B",-3,3,0)
	n.param:add("G -> R",-3,3,0)
	n.param:add("G -> G",-3,3,1)
	n.param:add("G -> B",-3,3,0)
	n.param:add("B -> R",-3,3,0)
	n.param:add("B -> G",-3,3,0)
	n.param:add("B -> B",-3,3,1)
	n.conn_i:add(0)
	n.conn_i:add(2)
	n.conn_i:add(5)
	n.conn_i:add(8)
	
	n.conn_o:add(0)
end

print(node[3].ui.name)

do
	local n=node:add("Add")
	n.ui.x=500
	n.ui.y=500
	n.param:add("Image 1",-3,3,1)
	n.param:add("Image 2",-3,3,1)
	n.conn_i:add(1)
	n.conn_i:add(2)
	n.conn_o:add(0)
end

--have a better (minimal) layout for a split node
do
	local n=node:add("Split")
	n.ui.x=300
	n.ui.y=700
	n.param:add("Empty",-3,3,1)
	n.param:add("Empty",-3,3,1)
	n.conn_i:add(0)
	n.conn_o:add(1)
	n.conn_o:add(2)
end

do
	local n=node:add("Output")
	n.ui.x=1000
	n.ui.y=100
	n.conn_i:add(0)
end

node:draw()
sdl.flip()
sdl.screenCopy(buf)

local calcUpdate = true

--eventually move to node lib with callbacks for some functions
function node:click()
	for _, n in ipairs(self.order) do
		--check click inside node
		if self[n].ui:click("node") then
			self:focus(n)
			local p, t = self[n].ui:click()
			if t=="connL" then
				if self[n].conn_i[p]~=nil then --if port exists
					if self[n].conn_i[p].node~=nil then --if allready connected
						local nn = self[n].conn_i[p].node --find source node and port
						local pp = self[n].conn_i[p].port
						self:focus(nn)
						self:noodleDrag(nn, pp)
					end
				end
			elseif t=="connR" then
				if self[n].conn_o[p]~=nil then --if node exists
					self:noodleDrag(n, p)
				end
			elseif t=="title" then
				self:nodeDrag(n)
			elseif t=="params" then
				calcUpdate = true
				self:paramDrag(n, p)
			end
			break
		end
	end
end

local d = ppm.readFile("img16.ppm")
local buf = ppm.toBuffer(d)
buf = img.scaleDownHQ(buf,2)
local bufout = buf:new()
d = nil

local surf = img.toSurface(bufout)


local function imgProcess(i1, i2, i3)
	lua.threadSetup({buf, img.newBuffer(i1), img.newBuffer(i2), img.newBuffer(i3), bufout}, 4, 1)
	lua.threadRun("ops", "mixer")
end
local function interfaceUpdate()
	local function get(n, p)
		return node[n].param[p].value[1]
	end
	imgProcess(
		{get(3,1), get(3,2), get(3,3)},
		{get(3,4), get(3,5), get(3,6)},
		{get(3,7), get(3,8), get(3,9)}
		)
end

local thread = false
local function interfaceDraw()
	if mouse.button[1] then
		if thread==true and lua.threadProgress[1]==-1 then
			lua.threadWait()
			img.toSurface(bufout, surf)
			thread = false
		end
		if calcUpdate and thread==false then
			interfaceUpdate()
			thread = true
		end
	end
	sdl.screenPut(surf, 20, 20)
end

node:setInterfaceDraw(interfaceDraw)

--main loop
while true do
	mouse:update()
	if mouse.click[1] then
		node:click()
		node:draw()
	else
		--force one last update before quitting
		if calcUpdate and thread==false then
			interfaceUpdate()
			thread = true
			calcUpdate = false
		end
		--collect process output
		if thread==true and lua.threadProgress[1]==-1 then
			lua.threadWait()
			img.toSurface(bufout, surf)
			thread = false
			node:draw()
		end
	end
	
	if mouse.quit then break end
end


--cleanup
sdl.destroyFont(ttf_font)
sdl.destroyFont(ttf_font_big)

lua.threadQuit()
sdl.quit()
