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

--Spline editor

Implement:
	- Hermite/Bezier spline
	- Quadratic Bezier for 3-point interpolation without tangents - basic curve
	- Linear interpolation
	- Catmull Rom & Cardinal tangent approximation -> cardinal is suboptimal in 1D
	- Finite differences tangent approximation
	- Custom slope handling?

Practical options:
	- Auto -> CatmullRom / Finite / Cage / own approximation/clamp peaks?
	- Aligned -> Hermite/Bezier with aligned handles / Cage with shiftable nodes
	- Free -> Hermite/Bezier with free tangents on both sides

Endpoint handling:
	- Free (own angle/0/1)
	- Clamped (constant value)
	- Linear extension
	- Periodic

Structure:
	- Create table containing all data:
		- input data
		- segment data
		- compute function
		- getValue function

Splitting curves:
	- Bezier curves: add point at any position x
		without disrupting curve flow

Different endpoint tangent:
	linear tangents cause problem with tangent on non-edge point:
		choose quadratic formula instead, based on two points and one tangent:
		y1' = 2y2 + 2y1 - y2'

Derive all functions for interval 0-1

optimal tangent at midpoint (x):
(2*x^3*y3-(3*x-1)*y2-(2*x^3-3*x+1)*y1)/(2*x^3-3*x^2+x)+(3*x^3*(x*y3-y2-(x-1)*y1))/(2*x^3-3*x^2+x)+(2*x*(-3*x*y3+3*y2+(3*x-3)*y1))/(2*x^2-3*x+1)
--]]

local function addPoint(self,x,y, dyL, dyR)
	if #self.data==0 then
		table.insert(self.data, {x=x, y=y, dyL=dyL, dyR=dyR})
	else
		local n
		for k, v in ipairs(self.data) do
			if v.x>x then n = k break end
		end
		n = n or #self.data+1
		table.insert(self.data, n, {x=x, y=y, dyL=dyL, dyR=dyR})
	end
end

local function removePoint(self, n)
	table.remove(self.data, n)
end

local function calcSegment(y1, dy1, y2, dy2)
	local a = y1
	local b = dy1
	local c = -3*y1 - 2*dy1 + 3*y2 - dy2
	local d = 2*y1 + dy1 - 2*y2 + dy2
	return {a, b, c, d}
end
local function calcSpline(self, splineType)
	local d = self.data
	splineType = splineType or "Smooth"
	for i = 1, #self.data-1 do
		local dy1, dy2 = 0, 0

		--bezier: same as hermite, only with differently defined tangents

		-- Catmull Rom derivative approximation
		if self.splineType=="CatmullRom" then
			if i~=1 then
				dy1 = (d[i+1].y-d[i-1].y)/(d[i+1].x-d[i-1].x)
			end
			if i~=#self.data-1 then
				dy2 = (d[i+2].y-d[i].y)/(d[i+2].x-d[i].x)
			end
		end

		-- FD derivative approx
		if self.splineType=="Finite" then
			if i~=1 then
				dy1 = ((d[i].y-d[i-1].y)/(d[i].x-d[i-1].x) +
						(d[i+1].y-d[i].y)/(d[i+1].x-d[i].x)) / 2
			end
			if i~=#self.data-1 then
				dy2 = ((d[i+1].y-d[i].y)/(d[i+1].x-d[i].x) +
						(d[i+2].y-d[i+1].y)/(d[i+2].x-d[i+1].x)) / 2
			end
		end

		if self.splineType=="Smooth" then
			if i~=1 then
				dy1 = ((d[i].y-d[i-1].y)/(d[i].x-d[i-1].x)*(d[i+1].x-d[i].x) +
						(d[i+1].y-d[i].y)/(d[i+1].x-d[i].x)*(d[i].x-d[i-1].x))/
						(d[i+1].x-d[i-1].x)
			end
			if i~=#self.data-1 then
				dy2 = ((d[i+1].y-d[i].y)/(d[i+1].x-d[i].x)*(d[i+2].x-d[i+1].x) +
						(d[i+2].y-d[i+1].y)/(d[i+2].x-d[i+1].x)*(d[i+1].x-d[i].x)) /
						(d[i+2].x-d[i].x)
			end
		end

		if self.splineClamp then
			if i>1 and
				((d[i].y>d[i-1].y and d[i].y>d[i+1].y) or
				(d[i].y<d[i-1].y and d[i].y<d[i+1].y))
				then dy1=0 end
			if i<#self.data-1 and
				((d[i+1].y>d[i].y and d[i+1].y>d[i+2].y) or
				(d[i+1].y<d[i].y and d[i+1].y<d[i+2].y))
				then dy2=0 end
		end

		if self.splineType=="Bezier" then
			dy1 = d[i].dyR
			dy2 = d[i+1].dyL
			print(dy1, dy2)
			if dy1==nil then
				print("Warning, missing dy/dx !")
				dy1=0
			end
			if dy2==nil then
				print("Warning, missing dy/dx !")
				dy2=0
			end
		end

		--correct for non-unit intervals
		dy1 = dy1*(d[i+1].x-d[i].x)
		dy2 = dy2*(d[i+1].x-d[i].x)
		

		--square interpolation on ends:
		---[[
		if self.endType=="Quadratic" then
			if i==1 then
				dy1 = 2*d[2].y-2*d[1].y-dy2
			end

			if i==#self.data-1 then
				dy2 = 2*d[i+1].y-2*d[i].y-dy1
			end
		elseif self.endType=="Linear" then
			if i==1 then
				dy1 = d[2].y-d[1].y
			end
			if i==#self.data-1 then
				dy2 = d[i+1].y-d[i].y
			end
		elseif self.endType=="Smooth" then
			if i==1 then
				--dy1 = d[2].y-d[1].y
				--dy1 = (4*d[2].y - 4*d[1].y - dy2)/3
				dy1 = (3*d[2].y - 3*d[1].y - dy2)/2
			end
			if i==#self.data-1 then
				--dy2 = d[i+1].y-d[i].y
				--dy2 = 4*d[#self.data].y - 4*d[#self.data-1].y - 3*dy1
				dy2 = (3*d[#self.data].y - 3*d[#self.data-1].y - dy1)/2
			end
		end
		--]]

		if i==1 then self.segments.dyBegin = -dy1/(d[2].x-d[1].x) end
		if i==#self.data-1 then self.segments.dyEnd = dy2/(d[#self.data].x-d[#self.data-1].x) end

		self.segments[i] = calcSegment(d[i].y, dy1, d[i+1].y, dy2)
		self.segments[i].x = d[i].x
	end
	self.segments.xEnd=self.data[#self.data].x
end

local function getValue(self,x)
	if self.extend=="Clamp" then
		if x<=self.data[1].x then return self.data[1].y end
		if x>=self.data[#self.data].x then return self.data[#self.data].y end
	end
	if self.extend=="Linear" then
		if x<=self.data[1].x then return self.data[1].y + (self.data[1].x-x)*self.segments.dyBegin end
		if x>=self.data[#self.data].x then return self.data[#self.data].y + (x-self.data[#self.data].x)*self.segments.dyEnd end
	end
	local n
	for k, v in ipairs(self.data) do
		if v.x>x then n = k-1 break end
	end
	x = (x-self.data[n].x)/(self.data[n+1].x-self.data[n].x)
	local o = self.segments[n]
	return o[1]+o[2]*x+o[3]*x^2+o[4]*x^3
end

local function printPoints(self)
	print("Points:")
	for k, v in ipairs(self.data) do
		print(v.x, v.y)
	end
	print("Segments:")
	for k, v in ipairs(self.segments) do
		print(v[1], v[2], v[3], v[4])
	end
	print("")
end

local function newSpline()
	local o = {}
		o.data = {}
		o.segments = {}
		o.add = addPoint
		o.remove = removePoint
		o.compute = calcSpline
		o.get = getValue
		o.print = printPoints
		o.splineType = "Custom" 	-- {Finite(Auto), CatmullRom(Auto), Bezier, Cage, Smooth}
		o.splineTangent = "Auto" 		-- {Auto, Aligned, Free}
		o.extend = "Linear"				-- {Free, Clamp, Linear(Auto), Periodic, Zero, Continuous(same as periodic, but with an offset to match start/end points)}
		o.endType = "Quadratic"			-- {Linear, Quadratic, Free, Periodic, Continuous}
		o.splineClamp = false			-- force local maxima to have a 0 tangent
	return o
end

local function toSpline(cage)
	local s=newSpline()
	s.splineType = "Bezier"
	s.endType = "Smooth"
	local n = #cage

	local function deriv(n)
		return (cage[n+1][2]-cage[n][2])/(cage[n+1][1]-cage[n][1])
	end
	local function meanX(n)
		return (cage[n][1]+cage[n+1][1])/2
	end
	local function meanY(n)
		return (cage[n][2]+cage[n+1][2])/2
	end

	s:add(cage[1][1], cage[1][2], deriv(1), deriv(1))
	print(deriv(1))
	for i = 2, n-2 do
		s:add(meanX(i), meanY(i), deriv(i), deriv(i))
	end
	s:add(cage[n][1], cage[n][2], deriv(n-1), deriv(n-1))	
	return s
end


--[[
local s = newSpline()

s:add(1,1)
s:add(1.5,1.2)
s:add(3,4)
s:add(4,4)
s:add(5.5,6)
s:add(6,6)
--]]

local s = toSpline({
	{1,1},
	{1.5,1},
	{1.6,1.2},
	{2,3},
	{3,5},
	{4,4.7},
	{5,5},
	{6,6},
})

local ffi = require("ffi")
local sdl = require("Include.sdltools")

sdl.init()
sdl.setScreen(820, 820, 32)
sdl.caption("Test UI", "Test UI");
require("Draw.draw")
require("Math.mathtools")

---[[
--s.splineType = "Smooth"
--s.endType = "Smooth"
s:compute()
for x=0,500 do
	setPixel(x+100, 800-math.floor(s:get(x/80)*100), 255, 0, 0)
end
--]]

---[[
--s.splineType = "Finite"
--s.endType = "Quadratic"
s:compute()
for x=0,500 do
	--setPixel(x+100, 800-math.floor(s:get(x/80)*100), 0, 255, 0)
end
--]]

---[[
--s.splineType = "CatmullRom"
--s.endType = "Linear"
s:compute()
for x=0,500 do
	--setPixel(x+100, 800-math.floor(s:get(x/80)*100), 64, 128, 255)
end
--]]

for k, v in ipairs(s.data) do
	setPixel(v.x*80+100, 800-v.y*100, 255, 255, 255)
	setPixel(v.x*80+100+1, 800-v.y*100, 255, 255, 255)
	setPixel(v.x*80+100-1, 800-v.y*100, 255, 255, 255)
	setPixel(v.x*80+100, 800-v.y*100+1, 255, 255, 255)
	setPixel(v.x*80+100, 800-v.y*100-1, 255, 255, 255)
end


sdl.flip()
sdl.wait(2000)

sdl.quit()