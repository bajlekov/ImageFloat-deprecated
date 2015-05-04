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

--require("../Lua/lua_utils.lua")
require("Node.nodeDraw")

-- pass struct instead of globals
local nodeDraw = nodeDraw
local drawNoodles = drawNoodles
local drawNoodle = drawNoodle
local drawNoodleLoose = drawNoodleLoose
local font = font
local sdl = __sdl
local __global = __global

-- create initial node structure
local node = {drawOrder={}, execOrder={}, levels={}, noExec={}, exec={}}			-- used for execution, set in node:calcLevels
--function node:setInput(input) self.mouse = input end							-- register input function
function node:setImageProcess(input) self.imageProcess = input end				-- register image processing
function node.imageProcess() end												-- set initial empty function

function node:nodeDrag(n)
	while sdl.input.button[1] do
		sdl.input.update()
		self[n].ui.x = self[n].ui.x + sdl.input.dx
		self[n].ui.y = self[n].ui.y + sdl.input.dy
		self:draw()
	end
end

function node:paramDrag(n, p)
	local v = self[n].param[p].value[1]
	local vmin = self[n].param[p].value[2]
	local vmax = self[n].param[p].value[3]
	local vrange = vmax-vmin

	while sdl.input.button[1] do
		sdl.input.update()

		-- FIXME: allready checked before?
		if self[n].param[p].type~="value" then break end --have check earlier and update data

		local fac = sdl.input.mod.shift and 10 or 1
		v = v + sdl.input.dx/148/fac*vrange
		if v>vmax then v=vmax end
		if v<vmin then v=vmin end
		if sdl.input.mod.alt then v = self[n].param[p].value[4] end
		if sdl.input.mod.ctrl then
			local unit = vrange/(sdl.input.mod.shift and 100 or 10)
			self[n].param[p].value[1] = vmin + math.floor(((v-vmin)/unit+0.5))*unit
		else
			self[n].param[p].value[1] = v
		end
		self[n].ui.draw=true
		self:draw("process")
	end
end

function node:noodleDrag(n, p)
	self[n]:disconnect(p) --disconnect old connection
	while sdl.input.button[1] do
		sdl.input.update()

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
			drawNoodleLoose(self[n].ui.x, self[n].ui.y, sdl.input.x, sdl.input.y, p)
		end
		sdl.update()
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


local function checkPos(r, self)
	local x = sdl.input.x
	local y = sdl.input.y
	local ox = self.x
	local oy = self.y
	if x>=r[1]+ox and x<=r[2]+ox and y>=r[3]+oy and y<=r[4]+oy then return true end
end


local nodeClick
do
	local areas = {
		node = {-13, 162, -2, 0},
		title = {0, 149, 0, 19},
		params = {0, 149, 21, 0},
		connL = {-12, -1, 7, 0},
		connR = {150, 161, 7, 0},
	}
	local areaNames = {"node", "title", "params", "connL", "connR"}
	function nodeClick(self, part)
		-- FIXME: functionality: if part~=nil then check if part is clicked, else return clicked part
		local offset = 21+12*self.p[1]
		areas.node[4] = offset + 2
		areas.params[4] = offset
		areas.connL[4] = offset
		areas.connR[4] = offset


		if part~=nil then
			local area = areas[part]

			if checkPos(area, self) then
				if part=="params" then
					local p = math.floor((sdl.input.y - self.y - 22)/ 12) + 1
					if p==0 then return 1 else return p end --correct for math.floor
				end
				if part=="connL" or part=="connR" then
					if sdl.input.y>=self.y+7 and sdl.input.y<=self.y+19 then return 0 end
					local p = math.floor((sdl.input.y - self.y - 22)/ 12) + 1
					return p>0 and p or nil
				end
				--for title return button end
				return true
			end
		else
			for i = 1, 5 do -- FIXME: replace pairs -> keep track of size of areas
				local k = areaNames[i]
				local p = nodeClick(self, k)
				if p and k~="node" then return p, k end
			end
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
		self[pos] = {node=nil, port=nil, pos=pos, buf=nil} --node==nil = disconnected
		table.insert(self.list, self[pos])
	end
end

--add new parameter slider
local function paramAdd(self, name, p, type)
	type = type or "value"
	--count number of params in array to be referenced to by other parts of the object
	local n = #self + 1
	if type=="value" then
		self[n] = {name=name, value={p[3], p[1], p[2], p[3]}, type="value"}
	elseif type=="text" then
		self[n] = {name=name, value=p, type="text"}
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
	self.drawOrder[n] = n
	self[n] = {
		n = n, 									-- which node in list
		conn_i	= {add=connAdd, list={}},		-- {node, port, position}
		conn_o	= {add=connAdd, list={}},		-- {node, port, position}
		param	= {add=paramAdd, n={0}},		-- {name, {value, min, max, default}}
		connect = noodleConnect, 				-- connects node_o with node_i
		disconnect = noodleDisconnect, 			-- disconnects node_o
		--unused: processInit = nil,				-- function to execute during processing
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
	self[n].ui.p = self[n].param.n				--for refering to number of params
	self[n].ui.click = nodeClick
	return self[n]
end

--remove node and move last node in its place
function node:remove(n)
	self[n].ui.buffer = nil
	--clear everything corresponding to node

	local nmax = #self

	self[n] = self[nmax]
	self[n].n = n

	--rework connections
	for i = 1, nmax - 1 do

		local n_i = self[i].conn_i
		local n_o = self[i].conn_o

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
	for k, v in ipairs(self.drawOrder) do
		if v==n then current_order = k end
	end
	for n = current_order, #self-1 do
		self.drawOrder[n] = self.drawOrder[n+1]
	end
	for k, v in ipairs(self.drawOrder) do
		if v==nmax then self.drawOrder[k]=n end
	end

	self.drawOrder[#self] = nil
	self[nmax]=nil	
end

-- put in resources table
node.backgrounds = {}
node.backgrounds.window = sdl.surf.image(__global.imgPath.."background.png")
node.backgrounds.node = sdl.surf.image(__global.imgPath.."node_t.png")

--destroy backgrounds at end?

local helpText = {
	"ImageFloat",
	"Copyright (C) 2011-2014 G.Bajlekov",
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

function node:draw(flag)
	-- see if drawing can be reduced when no update is available!!

	--sdl.surf.copy(node.backgrounds.window, sdl.screen.surf) --draws background
	sdl.draw.clear(sdl.screen.surf)

	-- TODO: use dirty rect updating
	-- TODO: use sdl2 renderers

	self.imageProcess(flag) -- puts image on screen
	drawNoodles(self) -- draws noodles

	--help text
	sdl.font.type(__global.ttfPath.."UbuntuR.ttf", 11)
	sdl.font.color(128, 64, 64)
	if __global.info then
		for k, v in ipairs(helpText) do
			sdl.draw.text(__global.setup.windowSize[1] - 220, 10 + k*10, v)
		end
	end

	for n = #self,1,-1 do
		self[self.drawOrder[n]]:draw()
	end
	if flag~="noflip" then sdl.update() end
end

function node:focus(n)
	--put node on bottom of drawing list
	local a, b
	for k, v in ipairs(self.drawOrder) do
		--print(k, v)
		if v==n then a=k b=v end
	end
	for i = a-1, 1, -1 do
		self.drawOrder[i+1] = self.drawOrder[i]
	end
	self.drawOrder[1] = n
end

function node:cleanup()
-- currently empty, everything is GC'd
end

do
	local c = require("Math.boolops") 
	function node:calcLevels()
		local current = {}
		local level = 1
		local tree = {}
		local error = false

		local collect = c.collect
		local negate = c.cNot
		local list = c.list

		--return nodes connected to node n
		local function connected(n, flag)
			local o = {}
			for _, v in ipairs(self[n][flag and "conn_o" or "conn_i"].list) do
				if v.node then o[v.node] = true end
			end
			return list(o), o
		end

		--add all nodes that can be used as generators
		for k, v in ipairs(node) do
			if v.procFlags.output then table.insert(current, k) end
		end

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

			if level>#self+1 then __dbg.error("Loop detected! Wrong node connections. FIXME") end
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

			-- display node tree
			--[[
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

		--invert execOrder
		local tempOrder = {}
		for i = 1, #self.execOrder do
			tempOrder[#self.execOrder-i+1] = self.execOrder[i]
		end
		self.execOrder = tempOrder
		tempOrder = nil

		--print(unpack(self.execOrder))

		self.exec = allProc
		self.noExec = list(noProc)

		-- refresh view
		-- NYI: bytecode 50 at node.lua:448
		for _, v in ipairs(self) do
			-- FIXME: possibly keep track of number of nodes and use a regular loop instead of an iterator
			-- then again, this is not (or shouldn't be) performance-sensitive code
			v.ui.draw=true
		end
		sdl.update()
	end
end


return node
