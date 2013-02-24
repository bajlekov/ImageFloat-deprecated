--[[
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
]]

-- minimal GL/GLU/GLUT binding to facilitate execution of GLSL shader

--[[
uses of GLSL shaders
	- useful when processing exceeds texture copy time
	- benefits with computations including powers
	- useful for calculation of kernel convolutions?
		- parallelizable task
		- useful 2D structure
		- unsure how memory model impacts performance, but now processing is less than 5% of GLSL time
	- possibly fast transforms?
	- recursive algorithms?
	- pass-through of buffers to next operations, but limited in memory -> tiling
	- tiling prevents consecutive dependent non-local operations
	- fft/convolution
--]]


local ffi = require("ffi")

-- FIXME: fix windows libs

local gl	= ffi.load("GL")
local glu	= ffi.load("GLU")
local glut	= ffi.load("glut")

ffi.cdef[[
typedef unsigned int GLenum;
typedef unsigned char GLboolean;
typedef unsigned int GLbitfield;
typedef signed char GLbyte;
typedef short GLshort;
typedef int GLint;
typedef int GLsizei;
typedef unsigned char GLubyte;
typedef unsigned short GLushort;
typedef unsigned int GLuint;
typedef unsigned short GLhalf;
typedef float GLfloat;
typedef float GLclampf;
typedef double GLdouble;
typedef double GLclampd;
typedef void GLvoid;
typedef char GLchar;
//	
void glMatrixMode( GLenum mode );
void glLoadIdentity( void );
void gluOrtho2D (GLdouble left, GLdouble right, GLdouble bottom, GLdouble top);
void glBegin( GLenum mode );
void glEnd( void );
void glTexCoord2f( GLfloat s, GLfloat t );
void glVertex2i( GLint x, GLint y );
void glViewport (GLint x, GLint y, GLsizei width, GLsizei height);
//
GLuint glCreateProgram (void);
GLuint glCreateShader (GLenum type);
GLint glGetUniformLocation (GLuint program, const GLchar *name);
void glShaderSource (GLuint shader, GLsizei count, const GLchar* *string, const GLint *length);
void glCompileShader (GLuint shader);
void glAttachShader (GLuint program, GLuint shader);
void glLinkProgram (GLuint program);
void glUseProgram (GLuint program);
void glGetShaderiv (GLuint shader, GLenum pname, GLint *params);
void glGetShaderInfoLog (GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
//
void glUniform1f (GLint location, GLfloat v0);
void glUniform2f (GLint location, GLfloat v0, GLfloat v1);
void glUniform3f (GLint location, GLfloat v0, GLfloat v1, GLfloat v2);
void glUniform4f (GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3);
void glUniform1i (GLint location, GLint v0);
void glUniform2i (GLint location, GLint v0, GLint v1);
void glUniform3i (GLint location, GLint v0, GLint v1, GLint v2);
void glUniform4i (GLint location, GLint v0, GLint v1, GLint v2, GLint v3);
// textures
void glDeleteTextures (GLsizei n, const GLuint *textures);
void glGenTextures (GLsizei n, GLuint *textures);
void glBindTexture (GLenum target, GLuint texture);
void glPixelStorei (GLenum pname, GLint param);
void glTexParameteri (GLenum target, GLenum pname, GLint param);
void glActiveTexture (GLenum texture);
void glTexImage2D (GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const GLvoid *pixels);
void glGetTexImage (GLenum target, GLint level, GLenum format, GLenum type, GLvoid *pixels);
//framebuffers
void glGenFramebuffers (GLsizei n, GLuint *framebuffers);
void glDeleteFramebuffers (GLsizei n, const GLuint *framebuffers);
void glBindFramebuffer (GLenum target, GLuint framebuffer);
void glFramebufferTexture2D (GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);
//
void glDrawBuffers (GLsizei n, const GLenum *bufs);
void glFinish (void);
void glFlush (void);
//??
void glutInitDisplayString(const char *string);
void glutInit(int *argcp, char **argv);
int glutCreateWindow(const char *title);
void glutHideWindow(void);
void glDisable (GLenum cap);
void glEnable (GLenum cap);
]]

local def = {}
def.TEXTURE_2D			= 0x0DE1
def.UNPACK_ALIGNMENT	= 0x0CF5
def.TEXTURE_WRAP_S		= 0x2802
def.TEXTURE_WRAP_T		= 0x2803
def.TEXTURE_MAG_FILTER	= 0x2800
def.TEXTURE_MIN_FILTER	= 0x2801
def.CLAMP_TO_BORDER		= 0x812D
def.NEAREST				= 0x2600
def.FRAMEBUFFER			= 0x8D40
def.COLOR_ATTACHMENT0	= 0x8CE0
def.COLOR_ATTACHMENT1	= 0x8CE1
def.COLOR_ATTACHMENT2	= 0x8CE2
def.COLOR_ATTACHMENT3	= 0x8CE3
def.COLOR_ATTACHMENT4	= 0x8CE4
def.COLOR_ATTACHMENT5	= 0x8CE5
def.COLOR_ATTACHMENT6	= 0x8CE6
def.COLOR_ATTACHMENT7	= 0x8CE7
def.COLOR_ATTACHMENT8	= 0x8CE8
def.COLOR_ATTACHMENT9	= 0x8CE9
def.COLOR_ATTACHMENT10	= 0x8CEA
def.COLOR_ATTACHMENT11	= 0x8CEB
def.COLOR_ATTACHMENT12	= 0x8CEC
def.COLOR_ATTACHMENT13	= 0x8CED
def.COLOR_ATTACHMENT14	= 0x8CEE
def.COLOR_ATTACHMENT15	= 0x8CEF
def.TEXTURE0		= 0x84C0
def.TEXTURE1 	= 0x84C1
def.TEXTURE2 	= 0x84C2
def.TEXTURE3 	= 0x84C3
def.TEXTURE4 	= 0x84C4
def.TEXTURE5 	= 0x84C5
def.TEXTURE6 	= 0x84C6
def.TEXTURE7 	= 0x84C7
def.TEXTURE8 	= 0x84C8
def.TEXTURE9 	= 0x84C9
def.TEXTURE10	= 0x84CA
def.TEXTURE11	= 0x84CB
def.TEXTURE12	= 0x84CC
def.TEXTURE13	= 0x84CD
def.TEXTURE14	= 0x84CE
def.TEXTURE15	= 0x84CF
def.TEXTURE16	= 0x84D0
def.TEXTURE17	= 0x84D1
def.TEXTURE18	= 0x84D2
def.TEXTURE19	= 0x84D3
def.TEXTURE20	= 0x84D4
def.TEXTURE21	= 0x84D5
def.TEXTURE22	= 0x84D6
def.TEXTURE23	= 0x84D7
def.TEXTURE24	= 0x84D8
def.TEXTURE25	= 0x84D9
def.TEXTURE26	= 0x84DA
def.TEXTURE27	= 0x84DB
def.TEXTURE28	= 0x84DC
def.TEXTURE29	= 0x84DD
def.TEXTURE30	= 0x84DE
def.TEXTURE31	= 0x84DF
def.DEPTH_TEST	= 0x0B71
def.CULL_FACE	= 0x0B44
def.FLOAT		= 0x1406
def.RED			= 0x1903
def.RG			= 0x8227
def.RGB			= 0x1907
def.RGBA		= 0x1908
def.R32F		= 0x822E
def.RG32F		= 0x8230
def.RGB32F		= 0x8815
def.RGBA32F		= 0x8814
def.PROJECTION	= 0x1701
def.MODELVIEW	= 0x1700
def.QUADS		= 0x0007
def.CLAMP		= 0x2900
def.FRAGMENT_SHADER		= 0x8B30
def.VERTEX_SHADER		= 0x8B31
def.INFO_LOG_LENGTH		= 0x8B84

-- functions
local glsl = {}

function glsl.init()
	local argv = ffi.new("char *[?]", 0, {})
	local argcp = ffi.new("int[1]", 0)
	glut.glutInit(argcp, argv)
	glut.glutCreateWindow("");
	glut.glutHideWindow()
	gl.glEnable(def.TEXTURE_2D)
	gl.glDisable(def.DEPTH_TEST);
	gl.glDisable(def.CULL_FACE);
	gl.glFlush();
	print("GLSL setup")
end

function glsl.finish() gl.glFinish() end

-- move to init
function glsl.reshape(h, w)
	gl.glMatrixMode(def.PROJECTION)
	gl.glLoadIdentity()
	glu.gluOrtho2D(0,w,0,h)
	gl.glMatrixMode(def.MODELVIEW)
	gl.glLoadIdentity()
	gl.glViewport(0,0,w,h)
end

do
	local function readFile(name)
		local str = io.open(name, "r"):read('*a')
		io.close()
		return str
	end
	
	local function shaderLog(s)
		local logLength = ffi.new('GLint[?]', 1)
		local charsWritten = ffi.new('GLsizei[?]', 1)
		
		gl.glGetShaderiv(s, def.INFO_LOG_LENGTH, logLength);

		if logLength[0] > 0 then
			local log = ffi.new('GLchar[?]', logLength[0]+1)
			gl.glGetShaderInfoLog(s, logLength[0], charsWritten, log)
			return ffi.string(log)
		else return "" end
	end
	
	local function shaderSource(shader, source)
		local sourcep = ffi.new('GLchar[?]', #source + 1)
		ffi.copy(sourcep, source)
		local sourcepp = ffi.new('const GLchar *[1]', sourcep)
		gl.glShaderSource(shader, 1, sourcepp, NULL)
	end
	
	function glsl.compileShader(vsFilename, fsFilename)
		local v, f, p
		local vs, fs
		
		vs = readFile(vsFilename);
		v = gl.glCreateShader(def.VERTEX_SHADER)
		shaderSource(v, vs)
		gl.glCompileShader(v)
		print(shaderLog(v))
		
		fs = readFile(fsFilename);
		f = gl.glCreateShader(def.FRAGMENT_SHADER)
		shaderSource(f, fs)
		gl.glCompileShader(f)
		print(shaderLog(f))
	
		p = gl.glCreateProgram()
		gl.glAttachShader(p,v)
		gl.glAttachShader(p,f)
		gl.glLinkProgram(p)
		
		return p
	end
end

function glsl.runShader(s, x, y)
    gl.glUseProgram(s);
    gl.glBegin(def.QUADS);
	    gl.glTexCoord2f(0, 0);
	    gl.glVertex2i(0, 0);
	    gl.glTexCoord2f(0, 1);
	    gl.glVertex2i(0, y);
	    gl.glTexCoord2f(1, 1);
	    gl.glVertex2i(x ,y);
	    gl.glTexCoord2f(1, 0);
	    gl.glVertex2i(x, 0);
    gl.glEnd();
    gl.glUseProgram(0);
end

function glsl.setUniformTex(s, n, name)
    gl.glUseProgram(s);
	gl.glUniform1i(gl.glGetUniformLocation(s, name), n)  
    gl.glUseProgram(0);
end

do
	local function setUniform4f(s, name, v1, v2, v3, v4)
	    gl.glUseProgram(s);
	    gl.glUniform4f(gl.glGetUniformLocation(s, name), v1, v2, v3, v4)  
	    gl.glUseProgram(0);
	end
	
	local function setUniform3f(s, name, v1, v2, v3)
	    gl.glUseProgram(s);
	    gl.glUniform3f(gl.glGetUniformLocation(s, name), v1, v2, v3)  
	    gl.glUseProgram(0);
	end
	
	local function setUniform2f(s, name, v1, v2)
	    gl.glUseProgram(s);
	    gl.glUniform2f(gl.glGetUniformLocation(s, name), v1, v2)  
	    gl.glUseProgram(0);
	end
	
	local function setUniform1f(s, name, v1)
	    gl.glUseProgram(s);
	    gl.glUniform1f(gl.glGetUniformLocation(s, name), v1)  
	    gl.glUseProgram(0);
	end
	
	function glsl.setUniform(s, name, v1, v2, v3, v4)
		if v2==nil then setUniform1f(s, name, v1)
		elseif v3==nil then setUniform2f(s, name, v1, v2)
		elseif v4==nil then setUniform3f(s, name, v1, v2, v3)
		else setUniform4f(s, name, v1, v2, v3, v4) end
	end
end

local __tf		= {def.RED, def.RG, def.RGB, def.RGBA}
local __tfInt	= {def.R32F, def.RG32F, def.RGB32F, def.RGBA32F}
function glsl.newTex(width, height, z)
	local texId = ffi.new("GLuint[1]")
	local texFormInt	= __tfInt[z]
	local texForm		= __tf[z]
	gl.glGenTextures(1, texId)
	gl.glBindTexture(def.TEXTURE_2D, texId[0]);
	gl.glPixelStorei(def.UNPACK_ALIGNMENT,1);
	gl.glTexImage2D(def.TEXTURE_2D, 0, texFormInt, width, height, 0, texForm, def.FLOAT, NULL)
	
	gl.glTexParameteri(def.TEXTURE_2D, def.TEXTURE_WRAP_S, def.CLAMP_TO_BORDER) -- clipping to 0 outside of image
	gl.glTexParameteri(def.TEXTURE_2D, def.TEXTURE_WRAP_T, def.CLAMP_TO_BORDER)
	gl.glTexParameteri(def.TEXTURE_2D, def.TEXTURE_MAG_FILTER, def.NEAREST)
	gl.glTexParameteri(def.TEXTURE_2D, def.TEXTURE_MIN_FILTER, def.NEAREST)
	return texId
end

function glsl.newFB()
	local fb = ffi.new("GLuint[1]")
	gl.glGenFramebuffers(1, fb)
	return fb
end

function glsl.attachTex(fb, texId, n)
	gl.glBindFramebuffer(def.FRAMEBUFFER, fb[0])
	gl.glFramebufferTexture2D(def.FRAMEBUFFER, def["COLOR_ATTACHMENT"..n], def.TEXTURE_2D, texId[0], 0);
	return fb;
end

function glsl.bindFB(fb)
	gl.glBindFramebuffer(def.FRAMEBUFFER, fb[0]);
	local mrt = ffi.new("GLenum[8]", {	def.COLOR_ATTACHMENT0,
										def.COLOR_ATTACHMENT1,
										def.COLOR_ATTACHMENT2,
										def.COLOR_ATTACHMENT3,
										def.COLOR_ATTACHMENT4,
										def.COLOR_ATTACHMENT5,
										def.COLOR_ATTACHMENT6,
										def.COLOR_ATTACHMENT7, })
	gl.glDrawBuffers(8, mrt);
end

function glsl.bindTex(tex, n)
	gl.glActiveTexture(def["TEXTURE"..n]);
	gl.glBindTexture(def.TEXTURE_2D, tex[0]);
end

function glsl.setTex(tex, data, width, height, z)
	local texForm		= __tf[z]
	local texFormInt	= __tfInt[z]
	gl.glBindTexture(def.TEXTURE_2D, tex[0]);
	gl.glTexImage2D(def.TEXTURE_2D, 0, texFormInt, width, height, 0, texForm, def.FLOAT, data);
end

function glsl.getTex(tex, data, z)
	local texForm		= __tf[z]
	gl.glBindTexture(def.TEXTURE_2D, tex[0]);
	gl.glGetTexImage(def.TEXTURE_2D, 0, texForm, def.FLOAT, data);
end

function glsl.freeTex(tex)
	gl.glDeleteTextures(1, tex);
end

function glsl.freeFB(fb)
	gl.glDeleteFramebuffers(1, fb);
end

--[[ complete shader function
shader = glsl.compile(vert, frag)
program = glsl.setupProgram(shader, # textures in, # textures out, x, y, z)
glsl.setProgram(program, {* textures in}, {uniforms})
glsl.runProgram(program)
glsl.getProgram(program, {* textures out})
glsl.freeProgram(program)
--]]


-- test
glsl.init()

-- texture size
local n = math.floor(math.random()*1000)
local m = math.floor(math.random()*1000)
local z = 1
local maxiter = 100
print(m.."x"..n.."x"..z.." float["..m*n*z.."], "..maxiter.." iterations.")
glsl.reshape(n, m)				-- setup viewport, important! 

-- setup data input and output
local data = ffi.new("float[?]", 4*m*n)
local result = ffi.new("float[?]", 4*m*n)
local res2 = ffi.new("float[?]", 4*m*n)
for i = 0, 4*m*n-1 do
	data[i]=i+1
end

-- setup textures and framebuffers
local tex1 = glsl.newTex(m,n, z)
local tex2 = glsl.newTex(m,n, z)
local tex3 = glsl.newTex(m,n, z)
local fbo1 = glsl.newFB()
glsl.attachTex(fbo1, tex1, 0)
glsl.attachTex(fbo1, tex3, 1)

local program = glsl.compileShader("shader.vs", "shader.fs") -- compile shader
glsl.setUniformTex(program, 0, "texUnit") -- pass uniform variables
glsl.setUniform(program, "powVec", 2.25, 2.25, 2.25, 2.25)

do
	local a = 0.099
	local G = 1/0.45
	
	local a_1 = 1/(1+a)
	local G_1 = 1/G
	
	local f = ((1+a)^G*(G-1)^(G-1))/(a^(G-1)*G^G)
	local k = a/(G-1)
	local k_f = k/f
	local f_1 = 1/f

	glsl.setUniform(program, "k_f", k_f, k_f, k_f, k_f)
	glsl.setUniform(program, "f", f, f, f, f)
	glsl.setUniform(program, "a", a, a, a, a)
	glsl.setUniform(program, "g_1", G_1, G_1, G_1, G_1)
end

-- set an inverse size for pixel offsets
glsl.setUniform(program, "xy", 1/m, 1/n)

glsl.bindFB(fbo1)				-- bind framebuffer
glsl.bindTex(tex2, 0)			-- bind textures

-- shading loop:
print("start GLSL ...")
local t = os.clock()
for i = 1, maxiter do
	glsl.setTex(tex2, data, m, n, z)	-- set data to texture
	glsl.runShader(program, m, n)		-- apply shader
	glsl.getTex(tex1, result, z)		-- get output data
	glsl.getTex(tex3, res2, z)			-- get output data
	glsl.finish()
end
print(os.clock() - t, "GLSL")
print(result[128], res2[0])
