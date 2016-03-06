-- a child node managing the draggable gems
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')

local app_node = require('lt.app_node')
local display_geom = require('lt.display_geom')
local tween = require('lt.tween')

return class.derive(app_node, function (gems)
	
	function gems:prepare()
		self.player_gems = array()
		self.ai_gems = array()
	end
	
	function gems:begin()
		local x_offset = (app.screen.width - 440) / 2
		if x_offset < 32 then
			x_offset = 32
		end
		
		for gem = 1, 3 do
			local y_position = app.screen.height * 0.5 + (gem - 2) * 64
			
			local player_gem = self:add_gem(x_offset, y_position, 'blue', x_offset - 80, 120 + gem * 10)
			self.player_gems:add(player_gem)
						
			local ai_gem = self:add_gem(app.screen.width - x_offset, y_position, 'green', app.screen.width - x_offset + 80, 125 + gem * 10)
			self.ai_gems:add(ai_gem)
		end
		
		self.drag_touch_area = self:add_touch_area_rect(self.view, 0, 0, app.screen.width, app.screen.height)
		self.drag_touch_area.enabled = false
		self.dragging_gem = nil
	end
	
	function gems:make_interactive(tiles, on_select)
		local dragging_gem = nil
		
		-- pick up a gem
		self.drag_touch_area.on_touch_begin = function (touch_area)
			for _, gem in ipairs(self.player_gems) do
				if not gem.tile then
					local x, y, width, height = gem:bounds(self.view)
					if display_geom.rect_contains_point(x, y, width, height, touch_area.touch_position[1], touch_area.touch_position[2]) then
						dragging_gem = gem
					end
				end
			end
		
			if dragging_gem then
				dragging_gem:send_to_front()
				self:tween(dragging_gem.shadow, tween.easing.ease_out(10), { x = 4 })
				self:tween(dragging_gem.sprite, tween.easing.ease_out(10), { y = -5 })
				dragging_gem.start = { dragging_gem.x, dragging_gem.y }
			end
		end

		-- move it
		self.drag_touch_area.on_touch_move = function (touch_area)
			if dragging_gem and touch_area.move_distance then
				dragging_gem.x = dragging_gem.start[1] + touch_area.drag_distance[1]
				dragging_gem.y = dragging_gem.start[2] + touch_area.drag_distance[2]
			end
		end		
		
		-- drop it
		self.drag_touch_area.on_touch_end = function (touch_area)
			if dragging_gem then
				-- check the tiles and the on select callback
				local selected_tile = nil
				for _, tile in ipairs(tiles) do
					if display_geom.point_distance(tile.x, tile.y, dragging_gem.x, dragging_gem.y) < 30 then
						selected_tile = tile
					end
				end				

				self:tween(dragging_gem.shadow, tween.easing.ease_out(10), { x = 2 })
				self:tween(dragging_gem.sprite, tween.easing.ease_out(10), { y = 0 })
				
				if selected_tile then
					self:tween(dragging_gem, tween.easing.ease_out(10), {
						x = selected_tile.x,
						y = selected_tile.y,
					})
					dragging_gem.tile = selected_tile
					selected_tile.gem = dragging_gem
					
					self.drag_touch_area.enabled = false
					on_select(selected_tile)
				else
					self:tween(dragging_gem, tween.easing.ease_out(10), {
						x = dragging_gem.start[1],
						y = dragging_gem.start[2],
					})
				end
				
				dragging_gem = nil
			end
		end
		
		self.drag_touch_area.enabled = true
	end
	
	function gems:all_gems_used()
		for _, gem in ipairs(self.player_gems) do
			if not gem.tile then
				return false
			end
		end
		for _, gem in ipairs(self.ai_gems) do
			if not gem.tile then
				return false
			end
		end
		return true
	end
	
	function gems:end_interactive()
		self.drag_touch_area.enabled = false
	end
	
	function gems:ai_move(tile, on_complete)
		local next_gem = nil
		for _, gem in ipairs(self.ai_gems) do
			if not gem.tile then
				next_gem = gem
				break
			end
		end
		
		next_gem.tile = tile
		tile.gem = next_gem
		
		-- pick it up
		next_gem:send_to_front()
		self:tween(next_gem.shadow, tween.easing.ease_out(10), { x = 4 })
		self:tween(next_gem.sprite, tween.easing.ease_out(10), { y = -5 })
		
		self:tween(next_gem, tween.easing.ease_inout(60), {
			x = tile.x,
			y = tile.y,
		}, on_complete)
		
		self.dispatch:delay(55, function ()
			self:tween(next_gem.shadow, tween.easing.ease_out(10), { x = 2 })
			self:tween(next_gem.sprite, tween.easing.ease_out(10), { y = 0 })
		end)
	end
		
	function gems:add_gem(x, y, color, tween_from_x, delay)
		local gem = self.view:add_display_list({
			x = tween_from_x,
			y = y,
			color = color,
			visible = false,
			tile = nil,
		})
		
		gem.shadow = gem:add_image('gem_shadow', {
			x = 2,
			y = 2,
			scale = 0.85,
			alpha = 0.75,
		})
		gem.sprite = gem:add_image('gem_' .. color, {
			scale = 0.75,
		})

		self.dispatch:delay(delay, function ()
			gem.visible = true
			self:tween(gem, tween.easing.ease_out(20), {
				x = x,
			})
		end)
		
		return gem
	end
	
end)