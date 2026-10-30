class_name Intro
extends CanvasLayer
## The opening of the game: you come in from the rain. Black; the street door swings open with its bell and the
## rain; you stand in the doorway looking at the lit street behind you, turn, and walk slowly into the kahvehane
## past the stove, the regulars and the çay ocağı until you stand behind your own chair looking across the table,
## which is where the main menu's camera starts. Halfway in, the name of the game is laid letter by letter as okey
## tiles across the picture, with a line of script under it, and lifts away again before the menu arrives.
## Letterbox bars frame the shot. Any key or click skips to the end. `finished` is emitted either way.
## Headless it is over at once (`enabled`), as the other shows are; tests switch it on to run it for real.

signal finished

static var enabled := DisplayServer.get_name() != "headless"

const DURATION := 15.0
const TITLE := "SNEAKY OKEY"
const TAGLINE := "Kahvehane 101'i. Taşını gören olmasın."
const DOOR_OPEN := -1.35 # radians the leaf swings into the room (as the visitors open it)
# Where the camera goes (x, y, z) and what it looks at, in order; the path curves through them and ends at the
# menu's first pose (MainMenu.orbit_pose(0.0)), which is added in _init.
const PATH := [
	[Vector3(1.25, 1.48, 2.75), Vector3(1.3, 1.25, 3.75)],   # in the doorway, looking back at the open door
	[Vector3(1.0, 1.5, 2.85), Vector3(-2.6, 1.05, 1.4)],     # turning: the stove and the cat
	[Vector3(0.55, 1.55, 2.8), Vector3(-1.5, 1.0, -0.6)],    # the table comes round, the regulars beyond it
	[Vector3(0.75, 1.65, 2.55), Vector3(0.1, 0.9, -0.1)],    # over your own chair, toward the others
]

var camera: Camera3D
var door_hinge: Node3D
## `fade` is Main's curtain: the intro lifts it as the door opens and drops it when skipped.
var fade: Fade

var _path: Array = []
var _root := Control.new()
var _bars: Array[ColorRect] = []
var _title := Control.new()
var _letters: Array[Control] = []
var _tagline := Label.new()
var _skip := Label.new()
var _time := 0.0
var _done := false
var _skipping := false
var _title_shown := false
var _title_lifted := false
var _door_closed := false


func _init() -> void:
	_path = PATH.duplicate()
	var end := MainMenu.orbit_pose(0.0)
	_path.append([end.origin, end.origin - end.basis.z * 2.5])


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.theme = KahveTheme.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 110)
		if i == 0:
			bar.offset_bottom = 110
		else:
			bar.offset_top = -110
		_root.add_child(bar)
		_bars.append(bar)
	_build_title()
	_skip.text = "Herhangi bir tuş: atla"
	_skip.theme_type_variation = "SmallLabel"
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -40
	_skip.offset_bottom = -36
	_skip.modulate.a = 0.0
	_root.add_child(_skip)
	if camera:
		camera.global_transform = _pose(0.0)
	if not enabled:
		_finish.call_deferred()
		return
	_start.call_deferred()


func _build_title() -> void:
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)
	var size := Vector2(116, 150)
	var gap := 10.0
	var words := TITLE.split(" ")
	var width := 0.0
	for word in words:
		width += word.length() * (size.x + gap)
	width += (words.size() - 1) * 50.0 - gap
	var x := -width * 0.5
	for word in words:
		for i in word.length():
			var tile := PanelContainer.new()
			tile.add_theme_stylebox_override("panel", KahveTheme.tile_style("normal"))
			tile.custom_minimum_size = size
			tile.size = size
			tile.position = Vector2(x, -size.y * 0.5 - 120.0)
			tile.pivot_offset = size * 0.5
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var letter := Label.new()
			letter.text = word[i]
			letter.add_theme_font_override("font", KahveTheme.font("sign"))
			letter.add_theme_font_size_override("font_size", 84)
			letter.add_theme_color_override("font_color", KahveTheme.SUIT_RED if i % 2 == 0 else KahveTheme.INK)
			letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tile.add_child(letter)
			tile.modulate.a = 0.0
			_title.add_child(tile)
			_letters.append(tile)
			x += size.x + gap
		x += 50.0
	_tagline.text = TAGLINE
	_tagline.add_theme_font_override("font", KahveTheme.font("script"))
	_tagline.add_theme_font_size_override("font_size", 58)
	_tagline.add_theme_color_override("font_color", KahveTheme.CREAM_LIGHT)
	_tagline.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_tagline.add_theme_constant_override("outline_size", 10)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tagline.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tagline.position = Vector2(-700, 10)
	_tagline.size = Vector2(1400, 80)
	_tagline.modulate.a = 0.0
	_title.add_child(_tagline)


func _start() -> void:
	if fade:
		fade.cover()
	Sfx.ui("door_open", -6.0)
	if door_hinge:
		var swing := door_hinge.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		swing.tween_property(door_hinge, "rotation:y", DOOR_OPEN, 1.4)
	if fade:
		fade.lighten(2.2)
	var hint := _skip.create_tween()
	hint.tween_interval(1.5)
	hint.tween_property(_skip, "modulate:a", 0.8, 0.8)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if camera:
		camera.global_transform = _pose(_time)
	if _time >= 3.6 and not _door_closed:
		_close_door()
	if _time >= 5.0 and not _title_shown:
		_show_title()
	if _time >= 11.5 and not _title_lifted:
		_lift_title()
	if _time >= DURATION:
		_finish()


func _input(event: InputEvent) -> void:
	if _done or _skipping:
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if (key and key.pressed and not key.echo) or (button and button.pressed):
		get_viewport().set_input_as_handled()
		skip()


## Jumps to the end: a quick cut to black, the camera in the menu's pose, the picture back.
func skip() -> void:
	if _done or _skipping:
		return
	_skipping = true
	if fade and not Fade.instant:
		await fade.darken(0.3)
	_finish()
	if fade:
		fade.lighten(0.6)


# The door falls shut behind us as we turn to the room.
func _close_door() -> void:
	_door_closed = true
	Sfx.ui("door_close", -8.0)
	if door_hinge:
		var swing := door_hinge.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		swing.tween_property(door_hinge, "rotation:y", 0.0, 0.8)


func _finish() -> void:
	if _done:
		return
	_done = true
	if camera:
		camera.global_transform = _pose(DURATION)
	if door_hinge:
		door_hinge.rotation.y = 0.0
	finished.emit()
	queue_free()


# --- The shot ---------------------------------------------------------------------------------------------------

## The camera at `time` seconds into the intro: a smooth curve through PATH, slow at both ends, with a little sway
## as of someone walking.
func _pose(time: float) -> Transform3D:
	var u := clampf(time / DURATION, 0.0, 1.0)
	u = smoothstep(0.0, 1.0, u) * 0.85 + u * 0.15 # eased, but never quite still
	var at := _spline(0, u)
	var look := _spline(1, u)
	var sway := sin(time * 1.7) * 0.012 * sin(PI * u)
	at += Vector3(sway, absf(sin(time * 3.4)) * 0.006 * sin(PI * u), 0.0)
	var forward := look - at
	if forward.length() < 0.001:
		forward = Vector3.FORWARD
	return Transform3D(Basis.looking_at(forward, Vector3.UP), at)


# Catmull-Rom through the points of the path (`which` 0: positions, 1: looks), u in 0..1.
func _spline(which: int, u: float) -> Vector3:
	var n := _path.size()
	var f := u * (n - 1)
	var i := clampi(int(floor(f)), 0, n - 2)
	var t := f - i
	var p0: Vector3 = _path[maxi(i - 1, 0)][which]
	var p1: Vector3 = _path[i][which]
	var p2: Vector3 = _path[i + 1][which]
	var p3: Vector3 = _path[mini(i + 2, n - 1)][which]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


# The name of the game: each letter tile drops onto the picture with a click, then the line under it writes in.
func _show_title() -> void:
	_title_shown = true
	for i in _letters.size():
		var tile := _letters[i]
		tile.scale = Vector2(1.6, 1.6)
		var drop := tile.create_tween()
		drop.tween_interval(0.09 * i)
		drop.tween_callback(func() -> void: Sfx.ui("tile_rack", -9.0))
		drop.tween_property(tile, "modulate:a", 1.0, 0.08)
		drop.parallel().tween_property(tile, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop.parallel().tween_property(tile, "rotation", randf_range(-0.03, 0.03), 0.22)
	var line := _tagline.create_tween()
	line.tween_interval(0.09 * _letters.size() + 0.4)
	line.tween_property(_tagline, "modulate:a", 1.0, 0.9)


func _lift_title() -> void:
	_title_lifted = true
	var lift := _title.create_tween().set_parallel()
	lift.tween_property(_title, "modulate:a", 0.0, 1.0)
	lift.tween_property(_title, "position:y", -40.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_skip.create_tween().tween_property(_skip, "modulate:a", 0.0, 0.5)
	for bar in _bars:
		var tween := bar.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(bar, "custom_minimum_size:y", 0.0, 1.6)
		tween.parallel().tween_property(bar, "offset_bottom" if bar == _bars[0] else "offset_top", 0.0, 1.6)


func title_visible() -> bool:
	return _title_shown and not _title_lifted


func is_running() -> bool:
	return not _done
