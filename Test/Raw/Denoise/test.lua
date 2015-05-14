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

-- framework for testing denoising algorithms of raw data

-- setup stuff
math.randomseed(os.time())
local ffi = require("ffi")
require("global")

local sdl = require("Include.sdl2")
local ppm = require("Tools.ppmtools")
local img = require("Tools.imgtools")
--local img = require("Test.Data.data")

-- write/set demosaic function
package.path =  "./?.lua;"..package.path
local denoise = require("Test.Raw.Denoise.nlmeans")
local demosaic = require("Test.Raw.Demosaic.dlmmse")

-- load image
local i = ppm.toBuffer(ppm.readIM("img.ppm"))
local original = i:copy()
sdl.screen.set(i.x, i.y)

local function imshow(i)
	i:toSurface(sdl.screen.surf)
	sdl.update()
	sdl.input.update()
	while not sdl.input.anykey do
		sdl.input.update()
	end
end

imshow(i)
local o = i:copy()

-- mosaic image
local function getC(x, y)
	return (x%2==1 and y%2==0 and "G") or
		(x%2==0 and y%2==1 and "G") or
		(x%2==0 and y%2==0 and "B") or
		(x%2==1 and y%2==1 and "R")
end

---[[ 
for x = 0, i.x-1 do
	for y = 0, i.y-1 do
		local c = getC(x, y)
		if c~="R" then i:a(x,y,0,0) end 
		if c~="G" then i:a(x,y,1,0) end
		if c~="B" then i:a(x,y,2,0) end
	end
end
--]]

i = i:grayscale()
imshow(i)

local rnorm = require("Test.Raw.Denoise.random")

-- add noise
for x = 0, i.x-1 do
	for y = 0, i.y-1 do
		--i:a(x,y,0, i:i(x,y,0)+math.random()*0.3-0.15)
		i:a(x,y,0, i:i(x,y,0)+rnorm(0, 0.05))
	end
end

imshow(i)

sdl.tic()
--require("jit.v").start()
--require("jit.p").start("l5i1m1", "profile.txt")
local j = denoise(i, 0.040)
--local j = denoise(i, 0.040, j)
--require("jit.p").stop()
sdl.toc()
--os.exit()

--local j = i:new()

--i:toSoA():toYX()
--j:toSoA():toYX()

local halide = require("Test.Optimization.halide")

local algorithm = [[
Func bilateral, temp, norm;
Var x, y, c;
int n = 8;

RDom r(-n,n*2, -n,n*2);

Func clamped = BoundaryConditions::repeat_edge(input);

Expr d = clamped(x+r.x*2, y+r.y*2, c)-clamped(x, y, c);

Expr g = exp((-pow(r.x*2,2)-pow(r.y*2,2))/dx);
Expr h = exp(-pow(d,2)/dv);

temp(x, y, c) += clamped(x+r.x*2, y+r.y*2, c)*g*h;
norm(x, y, c) += g*h;

bilateral(x, y, c) = temp(x, y, c)/norm(x, y, c);
]]

local schedule = [[
temp.update().unroll(r.y).unroll(r.x);
norm.update().unroll(r.y).unroll(r.x);
bilateral.parallel(y);
]]

--local fun = halide.compile("bilateral", {"input"}, {"dx", "dv"}, algorithm, schedule, nil, "bilateral")()
local fun = require("bilateral")

--sdl.tic()
--fun(halide.buffer(i), 4, 0.1, halide.buffer(j))
--sdl.toc()

imshow(j)

local j = demosaic(j)
local k = demosaic(i)

while not sdl.input.quit do
imshow(k)
imshow(j)
imshow(o)
end

ppm.writeIM(ppm.fromBuffer(j, "~/test_out.png"))