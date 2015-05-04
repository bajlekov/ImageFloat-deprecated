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

print("Thread initialisation...")

package.path = package.path .. ';Source/?.lua'

-- disable implicit globals
do
	function global(k, v) -- assign new global
		rawset(_G, k, v or false)
	end
	local function newGlobal(t, k, v) -- disable globals
		print("ERROR: Global assignment not allowed: "..k)
		print(debug.traceback())
		error("ERROR: Global assignment not allowed: "..k)
	end
	setmetatable(_G, {__newindex=newGlobal})
end

--package.path = 	"./?.lua;"..package.path

--[[
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
--]]
local ffi = require("ffi")

global("__global", {})
__global.setup = require("Setup.IFsetup")
__global.libPath = __global.setup.libPath or "./Libraries/"..ffi.os.."_"..ffi.arch.."/"

-- replace the complete sdl lib with just the mutex functions and possibly tick/wait!
local sdl = require("Include.sdl2")
global("__sdl", sdl)

if __global.setup.optCompile.ispc then
	__global.ISPC = ffi.load("./Source/Ops/ISPC/ops.so")
	ffi.cdef[[
	void ispc_pow(float* a, float b, float* o, int size);
	
	void ispc_LtoG(float* src, float* dst, int size);
	void ispc_GtoL(float* src, float* dst, int size);
	]]
end

--FIXME!! no global ops, rewrite with thread calling!
global("ops", require("Ops.ops")) -- global ops are required to ease calling
global("__init")
global("__setup")

-- initialise globals before assigning values from main thread
global("__progress")
global("__instance")
global("__tmax")
global("__mut")

function __init() -- initialisation function, runs once when instance is started
	__global.progress = ffi.cast("int*", __progress)
	__global.instance = __instance
	__global.instmax = __tmax
	__progress = nil
	__instance = nil
	__tmax = nil
	
	-- set GC parameters for collector to keep up with allocated data
	collectgarbage("setpause", 120)
	--collectgarbage("setstepmul")
end

global("__bufs")
global("__dims")
global("__params")

__global.state = {}
function __global.state:up(x, y, z)
	self.x = x or self.x
	self.y = y or self.y
	self.z = z or self.z
end

local getters = {}
getters.A = {}
getters.B = {}
getters.C = {}
getters.D = {}

local s

function getters.A:get() return self.data[0] end
function getters.A:set(c) self.data[0] = c end
function getters.A:get3() local c = self:get() return c, c, c end
function getters.A:set3(c1, c2, c3) local c = (c1+c2+c3)/3 self:set(c) end
getters.A.getxy = getters.A.get
getters.A.setxy = getters.A.set
getters.A.get3xy = getters.A.get3
getters.A.set3xy = getters.A.set3

function getters.B:get() return self.data[s.x*s.ymax+s.y] end 
function getters.B:set(c) self.data[s.x*s.ymax+s.y] = c end
function getters.B:get3() local c = self:get() return c, c, c end
function getters.B:set3(c1, c2, c3) local c = (c1+c2+c3)/3 self:set(c) end
function getters.B:getxy(n, x, y) return self.data[x*s.ymax+y] end
function getters.B:setxy(c, n, x, y) self.data[x*s.ymax+y] = c end
function getters.B:get3xy(x, y) local c = self:getxy(x, y) return c, c, c end
function getters.B:set3xy(c1, c2, c3, x, y) local c = (c1+c2+c3)/3 self:setxy(c, x, y) end

function getters.C:get(n) return self.data[n or s.z] end
function getters.C:set(c, n) self.data[n or s.z] = c end
function getters.C:get3() return self.data[0], self.data[1], self.data[2] end
function getters.C:set3(c1, c2, c3) self.data[0], self.data[1], self.data[2] = c1, c2, c3 end
getters.C.getxy = getters.C.get
getters.C.setxy = getters.C.set
getters.C.get3xy = getters.C.get3
getters.C.set3xy = getters.C.set3

function getters.D:get(n) return self.data[s.x*s.ymax*s.zmax+s.y*s.zmax+(n or s.z)] end
function getters.D:set(c, n) self.data[s.x*s.ymax*s.zmax+s.y*s.zmax+(n or s.z)] = c end
function getters.D:get3() return self:get(0), self:get(1), self:get(2) end
function getters.D:set3(c1, c2, c3) self:set(c1, 0) self:set(c2, 1) self:set(c3, 2) end
function getters.D:getxy(n, x, y) return self.data[x*s.ymax*s.zmax+y*s.zmax+(n or s.z)] end
function getters.D:setxy(c, n, x, y) self.data[x*s.ymax*s.zmax+y*s.zmax+(n or s.z)] = c end
function getters.D:get3xy(x, y) return self:getxy(0, x, y), self:getxy(1, x, y), self:getxy(2, x, y) end
function getters.D:get3xy(c1, c2, c3, x, y) self.setxy(c1, 0, x, y) self.setxy(c2, 1, x, y) self.setxy(c3, 2, x, y) end

function __setup() -- set up instance for processing after node parameters are passed
	--[[ pass:
		__bufs
		__dims
		__params
	--]]
	local __global = __global
	
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
	
	__global.state.x = 0
	__global.state.y = 0
	__global.state.z = 0
	__global.state.xmax = xmax
	__global.state.ymax = ymax
	__global.state.zmax = zmax
	__global.progress[__global.instmax+1] = __global.state.xmax
	
	-- setup getters/setters
	for i = 1, n do
		local b = buf[i]
		local buftype
		s = __global.state
		
		if b.x==1 and b.y==1 and b.z==1 then
			buftype = "A"
		elseif (b.x>1 or b.y>1) and b.z==1 then
			buftype = "B"
		elseif b.x==1 and b.y==1 and b.z==3 then
			buftype = "C"
		elseif (b.x>1 or b.y>1) and b.z==3 then
			buftype = "D"
		end
		
		b.get = getters[buftype].get
		b.get3 = getters[buftype].get3
		b.getxy = getters[buftype].getxy
		b.get3xy = getters[buftype].get3xy
		b.set = getters[buftype].set
		b.set3 = getters[buftype].set3
		b.setxy = getters[buftype].setxy
		b.set3xy = getters[buftype].set3xy
	end
	
	__global.buf = buf
	__global.params = __params
end
