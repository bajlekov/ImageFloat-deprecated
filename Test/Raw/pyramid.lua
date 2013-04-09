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
--]]


--pyramid decomposition and composition

-- method works for decimating image using gaussian filtering
--	- kernel width = 5: [1 4 6 4 1]/16 -> separable
--	- 
-- uses:
--	- fast frequency filtering
--	- merging
--		- using map (custom blending) or function (ex: focus/exposure stacking)
--		- functions include: contrast, brightness, saturation
--	- integrate align_image_stack for image aligning before merging (works quite well)

require("path")
local ffi = require("ffi")
__global = require("global")
local __global = __global -- local reference to global table
__global.loadFile = arg and arg[1] or __global.loadFile
collectgarbage("setpause", 120)
math.randomseed(os.time())

local sdl = require("sdltools")
local lua = require("luatools")
local dbg = require("dbgtools")
local ppm = require("ppmtools")
local img = require("imgtools")

__dbg = dbg
__img = img

-- layout:
--[[
		- pyrDown(G0) -> G1, L0
		- pyrUp(G1, L0) -> G0
		- pyrConstruct(G0, n) -> P
		- pyrCollapse(P) -> G0
		- gDown(G0) -> G1
		- gUp(G1) -> G0
		
		struct P {
			L = [img]
			ofx = []
			ofy = []
			n = maxLevels
		}
--]]

-- TODO: always use values from kernel!
local kernel = ffi.new("double[5]", 1/16, 4/16, 6/16, 4/16, 1/16)

local function filter(G0)
	local F0 = G0:new()
	local k = kernel
	
	-- horizontal:
	for x = 2, G0.x-3 do
		for y = 0, G0.y-1 do
			for z = 0, G0.z do
				local s =	G0:i(x-2,y,z)*k[0]+
							G0:i(x-1,y,z)*k[1]+
							G0:i(x+0,y,z)*k[2]+
							G0:i(x+1,y,z)*k[3]+
							G0:i(x+2,y,z)*k[4]
				F0:a(x,y,z,s)
			end
		end
	end
	-- horizontal edges
	for y = 0, G0.y-1 do
		for z = 0, G0.z do
			local x = 0
			local s =	G0:i(x+0,y,z)*k[2]+
						G0:i(x+1,y,z)*k[3]+
						G0:i(x+2,y,z)*k[4]
			F0:a(x,y,z,s*16/11)
			
			local x = 1
			local s =	G0:i(x-1,y,z)*k[1]+
						G0:i(x+0,y,z)*k[2]+
						G0:i(x+1,y,z)*k[3]+
						G0:i(x+2,y,z)*k[4]
			F0:a(x,y,z,s*16/15)
			
			local x = G0.x-2
			local s =	G0:i(x-2,y,z)*k[0]+
						G0:i(x-1,y,z)*k[1]+
						G0:i(x+0,y,z)*k[2]+
						G0:i(x+1,y,z)*k[3]
			F0:a(x,y,z,s*16/15)
			
			local x = G0.x-1
			local s =	G0:i(x-2,y,z)*k[0]+
						G0:i(x-1,y,z)*k[1]+
						G0:i(x+0,y,z)*k[2]
			F0:a(x,y,z,s*16/11)
		end
	end
	
	-- vertical:
	for x = 0, G0.x-1 do
		for y = 2, G0.y-3 do
			for z = 0, G0.z do
				local s =	G0:i(x,y-2,z)*k[0]+
							G0:i(x,y-1,z)*k[1]+
							G0:i(x,y+0,z)*k[2]+
							G0:i(x,y+1,z)*k[3]+
							G0:i(x,y+2,z)*k[4]
				F0:a(x,y,z,s)
			end
		end
	end
	-- vertical edges
	for x = 0, G0.x-1 do
		for z = 0, G0.z do
			local y = 0
			local s =	G0:i(x,y+0,z)*k[2]+
						G0:i(x,y+1,z)*k[3]+
						G0:i(x,y+2,z)*k[4]
			F0:a(x,y,z,s*16/11)
			
			local y = 1
			local s =	G0:i(x,y-1,z)*k[1]+
						G0:i(x,y+0,z)*k[2]+
						G0:i(x,y+1,z)*k[3]+
						G0:i(x,y+2,z)*k[4]
			F0:a(x,y,z,s*16/15)
			
			local y = G0.y-2
			local s =	G0:i(x,y-2,z)*k[0]+
						G0:i(x,y-1,z)*k[1]+
						G0:i(x,y+0,z)*k[2]+
						G0:i(x,y+1,z)*k[3]
			F0:a(x,y,z,s*16/15)
			
			local y = G0.y-1
			local s =	G0:i(x,y-2,z)*k[0]+
						G0:i(x,y-1,z)*k[1]+
						G0:i(x,y+0,z)*k[2]
			F0:a(x,y,z,s*16/11)
		end
	end
	
	return F0
end

-- check implementation, differs from filter + subsample!!
local function gDown(G0)
	local k = kernel
	local F0 = img:new(G0.x/2, G0.y, G0.z)
	
	-- horizontal:
	for x = 2, G0.x-3, 2 do
		for y = 0, G0.y-1 do
			for z = 0, G0.z do
				local s =	G0:i(x-2,y,z)*k[0]+
							G0:i(x-1,y,z)*k[1]+
							G0:i(x+0,y,z)*k[2]+
							G0:i(x+1,y,z)*k[3]+
							G0:i(x+2,y,z)*k[4]
				F0:a(x/2,y,z,s)
			end
		end
	end
	-- horizontal edges
	for y = 0, G0.y-1 do
		for z = 0, G0.z do
			local x = 0
			local s =	G0:i(x+0,y,z)*k[2]+
						G0:i(x+1,y,z)*k[3]+
						G0:i(x+2,y,z)*k[4]
			F0:a(0,y,z,s*16/11)
			
			local x = G0.x-2 -- FIXME boundary should be -1 if size is uneven!
			local s =	G0:i(x-2,y,z)*k[0]+
						G0:i(x-1,y,z)*k[1]+
						G0:i(x+0,y,z)*k[2]
			F0:a(x/2,y,z,s*16/11)
		end
	end	
	
	local F1 = img:new(G0.x/2, G0.y/2, G0.z)
	
	-- vertical:
	for x = 0, F0.x-1 do
		for y = 2, F0.y-3, 2 do
			for z = 0, F0.z do
				local s =	F0:i(x,y-2,z)*k[0]+
							F0:i(x,y-1,z)*k[1]+
							F0:i(x,y+0,z)*k[2]+
							F0:i(x,y+1,z)*k[3]+
							F0:i(x,y+2,z)*k[4]
				F1:a(x,y/2,z,s)
			end
		end
	end
	-- vertical edges
	for x = 0, F0.x-1 do
		for z = 0, F0.z do
			local y = 0
			local s =	F0:i(x,y+0,z)*k[2]+
						F0:i(x,y+1,z)*k[3]+
						F0:i(x,y+2,z)*k[4]
			F1:a(x,y/2,z,s*16/11)
			
			local y = F0.y-2 -- FIXME boundary should be -1 if size is uneven!
			local s =	F0:i(x,y-2,z)*k[0]+
						F0:i(x,y-1,z)*k[1]+
						F0:i(x,y+0,z)*k[2]
			F1:a(x,y/2,z,s*16/11)
		end
	end
	
	return F1
end

local function gUp(F1)
	local F0 = F1:new(F1.x*2, F1.y, F1.z)
	
	for x = 1, F1.x-2 do
		for y = 0, F1.y-1 do
			for z = 0, F1.z-1 do
				local s1 = (F1:i(x-1,y,z)+6*F1:i(x,y,z)+F1:i(x+1,y,z))/8
				local s2 = (F1:i(x,y,z)+F1:i(x+1,y,z))/2
				F0:a(x*2,y,z, s1)
				F0:a(x*2+1,y,z, s2)
			end
		end
	end
	
	for y = 0, F1.y-1 do
		for z = 0, F1.z-1 do
			local x = 0
			local s1 = (6*F1:i(x,y,z)+F1:i(x+1,y,z))/7
			local s2 = (F1:i(x,y,z)+F1:i(x+1,y,z))/2
			F0:a(x*2,y,z, s1)
			F0:a(x*2+1,y,z, s2)
			
			local x = F1.x-1
			local s1 = (6*F1:i(x,y,z)+F1:i(x-1,y,z))/7
			local s2 = F1:i(x,y,z)
			F0:a(x*2,y,z, s1)
			F0:a(x*2+1,y,z, s2)
		end
	end
	
	local G0 = F1:new(F1.x*2, F1.y*2, F1.z)
	
	for x = 0, F0.x-1 do
		for y = 1, F0.y-2 do
			for z = 0, F0.z-1 do
				local s1 = (F0:i(x,y-1,z)+6*F0:i(x,y,z)+F0:i(x,y+1,z))/8
				local s2 = (F0:i(x,y,z)+F0:i(x,y+1,z))/2
				G0:a(x,y*2,z, s1)
				G0:a(x,y*2+1,z, s2)
			end
		end
	end
	
	for x = 0, F0.x-1 do
		for z = 0, F0.z-1 do
			local y = 0
			local s1 = (6*F0:i(x,y,z)+F0:i(x,y+1,z))/7
			local s2 = (F0:i(x,y,z)+F0:i(x,y+1,z))/2
			G0:a(x,y*2,z, s1)
			G0:a(x,y*2+1,z, s2)
			
			local y = F0.y-1
			local s1 = (F0:i(x,y-1,z)+6*F0:i(x,y,z))/7
			local s2 = (F0:i(x,y,z))
			G0:a(x,y*2,z, s1)
			G0:a(x,y*2+1,z, s2)
		end
	end
	
	return G0	
end

local function pyrDown(G0)
	local G1 = gDown(G0)
	local L0 = G0 - gUp(G1)
	return G1, L0
end

local function pyrUp(G1, L0)
	L0 = L0 or 0
	local G0 = gUp(G1)+L0
	return G0
end

-- TODO: keep track of buffer sizes

-- full: keep gaussian components
local function pyrConstruct(G0, n)
	local P = {L={}, x={}, y={}, n=0}
	P.n = n or 5
	
	local G1, G2
	G1 = G0
	for i = 1, P.n do
		G2, P.L[i-1] = pyrDown(G1)
		G1 = G2
	end
	P.L[P.n] = G2
	return P
end

local function pyrConstructG(G0, n)
	local P = {L={}, x={}, y={}, n=0}
	P.n = n or 5
	
	local G = {}
	G[0] = G0
	for i = 1, P.n do
		G[i], P.L[i-1] = pyrDown(G[i-1])
	end
	P.L[P.n] = G[P.n]
	P.G = G
	return P
end

local function pyrCollapse(P)
	local G = {}
	G[P.n] = P.L[P.n]
	for i = P.n-1, 0, -1 do
		G[i] = pyrUp(G[i+1], P.L[i])
		G[i+1] = nil
	end
	local G0 = G[0]
	return G0
end

--test
local B = {}
B[1] = ppm.toBuffer(ppm.readIM("./focus/AIS_0001.tif"))
B[2] = ppm.toBuffer(ppm.readIM("./focus/AIS_0002.tif"))
B[3] = ppm.toBuffer(ppm.readIM("./focus/AIS_0003.tif"))
--B[4] = ppm.toBuffer(ppm.readIM("./focus/AIS_0004.tif"))
--B[5] = ppm.toBuffer(ppm.readIM("./focus/AIS_0005.tif"))
--B[6] = ppm.toBuffer(ppm.readIM("./focus/AIS_0006.tif"))
--B[7] = ppm.toBuffer(ppm.readIM("./focus/AIS_0007.tif"))
--B[8] = ppm.toBuffer(ppm.readIM("./focus/AIS_0008.tif"))
--B[9] = ppm.toBuffer(ppm.readIM("./focus/AIS_0009.tif"))
--B[10] = ppm.toBuffer(ppm.readIM("./focus/AIS_0010.tif"))
--B[11] = ppm.toBuffer(ppm.readIM("./focus/AIS_0011.tif"))
--B[12] = ppm.toBuffer(ppm.readIM("./focus/AIS_0012.tif"))
B[4] = ppm.toBuffer(ppm.readIM("./focus/AIS_0000.tif"))
local P = {}

tic()
for i = 1, 4 do
	P[i] = pyrConstruct(B[i], 3)
end
toc("Construct")


-- absmax function
function img.absmax(a, b)
	if type(b)=="number" then
		local o = a:new()
		for i = 0, a.x-1 do
			for j = 0, a.y-1 do
				for k = 0, a.z-1 do
					local a = a:get(i,j,k)
					o:set(i,j,k, math.abs(a)>=math.abs(b) and a or b)				
				end
			end
		end
		return o
	elseif type(b)=="table" and b.__type=="buffer" then
		if a.x~=b.x or a.y~=b.y or a.z~=b.z then
			print(debug.traceback("ERROR: Incompatible array sizes: ["..a.x..", "..a.y..", "..a.z.."], ["..b.x..", "..b.y..", "..b.z.."]."))
			return nil
		else
			local o = a:new()
			for i = 0, a.x-1 do
				for j = 0, a.y-1 do
					for k = 0, a.z-1 do
						local a = a:get(i,j,k)
						local b = b:get(i,j,k)
						o:set(i,j,k, math.abs(a)>=math.abs(b) and a or b )				
					end
				end
			end
			return o
		end
	else
		print(debug.traceback("ERROR: Invalid type."))
		return nil
	end
end

function img.mmin(a)
	local m = math.huge
	for i = 0, a.x-1 do
		for j = 0, a.y-1 do
			for k = 0, a.z-1 do
				local a = a:get(i,j,k)
				m = a<=m and a or m				
			end
		end
	end
	return m
end

function img.mmax(a)
	local m = -math.huge
	for i = 0, a.x-1 do
		for j = 0, a.y-1 do
			for k = 0, a.z-1 do
				local a = a:get(i,j,k)
				m = a>=m and a or m				
			end
		end
	end
	return m
end

tic()
for i = 0, 3 do
	for j = 2, 4 do
		P[1].L[i] = img.absmax(P[1].L[i], P[j].L[i])
		collectgarbage("collect")
	end
end
toc()

tic()
local G0 = pyrCollapse(P[1])
toc("Construct")

G0 = G0-img.mmin(G0)
G0 = G0/img.mmax(G0)

local d = ppm.fromBuffer(G0)
d.name = "pyramid_out.png"
ppm.writeIM(d)
d = nil
print("Done!")

--[[
math.randomseed(os.time())

local ffi = require("ffi")
--local sdl = require("sdltools")
--local dbg = require("dbgtools")

do
  local t
  function tic()
    t = os.clock()
  end
  function toc()
    print(os.clock()-t)
  end
end

local ppm = require("ppmtools")
local img = require("imgtools")

require("mathtools")

local d = ppm.readIM("img.ppm")
local bufi = ppm.toBuffer(d)
d = nil

local xmax = bufi.x
local ymax = bufi.y

local bufo = img.copyGS(bufi)

local o = bufo.data
local i = bufi.data

print(xmax, ymax)

--create kernel
local f = ffi.new("double[6][6]")
local sum = 0
for x = 0, 5 do
  for y = 0, 5 do 
    f[x][y] = math.func.gauss(math.sqrt((x-2.5)^2 + (y-2.5)^2), 1.5)
    sum = sum + f[x][y]
  end
end

--normalise
for x = 0, 5 do
  for y = 0, 5 do 
    f[x][y] = f[x][y]/sum
  end
end

function downscale(ibuf)
  local xmax = ibuf.x
  local ymax = ibuf.y
  local zmax = ibuf.z
  
  local obuf = img.newBuffer(math.floor(xmax/2), math.floor(ymax/2), zmax)
  
  local i = ibuf.data
  local o = obuf.data
  
  for z = 0, zmax-1 do
    for x = 2, xmax-3, 2 do
      for y = 2, ymax-3, 2 do
	local t = 0
	
	for xc = 0, 5 do
	  for yc = 0, 5 do
	    t = t + f[xc][yc]*i[x-2+xc][y-2+yc][z] 
	  end
	end
    
	o[x/2][y/2][z] = t
      end
    end
  end
  
  return obuf
end

function upscale(ibuf)
  local xmax = ibuf.x
  local ymax = ibuf.y
  local zmax = ibuf.z
  
  local obuf = img.newBuffer(math.floor(xmax*2), math.floor(ymax*2), zmax)
  
  local i = ibuf.data
  local o = obuf.data
  
  for z = 0, zmax-1 do
    for x = 2, xmax-3 do
      for y = 2, ymax-3 do
	o[x*2][y*2][z] = (i[x][y][z]*f[2][2] +
	    (i[x-1][y][z]+i[x][y-1][z])*f[1][2] +
	    (i[x+1][y][z]+i[x][y+1][z])*f[0][2] +
	    (i[x+1][y-1][z]+i[x-1][y+1][z])*f[0][1] +
	    i[x-1][y-1][z]*f[1][1] + i[x+1][y+1][z]*f[0][0])*4
	    
	o[x*2+1][y*2][z] = (i[x][y][z]*f[2][2] +
	    (i[x+1][y][z]+i[x][y-1][z])*f[1][2] +
	    (i[x-1][y][z]+i[x][y+1][z])*f[0][2] +
	    (i[x+1][y+1][z]+i[x-1][y-1][z])*f[0][1] +
	    i[x+1][y-1][z]*f[1][1] + i[x-1][y+1][z]*f[0][0])*4
	    
	o[x*2][y*2+1][z] = (i[x][y][z]*f[2][2] +
	    (i[x-1][y][z]+i[x][y+1][z])*f[1][2] +
	    (i[x+1][y][z]+i[x][y-1][z])*f[0][2] +
	    (i[x+1][y+1][z]+i[x-1][y-1][z])*f[0][1] +
	    i[x-1][y+1][z]*f[1][1] + i[x+1][y-1][z]*f[0][0])*4
	    
	o[x*2+1][y*2+1][z] = (i[x][y][z]*f[2][2] +
	    (i[x-1][y][z]+i[x][y-1][z])*f[0][2] +
	    (i[x+1][y][z]+i[x][y+1][z])*f[1][2] +
	    (i[x+1][y-1][z]+i[x-1][y+1][z])*f[0][1] +
	    i[x-1][y-1][z]*f[0][0] + i[x+1][y+1][z]*f[1][1])*4
      end
    end
  end
  
  return obuf
end

function pyramid(ibuf)
  local xmax = ibuf.x
  local ymax = ibuf.y
  local zmax = ibuf.z
  
  local dbuf = img.newBuffer(xmax, ymax, zmax)
  
  local i = ibuf.data
  local d = dbuf.data
  
  local obuf = downscale(ibuf)
  local tbuf = upscale(obuf)
  
  local t = tbuf.data
  
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      for z = 0, zmax-1 do
	d[x][y][z] = i[x][y][z] - t[x][y][z]
      end
    end
  end
  
  
  return obuf, dbuf
end

function reverse(obuf, dbuf, fac)
  fac = fac or 1
  local ibuf = upscale(obuf)
  
  local xmax = ibuf.x
  local ymax = ibuf.y
  local zmax = ibuf.z
  
  local i = ibuf.data
  local d = dbuf.data
  
  for x = 0, xmax-1 do
    for y = 0, ymax-1 do
      for z = 0, zmax-1 do
	i[x][y][z] = i[x][y][z] + fac*d[x][y][z]
      end
    end
  end
  
  return ibuf
end

local l = {}
local d = {}

l[0] = bufi

local n = 7

for i = 1,n do
  tic()
  l[i], d[i] = pyramid(l[i-1])
  toc()
end

local fac = {0, 1, 0, 0, 0, 1, 0}

local r = l[n]
for i = n, 1, -1 do
  tic()
  r = reverse(r, d[i], fac[i] or 1)
  toc()
end

bufo = r

---[[
d = ppm.fromBuffer(bufo)
o = nil
bufo = nil
collectgarbage("collect")
d.name = "pyramid_out.png"
ppm.writeIM(d)
d = nil
print("Done!")
--]]