extends CanvasLayer
class_name IntroScreen

## A short, icon-only tutorial shown once before a player's very first
## level, so the game doesn't drop them straight into gameplay with no
## explanation. No reading required - each card is a picture, held briefly,
## auto-advancing on its own, or tap the dedicated NEXT button to move on
## sooner. Skippable instantly since repeat players never see it again
## (GameManager.has_seen_intro persists across sessions).

signal intro_complete

const CARD_HOLD := 2.3
const FADE_TIME := 0.3
const BG_COLOR := Color(0.070588, 0.043137, 0.180392, 1)
const CAPTION_COLOR := Color(1.0, 0.43, 0.78)
const HINT_COLOR := Color(1.0, 0.7, 0.9, 0.55)

var _cards: Array[Dictionary] = [
	{
		"icons": ["res://imported_assets/aria_sprite.png", "res://generated_assets/key.png"],
		"text": "FIND THE HIDDEN KEYS",
	},
	{
		"icons": ["res://generated_assets/joystick_base.png", "res://generated_assets/joystick_thumb.png"],
		"text": "DRAG TO FLY",
	},
	{
		"icons": ["res://generated_assets/icon_reveal.png", "res://generated_assets/icon_dissolve.png"],
		"text": "TAP TO REVEAL OR DISSOLVE",
	},
	{
		"icons": ["res://generated_assets/black_hole_core.png", "res://generated_assets/black_hole_swirl.png"],
		"text": "BLACK HOLES PULL YOU BACK",
	},
	{
		"icons": ["res://generated_assets/sticky_trap.png", "res://generated_assets/icon_dissolve.png"],
		"text": "STUCK? USE DISSOLVE LIGHT",
	},
	{
		"icons": ["res://generated_assets/asteroid.png"],
		"text": "ASTEROIDS JUST BOUNCE YOU",
	},
]

var _icon_rects: Array[TextureRect] = []
var _caption: Label
var _next_button: Button
var _index := -1
var _visible_now := false
var _hold_timer: SceneTreeTimer
var _last_advance_msec := 0

## Ignores a second advance landing within this many milliseconds of the
## first. On touch the accidental double-tap is the common case, and two
## taps that fast are never a genuine request to skip two cards.
const ADVANCE_DEBOUNCE_MSEC := 300


func _ready() -> void:
	layer = 18
	visible = false

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	UILayout.keep_centered(self, [bg])

	for i in range(2):
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2(192, 192)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.position = Vector2(600 + i * 440, 360)
		rect.modulate.a = 0.0
		add_child(rect)
		_icon_rects.append(rect)

	_caption = Label.new()
	_caption.offset_left = 160
	_caption.offset_top = 686
	_caption.offset_right = 1760
	_caption.offset_bottom = 848
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	_caption.add_theme_font_size_override("font_size", 70)
	_caption.add_theme_color_override("font_color", CAPTION_COLOR)
	_caption.modulate.a = 0.0
	add_child(_caption)

	_next_button = Button.new()
	# Narrow and centered on x=960 - see the matching note in level_intro.gd
	# about `icon_alignment = RIGHT` stranding the arrow on a wide button.
	_next_button.offset_left = 810
	_next_button.offset_top = 960
	_next_button.offset_right = 1110
	_next_button.offset_bottom = 1056
	_next_button.add_theme_font_size_override("font_size", 56)
	_next_button.add_theme_color_override("font_color", HINT_COLOR)
	_next_button.flat = true
	# Arrow is an icon, not a "▶" in the text - the built-in font has no
	# glyph for it and rendered a tofu box here (see _make_icon_play).
	_next_button.text = "NEXT"
	_next_button.icon = load("res://generated_assets/icon_play.png")
	_next_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_button.pressed.connect(_try_advance)
	_next_button.pressed.connect(func(): ProceduralAudio.play_sfx("ui_tap"))
	add_child(_next_button)


func play() -> void:
	visible = true
	_visible_now = true
	_index = -1
	_next_card()


func _next_card() -> void:
	# Cancel the outgoing card's auto-advance timer. Each card used to
	# create a timer and never cancel it, so tapping NEXT left the previous
	# card's timer still pending - it would fire partway through the *next*
	# card and advance again. A few taps could rattle through the whole
	# tutorial in about a second.
	_cancel_hold_timer()

	_index += 1
	if _index >= _cards.size():
		_finish()
		return

	var card: Dictionary = _cards[_index]
	var icons: Array = card["icons"]
	for i in range(_icon_rects.size()):
		_icon_rects[i].texture = load(icons[i]) if i < icons.size() else null
		_icon_rects[i].modulate.a = 0.0
	_caption.text = card["text"]
	_caption.modulate.a = 0.0
	_next_button.text = "START" if _index == _cards.size() - 1 else "NEXT"

	var tw := create_tween()
	tw.set_parallel(true)
	for rect in _icon_rects:
		tw.tween_property(rect, "modulate:a", 1.0, FADE_TIME)
	tw.tween_property(_caption, "modulate:a", 1.0, FADE_TIME)

	_hold_timer = get_tree().create_timer(CARD_HOLD)
	# A plain method Callable rather than a lambda, so the connection is
	# torn down automatically if this screen is freed before the timer
	# fires - a lambda would happily resume on a freed node.
	_hold_timer.timeout.connect(_try_advance)


func _cancel_hold_timer() -> void:
	if _hold_timer and _hold_timer.timeout.is_connected(_try_advance):
		_hold_timer.timeout.disconnect(_try_advance)
	_hold_timer = null


func _try_advance() -> void:
	if not _visible_now:
		return
	var now := Time.get_ticks_msec()
	if now - _last_advance_msec < ADVANCE_DEBOUNCE_MSEC:
		return
	_last_advance_msec = now
	_next_card()


func _finish() -> void:
	_visible_now = false
	visible = false
	intro_complete.emit()
