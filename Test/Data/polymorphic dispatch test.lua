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

-- Test in how far polymorphic dispatch affects minimum parameter getters and setters

local function f(n)
	local a = n
	if a==0 then return 0 elseif a==1 then return 1 elseif a>1 then return 2 else return -1 end
end 

local function b(n) 
	local t = os.clock()
	local s = 0
	for i = 1, 100000000 do
		s = s + f(n)
	end
	print(os.clock()-t)
end

b(-1)
b(1)
b(2)
b(0)
b(-1)
b(1)

-- create new functions on change or flush cache...or use functions directly
local t = os.clock()
local s = 0
for i = 1, 100000000 do
	s = s + f(2)
end
print(os.clock()-t)

-- apparently calling directly isn't affected if the parameters change...but why is b() affected?
local t = os.clock()
local s = 0
for i = 1, 100000000 do
	s = s + f(1)
end
print(os.clock()-t)

local t = os.clock()
local s = 0
for i = 1, 100000000 do
	s = s + f(0)
end
print(os.clock()-t)

local t = os.clock()
local s = 0
for i = 1, 100000000 do
	s = s + f(-1)
end
print(os.clock()-t)