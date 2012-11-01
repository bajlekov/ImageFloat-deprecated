from pylab import array,fromfile

def read_rgb(fname):
	fid = open(fname, 'rb')
	res = fromfile(fid, 'd', 2)
	x = int(res[0])
	y = int(res[1])
	img = fromfile(fid, 'd', x*y*3).reshape(x, y, 3).swapaxes(0, 1)
	fid.close()
	return img

def write_rgb(fname,img):
	fid=open(fname,'wb')
	array([double(len(img[1])), double(len(img))]).tofile(fid)
	img.swapaxes(0,1).flatten().tofile(fid)
	fid.close()

