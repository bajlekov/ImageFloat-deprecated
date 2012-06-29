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
local img = {}

function img.newBuffer(a, b, c)
	local out = {}
	--properties
	if type(a)=="number" and b==nil then
		out.x = 1
		out.y = 1
		out.z = 1
		out.data = ffi.new("double[1][1][1]")
		out.data[0][0][0] = a
		out.type = 1
		out.cs = "MAP"
	elseif type(a)=="number" and type(b)=="number" and type(c)=="number" then
		out.x = a
		out.y = b
		out.z = c
		out.data = ffi.new("double["..a.."]["..b.."]["..c.."]")
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
		out.data = ffi.new("double[1][1][3]")
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
	out.saveIM = img.writeIM
	out.loadHD = img.bufferSaveHD
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
	out.data = ffi.new("double["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = buffer.cs
	out.type = buffer.type
	ffi.copy(out.data, buffer.data, buffer.x*buffer.y*buffer.z*8)
	return out
end

function img.new(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = buffer.z
	out.data = ffi.new("double["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = buffer.cs
	out.type = buffer.type
	return out
end

function img.copyGS(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = 1
	out.data = ffi.new("double["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = "MAP"
	if buffer.type==4 then
		out.type = 3 
	elseif buffer.type==2 then
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
	out.data = ffi.new("double["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = "MAP"
	if buffer.type==4 then
		out.type = 3 
	elseif buffer.type==2 then
		out.type = 1
	end
	return out
end

function img.copyColor(buffer)
	local out = img.newBuffer()
	out.x = buffer.x
	out.y = buffer.y
	out.z = 3
	out.data = ffi.new("double["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = "SRGB"
	if buffer.type==3 then
		out.type = 4 
	elseif buffer.type==1 then
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
	out.data = ffi.new("double["..tonumber(out.x).."]["..tonumber(out.y).."]["..tonumber(out.z).."]")
	out.cs = "SRGB"
	if buffer.type==3 then
		out.type = 4 
	elseif buffer.type==1 then
		out.type = 2
	end
	return out
end

do 
	local chunk = 1000
	function img.bufferSaveHD(buffer, fname)
		local x, y = buffer.x, buffer.y
		local b = ffi.cast("uint8_t*", buffer.data)
		local f = io.open(fname, "w")
		f:write(ffi.string(ffi.new("double[2]", {x, y}), 16))
		--write in several pieces
		for i = 0, x*y*3*8, chunk do
			f:write(ffi.string(b+i, chunk))
		end
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
		local res_d = ffi.cast("double*", res_s)
		local x, y = res_d[0], res_d[1]
		buffer.x, buffer.y, buffer.z = x, y, 3
		buffer.data = ffi.new("double["..x.."]["..y.."][3]")
		local b = ffi.cast("uint8_t*", buffer.data)
		--read in several pieces
		for i = 0, x*y*3*8, chunk do
			ffi.copy(b+i, f:read(chunk))
		end
		f:close()
		return buffer
	end

	function img.writeIM(buffer, name, op)
		op = op or ""
		local f = io.popen("convert -define quantum:format=floating-point -depth 64 -size "..buffer.y.."x"..buffer.x..
			" rgb:- -transpose "..op.." "..name, "w")
		local x, y, z = buffer.x, buffer.y, buffer.z
		f:write(ffi.string(buffer.data, x*y*3*8))
		f:close()
	end
end



require("imgops")(img)
return img