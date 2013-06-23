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

local filter = {}

function filter.min()
	for x = __instance+1, xmax-2, __tmax do
		if progress[0]==-1 then break end
		for y = 1, ymax-2 do
			__pp = (x * ymax + y)
			for c = 0, 2 do
				set[1]( 
					math.min(
						getxy[1](x-1,y-1,c), getxy[1](x,y-1,c), getxy[1](x+1,y-1,c),
						getxy[1](x-1,y,c), getxy[1](x,y,c), getxy[1](x+1,y,c),
						getxy[1](x-1,y+1,c), getxy[1](x,y+1,c), getxy[1](x+1,y+1,c)
						)
				, c)
			end
		end
		progress[__instance+1] = x - __instance
	end
	progress[__instance+1] = -1
end

function filter.max()
	for x = __instance+1, xmax-2, __tmax do
		if progress[0]==-1 then break end
		for y = 1, ymax-2 do
			__pp = (x * ymax + y)
			for c = 0, 2 do
				set[1]( 
					math.max(
						getxy[1](x-1,y-1,c), getxy[1](x,y-1,c), getxy[1](x+1,y-1,c),
						getxy[1](x-1,y,c), getxy[1](x,y,c), getxy[1](x+1,y,c),
						getxy[1](x-1,y+1,c), getxy[1](x,y+1,c), getxy[1](x+1,y+1,c)
						)
				, c)
			end
		end
		progress[__instance+1] = x - __instance
	end
	progress[__instance+1] = -1
end

function filter.median()
	for x = __instance+1, xmax-2, __tmax do
		if progress[0]==-1 then break end
		for y = 1, ymax-2 do
			__pp = (x * ymax + y)
			for c = 0, 2 do
				local v
				local t ={
						getxy[1](x-1,y-1,c), getxy[1](x,y-1,c), getxy[1](x+1,y-1,c),
						getxy[1](x-1,y,c), getxy[1](x,y,c), getxy[1](x+1,y,c),
						getxy[1](x-1,y+1,c), getxy[1](x,y+1,c), getxy[1](x+1,y+1,c)
						}
				table.sort(t)
				set[1](t[5], c)
			end
		end
		progress[__instance+1] = x - __instance
	end
	progress[__instance+1] = -1
end

return filter