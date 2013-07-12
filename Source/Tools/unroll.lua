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

-- library providing unrolled short loops for use in outer loops
-- usage: unroll[n](function, arguments...) for function(iterator, arguments...)


local unroll = {}
local funStart = "return function(fun, ...) "
local funEnd = "end"

local function construct(i)
	print("constructing unroll["..i.."] function")
	local funTable = {}
	table.insert(funTable, funStart)
	for j = 0, i-1 do
		table.insert(funTable, "fun("..j..", ...) ")
	end
	table.insert(funTable, funEnd)
	return loadstring(table.concat(funTable))()
end

-- extend metatable with newindex
local unrollMT = {}
function unrollMT.__index(self, k)
	self[k] = construct(k)
	return self[k]
end
setmetatable(unroll, unrollMT)

--testcase:
--[[
unroll[34](
function(i, a)
	print(i.."+"..a.."="..(i+a))
end
, 6)
--]]

return unroll