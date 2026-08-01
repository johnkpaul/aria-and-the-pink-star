extends CharacterBody2D
class_name Player

## Aria. All input arrives via TouchControls signals (joystick_moved,
## reveal_pressed, dissolve_pressed) — never through InputMap, since this
## game is touch-native. Mouse events are translated into the same signals
## upstream by TouchControls for desktop testing.
##
## Aria flies freely in open space - no gravity, no floor. The joystick
## drives velocity directly on both axes.

enum State { NORMAL, STUCK, PULLED }

const SPEED := 420.0
const REVEAL_RADIUS := 220.0
const BOUNCE_STRENGTH := 320.0
const BOUNDS_MARGIN := 40.0

const TEX_ARIA := preload("res://imported_assets/aria_sprite.png")

@onready var sprite: Sprite2D = $Sprite2D
@onready var sidekick: Sprite2D = $Sidekick

var world: WorldGenerator
var touch_controls: TouchControls

var state: State = State.NORMAL
var move_input := Vector2.ZERO
var facing := 1
var last_safe_position := Vector2.ZERO

var _current_trap: Node2D
var _bob_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 0
	sprite.texture = TEX_ARIA

	touch_controls = get_tree().get_first_node_in_group("touch_controls")
	if touch_controls:
		touch_controls.joystick_moved.connect(_on_joystick_moved)
		touch_controls.reveal_pressed.connect(_on_reveal_pressed)
		touch_controls.dissolve_pressed.connect(_on_dissolve_pressed)


func set_world(w: WorldGenerator) -> void:
	world = w


func set_safe_position(pos: Vector2) -> void:
	last_safe_position = pos


func _on_joystick_moved(vec: Vector2) -> void:
	move_input = vec


func _on_reveal_pressed() -> void:
	if state == State.PULLED:
		return
	var target := _find_nearest_hidden()
	if target:
		target.reveal()
		ProceduralAudio.play_sfx("reveal")


func _on_dissolve_pressed() -> void:
	if state != State.STUCK or not _current_trap:
		return
	_current_trap.dissolve()
	_current_trap = null
	state = State.NORMAL
	ProceduralAudio.play_sfx("dissolve")


func _find_nearest_hidden() -> Node2D:
	var best: Node2D = null
	var best_dist := REVEAL_RADIUS
	for c in get_tree().get_nodes_in_group("collectible"):
		if c.is_revealed():
			continue
		var d: float = global_position.distance_to(c.global_position)
		if d <= best_dist:
			best_dist = d
			best = c
	return best


func get_stuck(trap: Node2D) -> void:
	if state != State.NORMAL:
		return
	state = State.STUCK
	_current_trap = trap
	velocity = Vector2.ZERO
	ProceduralAudio.play_sfx("stuck")


func bounce(direction: Vector2) -> void:
	if state != State.NORMAL:
		return
	velocity = direction * BOUNCE_STRENGTH
	move_and_slide()
	ProceduralAudio.play_sfx("bump")
	if world and world.camera:
		world.camera.shake(6.0)


func _physics_process(delta: float) -> void:
	if state == State.PULLED:
		return

	if state == State.STUCK:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_visuals(delta, false)
		return

	velocity = move_input * SPEED

	var in_danger := false
	for hole in get_tree().get_nodes_in_group("black_hole"):
		var dist: float = global_position.distance_to(hole.global_position)
		if dist < BlackHole.EVENT_RADIUS:
			_get_pulled_back()
			return
		elif dist < BlackHole.PULL_RADIUS:
			in_danger = true
			var dir: Vector2 = (hole.global_position - global_position).normalized()
			var t: float = 1.0 - (dist - BlackHole.EVENT_RADIUS) / (BlackHole.PULL_RADIUS - BlackHole.EVENT_RADIUS)
			velocity += dir * BlackHole.PULL_STRENGTH * t

	move_and_slide()
	_clamp_to_bounds()

	if not in_danger:
		last_safe_position = global_position

	_update_visuals(delta, absf(move_input.x) > 0.05 or absf(move_input.y) > 0.05)


func _clamp_to_bounds() -> void:
	if not world:
		return
	var bounds := world.get_bounds_px()
	global_position.x = clampf(global_position.x, BOUNDS_MARGIN, bounds.x - BOUNDS_MARGIN)
	global_position.y = clampf(global_position.y, BOUNDS_MARGIN, bounds.y - BOUNDS_MARGIN)


func _update_visuals(delta: float, moving: bool) -> void:
	if absf(move_input.x) > 0.05:
		facing = 1 if move_input.x > 0.0 else -1
	sprite.scale.x = absf(sprite.scale.x) * facing
	if sidekick:
		sidekick.scale.x = absf(sidekick.scale.x) * facing

	_bob_timer += delta * (5.0 if moving else 2.0)
	sprite.position.y = sin(_bob_timer) * 4.0


func _get_pulled_back() -> void:
	if state == State.PULLED:
		return
	state = State.PULLED
	velocity = Vector2.ZERO
	ProceduralAudio.play_sfx("pulled")

	var flash := ColorRect.new()
	flash.color = Color(0.05, 0.0, 0.15, 0.0)
	flash.size = Vector2(1920, 1080)
	flash.position = -Vector2(960, 540)
	flash.z_index = 100
	add_child(flash)

	var tw := create_tween()
	tw.tween_property(flash, "color:a", 1.0, 0.12)
	tw.tween_callback(func():
		global_position = last_safe_position
		velocity = Vector2.ZERO
	)
	tw.tween_property(flash, "color:a", 0.0, 0.3)
	tw.tween_callback(func():
		flash.queue_free()
		state = State.NORMAL
	)
