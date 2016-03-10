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
}

-- assign global ref if we can
rawset(_G, 'platform', platform)

platform.timer.start(function (time, delta)
	if app then
		app:update()
	end
end)

return platform