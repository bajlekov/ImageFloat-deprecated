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
local ppm = {}
local img = require "Tools.imgtools"

---[[methods for ppm headers
function ppm.newHeader(t)
	local header = {}
	for k, v in pairs(t) do header[k]=v end
	return header
end
--]]

--[[
	exported (16bit):
		ppm.readFile
		ppm.readIM
		ppm.readRAW
		ppm.writeFile
		ppm.writeIM
	
	ppm.toBuffer
	ppm.fromBuffer

	todo:
		ascii:		
			- read/write Octave ascii tables (64bit)
			- read/write CSV (64bit)
			buffer.writeCSV
			buffer.readCSV
			buffer.writeOctave
			buffer.readOctave

		Binary:
			- read/write PFM binary files (64bit)
				- semi-standard ppm header
			- read/write binary data with structured headers (64bit)
				- python/octave interface
			- read/write rgb raw data (64bit)
				- IM pipe
			ppm.writePFM
			ppm.readPFM

		buffer.writeRAW
		buffer.readRAW
		buffer.writeIM
		buffer.readIM
		
		native:
			- read/write native jpg, png, tiff, bmp using SDL_image (only 8-bit)
			buffer.readSDL
]]

local function skip_comment(f)
	local t = f:seek()
	local fl = f:read("*l")
	while string.len(fl)==0 or string.byte(fl)<49 or string.byte(fl)>57 do
		t = f:seek()
		fl = f:read("*l")
	end
	f:seek("set", t)
end

local function swap_endianness(data, length)
	for i = 0, length-1, 2 do
		data[i], data[i+1] = data[i+1], data[i]
	end
	return data
end

local function image_data(header, ds)
	local b = header.depth==8 and 1 or 2
	local size = header.res.x * header.res.y * 3 * b
	local data = ffi.new("uint8_t[?]", size, ds)
	header.__data = data --keep a reference to the data array, as cast creates a reference to a pointer, not an array.
	if b==2 then
		data = swap_endianness(data, size)
		data = ffi.cast("uint16_t*", data)
	end
	header.data = data
	return header
end

function ppm.writeFile(header)
	local f = io.open(header.name, "w"..(ffi.os=="Windows" and "b" or ""))
	f:write("P6\n")
	f:write("# Created with PPMtools for Lua\n")
	f:write(string.format("%d %d\n", header.res.x, header.res.y))
	if header.depth==8 then
		f:write(string.format("%d\n", 2^8-1))
		local size = header.res.x * header.res.y * 3
		f:write(ffi.string(header.data, size))
	else
		f:write(string.format("%d\n", 2^16-1))
		local size = header.res.x * header.res.y * 6
		local data = ffi.new("uint8_t[?]", size)
		ffi.copy(data, header.data, size)
		data = swap_endianness(data, size)
		f:write(ffi.string(data, size))
	end	
	f:close()
end

function ppm.writeIM(header, op)
	op = op or ""
	local f = io.popen("convert ppm:- "..op.." "..header.name, "w"..(ffi.os=="Windows" and "b" or ""))
	f:write("P6\n")
	f:write("# Created with PPMtools for Lua\n")
	f:write(string.format("%d %d\n", header.res.x, header.res.y))
	if header.depth==8 then
		f:write(string.format("%d\n", 2^8-1))
		local size = header.res.x * header.res.y * 3
		f:write(ffi.string(header.data, size))
	else
		f:write(string.format("%d\n", 2^16-1))
		local size = header.res.x * header.res.y * 6
		local data = ffi.new("uint8_t[?]", size) --cast instead of copy?? endianness swap needs to be done on copy
		ffi.copy(data, header.data, size)
		data = swap_endianness(data, size)
		f:write(ffi.string(data, size))
	end
	f:close()
end

function ppm.readFile(name)
	local f = io.open(name, "r"..(ffi.os=="Windows" and "b" or ""))
	if f:read("*l")~="P6" then print("wrong format") return nil end
	skip_comment(f)
	local x, y, b = f:read("*n", "*n", "*n", "*l")
	local d = f:seek()
	local ds = f:read("*a")
	f:close()
	local header = ppm.newHeader{
		name = name,
		res = {
			x = x,
			y = y,
			},
		depth = b<256 and 8 or 16,
		data = {},
		}
	return image_data(header, ds)
end

local function read_pipe(f, name)
	if f:read("*l")~="P6" then print("wrong format") return nil end
	-- skip whiteline
	local fl = ""
	while string.len(fl)==0 or string.byte(fl)<49 or string.byte(fl)>57 do
		fl = f:read("*l")
	end
	local x, y = string.match(fl, "(%d+)%s(%d+)")
	fl = f:read("*l")
	local b = string.match(fl, "(%d+)")
	x, y, b = tonumber(x), tonumber(y), tonumber(b)
	--local d = f:seek("cur")
	--print(d)
	local ds = f:read("*a")
	f:close()
	local header = ppm.newHeader{
		name = name,
		res = {
			x = x,
			y = y,
			},
		depth = b<256 and 8 or 16,
		data = {},
		}
	return image_data(header, ds)
end

function ppm.readRAW(name, op)
	op = op or "-h -o 2 -6"
	local f = io.popen("dcraw -c "..op.." "..name, "r"..(ffi.os=="Windows" and "b" or ""))
	return read_pipe(f, name)
end

function ppm.readIM(name, op)
	op = op or ""
	local f = io.popen("convert "..name.." "..op.." ppm:- ", "r"..(ffi.os=="Windows" and "b" or ""))
	return read_pipe(f, name)
end

--image data to float buffer
function ppm.toBuffer(header)
	local buffer = img:new(header.res.x, header.res.y, 3)
	local scale = header.depth==8 and 1/(2^8-1) or 1/(2^16-1)
	
	for x = 0, buffer.x-1 do
		for y = 0, buffer.y-1 do
			for c = 0, 2 do
				local t = header.data[(x + buffer.x * y) * 3 + c] * scale
				buffer:set(x, y, c, t) 
			end
		end
	end
	return buffer
end

function ppm.toBufferCrop(header, newX, newY)
	local buffer = img:new(newX, newY, 3)
	local offX = math.floor((header.res.x - buffer.x)/2)
	local offY = math.floor((header.res.y - buffer.y)/2)
	local fullX = header.res.x
	local scale = header.depth==8 and 1/(2^8-1) or 1/(2^16-1)
	for x = 0, buffer.x-1 do
		for y = 0, buffer.y-1 do
			for c = 0, 2 do
				local t = header.data[(offX + x + fullX * (offY + y)) * 3 + c] * scale
				buffer:set(x, y, c, t) 
			end
		end
	end
	return buffer
end

--float buffer to ppm image
function ppm.fromBuffer(buffer, depth)
	depth = depth or 16
	local header = ppm.newHeader{
		name = "",
		res = {
			x = buffer.x,
			y = buffer.y,
			},
		depth = depth,
		data = depth==8 and ffi.new("uint8_t[?]", buffer.x * buffer.y * 3) or ffi.new("uint16_t[?]", buffer.x * buffer.y * 3)
		}
	local scale = header.depth==8 and (2^8-1) or (2^16-1)
	local bc
	for x = 0, buffer.x-1 do
		for y = 0, buffer.y-1 do
			for c = 0, 2 do
				bc = buffer:get(x, y, c)
				bc = bc>1 and scale or bc*scale
				bc = bc<0 and 0 or bc
				header.data[(x + buffer.x * y) * 3 + c] = bc
			end
		end
	end
	return header
end

return ppm

