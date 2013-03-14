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

--direct write to/from file? possibly multithreaded compress chunks?

-- zlib example from luajit tutorial
local ffi = require("ffi")

--gzread
--gzwrite
--gzflush

ffi.cdef[[
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen, uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen, uint8_t *source, unsigned long sourceLen);

typedef struct gzFile_s *gzFile;
gzFile gzopen(const char *path, const char *mode);
gzFile gzdopen(int fd, char *mode);
int gzclose(gzFile file);

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
	zlib.gzwrite(f, input, size)
	zlib.gzclose(f)
end

local function uncompressFile(output, size, file)
	--wb[1-9][f/h/R/F]
	n = n or ""
	local f = zlib.gzopen(file, "rb")
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
local d = d *2.123096754 / 2.334683457
local size = d.x*d.y*d.z*4

print(d.x, d.y)
local t = d.data[123]

--print("Uncompressed size (MB): ", size/1024^2)
tic()
local c, l = compress(ffi.cast("unsigned char *", d.data), size)
toc("pack")
--print("Compressed size (MB): ", tonumber(l)/1024^2)
d.data[123] = -3
tic()
uncompress(c, d.data, l, size)
toc("unpack")
assert(d.data[123]==t)

tic()
compressFile(d.data, size, "test.gz", 1)
toc("pack + write")
d.data[123] = -3
tic()
uncompressFile(d.data, size, "test.gz")
toc("unpack + read")
assert(d.data[123]==t)

tic()
compressFile(d.data, size, "test.gz", 0)
toc("write")
d.data[123] = -3
tic()
uncompressFile(d.data, size, "test.gz")
toc("read")
assert(d.data[123]==t)