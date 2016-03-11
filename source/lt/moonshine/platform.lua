-- sub in the love2d platform modules for loading as required
for _, module in ipairs({ 'resources', 'network_thread', 'render', 'app'}) do
	package.preload['lt.' .. module] = function ()
		return require('lt.moonshine.' .. module)
	end
end

local platform = {
	moonshine = true,
	screen = js_bridge.screen,
	graphics = js_bridge.graphics,
	timer = js_bridge.timer,
	create_texture = function (url, width, height)
		js_bridge.graphics.require_image(url);
		return {
			url = url,
			getWidth = function () return width end,
			getHeight = function () return height end,
		}
	end,
	create_quad = function (x, y, width, height, lwidth, lheight)
		return { x, y, width, height, lwidth, lheight }
	end,
	create_font = function (name, size)
		return {
			size = size,
			getHeight = function ()
				return size
			end, 
			getLineHeight = function ()
				return 1
			end,
			getWrap = function (font, text, width)
				return 0, 1
			end,
		}
	end,
}

-- assign global ref if we can
rawset(_G, 'platform', platform)

local event_dispatch = require('lt.event_dispatch')
platform.screen.set_touch_listener(function (event, x, y, id)
	event_dispatch.shared_instance():defer(event, { id = id, x = x, y = y })
end)

platform.timer.start(function (time, delta)
	if app then
		event_dispatch.shared_instance():dispatch_deferred()
		app:reconfigure_screen_size()

		local frames = math.ceil(delta / 16.7)
		if frames > 4 then
			frames = 4
		end
		for f = 1, frames do
			app:update(16)
		end
		app:render()
	end
end)

return platform