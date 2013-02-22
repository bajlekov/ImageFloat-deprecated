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

-- initial implementation of GLSL shaders for image processing
-- lua adaptation of process-array examples by Ingemar Ragnemalm 2010
-- using glua bindings for openGL (Copyright (c) 2011-2012 Adam Strzelecki)
-- https://github.com/nanoant/glua, MIT-license
-- TODO port minimal bindings for shaders
-- TODO coexistence with SDL
-- TODO possible multiple instances for parallel data loading?

local ffi = require("ffi")
local gl    = require("glua")

-- additional definitions
ffi.cdef[[
	__attribute__((visibility("default"))) void glMatrixMode( GLenum mode );
	__attribute__((visibility("default"))) void glLoadIdentity( void );
	__attribute__((visibility("default"))) void gluOrtho2D (GLdouble left, GLdouble right, GLdouble bottom, GLdouble top);
	__attribute__((visibility("default"))) void glBegin( GLenum mode );
	__attribute__((visibility("default"))) void glEnd( void );
	__attribute__((visibility("default"))) void glTexCoord2f( GLfloat s, GLfloat t );
	__attribute__((visibility("default"))) void glVertex2i( GLint x, GLint y );
]]
gl.PROJECTION	= 0x1701
gl.MODELVIEW	= 0x1700
gl.QUADS		= 0x0007
gl.CLAMP		= 0x2900
local glu = ffi.load("GLU")

--local x, y = 1024, 1024

local function reshape(h, w)
	gl.MatrixMode(gl.PROJECTION)
	gl.LoadIdentity()
	glu.gluOrtho2D(0,w,0,h)
	gl.MatrixMode(gl.MODELVIEW);
	gl.LoadIdentity();
	gl.Viewport(0,0,w,h);
end

local function readFile(name)
	local str = io.open(name, "r"):read('*a')
	io.close()
	return str
end

local function printShaderLog(obj)
    local infologLength = ffi.new("GLint[1]", 0)
    local charsWritten = ffi.new("GLint[1]", 0)

	gl.GetShaderiv(obj, gl.INFO_LOG_LENGTH, infologLength);

    if infologLength[0]>0 then
        local infoLog = ffi.new("char[?]", infologLength[0]) 
        gl.GetShaderInfoLog(obj, infologLength, charsWritten, infoLog);
		print(ffi.string(infoLog))
    end
end

local function compileShaders(vsFilename, fsFilename)
	local v, f, p
	local vs, fs
	
	vs = readFile(vsFilename);
	v = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(v, vs)
	gl.CompileShader(v)
	
	fs = readFile(fsFilename);
	f = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(f, fs)
	gl.CompileShader(f)

	p = gl.CreateProgram()
	gl.AttachShader(p,v)
	gl.AttachShader(p,f)
	gl.LinkProgram(p)
	
	return p
end

local function applyProgram(s, x, y)
    gl.UseProgram(s);
    gl.Begin(gl.QUADS);
	    gl.TexCoord2f(0, 0);
	    gl.Vertex2i(0, 0);
	    gl.TexCoord2f(0, 1);
	    gl.Vertex2i(0, y);
	    gl.TexCoord2f(1, 1);
	    gl.Vertex2i(x ,y);
	    gl.TexCoord2f(1, 0);
	    gl.Vertex2i(x, 0);
    gl.End();
    gl.UseProgram(0);
end

local function setUniformTex(s, n, name)
    gl.UseProgram(s);
    gl.Uniform1i(gl.GetUniformLocation(s, name), n)  
    gl.UseProgram(0);
end

local function setUniform4f(s, name, v1, v2, v3, v4)
    gl.UseProgram(s);
    gl.Uniform4f(gl.GetUniformLocation(s, name), v1, v2, v3, v4)  
    gl.UseProgram(0);
end

local function setUniform3f(s, name, v1, v2, v3)
    gl.UseProgram(s);
    gl.Uniform3f(gl.GetUniformLocation(s, name), v1, v2, v3)  
    gl.UseProgram(0);
end

local function setUniform1f(s, name, v1)
    gl.UseProgram(s);
    gl.Uniform1f(gl.GetUniformLocation(s, name), v1)  
    gl.UseProgram(0);
end

local __tf		= {gl.RED, gl.RG, gl.RGB, gl.RGBA}
local __tfInt	= {gl.R32F, gl.RG32F, gl.RGB32F, gl.RGBA32F}

local function newTex(width, height, z)
	local texId = ffi.new("GLuint[1]")
	local texFormInt	= __tfInt[z]
	local texForm		= __tf[z]
	gl.GenTextures(1, texId)
	gl.BindTexture(gl.TEXTURE_2D, texId[0]);
	gl.PixelStorei(gl.UNPACK_ALIGNMENT,1);
	gl.TexImage2D(gl.TEXTURE_2D, 0, texFormInt, width, height, 0, texForm, gl.FLOAT, NULL)
	
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	
	return texId
end

local function newFB(texId, n)
	local fb = ffi.new("GLuint[1]")
	gl.GenFramebuffers(1, fb)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fb[0])
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl["COLOR_ATTACHMENT"..n], gl.TEXTURE_2D, texId[0], 0);
	return fb;
end

local function bindFB(fb)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fb[0]);
	local mrt = ffi.new("GLenum[8]", {	gl.COLOR_ATTACHMENT0,
										gl.COLOR_ATTACHMENT1,
										gl.COLOR_ATTACHMENT2,
										gl.COLOR_ATTACHMENT3,
										gl.COLOR_ATTACHMENT4,
										gl.COLOR_ATTACHMENT5,
										gl.COLOR_ATTACHMENT6,
										gl.COLOR_ATTACHMENT7, })
	gl.DrawBuffers(8, mrt);
end

local function bindTex(tex, n)
	gl.ActiveTexture(gl["TEXTURE"..n]);
	gl.BindTexture(gl.TEXTURE_2D, tex[0]);
end

local function setTex(tex, data, width, height, z)
	local texForm		= __tf[z]
	local texFormInt	= __tfInt[z]
	gl.BindTexture(gl.TEXTURE_2D, tex[0]);
	gl.TexImage2D(gl.TEXTURE_2D, 0, texFormInt, width, height, 0, texForm, gl.FLOAT, data);
end

local function getTex(tex, data, z)
	local texForm		= __tf[z]
	gl.BindTexture(gl.TEXTURE_2D, tex[0]);
	gl.GetTexImage(gl.TEXTURE_2D, 0, texForm, gl.FLOAT, data);
end

-- main program

-- setup
print("start GLSL setup ...")
gl.utInitDisplayString('rgba double depth>=16 samples~8')
gl.utCreateWindow("");
gl.utHideWindow()
gl.Enable(gl.TEXTURE_2D)
gl.Disable(gl.DEPTH_TEST);
gl.Disable(gl.CULL_FACE);
gl.Flush();

-- texture size
local n = 2048
local m = 2048
reshape(n, m)				-- setup viewport, important! 

-- setup data input and output
local data = ffi.new("float[?]", 4*m*n)
local result = ffi.new("float[?]", 4*m*n)
for i = 0, 4*m*n-1 do
	data[i]=i+1
end

-- setup textures and framebuffers
local tex1 = newTex(m,n, 4)
local tex2 = newTex(m,n, 4)
local fbo1 = newFB(tex1, 0)

local program = compileShaders("shader.vs", "shader.fs") -- compile shader
setUniformTex(program, 0, "texUnit") -- pass uniform variables
setUniform4f(program, "powVec", 2.25, 2.25, 2.25, 2.25)
bindFB(fbo1)				-- bind framebuffer
bindTex(tex2, 0)			-- bind textures

-- shading loop:
print("start GLSL ...")
local t = os.clock()
for i = 1, 25 do
	setTex(tex2, data, m, n, 4)		-- set data to texture
	applyProgram(program, m, n)		-- apply shader
	getTex(tex1, result, 4)			-- get output data
end
print(os.clock() - t, "GLSL")
print(result[128], 129^2.25)

local t = os.clock()
for i = 1, 25 do
	for j = 0, m*n*4-1 do
		result[j] = data[j]^2.25
	end
end
print(os.clock() - t, "CPU")
print(result[128], 129^2.25)

print("success!!")
