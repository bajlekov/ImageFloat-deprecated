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

local pi = math.pi
local cos, sin = math.cos, math.sin
local floor = math.floor

local function rad2deg(a) return a/pi*180 end
local function deg2rad(a) return a*pi/180 end

local function rot(x, y, a, ox, oy)
	ox, oy = ox or 0, oy or 0
	x, y = x-ox, y-oy
	a = deg2rad(a)
	return
		x*cos(a)-y*sin(a)+ox,
		x*sin(a)+y*cos(a)+oy
end

-- create generic function accepting any transform function
-- of the sort: function t(x, y) ... return tx, ty end
-- with a settable closure containing rotation, translation, zoom etc

function bufrot(bufi, bufo, a, xo, yo, xz, yz)
	xo, yo = xo*bufo.x or 0, yo*bufo.y or 0
	xz, yz = 1/xz or 1, 1/yz or 1
	local xm, ym = bufo.x/2, bufo.y/2
	local bi = bufi.data
	local bo = bufo.data
	for x = 0, bufo.x-1 do
		for y = 0, bufo.y-1 do
			
			local xr, yr = (x-xm)*xz+xm-xo, (y-ym)*yz+ym+yo
			xr, yr = rot(xr,yr,-a, xm, ym)
			xf, yf = xr%1, yr%1
			xr, yr = floor(xr), floor(yr)

			if xr>=0 and xr<=bufi.x-1 and yr>=0 and yr<=bufi.y-1 then
				for i = 0, 2 do


					bo[x][y][i] = 	xf*yf*((xr==bufi.x-1 or yr==bufi.y-1) and 0 or bi[xr+1][yr+1][i]) +
									(1-xf)*yf*((xr==0 or yr==bufi.y-1) and 0 or bi[xr][yr+1][i]) +
									xf*(1-yf)*((xr==bufi.x-1 or yr==0) and 0 or bi[xr+1][yr][i]) +
									(1-xf)*(1-yf)*((xr==0 or yr==0) and 0 or bi[xr][yr][i])
				end
			end
		end
	end
end


return bufrot