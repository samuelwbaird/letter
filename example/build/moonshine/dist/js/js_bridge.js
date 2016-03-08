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

