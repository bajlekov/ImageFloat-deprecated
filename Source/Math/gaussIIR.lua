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

--[[
	Implementation of a Deriche-style Gaussian IIR filter after
	Gunnar Farneback and Carl-Fredrik Westin "Improving Deriche-style Recursive
	Gaussian Filters", Journal of Mathematics in Imaging and Vision (2006)
--]]
local exp = math.exp
local function gauss(x, s) return exp(-(x)^2/2/s^2) end

local function gaussIIR(input, output, sigma, length, stride) -- add output, stride
	
	stride = stride or 1
	
	-- parameters obtained from fit of a gaussian
	local a1 = 1.6806376642357039319364
	local a2 = -0.6812660166381832027582
	local b1 = 3.7569701140397087080203
	local b2 = -0.2652902746940916656193
	local w1 = 0.6319997351950183972491/sigma
	local w2 = 1.9975150914645314337292/sigma
	local l1 = -1.7858991854622259243257/sigma
	local l2 = -1.7256466474863954019270/sigma
	
	local cw1 = math.cos(w1)
	local cw2 = math.cos(w2)
	local sw1 = math.sin(w1)
	local sw2 = math.sin(w2)
	
	local n3 = exp(l2+2*l1)*(b2*sw2-a2*cw2) + exp(l1+2*l2)*(b1*sw1-a1*cw1)
	local n2 = 2*exp(l1+l2)*((a1+a2)*cw2*cw1 - b1*cw2*sw1 - b2*cw1*sw2) + a2*exp(2*l1) + a1*exp(2*l2)
	local n1 = exp(l2)*(b2*sw2-(a2+2*a1)*cw2) + exp(l1)*(b1*sw1-(a1+2*a2)*cw1)
	local n0 = a1+a2
	local d4 = exp(2*l1+2*l2)
	local d3 = -2*exp(l1+2*l2)*cw1 - 2*exp(l2+2*l1)*cw2
	local d2 = 4*exp(l1+l2)*cw2*cw1 + exp(2*l2) + exp(2*l1)
	local d1 = -2*exp(l2)*cw2 - 2*exp(l1)*cw1
	local m1 = n1 - d1*n0
	local m2 = n2 - d2*n0
	local m3 = n3 - d3*n0
	local m4 =    - d4*n0
	
	local scale = 1/math.sqrt(2*math.pi)/sigma
	
	-- create continuously updating (rolling) state instead of a temporary (unless output is same as input)
	
	local aa0, aa1, aa2, aa3, aa4 = 0, 0, 0, 0, 0 -- delayed input values
	local ap0, ap1, ap2, ap3, ap4 = 0, 0, 0, 0, 0 -- delayed processed values
	local dd = input
	local oo = output
	
	--TODO: scaling issues at small sigma!
	local norm
	if sigma>15 then -- threshold for accurate scaling ??
		norm = 1/math.sqrt(2*math.pi)/sigma;
	else
		local sum = 0
		for i = 1,sigma*15 do
			sum = sum + gauss(i, sigma)
		end
		norm = 1/(sum*2+1)
	end
	
	-- clear output/ make sure output is clean
	
	for i = 0, length-1 do
		aa0 = dd[i*stride]								-- read input
		ap0 = n0*aa0 + n1*aa1 + n2*aa2 + n3*aa3 - d1*ap1 - d2*ap2 - d3*ap3 - d4*ap4
		oo[i*stride] = oo[i*stride] + ap0*norm			-- write/add to output
		aa1, aa2, aa3 = aa0, aa1, aa2			-- roll aa
		ap1, ap2, ap3, ap4 = ap0, ap1, ap2, ap3	-- roll ap
	end
	
	local aa0, aa1, aa2, aa3, aa4 = 0, 0, 0, 0, 0 -- delayed input values
	local ap0, ap1, ap2, ap3, ap4 = 0, 0, 0, 0, 0 -- delayed processed values
		
	for i = length-1, 0, -1 do
		aa0 = dd[i*stride]								-- read input
		ap0 = m1*aa1 + m2*aa2 + m3*aa3 +m4*aa4 - d1*ap1 - d2*ap2 - d3*ap3 - d4*ap4
		oo[i*stride] = oo[i*stride] + ap0*norm			-- write/add to output
		aa1, aa2, aa3, aa4 = aa0, aa1, aa2, aa3	-- roll aa
		ap1, ap2, ap3, ap4 = ap0, ap1, ap2, ap3	-- roll ap
	end
	
end

--test
--[[
local ffi = require("ffi")

local i = ffi.new("float[100]")
local o = ffi.new("float[100]")

i[50] = 1

gaussIIR(i, o, 100, 100,1)

local s = 0
for i = 0, 99 do
	print(i, o[i])
	s = s + o[i]
end
print(s)
--]]

return gaussIIR
