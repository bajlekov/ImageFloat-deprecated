/*
	Copyright (C) 2011-2014 G. Bajlekov

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

export void vpow(uniform float x[], uniform float y[], uniform float z[]) {
  foreach(i = 0 ... 4) {
    z[i] = pow(x[i], y[i]);
  }
}

export void vpowVEC(uniform float x[], uniform float y[], uniform float z[], uniform int size) {
  foreach(i = 0 ... size) {
    z[i] = pow(x[i], y[i]);
  }
}

export void dilate(uniform float x[], uniform float y[]) {
  foreach(i = 0 ... 3) {
    y[i] = max(max(max(max(x[i-2], x[i-1]), x[i]), x[i+1]), x[i+2]);
  }
}

export void dilateCsingle(uniform float x[], uniform float y[]) {
  y[0] = max(max(max(max(x[-2], x[-1]), x[0]), x[1]), x[2]);
}

export void dilateSSE(uniform float x[], uniform float y[], uniform int start, uniform int end) {
  foreach(i = start ... end) {
    y[i] = max(max(max(max(x[i-2], x[i-1]), x[i]), x[i+1]), x[i+2]);
  }
}

export void dilateC(uniform float x[], uniform float y[], uniform int start, uniform int end) {
  for (int i = start; i<end; i++) {
    y[i] = max(max(max(max(x[i-2], x[i-1]), x[i]), x[i+1]), x[i+2]);
  }
}

export void addSSE(uniform float x[], uniform float y[], uniform float z[], uniform int end) {
  foreach(i = 0 ... end) {
    z[i] = x[i]+y[i];
  }
}

export void addSSEsingle(uniform float x[], uniform float y[], uniform float z[]) {
  foreach(i = 0 ... 4) {
    z[i] = x[i]+y[i];
  }
}