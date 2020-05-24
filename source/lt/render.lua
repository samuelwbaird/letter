-- the render object is passed through the change of display objects
-- to handle automatically batching sprites where possible
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local math = require('core.math')

return class(function (render)

	function render:init()
		self.sprite_batch = nil
		self.has_batched_data = false
	end
	
	-- overall render control ------------------
	
	function render:begin_render()
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.origin()	
	end

	function render:complete_render()
		if self.has_batched_data then
			self:flush_batch()
		end
		love.graphics.present()	
	end
	
	-- unbatched graphics -------------------
	
	function render:draw_rect(rect, rx, ry, rscale_x, rscale_y, rr, ra)
		self:begin_unbatched(rx, ry, rscale_x, rscale_y, rr)
		love.graphics.setColor(rect.color:unpack_with_alpha(ra))
		love.graphics.rectangle("fill", 0, 0, rect.width, rect.height)
	end
	
	function render:draw_circle(circle, rx, ry, rscale_x, rscale_y, rr, ra)
		self:begin_unbatched(rx, ry, rscale_x, rscale_y, rr)
		love.graphics.setColor(circle.color:unpack_with_alpha(ra))
		love.graphics.circle("fill", 0, 0, circle.radius, math.clamp(circle.radius * 0.25, 30, 100))
	end

	function render:draw_label(label, rx, ry, rscale_x, rscale_y, rr, ra)
		-- internally fonts may be at a different scale (eg. due to retina)
		local asset_scale = label.font.asset_scale
	
		self:begin_unbatched(rx, ry, rscale_x / asset_scale, rscale_y / asset_scale, rr)
		love.graphics.setFont(label.font:cached_font_object())
		love.graphics.setColor(label.font.color:unpack_with_alpha(ra))
	
		if label.align == 'center' then
			love.graphics.printf(label.text, label.wrap_width * -0.5 * asset_scale, 0, label.wrap_width * asset_scale, label.align)
		elseif label.align == 'right' then
			love.graphics.printf(label.text, label.wrap_width * -1 * asset_scale, 0, label.wrap_width * asset_scale, label.align)
		else
			love.graphics.printf(label.text, 0, 0, label.wrap_width * asset_scale, label.align)
		end
	end
	
	-- batched images ------------------------
	
	function render:draw_quad(texture, quad, rx, ry, rr, rscale_x, rscale_y, ox, oy, ra)
		if not self.sprite_batch then
			self.sprite_batch = love.graphics.newSpriteBatch(texture)
		elseif self.sprite_batch:getTexture() ~= texture then
			if self.has_batched_data then
				self:flush_batch()
			end
			self.sprite_batch:setTexture(texture)
		end
		
		self.has_batched_data = true
		self.sprite_batch:setColor(1, 1, 1, ra)
		self.sprite_batch:add(quad, rx, ry, rr, rscale_x, rscale_y, ox, oy)
	end	
	
	function render:begin_unbatched(rx, ry, rscale_x, rscale_y, rotation)
		if self.has_batched_data then
			self:flush_batch()
		end
	
		local g = love.graphics
		g.origin()
		g.translate(rx, ry)
		g.scale(rscale_x, rscale_y)
		g.rotate(rotation)
	end
	
	function render:flush_batch()
		if self.has_batched_data then
			love.graphics.origin()
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.draw(self.sprite_batch)
			
			self.sprite_batch:clear()
			self.has_batched_data = false
		end
	end

end)