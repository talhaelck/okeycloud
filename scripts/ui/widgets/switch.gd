class_name Switch
extends BaseButton
## An on/off switch: a groove that turns felt-green with a tile-coloured knob that slides over. Replaces Godot's
## CheckButton. `toggled(on)` as for any toggle button; `set_state(on)` moves it without sending anything.

const TRACK := Vector2(112, 64)
const KNOB := 56.0

var _knob := 0.0 # 0 = off, 1 = on


func _init() -> void:
	toggle_mode = true
	custom_minimum_size = TRACK
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	_knob = 1.0 if button_pressed else 0.0
	toggled.connect(func(on: bool) -> void:
		create_tween().tween_method(_move, _knob, 1.0 if on else 0.0, 0.14).set_trans(Tween.TRANS_SINE))


func set_state(on: bool) -> void:
	set_pressed_no_signal(on)
	_move(1.0 if on else 0.0)


func _move(value: float) -> void:
	_knob = value
	queue_redraw()


func _draw() -> void:
	var on := button_pressed
	draw_texture_rect(KahveTheme.tex("switch_on" if on else "switch_off"), Rect2(Vector2.ZERO, TRACK), false)
	var x := lerpf(KNOB * 0.5 + 6.0, TRACK.x - KNOB * 0.5 - 6.0, _knob)
	var tint := Color(1, 1, 1, 0.55 if disabled else 1.0)
	draw_texture(KahveTheme.tex("switch_knob"), Vector2(x - KNOB * 0.5, TRACK.y * 0.5 - KNOB * 0.5 - 2.0), tint)
	if has_focus():
		draw_rect(Rect2(Vector2(-3, -3), TRACK + Vector2(6, 6)), KahveTheme.ENAMEL_RED, false, 3.0)
