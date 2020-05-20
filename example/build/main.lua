-- example main module for love2D
-- copyright 2016 Samuel Baird MIT Licence
local app = require('lt.app')

app.launch(
	-- preferred logical screen size
	{
		width = 480,
		height = 320
	},
	-- available asset scales and suffixes
	{
		{ scale = 1, suffix = '_x1'},
		{ scale = 2, suffix = '_x2'},
		{ scale = 3, suffix = '_x3'},
		{ scale = 4, suffix = '_x4'},
	},
	-- initial scene to launch
	'game.title_scene'
)