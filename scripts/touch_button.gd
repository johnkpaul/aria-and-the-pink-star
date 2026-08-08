extends Control
class_name TouchButton

## Generic large touch/mouse button with visible press feedback and an
## independent "shown" state (used by the contextual Secondary button to
## appear/disappear without fighting the press-punch animation).

signal pressed
signal released

@export var pressed_scale: float = 1.15
@export var pressed_alpha: float = 1.0
@export var idle_scale: float = 1.0
@export var idle_alpha: float = 0.8
@export var tween_duration: float = 0.1

var _is_pressed := false
var _touch_index := -2
var _shown := true
var _resting_scale := 1.0
var _resting_alpha := 1.0


func _ready() -> void:
	pivot_offset = size / 2.0
	_resting_scale = idle_scale
	_resting_alpha = idle_alpha
	scale = Vector2(_resting_scale, _resting_scale)
	modulate.a = _resting_alpha
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(-1)


## Release is handled globally rather than via _gui_input, because
## _gui_input only fires for events that hit this Control's rect *at that
## instant* - a Control never "captures" a touch for the rest of its
## gesture the way native UI toolkits do. A quick tap where the finger
## lifts even a few pixels outside the button (extremely common - a kid's
## touch, or any fast tap) would otherwise leave _is_pressed stuck true
## forever, silently swallowing every future tap via the guard in _press().
func _input(event: InputEvent) -> void:
	if not _is_pressed:
		return
	if event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
		_release()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _touch_index == -1:
		_release()


func _press(idx: int) -> void:
	if _is_pressed:
		return
	_is_pressed = true
	_touch_index = idx
	_animate_to(pressed_scale, pressed_alpha)
	pressed.emit()
	_try_haptic()


func _release() -> void:
	if not _is_pressed:
		return
	_is_pressed = false
	_touch_index = -2
	_animate_to(_resting_scale, _resting_alpha)
	released.emit()


func _try_haptic() -> void:
	if Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(20)


## Shows/hides the button entirely (used for contextual visibility, e.g. the
## Secondary block button). When `punch` is true, plays a brief 1.3x scale
## pop as the button appears (used after a successful block placement).
func set_shown(shown: bool, punch: bool = false) -> void:
	if _shown == shown and not punch:
		return
	_shown = shown
	mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
	_resting_scale = 1.0 if shown else 0.0
	_resting_alpha = 1.0 if shown else 0.0
	if _is_pressed:
		return
	if punch and shown:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.3, 1.3), tween_duration)
		tw.parallel().tween_property(self, "modulate:a", 1.0, tween_duration)
		tw.tween_property(self, "scale", Vector2(1.0, 1.0), tween_duration)
	else:
		_animate_to(_resting_scale, _resting_alpha)


func punch_scale() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), tween_duration)
	tw.tween_property(self, "scale", Vector2(_resting_scale, _resting_scale), tween_duration)


func _animate_to(target_scale: float, target_alpha: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(target_scale, target_scale), tween_duration)
	tw.tween_property(self, "modulate:a", target_alpha, tween_duration)
