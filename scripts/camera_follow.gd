extends Camera2D
class_name CameraFollow

## Smoothly follows the player, clamped to the current level's pixel bounds
## so the 1920x1080 view never shows past the edge of the world.

@export var follow_speed: float = 4.0

## How much the background drifts relative to the camera - small enough
## that a level's max camera travel never pulls the (fixed-size) background
## texture's edge into view, but still enough to read as depth rather than
## a flat backdrop glued to the screen.
const PARALLAX_FACTOR := 0.08

var target: Node2D
var parallax_target: Node2D
var bounds_min := Vector2.ZERO
var bounds_max := Vector2.ZERO
var _has_bounds := false

## The camera's own position when parallax was set up for this level (i.e.
## its initial clamped position) - the background sprite sits exactly here
## at that moment and only drifts a small fraction of movement *away* from
## it. Offsetting by a fraction of the camera's raw world position instead
## (its distance from world origin, which is arbitrary and can be large)
## was the original bug here: it could push the background's fixed-size
## texture far enough off-center to expose empty space at the view's edge.
var _parallax_base := Vector2.ZERO

## The level size this camera is currently clamped to, kept so the bounds
## can be recomputed when the viewport changes shape.
var _level_size := Vector2.ZERO


func _ready() -> void:
	position_smoothing_enabled = false  # we do our own clamped smoothing
	# Rotating a phone changes the view's shape, and with it how far the
	# camera is allowed to travel before it would show past the level edge.
	get_viewport().size_changed.connect(_recompute_bounds)


func set_target(node: Node2D) -> void:
	target = node
	if target:
		global_position = _clamp_to_bounds(target.global_position)
		_update_parallax()


func set_parallax_target(node: Node2D) -> void:
	parallax_target = node
	_parallax_base = global_position
	_update_parallax()


func _update_parallax() -> void:
	if parallax_target:
		parallax_target.global_position = _parallax_base + (global_position - _parallax_base) * PARALLAX_FACTOR


func set_level_bounds(width_px: float, height_px: float) -> void:
	_level_size = Vector2(width_px, height_px)
	_recompute_bounds()


## Derived from the *actual* viewport rather than a hard-coded 1920x1080.
## `stretch/aspect="expand"` means the view is only that size at exactly
## 16:9 - held in portrait the logical view is far taller than 1080, and
## clamping to the old constant let the camera drift well past the top and
## bottom of the level, showing empty space above and below the play field.
func _recompute_bounds() -> void:
	if _level_size == Vector2.ZERO:
		return
	var half: Vector2 = get_viewport().get_visible_rect().size / 2.0

	if _level_size.x <= half.x * 2.0:
		bounds_min.x = _level_size.x / 2.0
		bounds_max.x = _level_size.x / 2.0
	else:
		bounds_min.x = half.x
		bounds_max.x = _level_size.x - half.x

	if _level_size.y <= half.y * 2.0:
		bounds_min.y = _level_size.y / 2.0
		bounds_max.y = _level_size.y / 2.0
	else:
		bounds_min.y = half.y
		bounds_max.y = _level_size.y - half.y

	_has_bounds = true


func _physics_process(delta: float) -> void:
	if not target:
		return
	var desired := _clamp_to_bounds(target.global_position)
	global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	_update_parallax()


func _clamp_to_bounds(pos: Vector2) -> Vector2:
	if not _has_bounds:
		return pos
	return Vector2(
		clampf(pos.x, bounds_min.x, bounds_max.x),
		clampf(pos.y, bounds_min.y, bounds_max.y)
	)


## Brief punchy shake for impacts (drilling, block placement landing).
## Small and short by design - this is a kids' game, not an explosion.
func shake(amount: float = 8.0, duration: float = 0.09) -> void:
	var tw := create_tween()
	tw.tween_property(self, "offset", Vector2(amount, amount * 0.5), duration * 0.33)
	tw.tween_property(self, "offset", Vector2(-amount, -amount * 0.5), duration * 0.33)
	tw.tween_property(self, "offset", Vector2.ZERO, duration * 0.34)
