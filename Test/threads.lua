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
local sdl = require("Include.sdl")

local l = {}
local lua = ffi.C -- no need to load lua library as it's already included in the C space

ffi.cdef([[
	typedef struct lua_State lua_State;
	typedef double lua_Number;

	lua_State *luaL_newstate();
	void luaL_openlibs(lua_State *L);
	int luaL_loadstring(lua_State *L, const char *s);
	int lua_call(lua_State *L, int nargs, int nresults);
	void lua_close(lua_State *L);
	void lua_getfield(lua_State *L, int idx, const char *k);

	// get pointer/number from stack
	ptrdiff_t lua_tointeger(lua_State *L, int index);
]])

local LUA_GLOBALSINDEX = -10002

function l.getPointer(state, name)
	lua.lua_getfield(state, LUA_GLOBALSINDEX, name);
	return ffi.C.lua_tointeger(state, -1);
end

function l.doString(state, str)
	assert(lua.luaL_loadstring(state, str)==0)
	assert(lua.lua_call(state, 0, 0)==0)
end

function l.newState()
	local state = lua.luaL_newstate()
	lua.luaL_openlibs(state)
	return state
end

function l.closeState(state)
	lua.lua_close(state)
end

-- test thread creation with SDL and the lua FFI/C-api alone

--[[ IDEA:
- data transfer between instances through cdata pointers
	- set up communication through ffi callbacks instead of C-api
	- callbacks with parameters convertable to C
		- introduce C-struct for buffer passing
		- watch out for scope of passed data, pointers should always be bound by the host!
	- setting operations needs to be performed through strings, which is messy in C
		- ...not with callbacks, rely on automatic lua to C to lua conversion

- classic C-api is only used for initial thread management
- ffi is used throughout for data passing
- limited use of callbacks for certain functions??
	- limited availability of callbacks, keep track of callbacks!
	- keep track of which function belongs to which thread...
	- restructure threads to effectively use callbacks
		- use callbacks only for setup
		- use flags and arrays for transfer of information
		- if callbacks are problematic then loop over variable till flag is set to start processing
- reverse callback for getting next job when one step is done
--]]

-- example of passing function pointers to threads and calling them
-- threaded calling using SDL

local s = {}
local f = {}

local nt = 8 -- more than 4 threads becomes much slower (0.01ms startup per thread for 4 threads)
--up to 8 threads perform useful work with 0.25ms overhead

local str = [===[
	local ffi = require("ffi")
	ffi.cdef[[
		typedef int (*threadCB)(void*);
		typedef void (*getstring)(const char*);
	]]
	
	local function loop(i)
		--do something
		local a = 1
		for i = 1, ffi.cast("double*",i)[0] do
			a = a * i
		end
		return a
		--return 0
	end
	ll = tonumber(ffi.cast("intptr_t",ffi.cast("threadCB", loop)))
	
	local function getString(str)
		print(ffi.string(str))
	end
	mm = tonumber(ffi.cast("intptr_t",ffi.cast("getstring", getString)))
	print(mm)
]===]

ffi.cdef[[
	typedef int (*threadCB)(void*);
	typedef void (*getstring)(const char*);
]]

sdl.tic()
for i = 1, nt do
	s[i] = l.newState()
	l.doString(s[i], str)
	f[i] = ffi.cast("threadCB", l.getPointer(s[i], "ll"))
end
sdl.toc()

local p = ffi.new("double[1]")
p[0]=1234567

local t = sdl.time()
local th = {}

for j = 1, 1000 do
	for i=1,nt do
		th[i] = sdl.thread.new(f[i], p)
	end
	for i=1,32 do
		sdl.thread.wait(th[i])
	end
end

print( ((sdl.time()-t)/1000).."ms" )

local mm = l.getPointer(s[1], "mm")
print(mm)
local getstring = ffi.cast("getstring", mm)

getstring("abcde random text \n\tlalala")

-- test C-api number passing vs callback number passing vs shared memory allocation

for i = 1, nt do
	l.closeState(s[i])
end
print("end...")

--[[

TODO:
- set up structures for buffer passing
	[bufnum, buf1addr, buf1x, buf1y, buf1z, buf2addr, buf2x, buf2y, buf2z ...]
- params passing:
	[paramnum, param1, param2, ...] no support for non-numeric params
- automatically update information without callbacks
- resizing buffers vs callback/C-api call??
	- no constant resizing, only when needed...similar to table array part resizing
	- no cleanup either, leave garbage in place
	- check for location consistency after resize!!!!!!!!

- still a mix between classic API and callbacks for setup of buffer locations

--]]
