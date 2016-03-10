local lfs = require('lfs')
assert(lfs, 'build utils requires lfs, Lua file system module')

local preload_source = {}
local output_path = ''

local function output(set_output_path)
	output_path = set_output_path
	if output_path ~= '' and output_path:sub(-1, -1) ~= '/' then
		output_path = output_path .. '/'
	end
end

local function files(path, dest_path, filter)
	local out = {}
	for file in lfs.dir(path) do
		local attributes = lfs.attributes(path .. '/' .. file)
		if file:sub(1, 1) ~= '.' and attributes then
			if attributes.mode == 'directory' then
				for _, file in ipairs(files(path .. '/' .. file, dest_path .. '/' .. file, filter)) do
					out[#out + 1] = file
				end
			else
				local data = {
					filename = file,
					path = dest_path,
					absolute = path .. '/' .. file,
					extension = file:match('.-%.(.*)$'),
				}
				if dest_path == '' or dest_path == nil then
					data.filepath = file
				else
					data.filepath = dest_path .. '/' .. file	
				end
				data.name = data.extension and file:sub(1, (#file - #data.extension) - 1) or file
				if not filter or (type(filter) == 'string' and data.filepath:match(filter)) or (type(filter) == 'function' and filter(data)) then
					out[#out + 1] = data
				end
			end
		end
	end
	return out
end

local function shell(command)
	print(command)
	local process = io.popen(command, 'r')
	process:read('*a')
	process:close()
end

local function copy(source, dest)
	shell('cp "' .. source .. '" "' .. dest .. '"')
end

local function add_to_preload(file)
	local input = assert(io.open(file.absolute, 'rb'), 'open file ' .. file.absolute)
	local content = input:read('*a')
	input:close()
	
	preload_source[#preload_source + 1] = 'package.preload[\'' .. file.path:gsub('/', '.') .. (file.path ~= '' and '.' or '') .. file.name .. '\'] = function ()\n'
	preload_source[#preload_source + 1] = '\n-------- ' .. file.path:gsub('/', '.') .. (file.path ~= '' and '.' or '') .. file.name .. ' ---------------------------\n'
	preload_source[#preload_source + 1] = content
	preload_source[#preload_source + 1] = '\nend\n'			
end

local function add_lua_data(file)
	local input = assert(io.open(file.absolute, 'rb'), 'open file ' .. file.absolute)
	local content = input:read('*a')
	input:close()
	
	-- can't get proper sandboxing with moonshine so we'll just sub in the globals we want
	preload_source[#preload_source + 1] = 'lua_data = lua_data or {}'
	preload_source[#preload_source + 1] = 'lua_data[\'' .. file.path:gsub('/', '.') .. (file.path ~= '' and '.' or '') .. file.name .. '\'] = function (dsl_globals)'
	preload_source[#preload_source + 1] = 'dsl_globals = dsl_globals or {} local keep_globals = {} for k, v in pairs(dsl_globals) do keep_globals[k] = rawget(_G, k) rawset(_G, k, v) end'
		
	preload_source[#preload_source + 1] = '\n-------- ' .. file.path:gsub('/', '.') .. (file.path ~= '' and '.' or '') .. file.name .. ' ---------------------------\n'
	preload_source[#preload_source + 1] = content
	preload_source[#preload_source + 1] = 'for k, v in pairs(dsl_globals) do rawset(_G, k, keep_globals[k]) end'
	preload_source[#preload_source + 1] = 'end\n'			
end

local function add_asset_path(source_path, dest_path, filter)
	shell('mkdir -p "' .. (output_path .. dest_path) .. '"')
	for _, file in pairs(files(source_path, dest_path, filter)) do
		-- luadata files to be compiled into shared source
		-- all other files copied
		if file.extension == 'ldata' then
			add_lua_data(file)
		else
			copy(file.absolute, output_path .. file.filepath)
		end
	end
end

local function add_source_path(source_path, dest_path, filter)
	for _, file in pairs(files(source_path, dest_path, filter)) do
		add_to_preload(file)
	end
end

local function html(main)
	-- create a temporary source file with all lua content
	local temp = assert(io.open('source.lua', 'wb'), 'write temp source.lua file')

	-- preload linked files
	temp:write(table.concat(preload_source, '\n'))
	
	-- write main script file
	local input = assert(io.open(main, 'rb'), 'open main script file ' .. main)
	temp:write(input:read('*a'))
	input:close()

	-- moonshine compile step and cleanup
	temp:close()	
	shell('mkdir -p "' .. output_path .. '"')
	shell('export PATH=$PATH:/usr/local/bin/; moonshine distil -o "' .. output_path .. '/source.json" source.lua')
end

return {
	output = output,
	add_asset_path = add_asset_path,
	add_source_path = add_source_path,
	html = html,
}