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
local ffi = require("ffi")

-- TODO: Extract base draw functions!!! to sdlDraw or similar!!!
local sdl = __sdl

local function icon(file, x, y)
	local oi = sdl.draw.image(x, y, file) -- FIXME!!!
end

local function text(text, font, x, y, r, g, b, a)
	local textObj = sdl.textCreate(text, font, r, g, b, a)
	sdl.blit(textObj, nil, __surf, sdl.rect(x, y, 0, 0))
	return textObj.w, textObj.h
end

local function textPut(textObj, x, y)
	sdl.blit(textObj, nil, __surf, sdl.rect(x, y, 0, 0))
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

global("nodeDraw") -- FIXME
function nodeDraw(self)

	local n = #self.param
	local x = 13
	local y = 2

	--buffer surface
	local surf = sdl.surf.new(176, 26+12*n)
	if self.ui.buffer==nil then
		sdl.surf.attach(surf)
		
		sdl.draw.color(128,128,128)
		sdl.draw.box(x-13, y-2, 175, 25+n*12)
		
		sdl.draw.alpha(0,0,0)
		sdl.draw.alpha(175,0,0)
		sdl.draw.alpha(0,25+12*n,0)
		sdl.draw.alpha(175,25+12*n,0)
	else
		surf = self.ui.buffer
	end

	if self.ui.draw==true then
		sdl.surf.attach(surf)
		sdl.surf.copy(self.node.backgrounds.node, surf, sdl.rect(0, 0, 174, 24+12*n), sdl.rect(1, 1, 0, 0))

		icon(title, x, y)

		local nn = n
		for n = 0, nn-1 do
			
			if self.param[n+1].type=="value" then
				sdl.draw.color(64,64,64)
				sdl.draw.box(x,y+21+n*12,149,12)
				local v = self.param[n+1].value
				v = math.floor(148*(v[1]-v[2])/(v[3]-v[2]))
				
				sdl.draw.color(128,128,128)
				sdl.draw.fill(x+v+1,y+22+n*12,148-v,11)
				sdl.draw.color(96,96,96)
				sdl.draw.fill(x+1,y+22+n*12,v,11)
				
				local t = self.param[n+1].name..":"
				local tv = string.format("%.2f",self.param[n+1].value[1])
				sdl.font.color(224,224,224)
				sdl.draw.text(x+2, y+20+12*n, t)
				local f = sdl.font.text(tv)
				sdl.surf.put(f,x+147-f.w, y+20+12*n)
			elseif self.param[n+1].type=="text" then
				sdl.font.color(64,64,64)
				if self.param[n+1].name~="" then
					sdl.draw.text(x+2, y+20+12*n, self.param[n+1].name)
				end
				if self.param[n+1].value~="" then
					local f = sdl.font.text(self.param[n+1].value)
					sdl.surf.put(f,x+147-f.w, y+20+12*n)
				end
			end
			
			sdl.draw.color(64,64,64)
			sdl.draw.box(x,y+21,149,nn*12)

		end
		sdl.font.color(224,224,224)
		sdl.font.size(14)
		sdl.draw.text(x+4, y+1, self.n..". "..self.ui.name)
		sdl.font.size(11) -- revert to regular size!
		
		--buttons
		if not self.ui.noClose then
			icon(cross, x+130, y+2)
		end

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
	sdl.screen.put(surf, x, y)	
end


global("drawNoodleLoose") -- FIXME
function drawNoodleLoose(x1, y1, x2, y2, p1)
	sdl.surf.attach()
	sdl.draw.color(192,64,64)
	local o1 = p1==0 and 0 or 2+12*p1
	sdl.draw.line(x1 + 159, y1 + 13 + o1, 10, 0)
	sdl.draw.line(x2-14, y2, 14, 0)
	sdl.draw.line(x1 + 169, y1 + 13 + o1, x2 - 14 - x1 - 169, y2 - y1 - 13 - o1)
end

local function __drawNoodle(x1, y1, x2, y2, p1, p2, c1, c2, c3)
	sdl.surf.attach()
	sdl.draw.color(192,192,192)
	local o1 = p1==0 and 0 or 2+12*p1
	local o2 = p2==0 and 0 or 2+12*p2
	sdl.draw.line(x1 + 159, y1 + 13 + o1, 10, 0)
	sdl.draw.line(x2 - 20, y2 + 13 + o2, 10, 0)
	sdl.draw.line(x1 + 169, y1 + 13 + o1, x2 - 20-x1-169, y2 + 13 + o2-y1-13-o1)
end

global("drawNoodle") -- FIXME
function drawNoodle(x1, y1, x2, y2, p1, p2)
	__drawNoodle(x1, y1, x2, y2, p1, p2)
end

global("drawNoodles") -- FIXME
function drawNoodles(node)
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
