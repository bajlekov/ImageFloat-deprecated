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

local node
local img
local lua = __lua
local dbg = require("dbgtools")

require("opsCS")

--node creation
local function add()
	do
		local n=node:new("Input")
		n.ui.x=100
		n.ui.y=100
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
	end

	do
		local n=node:new("Rotate")
		n.param:add("Rotate", {-90,90,0})
		n.ui.x=100
		n.ui.y=200
		n.conn_i:add(0)
		n.conn_o:add(0)
		function n:processRun(num)
			local bufsIn = {}
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
				bufsIn[1] = img.newBuffer({1,1,1})		-- input
				bo[0].buf = img.newBuffer({1,1,1})	-- output
			end

			if bufsIn[1].type==3 or bufsIn[1].type==4 then
				lua.threadSetup(bufsIn[1], bo[0].buf, {p[1].value[1]})
				--DEBUG: buggy rotfast/buggy SDL???
				lua.threadRun("ops", "transform", "rotFast")
				coroutine.yield(num)
			else
				bo[0].buf = bufsIn[1]:copy()
			end
		end
	end

	do
		local n=node:new("Mixer")
		n.ui.x=400
		n.ui.y=200
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
		function n:processRun(num)
			-- start timer
			local bufsIn = {}
			local bi = self.conn_i
			local bo = self.conn_o
			local p = self.param
			--move function to external?
			function getBufIn(p)
				return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
			end
			-- init output buffer same as input 
			-- collect types of input bufs, choose largest combination
			if bi[0].node then
				--if not color then all ops get assigned to same buffer and only blue channel is left because it's processed last
				bufsIn[1] = getBufIn(0):copyColor()			-- input
				--bufsIn[1] = getBufIn(0)			-- input
				bo[0].buf = getBufIn(0):newColor()	-- output
			else
				bufsIn[1] = img.newBuffer({1,1,1})		-- input
				bo[0].buf = img.newBuffer({1,1,1})	-- output
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
			lua.threadSetup({bufsIn[1], bufsIn[2], bufsIn[3], bufsIn[4]}, bo[0].buf)
			lua.threadRun("ops", "mixer")
			coroutine.yield(num)
			--CS process depending on output connection
			--profiler code
		end
	end

	do
		local n=node:new("Add")
		n.ui.x=500
		n.ui.y=400
		n.param:add("Input","Output","text")
		n.param:add("Input","","text")
		n.conn_i:add(1)
		n.conn_i:add(2)
		n.conn_o:add(1)
		--function n:processClear(num)
		--	self.conn_o[1].buf = img.newBuffer(0)
		--end
		function n:processRun(num)
			-- start timer
			local bufsIn = {}
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
			--CS process depending on output connection
			--profiler code
		end
	end

	do
		local zeroBuf = img.newBuffer(0)
		function generic_clean(n)
			for k, v in ipairs(node[n].conn_o.list) do
				v.buf = zeroBuf
			end
		end
	end



	do
		local n=node:new("Split")
		n.ui.x=300
		n.ui.y=400
		n.param:add("Input", "Output", "text")
		n.param:add("", "Output", "text")
		n.param:add("", "Output", "text")
		n.conn_i:add(1)
		n.conn_o:add(1)
		n.conn_o:add(2)
		n.conn_o:add(3)
		function n:processRun(num)
			-- start timer
			local bufsIn = {}
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
		end
	end

	do
		local n=node:new("Decompose")
		n.ui.x=700
		n.ui.y=400
		n.param:add("Input", "R", "text")
		n.param:add("", "G", "text")
		n.param:add("", "B", "text")
		n.conn_i:add(1)
		n.conn_o:add(1)
		n.conn_o:add(2)
		n.conn_o:add(3)
		function n:processRun(num)
			-- start timer
			local bufsIn = {}
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

		end
	end

	do
		local n=node:new("White Balance")
		n.ui.x=500
		n.ui.y=100
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

			--execute
			lua.threadSetup(bo[0].buf, bo[0].buf)
			lua.threadRun("ops", "cs", "SRGB", "XYZ")
			coroutine.yield(num)

			--DEBUG!!!!!!!!!!!!!!!!! infrequent crashes/double free??
			--check output of SRGB->XYZ transform!!

			local tr = vonKriesTransform({x, y, z}, "D65")
			lua.threadSetup(bo[0].buf, bo[0].buf, tr)
			lua.threadRun("ops", "cstransform")
			coroutine.yield(num)

			lua.threadSetup(bo[0].buf, bo[0].buf)
			lua.threadRun("ops", "cs", "XYZ", "SRGB")
			coroutine.yield(num)
			--CS process depending on output connection
			--profiler code
		end
	end

	do
		local n=node:new("Output")
		n.ui.x=1000
		n.ui.y=100
		n.conn_i:add(0)
		n.procFlags.output = true
		function n:processRun(num)
			-- start timer
			local bufsIn = {}
			local bi = self.conn_i
			local p = self.param
			--move function to external?
			function getBufIn(p)
				return self.node[bi[p].node].conn_o[bi[p].port].buf or img.newBuffer(0)
			end


			if bi[0].node then
				bufsIn[1]=getBufIn(0)
				lua.threadSetup(bufsIn[1], self.bufOut)
				lua.threadRun("ops", "copy")
				coroutine.yield(num)
			else
				print("*** node not connected")
			end
		end
	end
end

local function setup(n, i)
	node = n
	img = i
	node.add = add
end


return setup