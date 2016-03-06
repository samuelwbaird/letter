-- event_dispatch and matching client class event_handler
-- are just convenient wrappers around dispatching and listening to events
-- used by the touch areas
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')
local pool = require('core.pool')

-- event dispatcher

local event_dispatch = class(function (event_dispatch)
	
	function event_dispatch:init()
		self.events = {}
		self.listener_pool = pool()
		self.deferred = {}
		self.defer_pool = pool()
	end
	
	-- shared static reference -----------------------------
	
	local shared = {}
	
	function event_dispatch.reset_shared_instance()
		shared = { event_dispatch() }
	end
	
	event_dispatch.reset_shared_instance()
	
	function event_dispatch.shared_instance()
		return shared[#shared]
	end
	
	function event_dispatch.push_shared_instance()
		shared[#shared + 1] = event_dispatch()
	end
	
	function event_dispatch.pop_shared_instance()
		shared[#shared] = nil
	end
	
	-- listeners -----------------------------------------	
	
	function event_dispatch:add_listener(tag, event_name, action)
		local listeners = self.events[event_name]
		if not listeners then
			listeners = array()
			self.events[event_name] = listeners
		end
		local listener = self.listener_pool:acquire()
		listener.tag = tag
		listener.action = action
		listeners:push(listener)
	end
	
	function event_dispatch:remove_listener(tag, event_name)
		if not event_name then
			for name, _ in pairs(self.events) do
				self:remove_listener(tag, name)
			end
		else
			local listeners = self.events[event_name]
			if listeners and #listeners > 0 then
				local index = 1
				while index < #listeners do
					local listener = listeners[index]
					if listener.tag == tag then
						listener.tag = nil
						listener.action = nil
						self.listener_pool:release(listener)
						table.remove(listeners, index)
					else
						index = index + 1
					end
				end
			end
		end
	end
	
	function event_dispatch:remove_all()
		self.listener_pool:with_active(function (listener)
			listener.tag = nil
			listener.action = nil
		end)
		self.listener_pool:release_all()
		self.events = {}
	end
	
	function event_dispatch:dispatch(event_name, data)
		local listeners = self.events[event_name]
		if listeners and #listeners > 0 then
			-- clone the listeners and dispatch from the clone to allow update during iteration
			for _, listener in ipairs(listeners:clone()) do
				if listener.action then
					listener.action(data)
				end
			end
		end		
	end
	
	function event_dispatch:defer(event_name, data)
		local defer = self.defer_pool:acquire()
		defer.event_name = event_name
		defer.data = data
		self.deferred[#self.deferred + 1] = defer
	end
	
	function event_dispatch:dispatch_deferred()
		-- reset the defer list
		local deferred = self.deferred
		self.deferred = {}
		-- dispatch the previously deferred events
		for _, defer in ipairs(deferred) do
			self:dispatch(defer.event_name, defer.data)
			self.defer_pool:release(defer)
		end
	end
	
end)

-- convenient client class for event handling

local event_handler = class (function (event_handler)
	
	function event_handler:init(dispatcher)
		self.event_dispatch = dispatcher or event_dispatch.shared_instance()
		self.did_listen = false
	end
	
	function event_handler:listen(event_name, action)
		self.did_listen = true
		self.event_dispatch:add_listener(self, event_name, action)
	end
	
	function event_handler:unlisten(event_name)
		self.event_dispatch:remove_listener(self, event_name)
		if not event_name then
			self.did_listen = false
		end
	end
	
	function event_handler:dispatch(event_name, data)
		self.event_dispatch:dispatch(event_name, data)
	end
	
	function event_handler:defer(event_name, data)
		self.event_dispatch:defer(event_name, data)
	end
	
	function event_handler:dispose()
		if self.did_listen then
			self:unlisten()
		end
	end
	
end)

return class.package({
	event_dispatch = event_dispatch,
	event_handler = event_handler,
}, event_dispatch)