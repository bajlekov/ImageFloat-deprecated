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

-- function computing the covariance matrix of an image

-- missing

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
local function eig(a,b,c,d,f,g) --[a,b,c];[~,d,f];[~,~,g]
	jit.off()
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
	local x2 = 1/3*(a+d+g)+((1+i*sqrt(3))*zz)/(3*2^(2/3)*xx^(1/3))-((1-i*sqrt(3))*xx^(1/3))/(6*2^(1/3))
	local x3 = 1/3*(a+d+g)+((1-i*sqrt(3))*zz)/(3*2^(2/3)*xx^(1/3))-((1+i*sqrt(3))*xx^(1/3))/(6*2^(1/3))
	
	local e11 = -(1/3*(-a-d-g)+g+(2^(1/3)*zz)/(3*xx^(1/3))-xx^(1/3)/(3*2^(1/3)))/c+(f*(-c*f+b*g-b*x1))/(c*(-c*d+b*f+c*x1))
	local e12 = -(-c*f+b*g-b*x1)/(-c*d+b*f+c*x1)
	local e13 = 1
	
	local e21 = -(1/3*(-a-d-g)+g-((1+i*sqrt(3))*zz)/(3*2^(2/3)*xx^(1/3))+((1-i*sqrt(3))*xx^(1/3))/(6*2^(1/3)))/c+(f*(-c*f+b*g-b*x2))/(c*(-c*d+b*f+c*x2))
	local e22 = -(-c*f+b*g-b*x2)/(-c*d+b*f+c*x2)
	local e23 = 1

	local e31 = -(1/3*(-a-d-g)+g-((1-i*sqrt(3))*zz)/(3*2^(2/3)*xx^(1/3))+((1+i*sqrt(3))*xx^(1/3))/(6*2^(1/3)))/c+(f*(-c*f+b*g-b*x3))/(c*(-c*d+b*f+c*x3))
	local e32 = -(-c*f+b*g-b*x3)/(-c*d+b*f+c*x3)
	local e33 = 1
	
	-- calculate normalization factors
	local n1 = (e11^2+e12^2+1)^(1/2)
	local n2 = (e21^2+e22^2+1)^(1/2)
	local n3 = (e31^2+e32^2+1)^(1/2)
	
	e11, e12, e13 = e11/n1,e12/n1,e13/n1
	e21, e22, e23 = e21/n2,e22/n2,e23/n2
	e31, e32, e33 = e31/n3,e32/n3,e33/n3
	
	-- optional output
	print("["..e11.r..", ".. e12.r..", ".. e13.r.."]")
	print("["..e21.r..", ".. e22.r..", ".. e23.r.."]")
	print("["..e31.r..", ".. e32.r..", ".. e33.r.."]")
	
	print("eigenvalues:")
	print(x1.r)
	print(x2.r)
	print(x3.r)
	
	return {e11.r,e12.r,e13.r,
			e21.r,e22.r,e23.r,
			e31.r,e32.r,e33.r},
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

eig(1,3,3,4,5,6)

