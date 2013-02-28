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

local ffi = require "ffi"

local prec = __global.setup.bufferPrecision


ffi.cdef[[
	void * malloc ( size_t size );
	void * calloc ( size_t num, size_t size );
	void * realloc ( void * ptr, size_t size );
	void free ( void * ptr );
	typedef float float_a __attribute__ ((aligned (16)));
	typedef double double_a __attribute__ ((aligned (16)));
]] -- allocate aligned memory for use with SSE

-- allocate aligned floats
local function allocF(size)
	return ffi.gc(ffi.cast("float_a*", ffi.C.calloc(size, 4)), ffi.C.free)
end

-- allocate aligned doubles
local function allocD(size)
	return ffi.gc(ffi.cast("double_a*", ffi.C.calloc(size, 8)), ffi.C.free)
end


local buffer = {__type = "buffer"}
buffer.alloc = allocF
buffer.meta={__index = buffer}

function buffer.meta.__tostring(a)
	return "Image buffer ["..a.x..", "..a.y..", "..a.z.."], CS: "..a.cs.."."
end

function buffer.meta.__add(a, b)
	if type(b)=="number" then
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) + b)				
				end
			end
		end
		return o
	elseif type(b)=="table" and b.__type=="buffer" then
		if a.x~=b.x or a.y~=b.y or a.z~=b.z then
			print(debug.traceback("ERROR: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
			return nil
		else
			local o = a:new()
			for i = 0, a.x-1 do
				for j = 0, a.y-1 do
					for k = 0, a.z-1 do
						o:set(i,j,k, a:get(i,j,k) + b:get(i,j,k) )				
					end
				end
			end
			return o
		end
	else
		print(debug.traceback("ERROR: Invalid type."))
		return nil
	end
end

function buffer.meta.__sub(a, b)
	if type(b)=="number" then
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) - b)				
				end
			end
		end
		return o
	elseif type(b)=="table" and b.__type=="buffer" then
		if a.x~=b.x or a.y~=b.y or a.z~=b.z then
			print(debug.traceback("ERROR: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
			return nil
		else
			local o = a:new()
			for i = 0, a.x-1 do
				for j = 0, a.y-1 do
					for k = 0, a.z-1 do
						o:set(i,j,k, a:get(i,j,k) - b:get(i,j,k) )				
					end
				end
			end
			return o
		end
	else
		print(debug.traceback("ERROR: Invalid type."))
		return nil
	end
end

function buffer.meta.__mul(a, b)
	if type(b)=="number" then
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) * b)				
				end
			end
		end
		return o
	elseif type(b)=="table" and b.__type=="buffer" then
		if a.x~=b.x or a.y~=b.y or a.z~=b.z then
			print(debug.traceback("ERROR: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
			return nil
		else
			local o = a:new()
			for i = 0, a.x-1 do
				for j = 0, a.y-1 do
					for k = 0, a.z-1 do
						o:set(i,j,k, a:get(i,j,k) * b:get(i,j,k) )				
					end
				end
			end
			return o
		end
	else
		print(debug.traceback("ERROR: Invalid type."))
		return nil
	end
end

function buffer.meta.__div(a, b)
	if type(b)=="number" then
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) / b)				
				end
			end
		end
		return o
	elseif type(b)=="table" and b.__type=="buffer" then
		if a.x~=b.x or a.y~=b.y or a.z~=b.z then
			print(debug.traceback("ERROR: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
			return nil
		else
			local o = a:new()
			for i = 0, a.x-1 do
				for j = 0, a.y-1 do
					for k = 0, a.z-1 do
						o:set(i,j,k, a:get(i,j,k) / b:get(i,j,k) )				
					end
				end
			end
			return o
		end
	else
		print(debug.traceback("ERROR: Invalid type."))
		return nil
	end
end

function buffer.meta.__pow(a, b)
	if type(b)=="number" then
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					o:set(i,j,k, a:get(i,j,k) ^ b)				
				end
			end
		end
		return o
	elseif type(b)=="table" and b.__type=="buffer" then
		if a.x~=b.x or a.y~=b.y or a.z~=b.z then
			print(debug.traceback("ERROR: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
			return nil
		else
			local o = a:new()
			for i = 0, a.x-1 do
				for j = 0, a.y-1 do
					for k = 0, a.z-1 do
						o:set(i,j,k, a:get(i,j,k) ^ b:get(i,j,k) )				
					end
				end
			end
			return o
		end
	else
		print(debug.traceback("ERROR: Invalid type."))
		return nil
	end
end

function buffer.meta.__unm(a)
	local o = a:new()
	for i = 0, a.x-1 do
		for j = 0, a.y-1 do
			for k = 0, a.z-1 do
				o:set(i,j,k, - a:get(i,j,k))				
			end
		end
	end
	return o
end

function buffer:getABC(x,y,z)
	if x>=self.x or y>=self.y or z>=self.z or x<0 or y<0 or z<0 then
		print(debug.traceback("WARNING: Index outside array bounds, element ["..x..", "..y..", "..z.."] of ["..self.x..", "..self.y..", "..self.z.."]."))
		return 0
	else
		return self.data[x*self.y*self.z + y*self.z + z]
	end
end

function buffer:setABC(x,y,z, v)
	if x>=self.x or y>=self.y or z>=self.z or x<0 or y<0 or z<0 then
		print(debug.traceback("WARNING: Index outside array bounds, element ["..x..", "..y..", "..z.."] of ["..self.x..", "..self.y..", "..self.z.."]."))
		return nil
	else
		self.data[x*self.y*self.z + y*self.z + z] = v
	end
end

function buffer:get(x,y,z)
	return self.data[x*self.y*self.z + y*self.z + z]
end

function buffer:set(x,y,z, v)
	self.data[x*self.y*self.z + y*self.z + z] = v
end

function buffer:get3(x,y)
	local c = x*self.y*self.z + y*self.z
	return self.data[c], self.data[c+1], self.data[c+2] 
end

function buffer:set3(x,y, v1,v2,v3)
	local c = x*self.y*self.z + y*self.z
	self.data[c] = v1
	self.data[c+1] = v2
	self.data[c+2] = v3
end


function buffer:newI(x, y, c1, c2, c3)
	x = x or self.x or 1
	y = y or self.y or 1
	local o = self:new(x, y, 3)
	if c1 then
		c2 = c2 or c1
		c3 = c3 or c1
		for i = 0, x-1 do
			for j = 0, y-1 do
				o:set3(i,j, c1,c2,c3)
			end
		end
	end
	return o
end

function buffer:newM(x, y, v1)
	x = x or self.x or 1
	y = y or self.y or 1
	local o = self:new(x, y, 1)
	if v1 then
		for i = 0, x-1 do
			for j = 0, y-1 do
				o:set(i,j,0, v1)
			end
		end
	end
	return o
end
function buffer:getM(x,y) return self.data[x*self.y*self.z + y*self.z] end
function buffer:setM(x,y, v) self.data[x*self.y*self.z + y*self.z] = v end

function buffer:newC(c1, c2, c3)
	local o = self:new(1, 1, 3)
	if c1 then
		c2 = c2 or c1
		c3 = c3 or c1
		o:set3(0,0, c1,c2,c3)
	end
	return o
end
function buffer:getC(i) return self.data[i-1] end
function buffer:setC(i, v) self.data[i-1] = v end
function buffer:getC3() return self.data[0], self.data[1], self.data[2] end
function buffer:setC3(c1, c2, c3)
	self.data[0] = c1
	self.data[1] = c2
	self.data[2] = c3
end

function buffer:newV(v1)
	local o = self:new(1, 1, 1)
	if v1 then o:set(0,0,0, v1) end
	return o
end
function buffer:getV() return self.data[0] end
function buffer:setV(v) self.data[0] = v end

function buffer:newA(a)
	local l = #a
	local o = self:new(l, 1, 1)
	for i = 0, l-1 do
		o:set(i,0,0, a[i+1])
	end
	return o
end
function buffer:getA(i) return self.data[i] end
function buffer:setA(i, v) self.data[i] = v end

function buffer:type()
	print("Deprecated buffer property \"type\".")
	local x, y, z = self.x, self.y, self.z
	if		x==1 and y==1 and z==1 then		return 1
	elseif	x==1 and y==1 and z==3 then		return 2
	elseif	z==1 then						return 3
	elseif	z==3 then						return 4
	else
		print(debug.traceback("WARNING: type is undefined"))
		return 0
	end
end

function buffer:new(x, y, z)
	x = x or self.x or 1
	y = y or self.y or 1
	z = z or self.z or 1	
	local size = x*y*z
	
	local o = {
		data = self.alloc(size),
		cs = "MAP",
		x = x, y = y, z = z,	-- derive buffer type from coordinates
		xoff = 0, yoff = 0,		-- sub-regions for partial processing
		xlen = x, ylen = y,
	}
	setmetatable(o, buffer.meta)	
	return o
end

function buffer:copy(t)
	if t then
		if self.x==t.x and self.y==t.y and self.z==t.z then
			ffi.copy(self.data, t.data, self.x*self.y*self.z*4)
		else
			print(debug.traceback("ERROR: Buffer size mismatch! Target: ["..self.x..", "..self.y..", "..self.z.."], source: ["..t.x..", "..t.y..", "..t.z.."]."))
			return nil
		end
	else
		local o = self:new()
		ffi.copy(o.data, self.data, self.x*self.y*self.z*4) -- switch to 8 for double
		-- fast SSE memcopy?
		return o
	end
end

local function mean(c1, c2, c3) return (c1+c2+c3)/3 end
function buffer:copyG() -- only from image data!
	if self.z==3 then
		local o = self:new(self.x, self.y, 1)	
		for i = 0, self.x-1 do
			for j = 0, self.y-1 do
				o:setM(i,j, mean(self:get3(i, j)))
			end
		end
		return o
	elseif self.z==1 then
		return self:copy()
	else
		local o = self:new(self.x, self.y, 1)
		for i = 0, self.x-1 do
			for j = 0, self.y-1 do
				local s = 0
				for k = 0, self.z-1 do
					s = s + self:get(i, j, k)
				end
				o:setM(i,j, s/self.z)
			end
		end
		return o
	end
end

function buffer:copyC()
	if self.z==1 then
		local o = self:new(self.x, self.y, 3)
		for i = 0, self.x-1 do
			for j = 0, self.y-1 do
				local m = self:getM(i, j)
				o:set3(i,j, m,m,m)
			end
		end 
		return o
	elseif self.z==3 then
		return self:copy()
	else
		print(debug.traceback("WARNING: Non-standard Z dimension of "..self.z..", converting through grayscale"))
		return self:copyG():copyC()
	end
end

function buffer:clean()
	ffi.C.realloc(self.data, 1)
	self.x=1
	self.y=1
	self.z=1
end

require("imgops")(buffer)
return buffer


--[=[
local img = {}

function img.newBuffer(a, b, c)
	local out = {}
	--properties
	if type(a)=="number" and b==nil then
		out.x = 1
		out.y = 1
		out.z = 1
		out.data = ffi.new(prec[1].."[1][1][1]")
		out.data[0][0][0] = a
		out.type = 1
		out.cs = "MAP"
	elseif type(a)=="number" and type(b)=="number" and type(c)=="number" then
		out.x = a
		out.y = b
		out.z = c
		out.data = ffi.new(prec[1].."["..a.."]["..b.."]["..c.."]")
		if a==1 and b==1 then
			if c==1 then
				out.type = 1
				out.cs = "MAP"
			elseif c==3 then
				out.type = 2
				out.cs = "SRGB"
			end
		else
			if c==1 then
				out.type = 3
				out.cs = "MAP"
			elseif c==3 then
				out.type = 4
				out.cs = "SRGB"
			end
		end
	elseif type(a)=="table" then
		out.x = 1
		out.y = 1
		out.z = 3
		out.data = ffi.new(prec[1].."[1][1][3]")
		out.data[0][0][0] = a[1]
		out.data[0][0][1] = a[2]
		out.data[0][0][2] = a[3]
		out.type = 2
		out.cs = "SRGB"
	else
		out.x = nil
		out.y = nil
		out.z = nil
		out.data = nil
		out.type = 4
		out.cs = "SRGB"
	end
	out.tile = {
		tiles = 1,
		offset = 0,
	}
	out.__type = "buffer"

	--methods
	out.pixelOp = img.pixelOp
	out.toScreen = img.toScreen
	out.toScreenQuad = img.toScreenQuad
	out.saveHD = img.bufferSaveHD
	out.loadHD = img.bufferSaveHD
	out.saveIM = img.writeIM
	out.loadIM = img.readIM
	out.copy = img.copy
	out.new = img.new
	out.copyGS = img.copyGS
	out.newGS = img.newGS
	out.copyColor = img.copyColor
	out.newColor = img.newColor
	out.max = img.max
	out.min = img.min
	out.csConvert = img.csConvert
	out.invert = img.invert
	return out
end

function img.copy(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = buffer.z
	out.data = ffi.new(prec[1].."["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = buffer.cs
	out.type = buffer.type
	ffi.copy(out.data, buffer.data, buffer.x*buffer.y*buffer.z*prec[2])
	return out
end

function img.new(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = buffer.z
	out.data = ffi.new(prec[1].."["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = buffer.cs
	out.type = buffer.type
	return out
end

function img.copyGS(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = 1
	out.data = ffi.new(prec[1].."["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = "MAP"
	out.type = buffer.type
	if out.type==4 then
		out.type = 3 
	elseif out.type==2 then
		out.type = 1
	end
	if buffer.z==3 then
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				out.data[x][y][0] = (buffer.data[x][y][0] + buffer.data[x][y][1] + buffer.data[x][y][2])/3
			end
		end
	elseif buffer.z==1 then
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				out.data[x][y][0] = buffer.data[x][y][0]
			end
		end
	end

	return out
end

function img.newGS(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = 1
	out.data = ffi.new(prec[1].."["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = "MAP"
	out.type = buffer.type
	if out.type==4 then
		out.type = 3 
	elseif out.type==2 then
		out.type = 1
	end
	return out
end

function img.copyColor(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = 3
	out.data = ffi.new(prec[1].."["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = "SRGB"
	out.type = buffer.type
	if out.type==3 then
		out.type = 4 
	elseif out.type==1 then
		out.type = 2
	end
	if buffer.z==1 then
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				out.data[x][y][0] = buffer.data[x][y][0]
				out.data[x][y][1] = buffer.data[x][y][0]
				out.data[x][y][2] = buffer.data[x][y][0]
			end
		end
	elseif buffer.z==3 then
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				out.data[x][y][0] = buffer.data[x][y][0]
				out.data[x][y][1] = buffer.data[x][y][1]
				out.data[x][y][2] = buffer.data[x][y][2]
			end
		end
	end
	return out
end

function img.newColor(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = 3
	out.data = ffi.new(prec[1].."["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = "SRGB"
	out.type = buffer.type
	if out.type==3 then
		out.type = 4 
	elseif out.type==1 then
		out.type = 2
	end
	return out
end

--disk io native C functions
ffi.cdef[[
	struct _IO_FILE;
	typedef struct _IO_FILE FILE;
	size_t fread ( void * ptr, size_t size, size_t count, FILE * stream );
	size_t fwrite ( const void * ptr, size_t size, size_t count, FILE * stream );
]]

local function bufread(bptr, length, fptr)
	ffi.C.fread(bptr, 8, length*8, fptr)
end
local function bufwrite(bptr, length, fptr)
	ffi.C.fwrite(bptr, 8, length*8, fptr)
end

-- implement partial reads and writes!!!

do 
	function img.bufferSaveHD(buffer, fname)
		local f = io.open(fname, "w")
		bufwrite(buffer.data, buffer.x*buffer.y*3, f)
		f:close()
		return fname
	end
	function img.bufferLoadHD(p1, p2)
		if p2 then --adjust for possible load into exiting buffer
			buffer = p1
			fname = p2
		else
			local buffer = img.newBuffer()
			fname = p1
		end
		local f = io.open(fname, "r")
		local res_s = f:read(16)
		local res_d = ffi.cast(prec[1].."*", res_s)
		local x, y = res_d[0], res_d[1]
		
		buffer.x, buffer.y, buffer.z = x, y, 3
		buffer.data = ffi.new(prec[1].."["..x.."]["..y.."][3]")

		bufread(buffer.data, x*y*3, f)
		f:close()
		return buffer
	end

	function img.writeIM(buffer, name, op)
		print("Saving to: "..name)
		op = op or ""
		local f = io.popen("convert -define quantum:format=floating-point -depth 64 -size "..buffer.y.."x"..buffer.x..
			" rgb:- -transpose "..op.." "..name, "w")
		local x, y, z = buffer.x, buffer.y, buffer.z
		bufwrite(buffer.data, x*y*3, f)
		f:close()
	end

	function img.readIM(p1, p2, p3, p4)
		--buffer, file name, ops
		-- file name, ops, size y, size x
		if not p4 then
			buffer = p1
			name = p2
			op = p3 or ""
		else
			local buffer = img.newBuffer()
			name = p1
			op = p2 or ""
			x = p4
			y = p3
			buffer.x, buffer.y, buffer.z = x, y, 3
		end
		print("Loading: "..name)
		local x, y, z = buffer.x, buffer.y, buffer.z
		buffer.data = ffi.new(prec[1].."["..x.."]["..y.."][3]")

		local f = io.popen("convert -define quantum:format=floating-point -depth 64 -size "..buffer.y.."x"..buffer.x..
			" "..name.." -transpose "..op.." rgb:-", "r")
		bufread(buffer.data, x*y*3, f)
		f:close()
	end

	-- external processing using named pipes
	-- needs separate processing thread for synchronopus in-- and output
	function img.processIM(buffer, op)
		--os.execute("mkfifo tempBufferI")
		--os.execute("mkfifo tempBufferO")
		print("**")
		local x, y, z = buffer.x, buffer.y, buffer.z

		local fi = io.open("tempBufferI", "w")
		bufwrite(buffer.data, x*y*3, fi) -- parallel push
		fi:close()
		
		os.execute("convert -define quantum:format=floating-point -depth 64 -size "..buffer.y.."x"..buffer.x..
			" rgb:tempBufferI -transpose "..op.." -transpose rgb:tempBufferO")

		local fo = io.open("tempBufferO", "r")
		bufread(buffer.data, x*y*3, fo) -- parallel pull
		fo:close()
		os.remove("tempBufferI")
		os.remove("tempBufferO")
	end
end
--]=]
