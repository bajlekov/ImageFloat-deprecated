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

local ffi = require("ffi")

ffi.cdef[[
double erf(double i);
]]

local M_1_PI=0.31830988618379067154
local pi = math.pi
local cos = math.cos
local sin = math.sin
local exp = math.exp
local sqrt = math.sqrt
local abs = math.abs
local atan2 = math.atan2

math.func = {}
math.window = {}


function math.func.erf(i) return ffi.C.erf(i) end
function math.func.gauss(x, s) return exp(-(x)^2/2/s^2) end
function math.func.lorenz(x, s) return s^2/(x^2+s^2) end 
function math.func.gausscum(x, s) return 0.5 + erf((x)/sqrt(2)/s)/2 end
function math.func.lorenzcum(x, s) return atan2(x,s)*M_1_PI+0.5 end
function math.func.sinc(x) return x==0 and 1 or sin(pi*x)/(pi*x) end
function math.func.exp(x, t) return exp(-x/t) end

function math.window.nearest(x) return abs(x)<0.5 and 1 or 0 end
function math.window.linear(x) x = abs(x) return x<=1 and 1-x or 0 end
function math.window.welch(x) return abs(x)<1 and 1-x^2 or 0 end
function math.window.parzen(x)
	x = abs(x)
	return
	x<=1 and (4-6*x^2+3*x^3)/4
	or x<=2 and ((2-x)^3)/4
	or 0
end

--cosine lobe
function math.window.hann(x, a)
	-- a=0.5: Hann window
	-- a=0.54: Hamming window
	a = a or 0.5
	return
		abs(x)<=1 and a+(1-a)*cos(pi*x)
		or 0
end

--function math.window.bartlettHann()

do
	local t = {
		hann = {1/2, 1/2},
		hamming = {25/46, 21/46},
		blackman = {0.42, 0.5, 0.08},
		blackmanExact = {7938/18608, 9240/18608, 1430/18608},
		blackmanHarris3 = {0.4243801, 0.4973406, 0.0782793},
		blackmanHarris4 = {0.35875, 0.48829, 0.14128, 0.01168},
		--blackmanHarris4 = {0.40217, 0.49703, 0.09392, 0.00183},
		--blackmanHarris3 = {0.42323, 0.49755, 0.07922},
		--blackmanHarris3 = {0.422323, 0.49755, 0.07922},
		--blackmanHarris3 = {0.44959, 0.49364, 0.05677},
		blackmanHarris7 = {0.27105140069342, 0.43329793923448, 0.21812299954311, 0.06592544638803,
							0.01081174209837, 0.00077658482522, 0.00001388721735},
		flattop = {0.21557895, 0.41663158, 0.277263158, 0.083578947, 0.006947368},
		blackmanNuttal = {0.3635819, 0.4891775, 0.1365995, 0.0106411},
		nuttal = {0.355768, 0.487396, 0.144232, 0.012604},
		kaiser = {0.402, 0.498, 0.098, 0.001}, --approx
		lowSide = {0.323215218, 0.471492057, 0.175534280, 0.028497078, 0.001261367},
	}
	local  a0, a1, a2, a3, a4, a5, a6, an
	function math.window.blackmanSet(b0, b1, b2, b3, b4, b5, b6)
		if type(b0)=="string" then
			a0, a1, a2, a3, a4, a5, a6 = t[b0][1], t[b0][2], t[b0][3], t[b0][4], t[b0][5], t[b0][6], t[b0][7]
		elseif b0==nil then
			a0, a1, a2, a3, a4, a5, a6 = t[blackman][1], t[blackman][2], t[blackman][3], t[blackman][4], t[blackman][5], t[blackman][6], t[blackman][7]
		else
			a0, a1, a2, a3, a4, a5, a6 = b0, b1, b2, b3, b4, b5, b6
		end
		a2 = a2 or 0
		a3 = a3 or 0
		a4 = a4 or 0
		a5 = a5 or 0
		a6 = a6 or 0
		an = a0+a1+a2+a3+a4+a5+a6
	end
	function math.window.blackman(x)
		-- 7-term generic blackman-harris: suboptimal performance?
		return
			x<=1 and (a0 +
				(a1~=0 and a1*cos(pi*x) or 0) +
				(a2~=0 and a2*cos(2*pi*x) or 0) +
				(a3~=0 and a3*cos(3*pi*x) or 0) +
				(a4~=0 and a4*cos(4*pi*x) or 0) +
				(a5~=0 and a5*cos(5*pi*x) or 0) +
				(a6~=0 and a6*cos(6*pi*x) or 0))/an
			or 0
	end
end

function math.window.bohman(x)
	x = abs(x)
	return x<=1 and (1-x)*cos(pi*x)+1/pi*sin(pi*x) or 0
end
function math.window.tukey(x, a)
	x = abs(x)
	return
		x<=a and 1
		or x<=1 and 0.5+0.5*cos(pi/(1-a)*(x-a))
		or 0
end
function math.window.cosPower(x, a)
	return
		x<=1 and cos(pi*x*0.5)^a
		or 0
end
function math.window.cosine(x) return abs(x)<=1 and cos(pi*x/2) end
function math.window.lanczos(x, n)
	n = n or 1
	return abs(x)<=n and math.func.sinc(x)*math.func.sinc(x/n) or 0
end
do
	local t = {
		BSpline = {1, 0}, --order 3
		CatmullRom = {0, 1/2},
		MitchellNetravali = {1/3, 1/3},
		Cardinal = {0, 0},
	}
	local b, c
	function math.window.cubicSet(bn, cn)
		if type(bn)=="string" then
			b, c = t[bn][1], t[bn][2]
		else
			b, c = bn, cn
		end
	end
	function math.window.cubic(x)
		x = abs(x)
		return
			x<=1 and ((12-9*b-6*c)*x^3+(-18+12*b+6*c)*x^2+6-2*b)/
				(6-2*b)
			or x<=2 and ((-b-6*c)*x^3+(6*b+30*c)*x^2+(-12*b-48*c)*x+8*b+24*c)/
				(6-2*b)
			or 0
	end
end

--bartlettHann
--hannPoisson

local function I0(x)
	return 1 + x^2/4 + x^4/64 + x^6/2304 + x^8/147456 + x^10/14745600 +
		x^12/2123366400 + x^14/416179814400 + x^16/106542032486400 +
		x^18/34519618525593600 + x^20/13807847410237440000
end

function math.window.kaiser(x, a)
	a = a or 3
	x = abs(x)
	return
		x<=1 and I0(pi*a*sqrt(1-x^2))/
			I0(pi*a)
		or 0
end