-- a basic button class implementing iOS style up and down areas
-- by default the button display object will be expected to be a clip with two frames
-- up and down, however the up_frame and down_frame properties can be overridden
-- including setting them to functions that should be used as callbacks when
-- the button logically enters up or down state
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local geom = require('lt.display_geom')
local touch_area = require('lt.touch_area')

return class(function (button)

	-- static button properties shared by all buttons ---------------------
	
	-- override this with a function that delays the action by 1 frame to allow graphics updates
	button.delayed_action_callback = function (action)
		action()
	end
	
	-- override these functions to provide universal button click sounds if required
	button.on_button_down = function () end
	button.on_button_up = function () end
	
	-- static properties
	button.touch_out_padding = 20	-- how much extra logical space to allow on the outer touch area
	
	-- constructor --------------------------------------------------------
	
	function button:init(clip, action, event_dispatch)
		-- base properties for a button
		self.clip = clip
		self.action = action
		self.event_dispatch = event_dispatch
		
		-- override these properties if required
		self.up_frame = 1
		self.down_frame = 2
		self.is_down = false
		self.is_releasing = false
		
		self.touch_area_inner = touch_area.bounds(clip, 0, event_dispatch)
		self.touch_area_outer = touch_area.bounds(clip, button.touch_out_padding, event_dispatch)
		
		self.touch_area_inner.on_touch_begin = function () self:update() end
		self.touch_area_inner.on_touch_move = function () self:update() end
		self.touch_area_inner.on_touch_end = function () self:update() end

		self.touch_area_outer.on_touch_begin = function () self:update() end
		self.touch_area_outer.on_touch_move = function () self:update() end
		self.touch_area_outer.on_touch_end = function () self:handle_button_release() end
	end
	
	button:add_property('enabled',
		function (self)
			return self.touch_area_inner and self.touch_area_inner.enabled
		end,
		function (self, value)
			if self.touch_area_inner then
				self.touch_area_inner.enabled = value
				self.touch_area_outer.enabled = value
			end
			self:update()
		end)
		
	button:add_property('visible', function (self)
		local function is_display_object_visible(display_object)
			if not display_object.visible or display_object.alpha < 0.01 then
				return false
			end
		
			if display_object.parent then
				return is_display_object_visible(display_object.parent)
			else
				return true
			end
		end
		return is_display_object_visible(self.clip)
	end)

	function button:update()
		if self.enabled and self.visible and self.touch_area_inner.is_touched and self.touch_area_outer.is_touch_over and not self.is_releasing then
			if not self.is_down then
				self.is_down = true
				button.on_button_down()
				if type(self.down_frame) == 'function' then
					self.down_frame(self)
				else
					self.clip:goto(self.down_frame)
				end
			end
		else
			if self.is_down then
				self.is_down = false
				button.on_button_up()
				if type(self.up_frame) == 'function' then
					self.up_frame(self)
				else
					self.clip:goto(self.up_frame)
				end
			end
		end
	end
	
	function button:handle_button_release()
		if self.is_releasing then return end

		if self.is_down then
			self.is_releasing = true
			self:update()
		
			button.delayed_action_callback(function ()
				self.action(self)
				self.is_releasing = false
			end)
		end
	end
	
	function button:cancel_touch()
		if self.is_releasing then return end
		
		if self.touch_area_inner then
			self.touch_area_inner:cancel_touch()
		end
		if self.touch_area_outer then
			self.touch_area_outer:cancel_touch()
		end
		
		self:update()
	end

	function button:dispose()
		if self.touch_area_inner then
			self.touch_area_inner:dispose()
			self.touch_area_inner = nil
		end
		if self.touch_area_outer then
			self.touch_area_outer:dispose()
			self.touch_area_outer = nil
		end
		self.clip = nil
		self.action = nil
	end

end)