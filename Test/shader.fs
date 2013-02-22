#version 130

uniform sampler2D texUnit;
uniform vec4 powVec;

uniform vec4 k_f;
uniform vec4 f;
uniform vec4 a;
uniform vec4 g_1;
uniform vec2 xy;

void main(void)
{
  // LRGBtoSRGB
   vec2 texCoord = gl_TexCoord[0].xy;
   vec4 texVal  = texture2D(texUnit, texCoord);
   vec4 texOffL  = texture2D(texUnit, texCoord+vec2(-1.0*xy.x, 0.0));
   vec4 texOffR  = texture2D(texUnit, texCoord+vec2(xy.x, 0.0));
   vec4 mask = vec4(lessThanEqual(texVal, k_f));
   vec4 v1 = texVal*f;
   vec4 v2 = (a+vec4(1.0))*pow(texVal, g_1)-a;
   gl_FragData[0] = mix(v2, v1, mask);
   
   // multiple returns
   gl_FragData[1] = texOffL;
}