local msgpack = require('MessagePack')
local class = require('core.class')

-- the returned object is the handle that lives in your current thread
-- push requests to the handle with a callback
-- the callback fires when the request is complete

-- internally the request thread runs a function in a loop
-- receiving data and returning a response
-- the request is launched with some init code and the response function
	
-- when a request is created a task object is returned to track the task
-- this task object can be cancelled, cancelling the code on the other thread
-- is not implemented but it will prevent any callback from firing

-- a network thread launches a request thread with an HTTP request function
-- it returns the request thread object embellished with functions to form the requests

-- implementation note, the current thread must poll the request_thread for task completion
-- (Love2D will not signal from the channel)
-- if present app.dispatch is used to poll a thread until it completes

local request_thread_task = class(function (request_thread_task)

	function request_thread_task:init(request_thread, request_id, on_complete)
		self.request_thread = request_thread
		self.request_id = request_id
		self.on_complete = on_complete
	end

end)

local request_thread = class(function (request_thread)

	function request_thread:init(init_code_string, response_code_string, exit_code_string)
		self.last_request_id = 0
		self.current_tasks = {}
		
		self.channel_to_thread = love.thread.newChannel()
		self.channel_from_thread = love.thread.newChannel()
		
		self.thread = love.thread.newThread([[
			local channel_in, channel_out, init_code, response_code, exit_code = ...
			local msgpack = require('MessagePack')
			
			if init_code then
				local init_function, compile_error = loadstring(init_code)
				if not init_function then
					print('error creating request_thread, compile error in init\n' .. compile_error .. '\n' .. init_code)
					return
				end
				local success, result = pcall(init_function)
				if not success then
					print('error during init of request_thread\n' .. result)
					return
				end
			end
			
			local exit_function = nil
			if exit_code then
				local compile_error = nil
				exit_function, compile_error = loadstring(exit_code)
				if not exit_function then
					print('error creating request_thread, compile error in exit\n' .. compile_error .. '\n' .. exit_code)
					return
				end
			end
			
			local response_function, compile_error = loadstring(response_code)
			if not response_function then
				print('error creating request_thread compile error in response\n' .. compile_error .. '\n' .. response_code)
				return
			end
			
			while true do
				local input = msgpack.unpack(channel_in:demand())
				if input.end_loop == true then
					break
				end
				
				local success, result = pcall(response_function, input.params)
				local response = { did_complete = success, request_id = input.request_id }
				if success then
					response.result = result
				else
					print('error during response in request_thread\n' .. result)
					response.error = result
				end	
				channel_out:push(msgpack.pack(response))
			end
			
			if exit_function then
				local success, result = pcall(exit_function)
				if not success then
					print('error during exit of request_thread\n' .. result)
					return
				end
			end
		]])
		
		-- if global app object exists then hook into regular tick for polling
		local app = rawget(_G, 'app')
		if app then
			self.dispatch = app.dispatch
			self.is_hooked = false
		end

		self.thread:start(self.channel_to_thread, self.channel_from_thread, init_code_string, response_code_string, exit_code_string)
	end
	
	function request_thread:request(params, on_complete)
		-- create the task object to track the request
		self.last_request_id = self.last_request_id + 1
		local task = request_thread_task(self, self.last_request_id, on_complete)
		self.current_tasks[task.request_id] = task
		
		-- push the request to the channel
		self.channel_to_thread:push(msgpack.pack({
			request_id = task.request_id,
			params = params,
		}))
		
		--- add a polling hook if we are not currently polling
		if self.dispatch and not self.is_hooked then
			self.dispatch:hook(self:delegate(request_thread.poll), self)
			self.is_hooked = true
		end
	end
	
	function request_thread:cancel(task)
		if task then
			-- cancel a specific task
			if task.request_thread ~= self then
				return
			end
			if task.request_id then
				self.current_tasks[task.request_id] = nil
			end

			task.request_thread = nil
			task.request_id = nil
			task.on_complete = nil
		else
			-- cancel the whole thread
			if self.channel_to_thread then
				self.channel_to_thread:push(msgpack.pack({
					end_loop = true,
				}))
			end
			self.thread = nil
			self.channel = nil
			self.current_tasks = {}
		end
		
		-- unhook if no tasks are left
		if not next(self.current_tasks) and self.is_hooked then
			self.dispatch:remove(self)
			self.is_hooked = false
		end
	end
	
	function request_thread:poll()
		-- check the channel for replies
		local response = self.channel_from_thread:pop()
		if response then
			response = msgpack.unpack(response)
			local task = self.current_tasks[response.request_id]
			if task then
				local on_complete = task.on_complete
				self:cancel(task)
				if response.did_complete and on_complete then
					on_complete(response.result)
				end
			end
		end
	end
	
	function request_thread:complete()
		if self.thread then
			if self.channel_to_thread then
				self.channel_to_thread:push(msgpack.pack({
					end_loop = true,
				}))
			end
			self.thread:wait()
			self:cancel()
		end
	end
	
end)

local wrapped_socket = class(function (wrapped_socket)
	-- wraps a normal socket connect and does keep alive connection behaviour by default
	-- ignores close and open until the host or port changes or the connection timesout
	-- TODO: if luasec module is available then also support https connections here

	function wrapped_socket:init()
		self.timeout = 60
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

local network_thread = class(function (network_thread)
	
	function network_thread:init(background_thread_role)
		if background_thread_role then
			-- code is now running on the request thread to actually perform the network requests
			self.http = require('socket.http')
			-- pretends to be a real socket but acts like a keep-alive socket that only closes when needed
			self.wrapped_socket = wrapped_socket()
			
		else
			-- this code runs on the main thread as a client to the work happening on the background
			-- thread, pass back a request_thread set up to handle network requests
			local thread = request_thread([[
				-- global ref to object handling requests
				network_thread = require('lt.network_thread') (true)	-- thread side functionality
			]], [[
				local input = ...
				local method = input.method
				local params = input.params
				return network_thread[method](network_thread, unpack(params))
			]])
			
			-- add proxy methods on the thread object for the valid calls available
			local proxy_methods = { 'get', 'post', 'http_request', 'msgpack_api', 'download' }
			for _, proxy_method in ipairs(proxy_methods) do
				thread[proxy_method] = function (thread, params, on_complete)
					thread:request({
						method = proxy_method,
						params = params,
					}, on_complete)
				end
			end
			return thread
		end
	end
	
	function network_thread:get(url)
		return self:http_request(url, 'GET').body
	end
	
	function network_thread:post(url, post_data)
		return self:http_request(url, 'POST', nil, post_data).body
	end
	
	function network_thread:http_request(url, method, additional_headers, post_data)
		if post_data then
			additional_headers = additional_headers or {}
			additional_headers['Content-length'] = #post_data
		end
		
		local output = {}
		local r, status, headers = self.http.request {
		  method = method,
		  url = url,
		  headers = additional_headers,
		  sink = ltn12.sink.table(output),
		  source = post_data and ltn12.source.string(post_data) or nil,
		  -- reuse a single wrapped socket per thread that can provide the keep alive function
		  create = function  ()
			  return self.wrapped_socket
		  end
		}
		
		return {
			status = status,
			headers = headers,
			body = table.concat(output),
		}
	end
	
	function network_thread:msgpack_api(url, post_data)
		-- enable keep alive if possible
		local headers = { 
			['Connection'] = 'keep-alive',
			['Content-type'] = 'application/x-msgpack',
		}
		-- transparently convert to and from msgpack transport of data
		post_data = post_data and msgpack.pack(post_data)
		local response = self:http_request(url, 'POST', headers, post_data)
		if response.body and #response.body > 0 then
			return msgpack.unpack(response.body)
		end
	end
	
	function network_thread:download(url, file_path)
		local result = self.http_request(url, 'GET')
		if result.body then
			result.saved = love.filesystem.write(file_path, result.body)
		end
		
		return {
			status = status,
			downloaded = (status == 200),
			saved = result.saved,
			size = #result.body,
		}
	end
	
end)

return class.package({ request_thread = request_thread, network_thread = network_thread }, network_thread.new)