class_name Stamp
extends Control
## A rubber stamp slammed onto the screen: "YAKALANDIN!", "El açtın!", "Okey geldi!". It comes in big and fast, lands a
## little crooked with a double border, stays a moment and fades. One at a time; a new one replaces the old.

const STAY := 1.3

var _label := Label.new()
var _frame := Panel.new()
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", KahveTheme.font("display"))
	_label.add_theme_font_size_override("font_size", 92)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_frame.add_child(_label)
	add_child(_frame)
	visible = false


## `colour` is the ink: red for trouble, green for a good thing, gold for luck.
func slam(text: String, colour: Color) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", colour)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.03, 0.02, 0.55)
	box.border_color = colour
	box.set_border_width_all(10)
	box.set_corner_radius_all(18)
	box.set_expand_margin_all(0)
	_frame.add_theme_stylebox_override("panel", box)
	var width := maxf(560.0, text.length() * 64.0 + 120.0)
	_frame.size = Vector2(width, 190)
	_label.size = _frame.size
	_frame.pivot_offset = _frame.size * 0.5
	_frame.position = Vector2(size.x * 0.5 - width * 0.5, size.y * 0.30 - 95.0)
	_frame.rotation = randf_range(-0.07, -0.03)
	visible = true
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	_frame.scale = Vector2(2.4, 2.4)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.06)
	_tween.parallel().tween_property(_frame, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.tween_property(_frame, "scale", Vector2(1.05, 1.05), 0.05)
	_tween.tween_property(_frame, "scale", Vector2.ONE, 0.08)
	_tween.tween_interval(STAY)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(func() -> void: visible = false)
	Sfx.ui("tile_felt", 2.0)
