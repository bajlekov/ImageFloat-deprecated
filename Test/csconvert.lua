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

ffi = require("ffi")
cs = {}

function cs.LRGBtoSRGB(r, g, b)
	local a = 0.055
	local G = 2.4
	local k = a/(G-1)
	local f = ( (a+1)*k^(1/G)-a )/k
	r = (r<=k/f) and (r*f) or ((1+a)*r^(1/G)-a)
	g = (g<=k/f) and (g*f) or ((1+a)*g^(1/G)-a)
	b = (b<=k/f) and (b*f) or ((1+a)*b^(1/G)-a)
	return r, g, b
end

function cs.SRGBtoLRGB(r, g, b)
	local a = 0.055
	local G = 2.4
	local k = a/(G-1)
	local f = ( (a+1)*k^(1/G)-a )/k
	r = (r<=k) and (r/f) or (((r+a)/(1+a))^G)
	g = (g<=k) and (g/f) or (((g+a)/(1+a))^G)
	b = (b<=k) and (b/f) or (((b+a)/(1+a))^G)
	return r, g, b
end

return cs
