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

local ffi = require("ffi")

ffi.cdef[[
	void* malloc(size_t size);
	void* calloc(size_t num, size_t size);
	void* realloc(void* ptr, size_t size);
	void free(void* ptr);
]]

d = {}

for i = 1, 300 do
	--d[i] = ffi.new("double[?]",1024*1024)
	d[i] = ffi.C.calloc(1024*1024, 8)
	for j = 0, 1024*1024-1 do
		ffi.cast("double*", d[i])[j] = 8
	end
	collectgarbage("collect")
	--print(i, collectgarbage("count")/1000)
end

n = 0
for i = 1, 300 do
	for j = 0, 1024*1024-1 do
		n = n + ffi.cast("double*", d[i])[j]
	end
end
print(n)



-- allow garbage collection on regular allocated memory
local p = ffi.gc(ffi.C.calloc(100, 8), ffi.C.free)

-- structure for creating gc managed multidimensional arrays:
ffi.cdef[[
	typedef struct{
		double r, g, b;
	} rgb;
]]
print(ffi.sizeof("rgb"))
print(ffi.sizeof("double"))

--style: [x][y].r, [x][y].g, [x][y].b
--associate new indexing method??
d = ffi.new("rgb[4]")

print(d[0]["r"])

--easiest to create a coordinate to pointer converter function for indexing:
local idx = {xmax=0, ymax=0, call}
function idx:set(xmax, ymax)
	self.xmax = xmax
	self.ymax = ymax
end
function idx.call(x, y, z)
	return ((x * ymax + y)*3 + z)
end

--else create true 2D arrays containing rgb structs...same memory alignment? propagate structs to processing threads?
-- create array of struct pointer pointers
-- create array of structs
-- assign corresponding columns to pointers

-- possible overhead due to extra array of pointers? marginal
-- do not put secondary array to computing threads, array dereferencing vs pointer arithmetic performance?

-- array destruction should be handled by gc, both arrays need to be registered and kept in lua userdata!!!








