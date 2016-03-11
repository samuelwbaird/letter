'use strict';

// exported module
var js_bridge = {}; window.js_bridge = js_bridge;

// shared environment within this file
var shared = {};
var canvas = null;
var ctx = null;

// module pattern
var modul = function (module_constructor) { var mod = {}; module_constructor(mod); return mod; };

// class pattern
var klass = function (class_constructor) {
	var constructor = function () {  
		// init method called as an instance constructor if supplied
		if (constructor.prototype.init !== undefined) {
			constructor.prototype.init.apply(this, arguments)
		}
	};
	
	// prepare the prototype
	constructor.prototype = {};
	class_constructor(prototype);
};

// -- screen module -----------------------------------------------

js_bridge.screen = modul(function (screen) {
	screen.createCanvas = function (parent, width, height) {
		canvas = document.createElement("canvas");
		ctx = canvas.getContext("2d");
		canvas.width = width;
		canvas.height = height;
		parent.appendChild(canvas);
		
		canvas.addEventListener("mousedown", function (evt) { screen.touch_event('touch_begin', evt); }, false);
		canvas.addEventListener("mousemove", function (evt) { screen.touch_event('touch_move', evt); }, false);
		canvas.addEventListener("mouseup", function (evt) { screen.touch_event('touch_end', evt); }, false);
		
		return canvas;
	};
	
	screen.getWidth = function () { return canvas.width; };
	screen.getHeight = function () { return canvas.height; };
	
	var callback = null;
	
	screen.touch_event = function (event_name, evt) {
		evt.preventDefault();
		if (callback != null) {
			callback.call('something', event_name, evt.pageX - canvas.offsetLeft, evt.pageY - canvas.offsetTop, 1);
		}
	};
	
	// pipe through touch events
	screen.set_touch_listener = function (touch_callback) {
		callback = touch_callback;
		callback.retain();
	};
});

// -- graphics module --------------------------------------------

js_bridge.graphics = modul(function (graphics) {
	var images = {};
	
	graphics.require_image = function (url) {
		var img = images[url];
		
		if (img == null) {
			img = new Image();
			images[url] = img;
			img.onload = function () {
				img.has_loaded = true;
			}
			img.onerror = function () {
				images[url] = null;
			}
			img.src = url
		}
		
		if (img.has_loaded) {
			return img;
		} else {
			return null;
		}
	};
	
	graphics.draw_quad = function (url, qx, qy, qw, qh, ix, iy, iw, ih, x, y, sx, sy) {
		var img = images[url];
		if (img == null) {
			return;
		}
		
	    ctx.save();
		ctx.translate(x, y);
	    ctx.scale(sx, sy);
		ctx.drawImage(img, qx, qy, qw, qh, ix, iy, iw, ih);
	    ctx.restore();
	};
	
	
});

// -- timer module -----------------------------------------------

js_bridge.timer = modul(function (timer) {

	// cross browser request animation frame
	var requestAnimFrame = (function() {
	    return window.requestAnimationFrame       ||
	        window.webkitRequestAnimationFrame ||
	        window.mozRequestAnimationFrame    ||
	        window.oRequestAnimationFrame      ||
	        window.msRequestAnimationFrame     ||
	        function(callback) {
	            window.setTimeout(callback, 1000 / 60);
	        };
	}) ();
	
	var _active = false;
	
	timer.start = function (callback) {
		_active = true;
		
		var last = Date.now();
		var next_frame = function () {
			if (!_active) {
				return;
			}
			requestAnimFrame(next_frame);
			
			_active = false;
		    var now = Date.now();
		    var dt = (now - last) / 1000.0;
			last = now;
			callback.call("something", now, dt);
			// make sure this stops after errors...
			_active = true;
		}
		requestAnimFrame(next_frame);
	}
	
});