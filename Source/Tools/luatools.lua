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
local lua

--TODO: use loadlib!
if ffi.os == "Linux" then lua = ffi.load(__global.libPath.."libluajit.so") end
if ffi.os == "Windows" then lua = ffi.load("lua51.dll") end

ffi.cdef([[
	typedef struct lua_State lua_State;
	typedef double lua_Number;

	lua_State *luaL_newstate();
	void luaL_openlibs(lua_State *L);
	int luaL_loadfile(lua_State *L, const char *filename);
	int luaL_loadstring(lua_State *L, const char *s);
	int lua_call(lua_State *L, int nargs, int nresults);
	int lua_pcall(lua_State *L, int nargs, int nresults, int errfunc);
	void lua_close(lua_State *L);
	void lua_pushlightuserdata(lua_State *L, void *p);
	void lua_pushnumber(lua_State *L, lua_Number n);
	void lua_pushstring(lua_State *L, const char *s);
	void lua_setfield(lua_State *L, int idx, const char *k);
	void lua_getfield(lua_State *L, int idx, const char *k);
	void lua_createtable(lua_State *L, int narr, int nrec);
	void lua_settable(lua_State *L, int idx);

	int luaopen_base(lua_State *L);
	int luaopen_math(lua_State *L);
	int luaopen_string(lua_State *L);
	int luaopen_table(lua_State *L);
	int luaopen_io(lua_State *L);
	int luaopen_os(lua_State *L);
	int luaopen_package(lua_State *L);
	int luaopen_debug(lua_State *L);
	int luaopen_bit(lua_State *L);
	int luaopen_jit(lua_State *L);
	int luaopen_ffi(lua_State *L);
	
	// get stack size
	int lua_gettop (lua_State *L);
	// set stack position (0 = clean)
	void lua_settop (lua_State *L, int index);
]])

local l = {}
local LUA_GLOBALSINDEX = -10002

function l.pushNumber(state, num, name)
	lua.lua_pushnumber(state, num);
	lua.lua_setfield(state, LUA_GLOBALSINDEX, name);
end

function l.pushUserData(state, data, name)
	lua.lua_pushlightuserdata(state, data);
	lua.lua_setfield(state, LUA_GLOBALSINDEX, name);
end

local function lua_setfield(state, key, value)
	if type(key)=="string" then
		lua.lua_pushstring(state, key)
	else
		lua.lua_pushnumber(state, key)
	end
	lua.lua_pushnumber(state, value)
	lua.lua_settable(state, -3)
end

function l.pushTable(state, table, name)
	lua.lua_createtable(state, 0, 0);
	for k, v in pairs(table) do
		lua_setfield(state, k, v)
	end
	lua.lua_setfield(state, LUA_GLOBALSINDEX, name);
end
function l.pushITable(state, table, name)
	lua.lua_createtable(state, 0, 0);
	for k, v in ipairs(table) do
		lua_setfield(state, k, v)
	end
	lua.lua_setfield(state, LUA_GLOBALSINDEX, name);
end

function l.pushMultiple(state, t)
	for k, v in pairs(t) do
		if type(v)=="number" then l.pushNumber(state, v, k)
		elseif type(v)=="cdata" then l.pushUserData(state, v, k)
		elseif type(v)=="table" then l.pushTable(state, v, k)
		else print("wrong input") end
	end
end

function l.doFile(state, file)
	assert(lua.luaL_loadfile(state, file)==0)
	assert(lua.lua_call(state, 0, 0)==0)
end

function l.doString(state, str)
	assert(lua.luaL_loadstring(state, str)==0)
	assert(lua.lua_call(state, 0, 0)==0)
end

function l.doFunction(state, name)
	-- NYI: bytecode 63 at luatools.lua:118
	lua.lua_getfield(state, LUA_GLOBALSINDEX, name)
	assert(lua.lua_call(state, 0, 0)==0)
end

-- function indexing multiple levels of global table "name" with vararg keys
function l.loadVariable(state, name, ...)
	lua.lua_getfield(state, LUA_GLOBALSINDEX, name)
	local n = select("#", ...)
	if n>0 then
		for k = 1, n do
			local v = select(k, ...)
			lua.lua_getfield(state, -1, v)
		end
	end
end

function l.loadVariable(state, name, t)
	lua.lua_getfield(state, LUA_GLOBALSINDEX, name)
	local n = #t
	if n>0 then
		for k = 1, n do
			local v = t[k]
			lua.lua_getfield(state, -1, v)
		end
	end
end

function l.newState()
	local state = lua.luaL_newstate()
	--FIXME: error with luajit 2.1
	lua.luaL_openlibs(state)
	return state
end

function l.closeState(state)
	lua.lua_close(state)
end

--[[
os.execute("gcc -O3 -shared -fomit-frame-pointer -fPIC -o lib/Linux_x64/libthread.so thread.c -L. -lSDL")
os.execute("gcc -m32 -O3 -shared -fomit-frame-pointer -o lib/Linux_x32/libthread.so thread.c -L. -lSDL")
os.execute("i586-mingw32msvc-gcc -O3 -shared -fomit-frame-pointer -o lib/Windows_x32/thread.dll thread.c -L. -llua51 -lsdl")

gcc -O3 -shared -fomit-frame-pointer -fPIC -o thread.dll thread.c -L ./../ -llua51
--]]
--os.execute("gcc -O3 -shared -fomit-frame-pointer -fPIC -o ../Libraries/Linux_x64/libthread.so ./Threads/thread.c -L. -lSDL")
--print("!!!!!!!!! COMPILE THREAD CALLER FOR ALL PLATFORMS !!!!!!!!")
-- in a pinch, create independently running threads, and use flags to signal start/end of processing

if type(__sdl)=="table" then
	local p, th
	--if ffi.os == "Linux" then p, th = pcall(ffi.load, __global.libPath.."libthread.so") end
	--if ffi.os == "Windows" then p, th = pcall(ffi.load, __global.libPath.."thread.dll") end
  p, th = pcall(loadlib, "thread")

	if p then

		-- lua thread table
		ffi.cdef([[
			lua_State* L[65]; //lua states
			
			int lua_thread_call(void* in); //lua threaded function

			int arg_in;
			int arg_out;
		]])

		--multithreading helper functions:
		l.threadRunning = false
		l.threadFunction = th.lua_thread_call
		l.threadInstance = th.L
		function l.threadArgIn(n) th.arg_in = n end		-- not used
		function l.threadArgOut(n) th.arg_out = n end	-- not used

		function l.threadInit(n, file)	--number of threads, file to load in new instances
			l.numCores = n -- #number
			l.threadCounter = ffi.new("int[?]", n)
			for i = 0, n-1 do l.threadCounter[i]=i end
			print("using "..l.numCores.." threads...")
			l.threadProgress = ffi.new("int[?]", l.numCores+4) -- TH states... , abort, sync, ?, ?
			l.threadProgress[l.numCores+1]=1 
			l.mutex = __sdl.thread.mutex()
			for i=0, l.numCores-1 do
				l.threadInstance[i]=l.newState()						--create new state
				l.doFile(l.threadInstance[i], file)						--load functions
				l.pushNumber(l.threadInstance[i], i, "__instance")		-- assign instance number to state
				l.pushNumber(l.threadInstance[i], l.numCores, "__tmax")	-- max number of cores
				l.pushUserData(l.threadInstance[i], l.threadProgress, "__progress")		--progress state
				l.pushUserData(l.threadInstance[i], l.mutex, "__mut")
				l.doFunction(l.threadInstance[i], "__init")				--set up general comm structures
			end
		end
		function l.threadQuit()
			for i=0, l.numCores-1 do
				l.closeState(l.threadInstance[i])
			end
			--__sdl.destroyMutex(th.mut)
		end

		function l.threadPushMultiple(t)
			for i = 0, l.numCores-1 do
				l.pushMultiple(l.threadInstance[i], t)
			end
		end
		function l.threadPushNumber(v, n)
			for i = 0, l.numCores-1 do
				l.pushNumber(l.threadInstance[i], v, n)
			end
		end
		function l.threadPushTable(t, n)
			for i = 0, l.numCores-1 do
				l.pushTable(l.threadInstance[i], t, n)
			end
		end
		function l.threadPushITable(t, n)
			for i = 0, l.numCores-1 do
				l.pushITable(l.threadInstance[i], t, n)
			end
		end

		--keep reference to passed data!
		local buffersData
		function l.threadPushBuffers(t)
			buffersData = ffi.new("void*[?]", #t+1)
			for k, v in ipairs(t) do
				buffersData[k] = v.data
			end
			for i = 0, l.numCores-1 do
				l.pushUserData(l.threadInstance[i], buffersData, "__bufs")
			end
		end

		do
			local sdl = __sdl
			local thread = {}
			local procTime = sdl.time()
			local loopTime = sdl.time()
			local procName
			function l.threadSetup(buflist, params)
				local bufs = {}
				local dims = {} -- x1, y1, z1, x2, y2, z2, x3, y3, z3 ...
				local n -- error thrown or hook called during recording at luatools.lua:248

				if type(bufs)=="table" and buflist.__type==nil then -- table of bufs
					for k, v in ipairs(buflist) do
						bufs[k] = v
						dims[3*(k-1)+1] = v.x
						dims[3*(k-1)+2] = v.y
						dims[3*(k-1)+3] = v.z
						--table.insert(dims, v.x)
						--table.insert(dims, v.y)
						--table.insert(dims, v.z)
				end
				n = #bufs
				elseif type(bufs)=="table" and buflist.__type=="buffer" then
					bufs[1] = buflist
					dims[1] = buflist.x
					dims[2] = buflist.y
					dims[3] = buflist.z
					--table.insert(dims, buflist.x)
					--table.insert(dims, buflist.y)
					--table.insert(dims, buflist.z)
					n = 1
				end

				if type(params)~="table" then
					if type(params)=="number" then params = {params} else params = {} end
				end

				l.threadPushBuffers(bufs)
				l.threadPushITable(dims, "__dims")
				l.threadPushITable(params, "__params")

				for i = 0, l.numCores-1 do
					l.doFunction(l.threadInstance[i], "__setup") --run setup function
				end
			end
			function l.threadRun(name, ...)
				local a = {...}
				procTime = sdl.time()
				-- NYI: bytecode 71
				for i = 0, l.numCores-1 do
					l.threadProgress[i]=0
					lua.lua_settop(l.threadInstance[i], 0) -- restore stack
					l.loadVariable(l.threadInstance[i], name, a) -- loads processing function
					thread[i+1] = sdl.thread.new(l.threadFunction, l.threadCounter+i) -- runs preset function in each instance!!!
				end
				l.threadRunning = true
				procName = name.."."..table.concat(a,".")
			end
			function l.threadWait()
				--if l.threadRunning then
				for i = 0, l.numCores-1 do
					sdl.thread.wait(thread[i+1], NULL)
				end
				
				local timeNow = sdl.time()
				if not __global.preview then
					io.write("("..procName.."): "..(timeNow-procTime).."ms ("..(timeNow-loopTime).."ms)\n")
				end
				loopTime = timeNow
				--else
				--	-- deprecated use:
				--	error("Thread not running! Skipping threadWait()")
				--end
				l.threadRunning = false
				for i=0,l.numCores do
					l.threadProgress[i]=0
				end
			end
		end
		function l.nonThreadRun(...)
			l.threadCounter[0] = 0
			for i = 0, l.numCores-1 do
				l.loadVariable(l.threadInstance[i], ...)
				lua.lua_call(l.threadInstance[i], th.arg_in, th.arg_out)
				--implement with pcall in local instance!
			end
		end
		function l.threadRunWait(...)
			l.threadRun(...)
			l.threadWait()
		end
		function l.threadStop()
			if l.threadRunning then
				l.threadProgress[l.numCores]=-1
				l.threadWait()
				l.threadProgress[l.numCores]=0
			end
		end
		function l.threadGetProgress()
			if l.numCores==0 then return 0 end
			local n = 0
			for i = 0, l.numCores-1 do
				n = n + (l.threadProgress[i]==-1 and l.threadProgress[l.numCores+1] or l.threadProgress[i])
			end
			return n/l.numCores/l.threadProgress[l.numCores+1]
		end
		function l.threadDone() --returns true once when the threads are finished
			for i = 0, l.numCores-1 do
				if l.threadProgress[i]~=-1 then
				  return false
				end
		  end
		  return true
		end
	else
		print("threading library not loaded, multithreading functionality not supported")
	end

else
	print("SDL not loaded, multithreading functionality not supported")
end

global("__lua", l)
print("Lua threads loaded")
return l
