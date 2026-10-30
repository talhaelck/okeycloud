class_name SlipFeed
extends VBoxContainer
## What just happened, as paper slips: each slides in from the right with a coloured stripe (the colour of the seat it
## concerns), stays a few seconds and fades. At most MAX_SLIPS are on show; older ones go sooner.

const MAX_SLIPS := 4
const STAY := 6.0

var _slips: Array[Control] = []


func _init() -> void:
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `colour` is a seat's tile colour (or Color.TRANSPARENT for no stripe).
func add_slip(text: String, colour := Color.TRANSPARENT) -> void:
	var slip := PanelContainer.new()
	slip.add_theme_stylebox_override("panel", KahveTheme.slip_style())
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	slip.add_child(row)
	if colour.a > 0.0:
		var stripe := ColorRect.new()
		stripe.color = colour
		stripe.custom_minimum_size = Vector2(8, 0)
		row.add_child(stripe)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", KahveTheme.font("hand"))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	label.custom_minimum_size = Vector2(0, 0)
	row.add_child(label)
	add_child(slip)
	_slips.append(slip)
	while _slips.size() > MAX_SLIPS:
		_drop(_slips[0], 0.15)
	# In from the right, with a little overshoot, then out.
	slip.modulate.a = 0.0
	var tween := slip.create_tween()
	tween.tween_property(slip, "modulate:a", 1.0, 0.12)
	slip.pivot_offset = Vector2(slip.size.x, 0)
	tween.parallel().tween_property(slip, "scale", Vector2.ONE, 0.28).from(Vector2(0.9, 0.9)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(STAY)
	tween.tween_callback(func() -> void: _drop(slip, 0.5))


func count() -> int:
	return _slips.size()


func _drop(slip: Control, seconds: float) -> void:
	if not is_instance_valid(slip) or not _slips.has(slip):
		return
	_slips.erase(slip)
	var tween := slip.create_tween()
	tween.tween_property(slip, "modulate:a", 0.0, seconds)
	tween.tween_callback(slip.queue_free)
