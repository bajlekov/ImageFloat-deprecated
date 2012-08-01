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
--require("mathtools")

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

	alpha = [[ -- 3, 1 regular mix
	for c = 0, 2 do
		set[1]( (get[1](c))*get[3](c) + get[2](c)*(1-get[3](c)), c)
	end ]],

	dissolve = [[ --3, 1 harsh grainy mix
	for c = 0, 2 do
		set[1]( math.random()>get[3](c) and get[1](c) or get[2](c), c)
	end ]],

	multiply = [[ -- 2,1 
	for c = 0, 2 do
		set[1]( get[1](c) * get[2](c), c)
	end	]],

	screen = [[ -- 2,1 
	for c = 0, 2 do
		set[1](1-((1-get[1](c)) * (1-get[2](c))), c)
	end	]],

	overlay = [[ -- 3,1 overlay with alpha power 
	for c = 0, 2 do
		set[1]( get[2](c)<get[3](c) and
			(2*get[1](c)*get[2](c)) or
			(1-2*(1-get[1](c))*(1-get[2](c))), c)
	end	]],

	-- soft light (overlay with softer mix) ??
	-- hard light (overlay with swapped images)

	--Screen
	--Color dodge 		a/(1-b)
	--Linear dodge

	--Multiply
	--Color burn 		(1-a)/b
	--Linear burn

	--Vivid light
	--Linear light

	--divide
	--subtract
	--add
	--difference (positive subtract)

	--darken
	--lighten
	
	--hue
	--chroma
	--color (hue + chroma)
	--luma

	--grain extract
	--grain merge
}

-- construct all pixel functions from ops.strings
for k, v in pairs(ops.strings) do
	ops[k] = loadstring(startstring_matrix..v..endstring_matrix)
end

ops.strings = nil
return ops
