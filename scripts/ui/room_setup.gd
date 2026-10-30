class_name RoomSetup
extends Control
## "Masa kur" (design size 1920x1080), two pages.
## Page 0, the table: you sit at the bottom, the other three seats around a felt table. Your seat holds your name; a bot's
## seat holds his level (Kolay, Normal, Zor) and a locked slot for a friend (online comes later). To the right, the rule
## sets as paper cards (the standard game, the ones that ship, the ones you saved). Başlat starts.
## Page 1, the rules: categories on the left (with a search and "only what I changed"), the rules of one category in the
## middle with a switch or a number each, and on the right what the rule you point at does and what it is by default.
## The page edits `rules` and `bots`; tests drive it through set_rule / choose_preset / choose_level / start.

## Start pressed: the rules and a level id for each of seats 1-3.
signal started(rules: GameSettings, bots: Array)
signal back

const SEAT_NAMES := {1: "Hasan Amca", 2: "Hoca Dayı", 3: "Mahmut Usta"}

var rules := GameSettings.new()
var bots: Array[String] = ["normal", "normal", "normal"]

var _defaults := GameSettings.new()
var _pages: Array[Control] = []
var _page := 0
var _name_edit := LineEdit.new()
var _level_buttons: Array = [] # per bot seat: three toggle buttons
var _level_notes: Array[Label] = []
var _cards: Array[RuleCard] = []
var _preset_names: Array[String] = []
var _cards_box := VBoxContainer.new()
var _preset_note := Label.new()
var _controls := {} # key -> Switch or Stepper
var _dots := {} # key -> Panel
var _resets := {} # key -> Button
var _rows := {} # key -> the row's node
var _category_buttons: Array[Button] = []
var _category := 0
var _search := LineEdit.new()
var _only_changed := Switch.new()
var _groups: Array = []
var _detail_title := Label.new()
var _detail_text := Label.new()
var _detail_default := Label.new()
var _rules_note := Label.new()
var _message := Label.new()
var _save_panel := PanelContainer.new()
var _save_name := LineEdit.new()


func _ready() -> void:
	theme = KahveTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_groups = rules.groups()
	_pages = [_build_table_page(), _build_rules_page()]
	for page in _pages:
		add_child(page)
	_build_save_panel()
	_message.theme_type_variation = "SmallLabel"
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.offset_bottom = -120
	add_child(_message)
	choose_preset("klasik")
	show_page(0)
	KahveTheme.wire(self)


# --- Page 0: the table ---------------------------------------------------------------------------------------------

func _build_table_page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(_header("MASA KUR"))

	# The table with its four seats: the player's at the bottom, then round to the right (Hasan Amca), across (Hoca Dayı)
	# and to the left (Mahmut Usta), the way they sit in the room.
	var area := Control.new()
	area.position = Vector2(60, 150)
	area.size = Vector2(1180, 790)
	page.add_child(area)
	var felt := Panel.new()
	var felt_style := KahveTheme.box(Color("0f3a2b"), Color("4a2d17"), 14, 24, Vector2(0, 0))
	felt.add_theme_stylebox_override("panel", felt_style)
	felt.position = Vector2(250, 190)
	felt.size = Vector2(680, 400)
	area.add_child(felt)
	var felt_label := Label.new()
	felt_label.text = "101"
	felt_label.theme_type_variation = "TitleLabel"
	felt_label.add_theme_font_size_override("font_size", 130)
	felt_label.add_theme_color_override("font_color", Color(KahveTheme.CHALK, 0.9))
	felt_label.position = Vector2(felt.size.x * 0.5 - 110, felt.size.y * 0.5 - 100)
	felt.add_child(felt_label)
	var felt_small := Label.new()
	felt_small.text = "dört kişilik masa"
	felt_small.theme_type_variation = "HandLabel"
	felt_small.add_theme_color_override("font_color", Color(KahveTheme.CHALK, 0.7))
	felt_small.position = Vector2(felt.size.x * 0.5 - 130, felt.size.y * 0.5 + 50)
	felt.add_child(felt_small)

	area.add_child(_player_card(Vector2(365, 600)))
	area.add_child(_bot_card(0, 1, Vector2(750, 300)))   # right: Hasan Amca
	area.add_child(_bot_card(1, 2, Vector2(365, 0)))     # across: Hoca Dayı
	area.add_child(_bot_card(2, 3, Vector2(-20, 300)))   # left: Mahmut Usta

	# The rule sets.
	var side := VBoxContainer.new()
	side.position = Vector2(1290, 150)
	side.custom_minimum_size = Vector2(560, 0)
	side.add_theme_constant_override("separation", 14)
	page.add_child(side)
	var heading := Label.new()
	heading.text = "Kural seti"
	heading.theme_type_variation = "HeadingLabel"
	side.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_cards_box.add_theme_constant_override("separation", 10)
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards_box)
	_preset_note.theme_type_variation = "SmallLabel"
	side.add_child(_preset_note)
	var tune := Button.new()
	tune.text = "Kuralları ayarla"
	tune.theme_type_variation = "SmallTile"
	tune.pressed.connect(func() -> void: show_page(1))
	side.add_child(tune)

	page.add_child(_bottom_bar("Geri", "BAŞLAT", func() -> void: back.emit(), start))
	return page


func _seat_card(accent: Color) -> Array:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", KahveTheme.sign_style("dark", true))
	card.custom_minimum_size = Vector2(450, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.custom_minimum_size = Vector2(12, 0)
	row.add_child(stripe)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	return [card, column]


func _player_card(at: Vector2) -> Control:
	var parts := _seat_card(KahveTheme.SEAT_COLOURS[0])
	var card: PanelContainer = parts[0]
	var column: VBoxContainer = parts[1]
	card.position = at
	var label := Label.new()
	label.text = "Sen"
	label.theme_type_variation = "SmallLabel"
	column.add_child(label)
	_name_edit.text = Profile.player_name()
	_name_edit.max_length = Profile.MAX_LENGTH
	_name_edit.placeholder_text = "Adın"
	_name_edit.custom_minimum_size = Vector2(0, 62)
	column.add_child(_name_edit)
	return card


func _bot_card(index: int, seat: int, at: Vector2) -> Control:
	var parts := _seat_card(KahveTheme.SEAT_COLOURS[seat])
	var card: PanelContainer = parts[0]
	var column: VBoxContainer = parts[1]
	card.position = at
	var name_label := Label.new()
	name_label.text = SEAT_NAMES[seat]
	name_label.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	name_label.add_theme_font_size_override("font_size", KahveTheme.SIZE_LABEL)
	column.add_child(name_label)
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 8)
	column.add_child(levels)
	var group := ButtonGroup.new()
	var buttons := []
	for id: String in GameDirector.LEVEL_ORDER:
		var button := Button.new()
		button.theme_type_variation = "SmallTile"
		button.text = GameDirector.LEVELS[id].name
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func() -> void: choose_level(seat, id))
		levels.add_child(button)
		buttons.append(button)
	_level_buttons.append(buttons)
	var note := Label.new()
	note.theme_type_variation = "SmallLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_level_notes.append(note)
	var friend := HBoxContainer.new()
	friend.add_theme_constant_override("separation", 8)
	var lock := TextureRect.new()
	lock.texture = KahveTheme.tex("icon_lock")
	lock.custom_minimum_size = Vector2(26, 26)
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.modulate = Color(KahveTheme.CREAM, 0.5)
	friend.add_child(lock)
	var soon := Label.new()
	soon.text = "Arkadaşını davet et (yakında)"
	soon.theme_type_variation = "SmallLabel"
	soon.modulate.a = 0.7
	friend.add_child(soon)
	column.add_child(friend)
	return card


# --- Page 1: the rules ----------------------------------------------------------------------------------------------

func _build_rules_page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(_header("KURALLAR"))

	var left := VBoxContainer.new()
	left.position = Vector2(80, 160)
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 12)
	page.add_child(left)
	_search.placeholder_text = "Kural ara"
	_search.custom_minimum_size = Vector2(0, 62)
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _apply_filter())
	left.add_child(_search)
	var group := ButtonGroup.new()
	for i in _groups.size():
		var button := Button.new()
		button.theme_type_variation = "SmallTile"
		button.text = _groups[i].title
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void:
			_category = i
			_apply_filter())
		left.add_child(button)
		_category_buttons.append(button)
	var changed_row := HBoxContainer.new()
	changed_row.position = Vector2(1380, 790)
	changed_row.custom_minimum_size = Vector2(470, 0)
	changed_row.add_theme_constant_override("separation", 14)
	var changed_label := Label.new()
	changed_label.text = "Sadece değiştirdiklerim"
	changed_label.theme_type_variation = "SmallLabel"
	changed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	changed_row.add_child(changed_label)
	_only_changed.toggled.connect(func(_on: bool) -> void: _apply_filter())
	changed_row.add_child(_only_changed)
	page.add_child(changed_row)

	var middle := PanelContainer.new()
	middle.add_theme_stylebox_override("panel", KahveTheme.sign_style("dark"))
	middle.position = Vector2(500, 130)
	middle.custom_minimum_size = Vector2(840, 800)
	page.add_child(middle)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(740, 690)
	middle.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for g in _groups.size():
		for key: String in _groups[g].keys:
			var row := _rule_row(key)
			row.set_meta("group", g)
			rows.add_child(row)
			_rows[key] = row

	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", KahveTheme.paper_style())
	detail.position = Vector2(1380, 130)
	detail.custom_minimum_size = Vector2(470, 520)
	page.add_child(detail)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 14)
	detail.add_child(detail_box)
	_detail_title.add_theme_font_override("font", KahveTheme.font("sign"))
	_detail_title.add_theme_font_size_override("font_size", 38)
	_detail_title.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_title)
	_detail_text.add_theme_font_size_override("font_size", KahveTheme.SIZE_BODY)
	_detail_text.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(360, 0)
	detail_box.add_child(_detail_text)
	_detail_default.add_theme_font_override("font", KahveTheme.font("hand"))
	_detail_default.add_theme_font_size_override("font_size", 34)
	_detail_default.add_theme_color_override("font_color", KahveTheme.ENAMEL_RED)
	detail_box.add_child(_detail_default)
	_rules_note.theme_type_variation = "SmallLabel"
	_rules_note.position = Vector2(1380, 690)
	_rules_note.custom_minimum_size = Vector2(470, 0)
	_rules_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_rules_note)

	var bar := HBoxContainer.new()
	bar.position = Vector2(80, 960)
	bar.add_theme_constant_override("separation", 16)
	page.add_child(bar)
	for entry: Array in [["Masaya dön", func() -> void: show_page(0)], ["Varsayılana dön", func() -> void: choose_preset("klasik")],
			["Kaydet", func() -> void: _save_panel.visible = true]]:
		var button := Button.new()
		button.text = entry[0]
		button.theme_type_variation = "SmallTile"
		button.pressed.connect(entry[1])
		bar.add_child(button)
	return page


func _rule_row(key: String) -> Control:
	var label: Array = GameSettings.LABELS.get(key, [key, ""])
	var row := PanelContainer.new()
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(1, 1, 1, 0.05)
	plain.set_corner_radius_all(12)
	plain.content_margin_left = 18
	plain.content_margin_right = 14
	plain.content_margin_top = 8
	plain.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", plain)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	row.add_child(box)
	var dot := Panel.new()
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = KahveTheme.SUIT_YELLOW
	dot_style.set_corner_radius_all(9)
	dot.add_theme_stylebox_override("panel", dot_style)
	dot.custom_minimum_size = Vector2(18, 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.modulate.a = 0.0
	box.add_child(dot)
	_dots[key] = dot
	var title := Label.new()
	title.text = label[0]
	title.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	title.add_theme_font_size_override("font_size", KahveTheme.SIZE_BODY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(300, 0)
	box.add_child(title)

	var value: Variant = rules.get(key)
	var control: Control
	if value is bool:
		var toggle := Switch.new()
		toggle.toggled.connect(func(on: bool) -> void: set_rule(key, on, false))
		control = toggle
	else:
		var range: Array = GameSettings.RANGES.get(key, [0, 1000, 1])
		var stepper := Stepper.new().setup(range[0], range[1], range[2], float(value))
		stepper.value_changed.connect(func(v: float) -> void: set_rule(key, v, false))
		control = stepper
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(control)
	_controls[key] = control

	var reset := Button.new()
	reset.theme_type_variation = "SmallTile"
	reset.text = "Sıfırla"
	reset.modulate.a = 0.0 # only a changed row offers it
	reset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resets[key] = reset
	reset.pressed.connect(func() -> void: set_rule(key, _defaults.get(key)))
	box.add_child(reset)

	for target: Control in [row, control, reset]:
		target.mouse_entered.connect(func() -> void: _show_detail(key))
		target.focus_entered.connect(func() -> void: _show_detail(key))
	return row


# --- Shared bits ----------------------------------------------------------------------------------------------------

func _header(text: String) -> Control:
	var sign := PanelContainer.new()
	sign.add_theme_stylebox_override("panel", KahveTheme.sign_style("green", true))
	sign.position = Vector2(80, 36)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "HeadingLabel"
	sign.add_child(label)
	return sign


func _bottom_bar(left_text: String, right_text: String, on_left: Callable, on_right: Callable) -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := Button.new()
	left.text = left_text
	left.position = Vector2(80, 930)
	left.pressed.connect(on_left)
	bar.add_child(left)
	var go := Button.new()
	go.text = right_text
	go.add_theme_font_size_override("font_size", 46)
	for state in ["normal", "hover", "pressed"]:
		go.add_theme_stylebox_override(state, KahveTheme.sign_style("red", true))
	go.add_theme_color_override("font_color", Color("f7f1e1"))
	go.add_theme_color_override("font_hover_color", Color.WHITE)
	go.add_theme_color_override("font_pressed_color", Color("e8dcc0"))
	go.add_theme_color_override("font_focus_color", Color("f7f1e1"))
	go.custom_minimum_size = Vector2(430, 120)
	go.position = Vector2(1420, 905)
	go.pressed.connect(on_right)
	bar.add_child(go)
	return bar


func _build_save_panel() -> void:
	_save_panel.add_theme_stylebox_override("panel", KahveTheme.paper_style())
	_save_panel.set_anchors_preset(Control.PRESET_CENTER)
	_save_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_save_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_save_panel.custom_minimum_size = Vector2(760, 0)
	_save_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_save_panel.add_child(box)
	var heading := Label.new()
	heading.text = "Kural setine bir ad ver"
	heading.add_theme_font_override("font", KahveTheme.font("sign"))
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	box.add_child(heading)
	_save_name.placeholder_text = "Mesela: Cuma akşamı"
	_save_name.max_length = 30
	_save_name.custom_minimum_size = Vector2(0, 64)
	box.add_child(_save_name)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var save := Button.new()
	save.text = "Kaydet"
	save.pressed.connect(func() -> void: save_as(_save_name.text))
	buttons.add_child(save)
	var cancel := Button.new()
	cancel.text = "Vazgeç"
	cancel.pressed.connect(func() -> void: _save_panel.visible = false)
	buttons.add_child(cancel)
	add_child(_save_panel)


# Built-in sets first (the standard rules at the top), then the player's own.
func _preset_list() -> Array[String]:
	var all := GameSettings.preset_names()
	var out: Array[String] = []
	if all.has("klasik"):
		out.append("klasik")
	for name in all:
		if name != "klasik":
			out.append(name)
	return out


func _rebuild_cards() -> void:
	for card in _cards:
		_cards_box.remove_child(card)
		card.queue_free()
	_cards.clear()
	_preset_names = _preset_list()
	for name in _preset_names:
		var set_rules := GameSettings.preset(name)
		var lines := set_rules.summary()
		var summary := "Standart 101 kuralları." if lines.is_empty() else " · ".join(lines.slice(0, 3)) + (" …" if lines.size() > 3 else "")
		var card := RuleCard.new(GameSettings.preset_title(name), summary, name)
		card.chosen.connect(func() -> void: choose_preset(name))
		_cards_box.add_child(card)
		_cards.append(card)


# --- What the page does (also how tests use it) ------------------------------------------------------------------------

func show_page(index: int) -> void:
	_page = index
	for i in _pages.size():
		_pages[i].visible = i == index
	_message.text = ""
	if index == 1:
		if _category_buttons.size() > _category:
			_category_buttons[_category].button_pressed = true
		_apply_filter()
		_show_detail(_groups[_category].keys[0])


## One step back: from the rules to the table, from the table to the menu.
func go_back() -> void:
	if _save_panel.visible:
		_save_panel.visible = false
	elif _page == 1:
		show_page(0)
	else:
		back.emit()


## Changes a rule, as its control would. `sync` moves the control too (when something else made the change).
func set_rule(key: String, value: Variant, sync := true) -> void:
	rules.apply({key: value})
	if sync:
		_sync(key)
	_update_dot(key)
	_update_notes()
	if _only_changed.button_pressed:
		_apply_filter()


## Starts again from a rule set (a preset file name without .json).
func choose_preset(name: String) -> void:
	_rebuild_cards()
	rules = GameSettings.preset(name)
	for card in _cards:
		card.selected = card.set_name == name
	for key: String in _controls:
		_sync(key)
		_update_dot(key)
	_update_notes()
	for i in 3:
		_show_level(i)
	if _only_changed.button_pressed:
		_apply_filter()


## Gives bot seat `seat` (1-3) a level ("kolay", "normal" or "zor").
func choose_level(seat: int, id: String) -> void:
	if not GameDirector.LEVELS.has(id):
		return
	bots[seat - 1] = id
	_show_level(seat - 1)


## Keeps the rules under a name of the player's own (user://presets/) and selects it.
func save_as(name: String) -> void:
	name = name.strip_edges()
	if name == "":
		_message.text = "Bir ad yazman lazım."
		return
	var slug := ""
	for ch in name.to_lower():
		slug += ch if ch.unicode_at(0) > 127 or ch in "abcdefghijklmnopqrstuvwxyz0123456789" else "_"
	rules.save_preset(slug, name)
	_save_panel.visible = false
	_rebuild_cards()
	for card in _cards:
		card.selected = card.set_name == slug
	_message.text = "Kaydedildi: %s" % name


func start() -> void:
	Profile.set_player_name(_name_edit.text)
	started.emit(rules, bots.duplicate())


func _show_level(index: int) -> void:
	var id := bots[index]
	var buttons: Array = _level_buttons[index]
	for i in buttons.size():
		(buttons[i] as Button).set_pressed_no_signal(GameDirector.LEVEL_ORDER[i] == id)
	_level_notes[index].text = GameDirector.LEVELS[id].blurb


func _sync(key: String) -> void:
	var control: Control = _controls[key]
	var value: Variant = rules.get(key)
	if control is Switch:
		(control as Switch).set_state(value)
	elif control is Stepper:
		(control as Stepper).set_value(float(value))


func _update_dot(key: String) -> void:
	var changed: bool = rules.get(key) != _defaults.get(key)
	(_dots[key] as Panel).modulate.a = 1.0 if changed else 0.0
	(_resets[key] as Button).modulate.a = 1.0 if changed else 0.0
	(_resets[key] as Button).mouse_filter = Control.MOUSE_FILTER_STOP if changed else Control.MOUSE_FILTER_IGNORE


func _update_notes() -> void:
	var changed := rules.summary().size()
	var text := "Standart 101 kuralları." if changed == 0 else "%d kural standarttan farklı." % changed
	_preset_note.text = text
	_rules_note.text = text + " Sarı noktalar değişenleri gösterir."


# Shows the rows of the chosen category that match the search and the "only changed" filter.
func _apply_filter() -> void:
	var query := _search.text.strip_edges().to_lower()
	for key: String in _rows:
		var row: Control = _rows[key]
		var label: Array = GameSettings.LABELS.get(key, [key, ""])
		var matches := query == "" or (label[0] as String).to_lower().contains(query) or (label[1] as String).to_lower().contains(query)
		var in_category := query != "" or int(row.get_meta("group")) == _category # a search looks everywhere
		var changed_ok: bool = not _only_changed.button_pressed or rules.get(key) != _defaults.get(key)
		row.visible = matches and in_category and changed_ok


func _show_detail(key: String) -> void:
	var label: Array = GameSettings.LABELS.get(key, [key, ""])
	_detail_title.text = label[0]
	_detail_text.text = label[1]
	_detail_default.text = "Varsayılan: " + _format(key, _defaults.get(key))


func _format(key: String, value: Variant) -> String:
	if value is bool:
		return "açık" if value else "kapalı"
	if value is float:
		return "%.2f" % value if absf(value - snappedf(value, 0.1)) > 0.001 else "%.1f" % value
	return str(value)
