-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local platform = require('lt.moonshine.platform')

local display_data = require('lt.display_data')

return class(function (resources)

	local asset_suffix = ''
	local loaded_sheets = {}
	local images = {}	
	local clips = {}
	
	local debug_output = function (...)
		-- optionally display a list of all assets
		print(...)
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
	
	-- preloading ---------------------------------------
	
	function resources.preload_images(images, on_complete)
	end
	
	function resources.load_spritesheet(basepath, name, prefix)
		debug_output('load ' .. name .. asset_suffix .. '_description.ldata')
		prefix = prefix or ''
		
		-- record what we ended up loading
		local loaded_sheet = {
			name = name,
			prefix = prefix,
			textures = {},
			images = {},
			clips = {},
		}
		loaded_sheets[name] = loaded_sheet
		
		-- sandboxed callback functions to handle parsing the description
		local dsl = {
			sheet = function (filename, width, height, image_list)
				debug_output('  sheet ' .. filename)
				
				-- load the texture itself
				local texture = platform.create_texture(basepath .. filename, width, height)
				loaded_sheet.textures[filename] = texture
				
				-- register all the sprites in the texture
				for _, image in ipairs(image_list) do
					debug_output('    image ' .. image.name)
					
					-- the logical size of this sprite against the texture size
					local width_scale = (image.xy[3] - image.xy[1]) / ((image.uv[3] - image.uv[1]) * texture:getWidth())
					local height_scale = (image.xy[4] - image.xy[2]) / ((image.uv[4] - image.uv[2]) * texture:getHeight())
					
					local quad = platform.create_quad(
						image.uv[1] * texture.getWidth(),
						image.uv[2] * texture.getHeight(),
						(image.uv[3] - image.uv[1]) * texture.getWidth(),
						(image.uv[4] - image.uv[2]) * texture.getHeight(),
						image.xy[3] - image.xy[1],
						image.xy[4] - image.xy[2]
					)
					
					-- create and cache the image data object
					local image_data = display_data.image_data(image.name, texture, quad, image.xy)
					loaded_sheet.images[image.name] = image_data
					images[prefix .. image.name] = image_data
					
					-- create a single frame clip version of each image (for convenience where clips may replace static images later)
					local clip_data = display_data.clip_data(image.name)
					local frame_data = clip_data:add_frame()
					frame_data:add_image_content(nil, image_data)
					loaded_sheet.clips[image.name] = clip_data
					clips[prefix .. image.name] = clip_data	
				end
			end,
			
			clip = function (name, frames)
				local clip_data = display_data.clip_data(name)
				for frame_no, frame in ipairs(frames) do
					local frame_data = clip_data:add_frame(frame.label)
					for _, entry in ipairs(frame.content or {}) do
						if entry.image then
							assert(loaded_sheet.images[entry.image])
							frame_data:add_image_content(
								entry.instance, 
								loaded_sheet.images[entry.image], 
								unpack(entry.transform)
							)
						end
					end
				end
				loaded_sheet.clips[name] = clip_data
				clips[prefix .. name] = clip_data	
			end,			
		}
		
		-- load the ldata file and execute it within the sandbox
		lua_data[basepath:gsub('/', '.') .. name .. asset_suffix .. '_description'](dsl)
		
		-- once all clips are loaded link clip data directly to other image and clip_data
		-- also record frame numbers for all ranges based on labels
		for _, clip in pairs(loaded_sheet.clips) do
			clip:link_resources(resources)
			debug_output('    clip  ' .. clip.name)
			for _, frame in ipairs(clip.frames) do
				if frame.label then
					debug_output('      frame ' .. frame.label)
				end
			end
		end
	end
	
	
end)