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

local ffi = require("ffi")

local lua = {}

ffi.cdef([[
	typedef struct lua_State lua_State;
	typedef double lua_Number;
	
	lua_State *luaL_newstate();
	void luaL_openlibs(lua_State *L);
	int luaL_loadstring(lua_State *L, const char *s);
	int lua_call(lua_State *L, int nargs, int nresults);
	void lua_close(lua_State *L);
	void lua_setfield(lua_State *L, int idx, const char *k);
	void lua_getfield(lua_State *L, int idx, const char *k);
	
	// get pointer/number from stack
	ptrdiff_t lua_tointeger(lua_State *L, int index);
	
	void lua_pushnumber(lua_State *L, lua_Number n);
	
	typedef int (*threadCB)(void*);
]])

local LUA_GLOBALSINDEX = -10002

-- get pointer to global variable
function lua.getPointer(state, name)
	ffi.C.lua_getfield(state, LUA_GLOBALSINDEX, name);
	return ffi.C.lua_tointeger(state, -1);
end

-- run string on external lua thread
function lua.run(state, str)
	assert(ffi.C.luaL_loadstring(state, str)==0)
	assert(ffi.C.lua_call(state, 0, 0)==0)
end

-- close state
function lua.close(state)
	ffi.C.lua_close(ffi.gc(state, nil))
end

-- create new state
function lua.new()
	local state = ffi.C.luaL_newstate()
	ffi.C.luaL_openlibs(state)
	return ffi.gc(state, ffi.C.lua_close)
end


-- get pointer from external lua thread
function lua.fromFunPtr(state, ptr, funtype)
	return ffi.cast(funtype or "threadCB", lua.getPointer(state, ptr))
end

function lua.toFunPtr(fun, funtype)
	return tonumber(ffi.cast("intptr_t", ffi.cast(funtype or "threadCB", fun)))
end

function lua.pushNumber(state, num, name)
	ffi.C.lua_pushnumber(state, num);
	ffi.C.lua_setfield(state, LUA_GLOBALSINDEX, name);
end

return lua