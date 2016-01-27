-- take a Love2D game working with letter library and assets
-- and pre-package it into a more convenient form for building
-- within punchdrunk using the moonshine browser vm

local bozo = require('bozo')					-- should replace this with lfs

local config = {
	base_path = '../',							-- base path of all game content
	source = { 'core', 'util', 'lt', 'game' },	-- paths of source folders to include
	assets = { 'assets' },						-- paths of asset folders to scan
	asset_filter = 'x1',						-- which size assets should be included for the web build
	
	-- path to a working punchdrunk build (grunt will take over doing the build)
	output_path = '/Users/sam/Downloads/punchdrunk-master/'
}

local output = {}
local function write(string)
	output[#output + 1] = string
end

local output_html = {}
local function write_html(string)
	output_html[#output_html + 1] = string
end

-- write the preamble boilerplate for the Lua content
write([[
-- replace normal module load
local preload = {}
local default_require = require
function require(name)
	local existing = preload[name]
	if existing then
		if type(existing) == 'function' then
			existing = existing()
			preload[name] = existing
		end
		return existing
	else
		return default_require(name)
	end
end

-- replace loading of data files
local data = {}
local default_read = love.filesystem.read
love.filesystem.read = function (name)
	if data[name] then
		return data[name]
	else
		return default_read(name)
	end	
end

]])

-- write the preamble boilerplate for the html container of the game
write_html([[
<!doctype html>
<html>
<head><meta charset="utf-8" />
<link href='http://fonts.googleapis.com/css?family=Ubuntu:400,400italic' rel='stylesheet' type='text/css'>
<script src="js/punchdrunk.js"></script>
<script src="js/debug/debug.moonshine.js"></script>
<script src="js/debug/local.debug.moonshine.js" data-ui-url="js/debug/ui"></script>
<style type="text/css">
@font-face {
  font-family: 'Vera';
  src: url('coffeescript/love.js/graphics/Vera.ttf');
}
main {
  max-width: 568px;
  width: 80%;
  margin: 0 auto;
}
#game_container {
  text-align: center;
}
#preload {
  display: none;
}
</style>
</head>
<body>
<div id="game_container">
  <canvas id="game"></canvas>
</div>
<div id="preload">
]])

-- gather substitute files if present these will replace the same named source files
local subs = {}
for _, file in ipairs(bozo.files('.', 'lua')) do
	subs[file.filename] = file
end

-- combine all source files in a single lua file (hijacked require mechanism)
for _, source in ipairs(config.source) do
	for _, file in ipairs(bozo.files(config.base_path .. source, 'lua', true)) do
		write('-----------------------------------')
		write('-- ' .. file.filepath)
		write('')
		write('preload[\'' .. source .. '.' ..  file.path:gsub('%/', '%.') .. file.name .. '\'] = function ()')
		-- use web specific version if present
		if subs[file.filename] then
			file = subs[file.filename]
		end		
		local input = assert(io.open(file.absolute, 'r'))
		write(input:read('*a'))
		input:close()
		write('end')
		write('')
	end
end

-- combine all asset files, which are also lua source
for _, assets in ipairs(config.assets) do
	for _, file in ipairs(bozo.files(config.base_path .. assets)) do
		if file.filepath:match(config.asset_filter) then
			if file.extension == 'ldata' then
				write('-----------------------------------')
				write('-- ' .. file.filepath)
				write('')
				write('data[\'' .. assets .. '/' .. file.filepath .. '\'] = function ()')
				local input = assert(io.open(file.absolute, 'r'))
				write(input:read('*a'))
				input:close()
				write('end')
				write('')
			elseif file.extension == 'png' then
				-- png file will be required so copy it
				
				-- create the path
				local process = io.popen('mkdir -p ' .. config.output_path .. assets .. '/' .. file.path)
				process:read('*a')
				process:close()
				
				-- copy the file
				local input = assert(io.open(file.absolute, 'rb'))
				local out_file = assert(io.open(config.output_path .. assets .. '/' .. file.filepath, 'wb'))
				out_file:write(input:read('*a'))
				out_file:close()
				input:close()
				
				-- add it to the html boilerplate
				write_html('<img id="' .. assets .. '/' .. file.filepath .. '" src="' .. assets .. '/' .. file.filepath .. '">')
			end
		end
	end
end

-- include the main.lua file
local input = assert(io.open(config.base_path .. 'main.lua', 'r'))
write(input:read('*a'))
input:close()

-- write buffered main.lua output
local out_file = assert(io.open(config.output_path .. 'lua/main.lua', 'w'))
out_file:write(table.concat(output, '\n'))
out_file:close()

-- add footer of html content
write_html([[
<script>
new Punchdrunk({
  canvas: document.getElementById("game")
})
</script>
</body>
</html>
]])

-- write buffered html output
local out_file = assert(io.open(config.output_path .. 'index.html', 'w'))
out_file:write(table.concat(output_html, '\n'))
out_file:close()
