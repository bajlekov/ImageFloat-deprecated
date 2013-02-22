#version 130

uniform sampler2D texUnit;
uniform vec4 powVec;

void main(void)
{
   vec4 texVal  = texture2D(texUnit, gl_TexCoord[0].xy);
   gl_FragData[0] = pow(texVal, powVec);
}
