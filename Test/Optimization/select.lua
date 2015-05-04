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
-- provide select function in C that avoids branchy code => code remains branchy!

require("jit.v").start()

local compile = require("Tools.compile")
local ffi = require("ffi")
local sdl = require("Include.sdl2")


local code = [[
double select_C(_Bool c, double a, double b){
	if (c) return a;
	return b;
}

void select_C2(double *a, double *b){
	b[0] = select_C(a[0]>1, 1, 0);
}

void select_C16(double *a, double *b){
	for (int i=0;i<16;i++) {
		b[i] = select_C(a[i]>1, 1, 0);
	}
}

void select_loop(double *a, double *b, int n){
	for (int i=0;i<n;i++) {
		b[i] = select_C(a[i]>1, 1, 0);
	}
}
]]

ffi.cdef [[
double select_C(_Bool c, double a, double b);
void select_C2(double *a, double *b);
void select_C16(double *a, double *b);
void select_loop(double *a, double *b, int n);
]]

local c = compile.clang("select",code)

print(c.select_C(2>3,3,2))
print(c.select_C(3>2,3,2))

local n = 1000000
local d1 = ffi.new("double[?]", n)
local d2 = ffi.new("double[?]", n)

sdl.tic()
for i = 0, n-1 do
	d1[i] = math.random()*2
end
sdl.toc()

sdl.tic()
for i = 0, n-1 do
	d2[i] = d1[i]>1 and 1 or 0
end
sdl.toc()

sdl.tic()
for i = 0, n-1 do
	d2[i] = d1[i]>1
end
sdl.toc()

sdl.tic()
for i = 0, n-1 do
	d2[i] = c.select_C(d1[i]>1, 1, 0)
end
sdl.toc()

sdl.tic()
for i = 0, n-1 do
	c.select_C2(d1+i, d2+i)
end
sdl.toc()

sdl.tic()
for i = 0, n-1, 16 do
	c.select_C16(d1+i, d2+i)
end
sdl.toc()

sdl.tic()
c.select_loop(d1,d2,n)
sdl.toc()
