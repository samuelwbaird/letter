-- manage a love 2D thread to perform lua socket synchronous network requests asynchronously
-- this is a little complicate so keep it as simple as possible on the surface over that
-- NOTE this http client will only perform a single query at a time

local class = require('core.class')
local array = require('core.array')
local surly = require('util.surly')

local app_node = require('lt.app_node')

local http_client = class.derive(app_node, function (http_client)

	function http_client:init()
		self.last_request_receipt = 0
		self.receipts = {}
		
		-- commands sent to the background network thread
		self.channel_to_thread = love.thread.newChannel()
		-- commands recieved from the background network thread
		self.channel_from_thread = love.thread.newChannel()
		
		self.thread = love.thread.newThread([[
		local channel_from_client, channel_to_client = ...
		local background_thread = require('lt.http_client').http_client_background_thread(channel_from_client, channel_to_client)
		background_thread:thread_loop()
		]])
		self.thread:start(self.channel_to_thread, self.channel_from_thread)
	end
	
	function http_client:request(url, method, headers, timeout, body, with_result)
		self.last_request_receipt = self.last_request_receipt + 1
		-- retain the receipt for when the response comes back
		local response = {
			expiry = love.timer.getTime() + timeout,
			-- track the outcome
			complete = false,
			success = false,
			status = nil,
			headers = {},
			body = nil,
			-- the callback we'll use later
			with_result = with_result,
		}
		self.receipts[self.last_request_receipt] = response
		-- parse the request to the background thread
		self.channel_to_thread:push({
			receipt = self.last_request_receipt,
			url = url,
			method = method,
			headers = headers,
			timeout = timeout,
			body = body
		})
		return response
	end

	function http_client:update()
		-- check for any messages coming back from the network thread
		-- and dispatch them back to callers in the main thread
	end
	
	function http_client:dispose()
		-- end the thread
		if self.thread then
			self.channel_to_client:push({
				end_thread = true
			})
			self.thread:kill()
			self.thread:release()
			self.thread = nil
		end
		app_node.dispose(self)
	end
	
	
end)

local wrapped_socket = class(function (wrapped_socket)
	-- wraps a normal socket connect and does keep alive connection behaviour by default
	-- ignores close and open until the host or port changes or the connection timesout
	-- TODO: if luasec module is available then also support https connections here

	function wrapped_socket:init()
		self.timeout = 30
		self.real_socket = nil
		self.host = nil
		self.port = nil
	end

	function wrapped_socket:settimeout(timeout)
		self.timeout = timeout
		return true
	end
	
	function wrapped_socket:connect(host, port)
		if host ~= self.host or port ~= self.port then
			if self.real_socket then
				self.real_socket:close()
				self.real_socket = nil
			end
			self.host = host
			self.port = port
		end
		return true
	end
	
	function wrapped_socket:actually_connect()
		self.real_socket = require('socket').tcp()
		self.real_socket:connect(self.host, self.port)
		self.real_socket:settimeout(self.timeout)
	end
	
	function wrapped_socket:send(...)
		if not self.real_socket then
			self:actually_connect()
		end
		local r1, r2, r3, r4, r5 = self.real_socket:send(...)
		if r1 == nil then
			-- reopen on timeout
			self.real_socket:close()
			self.real_socket = nil
			self:actually_connect()
			r1, r2, r3, r4, r5 = self.real_socket:send(...)
		end
		return r1, r2, r3, r4, r5
	end
	
	function wrapped_socket:receive(...)
		if not self.real_socket then
			self:actually_connect()
		end
		local r1, r2, r3, r4, r5 = self.real_socket:receive(...)
		if r1 == nil then
			-- reopen on timeout
			self.real_socket:close()
			self.real_socket = nil
			self:actually_connect()
			r1, r2, r3, r4, r5 = self.real_socket:receive(...)
		end
		return r1, r2, r3, r4, r5
	end
	
	function wrapped_socket:close()
		-- don't actually close it, incase we can use it next time
		return true
	end
	
end)

local http_client_background_thread = class(function (http_client_background_thread)
	
	function http_client_background_thread:init(channel_from_client, channel_to_client)
		self.channel_from_client = channel_from_client
		self.channel_to_client = channel_to_client
		
		-- code is now running on the request thread to actually perform the network requests
		self.http = require('socket.http')
		-- pretends to be a real socket but acts like a keep-alive socket that only closes when needed
		self.wrapped_socket = wrapped_socket()
	end
	
	function http_client_background_thread:thread_loop()
		while true do
			local request = self.channel_from_client:demand()
			if request.end_thread then
				break
			end

			-- prepare the url request
			self.wrapped_socket.timeout = request.timeout or 30
			local headers = request.headers or {}
			local body = request.body
			local encode_objects = type(body) == 'table'
			headers['Connection'] = 'keep-alive'
			if encode_objects then
				body = surly.serialise(body)
				headers['Content-type'] = 'application/lua'
				headers['Accept-type'] = 'application/lua'
			end
			if body then
				headers['Content-length'] = #body				
			end

			-- perform the query using luasocket
			local output = {}
			local r, status, headers = self.http.request({
			  method = request.method,
			  url = request.url,
			  headers = headers,
			  sink = ltn12.sink.table(output),
			  source = body and ltn12.source.string(body) or nil,
			  -- reuse a single wrapped socket per thread that can provide the keep alive function
			  create = function  ()
				  return self.wrapped_socket
			  end
			})
			
			-- prepare the response
			headers = headers or {}
			local body = table.concat(output)
			if encode_objects then
				body = surly.parse(body)
			end
			self.channel_to_client:push({
				receipt = request.receipt,
				complete = (r ~= nil),
				success = (r ~= nil) and type(status) == 'number' and (math.floor(status / 200) == 2),
				status = status,
				headers = headers,
				body = body,
			})
		end
	end		
	
end)

return class.package({ http_client = http_client, http_client_background_thread = http_client_background_thread }, http_client.new)