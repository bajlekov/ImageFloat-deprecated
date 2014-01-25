--[[
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
]]

--[[ functions for communication with external programs and scripting environments
	based on fifo buffers/named pipes (windows??, android??) or file operations(fast due to OS disk caching in memory/read/write caching)
	
	- fifo for read/writes
	- fifo for synchronisation
	- pipe for control
		- no secure environment/capture of stderr
	
	- writing:
		- push external call to read X bytes
		- send x bytes
		- sync on op complete
	- writing:
		- push external call to send x bytes
		- receive x bytes
		- sync on op complete
	- sync:
		- flush fifo
		- push external call to send control char
		- wait for receive control char
		- resume
	
	ability to do async file ops in a helper thread
		- control is async due to op buffer (hence need for sync on external files)
		- push writing op to external thread
		- flip bit on complete
	
	in absence of fifo/named pipes:
		- write to file
		- read from file
		- sync through file creation/deletion
		- possibly use one-way communication through regular pipe, enables sync
			- can be created only in one direction, clutters stdin/out
	
	create utilities for commandline tools:
		- dcraw, imagemagic etc...
		- direct communication through named pipes
		- needs threaded operation for simultaneous send/receive data...or asynchronous send??
	
	
--]]