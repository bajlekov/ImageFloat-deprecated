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

--functions for compiling various sources

-- specify linker name
-- specify executable path

-- specify compiler arguments
-- specify linker arguments

local compile = {}
local ffi = require("ffi")

local function writeFile(file, str)
	local f, err = io.open(file,"w")
	f:write(str)
	f:close()
end

function compile.ispc(file, str)
	if str~=nil then
		writeFile(file..".ispc", str)
	end
	os.execute ("ispc --pic -o "..file..".o "..file..".ispc") print("compiling... (ispc)")
	os.execute ("clang -shared -o "..file..".so "..file..".o") print("linking... (clang)")
	return ffi.load("./"..file..".so")
end

function compile.gcc(file, str)
	if str~=nil then
		writeFile(file..".c", str)
	end
	os.execute ("gcc -O3 -std=gnu99 -march=native -fPIC -o "..file..".o -c "..file..".c") print("compiling... (gcc)")
	os.execute ("gcc -shared -o "..file..".so "..file..".o") print("linking... (gcc)")
	return ffi.load("./"..file..".so")
end


function compile.clang(file, str)
	if str~=nil then
		writeFile(file..".c", str)
	end
	os.execute ("clang -O3 -std=gnu99 -funroll-loops -march=native -fPIC -o "..file..".o -c "..file..".c") print("compiling... (clang)")
	os.execute ("clang -shared -o "..file..".so "..file..".o") print("linking... (clang)")
	return ffi.load("./"..file..".so")
end

return compile
