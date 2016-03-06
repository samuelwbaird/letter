-- an example of adding child nodes to an app node
-- this app node manages a moving tiled layer as a background effect
-- note that lt.display_list will batch contigious renders from the same texture
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local app_node = require('lt.app_node')
local tween = require('lt.tween')

return class.derive(app_node, function (tiled_background)
	
	function tiled_background:prepare()
	end
	
	function tiled_background:begin()
		self.tiles = self.view:add_display_list()
		for ty = -2, 2 do
			for tx = -2, 2 do
				self.tiles:add_image('background_tile', { x = tx * 255, y = ty * 191 })
			end
		end
		self:keep_moving()
	end
	
	function tiled_background:keep_moving()
		self:tween(self.tiles, tween.easing.ease_inout(math.random(60 * 3, 60 * 20)), {
			x = math.random(-100, 100),
			y = math.random(-100, 100),
			rotation = math.random(-1, 1) * math.pi * 0.1,
			scale = math.random() * 0.5 + 0.75,
			-- weird perspective illusion
			-- scale_x = math.random() * 0.5 + 0.75,
			-- scale_y = math.random() * 0.5 + 0.75,
		}, function ()
			self:keep_moving()
		end)
	end
	
end)