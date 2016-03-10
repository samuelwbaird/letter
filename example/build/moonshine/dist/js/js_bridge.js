'use strict';

// exported module
var js_bridge = {}; window.js_bridge = js_bridge;

// shared environment within this file
var shared = {};

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
	var canvas, ctx;
	
	screen.createCanvas = function (parent, width, height) {
		canvas = document.createElement("canvas");
		ctx = canvas.getContext("2d");
		canvas.width = width;
		canvas.height = height;
		parent.appendChild(canvas);
	};
	
	screen.getWidth = function () { return canvas.width; };
	screen.getHeight = function () { return canvas.height; };
});

// -- image module -----------------------------------------------

js_bridge.image = modul(function (image) {
	var images = {};
	
	image.require = function (url) {
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
	}

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
	
	var _callback;
	
	timer.start = function (callback) {
		timer.stop();
		
		_callback = callback;
		_callback.retain();
		var last = Date.now();
		var next_frame = function () {
			if (callback != _callback) {
				return;
			}
			requestAnimFrame(next_frame);
			
		    var now = Date.now();
		    var dt = (now - last) / 1000.0;
			last = now;
			callback.call("something", now, dt);
		}
		requestAnimFrame(next_frame);
	}
	
	timer.stop = function () {
		if (_callback != null) {
			_callback.release();
			_callback = null;
		}
	}
	
});