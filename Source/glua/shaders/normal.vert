#if __VERSION__ >= 150
#define MAX_LIGHTS 8
#else
// compatibility mode
#define MAX_LIGHTS gl_MaxLights
#define in  attribute
#define out varying
#endif

uniform int numLights;

uniform mat4 lightMatrix;
uniform mat4 modelViewMatrix;
uniform mat4 modelViewProjectionMatrix;

uniform vec3 lightPosition[MAX_LIGHTS];

in vec3 position;
in vec3 normal;
in vec2 texCoord;

out vec3 lightDirection[MAX_LIGHTS]; // light direction vector in tangent space
out vec3 eyeDirection;                 // eye direction vector in tangent space
out vec2 fragTexCoord;

// TODO: replace with the precalculated version
vec3 tangent()
{
	vec3 tangent;
	vec3 c1 = cross(normal, vec3(0.0, 0.0, 1.0));
	vec3 c2 = cross(normal, vec3(0.0, 1.0, 0.0));
	
	if(length(c1) > length(c2)) {
		tangent = c1;
	} else {
		tangent = c2;
	}
	return normalize(tangent);
}

void main()
{
	fragTexCoord = texCoord;
	gl_Position = modelViewProjectionMatrix * vec4(position, 1);

	// http://www.ozone3d.net/tutorials/bump_mapping_p4.php
	// we do not use non-uniform scaling, so we can use modelViewMatrix directly
	// instead inverse-transpose
#if __VERSION__ >= 150
	mat3 modelViewMatrix3 = mat3(modelViewMatrix);
#else
	mat3 modelViewMatrix3 = mat3(modelViewMatrix[0].xyz, modelViewMatrix[1].xyz, modelViewMatrix[2].xyz);
#endif
	vec3 n = modelViewMatrix3 * normal;
	vec3 t = normalize(modelViewMatrix3 * tangent());
	vec3 b = cross(n, t);

	vec3 vertex = vec3(modelViewMatrix * vec4(position, 1));
	vec3 tmp;

	for(int i = 0; i < numLights; i++) {
		tmp = vec3(modelViewMatrix * lightMatrix * vec4(lightPosition[i], 1)) - vertex;
		lightDirection[i] = vec3(
			dot(tmp, t),
			dot(tmp, b),
			dot(tmp, n));
	}

	tmp = -vertex;
	eyeDirection = vec3(
		dot(tmp, t),
		dot(tmp, b),
		dot(tmp, n));
}
