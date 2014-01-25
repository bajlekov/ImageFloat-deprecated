/*
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
*/

export void ispc_pack(uniform float src[], uniform float dst[], uniform int size) {
  foreach(i = 0 ... size) {
    dst[i] = src[i*3];
    dst[size+i] = src[i*3+1];
    dst[2*size+i] = src[i*3+2];
  }
}

export void ispc_unpack(uniform float src[], uniform float dst[], uniform int size) {
  foreach(i = 0 ... size) {
    dst[i*3] = src[i];
    dst[i*3+1] = src[size+i];
    dst[i*3+2] = src[2*size+i];
  }
}

export void ispc_mean_packed(uniform float src[], uniform float dst[], uniform int size) {
	foreach(i = 0 ... size) {
		dst[i] = (src[i] + src[i+size] + src[i+2*size])/3;
	}
}

export void ispc_mean_unpacked(uniform float src[], uniform float dst[], uniform int size) {
	foreach(i = 0 ... size) {
		dst[i*3] = (src[i*3] + src[i*3+1] + src[i*3+2])/3;
	}
}

export void ispc_mean_c(uniform float src[], uniform float dst[], uniform int size) {
	for(int i = 0; i<size;i++) {
		dst[i*3] = (src[i*3] + src[i*3+1] + src[i*3+2])/3;
	}
}