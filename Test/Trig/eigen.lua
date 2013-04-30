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

-- functions to obtain eigen vectors for PCA
require("path")
local ffi = require("ffi")
__global = require("global")
local __global = __global -- local reference to global table
__global.loadFile = arg and arg[1] or __global.loadFile
collectgarbage("setpause", 100) -- force quicker garbage collection to prevent heaping up
math.randomseed(os.time())

local sdl = require("sdltools")
local dbg = require("dbgtools")

local ppm = require("ppmtools")
local img = require("imgtools")

require("mathtools")

local d = ppm.readIM("../Resources/Photos/img.ppm")
print(__global.loadFile)
local buf1 = ppm.toBuffer(d)
d = nil

local d = ppm.readIM("../Resources/Photos/Veerle.jpg")
print(__global.loadFile)
local buf2 = ppm.toBuffer(d)
d = nil

-- function computing the covariance matrix of an image
local function cov(im)
	local rr, rg, rb, gg, gb, bb -- same as input to eig
	= 0,0,0,0,0,0
	local rm, gm, bm = 0, 0, 0
	local s = im.x*im.y
	
	for x = 0, im.x-1 do
		for y = 0, im.y-1 do
			local r, g, b = im:get3(x, y)
			rm = rm + r
			gm = gm + g
			bm = bm + b
		end
	end
	
	rm = rm/s
	gm = gm/s
	bm = bm/s
	
	for x = 0, im.x-1 do
		for y = 0, im.y-1 do
			local r, g, b = im:get3(x, y)
			r = r-rm
			g = g-gm
			b = b-bm
			rr = rr+r*r
			rg = rg+r*g
			rb = rb+r*b
			gg = gg+g*g
			gb = gb+g*b
			bb = bb+b*b
		end
	end
	
	
	return {rr/s,rg/s,rb/s,gg/s,gb/s,bb/s}, {rm, gm, bm}
end

-- complex class [extract to module]
local complex = {}
complex.meta={__index = complex, __call=complex.new}

function complex:new(r, i)
	r = r or 0
	i = i or 0
	local o = {r=r, i=i}
	setmetatable(o, complex.meta)
	return o
end

function complex.meta.__tostring(a)
	return "( "..a.r..", "..a.i.." i )"
end

function complex.meta.__add(a, b)
	local o = complex:new()
	if type(a)~="table" then a = complex:new(a, 0) end
	if type(b)~="table" then b = complex:new(b, 0) end
	o.r = a.r+b.r
	o.i = a.i+b.i
	return o
end

function complex.meta.__sub(a, b)
	local o = complex:new()
	if type(a)~="table" then a = complex:new(a, 0) end
	if type(b)~="table" then b = complex:new(b, 0) end
	o.r = a.r-b.r
	o.i = a.i-b.i
	return o
end

function complex.meta.__mul(a, b)
	local o = complex:new()
	if type(a)~="table" then a = complex:new(a, 0) end
	if type(b)~="table" then b = complex:new(b, 0) end
	o.r = a.r*b.r - a.i*b.i 
	o.i = a.i*b.r + a.r*b.i
	return o
end

function complex.meta.__div(a, b)
	
	local o = complex:new()
	if type(a)~="table" then a = complex:new(a, 0) end
	if type(b)~="table" then b = complex:new(b, 0) end
	o.r = (a.r*b.r + a.i*b.i)/(b.r^2+b.i^2) 
	o.i = (a.i*b.r - a.r*b.i)/(b.r^2+b.i^2)
	--print("div:", a, b, "=>",o)
	return o
end

function complex.meta.__pow(a, b)
	local o = complex:new()
	local x, y = a.r, a.i
	
	if b==1 then return a
	elseif b==2 then
		o.r = x^2-y^2
		o.i = 2*x*y
	elseif b==3 then
		o.r = x^3-3*x*y^2
		o.i = 3*x^2*y-y^3
	elseif b==4 then
		o.r = x^4-6*x^2*y^2+y^4
		o.i = 4*x^3*y-4*x*y^3
	elseif b==5 then
		o.r = x^5-10*x^3*y^2+5*x*y^4
		o.i = 5*x^4*y-10*x^2*y^3+y^5
	else
		local abs = math.sqrt(a.r^2+a.i^2)^b
		local arg = math.atan2(a.i, a.r)*b
		o.r = abs*math.cos(arg)
		o.i = abs*math.sin(arg)
	end
	return o
end

function complex.meta.__unm(a) return complex:new(-a.r, -a.i) end
function complex:im() return self.i end
function complex:re() return self.r end

-- analytical solution to eigenvector decomposition for symmetrical 3x3 matrices
local function eig(M) --[a,b,c];[~,d,f];[~,~,g]
	local a, b, c, d, f, g = unpack(M)
	local sqrt = math.sqrt
	local zz = -a^2-3*b^2-3*c^2+a*d-d^2-3*f^2+a*g+d*g-g^2
	local yy = 2*a^3+9*a*b^2+9*a*c^2-3*a^2*d+9*b^2*d-18*c^2*d-3*a*d^2+2*d^3+54*b*c*f-18*a*f^2+9*d*f^2-3*a^2*g-18*b^2*g+9*c^2*g+12*a*d*g-3*d^2*g+9*f^2*g-3*a*g^2-3*d*g^2+2*g^3
	
	local xx
	if 4*zz^3+yy^2<0 then
		xx = complex:new(yy, sqrt(-(4*zz^3+yy^2)))
	else
		xx = yy+sqrt(4*zz^3+yy^2)
	end
	
	local i = complex:new(0,1)
	
	local x1 = 1/3*(a+d+g)-(2^(1/3)*zz)/(3*xx^(1/3))+xx^(1/3)/(3*2^(1/3))
	local x2 = 1/3*(a+d+g)+((1-i*sqrt(3))*zz)/(3*2^(2/3)*xx^(1/3))-((1+i*sqrt(3))*xx^(1/3))/(6*2^(1/3))
	local x3 = 1/3*(a+d+g)+((1+i*sqrt(3))*zz)/(3*2^(2/3)*xx^(1/3))-((1-i*sqrt(3))*xx^(1/3))/(6*2^(1/3))
	
	local e = {}
	
	e[1] = -(1/3*(-a-d-g)+g+(2^(1/3)*zz)/(3*xx^(1/3))-xx^(1/3)/(3*2^(1/3)))/c+(f*(-c*f+b*g-b*x1))/(c*(-c*d+b*f+c*x1))
	e[2] = -(-c*f+b*g-b*x1)/(-c*d+b*f+c*x1)
	e[3] = 1
	
	e[4] = -(1/3*(-a-d-g)+g-((1-i*sqrt(3))*zz)/(3*2^(2/3)*xx^(1/3))+((1+i*sqrt(3))*xx^(1/3))/(6*2^(1/3)))/c+(f*(-c*f+b*g-b*x2))/(c*(-c*d+b*f+c*x2))
	e[5] = -(-c*f+b*g-b*x2)/(-c*d+b*f+c*x2)
	e[6] = 1
	
	e[7] = -(1/3*(-a-d-g)+g-((1+i*sqrt(3))*zz)/(3*2^(2/3)*xx^(1/3))+((1-i*sqrt(3))*xx^(1/3))/(6*2^(1/3)))/c+(f*(-c*f+b*g-b*x3))/(c*(-c*d+b*f+c*x3))
	e[8] = -(-c*f+b*g-b*x3)/(-c*d+b*f+c*x3)
	e[9] = 1

	
	-- calculate normalization factors
	local n1 = (e[1]^2+e[2]^2+1)^(1/2)
	local n2 = (e[4]^2+e[5]^2+1)^(1/2)
	local n3 = (e[7]^2+e[8]^2+1)^(1/2)
	
	e[1], e[2], e[3] = e[1]/n1,e[2]/n1,e[3]/n1
	e[4], e[5], e[6] = e[4]/n2,e[5]/n2,e[6]/n2
	e[7], e[8], e[9] = e[7]/n3,e[8]/n3,e[9]/n3
	
	-- optional output
	print("["..e[1].r..", ".. e[2].r..", ".. e[3].r.."]")
	print("["..e[4].r..", ".. e[5].r..", ".. e[6].r.."]")
	print("["..e[7].r..", ".. e[8].r..", ".. e[9].r.."]")
	
	--print("eigenvalues:")
	print(x1.r)
	print(x2.r)
	print(x3.r)
	
	-- sorting
	
	--if 
	
	return {e[1].r,e[4].r,e[7].r,
			e[2].r,e[5].r,e[8].r,
			e[3].r,e[6].r,e[9].r},
			-- eigenvalues
			{x1.r, x2.r, x3.r}
end

--[[
a = 2366.6
b = 2802.5
c = 2995.9
d = 3873.7
f = 4474.9
g = 5473.6
--]]

local a,b,c = 2366.6, 2802.5, 2995.9
local _,d,f = 2802.5, 3873.7, 4474.9
local _,_,g = 2995.9, 4474.9, 5473.6

--eig(cov(buf1))
--eig(cov(buf2))

local function det2(a, b, c, d) return a*d-b*c end
local function det3(a1,a2,a3,b1,b2,b3,c1,c2,c3)
	return a1*b2*c3-a1*b3*c2-a2*b1*c3+a2*b3*c1+a3*b1*c2-a3*b2*c1
end

local function adj(a1,a2,a3,b1,b2,b3,c1,c2,c3)
	local o = {0, 0, 0, 0, 0, 0, 0, 0, 0}
	o[1]=det2(b2, b3, c2, c3)
	o[2]=det2(a3, a2, c3, c2)
	o[3]=det2(a2, a3, b2, b3)

	o[4]=det2(b3, b1, c3, c1)
	o[5]=det2(a1, a3, c1, c3)
	o[6]=det2(a3, a1, b3, b1)
	
	o[7]=det2(b1, b2, c1, c2)
	o[8]=det2(a2, a1, c2, c1)
	o[9]=det2(a1, a2, b1, b2)
	return o
end

local function inv(M)
	local o = adj(unpack(M))
	local f = 1/det3(unpack(M))

	for i=1,9 do
		o[i]=o[i]*f
	end
	return o
end

local function T(M)
	return {M[1], M[4], M[7],
			M[2], M[5], M[8],
			M[3], M[6], M[9],
		}
end

local function mult(V, M)
	return {
		M[1]*V[1] + M[4]*V[2] + M[7]*V[3],
		M[2]*V[1] + M[5]*V[2] + M[8]*V[3],
		M[3]*V[1] + M[6]*V[2] + M[9]*V[3],
	}
end

local function matMult(M, N)
	return {
		M[1]*N[1] + M[2]*N[4] + M[3]*N[7],
		M[1]*N[2] + M[2]*N[5] + M[3]*N[8],
		M[1]*N[3] + M[2]*N[6] + M[3]*N[9],

		M[4]*N[1] + M[5]*N[4] + M[6]*N[7],
		M[4]*N[2] + M[5]*N[5] + M[6]*N[8],
		M[4]*N[3] + M[5]*N[6] + M[6]*N[9],

		M[7]*N[1] + M[8]*N[4] + M[9]*N[7],
		M[7]*N[2] + M[8]*N[5] + M[9]*N[8],
		M[7]*N[3] + M[8]*N[6] + M[9]*N[9],
	}
end

-- not needed
local function aaT(m)
	return {m[1]^2+m[2]^2+m[3]^2,
			m[1]*m[2]+m[2]*m[4]+m[3]*m[5],
			m[1]*m[3]+m[2]*m[5]+m[3]*m[6],
			m[2]^2+m[4]^2+m[5]^2,
			m[2]*m[3]+m[4]*m[5]+m[5]*m[6],
			m[3]^2+m[5]^2+m[6]^2}
end

--local M = eig(cov(buf1))
--print(unpack(M))
--print(unpack(inv(M)))

--print(unpack(mult(M, {0,1,0})))

local function applyConversion(im1, im2)
	local M1, m1 = cov(im1)
	local M2, m2 = cov(im2)
	M1 = eig(M1) -- implement diagonal matMult
	M2 = eig(M2)
	local iM1, iM2 = inv(M1), inv(M2)
	-- local iM1 = inv(M1)
	-- inverse equals transpose for orthogonal matrix
	
	--print(unpack(ev))
	
	--for i = 1, 9, 3 do
	--	M1[i] = 0
	--end
	--m2[1]=0
	
	--for i = 2, 9, 3 do
	--	M1[i] = 0
	--end
	--m2[2]=0
	
	--for i = 3, 9, 3 do
	--	M1[i] = 0
	--end
	--m2[3]=0
	
	-- remove least significant component
	
	for x = 0, im1.x-1 do
		for y = 0, im1.y-1 do
			local r, g, b = im1:get3(x, y)
			r,g,b = unpack(mult({r-m1[1], g-m1[2], b-m1[3]}, M1))
			g = 0
			r,g,b = unpack(mult({r, g, b}, iM2))
			im1:set3(x,y,r+m2[1],g+m2[2],b+m2[3])
		end
	end
end

applyConversion(buf2, buf2)
print("done")

d = ppm.fromBuffer(buf2)
d.name = "eigen_out.png"
ppm.writeIM(d)
d = nil
