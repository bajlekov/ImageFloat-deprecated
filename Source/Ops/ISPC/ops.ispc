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

// GtoL and LtoG gamma correcting functions
const uniform float a = 0.055;
const uniform float G = 1/0.42;
const uniform float a_1 = 1/1.055;
const uniform float G_1 = 0.42;

const uniform float f = 12.342887114692;
const uniform float k = 0.039827586206897;
const uniform float k_f = 0.0032267641951848;
const uniform float f_1 = 0.08101832178386;

export void ispc_LtoG(uniform float src[], uniform float dst[], uniform int size) {
  foreach(i = 0 ... size) {
    cif (src[i]<=k_f) {
    	dst[i] = src[i] * f;
    } else {
    	dst[i] = (a+1)*pow(src[i], G_1)-a;
    }
  }
}

export void ispc_GtoL(uniform float src[], uniform float dst[], uniform int size) {
  foreach(i = 0 ... size) {
    cif (src[i]<=k) {
    	dst[i] = src[i] * f_1;
    } else {
    	dst[i] = pow((src[i]+a)*a_1, G);
    }
  }
}
