extends CanvasLayer
class_name MissionFile

## Full-screen reveal shown after Aria collects the pink gem in the final
## level and reaches the home portal. Lines reveal one at a time in a
## single readable banner instead of stacking, so there's never more than
## one line of text on screen at once.

signal mission_complete

@export_multiline var custom_message: String = "A SPECIAL SURPRISE IS WAITING FOR YOU"

const PINK := Color(1.0, 0.43, 0.78)
const LIGHT_PINK := Color(1.0, 0.7, 0.9)
const LINE_HOLD := 1.1
const LINE_FADE := 0.35

@onready var scene_art: TextureRect = $SceneArt
@onready var banner: ColorRect = $Banner
@onready var current_line: Label = $Banner/CurrentLine
@onready var tap_hint: Label = $TapHint

var _texts: Array[String] = []
var _ready_for_tap := false


func _ready() -> void:
	layer = 20
	visible = false
	scene_art.texture = load("res://generated_assets/mission_scene.png")

	_texts = [
		"THE PINK GEM GLOWS!",
		"ALL THREE KEYS + THE GEM...",
		"A PORTAL HOME OPENS!",
		"IT LEADS TO:",
		custom_message,
		"TIME TO FLY HOME!",
	]

	current_line.text = ""
	current_line.modulate.a = 0.0
	current_line.add_theme_color_override("font_color", PINK)

	tap_hint.text = "TAP TO CONTINUE"
	tap_hint.add_theme_color_override("font_color", LIGHT_PINK)
	tap_hint.modulate.a = 0.0


func play() -> void:
	visible = true
	_ready_for_tap = false
	get_tree().create_timer(0.3).timeout.connect(_reveal_line.bind(0))


func _reveal_line(index: int) -> void:
	if index >= _texts.size():
		_show_tap_hint()
		return

	current_line.text = _texts[index]
	var tw := create_tween()
	tw.tween_property(current_line, "modulate:a", 1.0, LINE_FADE)
	tw.tween_interval(LINE_HOLD)
	tw.tween_property(current_line, "modulate:a", 0.0, LINE_FADE)
	tw.tween_callback(_reveal_line.bind(index + 1))


func _show_tap_hint() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(tap_hint, "modulate:a", 1.0, 0.5)
	tw.tween_property(tap_hint, "modulate:a", 0.2, 0.5)
	_ready_for_tap = true


func _input(event: InputEvent) -> void:
	if not visible or not _ready_for_tap:
		return
	if event is InputEventScreenTouch and event.pressed:
		_continue()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_continue()


func _continue() -> void:
	_ready_for_tap = false
	mission_complete.emit()
