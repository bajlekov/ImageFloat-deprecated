%	Copyright (C) 2011-2014 G. Bajlekov
%
%    ImageFloat is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    ImageFloat is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.


x = 4096;
s = 8192;

a = zeros(1,s); % x
a(x)=1;

ap = zeros(size(a)); % y-
am = zeros(size(a)); % y+
b = zeros(size(a)); % y

sigma = 512

% optimal values obtained from fit
a1 = 1.6806376642357039319364;
a2 = -0.6812660166381832027582;
b1 = 3.7569701140397087080203;
b2 = -0.2652902746940916656193;
w1 = 0.6319997351950183972491/sigma;
w2 = 1.9975150914645314337292/sigma;
l1 = -1.7858991854622259243257/sigma;
l2 = -1.7256466474863954019270/sigma;


cw1 = cos(w1);
cw2 = cos(w2);
sw1 = sin(w1);
sw2 = sin(w2);

n3 = exp(l2+2*l1)*(b2*sw2-a2*cw2) + exp(l1+2*l2)*(b1*sw1-a1*cw1);
n2 = 2*exp(l1+l2)*((a1+a2)*cw2*cw1 - b1*cw2*sw1 - b2*cw1*sw2) + a2*exp(2*l1) + a1*exp(2*l2);
n1 = exp(l2)*(b2*sw2-(a2+2*a1)*cw2) + exp(l1)*(b1*sw1-(a1+2*a2)*cw1);
n0 = a1+a2;
d4 = exp(2*l1+2*l2);
d3 = -2*exp(l1+2*l2)*cw1 - 2*exp(l2+2*l1)*cw2;
d2 = 4*exp(l1+l2)*cw2*cw1 + exp(2*l2) + exp(2*l1);
d1 = -2*exp(l2)*cw2 - 2*exp(l1)*cw1;
m1 = n1 - d1*n0;
m2 = n2 - d2*n0;
m3 = n3 - d3*n0;
m4 =    - d4*n0;

scale = 1/sqrt(2*pi)/sigma;
n0;

for i = 5:s
	ap(i) = n0*a(i) + n1*a(i-1) + n2*a(i-2) + n3*a(i-3) - d1*ap(i-1) - d2*ap(i-2) - d3*ap(i-3) - d4*ap(i-4) ;
end

for i = s-5:-1:1
	am(i) = m1*a(i+1) + m2*a(i+2) + m3*a(i+3) + m4*a(i+4) - d1*am(i+1) - d2*am(i+2) - d3*am(i+3) - d4*am(i+4);
end

b = ap.+am;

close all
plot(b*scale)
hold on
plot(normpdf(1:s,x,sigma), 'r.')
hold off

plot((b*scale-normpdf(1:s,x,sigma)))
sum(b(5:s-5)*scale-normpdf(5:s-5,x,sigma))