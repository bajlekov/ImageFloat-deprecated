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

// power function implementation from José Fonseca:
// http://jrfonseca.blogspot.com/2008/09/fast-sse2-pow-tables-or-polynomials.html

#include <math.h>
#include "xmmintrin.h"

#define EXP_POLY_DEGREE 5
#define LOG_POLY_DEGREE 6

#define POLY0(x, c0) _mm_set1_ps(c0)
#define POLY1(x, c0, c1) _mm_add_ps(_mm_mul_ps(POLY0(x, c1), x), _mm_set1_ps(c0))
#define POLY2(x, c0, c1, c2) _mm_add_ps(_mm_mul_ps(POLY1(x, c1, c2), x), _mm_set1_ps(c0))
#define POLY3(x, c0, c1, c2, c3) _mm_add_ps(_mm_mul_ps(POLY2(x, c1, c2, c3), x), _mm_set1_ps(c0))
#define POLY4(x, c0, c1, c2, c3, c4) _mm_add_ps(_mm_mul_ps(POLY3(x, c1, c2, c3, c4), x), _mm_set1_ps(c0))
#define POLY5(x, c0, c1, c2, c3, c4, c5) _mm_add_ps(_mm_mul_ps(POLY4(x, c1, c2, c3, c4, c5), x), _mm_set1_ps(c0))

__m128 exp2f4(__m128 x)
{
   __m128i ipart;
   __m128 fpart, expipart, expfpart;

   x = _mm_min_ps(x, _mm_set1_ps( 129.00000f));
   x = _mm_max_ps(x, _mm_set1_ps(-126.99999f));

   /* ipart = int(x - 0.5) */
   ipart = _mm_cvtps_epi32(_mm_sub_ps(x, _mm_set1_ps(0.5f)));

   /* fpart = x - ipart */
   fpart = _mm_sub_ps(x, _mm_cvtepi32_ps(ipart));

   /* expipart = (float) (1 << ipart) */
   expipart = _mm_castsi128_ps(_mm_slli_epi32(_mm_add_epi32(ipart, _mm_set1_epi32(127)), 23));

   /* minimax polynomial fit of 2**x, in range [-0.5, 0.5[ */
#if EXP_POLY_DEGREE == 5
   expfpart = POLY5(fpart, 9.9999994e-1f, 6.9315308e-1f, 2.4015361e-1f, 5.5826318e-2f, 8.9893397e-3f, 1.8775767e-3f);
#elif EXP_POLY_DEGREE == 4
   expfpart = POLY4(fpart, 1.0000026f, 6.9300383e-1f, 2.4144275e-1f, 5.2011464e-2f, 1.3534167e-2f);
#elif EXP_POLY_DEGREE == 3
   expfpart = POLY3(fpart, 9.9992520e-1f, 6.9583356e-1f, 2.2606716e-1f, 7.8024521e-2f);
#elif EXP_POLY_DEGREE == 2
   expfpart = POLY2(fpart, 1.0017247f, 6.5763628e-1f, 3.3718944e-1f);
#else
#error
#endif

   return _mm_mul_ps(expipart, expfpart);
}


__m128 log2f4(__m128 x)
{
	static int init = 0;
	static __m128i exp, mant;
	static __m128 one;
	
	if (init==0) {
		exp = _mm_set1_epi32(0x7F800000);
		mant = _mm_set1_epi32(0x007FFFFF);
		one = _mm_set1_ps( 1.0f);
		init=1;
	}
   
   __m128i i = _mm_castps_si128(x);
   __m128 e = _mm_cvtepi32_ps(_mm_sub_epi32(_mm_srli_epi32(_mm_and_si128(i, exp), 23), _mm_set1_epi32(127)));
   __m128 m = _mm_or_ps(_mm_castsi128_ps(_mm_and_si128(i, mant)), one);
   __m128 p;

   /* Minimax polynomial fit of log2(x)/(x - 1), for x in range [1, 2[ */
#if LOG_POLY_DEGREE == 6
   p = POLY5( m, 3.1157899f, -3.3241990f, 2.5988452f, -1.2315303f,  3.1821337e-1f, -3.4436006e-2f);
#elif LOG_POLY_DEGREE == 5
   p = POLY4(m, 2.8882704548164776201f, -2.52074962577807006663f, 1.48116647521213171641f, -0.465725644288844778798f, 0.0596515482674574969533f);
#elif LOG_POLY_DEGREE == 4
   p = POLY3(m, 2.61761038894603480148f, -1.75647175389045657003f, 0.688243882994381274313f, -0.107254423828329604454f);
#elif LOG_POLY_DEGREE == 3
   p = POLY2(m, 2.28330284476918490682f, -1.04913055217340124191f, 0.204446009836232697516f);
#else
#error
#endif

   /* This effectively increases the polynomial degree by one, but ensures that log2(1) == 0*/
   p = _mm_mul_ps(p, _mm_sub_ps(m, one));
   return _mm_add_ps(p, e);
}

 __m128 _mm_pow_ps(__m128 x, __m128 y) {
   return exp2f4(_mm_mul_ps(log2f4(x), y));
}

void vpow(float* x, float* y, float* z) {
	__m128 t0, t1;
	t0 = _mm_load_ps(x);
	t1 = _mm_load_ps(y);
	t0 = _mm_pow_ps(t0, t1);
	_mm_store_ps(z, t0);
}

void vadd(float* a, float* b, float* c){
	__m128 t0, t1;
	t0 = _mm_load_ps(a);
	t1 = _mm_load_ps(b);
	t0 = _mm_add_ps(t0, t1);
	_mm_store_ps(c, t0);
}

// _mm_cmple_ps(a, b) : a<=b
// _mm_add_ps
// _mm_sub_ps
// _mm_mul_ps
// _mm_div_ps
// _mm_pow_ps

void LRGBtoSRGB(float* x, float* z) {
	static int init = 0;
	static __m128 a, ap1, G_1, f, k_f;
	
	if (init==0) {
		a = _mm_set1_ps(0.099);
		ap1 = _mm_set1_ps(1.099);
		G_1 = _mm_set1_ps(0.45);
		f = _mm_set1_ps(4.5137862651153); //((1+a)^G*(G-1)^(G-1))/(a^(G-1)*G^G)
		k_f = _mm_mul_ps(_mm_set1_ps(0.081), _mm_rcp_ps(f));
		init=1;
	}
	
	__m128 t0, t1, m, d0, d1;
	
	// calculate t1
	t0 = _mm_load_ps(x);
	t1 = _mm_pow_ps(t0, G_1);
	t1 = _mm_mul_ps(ap1, t1);
	t1 = _mm_sub_ps(t1, a);
	
	// blend according to m
	m = _mm_cmple_ps(t0, k_f);
	d0 = _mm_and_ps(m, _mm_mul_ps(t0, f));
	d1 = _mm_andnot_ps(m, t1);
	m = _mm_or_ps(d0, d1); 
	
	_mm_store_ps(z, m);
}

void SRGBtoLRGB(float* x, float* z) {
	static int init = 0;
	static __m128 v1, a, a_1, G, f_1, k;
	
	if (init==0) {
		v1 = _mm_set1_ps(1.0);
		a = _mm_set1_ps(0.099);
		G = _mm_rcp_ps(_mm_set1_ps(0.45));
		a_1 = _mm_rcp_ps(_mm_add_ps(a, v1));
		k = _mm_set1_ps(0.081);
		f_1 = _mm_set1_ps(0.22154349835491);
		init=1;
	}
	
	__m128 t0, t1, m, d0, d1;
	
	// calculate t1
	// ((i+aa)*a_1)^G
	t0 = _mm_load_ps(x);
	t1 = _mm_add_ps(t0, a);
	t1 = _mm_mul_ps(t1, a_1);
	t1 = _mm_pow_ps(t1, G);
	
	// blend according to m
	m = _mm_cmple_ps(t0, k);
	d0 = _mm_and_ps(m, _mm_mul_ps(t0, f_1));
	d1 = _mm_andnot_ps(m, t1);
	m = _mm_or_ps(d0, d1); 
	
	_mm_store_ps(z, m);
}

void dilate(float* __restrict x, float* __restrict y) {
	__m128 m;
	m = _mm_load_ps(x);
	m = _mm_max_ps(m, _mm_loadu_ps(x-2));
	m = _mm_max_ps(m, _mm_loadu_ps(x-1));
	m = _mm_max_ps(m, _mm_loadu_ps(x+1));
	m = _mm_max_ps(m, _mm_loadu_ps(x+2));
	_mm_store_ps(y, m);
}

void erode(float* __restrict x, float* __restrict y) {
	__m128 m;
	m = _mm_load_ps(x);
	m = _mm_min_ps(m, _mm_loadu_ps(x-2));
	m = _mm_min_ps(m, _mm_loadu_ps(x-1));
	m = _mm_min_ps(m, _mm_loadu_ps(x+1));
	m = _mm_min_ps(m, _mm_loadu_ps(x+2));
	_mm_store_ps(y, m);
}

void dilateSSE(float* __restrict x, float* __restrict y, int start, int end) {
	int i;
	for (i=start; i<=end; i+=4) {
		dilate(x+i, y+i);
	}
}

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))
void dilateC(float* __restrict x, float* __restrict y, int start, int end) {
	//x = __builtin_assume_aligned (x, 16);
	//y = __builtin_assume_aligned (y, 16);
	
	int i;
	for (i=start; i<=end; i++) {
		y[i] = MAX(MAX(MAX(MAX(x[i-2], x[i-1]), x[i]), x[i+1]), x[i+2]);
	}
}

void dilateCsingle(float* __restrict x, float* __restrict y) {
	y[0] = MAX(MAX(MAX(MAX(x[-2], x[-1]), x[0]), x[1]), x[2]);
}

void addSSE(float* x, float* y, float* z, int size) {
	int i;
	for (i=0; i<size; i+=4) {
		_mm_store_ps(z+i, _mm_add_ps(_mm_load_ps(x+i), _mm_load_ps(y+i)));
	}
}

void addC(float* x, float* y, float* z, int size) {
	//x = __builtin_assume_aligned (x, 16);
	//y = __builtin_assume_aligned (y, 16);
	//z = __builtin_assume_aligned (z, 16);
	
	int i;
	for (i=0; i<size; i++) {
		z[i]=x[i]+y[i];
	}
}

void addSSEsingle(float* x, float* y, float* z) {
	_mm_store_ps(z, _mm_add_ps(_mm_load_ps(x), _mm_load_ps(y)));
}

void addCsingle(float* x, float* y, float* z) {
	z[0]=x[0]+y[0];
}
