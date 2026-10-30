class_name Nameplate
extends Node3D
## The name plate over a dayı's head: a small enamel sign with his name and a stripe in his tile colour (the score lives
## in the score sign, once). It faces the camera, keeps about the same size on screen whatever his distance, and lights
## up (green sign, brass name, a little lift) while it is his turn. It only shows while you look at him (`look`).
## The sign is an ordinary Control drawn in a SubViewport and shown on a Sprite3D, so it reads like the HUD's own.

const SIZE := Vector2i(340, 76)
## Metres of camera distance per unit of scale: the plate grows with distance so it stays about as big on screen.
const DISTANCE_PER_SCALE := 1.4

var _viewport := SubViewport.new()
var _sprite := Sprite3D.new()
var _panel := PanelContainer.new()
var _stripe := ColorRect.new()
var _name := Label.new()
var _turn := false
## Fades in while the player looks at this dayi, out when he looks away.
var looked_at := false
var _fade := 0.0
var _signature := ""
var _time := randf() * 6.0


func _init() -> void:
	_viewport.size = SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)

	var root := Control.new()
	root.theme = KahveTheme.theme()
	root.size = Vector2(SIZE)
	_viewport.add_child(root)
	_panel.size = Vector2(SIZE)
	_panel.add_theme_stylebox_override("panel", KahveTheme.sign_style("dark", true))
	root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)
	_stripe.custom_minimum_size = Vector2(10, 0)
	row.add_child(_stripe)
	_name.add_theme_font_override("font", KahveTheme.font("ui_bold"))
	_name.add_theme_font_size_override("font_size", 30)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	row.add_child(_name)

	_sprite.texture = _viewport.get_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = 0.00085
	_sprite.shaded = false
	_sprite.no_depth_test = true
	_sprite.double_sided = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.render_priority = 4
	add_child(_sprite)


func _process(delta: float) -> void:
	_time += delta
	_fade = move_toward(_fade, 1.0 if looked_at else 0.0, delta * (6.0 if looked_at else 3.0))
	_sprite.visible = _fade > 0.01
	_sprite.modulate.a = _fade
	var lift := 0.0
	var grow := 1.0
	if _turn:
		lift = 0.035 + sin(_time * 3.0) * 0.012
		grow = 1.06
	_sprite.position.y = lerpf(_sprite.position.y, lift, 1.0 - exp(-8.0 * delta))
	var camera := get_viewport().get_camera_3d()
	if camera:
		grow *= clampf(camera.global_position.distance_to(global_position) / DISTANCE_PER_SCALE, 0.35, 2.5)
	_sprite.scale = _sprite.scale.lerp(Vector3.ONE * grow, 1.0 - exp(-8.0 * delta))


## What the plate says. Only redraws when something changed.
func set_info(player_name: String, turn: bool, colour: Color) -> void:
	var signature := "%s|%s|%s" % [player_name, turn, colour.to_html()]
	if signature == _signature:
		return
	_signature = signature
	_turn = turn
	_name.text = player_name
	_stripe.color = colour
	_panel.add_theme_stylebox_override("panel", KahveTheme.sign_style("green" if turn else "dark", true))
	_name.add_theme_color_override("font_color", KahveTheme.BRASS_BRIGHT if turn else KahveTheme.CREAM_LIGHT)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func text() -> String:
	return _name.text


func is_shown() -> bool:
	return _fade > 0.01


func is_lit() -> bool:
	return _turn
