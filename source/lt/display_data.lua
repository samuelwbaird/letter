-- a package of classes for describing display data
-- these classes are used by the display list objects and the resource loaded
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')
local math = require('core.math')
local cache = require('core.cache')

-- color

local color = class(function (color)

	
	function color:init(r, g, b, alpha)
		self.r = r or 0 
		self.g = g or 0
		self.b = b or 0
		self.alpha = alpha or 1
	end
	
	function color:unpack_with_alpha(alpha)
		return self.r, self.g, self.b, self.alpha * alpha * 255
	end

	color.white = color(255, 255, 255)
	color.black = color(0, 0, 0)
	color.clear = color(0, 0, 0, 0)
	
	color.grey = function (grey_level)
		return color(grey_level, grey_level, grey_level)
	end
	
end)

-- font

local font = class(function (font)

	font.default_font_name = nil
	font.default_asset_scale = 1

	function font:init(font_size, font_name, font_color, font_asset_scale)
		self.size = font_size or 12
		self.name = font_name or font.default_font_name
		self.color = font_color or color.black
		self.asset_scale = font_asset_scale or font.default_asset_scale
	end
	
	local font_cache = cache(8)

	function font:cached_font_object()
		local key = (self.name or '') .. ':' .. self.size
		local obj = font_cache:get(key)
		if not obj then
			if self.name then
				obj = love.graphics.newFont(self.name, self.size * self.asset_scale)
			else
				obj = love.graphics.newFont(self.size * self.asset_scale)
			end
			font_cache:set(key, obj)
		end
		return obj
	end
	
	font.default = font()
	
end)


-- single image within a texture

local image_data = class(function(image_data)

	function image_data:init(name, texture, quad, xy)
		self.name = name
		self.texture = texture
		self.quad = quad
		self.xy = xy
		self.ox = -xy[1]
		self.oy = -xy[2]
	end

	function image_data:bounds()
		local xy = self.xy
		return xy[1], xy[2], xy[3] - xy[1], xy[4] - xy[2]
	end

end)

-- clip data, a sequence of frames, each with arbitrary sub-content

local clip_data = class(function (clip_data)
	
	function clip_data:init(name)
		self.name = name
		self.frames = array()
		self.labels = {}
	end
	
	local clip_frame = class(function (clip_frame)		
		function clip_frame:init(label)
			self.label = label
			self.content = array()
		end
		
		function clip_frame:generate_instance(name, data)
			local count = 1
			for _, c in ipairs(self.content) do
				if c.image_data == data or c.clip_data == data then
					count = count + 1
				end
			end
			return '_' .. name .. '_' .. count
		end
		
		function clip_frame:add_image_content(instance, image_data, x, y, scale_x, scale_y, rotation, alpha)
			-- generate an instance name automatically if not supplied
			if not instance then
				instance = self:generate_instance('img_' .. image_data.name, image_data)
			end
			local entry = {
				instance = instance,
				image_data = image_data,
				x = x or 0,
				y = y or 0,
				scale_x = scale_x or 1,
				scale_y = scale_y or 1,
				rotation = rotation or 0,
				alpha = alpha or 1,
			}
			self.content:push(entry)
			return self
		end
		
		function clip_data:add_clip_content(instance, clip_data, x, y, scale_x, scale_y, rotation, alpha, frame_no)				
			-- generate an instance name automatically if not supplied
			if not instance then
				instance = self:generate_instance('clip_' .. clip_data.name, clip_data)
			end
			local entry = {
				instance = instance,
				clip_data = clip_data,
				x = x or 0,
				y = y or 0,
				scale_x = scale_x or 1,
				scale_y = scale_y or 1,
				rotation = rotation or 0,
				alpha = alpha or 1,
				frame_no = frame_no,
			}
			self.content:push(entry)
			return self
		end
	end)
	
	function clip_data:add_frame(label)
		local frame = clip_frame(label)
		self.frames:push(frame)
		return frame
	end
	
	function clip_data:link_resources(resources)		
		-- generate start and end points for all frame labels as go through
		self.labels['all'] = { 1, #self.frames }
		
		local tracking_label = nil

		for frame_no, frame in ipairs(self.frames) do
			
			if frame.label then
				tracking_label = { frame_no, frame_no }
				self.labels[frame.label] = tracking_label
			elseif tracking_label then
				-- make sure end frame is stored for last tracked label
				tracking_label[2] = frame_no
			end
			
			-- link image_data and clip_data objects directly
			for _, c in ipairs(frame.content) do
				if c.image_data and type(c.image_data) == 'string' then
					c.image_data = resources.get_image_data(c.image_data)
				end
				if c.clip_data and type(c.clip_data) == 'string' then
					c.clip_data = resources.get_clip_data(c.clip_data)
				end
			end
		end		
	end
	
end)

return class.package({
	color = color,
	font = font,
	image_data = image_data,
	clip_data = clip_data,
})