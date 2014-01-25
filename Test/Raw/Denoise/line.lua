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

-- line denoise algorithm

-- adapted from Rawtherapee CFA line denoise by DCT filtering
--﻿ (copyright (c) 2008-2010  Emil Martinec <ejmartin@uchicago.edu>)

local unroll = require("Tools.unroll")
local ffi = require("ffi")

package.path =  "./?.lua;"..package.path
local dct = require("Test.Raw.Denoise.dct")

local function getCh(x, y)
	return (x%2==1 and y%2==1 and "G") or
		(x%2==0 and y%2==0 and "G") or
		(x%2==0 and y%2==1 and "B") or
		(x%2==1 and y%2==0 and "R")
end

--[[
	- smooth with gaussian to extract highpass difference (per channel/step=2)
	- construct 8x8 blocks for each channel and do dct on them
		- (process in steps of 8 -> overlap by half)
		- merge linearly w=[0, .25, .75, 1, 1, .75, .25, 0]
	-- process:
		- forward dct
		...
--]]


local eps = 1e-5
-- TODO: check performance double vs float
local gauss = ffi.new("double[5]", 0.20416368871516755/2, 0.18017382291138087, 0.1238315368057753, 0.0662822452863612, 0.02763055063889883)
local rolloff = ffi.new("double[8]", 0, 0.135335, 0.249352, 0.411112, 0.606531, 0.800737, 0.945959, 1)
local window = ffi.new("double[8]", 0, .25, .75, 1, 1, .75, .25, 0)

local function convH5fun(i, x, y, bi, bo, k)
	bo:a(x,y, bo:i(x,y) + bi:i(x-2*i,y)*k[i] + bi:i(x+2*i,y)*k[i])
end
local function convV5fun(i, x, y, bi, bo, k)
	bo:a(x,y, bo:i(x,y) + bi:i(x,y-2*i)*k[i] + bi:i(x,y+2*i)*k[i])
end
local function convH(bi, bo, k)
	for x = 8, bi.x-9 do
		for y = 0, bi.y-1 do
			unroll[5](convH5fun, x, y, bi, bo, k)
		end
	end
end
local function convV(bi, bo, k)
	for x = 0, bi.x-1 do
		for y = 8, bi.y-9 do
			unroll[5](convV5fun, x, y, bi, bo, k)
		end
	end
end

local dctblock = ffi.new("double[4][8][8]")
local noisefactor = ffi.new("double[4][8][2]")
local linehvar = ffi.new("double[4]")
local linevvar = ffi.new("double[4]")

local function extract8x8(i, j, xoff, yoff) -- unroll!!
	for x = 0, 7 do
		for y = 0, 7 do
			dctblock[j][x][y] = i:i(xoff+x*2, yoff+y*2)
		end
	end
	return dctblock[j]
end

local function lineDenoise(i, noise)
	--inputs
	noise = noise or 0.1
	local noisevar = (3*noise)^2
	local noisevarm4 = 4 * noisevar
	
	-- output
	local o = i:new()
	
	-- code
	local t1 = i:new()
	local t2 = i:new()
	
	convH(i, t1, gauss)
	convV(t1, t2, gauss)
	
	t1 = i-t2
	
	for x = 0, i.x-16, 8 do
		for y = 0, i.y-16, 8 do
			ffi.fill(dctblock, 4*8*8*8)
			ffi.fill(noisefactor, 4*8*2*8)
			ffi.fill(linehvar, 4*8)
			ffi.fill(linevvar, 4*8)
			
			--dctblock = ffi.new("double[4][8][8]")
			--noisefactor = ffi.new("double[4][8][2]")
			--linehvar = ffi.new("double[4]")
			--linevvar = ffi.new("double[4]")
			
			dct.dct(extract8x8(t1, 0, x, y))
			dct.dct(extract8x8(t1, 1, x+1, y))
			dct.dct(extract8x8(t1, 2, x, y+1))
			dct.dct(extract8x8(t1, 3, x+1, y+1))
			
			for j = 0, 3 do
				for i = 0, 7 do
					linehvar[j] = linehvar[j] + dctblock[j][0][i]^2
					linevvar[j] = linevvar[j] + dctblock[j][i][0]^2
				end
			end
			
			for j = 0, 3 do
				for i = 0, 7 do
					local coeffsq = dctblock[j][i][0]^2
					noisefactor[j][i][0] = coeffsq/(coeffsq+rolloff[i]*noisevar+eps)
					local coeffsq = dctblock[j][0][i]^2
					noisefactor[j][i][1] = coeffsq/(coeffsq+rolloff[i]*noisevar+eps)
				end
			end
			
			if noisevarm4>(linehvar[0]+linehvar[1]) then
				for i = 0, 7 do
					dctblock[0][0][i] = dctblock[0][0][i] * 0.5*(noisefactor[0][i][1]+noisefactor[1][i][1])
					dctblock[1][0][i] = dctblock[1][0][i] * 0.5*(noisefactor[0][i][1]+noisefactor[1][i][1])
				end
			end
			if noisevarm4>(linehvar[2]+linehvar[3]) then
				for i = 0, 7 do
					dctblock[2][0][i] = dctblock[2][0][i] * 0.5*(noisefactor[2][i][1]+noisefactor[3][i][1])
					dctblock[3][0][i] = dctblock[3][0][i] * 0.5*(noisefactor[2][i][1]+noisefactor[3][i][1])
				end
			end
			if noisevarm4>(linevvar[0]+linevvar[2]) then
				for i = 0, 7 do
					dctblock[0][i][0] = dctblock[0][i][0] * 0.5*(noisefactor[0][i][0]+noisefactor[2][i][0])
					dctblock[2][i][0] = dctblock[2][i][0] * 0.5*(noisefactor[0][i][0]+noisefactor[2][i][0])
				end
			end
			if noisevarm4>(linevvar[1]+linevvar[3]) then
				for i = 0, 7 do
					dctblock[1][i][0] = dctblock[1][i][0] * 0.5*(noisefactor[1][i][0]+noisefactor[3][i][0])
					dctblock[3][i][0] = dctblock[3][i][0] * 0.5*(noisefactor[1][i][0]+noisefactor[3][i][0])
				end
			end
			
			dct.idct(dctblock[0])
			dct.idct(dctblock[1])
			dct.idct(dctblock[2])
			dct.idct(dctblock[3])
			for m = 0, 7 do
				for n = 0, 7 do
					local t0 = o:i(x+2*m, y+2*n)
					local t1 = o:i(x+2*m+1, y+2*n)
					local t2 = o:i(x+2*m, y+2*n+1)
					local t3 = o:i(x+2*m+1, y+2*n+1)
					
					t0 = t0 + window[m]*window[n]*dctblock[0][m][n]
					t1 = t1 + window[m]*window[n]*dctblock[1][m][n]
					t2 = t2 + window[m]*window[n]*dctblock[2][m][n]
					t3 = t3 + window[m]*window[n]*dctblock[3][m][n]
					
					o:a(x+2*m, y+2*n, t0)
					o:a(x+2*m+1, y+2*n, t1)
					o:a(x+2*m, y+2*n+1, t2)
					o:a(x+2*m+1, y+2*n+1, t3)
				end
			end
		end
	end
	
	o = o + t2
	
	return o
end

return lineDenoise
