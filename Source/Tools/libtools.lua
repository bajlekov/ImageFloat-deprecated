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

-- implement easy loading of libraries

-- system/user/provided
-- linux/windows/osx
-- x64/x86/arm
-- handle versioning for linux
-- handle aliases
-- handle dependencies

-- create loader for each library type with different file names
local libs = {}

libs.luajit = {}
libs.jpeg = {} -- handled by sdl_img
libs.png= {} -- handled by sdl_img
libs.tiff = {} -- handled by sdl_img
libs.webp = {} -- handled by sdl_img
libs.sdl = {}
libs.sdl_ttf = {}
libs.sdl_image = {}
libs.zlib = {} -- handled by sdl_img
libs.freetype = {} -- handled by sdl_img
libs.fftw = {}


libs.thread = {}

local function loadlib(lib)
	
	local path = __global.libPath
		
	local libname
	if ffi.os=="Linux" then libname = "lib"..lib..".so" end
	if ffi.os=="Windows" then libname = lib..".dll" end
	local t
	local p
	p, t = pcall(ffi.load, lib)
	if not p then
		print("no native library found, trying user library "..lib)
		p, t = pcall(ffi.load, "./lib/usr/"..libname)
	end
	if not p then
		print("no user library found, trying supplied library "..lib)
		p, t = pcall(ffi.load, path..libname)
	end
	
	if p then
		return t
	else
		print("failed loading "..lib)
		return false
	end
end

--load libraries
if ffi.os=="Windows" then --maybe fix this?
	loadlib('libjpeg-8')
	loadlib('zlib1')
	loadlib('libfreetype-6')
	loadlib('libpng15-15')
	loadlib('libtiff-5')
end

_SDL = loadlib('SDL')
local _SDL = _SDL
local _TTF = loadlib("SDL_ttf")
local _IMG = loadlib("SDL_image")