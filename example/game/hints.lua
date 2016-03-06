-- a child node used to display the hint
-- separating this as a child node allows the tween manager and dispatch objects to be cleared
-- just for this node and easily managed
-- demonstrates a text label in the display list and the use of event_dispath.push_shared_dispatch
-- to establish a model context where existing event handlers are blocked temporarily
-- copyright 2016 Samuel Baird MIT Licence

local class = require('core.class')

local app_node = require('lt.app_node')
local display_data = require('lt.display_data')
local event_dispatch = require('lt.event_dispatch')
local tween = require('lt.tween')

return class.derive(app_node, function (hints)
	
	function hints:prepare()
	end
	
	function hints:begin()
		-- hints are nominally 460 wide and centered
		self.view.x = (app.screen.width - 460) * 0.5
		self.rect = self.view:add_rect(460, 28, display_data.color(220, 210, 140))
		
		self.label = self.view:add_label(display_data.font(13), {
			align = "center",
			wrap_width = 420,
			x = 230,
			y = 5,
		})
		
		-- begin offscreen for use later
		self.view.y = -30
		self.is_hinting = false
	end
	
	function hints:show_text(text, block_touches, on_complete, clear_after)
		-- block the main event dispatch to block touches to pre-existing touch areas
		self:end_hint(true)

		self.is_hinting = true
		self.block_touches = block_touches
		if block_touches then
			event_dispatch.push_shared_instance()
		end
		-- allow a single touch event to cancel the hint early (but not too early)
		self.dispatch:delay(20, function ()
			self:enable_touch_cancel()
		end)
		
		self.on_complete = on_complete
		self.label.text = text
		
		-- auto resize the rectangle area
		local tx, ty, tw, th = self.label:bounds()
		if th > 20 then
			self.rect.scale_y = (th + 10) / 28
		else
			self.rect.scale_y = 1
		end
		
		self:tween(self.view, tween.easing.ease_out(20), {
			y = 0
		})
		
		self.dispatch:delay(clear_after or (60 * 3), function ()
			self:end_hint()
		end)
	end
	
	function hints:enable_touch_cancel()
		self.event_handler:unlisten()
		self.event_handler = nil
		
		-- create a fresh event handler each time to make sure we are using the top of stack event_dispatcher
		self.event_handler:listen('touch_begin', function (touch_data)
			self:end_hint()
		end)
	end
	
	function hints:end_hint(cancel)
		self.event_handler:unlisten()
	
		if self.is_hinting then
			if self.block_touches then
				event_dispatch.pop_shared_instance()
			end
			self.is_hinting = false
			self.tween_manager:clear()
			self.dispatch:clear()

			if not cancel then
				local _, _, _, rect_height = self.rect:bounds(self.view)
				self:tween(self.view, tween.easing.ease_in(20), {
					y = rect_height * -1.1,
				}, function ()
					if self.on_complete then
						self.on_complete()				
					end
				end)
			end
		end
	end
	
end)