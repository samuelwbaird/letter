-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local platform = require('lt.moonshine.platform')

return class(function (render)
	
	function render:init()
	end
	
	function render:begin_render()
	end
	
	function render:complete_render()
	end
	
	function render:draw_quad(texture, quad, rx, ry, rr, rscale_x, rscale_y, ox, oy, ra)
		platform.graphics.draw_quad(
				texture.url, quad[1], quad[2], quad[3], quad[4], 
				-ox, -oy, quad[5], quad[6],
				rx, ry, rscale_x, rscale_y)
	end
	
	function render:draw_rect(rect, rx, ry, rscale_x, rscale_y, rr, ra)
	end
	
	function render:draw_circle(circle, rx, ry, rscale_x, rscale_y, rr, ra)
	end

	function render:draw_label(label, rx, ry, rscale_x, rscale_y, rr, ra)
	end
	
end)