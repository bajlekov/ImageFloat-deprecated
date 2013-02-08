
const short A[19] = {1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4};
const short B[19] = {2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2};
double pix[9];

void sort(int a, int b) {	
	if (pix[a]>pix[b]) {
		double t = pix[b];
		pix[b] = pix[a];
		pix[a] = t;
	}	
}

void medianD(double* in, double* out, int xmax, int ymax) {
	int x, y, i;
	for (x = 1; x<xmax-1; x++) {
		for (y = 1; y<ymax-1; y++) {
			pix[0] = in[(y-1)*xmax+x-1];
			pix[1] = in[y*xmax+x-1];
			pix[2] = in[(y+1)*xmax+x-1];
			pix[3] = in[(y-1)*xmax+x];
			pix[4] = in[y*xmax+x];
			pix[5] = in[(y+1)*xmax+x];
			pix[6] = in[(y-1)*xmax+x+1];
			pix[7] = in[y*xmax+x+1];
			pix[8] = in[(y+1)*xmax+x+1];
			
			for (i = 0; i<19; i++) {
				sort(A[i], B[i]);
			}
			
			out[y*xmax+x] = pix[4];
		}
	}
	
}