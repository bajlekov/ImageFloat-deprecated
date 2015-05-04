--[[
Copyright (C) 2011-2014 G. Bajlekov

Imagefloat is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Imagefloat is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- compile and run halide pipelines

local ffi = require("ffi")

local halide = {}
halide.path = "/home/galin/Downloads/halide"
halide.precision = "float"

local hHeader1 = [[
#include "Halide.h"
using namespace Halide;
]]

local hHeader2 = [[
int main(int argc, char **argv) {
]]

local hFooter = [[
return 0;
}
]]

ffi.cdef[[
typedef struct buffer_t {
	uint64_t dev;
	uint8_t* host;
	int32_t extent[4];
	int32_t stride[4];
	int32_t min[4];
	int32_t elem_size;
	__attribute__((aligned(1))) bool host_dirty;
	__attribute__((aligned(1))) bool dev_dirty;
	__attribute__((aligned(1))) uint8_t _padding[10 - sizeof(void *)];
} buffer_t;
]] -- initiate buffer type

-- compile halide pipeline, return initialising function
function halide.compile(bufOut, bufIn, params, algorithm, schedule, global, name)
	assert(type(bufOut)=="string", "only single named buffer implemented")
	schedule = schedule or ""
	global = global or ""
	params = params or {}
	name = name or bufOut
	
	-- generate inputs string
	local hInput = {}
	local hParams = {}
	local i = 1
	for _, v in pairs(bufIn) do
		if type(v)=="string" then v = {v, 3, true} end
		if v[3]==nil then v[3] = true end
		if v[2]==nil then v[2] = 3 end
		assert(type(v)=="table")
		
		local s = "ImageParam "..v[1].."(type_of<"..halide.precision..">(), "..v[2]..");\n"
		if v[3] then s = s..v[1]..".set_stride(0, Expr());\n" end
		hInput[i] = s
		hParams[i] = v[1]
		i = i + 1
	end
	for _, v in ipairs(params) do
		hInput[i] = "Param<"..halide.precision.."> "..v..";\n"
		hParams[i] = v
		i = i + 1
	end
	hInput = table.concat(hInput)
	
	local hExport
	hExport = bufOut..".compile_to_file(\""..name.."\", {"..table.concat(hParams, ", ").."});\n"
	hExport = bufOut..".output_buffer().set_stride(0, Expr());\n"..hExport
	-- TODO: multiple output buffers... only possible with known variables? or just dimensionality?
	
	local hCompile = [[
	g++ ]]..name..[[Source.cpp -std=c++11 -I ]]..halide.path..[[/include -L ]]..halide.path..[[/bin -lHalide -lpthread -ldl -o ]]..name..[[Generator
	LD_LIBRARY_PATH=]]..halide.path..[[/bin ./]]..name..[[Generator
	gcc -shared -lpthread -o lib]]..name..[[.so ]]..name..[[.o
	]]
	
	local f = io.open(name.."Source.cpp", "w")
	f:write(hHeader1)
	f:write(global)
	f:write(hHeader2)
	f:write(hInput)
	f:write(algorithm)
	f:write(schedule)
	f:write(hExport)
	f:write(hFooter)
	f:close()
	
	--print(hHeader..hInput..algorithm..schedule..hExport..hFooter)
	
	print("Compiling "..name.."...")
	os.execute(hCompile)
	
	os.remove(name.."Source.cpp")
	os.remove(name.."Generator")
	os.remove(name..".h")
	os.remove(name..".o")
	
	local cdef = "int "..name.."("..string.rep("buffer_t*, ", #bufIn)..string.rep(halide.precision..", ", #params).."buffer_t*);"
	
	-- write out a file doing exactly this as well
	local hLoad = [[
	-- Automatically generated loader for Halide library
	
	local ffi = require("ffi")
	ffi.cdef"]]..cdef..[["
	local lib = ffi.load("lib]]..name..[[.so")
	return lib["]]..name..[["]
	]]
	
	local f = io.open(name..".lua", "w")
	f:write(hLoad)
	f:close()
	
	return function()
		ffi.cdef(cdef)
		local lib = ffi.load("lib"..name..".so")
		return lib[name]
	end
end

-- create appropriate halide buffers from image
local pos = {}
pos.AoS = {}
pos.SoA = {}
function pos.AoS.XY(x, y, z) return y*z, z, 1 end
function pos.AoS.YX(x, y, z) return z, x*z, 1 end
function pos.SoA.XY(x, y, z) return y, 1, x*y end
function pos.SoA.YX(x, y, z) return 1, x, x*y end

function halide.buffer(image)
	local x, y, z = pos[image.pack][image.order](image.x, image.y, image.z)
	
	local buffer = ffi.new("buffer_t", 0)
	buffer.host = ffi.cast("uint8_t*", image.data)
	
	buffer.stride[0] = x
	buffer.stride[1] = y
	buffer.stride[2] = z
	
	buffer.extent[0] = image.x
	buffer.extent[1] = image.y
	buffer.extent[2] = image.z
	buffer.elem_size = 4 -- always 4 for floats
	return buffer
end

--return(halide)

-- TEST
local sdl = require("Include.sdl2")
local img = require("Test.Data.data")
local ppm = require("Tools.ppmtools")

local hCompute = [[
Func brighter;
Var x, y, c;
brighter(x, y, c) = input(x, y, c) * gain *(input.height()-y)/input.height();
]]

local hSchedule = [[
brighter.parallel(y).vectorize(y,16);
]]

--local fun = halide.compile("brighter",{"input"}, {"gain"}, hCompute, hSchedule)()
local fun = require("brighter")

local image = ppm.toBuffer(ppm.readFile("img.ppm"))
local imageOut = image:new()
--image:toSoA():toYX()
--imageOut:toSoA():toYX()

local bin = halide.buffer(image)
local bout = halide.buffer(imageOut)

local offset = 3

sdl.tic()
for i = 1, 100 do
	local err = fun(bin, offset, bout)
end
sdl.toc("done")

ppm.writeIM(ppm.fromBuffer(imageOut,16,"halideOut.png"))




local updownsample = [[
Var x, y;

Func downsample(Func f) {
    Func downx, downy;
    downx(x, y, _) = (f(2*x-1, y, _) + 3.0f * (f(2*x, y, _) + f(2*x+1, y, _)) + f(2*x+2, y, _)) / 8.0f;
    downy(x, y, _) = (downx(x, 2*y-1, _) + 3.0f * (downx(x, 2*y, _) + downx(x, 2*y+1, _)) + downx(x, 2*y+2, _)) / 8.0f;
    return downy;
}

Func upsample(Func f) {
    Func upx, upy;
    upx(x, y, _) = 0.25f * f((x/2) - 1 + 2*(x % 2), y, _) + 0.75f * f(x/2, y, _);
    upy(x, y, _) = 0.25f * upx(x, (y/2) - 1 + 2*(y % 2), _) + 0.75f * upx(x, y/2, _);
    return upy;
}
]]

local llc = [[
	const int J = 8;
	
	Func floating = BoundaryConditions::repeat_edge(input);
	
	Func gray;
	gray(x, y) = 0.299f * floating(x, y, 0) + 0.587f * floating(x, y, 1) + 0.114f * floating(x, y, 2);
	
	Func remap;
	Expr fx = cast<float>(x) / 256.0f;
	remap(x) = alpha*fx*exp(-fx*fx/2.0f);
	
	Var c, k;
	
	Func gPyramid[J];
	Expr level = k * (1.0f / (levels - 1));
	Expr idx = gray(x, y)*cast<float>(levels-1)*256.0f;
	idx = clamp(cast<int>(idx), 0, (levels-1)*256);
	gPyramid[0](x, y, k) = beta*(gray(x, y) - level) + level + remap(idx - 256*k);
	for (int j = 1; j < J; j++) {
		gPyramid[j](x, y, k) = downsample(gPyramid[j-1])(x, y, k);
	}
	
	Func lPyramid[J];
	lPyramid[J-1](x, y, k) = gPyramid[J-1](x, y, k);
	for (int j = J-2; j >= 0; j--) {
		lPyramid[j](x, y, k) = gPyramid[j](x, y, k) - upsample(gPyramid[j+1])(x, y, k);
	}
	
	Func inGPyramid[J];
	inGPyramid[0](x, y) = gray(x, y);
	for (int j = 1; j < J; j++) {
		inGPyramid[j](x, y) = downsample(inGPyramid[j-1])(x, y);
	}
	
	Func outLPyramid[J];
	for (int j = 0; j < J; j++) {
		Expr level = inGPyramid[j](x, y) * cast<float>(levels-1);
		Expr li = clamp(cast<int>(level), 0, levels-2);
		Expr lf = level - cast<float>(li);
		outLPyramid[j](x, y) = (1.0f - lf) * lPyramid[j](x, y, li) + lf * lPyramid[j](x, y, li+1);
	}
	
	Func outGPyramid[J];
	outGPyramid[J-1](x, y) = outLPyramid[J-1](x, y);
	for (int j = J-2; j >= 0; j--) {
		outGPyramid[j](x, y) = upsample(outGPyramid[j+1])(x, y) + outLPyramid[j](x, y);
	}
	
	Func color;
	float eps = 0.01f;
	color(x, y, c) = outGPyramid[0](x, y) * (floating(x, y, c)+eps) / (gray(x, y)+eps);
]]

local schedule = [[
	remap.compute_root();
	color.parallel(y, 4).vectorize(x, 8);
	gray.compute_root().parallel(y, 4).vectorize(x, 8);
	for (int j = 0; j < 4; j++) {
		if (j > 0) inGPyramid[j].compute_root().parallel(y, 4).vectorize(x, 16);
		if (j > 0) gPyramid[j].compute_root().parallel(y, 4).vectorize(x, 16);
		outGPyramid[j].compute_root().parallel(y, 4).vectorize(x, 16);
	}
	for (int j = 4; j < J; j++) {
		inGPyramid[j].compute_root().parallel(y);
		gPyramid[j].compute_root().parallel(k);
		outGPyramid[j].compute_root().parallel(y);
	}
]]

sdl.tic()
--local fun = halide.compile("color", {"input"}, {"levels", "alpha", "beta"}, llc, schedule, updownsample, "LocalLaplacianPyramid")()
local fun = require("LocalLaplacianPyramid")
sdl.toc("llc compile")

sdl.tic()
local err = fun(bin, 3, 0, 5, bout)
sdl.toc("llc run")
print(err)

ppm.writeIM(ppm.fromBuffer(imageOut,16,"llcOut.png"))

print("done")
