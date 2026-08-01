extends Area2D
class_name Collectible

## A hidden key (or, in the final level, the pink gem). Invisible and
## non-collidable until Aria's Reveal Light finds it (see player.gd's
## _find_nearest_hidden/reveal), at which point it fades in, starts
## pulsing, and becomes collectible on contact like any pickup.

signal collected(gem: bool)

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

const TEX_KEY := preload("res://generated_assets/key.png")
const TEX_GEM := preload("res://generated_assets/gem.png")

var _gem := false
var _revealed := false
var _collected := false


func _ready() -> void:
	add_to_group("collectible")
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	modulate.a = 0.0
	body_entered.connect(_on_body_entered)


func set_gem(gem: bool) -> void:
	_gem = gem
	if sprite:
		sprite.texture = TEX_GEM if gem else TEX_KEY
	if shape and shape.shape is RectangleShape2D:
		var size := 72.0 if gem else 56.0
		(shape.shape as RectangleShape2D).size = Vector2(size, size)


func is_revealed() -> bool:
	return _revealed


func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	monitoring = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	_start_pulse()


func _start_pulse() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not _revealed or not body.is_in_group("player"):
		return
	_collected = true
	collected.emit(_gem)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)
