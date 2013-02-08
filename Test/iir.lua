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

-- allow arbitrary FIR(convolutions) and IIR filters, FFT filtering, wavelet

--[[
	iir multipass exponential decay
	Adapted from: Fast 1D Gaussian convolution IIR approximation
	Author: Pascal Getreuer <getreuer@gmail.com>
	License: GNU GPL3
--]]
local function iirG(data, sigma, length, numsteps)
	numsteps = numsteps or 5
	
	-- checks
	
	local lambda = (sigma*sigma)/(2*numsteps)
	local dnu = (1+2*lambda-math.sqrt(1+4*lambda))/(2*lambda)
	local nu = dnu
	local boundaryscale = 1/(1-dnu)
	local postscale = math.pow(dnu/lambda, numsteps)
	
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

-- iir gaussian van vliet
--[[
	Implementation of a Gaussian IIR filter after
	Ian T. Young and Lucas J. van Vliet. "Recursive implementation of
	the Gaussian filter." _Signal Processing_ 44 (1995), pp. 139-151.
--]]
local function iirV(data, sigma, length, pad)
	local q
	if sigma>2.5 then
		q = 0.98711*sigma - 0.96330
	else
		q = 3.97156-4.14554*math.sqrt(1-0.26891*sigma)
	end
	
	z = ffi.new("double[?]", pad)
	
	local b0 = 1.57825 + q*(2.44413 + q*(1.42810 + q*0.422205))
	local b1 = q*(2.44413 + q*(2.85619 + q*1.26661))/b0
	local b2 = -q*q*(1.42810 + q*1.26661)/b0
	local b3 = q*q*q*0.422205/b0
	
	b0 = 1-(b1+b2+b3)
	local d = data
	
	z[pad-1] = b0*d[pad-1]
	z[pad-2] = b0*d[pad-2] + b1*z[pad-1]
	z[pad-3] = b0*d[pad-3] + b1*z[pad-2] + b2*z[pad-1]
	--z[pad-4] = b0*data[pad-4] + b1*z[pad-3] + b2*z[pad-2] + b3*z[pad-1]
	for i = pad-4, 0, -1 do
		z[i] = b0*d[i] + b1*z[i+1] + b2*z[i+2] + b3*z[i+3]
	end
	
	d[0] = b0*d[0] + b1*z[1] + b2*z[2] + b3*z[3]
	d[1] = b0*d[1] + b1*d[0] + b2*z[1] + b3*z[2]
	d[2] = b0*d[2] + b1*d[1] + b2*d[0] + b3*z[1]
	--d[3] = b0*d[3] + b1*d[2] + b2*d[1] + b3*d[0]
	for i = 3, length-1 do
		z[i] = b0*d[i] + b1*d[i-1] + b2*d[i-2] + b3*d[i-3]
	end
	
	--pad only on right end, large enough to buffer peaks
	
end



-- iir gaussian deriche


local ffi = require("ffi")

local a = ffi.new("double[5000]")

a[0] = 1

iirG(a, 3, 5000, 64)

for i = 0, 512 do
	print(a[i])
end

