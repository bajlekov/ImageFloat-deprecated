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

local prec = __global.setup.bufferPrecision

return function(img)

	--float buffer square aperture scaling
	function img.scaleDown(buffer, sc)
		local out = img:new(math.ceil(buffer.x / sc), math.ceil(buffer.y / sc), buffer.z)
		out.cs = buffer.cs
		local count = ffi.new(prec[1].."["..tonumber(out.x).."]["..tonumber(out.y).."]")
		for x = 0, buffer.x-1 do
			local nx = math.floor(x/sc)
			for y = 0, buffer.y-1 do
				local ny = math.floor(y/sc)
				for c = 0, buffer.z-1 do
					local t = out:get(nx,ny,c) + buffer:get(x,y,c)
					out:set(nx,ny,c, t)
				end
				count[nx][ny] = count[nx][ny] + 1
			end
		end
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				for c = 0, buffer.z-1 do
					out:set(x,y,c, out.data[x][y][c] / count[x][y])
				end
			end
		end
		return out
	end

	--weighted rescale
	function img.scaleDownHQ(buffer, sc)
		local out = img:new(math.ceil(buffer.x / sc), math.ceil(buffer.y / sc), buffer.z)
		out.cs = buffer.cs
		local count = ffi.new(prec[1].."["..tonumber(out.x).."]["..tonumber(out.y).."]")
		for x = 0, buffer.x-1 do
			local nx = math.floor(x/sc)
			local rx = math.abs(x % sc - 0.5 * sc)
			for y = 0, buffer.y-1 do
				local ny = math.floor(y/sc)
				local ry = math.abs(y % sc - 0.5 * sc)
				for c = 0, 2 do
					local t = out:get(nx,ny,c) + buffer:get(x,y,c) * rx * ry
					out:set(nx, ny, c, t)
				end
				count[nx][ny] = count[nx][ny] + rx * ry
			end
		end
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				for c = 0, 2 do
					out:set(x,y,c, out:get(x,y,c) / count[x][y])
				end
			end
		end
		return out
	end

	--nearest neighbor scaling
	function img.scaleDownFast(buffer, sc)
		local out = img:new(math.ceil(buffer.x / sc), math.ceil(buffer.y / sc), buffer.z)
		out.cs = buffer.cs
		for x = 0, out.x-1 do
			local nx = x*sc
			for y = 0, out.y-1 do
				local ny = y*sc
				for c = 0, 2 do
					out:set(x,y,c, buffer:get(nx,ny,c))
				end
			end
		end
		return out
	end

	--nearest neighbor
	function img.scaleUpFast(buffer, sc)
		local out = img:new(math.floor(buffer.x * sc), math.floor(buffer.y * sc), buffer.z)
		out.cs = buffer.cs
		for x = 0, out.x-1 do
			local nx = math.floor(x/sc)
			for y = 0, out.y-1 do
				local ny = math.floor(y/sc)
				for c = 0, 2 do
					local t = out:get(x,y,c) + buffer:get(nx,ny,c)
					out:set(x,y,c, t)
				end
			end
		end
		return out
	end

	function img.scaleDownQuad(buffer)
		local out = img:new(math.floor(buffer.x / 4), math.floor(buffer.y / 4), buffer.z)
		out.cs = buffer.cs
		for x = 0, out.x-1 do
			for y = 0, out.y-1 do
				for c = 0, 2 do
					out:set(x,y,c, buffer:get(x*4,y*4,c))
				end
			end
		end
		return out
	end

	function img.scaleUpQuad(buffer)
		local out = img:new(buffer.x * 4, buffer.y * 4, buffer.z)
		out.cs = buffer.cs
		for x = 0, buffer.x-1 do
			for y = 0, buffer.y-1 do
				for c = 0, 2 do
					for m = 0, 3 do
						for n = 0, 3 do 
							out:set(x*4+m,y*4+n,c, buffer:get(x,y,c))
						end
					end
				end
			end
		end
		return out
	end

	-- bilinear scaling for scales smaller than 100%

	--[[float buffer to screen buffer
	function img.toScreen(buffer)
		local surf = ffi.cast("uint32_t*", __sdl.pixbuf())
		for x = 0, buffer.x-1 do
			for y = 0, buffer.y-1 do
				local br, bg, bb
				br = buffer.data[x][y][0]
				bg = buffer.data[x][y][1]
				bb = buffer.data[x][y][2]
				br = br>1 and 255 or br*255
				bg = bg>1 and 255 or bg*255
				bb = bb>1 and 255 or bb*255
				br = br<0 and 0 or br
				bg = bg<0 and 0 or bg
				bb = bb<0 and 0 or bb
				surf[(x + buffer.x * y)] = bit.lshift(br, 16)+bit.lshift(bg, 8)+bb
			end
		end
	end
	--]]

	function img.toSurface(buffer, surface)
		surface = surface or __sdl.createSurface(buffer.x, buffer.y, 0)
		local surf = ffi.cast("uint32_t*", surface.pixels)
		--local surf = ffi.cast("uint8_t*", surface.pixels)
		

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
					surf[(x + buffer.x * y)] = bit.lshift(br,-16)+bit.lshift(bg, 8)+math.floor(bb)
				end
			end
		elseif buffer.z==1 then
			for x = 0, buffer.x-1 do
				for y = 0, buffer.y-1 do
					local br
					br = buffer:get(x,y,0)
					br = br>1 and 255 or br<0 and 0 or br*255
					surf[(x + buffer.x * y)] = bit.lshift(br,-16)+bit.lshift(br, 8)+math.floor(br)
				end
			end
		end

		return surface
	end

	function img.toSurfaceQuad(buffer, surface)
		surface = surface or __sdl.createSurface(buffer.x, buffer.y, 0)
		local surf = ffi.cast("uint8_t*", surface.pixels)
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
				for x=bx*4, bx*4+3 do
					for y=by*4, by*4+3 do
						surf[(x + (buffer.x*4) * y) * 4 + 2] = br
						surf[(x + (buffer.x*4) * y) * 4 + 1] = bg
						surf[(x + (buffer.x*4) * y) * 4 + 0] = bb
					end
				end
			end
		end
	end

	function img.toScreenQuad(buffer)
		local screen = __sdl.pixbuf()
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
				for x=bx*4, bx*4+3 do
					for y=by*4, by*4+3 do
						screen[(x + (buffer.x*4) * y) * 4 + 2] = br
						screen[(x + (buffer.x*4) * y) * 4 + 1] = bg
						screen[(x + (buffer.x*4) * y) * 4 + 0] = bb
					end
				end
			end
		end
	end

	--TODO: Move rest to different utility library!

	--float buffer pixel ops
	--FIXME: work with all types of buffers!
	function img.pixelOp(buffer, op)
		for x = 0, buffer.x-1 do
			for y = 0, buffer.y-1 do
				local a, b, c = buffer:get3(x,y)
				a, b, c = op(a, b, c, x, y)
				buffer:set3(x, y, a, b, c)
			end
		end
	end
	
	--[[
	function img.max(buffer)
		local m1 = -math.huge
		local m2 = m1
		local m3 = m1
		for x = 0, buffer.x-1 do
			for y = 0, buffer.y-1 do
				local c1, c2, c3 = buffer.data[x][y][0], buffer.data[x][y][1], buffer.data[x][y][2]
				m1 = c1>m1 and c1 or m1
				m2 = c2>m2 and c2 or m2
				m3 = c3>m3 and c3 or m3
			end
		end
		return m1, m2, m3
	end

	function img.min(buffer)
		local m1 = math.huge
		local m2 = m1
		local m3 = m1
		for x = 0, buffer.x-1 do
			for y = 0, buffer.y-1 do
				local c1, c2, c3 = buffer.data[x][y][0], buffer.data[x][y][1], buffer.data[x][y][2]
				m1 = c1<m1 and c1 or m1
				m2 = c2<m2 and c2 or m2
				m3 = c3<m3 and c3 or m3
			end
		end
		return m1, m2, m3
	end
	--]]

	function img.csConvert(buffer, cs)
		__lua.threadSetup({buffer, buffer}, 1, 1)
		__lua.threadRunWait("ops", "cs", buffer.cs, cs)
		buffer.cs = cs
	end

	function img.invert(buffer)
		buffac = buffer.cs=="LAB" and img.newBuffer({1,0,0}) or img.newBuffer({1,1,1})
		__lua.threadSetup({buffer, buffac, buffer}, 2, 1)
		__lua.threadRunWait("ops", "invert")
	end

end