-- an example of a minimal scene
-- load resources including a two frame animation used as a button
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local app_node = require('lt.app_node')
local tween = require('lt.tween')

return class.derive(app_node, function (title_scene)
	
	function title_scene:prepare()
		app.resources.load_spritesheet('assets/output/', 'title')
	end
	
	function title_scene:begin()
		-- centered background
		local img = self.view:add_image('title_screen')
		local x, y, width, height = img:bounds()
		-- scale up on extreme screen sizes of aspect ratios
		if app.screen.width > width then
			img.scale_x = app.screen.width / width
		end
		if app.screen.height > height then
			img.scale_y = app.screen.height / height
		end		
		img.x = (app.screen.width - (width * img.scale_x)) * 0.5
		img.y = (app.screen.height - (height * img.scale_y)) * 0.5
	
		-- add the clip that will be used as the play button
		local button_clip = self.view:add_clip('play_button')
		button_clip.x = (app.screen.width - 160) * 0.5
		button_clip.y = app.screen.height * 0.5
		
		self:add_button(button_clip, function (button)
			button.enabled = false
			self:tween(button_clip, tween.easing.interpolate({ 0, -0.2, -0.25, -0.15, 0.25, 1, 1.25}, 30), { y = 400 }, function ()
				app:set_scene('game.game_scene')
			end)
		end)
	end
	
end)