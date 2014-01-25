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

local ffi = require("ffi")
local sdl = require("sdltools")

sdl.init()
sdl.setScreen(820, 820, 32)
sdl.caption("Test UI", "Test UI");
require("draw")
require("mathtools")
function pixel(x, y) return setPixel(math.floor(x*800+10), math.floor(810-y*800),255,255,255) end
boxLine(10,10,810,810,255,255,255)

function poly(x1, y1, yp1, x2, y2, yp2)
	local n = 1/(-x2^3+3*x1*x2^2-3*x1^2*x2+x1^3)
	local a = (x1^2*(x2^2*(yp2-yp1)-3*x2*y2)+x1^3*(y2-x2*yp2)+x1*x2^3*yp1+(3*x1*x2^2-x2^3)*y1)*n
	local b = -(x1*(x2^2*(2*yp2+yp1)-6*x2*y2)-x1^3*yp2+x1^2*x2*(-yp2-2*yp1)+x2^3*yp1+6*x1*x2*y1)*n
	local c = (x1*(x2*(yp2-yp1)-3*y2)+x2^2*(yp2+2*yp1)+x1^2*(-2*yp2-yp1)-3*x2*y2+(3*x2+3*x1)*y1)*n
	local d = -(x2*(yp2+yp1)+x1*(-yp2-yp1)-2*y2+2*y1)/(-x2^3+3*x1*x2^2-3*x1^2*x2+x1^3)
	return a, b, c, d
end

function poly(x1, y1, yp1, x2, y2, yp2)
	local n = (x2-x1)
	yp1 = yp1*n
	yp2 = yp2*n
	local a = y1
	local b = yp1
	local c = -3*y1 - 2*yp1 + 3*y2 - yp2
	local d = 2*y1 + yp1 - 2*y2 + yp2
	return a,b,c,d 
end

function y(x, a, b, c, d)
	return a+b*x+c*x^2+d*x^3
end

function spline(x, ax, ay, bx, by, cx, cy)
	-- local t = -(math.sqrt((cx-2*bx+ax)*x-ax*cx+bx^2)+bx-ax)/(cx-2*bx+ax)
	local t
	if (cx-2*bx+ax)==0 then t = x else
		t = (math.sqrt((cx-2*bx+ax)*x-ax*cx+bx^2)-bx+ax)/(cx-2*bx+ax)
	end
	return (cy-2*by+ay)*t^2 + (2*by-2*ay)*t + ay
end

p1 = {0,0}
p2 = {.5,.65}

for x=0,1,1/800 do
	local a, b, c, d
	if x<.33 then
		a, b, c, d = poly(0,0,2,.33,.66,1)
		--y = spline(x, 0,0,p1[1],p1[2],(p1[1]+p2[1])/2,(p1[2]+p2[2])/2)
		pixel(x, y(x/.33, a, b, c, d)/3)
	else
		a, b, c, d = poly(.33,.66,1,1,1,1/2)
		--y = spline(x, (p1[1]+p2[1])/2,(p1[2]+p2[2])/2,p2[1],p2[2],1,1)
		pixel(x, y((x-.33)*1.5, a, b, c, d)/3)
	end
	

	--local y = math.window.cosPower(x*2,2)
	--pixel(x, y)
	--local y = math.window.blackman(x*2, "blackmanHarris7")
	--pixel(x, y)
end

drawLine(0*800+10, 800-0*800+10, p1[1]*800+10, 800-p1[2]*800+10, 255,0,255)
drawLine(p1[1]*800+10, 800-p1[2]*800+10, p2[1]*800+10, 800-p2[2]*800+10, 255,0,255)
drawLine(p2[1]*800+10, 800-p2[2]*800+10, 1*800+10, 800-1*800+10, 255,0,255)

sdl.flip()
sdl.wait(3000)

sdl.quit()
