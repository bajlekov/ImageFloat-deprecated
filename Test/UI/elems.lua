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

-- implementation of elems

return function(actions)
local sdl = __sdl

actions.elem.text.spec = {height=14}
function actions.elem.text.draw(elem)
	local x, y = elem.frame.x, elem.frame.y
	local w, h = elem.frame.w, elem.frame.h
	local k = elem.num
	
	local yp = k*elemHeight-(elem.frame.scroll or 0)
	
	if yp>elemHeight-3 and yp+elemHeight<h-2 then
		sdl.draw.color(224, 224, 224)
		sdl.draw.fill(x+2, y+2+yp, w-4, elemHeight-2)
		sdl.font.color(32,32,32)
		sdl.draw.text(x+4, y+yp, elem.name)
		elem.visible = true
	else
		elem.visible = false
	end
end

end