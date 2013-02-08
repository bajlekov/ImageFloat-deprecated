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


-- efficient number convert: use ffi arrays
-- don't concatenate tables, instead allocate memory at the start
-- handle all types, also signed types
-- efficient methods to get a single key without reading extra data
-- data table with known key values:
--[[
	camera brand
	camera model
	lens model/id?
	shutter
	aperture
	iso
	whitebalance
	focus
	date

	sort by any of these exif tags
--]]

local function num(str)
	-- proper way would be to put them in an ffi array, cast it correctly and read it out
	local n = #str
	local data = {str:byte(1, n)}
	local sum = 0
	for k, v in ipairs(data) do
		sum = sum + v*2^((k-1)*8)
	end
	return sum
end

local function snum(str)
	local n = #str
	local data = {str:byte(1, n)}
	local sum = 0
	for k, v in ipairs(data) do
		sum = sum + v*2^((k-1)*8)
	end
	
	-- handle sign
	if data[n]>127 then
		return -sum+128*2^((n-1)*8)
	else
		return sum
	end
end

local function exifRead(file, offset, header)
	offset = offset or 0 -- reference offset
	header = header or 8 -- read skip !! compensated with offset !!
	
	print("Reading EXIF data from "..file.." with offset "..offset.." and a header of "..header.." bytes.")
	
	local ex = {} -- output
	local f = io.open(file, "r") -- open file for read

	f:seek("set", offset + header) -- compensate for header and offset
	local n = num(f:read(2)) -- number of fields

	for i = 1, n do
		table.insert(ex, {
			num(f:read(2)), --tag
			num(f:read(2)),	--format
			num(f:read(4)),	--size
			num(f:read(4)),	--data
			})
	end
	
	local formatLength = {1,1,2,4,8,1,1,2,4,8,4,8,4}
	--[[
	1 - UByte
	2 - ASCII
	3 - UShort
	4 - ULong
	5 - URational ( ULong / ULong )
	6 - Byte
	7 - unspecified
	8 - Short
	9 - Long
	10 - Rational ( Long / Long )
	11 - Float
	12 - Double
	13 - Makernote address
	--]]
	
	-- speed up by only reading known values
	
	for k, v in pairs(ex) do -- go over all found fields
		local num = num
		if v[2]>5 and not v[2]==7 then num = snum end
		v.size = formatLength[v[2]]
		
		v.size = v.size or 0
		
		-- don't read into table if it's a known directory!
		
		if v.size*v[3]<=4 then
			v.data = v[4]	-- if data fits in field then read directly
			-- fix reading 2 values of length 2
		else
			f:seek("set", v[4] + offset)  -- else go to new offset
			
			if v[3]==1 then  -- if size is 1
				if v[2]==5 or v[2]==10 then
					v.data = num(f:read(4))/num(f:read(4))
				else
					v.data = num(f:read(8))
				end
			else
				local temp = {}  -- create table holding extra data
				for i = 1, v[3] do
					if v[2]==5 or v[2]==10 then
						table.insert(temp,num(f:read(4))/num(f:read(4)))
					else
						table.insert(temp,num(f:read(v.size)) )
					end
				end
				v.data = temp
			end
			
			if v[2]==2 then  -- following, if data is string then write to string
				v.data = string.char(unpack(v.data)):sub(1,-2)
			end
		end
		v.tag = string.format("%x", v[1])  -- convert all to string
		
		print(v.tag, v.data, v[2], v[3], v[4])
		
		if v.tag=="8769" then  --exif data
			v.data = exifRead(file, 0, v.data)
		end
		
		if v.tag=="927c" then  --makernote data
			v.data = exifRead(file, v[4], 12) -- specific for OLYMPUS V2
		end
		
		if v.tag=="2010" or v.tag=="2020" or v.tag=="2030" or v.tag=="2040" or v.tag=="2050" then  --makernote data
			v.data = exifRead(file, v[4] + offset, 0) -- specific for OLYMPUS V2
		end
		
		--v.tag=="927c" = makernotes
		--v.tag=="9286" = user comment
		--v.tag=="a302" = bayer pattern (2 width, 2 height, following: 0=red, 1=green, 2=blue, 3=cyan, 4=magenta, 5=yellow, 6=white)
		--v.tag=="c4a5" = Print image matching
		
		-- inside makernotes:
		-- 2010 = equipment
		-- 2020 = camera settings
		-- 2030 = raw development
		-- 2040 = image processing
		-- 2050 = focus info
		
	end
	--print(f:seek("set"))
	--print(f:seek("cur"))
	--print(f:seek("end"))
	f:close()
	
	-- fix output of data
	return ex
end

local ex = exifRead("/home/galin/P3050869.ORF",0,8)
