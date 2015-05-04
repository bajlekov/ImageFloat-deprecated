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

local dbg = require("Tools.dbgtools")

local cs = {}
local ffi = require("ffi")

--RESTRUCTURE!

--[[
CS spaces:
ANY
ANYRGB
ANYLXX
ANYHUE

XYZ
SRGB
LRGB
HSV
HSL
LAB
LUV
LCHAB
LCHUV

MAP

hue ranges from 0:1
L ranges from 0:1
a, b, u, v range -128:128 is mapped to -1:1
--]]

-- linear <=> gamma-corrected
local LRGBtoSRGB
local SRGBtoLRGB
do
	--TODO: Rec1361 transform!
	--TODO: custom gamma and cutoff
	local GAMMA = {}
	GAMMA.adobe 	= {0.45,0}
	GAMMA.apple 	= {0.56,0}
	GAMMA.cie 		= {0.45,0}
	GAMMA.srgb 		= {0.42,0.055}
	GAMMA.hdtv 		= {0.45,0.099}
	GAMMA.wide 		= {0.45,0}

	local userGamma = "srgb"
	local a = GAMMA[userGamma][2]
	local G = 1/GAMMA[userGamma][1]


	local a_1 = 1/(1+a)
	local G_1 = 1/G

	local f = ((1+a)^G*(G-1)^(G-1))/(a^(G-1)*G^G)
	local k = a/(G-1)
	local k_f = k/f
	local f_1 = 1/f

	local function _LRGBtoSRGB(i)
		return i<=k_f and i*f or (a+1)*i^G_1-a
	end
	local function _SRGBtoLRGB(i)
		return i<=k and i*f_1 or ((i+a)*a_1)^G
	end

	SRGBtoLRGB = function(i1, i2, i3)
		return _SRGBtoLRGB(i1), _SRGBtoLRGB(i2), _SRGBtoLRGB(i3)
	end
	LRGBtoSRGB = function(i1, i2, i3)
		return _LRGBtoSRGB(i1), _LRGBtoSRGB(i2), _LRGBtoSRGB(i3)
	end
end

-- HSV/HSL <=> SRGB
local SRGBtoHSV
local HSVtoSRGB
local SRGBtoHSL
local HSLtoSRGB
local SRGBtoHSI
do	
	local max = math.max
	local min = math.min
	--local function luma(r, g, b) return 0.299 * i1 + 0.587 * i2 + 0.114 * i3 end --Rec601
	local function luma(r, g, b) return 0.2126 * i1 + 0.7152 * i2 + 0.0722 * i3 end --Rec709
	local function chroma(c1, c2, c3) return max(c1, c2, c3)-min(c1, c2, c3) end
	local function value(c1, c2, c3) return max(c1, c2, c3) end
	local function lightness(c1, c2, c3) return (max(c1, c2, c3) + min(c1, c2, c3)) / 2 end
	local function intensity(r, g, b) return (r + g + b) / 3 end
	local function satV(c1, c2, c3) return chroma(c1, c2, c3) / value(c1, c2, c3) end
	local function satL(c1, c2, c3) return chroma(c1, c2, c3) / (1 - math.abs(2 * lightness(c1, c2, c3) - 1)) end
	local function satI(c1, c2, c3) return 1 - min(c1, c2, c3) / intensity(c1, c2, c3) end
	local function hue(r, g, b)
		local c = chroma(r, g, b)
		if c==0 then return 0 end
		local hue
		local m = max(r, g, b)
		if m==r then hue = ((g - b) / c) end
		if m==g then hue = (2 + (b - r) / c) end
		if m==b then hue = (4 + (r - g) / c) end
		return hue<0 and hue/6+1 or hue/6
	end
	-- choice table constructors outside of main function
	local ones = {{1,0,0},{1,1,0},{0,1,0},{0,1,1},{0,0,1},{1,0,1}}
	local exes = {{0,1,0},{-1,0,0},{0,0,1},{0,-1,0},{1,0,0},{0,0,-1}}
	
	local function HtoRGB(h)
		h = h * 6
		local n = math.floor(h)
		local x = h - n
		n = n + 1
		if n==7 then n=1 x=0 end --for malformed rounding
		return ones[n][1] + exes[n][1] * x, ones[n][2] + exes[n][2] * x, ones[n][3] + exes[n][3] * x
	end
	function SRGBtoHSV(c1, c2, c3) return hue(c1, c2, c3), satV(c1, c2, c3), value(c1, c2, c3) end
	function SRGBtoHSL(c1, c2, c3) return hue(c1, c2, c3), satL(c1, c2, c3), lightness(c1, c2, c3) end
	function SRGBtoHSI(c1, c2, c3) return hue(c1, c2, c3), satI(c1, c2, c3), intensity(c1, c2, c3) end
	function HSVtoSRGB(i1, i2, i3)
		local o1, o2, o3 = HtoRGB(i1)
		local c = i3 * i2
		return (o1-1)*c+i3, (o2-1)*c+i3, (o3-1)*c+i3
	end
	function HSLtoSRGB(i1, i2, i3)
		local o1, o2, o3 = HtoRGB(i1)
		local c = (1 - math.abs(2 * i3 - 1)) * i2
		return (o1-0.5)*c+i3, (o2-0.5)*c+i3, (o3-0.5)*c+i3
	end
	global("HtoRGB", HtoRGB)
end

local WP = {
	A 		= {0.44757/0.40744, 1, 0.14499/0.40744},
	B 		= {0.34840/0.35160, 1, 0.30000/0.35160},
	C 		= {0.31006/0.31615, 1, 0.37379/0.31615},
	D50 	= {0.34567/0.35850, 1, 0.29583/0.35850},
	D55 	= {0.33242/0.34743, 1, 0.32015/0.34743},
	D65 	= {0.312727/0.329024, 1, 0.358250/0.329024},
	D75 	= {0.29902/0.31485, 1, 0.38613/0.31485},
	D93 	= {0.28480/0.29320, 1, 0.42200/0.29320},
	E 		= {1,1,1},
	F1 		= {0.31310/0.33727, 1, 0.34963/0.33727},
	F2 		= {0.37208/0.37529, 1, 0.25263/0.37529},
	F3 		= {0.40910/0.39430, 1, 0.19660/0.39430},
	F4 		= {0.44018/0.40329, 1, 0.15653/0.40329},
	F5 		= {0.31379/0.34531, 1, 0.34090/0.34531},
	F6 		= {0.37790/0.38835, 1, 0.23375/0.38835},
	F7 		= {0.31292/0.32933, 1, 0.35775/0.32933},
	F8 		= {0.34588/0.35875, 1, 0.29537/0.35875},
	F9 		= {0.37417/0.37281, 1, 0.25302/0.37281},
	F10 	= {0.34609/0.35986, 1, 0.29405/0.35986},
	F11 	= {0.38052/0.37713, 1, 0.24235/0.37713},
	F12 	= {0.43695/0.40441, 1, 0.15864/0.40441},
}
-- https://en.wikipedia.org/wiki/Standard_illuminant
local wp = WP.D65 -- D65 normalised to Y=1

--RGB to XYZ transforms calculated based on whitepoint and primaries!
-- RGB spaces:
local RGB = {}
RGB.srgb 		= {0.64, 0.33, 0.03, 0.30, 0.60, 0.10, 0.15, 0.06, 0.79, wp=WP.D65}
RGB.apple 		= {0.625, 0.34, 0.035, 0.28, 0.595, 0.125, 0.155, 0.07, 0.775, wp=WP.D65}
RGB.adobe 		= {0.64, 0.33, 0.03, 0.21, 0.71, 0.08, 0.15, 0.06, 0.79, wp=WP.D65}
RGB.cie 		= {0.7347, 0.2653, 0, 0.2738, 0.7174, 0.0088, 0.1666, 0.0089, 0.8245, wp=WP.E}
RGB.wide 		= {0.735, 0.265, 0, 0.115, 0.826, 0.059, 0.157, 0.018, 0.825, wp=WP.D50}
RGB.prophoto 	= {0.7347, 0.2653, 0, 0.1596, 0.8404, 0, 0.0366, 0.0001, 0.9633, wp=WP.D50}

--inverse transform
local mat = {}	-- matrix operations
local C			-- convert xyz to rgb
local CI		-- convert rgb to xyz
do
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

	local function mult(M, V)
		return {
			M[1]*V[1] + M[2]*V[2] + M[3]*V[3],
			M[4]*V[1] + M[5]*V[2] + M[6]*V[3],
			M[7]*V[1] + M[8]*V[2] + M[9]*V[3],
		}
	end

	local function div(M, N)
		local o = {}
		for k, v in ipairs(M) do
			o[k]=v/N
		end
		return o
	end

	local function T(M)
		return {M[1], M[4], M[7],
				M[2], M[5], M[8],
				M[3], M[6], M[9],
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

	local function diagMult(M, V)
		return {
				M[1]*V[1], M[2]*V[2], M[3]*V[3],
				M[4]*V[1], M[5]*V[2], M[6]*V[3],
				M[7]*V[1], M[8]*V[2], M[9]*V[3],
			}
	end

	--calculating XYZtoRGB matrices - move to own function
	--go back to non-normalised whitepoint
	local norm = 1/(wp[1]+wp[2]+wp[3])
	local W = {wp[1]*norm, wp[2]*norm, wp[3]*norm}
	local P = RGB.srgb

	P = T(P)
	local U = mult(inv(P),W)
	local D = div(U, W[2])
	C = diagMult(P,D)
	CI = inv(C)

	mat.mult = mult
	mat.matMult = matMult
	mat.diagMult = diagMult
	mat.div = div
	mat.T = T
	mat.inv = inv
end

local LRGBtoXYZ
local XYZtoLRGB

do
	function LRGBtoXYZ(r, g, b)
		return 	C[1]*r + C[2]*g + C[3]*b,
				C[4]*r + C[5]*g + C[6]*b,
				C[7]*r + C[8]*g + C[9]*b
	end

	function XYZtoLRGB(x, y, z)
		return 	CI[1]*x + CI[2]*y + CI[3]*z,
				CI[4]*x + CI[5]*y + CI[6]*z,
				CI[7]*x + CI[8]*y + CI[9]*z
	end
end

-- dcraw RAWtoXYZ using D65 illuminant --in 16bit int?
local RAW = {}
RAW["OLYMPUS E-620"] = 
	{ 8453,-2198,-1092,-7609,15681,2008,-1725,2337,7824, b=0, w=0xfaf}

local CCT
do
	local xe =	0.3366
	local ye =	0.1735
	local A0 =	-949.86315
	local A1 =	6253.80338
	local t1 =	0.92159
	local A2 =	28.70599
	local t2 =	0.20039
	local A3 =	0.00004 	
	local t3 =	0.07125

	function CCT(x,y) -- 3000K - 50000K
		local n = (x - xe)/(y - ye)
		return A0 + A1*math.exp(-n/t1) + A2*math.exp(-n/t2) + A3*math.exp(-n/t3)
	end
	-- use sampling at 1K to find matching temperature and green-balance
end

local TtoXY
local tanTtoXY
local norTtoXY
local TtoM
local MtoT
local dMatT
--local dTdMatT
do
	local a, b, c, d, e, f, g, h
	a = {-0.2661239e9,-3.0258469e9}
	b = {-0.2343580e6, 2.1070379e6} 
	c = { 0.8776956e3, 0.2226347e3}
	d = { 0.179910, 0.240390}
	e = {-1.1063814 ,-0.9549476 , 3.0817580 }
	f = {-1.34811020,-1.37418593,-5.87338670}
	g = { 2.18555832, 2.09137015, 3.75112997}
	h = {-0.20219683,-0.16748867,-0.37001483}
	function TtoXY(T) --Planck locus
		local xt, yt, i
		i = T<=4000 and 1 or 2
		xt = a[i]/T^3 + b[i]/T^2 + c[i]/T + d[i]
		i = T<=2222 and 1 or T<=4000 and 2 or 3
		yt = e[i]*xt^3 + f[i]*xt^2 + g[i]*xt + h[i]		
		return xt,yt
	end

	function tanTtoXY(T)
		local dxdt, dydx, xt, i
		i = T<=4000 and 1 or 2
		xt = a[i]/T^3 + b[i]/T^2 + c[i]/T + d[i]
		dxdt = -c[i]/T^2-2*b[i]/T^3-3*a[i]/T^4
		i = T<=2222 and 1 or T<=4000 and 2 or 3
		dydx = 3*e[i]*xt^2+2*f[i]*xt+g[i]
		return dxdt, dydx*dxdt
	end
	function norTtoXY(T)
		local xp, yp = tanTtoXY(T)
		return yp, -xp
	end
	-- tangential vector = (x', y')
	-- normal vecotr = (y', -x')
	local function TtoM(T) return 1000000/T end
	local function MtoT(M) return 1000000/M end
	local function dMatT(M,T) return MtoT(TtoM(T)+M) end --offset with M mired from T
	
	local function dTdMatT(T) return (MtoT(TtoM(T)+0.5)-MtoT(TtoM(T)-0.5)) end --get offset in K for 1 mired at T 
	global("dTdMatT", dTdMatT)
end
global("TtoXY", TtoXY)
global("tanTtoXY", tanTtoXY)
global("norTtoXY", norTtoXY)

local TtoXY_D
do
	local a, b, c, d, e, f, g
	a = { 0.145986 , 0.244063, 0.237040}
	b = { 1.17444e3,0.09911e3,0.24748e3}
	c = {-0.98598e6, 2.9678e6, 1.9018e6}
	d = { 0.27475e9,-4.6070e9,-2.0064e9}
	e =-3.000
	f = 2.870
	g =-0.275
	function TtoXY_D(T) --CIE Daylight locus
		local xd, yd
		local i = T<=4000 and 1 or T<=7000 and 2 or 3
		xd = a[i] + b[i]/T + c[i]/T^2 + d[i]/T^3
		yd = e*xd^2 + f*xd + g
		return xd, yd
	end
end

local function XYtoT(x,y)
	local xe = 0.3320
	local ye = 0.1858
	local n = (x - xe)/(y - ye)
	return -449*n^3 + 3525*n^2 - 6823.3*n + 5520.33
end

--nm to xy (from table)

--chromaticity coordinates
local function XYtoXYZ(x,y)
	local X, Z
	X = x * (1/y)
	Z = (1-x-y) * (1/y)
	return X, 1, Z
end
local function XYZtoXY(X,Y,Z)
	local x, y
	x = X/(X+Y+Z)
	y = Y/(X+Y+Z)
	return x, y
end
global("XYtoXYZ", XYtoXYZ)

--chromatic adaptation transforms
local CAT = {}
CAT.xyz 		= {1, 0, 0, 0, 1, 0, 0, 0, 1}
CAT.vonkries 	= {0.3897, 0.6890,-0.0787,-0.2298, 1.1834, 0.0464, 0.0000, 0.0000, 1.0000}
CAT.bradford 	= {0.8951, 0.2664,-0.1614,-0.7502, 1.7135, 0.0367, 0.0389,-0.0685, 1.0296}
CAT.cat97		= CAT.bradford
CAT.cat97s		= {0.8562, 0.3372,-0.1934,-0.8361, 1.8327, 0.0033, 0.0357,-0.0469, 1.0112}
CAT.cat2000 	= {0.7982, 0.3389,-0.1371,-0.5918, 1.5512, 0.0406, 0.0008, 0.2390, 0.9753}
CAT.cat02		= {0.7328, 0.4296,-0.1624,-0.7036, 1.6975, 0.0061, 0.0030, 0.0136, 0.9834}
CAT.sharp 		= {1.2694,-0.0988,-0.1706,-0.8364, 1.8006, 0.0357, 0.0297,-0.0315, 1.0018}
CAT.rlab 		= {0.4002, 0.7076,-0.0808,-0.2263, 1.1653, 0.0457, 0.0000, 0.0000, 0.9182}
CAT.bs 			= {0.8752, 0.2787,-0.1539,-0.8904, 1.8709, 0.0195,-0.0061, 0.0162, 0.9899}
CAT.bs_pc		= {0.6489, 0.3915,-0.0404,-0.3775, 1.3055, 0.0720,-0.0271, 0.0888, 0.9383}

--pick chromatic adaptation matrix
local cat = CAT.bradford
local catInv = mat.inv(cat)

--implement color correction: von kries transform with chosen matrix
local function vonKriesTransform(source, dest)
	if type(source)=="string" then source = WP[source] end
	if type(dest)=="string" then dest = WP[dest] end
	source = mat.mult(cat,source)
	dest = mat.mult(cat,dest)
	local sd = {dest[1]/source[1], dest[2]/source[2], dest[3]/source[3]}
	return mat.matMult(mat.diagMult(catInv,sd), cat)
end
global("vonKriesTransform", vonKriesTransform)

--[[ example transformation matrix to sRGB with D50 wp

local M = vonKriesTransform(WP.D50, WP.D65)
print(unpack(mat.matMult(CI,M)))

local M = vonKriesTransform(WP.D65, WP.D50)
print(unpack(mat.matMult(M,C)))

--]]

local XYZtoLAB
do
	local c1 = (6/29)^3
	local c2 = ((29/6)^2)/3
	local c3 = 4/29
	function XYZtoLAB(x, y, z)
		local x = x/wp[1]
		local y = y/wp[2]
		local z = z/wp[3]
		x = x>c1 and x^(1/3) or c2*x+c3
		y = y>c1 and y^(1/3) or c2*y+c3
		z = z>c1 and z^(1/3) or c2*z+c3
		local l, a, b = 116*y-16, 500*(x-y), 200*(y-z)
		return l/100, a/128, b/128 --normalise to ranges: (0;100), (-128;128)
	end
end
local LABtoXYZ
do
	local c1 = 6/29
	local c2 = 4/29
	local c3 = 3*(6/29)^2
	function LABtoXYZ(l, a, b)
		l, a, b = l*100, a*128, b*128
		local y = (l+16)/116
		local x = a/500+y
		local z = y-b/200
		x = x>c1 and x^3 or (x-c2)*c3
		y = y>c1 and y^3 or (y-c2)*c3
		z = z>c1 and z^3 or (z-c2)*c3
		return x*wp[1], y*wp[2], z*wp[3]
	end
end

local XYZtoLUV
local LUVtoXYZ
do
	local xr=wp[1]
	local yr=wp[2]
	local zr=wp[3]
	local e=(6/29)^3 -- 0.008856452
	local k=(29/3)^3 -- 903.296296296
	local k_1=1/k
	local un=(4*xr)/(xr+15*yr+3*zr) -- u'n
	local vn=(9*yr)/(xr+15*yr+3*zr) -- v'n
	function XYZtoLUV(x, y, z)
		local l, u, v
		local up=(4*x)/(x+15*y+3*z) -- u'
		local vp=(9*y)/(x+15*y+3*z) -- v'
		l = y>e and y^(1/3)*116-16 or y*k
		u = 13 * l * (up - un)
		v = 13 * l * (vp - vn)
		return l/100, u/128, v/128
	end
	function LUVtoXYZ(l, u, v)
		local x,y,z
		l, u, v = l*100, u*128, v*128
		y = l>8 and ((l+16)/116)^3 or l*k_1
		local up = u/(13*l)+un -- u'
		local vp = v/(13*l)+vn -- v'
		x = y*up*9/(4*vp)
		z = y*(12-3*up-20*vp)/(4*vp)
		return x, y, z
	end
end

local pi = math.pi
local pi_1 = 1/math.pi
local function LXXtoLCH(l, x, y)
	local c, h
	c = math.sqrt(x^2+y^2)
	h = math.atan2(y, x)
	return l, c, (h*pi_1+1)/2
end
local function LCHtoLXX(l, c, h)
	local x, y
	h = (h*2-1)*pi
	x = c*math.cos(h)
	y = c*math.sin(h)
	return l, x, y
end

if __global.setup.optCompile.ispc then
	function cs.gamma()
		local pow = __global.ISPC.ispc_pow
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			
			pow(b[1].data + x*s.ymax*s.zmax, p[1], b[2].data + x*s.ymax*s.zmax, s.ymax*s.zmax)
			
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
else
	function cs.gamma()
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			for y = 0, s.ymax-1 do
				s:up(x, y)
				
				local c1, c2, c3 = b[1]:get3()
				b[2]:set3(c1^p[1], c2^p[1], c3^p[1])
				
			end
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
end

--general CS convert in place constructor (only threaded)
function cs.constructor(fun)
	return function()
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			for y = 0, s.ymax-1 do
				s:up(x, y)
				b[2]:set3(fun(b[1]:get3()))
			end
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
end

--TODO: autogeneration of all from direct links
local function SRGBtoXYZ(c1, c2, c3) return LRGBtoXYZ(SRGBtoLRGB(c1, c2, c3)) end
local function LRGBtoHSV(c1, c2, c3) return SRGBtoHSV(LRGBtoSRGB(c1, c2, c3)) end
local function LRGBtoHSL(c1, c2, c3) return SRGBtoHSL(LRGBtoSRGB(c1, c2, c3)) end
local function XYZtoSRGB(c1, c2, c3) return LRGBtoSRGB(XYZtoLRGB(c1, c2, c3)) end
local function XYZtoHSV(c1, c2, c3) return SRGBtoHSV(LRGBtoSRGB(XYZtoLRGB(c1, c2, c3))) end
local function XYZtoHSL(c1, c2, c3) return SRGBtoHSL(LRGBtoSRGB(XYZtoLRGB(c1, c2, c3))) end
local function HSVtoLRGB(c1, c2, c3) return SRGBtoLRGB(HSVtoSRGB(c1, c2, c3)) end
local function HSVtoXYZ(c1, c2, c3) return LRGBtoXYZ(SRGBtoLRGB(HSVtoSRGB(c1, c2, c3))) end
local function HSVtoHSL(c1, c2, c3) return SRGBtoHSL(HSVtoSRGB(c1, c2, c3)) end
local function HSLtoLRGB(c1, c2, c3) return SRGBtoLRGB(HSLtoSRGB(c1, c2, c3)) end
local function HSLtoXYZ(c1, c2, c3) return LRGBtoXYZ(SRGBtoLRGB(HSLtoSRGB(c1, c2, c3))) end
local function HSLtoHSV(c1, c2, c3) return SRGBtoHSV(HSLtoSRGB(c1, c2, c3)) end
local function LCHABtoLAB(c1, c2, c3) return LCHtoLXX(c1, c2, c3) end
local function LABtoLCHAB(c1, c2, c3) return LXXtoLCH(c1, c2, c3) end
local function LCHUVtoLUV(c1, c2, c3) return LCHtoLXX(c1, c2, c3) end
local function LUVtoLCHUV(c1, c2, c3) return LXXtoLCH(c1, c2, c3) end
local function LCHABtoXYZ(c1, c2, c3) return LABtoXYZ(LCHtoLXX(c1, c2, c3)) end
local function XYZtoLCHAB(c1, c2, c3) return LXXtoLCH(XYZtoLAB(c1, c2, c3)) end
local function LCHUVtoXYZ(c1, c2, c3) return LUVtoXYZ(LCHtoLXX(c1, c2, c3)) end
local function XYZtoLCHUV(c1, c2, c3) return LXXtoLCH(XYZtoLUV(c1, c2, c3)) end

-- rest of the transforms through XYZ, autogenerated
local function LRGBtoLUV(c1, c2, c3) return XYZtoLUV(LRGBtoXYZ(c1, c2, c3)) end
local function LUVtoLRGB(c1, c2, c3) return XYZtoLRGB(LUVtoXYZ(c1, c2, c3)) end
local function LRGBtoLCHUV(c1, c2, c3) return XYZtoLCHUV(LRGBtoXYZ(c1, c2, c3)) end
local function LCHUVtoLRGB(c1, c2, c3) return XYZtoLRGB(LCHUVtoXYZ(c1, c2, c3)) end
local function SRGBtoLUV(c1, c2, c3) return XYZtoLUV(SRGBtoXYZ(c1, c2, c3)) end
local function LUVtoSRGB(c1, c2, c3) return XYZtoSRGB(LUVtoXYZ(c1, c2, c3)) end
local function SRGBtoLCHUV(c1, c2, c3) return XYZtoLCHUV(SRGBtoXYZ(c1, c2, c3)) end
local function LCHUVtoSRGB(c1, c2, c3) return XYZtoSRGB(LCHUVtoXYZ(c1, c2, c3)) end
local function HSVtoLUV(c1, c2, c3) return XYZtoLUV(HSVtoXYZ(c1, c2, c3)) end
local function LUVtoHSV(c1, c2, c3) return XYZtoHSV(LUVtoXYZ(c1, c2, c3)) end
local function HSVtoLCHUV(c1, c2, c3) return XYZtoLCHUV(HSVtoXYZ(c1, c2, c3)) end
local function LCHUVtoHSV(c1, c2, c3) return XYZtoHSV(LCHUVtoXYZ(c1, c2, c3)) end
local function HSLtoLUV(c1, c2, c3) return XYZtoLUV(HSLtoXYZ(c1, c2, c3)) end
local function LUVtoHSL(c1, c2, c3) return XYZtoHSL(LUVtoXYZ(c1, c2, c3)) end
local function HSLtoLCHUV(c1, c2, c3) return XYZtoLCHUV(HSLtoXYZ(c1, c2, c3)) end
local function LCHUVtoHSL(c1, c2, c3) return XYZtoHSL(LCHUVtoXYZ(c1, c2, c3)) end
local function LRGBtoLAB(c1, c2, c3) return XYZtoLAB(LRGBtoXYZ(c1, c2, c3)) end
local function LABtoLRGB(c1, c2, c3) return XYZtoLRGB(LABtoXYZ(c1, c2, c3)) end
local function LRGBtoLCHAB(c1, c2, c3) return XYZtoLCHAB(LRGBtoXYZ(c1, c2, c3)) end
local function LCHABtoLRGB(c1, c2, c3) return XYZtoLRGB(LCHABtoXYZ(c1, c2, c3)) end
local function SRGBtoLAB(c1, c2, c3) return XYZtoLAB(SRGBtoXYZ(c1, c2, c3)) end
local function LABtoSRGB(c1, c2, c3) return XYZtoSRGB(LABtoXYZ(c1, c2, c3)) end
local function SRGBtoLCHAB(c1, c2, c3) return XYZtoLCHAB(SRGBtoXYZ(c1, c2, c3)) end
local function LCHABtoSRGB(c1, c2, c3) return XYZtoSRGB(LCHABtoXYZ(c1, c2, c3)) end
local function HSVtoLAB(c1, c2, c3) return XYZtoLAB(HSVtoXYZ(c1, c2, c3)) end
local function LABtoHSV(c1, c2, c3) return XYZtoHSV(LABtoXYZ(c1, c2, c3)) end
local function HSVtoLCHAB(c1, c2, c3) return XYZtoLCHAB(HSVtoXYZ(c1, c2, c3)) end
local function LCHABtoHSV(c1, c2, c3) return XYZtoHSV(LCHABtoXYZ(c1, c2, c3)) end
local function HSLtoLAB(c1, c2, c3) return XYZtoLAB(HSLtoXYZ(c1, c2, c3)) end
local function LABtoHSL(c1, c2, c3) return XYZtoHSL(LABtoXYZ(c1, c2, c3)) end
local function HSLtoLCHAB(c1, c2, c3) return XYZtoLCHAB(HSLtoXYZ(c1, c2, c3)) end
local function LCHABtoHSL(c1, c2, c3) return XYZtoHSL(LCHABtoXYZ(c1, c2, c3)) end
local function LUVtoLAB(c1, c2, c3) return XYZtoLAB(LUVtoXYZ(c1, c2, c3)) end
local function LABtoLUV(c1, c2, c3) return XYZtoLUV(LABtoXYZ(c1, c2, c3)) end
local function LUVtoLCHAB(c1, c2, c3) return XYZtoLCHAB(LUVtoXYZ(c1, c2, c3)) end
local function LCHABtoLUV(c1, c2, c3) return XYZtoLUV(LCHABtoXYZ(c1, c2, c3)) end
local function LCHUVtoLAB(c1, c2, c3) return XYZtoLAB(LCHUVtoXYZ(c1, c2, c3)) end
local function LABtoLCHUV(c1, c2, c3) return XYZtoLCHUV(LABtoXYZ(c1, c2, c3)) end
local function LCHUVtoLCHAB(c1, c2, c3) return XYZtoLCHAB(LCHUVtoXYZ(c1, c2, c3)) end
local function LCHABtoLCHUV(c1, c2, c3) return XYZtoLCHUV(LCHABtoXYZ(c1, c2, c3)) end

global("HSVtoLRGB", HSVtoLRGB)
global("XYZtoLRGB", XYZtoLRGB)

cs.HSV = {}
cs.HSL = {}
cs.SRGB = {}
cs.LRGB = {}
cs.XYZ = {}
cs.LAB = {}
cs.LUV = {}
cs.LCHAB = {}
cs.LCHUV = {}

do
	local function pass(c1, c2, c3) return c1, c2, c3 end
	cs.LRGB.LRGB = cs.constructor(pass)
	cs.SRGB.SRGB = cs.constructor(pass)
	cs.HSV.HSV = cs.constructor(pass)
	cs.HSL.HSL = cs.constructor(pass)
	cs.XYZ.XYZ = cs.constructor(pass)
	cs.LAB.LAB = cs.constructor(pass)
	cs.LUV.LUV = cs.constructor(pass)
	cs.LCHAB.LCHAB = cs.constructor(pass)
	cs.LCHUV.LCHUV = cs.constructor(pass)
end

--autogenerated list of all possible CS transforms
cs.LRGB.SRGB = cs.constructor(LRGBtoSRGB)
cs.LRGB.HSV = cs.constructor(LRGBtoHSV)
cs.LRGB.HSL = cs.constructor(LRGBtoHSL)
cs.LRGB.XYZ = cs.constructor(LRGBtoXYZ)
cs.LRGB.LAB = cs.constructor(LRGBtoLAB)
cs.LRGB.LUV = cs.constructor(LRGBtoLUV)
cs.LRGB.LCHAB = cs.constructor(LRGBtoLCHAB)
cs.LRGB.LCHUV = cs.constructor(LRGBtoLCHUV)
cs.SRGB.LRGB = cs.constructor(SRGBtoLRGB)
cs.SRGB.HSV = cs.constructor(SRGBtoHSV)
cs.SRGB.HSL = cs.constructor(SRGBtoHSL)
cs.SRGB.XYZ = cs.constructor(SRGBtoXYZ)
cs.SRGB.LAB = cs.constructor(SRGBtoLAB)
cs.SRGB.LUV = cs.constructor(SRGBtoLUV)
cs.SRGB.LCHAB = cs.constructor(SRGBtoLCHAB)
cs.SRGB.LCHUV = cs.constructor(SRGBtoLCHUV)
cs.HSV.LRGB = cs.constructor(HSVtoLRGB)
cs.HSV.SRGB = cs.constructor(HSVtoSRGB)
cs.HSV.HSL = cs.constructor(HSVtoHSL)
cs.HSV.XYZ = cs.constructor(HSVtoXYZ)
cs.HSV.LAB = cs.constructor(HSVtoLAB)
cs.HSV.LUV = cs.constructor(HSVtoLUV)
cs.HSV.LCHAB = cs.constructor(HSVtoLCHAB)
cs.HSV.LCHUV = cs.constructor(HSVtoLCHUV)
cs.HSL.LRGB = cs.constructor(HSLtoLRGB)
cs.HSL.SRGB = cs.constructor(HSLtoSRGB)
cs.HSL.HSV = cs.constructor(HSLtoHSV)
cs.HSL.XYZ = cs.constructor(HSLtoXYZ)
cs.HSL.LAB = cs.constructor(HSLtoLAB)
cs.HSL.LUV = cs.constructor(HSLtoLUV)
cs.HSL.LCHAB = cs.constructor(HSLtoLCHAB)
cs.HSL.LCHUV = cs.constructor(HSLtoLCHUV)
cs.XYZ.LRGB = cs.constructor(XYZtoLRGB)
cs.XYZ.SRGB = cs.constructor(XYZtoSRGB)
cs.XYZ.HSV = cs.constructor(XYZtoHSV)
cs.XYZ.HSL = cs.constructor(XYZtoHSL)
cs.XYZ.LAB = cs.constructor(XYZtoLAB)
cs.XYZ.LUV = cs.constructor(XYZtoLUV)
cs.XYZ.LCHAB = cs.constructor(XYZtoLCHAB)
cs.XYZ.LCHUV = cs.constructor(XYZtoLCHUV)
cs.LAB.LRGB = cs.constructor(LABtoLRGB)
cs.LAB.SRGB = cs.constructor(LABtoSRGB)
cs.LAB.HSV = cs.constructor(LABtoHSV)
cs.LAB.HSL = cs.constructor(LABtoHSL)
cs.LAB.XYZ = cs.constructor(LABtoXYZ)
cs.LAB.LUV = cs.constructor(LABtoLUV)
cs.LAB.LCHAB = cs.constructor(LABtoLCHAB)
cs.LAB.LCHUV = cs.constructor(LABtoLCHUV)
cs.LUV.LRGB = cs.constructor(LUVtoLRGB)
cs.LUV.SRGB = cs.constructor(LUVtoSRGB)
cs.LUV.HSV = cs.constructor(LUVtoHSV)
cs.LUV.HSL = cs.constructor(LUVtoHSL)
cs.LUV.XYZ = cs.constructor(LUVtoXYZ)
cs.LUV.LAB = cs.constructor(LUVtoLAB)
cs.LUV.LCHAB = cs.constructor(LUVtoLCHAB)
cs.LUV.LCHUV = cs.constructor(LUVtoLCHUV)
cs.LCHAB.LRGB = cs.constructor(LCHABtoLRGB)
cs.LCHAB.SRGB = cs.constructor(LCHABtoSRGB)
cs.LCHAB.HSV = cs.constructor(LCHABtoHSV)
cs.LCHAB.HSL = cs.constructor(LCHABtoHSL)
cs.LCHAB.XYZ = cs.constructor(LCHABtoXYZ)
cs.LCHAB.LAB = cs.constructor(LCHABtoLAB)
cs.LCHAB.LUV = cs.constructor(LCHABtoLUV)
cs.LCHAB.LCHUV = cs.constructor(LCHABtoLCHUV)
cs.LCHUV.LRGB = cs.constructor(LCHUVtoLRGB)
cs.LCHUV.SRGB = cs.constructor(LCHUVtoSRGB)
cs.LCHUV.HSV = cs.constructor(LCHUVtoHSV)
cs.LCHUV.HSL = cs.constructor(LCHUVtoHSL)
cs.LCHUV.XYZ = cs.constructor(LCHUVtoXYZ)
cs.LCHUV.LAB = cs.constructor(LCHUVtoLAB)
cs.LCHUV.LUV = cs.constructor(LCHUVtoLUV)
cs.LCHUV.LCHAB = cs.constructor(LCHUVtoLCHAB)

--code constructors:
--[[
local t = {"LRGB", "SRGB", "HSV", "HSL", "XYZ", "LAB", "LUV", "LCHAB", "LCHUV"}
for _, i in ipairs(t) do
	for _, j in ipairs(t) do
		if i~= j then print("--cs."..i.."."..j.." = cs.constructor("..i.."to"..j..")") end
	end
end 
--]]
--[[
local t1 = {"LRGB", "SRGB", "HSV", "HSL"}
local t2 = {"LUV", "LCHUV"}
local t3 = {"LAB", "LCHAB"}
local tt = {{t1, t2}, {t1, t3}, {t2, t3}}
for _, t in ipairs(tt) do
	for _, i in ipairs(t[1]) do
		for _, j in ipairs(t[2]) do
			print("--local function "..i.."to"..j.."(c1, c2, c3) return XYZto"..j.."("..i.."toXYZ(c1, c2, c3)) end")
			print("--local function "..j.."to"..i.."(c1, c2, c3) return XYZto"..i.."("..j.."toXYZ(c1, c2, c3)) end")
		end
	end
end

--]]

if __global.setup.optCompile.ispc then
	function cs.LRGB.SRGB()
		local LtoG = __global.ISPC.ispc_LtoG
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			
			LtoG(b[1].data + x*s.ymax*s.zmax, b[2].data + x*s.ymax*s.zmax, s.ymax*s.zmax)
			
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
	function cs.SRGB.LRGB()
		local GtoL = __global.ISPC.ispc_GtoL
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			
			GtoL(b[1].data + x*s.ymax*s.zmax, b[2].data + x*s.ymax*s.zmax, s.ymax*s.zmax)
			
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
end


if __global.setup.optCompile.ispc then
	ffi.cdef[[
	void ispc_mat3mul(float* src, float* dst, float* mat, int size);
	void ispc_mat3mulLtoG(float* src, float* dst, float* mat, int size);
	void ispc_GtoLmat3mul(float* src, float* dst, float* mat, int size);
	]]
	function cs.LRGB.XYZ()
		local mul = __global.ISPC.ispc_mat3mul
		local mat = ffi.new("float[9]", C)
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		if s.zmax~=3 then print("ERROR: wrong dimensions!") end
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			
			mul(b[1].data + x*s.ymax*s.zmax, b[2].data + x*s.ymax*s.zmax, mat, s.ymax*s.zmax)
			
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
	function cs.XYZ.LRGB()
		local mul = __global.ISPC.ispc_mat3mul
		local mat = ffi.new("float[9]", CI)
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		if s.zmax~=3 then print("ERROR: wrong dimensions!") end
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			
			mul(b[1].data + x*s.ymax*s.zmax, b[2].data + x*s.ymax*s.zmax, mat, s.ymax*s.zmax)
			
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
	function cs.SRGB.XYZ()
		local mul = __global.ISPC.ispc_GtoLmat3mul
		local mat = ffi.new("float[9]", C)
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		if s.zmax~=3 then print("ERROR: wrong dimensions!") end
		
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			
			mul(b[1].data + x*s.ymax*s.zmax, b[2].data + x*s.ymax*s.zmax, mat, s.ymax*s.zmax)
			
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
	function cs.XYZ.SRGB()
		local mul = __global.ISPC.ispc_mat3mulLtoG
		local mat = ffi.new("float[9]", CI)
		local s = __global.state
		local b = __global.buf
		local p = __global.params
		local progress	= __global.progress
		local inst	= __global.instance
		local instmax	= __global.instmax
		
		if s.zmax~=3 then print("ERROR: wrong dimensions!") end
			
		for x = inst, s.xmax-1, instmax do
			if progress[instmax]==-1 then break end
			
			mul(b[1].data + x*s.ymax*s.zmax, b[2].data + x*s.ymax*s.zmax, mat, s.ymax*s.zmax)
			
			progress[inst] = x - inst
		end
		progress[inst] = -1
	end
end

return cs
