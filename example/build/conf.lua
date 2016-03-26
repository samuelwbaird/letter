function love.conf(t)
    t.identity = "love_project"			-- The name of the save directory (string)
    t.version = "0.10.0"                -- The LÖVE version this game was made for (string)

    t.window.title = "Love Project"     -- The window title (string)
    t.window.icon = nil                 -- Filepath to an image to use as the window's icon (string)
	
    t.window.width = 568                -- The window width (number)
    t.window.height = 320               -- The window height (number)
    t.window.borderless = false         -- Remove all border visuals from the window (boolean)
    t.window.resizable = false          -- Let the window be user-resizable (boolean)
    t.window.minwidth = 480             -- Minimum window width if the window is resizable (number)
    t.window.minheight = 320            -- Minimum window height if the window is resizable (number)
    
	t.window.fullscreen = true         -- Enable fullscreen (boolean)
    t.window.fullscreentype = "desktop" -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
    t.window.vsync = true               -- Enable vertical sync (boolean)
    t.window.msaa = 0                   -- The number of samples to use with multi-sampled antialiasing (number)
    t.window.highdpi = true             -- Enable high-dpi mode for the window on a Retina display (boolean)
	
    t.window.display = nil              -- Index of the monitor to show the window in (number)
    t.window.x = nil
    t.window.y = nil
end