-- a child node managing the grid of tiles
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')

local app_node = require('lt.app_node')
local tween = require('lt.tween')
local resources = require('lt.resources')

local model = require('game.model')

return class.derive(app_node, function (tiles)
	
	function tiles:prepare()
	end
	
	function tiles:begin()
		self.shadow_layer = self.view:add_display_list()
		
		local vignette = self.view:add_image('vignette', {
			x = app.screen.width * 0.5,
			y = app.screen.height * 0.5,
			scale_x = app.screen.width / 142,
			scale_y = app.screen.height / 96,
			alpha = 0.8,
		})
		
		self.tile_layer = self.view:add_display_list()
		self.tiles = {}
		
		for ty = 1, 3 do
			for tx = 1, 4 do
				local x = (app.screen.width * 0.5) + (tx - 2.5) * 90
				local y = (app.screen.height * 0.5) + (ty - 2) * 90
				
				local shadow_img = self.shadow_layer:add_image('tile_shadow', {
					x = x + 2,
					y = y + 2,
				})
				
				local tile_img = self.tile_layer:add_image((tx + ty) % 2 == 0 and 'tile_white' or 'tile_black', {
					x = x,
					y = y,
				})
				
				shadow_img.visible = false
				tile_img.visible = false
				
				local tile_data = {
					state = (tx + ty) % 2 == 0 and 'white' or 'black',
					x = tile_img.x,
					y = tile_img.y,
					shadow = shadow_img,
					tile = tile_img,
				}
				
				self.tiles[tx .. '_' .. ty] = tile_data
				local button = self:add_button(tile_img, function (button)
					self:player_selects_tile(button.tile_data)
				end)
				button.tile_data = tile_data
				button.up_frame = function (button)
					button.tile_data.tile.y = button.tile_data.y + 0
				end
				button.down_frame = function (button)
					button.tile_data.tile.y = button.tile_data.y + 2
				end				
				tile_data.button = button
				button.enabled = false
				
				self.dispatch:delay(1 + (tx + ty) * 10 + math.random(1, 5), function ()
					
					shadow_img.alpha = 0
					shadow_img.visible = true
					
					tile_img.visible = true
					tile_img.y = tile_img.y - 384
					tile_img.scale = 2
					
					self:tween(shadow_img, tween.easing.linear(30), { alpha = 1.0 })
					self:tween(tile_img, tween.easing.interpolate({ 0, 0.2, 0.5, 1.0, 0.99, 1.0 }, 30), {
						y = tile_img.y + 384,
						scale = 1,
					})
					
				end)
				
			end
		end
	end
	
	function tiles:free_tiles()
		local out = array()
		for _, tile in pairs(self.tiles) do
			if tile.gem == nil then
				out:push(tile)
			end
		end
		return out
	end
	
	function tiles:model()
		local rows = {}
		for ty = 1, 3 do
			local row = {}
			for tx = 1, 4 do
				local tile_data = self.tiles[tx .. '_' .. ty]
				row[tx] = tile_data.gem and tile_data.gem.color or ''
			end
			rows[ty] = row
		end
		return model(rows)
	end
	
	function tiles:update_tile_colors()
		local model = self:model()
		for ty = 1, 3 do
			for tx = 1, 4 do
				local tile_data = self.tiles[tx .. '_' .. ty]
				local color = model:tile_color(tx, ty)
				if not color then
					color = (tx + ty) % 2 == 0 and 'white' or 'black'
				end
				if color ~= tile_data.state then
					self:set_tile(tile_data, color)
				end
			end
		end
	end
	
	function tiles:get_tile(id)
		return self.tiles[id]
	end
	
	function tiles:set_tile(tile_data, color)
		tile_data.state = color
		self.dispatch:delay(15, function ()
			tile_data.tile.image_data = resources.get_image_data('tile_' .. color)
		end)
		
		tile_data.tile.scale_x = 1
		self:tween(tile_data.tile, tween.easing.interpolate({ 0, 0.25, 1, 0.25, 0}, 30), {
			scale_x = 0.1,
		})
		self:tween(tile_data.tile, tween.easing.interpolate({ 0, 0.75, 1, 0.75, 0}, 30), {
			y = tile_data.tile.y - 5,
		})
		tile_data.shadow.scale_x = 1
		self:tween(tile_data.shadow, tween.easing.interpolate({ 0, 0.25, 1, 0.25, 0}, 30), {
			scale_x = 0.1
		})
	end
	
end)