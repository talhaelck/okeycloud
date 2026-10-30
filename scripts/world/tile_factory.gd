class_name TileFactory
## Builds okey tiles. A tile is Vector2i(color, number); color 4 is the fake okey.
## The printed face points along the tile's local +Z, upright along +Y.
## Mesh from tools/blender/tiles.py, faces from the atlas made by tools/tile_atlas.py, drawn by shaders/tile.gdshader.

const SIZE := Vector3(0.048, 0.07, 0.019)
const FAKE_OKEY := 4
const COLORS := 4
const NUMBERS := 13
const BLANK_CELL := 53
const MESH_SCENE := preload("res://assets/models/tiles/tile.glb")
const SHADER := preload("res://shaders/tile.gdshader")

static var _mesh: Mesh
static var _material: ShaderMaterial


## Atlas cell of a tile value (must match the layout in tools/tile_atlas.py).
static func cell(tile: Vector2i) -> int:
	return NUMBERS * COLORS if tile.x == FAKE_OKEY else tile.x * NUMBERS + tile.y - 1


static func create(tile: Vector2i) -> Tile:
	_load()
	var mi := Tile.new()
	mi.value = tile
	mi.add_to_group("tiles")
	mi.face.mesh = _mesh
	mi.face.material_override = _material
	mi.face.set_instance_shader_parameter("cell", float(cell(tile)))
	return mi


## One of the 106 tiles of the set (OkeyTiles ids).
static func of_id(id: int) -> Tile:
	var tile := create(OkeyTiles.value(id))
	tile.id = id
	return tile


## A tile-shaped mesh with a blank face and no body: decoration (the face-down tiles under the top of the pile).
static func blank() -> MeshInstance3D:
	_load()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _material
	mi.set_instance_shader_parameter("cell", float(BLANK_CELL))
	return mi


static func _load() -> void:
	if _mesh:
		return
	var scene: Node = MESH_SCENE.instantiate()
	_mesh = (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("atlas_albedo", load("res://assets/textures/tiles/tile_albedo.png"))
	_material.set_shader_parameter("atlas_normal", load("res://assets/textures/tiles/tile_normal.png"))
