local class = require('core.class')
local app_node = require('lt.app_node')

return class.derive(app_node, function (preload_scene)
	function preload_scene:begin()
		print('preload_scene')
		-- preload the images we'll required
		platform.graphics.require_image("assets/output/title_1_x2.png");
		platform.graphics.require_image("assets/output/game_1_x2.png");
	end
	
	function preload_scene:update()
		-- load the title scene when its assets are ready
		if platform.graphics.require_image("assets/output/title_1_x2.png") then
			app:set_scene('game.title_scene')
		end
	end
	
end)
