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

## How far Aria tilts nose-up/nose-down at full vertical stick, and how
## quickly she eases toward that angle. Small on purpose - just enough that
## climbing and diving read as flying rather than sliding, without the
## sprite ever looking like it's tipping over.
const MAX_BANK := 0.22
const BANK_SPEED := 7.0

## Aria is the title character but renders small on the device this is
## actually played on: 1080 logical units map to roughly 393 CSS px of
## phone height in landscape, putting her 128px sprite at about 47 px on
## screen - and half that in portrait. Scaling is applied here rather than
## in the scene because squash-and-stretch rewrites the same property every
## frame. The collision shape is deliberately left at its authored size, so
## she reads bigger without making hazards harder to dodge.
const ARIA_SCALE := 1.5
const SIDEKICK_SCALE := 0.9

## Peak squash/stretch at full speed - stretched along the direction of
## travel and squashed across it. On a sprite with no animation frames this
## is what sells movement as movement.
const STRETCH_MAX := 0.13
const STRETCH_SMOOTH := 8.0

## A sparkle wake, shed while flying fast enough to warrant one. Reuses the
## pickup burst's mote texture.
## Sized and timed to read as a continuous wake at the scale this actually
## renders on a phone - roughly a third of the design resolution. Shorter
## or smaller than this and it registers as an occasional flicker rather
## than a trail.
const TEX_SPARKLE := preload("res://generated_assets/sparkle.png")
const TRAIL_MIN_SPEED := 0.3
const TRAIL_INTERVAL := 0.045
const TRAIL_LIFETIME := 1.0

const TEX_ARIA := preload("res://imported_assets/aria_sprite.png")
const TEX_REVEAL_PULSE := preload("res://generated_assets/reveal_pulse.png")

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
var _near_hidden := false
var _stretch := 0.0
var _trail_timer := 0.0


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
	_spawn_reveal_pulse()
	var target := _find_nearest_hidden()
	if target:
		target.reveal()
		ProceduralAudio.play_sfx("reveal")
	else:
		ProceduralAudio.play_sfx("reveal_empty")


## A ring that expands from Aria out to exactly REVEAL_RADIUS and fades -
## fires on every tap of Reveal Light, whether or not it found anything, so
## a kid can always see how far the light just searched instead of
## wondering whether the button did anything at all.
func _spawn_reveal_pulse() -> void:
	var pulse := Sprite2D.new()
	pulse.texture = TEX_REVEAL_PULSE
	pulse.global_position = global_position
	pulse.z_index = 5
	pulse.modulate.a = 0.9
	get_parent().add_child(pulse)
	var target_scale: float = (REVEAL_RADIUS * 2.0) / pulse.texture.get_width()
	pulse.scale = Vector2(0.15, 0.15)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pulse, "scale", Vector2(target_scale, target_scale), 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pulse, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(pulse.queue_free)


func _on_dissolve_pressed() -> void:
	if state != State.STUCK or not _current_trap:
		return
	_current_trap.dissolve()
	_current_trap = null
	state = State.NORMAL
	ProceduralAudio.play_sfx("dissolve")
	if touch_controls:
		touch_controls.set_dissolve_highlighted(false)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.3)


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
	if touch_controls:
		touch_controls.set_dissolve_highlighted(true)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.0, 0.75, 0.92), 0.2)


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

	_update_reveal_highlight()
	_update_visuals(delta, absf(move_input.x) > 0.05 or absf(move_input.y) > 0.05)
	_update_trail(delta)


## Drops a sparkle behind Aria while she's moving with purpose. Motes are
## parented to the world rather than to her, so each one stays where it was
## shed and the wake trails behind instead of riding along with her.
func _update_trail(delta: float) -> void:
	if state != State.NORMAL:
		return
	if velocity.length() / SPEED < TRAIL_MIN_SPEED:
		return

	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = TRAIL_INTERVAL

	var parent := get_parent()
	if not parent:
		return

	var mote := Sprite2D.new()
	mote.texture = TEX_SPARKLE
	# Behind the pair, but still above the parallax backdrop.
	mote.z_index = -1
	mote.global_position = global_position \
		- velocity.normalized() * 46.0 \
		+ Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
	var s: float = randf_range(1.0, 1.5)
	mote.scale = Vector2(s, s)
	mote.modulate.a = 0.8
	parent.add_child(mote)

	var tw := mote.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mote, "scale", Vector2.ZERO, TRAIL_LIFETIME).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mote, "modulate:a", 0.0, TRAIL_LIFETIME).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(mote.queue_free)


func _update_reveal_highlight() -> void:
	var near: bool = _find_nearest_hidden() != null
	if near == _near_hidden:
		return
	_near_hidden = near
	if touch_controls:
		touch_controls.set_reveal_highlighted(near)


func _clamp_to_bounds() -> void:
	if not world:
		return
	var bounds := world.get_bounds_px()
	global_position.x = clampf(global_position.x, BOUNDS_MARGIN, bounds.x - BOUNDS_MARGIN)
	global_position.y = clampf(global_position.y, BOUNDS_MARGIN, bounds.y - BOUNDS_MARGIN)


func _update_visuals(delta: float, moving: bool) -> void:
	if absf(move_input.x) > 0.05:
		facing = 1 if move_input.x > 0.0 else -1

	_bob_timer += delta * (5.0 if moving else 2.0)
	sprite.position.y = sin(_bob_timer) * 5.0

	# Stretched along the axis she's travelling and squashed across it, so
	# the same still image reads as moving fast horizontally or climbing.
	# Eased rather than applied directly, or it snaps on every stick flick.
	var target_stretch := 0.0
	if state == State.NORMAL and velocity.length() > 1.0:
		var dir := velocity.normalized()
		var speed_t: float = clampf(velocity.length() / SPEED, 0.0, 1.0)
		target_stretch = speed_t * STRETCH_MAX * (absf(dir.x) - absf(dir.y))
	_stretch = lerpf(_stretch, target_stretch, clampf(STRETCH_SMOOTH * delta, 0.0, 1.0))

	sprite.scale = Vector2(
		ARIA_SCALE * (1.0 + _stretch) * facing,
		ARIA_SCALE * (1.0 - _stretch)
	)
	if sidekick:
		sidekick.scale = Vector2(
			SIDEKICK_SCALE * (1.0 + _stretch) * facing,
			SIDEKICK_SCALE * (1.0 - _stretch)
		)

	# `facing` flips the sprite via a negative scale.x, and Godot applies
	# rotation *after* scale - so the same angle would tilt her the wrong
	# way once mirrored. Multiplying by `facing` keeps the nose leaning into
	# the direction of travel on both headings. Banking is also zeroed out
	# whenever she isn't flying under her own power (stuck in a trap, or
	# being pulled back by a black hole).
	var target_bank := 0.0
	if state == State.NORMAL:
		target_bank = move_input.y * MAX_BANK * facing
	var bank: float = lerpf(sprite.rotation, target_bank, clampf(BANK_SPEED * delta, 0.0, 1.0))
	sprite.rotation = bank
	if sidekick:
		sidekick.rotation = bank


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
