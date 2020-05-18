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
					height = height,
					info = info,
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
		local anchors_added = {} 
		local new_anchors = array()
		local add_new_anchor = function (anchor, specific_rect)
			-- don't add duplicate anchors
			local key = anchor.x .. ':' .. anchor.y
			if anchors_added[key] then
				return
			end
			anchors_added[key] = true
			-- don't add anchors outside of the bounds
			if anchor.x >= self.width or anchor.y >= self.height then
				return
			end
			-- don't add anchors the intersect an existing rect
			if specific_rect then
				if point_intersects(anchor, specific_rect) then
					return
				end
			else
				for _, rect in ipairs(self.rects) do
					if point_intersects(anchor, rect) then
						return
					end
				end
			end
			new_anchors:push(anchor)
		end
		
		-- preserve existing anchors that are still valid
		for _, anchor in ipairs(self.anchors) do
			add_new_anchor(anchor, selected.rect)
		end
		
		-- take the bottom horizontal line of the new rect and extend leftward, turning intersections into anchors
		-- take the right hand vertical line of the new rect and extend upward, turning intersections into anchors
		for _, rect in ipairs(self.rects) do
			if rect.x + rect.width < selected.rect.x and rect.y < selected.rect.y + selected.rect.height and rect.y + rect.height > selected.rect.y + selected.rect.height then
				add_new_anchor({ x = rect.x + rect.width, y = selected.rect.y + selected.rect.height })
			end
			if rect.y + rect.height < selected.rect.y and rect.x < selected.rect.x + selected.rect.width and rect.x + rect.width > selected.rect.x + selected.rect.width then
				add_new_anchor({ x = selected.rect.x + selected.rect.width, y = rect.y + rect.height })
			end
		end		
		
		-- add new possible anchors at the top right and bottom left of the newly added rect
		add_new_anchor({ x = selected.rect.x + selected.rect.width, y = selected.rect.y })
		add_new_anchor({ x = selected.rect.x, y = selected.rect.y + selected.rect.height })
		self.anchors = new_anchors
		
		-- return the position assigned
		return selected.anchor.x, selected.anchor.y
	end
	
end)