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

--require("../Lua/lua_utils.lua")
require("node_draw")
local node = {order = {}, execOrder = {}, levels = {}, noExec = {}, exec = {}}

function node:setInput(input)
	self.mouse = input
end

function node:setImageProcess(input)
	self.imageProcess = input
end

function node.imageProcess()
	return nil
end

function node:nodeDrag(n)
	while self.mouse.button[1] do
		self.mouse:update()
		self[n].ui.x = self[n].ui.x + self.mouse.dx
		self[n].ui.y = self[n].ui.y + self.mouse.dy
		self:draw()
	end
end

function node:paramDrag(n, p)
	local v = self[n].param[p].value[1]
	local vmin = self[n].param[p].value[2]
	local vmax = self[n].param[p].value[3]
	local vrange = vmax-vmin
	
	while self.mouse.button[1] do
		self.mouse:update()
		if self[n].param[p].type~="value" then break end --have check earlier and update data
		local fac = self.mouse.mod.shift and 10 or 1
		v = v + self.mouse.dx/148/fac*vrange
		if v>vmax then v=vmax end
		if v<vmin then v=vmin end
		if self.mouse.mod.ctrl then v = self[n].param[p].value[4] end
		self[n].param[p].value[1] = v
		self[n].ui.draw=true
		self:draw("process")
	end
end

function node:noodleDrag(n, p)
	self[n]:disconnect(p) --disconnect old connection
	while self.mouse.button[1] do
		self.mouse:update()
		
		local _n, _p = nil, nil
		for k, v in ipairs(self) do
			if k~=n then
				local i = v.ui:click("connL")
				if i and v.conn_i[i]~=nil then
					self:focus(k) --focus on node mouse is over
					_n = k
					_p = i
				end
			end
		end

		--flip at the end of the drawing cycle, as additional elements are added
		self:draw("noflip")
		if _n and _p then
			drawNoodle(self[n].ui.x, self[n].ui.y, self[_n].ui.x, self[_n].ui.y, p, _p)
		else
			drawNoodleLoose(self[n].ui.x, self[n].ui.y, self.mouse.x, self.mouse.y, p)
		end
		__sdl.flip()
	end
	for k,v in ipairs(self) do
		if k~=n then
			local i = v.ui:click("connL")
			if i and v.conn_i[i]~=nil then
				self[n]:connect(p,k,i)
				self:focus(k) --focus on connected node
			end
		end
	end
	self:draw()
end

local function nodeClick(self, part)
	local mouse = node.mouse
	local function checkPos(r)
		local x = mouse.x
		local y = mouse.y
		local ox = self.x
		local oy = self.y
		if x>=r[1]+ox and x<=r[2]+ox and y>=r[3]+oy and y<=r[4]+oy then return true end
	end

	local areas = {
		node = {-13, 162, -2, 23+12*self.p[1]},
		title = {0, 149, 0, 19},
		params = {0, 149, 21, 21+12*self.p[1]},
		connL = {-12, -1, 7, 21+12*self.p[1]},
		connR = {150, 161, 7, 21+12*self.p[1]},
	}

	if part~=nil then
		local area = areas[part]

		if checkPos(area) then
			if part=="params" then
				local p = math.floor((mouse.y - self.y - 22)/ 12) + 1
				if p==0 then return 1 else return p end --correct for math.floor
			end
			if part=="connL" or part=="connR" then
				if mouse.y>=self.y+7 and mouse.y<=self.y+19 then return 0 end
				local p = math.floor((mouse.y - self.y - 22)/ 12) + 1
				return p>0 and p or nil
			end
			--for title return button end
			return true
		end
	else
		for k,_ in pairs(areas) do
			local p = nodeClick(self, k)
			if p and k~="node" then return p, k end
		end
	end
end

local function noodleConnect(self, pos, node, port)
	local n_in = self.node[node].conn_i[port]
	local n_out = self.conn_o[pos]

	--break if no matching connectors
	if n_out==nil or n_in==nil then return false end 
 	--remove possible old connection from old conn_i
	if n_out.node~=nil then self.node[n_out.node].conn_i[n_out.port].node = nil end
	--remove possible old connection to new conn_i
	if n_in.node~=nil then self.node[n_in.node].conn_o[n_in.port].node = nil end
	
	n_out.node = node
	n_out.port = port
	n_in.node = self.n
	n_in.port = pos
	-- n_in.buff = n_out.buff
	-- no sense to copy buffers on connection as if the buffer changes it won't get updated
	-- if needed put buffers in table! then reference is to first element of table...
end

local function noodleDisconnect(self, pos)
	if self.conn_o[pos]~=nil and self.conn_o[pos].node~=nil then
		local node = self.conn_o[pos].node
		local port = self.conn_o[pos].port

		self.conn_o[pos].node = nil
		self.conn_o[pos].port = nil
		self.node[node].conn_i[port].node = nil
		self.node[node].conn_i[port].port = nil
		self.node[node].conn_i[port].buffer = {} --implement buffers with multiple CS
		return true
	end
	return false
end

-- add new bulb for connecting noodles
local function connAdd(self, pos)
	if self[pos]==nil then
		self[pos] = {node = nil, port = nil, pos = pos, type = nil} --node==nil = disconnected
		self[pos].buf = nil
		table.insert(self.list, self[pos])
	end
end

--add new parameter slider
local function paramAdd(self, name, p, type)
	type = type or "value"
 	--count number of params in array to be referenced to by other parts of the object
 	local n = #self + 1
	if type=="value" then
		self[n] = {name = name, value = {p[3], p[1], p[2], p[3]}, type = "value"}
	elseif type=="text" then
		self[n] = {name = name, value = p, type = "text"}
	else
		error("Unknown parameter type at parameter "..n.."!")
		return nil
	end
	self.n[1] = n
	return n
end

--add new node
function node:new(name, x, y)
	name = name or ""
	x = x or 15
	y = y or 15
	local n = #self + 1
	self.order[n] = n
	self[n] = {
		n = n, 									-- which node in list
		conn_i = {add = connAdd, list ={}},		-- {node, port, position}
		conn_o = {add = connAdd, list ={}},		-- {node, port, position}
		param = {add = paramAdd, n={0}},		-- {name, {value, min, max, default}}
		connect = noodleConnect, 				-- connects node_o with node_i
		disconnect = noodleDisconnect, 			-- disconnects node_o
		processInit = nil,				-- function to execute during processing
			-- prepare output buffers
			-- prepare processing data
			-- call process
			-- clean up
		procFlags = {process = false, output = false},
		ui = {name = name, x = x, y = y, draw = true,
			collapsed=false, buffer=nil},		-- x, y etc...
		draw = nodeDraw,
		node = self,								--go one level back to nodelist from a single node
		profile = {},							--profiler data
		}
	self[n].ui.p = self[n].param.n					--for refering to number of params
	self[n].ui.click = nodeClick
	return self[n]
end

--remove node and move last node in its place
function node:remove(n)
	__sdl.destroySurface(self[n].ui.buffer)
	--clear everything corresponding to node


	local nmax = #self
	
	self[n] = self[nmax]
	self[n].n = n
	
	--rework connections
	for i = 1, nmax - 1 do
		
		n_i = self[i].conn_i
		n_o = self[i].conn_o
		
		if #n_i.list>0 then for j = 1, #n_i.list do
			if n_i.list[j].node==n then n_i.list[j].node = nil end --remove conn
			if n_i.list[j].node==nmax then n_i.list[j].node = n end --move conn to new node
		end end
		
		if #n_o.list>0 then for j = 1, #n_o.list do
			if n_o.list[j].node==n then n_o.list[j].node = nil end
			if n_o.list[j].node==nmax then n_o.list[j].node = n end
		end end
		
	end
	
	--ui order
	local current_order
	for k, v in ipairs(self.order) do
		if v==n then current_order = k end
	end
	for n = current_order, #self-1 do
		self.order[n] = self.order[n+1]
	end
	for k, v in ipairs(self.order) do
		if v==nmax then self.order[k]=n end
	end
	
	self.order[#self] = nil
	self[nmax]=nil
	
end

node.backgrounds = {}
node.backgrounds.window = __sdl.loadImage("background.png")
node.backgrounds.node = __sdl.loadImage("node_t.png")

function node:draw(flag)
	__sdl.blankScreen()
	--add own background image here
	__sdl.blit(node.backgrounds.window, nil, __sdl.screen, nil)
	self.imageProcess(flag)
	drawNoodles(self)
	for n = #self,1,-1 do
		self[self.order[n]]:draw()
	end
	if flag~="noflip" then __sdl.flip() end
end

function node:focus(n)
	--put node on bottom of drawing list
	local a, b
	for k, v in ipairs(self.order) do
		--print(k, v)
		if v==n then a=k b=v end
	end
	for i = a-1, 1, -1 do
		self.order[i+1] = self.order[i]
	end
	self.order[1] = n
end

function node:cleanup()
	__sdl.destroySurface(self.backgrounds.window)
	__sdl.destroySurface(self.backgrounds.node)
end

return node
