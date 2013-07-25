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

local dbg = require("dbgtools")
local img = __img

--node creation
local nodeTable
local function add(self, typeName)
	local n
	if nodeTable[typeName] then n = nodeTable[typeName](self) end
	-- assign random location to nodes, will eventually be removed:
	n.ui.x=100 + math.random(__global.setup.windowSize[1]-400)
	n.ui.y=100 + math.random(__global.setup.windowSize[2]-200)
	if typeName=="Input" then
		n.ui.x=100
		n.ui.y=__global.setup.windowSize[2]/2
		-- remove close button
		n.ui.noClose = true
	end
	if typeName=="Output" then
		n.ui.x=__global.setup.windowSize[1]-400
		n.ui.y=__global.setup.windowSize[2]/2
		-- remove close button
		n.ui.noClose = true
	end
end

local function setup(n, i)
	n.add = add
	nodeTable = require("nodeDefine")
end


return setup
