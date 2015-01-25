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

-- use persistent tables for input and output buffers and properties!
-- cleanup already copied buffers!

-- TODO: recycle buffers
-- TODO: skip threaded processing for values and colors

local lua = __lua
local img = __img
local sdl = __sdl

require("Ops.opsCS")
local nodeTable = {}

-- TODO: make defaults immutable!
local empty = img:new(1,1,1) -- no guarantee on content, use as unused output
local zero = img:new(1,1,1)
local one = img:new(1,1,1)
zero:set(0,0,0,0)
one:set(0,0,0,1)

nodeTable["Input"] = function(self)
	local n=self:new("Input")
	n.param:add("File:", __global.setup.imageLoadName, "text")
	n.param:add("", "Colour", "text")
	n.param:add("", "Grayscale", "text")
	n.conn_o:add(2)
	n.conn_o:add(3)
	function n:processRun(num)
		local bo = self.conn_o
		
		-- conditional processing!
		bo[2].buf = bo[2].node and self.bufIn:copy()
		bo[3].buf = bo[3].node and self.bufIn:grayscale()
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

local HSVtoLRGB = HSVtoLRGB
nodeTable["Color HSV"] = function(self)
	local n=self:new("Color")
	n.param:add("Hue", {0,1,1})
	n.param:add("Chroma", {0,1,1})
	n.param:add("Luma", {0,1,1})
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local r, g, b = self.param[1].value[1], self.param[2].value[1], self.param[3].value[1]
		r, g, b = HSVtoLRGB(r, g, b) 
		bo[0].buf = img:newC(r,g,b)
	end
	return n
end


local function getBufIn(self, p, default) -- get linked buffer or empty
	return self.conn_i[p].node and self.node[self.conn_i[p].node].conn_o[self.conn_i[p].port].buf or default or zero
end

nodeTable["Rotate"] = function(self)
	local n=self:new("Rotate")
	n.param:add("Rotate", {-180,180,0})
	n.conn_i:add(0)
	n.conn_o:add(0)
	function n:processRun(num)
		local p = self.param
		local bo = self.conn_o
		local b1 = getBufIn(self, 0)
		
		if b1.x>1 or b1.y>1 then
			bo[0].buf = b1:new()
			lua.threadSetup({b1, bo[0].buf}, {p[1].value[1]})
			lua.threadRun("ops", "transform", "rotFilt")
			coroutine.yield(num)
		else
			bo[0].buf = b1:copy()
		end
	end
	return n
end

nodeTable["Mixer"] = function(self)
	local n=self:new("Mixer")
	n.param:add("R ( R )",{-3,3,1})
	n.param:add("R ( G )",{-3,3,0})
	n.param:add("R ( B )",{-3,3,0})
	n.param:add("G ( R )",{-3,3,0})
	n.param:add("G ( G )",{-3,3,1})
	n.param:add("G ( B )",{-3,3,0})
	n.param:add("B ( R )",{-3,3,0})
	n.param:add("B ( G )",{-3,3,0})
	n.param:add("B ( B )",{-3,3,1})
	n.conn_i:add(0)
	n.conn_i:add(2)
	n.conn_i:add(5)
	n.conn_i:add(8)
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local p = self.param
		local b1 = getBufIn(self, 0)
		
		-- TODO: keep value buffers
		local br = getBufIn(self, 2,
			img:newC(p[1].value[1], p[2].value[1], p[3].value[1]))
		local bg = getBufIn(self, 5,
			img:newC(p[4].value[1], p[5].value[1], p[6].value[1]))
		local bb = getBufIn(self, 8,
			img:newC(p[7].value[1], p[8].value[1], p[9].value[1]))
		
		local x, y = img:checkSuper(b1, br, bg, bb)
		bo[0].buf = b1:new(x, y, 3)
		
		lua.threadSetup({b1, br, bg, bb, bo[0].buf})
		lua.threadRun("ops", "mixer")
		coroutine.yield(num)
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
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 1)
		local b2 = getBufIn(self, 2)
		bo[1].buf = img:newSuper(b1, b2)
		
		lua.threadSetup({b1, b2, bo[1].buf})
		lua.threadRun("ops", "add")
		coroutine.yield(num)
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
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 1)
		local b2 = getBufIn(self, 2)
		local b3 = getBufIn(self, 3, one)
		bo[1].buf = img:newSuper(b1, b2, b3)
		
		lua.threadSetup({b1, b2, b3, bo[1].buf})
		lua.threadRun("ops", "merge")
		coroutine.yield(num)
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
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 1)
		bo[1].buf = bo[1].node and b1:copy()
		bo[2].buf = bo[2].node and b1:copy()
		bo[3].buf = bo[3].node and b1:copy()
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
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 1)
		bo[1].buf = bo[1].node and b1:newM() or empty
		bo[2].buf = bo[2].node and b1:newM() or empty
		bo[3].buf = bo[3].node and b1:newM() or empty
		
		lua.threadSetup({b1, bo[1].buf, bo[2].buf, bo[3].buf})
		lua.threadRun("ops", "decompose")
		coroutine.yield(num)
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
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 1)
		local b2 = b1:newI() -- copy and in-place transfor or new and move
		
		lua.threadSetup({b1, b2})
		lua.threadRun("ops", "cs", "LRGB", "LCHAB")
			-- create buffers in parallel
			bo[1].buf = bo[1].node and b2:newM() or empty
			bo[2].buf = bo[2].node and b2:newM() or empty
			bo[3].buf = bo[3].node and b2:newM() or empty
		coroutine.yield(num)
		
		lua.threadSetup({b2, bo[1].buf, bo[2].buf, bo[3].buf})
		lua.threadRun("ops", "decompose")
		coroutine.yield(num)
	end
	return n
end

local TtoXY = TtoXY
local norTtoXY = norTtoXY
local tanTtoXY = tanTtoXY
local dTdMatT = dTdMatT
local vonKriesTransform = vonKriesTransform
local XYtoXYZ = XYtoXYZ
local XYZtoLRGB = XYZtoLRGB
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
		local bo = self.conn_o
		local p = self.param
		
		-- perform in parallel to RGB -> XYZ transform?
		local T, G, A = p[1].value[1], p[2].value[1], p[3].value[1]
		local x, y, z = TtoXY(T)
		local gx, gy = norTtoXY(T)
		local ax, ay = tanTtoXY(T)
		local n = dTdMatT(T)
		G, A = G*n, A*n
		gx, gy = gx*G, gy*G
		ax, ay = ax*A, ay*A
		x, y, z = XYtoXYZ(x+gx+ax, y+gy+ay)
		
		bo[4].buf = bo[4].node and img:newC(XYZtoLRGB(x,y,z))
		if bo[0].node then
			local b1 = getBufIn(self, 0)
			bo[0].buf = b1:newI()
			
			-- TODO: fuse ops
			lua.threadSetup({b1, bo[0].buf})
			lua.threadRun("ops", "cs", "LRGB", "XYZ")
				local tr = vonKriesTransform({x, y, z}, "D65")
			coroutine.yield(num)
			lua.threadSetup({bo[0].buf, bo[0].buf}, tr)
			lua.threadRun("ops", "cstransform")
			coroutine.yield(num)
			lua.threadSetup({bo[0].buf, bo[0].buf})
			lua.threadRun("ops", "cs", "XYZ", "LRGB")
			coroutine.yield(num)
		end
	end
	return n
end

nodeTable["Output"] = function(self)
	local n=self:new("Output")
	n.conn_i:add(0)
	n.procFlags.output = true
	function n:processRun(num)
		local bi = self.conn_i
		local p = self.param
		
		if bi[0].node then
			-- FIXME: move broadcasting to surface conversion
			-- TODO: read source CS from input when available
			lua.threadSetup({getBufIn(self, 0), self.bufOut})
			lua.threadRun("ops", "cs", "LRGB", "SRGB")
			coroutine.yield(num)
		else
			io.write("*** node not connected\n")
		end
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
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 1)
		local b2 = getBufIn(self, 2)
		local b3 = getBufIn(self, 3)
		local x, y = img:checkSuper(b1, b2, b3)
		bo[1].buf = img:new(x,y,3)
		
		lua.threadSetup({b1, b2, b3, bo[1].buf})
		lua.threadRun("ops", "compose")
		coroutine.yield(num)
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
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 1)
		local b2 = getBufIn(self, 2)
		local b3 = getBufIn(self, 3)
		local x, y = img:checkSuper(b1, b2, b3)
		bo[1].buf = img:new(x,y,3)
		
		lua.threadSetup({b1, b2, b3, bo[1].buf})
		lua.threadRun("ops", "compose")
		coroutine.yield(num)
		lua.threadSetup({bo[1].buf, bo[1].buf})
		lua.threadRun("ops", "cs", "LCHAB", "LRGB")
		coroutine.yield(num)
	end
	return n
end

nodeTable["ColorSpace"] = function(self)
	local n=self:new("RGB to XYZ")
	n.conn_i:add(0)
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 0)
		bo[0].buf = b1:new()
		
		lua.threadSetup({b1, bo[0].buf})
		lua.threadRun("ops", "cs", "LRGB", "XYZ")
		coroutine.yield(num)
	end
	return n
end

-- FIXME: does not work
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
		bo[0].buf = img:new(__global.imageSize[1], __global.imageSize[2], 1)
		print(bo[0].buf)
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
		bo[0].buf = img:new(__global.imageSize[1], __global.imageSize[2], 1)
		
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
	function n:processRun(num)
		local bo = self.conn_o
		local p = self.param
		local b1 = getBufIn(self, 0)
		
		if b1.x>1 or b1.y>1 then
			local blur = p[1].value[1]^2
			local tempBuf = b1:new()
			
			lua.threadSetup({b1, tempBuf}, blur)
			lua.threadRun("ops", "transform", "gaussH")
				bo[0].buf = b1:new()
			coroutine.yield(num)
			lua.threadSetup({tempBuf, bo[0].buf}, blur)
			lua.threadRun("ops", "transform", "gaussV")
			coroutine.yield(num)
			lua.threadSetup({bo[0].buf, bo[0].buf}, blur)
			lua.threadRun("ops", "transform", "gaussCorrect")
			coroutine.yield(num)
		else
			bo[0].buf = b1:copy()
		end
	end
	return n
end

nodeTable["Gamma"] = function(self)
	local n=self:new("Gamma")
	n.param:add("Power", {0,5,1})
	n.conn_i:add(0)
	n.conn_o:add(0)
	function n:processRun(num)
		local bo = self.conn_o
		local b1 = getBufIn(self, 0)
		bo[0].buf = b1:new()
		lua.threadSetup({b1 , bo[0].buf}, self.param[1].value[1])
		lua.threadRun("ops", "cs", "gamma")
		coroutine.yield(num)
	end
	return n
end
	
return nodeTable
