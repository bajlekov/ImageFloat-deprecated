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
--]]

-- fast median filtering with a minimum number of compares, C and lua implementation
local ffi = require("ffi")
local C
-- ISPC implementation:
if jit.os=="Windows" then --32bit
	-- x86-64 / i386pep for 64bit dll
	os.execute ("ispc --arch=x86 --opt=fast-math -o median.obj median.ispc") print("ISPC")
	os.execute ("ld -shared -mi386pep -o median.dll median.obj")
	C = ffi.load("median.dll")
else --Linux 64bit
	os.execute ("ispc --opt=fast-math --pic -o Test/median.o Test/median.ispc") print("ISPC")
	--os.execute ("gcc -O3 -std=gnu99 -ffast-math -march=native -fPIC -c Test/median.c -o Test/median.o") print("vectorised GCC")
	--os.execute ("clang -O3 -std=gnu99 -ffast-math -march=native -fPIC -c Test/median.c -o Test/median.o") print("LLVM")
	os.execute ("clang -shared -o Test/libmedian.so Test/median.o")
	C = ffi.load("./Test/libmedian.so")
end

ffi.cdef [[	void medianD(float* in, float* out, int xmax, int ymax) ]]

local median
do
	local pix = ffi.new("float[9]")
	local A = ffi.new("int[19]", 1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4)
	local B = ffi.new("int[19]", 2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2)
	local function sort(a, b)
		if pix[a]>pix[b] then
			pix[a], pix[b] = pix[b], pix[a]
		end
	end
	median = function(i, o, xmax, ymax)
		for y = 1, ymax-2 do
			for x = 1, xmax-2 do
				pix[0] = i[(y-1)*xmax+x-1];
				pix[1] = i[y*xmax+x-1];
				pix[2] = i[(y+1)*xmax+x-1];
				pix[3] = i[(y-1)*xmax+x];
				pix[4] = i[y*xmax+x];
				pix[5] = i[(y+1)*xmax+x];
				pix[6] = i[(y-1)*xmax+x+1];
				pix[7] = i[y*xmax+x+1];
				pix[8] = i[(y+1)*xmax+x+1];
				
				for i = 0, 18 do
					sort(A[i], B[i]);
				end
				o[y*xmax+x] = pix[4];
			end
		end
	end
end
	
local size = 4000
local imgI = ffi.new("float[?]", size*size)
local imgO1 = ffi.new("float[?]", size*size)
local imgO2 = ffi.new("float[?]", size*size)

for i = 0, size*size-1 do
	imgI[i] = math.random(4096)
end

--print("start")
local t = os.clock()
C.medianD(imgI, imgO2, size, size)
print("C: ",os.clock()-t)
local t = os.clock()
median(imgI, imgO1, size, size)
print("Lua: ",os.clock()-t)
local t = os.clock()
C.medianD(imgI, imgO2, size, size)
print("C: ",os.clock()-t)
local t = os.clock()
median(imgI, imgO1, size, size)
print("Lua: ",os.clock()-t)


for i = 100*400+200, 100*400+300 do
	assert(imgO1[i]-imgO2[i]==0)
	--print(imgO1[i]-imgO2[i])
end