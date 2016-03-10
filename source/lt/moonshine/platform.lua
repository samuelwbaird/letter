-- sub in the love2d platform modules for loading as required
for _, module in ipairs({ 'resources', 'network_thread', 'render', 'app'}) do
	package.preload['lt.' .. module] = function ()
		return require('lt.moonshine.' .. module)
	end
end

local platform = {
	moonshine = true,
	screen = js_bridge.screen,
	image = js_bridge.image,
	timer = js_bridge.timer,
	create_texture = function (url, width, height)
		return {
			url = url,
			getWidth = function () return width end,
			getHeight = function () return height end,
		}
	end,
	create_quad = function (x, y, width, height)
		return { x, y, width, height }
	end,
}

-- assign global ref if we can
rawset(_G, 'platform', platform)

local elapsed = 0
platform.timer.start(function (time, delta)
	if app then
		elapsed = elapsed + delta
		local frames = math.ceil(elapsed / 16)
		if frames > 2 then
			frames = 2
			elapsed = 0
		else
			elapsed = elapsed - (frames * 16)
		end
		for f = 1, frames do
			app:update(16)
		end
		app:render()
	else
		elapsed = 0
	end
end)

return platform