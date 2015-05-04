--[[
Copyright (C) 2011-2014 G. Bajlekov

Imagefloat is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Imagefloat is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- optimize processing by compiling ISPC functions
-- compile multiple function sets with multiple getter/setter functions -> optimize for different types of input
-- get[Image/Map/Color/Value][AoS/SoA][H/V][CS]
-- either precompile strictly for one use-case, skip CS or process chunks by ISPC, not complete functions

local compile = require("Tools.compile")
local ffi = require("ffi")

-- generation of specialized code

local access = [[
inline varying float get(uniform float d[], varying int i) {return d[i];}
inline void set(uniform float d[], varying int i, varying float v) {d[i] = v;}
]]

local body = [[
export void div(uniform float a[], uniform float b[], uniform float c[], uniform int n) {
  foreach(i=0...n) {
    varying float v = get(a, i) / get(b, i);
    set(c, i, v);
  }
}
]]

-- get order of parameters, get parameter attributes, assign correct getters, setters

local tt = os.clock()
for i = 1, 10 do
  local g = body:gmatch("export%W*void%W*(%w*)%W*(%b())")
  --print(g())
  
  local g = body:gmatch("[gs]et%b()")
  --print(g(), g(), g())
  compile.ispc("testA", access..body)
end
print(os.clock()-tt)

os.exit()

--



local tt = os.clock()
local test = [[
inline varying float get(uniform float d[], varying int i) {return d[i];}
inline uniform float get(uniform float d[], uniform int i) {return d[i];}
inline void set(uniform float d[], varying int i, varying float v) {d[i] = v;}
inline void set(uniform float d[], uniform int i, uniform float v) {d[i] = v;}

export void addVec(uniform float a[], uniform float b[], uniform float c[], uniform int n) {
	foreach(i=0...n) {
    if (a[i]<1) {
      varying float v = get(a, i)/get(b, i);
		  set(c, i, v);
		}
	}
}

export void addReg(uniform float a[], uniform float b[], uniform float c[], uniform int n) {
	for (uniform int i=0; i<n; i++) {
    if (a[i]<1) {
      uniform float v = get(a, i)/get(b, i);
		  set(c, i, v);
		}
	}
}
]]
local add = compile.ispc("test1",test)
print(os.clock() - tt)

local tt = os.clock()
local test = [[
float get(float* d, int i) {return d[i];}
void set(float* d, int i, float v) {d[i] = v;}

void addRegC(float* a, float* b, float* c, int n) {
	for (int i=0; i<n; i++) {
		if (a[i]<1) {
		  float v = get(a, i)/get(b, i);
		  set(c, i, v);
		}
	}
}
]]
local addC = compile.clang("test2",test)
print(os.clock() - tt)

ffi.cdef[[
void addVec(float* a, float* b, float* c, int n);
void addReg(float* a, float* b, float* c, int n);
void addRegC(float* a, float* b, float* c, int n);
]]

local n = 1000*1000*5

local a = ffi.new("float[?]", n)
local b = ffi.new("float[?]", n)
local c = ffi.new("float[?]", n)

for i = 0, n-1 do
  a[i] = math.random()*2
end

a[3] = 5
b[3] = 7

-- unbiased conditionals slow down lua and non-vectorized C significantly. ISPC handles more structures than C autovectorization
local function addLua(a, b, c, n)
	for i = 0, n-1 do
    if a[i]<1 then c[i] = a[i] / b[i] end
	end
end

local t = os.clock()
for i = 1, 100 do
	add.addVec(a, b, c, n)
end
print(os.clock()-t)

local t = os.clock()
for i = 1, 100 do
	add.addReg(a, b, c, n)
end
print(os.clock()-t)

local t = os.clock()
for i = 1, 100 do
	addC.addRegC(a, b, c, n)
end
print(os.clock()-t)

local t = os.clock()
for i = 1, 100 do
	addLua(a, b, c, n)
end
print(os.clock()-t)


print("whee", c[3])