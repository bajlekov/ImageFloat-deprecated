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

-- loading raw files workflow

-- setup stuff
math.randomseed(os.time())
local ffi = require("ffi")
require("global")

local sdl = require("Include.sdl")
local ppm = require("Tools.ppmtools")
local img = require("Tools.imgtools")

-- write/set demosaic function
package.path =  "./?.lua;"..package.path
local denoise = require("Test.Raw.Denoise.nlmeans")
local demosaic = require("Test.Raw.Demosaic.dlmmse")

-- load image

-- TODO: PGM loading!

local i = ppm.toBuffer(ppm.readIM("~/P7288854.tiff")):copyG()*16-64/4096
local original = i:copy()

local function imshow(i)
	sdl.screen.set(i.x, i.y)
	i:toSurface(sdl.screen.surf)
	sdl.update()

	while not sdl.input.key.any do
		sdl.input.update()
	end
end

-- mosaic image
local function getCh(x, y)
	return (x%2==1 and y%2==0 and "G") or
		(x%2==0 and y%2==1 and "G") or
		(x%2==0 and y%2==0 and "B") or
		(x%2==1 and y%2==1 and "R")
end

local dl = {2.151794, 0.940274, 1.085084}
local rgb_xyz = {	0.412453, 0.357580, 0.180423,
					0.212671, 0.715160, 0.072169,
					0.019334, 0.119193, 0.950227}
local cam_xyz = {	 0.8453,	-0.2198,	-0.1092,
					-0.7609,	 1.5681,	 0.2008,
					-0.1725,	 0.2337,	 0.7824}


local function det2(a, b, c, d) return a*d-b*c end
local function det3(a1,a2,a3,b1,b2,b3,c1,c2,c3)
	return a1*b2*c3-a1*b3*c2-a2*b1*c3+a2*b3*c1+a3*b1*c2-a3*b2*c1
end

local function adj(a1,a2,a3,b1,b2,b3,c1,c2,c3)
	local o = {0, 0, 0, 0, 0, 0, 0, 0, 0}
	o[1]=det2(b2, b3, c2, c3)
	o[2]=det2(a3, a2, c3, c2)
	o[3]=det2(a2, a3, b2, b3)

	o[4]=det2(b3, b1, c3, c1)
	o[5]=det2(a1, a3, c1, c3)
	o[6]=det2(a3, a1, b3, b1)
	
	o[7]=det2(b1, b2, c1, c2)
	o[8]=det2(a2, a1, c2, c1)
	o[9]=det2(a1, a2, b1, b2)
	return o
end

local function inv(M)
	local o = adj(unpack(M))
	local f = 1/det3(unpack(M))

	for i=1,9 do
		o[i]=o[i]*f
	end
	return o
end

local function T(M)
	return {M[1], M[4], M[7],
			M[2], M[5], M[8],
			M[3], M[6], M[9],
		}
end

local function matMult(M, N)
	return {
		M[1]*N[1] + M[2]*N[4] + M[3]*N[7],
		M[1]*N[2] + M[2]*N[5] + M[3]*N[8],
		M[1]*N[3] + M[2]*N[6] + M[3]*N[9],

		M[4]*N[1] + M[5]*N[4] + M[6]*N[7],
		M[4]*N[2] + M[5]*N[5] + M[6]*N[8],
		M[4]*N[3] + M[5]*N[6] + M[6]*N[9],

		M[7]*N[1] + M[8]*N[4] + M[9]*N[7],
		M[7]*N[2] + M[8]*N[5] + M[9]*N[8],
		M[7]*N[3] + M[8]*N[6] + M[9]*N[9],
	}
end

local rgb_cam = T(matMult(cam_xyz, rgb_xyz))

local n1, n2, n3 = 	1/(rgb_cam[1]+rgb_cam[4]+rgb_cam[7]),
					1/(rgb_cam[2]+rgb_cam[5]+rgb_cam[8]),
					1/(rgb_cam[3]+rgb_cam[6]+rgb_cam[9])
rgb_cam[1] = rgb_cam[1]*n1
rgb_cam[2] = rgb_cam[2]*n2
rgb_cam[3] = rgb_cam[3]*n3
rgb_cam[4] = rgb_cam[4]*n1
rgb_cam[5] = rgb_cam[5]*n2
rgb_cam[6] = rgb_cam[6]*n3
rgb_cam[7] = rgb_cam[7]*n1
rgb_cam[8] = rgb_cam[8]*n2
rgb_cam[9] = rgb_cam[9]*n3

local cam = inv(rgb_cam)

print(unpack(cam))


for x = 0, i.x-1 do
	for y = 0, i.y-1 do
		local v = i:i(x, y)
		local c = getCh(x, y)
		if c=="G" then
			v = v * dl[2]
		elseif c=="R" then
			v = v * dl[1]
		elseif c=="B" then
			v = v * dl[3]
		end
		i:a(x, y, v)
	end
end

local j = i:copy()
sdl.tic()
i = denoise(i,0.001)
sdl.toc("denoise")
sdl.tic()
i = demosaic(i)
sdl.toc("demosaic")

for x = 0, i.x-1 do
	for y = 0, i.y-1 do
		local r, g, b = i:get3(x, y)
		
		r = cam[1]*r+cam[4]*g+cam[7]*b
		g = cam[2]*r+cam[5]*g+cam[8]*b
		b = cam[3]*r+cam[6]*g+cam[9]*b
		
		i:set3(x, y, r, g, b)
	end
end

imshow(img.scaleDownQuad(i)^(1/1.8))

ppm.writeIM(ppm.fromBuffer(i^(1/1.8), "~/test_demosaic.png"))

