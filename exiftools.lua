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
	local n = #str
	local data = {str:byte(1, n)}
	local sum = 0
	for k, v in ipairs(data) do
		sum = sum + v*2^((k-1)*8)
	end
	return sum
end

local function exifRead(file, offset, header)
	ex = {}
	local f = io.open(file, "r")

	f:read((offset or 8) + (header or 12))
	local n = num(f:read(2))

	for i = 1, n do
		table.insert(ex, {
			num(f:read(2)), --tag
			num(f:read(2)),	--format
			num(f:read(4)),	--size
			num(f:read(4)),	--data
			})
	end
	local formatLength = {1,1,2,4,8,1,1,2,4,8,4,8}
	for k, v in pairs(ex) do
		v.size = formatLength[v[2]]
		if v.size*v[3]<=4 then
			v.data = v[4]
		else
			f:seek("set", v[4]+(header or 12))
			
			if v[3]==1 then
				if v[2]==5 then
					v.data = num(f:read(4))/num(f:read(4))
				else
					v.data = num(f:read(8))
				end
			else
				local temp = {}
				for i = 1, v[3] do
					if v[2]==5 then
						table.insert(temp,num(f:read(4))/num(f:read(4)))
					else
						table.insert(temp,num(f:read(v.size)) )
					end
				end
				v.data = temp
			end
			
			if v[2]==2 then
				v.data = string.char(unpack(v.data)):sub(1,-2)
			end
		end
		v.tag = string.format("%x", v[1])
		print(v.tag, v.data, v[2], v[3], v[4])
		if v.tag=="8769" then v.data = exifRead(file, v.data+(header or 0), header) end
		-- v.tag=="927c" = makernotes
	end
	--print(f:seek("set"))
	--print(f:seek("cur"))
	--print(f:seek("end"))
	f:close()
	return ex
end

exifRead("/home/galin/Pictures/P4308445.ORF",8,0)
local ex = exifRead("/home/galin/Pictures/P4308445.ORF", 3472, 12)

--[[
print(unpack(ex[1].data))
print(unpack(ex[2].data))
print(unpack(ex[3].data))
--]]