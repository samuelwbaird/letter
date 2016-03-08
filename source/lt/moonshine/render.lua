-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')

return class(function (render)
	
	function render:init()
		-- return a wrapper to trace missing properties and methods
		local obj = {}
		setmetatable(obj, {
			__index = function (obj, key)
				local val = self[key]
				if not val then
					error('render missing property ' .. key)
				end
				return val
			end
		})
		return obj
	end
	
end)