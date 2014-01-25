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

if __global and (not __global.setup.optCompile.ispc) then return {} end

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

local path = "./Source/Ops/ISPC/"
local file = "ops"

-- ISPC implementation:
local ISPC

if jit.os=="Windows" then --32bit
	--TODO: x86-64 / i386pep for 64bit dll
	--TODO: Paths to executables
	if __global==nil or __global.setup.optRecompile then
	os.execute ("ispc --arch=x86 --opt=fast-math -o "..path..file..".obj "..path..file..".ispc")
	os.execute ("ld -shared -mi386pe -o "..path..file..".dll "..path..file..".obj")
	end
	ISPC = ffi.load("./"..path..file..".dll")
else --Linux 64bit
	if __global==nil or __global.setup.optRecompile then
	os.execute ("ispc --opt=fast-math --pic -o "..path..file..".o "..path..file..".ispc") print("compiling... (ispc)")
	os.execute ("clang -shared -o "..path..file..".so "..path..file..".o") print("linking... (clang)")
	end
	ISPC = ffi.load("./"..path..file..".so")
end

ffi.cdef[[
	//void ispc_move(float* src, float* dst, int size);
	void ispc_add(float* a, float* b, float* o, int size);
	void ispc_sub(float* a, float* b, float* o, int size);
	void ispc_mul(float* a, float* b, float* o, int size);
	void ispc_div(float* a, float* b, float* o, int size);
	void ispc_pow(float* a, float b, float* o, int size);
	void ispc_move(float* i, float* o, int size);
	
	void ispc_LtoG(float* src, float* dst, int size);
	void ispc_GtoL(float* src, float* dst, int size);
]]

optim.add = ISPC.ispc_add
optim.sub = ISPC.ispc_sub
optim.mul = ISPC.ispc_mul
optim.div = ISPC.ispc_div
optim.pow = ISPC.ispc_pow
optim.mov = ISPC.ispc_move

-- FIXME: gamma node fails if this test is not run!!! ... segfault calling ispc functions from thread
-- on the bright side, this consistently triggers the error
-- bug in ispc??

--test
--[[
local LtoG
local GtoL
do
	local a = 0.055
	local G = 1/0.42

	local a_1 = 1/(1+a)
	local G_1 = 1/G

	local f = ((1+a)^G*(G-1)^(G-1))/(a^(G-1)*G^G)
	local k = a/(G-1)
	local k_f = k/f
	local f_1 = 1/f

	function LtoG(i)
		return i<=k_f and i*f or (a+1)*i^G_1-a
	end
	function GtoL(i)
		return i<=k and i*f_1 or ((i+a)*a_1)^G
	end
end

---[[

local size = 4096*128*3
local a = ffi.new("float[?]", size)
local b = ffi.new("float[?]", size)
local c = ffi.new("float[?]", size)
local d = ffi.new("float[?]", size)
local e = ffi.new("float[?]", size)

for i = 0, size-1 do
	a[i] = math.random()
	b[i] = math.random()
	c[i] = math.random()
end

local t = os.clock()
	ISPC.ispc_pow(a, 2, b, size)
print(os.clock() - t, "ISPC power")

local t = os.clock()
ISPC.ispc_LtoG(a, b, size)
ISPC.ispc_GtoL(b, c, size)
print(os.clock() - t, "ISPC gamma")

local t = os.clock()
for j = 0, size-1 do
	b[j] = LtoG(a[j])
end
for j = 0, size-1 do
	d[j] = GtoL(b[j])
end
print(os.clock() - t, "Lua gamma")

local d1, d2, d3 = 0, 0, 0
for i = 0, size do
	d1 = d1 + math.abs(c[i]-a[i])
	d2 = d2 + math.abs(d[i]-a[i])
end
print("error ISPC: "..d1)
print("error Lua: "..d2)
--]]

return optim
