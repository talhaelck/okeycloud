extends Node3D
## The kahvehane at night: tiled floor, wood-panelled walls under smoke-yellowed plaster, a hanging lamp over
## our table, a couple of background tables with regulars, shelves, an old TV and dim wall sconces.
## Props are CC0 Poly Haven models (assets/polyhaven); everything is placed relative to our table at the origin.

const WIDTH := 8.0 # along X
const DEPTH := 7.5 # along Z
const HEIGHT := 3.0
const PANEL := 1.1 # height of the wooden wainscot
const WALL := 0.06
const TEA_TABLE_TOP := 0.757 # round_wooden_table_01 at 0.75 scale
const SHELF_TOP := 0.884 # painted_wooden_shelves at 1.2 scale: the ledge on top
const SHELF_LOW := 0.235 # ... and the open shelf below it
const LAMP_WARM := Color(1.0, 0.82, 0.62)

var _fan: Node3D
var _regulars: Array = [] # Regular kinds still to seat, each once
var ambience := Ambience.new()
## The street door's hinge (Decor.door): Visitors swing it open.
var door_hinge: Node3D


func _ready() -> void:
	add_child(ambience)
	_regulars = Regular.KINDS.duplicate()
	_regulars.shuffle()
	_build_shell()
	_hanging_lamp(Vector3(0, HEIGHT, 0), 9.0, true)
	_background_table(Vector3(-2.7, 0, -2.2), 0.4)
	_background_table(Vector3(2.8, 0, -2.0), -0.3)
	_background_table(Vector3(-2.6, 0, 2.4), 0.9)
	_props()
	_air()
	_sounds()
	var visitors := Visitors.new()
	visitors.door_hinge = door_hinge
	visitors.ambience = ambience
	add_child(visitors)
	visitors.start()


func _process(delta: float) -> void:
	if _fan:
		_fan.rotate_y(delta * 2.5)


func _build_shell() -> void:
	var floor_mat := Mat.textured("brown_floor_tiles", 1.0)
	var plaster := Mat.textured("yellow_plaster_02", 2.0, Color(0.95, 0.85, 0.7))
	var panel := Mat.textured("dark_paneled_wood", 1.2)
	var ceiling := Mat.textured("plastered_wall", 2.0, Color(0.55, 0.5, 0.45))
	Mat.part(self, BoxMesh.new(), floor_mat, Vector3(0, -0.05, 0)).scale = Vector3(WIDTH, 0.1, DEPTH)
	Colliders.box(Colliders.static_body(self), Vector3(WIDTH, 0.1, DEPTH), Transform3D(Basis(), Vector3(0, -0.05, 0)))
	Mat.part(self, BoxMesh.new(), ceiling, Vector3(0, HEIGHT + 0.05, 0)).scale = Vector3(WIDTH, 0.1, DEPTH)
	# Four walls: [centre, length, facing yaw].
	for wall in [[Vector3(0, 0, -DEPTH / 2), WIDTH, 0.0], [Vector3(0, 0, DEPTH / 2), WIDTH, PI],
			[Vector3(-WIDTH / 2, 0, 0), DEPTH, PI / 2], [Vector3(WIDTH / 2, 0, 0), DEPTH, -PI / 2]]:
		var pivot := Node3D.new()
		pivot.position = wall[0]
		pivot.rotation.y = wall[2]
		add_child(pivot)
		var length: float = wall[1]
		Mat.part(pivot, BoxMesh.new(), plaster, Vector3(0, HEIGHT / 2, 0)).scale = Vector3(length, HEIGHT, WALL)
		Mat.part(pivot, BoxMesh.new(), panel, Vector3(0, PANEL / 2, WALL)).scale = Vector3(length, PANEL, 0.03)
		Mat.part(pivot, BoxMesh.new(), Mat.textured("dark_paneled_wood", 1.2, Color(0.6, 0.5, 0.45)),
			Vector3(0, PANEL, WALL + 0.02)).scale = Vector3(length, 0.05, 0.06)


## Industrial pendant with a warm spot cone that also lights the smoke in the air.
func _hanging_lamp(at: Vector3, energy: float, main := false) -> void:
	Mat.model(self, "hanging_industrial_lamp", at)
	var bulb := at + Vector3(0, -1.2, 0)
	var spot := SpotLight3D.new()
	spot.position = bulb
	spot.rotation.x = -PI / 2
	spot.light_color = LAMP_WARM
	spot.light_energy = energy
	spot.spot_range = 4.0
	spot.spot_angle = 55.0
	spot.spot_angle_attenuation = 0.8
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 1.5 if main else 0.8
	add_child(spot)
	var glow := OmniLight3D.new()
	glow.position = bulb + Vector3(0, 0.15, 0)
	glow.light_color = LAMP_WARM
	glow.light_energy = energy * 0.08
	glow.omni_range = 3.5
	add_child(glow)


## A round table with regulars around it, under its own lamp.
func _background_table(at: Vector3, yaw: float) -> void:
	var table := Node3D.new()
	table.position = at
	table.rotation.y = yaw
	add_child(table)
	ambience.loop("murmur_loop", at + Vector3(0, 1.1, 0), -8.0, 2.5)
	ambience.add_spot("spoon", at + Vector3(0, TEA_TABLE_TOP, 0))
	ambience.add_spot("dice", at + Vector3(0, TEA_TABLE_TOP, 0))
	Mat.model(table, "round_wooden_table_01", Vector3.ZERO, 0.0, 0.75)
	for i in 3:
		var angle := i * TAU / 3.0 + 0.3
		var dir := Vector3(sin(angle), 0, cos(angle))
		var seat_pos := dir * 0.85
		Mat.model(table, "plastic_monobloc_chair_01", seat_pos, angle + PI)
		if i < 2:
			# His glass at his elbow, out of the way of the tavla board between the two.
			var glass_at := dir.rotated(Vector3.UP, -0.9 if i == 0 else 0.9) * 0.42 + Vector3(0, TEA_TABLE_TOP, 0)
			Mat.meshy(table, "cay_bardagi", glass_at, randf() * TAU)
			Atmosphere.steam(table, glass_at + Vector3(0, 0.1, 0))
			if _regulars.is_empty(): # more seats than regulars: some come twice, across the room
				_regulars = Regular.KINDS.duplicate()
				_regulars.shuffle()
			var regular := Regular.new()
			regular.position = seat_pos + Vector3(0, Seat.SEAT_TOP - 0.03, 0) - dir * 0.04
			regular.rotation.y = angle
			table.add_child(regular)
			regular.setup(_regulars.pop_back())
	# The two of them play tavla between them; the ashtray goes to the free side.
	var between := (Vector3(sin(0.3), 0, cos(0.3)) + Vector3(sin(0.3 + TAU / 3.0), 0, cos(0.3 + TAU / 3.0))).normalized()
	Decor.tavla(table, between * 0.08 + Vector3(0, TEA_TABLE_TOP - 0.004, 0), atan2(between.x, between.z) + PI * 0.5)
	Mat.meshy(table, "kulluk", Vector3(0, TEA_TABLE_TOP, 0) - between * 0.38, randf() * TAU)
	Atmosphere.smoke(table, Vector3(0, TEA_TABLE_TOP + 0.03, 0) - between * 0.38)
	_hanging_lamp(Vector3(at.x, HEIGHT, at.z), 3.0)


func _props() -> void:
	var back := -DEPTH / 2 + WALL / 2 + 0.03
	var left := -WIDTH / 2 + WALL / 2 + 0.03
	var right := WIDTH / 2 - WALL / 2 - 0.03

	# Shelves along the left wall with a few things on top.
	for z in [-0.6, 0.0]:
		var shelf := Mat.model(self, "painted_wooden_shelves", Vector3(left + 0.02, 0, z), PI / 2)
		shelf.scale = Vector3.ONE * 1.2
	# Their top ledge (0.88 m) is only a hand deep in front of a raised back board; the open shelf below is 0.24 m.
	# Measured with tests/floating_props_test.gd: on 1.36 m everything stood in the air.
	var ledge := left + 0.22 # the middle of the ledge strip
	Mat.model(self, "jug_01", Vector3(ledge + 0.02, SHELF_TOP, -0.74), PI / 2)
	Mat.model(self, "mantel_clock_01", Vector3(ledge, SHELF_TOP, -0.42), PI / 2, 1.1)
	Mat.prop(self, "semaver", Vector3(ledge, SHELF_TOP, -0.08), PI / 2)
	Mat.meshy(self, "cay_bardagi", Vector3(ledge, SHELF_TOP, 0.16), randf() * TAU)
	for i in 3:
		Mat.meshy(self, "cay_bardagi", Vector3(left + 0.5, SHELF_LOW, -0.16 + i * 0.16), randf() * TAU)

	# Old TV up on a bracket in the back-right corner, its screen glow flickering on the wall.
	var tv_at := Vector3(right - 0.45, 1.85, back + 0.45)
	Mat.part(self, BoxMesh.new(), Mat.textured("dark_paneled_wood", 1.0), tv_at - Vector3(0, 0.03, 0)).scale = Vector3(0.75, 0.05, 0.6)
	Decor.tv_screen(Mat.model(self, "Television_01", tv_at, -PI / 4))
	var screen := OmniLight3D.new()
	screen.position = tv_at + Vector3(-0.35, 0.25, 0.35)
	screen.light_color = Color(0.55, 0.7, 1.0)
	screen.light_energy = 0.9
	screen.omni_range = 2.5
	screen.set_script(preload("res://scripts/world/flicker.gd"))
	add_child(screen)

	# The back wall looks out on the street: two windows with the clock and the calendar between them.
	for i in 2:
		Decor.window(self, Vector3(-1.2 + i * 2.4, 1.78, back), 0.0, Vector2(0.95, 1.15), float(i) * 3.7)
	Mat.model(self, "wall_clock", Vector3(0, 2.05, back)).set_meta("hung", true)
	Decor.calendar(self, Vector3(0, 1.5, back), 0.0)
	# Old photographs on the side walls.
	Decor.photo(self, Vector3(left, 2.05, -0.3), PI / 2, "vapur", 0.62)
	Decor.photo(self, Vector3(left, 1.85, -1.75), PI / 2, "sokak", 0.5)
	Decor.photo(self, Vector3(right, 2.0, 0.6), -PI / 2, "takim", 0.6)
	# The çay ocağı along the right wall, stools in front; the stove by the left wall; beams overhead.
	Decor.tea_counter(self, Vector3(right - 0.3, 0, 0.6), -PI / 2, 2.0)
	_hanging_lamp(Vector3(right - 0.6, HEIGHT, 0.2), 3.5)
	for z in [0.15, 1.05]:
		Mat.model(self, "wooden_stool_01", Vector3(right - 1.0, 0, z), randf() * TAU)
	Mat.model(self, "metal_trash_can", Vector3(right - 0.35, 0, 2.0), 0.3, 0.75)
	Decor.stove(self, Vector3(left + 0.45, 0, 1.0), PI / 2, HEIGHT)
	Decor.cat(self, Vector3(left + 0.95, 0, 0.5), 2.2)
	Decor.beams(self, WIDTH, HEIGHT, [-2.6, -1.3, 1.3, 2.6])
	Decor.price_list(self, Vector3(right, 1.75, 1.35), -PI / 2)

	# The front wall, behind seat 0 and in everyone else's view: the street door with the coat rack and notice board
	# beside it, a glass cabinet and a bookshelf, a plant in the corner, its own sconces.
	var front := DEPTH / 2 - WALL / 2 - 0.03
	door_hinge = Decor.door(self, Vector3(1.3, 0, front - 0.07), PI, 7.1) # in front of the wainscot
	Decor.coat_rack(self, Vector3(2.5, 1.75, front), PI)
	Decor.notice_board(self, Vector3(0.0, 1.55, front), PI)
	_hanging_lamp(Vector3(0.6, HEIGHT, front - 1.0), 3.0)
	Mat.model(self, "vintage_cabinet_01", Vector3(-1.3, 0.34 * 0.8, front - 0.28 * 0.8), PI, 0.8)
	Mat.model(self, "wooden_bookshelf_worn", Vector3(-3.2, 0, front - 0.3), 0.0)
	Mat.model(self, "potted_plant_02", Vector3(3.4, 0, front - 0.4))
	Mat.model(self, "metal_jerrycan", Vector3(right - 0.15, 0, 1.75), -PI / 2)
	for x in [-2.2, 2.9]:
		Mat.model(self, "industrial_wall_sconce", Vector3(x, 1.6, front), PI).set_meta("hung", true)
		_sconce_light(Vector3(x, 1.75, front - 0.2))
	for x in [-2.6, 2.4]:
		Mat.model(self, "industrial_wall_sconce", Vector3(x, 1.6, back)).set_meta("hung", true)
		_sconce_light(Vector3(x, 1.75, back + 0.2))
	for z in [-2.2, 2.2]:
		Mat.model(self, "industrial_wall_sconce", Vector3(right, 1.6, z), -PI / 2).set_meta("hung", true)
		_sconce_light(Vector3(right - 0.2, 1.75, z))

	Mat.model(self, "potted_plant_01", Vector3(left + 0.45, 0, back + 0.45))
	_fan = Mat.model(self, "ceiling_fan", Vector3(2.4, HEIGHT, 1.8))
	_fan.set_meta("hung", true)


# Old smoke hanging under the ceiling, thickest over the tables, and dust drifting through our lamp's light.
func _air() -> void:
	Atmosphere.dust(self, Vector3(0, 1.3, 0), Vector3(1.6, 1.1, 1.6))


# Rain on the windows and the door, the stove, the clock and the match on the TV; spoons at the tea counter.
func _sounds() -> void:
	var back := -DEPTH / 2 + WALL / 2 + 0.03
	var left := -WIDTH / 2 + WALL / 2 + 0.03
	var right := WIDTH / 2 - WALL / 2 - 0.03
	var front := DEPTH / 2 - WALL / 2 - 0.03
	for at in [Vector3(-1.2, 1.78, back), Vector3(1.2, 1.78, back), Vector3(1.3, 1.6, front)]:
		ambience.loop("rain_loop", at, -10.0, 2.0)
	ambience.loop("stove_loop", Vector3(left + 0.45, 0.5, 1.0), -6.0, 1.5)
	ambience.loop("clock_loop", Vector3(0, 2.05, back), -16.0, 1.5)
	ambience.loop("tv_crowd_loop", Vector3(right - 0.45, 2.0, back + 0.45), -10.0, 2.5)
	ambience.add_spot("spoon", Vector3(right - 0.3, 0.95, 0.6))
	ambience.start()


func _sconce_light(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = LAMP_WARM
	light.light_energy = 0.7
	light.omni_range = 2.2
	add_child(light)
