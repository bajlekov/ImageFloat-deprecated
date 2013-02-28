#version 130

uniform sampler2D texUnit;
uniform vec2 xy;

const int A[19] = int[](1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4);
const int B[19] = int[](2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2);
vec4 pix[9];

void sort(int a, int b) {	
	vec4 mask = vec4(lessThanEqual(pix[a], pix[b]));
	vec4 newA = mix(pix[a], pix[b], mask);
	vec4 newB = mix(pix[b], pix[a], mask);
	pix[a] = newA;
	pix[b] = newB;
}

vec4 get(vec2 texCoord, int x, int y) {
  return texture2D(texUnit, texCoord + vec2(x, y)*xy);
}

void main(void) {
  vec2 tc = gl_TexCoord[0].xy;
  //vec4 texVal  = texture2D(texUnit, tc);
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