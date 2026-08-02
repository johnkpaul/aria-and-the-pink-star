extends Area2D
class_name Asteroid

## A slowly drifting space rock. Bumping into it just bounces Aria back a
## short distance (player.bounce()) - no penalty, no state lost.

const DRIFT_RANGE := 48.0
const DRIFT_TIME := 2.4

@onready var sprite: Sprite2D = $Sprite2D

var _home := Vector2.ZERO


func _ready() -> void:
	add_to_group("asteroid")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	# world_generator.gd sets global_position right after add_child(), which
	# runs *after* _ready() fires - capturing "home" here would grab the
	# node's not-yet-placed (0,0) default instead of its real spawn point.
	# Deferring to the next idle frame waits until that position is set.
	call_deferred("_start_drift")
	if sprite:
		var spin := create_tween()
		spin.set_loops()
		spin.tween_property(sprite, "rotation", sprite.rotation + TAU, randf_range(4.0, 7.0)).set_trans(Tween.TRANS_LINEAR)


func _start_drift() -> void:
	_home = position
	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * DRIFT_RANGE
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "position", _home + offset, DRIFT_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position", _home - offset, DRIFT_TIME).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("bounce"):
		var dir: Vector2 = (body.global_position - global_position)
		if dir.length() < 1.0:
			dir = Vector2.UP
		body.bounce(dir.normalized())
