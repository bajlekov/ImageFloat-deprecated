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


-- helper files for parallel communication and execution
-- implements: parallel environments, synchronisation and communication

local ffi = require("ffi")
local sdl = require("Include.sdl2")
local lua = require("Test.Parallel.luatools")
local chan = require("Test.Parallel.chantools")

local thread = [[
	local ffi = require("ffi")
	local sdl = require("Include.sdl2")
	local lua = require("Test.Parallel.luatools")
	local chan = require("Test.Parallel.chantools")
	
	local function run(p)
		print("running...")
		local t = ffi.typeof("double[1]")
		local nOld
		for i = 1, 10000 do
			local n = t(i)
			chan.chList.ch1:push(n)
			nOld = n
		end
		print("...done sending")
		return 0
	end
	
	global("__runPtr")
	__runPtr = lua.toFunPtr(run)

	print("initialized")
]]

local ch = chan.new("ptr", "ch1")

local th = {}
for i = 1, 25 do
	th[i] = lua.new()
	lua.run(th[i], thread)
	local thRun = lua.fromFunPtr(th[i], "__runPtr")
	chan.register(th[i], "ch1")
	sdl.thread.new(thRun, nil)
end

for i = 1, 10000*25 do
	--print(ffi.cast("double*", ch:pull())[0], i)
	ch:pull()
end
print("...done receiving")