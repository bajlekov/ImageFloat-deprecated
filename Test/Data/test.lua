return function(data)
	local sdl = require("Include.sdl2")
	local alloc = require("Test.Data.alloc")
	print("Testing...")
	
	local d = data:new(6000,4000,3)
	sdl.tic()
	local f = d:copy()
	sdl.toc("copy")
	
	-- warmup
	d:toSoA()
	d:toAoS()
	f:toYX()
	f:toXY()
	
	d:toSoA()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local t = x*10+y
			f:set3(x, y, t+100, t+200, t+300)
		end
	end
	sdl.toc("SoA assign")
	
	d:toAoS()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local t = x*10+y
			f:set3(x, y, t+100, t+200, t+300)
		end
	end
	sdl.toc("AoS assign")
	
	sdl.tic()
	d:toSoA()
	sdl.toc("aos->soa")
	sdl.tic()
	d:toAoS()
	sdl.toc("soa->aos")
	sdl.tic()
	d:toSoA()
	sdl.toc("aos->soa")
	sdl.tic()
	d:toAoS()
	sdl.toc("soa->aos")
	
	sdl.tic()
	d:toYX()
	sdl.toc("Flip")
	sdl.tic()
	d:toXY()
	sdl.toc("Flop")
	sdl.tic()
	d:toYX()
	sdl.toc("Flip")
	sdl.tic()
	d:toXY()
	sdl.toc("Flop")
	
	sdl.tic()
	d:layout("SoA", "YX")
	sdl.toc("Combined")
	sdl.tic()
	d:layout("AoS", "XY")
	sdl.toc("Combined")
	
	print(d)
	
	d:toSoA()
	f:toSoA()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local a, b, c = f:get3(x, y)
			f:set3(x, y, a+b+c)
		end
	end
	sdl.toc("add XY "..d.pack)
	
	d:toAoS()
	f:toAoS()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local a, b, c = f:get3(x, y)
			f:set3(x, y, a+b+c)
		end
	end
	sdl.toc("add XY "..d.pack)
	
	d:toYX()
	f:toYX()
	
	d:toSoA()
	f:toSoA()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local a, b, c = f:get3(x, y)
			f:set3(x, y, a+b+c)
		end
	end
	sdl.toc("add YX "..d.pack)
	
	d:toAoS()
	f:toAoS()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local a, b, c = f:get3(x, y)
			f:set3(x, y, a+b+c)
		end
	end
	sdl.toc("add YX "..d.pack)
	
	collectgarbage("setpause", 100)
	print(alloc.count(), collectgarbage("count"))
	sdl.tic()
	local b=0
	for i = 1, 100000 do
		local a = d:new(6000,4000,3)
		a:set(1,1,1,1)
		b = b + a:get(1,1,1)
	end
	sdl.toc("constructor "..b)
	print(alloc.count(), collectgarbage("count"))
	collectgarbage("collect")
	print(alloc.count(), collectgarbage("count"))
	
	local function add(a, b, c)
		a:checkTarget(c)
		b:checkTarget(c)
		if c.order=="YX" then
			for y = 0, c.y-1 do
				for x = 0, c.x-1 do
					local a1, b1, c1 = a:get3(x, y)
					local a2, b2, c2 = b:get3(x, y)
					c:set3(x, y, a1+a2, b1+b2, c1+c2)
				end
			end
		else
			for x = 0, c.x-1 do
				for y = 0, c.y-1 do
					local a1, b1, c1 = a:get3(x, y)
					local a2, b2, c2 = b:get3(x, y)
					c:set3(x, y, a1+a2, b1+b2, c1+c2)
				end
			end
		end
	end
	
	local g = d:new(1, 4000, 3)
	
	local h = d:new(d:checkSuper(d, f, g))
	
	print(h)
	
	sdl.tic()
		add(g, d, h)
	sdl.toc("add")
	
end