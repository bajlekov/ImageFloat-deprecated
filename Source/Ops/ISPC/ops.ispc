/*
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
*/

export void ispc_move(uniform float src[], uniform float dst[], uniform int size) {
  foreach(i = 0 ... size) {
    dst[i] = src[i];
  }
}

export void ispc_add(uniform float A[], uniform float B[], uniform float O[], uniform int size) {
  foreach(i = 0 ... size) {
    O[i] = A[i] + B[i];
  }
}

export void ispc_sub(uniform float A[], uniform float B[], uniform float O[], uniform int size) {
  foreach(i = 0 ... size) {
    O[i] = A[i] - B[i];
  }
}

export void ispc_mul(uniform float A[], uniform float B[], uniform float O[], uniform int size) {
  foreach(i = 0 ... size) {
    O[i] = A[i] * B[i];
  }
}

export void ispc_div(uniform float A[], uniform float B[], uniform float O[], uniform int size) {
  foreach(i = 0 ... size) {
    O[i] = A[i] / B[i];
  }
}