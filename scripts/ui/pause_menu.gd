class_name PauseMenu
extends CanvasLayer
## The Esc menu: stops the game (the tree pauses; this menu keeps running) and offers Devam, the rules of this
## table, how to play, Ayarlar, Ana menüye dön and Çıkış. Esc again closes it. It fades up over the darkened table
## (the sign settles in from a little larger) and fades away when closed.

signal closed
signal menu_requested
signal quit_requested

var rules: GameSettings

var _root := Control.new()
var _dim := ColorRect.new()
var _main := PanelContainer.new()
var _rules := PanelContainer.new()
var _howto := PanelContainer.new()
var _settings: SettingsMenu
var _closing := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.theme = KahveTheme.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_dim.color = Color(0.02, 0.01, 0.0, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)

	_main.set_anchors_preset(Control.PRESET_CENTER)
	_main.offset_left = -190
	_main.offset_right = 190
	_main.offset_top = -210
	_main.offset_bottom = 210
	_main.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_main.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_main)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_main.add_child(box)
	box.add_child(KahveTheme.title("Mola", 40))
	for entry: Array in [["Devam", close], ["Masanın kuralları", _show_rules], ["Nasıl oynanır", _show_howto],
			["Ayarlar", _show_settings], ["Ana menüye dön", func() -> void: menu_requested.emit()],
			["Çıkış", func() -> void: quit_requested.emit()]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(0, 54)
		button.pressed.connect(entry[1])
		box.add_child(button)

	_build_page(_rules, "Masanın kuralları", _rules_text())
	_build_page(_howto, "Nasıl oynanır", MainMenu.controls_text())
	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_settings.visible = false
		_main.visible = true)
	_root.add_child(_settings)
	KahveTheme.wire(_root)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_arrive()


# The dimmer and the sign fade up; the sign settles from a little larger. Nothing to see headless.
func _arrive() -> void:
	if Fade.instant:
		return
	_main.pivot_offset = Vector2(190, 210)
	_dim.modulate.a = 0.0
	_main.modulate.a = 0.0
	_main.scale = Vector2(1.08, 1.08)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.25)
	tween.tween_property(_main, "modulate:a", 1.0, 0.2)
	tween.tween_property(_main, "scale", Vector2.ONE, 0.3)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if _rules.visible or _howto.visible or _settings.visible:
			_rules.visible = false
			_howto.visible = false
			_settings.visible = false
			_main.visible = true
		else:
			close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _closing:
		return
	_closing = true
	get_tree().paused = false
	closed.emit()
	if Fade.instant:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)


func _show_settings() -> void:
	_main.visible = false
	_settings.refresh()
	_settings.visible = true


func _show_rules() -> void:
	_main.visible = false
	_rules.visible = true


func _show_howto() -> void:
	_main.visible = false
	_howto.visible = true


func _rules_text() -> String:
	if rules == null:
		return ""
	var lines := rules.summary()
	return "Standart 101 kuralları." if lines.is_empty() else "Standarttan farklı olanlar:\n\n" + "\n".join(lines)


func _build_page(page: PanelContainer, title: String, text: String) -> void:
	page.set_anchors_preset(Control.PRESET_CENTER)
	page.offset_left = -560
	page.offset_right = 560
	page.offset_top = -380
	page.offset_bottom = 380
	page.grow_horizontal = Control.GROW_DIRECTION_BOTH
	page.grow_vertical = Control.GROW_DIRECTION_BOTH
	page.visible = false
	page.add_theme_stylebox_override("panel", KahveTheme.paper_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	page.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font", KahveTheme.font("sign"))
	heading.add_theme_font_size_override("font_size", KahveTheme.SIZE_HEADING)
	heading.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	box.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(980, 0)
	label.add_theme_font_override("font", KahveTheme.font("hand"))
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	scroll.add_child(label)
	var back := Button.new()
	back.text = "Geri"
	back.pressed.connect(func() -> void:
		page.visible = false
		_main.visible = true)
	box.add_child(back)
	_root.add_child(page)
