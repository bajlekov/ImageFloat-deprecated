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

local d = buffer:newM(16, 16)
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

drawLineSub(5.2,3, 11,4, 3)
-- sampling works, but is too slow
--	.filter only relevant pixels for smoothing
--		.maximal smoothing width is 2 pixel depending on line orientation
--	.fill inside pixels
--		.upper bound below top lines
--		.lower bound above bottom lines
--	.skip outside pixels
--	.simplify by measuring distance to line?
--		.handle corner cases

print("x=[")
for x = 0, d.x-1 do
	for y = 0, d.y-1 do
		io.write(d:i(x,y), " ")
		--print(d:i(x,y), " ")
	end
	io.write(";\n")
end
print("]")