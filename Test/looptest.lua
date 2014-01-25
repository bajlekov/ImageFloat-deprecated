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

--jit.opt.start("hotexit=1")

do
	function global(k, v) -- assign new global
		rawset(_G, k, v or false)
	end
	local function newGlobal(t, k, v) -- disable globals
		error("global assignment not allowed: "..k)
	end
	setmetatable(_G, {__newindex=newGlobal})
end

local sdl = require("Include.sdltools")
local dbg = require("Tools.dbgtools")
local unroll = require("Tools.unroll")

local a=128
local function f(b) return b+1 end
local function g(b) return b+1 end

jit.flush()

local function test(f, x, y)
  local b=0
  tic()
  for j=1,x do
  	b=0
  	for i=1,y do
  		b=f(b)
  	end
  end
  toc()
  print(b)
end

test(f, 100000000, 10)

local function test(f, x, y)
  local b=0
  local function g() b = f(b) end
  
  tic()
  for j=1,x do
    b=0
    unroll[y](g)
  end
  toc()
  print(b)
end

test(f, 100000000, 10)

--[[
local b=0
tic()
for j=1,1000000 do
	b=0
	b=g(b)
	b=g(b)
	b=g(b)
	b=g(b)
	b=g(b)
	b=g(b)
	b=g(b)
	b=g(b)
	b=g(b)
	b=g(b)
end
toc()
print(b)

local b=0
tic()
for j=1,1000000 do
	b=0
	for i=1,a do
		b=f(b)
	end
end
toc()
print(b)

local b=0
local function ff(i) b = g(i) end

tic()
for j=1,1000000 do
	b=0
	unroll[4095](ff)
end
toc()
print(b)
--]]