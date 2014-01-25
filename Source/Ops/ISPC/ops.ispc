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

export void ispc_pow(uniform float A[], uniform float b, uniform float O[], uniform int size) {
  foreach(i = 0 ... size) {
    O[i] = pow(A[i], b);
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

inline float LtoG(float i) {
	cif (i<=k_f) {
    	return i * f;
    } else {
    	return (a+1)*pow(i, G_1)-a;
    }
}

inline float GtoL(float i) {
    cif (i<=k) {
    	return i * f_1;
    } else {
    	return pow((i+a)*a_1, G);
    }
}

export void ispc_LtoG(uniform float src[], uniform float dst[], uniform int size) {
  foreach(i = 0 ... size) dst[i] = LtoG(src[i]);
}

export void ispc_GtoL(uniform float src[], uniform float dst[], uniform int size) {
  foreach(i = 0 ... size) dst[i] = GtoL(src[i]);
}

export void ispc_mat3mul(uniform float src[], uniform float dst[], uniform float mat[], uniform int size){
	varying float ri, gi, bi;
	varying float ro, go, bo;
	foreach(i = 0 ... size/3) {
		ri = src[i*3];
		gi = src[i*3+1];
		bi = src[i*3+2];
		
		ro = mat[0]*ri + mat[1]*gi + mat[2]*bi;
		go = mat[3]*ri + mat[4]*gi + mat[5]*bi;
		bo = mat[6]*ri + mat[7]*gi + mat[8]*bi;
		
		dst[i*3] = ro;
		dst[i*3+1] = go;
		dst[i*3+2] = bo;
	}
}

export void ispc_GtoLmat3mul(uniform float src[], uniform float dst[], uniform float mat[], uniform int size){
	varying float ri, gi, bi;
	varying float ro, go, bo;
	foreach(i = 0 ... size/3) {
		ri = GtoL(src[i*3]);
		gi = GtoL(src[i*3+1]);
		bi = GtoL(src[i*3+2]);
		
		ro = mat[0]*ri + mat[1]*gi + mat[2]*bi;
		go = mat[3]*ri + mat[4]*gi + mat[5]*bi;
		bo = mat[6]*ri + mat[7]*gi + mat[8]*bi;
		
		dst[i*3] = ro;
		dst[i*3+1] = go;
		dst[i*3+2] = bo;
	}
}

export void ispc_mat3mulLtoG(uniform float src[], uniform float dst[], uniform float mat[], uniform int size){
	varying float ri, gi, bi;
	varying float ro, go, bo;
	foreach(i = 0 ... size/3) {
		ri = src[i*3];
		gi = src[i*3+1];
		bi = src[i*3+2];
		
		ro = mat[0]*ri + mat[1]*gi + mat[2]*bi;
		go = mat[3]*ri + mat[4]*gi + mat[5]*bi;
		bo = mat[6]*ri + mat[7]*gi + mat[8]*bi;
		
		dst[i*3] = LtoG(ro);
		dst[i*3+1] = LtoG(go);
		dst[i*3+2] = LtoG(bo);
	}
}





