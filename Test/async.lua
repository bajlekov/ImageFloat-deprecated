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

-- create functions for asynchronous reading and writing of data to files

--TODO: asynchronous communication through named pipes -> implement async write to/read from pipes

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

-- known size, passing file handles!

-- disk writing funcs
-- disk io native C functions
ffi.cdef[[
	struct _IO_FILE;
	typedef struct _IO_FILE FILE;
	size_t fread ( void * ptr, size_t size, size_t count, FILE * stream );
	size_t fwrite ( const void * ptr, size_t size, size_t count, FILE * stream );
]]

local function diskread(mptr, length, fptr)
	ffi.C.fread(mptr, 1, length, fptr)
end
local function diskwrite(mptr, length, fptr)
	ffi.C.fwrite(mptr, 1, length, fptr)
end

-- format: [Xdim:int32, Ydim:in32, Zdim:int32, bits:int32, data:bits...]

local buf = {}
buf.x = 320
buf.y = 240
buf.z = 3
buf.data = ffi.new("float[?]", buf.x*buf.y*buf.z, 0)
for i = 0, 100 do
	buf.data[i] = i
end

local intSize = ffi.sizeof("int")
local function toDiskSync(buf, fname)
	local f = io.open(fname, "w")
	local header = ffi.new("int[4]", buf.x, buf.y, buf.z, 32)
	diskwrite(header, intSize*4, f)
	diskwrite(buf.data, buf.x*buf.y*buf.z*4, f)
	f:close()
	return fname
end

local function fromDiskSync(buf, fname)
	buf = buf or {}
	if not fname then buf, fname = {}, buf end
	local f = io.open(fname, "r")
	local header = ffi.new("int[4]")
	diskread(header, intSize*4, f)
	buf.x = header[0]
	buf.y = header[1]
	buf.z = header[2]
	buf.data = ffi.new("float[?]", buf.x*buf.y*buf.z)
	diskread(buf.data, buf.x*buf.y*buf.z*4, f)
	f:close()
	return buf
end

-- threaded code
local workerCode = [==[
	local ffi = require("ffi")
	
	ffi.cdef[[
		struct _IO_FILE;
		typedef struct _IO_FILE FILE;
		size_t fread ( void * ptr, size_t size, size_t count, FILE * stream );
		size_t fwrite ( const void * ptr, size_t size, size_t count, FILE * stream );
		
		typedef struct diskParams {
		   void* mptr;
		   int length;
		   FILE* fptr;
		} diskParams;
		
		typedef int (*diskOps)(diskParams*);
	]]	
	
	local function diskread(p)
		return ffi.C.fread(p.mptr, 1, p.length, p.fptr)
	end
	local function diskwrite(p)
		return ffi.C.fwrite(p.mptr, 1, p.length, p.fptr)
	end
	
	diskreadptr = tonumber(ffi.cast("intptr_t",ffi.cast("diskOps", diskread)))
	diskwriteptr = tonumber(ffi.cast("intptr_t",ffi.cast("diskOps", diskwrite)))
]==]

ffi.cdef[[
	typedef struct diskParams {
	   void* mptr;
	   int length;
	   FILE* fptr;
	} diskParams;
]]

ffi.cdef("typedef int (*diskOps)(diskParams*)")
local thread = l.newState()
l.doString(thread,workerCode)
local drthread = ffi.cast("diskOps", l.getPointer(thread, "diskreadptr"))
local dwthread = ffi.cast("diskOps", l.getPointer(thread, "diskwriteptr"))
local diskParams = ffi.typeof("struct diskParams")

local diskBusy = false
local fileHandle
local function diskWait()
	if diskBusy then
		sdl.thread.wait(diskBusy)
		fileHandle:close()
	end
	diskBusy = false
end

local function toDiskAsync(buf, fname)
	if diskBusy then diskWait() end
	fileHandle = io.open(fname, "w")
	local header = ffi.new("int[4]", buf.x, buf.y, buf.z, 32)
	diskwrite(header, intSize*4, fileHandle)
	diskBusy = sdl.thread.new(dwthread,
		diskParams(buf.data, buf.x*buf.y*buf.z*4, fileHandle))
	return fname
end

local function fromDiskAsync(buf, fname)
	buf = buf or {}
	if not fname then buf, fname = {}, buf end

	if diskBusy then diskWait() end
	fileHandle = io.open(fname, "r")
	local header = ffi.new("int[4]")
	diskread(header, intSize*4, fileHandle)
	buf.x = header[0]
	buf.y = header[1]
	buf.z = header[2]
	buf.data = ffi.new("float[?]", buf.x*buf.y*buf.z)
	diskBusy = sdl.thread.new(drthread,
		diskParams(buf.data, buf.x*buf.y*buf.z*4, fileHandle))
	return buf
end
