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


local function fib(n)
	if n <= 2 then
		return 1
	else
		return fib(n-1)+fib(n-2)
	end
end

t=os.clock()
fib(35)
print(os.clock()-t)

local sin = math.sin
local function numquad(lb,ub,npoints)
	local val = 0
	for x = lb, ub, (ub-lb)/npoints do
		val = val + sin(x)/npoints
	end
	return val
end

t=os.clock()
numquad(5,15,10^6)
print(os.clock()-t)


--eliminating locals

local d = {1, 2, 3}

local function setter(i, x)
	d[i] = x
end

local function getter(i)
	return d[i]
end

local function op1()
	local ri = getter(1)
	local gi = getter(2)
	local bi = getter(3)
	local ro, go, bo
	
	go = (gi + bi + ri)/3
	bo = gi + bi - ri
	ro = ri * (gi/bi)

	setter(1, ro)
	setter(2, go)
	setter(3, bo)
end

local function op2()
	setter(1, getter(1) * (getter(2)/getter(3)) )
	setter(2, (getter(2) + getter(3) + getter(1))/3)
	setter(3, getter(2) + getter(3) - getter(1) )
end

local function op2()
	setter(1, getter(1) * (getter(2)/getter(3)) )
	setter(2, (getter(2) + getter(3) + getter(1))/3)
	setter(3, getter(2) + getter(3) - getter(1) )
end

local function op3()
	local ri = getter(1)
	local gi = getter(2)
	local bi = getter(3)

	setter(1, ri * (gi/bi) )
	setter(2, (gi + bi + ri)/3)
	setter(3, gi + bi - ri )
end

local function loop(i, fun)
	for i = 1, i do
		fun()
	end
end

print("***")
t=os.clock()
loop(10^8, op1)
print(os.clock()-t)
t=os.clock()
loop(10^8, op2)
print(os.clock()-t)
t=os.clock()
loop(10^8, op3)
print(os.clock()-t)
t=os.clock()
loop(10^8, op1)
print(os.clock()-t)
t=os.clock()
loop(10^8, op2)
print(os.clock()-t)
t=os.clock()
loop(10^8, op3)
print(os.clock()-t)

-- it's faster!! to use locals for storing input and output 
-- saves up to 50% on loading overhead vs direct reassignment, cleaner too!

