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

-- for efficient compression separate exponent from mantissa, compress only exponent, as most values have a similar exponent
-- int16e, int16n, int16c (+ zipped exponent (16+4/8), signed normalized, unsigned clipped) --detect clipping

ffi.cdef[[
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen, uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen, uint8_t *source, unsigned long sourceLen);

typedef struct gzFile_s *gzFile;
gzFile gzopen(const char *path, const char *mode);
gzFile gzdopen(int fd, char *mode);
int gzclose(gzFile file);
int gzbuffer(gzFile file, unsigned long size);

int gzread(gzFile file, void* buf, unsigned long len);
int gzwrite(gzFile file, void* buf, unsigned long len);
]]
local zlib = ffi.load(ffi.os == "Windows" and "zlib1" or "z")

local function compress(input, size)
  local n = zlib.compressBound(size)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.compress2(buf, buflen, input, size, 1)
  assert(res == 0)
  return buf, buflen[0]
end

local function compressFile(input, size, file, n)
	--wb[1-9][f/h/R/F]
	n = n or 1
	local f = zlib.gzopen(file, "wb"..n)
	zlib.gzbuffer(f, 1024*512)
	zlib.gzwrite(f, input, size)
	zlib.gzclose(f)
end

local function uncompressFile(output, size, file)
	--wb[1-9][f/h/R/F]
	n = n or ""
	local f = zlib.gzopen(file, "rb")
	zlib.gzbuffer(f, 1024*512)
	zlib.gzread(f, output, size)
	zlib.gzclose(f)
end

local function uncompress(input, output, sizein, sizeout)
  local buf = ffi.cast("unsigned char *", output)
  local buflen = ffi.new("unsigned long[1]", sizeout)
  local res = zlib.uncompress(buf, buflen, input, sizein)
  assert(res == 0)
end

-- Simple test code.
local ppm = require("Tools.ppmtools")
local img = require("Tools.imgtools")
local sdl = require("Include.sdltools")
local dbg = require("Tools.dbgtools")

local d = ppm.toBuffer(ppm.readFile("Resources/Photos/img16.ppm", ""))
local d = d *2.134535623096754 / 2.334683457436457
local size = d.x*d.y*d.z
print(d.x, d.y, d.z)

-- new structure with 16/8bit precision mantissa and compressed 8bit exponent
os.execute ("ispc --opt=fast-math --pic -o Test/exp.o Test/exp.ispc") print("ISPC")
os.execute ("gcc -m64 -shared -o Test/libexp.so Test/exp.o")
ffi.cdef[[
	void packExp16(float* input, int16_t* mantissa, uint8_t* exp, int size);
	void unpackExp16(float* output, int16_t* mantissa, uint8_t* exp, int size);
	void packExp8(float* input, int8_t* mantissa, uint8_t* exp, int size);
	void unpackExp8(float* output, int8_t* mantissa, uint8_t* exp, int size);
	void packExp16u(float* input, uint16_t* mantissa, uint8_t* exp, int size);
	void unpackExp16u(float* output, uint16_t* mantissa, uint8_t* exp, int size);
	void packExp8u(float* input, uint8_t* mantissa, uint8_t* exp, int size);
	void unpackExp8u(float* output, uint8_t* mantissa, uint8_t* exp, int size);
]]
local Exp = ffi.load("./Test/libexp.so")

local m = ffi.new("short [?]", size)		--mantissa
local n = ffi.new("char [?]", size)		--exponent

tic()
Exp.packExp16(d.data, m, n, size)
toc("pack exp")
tic()
compressFile(m, size*2, "man.gz", "0F")	--no compression fo mantissa
compressFile(n, size, "exp.gz", "4f")	--compress exponent to ~1/20th of size
toc("compress + write")
tic()
uncompressFile(m, size*2, "man.gz")
uncompressFile(n, size, "exp.gz")
toc("uncompress + read")
tic()
Exp.unpackExp16(d.data, m, n, size)
toc("unpack exp")
