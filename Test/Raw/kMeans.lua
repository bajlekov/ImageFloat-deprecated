--[[
Copyright (C) 2011-2013 G. Bajlekov

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

-- 3D k-means clustering for posterization

--math.randomseed(os.time())
math.randomseed(os.time())
local ffi = require("ffi")

-- distance calculation, no sqrt for speed
local function dist(x1,y1,z1,x2,y2,z2)
	return (x1-x2)^2 + (y1-y2)^2 + (z1-z2)^2
end

local k = 12
local iter = 512
local threshold = 1

local clust = ffi.new("float[?][3]", k)
local newClust = ffi.new("float[?][3]", k)

local function clustInit(im)
	clust[0][0] = 0
	clust[0][1] = 0
	clust[0][2] = 0
	clust[1][0] = 1
	clust[1][1] = 1
	clust[1][2] = 1
	if im==nil then
		for i = 2, k-1 do
			clust[i][0] = math.random()
			clust[i][1] = math.random()
			clust[i][2] = math.random()
		end
	else
		for i = 2, k-1 do
			local x = math.floor(math.random()*im.x)
			local y = math.floor(math.random()*im.y)
			clust[i][0] = im:i(x,y,0)
			clust[i][1] = im:i(x,y,1)
			clust[i][2] = im:i(x,y,2)
		end
	end
end

local floor = math.floor

local function argmin(t, n)
	local min = t[0]
	local argmin = 0
	for i = 1, n-1 do
		if t[i]<min then min = t[i] argmin = i end
	end
	return argmin
end

local function dist(x1,y1,z1,x2,y2,z2)
	return (x1-x2)^2 + (y1-y2)^2 + (z1-z2)^2
end

local ispc = [[
	export uniform float dist(uniform float x1, uniform float y1, uniform float z1, uniform float x2, uniform float y2, uniform float z2) {
		return pow(x1-x2,2) + pow(y1-y2,2) + pow(z1-z2,2);
	}

	export uniform int argmin(uniform float t[], uniform int n) {
		uniform float min = t[0];
		uniform int amin = 0;
		uniform int i;
		for (i=1; i<n; i++) {
			if (t[i]<min) {
				min = t[i];
				amin = i;
			}
		}
		return amin;
	}
]]

ffi.cdef [[
	int argmin(float* t, int n);
	float dist(float x1, float y1, float z1, float x2, float y2, float z2);
]]

local compile = require("Tools.compile")

local cc = compile.ispc("test", ispc)

--partitioning argmin, worse performance:
local function argmin2(t,n)
	if n==1 then
		return 0, t[0] 
	else
		local split = floor(n/2)
		local a1, m1 = argmin2(t, split) 
		local a2, m2 = argmin2(t+split, n-split)
		if m1<m2 then
			return a1, m1
		else
			return a2+split, m2
		end
	end
end

local distTable = ffi.new("float[?]", k)
local meanCount = ffi.new("float[?]", k)

local random = math.random

local function clustIter(im)
	for i = 0, k-1 do
		meanCount[i] = 0
	end
	
	for x = 0, im.x-1 do
		for y = 0, im.y-1 do
			local r, g, b = im:i(x,y,0), im:i(x,y,1), im:i(x,y,2)
			for i = 0, k-1 do
				distTable[i] = dist(clust[i][0], clust[i][1], clust[i][2], r,g,b)
			end
			local c = cc.argmin(distTable, k)
			if meanCount[c]==0 then
				newClust[c][0] = r
				newClust[c][1] = g
				newClust[c][2] = b
				meanCount[c] = 1
			else
				newClust[c][0] = newClust[c][0] + r
				newClust[c][1] = newClust[c][1] + g
				newClust[c][2] = newClust[c][2] + b
				meanCount[c] = meanCount[c] + 1
			end
		end
	end
	
	local shift = 0
	
	for i = 0, k-1 do
		if meanCount[i]<threshold then -- implement cluster reset threshold for small clusters
			clust[i][0] = random()
			clust[i][1] = random()
			clust[i][2] = random()
			--print("miss...")
		else
			newClust[i][0] = newClust[i][0]/meanCount[i]
			newClust[i][1] = newClust[i][1]/meanCount[i]
			newClust[i][2] = newClust[i][2]/meanCount[i]
			
			shift = shift + dist(newClust[i][0],newClust[i][1],newClust[i][2], clust[i][0],clust[i][1],clust[i][2])
			
			clust[i][0] = newClust[i][0]
			clust[i][1] = newClust[i][1]
			clust[i][2] = newClust[i][2]
		end
	end
	return shift
end

local function clustApply(im)
	local xmax = im.x
	local ymax = im.y
	
	for x = 0, xmax-1 do
		for y = 0, ymax-1 do
			for i = 0, k-1 do
				distTable[i] = dist(clust[i][0], clust[i][1], clust[i][2], im:i(x,y,0), im:i(x,y,1), im:i(x,y,2))
			end
			local c = argmin(distTable, k)
			im:a(x,y,0,clust[c][0])
			im:a(x,y,1,clust[c][1])
			im:a(x,y,2,clust[c][2])
		end
	end
	
	print("done!")
end



-- test

--overload print for tables
function see(f)
	local function size(t)
		local c=0
		for _,_ in pairs(t) do
			c=c+1
		end
		return c
	end

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

do
  local t
  function tic()
    t = os.clock()
  end
  function toc()
    print(os.clock()-t)
  end
end


---[[
__global = require("global")
local ppm = require("Tools.ppmtools")
local img = require("Tools.imgtools")

local d = ppm.toBuffer(ppm.readIM("test.png"))

tic()
clustInit()
for i = 1, iter do
	local r = clustIter(d)
	print("iteration:",i, "residue:", r)
	if r==0 then break end
end
clustApply(d)
toc()

d = ppm.fromBuffer(d)
d.name = "kmeans_out.png"
ppm.writeIM(d)
--]]

tic()
local a = 0
for i=1,768*512*60*12 do
	a = a + dist(1,2,3,2,3,4)
end
toc()

local b = ffi.new("float[12]", 1,2,3,4,-1,6,7,8,9,10,11,12)
tic()
local a = 0
for i=1,768*512*60 do
	a = a + cc.argmin(b, 12)
end
toc()




