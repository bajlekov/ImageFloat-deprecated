/*
    Copyright (C) 2011-2013 G. Bajlekov

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
*/


const int A[19] = {1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4};
const int B[19] = {2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2};
float pix[9];

inline void sort(int a, int b) {	
	if (pix[a]>pix[b]) {
		float t = pix[b];
		pix[b] = pix[a];
		pix[a] = t;
	}
}

void medianD(float* in, float* out, int xmax, int ymax) {
	int x, y, i;
	for (y = 1; y<ymax-1; y++) {
		for (x = 1; x<xmax-1; x++) {
			pix[0] = in[(y-1)*xmax+x-1];
			pix[1] = in[y*xmax+x-1];
			pix[2] = in[(y+1)*xmax+x-1];
			pix[3] = in[(y-1)*xmax+x];
			pix[4] = in[y*xmax+x];
			pix[5] = in[(y+1)*xmax+x];
			pix[6] = in[(y-1)*xmax+x+1];
			pix[7] = in[y*xmax+x+1];
			pix[8] = in[(y+1)*xmax+x+1];
			
			//for (i = 0; i<19; i++) {
			//	sort(A[i], B[i]);
			//}
			
			sort(A[1], B[2]);
			sort(A[4], B[5]);
			sort(A[7], B[8]);
			sort(A[0], B[1]);
			sort(A[3], B[4]);
			sort(A[6], B[7]);
			sort(A[1], B[2]);
			sort(A[4], B[5]);
			sort(A[7], B[8]);
			sort(A[0], B[3]);
			sort(A[5], B[8]);
			sort(A[4], B[7]);
			sort(A[3], B[6]);
			sort(A[1], B[4]);
			sort(A[2], B[5]);
			sort(A[3], B[7]);
			sort(A[4], B[2]);
			sort(A[6], B[4]);
			sort(A[4], B[2]);
			
			out[y*xmax+x] = pix[4];
		}
	}
}
