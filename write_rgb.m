function write_rgb(fname,img)
	x = size(img,2);
	y = size(img,1);
	tmp = zeros(size(img(:)));
	tmp(1:3:end) = img(:,:,1)(:);
	tmp(2:3:end) = img(:,:,2)(:);
	tmp(3:3:end) = img(:,:,3)(:);
	fid = fopen(fname,"w");
	fwrite(fid,x,"float64");
	fwrite(fid,y,"float64");
	fwrite(fid,tmp,"float64");
	tmp = [];
	fclose(fid);
end

