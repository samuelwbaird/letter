-- top level love2D app
-- establishes screen sizing and selects correct assets
-- holds a root view display list to render each frame
-- runs a fixed step update method
-- runs an app_node as the scene
-- proxies all touch events from love into the managed event dispatch and handler
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')
local dispatch = require('util.dispatch')

local display_data = require('lt.display_data')
local display_list = require('lt.display_list')
local event_dispatch = require('lt.event_dispatch')
local button = require('lt.button')

local render = require('lt.love.render')
local resources = require('lt.love.resources')

return class(function (app)

	--[[
	Create an app object with the require settings then install all the required
	Love2D callbacks to make it function eg.
	
	local app = require('lt.app')
	app.launch(
		-- preferred logical screen size
		{ 480, 320 },
		-- available asset sizes and suffixes
		{
			{ scale = 1, suffix = '_x1'},
			{ scale = 2, suffix = '_x2'},
			{ scale = 4, suffix = '_x4'},
		},
		-- initial scene to launch
		'game.intro_scene',
	)
	
	]]
	
	function app.launch(reference_screen_size, asset_scales, initial_scene)
		-- event handling
		local mouse_is_pressed = false

		function love.mousepressed(x, y, button, is_touch)
			-- treating primary mouse as a touch
			if not is_touch and button == 1 then
				mouse_is_pressed = true
				event_dispatch.shared_instance():defer('touch_begin', { id = 1, x = x, y = y })
			end
		end

		function love.mousereleased(x, y, button, is_touch)
			-- treating primary mouse as a touch
			if not is_touch and button == 1 then
				mouse_is_pressed = false
				event_dispatch.shared_instance():defer('touch_end', { id = 1, x = x, y = y })
			end
		end

		function love.mousemoved(x, y, dx, dy)
			if mouse_is_pressed then
				event_dispatch.shared_instance():defer('touch_move', { id = 1, x = x, y = y })
			end
		end

		function love.touchpressed(id, x, y, pressure)
			event_dispatch.shared_instance().defer('touch_begin', { id = id, x = x, y = y })
		end

		function love.touchreleased(id, x, y, pressure)
			event_dispatch.shared_instance():defer('touch_end', { id = id, x = x, y = y })	
		end

		function love.touchmoved(id, x, y, pressure)
			event_dispatch.shared_instance():defer('touch_move', { id = id, x = x, y = y })	
		end

		-- main run loop and frame timing
		local app_is_running = true

		function love.handle_native_events()
			-- handle events
			if love.event then
				love.event.pump()
				for name, a,b,c,d,e,f in love.event.poll() do
					if name == "quit" then
						app_is_running = false
					end
					love.handlers[name](a,b,c,d,e,f)
				end
			end
		end

		function love.run()
			-- create an app instance
			local app = app(reference_screen_size, asset_scales, initial_scene)
			-- make a global reference available to it
			_G.app = app
			-- strict access to globals from here on
			setmetatable(_G, {
				__index = function (obj, property)
					error('uninitialised read from global ' .. tostring(property), 2)
				end,
				__newindex = function (obj, property, value)
					error('uninitialise write to global ' .. tostring(property), 2)
				end,
			})
			app:set_scene(app.initial_scene)
			
			local last_frame_time = love.timer.getTime()
			local fps = 60.0
			local frame_time = 1.0 / fps
			local renderer = render()
	
			-- fixed framerate loop
			while app_is_running do
				if app.paused then
					if love.timer then love.timer.sleep(0.1) end
					last_frame_time = love.timer.getTime()
					love.handle_native_events()
			
				else
					local now = love.timer.getTime()
					local delta = now - last_frame_time
					-- make sure we sleep for at least most of a whole frame, rely on vsync for final timing
					if delta < frame_time then
						love.timer.sleep(frame_time - delta)
					end
			
					local frames = math.floor((delta / frame_time) + 0.5)
					if frames < 1 then
						-- produce at least one frame (assuming vsync will keep us at 60)
						frames = 1
					elseif frames > 10 then
						-- if there is a big pause then treat it as a pause
						frames = 1
					end
			
					for frame = 1, frames do
						app.time = love.timer.getTime()
						-- some compatability with love timer class
						love.timer.step()
				
						-- event handling
						love.handle_native_events()
						event_dispatch.shared_instance():dispatch_deferred()
				
						-- fixed update
						app:update(frame_time)
					end
			
					-- render, relying on vsync to round out the timing
					app:render(renderer)
					last_frame_time = now
				end
			end
	
			if app then
				app:dispose()
				app = nil
			end	
		end
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
		if love.graphics and love.graphics.isActive() then
			renderer:begin_render()
			if self.root_view then
				self.root_view:render(renderer, 0, 0, 1, 1, 0, 1)
			end		
			renderer:complete_render()
		end
	end	
	
end)
