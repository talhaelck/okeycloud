class_name Decor
## Kahvehane set dressing built around Poly Haven props: rainy night windows, the wood stove, the tea counter (çay
## ocağı), a match on the TV, old photographs, a tear-off calendar and the ceiling beams.
## Every builder takes a point and a yaw in its parent's space; "front" is the side facing +Z before the yaw.

const WINDOW_SHADER := preload("res://shaders/night_window.gdshader")
const TV_SHADER := preload("res://shaders/tv_match.gdshader")
const MONTHS := ["OCAK", "ŞUBAT", "MART", "NİSAN", "MAYIS", "HAZİRAN", "TEMMUZ", "AĞUSTOS", "EYLÜL", "EKİM", "KASIM", "ARALIK"]


## A window onto the rainy street at night, in a wooden frame with a sill; cold street light falls in through it.
static func window(parent: Node3D, pos: Vector3, yaw: float, size: Vector2, seed: float) -> void:
	var root := _root(parent, pos, yaw)
	root.set_meta("hung", true) # on a wall, not standing on anything
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	var view := ShaderMaterial.new()
	view.shader = WINDOW_SHADER
	view.set_shader_parameter("seed", seed)
	quad.material = view
	glass.mesh = quad
	glass.position = Vector3(0, 0, 0.004)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glass)
	var wood := Mat.textured("dark_paneled_wood", 0.6, Color(0.5, 0.36, 0.28))
	var t := 0.07
	for y in [-1.0, 1.0]:
		_box(root, wood, Vector3(0, y * (size.y + t) * 0.5, 0.03), Vector3(size.x + t * 2.0, t, 0.08))
	for x in [-1.0, 1.0]:
		_box(root, wood, Vector3(x * (size.x + t) * 0.5, 0, 0.03), Vector3(t, size.y, 0.08))
	_box(root, wood, Vector3(0, 0, 0.025), Vector3(0.04, size.y, 0.05))
	_box(root, wood, Vector3(0, size.y * 0.18, 0.025), Vector3(size.x, 0.04, 0.05))
	_box(root, wood, Vector3(0, -size.y * 0.5 - t - 0.02, 0.09), Vector3(size.x + 0.3, 0.04, 0.2))
	var light := SpotLight3D.new()
	light.position = Vector3(0, size.y * 0.35, 0.25)
	light.basis = Basis.looking_at(Vector3(0, -0.9, 1.0))
	light.light_color = Color(0.5, 0.62, 1.0)
	light.light_energy = 1.4
	light.spot_range = 4.0
	light.spot_angle = 45.0
	light.light_volumetric_fog_energy = 0.8
	root.add_child(light)


## The old TV's screen showing a match (`tv` is the Television_01 model; its screen faces +Z).
static func tv_screen(tv: Node3D) -> void:
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.31)
	var match_view := ShaderMaterial.new()
	match_view.shader = TV_SHADER
	quad.material = match_view
	screen.mesh = quad
	screen.position = Vector3(-0.02, 0.255, 0.215)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tv.add_child(screen)


## The cast-iron stove with its flue going up and into the wall, a fire glowing inside.
static func stove(parent: Node3D, pos: Vector3, yaw: float, ceiling: float) -> void:
	var root := _root(parent, pos, yaw)
	Mat.model(root, "barrel_stove", Vector3.ZERO)
	var iron := Mat.material(Color(0.08, 0.075, 0.07), 0.55)
	var top := 0.86
	var bend := ceiling - 0.45
	var flue := Mat.part(root, Mat.cylinder(0.065, bend - top), iron, Vector3(0, (top + bend) * 0.5, 0))
	flue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var across := Mat.part(root, Mat.cylinder(0.065, 0.45), iron, Vector3(0, bend, -0.22))
	across.rotation.x = PI * 0.5
	var fire := OmniLight3D.new()
	fire.position = Vector3(0, 0.35, 0.4)
	fire.light_color = Color(1.0, 0.5, 0.18)
	fire.light_energy = 1.6
	fire.omni_range = 2.8
	fire.light_volumetric_fog_energy = 0.6
	fire.set_script(preload("res://scripts/world/fire_light.gd"))
	root.add_child(fire)
	var embers := Mat.part(root, BoxMesh.new(), Mat.glow(Color(1.0, 0.35, 0.08), 3.0), Vector3(0, 0.3, 0.29))
	embers.scale = Vector3(0.16, 0.08, 0.01)


## The çay ocağı: a long wooden counter with the semaver, a brass tray of tea glasses, the kettle and the radio,
## crates stacked at its end. `length` runs along local X.
static func tea_counter(parent: Node3D, pos: Vector3, yaw: float, length: float) -> void:
	var root := _root(parent, pos, yaw)
	var wood := Mat.textured("dark_paneled_wood", 0.8, Color(0.62, 0.45, 0.34))
	var top := Mat.textured("wood_table_worn", 0.8, Color(0.55, 0.42, 0.33))
	var height := 0.95
	_box(root, wood, Vector3(0, height * 0.5 - 0.02, 0), Vector3(length, height - 0.04, 0.55))
	_box(root, top, Vector3(0, height - 0.02, 0.02), Vector3(length + 0.06, 0.04, 0.64))
	var on := Vector3(0, height, 0)
	Mat.prop(root, "semaver", on + Vector3(-length * 0.32, 0, -0.05), 0.0)
	var brass := Mat.material(Color(0.62, 0.45, 0.2), 0.35)
	brass.metallic = 0.85
	Mat.part(root, Mat.cylinder(0.24, 0.012), brass, on + Vector3(0.05, 0.006, 0.02))
	for i in 6:
		var at := on + Vector3(0.05 + (i % 3 - 1) * 0.15, 0.012, 0.02 + (i / 3 - 0.5) * 0.16)
		Mat.meshy(root, "cay_bardagi", at, randf() * TAU)
		if i % 2 == 0:
			Atmosphere.steam(root, at + Vector3(0, 0.12, 0))
	Mat.model(root, "vintage_electric_kettle", on + Vector3(length * 0.26, 0, -0.08), -0.4)
	Mat.model(root, "vintage_radio_transceiver", on + Vector3(length * 0.38, 0, -0.04), 0.15, 0.75)
	for level in 2:
		var crate := Mat.model(root, "plastic_crate_01", Vector3(length * 0.5 + 0.25, level * 0.26, 0.05), 0.08 * level)
		if level > 0:
			crate.set_meta("rests_on_rim", true) # on the hollow crate below: a floor check sees through it


## An old photograph in a dark wooden frame hung on a wall, a little crooked.
static func photo(parent: Node3D, pos: Vector3, yaw: float, image: String, width: float) -> void:
	var root := _root(parent, pos, yaw)
	root.set_meta("hung", true) # on a wall, not standing on anything
	root.rotation.z = randf_range(-0.035, 0.035)
	var texture: Texture2D = load("res://assets/textures/pictures/%s.jpg" % image)
	var size := Vector2(width, width * texture.get_height() / texture.get_width())
	_box(root, Mat.textured("dark_paneled_wood", 0.4, Color(0.35, 0.24, 0.18)), Vector3(0, 0, 0.012), Vector3(size.x + 0.07, size.y + 0.07, 0.025))
	var print_material := StandardMaterial3D.new()
	print_material.albedo_texture = texture
	print_material.roughness = 0.55
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = print_material
	var picture := MeshInstance3D.new()
	picture.mesh = quad
	picture.position = Vector3(0, 0, 0.026)
	root.add_child(picture)


## A tear-off wall calendar showing today's date.
static func calendar(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var root := _root(parent, pos, yaw)
	root.set_meta("hung", true) # on a wall, not standing on anything
	_box(root, Mat.material(Color(0.88, 0.86, 0.8), 0.9), Vector3(0, 0, 0.008), Vector3(0.2, 0.27, 0.016))
	_box(root, Mat.material(Color(0.62, 0.1, 0.08), 0.8), Vector3(0, 0.105, 0.012), Vector3(0.2, 0.06, 0.02))
	var today := Time.get_date_dict_from_system()
	for line: Array in [[str(today.day), 150, Color(0.08, 0.06, 0.06), -0.01], [MONTHS[today.month - 1], 44, Color(0.95, 0.92, 0.88), 0.105]]:
		var label := Label3D.new()
		label.text = line[0]
		label.font_size = line[1]
		label.modulate = line[2]
		label.outline_size = 0
		label.pixel_size = 0.0006
		label.position = Vector3(0, line[3], 0.024)
		label.double_sided = false
		root.add_child(label)


## Dark wooden beams across the ceiling, at each z in `along`.
static func beams(parent: Node3D, width: float, ceiling: float, along: Array) -> void:
	var wood := Mat.textured("dark_paneled_wood", 0.5, Color(0.38, 0.27, 0.2))
	for z: float in along:
		_box(parent, wood, Vector3(0, ceiling - 0.1, z), Vector3(width, 0.2, 0.18))


## The street door: a wooden frame and a door leaf (glass upper half onto the rainy street, brass handle) hung on a
## hinge at its left edge, a doormat, and cold street light falling in. Returns the hinge: turn it about Y to open
## the door (positive opens it into the room).
static func door(parent: Node3D, pos: Vector3, yaw: float, seed: float) -> Node3D:
	var root := _root(parent, pos, yaw)
	var wood := Mat.textured("wood_table_worn", 0.6, Color(0.8, 0.55, 0.38))
	var size := Vector2(0.95, 2.15)
	for x in [-1.0, 1.0]:
		_box(root, wood, Vector3(x * (size.x * 0.5 + 0.05), size.y * 0.5, 0.03), Vector3(0.1, size.y, 0.1))
	_box(root, wood, Vector3(0, size.y + 0.05, 0.03), Vector3(size.x + 0.2, 0.1, 0.1))
	# Behind the leaf, the street itself, seen when the door stands open.
	var street := MeshInstance3D.new()
	var outside := QuadMesh.new()
	outside.size = size
	var street_view := ShaderMaterial.new()
	street_view.shader = WINDOW_SHADER
	street_view.set_shader_parameter("seed", seed + 1.3)
	outside.material = street_view
	street.mesh = outside
	street.position = Vector3(0, size.y * 0.5, -0.005)
	root.add_child(street)
	var hinge := Node3D.new()
	hinge.position = Vector3(-size.x * 0.5, 0, 0.02)
	root.add_child(hinge)
	var leaf := Vector3(size.x * 0.5, 0, 0) # leaf parts are laid out from the hinge
	_box(hinge, wood, leaf + Vector3(0, size.y * 0.27, 0), Vector3(size.x, size.y * 0.54, 0.05))
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x - 0.16, size.y * 0.4)
	var view := ShaderMaterial.new()
	view.shader = WINDOW_SHADER
	view.set_shader_parameter("seed", seed)
	view.set_shader_parameter("brightness", 0.8)
	quad.material = view
	glass.mesh = quad
	glass.position = leaf + Vector3(0, size.y * 0.75, -0.01)
	hinge.add_child(glass)
	for y in [size.y * 0.54, size.y * 0.97]:
		_box(hinge, wood, leaf + Vector3(0, y, 0.01), Vector3(size.x, 0.08, 0.06))
	for x in [-1.0, 1.0]:
		_box(hinge, wood, leaf + Vector3(x * (size.x * 0.5 - 0.04), size.y * 0.75, 0.01), Vector3(0.08, size.y * 0.44, 0.06))
	_box(hinge, _brass(), leaf + Vector3(size.x * 0.36, 1.0, 0.06), Vector3(0.12, 0.025, 0.04))
	_box(root, Mat.textured("rough_linen", 0.3, Color(0.35, 0.12, 0.1)), Vector3(0, 0.005, 0.45), Vector3(0.8, 0.01, 0.5))
	var light := SpotLight3D.new()
	light.position = Vector3(0, size.y * 0.8, 0.2)
	light.basis = Basis.looking_at(Vector3(0, -1.0, 0.8))
	light.light_color = Color(0.5, 0.62, 1.0)
	light.light_energy = 1.0
	light.spot_range = 3.5
	light.spot_angle = 40.0
	root.add_child(light)
	return hinge


## A wall coat rack: a board with brass hooks, flat caps and an old overcoat hanging from it.
static func coat_rack(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var root := _root(parent, pos, yaw)
	root.set_meta("hung", true) # on a wall, not standing on anything
	_box(root, Mat.textured("dark_paneled_wood", 0.4, Color(0.4, 0.28, 0.2)), Vector3(0, 0, 0.012), Vector3(0.9, 0.1, 0.025))
	var caps := [Color(0.22, 0.2, 0.18), Color(0.3, 0.24, 0.17), Color(0.15, 0.16, 0.2)]
	for i in 4:
		var x := -0.33 + i * 0.22
		var hook := Mat.part(root, Mat.cylinder(0.008, 0.08), _brass(), Vector3(x, 0, 0.06))
		hook.rotation.x = PI * 0.5
		if i == 1:
			# The overcoat: a long draped body with shoulders.
			var coat := Mat.textured("rough_linen", 0.25, Color(0.2, 0.17, 0.14))
			var body := Mat.part(root, Mat.cylinder(0.17, 0.95, 0.2), coat, Vector3(x, -0.5, 0.1))
			body.scale = Vector3(1, 1, 0.45)
			Mat.part(root, Mat.sphere(0.12), coat, Vector3(x, -0.05, 0.1)).scale = Vector3(1.4, 0.6, 0.6)
		else:
			var cap := Mat.textured("rough_linen", 0.15, caps[i % caps.size()])
			var crown := Mat.part(root, Mat.cylinder(0.11, 0.05, 0.1), cap, Vector3(x, -0.04, 0.11))
			crown.rotation.x = PI * 0.5 - 0.35
			var peak := Mat.part(root, Mat.cylinder(0.08, 0.008), cap, Vector3(x, -0.12, 0.15))
			peak.rotation.x = PI * 0.5 - 0.35
			peak.scale = Vector3(1, 1, 0.6)


## A cork notice board with pinned papers: an okey tournament poster, a lost-and-found note and a sign.
static func notice_board(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var root := _root(parent, pos, yaw)
	root.set_meta("hung", true) # on a wall, not standing on anything
	_box(root, Mat.textured("dark_paneled_wood", 0.4, Color(0.35, 0.24, 0.18)), Vector3(0, 0, 0.01), Vector3(0.9, 0.62, 0.02))
	_box(root, Mat.material(Color(0.62, 0.45, 0.3), 0.95), Vector3(0, 0, 0.022), Vector3(0.84, 0.56, 0.01))
	var ink := Color(0.1, 0.1, 0.1)
	var red := Color(0.7, 0.08, 0.06)
	_paper(root, Vector3(-0.17, 0.02, 0.03), Vector2(0.36, 0.48), Color(0.95, 0.88, 0.55), 0.03, [
		["OKEY", 64, red], ["TURNUVASI", 38, red], ["Cumartesi 20.00", 26, ink], ["Birinciye", 24, ink],
		["1 KOLİ ÇAY", 34, Color(0.05, 0.3, 0.1)], ["Masa başı 4 kişi", 18, ink]])
	_paper(root, Vector3(0.23, 0.1, 0.03), Vector2(0.26, 0.3), Color(0.96, 0.95, 0.92), -0.05, [
		["KAYIP", 40, ink], ["Kehribar tespih", 22, ink], ["Bulan Hüseyin", 20, ink], ["Abiye versin", 20, ink]])
	_paper(root, Vector3(0.24, -0.17, 0.03), Vector2(0.2, 0.14), Color(0.92, 0.92, 0.88), 0.08, [
		["VERESİYE", 22, Color(0.5, 0.05, 0.05)], ["YOKTUR", 22, Color(0.5, 0.05, 0.05)]])


## The chalkboard price list over the tea counter.
static func price_list(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var root := _root(parent, pos, yaw)
	root.set_meta("hung", true) # on a wall, not standing on anything
	_box(root, Mat.textured("dark_paneled_wood", 0.4, Color(0.4, 0.28, 0.2)), Vector3(0, 0, 0.006), Vector3(0.66, 0.51, 0.012))
	_box(root, Mat.material(Color(0.08, 0.12, 0.09), 0.85), Vector3(0, 0, 0.014), Vector3(0.6, 0.45, 0.01))
	var chalk := Color(0.92, 0.92, 0.86)
	_text_lines(root, [["FİYAT LİSTESİ", 34, Color(0.95, 0.85, 0.4)], ["Çay ............ 15", 26, chalk],
		["Oralet ......... 15", 26, chalk], ["Türk Kahvesi ... 40", 26, chalk], ["Gazoz .......... 30", 26, chalk],
		["Okey (saat) .... 20", 26, chalk]], Vector3(0, 0.16, 0.021), 0.065)


## An open tavla board with its checkers set up, for a background table (board centre at the origin).
static func tavla(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var root := _root(parent, pos, yaw)
	var wood := Mat.textured("wood_table_worn", 0.3, Color(0.75, 0.5, 0.3))
	_box(root, wood, Vector3(0, 0.012, 0), Vector3(0.5, 0.024, 0.38))
	_box(root, Mat.material(Color(0.2, 0.12, 0.07), 0.8), Vector3(0, 0.025, 0), Vector3(0.46, 0.004, 0.34))
	_box(root, wood, Vector3(0, 0.03, 0), Vector3(0.02, 0.012, 0.38))
	var points := [Mat.material(Color(0.85, 0.75, 0.55), 0.7), Mat.material(Color(0.45, 0.12, 0.08), 0.7)]
	for i in 24:
		var side := 1.0 if i < 12 else -1.0
		_box(root, points[i % 2], Vector3(_point_x(i), 0.0275, side * 0.1), Vector3(0.026, 0.001, 0.13))
	var checkers := [Mat.material(Color(0.92, 0.9, 0.84), 0.4), Mat.material(Color(0.12, 0.1, 0.09), 0.4)]
	for stack: Array in [[0, 2, 0], [5, 5, 1], [7, 3, 1], [11, 5, 0], [12, 5, 1], [16, 3, 0], [18, 5, 0], [23, 2, 1]]:
		var side := 1.0 if stack[0] < 12 else -1.0
		for n in int(stack[1]):
			Mat.part(root, Mat.cylinder(0.016, 0.006), checkers[stack[2]], Vector3(_point_x(stack[0]), 0.031, side * (0.15 - n * 0.033)))
	for d in 2:
		var die := Mat.part(root, BoxMesh.new(), Mat.material(Color(0.95, 0.94, 0.9), 0.4), Vector3(0.07 + d * 0.03, 0.036, 0.02 - d * 0.02))
		die.scale = Vector3.ONE * 0.014
		die.rotation.y = randf() * TAU


## The kahvehane's cat asleep on the floor by the stove, breathing slowly (Meshy model, assets/models/meshy/kedi.glb).
static func cat(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var root := _root(parent, pos, yaw)
	var body := Mat.meshy(root, "kedi")
	var breath := body.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	breath.tween_property(body, "scale", Vector3(1.0, 1.06, 1.03), 1.6)
	breath.tween_property(body, "scale", Vector3.ONE, 1.9)


static func _point_x(i: int) -> float:
	var column := i % 12
	return (column - 5.5) * 0.036 + signf(column - 5.5) * 0.012


static func _brass() -> StandardMaterial3D:
	var brass := Mat.material(Color(0.7, 0.52, 0.25), 0.3)
	brass.metallic = 0.9
	return brass


static func _paper(root: Node3D, pos: Vector3, size: Vector2, color: Color, tilt: float, lines: Array) -> void:
	var sheet := Node3D.new()
	sheet.position = pos
	sheet.rotation.z = tilt
	root.add_child(sheet)
	_box(sheet, Mat.material(color, 0.95), Vector3.ZERO, Vector3(size.x, size.y, 0.002))
	_box(sheet, Mat.material(Color(0.75, 0.1, 0.1), 0.4), Vector3(0, size.y * 0.42, 0.004), Vector3(0.012, 0.012, 0.006))
	_text_lines(sheet, lines, Vector3(0, size.y * 0.3, 0.003), size.y / (lines.size() + 1.5))


static func _text_lines(root: Node3D, lines: Array, top: Vector3, step: float) -> void:
	for i in lines.size():
		var label := Label3D.new()
		label.text = lines[i][0]
		label.font_size = lines[i][1]
		label.modulate = lines[i][2]
		label.outline_size = 0
		label.pixel_size = 0.0006
		label.double_sided = false
		label.position = top + Vector3(0, -i * step, 0)
		root.add_child(label)


static func _root(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	return root


static func _box(parent: Node3D, look: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var box := Mat.part(parent, BoxMesh.new(), look, pos)
	box.scale = size
	return box
