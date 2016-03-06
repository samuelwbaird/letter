-- sub in the love2d platform modules for loading as required
for _, module in ipairs({ 'resources', 'network_thread', 'render', 'app'}) do
	package.preload['lt.' .. module] = function ()
		return require('lt.love.' .. module)
	end
end

local platform = {
	love = true,
}

-- assign global ref if we can
rawset(_G, 'platform', platform)

return platform