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
	- tiling prevents consecutive dependent non-local operations -> horizontal blocks instead of tiles, uses consequtive memory
	
	* fft??
	* piece-wise transpose?
		- in general make single readout swapping transpose, eliminating multiple partial reads of a single area
	* convolutions
	* median filter
	* IIR gaussian filter
--]]


local ffi = require("ffi")

-- FIXME: windows functions work, but nothing is processed

local win = jit.os=="Windows"

print(jit.os, jit.arch)

local gl	= win and ffi.load("opengl32") or  ffi.load("GL") -- openGL on windows seems not to be updated by the graphics driver
local glu	= win and ffi.load("glu32") or ffi.load("GLU")
local glut	= win and ffi.load("freeglut") or ffi.load("glut")

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
def.CORE_PROFILE		= 0x0001
def.COMPATIBILITY_PROFILE = 0x0002
def.VENDOR				= 0x1F00
def.RENDERER			= 0x1F01
def.VERSION				= 0x1F02
def.EXTENSIONS			= 0x1F03

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
void glFinish (void);
void glFlush (void);
// textures
void glDeleteTextures (GLsizei n, const GLuint *textures);
void glGenTextures (GLsizei n, GLuint *textures);
void glBindTexture (GLenum target, GLuint texture);
void glPixelStorei (GLenum pname, GLint param);
void glTexParameteri (GLenum target, GLenum pname, GLint param);
void glTexImage2D (GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const GLvoid *pixels);
void glGetTexImage (GLenum target, GLint level, GLenum format, GLenum type, GLvoid *pixels);
//
void glutInitDisplayString(const char *string);
void glutInit(int *argcp, char **argv);
int glutCreateWindow(const char *title);
void glutHideWindow(void);
void glDisable (GLenum cap);
void glEnable (GLenum cap);
//compatibility helpers
void glutInitContextProfile( int profile );
const GLubyte * glGetString (GLenum name);
void glutInitContextVersion( int majorVersion, int minorVersion );
]]

-- functions
local glsl = {}
local dep = {}
local function getDeps()
	-- cast GL3 prototypes to functions
	ffi.cdef[[
	//GL3 prototypes
	void * glutGetProcAddress(const char *procName);
	typedef void (PFNGLGENFRAMEBUFFERSPROC) (GLsizei n, GLuint *framebuffers);
	typedef void (PFNGLBINDFRAMEBUFFERPROC) (GLenum target, GLuint framebuffer);
	typedef void (PFNGLFRAMEBUFFERTEXTURE2DPROC) (GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);
	typedef GLuint (PFNGLCREATESHADERPROC) (GLenum type);
	typedef void (PFNGLSHADERSOURCEPROC) (GLuint shader, GLsizei count, const GLchar* *string, const GLint *length);
	typedef void (PFNGLCOMPILESHADERPROC) (GLuint shader);
	typedef void (PFNGLGETSHADERIVPROC) (GLuint shader, GLenum pname, GLint *params);
	typedef void (PFNGLGETPROGRAMIVPROC) (GLuint program, GLenum pname, GLint *params);
	typedef void (PFNGLGETSHADERINFOLOGPROC) (GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
	typedef void (PFNGLGETPROGRAMINFOLOGPROC) (GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
	typedef GLuint (PFNGLCREATEPROGRAMPROC) (void);
	typedef void (PFNGLATTACHSHADERPROC) (GLuint program, GLuint shader);
	typedef void (PFNGLLINKPROGRAMPROC) (GLuint program);
	typedef void (PFNGLUSEPROGRAMPROC) (GLuint program);
	typedef void (PFNGLUNIFORM1FPROC) (GLint location, GLfloat v0);
	typedef void (PFNGLUNIFORM2FPROC) (GLint location, GLfloat v0, GLfloat v1);
	typedef void (PFNGLUNIFORM3FPROC) (GLint location, GLfloat v0, GLfloat v1, GLfloat v2);
	typedef void (PFNGLUNIFORM4FPROC) (GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3);
	typedef void (PFNGLUNIFORM1IPROC) (GLint location, GLint v0);
	typedef GLint (PFNGLGETUNIFORMLOCATIONPROC) (GLuint program, const GLchar *name);
	typedef void (PFNGLDRAWBUFFERSPROC) (GLsizei n, const GLenum *bufs);
	typedef void (PFNGLACTIVETEXTUREPROC) (GLenum texture);
	
	typedef void (PFNGLDELETEFRAMEBUFFERSPROC) (GLsizei n, const GLuint *framebuffers);
	]]
	
	dep.glGenFramebuffers = ffi.cast("PFNGLGENFRAMEBUFFERSPROC*",glut.glutGetProcAddress("glGenFramebuffers"))
	dep.glBindFramebuffer = ffi.cast("PFNGLBINDFRAMEBUFFERPROC*",glut.glutGetProcAddress("glBindFramebuffer"))
	dep.glFramebufferTexture2D = ffi.cast("PFNGLFRAMEBUFFERTEXTURE2DPROC*",glut.glutGetProcAddress("glFramebufferTexture2D"))
	dep.glCreateShader = ffi.cast("PFNGLCREATESHADERPROC*",glut.glutGetProcAddress("glCreateShader"))
	dep.glShaderSource = ffi.cast("PFNGLSHADERSOURCEPROC*",glut.glutGetProcAddress("glShaderSource"))
	dep.glCompileShader = ffi.cast("PFNGLCOMPILESHADERPROC*",glut.glutGetProcAddress("glCompileShader"))
	dep.glGetShaderiv = ffi.cast("PFNGLGETSHADERIVPROC*",glut.glutGetProcAddress("glGetShaderiv"))
	dep.glGetShaderInfoLog = ffi.cast("PFNGLGETSHADERINFOLOGPROC*",glut.glutGetProcAddress("glGetShaderInfoLog"))
	dep.glGetProgramiv = ffi.cast("PFNGLGETPROGRAMIVPROC*",glut.glutGetProcAddress("glGetProgramiv"))
	dep.glGetProgramInfoLog = ffi.cast("PFNGLGETPROGRAMINFOLOGPROC*",glut.glutGetProcAddress("glGetProgramInfoLog"))
	dep.glCreateProgram = ffi.cast("PFNGLCREATEPROGRAMPROC*",glut.glutGetProcAddress("glCreateProgram"))
	dep.glAttachShader = ffi.cast("PFNGLATTACHSHADERPROC*",glut.glutGetProcAddress("glAttachShader"))
	dep.glLinkProgram = ffi.cast("PFNGLLINKPROGRAMPROC*",glut.glutGetProcAddress("glLinkProgram"))
	dep.glUseProgram = ffi.cast("PFNGLUSEPROGRAMPROC*",glut.glutGetProcAddress("glUseProgram"))
	dep.glUniform1f = ffi.cast("PFNGLUNIFORM1FPROC*",glut.glutGetProcAddress("glUniform1f"))
	dep.glUniform2f = ffi.cast("PFNGLUNIFORM2FPROC*",glut.glutGetProcAddress("glUniform2f"))
	dep.glUniform3f = ffi.cast("PFNGLUNIFORM3FPROC*",glut.glutGetProcAddress("glUniform3f"))
	dep.glUniform4f = ffi.cast("PFNGLUNIFORM4FPROC*",glut.glutGetProcAddress("glUniform4f"))
	dep.glUniform1i = ffi.cast("PFNGLUNIFORM1IPROC*",glut.glutGetProcAddress("glUniform1i"))
	dep.glGetUniformLocation = ffi.cast("PFNGLGETUNIFORMLOCATIONPROC*",glut.glutGetProcAddress("glGetUniformLocation"))
	dep.glDrawBuffers = ffi.cast("PFNGLDRAWBUFFERSPROC*",glut.glutGetProcAddress("glDrawBuffers"))
	dep.glActiveTexture = ffi.cast("PFNGLACTIVETEXTUREPROC*",glut.glutGetProcAddress("glActiveTexture"))
	dep.glDeleteFramebuffers = ffi.cast("PFNGLDELETEFRAMEBUFFERSPROC*",glut.glutGetProcAddress("glDeleteFramebuffers"))
end

function glsl.init()
	local argv = ffi.new("char *[?]", 0, {})
	local argcp = ffi.new("int[1]", 0)
	glut.glutInit(argcp, argv)
	glut.glutInitContextVersion( 3, 0 )
	glut.glutInitContextProfile(def.CORE_PROFILE)
	glut.glutCreateWindow("");
	glut.glutHideWindow()
	gl.glDisable(def.DEPTH_TEST);
	gl.glDisable(def.CULL_FACE);
	gl.glFlush();
	print(ffi.string(gl.glGetString(def.VENDOR)))
	print(ffi.string(gl.glGetString(def.VERSION)))
	print(ffi.string(gl.glGetString(def.RENDERER)))
	getDeps()
end

function glsl.finish() gl.glFinish() end
function glsl.flush() gl.glFlush() end

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
		local str = io.open(name, "rb"):read('*a')
		io.close()
		return str
	end
	
	local function shaderLog(s)
		local logLength = ffi.new('GLint[?]', 1)
		local charsWritten = ffi.new('GLsizei[?]', 1)
		
		dep.glGetShaderiv(s, def.INFO_LOG_LENGTH, logLength);

		if logLength[0] > 0 then
			local log = ffi.new('GLchar[?]', logLength[0]+1)
			dep.glGetShaderInfoLog(s, logLength[0], charsWritten, log)
			return ffi.string(log)
		else return "" end
	end
	
	local function programLog(s)
		local logLength = ffi.new('GLint[?]', 1)
		local charsWritten = ffi.new('GLsizei[?]', 1)
		
		dep.glGetProgramiv(s, def.INFO_LOG_LENGTH, logLength);

		if logLength[0] > 0 then
			local log = ffi.new('GLchar[?]', logLength[0]+1)
			dep.glGetProgramInfoLog(s, logLength[0], charsWritten, log)
			return ffi.string(log)
		else return "" end
	end
	
	local function shaderSource(shader, source)
		local sourcep = ffi.new('GLchar[?]', #source + 1)
		ffi.copy(sourcep, source)
		local sourcepp = ffi.new('const GLchar *[1]', sourcep)
		dep.glShaderSource(shader, 1, sourcepp, NULL)
	end
	
	function glsl.compileShader(vsFilename, fsFilename)
		local v, f, p
		local vs, fs
		
		vs = readFile(vsFilename);
		v = dep.glCreateShader(def.VERTEX_SHADER)
		shaderSource(v, vs)
		dep.glCompileShader(v)
		print(shaderLog(v))
		
		fs = readFile(fsFilename);
		f = dep.glCreateShader(def.FRAGMENT_SHADER)
		shaderSource(f, fs)
		dep.glCompileShader(f)
		print(shaderLog(f))
	
		p = dep.glCreateProgram()
		dep.glAttachShader(p,v)
		dep.glAttachShader(p,f)
		dep.glLinkProgram(p)
		print(programLog(p))
		return p
	end
end

function glsl.runShader(s, x, y)
    dep.glUseProgram(s);
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
    dep.glUseProgram(0);
end

function glsl.setUniformTex(s, n, name)
    dep.glUseProgram(s);
	dep.glUniform1i(dep.glGetUniformLocation(s, name), n)  
    dep.glUseProgram(0);
end

do
	local function setUniform4f(s, name, v1, v2, v3, v4)
	    dep.glUseProgram(s);
	    dep.glUniform4f(dep.glGetUniformLocation(s, name), v1, v2, v3, v4)  
	    dep.glUseProgram(0);
	end
	
	local function setUniform3f(s, name, v1, v2, v3)
	    dep.glUseProgram(s);
	    dep.glUniform3f(dep.glGetUniformLocation(s, name), v1, v2, v3)  
	    dep.glUseProgram(0);
	end
	
	local function setUniform2f(s, name, v1, v2)
	    dep.glUseProgram(s);
	    dep.glUniform2f(dep.glGetUniformLocation(s, name), v1, v2)  
	    dep.glUseProgram(0);
	end
	
	local function setUniform1f(s, name, v1)
	    dep.glUseProgram(s);
	    dep.glUniform1f(dep.glGetUniformLocation(s, name), v1)  
	    dep.glUseProgram(0);
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
	dep.glGenFramebuffers(1, fb)
	return fb
end

function glsl.attachTex(fb, texId, n)
	if jit.os=="Windows" and n>1 then
		print("Only gl_FragData[0] support on windows. No output will be written to this texture!")
	end
	dep.glBindFramebuffer(def.FRAMEBUFFER, fb[0])
	dep.glFramebufferTexture2D(def.FRAMEBUFFER, def["COLOR_ATTACHMENT"..n], def.TEXTURE_2D, texId[0], 0);
	return fb;
end

function glsl.bindFB(fb)
	dep.glBindFramebuffer(def.FRAMEBUFFER, fb[0]);
	
	-- code is problematic on wondows
	if jit.os=="Windows" then
		print("Only output at gl_FragData[0] supported on windows!")
	else
		local mrt = ffi.new("GLenum[8]", {	def.COLOR_ATTACHMENT0,
											def.COLOR_ATTACHMENT1,
											def.COLOR_ATTACHMENT2,
											def.COLOR_ATTACHMENT3,
											def.COLOR_ATTACHMENT4,
											def.COLOR_ATTACHMENT5,
											def.COLOR_ATTACHMENT6,
											def.COLOR_ATTACHMENT7, })
		dep.glDrawBuffers(8, mrt);
	end
end

function glsl.bindTex(tex, n)
	dep.glActiveTexture(def["TEXTURE"..n]);
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
	dep.glDeleteFramebuffers(1, fb);
end



function glsl.run(prog, texIn, texOut, uni)
	for i = 1, #uni do
		glsl.setUniform(prog.sh, uni[i].name, uni[i][1], uni[i][2], uni[i][3], uni[i][4])
	end
	for i = 1, prog.ni do
		glsl.bindTex(prog.ti[i], i-1)					--bind texture
		glsl.setUniformTex(prog.sh, i-1, "tex"..i)		--set texture as named uniform
		glsl.setTex(prog.ti[i], texIn[i], prog.x, prog.y, prog.z)
	end
	glsl.bindFB(prog.fb)								--bind framebuffer
	glsl.runShader(prog.sh, prog.x, prog.y)				-- apply shader
	for i = 1, prog.no do
		glsl.getTex(prog.to[i], texOut[i], prog.z)		-- get output data
	end
	--glsl.finish()
end

function glsl.free(prog)
	for i = 1, prog.ni do
		glsl.freeTex(prog.ti[i])
	end
	for i = 1, prog.no do
		glsl.freeTex(prog.to[i])
	end
	glsl.freeFB(prog.fb)
end


function glsl.new(shader, nTexIn, nTexOut, sizeX, sizeY, sizeZ)
	local o = {x = sizeX, y=sizeY, z=sizeZ, ni=nTexIn, no=nTexOut, ti={}, to={}}
	o.sh = glsl.compileShader("Shaders/shader.vs", shader)	--compile shader
	glsl.reshape(sizeX, sizeY)								--set size
	o.fb = glsl.newFB()										--new fbo
	for i = 1, nTexIn do
		o.ti[i] = glsl.newTex(sizeX, sizeY, sizeZ)			--create input textures
	end
	for i = 1, nTexOut do
		o.to[i] = glsl.newTex(sizeX, sizeY, sizeZ)			--create output textures
		glsl.attachTex(o.fb, o.to[i], i-1)					--attach output textures
	end
	o.run = glsl.run
	o.free = glsl.free
	
	return o
end

-- test/example
--[[
glsl.init()

-- texture size
local n = 4096
local m = 2048
local z = 1
local maxiter = 10
print(m.."x"..n.."x"..z.." float["..m*n*z.."], "..maxiter.." iterations.")
glsl.reshape(n, m)				-- setup viewport, important! 

-- setup data input and output
local data = ffi.new("float[?]", 4*m*n)
local result = ffi.new("float[?]", 4*m*n)
local res2 = ffi.new("float[?]", 4*m*n)

for i = 0, 4*m*n-1 do
	data[i] = i+1
	res2[i] = 5 
end

-- ====================================================
-- new GLSL program
-- ====================================================
local pr = glsl.new("Shaders/median.fs", 1, 1, m, n, z)

print("start GLSL ...")
local g = os.time()
local t = os.clock()
for i = 1, maxiter do
	pr:run({data}, {result}, {{1/m, 1/n, name="xy"}})
end
print(os.clock() - t, "GLSL (cpu time)")
print(os.time()-g, "GLSL (wall time)")
pr:free()
print(result[4096+128], result[4096+129], result[4096+130], result[4096+131])

-- timing of native median filter from "./median.lua":

local median
do
	local pix = ffi.new("double[9]")
	local A = ffi.new("short[19]", 1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4)
	local B = ffi.new("short[19]", 2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2)
	local function sort(a, b)
		if pix[a]>pix[b] then
			pix[a], pix[b] = pix[b], pix[a]
		end
	end
	median = function(i, o, xmax, ymax)
		for x = 1, xmax-2 do
			for y = 1, ymax-2 do
				pix[0] = i[(y-1)*xmax+x-1];
				pix[1] = i[y*xmax+x-1];
				pix[2] = i[(y+1)*xmax+x-1];
				pix[3] = i[(y-1)*xmax+x];
				pix[4] = i[y*xmax+x];
				pix[5] = i[(y+1)*xmax+x];
				pix[6] = i[(y-1)*xmax+x+1];
				pix[7] = i[y*xmax+x+1];
				pix[8] = i[(y+1)*xmax+x+1];
				
				for i = 0, 18 do
					sort(A[i], B[i]);
				end
				o[y*xmax+x] = pix[4];
			end
		end
	end
end

print("start Lua ...")
local g = os.time()
local t = os.clock()
for i = 1, maxiter do
	median(data, result, m, n*z)
end
print(os.clock() - t, "Lua (cpu time)")
print(os.time()-g, "Lua (wall time)")
print(result[4096+128], result[4096+129], result[4096+130], result[4096+131])
--]]

return glsl