-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')

return class(function (resources)

	local asset_suffix = ''
	local loaded_sheets = {}
	local images = {}	
	local clips = {}
	
	local debug_output = function (...)
		-- optionally display a list of all assets
		-- print(...)
	end
	
	-- access loaded assets ------------------------------
	
	function resources.get_image_data(name)
		return images[name]
	end	
	
	function resources.get_clip_data(name)
		return clips[name]
	end
	
	-- asset loading -------------------------------------

	function resources.set_asset_suffix(suffix)
		asset_suffix = suffix
	end
	
	function resources.get_asset_suffix()
		return asset_suffix
	end	
	
end)