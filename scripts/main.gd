extends Node
class_name Main

## Root of the game: title screen -> Level 1 -> Level 2 -> Level 3 ->
## Level 4 -> Mission File. Owns the persistent TouchControls and UIManager
## layers (they survive across level loads) and swaps World instances
## between levels.

const WORLD_SCENE := preload("res://scenes/world.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch_controls.tscn")
const UI_SCENE := preload("res://scenes/ui.tscn")
const MISSION_FILE_SCENE := preload("res://scenes/mission_file.tscn")
const INTRO_SCENE_SCRIPT := preload("res://scripts/intro_screen.gd")
const LEVEL_INTRO_SCRIPT := preload("res://scripts/level_intro.gd")

const LEVEL_CLEAR_DURATION := 2.0
const TITLE_MIN_DURATION := 3.0

@onready var title_screen: CanvasLayer = $TitleScreen
@onready var title_label: Label = $TitleScreen/TitleLabel
@onready var level_clear_overlay: CanvasLayer = $LevelClearOverlay
@onready var world_container: Node2D = $WorldContainer
@onready var version_tag: CanvasLayer = $VersionTag
@onready var version_label: Label = $VersionTag/VersionLabel
@onready var screen_fader: ColorRect = $ScreenFader/Fade
@onready var birthday_label: Label = $TitleScreen/BirthdayLabel
@onready var level_buttons: Array[Button] = [
	$TitleScreen/LevelButtons/Level1Button,
	$TitleScreen/LevelButtons/Level2Button,
	$TitleScreen/LevelButtons/Level3Button,
	$TitleScreen/LevelButtons/Level4Button,
]
## Level 1 has no lock icon (always unlocked), hence the null placeholder.
@onready var level_lock_icons: Array = [
	null,
	$TitleScreen/LevelButtons/Level2Button/LockIcon,
	$TitleScreen/LevelButtons/Level3Button/LockIcon,
	$TitleScreen/LevelButtons/Level4Button/LockIcon,
]
@onready var reset_button: Button = $TitleScreen/ResetButton
@onready var reset_confirm_yes: Button = $TitleScreen/ResetConfirmYes
@onready var reset_confirm_no: Button = $TitleScreen/ResetConfirmNo

var touch_controls: TouchControls
var ui_manager: UIManager
var current_world: WorldGenerator
var _audio_unlocked := false
var _title_touch_ready := false
## True from the moment a level flow starts until its World is built. The
## title screen stays visible for the length of the opening fade, so
## without this a second tap inside that window runs the whole flow twice.
var _starting := false


func _ready() -> void:
	_ensure_generated_assets()

	# Swaps every label in the game off Godot's built-in smooth sans and
	# onto a pixel font that matches the artwork. Applied by walking the
	# tree and hooking node_added, because Control theme lookup can't reach
	# a Label parented to a CanvasLayer - see procedural_font.gd.
	ProceduralFont.install(get_tree())

	_center_ui_layers()

	version_label.text = "v" + GameManager.BUILD_VERSION

	touch_controls = TOUCH_CONTROLS_SCENE.instantiate()
	add_child(touch_controls)
	# Godot's CanvasLayer draw-order-by-`layer` isn't reliably occluding
	# this behind the title/tutorial/level-intro screens in the web export
	# (their higher `layer` values should be enough, but in practice the
	# gameplay action buttons visibly bled through on those screens) - so
	# visibility is driven explicitly at every screen transition instead of
	# trusting layering alone.
	touch_controls.visible = false

	ui_manager = UI_SCENE.instantiate()
	add_child(ui_manager)
	ui_manager.menu_requested.connect(_on_menu_requested)

	level_clear_overlay.visible = false
	screen_fader.color.a = 0.0
	title_label.add_theme_color_override("font_color", Color(1.0, 0.43, 0.78))
	title_label.text = "ARIA AND THE PINK STAR"
	_start_birthday_bounce()

	for i in range(level_buttons.size()):
		level_buttons[i].pressed.connect(_on_level_button_pressed.bind(i))
		level_buttons[i].pressed.connect(_play_ui_tap)

	reset_button.pressed.connect(_on_reset_button_pressed)
	reset_confirm_yes.pressed.connect(_on_reset_confirmed)
	reset_confirm_no.pressed.connect(_cancel_reset_confirm)
	for btn in [reset_button, reset_confirm_yes, reset_confirm_no]:
		btn.pressed.connect(_play_ui_tap)

	_show_title_screen()


## TouchControls and UIManager are deliberately absent here: their contents
## are anchored to the screen edges already, so they're correct at any
## viewport size and shifting them would pull the action buttons and HUD
## inward off their corners.
func _center_ui_layers() -> void:
	UILayout.keep_centered(title_screen, [$TitleScreen/Background])
	UILayout.keep_centered(level_clear_overlay, [$LevelClearOverlay/Background])
	UILayout.keep_centered(version_tag)
	UILayout.keep_centered($ScreenFader, [screen_fader])


func _play_ui_tap() -> void:
	ProceduralAudio.play_sfx("ui_tap")


## Briefly fades the screen out, runs `mid_action` while hidden, then fades
## back in - used at the few hard-cut screen swaps (title <-> gameplay,
## level-clear -> mission file) so they read as an intentional transition
## rather than an instant pop.
func _fade_transition(mid_action: Callable, fade_time: float = 0.2) -> void:
	var tw := create_tween()
	tw.tween_property(screen_fader, "color:a", 1.0, fade_time)
	await tw.finished
	mid_action.call()
	var tw2 := create_tween()
	tw2.tween_property(screen_fader, "color:a", 0.0, fade_time)
	await tw2.finished


func _start_birthday_bounce() -> void:
	birthday_label.pivot_offset = birthday_label.size / 2.0
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(birthday_label, "scale", Vector2(1.08, 1.08), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(birthday_label, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)


func _show_title_screen() -> void:
	# Back at the title, a fresh run is allowed again.
	_starting = false
	_refresh_level_buttons()
	_cancel_reset_confirm()
	title_screen.visible = true
	touch_controls.visible = false
	version_tag.visible = true
	_title_touch_ready = false
	await get_tree().create_timer(TITLE_MIN_DURATION).timeout
	_title_touch_ready = true


const LOCKED_NUMBER_COLOR := Color(0.55, 0.55, 0.58, 1.0)
const UNLOCKED_NUMBER_COLOR := Color(1.0, 1.0, 1.0, 1.0)


## Locked levels get three stacked signals rather than relying on faded
## alpha alone: the number itself turns an explicit grey, a padlock icon
## overlays it, and the whole button dims slightly on top of that.
func _refresh_level_buttons() -> void:
	for i in range(level_buttons.size()):
		var unlocked: bool = i <= GameManager.highest_unlocked_level
		level_buttons[i].disabled = not unlocked
		level_buttons[i].modulate.a = 1.0 if unlocked else 0.6
		level_buttons[i].add_theme_color_override(
			"font_color", UNLOCKED_NUMBER_COLOR if unlocked else LOCKED_NUMBER_COLOR
		)
		var lock_icon = level_lock_icons[i]
		if lock_icon:
			lock_icon.visible = not unlocked


## Tapping "NEW GAME" swaps it for two explicit buttons - RESET and
## CANCEL - rather than reusing the same spot for a second confirming tap.
func _on_reset_button_pressed() -> void:
	reset_button.visible = false
	reset_confirm_yes.visible = true
	reset_confirm_no.visible = true


func _cancel_reset_confirm() -> void:
	reset_confirm_yes.visible = false
	reset_confirm_no.visible = false
	reset_button.visible = true


func _on_reset_confirmed() -> void:
	_cancel_reset_confirm()
	GameManager.reset_progress()
	_refresh_level_buttons()


## The in-level MENU button (top-center HUD) bails out of the current
## level straight back to the title screen. No confirmation dialog:
## unlocked-level progress is untouched, only the current level's
## in-progress key/gem is lost, and picking the level again from the
## title screen is one tap away.
func _on_menu_requested() -> void:
	await _fade_transition(func():
		_clear_world_container()
		_hide_level_clear()
	)
	_show_title_screen()


func _ensure_generated_assets() -> void:
	var probe_path := "res://generated_assets/portal.png"
	if not FileAccess.file_exists(probe_path):
		# Editor-convenience fallback only: an exported HTML5 build ships
		# with generated_assets/ already baked in by build.sh, since
		# preload() calls elsewhere need the files to exist at export time.
		ProceduralArt.run_all()


func _unhandled_input(event: InputEvent) -> void:
	# Fires only for taps the level-select Buttons didn't already consume,
	# so tapping empty title-screen space starts/continues from wherever
	# Aria left off, without double-triggering when a button is tapped.
	if not title_screen.visible:
		return
	if not _title_touch_ready:
		return
	var touched: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if touched:
		_start_game(GameManager.highest_unlocked_level)


func _on_level_button_pressed(index: int) -> void:
	if not _title_touch_ready:
		return
	if index > GameManager.highest_unlocked_level:
		return
	_start_game(index)


func _start_game(level_index: int) -> void:
	if _starting:
		return
	_starting = true
	if not _audio_unlocked:
		_audio_unlocked = true
		ProceduralAudio.unlock_audio()
	await _fade_transition(func():
		title_screen.visible = false
		version_tag.visible = false
	)

	if not GameManager.has_seen_intro:
		GameManager.mark_intro_seen()
		var intro: IntroScreen = INTRO_SCENE_SCRIPT.new()
		add_child(intro)
		intro.intro_complete.connect(func():
			intro.queue_free()
			_show_level_intro_then_load(level_index)
		, CONNECT_ONE_SHOT)
		intro.play()
	else:
		_show_level_intro_then_load(level_index)


## Brief narrative card (level name + a sentence of story context from
## LevelData) before the level itself loads.
func _show_level_intro_then_load(index: int) -> void:
	touch_controls.visible = false
	var level := LevelData.get_level(index)
	var card: LevelIntro = LEVEL_INTRO_SCRIPT.new()
	add_child(card)
	card.intro_complete.connect(func():
		card.queue_free()
		_load_level(index)
	, CONNECT_ONE_SHOT)
	card.play(level)


func _load_level(index: int) -> void:
	GameManager.reset_for_level(index)
	# Guards against a stale glow if the player left the previous level via
	# MENU while still stuck in a trap or near a hidden collectible -
	# touch_controls persists across level loads, so nothing else would
	# ever clear these.
	touch_controls.set_dissolve_highlighted(false)
	touch_controls.set_reveal_highlighted(false)
	touch_controls.visible = true
	_clear_world_container()
	current_world = WORLD_SCENE.instantiate()
	world_container.add_child(current_world)
	current_world.build_level(index)
	ui_manager.bind_world(current_world)
	current_world.level_complete.connect(_on_level_complete.bind(index), CONNECT_ONE_SHOT)
	_starting = false


## Tears down any World still in the container before a new one is built.
## `_load_level` used to simply overwrite `current_world`, which orphaned
## the previous World *while it was still in the tree* - it kept running,
## and its Aria kept responding to the joystick. Two players move in
## lockstep on identical input so it reads as one, right up until a black
## hole pulls one of them back to its own last safe position and four
## characters appear at once.
func _clear_world_container() -> void:
	for child in world_container.get_children():
		# Removed as well as queued: queue_free only takes effect at the end
		# of the frame, and until then the stale player is still in the
		# "player" group and still wired to the touch controls.
		world_container.remove_child(child)
		child.queue_free()
	current_world = null


func _on_level_complete(index: int) -> void:
	GameManager.unlock_level(index + 1)

	_show_level_clear()
	await get_tree().create_timer(LEVEL_CLEAR_DURATION).timeout

	var is_last: bool = index + 1 >= LevelData.get_level_count()
	await _fade_transition(func():
		_hide_level_clear()
		_clear_world_container()
		if is_last:
			touch_controls.visible = false
	)

	if not is_last:
		_show_level_intro_then_load(index + 1)
	else:
		_show_mission_file()


func _show_level_clear() -> void:
	level_clear_overlay.visible = true
	var label: Label = level_clear_overlay.get_node("LevelClearLabel")
	label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.3)


func _hide_level_clear() -> void:
	level_clear_overlay.visible = false


func _show_mission_file() -> void:
	var mission := MISSION_FILE_SCENE.instantiate()
	if GameManager.custom_mission_message != "":
		mission.custom_message = GameManager.custom_mission_message
	add_child(mission)
	mission.mission_complete.connect(func():
		mission.queue_free()
		_show_title_screen()
	)
	mission.play()
