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

--denoise
math.randomseed(os.time())


ffi = require("ffi")
ppm = require("ppmtools")
img = require("imgtools")

d = ppm.readIM("lena_noisy.jpg")
--d = ppm.readIM("noise.jpg")
local bufi = ppm.toBuffer(d)
d = nil

local bufo = img.new(bufi)

local xmax = bufi.x
local ymax = bufi.y

print(xmax, ymax)

function walk(x,y)
	x = x + math.random(3) - 2
	y = y + math.random(3) - 2
	if x<0 then x=0 end
	if y<0 then y=0 end
	if x>=xmax then x = xmax-1 end
	if y>=ymax then y = ymax-1 end
	return x, y
end

--img.pixelOp(bufi, function(r,g,b) return (r+g+b)/3,0,0 end)

function smooth(p1, p2)
	for x = 0, xmax-1 do
		print(x)
		for y = 0, ymax-1 do
			local xn, yn
			local t1, t2, t3 = bufi.data[x][y][0], bufi.data[x][y][1], bufi.data[x][y][2]
			local n = (t1 + t2 + t3)
			local n_orig = n
			local c = 1
			for z = 1, 10 do 								--quality (number of samples)
				xn, yn = walk(x, y)
				local f1=1
				local f2=1
				for i=1, 20 do								--radius (maximum distance to search)
					local n_old = n
					n = (bufi.data[xn][yn][0] + bufi.data[xn][yn][1] + bufi.data[xn][yn][2])
					local d = math.abs(n_old-n)/3
					local dd = math.abs(n_orig-n)/3
						--power (how fast influence decreases)
						f1 = p1==0 and 1 or f1*(1-d)^p1
						f2 = p2==0 and 1 or (1-dd)^p2
					if f1<0.01 and f2<0.3 then break else			--threshold (blotching)
						t1 = t1 + bufi.data[xn][yn][0]*(f1*f2)
						t2 = t2 + bufi.data[xn][yn][1]*(f1*f2)
						t3 = t3 + bufi.data[xn][yn][2]*(f1*f2)
						c = c + (f1*f2)
					end
						--bufo.data[xn][yn][0]=bufo.data[xn][yn][0] + f1/200
					
					xn, yn = walk(xn, yn)
				end
			end
			bufo.data[x][y][0] = t1/c--c/500						--add in original image (possible mix with other filters)
			bufo.data[x][y][1] = t2/c
			bufo.data[x][y][2] = t3/c
		end
	end
end

require("mathtools")

function bilateral(sigma, power)
	--create kernel
	local gauss = ffi.new("double[15][15]")
	for x = 0, 14 do
		for y = 0, 14 do 
			gauss[x][y]=math.gauss(math.sqrt((x-7)^2+(y-7)^2),sigma)
		end
	end

	function get(x,y)
		if x>=0 and x<xmax and y>=0 and y<ymax then
			return (bufi.data[x][y][0] + bufi.data[x][y][1] + bufi.data[x][y][2])/3
		else
			return 0
		end
	end

	function get(x,y)
		return (x>=0 and x<xmax and y>=0 and y<ymax) and (bufi.data[x][y][0] + bufi.data[x][y][1] + bufi.data[x][y][2])/3 or 0
	end

	function set(x,y,z)
		bufo.data[x][y][0]=z
		bufo.data[x][y][1]=z
		bufo.data[x][y][2]=z
	end

	--gaussian blur
	for x = 0, xmax-1 do
		for y = 0, ymax-1 do
			local i = get(x,y)
			local o = 0
			local sum = 0
			for cx = -7, 7 do
				for cy = -7, 7 do
					local l = get(x+cx, y+cy)
					local f = gauss[cx+7][cy+7]*math.log((1-math.abs(i-l)))--^power
					o = o + l * f
					sum = sum + f
				end
			end
			set(x,y,o/sum)
		end
	end
end


--smooth(16,0)
--bufi = img.copy(bufo)
--smooth(0,8)
--bufi = img.copy(bufo)
--smooth(0,3)
bilateral(6, 3)

--less smoothing in lighter areas causes bright noise to remain

d = ppm.fromBuffer(bufo)
d.name = "noise_out.ppm"
ppm.writeFile(d)
d = nil
print("Done!")