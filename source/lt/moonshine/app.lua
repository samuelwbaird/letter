-- top level moonshine app
-- establishes screen sizing and selects correct assets
-- holds a root view display list to render each frame
-- runs a fixed step update method
-- runs an app_node as the scene
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local dispatch = require('util.dispatch')

local display_data = require('lt.display_data')
local display_list = require('lt.display_list')
local event_dispatch = require('lt.event_dispatch')
local button = require('lt.button')

local render = require('lt.moonshine.render')
local resources = require('lt.moonshine.resources')

return class(function (app)
	
	-- 
	function app.launch(reference_screen_size, asset_scales, initial_scene)
		-- create an app instance
		local app = app(reference_screen_size, asset_scales, initial_scene)
		-- create a renderer instance
		local renderer = render()
		-- make a global reference available to it
		_G.app = app
		_G.renderer = renderer
		
		-- strict access to globals from here on
		setmetatable(_G, {
			__index = function (obj, property)
				error('uninitialised read from global ' .. tostring(property), 2)
			end,
		})
		
		-- start the first scene
		app:set_scene(app.initial_scene)
		return app
	end
	
	function app:init(reference_screen_size, asset_scales, initial_scene)
		-- root objects
		self.current_scene = nil	
		self.root_view = display_list()
		self.resources = resources
		self.dispatch = dispatch()
		-- gameplay paused
		self.paused = false
		-- logical screen size
		self.screen = {
			width = 0,
			height = 0,
		}

		-- set up the root view and scaling
		self:configure_screen_size(reference_screen_size, asset_scales)
		print('screen ' .. self.screen.width .. ' x ' .. self.screen.height .. ' at ' .. self.screen.scale .. ' using ' .. resources.get_asset_suffix())
	
		-- configure buttons to the use the main dispatch delay
		button.delayed_action_callback = function (action)
			self.dispatch:delay(1, action)
		end
		-- configure animation on_complete callbacks to occur 
		display_list.clip.delayed_on_complete_callback = function (action)
			self.dispatch:delay(1, action)
		end
	
		-- set the first scene
		self.initial_scene = initial_scene
	end
	
	function app:configure_screen_size(reference_screen_size, asset_scales)
		-- logical size
		self.screen.width = reference_screen_size.width
		self.screen.height = reference_screen_size.height
	
		-- adapt logical screen size to fill the screen at as close as possible to the reference size
		local wscale = platform.screen.getWidth() / self.screen.width
		local hscale = platform.screen.getHeight() / self.screen.height
	
		-- scale up by the lowest amount and adapt the other dimension
		-- if the scale if very close to one of the asset scales then use it directly to get clearer graphics
		self.screen.scale = hscale < wscale and hscale or wscale
		for _, asset_scale in ipairs(asset_scales) do
			if math.abs(asset_scale.scale - self.screen.scale) < asset_scale.scale * 0.2 then
				self.screen.scale = asset_scale.scale
			end
		end		
		self.screen.width = platform.screen.getWidth() / self.screen.scale
		self.screen.height = platform.screen.getHeight() / self.screen.scale
		self.root_view.scale = self.screen.scale
	
		-- select the correct asset suffix
		local selected = nil
		for _, asset_scale in ipairs(asset_scales) do
			if selected == nil or math.abs(asset_scale.scale - self.screen.scale) < math.abs(selected.scale - self.screen.scale) then
				selected = asset_scale
			end
		end
	
		-- make sure spritesheets are loaded with the right resolution assets
		self.resources.set_asset_suffix(selected.suffix)
		-- make sure fonts are generated with the right resolution assets
		display_data.font.default_asset_scale = selected.scale
		
	end

	function app:dispose()
		self:set_scene(nil)
	end
	
	function app:set_scene(scene, ...)
		if self.current_scene then
			self.current_scene:dispose()
			self.current_scene = nil
		end
		event_dispatch.reset_shared_instance()
		collectgarbage("collect")
	
		if scene then
			if type(scene) == 'string' then
				scene = require(scene) (...)
			end
		
			self.current_scene = scene
			self.current_scene:prepare()
			self.root_view:add(scene.view)
			self.current_scene:begin()
		end
	end

	function app:pause()
		self.paused = true
	end

	function app:resume()
		self.paused = false
	end

	function app:update(delta)
		if self.paused then
			return
		end
		
		-- animation steps prior to entering into update code
		self.root_view:update_animated_clips(delta)
	
		-- any delayed code on the main thread
		self.dispatch:update()
	
		-- scene specific update
		if self.current_scene then
			self.current_scene:update(delta)
		end
	end

	function app:render(renderer)
		if self.paused then
			return
		end
		
		renderer:begin_render()
		if self.root_view then
			self.root_view:render(renderer, 0, 0, 1, 1, 0, 1)
		end		
		renderer:complete_render()
	end	
	
	
end)