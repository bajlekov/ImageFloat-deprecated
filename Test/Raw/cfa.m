%	Copyright (C) 2011-2013 G. Bajlekov
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


% interpolating CFA data
pkg load image

% load CFA data
%I = double(imread("img.pgm"));
%I = I(1101:1900, 1101:1900);

J = double(imread("test.png"));
%J = J(end/2-49:end/2+50, end/2-49:end/2+50, :);

x = size(J, 1);
y = size(J, 2);

r = [0 0; 0 1];
g1 = [0 1; 0 0];
g2 = [0 0; 1 0];
b = [1 0; 0 0];
global R = repmat(r, x/2, y/2)==1;
global G1 = repmat(g1, x/2, y/2)==1;
global G2 = repmat(g2, x/2, y/2)==1;
global B = repmat(b, x/2, y/2)==1;

I = [];
I = R.*J(:,:,1) + (G1+G2).*J(:,:,2) + B.*J(:,:,3);

%I(I>4015) = 4015;
%I = I - 64;
%I(I<0) = 0;

function t = colorScale(o, cam)
  t = o/256;
  %t = [];
  %t(:,:,1) = cam(1,1).*o(:,:,1) + cam(2,1).*o(:,:,2) + cam(3,1).*o(:,:,3);
  %t(:,:,2) = cam(1,2).*o(:,:,1) + cam(2,2).*o(:,:,2) + cam(3,2).*o(:,:,3);
  %t(:,:,3) = cam(1,3).*o(:,:,1) + cam(2,3).*o(:,:,2) + cam(3,3).*o(:,:,3);
  %t = t/min(max(max(t)));
  %t = real(t.^(1/2.25));
end

mult = [1.890625 1.000000 1.343750];
dl = [2.151794 0.940274 1.085084];

% whitebalance applied to raw data before processing!
%wb = 1./[sum(I(R))/sum(R(:)), sum(I(G1))/sum(G1(:)), sum(I(B))/sum(B(:)), sum(I(G2))/sum(G2(:))];
%wb = wb/max(wb);
%I(R)*=wb(1);
%I(G1)*=wb(2);
%I(B)*=wb(3);
%I(G2)*=wb(4);

% matrix from rgb to xyz (standard)
rgb_xyz = [0.412453, 0.357580, 0.180423;
0.212671, 0.715160, 0.072169;
0.019334, 0.119193, 0.950227];

% matrix from xyz to camera, hardcoded, sensor-dependent
cam_xyz = [8453,-2198,-1092; -7609,15681,2008; -1725,2337,7824]/10000;
% constructing cam_rgb:
rgb_cam = (cam_xyz*rgb_xyz)';
%normalise
rgb_cam = rgb_cam./sum(rgb_cam);
%invert
cam_rgb = inverse(rgb_cam);
% matrix from camera to xyz
cam = cam_rgb*rgb_xyz';	% to XYZ
cam = cam_rgb;		% to RGB


% 1 - simple pixel binning:
%o = [];
%o(:,:,1) = reshape(I(R), x/2, y/2);
%o(:,:,2) = reshape(I(G1)+I(G2), x/2, y/2)/2;
%o(:,:,3) = reshape(I(B), x/2, y/2);
%o = colorScale(o, cam);
%imshow(o)

% 2 - bilinear interpolation:
%o = [];
%o(:,:,1) = imfilter(I.*R, [.25, .5, .25; .5, 1, .5; .25, .5, .25]);
%o(:,:,2) = imfilter(I.*(G1+G2), [0, .25, 0; .25, 1, .25; 0, .25, 0]);
%o(:,:,3) = imfilter(I.*B, [.25, .5, .25; .5, 1, .5; .25, .5, .25]);
%o = colorScale(o, cam);
%imwrite(o, "out_BI.png");

% 3 - freeman-filtered bilinear:
%o = [];
%o(:,:,1) = imfilter(I.*R, [.25, .5, .25; .5, 1, .5; .25, .5, .25]);
%o(:,:,2) = imfilter(I.*(G1+G2), [0, .25, 0; .25, 1, .25; 0, .25, 0]);
%o(:,:,3) = imfilter(I.*B, [.25, .5, .25; .5, 1, .5; .25, .5, .25]);
%o(:,:,1) = medfilt2(o(:,:,1)-o(:,:,2))+o(:,:,2);
%o(:,:,3) = medfilt2(o(:,:,3)-o(:,:,2))+o(:,:,2);
%o = colorScale(o, cam);
%imwrite(o, "out_FREE.png");

% median filtering chroma
function o = cleanChroma(o, n)
  for i = 1:n
    o(:,:,1) = medfilt2(o(:,:,1)-o(:,:,2))+o(:,:,2);
    o(:,:,3) = medfilt2(o(:,:,3)-o(:,:,2))+o(:,:,2);
    o(:,:,2) = 1/2*(medfilt2(o(:,:,2)-o(:,:,1)) + medfilt2(o(:,:,2)-o(:,:,3)) + +o(:,:,1) + +o(:,:,3));
  end
end
%o = cleanChroma(o, 3);

% 4 - Malvar-He-Cutler interpolation:
%GX = [
%      0 0 -1 0 0;
%      0 0 2 0 0;
%      -1 2 4 2 -1;
%      0 0 2 0 0;
%      0 0 -1 0 0
%      ]/8;
%XGR = [
%      0 0 1/2 0 0;
%      0 -1 0 -1 0;
%      -1 4 5 4 -1;
%      0 -1 0 -1 0;
%      0 0 1/2 0 0;
%      ]/8;
%XGC = [
%      0 0 -1 0 0;
%      0 -1 4 -1 0;
%      1/2 0 5 0 1/2;
%      0 -1 4 -1 0;
%      0 0 -1 0 0;
%      ]/8;
%RB = [
%      0 0 -3/2 0 0;
%      0 2 0 2 0;
%      -3/2 0 6 0 -3/2;
%      0 2 0 2 0;
%      0 0 -3/2 0 0;
%      ]/8;
%o = [];
%o(:,:,1) = I.*R + imfilter(I, XGR).*G2 + imfilter(I, XGC).*G1 + imfilter(I, RB).*B;
%o(:,:,2) = I.*(G1+G2) + imfilter(I, GX).*(R+B);
%o(:,:,3) = I.*B + imfilter(I, XGR).*G1 + imfilter(I, XGC).*G2 + imfilter(I, RB).*R;
%o = cleanChroma(o, 3);
%o = colorScale(o, cam);
%imwrite(o, "out_MHC.png");


% 5 - smooth hue transition:
%
% interpolate green channel as usual
% interpolate r-g and b-g channels to obtain missing R and G values
%o = [];
%G = imfilter(I.*(G1+G2), [0, .25, 0; .25, 1, .25; 0, .25, 0]);
%o(:,:,1) = imfilter((I-G).*R, [.25, .5, .25; .5, 1, .5; .25, .5, .25])+G;
%o(:,:,3) = imfilter((I-G).*B, [.25, .5, .25; .5, 1, .5; .25, .5, .25])+G;
%o(:,:,2) = G;
%G = [];
%o = colorScale(o, cam);
%imwrite(o, "out_HUE.png");



% 6 - Pixel Grouping 
o = [];

% interpolate green channel along gradients
function o = ppg_green(I)
  global R
  global G1
  global G2
  global B

  x = size(I,1);
  y = size(I,2);
  
  DHG = [1 0 -1];
  DVG = [1 0 -1]';
  DEX = [0 0 1 0 -1];
  DSX = [0 0 1 0 -1]';
  DWX = [-1 0 1 0 0];
  DNX = [-1 0 1 0 0]';

  FN = [-1 3 1 1 0]'./4;
  FE = [0 1 1 3 -1]./4;
  FW = [-1 3 1 1 0]./4;
  FS = [0 1 1 3 -1]'./4;

  
  D(:,:,1) = abs(imfilter(I, DNX)).*2 + abs(imfilter(I, DVG));
  D(:,:,2) = abs(imfilter(I, DEX)).*2 + abs(imfilter(I, DHG));
  D(:,:,3) = abs(imfilter(I, DWX)).*2 + abs(imfilter(I, DHG));
  D(:,:,4) = abs(imfilter(I, DSX)).*2 + abs(imfilter(I, DVG));

  [Vmin, Dmin] = min(D, [], 3);
  Vmax = max(D, [], 3);
  thr = Vmin*1.5;

  V = [];
  V(:,:,1) = imfilter(I, FN);
  V(:,:,2) = imfilter(I, FE);
  V(:,:,3) = imfilter(I, FW);
  V(:,:,4) = imfilter(I, FS);

  for xi = 1:x
    for yi = 1:y
      % minimum-based
      % o(xi, yi) = V(xi, yi, Dmin(xi, yi));
      
      % threshold-based
      thrFilt = D(xi, yi, :) <= thr(xi, yi);
      o(xi, yi) = sum(V(xi, yi, thrFilt))/sum(thrFilt);
    end
  end

  o = o.*(R+B) + I.*(G1+G2);
end

function ht = hue_transit(l1, l2, l3, v1, v3)
  if (l1<l2 && l2<l3) || (l1>l2 && l2>l3)
    ht = v1+(v3-v1)*(l2-l1)/(l3-l1);
  else
    ht = (v1+v3)/2+(l2*2-l1-l3)/2;
    % ht = (v1+v3)/2+(l2*2-l1-l3)*x; variable parameter x controlling how much of the green peak should affect R/G interpolation
    % prevents color shifts by synchronising with the underlying green channel
  end
end

function r, b = ppg_redgreen(I, G)
  global R
  global G1
  global G2
  global B
  
  r = I.*R;
  b = I.*B;
  
  x = size(I,1);
  y = size(I,2);
  
  for xi = 2:x-1 
    for yi = 2:y-1
      if G1(xi,yi)
	r(xi, yi) = hue_transit(G(xi-1, yi), G(xi, yi), G(xi+1, yi), r(xi-1, yi), r(xi+1, yi));	% horisontal red
	b(xi, yi) = hue_transit(G(xi, yi-1), G(xi, yi), G(xi, yi+1), b(xi, yi-1), b(xi, yi+1));	% vertical blue
      elseif G2(xi,yi)
	b(xi, yi) = hue_transit(G(xi-1, yi), G(xi, yi), G(xi+1, yi), b(xi-1, yi), b(xi+1, yi));	% horisontal blue
	r(xi, yi) = hue_transit(G(xi, yi-1), G(xi, yi), G(xi, yi+1), r(xi, yi-1), r(xi, yi+1));	% vertical red
      end
    end
  end
end

function r, b, V = ppg_redblue(I, G)
  global R
  global G1
  global G2
  global B
  
  x = size(I,1);
  y = size(I,2);
  
  DBR = [ 0,0,-1;
	  0,0,0;
	  1,0,0];
  DG1R = [0,0,-1;
	  0,1,0;
	  0,0,0];
  DG2R = [0,0,0;
	  0,1,0;
	  -1,0,0];
  DR1R = [0 0 0 0 -1;
	  0 0 0 0 0;
	  0 0 1 0 0;
	  0 0 0 0 0;
	  0 0 0 0 0];
  DR2R = [0 0 0 0 0;
	  0 0 0 0 0;
	  0 0 1 0 0;
	  0 0 0 0 0;
	  -1 0 0 0 0];
	  
  DBL = [ -1,0,0;
	  0,0,0;
	  0,0,1];
  DG1L = [-1,0,0;
	  0,1,0;
	  0,0,0];
  DG2L = [0,0,0;
	  0,1,0;
	  0,0,-1];
  DR1L = [-1 0 0 0 0;
	  0 0 0 0 0;
	  0 0 1 0 0;
	  0 0 0 0 0;
	  0 0 0 0 0];
  DR2L = [0 0 0 0 0;
	  0 0 0 0 0;
	  0 0 1 0 0;
	  0 0 0 0 0;
	  0 0 0 0 -1];
  
  D = [];
  D(:,:,1) = abs(imfilter(I, DBR)) + abs(imfilter(I, DG1R)) + abs(imfilter(I, DG2R)) + abs(imfilter(I, DR1R)) + abs(imfilter(I, DR2R));
  D(:,:,2) = abs(imfilter(I, DBL)) + abs(imfilter(I, DG1L)) + abs(imfilter(I, DG2L)) + abs(imfilter(I, DR1L)) + abs(imfilter(I, DR2L));
  [~, Dmin] = min(D, [], 3);
  
  V = zeros(size(I));
  
  for xi = 2:x-1
    for yi = 2:y-1
      if Dmin(xi, yi)==1
	V(xi, yi) = hue_transit(G(xi+1, yi-1), G(xi, yi), G(xi-1, yi+1), I(xi+1, yi-1), I(xi-1, yi+1));		% right slanted
      else
	V(xi, yi) = hue_transit(G(xi-1, yi-1), G(xi, yi), G(xi+1, yi+1), I(xi-1, yi-1), I(xi+1, yi+1));		% left slanted
      end
    end
  end
  
  r = V.*B;
  b = V.*R;
end


% apply to I:
o = [];
g = ppg_green(I);
disp("green done")
% possibly interchange green-estimating function, or make it average over multiple gradients for smoothness?
[r1, b1] = ppg_redgreen(I, g);
disp("redgreen done")
[r2, b2] = ppg_redblue(I, g);
disp("redblue done")
o(:,:,1) = r1 + r2;
o(:,:,2) = g;
o(:,:,3) = b1 + b2;

% chroma filtering eliminates remaining sharp-edge splotches
% o = cleanChroma(o, 3);

imagesc(o);
imwrite(o/256, "out_PPG.png");



%next: VNG

















