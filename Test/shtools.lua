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

-- Incomplete directory listing tools

local ffi = require("ffi")

sh = {}

local function ls_FB(dir)
	local f = io.popen("ls -p "..dir)
	local fl = {}
	local dl = {}
	for s in f:lines () do
		if string.match(s, "(.*)/$") then
			dl[string.match(s, "(.*)/$")] =true
		else
			fl[s] = true
		end
	end
  f:close()
	return fl, dl
end

local function cwd_FB()
  local f = io.popen("pwd")
  local fl = {}
  local dl = {}
  return f:read("*l")
end

ffi.cdef([[
	char* getcwd (char *buffer, size_t size);
  unsigned long GetCurrentDirectoryA(unsigned long in, char *out);
]])

local function cwd_POSIX()
  return ffi.string(ffi.C.getcwd(ffi.new("char[1024]"),1024)) 
end

local function cwd_WIN()
  local t = ffi.new("uint8_t[1024]")
  ffi.C.GetCurrentDirectoryA(1024, t)
  return ffi.string(t)
end

local ls_POSIX
local ls_WIN

if ffi.os=="Windows" then

  ffi.cdef[[
  #pragma pack(push)
  #pragma pack(1)
    struct WIN32_FIND_DATAA
    {
      uint32_t dwFileAttributes;
      uint64_t ftCreationTime;
      uint64_t ftLastAccessTime;
      uint64_t ftLastWriteTime;
      struct
      {
        union
        {
          uint64_t packed;
          struct
          {
            uint32_t high;
            uint32_t low;
          };
        };
      } nFileSize;
      uint32_t dwReserved[2];
      char cFileName[260];
      char cAlternateFileName[14];
    };
  #pragma pack(pop)
    void* FindFirstFileA(const char* pattern, struct WIN32_FIND_DATAA* fd);
    bool FindNextFileA(void* ff, struct WIN32_FIND_DATAA* fd);
    bool FindClose(void* ff);
  ]]

  function ls_WIN(path, pattern)
    if not path:sub(-1):find("[\\/]") then
      path = path .. "/*"
    else
      path = path .. "*"
    end
    local fd = ffi.new("struct WIN32_FIND_DATAA")
    local ft = {}
    local dt = {}
    local hFile = ffi.C.FindFirstFileA(path, fd)
    while ffi.C.FindNextFileA(hFile, fd) do
      if ffi.string(fd.cFileName)~=".." and ffi.string(fd.cFileName)~="." then
        if fd.dwFileAttributes==16 then dt[ffi.string(fd.cFileName)]=true end
        if fd.dwFileAttributes==32 then ft[ffi.string(fd.cFileName)]=true end
      end
    end
    ffi.C.FindClose(hFile)
    return ft, dt
  end

else
    ffi.cdef([=[
     typedef unsigned long int __ino_t;
     typedef long int __off_t;
     struct dirent
    {
      __ino_t d_ino;
      __off_t d_off;
      unsigned short int d_reclen;
      unsigned char d_type;
      char d_name[256];
    };
    typedef struct __dirstream DIR;
    DIR *opendir (char *__name);
    struct dirent *readdir (DIR *__dirp);
    int closedir (DIR *__dirp);
  ]=])
    
  function ls_POSIX(dir)
    dir = ffi.C.opendir (ffi.cast("char *", dir));
    local ft = {}
    local dt = {}
    local ent = ffi.C.readdir(dir)
    while ent~=nil do
      if ffi.string(ent.d_name):sub(1,1)~="." then
        if ent.d_type==8 then ft[ffi.string(ent.d_name)] = true end
        if ent.d_type==4 then dt[ffi.string(ent.d_name)] = true end
      end
      ent = ffi.C.readdir(dir)
    end
    ffi.C.closedir(dir)
    return ft, dt
  end
end


if ffi.os=="Windows" then
  sh.cwd=cwd_WIN
  sh.ls=ls_WIN
else
  sh.cwd=cwd_POSIX
  sh.ls=ls_POSIX
end

print(sh.ls(""))

return sh