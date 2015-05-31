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

-- minimal ffi binding for zmq library to facilitate multithreaded message passing

local ffi = require("ffi")
local ZMQ = ffi.load("zmq")

ffi.cdef[[
	void zmq_version (int *major, int *minor, int *patch);
	void *zmq_ctx_new ();
	int zmq_ctx_term (void *context);
	
	void *zmq_socket (void *context, int type);
	int zmq_close (void *socket);
	int zmq_bind (void *socket, const char *endpoint);
	int zmq_connect (void *socket, const char *endpoint);
	int zmq_send (void *socket, void *buf, size_t len, int flags);
	int zmq_recv (void *socket, void *buf, size_t len, int flags);
	
	int zmq_errno (void);
	const char *zmq_strerror (int errnum);
]]

local zmq = {}

function zmq.version()
	local v = ffi.new("int[3]")
	ZMQ.zmq_version(v, v+1, v+2)
	return v[0], v[1], v[2]
end

zmq.ctx = {}

-- do not GC contexts
function zmq.ctx.new()
	local context = ZMQ.zmq_ctx_new()
	zmq.context = context
	return context
end
function zmq.ctx.set(context)
	zmq.context = context
end
function zmq.ctx.term(context)
	context = context or zmq.context
	assert(ZMQ.zmq_ctx_term(context)==0)
	zmq.context = nil
end

zmq.socket = {}

zmq.PAIR = 0 -- paired bidirectional connection
zmq.PUB = 1 -- send, send ... dropping, fan out
zmq.SUB = 2 -- receive, receive ... dropping
zmq.REQ = 3 -- send, receive, send, receive ...
zmq.REP = 4 -- receive, send, receive, send ...
zmq.PULL = 7 -- receive, receive ... blocking
zmq.PUSH = 8 -- send, send ... blocking

zmq.socket.meta = {__index=zmq.socket}

function zmq.socket.new(type)
	local o = {
		socket = ffi.gc(ZMQ.zmq_socket(zmq.context, type), ZMQ.zmq_close)
	}
	setmetatable(o, zmq.socket.meta)
	return o
end

function zmq.socket:close()
	assert(ZMQ.zmq_close(ffi.gc(self.socket, nil))==0)
end
function zmq.socket:bind(endpoint) -- incoming
	assert(ZMQ.zmq_bind(self.socket, endpoint)==0)
end
function zmq.socket:connect(endpoint) -- outgoing
	assert(ZMQ.zmq_connect(self.socket, endpoint)==0)
end
function zmq.socket:send(data, size)
	assert(ZMQ.zmq_send(self.socket, data, size, 0)~=-1)
end
function zmq.socket:recv(data, size)
	assert(ZMQ.zmq_recv(self.socket, data, size, 0)~=-1)
end

function zmq.error()
	print(ffi.string(ZMQ.zmq_strerror(ZMQ.zmq_errno())))
end

return zmq

