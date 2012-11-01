package.preload['ops']=(function(...)
local ops={}
ops.cs=require("opsCS")
ops.fft=require("opsFFT")
ops.transform=require("opsTransform")
ops.filter=require("opsFilter")
ops.layer=require("opsLayer")
require("mathtools")
local startstring_matrix=[[
							for x = __instance, xmax-1, __tmax do
								if progress[0]==-1 then break end
								for y = 0, ymax-1 do
									__pp = (x * ymax + y)
]]local endstring_matrix=[[
									end
								progress[__instance+1] = x - __instance
							end
							progress[__instance+1] = -1
]]
local startstring_single=[[ __pp = 0 ]]
local endstring_single=[[ progress[__instance+1] = -1 ]]
ops.strings={
invert=[[ -- 2, 1
	for c = 0, 2 do
		set[1]( (1-get[1](c))*get[2](c) + get[1](c)*(1-get[2](c)), c)
	end ]],
mixer=[[ -- 4, 1
	set[1]( get[2](0)*get[1](0) + get[2](1)*get[1](1) + get[2](2)*get[1](2), 0)
	set[1]( get[3](0)*get[1](0) + get[3](1)*get[1](1) + get[3](2)*get[1](2), 1)
	set[1]( get[4](0)*get[1](0) + get[4](1)*get[1](1) + get[4](2)*get[1](2), 2)
	]],
cstransform=[[ --1, 1, {9}
	local c1, c2, c3 = get3[1]()
	local p1, p2, p3
	p1 = params[1]*c1 + params[2]*c2 + params[3]*c3
	p2 = params[4]*c1 + params[5]*c2 + params[6]*c3
	p3 = params[7]*c1 + params[8]*c2 + params[9]*c3
	set3[1](p1, p2, p3)
	]],
copy=[[ -- 1, 1
	set3[1]( get3[1]())
	]],
hsxedit=[[ -- 2,1
	local x = get[2](0)+get[1](0)
	x = x>1 and x-1 or x
	set[1]( x, 0)
	set[1]( get[2](1)*get[1](1), 1)
	set[1]( get[2](2)*get[1](2), 2)
	]],
lchedit=[[ -- 2,1
	local x = get[2](2)+get[1](2)
	x = x>1 and x-1 or x
	set[1]( get[2](0)*get[1](0), 0)
	set[1]( get[2](1)*get[1](1), 1)
	set[1]( x, 2)
	]],
rgbedit=[[ -- 3,1
	for c = 0, 2 do
		set[1]( get[1](c)*get[2](c)+get[3](c) , c)
	end	]],
compose=[[ -- 3,1
	set3[1]( get[1](0), get[2](1), get[3](2) )
	]],
decompose=[[ -- 1,3
		set[1](get[1](0))
		set[2](get[1](1))
		set[3](get[1](2))
	]],
merge=[[ -- 3,1
	for c = 0, 2 do
		set[1]( get[1](c)*get[3](c) + get[2](c)*(1-get[3](c)), c)
	end	]],
add=[[ -- 2,1
	for c = 0, 2 do
		set[1]( get[1](c) + get[2](c), c)
	end	]],
sub=[[ -- 2,1
	for c = 0, 2 do
		set[1]( get[1](c) - get[2](c), c)
	end	]],
mult=[[ -- 2,1
	for c = 0, 2 do
		set[1]( get[1](c) * get[2](c), c)
	end	]],
div=[[ -- 2,1
	for c = 0, 2 do
		set[1]( get[1](c) / get[2](c), c)
	end	]],
compMult=[[ -- 4, 2
	for c = 0, 2 do
		set[1]( get[1](c)*get[3](c) - get[2](c)*get[4](c), c)
		set[2]( get[1](c)*get[4](c) + get[2](c)*get[3](c), c)
	end
	]],
zero=[[ -- 0,1
	for c = 0, 2 do
		set[1]( 0, c)
	end	]],
equaliseGB=[[ -- 1,1
		local GB = (get[1](1)+get[1](2))/2
		set[1]( GB, 1)
		set[1]( GB, 2)
	]],
invertR_GB=[[ -- 1,1
		local GB = 1-get[1](0)
		set[1]( GB, 1)
		set[1]( GB, 2)
	]],
pass=[[ -- 1, 1
	set3[1](get3[1]())
	]],
}
do
local function filter(func,flag)
for x=__instance,xmax/2,__tmax do
if progress[0]==-1 then break end
for y=0,ymax/2 do
local gauss
local size=128
gauss=func(math.sqrt(x^2+y^2),get[1](0)*size)
gauss=gauss+(flag and func(math.sqrt((xmax-x+1)^2+y^2),get[1](0)*size)or 0)
gauss=gauss+(flag and func(math.sqrt(x^2+(ymax-y+1)^2),get[1](0)*size)or 0)
gauss=gauss+(flag and func(math.sqrt((xmax-x+1)^2+(ymax-y+1)^2),get[1](0)*size)or 0)
gauss=gauss*get[2]()+1-get[2]()
set3xy[1](gauss,gauss,gauss,x,y)
if x~=0 then set3xy[1](gauss,gauss,gauss,xmax-x,y)end
if y~=0 then set3xy[1](gauss,gauss,gauss,x,ymax-y)end
if x~=0 and y~=0 then set3xy[1](gauss,gauss,gauss,xmax-x,ymax-y)end
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
function ops.gauss()return filter(math.func.gauss)end
function ops.lorenz()return filter(math.func.lorenz)end
function ops.gauss_wrap()return filter(math.func.gauss,true)end
function ops.lorenz_wrap()return filter(math.func.lorenz,true)end
end
for k,v in pairs(ops.strings)do
ops[k]=loadstring(startstring_matrix..v..endstring_matrix)
end
ops.strings=nil
ops.empty=function()progress[__instance+1]=-1 end
ops.norm=function()
local sum={[0]=0,[1]=0,[2]=0}
for x=__instance,xmax-1,__tmax do
if progress[0]==-1 then break end
for y=0,ymax-1 do
__pp=(x*ymax+y)
for c=0,2 do
sum[c]=sum[c]+get[1](c)
end
end
progress[__instance+1]=(x-__instance)/2
end
sum[0]=sum[0]==0 and 1 or sum[0]
sum[1]=sum[1]==0 and 1 or sum[1]
sum[2]=sum[2]==0 and 1 or sum[2]
for x=__instance,xmax-1,__tmax do
if progress[0]==-1 then break end
for y=0,ymax-1 do
__pp=(x*ymax+y)
for c=0,2 do
set[1](get[1](c)/sum[c],c)
end
end
progress[__instance+1]=(x-__instance)/2+(xmax-1)/2
end
progress[__instance+1]=-1
end
return ops
end)
package.preload['dbgtools']=(function(...)
local dbg={}
if type(__sdl)=="table"then
local t=0
function tic()
t=__sdl.ticks()
end
function toc(m)
if m then
print(m..": "..tostring(__sdl.ticks()-t).."ms")
else
print(tostring(__sdl.ticks()-t).."ms")
end
end
else
function tic()print("SDL library missing")end
toc=tic
end
function dbg.mem(m)
collectgarbage("collect")
if m then
print(string.format(m..": %.1fMB",collectgarbage("count")/1000))
else
print(string.format("%.1fMB",collectgarbage("count")/1000))
end
end
local function size(t)
local c=0
for _,_ in pairs(t)do
c=c+1
end
return c
end
function dbg.see(f)
if type(f)~="table"then print(type(f)..":",f)return end
if size(f)==0 then
print("empty "..tostring(table))
end
for k,v in pairs(f)do
if type(v)=="table"then
print("["..k.."]","table","["..size(v).."]")
elseif type(v)=="function"then
print("["..k.."]","function",debug.getinfo(v)["short_src"])
else
print("["..tostring(k).."]",type(v)..":",v)
end
end
end
function dbg.gc()
collectgarbage("collect")
print("*** COLLECT GARBAGE ***")
end
function dbg.print(m)
print("DEBUG: "..m)
end
function dbg.warn(m)
print(debug.traceback("WARNING: "..m))
end
function dbg.error(m)
error("ERROR: "..m,0)
end
__dbg=dbg
return dbg end)
package.preload['opsCS']=(function(...)
local dbg=require("dbgtools")
local cs={}
local ffi=require("ffi")
local LRGBtoSRGB
local SRGBtoLRGB
do
local GAMMA={}
GAMMA.adobe={0.45,0}
GAMMA.apple={0.56,0}
GAMMA.cie={0.45,0}
GAMMA.srgb={0.42,0.055}
GAMMA.hdtv={0.45,0.099}
GAMMA.wide={0.45}
local Rec709=false
local a=Rec709 and 0.099 or 0.055
local G=Rec709 and 1/0.45 or 1/0.42
local a_1=1/(1+a)
local G_1=1/G
local f=((1+a)^G*(G-1)^(G-1))/(a^(G-1)*G^G)
local k=a/(G-1)
local k_f=k/f
local f_1=1/f
local function _LRGBtoSRGB(i)
return i<=k_f and i*f or(a+1)*i^G_1-a
end
local function _SRGBtoLRGB(i)
return i<=k and i*f_1 or((i+a)*a_1)^G
end
function SRGBtoLRGB(i1,i2,i3)
return _SRGBtoLRGB(i1),_SRGBtoLRGB(i2),_SRGBtoLRGB(i3)
end
function LRGBtoSRGB(i1,i2,i3)
return _LRGBtoSRGB(i1),_LRGBtoSRGB(i2),_LRGBtoSRGB(i3)
end
end
local SRGBtoHSV
local HSVtoSRGB
local SRGBtoHSL
local HSLtoSRGB
local SRGBtoHSI
do
local max=math.max
local min=math.min
local function luma(r,g,b)return 0.2126*i1+0.7152*i2+0.0722*i3 end
local function chroma(c1,c2,c3)return max(c1,c2,c3)-min(c1,c2,c3)end
local function value(c1,c2,c3)return max(c1,c2,c3)end
local function lightness(c1,c2,c3)return(max(c1,c2,c3)+min(c1,c2,c3))/2 end
local function intensity(r,g,b)return(r+g+b)/3 end
local function satV(c1,c2,c3)return chroma(c1,c2,c3)/value(c1,c2,c3)end
local function satL(c1,c2,c3)return chroma(c1,c2,c3)/(1-math.abs(2*lightness(c1,c2,c3)-1))end
local function satI(c1,c2,c3)return 1-min(c1,c2,c3)/intensity(c1,c2,c3)end
local function hue(r,g,b)
local c=chroma(r,g,b)
if c==0 then return 0 end
local hue
local m=max(r,g,b)
if m==r then hue=((g-b)/c)end
if m==g then hue=(2+(b-r)/c)end
if m==b then hue=(4+(r-g)/c)end
return hue<0 and hue/6+1 or hue/6
end
local ones={{1,0,0},{1,1,0},{0,1,0},{0,1,1},{0,0,1},{1,0,1}}
local exes={{0,1,0},{-1,0,0},{0,0,1},{0,-1,0},{1,0,0},{0,0,-1}}
function HtoRGB(h)
h=h*6
local n=math.floor(h)
local x=h-n
n=n+1
if n==7 then n=1 x=0 end
return ones[n][1]+exes[n][1]*x,ones[n][2]+exes[n][2]*x,ones[n][3]+exes[n][3]*x
end
function SRGBtoHSV(c1,c2,c3)return hue(c1,c2,c3),satV(c1,c2,c3),value(c1,c2,c3)end
function SRGBtoHSL(c1,c2,c3)return hue(c1,c2,c3),satL(c1,c2,c3),lightness(c1,c2,c3)end
function SRGBtoHSI(c1,c2,c3)return hue(c1,c2,c3),satI(c1,c2,c3),intensity(c1,c2,c3)end
function HSVtoSRGB(i1,i2,i3)
local o1,o2,o3=HtoRGB(i1)
local c=i3*i2
return(o1-1)*c+i3,(o2-1)*c+i3,(o3-1)*c+i3
end
function HSLtoSRGB(i1,i2,i3)
local o1,o2,o3=HtoRGB(i1)
local c=(1-math.abs(2*i3-1))*i2
return(o1-0.5)*c+i3,(o2-0.5)*c+i3,(o3-0.5)*c+i3
end
end
local WP={
A={0.44757/0.40744,1,0.14499/0.40744},
B={0.34840/0.35160,1,0.30000/0.35160},
C={0.31006/0.31615,1,0.37379/0.31615},
D50={0.34567/0.35850,1,0.29583/0.35850},
D55={0.33242/0.34743,1,0.32015/0.34743},
D65={0.312727/0.329024,1,0.358250/0.329024},
D75={0.29902/0.31485,1,0.38613/0.31485},
D93={0.28480/0.29320,1,0.42200/0.29320},
E={1,1,1},
F1={0.31310/0.33727,1,0.34963/0.33727},
F2={0.37208/0.37529,1,0.25263/0.37529},
F3={0.40910/0.39430,1,0.19660/0.39430},
F4={0.44018/0.40329,1,0.15653/0.40329},
F5={0.31379/0.34531,1,0.34090/0.34531},
F6={0.37790/0.38835,1,0.23375/0.38835},
F7={0.31292/0.32933,1,0.35775/0.32933},
F8={0.34588/0.35875,1,0.29537/0.35875},
F9={0.37417/0.37281,1,0.25302/0.37281},
F10={0.34609/0.35986,1,0.29405/0.35986},
F11={0.38052/0.37713,1,0.24235/0.37713},
F12={0.43695/0.40441,1,0.15864/0.40441},
}
local wp=WP.D65
local RGB={}
RGB.srgb={0.64,0.33,0.03,0.30,0.60,0.10,0.15,0.06,0.79,wp=WP.D65}
RGB.apple={0.625,0.34,0.035,0.28,0.595,0.125,0.155,0.07,0.775,wp=WP.D65}
RGB.adobe={0.64,0.33,0.03,0.21,0.71,0.08,0.15,0.06,0.79,wp=WP.D65}
RGB.cie={0.7347,0.2653,0,0.2738,0.7174,0.0088,0.1666,0.0089,0.8245,wp=WP.E}
RGB.wide={0.735,0.265,0,0.115,0.826,0.059,0.157,0.018,0.825,wp=WP.D50}
RGB.prophoto={0.7347,0.2653,0,0.1596,0.8404,0,0.0366,0.0001,0.9633,wp=WP.D50}
do
local function det2(a,b,c,d)return a*d-b*c end
local function det3(a1,a2,a3,b1,b2,b3,c1,c2,c3)
return a1*b2*c3-a1*b3*c2-a2*b1*c3+a2*b3*c1+a3*b1*c2-a3*b2*c1
end
local function adj(a1,a2,a3,b1,b2,b3,c1,c2,c3)
local o={0,0,0,0,0,0,0,0,0}
o[1]=det2(b2,b3,c2,c3)
o[2]=det2(a3,a2,c3,c2)
o[3]=det2(a2,a3,b2,b3)
o[4]=det2(b3,b1,c3,c1)
o[5]=det2(a1,a3,c1,c3)
o[6]=det2(a3,a1,b3,b1)
o[7]=det2(b1,b2,c1,c2)
o[8]=det2(a2,a1,c2,c1)
o[9]=det2(a1,a2,b1,b2)
return o
end
local function inv(M)
local o=adj(unpack(M))
local f=1/det3(unpack(M))
for i=1,9 do
o[i]=o[i]*f
end
return o
end
local function mult(M,V)
return{
M[1]*V[1]+M[2]*V[2]+M[3]*V[3],
M[4]*V[1]+M[5]*V[2]+M[6]*V[3],
M[7]*V[1]+M[8]*V[2]+M[9]*V[3],
}
end
local function div(M,N)
local o={}
for k,v in ipairs(M)do
o[k]=v/N
end
return o
end
local function T(M)
return{M[1],M[4],M[7],
M[2],M[5],M[8],
M[3],M[6],M[9],
}
end
local function matMult(M,N)
return{
M[1]*N[1]+M[2]*N[4]+M[3]*N[7],
M[1]*N[2]+M[2]*N[5]+M[3]*N[8],
M[1]*N[3]+M[2]*N[6]+M[3]*N[9],
M[4]*N[1]+M[5]*N[4]+M[6]*N[7],
M[4]*N[2]+M[5]*N[5]+M[6]*N[8],
M[4]*N[3]+M[5]*N[6]+M[6]*N[9],
M[7]*N[1]+M[8]*N[4]+M[9]*N[7],
M[7]*N[2]+M[8]*N[5]+M[9]*N[8],
M[7]*N[3]+M[8]*N[6]+M[9]*N[9],
}
end
local function diagMult(M,V)
return{
M[1]*V[1],M[2]*V[2],M[3]*V[3],
M[4]*V[1],M[5]*V[2],M[6]*V[3],
M[7]*V[1],M[8]*V[2],M[9]*V[3],
}
end
local norm=1/(wp[1]+wp[2]+wp[3])
local W={wp[1]*norm,wp[2]*norm,wp[3]*norm}
local P=RGB.srgb
P=T(P)
local U=mult(inv(P),W)
local D=div(U,W[2])
C=diagMult(P,D)
CI=inv(C)
mat={}
mat.mult=mult
mat.matMult=matMult
mat.diagMult=diagMult
mat.div=div
mat.T=T
mat.inv=inv
end
local LRGBtoXYZ
local XYZtoLRGB
do
function LRGBtoXYZ(r,g,b)
return C[1]*r+C[2]*g+C[3]*b,
C[4]*r+C[5]*g+C[6]*b,
C[7]*r+C[8]*g+C[9]*b
end
function XYZtoLRGB(x,y,z)
return CI[1]*x+CI[2]*y+CI[3]*z,
CI[4]*x+CI[5]*y+CI[6]*z,
CI[7]*x+CI[8]*y+CI[9]*z
end
end
RAW={}
RAW["OLYMPUS E-620"]=
{8453,-2198,-1092,-7609,15681,2008,-1725,2337,7824,b=0,w=0xfaf}
do
local xe=0.3366
local ye=0.1735
local A0=-949.86315
local A1=6253.80338
local t1=0.92159
local A2=28.70599
local t2=0.20039
local A3=0.00004
local t3=0.07125
function CCT(x,y)
local n=(x-xe)/(y-ye)
return A0+A1*math.exp(-n/t1)+A2*math.exp(-n/t2)+A3*math.exp(-n/t3)
end
end
do
local a,b,c,d,e,f,g,h
a={-0.2661239e9,-3.0258469e9}
b={-0.2343580e6,2.1070379e6}
c={0.8776956e3,0.2226347e3}
d={0.179910,0.240390}
e={-1.1063814,-0.9549476,3.0817580}
f={-1.34811020,-1.37418593,-5.87338670}
g={2.18555832,2.09137015,3.75112997}
h={-0.20219683,-0.16748867,-0.37001483}
function TtoXY(T)
local xt,yt,i
i=T<=4000 and 1 or 2
xt=a[i]/T^3+b[i]/T^2+c[i]/T+d[i]
i=T<=2222 and 1 or T<=4000 and 2 or 3
yt=e[i]*xt^3+f[i]*xt^2+g[i]*xt+h[i]
return xt,yt
end
function tanTtoXY(T)
local dxdt,dydx,xt,i
i=T<=4000 and 1 or 2
xt=a[i]/T^3+b[i]/T^2+c[i]/T+d[i]
dxdt=-c[i]/T^2-2*b[i]/T^3-3*a[i]/T^4
i=T<=2222 and 1 or T<=4000 and 2 or 3
dydx=3*e[i]*xt^2+2*f[i]*xt+g[i]
return dxdt,dydx*dxdt
end
function norTtoXY(T)
local xp,yp=tanTtoXY(T)
return yp,-xp
end
function TtoM(T)return 1000000/T end
function MtoT(M)return 1000000/M end
function dMatT(M,T)return MtoT(TtoM(T)+M)end
function dTdMatT(T)return(MtoT(TtoM(T)+0.5)-MtoT(TtoM(T)-0.5))end
end
do
local a,b,c,d,e,f,g
a={0.145986,0.244063,0.237040}
b={1.17444e3,0.09911e3,0.24748e3}
c={-0.98598e6,2.9678e6,1.9018e6}
d={0.27475e9,-4.6070e9,-2.0064e9}
e=-3.000
f=2.870
g=-0.275
function TtoXY_D(T)
local xd,yd
i=t<=4000 and 1 or T<=7000 and 2 or 3
xd=a[i]+b[i]/T+c[i]/T^2+d[i]/T^3
yd=e*xd^2+f*xd+g
return xd,yd
end
end
function XYtoT(x,y)
local xe=0.3320
local ye=0.1858
local n=(x-xe)/(y-ye)
return-449*n^3+3525*n^2-6823.3*n+5520.33
end
function XYtoXYZ(x,y)
local X,Z
X=x*(1/y)
Z=(1-x-y)*(1/y)
return X,1,Z
end
function XYZtoXY(X,Y,Z)
local x,y
x=X/(X+Y+Z)
y=Y/(X+Y+Z)
return x,y
end
local CAT={}
CAT.xyz={1,0,0,0,1,0,0,0,1}
CAT.vonkries={0.3897,0.6890,-0.0787,-0.2298,1.1834,0.0464,0.0000,0.0000,1.0000}
CAT.bradford={0.8951,0.2664,-0.1614,-0.7502,1.7135,0.0367,0.0389,-0.0685,1.0296}
CAT.cat97=CAT.bradford
CAT.cat97s={0.8562,0.3372,-0.1934,-0.8361,1.8327,0.0033,0.0357,-0.0469,1.0112}
CAT.cat2000={0.7982,0.3389,-0.1371,-0.5918,1.5512,0.0406,0.0008,0.2390,0.9753}
CAT.cat02={0.7328,0.4296,-0.1624,-0.7036,1.6975,0.0061,0.0030,0.0136,0.9834}
CAT.sharp={1.2694,-0.0988,-0.1706,-0.8364,1.8006,0.0357,0.0297,-0.0315,1.0018}
CAT.rlab={0.4002,0.7076,-0.0808,-0.2263,1.1653,0.0457,0.0000,0.0000,0.9182}
CAT.bs={0.8752,0.2787,-0.1539,-0.8904,1.8709,0.0195,-0.0061,0.0162,0.9899}
CAT.bs_pc={0.6489,0.3915,-0.0404,-0.3775,1.3055,0.0720,-0.0271,0.0888,0.9383}
local cat=CAT.bradford
local catInv=mat.inv(cat)
function vonKriesTransform(source,dest)
if type(source)=="string"then source=WP[source]end
if type(dest)=="string"then dest=WP[dest]end
source=mat.mult(cat,source)
dest=mat.mult(cat,dest)
local sd={dest[1]/source[1],dest[2]/source[2],dest[3]/source[3]}
return mat.matMult(mat.diagMult(catInv,sd),cat)
end
local XYZtoLAB
do
local c1=(6/29)^3
local c2=((29/6)^2)/3
local c3=4/29
function XYZtoLAB(x,y,z)
local x=x/wp[1]
local y=y/wp[2]
local z=z/wp[3]
x=x>c1 and x^(1/3)or c2*x+c3
y=y>c1 and y^(1/3)or c2*y+c3
z=z>c1 and z^(1/3)or c2*z+c3
local l,a,b=116*y-16,500*(x-y),200*(y-z)
return l/100,a/128,b/128
end
end
local LABtoXYZ
do
local c1=6/29
local c2=4/29
local c3=3*(6/29)^2
function LABtoXYZ(l,a,b)
l,a,b=l*100,a*128,b*128
local y=(l+16)/116
local x=a/500+y
local z=y-b/200
x=x>c1 and x^3 or(x-c2)*c3
y=y>c1 and y^3 or(y-c2)*c3
z=z>c1 and z^3 or(z-c2)*c3
return x*wp[1],y*wp[2],z*wp[3]
end
end
local XYZtoLUV
local LUVtoXYZ
do
local xr=wp[1]
local yr=wp[2]
local zr=wp[3]
local e=(6/29)^3
local k=(29/3)^3
local k_1=1/k
local un=(4*xr)/(xr+15*yr+3*zr)
local vn=(9*yr)/(xr+15*yr+3*zr)
function XYZtoLUV(x,y,z)
local l,u,v
local up=(4*x)/(x+15*y+3*z)
local vp=(9*y)/(x+15*y+3*z)
l=y>e and y^(1/3)*116-16 or y*k
u=13*l*(up-un)
v=13*l*(vp-vn)
return l/100,u/128,v/128
end
function LUVtoXYZ(l,u,v)
local x,y,z
l,u,v=l*100,u*128,v*128
y=l>8 and((l+16)/116)^3 or l*k_1
local up=u/(13*l)+un
local vp=v/(13*l)+vn
x=y*up*9/(4*vp)
z=y*(12-3*up-20*vp)/(4*vp)
return x,y,z
end
end
local pi=math.pi
local pi_1=1/math.pi
local function LXXtoLCH(l,x,y)
local c,h
c=math.sqrt(x^2+y^2)
h=math.atan2(y,x)
return l,c,(h*pi_1+1)/2
end
local function LCHtoLXX(l,c,h)
local x,y
h=(h*2-1)*pi
x=c*math.cos(h)
y=c*math.sin(h)
return l,x,y
end
function cs.constructor(fun)
return function()
for x=__instance,xmax-1,__tmax do
if progress[0]==-1 then break end
for y=0,ymax-1 do
__pp=(x*ymax+y)
set3[1](fun(get3[1]()))
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
end
local function SRGBtoXYZ(c1,c2,c3)return LRGBtoXYZ(SRGBtoLRGB(c1,c2,c3))end
local function LRGBtoHSV(c1,c2,c3)return SRGBtoHSV(LRGBtoSRGB(c1,c2,c3))end
local function LRGBtoHSL(c1,c2,c3)return SRGBtoHSL(LRGBtoSRGB(c1,c2,c3))end
local function XYZtoSRGB(c1,c2,c3)return LRGBtoSRGB(XYZtoLRGB(c1,c2,c3))end
local function XYZtoHSV(c1,c2,c3)return SRGBtoHSV(LRGBtoSRGB(XYZtoLRGB(c1,c2,c3)))end
local function XYZtoHSL(c1,c2,c3)return SRGBtoHSL(LRGBtoSRGB(XYZtoLRGB(c1,c2,c3)))end
local function HSVtoLRGB(c1,c2,c3)return SRGBtoLRGB(HSVtoSRGB(c1,c2,c3))end
local function HSVtoXYZ(c1,c2,c3)return LRGBtoXYZ(SRGBtoLRGB(HSVtoSRGB(c1,c2,c3)))end
local function HSVtoHSL(c1,c2,c3)return SRGBtoHSL(HSVtoSRGB(c1,c2,c3))end
local function HSLtoLRGB(c1,c2,c3)return SRGBtoLRGB(HSLtoSRGB(c1,c2,c3))end
local function HSLtoXYZ(c1,c2,c3)return LRGBtoXYZ(SRGBtoLRGB(HSLtoSRGB(c1,c2,c3)))end
local function HSLtoHSV(c1,c2,c3)return SRGBtoHSV(HSLtoSRGB(c1,c2,c3))end
local function LCHABtoLAB(c1,c2,c3)return LCHtoLXX(c1,c2,c3)end
local function LABtoLCHAB(c1,c2,c3)return LXXtoLCH(c1,c2,c3)end
local function LCHUVtoLUV(c1,c2,c3)return LCHtoLXX(c1,c2,c3)end
local function LUVtoLCHUV(c1,c2,c3)return LXXtoLCH(c1,c2,c3)end
local function LCHABtoXYZ(c1,c2,c3)return LABtoXYZ(LCHtoLXX(c1,c2,c3))end
local function XYZtoLCHAB(c1,c2,c3)return LXXtoLCH(XYZtoLAB(c1,c2,c3))end
local function LCHUVtoXYZ(c1,c2,c3)return LUVtoXYZ(LCHtoLXX(c1,c2,c3))end
local function XYZtoLCHUV(c1,c2,c3)return LXXtoLCH(XYZtoLUV(c1,c2,c3))end
local function LRGBtoLUV(c1,c2,c3)return XYZtoLUV(LRGBtoXYZ(c1,c2,c3))end
local function LUVtoLRGB(c1,c2,c3)return XYZtoLRGB(LUVtoXYZ(c1,c2,c3))end
local function LRGBtoLCHUV(c1,c2,c3)return XYZtoLCHUV(LRGBtoXYZ(c1,c2,c3))end
local function LCHUVtoLRGB(c1,c2,c3)return XYZtoLRGB(LCHUVtoXYZ(c1,c2,c3))end
local function SRGBtoLUV(c1,c2,c3)return XYZtoLUV(SRGBtoXYZ(c1,c2,c3))end
local function LUVtoSRGB(c1,c2,c3)return XYZtoSRGB(LUVtoXYZ(c1,c2,c3))end
local function SRGBtoLCHUV(c1,c2,c3)return XYZtoLCHUV(SRGBtoXYZ(c1,c2,c3))end
local function LCHUVtoSRGB(c1,c2,c3)return XYZtoSRGB(LCHUVtoXYZ(c1,c2,c3))end
local function HSVtoLUV(c1,c2,c3)return XYZtoLUV(HSVtoXYZ(c1,c2,c3))end
local function LUVtoHSV(c1,c2,c3)return XYZtoHSV(LUVtoXYZ(c1,c2,c3))end
local function HSVtoLCHUV(c1,c2,c3)return XYZtoLCHUV(HSVtoXYZ(c1,c2,c3))end
local function LCHUVtoHSV(c1,c2,c3)return XYZtoHSV(LCHUVtoXYZ(c1,c2,c3))end
local function HSLtoLUV(c1,c2,c3)return XYZtoLUV(HSLtoXYZ(c1,c2,c3))end
local function LUVtoHSL(c1,c2,c3)return XYZtoHSL(LUVtoXYZ(c1,c2,c3))end
local function HSLtoLCHUV(c1,c2,c3)return XYZtoLCHUV(HSLtoXYZ(c1,c2,c3))end
local function LCHUVtoHSL(c1,c2,c3)return XYZtoHSL(LCHUVtoXYZ(c1,c2,c3))end
local function LRGBtoLAB(c1,c2,c3)return XYZtoLAB(LRGBtoXYZ(c1,c2,c3))end
local function LABtoLRGB(c1,c2,c3)return XYZtoLRGB(LABtoXYZ(c1,c2,c3))end
local function LRGBtoLCHAB(c1,c2,c3)return XYZtoLCHAB(LRGBtoXYZ(c1,c2,c3))end
local function LCHABtoLRGB(c1,c2,c3)return XYZtoLRGB(LCHABtoXYZ(c1,c2,c3))end
local function SRGBtoLAB(c1,c2,c3)return XYZtoLAB(SRGBtoXYZ(c1,c2,c3))end
local function LABtoSRGB(c1,c2,c3)return XYZtoSRGB(LABtoXYZ(c1,c2,c3))end
local function SRGBtoLCHAB(c1,c2,c3)return XYZtoLCHAB(SRGBtoXYZ(c1,c2,c3))end
function LCHABtoSRGB(c1,c2,c3)return XYZtoSRGB(LCHABtoXYZ(c1,c2,c3))end
local function HSVtoLAB(c1,c2,c3)return XYZtoLAB(HSVtoXYZ(c1,c2,c3))end
local function LABtoHSV(c1,c2,c3)return XYZtoHSV(LABtoXYZ(c1,c2,c3))end
local function HSVtoLCHAB(c1,c2,c3)return XYZtoLCHAB(HSVtoXYZ(c1,c2,c3))end
local function LCHABtoHSV(c1,c2,c3)return XYZtoHSV(LCHABtoXYZ(c1,c2,c3))end
local function HSLtoLAB(c1,c2,c3)return XYZtoLAB(HSLtoXYZ(c1,c2,c3))end
local function LABtoHSL(c1,c2,c3)return XYZtoHSL(LABtoXYZ(c1,c2,c3))end
local function HSLtoLCHAB(c1,c2,c3)return XYZtoLCHAB(HSLtoXYZ(c1,c2,c3))end
local function LCHABtoHSL(c1,c2,c3)return XYZtoHSL(LCHABtoXYZ(c1,c2,c3))end
local function LUVtoLAB(c1,c2,c3)return XYZtoLAB(LUVtoXYZ(c1,c2,c3))end
local function LABtoLUV(c1,c2,c3)return XYZtoLUV(LABtoXYZ(c1,c2,c3))end
local function LUVtoLCHAB(c1,c2,c3)return XYZtoLCHAB(LUVtoXYZ(c1,c2,c3))end
local function LCHABtoLUV(c1,c2,c3)return XYZtoLUV(LCHABtoXYZ(c1,c2,c3))end
local function LCHUVtoLAB(c1,c2,c3)return XYZtoLAB(LCHUVtoXYZ(c1,c2,c3))end
local function LABtoLCHUV(c1,c2,c3)return XYZtoLCHUV(LABtoXYZ(c1,c2,c3))end
local function LCHUVtoLCHAB(c1,c2,c3)return XYZtoLCHAB(LCHUVtoXYZ(c1,c2,c3))end
local function LCHABtoLCHUV(c1,c2,c3)return XYZtoLCHUV(LCHABtoXYZ(c1,c2,c3))end
cs.HSV={}
cs.HSL={}
cs.SRGB={}
cs.LRGB={}
cs.XYZ={}
cs.LAB={}
cs.LUV={}
cs.LCHAB={}
cs.LCHUV={}
cs.LRGB.SRGB=cs.constructor(LRGBtoSRGB)
cs.LRGB.HSV=cs.constructor(LRGBtoHSV)
cs.LRGB.HSL=cs.constructor(LRGBtoHSL)
cs.LRGB.XYZ=cs.constructor(LRGBtoXYZ)
cs.LRGB.LAB=cs.constructor(LRGBtoLAB)
cs.LRGB.LUV=cs.constructor(LRGBtoLUV)
cs.LRGB.LCHAB=cs.constructor(LRGBtoLCHAB)
cs.LRGB.LCHUV=cs.constructor(LRGBtoLCHUV)
cs.SRGB.LRGB=cs.constructor(SRGBtoLRGB)
cs.SRGB.HSV=cs.constructor(SRGBtoHSV)
cs.SRGB.HSL=cs.constructor(SRGBtoHSL)
cs.SRGB.XYZ=cs.constructor(SRGBtoXYZ)
cs.SRGB.LAB=cs.constructor(SRGBtoLAB)
cs.SRGB.LUV=cs.constructor(SRGBtoLUV)
cs.SRGB.LCHAB=cs.constructor(SRGBtoLCHAB)
cs.SRGB.LCHUV=cs.constructor(SRGBtoLCHUV)
cs.HSV.LRGB=cs.constructor(HSVtoLRGB)
cs.HSV.SRGB=cs.constructor(HSVtoSRGB)
cs.HSV.HSL=cs.constructor(HSVtoHSL)
cs.HSV.XYZ=cs.constructor(HSVtoXYZ)
cs.HSV.LAB=cs.constructor(HSVtoLAB)
cs.HSV.LUV=cs.constructor(HSVtoLUV)
cs.HSV.LCHAB=cs.constructor(HSVtoLCHAB)
cs.HSV.LCHUV=cs.constructor(HSVtoLCHUV)
cs.HSL.LRGB=cs.constructor(HSLtoLRGB)
cs.HSL.SRGB=cs.constructor(HSLtoSRGB)
cs.HSL.HSV=cs.constructor(HSLtoHSV)
cs.HSL.XYZ=cs.constructor(HSLtoXYZ)
cs.HSL.LAB=cs.constructor(HSLtoLAB)
cs.HSL.LUV=cs.constructor(HSLtoLUV)
cs.HSL.LCHAB=cs.constructor(HSLtoLCHAB)
cs.HSL.LCHUV=cs.constructor(HSLtoLCHUV)
cs.XYZ.LRGB=cs.constructor(XYZtoLRGB)
cs.XYZ.SRGB=cs.constructor(XYZtoSRGB)
cs.XYZ.HSV=cs.constructor(XYZtoHSV)
cs.XYZ.HSL=cs.constructor(XYZtoHSL)
cs.XYZ.LAB=cs.constructor(XYZtoLAB)
cs.XYZ.LUV=cs.constructor(XYZtoLUV)
cs.XYZ.LCHAB=cs.constructor(XYZtoLCHAB)
cs.XYZ.LCHUV=cs.constructor(XYZtoLCHUV)
cs.LAB.LRGB=cs.constructor(LABtoLRGB)
cs.LAB.SRGB=cs.constructor(LABtoSRGB)
cs.LAB.HSV=cs.constructor(LABtoHSV)
cs.LAB.HSL=cs.constructor(LABtoHSL)
cs.LAB.XYZ=cs.constructor(LABtoXYZ)
cs.LAB.LUV=cs.constructor(LABtoLUV)
cs.LAB.LCHAB=cs.constructor(LABtoLCHAB)
cs.LAB.LCHUV=cs.constructor(LABtoLCHUV)
cs.LUV.LRGB=cs.constructor(LUVtoLRGB)
cs.LUV.SRGB=cs.constructor(LUVtoSRGB)
cs.LUV.HSV=cs.constructor(LUVtoHSV)
cs.LUV.HSL=cs.constructor(LUVtoHSL)
cs.LUV.XYZ=cs.constructor(LUVtoXYZ)
cs.LUV.LAB=cs.constructor(LUVtoLAB)
cs.LUV.LCHAB=cs.constructor(LUVtoLCHAB)
cs.LUV.LCHUV=cs.constructor(LUVtoLCHUV)
cs.LCHAB.LRGB=cs.constructor(LCHABtoLRGB)
cs.LCHAB.SRGB=cs.constructor(LCHABtoSRGB)
cs.LCHAB.HSV=cs.constructor(LCHABtoHSV)
cs.LCHAB.HSL=cs.constructor(LCHABtoHSL)
cs.LCHAB.XYZ=cs.constructor(LCHABtoXYZ)
cs.LCHAB.LAB=cs.constructor(LCHABtoLAB)
cs.LCHAB.LUV=cs.constructor(LCHABtoLUV)
cs.LCHAB.LCHUV=cs.constructor(LCHABtoLCHUV)
cs.LCHUV.LRGB=cs.constructor(LCHUVtoLRGB)
cs.LCHUV.SRGB=cs.constructor(LCHUVtoSRGB)
cs.LCHUV.HSV=cs.constructor(LCHUVtoHSV)
cs.LCHUV.HSL=cs.constructor(LCHUVtoHSL)
cs.LCHUV.XYZ=cs.constructor(LCHUVtoXYZ)
cs.LCHUV.LAB=cs.constructor(LCHUVtoLAB)
cs.LCHUV.LUV=cs.constructor(LCHUVtoLUV)
cs.LCHUV.LCHAB=cs.constructor(LCHUVtoLCHAB)
return cs
end)
package.preload['opsFFT']=(function(...)
local fftops={}
local fft=require("fftw")
local ffi=require("ffi")
local function loadlib(lib)
local path="./lib/"..ffi.os.."_"..ffi.arch.."/"
local libname
if ffi.os=="Linux"then libname="lib"..lib..".so"end
if ffi.os=="Windows"then libname=lib..".dll"end
local t
local p
p,t=pcall(ffi.load,lib)
if not p then
print("no native library found, trying user library "..lib)
p,t=pcall(ffi.load,"./lib/usr/"..libname)
end
if not p then
print("no user library found, trying supplied library "..lib)
p,t=pcall(ffi.load,path..libname)
end
if p then
return t
else
print("failed loading "..lib)
return false
end
end
local SDL=loadlib("SDL")
ffi.cdef[[
struct SDL_mutex;
typedef struct SDL_mutex SDL_mutex;
extern int SDL_mutexP(SDL_mutex *mutex);
extern int SDL_mutexV(SDL_mutex *mutex);
]]
local function mutexLock()return SDL.SDL_mutexP(__mut)end
local function mutexUnlock()return SDL.SDL_mutexV(__mut)end
do
local size=0
local norm
local init=false
local iR,iG,iB
local oR,oG,oB
local plan
local flag_old=nil
local function fftSetup(flag)
mutexLock()
if init then
fft.destroyBuffer(iR)
fft.destroyBuffer(iG)
fft.destroyBuffer(iB)
fft.destroyBuffer(oR)
fft.destroyBuffer(oG)
fft.destroyBuffer(oB)
fft.destroyPlan(plan)
else
init=true
end
iR=fft.createBuffer(size)
iG=fft.createBuffer(size)
iB=fft.createBuffer(size)
oR=fft.createBuffer(size)
oG=fft.createBuffer(size)
oB=fft.createBuffer(size)
mutexUnlock()
end
local function ffty(flag)
if size~=ymax then
size=ymax
norm=1/math.sqrt(size)
fftSetup(flag)
mutexLock()
plan=fft.createPlan(size,iR,oR,flag,false,fft.PLAN[2])
mutexUnlock()
end
for x=__instance,xmax-1,__tmax do
if progress[0]==-1 then break end
for y=0,ymax-1 do
__pp=(x*ymax+y)
iR[y][0],iG[y][0],iB[y][0]=get3[1]()
iR[y][1],iG[y][1],iB[y][1]=get3[2]()
end
fft.fftw.fftw_execute_dft(plan,iR,oR)
fft.fftw.fftw_execute_dft(plan,iG,oG)
fft.fftw.fftw_execute_dft(plan,iB,oB)
for y=0,ymax-1 do
__pp=(x*ymax+y)
set3[1](oR[y][0]*norm,oG[y][0]*norm,oB[y][0]*norm)
set3[2](oR[y][1]*norm,oG[y][1]*norm,oB[y][1]*norm)
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
local function fftx(flag)
if size~=xmax then
size=xmax
norm=1/math.sqrt(size)
fftSetup(flag)
mutexLock()
plan=fft.createPlan(size,iR,oR,flag,false,fft.PLAN[2])
mutexUnlock()
end
for y=__instance,ymax-1,__tmax do
if progress[0]==-1 then break end
for x=0,xmax-1 do
__pp=(x*ymax+y)
iR[x][0],iG[x][0],iB[x][0]=get3[1]()
iR[x][1],iG[x][1],iB[x][1]=get3[2]()
end
fft.fftw.fftw_execute_dft(plan,iR,oR)
fft.fftw.fftw_execute_dft(plan,iG,oG)
fft.fftw.fftw_execute_dft(plan,iB,oB)
for x=0,xmax-1 do
__pp=(x*ymax+y)
set3[1](oR[x][0]*norm,oG[x][0]*norm,oB[x][0]*norm)
set3[2](oR[x][1]*norm,oG[x][1]*norm,oB[x][1]*norm)
end
progress[__instance+1]=y-__instance
end
progress[__instance+1]=-1
end
function fftops.fftx()return fftx(true)end
function fftops.ffty()return ffty(true)end
function fftops.ifftx()return fftx(false)end
function fftops.iffty()return ffty(false)end
end
return fftops end)
package.preload['opsTransform']=(function(...)
local transform={}
require("mathtools")
local pi=math.pi
local cos,sin=math.cos,math.sin
local floor=math.floor
local function rad2deg(a)return a/pi*180 end
local function deg2rad(a)return a*pi/180 end
local function rot(x,y,a,ox,oy,sx,sy)
sx=sx or 1
sy=sy or 1
ox,oy=ox or 0,oy or 0
x,y=x-ox,y-oy
x,y=x/sx,y/sy
a=deg2rad(a)
return
x*cos(a)-y*sin(a)+ox,
x*sin(a)+y*cos(a)+oy
end
function transform.rotFast()
local xm,ym=xmax/2-1,ymax/2-1
for x=__instance,xmax-1,__tmax do
if progress[0]==-1 then break end
for y=0,ymax-1 do
__pp=(x*ymax+y)
for c=0,zmax-1 do
local xr,yr=rot(x,y,params[1],xm,ym)
local xf,yf=xr%1,yr%1
xr,yr=floor(xr),floor(yr)
if xr>=0 and xr<=xmax-1 and yr>=0 and yr<=ymax-1 then
local bo=((xr>=xmax-1 or yr>=ymax-1)and 0 or xf*yf*getxy[1](xr+1,yr+1,c))+
((xr<=0 or yr>=ymax-1)and 0 or(1-xf)*yf*getxy[1](xr,yr+1,c))+
((xr>=xmax-1 or yr<=0)and 0 or xf*(1-yf)*getxy[1](xr+1,yr,c))+
((xr<=0 or yr<=0)and 0 or(1-xf)*(1-yf)*getxy[1](xr,yr,c))
set[1](bo,c)
end
end
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
function transform.rotFilt()
local filt=math.window.cubic
math.window.cubicSet("BSpline")
local filtType=.5
local scale=1
local width=2
local xm,ym=xmax/2,ymax/2
for x=__instance,xmax-1,__tmax do
if progress[0]==-1 then break end
for y=0,ymax-1 do
__pp=(x*ymax+y)
for c=0,zmax-1 do
local xr,yr=rot(x,y,params[1],xm,ym)
local xf,yf=xr%1,yr%1
xr,yr=floor(xr),floor(yr)
if xr>=0 and xr<=xmax-1 and yr>=0 and yr<=ymax-1 then
local bo=0
local sum=0
for x=1-width,width do
for y=1-width,width do
local weight=filt(math.sqrt((x-xf)^2+(y-yf)^2)/scale,filtType)
sum=sum+weight
bo=bo+(((xr+x)>0 and(yr+y)>0 and(xr+x)<=xmax-1 and(yr+y)<=ymax-1)and weight*getxy[1](xr+x,yr+y,c)or 0)
end
end
set[1](bo/sum,c)
end
end
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
function transform.rot2()
local xm,ym=xmax/2,ymax/2
for x=__instance,xmax-1,__tmax do
if progress[0]==-1 then break end
for y=0,ymax-1 do
__pp=(x*ymax+y)
for c=0,2 do
local xr,yr=rot(x,y,get[2](c),xm,ym)
xr,yr=floor(xr),floor(yr)
if xr>=0 and xr<=xmax-1 and yr>=0 and yr<=ymax-1 then
setxy[1](get[1](c),xr,yr,c)
end
end
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
return transform end)
package.preload['opsFilter']=(function(...)
local filter={}
function filter.min()
for x=__instance+1,xmax-2,__tmax do
if progress[0]==-1 then break end
for y=1,ymax-2 do
__pp=(x*ymax+y)
for c=0,2 do
set[1](
math.min(
getxy[1](x-1,y-1,c),getxy[1](x,y-1,c),getxy[1](x+1,y-1,c),
getxy[1](x-1,y,c),getxy[1](x,y,c),getxy[1](x+1,y,c),
getxy[1](x-1,y+1,c),getxy[1](x,y+1,c),getxy[1](x+1,y+1,c)
)
,c)
end
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
function filter.max()
for x=__instance+1,xmax-2,__tmax do
if progress[0]==-1 then break end
for y=1,ymax-2 do
__pp=(x*ymax+y)
for c=0,2 do
set[1](
math.max(
getxy[1](x-1,y-1,c),getxy[1](x,y-1,c),getxy[1](x+1,y-1,c),
getxy[1](x-1,y,c),getxy[1](x,y,c),getxy[1](x+1,y,c),
getxy[1](x-1,y+1,c),getxy[1](x,y+1,c),getxy[1](x+1,y+1,c)
)
,c)
end
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
function filter.median()
for x=__instance+1,xmax-2,__tmax do
if progress[0]==-1 then break end
for y=1,ymax-2 do
__pp=(x*ymax+y)
for c=0,2 do
local v
local t={
getxy[1](x-1,y-1,c),getxy[1](x,y-1,c),getxy[1](x+1,y-1,c),
getxy[1](x-1,y,c),getxy[1](x,y,c),getxy[1](x+1,y,c),
getxy[1](x-1,y+1,c),getxy[1](x,y+1,c),getxy[1](x+1,y+1,c)
}
table.sort(t)
set[1](t[5],c)
end
end
progress[__instance+1]=x-__instance
end
progress[__instance+1]=-1
end
return filter end)
package.preload['mathtools']=(function(...)
local ffi=require("ffi")
ffi.cdef[[
double erf(double i);
]]
local M_1_PI=0.31830988618379067154
local pi=math.pi
local cos=math.cos
local sin=math.sin
local exp=math.exp
local sqrt=math.sqrt
local abs=math.abs
math.func={}
math.window={}
function math.func.erf(i)return ffi.C.erf(i)end
function math.func.gauss(x,s)return exp(-(x)^2/2/s^2)end
function math.func.lorenz(x,s)return s^2/(x^2+s^2)end
function math.func.gausscum(x,s)return 0.5+erf((x)/sqrt(2)/s)/2 end
function math.func.lorenzcum(x,s)return math.atan2(x,s)*M_1_PI+0.5 end
function math.func.sinc(x)return x==0 and 1 or sin(pi*x)/(pi*x)end
function math.func.exp(x,t)return exp(-x/t)end
function math.window.nearest(x)return abs(x)<0.5 and 1 or 0 end
function math.window.linear(x)x=abs(x)return x<=1 and 1-x or 0 end
function math.window.welch(x)return abs(x)<1 and 1-x^2 or 0 end
function math.window.parzen(x)
x=abs(x)
return
x<=1 and(4-6*x^2+3*x^3)/4
or x<=2 and((2-x)^3)/4
or 0
end
function math.window.hann(x,a)
a=a or 0.5
return
abs(x)<=1 and a+(1-a)*cos(pi*x)
or 0
end
do
local t={
hann={1/2,1/2},
hamming={25/46,21/46},
blackman={0.42,0.5,0.08},
blackmanExact={7938/18608,9240/18608,1430/18608},
blackmanHarris3={0.4243801,0.4973406,0.0782793},
blackmanHarris4={0.35875,0.48829,0.14128,0.01168},
blackmanHarris7={0.27105140069342,0.43329793923448,0.21812299954311,0.06592544638803,
0.01081174209837,0.00077658482522,0.00001388721735},
flattop={0.21557895,0.41663158,0.277263158,0.083578947,0.006947368},
blackmanNuttal={0.3635819,0.4891775,0.1365995,0.0106411},
nuttal={0.355768,0.487396,0.144232,0.012604},
kaiser={0.402,0.498,0.098,0.001},
lowSide={0.323215218,0.471492057,0.175534280,0.028497078,0.001261367},
}
local a0,a1,a2,a3,a4,a5,a6,an
function math.window.blackmanSet(b0,b1,b2,b3,b4,b5,b6)
if type(b0)=="string"then
a0,a1,a2,a3,a4,a5,a6=t[b0][1],t[b0][2],t[b0][3],t[b0][4],t[b0][5],t[b0][6],t[b0][7]
elseif b0==nil then
a0,a1,a2,a3,a4,a5,a6=t[blackman][1],t[blackman][2],t[blackman][3],t[blackman][4],t[blackman][5],t[blackman][6],t[blackman][7]
else
a0,a1,a2,a3,a4,a5,a6=b0,b1,b2,b3,b4,b5,b6
end
a2=a2 or 0
a3=a3 or 0
a4=a4 or 0
a5=a5 or 0
a6=a6 or 0
an=a0+a1+a2+a3+a4+a5+a6
end
function math.window.blackman(x)
return
x<=1 and(a0+
(a1~=0 and a1*cos(pi*x)or 0)+
(a2~=0 and a2*cos(2*pi*x)or 0)+
(a3~=0 and a3*cos(3*pi*x)or 0)+
(a4~=0 and a4*cos(4*pi*x)or 0)+
(a5~=0 and a5*cos(5*pi*x)or 0)+
(a6~=0 and a6*cos(6*pi*x)or 0))/an
or 0
end
end
function math.window.bohman(x)
x=abs(x)
return x<=1 and(1-x)*cos(pi*x)+1/pi*sin(pi*x)or 0
end
function math.window.tukey(x,a)
x=abs(x)
return
x<=a and 1
or x<=1 and 0.5+0.5*cos(pi/(1-a)*(x-a))
or 0
end
function math.window.cosPower(x,a)
return
x<=1 and cos(pi*x*0.5)^a
or 0
end
function math.window.cosine(x)return abs(x)<=1 and cos(pi*x/2)end
function math.window.lanczos(x,n)
n=n or 1
return abs(x)<=n and math.func.sinc(x)*math.func.sinc(x/n)or 0
end
do
local t={
BSpline={1,0},
CatmullRom={0,1/2},
MitchellNetravali={1/3,1/3},
Cardinal={0,0},
}
local b,c
function math.window.cubicSet(bn,cn)
if type(bn)=="string"then
b,c=t[bn][1],t[bn][2]
else
b,c=bn,cn
end
end
function math.window.cubic(x)
x=abs(x)
return
x<=1 and((12-9*b-6*c)*x^3+(-18+12*b+6*c)*x^2+6-2*b)/
(6-2*b)
or x<=2 and((-b-6*c)*x^3+(6*b+30*c)*x^2+(-12*b-48*c)*x+8*b+24*c)/
(6-2*b)
or 0
end
end
local function I0(x)
return 1+x^2/4+x^4/64+x^6/2304+x^8/147456+x^10/14745600+
x^12/2123366400+x^14/416179814400+x^16/106542032486400+
x^18/34519618525593600+x^20/13807847410237440000
end
function math.window.kaiser(x,a)
a=a or 3
x=abs(x)
return
x<=1 and I0(pi*a*sqrt(1-x^2))/
I0(pi*a)
or 0
end end)
package.preload['fftw']=(function(...)
local ffi=require("ffi")
local p,fftw=pcall(loadlib,"fftw3")
assert(p,fftw)
ffi.cdef(io.open('FFTW.h','r'):read('*a'))
io.close()
fft={}
fft.fftw=fftw
fft.FORWARD=-1
fft.INVERSE=1
fft.PLAN={[0]=2^6,0,2^5,2^3}
function fft.createPlan(n,p_in,p_out,forward,real,plan)
pln=plan or fft.PLAN[0]
local sign=forward and fft.FORWARD or fft.INVERSE
if real==true then
if sign==fft.FORWARD then
return fftw.fftw_plan_dft_r2c_1d(n,p_in,p_out,plan)
elseif sign==fft.INVERSE then
return fftw.fftw_plan_dft_c2r_1d(n,p_in,p_out,plan)
end
elseif real==false then
return fftw.fftw_plan_dft_1d(n,p_in,p_out,sign,plan)
end
end
function fft.executePlan(plan)
fftw.fftw_execute(plan)
end
function fft.destroyPlan(plan)
fftw.fftw_destroy_plan(plan)
end
function fft.createBuffer(size)
return ffi.cast("fftw_complex*",fftw.fftw_malloc(ffi.sizeof("fftw_complex")*size))
end
function fft.destroyBuffer(buffer)
fftw.fftw_free(buffer)
end
return fft end)
print("Thread setup...")
local ffi=require("ffi")
function loadlib(lib)
local path="./lib/"..ffi.os.."_"..ffi.arch.."/"
local libname
if ffi.os=="Linux"then libname="lib"..lib..".so"end
if ffi.os=="Windows"then libname=lib..".dll"end
local t
local p
p,t=pcall(ffi.load,lib)
if not p then
print("no native library found, trying user library "..lib)
p,t=pcall(ffi.load,"./lib/usr/"..libname)
end
if not p then
print("no user library found, trying supplied library "..lib)
p,t=pcall(ffi.load,path..libname)
end
if p then
return t
else
print("failed loading "..lib)
return false
end
end
ops=require("ops")
progress=nil
function init()
progress=ffi.cast("int*",progress)
collectgarbage("stop")
end
function setup()
__pp=0
get={}
set={}
get3={}
set3={}
getxy={}
setxy={}
get3xy={}
set3xy={}
local bufdata={}
local b=ffi.cast("void**",b)
for i=1,ibuf+obuf do
bufdata[i]=ffi.cast("double*",b[i])
end
b=nil
for i=1,ibuf do
if buftype[i]==1 then get[i]=function()return bufdata[i][0]end
elseif buftype[i]==2 then get[i]=function(c)return bufdata[i][c]end
elseif buftype[i]==3 then get[i]=function()return bufdata[i][__pp]end
elseif buftype[i]==4 then get[i]=function(c)return bufdata[i][__pp*3+c]end
end
if buftype[i]==2 or buftype[i]==4 then
get3[i]=function()return get[i](0),get[i](1),get[i](2)end
else
get3xy[i]=function()local v=get[i]()return v,v,v end
end
end
for i=1,ibuf do
if buftype[i]==1 then getxy[i]=function(x,y)return bufdata[i][0]end
elseif buftype[i]==2 then getxy[i]=function(x,y,c)return bufdata[i][c]end
elseif buftype[i]==3 then getxy[i]=function(x,y)return bufdata[i][(x*ymax+y)]end
elseif buftype[i]==4 then getxy[i]=function(x,y,c)return bufdata[i][(x*ymax+y)*3+c]end
end
if buftype[i]==2 or buftype[i]==4 then
get3xy[i]=function(x,y)return get[i](x,y,0),get[i](x,y,1),get[i](x,y,2)end
else
get3xy[i]=function(x,y)local v=get[i](x,y)return v,v,v end
end
end
for i=1,obuf do
local ii=i+ibuf
if buftype[ii]==1 then set[i]=function(v)bufdata[ii][0]=v end
elseif buftype[ii]==2 then set[i]=function(v,c)bufdata[ii][c]=v end
elseif buftype[ii]==3 then set[i]=function(v)bufdata[ii][__pp]=v end
elseif buftype[ii]==4 then set[i]=function(v,c)bufdata[ii][__pp*3+c]=v end
end
if buftype[ii]==2 or buftype[ii]==4 then
set3[i]=function(c0,c1,c2)set[i](c0,0)set[i](c1,1)set[i](c2,2)end
else
set3[i]=function(c0,c1,c2)set[i]((c0+c1+c2)/3)end
end
end
for i=1,obuf do
local ii=i+ibuf
if buftype[ii]==1 then setxy[i]=function(v,x,y)bufdata[ii][0]=v end
elseif buftype[ii]==2 then setxy[i]=function(v,x,y,c)bufdata[ii][c]=v end
elseif buftype[ii]==3 then setxy[i]=function(v,x,y)bufdata[ii][(x*ymax+y)]=v end
elseif buftype[ii]==4 then setxy[i]=function(v,x,y,c)bufdata[ii][(x*ymax+y)*3+c]=v end
end
if buftype[ii]==2 or buftype[ii]==4 then
set3xy[i]=function(c0,c1,c2,x,y)setxy[i](c0,x,y,0)setxy[i](c1,x,y,1)setxy[i](c2,x,y,2)end
else
set3xy[i]=function(c0,c1,c2,x,y)setxy[i]((c0+c1+c2)/3,x,y)end
end
end
end
