-- altered for web build via punchdrunk and moonshine vm
-- the render object is passed through the change of display objects
-- sprite batching is not available
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')

return class(function (render)

	function render:init()
	end
	
	-- overall render control ------------------
	
	function render:begin_render()
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.origin()	
	end

	function render:complete_render()
	end

	-- individual render ------------------------
	
	function render:begin_unbatched(rx, ry, rscale_x, rscale_y, rotation)
		local g = love.graphics
		g.origin()
		g.translate(rx, ry)
		g.scale(rscale_x, rscale_y)
		g.rotate(rotation)
	end
	
	function render:draw_batched_quad(texture, quad, rx, ry, rr, rscale_x, rscale_y, ox, oy, ra)
		-- no batching available
		-- set color , ra
		love.graphics.draw(texture, quad, rx, ry, rr, rscale_x, rscale_y, ox, oy)
	end	
	
	function render:flush_batch()
	end

end)