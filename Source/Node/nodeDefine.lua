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

-- use persistent tables for input and output buffers and properties!
-- cleanup already copied buffers!

local lua = __lua
local img = __img

-- FIXME: other way to include CS ops!
require("opsCS")
local nodeTable = {}

-- FIXME: remove function declarations from process!!! 

nodeTable["Input"] = function(self)
	local n=self:new("Input")
	n.param:add("File:", __global.setup.imageLoadName, "text")
	n.param:add("", "Coulour", "text")
	n.param:add("", "Greyscale", "text")
	n.conn_o:add(2)
	n.conn_o:add(3)
	function n:processRun(num)
		local bo = self.conn_o

		bo[2].buf = self.bufIn:copy()
		bo[3].buf = self.bufIn:copyG()
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

		bo[0].buf = img:newC(r,g,b)
	end
	return n
end

nodeTable["Color HSV"] = function(self)
	local n=self:new("Color")
	n.param:add("Hue", {0,1,1})
	n.param:add("Chroma", {0,1,1})
	n.param:add("Luma", {0,1,1})
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local r, g, b = self.param[1].value[1], self.param[2].value[1], self.param[3].value[1]

		r, g, b = HSVtoSRGB(r, g, b) 

		bo[0].buf = img:newC(r,g,b)
		--coroutine.yield("pass")
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

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newC(1)
		end

		if bi[0].node then
			bufsIn[1] = getBufIn(0)			-- input
			bo[0].buf = getBufIn(0):new()	-- output
		else
			bufsIn[1] = img:newC()		-- input
			bo[0].buf = img:newC()		-- output
		end

		if bufsIn[1]:type()==3 or bufsIn[1]:type()==4 then
			lua.threadSetup({bufsIn[1], bo[0].buf}, {p[1].value[1]})
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
		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newV()
		end
		
		if bi[0].node then
			bufsIn[1] = getBufIn(0):copyC()			-- input
			bo[0].buf = getBufIn(0):newI()			-- output
		else
			bufsIn[1] = img:newC(1)			-- input
			bo[0].buf = img:newC()			-- output
		end

		-- if no input buffers then create from params
		if bi[2].node then
			bufsIn[2] = getBufIn(2)
		else
			bufsIn[2] = img:newC(p[1].value[1], p[2].value[1], p[3].value[1])
		end
		if bi[5].node then
			bufsIn[3] = getBufIn(5)
		else
			bufsIn[3] = img:newC(p[4].value[1], p[5].value[1], p[6].value[1])
		end
		if bi[8].node then
			bufsIn[4] = getBufIn(8)
		else
			bufsIn[4] = img:newC(p[7].value[1], p[8].value[1], p[9].value[1])
		end

		--execute
		lua.threadSetup({bufsIn[1], bufsIn[2], bufsIn[3], bufsIn[4], bo[0].buf})
		lua.threadRun("ops", "mixer")
		coroutine.yield(num)
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
	local bufsIn = {}
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o
		local p = self.param
		--move function to external?
		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		bufsIn[1] = bi[1].node and getBufIn(1) or img:newV()
		bufsIn[2] = bi[2].node and getBufIn(2) or img:newV()
		local x, y, z
		x = math.max(bufsIn[1].x, bufsIn[2].x)
		y = math.max(bufsIn[1].y, bufsIn[2].y)
		z = math.max(bufsIn[1].z, bufsIn[2].z)
		bo[1].buf = img:new(x,y,z)

		--execute
		lua.threadSetup({bufsIn[1], bufsIn[2], bo[1].buf})
		lua.threadRun("ops", "add")
		coroutine.yield(num)
		bufsIn = {}
		--CS process depending on output connection
		--profiler code
	end
	return n
end

nodeTable["Merge"] = function(self)
	local n=self:new("Merge")
	n.param:add("Input","Output","text")
	n.param:add("Input","","text")
	n.param:add("Factor","","text")
	n.conn_i:add(1)
	n.conn_i:add(2)
	n.conn_i:add(3)
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
		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		bufsIn[1] = bi[1].node and getBufIn(1) or img:newV()
		bufsIn[2] = bi[2].node and getBufIn(2) or img:newV()
		bufsIn[3] = bi[3].node and getBufIn(3) or img:newV(1)
		
		local x, y, z
		x = math.max(bufsIn[1].x, bufsIn[2].x, bufsIn[3].x)
		y = math.max(bufsIn[1].y, bufsIn[2].y, bufsIn[3].y)
		z = math.max(bufsIn[1].z, bufsIn[2].z, bufsIn[3].z)
		bo[1].buf = img:new(x,y,z)

		--execute
		lua.threadSetup({bufsIn[1], bufsIn[2], bufsIn[3], bo[1].buf})
		lua.threadRun("ops", "merge")
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

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newV()
		end

		if bi[1].node then
			bufsIn[1] = getBufIn(1)			-- input
		else
			bufsIn[1] = img:newV(0)		-- input
		end

		bo[1].buf = bufsIn[1]:copy()
		bo[2].buf = bufsIn[1]:copy()
		bo[3].buf = bufsIn[1]:copy()
		bufsIn = {}
	end
	return n
end

nodeTable["DecomposeRGB"] = function(self)
	local n=self:new("Decompose RGB")
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

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		if bi[1].node then
			bufsIn[1] = getBufIn(1)			-- input
		else
			bufsIn[1] = img:newV()		-- input
		end

		bo[1].buf = bufsIn[1]:newM()
		bo[2].buf = bufsIn[1]:newM()
		bo[3].buf = bufsIn[1]:newM()

		lua.threadSetup({bufsIn[1], bo[1].buf, bo[2].buf, bo[3].buf})
		lua.threadRun("ops", "decompose")
		coroutine.yield(num)
		bufsIn = {}
	end
	return n
end

nodeTable["DecomposeLCH"] = function(self)
	local n=self:new("Decompose LCH")
	n.param:add("Input", "L", "text")
	n.param:add("", "C", "text")
	n.param:add("", "H", "text")
	n.conn_i:add(1)
	n.conn_o:add(1)
	n.conn_o:add(2)
	n.conn_o:add(3)
	local bufsIn = {}
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
		end

		if bi[1].node then
			bufsIn[1] = getBufIn(1)			-- input
		else
			bufsIn[1] = img:newV()		-- input
		end

		bo[1].buf = bufsIn[1]:newM()
		bo[2].buf = bufsIn[1]:newM()
		bo[3].buf = bufsIn[1]:newM()
		
		lua.threadSetup({bufsIn[1], bufsIn[1]})
		lua.threadRun("ops", "cs", "SRGB", "LCHAB")
		coroutine.yield(num)
		lua.threadSetup({bufsIn[1], bo[1].buf, bo[2].buf, bo[3].buf})
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

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newC(1)
		end

		-- init output buffer same as input
		-- collect types of input bufs, choose largest combination
		if bi[0].node then
			bo[0].buf = getBufIn(0):copyC()	-- output
		else
			bo[0].buf = img:newC(1)	-- output
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
		bo[4].buf = img:newC(x,y,z)
		
		--depending on speed it might be better to call just one coroutine.yield() ??
		
		-- fuse ops!! check on how to do it for ispc code ...
		lua.threadSetup({bo[0].buf, bo[0].buf})
		lua.threadRun("ops", "cs", "SRGB", "XYZ")
		coroutine.yield(num)
		local tr = vonKriesTransform({x, y, z}, "D65")
		lua.threadSetup({bo[0].buf, bo[0].buf}, tr)
		lua.threadRun("ops", "cstransform")
		coroutine.yield(num)
		lua.threadSetup({bo[0].buf, bo[0].buf})
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

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newV(1)
		end
		
		--[[
		if bi[0].node then
			self.bufOut = getBufIn(0):copyC()
		else
			print("*** node not connected")
			-- needs to refresh buffer!
		end
		--]]
		--FIXME: needs to scale up to full image if only a color or value is passed!!

		if bi[0].node then
			bufsIn[1]=getBufIn(0):copyC() --FIXME: better way to handle GS => color
			-- keep multithreaded to allow broadcasting...non-parallel broadcasting copy?
			lua.threadSetup({bufsIn[1], self.bufOut})
			lua.threadRun("ops", "copy")
			coroutine.yield(num)
		else
			print("*** node not connected")
			-- needs to refresh buffer!
		end
		
		bufsIn = {}
	end
	return n
end

-- simple multiply node for altering channel levels
-- enhance compose and decompose with intrinsic levels?

nodeTable["ComposeRGB"] = function(self)
local n=self:new("Compose RGB")
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

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newV()
		end

		if bi[1].node then
			bufsIn[1] = getBufIn(1)			-- input
		else
			bufsIn[1] = img:newV()	-- input
		end
		if bi[2].node then
			bufsIn[2] = getBufIn(2)			-- input
		else
			bufsIn[2] = img:newV()	-- input
		end
		if bi[3].node then
			bufsIn[3] = getBufIn(3)			-- input
		else
			bufsIn[3] = img:newV()	-- input
		end
		local x, y
		x = math.max(bufsIn[1].x, bufsIn[2].x, bufsIn[3].x)
		y = math.max(bufsIn[1].y, bufsIn[2].y, bufsIn[3].y)
		bo[1].buf = img:new(x,y,3)

		lua.threadSetup({bufsIn[1], bufsIn[2], bufsIn[3], bo[1].buf})
		lua.threadRun("ops", "compose")
		coroutine.yield(num)
		bufsIn = {}
	end
	return n
end

nodeTable["ComposeLCH"] = function(self)
local n=self:new("Compose LCH")
	n.param:add("L", "Output", "text")
	n.param:add("C", "", "text")
	n.param:add("H", "", "text")
	n.conn_o:add(1)
	n.conn_i:add(1)
	n.conn_i:add(2)
	n.conn_i:add(3)
	local bufsIn = {}
	function n:processRun(num)
		-- start timer
		local bi = self.conn_i
		local bo = self.conn_o

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newV()
		end

		if bi[1].node then
			bufsIn[1] = getBufIn(1)			-- input
		else
			bufsIn[1] = img:newV()	-- input
		end
		if bi[2].node then
			bufsIn[2] = getBufIn(2)			-- input
		else
			bufsIn[2] = img:newV()	-- input
		end
		if bi[3].node then
			bufsIn[3] = getBufIn(3)			-- input
		else
			bufsIn[3] = img:newV()	-- input
		end
		local x, y
		x = math.max(bufsIn[1].x, bufsIn[2].x, bufsIn[3].x)
		y = math.max(bufsIn[1].y, bufsIn[2].y, bufsIn[3].y)
		bo[1].buf = img:new(x,y,3)
		
		lua.threadSetup({bufsIn[1], bufsIn[2], bufsIn[3], bo[1].buf})
		lua.threadRun("ops", "compose")
		coroutine.yield(num)
		lua.threadSetup({bo[1].buf, bo[1].buf})
		lua.threadRun("ops", "cs", "LCHAB", "SRGB")
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

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newC(1)
		end

		if bi[0].node then
			bufsIn[1] = getBufIn(0):copyC()			-- input
			bo[0].buf = bufsIn[1]:new()	-- output
		else
			bufsIn[1] = img:newC(1)		-- input
			bo[0].buf = img:newC(1)	-- output
		end

		lua.threadSetup({bufsIn[1], bo[0].buf})
		lua.threadRun("ops", "cs", "SRGB", "XYZ")
		coroutine.yield(num)
		bufsIn = {}
	end
	return n
end

-- FIXME: reference size 
nodeTable["GradientRot"] = function(self)
	local n=self:new("Gradient")
	n.param:add("X", {-1,1,0})
	n.param:add("Y", {-1,1,0})
	n.param:add("Offset", {0,1,0})
	n.param:add("Width", {0,1,0.2})
	n.param:add("Intensity", {0,1,0.2})
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local p = self.param
		
		--
		bo[0].buf = img:new(__global.imageSize[1], __global.imageSize[2], 1)
		
		-- FIXME: don't require passing input/output buffers to thread
		lua.threadSetup(bo[0].buf, {p[1].value[1], p[2].value[1], p[3].value[1], p[4].value[1], p[5].value[1]})
		lua.threadRun("ops", "transform", "gradRot")
		coroutine.yield(num)
	end
	return n
end

nodeTable["GradientLin"] = function(self)
	local n=self:new("Gradient")
	n.param:add("Angle", {-180,180,0})
	n.param:add("Offset", {-1,1,0})
	n.param:add("Width", {0,1,0.2})
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local p = self.param
		
		--
		bo[0].buf = img:new(__global.imageSize[1], __global.imageSize[2], 1)
		
		-- FIXME: don't require passing input/output buffers to thread
		lua.threadSetup(bo[0].buf, {p[1].value[1], p[2].value[1], p[3].value[1]})
		lua.threadRun("ops", "transform", "gradLin")
		coroutine.yield(num)
	end
	return n
end

nodeTable["Gaussian"] = function(self)
	local n=self:new("Gaussian")
	n.param:add("Width", {0,1,0.1})
	n.conn_i:add(0)
	n.conn_o:add(0)
	
	local bufsIn = {}
	
	function n:processRun(num)
		local bo = self.conn_o
		local bi = self.conn_i
		local p = self.param
		
		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newC(1)
		end
		
		local tempBuf
		if bi[0].node then
			bufsIn[1] = getBufIn(0)		-- input
			bo[0].buf = bufsIn[1]:new()	-- output
			tempBuf = bufsIn[1]:new()	-- temporary
		else
			bufsIn[1] = img:newV()		-- input
			bo[0].buf = bufsIn[1]:new()	-- output
			tempBuf = bufsIn[1]:new()	-- temporary
		end
		
		local blur = p[1].value[1]^2
		
		lua.threadSetup({bufsIn[1], tempBuf}, blur)
		lua.threadRun("ops", "transform", "gaussH")
		coroutine.yield(num)
		lua.threadSetup({tempBuf, bo[0].buf}, blur)
		lua.threadRun("ops", "transform", "gaussV")
		coroutine.yield(num)
		lua.threadSetup({bo[0].buf, bo[0].buf}, blur)
		lua.threadRun("ops", "transform", "gaussCorrect")
		coroutine.yield(num)
	end
	return n
end

nodeTable["Gamma"] = function(self)
	local n=self:new("Gamma")
	n.param:add("Power", {0,5,1})
	n.conn_i:add(0)
	n.conn_o:add(0)
	local bufsIn = {}
	function n:processRun(num)
		local bi = self.conn_i
		local bo = self.conn_o

		local function getBufIn(p)
			return self.node[bi[p].node].conn_o[bi[p].port].buf or img:newC(1)
		end

		if bi[0].node then
			bufsIn[1] = getBufIn(0):copy()			-- input
			bo[0].buf = bufsIn[1]:new()	-- output
		else
			bufsIn[1] = img:newV()		-- input
			bo[0].buf = img:newV()	-- output
		end

		lua.threadSetup({bufsIn[1], bo[0].buf}, self.param[1].value[1])
		lua.threadRun("ops", "cs", "gamma")
		coroutine.yield(num)
		bufsIn = {}
	end
	return n
end
	
return nodeTable
