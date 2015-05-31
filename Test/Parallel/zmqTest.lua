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
local zmq = require("Test.Parallel.zmq")

local thread = [[
	local ffi = require("ffi")
	local sdl = require("Include.sdl2")
	local lua = require("Test.Parallel.luatools")
	local zmq = require("Test.Parallel.zmq")
	
	local pull
	
	local function setup(ptr)
		zmq.ctx.set(ptr)
		pull = zmq.socket.new(zmq.PULL)
		push = zmq.socket.new(zmq.PUSH)
		pull:connect("inproc://test1")
		push:connect("inproc://test2")
		
		return 0
	end
	
	local function run(ptr)
		local data = ffi.new("double[1]")
		while true do
			pull:recv(data, 8)
			data[0] = - data[0]
			push:send(data, 8)
		end
		
		return 0
	end
	
	__setupPtr = lua.toFunPtr(setup)
	__runPtr = lua.toFunPtr(run)
	
]]

-- zmq setup
print(zmq.version())
zmq.ctx.new()

local push = zmq.socket.new(zmq.PUSH)
local pull = zmq.socket.new(zmq.PULL)

push:bind("inproc://test1")
pull:bind("inproc://test2")
local data = ffi.new("double[1]", 12345)

--lua setup
sdl.tic()
local th = {}
for i = 1, 16 do
	th[i] = lua.new()
	lua.run(th[i], thread)
	lua.pushNumber(th[i], i, "__thread_number")
	
	lua.fromFunPtr(th[i], "__setupPtr")(zmq.context)
	sdl.thread.new(lua.fromFunPtr(th[i], "__runPtr"), nil)
end
sdl.toc()

sdl.tic()
for i = 1, 1000000/512 do
	for j = 1, 512 do
		data[0] = i*512-512+j
		push:send(data, 8)
	end
	--io.write("send:"..i.."/\n")
	for j = 1, 512 do
		pull:recv(data, 8)
		--io.write(data[0].."\n")
	end
end
sdl.toc()

-- need to shut down threads using sockets for proper cleanup
--[[
push:close()
pull:close()
zmq.ctx.term()
--]]

print("Done!")


