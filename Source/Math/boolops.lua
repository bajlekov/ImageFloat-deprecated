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

local coll = {}

-- collects items from a list in a collection, if a collection is specified then items are added
function coll.collect(t, u)
	u = u or {}
	for k, v in ipairs(t) do
		u[v] = true
	end
	return u
end

-- put items from a collection in a list
function coll.list(t, u)
	u = u or {}
	for k, v in pairs(t) do
		table.insert(u, k)
	end
	return u
end

function coll.new(min, max)
	local u = {}
	for i = min, max do
		u[i] = true
	end
	return u
end

-- collects items in a and NOT in b
function coll.cNot(a, b)
	for k, v in pairs(b) do
		a[k]=nil
	end
	return a
end

-- collects only items in both a AND b
function coll.cAnd(a, b)
	local u = {}
	for k, v in pairs(a) do
		u[k] = b[k] and true or nil
	end
	return u
end

-- collects only items in any a OR b
function coll.cOr(a, b)
	local u = {}
	for k, v in pairs(a) do
		u[k] = true
	end
	for k, v in pairs(b) do
		u[k] = true
	end
	return u
end

return coll