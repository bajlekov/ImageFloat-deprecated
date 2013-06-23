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

--denoise
math.randomseed(os.time())

local ffi = require("ffi")
local sdl = require("sdltools")
local dbg = require("dbgtools")

local ppm = require("ppmtools")
local img = require("imgtools")

d = ppm.readIM("lenaNoise.png")
--d = ppm.readIM("noise.jpg")
local bufi = ppm.toBuffer(d)
d = nil

local bufo = img.new(bufi)

local xmax = bufi.x
local ymax = bufi.y

print(xmax, ymax)

do
    local i = bufi.data
    local o = bufo.data
    -- add noise
    for x = 0, xmax-1 do
      for y = 0, ymax-1 do
	for z = 0, 2 do
	  local c = i[x][y][z]
	  --c = c + (math.random()*2-1)
	  c = (c<0 and 0) or (c>1 and 1) or c
	  i[x][y][z] = c
	  o[x][y][z] = c
	end
      end
    end
end

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

function bilateral(sigma, illum, center, neighbor)
	jit.flush()
	local ks = 15 --kernel size
	local A = ffi.new("double["..xmax.."]["..ymax.."]")
	
	local sigma2 = 1/2/sigma^2
	local illum2 = 1/2/illum^2
	
	local exp = math.exp
	local gauss2 = function(x2, s2) return exp(-x2*s2) end
	local gauss = math.func.gauss
	local sqrt = math.sqrt
	local log = math.log
	local abs = math.abs
	local bi = bufi.data
	local bo = bufo.data
	
	for x = 0, xmax-1 do
	  for y = 0, ymax-1 do
	    A[x][y] = bi[x][y][0]
	  end
	end
	
	--create kernel
	local kernel = ffi.new("double["..(2*ks+1).."]["..(2*ks+1).."]")
	for x = -ks, ks do
		for y = -ks, ks do 
			kernel[x+ks][y+ks] = gauss2((x)^2+(y)^2, sigma2)
		end
	end
	
	--precompute illuminance gaussian
	local n = 2^16
	local gi = ffi.new("double[?]", n)
	for i = 0, n-1 do
	  gi[i] = gauss2(i/n*9, illum2)
	end
	
	local diffSq = ffi.new("double["..(xmax+2).."]["..(ymax+2).."][8]")
	--get greyscale
	--gaussian blur
	--for x = ks+64, xmax-ks-65 do
	for x = ks+64, xmax-ks-65 do
		for y = ks+64, ymax-ks-65 do
			local i = A[x][y]
			local o = 0
			local sum = 0

			-- precalculate difference squares?? --does not appear to offer advantages, check implementation!!
			for cx = -ks, ks do
				for cy = -ks, ks do
					diffSq[cx+ks][cy+ks][0] = (A[x][y] - A[x+cx][y+cy])^2
					diffSq[cx+ks][cy+ks][1] = (A[x+1][y] - A[x+cx+1][y+cy])^2
					diffSq[cx+ks][cy+ks][2] = (A[x-1][y] - A[x+cx-1][y+cy])^2
					diffSq[cx+ks][cy+ks][3] = (A[x][y+1] - A[x+cx][y+cy+1])^2
					diffSq[cx+ks][cy+ks][4] = (A[x][y-1] - A[x+cx][y+cy-1])^2
					diffSq[cx+ks][cy+ks][5] = (A[x+1][y+1] - A[x+cx+1][y+cy+1])^2
					diffSq[cx+ks][cy+ks][6] = (A[x-1][y+1] - A[x+cx-1][y+cy+1])^2
					diffSq[cx+ks][cy+ks][7] = (A[x+1][y-1] - A[x+cx+1][y+cy-1])^2
					diffSq[cx+ks][cy+ks][8] = (A[x-1][y-1] - A[x+cx-1][y+cy-1])^2
				end
			end

			for cx = -ks, ks do
				for cy = -ks, ks do
					local l = A[x+cx][y+cy]
					--streamline gaussian with a lookup table

					-- pattern:
					local f = kernel[cx+ks][cy+ks]*gi[(
							diffSq[cx+ks][cy+ks][0]*center + (
							diffSq[cx+ks][cy+ks][1] +
							diffSq[cx+ks][cy+ks][2] +
							diffSq[cx+ks][cy+ks][3] +
							diffSq[cx+ks][cy+ks][4] +
							diffSq[cx+ks][cy+ks][5]/2 +
							diffSq[cx+ks][cy+ks][6]/2 +
							diffSq[cx+ks][cy+ks][7]/2 +
							diffSq[cx+ks][cy+ks][8]/2)*neighbor )*n/9]



					--local f = kernel[cx+ks][cy+ks]*gauss(i-l, illum)
					--local f = gauss(i-l, illum)
					o = o + l * f
					sum = sum + f
				end
			end
			bo[x][y][0] = o/sum
		end
	end
end


--smooth(16,0)
--bufi = img.copy(bufo)
--smooth(0,8)
--bufi = img.copy(bufo)
--smooth(0,3)

local median
do
  local pix = ffi.new("double[9]")
  local A = ffi.new("short[19]", 1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4)
  local B = ffi.new("short[19]", 2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2)
  
  local function sort(a, b)
      if pix[a]>pix[b] then
	pix[a], pix[b] = pix[b], pix[a]
      end
  end
  
  median = function(o, x, y)

    pix[0] = o[x-1][y-1][0]
    pix[1] = o[x-1][y][0]
    pix[2] = o[x-1][y+1][0]
    pix[3] = o[x][y-1][0]
    pix[4] = o[x][y][0]
    pix[5] = o[x][y+1][0]
    pix[6] = o[x+1][y-1][0]
    pix[7] = o[x+1][y][0]
    pix[8] = o[x+1][y+1][0]
    
    for i = 0, 18 do
      sort(A[i],B[i])
    end
    
    return pix[4]
  end
end

do
    local i = bufi.data
    local o = bufo.data
    for x = 0, xmax-1 do
      for y = 0, ymax-1 do
	i[x][y][0] = (i[x][y][0] + i[x][y][1] + i[x][y][2])/3
	o[x][y][0] = i[x][y][0]
      end
    end
end

tic()
bilateral(5, .5, 1, .7)
toc()

do
    local o = bufo.data
    for x = 2, xmax-3 do
	for y = 2, ymax-3 do
			o[x][y][1] = o[x][y][0]
			--o[x][y][1] = median(o, x, y)*0.5+o[x][y][0]*0.5
	end
    end
    for x = 0, xmax-1 do
      for y = 0, ymax-1 do
		local c = o[x][y][1]
		o[x][y][0] = c
		o[x][y][2] = c
	end
    end
end

-- smoothing of outliers (similar to neighbor clamping, but mix modulated by offset)

-- less smoothing in lighter areas causes bright noise to remain

d = ppm.fromBuffer(bufo)
d.name = "noise_out.png"
ppm.writeIM(d)
d = nil
print("Done!")