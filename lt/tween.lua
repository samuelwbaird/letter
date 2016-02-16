-- a package implementing a tweening system
-- easing functions generate easing data (as an array of values from 0 to 1)
-- tween objects track the changes to the properties of an object across that easing
-- create a manager object to actually run the tweens (normally done automatically by an app_node)
-- copyright 2016 Samuel Baird MIT Licence

local module = require('core.module')
local class = require('core.class')
local cache = require('core.cache')

local dispatch = require('util.dispatch')

local easing = module(function (easing)
	
	-- TODO: bounce_past
	-- TODO: spring_past
	
	local function cached_from_formula(cache, frames, formula)
		return cache:get_or_set(frames, function ()
			local out = {}
			for i = 1, frames do
				local ratio = i / frames
				out[i] = formula(ratio)
			end
			return out
		end)
	end
	
	local linear_cache = cache(128)
	function easing.linear(frames)
		return cached_from_formula(linear_cache, frames, function (ratio)
			return ratio
		end)
	end
	
	local ease_in_cache = cache(128)
	function easing.ease_in(frames)
		return cached_from_formula(ease_in_cache, frames, function (ratio)
			return ratio * ratio
		end)
	end
	
	local ease_out_cache = cache(128)
	function easing.ease_out(frames)
		return cached_from_formula(ease_out_cache, frames, function (ratio)
			return 1 - (1 - ratio) * (1 - ratio)
		end)
	end
	
	local ease_inout_cache = cache(128)
	function easing.ease_inout(frames)
		return cached_from_formula(ease_inout_cache, frames, function (ratio)
			ratio = ratio * 2
			if ratio < 1 then
				return ratio * ratio * 0.5
			else
				ratio = 1 - (ratio - 1)
				return 0.5 + (1 - (ratio * ratio)) * 0.5
			end
		end)
	end
	
	function easing.interpolate(values, frames)
		local scale = (#values - 1) / frames
		local out = {}
		for i = 1, frames do
			local ratio = (i - 1) * scale
			local base = math.floor(ratio)
			local offset = ratio - base
			if base < #values then
				out[i] = (values[base + 1] * (1 - offset)) + (values[base + 2] * offset)
			else
				out[i] = values[#values]
			end
		end
		return out
	end
end)

local tween = class(function (tween)
	
	function tween:init(target, easing, properties, on_complete)
		self.target = target
		self.easing = easing
		self.on_complete = on_complete
		
		-- gather start and end values for all tweened properties
		self.properties = {}
		for k, v in pairs(properties) do
			self.properties[k] = { target[k], v }
		end		
		
		self.frame = 0
	end
	
	function tween:update()
		self.frame = self.frame + 1
		local ratio = self.easing[self.frame]
		local inverse = 1 - ratio
		
		for k, values in pairs(self.properties) do
			self.target[k] = (values[1] * inverse) + (values[2] * ratio)
		end
		
		-- return true if complete
		if self.frame == #self.easing then
			local on_complete = self.on_complete
			self.on_complete = nil
			if on_complete then
				on_complete()
			end
			return true
		end
	end
	
end)

local manager = class(function (manager)
	
	function manager:init()
		self.tweens = dispatch.update_list(tween.update)
	end
	
	function manager:add(tween)
		self.tweens:add(tween, tween.target)
	end
	
	function manager:remove_tweens_of(target)
		self.tweens:remove(target)
	end
	
	function manager:update()
		self.tweens:update()
	end
	
	function manager:clear()
		self.tweens:clear()
	end
	
	function manager:dispose()
		self.tweens:clear()
		self.tweens = nil
	end
	
end)	

return class.package({ easing = easing, tween = tween, manager = manager }, tween.new )