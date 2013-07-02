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

const uniform int A[19] = {1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4};
const uniform int B[19] = {2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2};
varying float pix[9];

inline void sort(uniform int a, uniform int b) {	
	cif (pix[a]>pix[b]) {
		varying float t = pix[b];
		pix[b] = pix[a];
		pix[a] = t;
	}
}

export void medianD(uniform float i[], uniform float o[], uniform int xmax, uniform int ymax) {
	foreach (y=1...ymax-1, x = 1...xmax-1) {
		pix[0] = i[(y-1)*xmax+x-1];
		pix[1] = i[y*xmax+x-1];
		pix[2] = i[(y+1)*xmax+x-1];
		pix[3] = i[(y-1)*xmax+x];
		pix[4] = i[y*xmax+x];
		pix[5] = i[(y+1)*xmax+x];
		pix[6] = i[(y-1)*xmax+x+1];
		pix[7] = i[y*xmax+x+1];
		pix[8] = i[(y+1)*xmax+x+1];
		
		//uniform int j;
		//for (j = 0; j<19; j++) {
		//	sort(A[j], B[j]);
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
				
		o[y*xmax+x] = pix[4];
	}
}