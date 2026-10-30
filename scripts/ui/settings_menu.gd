class_name SettingsMenu
extends PanelContainer
## "Ayarlar": the player's own settings (Prefs) on a sheet of paper: sound, picture and the shows, in three groups.
## Each row is the setting's name with a line under it saying what it does, and a switch or a number on the right;
## a changed row shows a small Sıfırla tile. Every change is applied and kept at once. Opened from the main menu's
## AYARLAR tile and from the pause menu; Esc or Tamam closes it (`closed`).

signal closed

var _controls := {} # key -> Switch or Stepper
var _resets := {} # key -> Button


func _ready() -> void:
	add_theme_stylebox_override("panel", KahveTheme.paper_style())
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(1180, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var heading := Label.new()
	heading.text = "Ayarlar"
	heading.add_theme_font_override("font", KahveTheme.font("sign"))
	heading.add_theme_font_size_override("font_size", KahveTheme.SIZE_HEADING)
	heading.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var note := Label.new()
	note.text = "her değişiklik hemen uygulanır"
	note.add_theme_font_override("font", KahveTheme.font("script"))
	note.add_theme_font_size_override("font_size", 34)
	note.add_theme_color_override("font_color", KahveTheme.ENAMEL_RED)
	head.add_child(note)
	for group: Array in Prefs.GROUPS:
		var title := Label.new()
		title.text = group[0]
		title.add_theme_font_override("font", KahveTheme.font("sign"))
		title.add_theme_font_size_override("font_size", KahveTheme.SIZE_BODY)
		title.add_theme_color_override("font_color", Color(KahveTheme.PAPER_INK, 0.7))
		box.add_child(title)
		var rule := ColorRect.new()
		rule.color = Color(KahveTheme.PAPER_INK, 0.35)
		rule.custom_minimum_size = Vector2(0, 2)
		box.add_child(rule)
		for key: String in group[1]:
			box.add_child(_row(key))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	footer.alignment = BoxContainer.ALIGNMENT_END
	var all_back := Button.new()
	all_back.text = "Hepsini sıfırla"
	all_back.theme_type_variation = "SmallTile"
	all_back.pressed.connect(func() -> void:
		Prefs.reset_all()
		refresh())
	footer.add_child(all_back)
	var ok := Button.new()
	ok.text = "Tamam"
	ok.pressed.connect(func() -> void: closed.emit())
	footer.add_child(ok)
	box.add_child(footer)
	refresh()
	KahveTheme.wire(self)


func _row(key: String) -> Control:
	var info: Array = Prefs.ROWS[key]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = info[0]
	title.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	title.add_theme_font_size_override("font_size", KahveTheme.SIZE_BODY)
	title.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	words.add_child(title)
	var text := Label.new()
	text.text = info[1]
	text.add_theme_font_override("font", KahveTheme.font("hand"))
	text.add_theme_font_size_override("font_size", 26)
	text.add_theme_color_override("font_color", Color(KahveTheme.PAPER_INK, 0.75))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(text)
	row.add_child(words)
	var reset := Button.new()
	reset.theme_type_variation = "SmallTile"
	reset.text = "Sıfırla"
	reset.modulate.a = 0.0
	reset.focus_mode = Control.FOCUS_NONE
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func() -> void:
		Prefs.set_value(key, Prefs.default_of(key))
		refresh())
	row.add_child(reset)
	_resets[key] = reset
	var control: Control
	if info[3] is String:
		var toggle := Switch.new()
		toggle.toggled.connect(func(on: bool) -> void: _change(key, on))
		control = toggle
	else:
		var range: Array = info[3]
		var stepper := Stepper.new().setup(range[0], range[1], range[2], float(Prefs.get_value(key)), range[3])
		stepper.value_changed.connect(func(v: float) -> void: _change(key, int(v)))
		control = stepper
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	_controls[key] = control
	return row


## Puts every control where the settings are.
func refresh() -> void:
	for key: String in _controls:
		var control: Control = _controls[key]
		if control is Switch:
			(control as Switch).set_state(Prefs.get_value(key))
		else:
			(control as Stepper).set_value(float(Prefs.get_value(key)))
		var reset: Button = _resets[key]
		reset.modulate.a = 0.0 if Prefs.is_default(key) else 1.0
		reset.mouse_filter = Control.MOUSE_FILTER_IGNORE if Prefs.is_default(key) else Control.MOUSE_FILTER_STOP


## As the player changing a row: writes the setting, applies it and keeps it.
func set_pref(key: String, value: Variant) -> void:
	_change(key, value)
	refresh()


func _change(key: String, value: Variant) -> void:
	Prefs.set_value(key, value)
	var reset: Button = _resets[key]
	reset.modulate.a = 0.0 if Prefs.is_default(key) else 1.0
	reset.mouse_filter = Control.MOUSE_FILTER_IGNORE if Prefs.is_default(key) else Control.MOUSE_FILTER_STOP
