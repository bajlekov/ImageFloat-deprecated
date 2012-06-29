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

local fftops = {}

local fft = require ("fftw")
local ffi = require ("ffi")

local function loadlib(lib)
	local path = "./lib/"..ffi.os.."_"..ffi.arch.."/"
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

local SDL = loadlib("SDL")
ffi.cdef[[
struct SDL_mutex;
typedef struct SDL_mutex SDL_mutex;
extern int SDL_mutexP(SDL_mutex *mutex);
extern int SDL_mutexV(SDL_mutex *mutex);
]]

local function mutexLock() return SDL.SDL_mutexP(__mut) end
local function mutexUnlock() return SDL.SDL_mutexV(__mut) end

do
	local size = 0
	local norm
	local init = false
	local iR, iG, iB
	local oR, oG, oB
	local plan
	local flag_old = nil
	local function fftSetup(flag)
			mutexLock()
			if init then
				fft.destroyBuffer(iR)
				fft.destroyBuffer(iG)
				fft.destroyBuffer(iB)
				fft.destroyBuffer(oR)
				fft.destroyBuffer(oG)
				fft.destroyBuffer(oB)
				fft.destroyPlan(plan)
			else
				init=true
			end
			iR = fft.createBuffer(size)
			iG = fft.createBuffer(size)
			iB = fft.createBuffer(size)
			oR = fft.createBuffer(size)
			oG = fft.createBuffer(size)
			oB = fft.createBuffer(size)
			mutexUnlock()
	end
	local function ffty(flag) --1, 2
		if size~=ymax then
			size = ymax
			norm = 1/math.sqrt(size)
			fftSetup(flag)
			mutexLock()
				plan = fft.createPlan(size, iR, oR, flag, false, fft.PLAN[2])
			mutexUnlock()
		end
		for x = __instance, xmax-1, __tmax do
			if progress[0]==-1 then break end
				for y = 0, ymax-1 do
					__pp = (x * ymax + y)
					iR[y][0], iG[y][0], iB[y][0]=get3[1]()
					iR[y][1], iG[y][1], iB[y][1]=get3[2]()
				end
				fft.fftw.fftw_execute_dft(plan, iR, oR)
				fft.fftw.fftw_execute_dft(plan, iG, oG)
				fft.fftw.fftw_execute_dft(plan, iB, oB)
				for y = 0, ymax-1 do
					__pp = (x * ymax + y)
					set3[1](oR[y][0]*norm, oG[y][0]*norm, oB[y][0]*norm)
					set3[2](oR[y][1]*norm, oG[y][1]*norm, oB[y][1]*norm)
				end
			progress[__instance+1] = x - __instance
		end
		progress[__instance+1] = -1
	end

	local function fftx(flag)
		if size~=xmax then
			size = xmax
			norm = 1/math.sqrt(size)
			fftSetup(flag)
			mutexLock()
				plan = fft.createPlan(size, iR, oR, flag, false, fft.PLAN[2])
			mutexUnlock()
		end
		for y = __instance, ymax-1, __tmax do
			if progress[0]==-1 then break end
				for x = 0, xmax-1 do
					__pp = (x * ymax + y)
					iR[x][0], iG[x][0], iB[x][0]=get3[1]()
					iR[x][1], iG[x][1], iB[x][1]=get3[2]()
				end
				fft.fftw.fftw_execute_dft(plan, iR, oR)
				fft.fftw.fftw_execute_dft(plan, iG, oG)
				fft.fftw.fftw_execute_dft(plan, iB, oB)
				for x = 0, xmax-1 do
					__pp = (x * ymax + y)
					set3[1](oR[x][0]*norm, oG[x][0]*norm, oB[x][0]*norm)
					set3[2](oR[x][1]*norm, oG[x][1]*norm, oB[x][1]*norm)
				end
			progress[__instance+1] = y - __instance
		end
		progress[__instance+1] = -1
	end

	function fftops.fftx() return fftx(true) end
	function fftops.ffty() return ffty(true) end
	function fftops.ifftx() return fftx(false) end
	function fftops.iffty() return ffty(false) end
end

return fftops