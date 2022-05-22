-- client connection to tiny wide open spaces sessions to work with letter and love2d 

local class = require('core.class')
local array = require('core.array')

local app_node = require('lt.app_node')
local http_client = require('lt.http_client')

return class.derive(app_node, function (http_session)
	
	-- storage
	-- get key = string
	-- set key string
	
	function http_session:init(base_url, session_data, storage, persist_session_id_key)
		self.base_url = base_url
		self.session_data = session_data
		self.session_id = nil
		self.last_id = 0
		
		self.last_receipt = 0
		self.receipts = {}
		
		self.backoff = 0
		self.exponential_backoff = 30
		self.guards = {}
		
		self.pull_queue = array()
		self.push_queue = array()
		
		self.pull_http_client = http_client()
		self.push_http_client = http_client()
		self:add(self.pull_http_client)
		self:add(self.push_http_client)
		
		-- restore a persistent session id if we have one
		if storage and persist_session_id_key then
			self.storage = storage
			self.persist_session_id_key = persist_session_id_key
			self.validate_session = true
			self.session_id = storage:get(persist_session_id_key)
		end
	end
	
	function http_session:push(message, with_response, with_error)
		-- add a receipt when expecting a response, so we can pick up that response later
		if with_response or with_error then
			self.last_receipt = self.last_receipt + 1
			message.receipt = self.last_receipt
			self.receipts[message.receipt] = {
				time = love.timer.getTime(),
				with_success = with_response,
				with_error = with_error,
			}
		end
		
		self.push_queue:push({
			message = message,
			with_response = with_response,
			with_error = with_error,
		})
	end
	
	function http_session:read_message(with_message)
		if #self.pull_queue == 0 then
			return
		end
		
		-- pull the next message from the queue
		local message = self.pull_queue[1]
		self.pull_queue:remove(1)
		
		-- handle API responses to this message if it has one
		local receipt = message.receipt
		if receipt and self.receipts[receipt] then
			local entry = self.receipts[receipt]
			self.receipts[receipt] = nil
			if not message.success then
				if entry.with_error then
					entry.with_error(message.error)
				end
			elseif entry.with_success then
				entry.with_success(message)
			end
		end

		-- run the message handler for this message
		if with_message then
			with_message(message)
		end
			
		-- or return it
		return message
	end
	
	function http_session:read_messages(with_message)
		while #self.pull_queue > 0 do
			self:read_message(with_message)
		end
	end
	
	function http_session:peek_message()
		return self.pull_queue[1]
	end
	
	function http_session:peek_messages()
		local out = array()
		for i, m in ipairs(self.pull_queue) do
			out[i] = m
		end
		return out
	end
			
	-- on the app node timer ensure all queries that should be in flight are in flight
	function http_session:update()
		app_node.update(self)
		
		-- if we do not have a session id and there is no session query in flight, then query again
		if not self.session_id then
			self:wrapped_query(self.pull_http_client, 'create', self.session_data, function (response)
				self.session_id = response.session_id
				self.validate_session = false
				print('session_id: ' .. self.session_id)
				if self.storage then
					self.storage:set(self.persist_session_id_key, self.session_id)
				end
			end, function (error)
			end)
			return
		end
		
		if self.validate_session then
			self:wrapped_query(self.pull_http_client, 'validate', {}, function (response)
				self.validate_session = false
			end, function (error)
			end)
			return
		end
		
		-- if we have data to push then push the next one
		if #self.push_queue > 0 then
			local entry = self.push_queue[1]
			self:wrapped_query(self.push_http_client, 'push', entry.message, function (response)
				self.push_queue:remove(1)
			end, function (error)
				self.push_queue:remove(1)
				if entry.message.receipt then
					self.receipts[entry.message.receipt] = nil
				end
				if entry.with_error then
					entry.with_error(error)
				end
			end)
		end
		
		-- if we don't have a pull query in flight then initiate the next one
		self:wrapped_query(self.pull_http_client, 'pull', { last_id = self.last_id, max = 0 }, function (messages)
			for _, message in ipairs(messages) do
				if message.id > self.last_id then
					self.last_id = message.id
				end
				-- save it for reading
				self.pull_queue:push(message)
			end
		end, function (error)
		end)
		
		-- TODO: possibly check receipts for timeout and consider those an error
	end
	
	-- call this repeatedly for any desired query to handle retry without duplication, and with backoff on error
	function http_session:wrapped_query(http_client, path, send_data, with_success, with_error)
		-- ignore queries during backoff
		if self.backoff > 0 then
			self.backoff = self.backoff - 1
			return
		end
		
		-- guard against multiple queries to the same path at once
		if self.guards[path] then
			return
		end
		self.guards[path] = true
		
		-- if we have a session id then include it in the data being sent
		if self.session_id then
			send_data.session_id = self.session_id
		end

		-- request(url, method, headers, timeout, body, with_result)
		http_client:request(self.base_url .. path, 'post', {}, 60, send_data, function (response)
			self.guards[path] = false
			if response.success then
				self.exponential_backoff = 30
				if with_success then
					with_success(response.body)
				end
			else
				-- if query is unauthorised then clear the session
				if response.status == 403 then
					self.session_id = nil
					self.last_id = 0
					self.pull_queue = array()
					self.push_queue = array()
					if self.storage then
						self.storage:set(self.persist_session_id_key, nil)
					end
				end
				print('error querying ' .. path .. ' ' .. response.status)
				if self.exponential_backoff < 60 * 60 then
					self.exponential_backoff = self.exponential_backoff * 2
				end
				self.backoff = self.exponential_backoff
				print('query backoff ' .. self.backoff)
				if with_error then
					with_error(response.body or response.status or 'no connection')
				end
			end
		end)
	end	
end)
