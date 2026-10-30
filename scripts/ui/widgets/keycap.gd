class_name KeyCap
extends PanelContainer
## A key on a keyboard ("F", "Sol tık", "Çift tık"): for the hints that say what to press.
## `KeyCap.line(["Çek", ["Sol tık"], "desteye"])` builds a whole hint: plain strings are words, arrays are keys.


func _init(key := "") -> void:
	add_theme_stylebox_override("panel", KahveTheme.keycap_style())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if key != "":
		set_key(key)


func set_key(key: String) -> void:
	for child in get_children():
		child.queue_free()
	var label := Label.new()
	label.text = key
	label.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	label.add_theme_font_size_override("font_size", KahveTheme.SIZE_SMALL)
	label.add_theme_color_override("font_color", Color("f1ead8"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


## A row of words and keys.
static func line(parts: Array, size := KahveTheme.SIZE_SMALL) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part: Variant in parts:
		if part is Array:
			row.add_child(KeyCap.new(str((part as Array)[0])))
		else:
			var label := Label.new()
			label.text = str(part)
			label.add_theme_font_size_override("font_size", size)
			label.add_theme_color_override("font_color", KahveTheme.CREAM_LIGHT)
			label.add_theme_constant_override("outline_size", 6)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(label)
	return row
