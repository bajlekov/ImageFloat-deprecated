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

-- use persistent tables for input and output buffers and properties!
-- cleanup already copied buffers!

local lua = __lua
local img = __img
require("opsCS")
local nodeTable = {}

nodeTable["Input"] = function(self)
	local n=self:new("Input")
	n.param:add("File:", "img16.ppm", "text")
	n.param:add("", "Coulour", "text")
	n.param:add("", "Greyscale", "text")
	n.conn_o:add(2)
	n.conn_o:add(3)
	function n:processRun(num)
		local bo = self.conn_o

		bo[2].buf = self.bufIn:copy()
		bo[3].buf = self.bufIn:copyGS()
	end
	return n
end

nodeTable["Color RGB"] = function(self)
	local n=self:new("Color")
	n.param:add("Red", {0,1,1})
	n.param:add("Green", {0,1,1})
	n.param:add("Blue", {0,1,1})
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local r, g, b = self.param[1].value[1], self.param[2].value[1], self.param[3].value[1]

		bo[0].buf = img.newBuffer({r,g,b})
	end
	return n
end

nodeTable["Color LCH"] = function(self)
	local n=self:new("Color")
	n.param:add("Luma", {0,1,1})
	n.param:add("Chroma", {0,1,1})
	n.param:add("Hue", {0,1,1})
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local r, g, b = self.param[1].value[1], self.param[2].value[1], self.param[3].value[1]

		r, g, b = LCHABtoSRGB(r, g, b) 

		bo[0].buf = img.newBuffer({r,g,b})
		coroutine.yield("pass")
	end
	return n
end

nodeTable["Rotate"] = function(self)
	local n=self:new("Rotate")
	n.param:add("Rotate", {-90,90,0})
	n.conn_i:add(0)
	n.conn_o:add(0)
	local bufsIn = {}
	function n:processRun(num)
		local p = self.param
		local bi = self.conn_i
		local bo = self.conn_o

		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer({1,1,1})
		end

		if bi[0].node then
			bufsIn[1] = getBufIn(0)			-- input
			bo[0].buf = getBufIn(0):new()	-- output
		else
			bufsIn[1] = img.newBuffer({0,0,0})		-- input
			bo[0].buf = img.newBuffer({0,0,0})	-- output
		end

		if bufsIn[1].type==3 or bufsIn[1].type==4 then
			lua.threadSetup(bufsIn[1], bo[0].buf, {p[1].value[1]})
			lua.threadRun("ops", "transform", "rotFast")
			coroutine.yield(num)
		else
			bo[0].buf = bufsIn[1]:copy()
		end
		bufsIn = {}
	end
	return n
end

nodeTable["Mixer"] = function(self)
	local n=self:new("Mixer")
	n.param:add("R -> R",{-3,3,1})
	n.param:add("G -> R",{-3,3,0})
	n.param:add("B -> R",{-3,3,0})
	n.param:add("R -> G",{-3,3,0})
	n.param:add("G -> G",{-3,3,1})
	n.param:add("B -> G",{-3,3,0})
	n.param:add("R -> B",{-3,3,0})
	n.param:add("G -> B",{-3,3,0})
	n.param:add("B -> B",{-3,3,1})
	n.conn_i:add(0)
	n.conn_i:add(2)
	n.conn_i:add(5)
	n.conn_i:add(8)
	n.conn_o:add(0)
	-- have internal structure for extra buffers!
	local bufsIn = {}
	--clean up local after use!!!
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o
		local p = self.param
		--move function to external?
		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end
		
		if bi[0].node then
			bufsIn[1] = getBufIn(0):copyColor()			-- input
			bo[0].buf = getBufIn(0):newColor()			-- output
		else
			bufsIn[1] = img.newBuffer({1,1,1})			-- input
			bo[0].buf = img.newBuffer({0,0,0})			-- output
		end

		-- if no input buffers then create from params
		if bi[2].node then
			bufsIn[2] = getBufIn(2)
		else
			bufsIn[2] = img.newBuffer({p[1].value[1], p[2].value[1], p[3].value[1]})
		end
		if bi[5].node then
			bufsIn[3] = getBufIn(5)
		else
			bufsIn[3] = img.newBuffer({p[4].value[1], p[5].value[1], p[6].value[1]})
		end
		if bi[8].node then
			bufsIn[4] = getBufIn(8)
		else
			bufsIn[4] = img.newBuffer({p[7].value[1], p[8].value[1], p[9].value[1]})
		end

		--execute
		print("threads start MIX")
		lua.threadSetup({bufsIn[1], bufsIn[2], bufsIn[3], bufsIn[4]}, bo[0].buf)
		lua.threadRun("ops", "mixer")
		coroutine.yield(num)
		print("threads done MIX")
		bufsIn = {}

		--CS process depending on output connection
		--profiler code
	end
	return n
end

nodeTable["Add"] = function(self)
	local n=self:new("Add")
	n.param:add("Input","Output","text")
	n.param:add("Input","","text")
	n.conn_i:add(1)
	n.conn_i:add(2)
	n.conn_o:add(1)
	--function n:processClear(num)
	--	self.conn_o[1].buf = img.newBuffer(0)
	--end
	local bufsIn = {}
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o
		local p = self.param
		--move function to external?
		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		bufsIn[1] = bi[1].node and getBufIn(1) or img.newBuffer(0)
		bufsIn[2] = bi[2].node and getBufIn(2) or img.newBuffer(0)
		local x, y, z
		x = math.max(bufsIn[1].x, bufsIn[2].x)
		y = math.max(bufsIn[1].y, bufsIn[2].y)
		z = math.max(bufsIn[1].z, bufsIn[2].z)
		bo[1].buf = img.newBuffer(x,y,z)

		--execute
		lua.threadSetup({bufsIn[1], bufsIn[2]}, bo[1].buf)
		lua.threadRun("ops", "add")
		coroutine.yield(num)
		bufsIn = {}
		--CS process depending on output connection
		--profiler code
	end
	return n
end

nodeTable["Split"] = function(self)
	local n=self:new("Split")
	n.param:add("Input", "Output", "text")
	n.param:add("", "Output", "text")
	n.param:add("", "Output", "text")
	n.conn_i:add(1)
	n.conn_o:add(1)
	n.conn_o:add(2)
	n.conn_o:add(3)
	local bufsIn = {}
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o

		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		if bi[1].node then
			bufsIn[1] = getBufIn(1)			-- input
		else
			bufsIn[1] = img.newBuffer(0)		-- input
		end

		bo[1].buf = bufsIn[1]:copy()
		bo[2].buf = bufsIn[1]:copy()
		bo[3].buf = bufsIn[1]:copy()
		bufsIn = {}
	end
	return n
end

nodeTable["Decompose"] = function(self)
	local n=self:new("Decompose")
	n.param:add("Input", "R", "text")
	n.param:add("", "G", "text")
	n.param:add("", "B", "text")
	n.conn_i:add(1)
	n.conn_o:add(1)
	n.conn_o:add(2)
	n.conn_o:add(3)
	local bufsIn = {}
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o

		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		if bi[1].node then
			bufsIn[1] = getBufIn(1)			-- input
		else
			bufsIn[1] = img.newBuffer(0)		-- input
		end

		bo[1].buf = bufsIn[1]:newGS()
		bo[2].buf = bufsIn[1]:newGS()
		bo[3].buf = bufsIn[1]:newGS()

		lua.threadSetup(bufsIn[1], {bo[1].buf, bo[2].buf, bo[3].buf})
		lua.threadRun("ops", "decompose")
		coroutine.yield(num)
		bufsIn = {}
	end
	return n
end

nodeTable["WhiteBalance"] = function(self)
	local n=self:new("White Balance")
	n.param:add("Temperature (K)",{2500,15000,6500})
	n.param:add("MG Tint",{-100,100,0})
	n.param:add("AB Tint",{-100,100,0})
	n.param:add("", "Whitepoint", "text")
	n.conn_i:add(0)
	n.conn_o:add(0)
	n.conn_o:add(4)
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o
		local p = self.param

		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer({1,1,1})
		end

		-- init output buffer same as input
		-- collect types of input bufs, choose largest combination
		if bi[0].node then
			bo[0].buf = getBufIn(0):copyColor()	-- output
			--bo[0].buf = getBufIn(0)
		else
			bo[0].buf = img.newBuffer({1,1,1})	-- output
		end

		local T, G, A = p[1].value[1], p[2].value[1], p[3].value[1]
		local x, y, z = TtoXY(T)
		local gx, gy = norTtoXY(T)
		local ax, ay = tanTtoXY(T)
		local n = dTdMatT(T)
		G, A = G*n, A*n
		gx, gy = gx*G, gy*G
		ax, ay = ax*A, ay*A
		x, y, z = XYtoXYZ(x+gx+ax, y+gy+ay)
		bo[4].buf = img.newBuffer({x,y,z})
		
		--depending on speed it might be better to call just one coroutine.yield()
		lua.threadSetup(bo[0].buf, bo[0].buf)
		lua.threadRun("ops", "cs", "SRGB", "XYZ")
		coroutine.yield(num)
		local tr = vonKriesTransform({x, y, z}, "D65")
		lua.threadSetup(bo[0].buf, bo[0].buf, tr)
		lua.threadRun("ops", "cstransform")
		coroutine.yield(num)
		lua.threadSetup(bo[0].buf, bo[0].buf)
		lua.threadRun("ops", "cs", "XYZ", "SRGB")
		coroutine.yield(num)
		bufsIn = {}
	end
	return n
end

nodeTable["Output"] = function(self)
	local n=self:new("Output")
	n.conn_i:add(0)
	n.procFlags.output = true
	local bufsIn = {}
	function n:processRun(num)
		local bi = self.conn_i
		local p = self.param

		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		if bi[0].node then
			bufsIn[1]=getBufIn(0)
			-- keep multithreaded to allow broadcasting...non-parallel broadcasting copy?
			print("OUTPUT start")
			lua.threadSetup(bufsIn[1], self.bufOut)
			lua.threadRun("ops", "copy")
			coroutine.yield(num)
			print("OUTPUT end")
		else
			print("*** node not connected")
		end
		bufsIn = {}
	end
	return n
end

-- simple multiply node for altering channel levels
-- enhance compose and decompose with intrinsic levels?

nodeTable["Compose"] = function(self)
local n=self:new("Compose")
	n.param:add("R", "Output", "text")
	n.param:add("G", "", "text")
	n.param:add("B", "", "text")
	n.conn_o:add(1)
	n.conn_i:add(1)
	n.conn_i:add(2)
	n.conn_i:add(3)
	local bufsIn = {}
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o

		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		if bi[1].node then
			bufsIn[1] = getBufIn(1)			-- input
		else
			bufsIn[1] = img.newBuffer(0)	-- input
		end
		if bi[2].node then
			bufsIn[2] = getBufIn(2)			-- input
		else
			bufsIn[2] = img.newBuffer(0)	-- input
		end
		if bi[3].node then
			bufsIn[3] = getBufIn(3)			-- input
		else
			bufsIn[3] = img.newBuffer(0)	-- input
		end
		local x, y
		x = math.max(bufsIn[1].x, bufsIn[2].x, bufsIn[3].x)
		y = math.max(bufsIn[1].y, bufsIn[2].y, bufsIn[3].y)
		bo[1].buf = img.newBuffer(x,y,3)

		lua.threadSetup({bufsIn[1], bufsIn[2], bufsIn[3]}, bo[1].buf)
		lua.threadRun("ops", "compose")
		coroutine.yield(num)
		bufsIn = {}
	end
	return n
end

nodeTable["ColorSpace"] = function(self)
	local n=self:new("RGB to XYZ")
	n.conn_i:add(0)
	n.conn_o:add(0)
	local bufsIn = {}
	function n:processRun(num)
		local bi = self.conn_i
		local bo = self.conn_o

		function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer({1,1,1})
		end

		if bi[0].node then
			bufsIn[1] = getBufIn(0):copyColor()			-- input
			bo[0].buf = bufsIn[1]:new()	-- output
		else
			bufsIn[1] = img.newBuffer({1,1,1})		-- input
			bo[0].buf = img.newBuffer({1,1,1})	-- output
		end

		lua.threadSetup(bufsIn[1], bo[0].buf)
		lua.threadRun("ops", "cs", "SRGB", "XYZ")
		coroutine.yield(num)
		bufsIn = {}
	end
	return n
end
	
return nodeTable
