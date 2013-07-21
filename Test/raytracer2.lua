-- raytracer interpretation of https://gist.github.com/IainNZ/6044280

local ffi = require("ffi")

-- math functions
local sqrt = math.sqrt
local atan2 = math.atan2
local acos = math.acos
local asin = math.asin
local sin, cos, tan = math.sin, math.cos, math.tan
local pi = math.pi
local inf = math.huge

-- types
ffi.cdef [[
struct vec{
	double x, y, z;
};
struct ray{
	struct vec orig;
	struct vec dir;
};
struct hit{
	double lambda;
	struct vec normal;
};
struct sph{
	struct vec center;
	double radius;
};
]]

local Vec = ffi.typeof("struct vec")
local Ray = ffi.typeof("struct ray")
local Hit = ffi.typeof("struct hit")
local Sphere = ffi.typeof("struct sph")

local function add(a, b) return Vec(a.x+b.x, a.y+b.y, a.z+b.z) end
local function sub(a, b) return Vec(a.x-b.x, a.y-b.y, a.z-b.z) end
local function mul(a, b) return Vec(a.x*b, a.y*b, a.z*b) end
local function div(a, b) return Vec(a.x/b, a.y/b, a.z/b) end
local function unm(a) return Vec(-a.x, -a.y, -a.z) end
local function echo(a) return "["..a.x..", "..a.y..", "..a.z.."]" end
local function dot(a, b) return a.x*b.x+a.y*b.y+a.z*b.z end
local function mag(a) return sqrt(dot(a,a)) end
local function norm(a) return a/mag(a) end

local mt = {__add=add, __sub=sub, __mul=mul, __div=div, __unm=unm, __tostring=echo, __len=mag}
local Vec = ffi.metatype("struct vec", mt)

-- implementation
local function ray_sphere(s, ray)
	local v = s.center - ray.orig
	local b = dot(v, ray.dir)
	local disc = b*b - dot(v, v) + s.radius*s.radius
	if disc>=0 then
		local d = sqrt(disc)
		local t2 = b+d
		if t2>=0 then
			local t1 = b-d
			return t1>0 and t1 or t2
		end
	end
	return inf
end

local function intersectS(s, i, ray)
	local l = ray_sphere(s, ray)
	if l>=i.lambda then
		return i
	else
		local n = ray.orig + ray.dir*l - s.center
		return Hit(l, norm(n))
	end
end

local function Group(b, o)
	return {bound=b, objs=o or {}}
end

local function intersect(g, i, ray)
	if type(g)=="cdata" then return intersectS(g, i, ray) end
	local l = ray_sphere(g.bound, ray)
	if l>=i.lambda then
		return i
	else
		for _,j in ipairs(g.objs) do
			i = intersect(j, i, ray) 
		end
		return i
	end
end

local delta = 1.4901161193847656e-8
local function ray_trace(light, ray, scene)
	local i = intersect(scene, Hit(inf, Vec(0,0,0)), ray)
	if i.lambda==inf then return 0 end
	local o = ray.orig+ray.dir*i.lambda+i.normal*delta
	local g = dot(i.normal, light)
	if g>=0 then return 0 end
	local sray = Ray(o, light*-1)
	local si = intersect(scene, Hit(inf, Vec(0,0,0)), sray)
	return si.lambda==inf and -g or 0
end

local function create(level, c, r)
	local sphere = Sphere(c, r)
	if level == 1 then
		return sphere
	end
	local group = Group(Sphere(c, 3*r))
	table.insert(group.objs, sphere)
	local rn = 3*r/sqrt(12)
	for dz = -1, 1, 2 do
		for dx = -1, 1, 2 do
			local c2 = c + Vec(dx*rn, rn, dz*rn)
			table.insert(group.objs, create(level-1, c2, r/2))
		end
	end
	return group
end

local function Raytracer(levels, n, ss)
	local scene = create(levels, Vec(0, -1, 0), 1)
	local light = norm(Vec(-1, -3, 2))
	local f = io.open("output.pgm", "w")
	f:write("P5\n",n," ",n,"\n",255,"\n")
	for y = (n-1), 0, -1 do
		for x = 0, (n-1), 1 do
			local g = 0
			for dx = 0, (ss-1) do
				for dy = 0, (ss-1) do
					local d = Vec(x+dx*1/ss-n/2, y+dy*1/ss-n/2, n*1)
					local ray = Ray(Vec(0, 0, -4), norm(d))
					g = g + ray_trace(light, ray, scene);
				end
			end
			f:write(math.floor(0.5 + 255 * g / (ss*ss)))
		end
	end
	f:close()
end

Raytracer(1, 100, 1)

print("check!")



