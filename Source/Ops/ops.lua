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

-- getters and setters are found in global tables, slowdown?

local ops = {}
ops.cs = require("opsCS")
--ops.fft = require("opsFFT")
ops.transform = require("opsTransform")
ops.filter = require("opsFilter")
ops.layer = require("opsLayer")

require("mathtools")
local ffi = require("ffi")

-- function to synchronise between a multi-pass operation
local function syncThreads()
	print("WARNING: the syncThreads function is not stable!")
	local progress	= __global.progress
	local inst		= __global.instance
	local instmax	= __global.instmax
	local old = progress[inst]
	
	progress[inst] = -2 -- set thread to waiting
	local hold = true
	
	while hold do
		hold = false
		for i = 0, instmax-1 do
			if progress[i]~=-2 then
				hold = true
				break
			end
		end
		
		__sdl.lockMutex(__mut)
		if progress[inst]==-3 then
			hold = false
		elseif hold==false then
			for i = 0, instmax-1 do
				progress[i] = -3
			end
			hold = false
		end
		__sdl.unlockMutex(__mut)
	end
	
	progress[inst] = old --return to old state
end

-- refactor to avoid small loops along Z-dim
-- and to avoid compiling of text functions
-- and to avoid overhead for single channel ops

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

-- make wrapper functions available through __global.tools
__global.tools = {wrapChan=wrapChan, wrapLoop=wrapLoop, syncThreads=syncThreads}

local function invert(b, p, c) -- 2, 1
	b[3]:set( (1-b[1]:get(c))*b[2]:get(c) + b[1]:get(c)*(1-b[2]:get(c)), c)
end
ops.invert = wrapLoop(wrapChan(invert))


local function mixer(b, p) -- 4, 1
	b[5]:set( b[2]:get(0)*b[1]:get(0) + b[2]:get(1)*b[1]:get(1) + b[2]:get(2)*b[1]:get(2), 0)
	b[5]:set( b[3]:get(0)*b[1]:get(0) + b[3]:get(1)*b[1]:get(1) + b[3]:get(2)*b[1]:get(2), 1)
	b[5]:set( b[4]:get(0)*b[1]:get(0) + b[4]:get(1)*b[1]:get(1) + b[4]:get(2)*b[1]:get(2), 2)
end
ops.mixer = wrapLoop(mixer)

local function cstransform(b, p) -- 1, 1, 9
	local c1, c2, c3 = b[1]:get3()
	local p1, p2, p3
	p1 = p[1]*c1 + p[2]*c2 + p[3]*c3
	p2 = p[4]*c1 + p[5]*c2 + p[6]*c3
	p3 = p[7]*c1 + p[8]*c2 + p[9]*c3
	b[2]:set3(p1, p2, p3)
end 
ops.cstransform = wrapLoop(cstransform)

if __global.setup.optCompile.ispc then
	function ops.cstransform()		
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		local mul = __global.ISPC.ispc_mat3mul
		local mat = ffi.new("float[9]", p)
		
		if s.zmax~=3 then print("ERROR: wrong dimensions!") end
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			
			mul(b[1].data + x*s.ymax*s.zmax, b[2].data + x*s.ymax*s.zmax, mat, s.ymax*s.zmax)
			
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
end

local function copy(b, p, z) -- 1, 1
	b[2]:set(b[1]:get(z), z)
end
ops.copy = wrapLoop(wrapChan(copy))


local function hsxedit(b, p) -- 2, 1
	local x = b[2]:get(0)+b[1]:get(0)
	x = x>1 and x-1 or x
	b[3]:set( x, 0)
	b[3]:set( b[2]:get(1)*b[1]:get(1), 1)
	b[3]:set( b[2]:get(2)*b[1]:get(2), 2)
end
ops.hsxedit = wrapLoop(hsxedit)

local function lchedit(b, p) -- 2, 1
local x = b[2]:get(2)+b[1]:get(2)
x = x>1 and x-1 or x
b[3]:set( b[2]:get(0)*b[1]:get(0), 0)
b[3]:set( b[2]:get(1)*b[1]:get(1), 1)
b[3]:set( x, 2)
end
ops.lchedit = wrapLoop(lchedit)

local function rgbedit(b, p, c) -- 3, 1
	b[4]:set( b[1]:get(c)*b[2]:get(c)+b[3]:get(c) , c)
end
ops.rgbedit = wrapLoop(wrapChan(rgbedit))

local function compose(b, p) -- 3,1
b[4]:set3( b[1]:get(0), b[2]:get(1), b[3]:get(2) )
end
ops.compose = wrapLoop(compose)

local function decompose(b, p) -- 1,3
	b[2]:set(b[1]:get(0))
	b[3]:set(b[1]:get(1))
	b[4]:set(b[1]:get(2))
end
ops.decompose = wrapLoop(decompose)

local function merge(b, p, c) -- 3,1
	b[4]:set( b[1]:get(c)*b[3]:get(c) + b[2]:get(c)*(1-b[3]:get(c)), c)
end
ops.merge = wrapLoop(wrapChan(merge))

--ops.strings = {

local function add(b, p, c) -- 2, 1
	b[3]:set( b[1]:get(c) + b[2]:get(c), c)
end
ops.add = wrapLoop(wrapChan(add))

local function sub(b, p, c) -- 2, 1
	b[3]:set( b[1]:get(c) - b[2]:get(c), c)
end
ops.sub = wrapLoop(wrapChan(sub))

local function mul(b, p, c) -- 2, 1
	b[3]:set( b[1]:get(c) * b[2]:get(c), c)
end
ops.mul = wrapLoop(wrapChan(mul))

local function div(b, p, c) -- 2, 1
	b[3]:set( b[1]:get(c) / b[2]:get(c), c)
end
ops.div = wrapLoop(wrapChan(div))

local function compMult(b, p, c) -- 4, 2
	b[5]:set( b[1]:get(c)*b[3]:get(c) - b[2]:get(c)*b[4]:get(c), c)
	b[6]:set( b[1]:get(c)*b[4]:get(c) + b[2]:get(c)*b[3]:get(c), c)
end
ops.compMult = wrapLoop(wrapChan(compMult))

local function zero(b, p, c)-- 0,1
	b[1]:set( 0, c)
end
ops.zero = wrapLoop(wrapChan(zero))

local function equaliseGB(b, p) -- 1,1
	local GB = (b[1]:get(1)+b[1]:get(2))/2
	b[2]:set( GB, 1)
	b[2]:set( GB, 2)
end
ops.equaliseGB = wrapLoop(equaliseGB)

local function invertR_GB(b, p) -- 1,1
	local GB = 1-b[1]:get(0)
	b[2]:set( GB, 1)
	b[2]:set( GB, 2)
end
ops.invertR_GB = wrapLoop(invertR_GB)



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

--[[
do
	local function filter(func, flag)
		return function()	
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		for x = inst, s.xmax/2, instmax do
			if progress[instmax]==-1 then break end
			for y = 0, s.ymax/2 do
				local gauss
				local size = 128 --math.sqrt(xmax^2+ymax^2)
				gauss = func(math.sqrt(x^2+y^2), b[1]:get(0)*size)
				gauss = gauss + (flag and func(math.sqrt((s.xmax-x+1)^2+y^2), b[1]:get(0)*size) or 0)
				gauss = gauss + (flag and func(math.sqrt(x^2+(s.ymax-y+1)^2), b[1]:get(0)*size) or 0)
				gauss = gauss + (flag and func(math.sqrt((s.xmax-x+1)^2+(s.ymax-y+1)^2), b[1]:get(0)*size) or 0)
				--gauss = gauss * b[2]:get() + 1 - b[2]:get()
				b[3]:set3xy(gauss, gauss, gauss,x,y)
				if x~=0 then b[3]:set3xy(gauss, gauss, gauss, s.xmax-x, y) end
				if y~=0 then b[3]:set3xy(gauss, gauss, gauss, x, s.ymax-y) end
				if x~=0 and y~=0 then b[3]:set3xy[1](gauss, gauss, gauss, s.xmax-x, s.ymax-y) end
			end
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end

	function ops.gauss() return filter(math.func.gauss) end
	function ops.lorenz() return filter(math.func.lorenz) end
	function ops.gauss_wrap() return filter(math.func.gauss, true) end
	function ops.lorenz_wrap() return filter(math.func.lorenz, true) end
end
--]]

return ops