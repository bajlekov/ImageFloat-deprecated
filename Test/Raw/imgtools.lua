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
local img = {}

function img.newBuffer(a, b, c)
	local out = {}
	--properties
	if type(a)=="number" and b==nil then
		out.x = 1
		out.y = 1
		out.z = 1
		out.data = ffi.new("float[1][1][1]")
		out.data[0][0][0] = a
		out.type = 1
		out.cs = "MAP"
	elseif type(a)=="number" and type(b)=="number" and type(c)=="number" then
		out.x = a
		out.y = b
		out.z = c
		out.data = ffi.new("float["..a.."]["..b.."]["..c.."]")
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
		out.data = ffi.new("float[1][1][3]")
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
	out.data = ffi.new("float["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = buffer.cs
	out.type = buffer.type
	ffi.copy(out.data, buffer.data, buffer.x*buffer.y*buffer.z*4)
	return out
end

function img.new(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = buffer.z
	out.data = ffi.new("float["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = buffer.cs
	out.type = buffer.type
	return out
end

function img.copyGS(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = 1
	out.data = ffi.new("float["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
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
	out.data = ffi.new("float["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
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
	out.data = ffi.new("float["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
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
	out.data = ffi.new("float["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
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
		local res_d = ffi.cast("float*", res_s)
		local x, y = res_d[0], res_d[1]
		
		buffer.x, buffer.y, buffer.z = x, y, 3
		buffer.data = ffi.new("float["..x.."]["..y.."][3]")

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
		buffer.data = ffi.new("float["..x.."]["..y.."][3]")

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



require("imgops")(img)
return img