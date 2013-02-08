disp("Vector Median Filter");

pkg load image
i = double(imread("lena.png"));

i = i + unifrnd(0,30,size(i));

% vector distance function
function d = dist(v, w)
  d = sum((v-w).^2);
end

% vector median function
function m = vmedfilt(v)
% v = [3 x n] matrix with n 3d vectors
  n = size(v, 1);
  m = zeros(n);
  
  for x=1:n
    for y=1:x-1
      m(x, y) = m(y, x) = dist(v(x, :), v(y, :));
    end
  end
  
  [~, m] = min(sum(m));
  m = v(m, :);
end

o = zeros(size(i));
for x = 256:384
  for y = 128:256
    v = [ squeeze(i(x-1,y-1,:))';
	  squeeze(i(x-1,y,:))';
	  squeeze(i(x-1,y+1,:))';
	  squeeze(i(x,y-1,:))';
	  squeeze(i(x,y,:))';
	  squeeze(i(x,y+1,:))';
	  squeeze(i(x+1,y-1,:))';
	  squeeze(i(x+1,y,:))';
	  squeeze(i(x+1,y+1,:))'];
    m = vmedfilt(v);
    o(x, y, :) = m;
  end
end

o(256:384, 256:384, 1) = medfilt2(i(256:384, 128:256, 1));
o(256:384, 256:384, 2) = medfilt2(i(256:384, 128:256, 2));
o(256:384, 256:384, 3) = medfilt2(i(256:384, 128:256, 3));
