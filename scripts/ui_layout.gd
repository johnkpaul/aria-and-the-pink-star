extends RefCounted
class_name UILayout

## Every full-screen UI in this game is authored against a fixed 1920x1080
## canvas using absolute offsets and no anchors. That's fine as long as the
## logical viewport really is 1920x1080 - but `stretch/aspect="expand"`
## grows the logical width on any screen wider than 16:9, and an iPhone 16
## in landscape is about 2.17:1, which yields a ~2340-wide space. The
## authored canvas then sits hard against the left with a dead strip down
## the right, and full-screen background rects stop short of the edge.
##
## Rather than re-anchor several dozen nodes across four scenes, each UI
## CanvasLayer is shifted so its 1920-wide canvas is centred, and the rects
## that are meant to cover the screen are stretched to the real viewport.

const DESIGN := Vector2(1920.0, 1080.0)


static func _viewport_size(node: Node) -> Vector2:
	return node.get_viewport().get_visible_rect().size


## Centres a layer's authored 1920x1080 canvas inside the real viewport,
## and keeps it centred if the window is later resized or rotated (which on
## a phone happens constantly - Safari's toolbar collapsing alone fires it).
##
## A per-call lambda is used rather than `_apply.bind(layer, covers)`
## because Callable equality ignores bound arguments: every bound copy of
## the same static method compares equal, so connecting a second layer was
## rejected as a duplicate connection and only the first layer on screen
## ever tracked resizes. The connection is dropped when the layer leaves
## the tree, since the level-intro and mission screens are created and
## freed repeatedly and would otherwise pile up dead handlers.
static func keep_centered(layer: CanvasLayer, covers: Array = []) -> void:
	_apply(layer, covers)
	var viewport := layer.get_viewport()
	var on_resize := func() -> void: _apply(layer, covers)
	viewport.size_changed.connect(on_resize)
	layer.tree_exiting.connect(func() -> void:
		if is_instance_valid(viewport) and viewport.size_changed.is_connected(on_resize):
			viewport.size_changed.disconnect(on_resize)
	)


static func _apply(layer: CanvasLayer, covers: Array) -> void:
	if not is_instance_valid(layer):
		return
	var vp := _viewport_size(layer)
	layer.offset = ((vp - DESIGN) * 0.5).round()
	for c in covers:
		if is_instance_valid(c):
			cover_viewport(c, layer)


## Stretches a rect to cover the entire viewport despite living inside a
## layer that's been shifted - used for backdrops and the screen fader,
## which have to reach the physical edges or they leave visible strips.
static func cover_viewport(rect: Control, layer: CanvasLayer) -> void:
	rect.position = -layer.offset
	rect.size = _viewport_size(layer)
