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

local ffi = require("ffi")
local max = math.max
local min = math.min

local function luma(r, g, b) return 0.2126 * r + 0.7152 * g + 0.0722 * b end --Rec709
local function chroma(r, g, b) return max(r, g, b)-min(r, g, b) end
local function hue(r, g, b)
	local c = chroma(r, g, b)
	if c==0 then return 0 end
	local hue
	local m = max(r, g, b)
	if m==r then hue = ((g - b) / c) end
	if m==g then hue = (2 + (b - r) / c) end
	if m==b then hue = (4 + (r - g) / c) end
	return hue<0 and hue/6+1 or hue/6
end

local size = 256
local height = 100
local hist = {}
hist.r = ffi.new("int[?]",size+1)
hist.g = ffi.new("int[?]",size+1)
hist.b = ffi.new("int[?]",size+1)
hist.l = ffi.new("int[?]",size+1)
hist.c = ffi.new("int[?]",size+1)
hist.h = ffi.new("int[?]",size+1)

local floor = math.floor
local max = math.max

function hist.calculate(buffer)
	--jit.flush()

	local hr, hg, hb =hist.r, hist.g, hist.b
	local hl, hc, hh =hist.l, hist.c, hist.h

	--clear histograms
	ffi.fill(hr, (size+1)*4)
	ffi.fill(hg, (size+1)*4)
	ffi.fill(hb, (size+1)*4)
	ffi.fill(hl, (size+1)*4)
	ffi.fill(hc, (size+1)*4)
	ffi.fill(hh, (size+1)*4)

	--count occurences
	for x = 0, buffer.x-1 do
		for y = 0, buffer.y-1 do
			local r, g, b = buffer:get3(x,y)
			local l, c, h = luma(r, g, b), chroma(r, g, b), hue(r, g, b)
			r = (r<0 and 0) or (r>1 and size) or floor(r*size)
			g = (g<0 and 0) or (g>1 and size) or floor(g*size)
			b = (b<0 and 0) or (b>1 and size) or floor(b*size)
			l = (l<0 and 0) or (l>1 and size) or floor(l*size)
			c = (c<0 and 0) or (c>1 and size) or floor(c*size)
			h = floor(h*size)
			hr[r] = hr[r] + 1
			hg[g] = hg[g] + 1
			hb[b] = hb[b] + 1
			hl[l] = hl[l] + 1
			hc[c] = hc[c] + 1
			hh[h] = hh[h] + 1
		end
	end

	--normalisation
	local mrgb, ml, mc, mh = 1, 1, 1, 1 --prevents slowdowns and division by 0
	for i=1, size-1 do
		mrgb = max(mrgb, hr[i], hg[i], hb[i])
		ml = max(ml, hl[i])
		mc = max(mc, hc[i])
		mh = max(mh, hh[i])
	end
	mrgb = (1/mrgb)*height
	ml = (1/ml)*height
	mc = (1/mc)*height
	mh = (1/mh)*height
	for i=0, size do
		hr[i] = hr[i]*mrgb
		hg[i] = hg[i]*mrgb
		hb[i] = hb[i]*mrgb
		hl[i] = hl[i]*ml
		hc[i] = hc[i]*mc
		hh[i] = hh[i]*mh
	end
end

return hist