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

--[[
	Note:
	- LuaJIT requires SSE2, assume it's always available
		- not using it is a waste, still offer fallback options
	
	Conclusions:
	- SSE often improves performance by 2-3x over native lua
	- C improves performance by about 1-2x, provided -ffast-math is used
	- lua performs similarly to C when using an SSE operation
	- the GCC vectoriser is able to optimise some functions better than native SSE
		- native C routines offers small improvements, unless vectorised
	- implementing SSE routines is worthwile, easily accessed from lua
		- needs extra code to handle unaligned array start and ends
		- needs extra logistics to provide library
		- code and performance becomes architecture-dependent, allowing native lua feedback is needed 
	- loops in lua vs C do not matter
	
	Actions:
	- implement fallback mechanisms in pure lua (settings option)
	- offer optimised library with support for basic vector and element operations
	- offer specific operations coded in SSE or auto-vectorised by GCC (depending on performance)
	
	- use ispc for easier SIMD code
--]]

-- create c library for vectorised calculation of above functions
--os.execute ("clang -mllvm -vectorize-loops -mllvm -vectorize -O3 -std=gnu99 -ffast-math -march=native -fPIC -c Test/sse.c -o Test/sse.o") print("LLVM")
--os.execute ("gcc -m64 -O3 -std=gnu99 -ffast-math -march=native -fPIC -ftree-vectorizer-verbose=2 -c Test/sse.c -o Test/sse.o") print("vectorised GCC")
--os.execute ("gcc -O3 -std=gnu99 -ffast-math -fexpensive-optimizations -march=native -mtune=native -fPIC -fno-tree-vectorize -c Test/sse.c -o Test/sse.o") print("non-vectorised GCC")
--os.execute ("gcc -shared -o Test/libsse.so Test/sse.o")

os.execute ("ispc --opt=fast-math -o Test/sse.o Test/sse.ispc") print("ISPC")
--os.execute ("ispc --emit-asm --arch=x86-64 --math-lib=fast --opt=fast-math --opt=force-aligned-memory --pic -o Test/sse.asm Test/sse.ispc")

os.execute ("gcc -m64 -shared -o Test/libsse.so Test/sse.o")
-- test library

ffi = require("ffi")
sse = ffi.load("./Test/libsse.so")

ffi.cdef[[
	void vpow(float* x, float* y, float* z);
	void vpowVEC(float* x, float* y, float* z, int size);
	void add(float* a, float* b, float* c);
	void LRGBtoSRGB(float* x, float* z);
	void SRGBtoLRGB(float* x, float* z);
	typedef float float_a __attribute__ ((aligned (16)));
	int printf ( const char * format, ... );
]]

-- check accuracy of power calculations

-- example code for gamma transform from opsCS
--[[
local aa = 0.099
local G = 1/0.45

local a_1 = 1/(1+aa)
local G_1 = 1/G

local f = ((1+aa)^G*(G-1)^(G-1))/(aa^(G-1)*G^G)
local k = aa/(G-1)
local k_f = k/f
local f_1 = 1/f

local function LRGBtoSRGB(i)
	return i<=k_f and i*f or (aa+1)*i^G_1-aa
end
local function SRGBtoLRGB(i)
	return i<=k and i*f_1 or ((i+aa)*a_1)^G
end

local a = ffi.new("float_a[4]",{0.3,0.5,0.7,0.9})
local b = ffi.new("float_a[4]",{2.25,2.25,2.25,2.25})
local c = ffi.new("float_a[4]",{0,0,0,0})

-- test precision
print("\nSSE v. Lua power:")
sse.vpow(a,b,c)
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])

c[0]=a[0]^b[0]
c[1]=a[1]^b[1]
c[2]=a[2]^b[2]
c[3]=a[3]^b[3]
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])


-- test precision
print("\nSSE v. Lua SRGBtoLRGB:")
sse.SRGBtoLRGB(a,c)
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])

c[0]=SRGBtoLRGB(a[0])
c[1]=SRGBtoLRGB(a[1])
c[2]=SRGBtoLRGB(a[2])
c[3]=SRGBtoLRGB(a[3])
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])

sse.LRGBtoSRGB(a,c)
sse.SRGBtoLRGB(c,c)
print("\nRoundtrip:")
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])
print("")
local s = 0

local t1, t2

t1 = os.clock()
for i = 1,10000000 do
	a[0]=i+3
	a[1]=i+2
	a[2]=i+1
	a[3]=i
	sse.vpow(a, b, c)
	s = s + c[0] + c[1] + c[2] + c[3]
end
t2 = os.clock()
print(t2-t1, "Lua SSE power")

s = 0
local sqrt = math.sqrt

t1 = os.clock()
for i = 1,10000000 do
	a[0]=i+3
	a[1]=i+2
	a[2]=i+1
	a[3]=i
	c[0] = a[0]^b[0]
	c[1] = a[1]^b[1]
	c[2] = a[2]^b[2]
	c[3] = a[3]^b[3]
	s = s + c[0] + c[1] + c[2] + c[3]
end
t2 = os.clock()
print(t2-t1, "Lua native power")
print("============================")
--]]

-- dilation example:
---[=[
local size = 1024000
local iter = 500
local a = ffi.new("float_a[?]", size)
local b = ffi.new("float_a[?]", size)
local c = ffi.new("float_a[?]", size)
local d = ffi.new("float_a[?]", size)

-- randomize a
for i = 0, size-1 do
	a[i] = math.random()
	b[i] = math.random()
	c[i] = math.random()
end

---[[ test pow function in ispc
local t = os.clock()
for i = 1, iter/10 do
	sse.vpowVEC(a, b, c, size)
end
print((os.clock()-t)*3, "Native ISPC pow")

local t = os.clock()
for i = 1, iter/10 do
	for j = 0, size-1, 4 do
		sse.vpow(a+j, b+j, c+j)
	end
end
print((os.clock()-t)*3, "Lua ISPC pow")

local t = os.clock()
for i = 1, iter/10 do
	sse.vpowVEC(a, b, c, size)
end
print((os.clock()-t)*3, "Native ISPC pow")


local t = os.clock()
for i = 1, iter/10 do
	for j = 0, size-1, 4 do
		sse.vpow(a+j, b+j, c+j)
	end
end
print((os.clock()-t)*3, "Lua ISPC pow")


local t = os.clock()
for i = 1, iter/10 do
	for j = 0, size-1 do
		d[j] = a[j]^b[j]
	end
end
print((os.clock()-t)*3, "Lua native pow")

local sum = 0
for i= 0, 100 do
	sum = sum + math.abs(c[i]-d[i])
end
print(sum, "total error")
--]]

-- closing is dilation followed by erosion
-- can be combined in a single SSE function where erosion lags by 1 and reuses registers?

-- native lua approach
local function dilate(a, b)
	for i = 4, size-4 do
		b[i] = math.max(a[i-2], a[i-1], a[i], a[i+1], a[i+2])
	end
end

-- warmup
for i = 1, 500 do
	dilate(a, b)
end

local t = os.clock()
for i = 1, iter/3 do
	dilate(a, b)
end
print((os.clock()-t)*3, "Lua native dilate")

ffi.cdef[[
	void dilate(float* x, float* y);
	void erode(float* x, float* y);
	void dilateC(float* x, float* y, int start, int end);
	void dilateSSE(float* x, float* y, int start, int end);
	void dilateCsingle(float* x, float* y);
	
	void addSSE(float* x, float* y, float* z, int size);
	void addC(float* x, float* y, float* z, int size);
	void addSSEsingle(float* x, float* y, float* z);
	void addCsingle(float* x, float* y, float* z);
]]

local function dilateC(a, b)
	for i = 4, size-4 do
		sse.dilateCsingle(a+i, b+i)
	end
end

local function dilateSSE(a, b)
	for i = 4, size-4, 4 do
		sse.dilate(a+i, b+i)
	end
end

local t = os.clock()
for i = 1, iter do
	dilateSSE(a, b)
end
print(os.clock()-t, "Lua SSE dilate")
-- about 3x improvement

local t = os.clock()
for i = 1, iter do
	dilateC(a, b)
end
print(os.clock()-t, "Lua C-lib dilate")

local t = os.clock()
for i = 1, iter do
	sse.dilateC(a, b, 4, size-4)
end
print(os.clock()-t, "C native dilate (slow without -ffast-math, vectorised)")
-- why is the native c loop so much slower?

local t = os.clock()
for i = 1, iter do
	sse.dilateSSE(a, b, 4, size-4)
end
print(os.clock()-t, "C SSE dilate")
-- lua SSE loop at same performance

print("============================")

iter = iter*5

local t = os.clock()
for i = 1, iter do
	sse.addSSE(a, b, a, size)
end
print(os.clock()-t, "C SSE add in-place")

local t = os.clock()
for i = 1, iter do
	sse.addSSE(a, b, c, size)
end
print(os.clock()-t, "C SSE add out-of-place")

local t = os.clock()
for i = 1, iter do
	--sse.addC(a, b, a, size)
end
print(os.clock()-t, "C native add in-place (vectorised)")

local t = os.clock()
for i = 1, iter do
	--sse.addC(a, b, c, size)
end
print(os.clock()-t, "C native add out-of-place (vectorised)")

local function add(a, b, c)
	for i = 0, size-1 do
		c[i] = a[i]+b[i]
	end
end

local function addSSE(a, b, c)
	for i = 4, size-4, 4 do
		sse.addSSEsingle(a+i, b+i, c+i)
	end
end

local function addC(a, b, c)
	for i = 4, size-4 do
		sse.addCsingle(a+i, b+i, c+i)
	end
end

local t = os.clock()
for i = 1, iter do
	add(a, b, a)
end
print(os.clock()-t, "Lua native add in-place")

local t = os.clock()
for i = 1, iter do
	add(a, b, c)
end
print(os.clock()-t, "Lua native add out-of-place")
-- native lua is some 30% slower than native C, SSE improves in-place add

local t = os.clock()
for i = 1, iter do
	addSSE(a, b, a)
end
print(os.clock()-t, "Lua SSE add in-place")

local t = os.clock()
for i = 1, iter do
	addSSE(a, b, c)
end
print(os.clock()-t, "Lua SSE add out-of-place")

--[[
local t = os.clock()
for i = 1, iter do
	addC(a, b, a)
end
print(os.clock()-t, "Lua C-lib add in-place")

local t = os.clock()
for i = 1, iter do
	addC(a, b, c)
end
print(os.clock()-t, "Lua C-lib add out-of-places")
--]]
--]=]