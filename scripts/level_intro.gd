extends CanvasLayer
class_name LevelIntro

## Brief narrative card shown right before each level loads: the level's
## name plus a sentence or two of story context (LevelData's "story"
## field), so the surface -> bridge -> cave progression - and mood shifts
## like Level 3's darker lighting - read as a treasure hunt with a reason,
## not an unexplained jump. Auto-advances after a short hold, or tap the
## START button to jump straight in.

signal intro_complete

const HOLD_TIME := 2.6
const FADE_TIME := 0.3
const BG_COLOR := Color(0.070588, 0.043137, 0.180392, 1)
const TITLE_COLOR := Color(1.0, 0.43, 0.78)
const STORY_COLOR := Color(0.95, 0.95, 0.95, 0.9)
const START_COLOR := Color(1.0, 0.7, 0.9, 0.7)

var _title_label: Label
var _story_label: Label
var _start_button: Button
var _advancing := false
var _visible_now := false


func _ready() -> void:
	layer = 17
	visible = false

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(1920, 1080)
	add_child(bg)

	_title_label = Label.new()
	_title_label.offset_left = 160
	_title_label.offset_top = 320
	_title_label.offset_right = 1760
	_title_label.offset_bottom = 440
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 80)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(_title_label)

	_story_label = Label.new()
	_story_label.offset_left = 200
	_story_label.offset_top = 480
	_story_label.offset_right = 1720
	_story_label.offset_bottom = 680
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_story_label.add_theme_font_size_override("font_size", 44)
	_story_label.add_theme_color_override("font_color", STORY_COLOR)
	add_child(_story_label)

	_start_button = Button.new()
	_start_button.offset_left = 760
	_start_button.offset_top = 900
	_start_button.offset_right = 1160
	_start_button.offset_bottom = 990
	_start_button.add_theme_font_size_override("font_size", 44)
	_start_button.add_theme_color_override("font_color", START_COLOR)
	_start_button.flat = true
	_start_button.text = "START ▶"
	_start_button.pressed.connect(_advance)
	add_child(_start_button)


func play(level: Dictionary) -> void:
	_title_label.text = level.get("name", "").to_upper()
	_story_label.text = level.get("story", "")
	visible = true
	_visible_now = true
	_advancing = false

	for n in [_title_label, _story_label, _start_button]:
		n.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	for n in [_title_label, _story_label, _start_button]:
		tw.tween_property(n, "modulate:a", 1.0, FADE_TIME)

	get_tree().create_timer(HOLD_TIME).timeout.connect(_advance)


func _advance() -> void:
	if _advancing or not _visible_now:
		return
	_advancing = true
	_visible_now = false
	visible = false
	intro_complete.emit()
