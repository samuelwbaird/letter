-- the render object is passed through the change of display objects
-- to handle automatically batching sprites where possible
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')

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

	-- individual render ------------------------
	
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
	
	function render:draw_batched_quad(texture, quad, rx, ry, rr, rscale_x, rscale_y, ox, oy, ra)
		if not self.sprite_batch then
			self.sprite_batch = love.graphics.newSpriteBatch(texture)
		elseif self.sprite_batch:getTexture() ~= texture then
			if self.has_batched_data then
				self:flush_batch()
			end
			self.sprite_batch:setTexture(texture)
		end
		
		self.has_batched_data = true
		self.sprite_batch:setColor(255, 255, 255, ra * 255)
		self.sprite_batch:add(quad, rx, ry, rr, rscale_x, rscale_y, ox, oy)
	end	
	
	function render:flush_batch()
		if self.has_batched_data then
			love.graphics.origin()
			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.draw(self.sprite_batch)
			
			self.sprite_batch:clear()
			self.has_batched_data = false
		end
	end

end)