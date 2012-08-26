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

local ops = {}
ops.cs = require("opsCS")
ops.fft = require("opsFFT")
ops.transform = require("opsTransform")
ops.filter = require("opsFilter")
ops.layer = require("opsLayer")

require("mathtools")


-- generic pixel function loop
local startstring_matrix = [[
							for x = __instance, xmax-1, __tmax do
								if progress[0]==-1 then break end
								for y = 0, ymax-1 do
									__pp = (x * ymax + y)
]] local endstring_matrix = [[
									end
								progress[__instance+1] = x - __instance
							end
							progress[__instance+1] = -1
]]


--for value/colour processing:
local startstring_single = [[ __pp = 0 ]]
local endstring_single = [[ progress[__instance+1] = -1 ]]

ops.strings = {

	invert = [[ -- 2, 1
	for c = 0, 2 do
		set[1]( (1-get[1](c))*get[2](c) + get[1](c)*(1-get[2](c)), c)
	end ]],

	mixer = [[ -- 4, 1
	set[1]( get[2](0)*get[1](0) + get[2](1)*get[1](1) + get[2](2)*get[1](2), 0)
	set[1]( get[3](0)*get[1](0) + get[3](1)*get[1](1) + get[3](2)*get[1](2), 1)
	set[1]( get[4](0)*get[1](0) + get[4](1)*get[1](1) + get[4](2)*get[1](2), 2)
	]],

	cstransform = [[ --1, 1, {9}
	local c1, c2, c3 = get3[1]()
	local p1, p2, p3
	p1 = params[1]*c1 + params[2]*c2 + params[3]*c3
	p2 = params[4]*c1 + params[5]*c2 + params[6]*c3
	p3 = params[7]*c1 + params[8]*c2 + params[9]*c3
	set3[1](p1, p2, p3)
	]],

	copy = [[ -- 1, 1
	set3[1]( get3[1]())
	]],

	hsxedit = [[ -- 2,1
	local x = get[2](0)+get[1](0)
	x = x>1 and x-1 or x
	set[1]( x, 0)
	set[1]( get[2](1)*get[1](1), 1)
	set[1]( get[2](2)*get[1](2), 2)
	]],

	lchedit = [[ -- 2,1
	local x = get[2](2)+get[1](2)
	x = x>1 and x-1 or x
	set[1]( get[2](0)*get[1](0), 0)
	set[1]( get[2](1)*get[1](1), 1)
	set[1]( x, 2)
	]],

	rgbedit = [[ -- 3,1
	for c = 0, 2 do
		set[1]( get[1](c)*get[2](c)+get[3](c) , c)
	end	]],

	compose = [[ -- 3,1
	set3[1]( get[1](0), get[2](1), get[3](2) )
	]],

	decompose = [[ -- 1,3
		set[1](get[1](0))
		set[2](get[1](1))
		set[3](get[1](2))
	]],

	merge = [[ -- 3,1
	for c = 0, 2 do
		set[1]( get[1](c)*get[3](c) + get[2](c)*(1-get[3](c)), c)
	end	]],

	add = [[ -- 2,1
	for c = 0, 2 do
		set[1]( get[1](c) + get[2](c), c)
	end	]],

	sub = [[ -- 2,1
	for c = 0, 2 do
		set[1]( get[1](c) - get[2](c), c)
	end	]],

	mult = [[ -- 2,1
	for c = 0, 2 do
		set[1]( get[1](c) * get[2](c), c)
	end	]],

	div = [[ -- 2,1
	for c = 0, 2 do
		set[1]( get[1](c) / get[2](c), c)
	end	]],

	compMult = [[ -- 4, 2
	for c = 0, 2 do
		set[1]( get[1](c)*get[3](c) - get[2](c)*get[4](c), c)
		set[2]( get[1](c)*get[4](c) + get[2](c)*get[3](c), c)
	end
	]],

	zero = [[ -- 0,1
	for c = 0, 2 do
		set[1]( 0, c)
	end	]],

	equaliseGB = [[ -- 1,1
		local GB = (get[1](1)+get[1](2))/2
		set[1]( GB, 1)
		set[1]( GB, 2)
	]],

	invertR_GB = [[ -- 1,1
		local GB = 1-get[1](0)
		set[1]( GB, 1)
		set[1]( GB, 2)
	]],

	pass = [[ -- 1, 1
	set3[1](get3[1]())
	]],
}

do
	local function filter(func, flag)
		for x = __instance, xmax/2, __tmax do
			if progress[0]==-1 then break end
			for y = 0, ymax/2 do
				local gauss
				local size = 128 --math.sqrt(xmax^2+ymax^2)
				gauss = func(math.sqrt(x^2+y^2), get[1](0)*size)
				gauss = gauss + (flag and func(math.sqrt((xmax-x+1)^2+y^2), get[1](0)*size) or 0)
				gauss = gauss + (flag and func(math.sqrt(x^2+(ymax-y+1)^2), get[1](0)*size) or 0)
				gauss = gauss + (flag and func(math.sqrt((xmax-x+1)^2+(ymax-y+1)^2), get[1](0)*size) or 0)
				gauss = gauss * get[2]() + 1 - get[2]()
				set3xy[1](gauss, gauss, gauss,x,y)
				if x~=0 then set3xy[1](gauss, gauss, gauss, xmax-x,y) end
				if y~=0 then set3xy[1](gauss, gauss, gauss, x, ymax-y) end
				if x~=0 and y~=0 then set3xy[1](gauss, gauss, gauss, xmax-x, ymax-y) end
			end
			progress[__instance+1] = x - __instance
		end
		progress[__instance+1] = -1
	end

	function ops.gauss() return filter(math.func.gauss) end
	function ops.lorenz() return filter(math.func.lorenz) end
	function ops.gauss_wrap() return filter(math.func.gauss, true) end
	function ops.lorenz_wrap() return filter(math.func.lorenz, true) end
end

-- construct all pixel functions from ops.strings
for k, v in pairs(ops.strings) do
	ops[k] = loadstring(startstring_matrix..v..endstring_matrix)
end

ops.strings = nil

ops.empty = function() progress[__instance+1] = -1 end

ops.norm = function()	-- 1,1
	local sum = {[0]=0, [1]=0, [2]=0}

	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y)
			for c = 0, 2 do
				sum[c] = sum[c] + get[1](c)
			end
		end
		progress[__instance+1] = (x - __instance)/2
	end

	sum[0] = sum[0]==0 and 1 or sum[0]
	sum[1] = sum[1]==0 and 1 or sum[1]
	sum[2] = sum[2]==0 and 1 or sum[2]

	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y)
			for c = 0, 2 do
				set[1](get[1](c)/sum[c], c)
			end
		end
		progress[__instance+1] = (x - __instance)/2 + (xmax-1)/2
	end

	progress[__instance+1] = -1
end

return ops

--[[
PROTOTYPES
-- performance note: memory-align loops in same order as array [x][y][c]
cs.LRGBtoSRGB = function()
	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y) * 3
			for c = 0, 2 do
				set[1]( LRGBtoSRGB(get[1](c))*get[2](c) + get[1](c)*(1-get[2](c)), c)
			end
		end
		progress[__instance+1] = x - __instance
	end
	progress[__instance+1] = -1
end

cs.SRGBtoLRGB = function()
	for x = __instance, xmax-1, __tmax do
		if progress[0]==-1 then break end
		for y = 0, ymax-1 do
			__pp = (x * ymax + y) * 3
			for c = 0, 2 do
				set[1]( SRGBtoLRGB(get[1](c))*get[2](c) + get[1](c)*(1-get[2](c)), c)
			end
		end
		progress[__instance+1] = x - __instance
	end
	progress[__instance+1] = -1
end
--]]
