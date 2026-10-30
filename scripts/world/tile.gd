class_name Tile
extends RigidBody3D
## One okey tile: a Jolt physics body with its mesh in `face`. Frozen (kinematic) while it sits on a rack,
## in a hand or in the draw pile, so it only moves where code puts it; loose on the felt it is free to fall,
## bounce, slide and be pushed by hands. value = Vector2i(color, number); holder is the Rack or Table it sits on
## (null while carried). `id` ties it to the rules (OkeyTiles).

const SLIDE_TIME := 0.18
const MASS := 0.012 # about 12 g of bakelite

static var _shape: BoxShape3D
static var _surface: PhysicsMaterial

var value: Vector2i
## Which of the 106 tiles this is (OkeyTiles), -1 for tiles made from a bare value.
var id := -1
var holder: Node
var selected := false
var face := MeshInstance3D.new()

var _tween: Tween


func _init() -> void:
	if _shape == null:
		_shape = BoxShape3D.new()
		_shape.size = TileFactory.SIZE
		_surface = PhysicsMaterial.new()
		_surface.friction = 0.55
		_surface.bounce = 0.12
	mass = MASS
	physics_material_override = _surface
	continuous_cd = true
	collision_layer = Colliders.TILES
	collision_mask = Colliders.STATIC | Colliders.TILES | Colliders.PROPS | Colliders.HANDS
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var shape := CollisionShape3D.new()
	shape.shape = _shape
	add_child(shape)
	add_child(face)


## Glides to a transform in the parent's space (pins the tile first).
func slide_to(target: Transform3D, time := SLIDE_TIME) -> void:
	pin()
	stop_sliding()
	var start := transform
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void: transform = start.interpolate_with(target, t), 0.0, 1.0, time)


func stop_sliding() -> void:
	if _tween:
		_tween.kill()
		_tween = null


## Freezes the tile so only code moves it (rack, hand, pile).
func pin() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## Lets physics take over: the tile drops with `velocity` and settles wherever it lands.
func set_loose(velocity := Vector3.ZERO) -> void:
	stop_sliding()
	freeze = false
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO
	sleeping = false


## Hover glow on the tile (drawn by tile.gdshader).
func set_highlight(on: bool) -> void:
	face.set_instance_shader_parameter("highlight", 1.0 if on else 0.0)


## Blue rim for a tile picked to be moved with the others (Ctrl+click).
func set_selected(on: bool) -> void:
	selected = on
	face.set_instance_shader_parameter("selected", 1.0 if on else 0.0)
