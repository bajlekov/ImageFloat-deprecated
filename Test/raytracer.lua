-- raytracer interpretation of https://gist.github.com/AdrianV/5774141

local ffi = require("ffi")

local width, height = 1280, 720
local fov = 45
local maxDepth = 6

ffi.cdef [[
struct vec{
	double x, y, z;
};
struct col{
	double r, g, b;
};
struct ray{
	struct vec o, n;
};
struct sph{
	struct vec c;
	double r;
};
]]

local Vec = ffi.typeof("struct vec")
local Col = ffi.typeof("struct col")
local Ray = ffi.typeof("struct ray")
local Sph = ffi.typeof("struct sph")

local function add(a, b) return Vec(a.x+b.x, a.y+b.y, a.z+b.z) end
local function sub(a, b) return Vec(a.x-b.x, a.y-b.y, a.z-b.z) end
local function mul(a, b) return Vec(a.x*b, a.y*b, a.z*b) end
local function div(a, b) return Vec(a.x/b, a.y/b, a.z/b) end
local function unm(a) return Vec(-a.x, -a.y, -a.z) end
local function echo(a) return "["..a.x..", "..a.y..", "..a.z.."]" end

local function asVec(a) return Vec(a, a, a) end

-- sph [center, radius, material]
-- tri [a, b, c, normal center, radius, material]
-- infplane [center, normal]
-- cyl [center, z, radius, height]

-- space transforms xyz <> sph
-- angle between vectors
local sqrt = math.sqrt
local atan2 = math.atan2
local acos = math.acos
local asin = math.asin
local sin, cos, tan = math.sin, math.cos, math.tan
local pi = math.pi

local function rad_deg(a) return a*180/pi end
local function deg_rad(a) return a*pi/180 end

local function dot(a, b) return a.x*b.x+a.y*b.y+a.z*b.z end
local function mag(a) return sqrt(dot(a,a)) end
local function norm(a) return a/mag(a) end

local function angle(a, b) return acos(dot(norm(a), norm(b))) end

local function xyz_sph(a)
	local rho = mag(a)
	local phi = atan2(a.y, a.x)
	local theta = acos(a.z/rho)
	return Vec(rho, phi, theta)
end

local function sph_xyz(a)
	local x = a.x*cos(a.y)*sin(a.z)
	local y = a.x*sin(a.y)*sin(a.z)
	local z = a.x*cos(a.z)
	return Vec(x, y, z)
end

local mt = {__add=add, __sub=sub, __mul=mul, __div=div, __unm=unm, __tostring=echo, __len=mag}

local Vec = ffi.metatype("struct vec", mt)

-- sphere tests:
-- check distances
-- check inside: dist<radius -> optimize
-- create min, max intersections
-- discard max<origin
-- optional: sort by distance, check nearest for isect
-- when valid intersect found, discard further with min>isect
-- perform shading on nearest isect



-- test for bounding sphere
local function testSphere(ray, sph) --ray, sphere -> isect, dist, conn
	local connVec = sph.c-ray.o
	local connMag = mag(connVec)
	local alpha = angle(ray.n, connVec)
		-- check inside, abort if opaque
	local dist = connMag*asin(alpha)
	if connMag<sph.r then -- early abort if inside
		return "inside", dist, connMag, alpha
	elseif dist<sph.r and alpha<pi/2 then
		return "outside", dist, connMag, alpha
	else
		return false
	end
end

-- intersection with sphere
local function isectSphere(ray, sph, dist, conn, alpha, inside) -- ray, sphere -> pos, dist
	local A = sqrt(conn^2 - dist^2)
	local B = sqrt(sph.r^2 - dist^2)
	
	if inside then
		return alpha<pi/2 and
			ray.o+ray.n*(B+A), (B+A) or
			ray.o+ray.n*(B-A), (B-A)
	else return ray.o+ray.n*(A-B), (A-B) end
end

local function reflectSphere(ray, sph, pos, dist) -- ray, sphere -> ray
	local sphNorm = (pos-sph.c)/sph.r
	local x = sphNorm*acos(angle(ray.n, sphNorm))
	return Ray(pos, ray.n-x*2)
end

local function rotX(i, t) -- input vector, theta
	local x = i.x
	local y = i.y*cos(t) - i.z*sin(t)
	local z = i.y*sin(t) + i.z*cos(t)
	return Vec(x, y, z) 
end

local function rotY(i, t) -- input vector, theta
	local y = i.y
	local x = i.x*cos(t) + i.z*sin(t)
	local z = -i.x*sin(t) + i.z*cos(t)
	return Vec(x, y, z) 
end

local function rotZ(i, t) -- input vector, theta
	local z = i.z
	local x = i.x*cos(t) - i.y*sin(t)
	local y = i.x*sin(t) + i.y*cos(t)
	return Vec(x, y, z) 
end

local function rotXYZ(i, tX, tY, tZ)
	return rotZ(rotY(rotX(i, tX), tY), tZ)
end

local function rotYZ(i, tY, tZ)
	return rotZ(rotY(i, tY), tZ)
end

local function getRotCoef(i) -- get required rotation factors to transform 0,0,1 to desired vector
	local sph = xyz_sph(i) -- rho, phi, theta
	return sph.z, sph.y -- rotY, rotZ
end

-- create ray from origin to direction on sensor
-- intersect ray with sphere
-- on intersect: spawn child ray(s), match with lamp, return fraction of reflectance
-- light falloff
-- calc reflection direction

local function camRayGenerator(origin, direction, distance) -- construct camera ray generator with input angles x, y
	local rY, rZ = getRotCoef(direction-origin)
	local scrO = rotYZ(Vec(-0.5, -0.5, distance), rY, rZ)
	local scrX = rotYZ(Vec(1, 0, 0), rY, rZ)
	local scrY = rotYZ(Vec(0, 1, 0), rY, rZ)
	
	return function(x, y)
		return Ray(origin, norm(scrO+scrX*x+scrY*y))		
	end
end
	
local rayGen = camRayGenerator(Vec(0,0,0), Vec(1,0,0), 10000)
print(rayGen(0,0).n)


