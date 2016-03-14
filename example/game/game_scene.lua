-- a sample game, built as an app_node scene
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')
local app_node = require('lt.app_node')
local tween = require('lt.tween')
local resources = require('lt.resources')

local tiled_background = require('game.tiled_background')
local hints = require('game.hints')
local tiles = require('game.tiles')
local gems = require('game.gems')

return class.derive(app_node, function (game_scene)
	
	function game_scene:prepare()
		app.resources.load_spritesheet('assets/output/', 'game')
	end
	
	local states = {}
	
	function game_scene:begin()		
		local tiled_background = tiled_background()
		self:add(tiled_background)
		-- background is center
		tiled_background.view.x = app.screen.width * 0.5
		tiled_background.view.y = app.screen.height * 0.5
		
		self.tiles = tiles()
		self:add(self.tiles)
		
		self.gems = gems()
		self:add(self.gems)	
		
		-- add the layer for display text hints
		self.hints = hints()
		self:add(self.hints)
		
		self.hints_done = {
			first_color_hint = false,
			second_color_hint = false,
		}
		
		self.dispatch:delay(60 * 2, function ()
			self.hints:show_text('In this game players take turns placing their gems.', true, function ()
				self:set_state(states.players_turn)
				self.hints:show_text('It\'s your turn first, drag a blue gem to a tile.', false, function ()
				end)
			end)
		end)
	end
	
	function game_scene:set_state(state)
		if state ~= self.state then
			if self.state and self.state.on_exit then
				self.state.on_exit(self)
			end
		
			self.state = state
			if self.state and self.state.on_enter then
				self.state.on_enter(self)
			end
		end
	end
	
	function game_scene:on_enter_players_turn()
		self.gems:make_interactive(self.tiles:free_tiles(), function (tile_data)
			if not self.hints.first_color_hint then
				self.hints.first_color_hint = true
				self.hints:show_text('After each gem is placed all the tiles check their color.', true, function ()
					self.tiles:update_tile_colors()
					self.hints:show_text('If there is a blue gem near the tile it turns blue.', true, function ()
						self:set_state(states.ai_turn)					
					end)
				end)
			else
				self.tiles:update_tile_colors()
				if not self:check_gameover() then
					self:set_state(states.ai_turn)					
				end
			end
		end)
	end
	
	function game_scene:on_exit_players_turn()
		self.gems:end_interactive()
	end

	function game_scene:on_enter_ai_turn()
		local tile = self.tiles:get_tile(self.tiles:model():next_ai_move())
	
		-- move the AI gem to this tile
		self.gems:ai_move(tile, function ()
			if not self.hints.second_color_hint then
				self.hints.second_color_hint = true
				self.hints:show_text('If there are green gems near the tile it turns green.', true, function ()
					self.tiles:update_tile_colors()
					self.hints:show_text('If there are the same number of green and blue gems nearby the tile will become neutral.', true, function ()
						self.hints:show_text('After all gems are placed, the player with the most coloured tiles wins.', true, function ()
							self:set_state(states.players_turn)
						end)
					end)
				end, 8 * 60)
			else
				self.tiles:update_tile_colors()
				if not self:check_gameover() then
					self:set_state(states.players_turn)
				end
			end
		end)
	end
	
	function game_scene:check_gameover()
		if self.gems:all_gems_used() then
			local model = self.tiles:model()
			if model.ai_wins then
				self.hints:show_text('You Lose', true, function ()
					app:set_scene('game.title_scene')
				end)
			elseif model.player_wins then
				self.hints:show_text('You Win', true, function ()
					app:set_scene('game.title_scene')
				end)
			else
				self.hints:show_text('It\'s a draw', true, function ()
					app:set_scene('game.title_scene')
				end)
			end
			return true
		end
	end
	
	-- main states through the game
	states.players_turn = {
		on_enter = game_scene.on_enter_players_turn,
		on_exit = game_scene.on_exit_players_turn,
	}
	states.ai_turn = {
		on_enter = game_scene.on_enter_ai_turn,
	}
	
end)