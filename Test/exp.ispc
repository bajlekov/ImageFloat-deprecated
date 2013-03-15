/*
	Copyright (C) 2011-2012 G. Bajlekov
	
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

export void packExp(uniform float input[], uniform int16 mantissa[], uniform int8 exponent[], uniform int size) {
	foreach(i = 0 ... size) {
		int t;
		mantissa[i] = frexp(input[i], &t)*32768;
		exponent[i] = t;
	}
}

export void unpackExp(uniform float output[], uniform int16 mantissa[], uniform int8 exponent[], uniform int size) {
	foreach(i = 0 ... size) {
		output[i] = ldexp(mantissa[i]/32768.0, exponent[i]);
	}
}