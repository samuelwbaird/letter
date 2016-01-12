-- a sample spritesheet builder using the bozo library (https://github.com/samuelwbaird/bozo)
-- copyright 2016 Samuel Baird MIT Licence

-- iterate a series of folder containing sprite assets and produce spritesheets for each source
-- generate a range of scaled output as required. Multiple sheets are generated per folder
-- if the assets do not fit the maximum sheet size
--
-- transparent borders are cropped from source images, but the specified registration of the original
-- image is preserved
--
-- spritesheet data is required as Lua code (executable in a sandbox)

local array = require('core.array')
local bozo = require('bozo')
local atlasbuilder = require('bozo.atlasbuilder')

--  settings

-- source art is considered to be at the following scale
local source_scale = 4

-- output is required at the following output_scales
local output_scales = { 1, 2, 3, 4 }

-- maximum spritesheet size (x scale)
local max_sheet_size = 1024

-- paths
local input_path = 'input/'
local output_path = 'output/'

-- generate spritesheets as required for a given input folder

function create_spritesheet(name, sources, clips)

	-- this process runs once for each required output scale
	for _, scale in ipairs(output_scales) do
		-- create an atlas builder
		local atlas = atlasbuilder()
		for _, source in ipairs(sources) do
			local path, anchor_x, anchor_y = source[1], source[2] or 0.5, source[3] or 0.5
		
			-- get all the images together, using bozo it iterate all the input files		
			for _, file in ipairs(bozo.files(input_path .. path, 'png')) do
				local image = bozo.image(file.absolute)
				if scale ~= source_scale then
					-- high quality downsizing if required
					local scaled = image:resized_to(math.floor(image:width() * scale / source_scale), math.floor(image:height() * scale / source_scale), 'lanczos3', true)
					image:dispose()
					image = scaled
				end
				-- add the image to the atlas, preserving the anchor and asset scale
				atlas:add_image(file.name, image, scale, anchor_x, anchor_y)
			end
		end

		-- now 'solve' the layout at a given maximum sheet size
		local result = atlas:solve(scale, scale * max_sheet_size)
		
		-- the output will be some number of sheets, however many are required to fit the assets
		local basename = name .. '_x' .. scale
		print(basename)
		local description = assert(io.open(output_path .. basename .. '_description.ldata', 'w'))

		-- write a header into the description file
		description:write('-- file header\n')
		description:write('version = 1\n')
		description:write('clip_style = \'x,y,sx,sy,r,a\'\n')
		description:write('\n')

		description:write('-- all texture atlases to load\n')
		for index, output in ipairs(result) do
			local basename = name .. '_' .. index .. '_x' .. scale
			
			-- size specific image
			local image = output:image()
			
			-- first write the instruction to load the image
			description:write('sheet(\'' .. basename .. '.png\', ' .. image:width() .. ', ' .. image:height() .. ', {\n')
			for _, entry in ipairs(output:entries()) do
				-- xy is relative position at scale of 1 of corners of the sprite against the anchor
				-- uv is 0 - 1 position of the corners of the sprite in the sheet
				description:write('{ name = "' .. entry.name .. '", xy = {' .. entry.xy[1] .. ',' .. entry.xy[2] .. ',' .. entry.xy[3] .. ',' .. entry.xy[4] .. '}, uv = {' .. entry.uv[1] .. ',' .. entry.uv[2] .. ',' .. entry.uv[3] .. ',' .. entry.uv[4] .. '} },\n')
			end
			description:write('})\n\n')
			
			image:save(output_path .. basename .. '.png')
			-- free up memory
			image:dispose()
		end
		
		description:write('-- animated clips / frame descriptions\n')
		if clips then
			-- take the simple image sequences provided and generate a full clip specification for them
			for name, frames in pairs(clips) do
				local all_are_strings = true
				for _, frame in ipairs(frames) do
					if type(frame) ~= 'string' then
						all_are_strings = false
						break
					end
				end
				description:write('clip(\'' .. name .. '\', {\n')
				if all_are_strings then
					-- are the frames just a sequence of names? if so write out the animation data for a sprite sequence
					for _, frame in ipairs(frames) do
						description:write('  { --[[label = \'\',]] content = { { --[[instance = nil,]] image = \'' .. frame .. '\', transform = { 0, 0, 1, 1, 0, 1 } } } },\n')
					end
				else
					-- if the frames are more complex then just include them verbatim as animation data
					for _, frame in ipairs(frames) do
						description:write('  {')
						if frame.label then
							description:write('label = \'' .. frame.label .. '\' ')
						end
						description:write('content = {\n')
						
						description:write('  }},\n')
					end
				end
				-- each frame of clip is a list of contents, in this case only a single image per frame
				description:write('})\n')
			end
		end
		description:write('\n')
		
		-- free up memory
		atlas:dispose()
		description:close()
	end
end

-- now run the function on the input images

-- input folders
-- each sprite sheet is created from a list of input folders
-- each folder has a setting for the relative anchor point of images in that folder

-- clip data
-- clips can define a number of frames and a full scene graph per frame
-- objects making up the scene can be either images or clips
-- each object within the frame has transform values set (in a format to match the format set in the style header)
-- full clip data is quite detailed and is expected to be exported from an clip tool
-- this spritesheet script allows a shorthand to set up simple clips as a sequence of images

-- create a sprite sheet for the title screen assets
create_spritesheet(
	-- output resource name
	'title',
	-- specify the source folders, with the registration point offset to use for those images
	{
		{ 'title', 0.0, 0.0 },
	},
	-- animation data
	{
		-- some animations are just an image sequence
		play_button = { 'play_button0001', 'play_button0002' },
	}
)

-- create a spritesheet for the game assets
create_spritesheet(
	-- output resource name
	'game',
	-- image source folders
	{
		{ 'game', 0.5, 0.5 },
	},
	-- animation data
	{
		-- animations can contain a number of other images or clips per each frame in a full heirachy
		-- this can be used to layout scenes as well as creating more complex animations from parts
		-- in general the best way to generate this data would be to export it from another tool such as flash
	    { label = 'opening_pose', content = {
			{ --[[instance = nil,]] image = 'play_button0001', transform = { 0, 0, 1, 1, 0, 1 } },
		}},
	    { label = 'ending_pose', content = {
			{ --[[instance = nil,]] image = 'play_button0002', transform = { 0, 0, 1, 1, 0, 1 } },
		}},
	}
)