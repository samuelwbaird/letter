-- heavyweight objects for defining the main spine of the game
-- these objects manage other app_nodes in a tree and primarily scope resources and updates
-- normally used to manage large chunks rather than individual sprites or entities
-- in this implementation many of the convenient properties are only created lazily when first accessed
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')
local dispatch = require('util.dispatch')

local display_list = require('lt.display_list')
local event_dispatch = require('lt.event_dispatch')
local touch_area = require('lt.touch_area')
local button = require('lt.button')
local tween = require('lt.tween')

return class(function (app_node)

	-- lazy properties created when needed
	app_node:add_lazy_property('children', dispatch.update_set)
	app_node:add_lazy_property('view', display_list)
	app_node:add_lazy_property('event_handler', event_dispatch.event_handler)
	app_node:add_lazy_property('dispatch', dispatch)
	app_node:add_lazy_property('weave', dispatch.weave)
	app_node:add_lazy_property('tween_manager', tween.manager)
	app_node:add_lazy_property('disposables', array)
	
	-- list of props that need to be updated each frame if present
	local update_lazy_props = { 'tween_manager', 'dispatch', 'weave' }
	-- list of props and clean up methods that should be invoked on dispose
	local dispose_lazy_props = { view = 'remove_from_parent', event_handler = 'dispose', weave = 'clear', dispatch = 'clear', tween_manager = 'dispose' }

	function app_node:init()
		-- override this if required
	end
	
	function app_node:prepare()
		-- override this if required
	end
	
	function app_node:begin()
		-- override this if required
	end
	
	function app_node:add(child, view_parent)
		self.children:add(child)
		child:prepare()
		
		-- view_parent = false to not add, or this nodes view by default
		if view_parent == nil then
			view_parent = self.view
		end
		if view_parent then
			view_parent:add(child.view)
			-- begin is called only once the view is added
			child:begin()
		end
	end
	
	function app_node:add_button(clip, action)
		local button = button(clip, action)
		self:add_disposable(button)
		return button
	end
	
	function app_node:add_touch_area(display_object, padding, event_dispatch)
		local ta = touch_area.bounds(display_object, padding, event_dispatch)
		self:add_disposable(ta)
		return ta
	end
	
	function app_node:add_touch_area_rect(display_object, x, y, width, height, event_dispatch)
		local ta = touch_area.rect(display_object, x, y, width, height, event_dispatch)
		self:add_disposable(ta)
		return ta
	end
	
	function app_node:add_disposable(disposable)
		self.disposables:push(disposable)
	end
	
	function app_node:tween(target, easing, properties, on_complete)
		local t = tween(target, easing, properties, on_complete)
		self.tween_manager:add(t)
		return t
	end
	
	-- require_spritesheet
	
	function app_node:remove(child)
		if self.children:remove(child) then
			child:dispose()
		end
	end
	
	function app_node:update(...)
		-- update managed lazy property objects if present
		for _, prop in ipairs(update_lazy_props) do
			local obj = rawget(self, prop)
			if obj then
				obj:update()
			end
		end
		
		-- update all children
		local children = rawget(self, 'children')
		if children then
			-- update set is safe to update during this method
			children:update(function (child, ...)
				child:update(...)
			end, ...)
		end
	end

	function app_node:dispose()
		local children = rawget(self, 'children')
		if children then
			for _, child in ipairs(children) do
				child:dispose()
			end
			children:clear()
			self.children = nil
		end
		
		for prop, dispose_method in pairs(dispose_lazy_props) do
			local obj = rawget(self, prop)
			if obj then
				obj[dispose_method](obj)
				rawset(self, prop, nil)
			end
		end
		
		local disposables = rawget(self, 'disposables')
		if disposables then
			for _, disposable in ipairs(disposables) do
				if type(disposable) == 'function' then
					disposable()
				elseif disposable.dispose then
					disposable:dispose()
				else
					error('cannot dispose ' .. tostring(disposable))
				end
			end
			self.disposables = nil
		end
	end

end)