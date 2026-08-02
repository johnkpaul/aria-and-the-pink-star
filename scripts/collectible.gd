extends Area2D
class_name Collectible

## A hidden key (or, in the final level, the pink gem). Invisible and
## non-collidable until Aria's Reveal Light finds it (see player.gd's
## _find_nearest_hidden/reveal), at which point it fades in, starts
## pulsing, and becomes collectible on contact like any pickup.

signal collected(gem: bool, world_pos: Vector2)

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

const TEX_KEY := preload("res://generated_assets/key.png")
const TEX_GEM := preload("res://generated_assets/gem.png")
const TEX_SPARKLE := preload("res://generated_assets/sparkle.png")

## Collecting is the core reward moment of the whole game, so it gets a
## burst of motes flung outward rather than only the scale-and-fade the
## pickup itself does. The gem (one per game, the final objective) throws
## more of them, further, so it visibly outranks a regular key.
const BURST_COUNT_KEY := 10
const BURST_COUNT_GEM := 18

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


## Collision is deliberately withheld until the fade-in finishes. Enabling
## it up front meant that revealing a key you were already standing on
## collected it instantly, while the sprite was still at alpha ~0 - so the
## key was picked up without ever being seen, and the whole find-and-grab
## beat collapsed into one indistinguishable instant. Now it visibly
## appears first, then becomes grabbable.
func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_enable_pickup)
	_start_pulse()


func _enable_pickup() -> void:
	if _collected:
		return
	monitoring = true
	# Godot only emits body_entered on an actual crossing, so a player
	# already sitting inside the area when monitoring switches on would
	# never trigger it. Check the standing overlap explicitly.
	await get_tree().physics_frame
	if _collected or not is_instance_valid(self):
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_body_entered(body)
			return


func _start_pulse() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not _revealed or not body.is_in_group("player"):
		return
	_collected = true
	_spawn_burst()
	collected.emit(_gem, global_position)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)


## Motes are parented to the world, not to `self` - this node queue_frees
## itself ~0.15s from now, and a tween created on a freed node is killed
## with it, so anything outliving the pickup has to live outside it.
func _spawn_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	var count: int = BURST_COUNT_GEM if _gem else BURST_COUNT_KEY
	var spread: float = 130.0 if _gem else 90.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(count):
		var mote := Sprite2D.new()
		mote.texture = TEX_SPARKLE
		mote.global_position = global_position
		mote.z_index = 6
		var s: float = rng.randf_range(0.5, 1.0)
		mote.scale = Vector2(s, s)
		parent.add_child(mote)

		# Evenly fanned rather than fully random, so a burst never clumps
		# into one lopsided spray on an unlucky roll.
		var angle: float = (TAU * i / count) + rng.randf_range(-0.25, 0.25)
		var dist: float = spread * rng.randf_range(0.6, 1.0)
		var target: Vector2 = global_position + Vector2.from_angle(angle) * dist
		var dur: float = rng.randf_range(0.35, 0.6)

		var mt := mote.create_tween()
		mt.set_parallel(true)
		mt.tween_property(mote, "global_position", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		mt.tween_property(mote, "scale", Vector2.ZERO, dur).set_trans(Tween.TRANS_SINE)
		mt.tween_property(mote, "rotation", rng.randf_range(-PI, PI), dur)
		mt.chain().tween_callback(mote.queue_free)
