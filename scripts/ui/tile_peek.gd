class_name TilePeek
extends Node3D
## A floating card that shows a far-away tile up close: the tile's own face (from the tile atlas) on a dark rounded
## plate with a soft shadow and a little pointer down to the tile. Same size on screen however far the tile is;
## fades in and out. Drawn on top of everything so the table or a rack never hides it.

const ATLAS := preload("res://assets/textures/tiles/tile_albedo.png")
const COLUMNS := 8
const CELL := Vector2(200, 292)
const PIXEL := 0.0005 # world size of one atlas pixel at fixed screen size
const FADE := 0.12
const RISE := 0.035 # card bottom above the tile's top

var _face := Sprite3D.new()
var _plate := Sprite3D.new()
var _shadow := Sprite3D.new()
var _pointer := Sprite3D.new()
var _atlas := AtlasTexture.new()
var _shown: Tile
var _alpha := 0.0
var _target := 0.0


func _ready() -> void:
	_atlas.atlas = ATLAS
	_face.texture = _atlas
	var plate_size := Vector2i(CELL) + Vector2i(36, 36)
	_plate.texture = _rounded(plate_size, 26, Color(0.1, 0.07, 0.05, 0.92), 0.0)
	_shadow.texture = _rounded(plate_size + Vector2i(40, 40), 46, Color(0, 0, 0, 0.55), 18.0)
	_pointer.texture = _triangle(Vector2i(44, 26), Color(0.1, 0.07, 0.05, 0.92))
	var order := 0
	for sprite: Sprite3D in [_shadow, _plate, _pointer, _face]:
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.fixed_size = true
		sprite.no_depth_test = true
		sprite.shaded = false
		sprite.pixel_size = PIXEL
		sprite.render_priority = 20 + order
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		order += 1
		add_child(sprite)
	# Stack the card upward from this node's origin (which sits just above the tile).
	_face.offset = Vector2(0, CELL.y * 0.5 + 18 + 26)
	_plate.offset = _face.offset
	_shadow.offset = _face.offset + Vector2(4, -6)
	_pointer.offset = Vector2(0, 13)
	visible = false


## Shows `tile` (or hides the card when null).
func show_tile(tile: Tile) -> void:
	if tile != null:
		_shown = tile
		var cell := TileFactory.cell(tile.value)
		_atlas.region = Rect2(Vector2(cell % COLUMNS, cell / COLUMNS) * CELL, CELL)
	_target = 1.0 if tile != null else 0.0


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, _target, delta / FADE)
	visible = _alpha > 0.0 and is_instance_valid(_shown)
	if not visible:
		return
	global_position = _shown.global_position + Vector3.UP * (TileFactory.SIZE.y * 0.5 + RISE)
	var pop := 0.85 + 0.15 * _alpha
	scale = Vector3.ONE * pop
	for sprite: Sprite3D in [_shadow, _plate, _pointer, _face]:
		sprite.modulate.a = _alpha


static func _rounded(size: Vector2i, radius: int, color: Color, blur: float) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var inner := Vector2(size) * 0.5 - Vector2(radius + blur, radius + blur)
	for y in size.y:
		for x in size.x:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(size) * 0.5).abs()
			var d := (p - inner).max(Vector2.ZERO).length() - radius
			var a := clampf(0.5 - d / maxf(blur, 1.0), 0.0, 1.0) if blur > 0.0 else clampf(0.5 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(color, color.a * a))
	return ImageTexture.create_from_image(image)


static func _triangle(size: Vector2i, color: Color) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var half := size.x * 0.5 * float(y + 1) / size.y
		for x in size.x:
			var a := clampf(half - absf(x + 0.5 - size.x * 0.5), 0.0, 1.0)
			image.set_pixel(x, size.y - 1 - y, Color(color, color.a * a))
	return ImageTexture.create_from_image(image)
