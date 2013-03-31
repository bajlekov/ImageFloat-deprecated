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

print("Thread initialisation...")

package.path = 	"./?.lua;"..
				"./Setup/?.lua;"..
				"./Build/?.lua;"..
				"./Draw/?.lua;"..
				"./Include/?.lua;"..
				"./Interop/?.lua;"..
				"./Math/?.lua;"..
				"./Node/?.lua;"..
				"./Ops/?.lua;"..
				"./Threads/?.lua;"..
				"./Tools/?.lua;"..package.path

local ffi = require("ffi")

__global = {}
__global.setup = require("IFsetup")
__global.libPath = __global.setup.libPath or "../Libraries/"..ffi.os.."_"..ffi.arch.."/"

-- replace the complete sdl lib with just the mutex functions and possibly tick/wait!
local sdl = require("sdltools")

if __global.setup.optCompile.ispc then
	__global.ISPC = ffi.load("./Ops/ISPC/ops.so")
	ffi.cdef[[
	void ispc_pow(float* a, float b, float* o, int size);
	
	void ispc_LtoG(float* src, float* dst, int size);
	void ispc_GtoL(float* src, float* dst, int size);
	]]
end
 
ops = require("ops") -- global ops are required to ease calling

function __init() -- initialisation function, runs once when instance is started
	__global.progress = ffi.cast("int*", __progress)
	__global.instance = __instance
	__global.instmax = __tmax
	__progress = nil
	__instance = nil
	__tmax = nil
	-- FIXME figure out where gc causes trouble!!
	
	-- set GC parameters for collector to keep up with allocated data
	collectgarbage("setpause", 120)
	--collectgarbage("setstepmul")
end

function __setup() -- set up instance for processing after node parameters are passed
	--[[ pass:
		__bufs
		__dims
		__params
	--]]
	local buf = {}					-- structure containing all buffers and functions
	local n = #__dims/3
	local dims = __dims
	
	local b = ffi.cast("void**", __bufs) 
	local bufdata = {}
	
	local xmax, ymax, zmax = 0, 0, 0
	
	-- setup buffer data
	for i = 1, n do
		buf[i] = {}
		buf[i].data = ffi.cast(__global.setup.bufferPrecision[1].."*", b[i])
		buf[i].x = dims[(i-1)*3 + 1]
		buf[i].y = dims[(i-1)*3 + 2]
		buf[i].z = dims[(i-1)*3 + 3]
		xmax = math.max(xmax, buf[i].x)
		ymax = math.max(ymax, buf[i].y)
		zmax = math.max(zmax, buf[i].z)
	end
	
	buf.max = n
	
	__global.state = {x=0, y=0, z=0, xmax=xmax, ymax=ymax, zmax=zmax}
	function __global.state:up(x, y, z)
		self.x = x or self.x
		self.y = y or self.y
		self.z = z or self.z
	end
	__global.progress[__global.instmax+1] = __global.state.xmax
	
	-- setup getters/setters
	for i = 1, n do
		local b = buf[i]
		local s = __global.state
		
		if b.x==1 and b.y==1 and b.z==1 then
			function b:get() return self.data[0] end
			function b:set(c) self.data[0] = c end
			function b:get3() local c = self:get() return c, c, c end
			function b:set3(c1, c2, c3) local c = (c1+c2+c3)/3 self:set(c) end
			b.getxy = b.get
			b.setxy = b.set
			b.get3xy = b.get3
			b.set3xy = b.set3
		elseif (b.x>1 or b.y>1) and b.z==1 then
			function b:get() return self.data[s.x*s.ymax+s.y] end 
			function b:set(c) self.data[s.x*s.ymax+s.y] = c end
			function b:get3() local c = self:get() return c, c, c end
			function b:set3(c1, c2, c3) local c = (c1+c2+c3)/3 self:set(c) end
			function b:getxy(n, x, y) return self.data[x*s.ymax+y] end
			function b:setxy(c, n, x, y) self.data[x*s.ymax+y] = c end
			function b:get3xy(x, y) local c = self:getxy(x, y) return c, c, c end
			function b:set3xy(c1, c2, c3, x, y) local c = (c1+c2+c3)/3 self:setxy(c, x, y) end
		elseif b.x==1 and b.y==1 and b.z==3 then
			function b:get(n) return self.data[n or s.z] end
			function b:set(c, n) self.data[n or s.z] = c end
			function b:get3() return self.data[0], self.data[1], self.data[2] end
			function b:set3(c1, c2, c3) self.data[0], self.data[1], self.data[2] = c1, c2, c3 end
			b.getxy = b.get
			b.setxy = b.set
			b.get3xy = b.get3
			b.set3xy = b.set3
		elseif (b.x>1 or b.y>1) and b.z==3 then
			function b:get(n) return self.data[s.x*s.ymax*s.zmax+s.y*s.zmax+(n or s.z)] end
			function b:set(c, n) self.data[s.x*s.ymax*s.zmax+s.y*s.zmax+(n or s.z)] = c end
			function b:get3() return self:get(0), self:get(1), self:get(2) end
			function b:set3(c1, c2, c3) self:set(c1, 0) self:set(c2, 1) self:set(c3, 2) end
			function b:getxy(n, x, y) return self.data[x*s.ymax*s.zmax+y*s.zmax+(n or s.z)] end
			function b:setxy(c, n, x, y) self.data[x*s.ymax*s.zmax+y*s.zmax+(n or s.z)] = c end
			function b:get3xy(x, y) return self:getxy(0, x, y), self:getxy(1, x, y), self:getxy(2, x, y) end
			function b:get3xy(c1, c2, c3, x, y) self.setxy(c1, 0, x, y) self.setxy(c2, 1, x, y) self.setxy(c3, 2, x, y) end
		end
	end
	
	__global.buf = buf
	__global.params = __params
	__params = nil
	__bufs = nil
	__dims = nil
end
