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
local lua = require("Test.Parallel.luatools")
local sdl = require("Include.sdl2")
require("global")

ffi.cdef [[
	typedef struct{
		SDL_sem *write;
		SDL_sem *read;
		double v;
	} numChStruct;
	typedef struct{
		SDL_sem *write;
		SDL_sem *read;
		void *v;
	} ptrChStruct;
	typedef struct{
		SDL_sem *write;
		SDL_sem *read;
		double *v;	// pointer to data
		int n;		// total length
		int r;		// read location
		int w;		// write location
	} bufChStruct;
	typedef int (*numChFun)(numChStruct*, const char*);
	typedef int (*ptrChFun)(ptrChStruct*, const char*);
	typedef int (*bufChFun)(bufChStruct*, const char*);
	typedef int (*ptrFun)(void*, const char*);
]]

local ptrChStruct = ffi.typeof("ptrChStruct")
local numChStruct = ffi.typeof("numChStruct")
local bufChStruct = ffi.typeof("bufChStruct")

local ptrChStructAddr = ffi.typeof("ptrChStruct &")
local numChStructAddr = ffi.typeof("numChStruct &")
local bufChStructAddr = ffi.typeof("bufChStruct &")

-- channel passing doubles
local function numChannel(chStruct)
	local o = {__type="num"}
	local c
	if chStruct then
		assert(ffi.typeof(chStruct)==numChStruct or ffi.typeof(chStruct)==numChStructAddr)
		c = chStruct
	else
		-- root semaphores
		o.__write = sdl.thread.sem(0)
		o.__read = sdl.thread.sem(1)
		c = numChStruct(o.__write, o.__read)
	end
	
	function o:push(i)
		sdl.thread.sWait(c.read)
		c.v = i
		sdl.thread.sPost(c.write)
	end
	function o:pull()
		sdl.thread.sWait(c.write)
		local t = c.v
		sdl.thread.sPost(c.read)
		return t
	end
	function o:peek() return c.v end
	function o:struct() return c end
	return o
end

-- channel passing void pointers
local function ptrChannel(chStruct)
	
	local o = {__type="ptr"}
	local c
	if chStruct then
		assert(ffi.typeof(chStruct)==ptrChStruct  or ffi.typeof(chStruct)==ptrChStructAddr)
		c = chStruct
	else
		-- root semaphores
		o.__write = sdl.thread.sem(0)
		o.__read = sdl.thread.sem(1)
		c = ptrChStruct(o.__write, o.__read)
	end
	
	function o:push(i)
		sdl.thread.sWait(c.read)
		c.v = i
		sdl.thread.sPost(c.write)
	end
	function o:pull()
		sdl.thread.sWait(c.write)
		local t = c.v
		sdl.thread.sPost(c.read)
		return t
	end
	function o:peek() return c.v end
	function o:struct() return c end
	return o
end

-- buffered channel passing doubles (buffering is difficult with garbage-collected pointers)
local function bufChannel(chStruct)
	local length
	if type(chStruct)=="number" then
		length = chStruct
		chStruct = nil
	end
	
	local o = {__type="buf"}
	local c
	if chStruct then
		assert(ffi.typeof(chStruct)==bufChStruct or ffi.typeof(chStruct)==bufChStructAddr)
		c = chStruct
	else
		-- root garbage-collected entries
		o.__write = sdl.thread.sem(0)
		o.__read = sdl.thread.sem(length)
		o.__v = ffi.new("double[?]", length)
		
		c = bufChStruct()
		c.write = o.__write
		c.read = o.__read
		c.v = o.__v
		c.n = length
		c.r = 0
		c.w = 0
	end
	
	function o:push(i)
		sdl.thread.sWait(c.read)
		c.v[c.w] = i
		c.w = c.w + 1
		if c.w==c.n then c.w = 0 end
		sdl.thread.sPost(c.write)
	end
	function o:pull()
		sdl.thread.sWait(c.write)
		local t = c.v[c.r]
		c.r = c.r + 1
		if c.r==c.n then c.r = 0 end
		sdl.thread.sPost(c.read)
		return t
	end
	function o:peek(n) return c.v[n or c.r] end
	function o:struct() return c end
	return o
end

local chList = {}
local function getNumCh(ptr, name)
	local ch = ffi.cast("numChStruct*", ptr)
	chList[ffi.string(name)] = numChannel(ch[0])
	return 0
end
global("__getNumCh")
__getNumCh = lua.toFunPtr(getNumCh, "numChFun")
local function getPtrCh(ptr, name)
	local ch = ffi.cast("ptrChStruct*", ptr)
	chList[ffi.string(name)] = ptrChannel(ch[0])
	return 0
end
global("__getPtrCh")
__getPtrCh = lua.toFunPtr(getPtrCh, "ptrChFun")
local function getBufCh(ptr, name)
	local ch = ffi.cast("bufChStruct*", ptr)
	chList[ffi.string(name)] = ptrChannel(ch[0])
	return 0
end
global("__getBufCh")
__getPtrCh = lua.toFunPtr(getPtrCh, "bufChFun")

local ptrList = {}
local function getPtr(ptr, name)
	ptrList[ffi.string(name)] = ptr
	return 0
end
global("__getPtr")
__getPtrCh = lua.toFunPtr(getPtrCh, "ptrFun")


-- channel API
local ch = {}

-- create channels
function ch.new(__type, __name, size)
	assert(type(__type)=="string")
	assert(type(__name)=="string")
	
	local ch
	if __type=="num" then
		ch = numChannel()
	elseif __type=="ptr" then
		ch = ptrChannel()
	elseif __type=="buf" then
		assert(type(size)=="number" and size>0, "incorrect size")
		ch = bufChannel(size)
	else
		error("incorrect buffer type")
	end
	chList[__name] = ch
	return ch
end

function ch.toChan(struct, __name)
	assert(type(__name)=="string")
	
	local ch
	if ffi.typeof(struct)=="numChStruct" then
		ch = numChannel(struct)
	elseif ffi.typeof(struct)=="ptrChStruct" then
		ch = ptrChannel(struct)
	elseif ffi.typeof(struct)=="bufChStruct" then
		ch = bufChannel(struct)
	else
		error("incorrect buffer struct")
	end
	chList[__name] = ch
	return ch
end

-- pass channels to threads (register)
function ch.register(thread, __name)
	assert(type(__name)=="string")
	assert(thread) -- TODO: check for lua instance
	local ch = chList[__name]
	assert(ch, "Channel not found")
	assert(type(ch.__type)=="string")
	
	if ch.__type=="num" then
		assert(lua.fromFunPtr(thread, "__getNumCh", "numChFun")(ch:struct(), __name)==0)
	elseif ch.__type=="ptr" then
		assert(lua.fromFunPtr(thread, "__getPtrCh", "ptrChFun")(ch:struct(), __name)==0)
	elseif ch.__type=="buf" then
		assert(lua.fromFunPtr(thread, "__getBufCh", "bufChFun")(ch:struct(), __name)==0)
	else
		error("incorrect channel name")
	end
end

ch.chList = chList
ch.ptrList = ptrList

return ch