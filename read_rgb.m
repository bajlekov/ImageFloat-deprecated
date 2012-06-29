function [img]=read_rgb(fname)
	fid=fopen(fname,"r");
	x = fread(fid,1,"float64");
	y = fread(fid,1,"float64");
	tmp = fread(fid,x*y*3,"float64");
	fclose(fid);
	img(:,:,1) = reshape(tmp(1:3:end),y,x);
	img(:,:,2) = reshape(tmp(2:3:end),y,x);
	img(:,:,3) = reshape(tmp(3:3:end),y,x);
	tmp = [];
end

