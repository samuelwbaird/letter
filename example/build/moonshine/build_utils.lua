local lfs = require('lfs')
assert(lfs, 'build utils requires lfs, Lua file system module')

local preload_source = {}

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
					filepath = dest_path .. '/' .. file,
					path = dest_path,
					absolute = path .. '/' .. file,
					extension = file:match('.-%.(.*)$'),
				}
				data.name = data.extension and file:sub(1, (#file - #data.extension) - 1) or file
				if not filter or (type(filter) == 'string' and file:match(data.filepath)) or (type(filter) == 'function' and filter(data)) then
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

local function add_to_preload(file)
	local input = assert(io.open(file.absolute, 'rb'), 'open file ' .. file.absolute)
	local content = input:read('*a')
	input:close()
	
	preload_source[#preload_source + 1] = 'package.preload[\'' .. file.path:gsub('/', '.') .. (file.path and '.' or '') .. file.name .. '\'] = function ()\n'
	preload_source[#preload_source + 1] = '\n-------- ' .. file.path:gsub('/', '.') .. (file.path and '.' or '') .. file.name .. ' ---------------------------\n'
	preload_source[#preload_source + 1] = content
	preload_source[#preload_source + 1] = '\nend\n'
			
end

local function add_asset_path(source_path, dest_path, filter)
end

local function add_source_path(source_path, dest_path, filter)
	for _, file in pairs(files(source_path, dest_path, filter)) do
		add_to_preload(file)
	end
end

local function html(main, output_folder, content_folder)
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
	local full_path = output_folder .. '/' .. content_folder
	shell('mkdir -p "' .. full_path .. '"')
	shell('export PATH=$PATH:/usr/local/bin/; moonshine distil -o "' .. full_path .. '/source.json" source.lua')
	-- os.remove('source.lua')
end

return {
	add_asset_path = add_asset_path,
	add_source_path = add_source_path,
	html = html,
}