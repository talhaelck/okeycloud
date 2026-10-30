class_name Stepper
extends HBoxContainer
## A number with a minus and a plus tile either side (replaces Godot's SpinBox). Holding a tile repeats it.
## `value_changed(v)` is sent for the player's changes only; `set_value(v)` just moves the display.

signal value_changed(value: float)

const REPEAT_DELAY := 0.45
const REPEAT_EVERY := 0.07

var min_value := 0.0
var max_value := 100.0
var step := 1.0
var value := 0.0:
	set = set_value
## Text after the number ("sn", "dk").
var suffix := ""

var _label := Label.new()
var _minus := Button.new()
var _plus := Button.new()
var _held := 0
var _timer := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 6)
	for button: Button in [_minus, _plus]:
		button.theme_type_variation = "SmallTile"
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(66, 0)
	_minus.text = "−"
	_plus.text = "+"
	_label.custom_minimum_size = Vector2(120, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	_label.add_theme_font_size_override("font_size", KahveTheme.SIZE_LABEL)
	add_child(_minus)
	add_child(_label)
	add_child(_plus)
	_minus.button_down.connect(func() -> void: _press(-1))
	_plus.button_down.connect(func() -> void: _press(1))
	for button: Button in [_minus, _plus]:
		button.button_up.connect(func() -> void: _held = 0)


func setup(min_v: float, max_v: float, step_v: float, start: float, unit := "") -> Stepper:
	min_value = min_v
	max_value = max_v
	step = step_v
	suffix = unit
	set_value(start)
	return self


func set_value(v: float) -> void:
	value = clampf(snappedf(v, step), min_value, max_value)
	var whole := step >= 1.0 and absf(step - roundf(step)) < 0.0001
	var decimals := "%.2f" if step < 0.1 else "%.1f"
	_label.text = ("%d" % int(value) if whole else decimals % value) + (" " + suffix if suffix != "" else "")
	_minus.disabled = value <= min_value
	_plus.disabled = value >= max_value


## What a press does: the change a player's own click makes.
func nudge(direction: int) -> void:
	var before := value
	set_value(value + direction * step)
	if value != before:
		value_changed.emit(value)


func _press(direction: int) -> void:
	nudge(direction)
	_held = direction
	_timer = REPEAT_DELAY


func _process(delta: float) -> void:
	if _held == 0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REPEAT_EVERY
		nudge(_held)
