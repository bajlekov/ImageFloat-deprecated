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

-- implement compiled functions for buffer operations:
local optim = {}
--[[
	- copy		(src, dest, len)
	- add		(a, b, dest, len)
	- subtract	(a, b, dest, len)
	- multiply	(a, b, dest, len)
	- divide	(a, b, dest, len)
	- power		(a, b, dest, len)
	- root		(src, dest, len)
	- gamma		(src, dest, len)
	
	- different methods depending on size?
		-if b = a/3 then assume b is gray
		-if b = 3 then assume b is color
		-if b = 1 then assume b is value
--]]

local ffi = require("ffi")
local C

local path = "Ops/ISPC/"
local file = "ops"

-- ISPC implementation:
local ISPC
if jit.os=="Windows" then --32bit
	--TODO: x86-64 / i386pep for 64bit dll
	--TODO: Paths to executables
	os.execute ("ispc --arch=x86 --opt=fast-math -o "..path..file..".obj "..path..file..".ispc")
	os.execute ("ld -shared -mi386pe -o "..path..file..".dll "..path..file..".obj")
	ISPC = ffi.load("median.dll")
else --Linux 64bit
	os.execute ("ispc --opt=fast-math --pic -o "..path..file..".o "..path..file..".ispc") print("compiling... (ispc)")
	os.execute ("clang -shared -o "..path..file..".so "..path..file..".o") print("linking... (clang)")
	ISPC = ffi.load("./"..path..file..".so")
end

ffi.cdef[[
	//void ispc_move(float* src, float* dst, int size);
	void ispc_add(float* a, float* b, float* o, int size);
	void ispc_sub(float* a, float* b, float* o, int size);
	void ispc_mul(float* a, float* b, float* o, int size);
	void ispc_div(float* a, float* b, float* o, int size);
]]

optim.add = ISPC.ispc_add
optim.sub = ISPC.ispc_sub
optim.mul = ISPC.ispc_mul
optim.div = ISPC.ispc_div

--test
--[[
local size = 4096*4096*3
local a = ffi.new("float[?]", size)
local b = ffi.new("float[?]", size)
local c = ffi.new("float[?]", size)

for i = 0, size-1 do
	a[i] = math.random()
	b[i] = math.random()
	c[i] = math.random()
end

local t = os.clock()
for i = 1, 10 do
	ISPC.ispc_div(a, b, c, size)
end
print(os.clock() - t, "ISPC add")

local t = os.clock()
for i = 1, 10 do
	for j = 0, size-1 do
		c[j] = a[j] / b[j]
	end
end
print(os.clock() - t, "Lua add")


--]]

return optim