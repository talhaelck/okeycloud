class_name RuleCard
extends PanelContainer
## A rule set on a paper slip: its name and, under it, how it differs from the standard game. Click to choose it; the
## chosen one gets a red tick and sits a little forward. `chosen` is sent when it is clicked.

signal chosen

var set_name := ""
var selected := false:
	set(value):
		selected = value
		_refresh()

var _title := Label.new()
var _summary := Label.new()
var _tick := TextureRect.new()
var _hover := false


func _init(title := "", summary := "", id := "") -> void:
	set_name = id
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("panel", KahveTheme.paper_style_small())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	_title.text = title
	_title.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	_title.add_theme_font_size_override("font_size", KahveTheme.SIZE_LABEL)
	_title.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	words.add_child(_title)
	_summary.text = summary
	_summary.add_theme_font_override("font", KahveTheme.font("hand"))
	_summary.add_theme_font_size_override("font_size", 28)
	_summary.add_theme_color_override("font_color", Color(KahveTheme.PAPER_INK, 0.8))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(430, 0)
	words.add_child(_summary)
	_tick.texture = KahveTheme.tex("icon_check")
	_tick.custom_minimum_size = Vector2(44, 44)
	_tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tick.modulate = KahveTheme.ENAMEL_RED
	_tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tick)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit()
		accept_event()
	var key := event as InputEventKey
	if key and key.pressed and key.keycode in [KEY_ENTER, KEY_SPACE]:
		chosen.emit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hover = what == NOTIFICATION_MOUSE_ENTER
		_refresh()


func _refresh() -> void:
	if not is_node_ready() and _tick.get_parent() == null:
		return
	_tick.modulate.a = 1.0 if selected else 0.0
	self_modulate = Color.WHITE if selected or _hover else Color(0.86, 0.84, 0.8)
