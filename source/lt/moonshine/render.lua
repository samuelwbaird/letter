-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')

return class(function (render)
	
	function render:init()
	end
	
	function render:begin_render()
	end
	
	function render:complete_render()
	end
	
	function render:draw_quad(texture, quad, rx, ry, rr, rscale_x, rscale_y, ox, oy, ra)
		print('draw_quad ' .. texture.url ..' ' .. rx .. ' ' .. ry)
	end
	
	function render:draw_rect(rect, rx, ry, rscale_x, rscale_y, rr, ra)
	end
	
	function render:draw_circle(circle, rx, ry, rscale_x, rscale_y, rr, ra)
	end

	function render:draw_label(label, rx, ry, rscale_x, rscale_y, rr, ra)
	end
	
end)