extends CanvasLayer
class_name UIManager

## Persistent HUD: key/gem progress meter (top-left), a small MENU button
## (top-center) to bail out of the current level back to the title screen,
## and an idle hint arrow after 5s of no input.

signal menu_requested

const IDLE_HINT_DELAY := 5.0

## How long a collected key takes to fly from where it was picked up to the
## HUD meter. The meter's fill is delayed to match, so the bar visibly
## responds to the key *landing* rather than filling on its own beat.
const FLIGHT_TIME := 0.55
const FLYER_SIZE := Vector2(96, 96)

const TEX_KEY := preload("res://generated_assets/key.png")
const TEX_GEM := preload("res://generated_assets/gem.png")

@onready var meter_fill_clip: Control = $KeyMeter/FillClip
@onready var meter_fill: TextureRect = $KeyMeter/FillClip/Fill
@onready var idle_hint: TextureRect = $IdleHint
@onready var menu_button: Button = $MenuButton
@onready var key_icon: TextureRect = $KeyIcon

var world: WorldGenerator
var _idle_timer := 0.0
var _hint_visible := false
var _hint_tween: Tween


func _ready() -> void:
	layer = 5
	meter_fill_clip.clip_contents = true
	idle_hint.texture = load("res://generated_assets/icon_arrow_hint.png")
	idle_hint.modulate.a = 0.0
	key_icon.pivot_offset = key_icon.size / 2.0

	menu_button.pressed.connect(func(): menu_requested.emit())
	menu_button.pressed.connect(func(): ProceduralAudio.play_sfx("ui_tap"))

	var tc: TouchControls = get_tree().get_first_node_in_group("touch_controls")
	if tc:
		tc.joystick_moved.connect(func(v: Vector2): if v.length() > 0.05: _reset_idle())
		tc.reveal_pressed.connect(_reset_idle)
		tc.dissolve_pressed.connect(_reset_idle)


func bind_world(w: WorldGenerator) -> void:
	world = w
	world.key_collected.connect(_on_key_progress)
	world.collectible_picked_up.connect(_fly_to_meter)
	_on_key_progress(world.collected_collectibles, maxi(world.total_collectibles, 1), true)
	_reset_idle()


## Sends a copy of the collected key/gem arcing from where it was picked up
## to the HUD meter. Picking one up used to register only as a bar quietly
## growing in the corner, which is easy to miss when the pickup happens
## right under you - this draws an explicit line between the two.
func _fly_to_meter(world_pos: Vector2, gem: bool) -> void:
	if not world or not world.camera:
		return
	var flyer := TextureRect.new()
	flyer.texture = TEX_GEM if gem else TEX_KEY
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.size = FLYER_SIZE
	flyer.pivot_offset = FLYER_SIZE / 2.0
	flyer.position = _world_to_screen(world_pos) - FLYER_SIZE / 2.0
	add_child(flyer)

	var target: Vector2 = key_icon.position + key_icon.size / 2.0 - FLYER_SIZE / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flyer, "position", target, FLIGHT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(flyer, "scale", Vector2(0.5, 0.5), FLIGHT_TIME).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func() -> void:
		flyer.queue_free()
		_punch_key_icon()
	)


## Camera2D has no `unproject_position()` - that's Camera3D only, and
## calling it throws "Nonexistent function". The viewport's canvas
## transform is what maps world space to screen space under a 2D camera.
## The idle-hint code had been calling the Camera3D method since it was
## written, so it threw every frame the hint was on screen and left the
## arrow parked whereever it happened to be.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _punch_key_icon() -> void:
	var tw := create_tween()
	tw.tween_property(key_icon, "scale", Vector2(1.45, 1.45), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(key_icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)


## `instant` is used for the initial bind at level load. The meter's clip
## starts at full width in ui.tscn, so tweening to the real (empty) value
## made every level open with the key bar visibly draining from full to
## nothing - it read as losing progress rather than starting fresh.
func _on_key_progress(collected: int, total: int, instant: bool = false) -> void:
	var ratio: float = float(collected) / float(maxi(total, 1))
	var full_width: float = meter_fill.size.x
	var target: float = full_width * ratio
	if instant:
		meter_fill_clip.size.x = target
		return
	var tw := create_tween()
	tw.tween_property(meter_fill_clip, "size:x", target, 0.25).set_delay(FLIGHT_TIME)


func _process(delta: float) -> void:
	if not world or not world.player:
		return
	_idle_timer += delta
	if _idle_timer >= IDLE_HINT_DELAY and not _hint_visible:
		_show_hint()
	if _hint_visible:
		_update_hint_position()


func _reset_idle() -> void:
	_idle_timer = 0.0
	if _hint_visible:
		_hide_hint()


func _show_hint() -> void:
	_hint_visible = true
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	_hint_tween.tween_property(idle_hint, "modulate:a", 1.0, 0.4)
	_hint_tween.tween_property(idle_hint, "modulate:a", 0.15, 0.4)


func _hide_hint() -> void:
	_hint_visible = false
	if _hint_tween:
		_hint_tween.kill()
	idle_hint.modulate.a = 0.0


## Points at the nearest remaining key, or - once they're all collected and
## the collectible group is empty - at the home portal. Previously the hint
## just hid itself in that second case, which meant an idle player got no
## guidance during precisely the stretch where the goal had silently
## changed from "hunt" to "fly home".
func _update_hint_position() -> void:
	if not world.camera:
		idle_hint.visible = false
		return

	var player_pos: Vector2 = world.player.global_position
	var target_pos: Vector2
	var items := get_tree().get_nodes_in_group("collectible")

	if items.is_empty():
		if not is_instance_valid(world.portal):
			idle_hint.visible = false
			return
		target_pos = world.portal.global_position
	else:
		var nearest: Node2D = items[0]
		var nearest_dist := player_pos.distance_squared_to(nearest.global_position)
		for c in items:
			var d := player_pos.distance_squared_to(c.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = c
		target_pos = nearest.global_position

	idle_hint.visible = true

	var dir: Vector2 = (target_pos - player_pos)
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var screen_player: Vector2 = _world_to_screen(player_pos)
	idle_hint.position = screen_player + dir * 96.0 - idle_hint.size / 2.0
	idle_hint.rotation = dir.angle() + PI / 2.0
