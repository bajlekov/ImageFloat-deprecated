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

-- transform array of XYZ data to hybrid arrays of X, Y and Z data to facilitate SIMD processing
-- take care of edge cases (remainder)

--[[
this structure is useful for single pixel ops, scatters and gathers are inefficient when pixels are grouped by 16
for pixel ops: have separate getters and setters for the new layout:

struct: [rrrr rrrr rrrr rrrr gggg gggg gggg gggg bbbb bbbb bbbb bbbb]

result: fair pixel locality, excellent alignment for SIMD CS ops
disadvantage: need for pixel transfer, dealing with remainders
check ISPC SIMD-ability for short arrays (16 x float)
--]]

-- write ispc file
print(os.execute("pwd"))
local ffi = require("ffi")

-- compile ispc
local file = "test"
os.execute ("ispc --opt=fast-math --pic -o "..file..".o "..file..".ispc") print("compiling... (ispc)")
os.execute ("clang -shared -O4 -o "..file..".so "..file..".o") print("linking... (clang)")
local ISPC = ffi.load("./"..file..".so")
ffi.cdef[[
	void ispc_pack(float* src, float* dst, int size);
	void ispc_unpack(float* src, float* dst, int size);
	void ispc_mean_packed(float* src, float* dst, int size);
	void ispc_mean_unpacked(float* src, float* dst, int size);
	void ispc_mean_c(float* src, float* dst, int size);
]]

local function lua_pack(src, dst, size)
	for i = 0, size-1 do
		dst[i] = src[i*3]
    	dst[size+i] = src[i*3+1]
    	dst[2*size+i] = src[i*3+2]
	end
end

local function lua_unpack(src, dst, size)
	for i = 0, size-1 do
		dst[i*3] = src[i]
    	dst[i*3+1] = src[size+i]
    	dst[i*3+2] = src[2*size+i]
	end
end


local size = 4096*3072
-- check operation speed
local a = ffi.new("float[?]", size*3)
local b = ffi.new("float[?]", size*3)

for i = 0, size*3-1, 3 do
	a[i]=1+i/3*10
	a[i+1]=2+i/3*10
	a[i+2]=3+i/3*10
end

-- check transform speed
local step = 16
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		ISPC.ispc_pack(a+i,b+i,step)
		ISPC.ispc_unpack(b+i,a+i,step)
	end
end
local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		ISPC.ispc_pack(a+i,b+i,step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_unpack(b+i,a+i,step)
		--ISPC.ispc_mean_unpacked(a+i, a+i, step)
	end
end
print(os.clock()-t, "pack/unpack + 8x packed")

local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		ISPC.ispc_pack(a+i,b+i,step)
		ISPC.ispc_unpack(b+i,a+i,step)
	end
end
print(os.clock()-t, "pack/unpack ispc")

local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		lua_pack(a+i,b+i,step)
		lua_unpack(b+i,a+i,step)
	end
end
print(os.clock()-t, "pack/unpack lua")

local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		ISPC.ispc_mean_unpacked(a+i, a+i, step)
		ISPC.ispc_mean_unpacked(a+i, a+i, step)
		ISPC.ispc_mean_unpacked(a+i, a+i, step)
		ISPC.ispc_mean_unpacked(a+i, a+i, step)
		ISPC.ispc_mean_unpacked(a+i, a+i, step)
		ISPC.ispc_mean_unpacked(a+i, a+i, step)
		ISPC.ispc_mean_unpacked(a+i, a+i, step)
		ISPC.ispc_mean_unpacked(a+i, a+i, step)
	end
end
print(os.clock()-t, "8x unpacked")

local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
		ISPC.ispc_mean_packed(b+i, b+i, step)
	end
end
print(os.clock()-t, "8x packed")

local t = os.clock()
for j = 1, 10 do
	ISPC.ispc_mean_packed(b, b, size)
end
print(os.clock()-t, "all-at-once")


local function mean(src, dst, size)
	for i = 0, size-1 do
		dst[i*3] = (src[i*3] + src[i*3+1] + src[i*3+2])/3
	end
end

local function meanSingle(src,dst)
	dst[0] = (src[0] + src[1] + src[2])/3
end

local function meanI(i, src, dst)
	meanSingle(src+i*3, dst+i*3)
end

local function unroll8(fun, ...)
	fun(0, ...) fun(1, ...) fun(2, ...) fun(3, ...)
	fun(4, ...) fun(5, ...) fun(6, ...) fun(7, ...)
end

local function unroll16(fun, ...)
	fun(0, ...)  fun(1, ...)  fun(2, ...)  fun(3, ...)
	fun(4, ...)  fun(5, ...)  fun(6, ...)  fun(7, ...)
	fun(8, ...)  fun(9, ...)  fun(10, ...) fun(11, ...)
	fun(12, ...) fun(13, ...) fun(14, ...) fun(15, ...)
end

local function unroll32(fun, ...)
	fun(0, ...)  fun(1, ...)  fun(2, ...)  fun(3, ...)
	fun(4, ...)  fun(5, ...)  fun(6, ...)  fun(7, ...)
	fun(8, ...)  fun(9, ...)  fun(10, ...) fun(11, ...)
	fun(12, ...) fun(13, ...) fun(14, ...) fun(15, ...)
	
	fun(16, ...) fun(17, ...) fun(18, ...) fun(19, ...)
	fun(20, ...) fun(21, ...) fun(22, ...) fun(23, ...)
	fun(24, ...) fun(25, ...) fun(26, ...) fun(27, ...)
	fun(28, ...) fun(29, ...) fun(30, ...) fun(31, ...)
end
--template for unrolling

local function none(src, dst, size)
	local i = 1
	dst[i*3] = (src[i*3] + src[i*3+1] + src[i*3+2])/3
end

step = 1
local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		meanSingle(a+i, a+i, step)
	end
end
print(os.clock()-t, step)
--performance suffers from small inner loop!
--wrap calls into unrolled loop!!

step = 8
local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		unroll8(meanI, a+i, a+i)
	end
end
print(os.clock()-t, step)

step = 16
local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		unroll16(meanI, a+i, a+i)
	end
end
print(os.clock()-t, step)

step = 32
local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		unroll32(meanI, a+i, a+i)
	end
end
print(os.clock()-t, step)
--performance suffers from small inner loop, recovers past chunks of 1024...
-- construct inlineable function

step = 1024
local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		mean(a+i, a+i, step)
	end
end
print(os.clock()-t, step)
--performance suffers from small inner loop!

step = 1024
local t = os.clock()
for j = 1, 10 do
	for i = 0, size*3-1,step*3 do
		ISPC.ispc_mean_c(a+i, a+i, step)
	end
end
print(os.clock()-t, "C")


-- check local ISPC ops with lua loop (works with simple add ops), allowing local op chaining in sets of 16xRGB
-- check code validity!!!!

--[[ NOTES:
ispc seems to optimize non-aligned ops as well, conversion to packed order might be unnecessary (unless all ops benefit from it)
ispc is roughly ~3x faster than native c or lua, chunking data does not affect performance, benefits locality for chained ops

check performance for chained pixel vs chained chunk vs chained whole image processing (also chained chunk allows SIMD processing, check both with and without)

convert CS library to iscp compiled code for better performance
convert code to chained chunk processing for color ops (design!!!!!)

depending on operation, chained ops can perform much better, ex: packed vs unpacked chained ops...take care to distinguish effects! chaining does not always result in great benefits
--]]
