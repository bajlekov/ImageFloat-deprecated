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

do
  function global(k, v) -- assign new global
    rawset(_G, k, v or false)
  end
  local function newGlobal(t, k, v) -- disable globals
    error("global assignment not allowed: "..k)
  end
  setmetatable(_G, {__newindex=newGlobal})
end

local g
local ffi = require("ffi")

g = {preview = true, error=false, info=true}
g.setup = require("Setup.IFsetup")
g.setup.bufferPrecision = g.setup.bufferPrecision or {"float", 4}

g.libPath = g.setup.libPath or "./Libraries/"..ffi.os.."_"..ffi.arch.."/"
g.imgPath = g.setup.imgPath or "./Resources/Images/"
g.ttfPath = g.setup.ttfPath or "./Resources/Fonts/"

g.loadFile = g.setup.imageLoadPath..g.setup.imageLoadName
g.saveFile = g.setup.imageSavePath..g.setup.imageSaveName

global("__global", g)

return g