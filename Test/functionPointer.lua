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

-- Exploring function pointers in ISPC to produce buffer-structure independent operations

--[[ testcase:
		add buffer A + buffer B into buffer C
		either buffer can be of the following types:
			1:	single value [1x1x1]
			2:	single color [1x1x3]
			3:	value map	 [XxYx1]
			4:	color map	 [XxYxZ]
		in addition to efficiently sampling A and B, the shape of C is automatically inferred
		
		preferred notation:
		buffer table:
			- data pointer
			- X size
			- Y size
			- Z size
--]]

local ffi=require("ffi")

-- lua example:

local function newBuffer(x, y, z)
	local out = {}
	out.d = ffi.new("float[?]", x*y*z)
	out.x = x
	out.y = y
	out.z = z
	function out:get(x, y, z)
		return self.d[x*self.y*self.z + y*self.z + z]
	end
	function out:set(x, y, z, v)
		self.d[x*self.y*self.z + y*self.z + z] = v
	end
	return out
end

local function get1(b, x, y, z) return b.d[0] end
local function get2(b, x, y, z) return b.d[z] end
local function get3(b, x, y, z) return b.d[x*b.y + y] end
local function get4(b, x, y, z) return b.d[x*b.y*b.z + y*b.z + z] end

local function set1(b, x, y, z, v) b.d[z] = v end
local function set2(b, x, y, z, v) b.d[z] = v end
local function set3(b, x, y, z, v) b.d[x*b.y + y] = v end
local function set4(b, x, y, z, v) b.d[x*b.y*b.z + y*b.z + z] = v end

local function getX(x,y,z)
	if		x==1 and y==1 and z==1 then return get1
	elseif	x==1 and y==1 and z==3 then return get2
	elseif	x>1  and y>1  and z==1 then return get3
	elseif	x>1  and y>1  and z==3 then return get4
	end
end

local function setX(x,y,z)
	if		x==1 and y==1 and z==1 then return set1
	elseif	x==1 and y==1 and z==3 then return set2
	elseif	x>1  and y>1  and z==1 then return set3
	elseif	x>1  and y>1  and z==3 then return set4
	end
end

local max = math.max
local function addLua(a, b)
	local xmax, ymax, zmax = max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)
	local c = newBuffer(xmax,ymax,zmax)
	
	local getA = getX(a.x, a.y, a.z)
	local getB = getX(b.x, b.y, b.z)
	local setC = setX(c.x, c.y, c.z)
	
	if zmax==1 then
	for x = 0, xmax-1 do
		for y = 0, ymax-1 do
			local v = getA(a, x, y, 0) + getB(b, x, y, 0)
			setC(c, x, y, 0, v)
		end
	end
	else
	for x = 0, xmax-1 do
		for y = 0, ymax-1 do
			local v
			v = getA(a, x, y, 0) + getB(b, x, y, 0)
			setC(c, x, y, 0, v)
			v = getA(a, x, y, 1) + getB(b, x, y, 1)
			setC(c, x, y, 1, v)
			v = getA(a, x, y, 2) + getB(b, x, y, 2)
			setC(c, x, y, 2, v)
		end
	end
	end
	return c
end

-- test

local A = newBuffer(1,1,3)
local B = newBuffer(4,4,1)

A:set(0,0,0,5)
B:set(1,1,0,3)

local C = addLua(A, B)

print(C.x, C.y, C.z)
print(C:get(0,0,0))
print(C:get(1,1,0))
print(C:get(1,1,2))
print(C:get(2,2,0))

print("Lua: worky!")

-- ispc function pointer test:
--[=[
local compile = require("Tools.compile")

local ispc = [[
typedef uniform float (*FPfloat)(float);

export inline uniform
	float add5(uniform float f)
		{return f+5.0;}
		
export inline uniform
	float add3(uniform float f)
		{return f+3.0;}

export uniform
	float twice(uniform float i, uniform FPfloat f){
		return f(f(i));
	}
]]

ffi.cdef [[
	typedef float (*FPfloat)(float);
	float add3(float f);
	float add5(float f);
	float twice(float i, FPfloat f);
]]

local c = compile.ispc("test", ispc)

print(c.twice(22, c.add3))
--]=]

--[[ lessons learned:
		ispc function pointer system is a bit tricky
		print commands are not handled well at all and several functions interfere.
		passing pointers to exported functions works
		
		test arithmetics...
--]]


-- ispc testcase:

ispc = [[
typedef varying float (*FPget)(uniform float[], uniform int[], varying int, varying int, varying int);
typedef void (*FPset)(uniform float[], uniform int[], varying int, varying int, varying int, varying float);

varying float
	get1(uniform float b[], uniform int m[], varying int x, varying int y, varying int z) {
		return b[0]; }

varying float
	get2(uniform float b[], uniform int m[], varying int x, varying int y, varying int z) {           
		return b[z]; }

varying float
	get3(uniform float b[], uniform int m[], varying int x, varying int y, varying int z) {           
		return b[x*m[1] + y]; }

varying float
	get4(uniform float b[], uniform int m[], varying int x, varying int y, varying int z) {           
		return b[x*m[1]*m[2] + y*m[2] + z]; }

void
	set1(uniform float b[], uniform int m[], varying int x, varying int y, varying int z, varying float v) {
		b[z] = v; }

void
	set2(uniform float b[], uniform int m[], varying int x, varying int y, varying int z, varying float v) {
		b[z] = v; }

void
	set3(uniform float b[], uniform int m[], varying int x, varying int y, varying int z, varying float v) {
		b[x*m[1] + y] = v; }

void
	set4(uniform float b[], uniform int m[], varying int x, varying int y, varying int z, varying float v) {
		b[x*m[1]*m[2] + y*m[2] + z] = v; }

uniform FPget getX(int x, int y, int z) {
	if		(x==1 & y==1 & z==1) { return get1; }
	else if	(x==1 & y==1 & z==3) { return get2; }
	else if	(x>1  & y>1  & z==1) { return get3; }
	else if	(x>1  & y>1  & z==3) { return get4; }
}

uniform FPset setX(int x, int y, int z) {
	if		(x==1 & y==1 & z==1) { return set1; }
	else if	(x==1 & y==1 & z==3) { return set2; }
	else if	(x>1  & y>1  & z==1) { return set3; }
	else if	(x>1  & y>1  & z==3) { return set4; }
}

export void add(uniform int m[], uniform float a[], uniform float b[], uniform float c[]) {
	uniform FPget getA = getX(m[0], m[1], m[2]);
	uniform FPget getB = getX(m[3], m[4], m[5]);
	uniform FPset setC = setX(m[6], m[7], m[8]);
	
	if (m[8]==1) {
		foreach(x=0 ... m[6], y=0 ... m[7]) {
			varying float v = getA(a, m, x, y, 0) + getB(b, m+3, x, y, 0);
			setC(c, m+6, x, y, 0, v);
		}
	} else {
		foreach(x=0 ... m[6], y=0 ... m[7]) {
			varying float v;
			v = getA(a, m, x, y, 0) + getB(b, m+3, x, y, 0);
			setC(c, m+6, x, y, 0, v);
			v = getA(a, m, x, y, 1) + getB(b, m+3, x, y, 1);
			setC(c, m+6, x, y, 1, v);
			v = getA(a, m, x, y, 2) + getB(b, m+3, x, y, 2);
			setC(c, m+6, x, y, 2, v);
		}
	}
}


export void add_1(uniform int m[], uniform float a[], uniform float b[], uniform float c[]) {
	foreach(x=0 ... m[6], y=0 ... m[7]) {
		c[x*m[7]*m[8] + y*m[8] + 0] = a[x*m[1]*m[2] + y*m[2] + 0] + b[0];
		c[x*m[7]*m[8] + y*m[8] + 1] = a[x*m[1]*m[2] + y*m[2] + 1] + b[1];
		c[x*m[7]*m[8] + y*m[8] + 2] = a[x*m[1]*m[2] + y*m[2] + 2] + b[2];
	}
}

export void add_2(uniform int m[], uniform float a[], uniform float b[], uniform float c[]) {
	foreach(x=0 ... m[6], y=0 ... m[7]) {
		c[x*m[7]*m[8] + y*m[8] + 0] = a[x*m[1]*m[2] + y*m[2] + 0] + b[x*m[4] + y];
		c[x*m[7]*m[8] + y*m[8] + 1] = a[x*m[1]*m[2] + y*m[2] + 1] + b[x*m[4] + y];
		c[x*m[7]*m[8] + y*m[8] + 2] = a[x*m[1]*m[2] + y*m[2] + 2] + b[x*m[4] + y];
	}
}

export void add_3(uniform int m[], uniform float a[], uniform float b[], uniform float c[]) {
	foreach(x=0 ... m[6], y=0 ... m[7]) {
		c[x*m[7]*m[8] + y*m[8] + 0] = a[x*m[1]*m[2] + y*m[2] + 0] + b[0];
		c[x*m[7]*m[8] + y*m[8] + 1] = a[x*m[1]*m[2] + y*m[2] + 1] + b[0];
		c[x*m[7]*m[8] + y*m[8] + 2] = a[x*m[1]*m[2] + y*m[2] + 2] + b[0];
	}
}

export void add_4(uniform int m[], uniform float a[], uniform float b[], uniform float c[]) {
	foreach(x=0 ... m[6], y=0 ... m[7]) {
		c[x*m[7]*m[8] + y*m[8] + 0] = a[x*m[1]*m[2] + y*m[2] + 0] + b[x*m[4]*m[5] + y*m[5] + 0];
		c[x*m[7]*m[8] + y*m[8] + 1] = a[x*m[1]*m[2] + y*m[2] + 1] + b[x*m[4]*m[5] + y*m[5] + 1];
		c[x*m[7]*m[8] + y*m[8] + 2] = a[x*m[1]*m[2] + y*m[2] + 2] + b[x*m[4]*m[5] + y*m[5] + 2];
	}
}

]]

ffi.cdef [[
typedef float (*FPget)(float*, int*, int, int, int);
typedef void (*FPset)(float*, int*, int, int, int, float);

//float get1(float* b, int* m, int x, int y, int z);
//float get2(float* b, int* m, int x, int y, int z);
//float get3(float* b, int* m, int x, int y, int z);
//float get4(float* b, int* m, int x, int y, int z);

//void set1(float* b, int* m, int x, int y, int z, float v);
//void set2(float* b, int* m, int x, int y, int z, float v);
//void set3(float* b, int* m, int x, int y, int z, float v);
//void set4(float* b, int* m, int x, int y, int z, float v);

void add(int* m, float* a, float* b, float* c);
void add_branchy(int* m, float* a, float* b, float* c);

void add_1(int* m, float* a, float* b, float* c);
void add_2(int* m, float* a, float* b, float* c);
void add_3(int* m, float* a, float* b, float* c);
void add_4(int* m, float* a, float* b, float* c);
]]

clang = [[
typedef float (*FPget)(float*, int*, int, int, int);
typedef void (*FPset)(float*, int*, int, int, int, float);

float get1(float* b, int* m, int x, int y, int z) {
		return b[0]; }  __attribute__((hot))

float get2(float* b, int* m, int x, int y, int z) {
		return b[z]; }  __attribute__((hot))

float get3(float* b, int* m, int x, int y, int z) {
		return b[x*m[1] + y]; }  __attribute__((hot))

float get4(float* b, int* m, int x, int y, int z) {
		return b[x*m[1]*m[2] + y*m[2] + z]; }  __attribute__((hot))


void set1(float* b, int* m, int x, int y, int z, float v) {
		b[z] = v; }  __attribute__((hot))

void set2(float* b, int* m, int x, int y, int z, float v) {
		b[z] = v; }  __attribute__((hot))

void set3(float* b, int* m, int x, int y, int z, float v) {
		b[x*m[1] + y] = v; }  __attribute__((hot))

void set4(float* b, int* m, int x, int y, int z, float v) {
		b[x*m[1]*m[2] + y*m[2] + z] = v; }  __attribute__((hot))

FPget getX(int x, int y, int z) {
	if		(x==1 & y==1 & z==1) { return get1; }
	else if	(x==1 & y==1 & z==3) { return get2; }
	else if	(x>1  & y>1  & z==1) { return get3; }
	else { return get4; }
}

FPset setX(int x, int y, int z) {
	if		(x==1 & y==1 & z==1) { return set1; }
	else if	(x==1 & y==1 & z==3) { return set2; }
	else if	(x>1  & y>1  & z==1) { return set3; }
	else { return set4; }
}


void add(int* m, float* a, float* b, float* c) {
	FPget getA = getX(m[0], m[1], m[2]);
	FPget getB = getX(m[3], m[4], m[5]);
	FPset setC = setX(m[6], m[7], m[8]);
	
	int x, y, z;
	
	if (m[8]==1) {
		for (x=0; x<m[6]; x++) {
		for (y=0; y<m[7]; y++) {
			float v = getA(a, m, x, y, 0) + getB(b, m+3, x, y, 0);
			setC(c, m+6, x, y, z, 0);
		}}
	} else {
		for (x=0; x<m[6]; x++) {
		for (y=0; y<m[7]; y++) {
			float v;
			v = getA(a, m, x, y, 0) + getB(b, m+3, x, y, 0);
			setC(c, m+6, x, y, 0, v);
			v = getA(a, m, x, y, 1) + getB(b, m+3, x, y, 1);
			setC(c, m+6, x, y, 1, v);
			v = getA(a, m, x, y, 2) + getB(b, m+3, x, y, 2);
			setC(c, m+6, x, y, 2, v);
		}}
	}
}

static float getF(float* b, int* m, int x, int y, int z) {
	if		(m[0]==1 & m[1]==1 & m[2]==1) { return get1(b, m, x, y, z); }
	else if	(m[0]==1 & m[1]==1 & m[2]==3) { return get2(b, m, x, y, z); }
	else if	(m[0]>1  & m[1]>1  & m[2]==1) { return get3(b, m, x, y, z); }
	else { return get4(b, m, x, y, z); }
}  __attribute__((hot))

static void setF(float* b, int* m, int x, int y, int z, float v) {
	if		(m[0]==1 & m[1]==1 & m[2]==1) { return set1(b, m, x, y, z, v); }
	else if	(m[0]==1 & m[1]==1 & m[2]==3) { return set2(b, m, x, y, z, v); }
	else if	(m[0]>1  & m[1]>1  & m[2]==1) { return set3(b, m, x, y, z, v); }
	else { return set4(b, m, x, y, z, v); }
	//return set4(b, m, x, y, z, v);
}  __attribute__((hot))

void add_branchy(int* m, float* a, float* b, float* c) {
	int x, y, z;
	
	if (m[8]==1) {
		for (x=0; x<m[6]; x++) {
		for (y=0; y<m[7]; y++) {
			float v = getF(a, m, x, y, 0) + getF(b, m+3, x, y, 0);
			setF(c, m+6, x, y, z, 0);
		}}
	} else {
		for (x=0; x<m[6]; x++) {
		for (y=0; y<m[7]; y++) {
			float v;
			v = getF(a, m, x, y, 0) + getF(b, m+3, x, y, 0);
			setF(c, m+6, x, y, 0, v);
			v = getF(a, m, x, y, 1) + getF(b, m+3, x, y, 1);
			setF(c, m+6, x, y, 1, v);
			v = getF(a, m, x, y, 2) + getF(b, m+3, x, y, 2);
			setF(c, m+6, x, y, 2, v);
		}}
	}
} __attribute__((hot))


void add_1(int* m, float* a, float* b, float* c) {
	int x, y, z;

	for (x=0; x<m[6]; x++) {
	for (y=0; y<m[7]; y++) {
		c[x*m[7]*m[8] + y*m[8] + 0] = a[x*m[1]*m[2] + y*m[2] + 0] + b[0];
		c[x*m[7]*m[8] + y*m[8] + 1] = a[x*m[1]*m[2] + y*m[2] + 1] + b[1];
		c[x*m[7]*m[8] + y*m[8] + 2] = a[x*m[1]*m[2] + y*m[2] + 2] + b[2];
	}}
}

void add_2(int* m, float* a, float* b, float* c) {
	int x, y, z;

	for (x=0; x<m[6]; x++) {
	for (y=0; y<m[7]; y++) {
		c[x*m[7]*m[8] + y*m[8] + 0] = a[x*m[1]*m[2] + y*m[2] + 0] + b[x*m[4] + y];
		c[x*m[7]*m[8] + y*m[8] + 1] = a[x*m[1]*m[2] + y*m[2] + 1] + b[x*m[4] + y];
		c[x*m[7]*m[8] + y*m[8] + 2] = a[x*m[1]*m[2] + y*m[2] + 2] + b[x*m[4] + y];
	}}
}

void add_3(int* m, float* a, float* b, float* c) {
	int x, y, z;

	for (x=0; x<m[6]; x++) {
	for (y=0; y<m[7]; y++) {
		c[x*m[7]*m[8] + y*m[8] + 0] = a[x*m[1]*m[2] + y*m[2] + 0] + b[0];
		c[x*m[7]*m[8] + y*m[8] + 1] = a[x*m[1]*m[2] + y*m[2] + 1] + b[0];
		c[x*m[7]*m[8] + y*m[8] + 2] = a[x*m[1]*m[2] + y*m[2] + 2] + b[0];
	}}
}


void add_4(int* m, float* a, float* b, float* c) {
	int x, y, z;

	for (x=0; x<m[6]; x++) {
	for (y=0; y<m[7]; y++) {
		c[x*m[7]*m[8] + y*m[8] + 0] = a[x*m[1]*m[2] + y*m[2] + 0] + b[x*m[4]*m[5] + y*m[5] + 0];
		c[x*m[7]*m[8] + y*m[8] + 1] = a[x*m[1]*m[2] + y*m[2] + 1] + b[x*m[4]*m[5] + y*m[5] + 1];
		c[x*m[7]*m[8] + y*m[8] + 2] = a[x*m[1]*m[2] + y*m[2] + 2] + b[x*m[4]*m[5] + y*m[5] + 2];
	}}
}

/*
--add XxYx3, 1x1x3
--add XxYx3, XxYx1
--add XxYx3, 1x1x1
--add XxYx3, XxYx3
*/



]]

local compile = require("Tools.compile")

--local cc = compile.ispc("test", ispc)
local cc = compile.clang("test", clang)

local max = math.max
local function addISPC(a, b)
	local xmax, ymax, zmax = max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)
	local c = newBuffer(xmax,ymax,zmax)
	
	local s = ffi.new("int[9]", a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z)
	-- ispc function takes: [max size, a size, b size], a pointer, b pointer, c pointer, getA, getB, getC
	-- refine with structs similar to the lua buffer ones 
	
	cc.add_branchy(s, a.d, b.d, c.d)
	
	-- fixme: assigning variable value from calculation to uniform vector (b[0] = v) does not work
	
	return c
end

local function addISPCfun(a, b, fun)
	local xmax, ymax, zmax = max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)
	local c = newBuffer(xmax,ymax,zmax)
	
	local s = ffi.new("int[9]", a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z) 
	
	fun(s, a.d, b.d, c.d)
	
	return c
end

-- test

local A = newBuffer(1,1,3)
local B = newBuffer(4,4,1)

A:set(0,0,0,5)
B:set(1,1,0,3)

local C = addISPC(A, B)

print(C.x, C.y, C.z)
print(C:get(0,0,0))
print(C:get(1,1,0))
print(C:get(1,1,2))
print(C:get(2,2,0))

print("ISPC: worky!")




-- benchmark
local tic, toc
do
	local t
	tic = function() t = os.clock() end
	toc = function() return os.clock()-t end
end

local A = newBuffer(4096*2, 3072, 3)
local B = newBuffer(4096*2, 3072, 1)
local C = newBuffer(1, 1, 3)
local D = newBuffer(1, 1, 1)

--add XxYx3, 1x1x3
local function add_1(a,b)
	local xmax, ymax, zmax = max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)
	local c = newBuffer(xmax,ymax,zmax)
	for x = 0, xmax-1 do
		for y = 0, ymax-1 do
			c.d[x*c.y*c.z + y*c.z + 0] = a.d[x*a.y*a.z + y*a.z + 0] + b.d[0]
			c.d[x*c.y*c.z + y*c.z + 1] = a.d[x*a.y*a.z + y*a.z + 1] + b.d[1]
			c.d[x*c.y*c.z + y*c.z + 2] = a.d[x*a.y*a.z + y*a.z + 2] + b.d[2]
		end
	end
	return c
end
--add XxYx3, XxYx1
local function add_2(a,b)
	local xmax, ymax, zmax = max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)
	local c = newBuffer(xmax,ymax,zmax)
	for x = 0, xmax-1 do
		for y = 0, ymax-1 do
			c.d[x*c.y*c.z + y*c.z + 0] = a.d[x*a.y*a.z + y*a.z + 0] + b.d[x*b.y + y]
			c.d[x*c.y*c.z + y*c.z + 1] = a.d[x*a.y*a.z + y*a.z + 1] + b.d[x*b.y + y]
			c.d[x*c.y*c.z + y*c.z + 2] = a.d[x*a.y*a.z + y*a.z + 2] + b.d[x*b.y + y]
		end
	end
	return c
end
--add XxYx3, 1x1x1
local function add_3(a,b)
	local xmax, ymax, zmax = max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)
	local c = newBuffer(xmax,ymax,zmax)
	for x = 0, xmax-1 do
		for y = 0, ymax-1 do
			c.d[x*c.y*c.z + y*c.z + 0] = a.d[x*a.y*a.z + y*a.z + 0] + b.d[0]
			c.d[x*c.y*c.z + y*c.z + 1] = a.d[x*a.y*a.z + y*a.z + 1] + b.d[0]
			c.d[x*c.y*c.z + y*c.z + 2] = a.d[x*a.y*a.z + y*a.z + 2] + b.d[0]
		end
	end
	return c
end
--add XxYx3, XxYx3
local function add_4(a,b)
	local xmax, ymax, zmax = max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)
	local c = newBuffer(xmax,ymax,zmax)
	for x = 0, xmax-1 do
		for y = 0, ymax-1 do
			c.d[x*c.y*c.z + y*c.z + 0] = a.d[x*a.y*a.z + y*a.z + 0] + b.d[x*b.y*b.z + y*b.z + 0]
			c.d[x*c.y*c.z + y*c.z + 1] = a.d[x*a.y*a.z + y*a.z + 1] + b.d[x*b.y*b.z + y*b.z + 1]
			c.d[x*c.y*c.z + y*c.z + 2] = a.d[x*a.y*a.z + y*a.z + 2] + b.d[x*b.y*b.z + y*b.z + 2]
		end
	end
	return c
end

tic()
for i = 1, 1 do
	local o
	o = addLua(A,C)
	collectgarbage("collect")
	o = addLua(o,B)
	collectgarbage("collect")
	o = addLua(o,D)
	collectgarbage("collect")
	o = addLua(o,A)
	collectgarbage("collect")
end
print(toc(), "Lua")

tic()
for i = 1, 1 do
	local o
	o = add_1(A,C)
	collectgarbage("collect")
	o = add_2(o,B)
	collectgarbage("collect")
	o = add_3(o,D)
	collectgarbage("collect")
	o = add_4(o,A)
	collectgarbage("collect")
end
print(toc(), "Lua explicit")

tic()
for i = 1, 1 do
	local o
	o = addISPC(A,C)
	collectgarbage("collect")
	o = addISPC(o,B)
	collectgarbage("collect")
	o = addISPC(o,D)
	collectgarbage("collect")
	o = addISPC(o,A)
	collectgarbage("collect")
end
print(toc(), "ISPC")

tic()
for i = 1, 1 do
	local o
	o = addISPCfun(A,C, cc.add_1)
	collectgarbage("collect")
	o = addISPCfun(o,B, cc.add_2)
	collectgarbage("collect")
	o = addISPCfun(o,D, cc.add_3)
	collectgarbage("collect")
	o = addISPCfun(o,A, cc.add_4)
	collectgarbage("collect")
end
print(toc(), "ISPC explicit")


print("done")

--[[
	Regular loops in ISPC are slower than lua
	Using SSE4 is much faster than AVX instructions
	Test with actual C compiler for buggy ISPC behaviour - small gain for ISPC
	Eliminating z-loop from lua makes it even faster!!!
		Apparently inlining works much better with a tracing jit, no penalty for lua
		Eliminating function pointers makes C a bit faster than lua (0.75s vs 0.45s, ISPC: 0.70s)
			at the cost of excessive function specialisation (the add alone has 16 varieties)
			introducing branchy code to select proper getters and setters results in mediocre performance
--]]