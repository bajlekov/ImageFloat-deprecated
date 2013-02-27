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

--test for accurate primitive drawing on canvas
package.path = 	"./?.lua;"..
"../Test/?.lua;"..package.path

local ffi = require("ffi")
local buffer = require("buffer")

local f = math.floor

local d = buffer:newM(32, 32)
d.i = function(self, x,y) return d.getM(self, f(x), f(y)) end
d.a = function(self, x,y,z) d.setM(self, f(x), f(y), z) end

local abs = math.abs
local floor = math.floor
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local tan = math.tan

local function lineAB(x1, y1, x2, y2)
	-- form: a*x + b
	local a = (y2-y1)/(x2-x1)
	local b = y1-x1*a
	return a, b
end

local function pointUp(a,b,x,y)
	local ly = a*x+b
	return y>ly and true or flase
end

local subRes = 16

local function drawLineSub(x1, y1, x2, y2, w)
	-- assume line is pointing to north-east, x2>x1, y2>y1: /
	-- get tangent and normal
	local tX, tY = x2-x1, y2-y1
	local l = sqrt(tX^2+tY^2)
	tX, tY = tX/l, tY/l
	local nX, nY = -tY, tX
	-- get 4 points
	local aX, bX, cX, dX = x1-w*tX+w*nX, x1-w*tX-w*nX, x2+w*tX-w*nX, x2+w*tX+w*nX  
	local aY, bY, cY, dY = y1-w*tY+w*nY, y1-w*tY-w*nY, y2+w*tY-w*nY, y2+w*tY+w*nY
	local aA, aB = lineAB(aX, aY, bX, bY)
	local bA, bB = lineAB(bX, bY, cX, cY)
	local cA, cB = lineAB(cX, cY, dX, dY)
	local dA, dB = lineAB(dX, dY, aX, aY)
	
	local xmin, xmax = math.min(x1, x2)-w-2, math.max(x1, x2)+w+2 
	local ymin, ymax = math.min(y1, y2)-w-2, math.max(y1, y2)+w+2
	
	for x = xmin, xmax, 1/subRes do
		for y = ymin, ymax, 1/subRes do
			if	pointUp(aA, aB, x, y) and
				(not pointUp(dA, dB, x, y)) and
				(not pointUp(cA, cB, x, y)) and
				pointUp(bA, bB, x, y)
			then d:a(x+0.5,y+0.5,d:i(x+0.5,y+0.5)+1/(subRes*subRes)) end
		end
	end
end

-- sampling works, but is too slow/inaccurate
--	.filter only relevant pixels for smoothing
--		.maximal smoothing width is 2 pixel depending on line orientation
--	.fill inside pixels
--		.upper bound below top lines
--		.lower bound above bottom lines
--	.skip outside pixels
--	.simplify by measuring distance to line?
--		.handle corner cases
--[[
	For all: first calculate the weight, then apply. image buffers don't have the precision for multiple add/multiply's
	- single thickness line drawing:
		- [check] shade all pixels through which the line passes
		- [check] shade either top or bottom adjecent pixels dependent on direction
		
		- for horizontal line: (fix for vertical width of slanted line!!!)
			- check level at left boundary of pixel column
			- check level at right boundary of pixel column
			- determine which pixels are affected:
				- pixels in which boundaries fall
				- pixel above if any boundary in upper half
				- pixel below if any boundary in lower half
				- if both below and above then split pixel at mid-line crossing
			- when moving to next column simply increment crossing (inaccurate) or calculate from equation
			- for filled structure fill an additional inside point
		- corners/junctions (sharp):
			- extend outer edges till crossing at outer vertex
			- geometric calculation, prevents overlap between edges
				- scan from top line to bottom line
				- split pixels at edges or crossings
			- extent of affected pixels can reach much further than corner
				- calculate outside lines to determine outside bound
				- calculate inside lines crossing for inner bound
				- perform geometric calculations between these bounds 
		- circle approximation for rounded edges
			- semi-circle with radius w capping the ends at exact segment length
			- integrating over circle segments?? worth the trouble?
			- circles are not a priority, implement fast integration
		- bevel approximation for joints
			- straight line capping the outer vertices at exact segment length
			- inner vertex remains a point
	- drawing line segments:
		- pass width, start-, end vertices, inner bound verts, outer bound verts
	- different fill and stroke colors!!
--]]

-- determine pixel fill based on entry points of a straight line
-- nil/false for no crossing
local function pFill(a, b, c, d)
	--		+ > C -+
	--		|      |
	--		A      B
	--		^      ^
	--		+ > D -+		
	if 			a and b then	return (a+b)/2
	elseif		a and c then	return 1-(1-a)*c/2
	elseif		a and d then	return a*d/2
	elseif		b and c then	return 1-(1-b)*(1-c)/2
	elseif		b and d then	return b*(1-d)/2
	elseif		c and d then	return 1-(c+d)/2
	else 						return false end 	
end

local function discard(a, b, c)
	local A, B, C = abs(0.5-a), abs(0.5-b), abs(0.5-c)
	local M = math.max(A, B, C)
	
	if M==A then return nil, b, c
	elseif M==B then return a, nil, c
	elseif M==C then return a, b, nil
	else print("error!!") end
end

local eps = 0.0001
--check intersection of pixel bounds and line
local function pCheck(a, b, x, y)
	local A, B, C, D = nil, nil, nil, nil
	
	--skip if outside of range
	if		a>0 and y+1<a*(x)+b then	return 1
	elseif	a<0 and y+1<a*(x+1)+b then	return 1
	elseif	a>0 and y>a*(x+1)+b then	return 0
	elseif	a<0 and y>a*(x)+b then		return 0
	end
	
	A = a*x+b - y
	B = a*(x+1)+b - y
	C = (y+1-b)/a - x
	D = (y-b)/a - x
	
	-- FIXME: design better way to deal with such inaccuracies
	-- include edge cases due to inaccuracy
	if A<-eps or A>1+eps then A=nil end
	if B<-eps or B>1+eps then B=nil end
	if C<-eps or C>1+eps then C=nil end
	if D<-eps or D>1+eps then D=nil end
	
	-- discard most deviant edge case 
	if A and B and C then A, B, C = discard(A, B, C)
	elseif A and B and D then A, B, D = discard(A, B, D)
	elseif A and C and D then A, C, D = discard(A, C, D)
	elseif B and C and D then B, C, D = discard(B, C, D)
	end
	
	-- debug checks
	--p = (A and 1 or 0) + (B and 1 or 0) + (C and 1 or 0) + (D and 1 or 0)
	--if p~=2 then print(A,B,C,D) end
	
	--local f = pFill(A,B,C,D)
	--assert(f, tostring(f))
	return pFill(A,B,C,D)
end


-- draw infinite line
local function infLine(a, b)
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			d:a(x,y, pCheck(a,b,x,y) - pCheck(a-0.6,b-4,x,y))
		end
	end
end

local t = os.clock()
for i = 1, 100000 do
infLine(1.3,-2.4)
end
print(os.clock()-t, "seconds\n")
-- processes ~30Mpix/sec, mostly memory access
-- improve by only drawing relevant parts, fast filling rest

-- print output in matlab matrix form
---[[
print("x=[")
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		io.write(d:i(x,y), " ")
		--print(d:i(x,y), " ")
	end
	io.write(";\n")
end
print("]")
--]]