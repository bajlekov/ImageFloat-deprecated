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

--[[
	Adapted from: Fast 1D Gaussian convolution IIR approximation
	Author: Pascal Getreuer <getreuer@gmail.com>
	License: GNU GPL3
--]]


local function iir(data, sigma, numsteps, length)
	local sqrt = math.sqrt
	local pow = math.pow
	
	-- checks
	
	local lambda = (sigma*sigma)/(2*numsteps)
	local dnu = (1+2*lambda-sqrt(1+4*lambda))/(2*lambda)
	local nu = dnu
	local boundaryscale = 1/(1-dnu)
	local postscale = pow(dnu/lambda, numsteps)
	
	for step = 1, numsteps do
		data[0] = data[0] * boundaryscale -- fix for lua arrays!
		for i = 1, length-1 do
			data[i] = data[i] + nu*data[i-1]
		end
		data[length-1] = data[length-1] * boundaryscale
		for i = length-1, 1, -1 do
			data[i-1] = data[i-1] + nu*data[i]
		end
	end
	
	for i = 0, length-1 do
		data[i] = data[i] * postscale
	end
end

local ffi = require("ffi")

local a = ffi.new("double[20]")

a[9] = 1

iir(a, 3, 512, 20)

for i = 0, 19 do
	print(a[i])
end

