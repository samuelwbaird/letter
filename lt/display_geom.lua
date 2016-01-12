-- module of functions for handling transform data
--
-- Lua has a registered based intepreter and multiple return values
-- this makes it more efficient to treat transform and geometry
-- as unpacked values (although this is less convenient in code)
--
-- as this is working with simple scale, rotate transform values in
-- the main love drawing methods, these transform types use those
-- sort of values instead of an affine or 3D matrix
--
-- copyright 2016 Samuel Baird MIT Licence


local module = require('core.module')

return module(function (display_geom)
	
	-- unpacked types
	-- transform		x, y, scale_x, scale_y, rotation, alpha
	-- point_transform	x, y, scale_x, scale_y, rotation
	-- point			x, y
	-- rect				x, y, width, height
	
	-- handling transforms
	-- eventually move to an affine or 3D transform matrix, but for now...
	-- handle as unpacked values, x, y , scale_x, scale_y, rotation (radian), alpha (0 - 1)
	-- this is a bit cumbersome but cuts down on temporary objects significantly and should run well
	
	function display_geom.multiply_transform(tr_x, tr_y, tr_scale_x, tr_scale_y, tr_rotation, tr_alpha, x, y, scale_x, scale_y, rotation, alpha)
		-- handle different if parent rotation is involved
		if tr_rotation == 0 then
			return 
				tr_x + (tr_scale_x * x),
				tr_y + (tr_scale_y * y),
				tr_scale_x * scale_x,
				tr_scale_y * scale_y,
				tr_rotation + rotation,
				tr_alpha * alpha
		else
			local c = math.cos(tr_rotation)
			local s = math.sin(tr_rotation)
			return 
				tr_x + (tr_scale_x * x * c) - (tr_scale_y * y * s),
				tr_y + (tr_scale_y * y * c) + (tr_scale_x * x * s),
				tr_scale_x * scale_x,
				tr_scale_y * scale_y,
				tr_rotation + rotation,
				tr_alpha * alpha
		end
	end
	
	function display_geom.transform_position(tr_x, tr_y, tr_scale_x, tr_scale_y, tr_rotation, x, y)
		-- handle different if parent rotation is involved
		if tr_rotation == 0 then
			return 
				tr_x + (tr_scale_x * x),
				tr_y + (tr_scale_y * y)
		else
			local c = math.cos(tr_rotation)
			local s = math.sin(tr_rotation)
			return 
				tr_x + (tr_scale_x * x * c) - (tr_scale_y * y * s),
				tr_y + (tr_scale_y * y * c) + (tr_scale_x * x * s)
		end
	end
	
	function display_geom.untransform_position(tr_x, tr_y, tr_scale_x, tr_scale_y, tr_rotation, x, y)
		-- handle different if parent rotation is involved
		if tr_rotation == 0 then
			return 
				(x - tr_x) / tr_scale_x,
				(y - tr_y) / tr_scale_y
		else
			local c = math.cos(-tr_rotation)
			local s = math.sin(-tr_rotation)
			x = (x - tr_x) / tr_scale_x
			y = (y - tr_y) / tr_scale_y
			return 
				(tr_scale_x * x * c) - (tr_scale_y * y * s),
				(tr_scale_y * y * c) + (tr_scale_x * x * s)
		end
	end
	
	function display_geom.rect_expand_to_include_point(x, y, width, height, px, py)
		if not x then
			return px, py, 0, 0
		end
		
		if px < x then
			width = (x + width) - px
			x = px
		elseif px > x + width then
			width = px - x
		end
		
		if py < y then
			height = (y + height) - py
			y = py
		elseif py > y + height then
			height = py - y
		end
		
		return x, y, width, height
	end
	
	function display_geom.rect_pad(x, y, width, height, pad_x, pad_y)
		pad_y = pad_y or pad_x		
		return x - pad_x, y - pad_y, width + (pad_x * 2), height + (pad_y * 2)
	end
	
	function display_geom.rect_contains_point(x, y, width, height, px, py)
		return px >= x and py >= y and px <= x + width and py <= y + height
	end
	
	function display_geom.point_distance(x1, y1, x2, y2)
		local x = x2 - x1
		local y = y2 - y1
		return ((x * x) + (y * y)) ^ 0.5
	end
	
end)