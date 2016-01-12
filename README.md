# love letter
_A reference game implementation for Löve2D_

This repo provides a reference implementation for a game built on top of Löve2D (0.10.0) building on a core lua library (https://github.com/samuelwbaird/core) and implementing much of the functionality and patterns from adilb, an actionscript library for constructing games (https://github.com/samuelwbaird/adlib).

The main features are:

* display_list module implements a simplified actionscript 3 style display list heirachy on top of Löve2D's procedural graphics API
* automatic sprite batching where possible when rendering the display list
* app_node class provides the main heavy weight objects for managing the game and main resource scope and ownership (refer to adlib library)
* a clip display object that can hold both scene and animation data
* touch input and buttons handled as per adlib library
* screen size independence, transparently selecting between multiple asset resolutions
* a spritesheet builder creating high quality resized sheets from a single source (requires https://github.com/samuelwbaird/bozo)
* fixed framerate style main loop
* tweening, delayed dispatch, scene management

## Documentation

The code is only minimally documented at present, some more reference is available at the source repositories for the code and adlib libraries. There are plenty of TODO: notes sprinkled throughout.

The main loop launches and automatically scales to fit the screen size available, choosing a scaling ratio that preserves a logical size and selecting appropriate assets. This, along with the fixed framerate updates means that all game code is coded to a single logical resolution.

A single scene is running at all times, the scene object being an app_node. This object and all its children are updated in step with the frame rate and the view object associated with the scene (a display_list) is rendered once per frame.

### Display list implementation

The main types of display objects for use in the display list are:

* display_list, all others derive from this, but this plain type can be used as a grouping object
* image, displays an image from a sprite sheet
* clip, displays frame based scene or animation data (each frame describes a sub-tree of child objects)
* text, displays text
* rect and circle geometry primitives

Convenience add_ methods are defined for each display object to allow you to create a new child object and add it to the parents display list in one step. For example:

	local view = display_list()
	local img = display_list.image('sprite01')
	img.x = 100
	img.y = 50
	view:add(img)

Can be abbrievated to: 

	local view = display_list()
	view:add_image('sprite01', { x = 100, y = 50 })

Spritesheets are loaded with the resources module, and the spritesheet description files themselves (ldata) are actually valid Lua code, executed in a sandbox.

### Transforms

Typically a 3x3 affine or 4x4 3D transformation matrix would be used to manage the position and scale of each object in the tree, however Löve2D itself renders using simple x, y, scale and rotation values, so the display_list object also uses these simple values as the transform data. This is less generally useful but skips converting back and forth between scalar and matrix values.

Given Lua's register based intepreter and multiple return values the display_list objects also treat this transform data in an unboxed (unpacked) manner. So where a position, bounds or transform is returned or used as a parameter the individual values are passed each time rather than a rect or transform object. This is a bit inconvient for the programmer as the parameters must be checked carefully but removes a whole layer of boxing, unboxing and temporary objects requiring garbage collection.

### Touch handling

Touch events are funnelled from love into a managed event dispatcher (just copying the structure from adlib library). There is a shared instance of this dispatcher used by defaults, which can be replaced when you want to block events or simulate modal input.

Objects in the display list do not handle touches themselves, instead touch_area objects are created, normally with a reference to a display object whose co-ordinate system they should use. The touch_area then fires callbacks on touch events, having preprocesed the touch data into that co-ordinate space and providing some convenience for tracking the touch movement.

## Reference game

The reference game is called Stones (or something like that), its not a great game but it serves to exercise most of the features. Player's take turns placing 3 gems on a 4x3 grid of tiles. After each gem is placed the tiles update their colors to reflect the number of gems around them. If there are more green gems around they turn green, if more blue they turn blue. The winner is the player at the end of the game with the most gems in their color.

The game features a title scene, purely to demonstrate multiple scenes. Scenes are derived classes of the app_node class, which manages a set of resources in a heirachy. Each scene has one view object, which is a display list, the display list can be filled with a tree of sub objects, images, text, rects, clips and other display lists. The transforms applied to any object in the tree affect all children of that object, so a top level display list object is used to resize the contents of the game to fit the screen.

The sprite sheet script creates to sets of spritesheets one for the title scene and another for the main game scene which are loaded when required in the most appriate resolution. When the display list is rendered, consecutive draw calls from the same spritesheet are automatically batch, the batch broken up and flushed whenever required.

The main gameplay is broken up into a few app_node objects, one managing a pointless moving tile background, one for the hint system, one for the tiles and one for the gems (note not one per gem or per tile, which are only lightweight objects).

A model object implements some very basic AI choosing the next best move for the computer player, but a little randomness has been added as the rules of the game are not that clever and like tic-tac-toe a draw is inevitable if the AI plays it straight. 