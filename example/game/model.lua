-- a class to model the game rules
-- the method with_move produces a derived model giving the state after a hypothetical move is made
-- this is used to implement a really blunt AI picking the best move for the AI after each turn
-- the logic for this is fudged with a bit of randomness to stop the game always ending in a draw
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')

return class(function (model)
	
	function model:init(gem_positions)
		-- supply gem positions as an array of arrays
		self.gem_rows = gem_positions
		-- derive tile colours
		self.tile_rows = {}

		local blue_count = 0
		local green_count = 0
		for ty = 1, 3 do
			local row = {}
			for tx = 1, 4 do
				local c = self:tile_color(tx, ty)
				if c == 'blue' then
					blue_count = blue_count + 1
				elseif c == 'green' then
					green_count = green_count + 1
				end
				row[tx] = {
					id = tx .. '_' .. ty,
					color = c
				}
			end
			self.tile_rows[ty] = row
		end
		
		-- derive scores
		self.blue_count = blue_count
		self.green_count = green_count
		if self.blue_count > self.green_count then
			self.player_wins = true
		elseif self.green_count > self.blue_count then
			self.ai_wins = true
		else
			self.draw = true
		end
	end
	
	function model:tile_color(x, y)
		local blue_count = 0
		local green_count = 0
		for ty = y - 1, y + 1 do
			for tx = x - 1, x + 1 do
				if true or (ty == y or tx == x) then
					local c = self:get_gem(tx, ty)
					if c == 'blue' then
						blue_count = blue_count + 1
					elseif c == 'green' then
						green_count = green_count + 1
					end
				end
			end
		end
		if blue_count > green_count then
			return 'blue'
		elseif green_count > blue_count then
			return 'green'
		end
	end
	
	function model:get_gem(x, y)
		if x >= 1 and x <= 4 and y >= 1 and y <= 3 then
			return self.gem_rows[y][x]
		end
	end
	
	-- return a new model with a move applied
	
	function model:all_moves()
		local moves = array()
		for ty = 1, 3 do
			for tx = 1, 4 do
				if self.gem_rows[ty][tx] == '' then
					moves:push(tx .. '_' .. ty)
				end
			end
		end
		return moves
	end
	
	function model:with_move(move_id, color)
		local rows = {}
		for ty = 1, 3 do
			local row = {}
			for tx = 1, 4 do
				local id = tx .. '_' .. ty
				if id == move_id then
					row[tx] = color
				else
					row[tx] = self.gem_rows[ty][tx]
				end
			end
			rows[ty] = row
		end
		return model(rows)
	end
	
	function model:next_ai_move()
		local all_moves = self:all_moves()
		local all_winning_moves = {}
		
		-- first check for a winning move
		for _, move in ipairs(all_moves) do
			if self:with_move(move, 'blue').ai_wins then
				all_winning_moves[#all_winning_moves + 1] = move
			end
		end
		-- if any winning moves (for this turn) then pick one randomly
		if #all_winning_moves > 0 then
			all_moves = all_winning_moves
		end
		
		-- othewise sort by best outcome
		local sort_them = array()
		for _, move in ipairs(all_moves) do
			local result = self:with_move(move, 'green')
			sort_them:push({
				score = (result.green_count - result.blue_count) + (math.random() * 6),	-- a little random to let some light in for players to win
				move = move
			})
		end
		sort_them:sort(function (t1, t2)
			return t1.score > t2.score
		end)
		
		return sort_them[1].move
	end
	
	
end)