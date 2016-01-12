-- a touch_area object receives touch events from an event_dispatch
-- converts them into a given co-ordinate space and then tracks touch
-- phase beginning moving and ending in that area
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local event_dispatch = require('lt.event_dispatch')
local geom = require('lt.display_geom')

return class(function (touch_area)

	-- static constructors

	function touch_area.bounds(display_object, padding, selected_event_dispatch)
		padding = padding or 0
		
		return touch_area(
			function (x, y)		-- point conversion
				return display_object:world_to_local(x, y)
			end,
			function (px, py)	-- area test
				local x, y, width, height = display_object:bounds()
				x, y, width, height = geom.rect_pad(x, y, width, height, padding)
				return geom.rect_contains_point(x, y, width, height, px, py)
			end,
			selected_event_dispatch)
	end

	function touch_area.rect(display_object, x, y, width, height, selected_event_dispatch)
		return touch_area(
			function (x, y)		-- point conversion
				return display_object:world_to_local(x, y)
			end,
			function (px, py)	-- area test
				return geom.rect_contains_point(x, y, width, height, px, py)
			end,
			selected_event_dispatch)
	end

	-- constructor
	
	function touch_area:init(point_conversion, area_test, selected_event_dispatch)
		self.point_conversion = point_conversion
		self.area_test = area_test
		self.event_handler = event_dispatch.event_handler(selected_event_dispatch)
		self.enabled = true
		
		-- initialise values
		self:cancel_touch()
		
		-- clients should supply these
		self.on_touch_begin = nil
		self.on_touch_move = nil
		self.on_touch_end = nil
	end

	function touch_area:cancel_touch()
		self.is_touched = false
		self.is_touch_over = false
		self.touch_id = nil
		
		self.touch_time = nil
		self.touch_position = nil
		
		self.touch_start_time = nil
		self.touch_start_position = nil
		
		self.drag_distance = nil
		self.move_distance = nil
	end

	touch_area:add_property('enabled',
		function (self)
			return self.event_handler.did_listen
		end,
		function (self, value)
			if value and not self.event_handler.did_listen then
				self.event_handler:listen('touch_begin', function (touch_data)
					self:handle_touch_begin(touch_data.id, touch_data.x, touch_data.y)
				end)
				self.event_handler:listen('touch_move', function (touch_data)
					self:handle_touch_move(touch_data.id, touch_data.x, touch_data.y)
				end)
				self.event_handler:listen('touch_end', function (touch_data)
					self:handle_touch_end(touch_data.id, touch_data.x, touch_data.y)
				end)
			elseif not value and self.event_handler.did_listen then
				self.event_handler:unlisten()
				self:cancel_touch()
			end
		end)
		
	touch_area:add_property('position', function (self)
		if self.touch_position then
			return unpack(self.touch_position)
		end
	end)
	
	function touch_area:handle_touch_begin(id, x, y)
		if self.touch_id then return end	 			-- already tracking a touch
		if not self.point_conversion then return end	-- no longer valid
		
		local x, y = self.point_conversion(x, y)
		local is_touch_over = self.area_test(x, y)
		if not is_touch_over then return end

		-- TODO: check for filtering and intercepts here

		self.is_touched = true
		self.is_touch_over = true
		self.touch_id = id
		
		self.touch_position = { x, y }
		self.touch_time = love.timer.getTime()
		
		self.touch_start_position = { x, y }
		self.touch_start_time = self.touch_time

		self.drag_distance = nil
		self.move_distance = nil
		
		if self.on_touch_begin then
			self.on_touch_begin(self)
		end
	end
	
	function touch_area:handle_touch_move(id, x, y)
		if self.touch_id ~= id then return end
		
		local x, y = self.point_conversion(x, y)
		self:update_values(x, y)
		
		if self.on_touch_move then
			self.on_touch_move(self)
		end
	end
	
	function touch_area:handle_touch_end(id, x, y)
		if self.touch_id ~= id then return end
	
		local x, y = self.point_conversion(x, y)
		self:update_values(x, y)
		
		if self.on_touch_end then
			self.on_touch_end(self)
		end
		
		self:cancel_touch()
	end
	
	function touch_area:update_values(x, y)
		local previous_position = self.touch_position
		
		self.is_touch_over = self.area_test(x, y)
		self.touch_position = { x, y }
		self.touch_time = love.timer.getTime()
		
		self.drag_distance = { x - self.touch_start_position[1], y - self.touch_start_position[2] }
		self.move_distance = { x - previous_position[1], y - previous_position[2] }
	end

	function touch_area:dispose()
		if self.event_handler then
			self.event_handler:dispose()
			self.event_handler = nil
		end
		self.on_touch_begin = nil
		self.on_touch_move = nil
		self.on_touch_end = nil
	end

end)