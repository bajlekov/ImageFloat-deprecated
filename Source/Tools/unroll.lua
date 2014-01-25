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
	if k>4096 then
		return function(fun, ...)
			for i = 0, k-1 do
				fun(i, ...)
			end
		end
	elseif k>0 then
		self[k] = construct(k)
		return self[k]
	end
	error("Wrong loop length:"..k)
end
setmetatable(unroll, unrollMT)


-- add functions for multidimensional unrolling
unroll.construct1 = function(i1, i2)
  local funTable = {}
  table.insert(funTable, funStart)
  for i = i1, i2 do
    table.insert(funTable, "fun("..i..", ...) ")
  end
  table.insert(funTable, funEnd)
  return loadstring(table.concat(funTable))()
end

unroll.construct2 = function(i1, i2, j1, j2)
  local funTable = {}
  table.insert(funTable, funStart)
  for i = i1, i2 do
    for j = j1, j2 do
      table.insert(funTable, "fun("..i..","..j..", ...) ")
    end
  end
  table.insert(funTable, funEnd)
  return loadstring(table.concat(funTable))()
end

unroll.construct3 = function(i1, i2, j1, j2, k1, k2)
  local funTable = {}
  table.insert(funTable, funStart)
  for i = i1, i2 do
    for j = j1, j2 do
      for k = k1, k2 do
        table.insert(funTable, "fun("..i..","..j..","..k..", ...) ")
      end
    end
  end
  table.insert(funTable, funEnd)
  return loadstring(table.concat(funTable))()
end

unroll.construct4 = function(i1, i2, j1, j2, k1, k2, l1, l2)
  local funTable = {}
  table.insert(funTable, funStart)
  for i = i1, i2 do
    for j = j1, j2 do
      for k = k1, k2 do
        for l = l1, l2 do
          table.insert(funTable, "fun("..i..","..j..","..k..","..l..", ...) ")
        end
      end
    end
  end
  table.insert(funTable, funEnd)
  return loadstring(table.concat(funTable))()
end

function unroll.construct(i1, i2, j1, j2, k1, k2, l1, l2)
  if      l1 and l2 then return unroll.construct4(i1,i2,j1,j2,k1,k2,l1,l2)
  elseif  k1 and k2 then return unroll.construct3(i1,i2,j1,j2,k1,k2)
  elseif  j1 and j2 then return unroll.construct2(i1,i2,j1,j2)
  elseif  i1 and j1 then return unroll.construct1(i1,i2)
  else
    error("insufficient parameters")
  end
end

--testcase:
--[[
unroll[34](
function(i, a)
	print(i.."+"..a.."="..(i+a))
end
, 6)
--]]

return unroll