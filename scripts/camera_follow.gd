extends Camera2D
class_name CameraFollow

## Smoothly follows the player, clamped to the current level's pixel bounds
## so the 1920x1080 view never shows past the edge of the world.

@export var follow_speed: float = 4.0

var target: Node2D
var bounds_min := Vector2.ZERO
var bounds_max := Vector2.ZERO
var _has_bounds := false

const VIEW_SIZE := Vector2(1920, 1080)


func _ready() -> void:
	position_smoothing_enabled = false  # we do our own clamped smoothing


func set_target(node: Node2D) -> void:
	target = node
	if target:
		global_position = _clamp_to_bounds(target.global_position)


func set_level_bounds(width_px: float, height_px: float) -> void:
	var half := VIEW_SIZE / 2.0
	if width_px <= VIEW_SIZE.x:
		bounds_min.x = width_px / 2.0
		bounds_max.x = width_px / 2.0
	else:
		bounds_min.x = half.x
		bounds_max.x = width_px - half.x

	if height_px <= VIEW_SIZE.y:
		bounds_min.y = height_px / 2.0
		bounds_max.y = height_px / 2.0
	else:
		bounds_min.y = half.y
		bounds_max.y = height_px - half.y

	_has_bounds = true


func _physics_process(delta: float) -> void:
	if not target:
		return
	var desired := _clamp_to_bounds(target.global_position)
	global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))


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
