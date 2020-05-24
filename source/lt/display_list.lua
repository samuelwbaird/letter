-- implements a basic display list (in the style of the Actionscript 3 display list)
-- with display_list, text, image, clip, rect and circle objects
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')
local math = require('core.math')

local resources = require('lt.resources')
local display_data = require('lt.display_data')
local display_geom = require('lt.display_geom')

-- direct upvalues for these functions (slightly faster)
local multiply_transform = display_geom.multiply_transform
local transform_position = display_geom.transform_position
local untransform_position = display_geom.untransform_position
local rect_expand_to_include_point = display_geom.rect_expand_to_include_point

local display_list = class(function (display_list)

	-- main display object class
	-- implementing a list/tree of nested display objects
	
	-- derived class implementing
	-- text (with font and size)
	-- image (from atlas or separate with offset)
	-- clip (display clip_data)
	-- rect and circle
	-- TODO: mask_rect
	-- TODO: custom (with pre, inner and post render callbacks)
	
	function display_list:init(init_values)
		self.name = nil
		self.parent = nil
		
		self.x = 0
		self.y = 0
		self.scale_x = 1
		self.scale_y = 1
		self.rotation = 0
		self.alpha = 1
		self.visible = true
		
		if init_values then
			for k, v in pairs(init_values) do
				self[k] = v
			end
		end
	end
	
	-- instantiate children only when required
	display_list:add_lazy_property('children', array)
	
	-- convenient property syntax
	display_list:add_property('scale',
		function (self)
			return (self.scale_x + self.scale_y) * 0.5
		end,
		function (self, value)
			self.scale_x, self.scale_y = value, value
		end)

	-- list -------------------------------------------
	
	function display_list:add(display)
		if display.parent then
			display:remove_from_parent()
		end
		self.children:push(display)
		display.parent = self
	end
	
	function display_list:add_at_index(display, index)
		if display.parent then
			display:remove_from_parent()
		end
		table.insert(self.children, index, display)
		display.parent = self
	end
	
	function display_list:send_to_front(display)
		if display then
			if display.parent then
				display:remove_from_parent()
			end
			self:add_at_index(display, #self.children + 1)
		
		elseif self.parent then
			self.parent:send_to_front(self)
		end
	end
	
	function display_list:send_to_back(display)
		if display then
			if display.parent then
				display:remove_from_parent()
			end
			self:add_at_index(display, 1)
			
		elseif self.parent then
			self.parent:send_to_back(self)
		end
	end
	
	function display_list:remove(display)
		if display.parent == self then
			self.children:remove_element(display)
			display.parent = nil
		end
	end
	
	function display_list:remove_from_parent()
		if self.parent then
			self.parent:remove(self)
		end
	end
	
	function display_list:remove_all_children()
		local children = rawget(self, 'children')
		if children then
			for _, child in ipairs(children) do
				child.parent = nil
			end
			rawset(self, 'children', nil)
		end
	end
	
	-- transforms and co-ords -------------------------
	
	function display_list:transform()
		return self.x, self.y, self.scale_x, self.scale_y, self.rotation, self.alpha
	end
	
	function display_list:world_transform()
		if self.parent then
			local px, py, psx, psy, pr, pa = self.parent:world_transform()
			return multiply_transform(
				px, py, psx, psy, pr, pa,
				self.x, self.y, self.scale_x, self.scale_y, self.rotation, self.alpha
			)
		else
			return self.x, self.y, self.scale_x, self.scale_y, self.rotation, self.alpha
		end
	end
	
	function display_list:local_to_world(x, y)
		local px, py, psx, psy, pr, pa = self:world_transform()		
		return transform_position(px, py, psx, psy, pr, x, y)
	end
	
	function display_list:world_to_local(x, y)
		local px, py, psx, psy, pr, pa = self:world_transform()		
		return untransform_position(px, py, psx, psy, pr, x, y)
	end
	
	-- handling bounds ----------------------------------
	
	-- taking the same unpacked approach for now to handling bounds
	-- left, right, width, height
	
	function display_list:bounds(reference)
		-- get bounds without reference
		local x, y, width, height = self:content_bounds()
		-- expand the bounds to fit all children recursively
		local children = rawget(self, 'children')
		if children then
			for _, child in ipairs(children) do
				local cx, cy, cwidth, cheight = child:bounds()
				if cx then
					local tx, ty, tsx, tsy, tr = child.x, child.y, child.scale_x, child.scale_y, child.rotation
					-- transform into this space and expand current bounds by each corner
					x, y, width, height = rect_expand_to_include_point(x, y, width, height, transform_position(tx, ty, tsx, tsy, tr, cx, cy))
					x, y, width, height = rect_expand_to_include_point(x, y, width, height, transform_position(tx, ty, tsx, tsy, tr, cx + cwidth, cy))
					x, y, width, height = rect_expand_to_include_point(x, y, width, height, transform_position(tx, ty, tsx, tsy, tr, cx + cwidth, cy + cheight))
					x, y, width, height = rect_expand_to_include_point(x, y, width, height, transform_position(tx, ty, tsx, tsy, tr, cx, cy + cheight))
				end
			end
		end
		
		if reference == nil or reference == self then
			return x, y, width, height
		elseif not x then
			return nil
		else
			-- if a reference is supplied then transform these bounds into that reference
			local points = { { x, y }, { x + width, y }, { x + width, y + height }, { x, y + height } }
			local fx, fy, fsx, fsy, fr = self:world_transform()
			local tx, ty, tsx, tsy, tr = reference:world_transform()		
			-- transform each point and create a rect to fit
			x, y, width, height = nil, nil, nil, nil
			for index, point in ipairs(points) do
				local wx, wy = transform_position(fx, fy, fsx, fsy, fr, point[1], point[2])
				x, y, width, height = rect_expand_to_include_point(x, y, width, height, untransform_position(tx, ty, tsx, tsy, tr, wx, wy))
			end
			return x, y, width, height
		end
	end
	
	function display_list:content_bounds()
		-- get bounds without any reference point
		-- derived classes should implement only this method
		return nil
	end

	-- render -----------------------------------------
	
	function display_list:update_animated_clips()
		if self.update then
			self:update()
		end
		
		local children = rawget(self, 'children')
		if children then
			for _, child in ipairs(children) do
				child:update_animated_clips()
			end
		end
	end
	
	function display_list:render(renderer, px, py, psx, psy, pr, pa)
		if not self.visible then
			return
		end
	
		-- calculate the derived transform to pass onto any children being rendered
		local rt1, rt2, rt3, rt4, rt5, rt6 = multiply_transform(
			px, py, psx, psy, pr, pa,
			self.x, self.y, self.scale_x, self.scale_y, self.rotation, self.alpha
		)
		
		if rt6 < 0.01 then
			return
		end
		
		-- specific rendering required for this display list object
		local inner = self.render_inner
		if inner then
			inner(self, renderer, rt1, rt2, rt3, rt4, rt5, rt6)
		end
		-- render children
		local children = rawget(self, 'children')
		if children then
			for _, child in ipairs(children) do
				child:render(renderer, rt1, rt2, rt3, rt4, rt5, rt6)
			end
		end
	end
	
end)

-- derived type holding image content (from a texture map)

local image = class.derive(display_list, function (image)
	
	function image:init(name_or_image_data, init_values)
		display_list.init(self, init_values)
		
		if display_data.image_data.has_instance(name_or_image_data) then
			self.image_data = name_or_image_data
		elseif type(name_or_image_data) == 'string' then			
			self.image_data = assert(resources.get_image_data(name_or_image_data), 'missing image data ' .. name_or_image_data)
		else
			error('invalid image data')
		end
	end

	function image:render_inner(renderer, rx, ry, rscale_x, rscale_y, rr, ra)
		renderer:draw_quad(self.image_data.texture, self.image_data.quad, rx, ry, rr, rscale_x, rscale_y, self.image_data.ox, self.image_data.oy, ra)
	end

	function image:content_bounds()
		return self.image_data:bounds()
	end
	
end)

-- derived type displaying clip_data content

local clip = class.derive(display_list, function (clip)
	
	-- override this for on_complete callbacks to occur after the animation updates have occurred
	clip.delayed_on_complete_callback = function (action)
		action()
	end
	
	function clip:init(name_or_clip_data, init_values)
		display_list.init(self, init_values)
		
		if display_data.clip_data.has_instance(name_or_clip_data) then
			self.clip_data = name_or_clip_data
		elseif type(name_or_clip_data) == 'string' then			
			self.clip_data = assert(resources.get_clip_data(name_or_clip_data), 'missing clip data ' .. name_or_clip_data)
		else
			error('invalid clip data')
		end
		
		self.playback_speed = 1
		self.playback_position = 1
		
		self.is_playing = false
		self.start_frame = 1
		self.end_frame = #self.clip_data.frames
		self.loop = true
		
		self.current_frame = nil
		self:set_frame(self.clip_data.frames[1])
	end
	
	display_list:add_property('no_frames', function (self)
		return #self.clip_data.frames
	end)
	
	-- first two args can be start and end frame numbers
	-- any other args can be loop Y/N, frame label or on_complete
	function clip:play(arg1, arg2, arg3, arg4)
		local goto_frame = nil
		
		self.is_playing = true
		self.on_complete = nil
		
		local label_was_set = false
		local loop_was_set = false
		local on_complete_was_set = false
		
		-- check for string labels, booleans and functions
		local args = { arg1, arg2, arg3, arg4 }
		for _, arg in ipairs(args) do
			if type(arg) == 'boolean' then
				loop_was_set = true
				self.loop = arg
			elseif type(arg) == 'string' then
				if label_was_set then
					error('only one label string argument is allowed', 2)
				else
					if not loop_was_set then
						self.loop = false
					end
					local frames = self.clip_data.labels[arg]
					if not frames then
						error('unknown frame ' .. label .. ' in clip ' .. self.clip_data.name)
					end
					self.start_frame = frames[1]
					self.end_frame = frames[2]
					label_was_set = true
				end
			elseif type(arg) == 'function' then
				if on_complete_was_set then
					error('only one on_complete function argument is allowed', 2)
				else
					if not loop_was_set then
						self.loop = false
					end
					self.on_complete = arg
					on_complete_was_set = true
				end
			end
		end
		
		-- check for start and end labels specified as numbers
		if type(arg1) == 'number' and type(arg2) == 'number' then
			if label_was_set then
				error('cannot set a label and numeric frames', 2)
			else
				self.start_frame = arg1
				self.end_frame = arg2
			end
		end
		
		if self.loop and self.on_complete then
			error('on_complete will not be used with looping animation', 2)
		end
	end
	
	function clip:goto(label_or_number)
		if type(label_or_number) == 'number' then
			self.start_frame = label_or_number
			self.end_frame = label_or_number
		else
			local frames = self.clip_data.labels[label_or_number or 'all']
			if not frames then
				error('unknown frame ' .. label .. ' in clip ' .. self.clip_data.name)
			end
			self.start_frame = frames[1]
			self.end_frame = frames[1]
		end

		self.is_playing = false
		self:set_frame(self.clip_data.frames[self.start_frame])
	end
	
	function clip:stop()
		self.is_playing = false
	end
	
	function clip:update()
		-- update animation pointer by one frame
		if self.is_playing then
			-- update the playback position
			self.playback_position = self.playback_position + self.playback_speed
			if self.playback_position > self.end_frame then
				if self.loop then
					while self.playback_position >= self.end_frame do
						self.playback_position = self.playback_position - ((self.end_frame - self.start_frame) + 1)
					end
				else
					self.playback_position = self.end_frame
					self.is_playing = false
				end				
			end
			
			local frame = self.clip_data.frames[math.floor(self.playback_position)]
			if frame ~= self.current_frame then
				self:set_frame(frame)
			end
			
			if not self.is_playing then
				if self.on_complete then
					local temp = self.on_complete
					self.on_complete = nil
					clip.delayed_on_complete_callback(function ()
						temp(self)
					end)
				end
			end
		end
	end
	
	function clip:set_frame(frame)
		self.current_frame = frame;
		-- retain a list of current content (re-use objects where they match)
		local current = {}
		local remove = {}
		for index, child in ipairs(self.children) do
			if child.name then
				current[child.name] = child
			else
				current['__' .. index] = child
			end
		end

		-- recreate the child display list, re-using objects
		for index, content in ipairs(frame.content) do
			local child = current[content.instance]
			if child then
				-- move it to the correct index
				self.children[index] = child
				-- make sure this is not removed later
				current[content.instance] = nil				
			else
				-- create a new child clip
				if content.image_data then
					child = image(content.image_data)
				elseif content.clip_data then
					child = clip(content.clip_data)
					-- if frame is not specified then the sub clip should play
					if not content.frame_no then
						child:play()
					end
				end
				child.parent = self
				self.children[index] = child
			end
			
			-- apply the new transform
			child.x = content.x
			child.y = content.y
			child.scale_x = content.scale_x
			child.scale_y = content.scale_y
			child.rotation = content.rotation
			child.alpha = content.alpha
			if content.frame_no then
				child:goto_and_stop(content.frame_no)
			end
		end
		
		-- trim extra child references
		for index = #self.children, #frame.content + 1, -1 do
			self.children[index] = nil
		end
		for _, child in pairs(current) do
			child.parent = nil
		end
	end
	
end)

-- derived type rendering a rectangle

local rect = class.derive(display_list, function (rect)
	
	function rect:init(width, height, color, init_values)
		display_list.init(self, init_values)
		self.width = width
		self.height = height
		self.color = color or display_data.color.white
	end
	
	function rect:render_inner(renderer, rx, ry, rscale_x, rscale_y, rr, ra)
		renderer:draw_rect(self, rx, ry, rscale_x, rscale_y, rr, ra)
	end
	
	function rect:content_bounds()
		return 0, 0, self.width, self.height
	end
	
end)

-- derived type rendering a circle

local circle = class.derive(display_list, function (circle)
	
	function circle:init(radius, color, init_values)
		display_list.init(self, init_values)
		self.radius = radius
		self.color = color or display_data.color.white
	end
	
	function circle:render_inner(renderer, rx, ry, rscale_x, rscale_y, rr, ra)
		renderer:draw_circle(self, rx, ry, rscale_x, rscale_y, rr, ra)
	end
	
	function circle:content_bounds()
		return -self.radius, -self.radius, self.radius * 2, self.radius * 2
	end
	
end)

local label = class.derive(display_list, function (label)
	
	function label:init(font, init_values)
		-- allow these to be override by init_values
		self.align = "center"
		self.wrap_width = 10000
		
		display_list.init(self, init_values)

		self.font = font or display_data.font.default
	end
	
	function label:render_inner(renderer, rx, ry, rscale_x, rscale_y, rr, ra)
		if self.text then
			renderer:draw_label(self, rx, ry, rscale_x, rscale_y, rr, ra)
		end
	end
	
	function label:content_bounds()
		local font = self.font:cached_font_object()
		
		-- internally fonts may be at a different scale (eg. due to retina)
		local asset_scale = self.font.asset_scale
		
		local width, lines = font:getWrap(self.text, self.wrap_width * asset_scale)
		local offset = 0
		if self.align == 'center' then
			offset = width * -0.5
		elseif self.align == 'right' then
			offset = width * -1
		end
		
		return 
			(offset) / asset_scale,
			0, 
			width / asset_scale,
			((lines and #lines or 1) * (font:getLineHeight() or 1) * (font:getHeight() or font.size)) / asset_scale
	end
	
end)

-- create a reference from each class to add each other class
local all_classes = {
	display_list = display_list,
	image = image,
	clip = clip,
	rect = rect,
	circle = circle,
	label = label,
}
for name, class in pairs(all_classes) do
	for other_name, other_class in pairs(all_classes) do
		class['add_' .. other_name] = function (dl, ...)
			local child = other_class(...)
			dl:add(child)
			return child
		end
	end
end

return class.package(all_classes, display_list)