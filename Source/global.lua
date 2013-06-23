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

local global
local ffi = require("ffi")

global = {preview = true, error=false, info=true}
global.setup = require("Setup.IFsetup")
global.setup.bufferPrecision = global.setup.bufferPrecision or {"float", 4}

global.libPath = global.setup.libPath or "../Libraries/"..ffi.os.."_"..ffi.arch.."/"
global.imgPath = global.setup.imgPath or "../Resources/Images/"
global.ttfPath = global.setup.ttfPath or "../Resources/Fonts/"

global.loadFile = global.setup.imageLoadPath..global.setup.imageLoadName
global.saveFile = global.setup.imageSavePath..global.setup.imageSaveName

return global