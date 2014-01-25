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

-- in-place dct transform on 8x8 array

--[[
Adapted from:

Discrete Cosine Transform Code
Copyright(C) 1997 Takuya OOURA (email: ooura@mmm.t.u-tokyo.ac.jp).
--]]

local dct = {}

local C8_1R = 0.49039264020161522456
local C8_1I = 0.09754516100806413392
local C8_2R = 0.46193976625564337806
local C8_2I = 0.19134171618254488586
local C8_3R = 0.41573480615127261854
local C8_3I = 0.27778511650980111237
local C8_4R = 0.35355339059327376220
local W8_4R = 0.70710678118654752440

function dct.dct(a) -- unroll!
	for j = 0, 7 do
		local x0r = a[0][j] + a[7][j]
		local x1r = a[0][j] - a[7][j]
		local x0i = a[2][j] + a[5][j]
		local x1i = a[2][j] - a[5][j]
		local x2r = a[4][j] + a[3][j]
		local x3r = a[4][j] - a[3][j]
		local x2i = a[6][j] + a[1][j]
		local x3i = a[6][j] - a[1][j]
		local xr = x0r + x2r
		local xi = x0i + x2i
		a[0][j] = C8_4R * (xr + xi)
		a[4][j] = C8_4R * (xr - xi)
		xr = x0r - x2r
		xi = x0i - x2i
		a[2][j] = C8_2R * xr - C8_2I * xi
		a[6][j] = C8_2R * xi + C8_2I * xr
		xr = W8_4R * (x1i - x3i)
		x1i = W8_4R * (x1i + x3i)
		x3i = x1i - x3r
		x1i = x1i + x3r
		x3r = x1r - xr
		x1r = x1r + xr
		a[1][j] = C8_1R * x1r - C8_1I * x1i
		a[7][j] = C8_1R * x1i + C8_1I * x1r
		a[3][j] = C8_3R * x3r - C8_3I * x3i
		a[5][j] = C8_3R * x3i + C8_3I * x3r
end
for j = 0, 7 do -- unroll!
	local x0r = a[j][0] + a[j][7]
	local x1r = a[j][0] - a[j][7]
	local x0i = a[j][2] + a[j][5]
	local x1i = a[j][2] - a[j][5]
	local x2r = a[j][4] + a[j][3]
	local x3r = a[j][4] - a[j][3]
	local x2i = a[j][6] + a[j][1]
	local x3i = a[j][6] - a[j][1]
	local xr = x0r + x2r
	local xi = x0i + x2i
	a[j][0] = C8_4R * (xr + xi)
	a[j][4] = C8_4R * (xr - xi)
	xr = x0r - x2r
	xi = x0i - x2i
	a[j][2] = C8_2R * xr - C8_2I * xi
	a[j][6] = C8_2R * xi + C8_2I * xr
	xr = W8_4R * (x1i - x3i)
	x1i = W8_4R * (x1i + x3i)
	x3i = x1i - x3r
	x1i = x1i + x3r
	x3r = x1r - xr
	x1r = x1r + xr
	a[j][1] = C8_1R * x1r - C8_1I * x1i
	a[j][7] = C8_1R * x1i + C8_1I * x1r
	a[j][3] = C8_3R * x3r - C8_3I * x3i
	a[j][5] = C8_3R * x3i + C8_3I * x3r
end
end

function dct.idct(a)
	for j = 0, 7 do -- unroll!
		local x1r = C8_1R * a[1][j] + C8_1I * a[7][j]
		local x1i = C8_1R * a[7][j] - C8_1I * a[1][j]
		local x3r = C8_3R * a[3][j] + C8_3I * a[5][j]
		local x3i = C8_3R * a[5][j] - C8_3I * a[3][j]
		local xr = x1r - x3r
		local xi = x1i + x3i
		x1r = x1r + x3r
		x3i = x3i - x1i
		x1i = W8_4R * (xr + xi)
		x3r = W8_4R * (xr - xi)
		xr = C8_2R * a[2][j] + C8_2I * a[6][j]
		xi = C8_2R * a[6][j] - C8_2I * a[2][j]
		local x0r = C8_4R * (a[0][j] + a[4][j])
		local x0i = C8_4R * (a[0][j] - a[4][j])
		local x2r = x0r - xr
		local x2i = x0i - xi
		x0r = x0r + xr
		x0i = x0i + xi
		a[0][j] = x0r + x1r
		a[7][j] = x0r - x1r
		a[2][j] = x0i + x1i
		a[5][j] = x0i - x1i
		a[4][j] = x2r - x3i
		a[3][j] = x2r + x3i
		a[6][j] = x2i - x3r
		a[1][j] = x2i + x3r
	end
	for j = 0, 7 do -- unroll!
		local x1r = C8_1R * a[j][1] + C8_1I * a[j][7]
		local x1i = C8_1R * a[j][7] - C8_1I * a[j][1]
		local x3r = C8_3R * a[j][3] + C8_3I * a[j][5]
		local x3i = C8_3R * a[j][5] - C8_3I * a[j][3]
		local xr = x1r - x3r
		local xi = x1i + x3i
		x1r = x1r + x3r
		x3i = x3i - x1i
		x1i = W8_4R * (xr + xi)
		x3r = W8_4R * (xr - xi)
		xr = C8_2R * a[j][2] + C8_2I * a[j][6]
		xi = C8_2R * a[j][6] - C8_2I * a[j][2]
		local x0r = C8_4R * (a[j][0] + a[j][4])
		local x0i = C8_4R * (a[j][0] - a[j][4])
		local x2r = x0r - xr
		local x2i = x0i - xi
		x0r = x0r + xr
		x0i = x0i + xi
		a[j][0] = x0r + x1r
		a[j][7] = x0r - x1r
		a[j][2] = x0i + x1i
		a[j][5] = x0i - x1i
		a[j][4] = x2r - x3i
		a[j][3] = x2r + x3i
		a[j][6] = x2i - x3r
		a[j][1] = x2i + x3r
	end
end

-- test
--[[
ffi = require("ffi")

local d = ffi.new("double[8][8]")
for x = 0, 7 do
	for y = 0, 7 do
		d[x][y]=math.random(255)
	end
end

local function disp(a)
	io.write("\n")
	for x = 0, 7 do
		for y = 0, 7 do
			io.write(a[x][y].."\t")
		end
		io.write("\n")
	end
end

disp(d)
dct(d)
disp(d)
idct(d)
disp(d)
--]]

return dct
