class_name MainMenu
extends CanvasLayer
## The main menu, over the living kahvehane (design size 1920x1080). The camera drifts slowly round the table; over it
## hangs an enamel sign with the name of the game, and below stand the choices as tiles in an okey rack:
## OYNA (the table setup), KURALLAR (the same, at the rules), NASIL OYNANIR, ÇIKIŞ.
## When the menu opens the sign swings a little and the tiles slide up into the rack one by one: the one moment of
## motion that nobody asked for. Arrow keys move between tiles, Enter takes one, Esc goes back.

signal started(rules: GameSettings, bots: Array)
signal quit_pressed

const CONTROLS := """Fare: etrafa bak
Space ya da sağ tık: ıstakana bak (ekranın geri kalanı bulanıklaşır)
W ya da tekerlek: masaya eğil, perleri kuş bakışı gör (ıstakanı göremezsin)
Sol tık: taş al, bırak
Desteye ya da soldakinin attığına tıkla: taşı çek
Çift tık: ıstakadaki taşı at
Ctrl+tık: birkaç taş seç, birini sürükle, hepsi gelir
Taşı açılmış bir perin üstüne bırak: işle
Istakada perleri aralarında boşluk bırakarak diz, Enter: el aç
R ya da ıstaka düğmeleri: otomatik diz
Shift: sessiz ama yavaş çal
F: Yakala! (baktığın kişiyi suçla)   C: Taş say!
Tab: puanlar   H: yardım   1-4: başka koltuğun gözünden bak   Esc: menü"""

## The controls card (a multi-line constant keeps the line ends of the file it is in, so they are cleaned here).
static func controls_text() -> String:
	return CONTROLS.replace("\r", "")


var camera: Camera3D

var _root := Control.new()
var _hanger := Control.new()
var _rack := Control.new()
var _tiles: Array[MenuTile] = []
var _setup: RoomSetup
var _howto := PanelContainer.new()
var _time := 0.0


func _ready() -> void:
	layer = 10
	_root.theme = KahveTheme.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_sign()
	_build_rack()
	_build_howto()
	_setup = RoomSetup.new()
	_setup.visible = false
	_setup.started.connect(func(rules: GameSettings, bots: Array) -> void: started.emit(rules, bots))
	_setup.back.connect(_close_setup)
	_root.add_child(_setup)
	var version := Label.new()
	version.text = "Sürüm 0.1"
	version.theme_type_variation = "SmallLabel"
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -36
	version.offset_bottom = -22
	_root.add_child(version)
	KahveTheme.wire(_root)
	_arrive()


func _process(delta: float) -> void:
	if camera == null:
		return
	# A slow sweep behind the player's chair, looking across the table.
	_time += delta
	var angle := sin(_time * 0.12) * 0.55
	var position := Vector3(sin(angle) * 2.5, 1.62 + sin(_time * 0.2) * 0.08, cos(angle) * 2.5)
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(0.25, 0.9, -0.1) - position, Vector3.UP), position)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if _howto.visible:
			_close_howto()
		elif _setup.visible:
			_setup.go_back()
		get_viewport().set_input_as_handled()


# --- Building -----------------------------------------------------------------------------------------------------

func _build_sign() -> void:
	_hanger.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hanger.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hanger.custom_minimum_size = Vector2(960, 430)
	_hanger.size = Vector2(960, 430)
	_hanger.offset_left = -480
	_hanger.offset_right = 480
	_hanger.offset_top = 0
	_hanger.offset_bottom = 430
	_hanger.pivot_offset = Vector2(480, 0)
	_hanger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hanger)
	for x in [170.0, 790.0]:
		var chain := ColorRect.new()
		chain.color = Color("2c2d2b")
		chain.position = Vector2(x - 5, 0)
		chain.size = Vector2(10, 140)
		chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hanger.add_child(chain)
		var shine := ColorRect.new()
		shine.color = Color("6d726c")
		shine.position = Vector2(x - 5, 0)
		shine.size = Vector2(3, 140)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hanger.add_child(shine)
	var sign := PanelContainer.new()
	sign.position = Vector2(0, 110)
	sign.custom_minimum_size = Vector2(960, 0)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hanger.add_child(sign)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	sign.add_child(words)
	var title := Label.new()
	title.text = "SNEAKY OKEY"
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", KahveTheme.SIZE_HERO)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(title)
	var line := Label.new()
	line.text = "Kahvehane 101'i. Taşını gören olmasın."
	line.theme_type_variation = "HandLabel"
	line.add_theme_font_size_override("font_size", 40)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(line)


func _build_rack() -> void:
	var width := 1380.0
	_rack.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_rack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_rack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_rack.offset_left = -width * 0.5
	_rack.offset_right = width * 0.5
	_rack.offset_top = -500
	_rack.offset_bottom = -30
	_rack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_rack)
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", KahveTheme.slice("rack_back", Vector4(48, 40, 48, 40), Vector4()))
	back.position = Vector2(0, 190)
	back.size = Vector2(width, 230)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rack.add_child(back)
	var entries := [["OYNA", KahveTheme.SUIT_RED, _open_play], ["KURALLAR", KahveTheme.SUIT_BLACK, _open_rules],
		["NASIL
OYNANIR", KahveTheme.SUIT_BLUE, _open_howto], ["ÇIKIŞ", KahveTheme.SUIT_YELLOW, func() -> void: quit_pressed.emit()]]
	var gap := 26.0
	var start := (width - (entries.size() * MenuTile.SIZE.x + (entries.size() - 1) * gap)) * 0.5
	for i in entries.size():
		var tile := MenuTile.new(entries[i][0], entries[i][1])
		tile.position = Vector2(start + i * (MenuTile.SIZE.x + gap), 96)
		tile.pressed.connect(entries[i][2])
		_rack.add_child(tile)
		_tiles.append(tile)
	for i in _tiles.size():
		_tiles[i].focus_neighbor_left = _tiles[maxi(i - 1, 0)].get_path()
		_tiles[i].focus_neighbor_right = _tiles[mini(i + 1, _tiles.size() - 1)].get_path()
	var front := Panel.new()
	front.add_theme_stylebox_override("panel", KahveTheme.slice("rack_front", Vector4(48, 30, 48, 28), Vector4()))
	front.position = Vector2(0, 340)
	front.size = Vector2(width, 120)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rack.add_child(front)


func _build_howto() -> void:
	_howto.add_theme_stylebox_override("panel", KahveTheme.paper_style())
	_howto.set_anchors_preset(Control.PRESET_CENTER)
	_howto.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_howto.grow_vertical = Control.GROW_DIRECTION_BOTH
	_howto.custom_minimum_size = Vector2(1100, 0)
	_howto.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_howto.add_child(box)
	var heading := Label.new()
	heading.text = "Nasıl oynanır"
	heading.add_theme_font_override("font", KahveTheme.font("sign"))
	heading.add_theme_font_size_override("font_size", KahveTheme.SIZE_HEADING)
	heading.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	box.add_child(heading)
	var text := Label.new()
	text.text = controls_text()
	text.add_theme_font_override("font", KahveTheme.font("hand"))
	text.add_theme_font_size_override("font_size", 36)
	text.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var ok := Button.new()
	ok.text = "Tamam"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(_close_howto)
	box.add_child(ok)
	_root.add_child(_howto)


# The opening moment: the sign swings, the tiles slide up into the rack one after another.
func _arrive() -> void:
	var swing := _hanger.create_tween().set_loops()
	swing.tween_property(_hanger, "rotation", 0.012, 2.6).from(-0.012).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing.tween_property(_hanger, "rotation", -0.012, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _tiles.size():
		var tile := _tiles[i]
		var rest := tile.position.y
		tile.position.y = rest + 420.0
		var slide := tile.create_tween()
		slide.tween_interval(0.25 + i * 0.12)
		slide.tween_property(tile, "position:y", rest, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slide.tween_callback(func() -> void: Sfx.ui("tile_rack", -4.0))
	_tiles[0].grab_focus.call_deferred()


# --- Screens ----------------------------------------------------------------------------------------------------

## Opens the table setup (also what OYNA does).
func open_setup() -> RoomSetup:
	_open_play()
	return _setup


func setup_screen() -> RoomSetup:
	return _setup


func _open_play() -> void:
	_show_rack(false)
	_setup.visible = true
	_setup.show_page(0)


func _open_rules() -> void:
	_show_rack(false)
	_setup.visible = true
	_setup.show_page(1)


func _close_setup() -> void:
	_setup.visible = false
	_show_rack(true)


func _open_howto() -> void:
	_show_rack(false)
	_howto.visible = true


func _close_howto() -> void:
	_howto.visible = false
	_show_rack(true)


func _show_rack(on: bool) -> void:
	_rack.visible = on
	_hanger.visible = on
	if on:
		_tiles[0].grab_focus.call_deferred()
