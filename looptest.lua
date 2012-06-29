--[[
	Copyright (C) 2011-2012 G. Bajlekov

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

sdl = require("sdltools")
dbg = require("dbgtools")

a=1
local function f(b) return b+1 end
local function g(b) return b+1 end


local b=0
tic()
for j=1,1000000000 do
	b=0
	for i=1,a do
		b=f(b)
	end
end
toc()
print(b)

local b=0
tic()
for j=1,1000000000 do
	b=0
	b=g(b)
end
toc()
print(b)