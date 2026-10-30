class_name Hud
extends CanvasLayer
## What is on screen while you play (design size 1920x1080; docs/design/screens.md). Few things, each a kahvehane object:
##   top left    the score sign: a row per seat in its tile colour, the one whose turn it is lit, a tick for those who opened;
##   top centre  a small banner: whose turn it is (and your clock);
##   bottom      one line that says what to press now, with key caps;
##   rack view   the opening bar (87 / 101), and tile buttons to lay the rack out;
##   right       paper slips for what just happened (they fade);
##   centre      a rubber stamp for the big moments, a red toast for "not now", a small cue when something moves nearby;
##   end of hand the chalkboard (HandEndShow writes it), Tab: the ledger sheet, H or F1: how to play.
## The 3D name plates over the dayıs are Nameplate, not here.

const TOOLS := [["sets", "Seri diz", "icon_sets"], ["pairs", "Çift diz", "icon_pairs"], ["color", "Renge göre", "icon_color"],
	["number", "Sayıya göre", "icon_number"], ["open", "El aç", "icon_check"]]
## HandEndShow was written for a 1280-wide board; its sizes are multiplied by this.
const BOARD_SCALE := 1.5

## A rack tool was pressed (an id from TOOLS).
signal tool_pressed(id: String)

var _root := Control.new()
var _crosshair := Control.new()
var _crosshair_hot := false
var _hint := Label.new()
var _turn := PanelContainer.new()
var _turn_label := Label.new()
var _turn_stripe := ColorRect.new()
var _turn_key := "" # the banner's words without the clock, to see when whose turn it is changes
var _turn_tween: Tween
var _turn_urgent := false
var _prompt_tween: Tween
var _page_tweens := {}
var _prompt_box := PanelContainer.new()
var _prompt_holder := HBoxContainer.new()
var _prompt_signature := ""
var _cue_box := PanelContainer.new()
var _cue_holder := HBoxContainer.new()
var _cue := Label.new() # the cue's plain text (also what tests read)
var _cue_side := 0
var _opening := ProgressPill.new()
var _tools := HBoxContainer.new()
var _tool_buttons := {}
var _feed := SlipFeed.new()
var _stamp := Stamp.new()
var _toast := PanelContainer.new()
var _toast_label := Label.new()
var _toast_tween: Tween
var _board := PanelContainer.new()
var _board_rows := VBoxContainer.new()
var _board_buttons := HBoxContainer.new()
var _sheet := PanelContainer.new()
var _ledger := VBoxContainer.new()
var _help := PanelContainer.new()


func _ready() -> void:
	_root.theme = KahveTheme.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_crosshair()
	_build_turn()
	_build_prompt()
	_build_cue()
	_build_opening_and_tools()
	_build_feed_and_toast()
	_build_board()
	_build_paper_pages()
	_root.add_child(_stamp)
	KahveTheme.wire(_root)


func _process(_delta: float) -> void:
	if _cue_box.visible:
		var view := _root.size
		var x := (view.x - _cue_box.size.x) * 0.5
		if _cue_side < 0:
			x = 48.0
		elif _cue_side > 0:
			x = view.x - _cue_box.size.x - 48.0
		_cue_box.position = Vector2(x, view.y * (0.52 if _cue_side != 0 else 0.66))


# --- Building -----------------------------------------------------------------------------------------------------

func _build_crosshair() -> void:
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		_crosshair.draw_circle(Vector2.ZERO, 6.5, Color(0, 0, 0, 0.5))
		_crosshair.draw_circle(Vector2.ZERO, 4.5, Color(1, 1, 1, 0.95))
		if _crosshair_hot:
			_crosshair.draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 40, Color(0, 0, 0, 0.5), 5.0)
			_crosshair.draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 40, KahveTheme.BRASS_BRIGHT, 3.0))
	_root.add_child(_crosshair)
	_hint.anchor_top = 0.5
	_hint.anchor_bottom = 0.5
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.offset_top = 60
	_hint.offset_bottom = 130
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	_hint.add_theme_font_size_override("font_size", KahveTheme.SIZE_BODY)
	_hint.add_theme_color_override("font_color", KahveTheme.CREAM_LIGHT)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)


func _build_turn() -> void:
	_turn.add_theme_stylebox_override("panel", KahveTheme.sign_style("dark", true))
	_turn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_turn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_turn.offset_top = 30
	_turn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn.pivot_offset = Vector2(0, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_turn.add_child(row)
	_turn_stripe.custom_minimum_size = Vector2(8, 28)
	row.add_child(_turn_stripe)
	_turn_label.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	_turn_label.add_theme_font_size_override("font_size", KahveTheme.SIZE_SMALL)
	row.add_child(_turn_label)
	_turn.visible = false
	_root.add_child(_turn)


func _build_prompt() -> void:
	_prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_box.offset_bottom = -34
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.04, 0.025, 0.015, 0.55)
	pill.set_corner_radius_all(30)
	pill.content_margin_left = 30
	pill.content_margin_right = 30
	pill.content_margin_top = 10
	pill.content_margin_bottom = 12
	_prompt_box.add_theme_stylebox_override("panel", pill)
	_prompt_holder.add_theme_constant_override("separation", 26)
	_prompt_box.add_child(_prompt_holder)
	_prompt_box.visible = false
	_root.add_child(_prompt_box)


func _build_cue() -> void:
	_cue_box.add_theme_stylebox_override("panel", KahveTheme.sign_style("red", true))
	_cue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue_box.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_cue_box.add_child(row)
	var eye := TextureRect.new()
	eye.texture = KahveTheme.tex("icon_eye")
	eye.custom_minimum_size = Vector2(40, 40)
	eye.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eye.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	eye.modulate = KahveTheme.CREAM_LIGHT
	row.add_child(eye)
	_cue.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	_cue.add_theme_font_size_override("font_size", KahveTheme.SIZE_BODY)
	row.add_child(_cue)
	_cue_holder.add_theme_constant_override("separation", 10)
	row.add_child(_cue_holder)
	_root.add_child(_cue_box)


func _build_opening_and_tools() -> void:
	_opening.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_opening.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_opening.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_opening.custom_minimum_size = Vector2(560, 54)
	_opening.offset_bottom = -250
	_opening.visible = false
	_root.add_child(_opening)

	_tools.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tools.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tools.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tools.offset_bottom = -150
	_tools.add_theme_constant_override("separation", 12)
	_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tools.visible = false
	for entry: Array in TOOLS:
		var button := Button.new()
		button.theme_type_variation = "SmallTile"
		button.text = entry[1]
		button.icon = KahveTheme.tex(entry[2])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 30)
		for colour in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(colour, KahveTheme.INK)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: tool_pressed.emit(entry[0]))
		_tools.add_child(button)
		_tool_buttons[entry[0]] = button
	_root.add_child(_tools)


func _build_feed_and_toast() -> void:
	_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feed.custom_minimum_size = Vector2(520, 0)
	_feed.offset_right = -36
	_feed.offset_bottom = -34
	_root.add_child(_feed)

	_toast.add_theme_stylebox_override("panel", KahveTheme.sign_style("red", true))
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -330
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	_toast_label.add_theme_font_size_override("font_size", KahveTheme.SIZE_BODY)
	_toast.add_child(_toast_label)
	_toast.visible = false
	_root.add_child(_toast)


func _build_board() -> void:
	_board.add_theme_stylebox_override("panel", KahveTheme.sign_style("green"))
	_board.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	_board.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_board.offset_left = -740
	_board.offset_right = -30
	_board.offset_top = -505
	_board.offset_bottom = 505
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	var slate := VBoxContainer.new()
	slate.add_theme_constant_override("separation", 10)
	_board_rows.add_theme_constant_override("separation", 4)
	slate.add_child(_board_rows)
	_board_buttons.add_theme_constant_override("separation", 14)
	_board_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	slate.add_child(_board_buttons)
	_board.add_child(slate)
	_root.add_child(_board)


func _build_paper_pages() -> void:
	# The ledger sheet (Tab) and the how-to-play card (H, F1): paper on the table.
	for page: PanelContainer in [_sheet, _help]:
		page.add_theme_stylebox_override("panel", KahveTheme.paper_style())
		page.set_anchors_preset(Control.PRESET_CENTER)
		page.grow_horizontal = Control.GROW_DIRECTION_BOTH
		page.grow_vertical = Control.GROW_DIRECTION_BOTH
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.visible = false
		_root.add_child(page)
	_ledger.add_theme_constant_override("separation", 10)
	_sheet.add_child(_ledger)
	var help_text := Label.new()
	help_text.text = MainMenu.controls_text()
	help_text.add_theme_font_override("font", KahveTheme.font("hand"))
	help_text.add_theme_font_size_override("font_size", 36)
	help_text.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	_help.add_child(help_text)


# --- The game's side ----------------------------------------------------------------------------------------------

func show_crosshair(on: bool) -> void:
	_crosshair.visible = on


## What a click here would do ("" = nothing): under the crosshair, which turns into a ring when there is something.
func set_hint(text: String) -> void:
	_hint.text = text
	var hot := text != ""
	if hot != _crosshair_hot:
		_crosshair_hot = hot
		_crosshair.queue_redraw()


## The banner at the top: whose turn it is, in his colour. "" hides it. When the turn passes the banner drops in
## afresh (yours with a tick), and the last seconds of your clock make its stripe blink.
func set_turn(text: String, colour := Color.WHITE) -> void:
	_turn.visible = text != ""
	_turn_label.text = text
	_turn_stripe.color = colour
	var key := text.get_slice("  ·", 0)
	var seconds := int(text.get_slice("·  ", 1)) if text.contains("·") else 0
	var urgent := key == "Sıra sende" and seconds > 0 and seconds <= 5
	if key != _turn_key:
		_turn_key = key
		_turn_urgent = false
		if key != "":
			_banner_in(key == "Sıra sende")
	if urgent != _turn_urgent:
		_turn_urgent = urgent
		if _turn_tween:
			_turn_tween.kill()
			_turn_tween = null
		_turn_stripe.modulate = Color.WHITE
		if urgent:
			_turn_tween = create_tween().set_loops()
			_turn_tween.tween_property(_turn_stripe, "modulate", Color(1, 0.25, 0.2), 0.25)
			_turn_tween.tween_property(_turn_stripe, "modulate", Color.WHITE, 0.25)


# The banner drops in from above and settles (with a tick when it is your turn).
func _banner_in(mine: bool) -> void:
	if mine:
		Sfx.ui("tile_click", -6.0)
	if Fade.instant:
		return
	if _turn_tween:
		_turn_tween.kill()
	_turn.modulate.a = 0.0
	_turn.offset_top = 30 - 36
	_turn_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_property(_turn, "offset_top", 30.0, 0.4)
	_turn_tween.tween_property(_turn, "modulate:a", 1.0, 0.2)
	_turn_tween.chain().tween_callback(func() -> void: _turn_tween = null)


## One line saying what to press now: words and keys, as KeyCap.line takes them ([] hides it). A "|" in the list
## starts a new group, with a wider gap.
func set_prompt(parts: Array) -> void:
	var signature := str(parts)
	if signature == _prompt_signature:
		return
	_prompt_signature = signature
	for child in _prompt_holder.get_children():
		_prompt_holder.remove_child(child)
		child.queue_free()
	_prompt_box.visible = not parts.is_empty()
	if _prompt_box.visible and not Fade.instant: # a new line fades up
		if _prompt_tween:
			_prompt_tween.kill()
		_prompt_box.modulate.a = 0.0
		_prompt_tween = create_tween()
		_prompt_tween.tween_property(_prompt_box, "modulate:a", 1.0, 0.3)
	var group: Array = []
	for part: Variant in parts:
		if part is String and part == "|":
			if not group.is_empty():
				_prompt_holder.add_child(KeyCap.line(group, KahveTheme.SIZE_BODY))
			group = []
		else:
			group.append(part)
	if not group.is_empty():
		_prompt_holder.add_child(KeyCap.line(group, KahveTheme.SIZE_BODY))


## The opening bar over the rack: "Açılış 87 / 101". Hidden when `shown` is false.
func set_opening(shown: bool, value := 0.0, goal := 0.0, text := "") -> void:
	_opening.visible = shown
	if shown:
		_opening.maximum = maxf(maxf(goal * 1.3, value), 1.0)
		_opening.goal = goal
		_opening.value = value
		_opening.text = text


## A short cue about something near: at the edge it came from (side -1 left, +1 right), 0 in the lower middle.
## `parts` (words and key caps) follow the text, e.g. ["Gördün", ["F"], "Yakala!"]; "" hides the cue.
func set_cue(text: String, side := 0, parts: Array = []) -> void:
	_cue.text = text
	_cue_side = side
	_cue_box.visible = text != ""
	for child in _cue_holder.get_children():
		_cue_holder.remove_child(child)
		child.queue_free()
	if not parts.is_empty():
		_cue_holder.add_child(KeyCap.line(parts, KahveTheme.SIZE_BODY))


## A note about what just happened, as a paper slip on the right; `colour` is a seat's tile colour.
func note(text: String, colour := Color.TRANSPARENT) -> void:
	_feed.add_slip(text, colour)


## A rubber stamp in the middle of the screen, for the big moments.
func stamp(text: String, colour: Color) -> void:
	_stamp.slam(text, colour)


## A small red notice for "not now" and other refusals.
func toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


## Kept for callers that have not chosen yet: the big moments are stamps.
func flash(text: String, color: Color) -> void:
	stamp(text, color)


## Shows the buttons for the rack: `ids` are the ones to show (a subset of TOOLS), nothing hides them all.
func show_tools(ids: Array) -> void:
	_tools.visible = not ids.is_empty()
	for id: String in _tool_buttons:
		(_tool_buttons[id] as Button).visible = ids.has(id)


func tools_visible() -> bool:
	return _tools.visible


func opening_visible() -> bool:
	return _opening.visible


func feed_count() -> int:
	return _feed.count()


## The how-to-play card.
func toggle_help() -> void:
	_show_page(_help, not _help.visible)


# A paper page (the ledger, the help) is laid on the table: it fades up from a little larger, and lifts away.
func _show_page(page: Control, on: bool) -> void:
	if Fade.instant:
		page.visible = on
		page.modulate.a = 1.0
		return
	if _page_tweens.has(page):
		(_page_tweens[page] as Tween).kill()
	page.visible = true
	page.pivot_offset = page.size * 0.5
	var tween := page.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if on:
		page.modulate.a = 0.0
		page.scale = Vector2(1.04, 1.04)
		tween.tween_property(page, "modulate:a", 1.0, 0.18)
		tween.tween_property(page, "scale", Vector2.ONE, 0.25)
		Sfx.ui("tile_slide", -8.0)
	else:
		tween.tween_property(page, "modulate:a", 0.0, 0.15)
		tween.tween_property(page, "scale", Vector2(1.03, 1.03), 0.15)
		tween.chain().tween_callback(func() -> void:
			page.visible = false
			page.scale = Vector2.ONE)
	_page_tweens[page] = tween


func help_visible() -> bool:
	return _help.visible


## The ledger (Tab): the match as a page of a veresiye defteri. `data`: {hand (the one in play), hands (of the match),
## players: [{name, colour, total, lead, turn}], history: [{scores: [4], notes: [[[text, points], ...] x 4]}], footer}.
## {} hides it.
func show_ledger(data: Dictionary) -> void:
	if data.is_empty():
		if _sheet.visible:
			_show_page(_sheet, false)
		return
	for child in _ledger.get_children():
		_ledger.remove_child(child)
		child.queue_free()
	var ink := KahveTheme.PAPER_INK
	var players: Array = data.players
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Veresiye defteri"
	title.add_theme_font_override("font", KahveTheme.font("sign"))
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", ink)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var which := Label.new()
	which.text = "%d. el / %d" % [data.hand, data.hands]
	which.add_theme_font_override("font", KahveTheme.font("script"))
	which.add_theme_font_size_override("font_size", 46)
	which.add_theme_color_override("font_color", KahveTheme.ENAMEL_RED)
	head.add_child(which)
	_ledger.add_child(head)
	_ledger.add_child(_rule(3.0))

	var grid := GridContainer.new()
	grid.columns = 1 + players.size()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	grid.add_child(_cell("", "hand", 30, HORIZONTAL_ALIGNMENT_LEFT, 130))
	for player: Dictionary in players:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(210, 0)
		box.add_theme_constant_override("separation", 0)
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 8)
		var dot := Panel.new()
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = player.colour
		dot_style.set_corner_radius_all(11)
		dot_style.border_color = Color(ink, 0.5)
		dot_style.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", dot_style)
		dot.custom_minimum_size = Vector2(22, 22)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		line.add_child(_cell(player.name, "ui_bold", 26, HORIZONTAL_ALIGNMENT_CENTER, 0, KahveTheme.ENAMEL_RED if player.turn else ink))
		box.add_child(line)
		box.add_child(_cell("sıra onda" if player.turn else "", "script", 26, HORIZONTAL_ALIGNMENT_CENTER, 0, KahveTheme.ENAMEL_RED))
		grid.add_child(box)
	var history: Array = data.history
	var shown := history.slice(maxi(history.size() - 6, 0))
	var first := history.size() - shown.size()
	for i in shown.size():
		grid.add_child(_cell("%d. el" % (first + i + 1), "hand", 34, HORIZONTAL_ALIGNMENT_LEFT, 130, Color(ink, 0.75)))
		var scores: Array = shown[i].scores
		var best: int = scores.min()
		for score: int in scores:
			var heavy := score >= 100
			grid.add_child(_cell("%d" % score, "hand", 40, HORIZONTAL_ALIGNMENT_CENTER, 0,
				KahveTheme.ENAMEL_RED if heavy else (Color("1f6b3b") if score == best else ink)))
	if history.is_empty():
		grid.add_child(_cell("Henüz el bitmedi", "hand", 32, HORIZONTAL_ALIGNMENT_LEFT, 130, Color(ink, 0.6)))
		for i in players.size():
			grid.add_child(_cell("", "hand", 32))
	_ledger.add_child(grid)
	_ledger.add_child(_rule(3.0))
	_ledger.add_child(_rule(1.5))

	var totals := GridContainer.new()
	totals.columns = grid.columns
	totals.add_theme_constant_override("h_separation", 16)
	totals.add_child(_cell("Toplam", "sign", 30, HORIZONTAL_ALIGNMENT_LEFT, 130))
	for player: Dictionary in players:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(210, 0)
		box.add_theme_constant_override("separation", -4)
		box.add_child(_cell("%d" % player.total, "sign", 54, HORIZONTAL_ALIGNMENT_CENTER, 0, KahveTheme.ENAMEL_RED if player.lead else ink))
		box.add_child(_cell("önde" if player.lead else "", "script", 28, HORIZONTAL_ALIGNMENT_CENTER, 0, KahveTheme.ENAMEL_RED))
		totals.add_child(box)
	_ledger.add_child(totals)

	# What was written against each name in the last hand, as the margin notes of a ledger.
	var notes: Array[String] = []
	if not history.is_empty():
		var last: Dictionary = history.back()
		for i in players.size():
			for note: Array in last.notes[i]:
				notes.append("%s: %s  %+d" % [players[i].name, note[0], note[1]])
	if not notes.is_empty():
		_ledger.add_child(_rule(1.5))
		for note in notes.slice(0, 6):
			_ledger.add_child(_cell(note, "hand", 28, HORIZONTAL_ALIGNMENT_LEFT, 0, Color(ink, 0.85)))
	var footer: String = data.footer
	if footer != "":
		_ledger.add_child(_cell(footer, "script", 36, HORIZONTAL_ALIGNMENT_RIGHT, 0, KahveTheme.ENAMEL_RED))
	var was_up := _sheet.visible
	_sheet.visible = true
	_sheet.reset_size()
	if not was_up:
		_show_page(_sheet, true)


func _cell(text: String, kind: String, size: int, align := HORIZONTAL_ALIGNMENT_LEFT, width := 0, colour := KahveTheme.PAPER_INK) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_override("font", KahveTheme.font(kind))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if width > 0:
		label.custom_minimum_size = Vector2(width, 0)
	return label


func _rule(thickness: float) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(KahveTheme.PAPER_INK, 0.55)
	line.custom_minimum_size = Vector2(0, thickness)
	return line


func sheet_visible() -> bool:
	return _sheet.visible


# --- The chalkboard ---------------------------------------------------------------------------------------------

## Clears the chalkboard, titles it and shows it (HandEndShow adds the rows).
func board_open(title: String) -> void:
	board_clear()
	_board.visible = true
	var label := Label.new()
	label.text = title
	label.add_theme_font_override("font", KahveTheme.font("sign"))
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", KahveTheme.BRASS_BRIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_rows.add_child(label)


func board_clear() -> void:
	for child in _board_rows.get_children():
		_board_rows.remove_child(child)
		child.queue_free()
	for child in _board_buttons.get_children():
		_board_buttons.remove_child(child)
		child.queue_free()


func board_close() -> void:
	board_clear()
	_board.visible = false
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE


func board_visible() -> bool:
	return _board.visible


func board_row_count() -> int:
	return _board_rows.get_child_count()


## One line in chalk: `left` text, `right` figure. Returns {row, left, right} so the show can fade and count it.
## Sizes are for the old 1280-wide board and scaled here.
func board_row(left: String, right := "", size := 20, color := KahveTheme.CHALK, indent := 0.0) -> Dictionary:
	var row := HBoxContainer.new()
	if indent > 0.0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(indent * BOARD_SCALE, 0)
		row.add_child(gap)
	var left_label := Label.new()
	var right_label := Label.new()
	for label in [left_label, right_label]:
		label.add_theme_font_override("font", KahveTheme.font("hand"))
		label.add_theme_font_size_override("font_size", int(size * BOARD_SCALE * 1.1))
		label.add_theme_color_override("font_color", color)
	left_label.text = left
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_label.text = right
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(left_label)
	row.add_child(right_label)
	_board_rows.add_child(row)
	return {"row": row, "left": left_label, "right": right_label}


## Buttons under the board: entries of [text, callable].
func board_buttons(entries: Array) -> void:
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		_board_buttons.add_child(button)
	KahveTheme.wire(_board_buttons)
	_board.mouse_filter = Control.MOUSE_FILTER_PASS
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
