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

-- image input, angle input, image output
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

	local filt = math.window.linear
	math.window.cubicSet("CatmullRom")
	local filtType = 3
	local scale = 1
	local width = 1
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

return transform