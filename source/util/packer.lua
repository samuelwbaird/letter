-- basic rect packing algorithm to use where required
-- initialise an object with the width and height available
-- then add_rect supplying width and height
-- copyright 2019 Samuel Baird MIT Licence

local class = require('core.class')
local array = require('core.array')

return class(function (packer)
	
	function packer:init(width, height)
		-- total size
		self.width = width
		self.height = height
		
		-- all successfully stored rects
		self.rects = array()
		
		-- next possible storage position
		self.anchors = array()
		self.anchors:push({ x = 0, y = 0 })
	end
	
	-- util functions -----------------------------------
	
	local function rect_intersects(r1, r2)
		-- if one is right of the other
		if r1.x >= r2.x + r2.width or r2.x >= r1.x + r1.width then
			return false
		end
		
		-- if one is above the other
		if r1.y >= r2.y + r2.height or r2.y >= r1.y + r1.height then
			return false
		end
		
		return true
	end
	
	local function point_intersects(p1, r1)
		return p1.x >= r1.x and p1.x < r1.x + r1.width and p1.y >= r1.y and p1.y < r1.y + r1.height
	end
	
	------------------------------------------
	
	-- add an object with a given width and height, return x, y if successful or nil
	function packer:add_rect(width, height, info)
		-- test each possible anchor point this image could be placed at
		local possible_anchor_points = array()
		for _, anchor in ipairs(self.anchors) do
			-- is there enough space in the sheet here
			if anchor.x + width <= self.width and anchor.y + height <= self.height then
				-- would this position intersect with an existing rect
				local possible = true
				local rect = {
					x = anchor.x,
					y = anchor.y,
					width = width,
					height = height
				}
				for _, existing_rect in ipairs(self.rects) do
					if rect_intersects(rect, existing_rect) then
						possible = false
						break
					end
				end
				if possible then
					possible_anchor_points:push({
						anchor = anchor,
						rect = rect,
					})
				end
			end
		end
		
		-- if there are no possible anchor points we fail out
		if #possible_anchor_points == 0 then
			return nil
		end
		
		-- score this position using a heuristic for how much it eats into the remaining space
		for _, pos in ipairs(possible_anchor_points) do
			-- heuristic score based on the area of the bottom right position of the rect, works well
			pos.score = (pos.rect.x + pos.rect.width) * (pos.rect.y + pos.rect.height)
		end

		-- choose the best scoring anchor point
		possible_anchor_points:sort(function (p1, p2)
			return p1.score < p2.score
		end)
		local selected = possible_anchor_points[1]
		
		-- add the rect at this point
		self.rects:push(selected.rect)
		
		-- update anchors
		local anchors = array()
		
		-- filter out existing anchors that are now invalid
		for _, anchor in ipairs(self.anchors) do
			if not point_intersects(anchor, selected.rect) then
				anchors:push(anchor)
			end
		end
		
		-- TODO: for better packing we would need to add additional anchors here for where the any of the lines of the new rect would intersect with existing rects if extended, creating anchors that aren't on a corner
		
		-- add new possible anchors at the top right and bottom left of the newly added rect
		anchors:push({ x = selected.rect.x + selected.rect.width, y = selected.rect.y })
		anchors:push({ x = selected.rect.x, y = selected.rect.y + selected.rect.height })
		self.anchors = anchors
		
		-- return the position assigned
		return selected.anchor.x, selected.anchor.y
	end
	
end)