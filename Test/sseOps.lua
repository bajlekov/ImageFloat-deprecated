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

os.execute('pwd')

-- check accuracy of power calculations

-- example code for gamma transform from opsCS
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

-- create c library for vectorised calculation of above functions
os.execute ("gcc -O2 -march=native -fPIC -c Test/sse.c -o Test/sse.o")
os.execute ("gcc -shared -o Test/libsse.so Test/sse.o")

-- test library

ffi = require("ffi")
--lib = ffi.load("./Test/libsse.so")
lib = ffi.load("./Test/libadd.so")
sse = ffi.load("./Test/libsse.so")

ffi.cdef[[
	void vpow(float* x, float* y, float* z);
	void add(float* a, float* b, float* c);
	void LRGBtoSRGB(float* x, float* z);
	void SRGBtoLRGB(float* x, float* z);
	typedef float float_a __attribute__ ((aligned (16)));
	int printf ( const char * format, ... );
]]

local a = ffi.new("float_a[4]",{0.3,0.5,0.7,0.9})
local b = ffi.new("float_a[4]",{2.25,2.25,2.25,2.25})
local c = ffi.new("float_a[4]",{0,0,0,0})

-- test precision
sse.vpow(a,b,c)
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])

c[0]=a[0]^b[0]
c[1]=a[1]^b[1]
c[2]=a[2]^b[2]
c[3]=a[3]^b[3]
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])


-- test precision
sse.SRGBtoLRGB(a,c)
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])

c[0]=SRGBtoLRGB(a[0])
c[1]=SRGBtoLRGB(a[1])
c[2]=SRGBtoLRGB(a[2])
c[3]=SRGBtoLRGB(a[3])
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])

sse.LRGBtoSRGB(a,c)
sse.SRGBtoLRGB(c,c)
ffi.C.printf("%0.10f\t%0.10f\t%0.10f\t%0.10f\n", c[0], c[1], c[2], c[3])

local s = 0

local t1, t2

t1 = os.clock()
for i = 1,10000000 do
	a[0]=i+3
	a[1]=i+2
	a[2]=i+1
	a[3]=i
	sse.SRGBtoLRGB(a, c)
	s = s + c[0] + c[1] + c[2] + c[3]
end
t2 = os.clock()
print(s, c[0], c[1], c[2], c[3])
print(t2-t1)

s = 0
local sqrt = math.sqrt

t1 = os.clock()
for i = 1,10000000 do
	a[0]=i+3
	a[1]=i+2
	a[2]=i+1
	a[3]=i
	c[0] = SRGBtoLRGB(a[0])
	c[1] = SRGBtoLRGB(a[1])
	c[2] = SRGBtoLRGB(a[2])
	c[3] = SRGBtoLRGB(a[3])
	s = s + c[0] + c[1] + c[2] + c[3]
end
t2 = os.clock()
print(s, c[0], c[1], c[2], c[3])
print((t2-t1)/4)