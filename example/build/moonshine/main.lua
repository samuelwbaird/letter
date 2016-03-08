-- example top level script for web based build
-- copyright 2016 Samuel Baird MIT Licence

local platform = require('lt.moonshine.platform')
local app = require('lt.app')


-- insert a preloading scene inline
package.preload['preload_scene'] = function ()
	local class = require('core.class')
	local app_node = require('lt.app_node')

	return class.derive(app_node, function (preload_scene)
		function preload_scene:begin()
			print('preload_scene')
		end
	end)
end


-- preload assets then launch app
app.launch(
	-- preferred logical screen size (will adjust logical size to canvas dimensions)
	{
		width = 480,
		height = 320
	},
	-- available asset scales and suffixes
	{
		-- only using one set of assets in this web build
		{ scale = 2, suffix = '_x2'},
	},
	-- initial scene to launch
	'preload_scene'
)
