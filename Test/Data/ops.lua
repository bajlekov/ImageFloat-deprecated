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

local unroll = require("Tools.unroll")
local sdl = __sdl
local ffi = require("ffi")

return function(img)

	local function scaleNorm(c, x, y, out, count)
		out:set(x,y,c, out:get(x,y,c) / count:get(x,y,0))
	end
	--weighted rescale
	local function scaleDownHQ(c, nx, ny, x, y, out, buffer, rx, ry)
		local t = out:get(nx,ny,c) + buffer:get(x,y,c) * rx * ry
		out:set(nx, ny, c, t)
	end
	function img.scaleDownHQ(buffer, sc)
		local out = img:new(math.ceil(buffer.x / sc), math.ceil(buffer.y / sc), buffer.z)
		local count = out:new(nil, nil, 1)
		for x = 0, buffer.x-1 do
			local nx = math.floor(x/sc)
			local rx = math.abs(x % sc - 0.5 * sc)
			for y = 0, buffer.y-1 do
				local ny = math.floor(y/sc)
				local ry = math.abs(y % sc - 0.5 * sc)
				unroll[buffer.z](scaleDownHQ, nx, ny, x, y, out, buffer, rx, ry)
				count:set(nx,ny,0, count:get(nx,ny,1) + rx * ry)
			end
		end
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				unroll[buffer.z](scaleNorm, x, y, out, count)
			end
		end
		return out
	end
	
	local function scaleDownQuad(c, x, y, out, buffer)
		out:set(x,y,c, buffer:get(x*4,y*4,c))
	end
	function img.scaleDownQuad(buffer)
		sdl.tic()
		local out = img:new(math.floor(buffer.x / 4), math.floor(buffer.y / 4), buffer.z)
		out.cs = buffer.cs
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				unroll[buffer.z](scaleDownQuad, x, y, out, buffer)
			end
		end
		sdl.toc("downscale")
		return out
	end
	
	local unroll344 = unroll.construct(0,2,0,3,0,3)
	local unroll44 = unroll.construct(0,3,0,3)
	 
	local function scaleUpQuad(c, m, n, x, y, out, buffer)
		out:set(x*4+m,y*4+n,c, buffer:get(x,y,c))
	end
	function img.scaleUpQuad(buffer)
		assert(buffer.z==3 or buffer.z==1)
		local out = img:new(buffer.x * 4, buffer.y * 4, buffer.z)
		out.cs = buffer.cs
		for x = 0, buffer.x-1 do
			for y = 0, buffer.y-1 do
				unroll344(scaleUpQuad, x, y, out, buffer)
			end
		end
		return out
	end
	
	
		local alpha = bit.lshift(255,-8)
	function img.toSurface(buffer, surface)
		surface = surface or sdl.surf.new(buffer.x, buffer.y)
		local surf = ffi.cast("uint32_t*", surface.pixels)
		if buffer.z==3 then
			for x = 0, buffer.x-1 do
				for y = 0, buffer.y-1 do
					local br, bg, bb
					br = buffer:get(x,y,0)
					bg = buffer:get(x,y,1)
					bb = buffer:get(x,y,2)
					br = br>1 and 255 or br<0 and 0 or br*255
					bg = bg>1 and 255 or bg<0 and 0 or bg*255
					bb = bb>1 and 255 or bb<0 and 0 or bb*255
					surf[(x + buffer.x * y)] = bit.lshift(br,-16)+bit.lshift(bg, 8)+math.floor(bb)+alpha
				end
			end
		elseif buffer.z==1 then
			for x = 0, buffer.x-1 do
				for y = 0, buffer.y-1 do
					local br
					br = buffer:get(x,y,0)
					br = br>1 and 255 or br<0 and 0 or br*255
					surf[(x + buffer.x * y)] = bit.lshift(br,-16)+bit.lshift(br, 8)+math.floor(br)+alpha
				end
			end
		end
		
		return surface
	end

	local function toQuadFun(xx, yy, bx, by, br, bg, bb, surf, buffer)
		local x = bx*4+xx
		local y = by*4+yy
		surf[(x + (buffer.x*4) * y) * 4 + 2] = br
		surf[(x + (buffer.x*4) * y) * 4 + 1] = bg
		surf[(x + (buffer.x*4) * y) * 4 + 0] = bb
	end
	local function toQuad(buffer, surf) -- buffer upscaled to surface
		for bx = 0, buffer.x-1 do
			for by = 0, buffer.y-1 do
				local br, bg, bb
				if buffer.z==3 then
					br = buffer:get(bx,by,0)
					bg = buffer:get(bx,by,1)
					bb = buffer:get(bx,by,2)
					br = br>1 and 255 or br<0 and 0 or br*255
					bg = bg>1 and 255 or bg<0 and 0 or bg*255
					bb = bb>1 and 255 or bb<0 and 0 or bb*255
				elseif buffer.z==1 then
					br = buffer:get(bx,by,0)
					br = br>1 and 255 or br<0 and 0 or br*255
					bg, bb = br, br
				end
				unroll44(toQuadFun, bx, by, br, bg, bb, surf, buffer)
			end
		end
	end
	
	function img.toSurfaceQuad(buffer, surface)
		surface = surface or __sdl.createSurface(buffer.x, buffer.y, 0)
		local surf = ffi.cast("uint8_t*", surface.pixels)
		toQuad(buffer, surf)
	end
	function img.toScreenQuad(buffer)
		local surf = __sdl.pixbuf()
		toQuad(buffer, surf)
	end

	function img.pixelOp(buffer, op)
		for x = 0, buffer.x-1 do
			for y = 0, buffer.y-1 do
				local a, b, c = buffer:get3(x,y)
				a, b, c = op(a, b, c, x, y)
				buffer:set3(x, y, a, b, c)
			end
		end
	end

	function img.csConvert(buffer, cs)
		__lua.threadSetup({buffer, buffer}, 1, 1)
		__lua.threadRunWait("ops", "cs", buffer.cs, cs)
		buffer.cs = cs
	end

	function img.invert(buffer)
		-- check for multiple cs using luminance
		local buffac = buffer.cs=="LAB" and img.newBuffer({1,0,0}) or img.newBuffer({1,1,1})
		__lua.threadSetup({buffer, buffac, buffer}, 2, 1)
		__lua.threadRunWait("ops", "invert")
	end
	
	function img.grayscale(buffer)
		if buffer.z==1 then
			return buffer:copy()
		elseif buffer.z==3 then
			local out = buffer:new(nil, nil, 1)
			if out.order=="YX" then		-- use loops aligned with the target for better performance
				for y = 0, out.y-1 do
					for x = 0, out.x-1 do
						local a, b, c = buffer:get3(x, y)
						local abc = (a+b+c)
						out:set(x, y, 0, abc)
					end
				end
			else
				for x = 0, out.x-1 do
					for y = 0, out.y-1 do
						local a, b, c = buffer:get3(x, y)
						local abc = (a+b+c)
						out:set(x, y, 0, abc)
					end
				end
			end
			return out
		else
			error("Grayscale: Incompatible number of channels")
		end
	end
	
	function img.color(buffer) return buffer:copy(nil, nil, 3) end
end