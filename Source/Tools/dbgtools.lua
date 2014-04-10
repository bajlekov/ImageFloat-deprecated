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

local dbg = {}

global("tic")
global("toc")
if type(__sdl)=="table" then
	local t = 0
	function tic()
		t = __sdl.time()
	end
	function toc(m)
		if m then
			io.write(m..": "..tostring(__sdl.time() - t).."ms\n")
		else
			io.write(tostring(__sdl.time() - t).."ms\n")
		end
	end
else 
	function tic() print("SDL library missing") end
	toc = tic
end

function dbg.mem(m)
	collectgarbage("collect")
	if m then
		print(string.format(m..": %.1fMB", collectgarbage("count")/1024))
	else
		print(string.format("%.1fMB", collectgarbage("count")/1024))
	end
end

local function size(t)
	local c=0
	for _,_ in pairs(t) do
		c=c+1
	end
	return c
end

function dbg.see(f)
	if type(f)~="table" then print(type(f)..":",f) return end
	if size(f)==0 then
		print("empty "..tostring(table))
	end
	for k,v in pairs(f) do
		if type(v)=="table" then
			print("["..k.."]","table","["..size(v).."]")
		elseif type(v)=="function" then
			print("["..k.."]","function",debug.getinfo(v)["short_src"])
		else
			print("["..tostring(k).."]",type(v)..":",v)
		end
	end
end

function dbg.gc()
	collectgarbage("collect")
	print("*** COLLECT GARBAGE ***")
end

function dbg.print(m)
	print("DEBUG: "..m)
end

function dbg.warn(m)
	print(debug.traceback("WARNING: "..m))
end

function dbg.error(m)
	error("ERROR: "..m,0)
end

local ticks = __sdl.time
local time = ticks()
local function trace()
	local t = ticks()-time
	if t>0 then
		io.write("\n"..(debug.getinfo (2, "n").name or "*none*")..": "..t.."ms\n")
		io.write(debug.traceback())
	else io.write(".") end
	time = ticks()
end
function dbg.traceStart()
	debug.sethook(trace, "c")
end
function dbg.traceStop()
	debug.sethook()
end


global("__dbg", dbg)
return dbg