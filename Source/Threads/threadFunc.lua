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

--[[
function loadlib(lib)
	local path = __global.libPath
	local libname
	if ffi.os=="Linux" then libname = "lib"..lib..".so" end
	if ffi.os=="Windows" then libname = lib..".dll" end
	local t
	local p
	p, t = pcall(ffi.load, lib)
	if not p then
		print("no user library found, trying supplied library "..lib)
		p, t = pcall(ffi.load, path..libname)
	end
	
	if p then
		return t
	else
		print("failed loading "..lib)
		return false
	end
end
--]]
 
ops = require("ops") -- global ops are required to ease calling

function __init() -- initialisation function, runs once when instance is started
	__global.progress = ffi.cast("int*", __progress)
	__global.instance = __instance
	__global.instmax = __tmax
	__progress = nil
	__instance = nil
	__tmax = nil
	-- FIXME figure out where gc causes trouble!!
	--collectgarbage("stop")
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

	--[[
	--print("Thread Setup:", b,xmax,ymax,zmax,ibuf,obuf)
	--print("*", unpack(buftype))

	--functions for accessing buffers
	__pp = 0 --__pp indicates pixel position
	get = {} -- get/set functions dependent on buffer type
	set = {}
	get3 = {} -- get/set function for triplets, wrapping above
	set3 = {}
	getxy = {} -- same as above with additional coordinate parameters for non-local changes
	setxy = {}
	get3xy = {}
	set3xy = {}

	local bufdata={}
	__global.bufdata = bufdata -- for acces to raw buffer data!
	local b = ffi.cast("void**", b)
	for i = 1, ibuf+obuf do
		bufdata[i] = ffi.cast(__global.setup.bufferPrecision[1].."*", b[i])
		--print("*", i, bufdata[i])
	end
	b = nil -- leave only bufdata, actual data is kept referenced in original thread
	
	-- !! GC problem
	-- collectgarbage("collect") -- too slow/ no negative effects observed otherwise
	-- probably lowering mem consumption so no gc is triggered at other position, thus preventing crash
	-- due to low memory consumption of threads, have interval gc instead of automatic??
	-- ability to see what is cleaned by gc??

	for i = 1, ibuf do
		if buftype[i]==1 then get[i] = function() return bufdata[i][0] end
		elseif buftype[i]==2 then get[i] = function(c) return bufdata[i][c] end
		elseif buftype[i]==3 then get[i] = function() return bufdata[i][__pp] end
		elseif buftype[i]==4 then get[i] = function(c) return bufdata[i][__pp*3+c] end
		end
		if buftype[i]==2 or buftype[i]==4 then
			get3[i] = function() return get[i](0), get[i](1), get[i](2) end
		else
			get3xy[i] = function() local v = get[i]() return v,v,v end
		end
	end

	for i = 1, ibuf do
		if buftype[i]==1 then getxy[i] = function(x,y) return bufdata[i][0] end
		elseif buftype[i]==2 then getxy[i] = function(x,y,c) return bufdata[i][c] end
		elseif buftype[i]==3 then getxy[i] = function(x,y) return bufdata[i][(x*ymax+y)] end
		elseif buftype[i]==4 then getxy[i] = function(x,y,c) return bufdata[i][(x*ymax+y)*3+c] end
		end
		if buftype[i]==2 or buftype[i]==4 then
			get3xy[i] = function(x,y) return get[i](x,y,0), get[i](x,y,1), get[i](x,y,2) end
		else
			get3xy[i] = function(x,y) local v = get[i](x,y) return v,v,v end
		end
	end

	for i = 1, obuf do
		local ii = i + ibuf
		if buftype[ii]==1 then set[i] = function(v) bufdata[ii][0] = v end
		elseif buftype[ii]==2 then set[i] = function(v, c) bufdata[ii][c] = v end
		elseif buftype[ii]==3 then set[i] = function(v) bufdata[ii][__pp] = v end
		elseif buftype[ii]==4 then set[i] = function(v, c) bufdata[ii][__pp*3+c] = v end
		end
		if buftype[ii]==2 or buftype[ii]==4 then
			set3[i] = function(c0, c1, c2) set[i](c0, 0) set[i](c1, 1) set[i](c2, 2) end
		else
			set3[i] = function(c0, c1, c2) set[i]((c0+c1+c2)/3) end
		end
	end

	for i = 1, obuf do
		local ii = i + ibuf
		if buftype[ii]==1 then setxy[i] = function(v,x,y) bufdata[ii][0] = v end
		elseif buftype[ii]==2 then setxy[i] = function(v,x,y,c) bufdata[ii][c] = v end
		elseif buftype[ii]==3 then setxy[i] = function(v,x,y) bufdata[ii][(x*ymax+y)] = v end
		elseif buftype[ii]==4 then setxy[i] = function(v,x,y,c) bufdata[ii][(x*ymax+y)*3+c] = v end
		end
		if buftype[ii]==2 or buftype[ii]==4 then
			set3xy[i] = function(c0,c1,c2,x,y) setxy[i](c0,x,y,0) setxy[i](c1,x,y,1) setxy[i](c2,x,y,2) end		
		else
			set3xy[i] = function(c0,c1,c2,x,y) setxy[i]((c0+c1+c2)/3,x,y) end
		end
	end
end

--]]

-- must be global to be reachable trough the api
--dbg = require("dbgtools")




--[[
	-- sample buffer from HD to conserve memory...sloooow
	do
		f[1] = io.open("1.dat", "r")
		local curpos = -1
		local datachunk = ffi.new("double[4]")
		local datachar = ffi.cast("uint8_t*", datachunk)
		get[1] = function(i)
			if __pp*8==curpos then --and __pp*8<curpos+chunk-3 then
				return datachunk[i]
			else
				curpos = __pp*8
				f[1]:seek("set", __pp*8)
				ffi.copy(datachar, f[1]:read(3*8))
				return datachunk[i]
			end
		end
	end
	
	function closeFiles()
		for k, v in pairs(f) do
			v:close()
		end
	end
--]]







