extends CanvasLayer
class_name TouchControls

## Primary input system for Aria and the Pink Star. Owns the virtual
## joystick (left half of screen, both axes since Aria flies freely) and
## two action buttons (right half): Reveal Light and Dissolve Light.
## Player.gd listens to these signals instead of reading InputMap directly.

signal joystick_moved(vector: Vector2)
signal reveal_pressed
signal dissolve_pressed

const JOYSTICK_RADIUS := 232.0
const DEADZONE := 0.15

## The joystick used to be fully invisible until a finger touched the left
## half of the screen, which meant a first-time player had nothing on
## screen telling them flying was even possible. It now rests visibly at
## the spot the scene parks it, dimmed, and returns there on release -
## touching anywhere on the left still works exactly as before.
const JOY_IDLE_ALPHA := 0.45
const JOY_ACTIVE_ALPHA := 1.0
## Radius (in the 1920x1080 UI space) of the little looping orbit the thumb
## traces to demonstrate the drag gesture before it's ever been used.
const JOY_HINT_RADIUS := 70.0
const JOY_HINT_PERIOD := 2.4

@onready var joystick: Control = $Joystick
@onready var joy_base: TextureRect = $Joystick/Base
@onready var joy_thumb: TextureRect = $Joystick/Thumb
@onready var reveal_button: TouchButton = $RevealButton
@onready var dissolve_button: TouchButton = $DissolveButton

var _joy_touch_index := -2  # -2 = untouched, -1 = mouse
var _joy_center := Vector2.ZERO
var _joy_vector := Vector2.ZERO
var _dissolve_highlight_tween: Tween
var _reveal_highlight_tween: Tween

## Where the scene authored the joystick (bottom-left). Captured after the
## first layout pass rather than in _ready(), since anchored children
## haven't resolved their positions yet at that point.
var _park_base_pos := Vector2.ZERO
var _park_thumb_pos := Vector2.ZERO
var _parked := false
var _ever_dragged := false
var _hint_tween: Tween


func _ready() -> void:
	add_to_group("touch_controls")
	layer = 10
	joy_base.modulate.a = 0.0
	joy_thumb.modulate.a = 0.0

	reveal_button.pressed.connect(func(): reveal_pressed.emit())
	dissolve_button.pressed.connect(func(): dissolve_pressed.emit())

	_prevent_browser_scroll()
	_capture_park_positions.call_deferred()


func _capture_park_positions() -> void:
	await get_tree().process_frame
	_park_base_pos = joy_base.global_position
	_park_thumb_pos = joy_thumb.global_position
	_parked = true
	_return_to_park()
	_start_drag_hint()


func _return_to_park() -> void:
	if not _parked:
		return
	joy_base.global_position = _park_base_pos
	joy_thumb.global_position = _park_thumb_pos
	joy_base.modulate.a = JOY_IDLE_ALPHA
	joy_thumb.modulate.a = JOY_IDLE_ALPHA
	joy_thumb.scale = Vector2.ONE


## Traces the thumb slowly around its parked centre so the control reads as
## "drag me" rather than "a decoration". Runs only until the player drags
## for the first time, then never again.
func _start_drag_hint() -> void:
	if _ever_dragged or not _parked:
		return
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	var steps := 24
	for i in range(steps + 1):
		var angle: float = TAU * float(i) / steps
		var offset := Vector2.from_angle(angle) * JOY_HINT_RADIUS
		_hint_tween.tween_property(
			joy_thumb, "global_position", _park_thumb_pos + offset, JOY_HINT_PERIOD / steps
		).set_trans(Tween.TRANS_SINE)


func _stop_drag_hint() -> void:
	_ever_dragged = true
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null


func _input(event: InputEvent) -> void:
	var vp_width: float = get_viewport().get_visible_rect().size.x
	var half_x: float = vp_width * 0.5

	if event is InputEventScreenTouch:
		if event.position.x < half_x:
			if event.pressed:
				_joystick_start(event.index, event.position)
			elif event.index == _joy_touch_index:
				_joystick_end()
	elif event is InputEventScreenDrag:
		if event.index == _joy_touch_index:
			_joystick_update(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x < half_x:
			if event.pressed:
				_joystick_start(-1, event.position)
			elif _joy_touch_index == -1:
				_joystick_end()
	elif event is InputEventMouseMotion:
		if _joy_touch_index == -1 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_joystick_update(event.position)


func _joystick_start(idx: int, pos: Vector2) -> void:
	_stop_drag_hint()
	_joy_touch_index = idx
	_joy_center = pos
	joy_base.global_position = pos - joy_base.size / 2.0
	joy_thumb.global_position = pos - joy_thumb.size / 2.0
	joy_base.modulate.a = JOY_ACTIVE_ALPHA
	joy_thumb.modulate.a = JOY_ACTIVE_ALPHA
	var tw := create_tween()
	tw.tween_property(joy_thumb, "scale", Vector2(1.2, 1.2), 0.08)
	_spawn_joy_particles(pos)


func _joystick_update(pos: Vector2) -> void:
	var delta: Vector2 = pos - _joy_center
	var clamped: Vector2 = delta.limit_length(JOYSTICK_RADIUS)
	joy_thumb.global_position = _joy_center + clamped - joy_thumb.size / 2.0

	var norm: Vector2 = clamped / JOYSTICK_RADIUS
	_joy_vector = norm if norm.length() > DEADZONE else Vector2.ZERO
	joystick_moved.emit(_joy_vector)


func _joystick_end() -> void:
	_joy_touch_index = -2
	_joy_vector = Vector2.ZERO
	joystick_moved.emit(_joy_vector)

	# Glides back to its parked home and dims, rather than fading out
	# entirely - the control stays on screen so it's always discoverable.
	var base_target: Vector2 = _park_base_pos if _parked else joy_base.global_position
	var thumb_target: Vector2 = _park_thumb_pos if _parked else \
		joy_base.global_position + joy_base.size / 2.0 - joy_thumb.size / 2.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(joy_base, "global_position", base_target, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(joy_thumb, "global_position", thumb_target, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(joy_thumb, "scale", Vector2.ONE, 0.1)
	tw.tween_property(joy_base, "modulate:a", JOY_IDLE_ALPHA, 0.18)
	tw.tween_property(joy_thumb, "modulate:a", JOY_IDLE_ALPHA, 0.18)


func _spawn_joy_particles(pos: Vector2) -> void:
	for i in range(2):
		var p := ColorRect.new()
		p.color = Color(1.0, 0.43, 0.78)
		p.size = Vector2(8, 8)
		p.global_position = pos
		add_child(p)
		var dir := Vector2.from_angle(randf() * TAU)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", pos + dir * 80.0, 0.3)
		tw.tween_property(p, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(p.queue_free)


## Called by player.gd whenever Aria gets stuck/unstuck in a sticky trap,
## so the Dissolve Light button visibly glows while it's the button that
## actually does something - a kid stuck in a trap shouldn't have to guess
## which of the two buttons is the way out.
func set_dissolve_highlighted(active: bool) -> void:
	if active:
		if _dissolve_highlight_tween:
			return
		_dissolve_highlight_tween = create_tween()
		_dissolve_highlight_tween.set_loops()
		_dissolve_highlight_tween.tween_property(dissolve_button, "modulate", Color(1.7, 1.7, 1.7), 0.35).set_trans(Tween.TRANS_SINE)
		_dissolve_highlight_tween.tween_property(dissolve_button, "modulate", Color(1.0, 1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
	else:
		if _dissolve_highlight_tween:
			_dissolve_highlight_tween.kill()
			_dissolve_highlight_tween = null
		dissolve_button.modulate = Color(1.0, 1.0, 1.0)


## Called by player.gd every frame Aria's within reveal range of a hidden
## key/gem (and stops the moment she isn't), turning "randomly mash the
## button" into a discoverable "walk around and watch for the glow" loop.
func set_reveal_highlighted(active: bool) -> void:
	if active:
		if _reveal_highlight_tween:
			return
		_reveal_highlight_tween = create_tween()
		_reveal_highlight_tween.set_loops()
		_reveal_highlight_tween.tween_property(reveal_button, "modulate", Color(1.7, 1.7, 1.7), 0.35).set_trans(Tween.TRANS_SINE)
		_reveal_highlight_tween.tween_property(reveal_button, "modulate", Color(1.0, 1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
	else:
		if _reveal_highlight_tween:
			_reveal_highlight_tween.kill()
			_reveal_highlight_tween = null
		reveal_button.modulate = Color(1.0, 1.0, 1.0)


func _prevent_browser_scroll() -> void:
	if OS.get_name() != "Web":
		return
	JavaScriptBridge.eval("""
		document.addEventListener('touchmove', function(e) { e.preventDefault(); }, { passive: false });
		document.addEventListener('gesturestart', function(e) { e.preventDefault(); }, { passive: false });
		document.body.style.touchAction = 'none';
	""", true)
