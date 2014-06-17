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
local sdl = require("Include.sdl")

-- TODO: fix definitions to be minimal and not overlaping with others!

local l = {}

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
	ffi.C.lua_getfield(state, LUA_GLOBALSINDEX, name);
	return ffi.C.lua_tointeger(state, -1);
end
function l.doString(state, str)
	assert(ffi.C.luaL_loadstring(state, str)==0)
	assert(ffi.C.lua_call(state, 0, 0)==0)
end
function l.newState()
	local state = ffi.C.luaL_newstate()
	ffi.C.luaL_openlibs(state)
	return state
end
function l.closeState(state)
	ffi.C.lua_close(state)
end

local typedefs = [[
	typedef int (*threadCB)(void*);
	typedef struct{
		SDL_sem *write;
		SDL_sem *read;
		double v;
	}chStruct;
	typedef struct{
		SDL_sem *write;
		SDL_sem *read;
		double *v;	// pointer to data
		int n;		// total length
		int r;		// read location
		int w;		// write location
	}chStructBuf;
	typedef int (*chFun)(chStruct*, const char*);
]]

ffi.cdef(typedefs)

local threadString = [=[
	local ffi = require("ffi")
	local sdl = require("Include.sdl")
	ffi.cdef[[ ]=]..typedefs..[=[ ]]
	
	local function funptr(fun, funtype)
		return tonumber(ffi.cast("intptr_t", ffi.cast(funtype or "threadCB", fun)))
	end
	
	local function channel(chStruct)
		local o = {}
		local c
		if chStruct then
			c = chStruct
		else
			print("new channel")
			c = ffi.new("chStruct")
			c.write = sdl.thread.sem(0)
			c.read = sdl.thread.sem(1)
		end
		
		function o:push(i)
			sdl.thread.semWait(c.read)
			c.v = i
			sdl.thread.semPost(c.write)
		end
		function o:pull()
			sdl.thread.semWait(c.write)
			local t = c.v
			sdl.thread.semPost(c.read)
			return t
		end
		function o:struct() return c end
		return o
	end
	
	local chList = {}
	local function getCh(ptr, name)
		local ch = ffi.cast("chStruct*", ptr)
		chList[ffi.string(name)] = channel(ch[0])
		return 0
	end
	__getCh = funptr(getCh, "chFun")
	
	
	local function run(p)
		print("running...")
		local n = 0
		while true do
			chList.ch:push(n)
			n = n + 1
		end
		return 0
	end
	__run = funptr(run)
	
	print("initialized", __run)
]=]


local function funptr(state, ptr, funtype)
	return ffi.cast(funtype or "threadCB", l.getPointer(state, ptr))
end

local function channel(chStruct)
	local o = {}
	local c
	if chStruct then
		c = chStruct
	else
		c = ffi.new("chStruct")
		c.write = sdl.thread.sem(0)
		c.read = sdl.thread.sem(1)
	end
	
	function o:push(i)
		sdl.thread.semWait(c.read)
		c.v = i
		sdl.thread.semPost(c.write)
	end
	function o:pull()
		sdl.thread.semWait(c.write)
		local t = c.v
		sdl.thread.semPost(c.read)
		return t
	end
	function o:peek() return c.v end
	function o:struct() return c end
	return o
end

local function channelBuf(chStruct)
	local length
	if type(chStruct)=="number" then
		length = chStruct
		chStruct = nil
	end
	
	local o = {}
	local c
	if chStruct then
		c = chStruct
	else
		c = ffi.new("chStructBuf")
		c.write = sdl.thread.sem(0)
		c.read = sdl.thread.sem(length)
		c.v = ffi.new("double[?]", length)
		c.n = length
		c.r = 0
		c.w = 0
	end
	
	function o:push(i)
		sdl.thread.semWait(c.read)
		c.v[c.w] = i
		c.w = c.w + 1
		if c.w==c.n then c.w = 0 end
		sdl.thread.semPost(c.write)
	end
	function o:pull()
		sdl.thread.semWait(c.write)
		local t = c.v[c.r]
		c.r = c.r + 1
		if c.r==c.n then c.r = 0 end
		sdl.thread.semPost(c.read)
		return t
	end
	function o:peek(n) return c.v[n or c.r] end
	function o:struct() return c end
	return o
end

-- testing
local ch = channel()

local th = l.newState()
l.doString(th, threadString)
local thRun = funptr(th, "__run")
local chPass = funptr(th, "__getCh", "chFun")
chPass(ch:struct(), "ch")
sdl.thread.new(thRun, nil)

local th = l.newState()
l.doString(th, threadString)
local thRun = funptr(th, "__run")
local chPass = funptr(th, "__getCh", "chFun")
chPass(ch:struct(), "ch")
sdl.thread.new(thRun, nil)

print(ch:pull(), "yay")
print(ch:pull(), ".")
print(ch:pull(), ".")
print(ch:pull(), ".")

--[[
local t = sdl.time()
for j = 1, 100000 do
	print(ch:pull())
end
print( ((sdl.time()-t)/100000).."ms" )
--]]

print("done!")
