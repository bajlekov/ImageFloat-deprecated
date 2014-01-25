#version 130

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

uniform sampler2D tex1;
uniform vec2 xy;

//comparisons for optimal sort
const int A[19] = int[](1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4);
const int B[19] = int[](2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2);
vec4 pix[9];

//sort routine
void sort(int a, int b) {	
	vec4 mask = vec4(lessThanEqual(pix[a], pix[b]));
	vec4 newA = mix(pix[a], pix[b], mask);
	vec4 newB = mix(pix[b], pix[a], mask);
	pix[a] = newA;
	pix[b] = newB;
}

//get texture value at offset
vec4 get(vec2 texCoord, int x, int y) {
  return texture(tex1, texCoord + vec2(x, y)*xy);
}

//median filter
void main(void) {
  vec2 tc = gl_TexCoord[0].xy;
  
  pix[0] = get(tc, -1, -1);
  pix[1] = get(tc, 0, -1);
  pix[2] = get(tc, 1, -1);
  pix[3] = get(tc, -1, 0);
  pix[4] = get(tc, 0, 0);
  pix[5] = get(tc, 1, 0);
  pix[6] = get(tc, -1, 1);
  pix[7] = get(tc, 0, 1);
  pix[8] = get(tc, 1, 1);
  
  int i;
  for (i=0; i<19; i++) {
    sort(A[i],B[i]);
  }
  
  gl_FragData[0] = pix[4];
}