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

local ffi = require("ffi")
local p, fftw = pcall(loadlib, "fftw3")
assert(p, fftw)

--os.execute([=[echo '#include <fftw3.h>' > stub.c]=])
--os.execute([=[gcc -I /usr/include/SDL -E stub.c | grep -v '^#' > FFTW.h]=])

ffi.cdef(io.open(__global.setup.incPath.."FFTW.h", "r"):read('*a')) --contains stdio, interfering with sdl
io.close()

fft = {}
fft.fftw=fftw

fft.FORWARD = -1
fft.INVERSE = 1
fft.PLAN = {[0]=2^6, 0, 2^5, 2^3}

function fft.createPlan(n, p_in, p_out, forward, real, plan)
     pln = plan or fft.PLAN[0]
     local sign = forward and fft.FORWARD or fft.INVERSE
     if real==true then
          if sign==fft.FORWARD then
               return fftw.fftw_plan_dft_r2c_1d(n, p_in, p_out, plan)
          elseif sign==fft.INVERSE then
               return fftw.fftw_plan_dft_c2r_1d(n, p_in, p_out, plan)
          end
     elseif real==false then
          return fftw.fftw_plan_dft_1d(n, p_in, p_out, sign, plan)
     end
end

function fft.executePlan(plan)
     fftw.fftw_execute(plan)
end

function fft.destroyPlan(plan)
     fftw.fftw_destroy_plan(plan)
end

function fft.createBuffer(size)
     return ffi.cast("fftw_complex*", fftw.fftw_malloc(ffi.sizeof("fftw_complex")*size))
end

function fft.destroyBuffer(buffer)
     fftw.fftw_free(buffer)
end

return fft
