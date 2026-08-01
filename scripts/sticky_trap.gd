extends Area2D
class_name StickyTrap

## A blob of pink goo on a planet's surface. Flying into it freezes Aria
## in place (see player.gd's get_stuck) until Dissolve Light is used on it,
## at which point it melts away permanently - no permanent penalty, just a
## brief detour.

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("sticky_trap")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_start_wobble()


func _start_wobble() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "scale", Vector2(1.08, 0.94), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2(0.94, 1.08), 0.5).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("get_stuck"):
		body.get_stuck(self)


func dissolve() -> void:
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.4, 0.3), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)
