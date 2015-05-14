return function(data)
	--jit.opt.start("sizemcode=512")
	--require("jit.v").start()
	--require("jit.v").start("verbose.txt")
	--require("jit.dump").start("tT", "dump.txt")
	--require("jit.p").start("vfi1m1", "profile.txt")
	
	local sdl = require("Include.sdl2")
	local alloc = require("Test.Data.alloc")
	print("Testing...")
	
	local d = data:new(6000,4000,3)
	d:toZYX()
	sdl.tic()
	local f = d:copy()
	local f = d:copy()
	local f = d:copy()
	local f = d:copy()
	local f = d:copy()
	sdl.toc("copy * 5")
	
	-- warmup
	d:toZXY()
	d:toXYZ()
	f:toYXZ()
	f:toXYZ()
	
	d:toZXY()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local t = x*10+y
			f:set3(x, y, t+100, t+200, t+300)
		end
	end
	sdl.toc("SoA assign")
	
	d:toXYZ()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local t = x*10+y
			f:set3(x, y, t+100, t+200, t+300)
		end
	end
	sdl.toc("AoS assign")
	
	sdl.tic()
	d:toZXY()
	sdl.toc("aos->soa")
	sdl.tic()
	d:toXYZ()
	sdl.toc("soa->aos")
	sdl.tic()
	d:toZXY()
	sdl.toc("aos->soa")
	sdl.tic()
	d:toXYZ()
	sdl.toc("soa->aos")
	
	sdl.tic()
	d:toYXZ()
	sdl.toc("Flip")
	sdl.tic()
	d:toXYZ()
	sdl.toc("Flop")
	sdl.tic()
	d:toYXZ()
	sdl.toc("Flip")
	sdl.tic()
	d:toXYZ()
	sdl.toc("Flop")
	
	sdl.tic()
	d:layout("ZYX")
	sdl.toc("XYZ->ZYX")
	sdl.tic()
	d:layout("XYZ")
	sdl.toc("ZYX->XYZ")
	
	print(d)
	
	d:toZXY()
	f:toZXY()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local a, b, c = f:get3(x, y)
			f:set3(x, y, a+b+c)
		end
	end
	sdl.toc("add "..d.order)
	
	d:toXYZ()
	f:toXYZ()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local a, b, c = f:get3(x, y)
			f:set3(x, y, a+b+c)
		end
	end
	sdl.toc("add "..d.order)
	
	d:toYXZ()
	f:toYXZ()
	
	d:toZYX()
	f:toZYX()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local a, b, c = f:get3(x, y)
			f:set3(x, y, a+b+c)
		end
	end
	sdl.toc("add "..d.order)
	
	d:toYXZ()
	f:toYXZ()
	sdl.tic()
	for x = 0, d.x-1 do
		for y = 0, d.y-1 do
			local a, b, c = f:get3(x, y)
			f:set3(x, y, a+b+c)
		end
	end
	sdl.toc("add "..d.order)
	
	collectgarbage("setpause", 100)
	--print(alloc.count(), collectgarbage("count"))
	sdl.tic()
	local b=0
	for i = 1, 100000 do
		local a = d:new(6000,4000,3)
		a:set(1,1,1,1)
		b = b + a:get(1,1,1)
	end
	sdl.toc("constructor "..b)
	--print(alloc.count(), collectgarbage("count"))
	collectgarbage("collect")
	--print(alloc.count(), collectgarbage("count"))
	
	local function add(a, b, c)
		a:checkTarget(c)
		b:checkTarget(c)
		for x = 0, c.x-1 do
			for y = 0, c.y-1 do
				local a1, b1, c1 = a:get3(x, y)
				local a2, b2, c2 = b:get3(x, y)
				c:set3(x, y, a1+a2, b1+b2, c1+c2)
			end
		end
	end
	
	local g = d:new(1, 4000, 3)
	
	local h = d:new(d:checkSuper(d, f, g))
	
	print(h)
	
	sdl.tic()
	print(h:getStride())
	sdl.toc()
	
	sdl.tic()
		add(g, d, h)
	sdl.toc("add")
	
end