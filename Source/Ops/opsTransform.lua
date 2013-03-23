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
local transform = {}

--transforms should be implemented as inverse operations performed on the output pixels!!

require("mathtools")

--prerequisites
local pi = math.pi
local cos, sin = math.cos, math.sin
local floor = math.floor
local function rad2deg(a) return a/pi*180 end
local function deg2rad(a) return a*pi/180 end
local function rot(x, y, a, ox, oy, sx, sy)
	sx = sx or 1
	sy = sy or 1
	ox, oy = ox or 0, oy or 0
	x, y = x-ox, y-oy
	x, y = x/sx, y/sy
	a = deg2rad(a)
	return
		x*cos(a)-y*sin(a)+ox,
		x*sin(a)+y*cos(a)+oy
end

--image input, angle input, image output
--rotate output and sample from input
function transform.rotFast()
	local xm, ym = xmax/2-1, ymax/2-1
	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y)
			for c = 0, zmax-1 do
				local xr, yr = rot(x, y, params[1], xm, ym)
				local xf, yf = xr%1, yr%1
				xr, yr = floor(xr), floor(yr)
				if xr>=0 and xr<=xmax-1 and yr>=0 and yr<=ymax-1 then
					local bo = 	((xr>=xmax-1 or yr>=ymax-1) and 0 or xf*yf*getxy[1](xr+1,yr+1,c)) +
										((xr<=0 or yr>=ymax-1) and 0 or (1-xf)*yf*getxy[1](xr,yr+1,c)) +
										((xr>=xmax-1 or yr<=0) and 0 or xf*(1-yf)*getxy[1](xr+1,yr,c)) +
										((xr<=0 or yr<=0) and 0 or (1-xf)*(1-yf)*getxy[1](xr,yr,c))
					set[1](bo, c)
				end
			end
		end
		progress[__instance+1] = x - __instance
	end
	progress[__instance+1] = -1
end

function transform.rotFilt()
	local filt = math.window.cubic
	math.window.cubicSet("BSpline")
	--math.window.blackmanSet("blackmanHarris4")
	local filtType = .5
	local scale = 1
	local width = 2
	local xm, ym = xmax/2, ymax/2
	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y)
			for c = 0, zmax-1 do
				local xr, yr = rot(x, y, params[1], xm, ym)
				local xf, yf = xr%1, yr%1
				xr, yr = floor(xr), floor(yr)
				if xr>=0 and xr<=xmax-1 and yr>=0 and yr<=ymax-1 then
					local bo = 0
					local sum = 0
						for x=1-width, width do
							for y=1-width, width do
								local weight = filt(math.sqrt((x-xf)^2 + (y-yf)^2)/scale,filtType)
								sum = sum + weight
								bo = bo + (((xr+x)>0 and (yr+y)>0 and (xr+x)<=xmax-1 and (yr+y)<=ymax-1) and weight*getxy[1](xr+x,yr+y,c) or 0 )
							end
						end
					set[1](bo/sum, c)
				end
			end
		end
		progress[__instance+1] = x - __instance
	end
	progress[__instance+1] = -1
end

-- rotates input and splats on output, only way to use sample-based angles
function transform.rot2()
	local xm, ym = xmax/2, ymax/2
	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y)
			for c = 0, 2 do
				local xr, yr = rot(x, y, get[2](c), xm, ym)
				xr, yr = floor(xr), floor(yr)
				if xr>=0 and xr<=xmax-1 and yr>=0 and yr<=ymax-1 then
					-- desired effect is achieved, but interpolation is very tricky!!!
					-- splating requires add function and clear function to collect
					-- values from multiple pixels
					--if structured sampling is too complex implement random sample splating and oversample!
					setxy[1](get[1](c), xr, yr, c)
				end
			end
		end
		progress[__instance+1] = x - __instance
	end
	progress[__instance+1] = -1
end

-- x[-1,1], y[-1,1], off[0,1], sigma[0,1]
function transform.gradRot()
	local s = __global.state
	local buf = __global.buf
	local p = __global.params
	local progress	= __global.progress
	local inst	= __global.instance
	local instmax	= __global.instmax
	--init
	local xm, ym = (p[1]+1)/2*s.xmax, (p[2]+1)/2*s.ymax
	local unit = math.sqrt((s.xmax/2)^2 + (s.ymax/2)^2)
	local off = unit*p[3]
	local sigma = unit*p[4]
	sigma = sigma<1 and 1 or sigma
	
	--setup loop
	for x = inst, s.xmax-1, instmax do
		if progress[instmax]==-1 then break end
		for y = 0, s.ymax-1 do
			s:up(x, y)
			
			local d = math.sqrt((x-xm)^2 + (y-ym)^2)
			local g = d<off and 1 or math.func.gauss(d-off, sigma)
			g = g*p[5]
			
			buf[1]:set(g)
		end
		progress[inst] = x - inst
	end
	progress[inst] = -1
end

-- a[-1,1], b[-1,1], c[0,1], sigma[0,1], intensity[0,1]
function transform.gradLin()
	local s = __global.state
	local buf = __global.buf
	local p = __global.params
	local progress	= __global.progress
	local inst	= __global.instance
	local instmax	= __global.instmax
	--init
	local a, b = math.tan(p[1]/180*math.pi), 1
	local a2 = math.sqrt(a^2+1)
	local unit = math.sqrt((s.xmax/2)^2 + (s.ymax/2)^2)
	local c = unit*p[2]*a2
	local sigma = unit*p[3]
	local sign = (p[1]>=-90 and p[1]<=90) and true or false
	sigma = sigma<1 and 1 or sigma
	
	--setup loop
	for x = inst, s.xmax-1, instmax do
		if progress[instmax]==-1 then break end
		for y = 0, s.ymax-1 do
			s:up(x, y)
			
			local d = (a*(x-s.xmax/2) + (y-s.ymax/2) + c)/a2
			local g = sign and 1-math.func.gausscum(d, sigma) or math.func.gausscum(d, sigma)
			
			buf[1]:set(g)
		end
		progress[inst] = x - inst
	end
	progress[inst] = -1
end


local gaussIIR = require("gaussIIR")
function transform.gaussV()
	local s = __global.state
	local b = __global.buf
	local p = __global.params
	local progress	= __global.progress
	local inst	= __global.instance
	local instmax	= __global.instmax
	
	local sigma = p[1]*s.ymax/4
	local step = s.ymax*s.zmax
	local stride = s.zmax
	local length = s.ymax
	sigma = sigma<1 and 1 or sigma
	
	for x = inst, s.xmax-1, instmax do
		if progress[instmax]==-1 then break end
		if s.zmax==3 then
			gaussIIR(b[1].data + x*step + 0, b[2].data + x*step + 0, sigma, length, stride)
			gaussIIR(b[1].data + x*step + 1, b[2].data + x*step + 1, sigma, length, stride)
			gaussIIR(b[1].data + x*step + 2, b[2].data + x*step + 2, sigma, length, stride)
		elseif s.zmax==1 then
			gaussIIR(b[1].data + x*step + 0, b[2].data + x*step + 0, sigma, length, stride)
		end
		
		progress[inst] = x - inst
	end
	progress[inst] = -1
end

function transform.gaussH()
	local s = __global.state
	local b = __global.buf
	local p = __global.params
	local progress	= __global.progress
	local inst	= __global.instance
	local instmax	= __global.instmax
	
	-- set max value of progress
	progress[instmax+1] = s.ymax
	
	local sigma = p[1]*s.ymax/4
	local step = s.zmax
	local stride = s.ymax*s.zmax
	local length = s.xmax
	sigma = sigma<0.000001 and 0.000001 or sigma
	
	--TODO: correct for shading due to edge cutoff
	for x = inst, s.ymax-1, instmax do
		if progress[instmax]==-1 then break end
		
		if s.zmax==3 then
			gaussIIR(b[1].data + x*step + 0, b[2].data + x*step + 0, sigma, length, stride)
			gaussIIR(b[1].data + x*step + 1, b[2].data + x*step + 1, sigma, length, stride)
			gaussIIR(b[1].data + x*step + 2, b[2].data + x*step + 2, sigma, length, stride)
		elseif s.zmax==1 then
			gaussIIR(b[1].data + x*step + 0, b[2].data + x*step + 0, sigma, length, stride)
		end
		
		progress[inst] = x - inst
	end
	progress[inst] = -1
end

function transform.gaussCorrect()
	local s = __global.state
	local b = __global.buf
	local p = __global.params
	local progress	= __global.progress
	local inst	= __global.instance
	local instmax	= __global.instmax
	
	local xcorr = ffi.new("double[?]", s.xmax)
	local ycorr = ffi.new("double[?]", s.ymax)
	local sigma = p[1]*s.ymax/4
	sigma = sigma<0.000001 and 0.000001 or sigma
	
	local gausscum = math.func.gausscum
	
	for x = 0, s.xmax-1 do
		xcorr[x] = 1/(1-gausscum(x+0.5, sigma)-gausscum(s.xmax-x-0.5, sigma))
	end
	for y = 0, s.ymax-1 do
		ycorr[y] = 1/(1-gausscum(y+0.5, sigma)-gausscum(s.ymax-y-0.5, sigma))
	end
		
	for x = inst, s.xmax-1, instmax do
		if progress[instmax]==-1 then break end
		for y = 0, s.ymax-1 do
			s:up(x, y)
			
			local f = xcorr[x]*ycorr[y]
			if s.zmax==3 then
				local c1, c2, c3 = b[1]:get3()
				c1, c2, c3 = c1*f, c2*f, c3*f
				b[1]:set3(c1, c2, c3)
			elseif s.zmax==1 then
				local c = b[1]:get()
				b[1]:set(c*f)
			end
			
		end
		progress[inst] = x - inst
	end
	progress[inst] = -1
end

return transform