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

-- getters and setters are found in global tables, slowdown?

local ops = {}
ops.cs = require("opsCS")
--ops.fft = require("opsFFT")
ops.transform = require("opsTransform")
ops.filter = require("opsFilter")
ops.layer = require("opsLayer")

require("mathtools")

-- generic pixel function loop
local startstring_matrix = [[
							local s = __global.state
							local b = __global.buf
							local p = __global.params
							local progress	= __global.progress
							local inst	= __global.instance
							local instmax	= __global.instmax
							
							for x = inst, s.xmax-1, instmax do
								if progress[instmax]==-1 then break end
								for y = 0, s.ymax-1 do
									s:up(x, y)
]]

local endstring_matrix = [[
									end
								progress[inst] = x - inst
							end
							progress[inst] = -1
]]


--for value/colour processing:
--local startstring_single = [[ __pp = 0 ]]
--local endstring_single = [[ progress[__instance+1] = -1 ]]

-- TODO: refactor ops, remove inner loops! see Test/opsInterface.lua
ops.strings = {

	invert = [[ -- 2, 1
	for c = 0, 2 do
		b[3]:set( (1-b[1]:get(c))*b[2]:get[2](c) + b[1]:get(c)*(1-b[2]:get(c)), c)
	end ]],

	mixer = [[ -- 4, 1
	b[5]:set( b[2]:get(0)*b[1]:get(0) + b[2]:get(1)*b[1]:get(1) + b[2]:get(2)*b[1]:get(2), 0)
	b[5]:set( b[3]:get(0)*b[1]:get(0) + b[3]:get(1)*b[1]:get(1) + b[3]:get(2)*b[1]:get(2), 1)
	b[5]:set( b[4]:get(0)*b[1]:get(0) + b[4]:get(1)*b[1]:get(1) + b[4]:get(2)*b[1]:get(2), 2)
	]],

	cstransform = [[ --1, 1, {9}
	local c1, c2, c3 = b[1]:get3()
	local p1, p2, p3
	p1 = p[1]*c1 + p[2]*c2 + p[3]*c3
	p2 = p[4]*c1 + p[5]*c2 + p[6]*c3
	p3 = p[7]*c1 + p[8]*c2 + p[9]*c3
	b[2]:set3(p1, p2, p3)
	]],

	copy = [[ -- 1, 1
	b[2]:set3( b[1]:get3())
	]],

	hsxedit = [[ -- 2,1
	local x = b[2]:get(0)+b[1]:get(0)
	x = x>1 and x-1 or x
	b[3]:set( x, 0)
	b[3]:set( b[2]:get(1)*b[1]:get(1), 1)
	b[3]:set( b[2]:get(2)*b[1]:get(2), 2)
	]],

	lchedit = [[ -- 2,1
	local x = b[2]:get(2)+b[1]:get(2)
	x = x>1 and x-1 or x
	b[3]:set( b[2]:get(0)*b[1]:get(0), 0)
	b[3]:set( b[2]:get(1)*b[1]:get(1), 1)
	b[3]:set( x, 2)
	]],

	rgbedit = [[ -- 3,1
	for c = 0, 2 do
		b[4]:set( b[1]:get(c)*b[2]:get(c)+b[3]:get(c) , c)
	end	]],

	compose = [[ -- 3,1
	b[4]:set3( b[1]:get(0), b[2]:get(1), b[3]:get(2) )
	]],

	decompose = [[ -- 1,3
		b[2]:set(b[1]:get(0))
		b[3]:set(b[1]:get(1))
		b[4]:set(b[1]:get(2))
	]],

	merge = [[ -- 3,1
	for c = 0, 2 do
		b[4]:set( b[1]:get(c)*b[3]:get(c) + b[2]:get(c)*(1-b[3]:get(c)), c)
	end	]],

	add = [[ -- 2,1
	for c = 0, 2 do
		b[3]:set( b[1]:get(c) + b[2]:get(c), c)
	end	]],

	sub = [[ -- 2,1
	for c = 0, 2 do
		b[3]:set( b[1]:get(c) - b[2]:get(c), c)
	end	]],

	mult = [[ -- 2,1
	for c = 0, 2 do
		b[3]:set( b[1]:get(c) * b[2]:get(c), c)
	end	]],

	div = [[ -- 2,1
	for c = 0, 2 do
		b[3]:set( b[1]:get(c) / b[2]:get(c), c)
	end	]],

	compMult = [[ -- 4, 2
	for c = 0, 2 do
		b[5]:set( b[1]:get(c)*b[3]:get(c) - b[2]:get(c)*b[4]:get(c), c)
		b[6]:set( b[1]:get(c)*b[4]:get(c) + b[2]:get(c)*b[3]:get(c), c)
	end
	]],

	zero = [[ -- 0,1
	for c = 0, 2 do
		b[1]:set( 0, c)
	end	]],

	equaliseGB = [[ -- 1,1
		local GB = (b[1]:get(1)+b[1]:get(2))/2
		b[2]:set( GB, 1)
		b[2]:set( GB, 2)
	]],

	invertR_GB = [[ -- 1,1
		local GB = 1-b[1]:get(0)
		b[2]:set( GB, 1)
		b[2]:set( GB, 2)
	]],
}

--[[
do
	local function filter(func, flag)
		for x = __instance, xmax/2, __tmax do
			if progress[0]==-1 then break end
			for y = 0, ymax/2 do
				local gauss
				local size = 128 --math.sqrt(xmax^2+ymax^2)
				gauss = func(math.sqrt(x^2+y^2), get[1](0)*size)
				gauss = gauss + (flag and func(math.sqrt((xmax-x+1)^2+y^2), get[1](0)*size) or 0)
				gauss = gauss + (flag and func(math.sqrt(x^2+(ymax-y+1)^2), get[1](0)*size) or 0)
				gauss = gauss + (flag and func(math.sqrt((xmax-x+1)^2+(ymax-y+1)^2), get[1](0)*size) or 0)
				gauss = gauss * get[2]() + 1 - get[2]()
				set3xy[1](gauss, gauss, gauss,x,y)
				if x~=0 then set3xy[1](gauss, gauss, gauss, xmax-x,y) end
				if y~=0 then set3xy[1](gauss, gauss, gauss, x, ymax-y) end
				if x~=0 and y~=0 then set3xy[1](gauss, gauss, gauss, xmax-x, ymax-y) end
			end
			progress[__instance+1] = x - __instance
		end
		progress[__instance+1] = -1
	end

	function ops.gauss() return filter(math.func.gauss) end
	function ops.lorenz() return filter(math.func.lorenz) end
	function ops.gauss_wrap() return filter(math.func.gauss, true) end
	function ops.lorenz_wrap() return filter(math.func.lorenz, true) end
end
--]]

-- construct all pixel functions from ops.strings
for k, v in pairs(ops.strings) do
	ops[k] = loadstring(startstring_matrix..v..endstring_matrix)
end
ops.strings = nil

ops.empty = function() __global.progress[__global.inst] = -1 end



-- refactor to avoid small loops along Z-dim
-- and to avoid compiling of text functions
-- and to avoid overhead for single channel ops

do
-- wrap single channel ops in multichannel functions:
local function wrapChan(fun)
	return function(b, p, zSize)
		if zSize==nil then
			fun(b, p, 0)
			fun(b, p, 1)
			fun(b, p, 2)
		elseif zSize==1 then
			fun(b, p, 0)
		elseif zSize==2 then
			fun(b, p, 0)
			fun(b, p, 1)
		elseif zSize==3 then
			fun(b, p, 0)
			fun(b, p, 1)
			fun(b, p, 2)
		elseif zSize==4 then
			fun(b, p, 0)
			fun(b, p, 1)
			fun(b, p, 2)
			fun(b, p, 3)
		else
			for z = 0, zSize-1 do	-- if none of the above still perform loop
				fun(b, p, z)
			end
		end
	end
end

-- wrap single pixel ops in loops:
local function wrapLoop(fun, preFun)
	return function()	
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		-- preprocessing function, if needed
		if preFun then preFun(b, p, s) end
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			for y = 0, s.ymax-1 do
				s:up(x, y)
				
				-- possibly pass through (x, y) 
				fun(b, p, s.zmax)
				
			end
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
end

-- test code:
--[[
--write function(b, p, z):
local function copy(b, p, z)
	b[2]:set(b[1]:get(z), z)
end
ops.copy = wrapLoop(wrapChan(copy))

local function copy(b, p)
	b[2]:set3(b[1]:get3())
end
ops.copy = wrapLoop(copy)
--]]
end



--[[
ops.norm = function()	-- 1,1
	local sum = {[0]=0, [1]=0, [2]=0}

	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y)
			for c = 0, 2 do
				sum[c] = sum[c] + get[1](c)
			end
		end
		progress[__instance+1] = (x - __instance)/2
	end

	sum[0] = sum[0]==0 and 1 or sum[0]
	sum[1] = sum[1]==0 and 1 or sum[1]
	sum[2] = sum[2]==0 and 1 or sum[2]

	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y)
			for c = 0, 2 do
				set[1](get[1](c)/sum[c], c)
			end
		end
		progress[__instance+1] = (x - __instance)/2 + (xmax-1)/2
	end

	progress[__instance+1] = -1
end
--]]


-- Example functions
--[[
--bufs:[in, out]
ops.copy = function()	
	local s = __global.state
	local b = __global.buf
	local p = __global.params
	local progress	= __global.progress
	local inst	= __global.instance
	local instmax	= __global.instmax
	
	for x = inst, s.xmax-1, instmax do
		if progress[instmax]==-1 then break end
		for y = 0, s.ymax-1 do
			s:up(x, y)
			
			-- main program
			local c1, c2, c3 = b[1]:get3()
			b[2]:set3(c1, c2, c3)
			
		end
		progress[inst] = x - inst
	end
	progress[inst] = -1
end

ops.merge = function()
	local s = __global.state
	local b = __global.buf
	local p = __global.params
	local progress	= __global.progress
	local inst	= __global.instance
	local instmax	= __global.instmax
	
	for x = inst, s.xmax-1, instmax do
		if progress[instmax]==-1 then break end
		for y = 0, s.ymax-1 do
			s:up(x, y)
			
			-- main program
			local a1, a2, a3 = b[1]:get3()
			local b1, b2, b3 = b[2]:get3()
			local f1, f2, f3 = b[3]:get3()
			local c1, c2, c3 = 	a1*f1+b1*(1-f1),
								a2*f2+b2*(1-f2),
								a3*f3+b3*(1-f3)
			b[4]:set3(c1, c2, c3)
			
		end
		progress[inst] = x - inst
	end
	progress[inst] = -1	
end
--]]

return ops