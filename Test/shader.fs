#version 130

uniform sampler2D texUnit;
uniform vec4 powVec;

uniform vec4 k_f;
uniform vec4 f;
uniform vec4 a;
uniform vec4 g_1;

void main(void)
{
  // LRGBtoSRGB
   vec4 texVal  = texture2D(texUnit, gl_TexCoord[0].xy);
   bvec4 mask = lessThanEqual(texVal, k_f);
   vec4 v1 = texVal*f;
   vec4 v2 = (a+vec4(1.0,1.0,1.0,1.0))*pow(texVal, g_1)-a;
   gl_FragData[0] = mix(v2, v1, mask);
}
