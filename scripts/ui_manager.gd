extends CanvasLayer
class_name UIManager

## Persistent HUD: key/gem progress meter (top-left), a small MENU button
## (top-center) to bail out of the current level back to the title screen,
## and an idle hint arrow after 5s of no input.

signal menu_requested

const IDLE_HINT_DELAY := 5.0

@onready var meter_fill_clip: Control = $KeyMeter/FillClip
@onready var meter_fill: TextureRect = $KeyMeter/FillClip/Fill
@onready var idle_hint: TextureRect = $IdleHint
@onready var menu_button: Button = $MenuButton

var world: WorldGenerator
var _idle_timer := 0.0
var _hint_visible := false
var _hint_tween: Tween


func _ready() -> void:
	layer = 5
	meter_fill_clip.clip_contents = true
	idle_hint.texture = load("res://generated_assets/icon_arrow_hint.png")
	idle_hint.modulate.a = 0.0

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
	_on_key_progress(world.collected_collectibles, maxi(world.total_collectibles, 1), true)
	_reset_idle()


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
	tw.tween_property(meter_fill_clip, "size:x", target, 0.25)


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

	var screen_player: Vector2 = world.camera.unproject_position(player_pos)
	idle_hint.position = screen_player + dir * 96.0 - idle_hint.size / 2.0
	idle_hint.rotation = dir.angle() + PI / 2.0
