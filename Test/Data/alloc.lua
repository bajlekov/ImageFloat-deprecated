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

-- memory allocation for buffers

local ffi = require("ffi")
local alloc = {}
alloc.trace = {}

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

function alloc.trace.free(p)
	allocCount = allocCount - 1
	allocTable[p] = nil
	ffi.C.free(ffi.gc(p, nil))
end

function alloc.trace.float32(size)
	allocCount = allocCount + 1
	local t = ffi.cast("float_a*", ffi.C.calloc(size, 4))
	allocTable[t] = size * 4
	return ffi.gc(t, alloc.trace.free)
end

function alloc.trace.float64(size)
	allocCount = allocCount + 1
	local t = ffi.cast("double_a*", ffi.C.calloc(size, 8))
	allocTable[t] = size * 8
	return ffi.gc(t, alloc.trace.free)
end

function alloc.trace.count() return allocCount end

function alloc.trace.size()
	local sum = 0
	for _, v in pairs(allocTable) do sum = sum + v end
	return sum/1024/1024
end


function alloc.free(p)
	ffi.C.free(ffi.gc(p, nil))
end

function alloc.float32(size)
	local t = ffi.cast("float_a*", ffi.C.calloc(size, 4))
	return ffi.gc(t, ffi.C.free)
end

function alloc.float64(size)
	local t = ffi.cast("double_a*", ffi.C.calloc(size, 8))
	return ffi.gc(t, ffi.C.free)
end

return alloc