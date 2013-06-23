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
local ffi = require("ffi")

-- TODO: Extract base draw functions!!! to sdlDraw or similar!!!
local sdl = __sdl

-- interface draw
do
	local __dimX
	local __dimY
	local pixbuf
	local __surf

	--surface draw functions
	local function setSurface(surf)
		__surf = surf
		pixbuf = ffi.cast("uint8_t*", surf.pixels)
		__dimX = surf.w
		__dimY = surf.h
	end

	local function setPixel(x,y,r,g,b)
		if x>=0 and x<__dimX and y>=0 and y<__dimY then
			pixbuf[(x + __dimX*y)*4+3] = 255
			pixbuf[(x + __dimX*y)*4+2] = r
			pixbuf[(x + __dimX*y)*4+1] = g
			pixbuf[(x + __dimX*y)*4] = b
		end
	end

	local function setAlpha(x,y,a)
		if x>=0 and x<__dimX and y>=0 and y<__dimY then
	  		pixbuf[(x + __dimX*y)*4+3] = a
		end
	end


	local function hLine(x,y,l,r,g,b)
		for x = x, x+l-1 do
			setPixel(x,y,r,g,b)
		end
	end

	local function vLine(x,y,l,r,g,b)
		for y = y, y+l-1 do
			setPixel(x,y,r,g,b)
		end
	end

	local function boxFill(x1,y1,x2,y2,r,g,b)
		for x = x1, x2 do
			for y = y1, y2 do
				setPixel(x,y,r,g,b)
			end
		end
	end

	local function boxLine(x1,y1,x2,y2,r,g,b)
		for x = x1, x2 do
			for y = y1, y2, y2-y1 do
				setPixel(x,y,r,g,b)
			end
		end
		for x = x1, x2, x2-x1 do
			for y = y1, y2 do
				setPixel(x,y,r,g,b)
			end
		end
	end

	local function icon(file, x, y)
		local oi = sdl.loadImage(file)
		sdl.blit( oi, nil, __surf, sdl.rectangle(x, y, 0, 0))
	end

	local function text(text, font, x, y, r, g, b, a)
		local textObj = sdl.textCreate(text, font, r, g, b, a)
		sdl.blit(textObj, nil, __surf, sdl.rectangle(x, y, 0, 0))
		return textObj.w, textObj.h
	end

	local function textPut(textObj, x, y)
		sdl.blit(textObj, nil, __surf, sdl.rectangle(x, y, 0, 0))
	end


	--=======================================--
	local nlg = __global.imgPath.."nlg.png"
	local nlo = __global.imgPath.."nlo.png"
	local nrg = __global.imgPath.."nrg.png"
	local nro = __global.imgPath.."nro.png"
	local title = __global.imgPath.."titlebar.png"
	local cross = __global.imgPath.."cross-button.png"
	local function nodeL(x,y, flag)
		if flag then
			icon(nlg, x-6, y-6)
		else
			icon(nlo, x-6, y-6)
		end
	end

	local function nodeR(x,y, flag)
		if flag then
			icon(nrg, x-6, y-6)
		else
			icon(nro, x-6, y-6)
		end
	end


	local nodeSurf = {}

	function nodeDraw(self)

		local n = #self.param
		local x = 13
		local y = 2

		--buffer surface
		local surf
		if self.ui.buffer==nil then
			local surf_temp = sdl.createSurface(176, 26+12*n, 0)
			surf = _SDL.SDL_DisplayFormatAlpha(surf_temp)
			--sdl.destroySurface(surf_temp)
			setSurface(surf)
			setAlpha(0,0,0)
			setAlpha(175,0,0)
			setAlpha(0,25+12*n,0)
			setAlpha(175,25+12*n,0)
			
			hLine(x-12, y-2,174, 224,224,224)
			hLine(x-12, y+23+12*n,174, 224,224,224)
			vLine(x-13, y-1, 24+n*12, 224,224,224)
			vLine(x+162, y-1, 24+n*12, 224,224,224)
		else
			surf = self.ui.buffer
		end

		if self.ui.draw==true then
			setSurface(surf)
			sdl.blit(self.node.backgrounds.node, sdl.rectangle(0, 0, 174, 24+12*n), surf, sdl.rectangle(1, 1, 0, 0))
			--__sdl.fillRect(surf, NULL, __sdl.mapRGBA(surf,0, 0, 0, 128)); 
			--_SDL.SDL_SetAlpha(surf, 0x00010000, 0)

			--title
			icon(title, x, y)

			local nn = n
			for n = 0, nn-1 do
				
				if self.param[n+1].type=="value" then
					boxLine(x,y+21+n*12,x+149,y+23+n*12+10,64,64,64)
					local v = self.param[n+1].value
					v = math.floor(148*(v[1]-v[2])/(v[3]-v[2]))
					boxFill(x+v+1,y+22+n*12,x+148,y+32+n*12,mg())
					boxFill(x+1,y+22+n*12,x+v,y+32+n*12,96,96,96)

					local t = self.param[n+1].name..":"
					local tv = string.format("%.2f",self.param[n+1].value[1])
					text(t, font.normal, x+2, y+20+12*n)
					local f = sdl.textCreate(tv, font.normal)
					textPut(f,x+147-f.w, y+20+12*n)
				elseif self.param[n+1].type=="text" then
					if self.param[n+1].name~="" then
						text(self.param[n+1].name, font.normal, x+2, y+20+12*n, 64,64,64)
					end
					if self.param[n+1].value~="" then
						local f = sdl.textCreate(self.param[n+1].value, font.normal, 64,64,64)
						textPut(f,x+147-f.w, y+20+12*n)
					end
				end

				boxLine(x,y+21,x+149,y+11+nn*12+10,64,64,64)

			end	
			text(self.n..". "..self.ui.name, font.big, x+4, y+1, 192,192,192)
			--buttons
			icon(cross, x+130, y+2)

			--conns
			if #self.conn_i.list>0 then
				for _, v in ipairs(self.conn_i.list) do
					local flag = not v.node
					if v.pos==0 then
						nodeL(x-6,y+13, flag)
					else
						nodeL(x-6,y+27+(v.pos-1)*12, flag)
					end
				end 
			end
			
			if #self.conn_o.list>0 then
				for _, v in ipairs(self.conn_o.list) do
					local flag = not v.node
					if v.pos==0 then
						nodeR(x+155,y+13, flag)
					else
						nodeR(x+155,y+27+(v.pos-1)*12, flag)
					end
				end
			end

			self.ui.draw=false
		end

		x = self.ui.x-13
		y = self.ui.y-2
		
		self.ui.buffer = surf
		sdl.screenPut(surf, x, y)	
	end
end




function drawNoodleLoose(x1, y1, x2, y2, p1)
	local o1 = p1==0 and 0 or 2+12*p1
	drawLine(x1 + 155, y1 + 13 + o1, x1 + 169, y1 + 13 +o1, 255, 255, 128)
	drawLine(x2, y2, x2 - 14, y2, 255, 255, 128)
	drawLine(x1 + 169, y1 + 13 + o1, x2 - 14, y2, 255, 255, 128)
end

local function __drawNoodle(x1, y1, x2, y2, p1, p2, c1, c2, c3)
	local o1 = p1==0 and 0 or 2+12*p1
	local o2 = p2==0 and 0 or 2+12*p2
	drawLine(x1 + 155, y1 + 13 + o1, x1 + 169, y1 + 13 +o1, c1, c2, c3)
	drawLine(x2 - 6, y2 + 13 + o2, x2 - 20, y2 + 13 + o2, c1, c2, c3)
	drawLine(x1 + 169, y1 + 13 + o1, x2 - 20, y2 + 13 + o2, c1, c2, c3)
end

function drawNoodle(x1, y1, x2, y2, p1, p2)
	__drawNoodle(x1, y1, x2, y2, p1, p2, 255, 255, 128)
end
	---[[
function drawNoodles(node)
	local function drawNoodle(x1, y1, x2, y2, p1, p2)
		__drawNoodle(x1, y1, x2, y2, p1, p2, 128, 128, 128)
	end

	for _, node in ipairs(node) do
		if #node.conn_o.list>0 then
			for _,v in ipairs(node.conn_o.list) do
				if v.node then
					local x1, x2, y1, y2, p1, p2
					x1 = node.ui.x
					y1 = node.ui.y

					local c = v.node
					x2 = node.node[c].ui.x
					y2 = node.node[c].ui.y

					p1 = v.pos
					p2 = v.port

					drawNoodle(x1, y1, x2, y2, p1, p2)
				end
			end
		end
	end
end
