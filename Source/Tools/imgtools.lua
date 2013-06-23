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

local ffi = require "ffi"
local optim = require "Tools.optimtools"
local ispc = __global.setup.optCompile.ispc
if ispc then print ("Optimization for buffer ops enabled...") end

local prec
if __global==nil then
	prec = {"float",4} 
else
	prec = __global.setup.bufferPrecision
end
print("Using "..(prec[2]*8).."bit precision buffers...")

ffi.cdef[[
	void * malloc ( size_t size );
	void * calloc ( size_t num, size_t size );
	void * realloc ( void * ptr, size_t size );
	void free ( void * ptr );
	typedef float float_a __attribute__ ((aligned (16)));
	typedef double double_a __attribute__ ((aligned (16)));
]] -- allocate aligned memory for use with SSE


local allocCount = 0
local allocTable = {}
setmetatable(allocTable, {__mode="k"})
local function free(p)
	allocCount = allocCount - 1
	allocTable[p] = nil
	ffi.C.free(p)
end

-- allocate aligned floats
local function allocF(size)
	allocCount = allocCount + 1
	local t = ffi.cast("float_a*", ffi.C.calloc(size, 4))
	allocTable[t] = size * 4
	return ffi.gc(t, free)
end

-- allocate aligned doubles
local function allocD(size)
	allocCount = allocCount + 1
	local t = ffi.cast("double_a*", ffi.C.calloc(size, 8))
	allocTable[t] = size * 8
	return ffi.gc(t, free)
end

function __getAllocCount()
	return allocCount
end
function __getAllocSize()
	local sum = 0
	for _, v in pairs(allocTable) do
		sum = sum + v
	end
	return sum/1024/1024
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
			if ISPC then
				optim.add(a.data, b.data, o.data, a.x*a.y*a.z)
			else
				for i = 0, a.x-1 do
					for j = 0, a.y-1 do
						for k = 0, a.z-1 do
							o:set(i,j,k, a:get(i,j,k) + b:get(i,j,k) )				
						end
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
			if ISPC then
				optim.sub(a.data, b.data, o.data, a.x*a.y*a.z)
			else
				for i = 0, a.x-1 do
					for j = 0, a.y-1 do
						for k = 0, a.z-1 do
							o:set(i,j,k, a:get(i,j,k) - b:get(i,j,k) )				
						end
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
			if ISPC then
				optim.mul(a.data, b.data, o.data, a.x*a.y*a.z)
			else
				for i = 0, a.x-1 do
					for j = 0, a.y-1 do
						for k = 0, a.z-1 do
							o:set(i,j,k, a:get(i,j,k) * b:get(i,j,k) )				
						end
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
			if ISPC then
				optim.div(a.data, b.data, o.data, a.x*a.y*a.z)
			else
				for i = 0, a.x-1 do
					for j = 0, a.y-1 do
						for k = 0, a.z-1 do
							o:set(i,j,k, a:get(i,j,k) / b:get(i,j,k) )				
						end
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

function buffer.min(a, b)
	if type(b)=="number" then
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					local a = a:get(i,j,k)
					o:set(i,j,k, a<=b and a or b)				
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
						local a = a:get(i,j,k)
						local b = b:get(i,j,k)
						o:set(i,j,k, a<=b and a or b )				
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

function buffer.max(a, b)
	if type(b)=="number" then
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					local a = a:get(i,j,k)
					o:set(i,j,k, a>=b and a or b)				
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
						local a = a:get(i,j,k)
						local b = b:get(i,j,k)
						o:set(i,j,k, a>=b and a or b )				
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

function buffer:getM(x,y) return self.data[x*self.y*self.z + y*self.z] end
function buffer:setM(x,y, v) self.data[x*self.y*self.z + y*self.z] = v end
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

function buffer:getC(i) return self.data[i-1] end
function buffer:setC(i, v) self.data[i-1] = v end
function buffer:getC3() return self.data[0], self.data[1], self.data[2] end
function buffer:setC3(c1, c2, c3)
	self.data[0] = c1
	self.data[1] = c2
	self.data[2] = c3
end
function buffer:newC(c1, c2, c3)
	local o = self:new(1, 1, 3)
	if c1 then
		c2 = c2 or c1
		c3 = c3 or c1
		o:set3(0,0, c1,c2,c3)
	end
	return o
end

function buffer:getV() return self.data[0] end
function buffer:setV(v) self.data[0] = v end
function buffer:newV(v1)
	local o = self:new(1, 1, 1)
	if v1 then o:set(0,0,0, v1) end
	return o
end

function buffer:getA(i) return self.data[i] end
function buffer:setA(i, v) self.data[i] = v end
function buffer:newA(a)
	local l = #a
	local o = self:new(l, 1, 1)
	for i = 0, l-1 do
		o:set(i,0,0, a[i+1])
	end
	return o
end

function buffer:type()
	-- TODO: debug/warning/developer mode
	--print("Deprecated buffer property \"type\".")
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
	
	if z==1 then
		if x==1 and y==1 then
			o.i = o.getV
			o.a = o.setV
		elseif y==1 then
			o.i = o.getA
			o.a = o.setA
		else
			o.i = o.getM
			o.a = o.setM
		end
	elseif z==3 then
		if x==1 and y==1 then
			o.i = o.getC
			o.a = o.setC
		else
			o.i = o.get
			o.a = o.set
		end
	end
	
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

function buffer:free()
	ffi.C.free(ffi.gc(self.data, nil))
end

do
	local b = ffi.new("double[9]")  
	function buffer:mDilate()
		local t = self:new()
		--TODO: brute-force dilate, remove inner loop!
		for x= 1, self.x-2 do
			for y = 1, self.y-2 do
				for z = 0, self.z-1 do
					b[0] = self:get(x-1, y, z)
					b[1] = self:get(x, y, z)
					b[2] = self:get(x+1, y, z)
					b[3] = self:get(x, y-1, z)
					b[4] = self:get(x, y+1, z)
					
					t:set(x, y, z, math.max(b[0], b[1], b[2], b[3], b[4]))
				end
			end
		end
		self:copy(t) -- put back values
	end
	function buffer:mErode()
		local t = self:new()
		--TODO: brute-force dilate, remove inner loop!
		for x= 1, self.x-2 do
			for y = 1, self.y-2 do
				for z = 0, self.z-1 do
					b[0] = self:get(x-1, y, z)
					b[1] = self:get(x, y, z)
					b[2] = self:get(x+1, y, z)
					b[3] = self:get(x, y-1, z)
					b[4] = self:get(x, y+1, z)
					
					t:set(x, y, z, math.min(b[0], b[1], b[2], b[3], b[4]))
				end
			end
		end
		self:copy(t) -- put back values
	end
	function buffer:mOpen(n)
		n = n or 1
		for i = 1, n do
			self:mErode()
		end
		for i = 1, n do
			self:mDilate()
		end  
	end
	
	function buffer:mClose(n)
		n = n or 1
		for i = 1, n do
			self:mDilate()
		end
		for i = 1, n do
			self:mErode()
		end  
	end
	function buffer:mClamp()
		local t = self:new()
		--TODO: brute-force dilate, remove inner loop!
		for x= 1, self.x-2 do
			for y = 1, self.y-2 do
				for z = 0, self.z-1 do
					b[0] = self:get(x, y, z)
					b[1] = self:get(x-1, y, z)
					b[2] = self:get(x+1, y, z)
					b[3] = self:get(x, y-1, z)
					b[4] = self:get(x, y+1, z)
					b[5] = self:get(x-1, y-1, z)
					b[6] = self:get(x+1, y+1, z)
					b[7] = self:get(x+1, y-1, z)
					b[8] = self:get(x-1, y+1, z)
					
					local min = math.min(b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
					local max = math.max(b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
					b[0] = b[0]>max and max or b[0]
					b[0] = b[0]<min and min or b[0]
					t:set(x, y, z, b[0])
				end
			end
		end
		self:copy(t) -- put back values
	end
end


require("Tools.imgops")(buffer)
return buffer


--[=[
img.newBuffer(x, y, z)		=>	img:new		(x, y, z)
img.newBuffer(x)			=>	img:newV	(x)
img.newBuffer({r, g, b})	=>	img:newC	(r, g, b)
img.pixelOp					==
img.toScreen				==
img.toScreenQuad			==
img.saveHD = img.bufferSaveHD	??
img.loadHD = img.bufferSaveHD	??
img.saveIM = img.writeIM		??
img.loadIM = img.readIM			??
img.copy					=>	img:copy()
img.new						=>	img:new()
img.copyGS					=>	img:copyG()
img.newGS					=>	img:newM()
img.copyColor				=>	img:copyC()
img.newColor				=>	img:newI()
img.max							??
img.min							??
img.csConvert				==
img.invert					==


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
