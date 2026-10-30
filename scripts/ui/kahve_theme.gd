class_name KahveTheme
## The look of every screen. Not panels and buttons but things from the kahvehane (docs/design/screens.md):
##   a button is an okey tile (cream bakelite with a thickness; it rises when you point at it and sinks when you press),
##   a title or a panel is an enamel shop sign (deep green or red, a white inner line, rivets),
##   the rules and the ledger are paper, a key is a keycap, the score at the end of a hand is chalk on slate.
## Textures come from tools/make_ui.py (assets/ui/), fonts from tools/fetch_fonts.py (assets/fonts/, SIL OFL).
## The design size is 1920x1080 (project.godot stretches it to the window), so sizes here are in those pixels.
## `theme()` goes on the root Control of a screen; `wire()` adds the click sound to every button below a node.

# --- Colours -------------------------------------------------------------------------------------------------------
const BOARD := Color("0f3a2b") # enamel green and the slate of the score board
const ENAMEL_RED := Color("a3231a")
const TILE := Color("ede3cc")
const INK := Color("1b1410")
const WOOD := Color("2a1a10")
## The four colours of the tiles. Each seat gets one: its score row, name plate and turn ring.
const SUIT_RED := Color("d1342c")
const SUIT_BLACK := Color("2a2a2e")
const SUIT_BLUE := Color("2a63c9")
const SUIT_YELLOW := Color("e39a14")
const SEAT_COLOURS := [SUIT_RED, SUIT_BLACK, SUIT_BLUE, SUIT_YELLOW]
## Brass: only for what won, and for what you are pointing at.
const BRASS := Color("c99a3c")
const BRASS_BRIGHT := Color("f0c35a")
const CREAM := Color("ede3cc")
const CREAM_LIGHT := Color("fbf5e4")
const INK_SOFT := Color("5c4a3a")
const CHALK := Color("e9f1e8")
const CHALK_DIM := Color("a9bdb0")
const PAPER_INK := Color("2b2118")

# --- Type scale (design pixels) ------------------------------------------------------------------------------------
const SIZE_TINY := 20
const SIZE_SMALL := 24
const SIZE_BODY := 28
const SIZE_LABEL := 32
const SIZE_HEADING := 44
const SIZE_TITLE := 64
const SIZE_HERO := 110

const WGHT := 2003265652 # the OpenType tag "wght", for the variable fonts

static var _theme: Theme
static var _fonts := {}
static var _textures := {}


## "sign" (Alfa Slab One: tabela and tile lettering), "display" (Bungee), "ui" (Rubik medium), "ui_bold" (Rubik bold),
## "hand" (Patrick Hand: ledger and chalk), "script" (Caveat: the quick scribble).
static func font(kind := "ui") -> Font:
	if not _fonts.has(kind):
		match kind:
			"sign":
				_fonts[kind] = load("res://assets/fonts/AlfaSlabOne-Regular.ttf")
			"display":
				_fonts[kind] = load("res://assets/fonts/Bungee-Regular.ttf")
			"hand":
				_fonts[kind] = load("res://assets/fonts/PatrickHand-Regular.ttf")
			"script":
				_fonts[kind] = _variable("res://assets/fonts/Caveat-Variable.ttf", 600)
			"ui_bold":
				_fonts[kind] = _variable("res://assets/fonts/Rubik-Variable.ttf", 700)
			_:
				_fonts[kind] = _variable("res://assets/fonts/Rubik-Variable.ttf", 500)
	return _fonts[kind]


static func _variable(path: String, weight: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = load(path)
	variation.variation_opentype = {WGHT: weight}
	return variation


static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://assets/ui/%s.png" % name)
	return _textures[name]


# --- Styles built from the textures -----------------------------------------------------------------------------

## A 9-slice style of an assets/ui texture. `margins` are the slice edges (left, top, right, bottom) and `content` the
## space kept free inside, both in texture pixels.
static func slice(name: String, margins: Vector4, content: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex(name)
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


## An okey tile as a button in one of its states: "normal", "hover", "pressed", "disabled". Its lettering sits on the
## face, which is why the content margins change with the state: the text rises and sinks with the tile.
static func tile_style(state := "normal", small := false) -> StyleBoxTexture:
	var face := {"normal": [20, 36], "hover": [14, 42], "pressed": [26, 30], "disabled": [20, 36]}[state] as Array
	if small: # the same tile drawn at 0.6 for rows of settings and the rack's tools
		return slice("tilesm_" + state, Vector4(17, 22, 17, 31), Vector4(24, face[0] * 0.6, 24, face[1] * 0.6))
	return slice("tile_" + state, Vector4(28, 36, 28, 52), Vector4(36, face[0], 36, face[1]))


## An enamel sign: "green", "red" or "dark". Content sits inside its white line.
static func sign_style(colour := "green", small := false) -> StyleBoxTexture:
	if small: # the half-size sign: badges, the turn banner, a toast
		return slice("signsm_" + colour, Vector4(20, 20, 20, 22), Vector4(26, 22, 26, 28))
	return slice("sign_" + colour, Vector4(40, 40, 40, 44), Vector4(52, 48, 52, 54))


static func paper_style() -> StyleBoxTexture:
	return slice("paper", Vector4(40, 40, 40, 44), Vector4(54, 46, 54, 54))


static func slip_style() -> StyleBoxTexture:
	return slice("slip", Vector4(24, 24, 24, 30), Vector4(30, 22, 30, 30))


## A slip with room for two lines of text (the rule-set cards).
static func paper_style_small() -> StyleBoxTexture:
	return slice("slip", Vector4(24, 24, 24, 30), Vector4(30, 18, 24, 28))


static func keycap_style() -> StyleBoxTexture:
	return slice("keycap", Vector4(16, 16, 16, 20), Vector4(16, 6, 16, 12))


## Only for the odd spot a flat box is still the right thing (a thin outline, a dimmer).
static func box(color: Color, border := BRASS, border_width := 3, radius := 8, margin := Vector2(18, 9)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin.x
	style.content_margin_right = margin.x
	style.content_margin_top = margin.y
	style.content_margin_bottom = margin.y
	return style


# --- The theme ------------------------------------------------------------------------------------------------------

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("ui")
	t.default_font_size = SIZE_BODY

	# Buttons are tiles, lettered in the slab face like the numbers on a tile.
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "Button", tile_style(state))
		t.set_stylebox(state, "OptionButton", tile_style(state))
	var focus := slice("tile_focus", Vector4(28, 36, 28, 52), Vector4(0, 0, 0, 0))
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("focus", "OptionButton", focus)
	for kind in ["Button", "OptionButton"]:
		t.set_font("font", kind, font("sign"))
		t.set_font_size("font_size", kind, SIZE_LABEL)
		for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(colour, kind, INK)
		t.set_color("font_disabled_color", kind, Color(INK, 0.4))
		t.set_constant("outline_size", kind, 0)
	t.set_constant("h_separation", "Button", 12)
	# The small tile: for settings rows, steppers and the rack's tools.
	t.set_type_variation("SmallTile", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "SmallTile", tile_style(state, true))
	t.set_stylebox("focus", "SmallTile", slice("tilesm_focus", Vector4(17, 22, 17, 31), Vector4(0, 0, 0, 0)))
	t.set_font_size("font_size", "SmallTile", SIZE_SMALL)
	for colour in ["font_pressed_color", "font_hover_pressed_color"]: # a chosen toggle reads red
		t.set_color(colour, "SmallTile", ENAMEL_RED)

	# Panels: the dark enamel sign.
	t.set_stylebox("panel", "PanelContainer", sign_style("green"))
	t.set_stylebox("panel", "Panel", sign_style("green"))
	t.set_stylebox("panel", "PopupMenu", sign_style("dark"))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("hover", "PopupMenu", box(CREAM, CREAM, 0, 6, Vector2(12, 6)))
	t.set_font_size("font_size", "PopupMenu", SIZE_BODY)

	# Text: chalk-white on the dark signs, with no outline (the outline was what made it look like a prototype).
	t.set_color("font_color", "Label", CREAM_LIGHT)
	t.set_constant("outline_size", "Label", 0)
	t.set_font_size("font_size", "Label", SIZE_BODY)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font("sign"))
	t.set_font_size("font_size", "TitleLabel", SIZE_TITLE)
	t.set_color("font_color", "TitleLabel", Color("f7f1e1"))
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", font("sign"))
	t.set_font_size("font_size", "HeadingLabel", SIZE_HEADING)
	t.set_color("font_color", "HeadingLabel", Color("f7f1e1"))
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", SIZE_SMALL)
	t.set_color("font_color", "SmallLabel", Color(CREAM, 0.75))
	t.set_type_variation("HandLabel", "Label")
	t.set_font("font", "HandLabel", font("hand"))
	t.set_font_size("font_size", "HandLabel", SIZE_LABEL)
	t.set_color("font_color", "HandLabel", CHALK)

	# Tabs of the rules page: a tile each.
	t.set_stylebox("tab_selected", "TabContainer", tile_style("normal"))
	t.set_stylebox("tab_unselected", "TabContainer", tile_style("disabled"))
	t.set_stylebox("tab_hovered", "TabContainer", tile_style("hover"))
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", Color(INK, 0.6))
	t.set_color("font_hovered_color", "TabContainer", INK)

	var field := box(CREAM, Color(INK, 0.5), 2, 10, Vector2(16, 8))
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", box(CREAM_LIGHT, ENAMEL_RED, 3, 10, Vector2(16, 8)))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	t.set_color("caret_color", "LineEdit", ENAMEL_RED)
	t.set_font_size("font_size", "LineEdit", SIZE_LABEL)

	t.set_stylebox("slider", "HSlider", slice("bar_groove", Vector4(14, 14, 14, 14), Vector4(0, 0, 0, 0)))
	t.set_stylebox("grabber_area", "HSlider", slice("bar_fill", Vector4(14, 14, 14, 14), Vector4(0, 0, 0, 0)))
	t.set_stylebox("grabber_area_highlight", "HSlider", slice("bar_fill", Vector4(14, 14, 14, 14), Vector4(0, 0, 0, 0)))
	t.set_icon("grabber", "HSlider", tex("switch_knob"))
	t.set_icon("grabber_highlight", "HSlider", tex("switch_knob"))

	# The scroll bar: a thin groove with a felt-green thumb.
	var groove := box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 8, Vector2(0, 0))
	var thumb := box(Color("2f7d57"), Color(0, 0, 0, 0), 0, 8, Vector2(0, 0))
	var thumb_hot := box(Color("45a577"), Color(0, 0, 0, 0), 0, 8, Vector2(0, 0))
	t.set_stylebox("scroll", "VScrollBar", groove)
	t.set_stylebox("grabber", "VScrollBar", thumb)
	t.set_stylebox("grabber_highlight", "VScrollBar", thumb_hot)
	t.set_stylebox("grabber_pressed", "VScrollBar", thumb_hot)

	var line := StyleBoxLine.new()
	line.color = Color(CREAM, 0.25)
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 18)
	_theme = t
	return t


## Hover and click sounds for every button under `node` (and any added to it later).
static func wire(node: Node) -> void:
	for child in node.get_children():
		wire(child)
	if node is BaseButton and not node.has_meta("kahve_wired"):
		node.set_meta("kahve_wired", true)
		(node as BaseButton).mouse_entered.connect(func() -> void: Sfx.ui("ui_hover", -10.0))
		(node as BaseButton).pressed.connect(func() -> void: Sfx.ui("tile_click", -3.0))
	if not node.has_meta("kahve_watch"):
		node.set_meta("kahve_watch", true)
		node.child_entered_tree.connect(func(child: Node) -> void: wire.call_deferred(child))


## A heading in the slab face. (Kept for the screens that are not rebuilt yet.)
static func title(text: String, size := SIZE_HEADING) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font("sign"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f7f1e1"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
