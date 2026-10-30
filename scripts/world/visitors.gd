class_name Visitors
extends Node3D
## People moving about the kahvehane (Walker): the çaycı going round the tables with his tray of tea, and now and
## then someone coming in from the rain: the door swings open with its bell, every dayı at the table turns to look,
## he hangs his cap, stops at the tea counter, and goes back out.
## Positions are in the room's space (our table at the origin).

const CAYCI := "res://assets/models/walkers/cayci.glb"
const CUSTOMER := "res://assets/models/walkers/musteri.glb"
const DOOR_OPEN := -1.35 # radians: the leaf swings into the room
## The çaycı's tray, long side between his hands: its ends sit in his palms (wrists 0.66 m apart in the carry clip).
const TRAY_SIZE := Vector2(0.5, 0.24)

var room: Node3D
var door_hinge: Node3D
var ambience: Ambience
## The street door (on its sill) and the spots people walk between.
var door := Vector3(1.3, 0, 3.6)
var counter := Vector3(2.6, 0, 0.6)
var coat_rack := Vector3(2.5, 0, 3.0)
## The çaycı's round: [point, table centre to face or null].
var round_trip: Array = [
	[Vector3(2.2, 0, -0.9), null], [Vector3(2.0, 0, -1.4), Vector3(2.8, 0, -2.0)],
	[Vector3(0.0, 0, -2.4), null], [Vector3(-1.9, 0, -1.6), Vector3(-2.7, 0, -2.2)],
	[Vector3(-2.1, 0, 0.3), null], [Vector3(-1.8, 0, 1.8), Vector3(-2.6, 0, 2.4)],
	[Vector3(0.0, 0, 2.3), null], [Vector3(2.0, 0, 1.6), null],
]

var _cayci: Walker
var _tray: Node3D


func start() -> void:
	if ResourceLoader.exists(CAYCI):
		_start_cayci()
	if ResourceLoader.exists(CUSTOMER):
		_customers()


# --- The çaycı ---------------------------------------------------------------------------------------------

func _start_cayci() -> void:
	_cayci = Walker.new()
	_cayci.speed = 0.8
	_cayci.hold_pose = true
	_cayci.position = counter
	_cayci.add_to_group("view_blockers") # walking past a table, he blocks the view (Visibility): a chance to steal
	add_child(_cayci)
	await _cayci.setup(CAYCI, "Carry_Heavy_Object_Walk_inplace", "Idle")
	_cayci.stand()
	_tray = _build_tray()
	# Moved the moment his skeleton is posed, so the tray never lags a frame behind his hands.
	_cayci._skeleton.skeleton_updated.connect(func() -> void:
		if is_inside_tree() and _cayci.is_inside_tree(): # (not while the scene is being taken down)
			_tray.global_transform = tray_pose())
	while is_inside_tree():
		await _cayci.face(counter + Vector3(1, 0, 0))
		await get_tree().create_timer(randf_range(5.0, 10.0)).timeout
		for stop: Array in round_trip:
			await _cayci.walk([stop[0]])
			if stop[1] != null:
				await _cayci.face(stop[1])
				await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
		await _cayci.walk([counter])


# A long brass tray with raised rims and four glasses of tea; its short ends rest in his palms.
func _build_tray() -> Node3D:
	var tray := Node3D.new()
	add_child(tray)
	var brass := Mat.material(Color(0.72, 0.53, 0.26), 0.3)
	brass.metallic = 0.9
	Mat.part(tray, BoxMesh.new(), brass, Vector3(0, 0.004, 0)).scale = Vector3(TRAY_SIZE.x, 0.008, TRAY_SIZE.y)
	for side in [-1.0, 1.0]:
		Mat.part(tray, BoxMesh.new(), brass, Vector3(0, 0.015, side * TRAY_SIZE.y * 0.5)).scale = Vector3(TRAY_SIZE.x, 0.022, 0.008)
		Mat.part(tray, BoxMesh.new(), brass, Vector3(side * TRAY_SIZE.x * 0.5, 0.015, 0)).scale = Vector3(0.008, 0.022, TRAY_SIZE.y)
	for i in 4:
		Mat.meshy(tray, "cay_bardagi", Vector3((i - 1.5) * 0.1, 0.008, 0.0), randf() * TAU).scale = Vector3.ONE * 0.85
	return tray


## Where the tray is: its long axis along the line between his wrists, level, centred between his palms (a palm
## reaches PALM in from the wrist), its floor just under the wrists.
func tray_pose() -> Transform3D:
	var left := _cayci.hand("Left")
	var right := _cayci.hand("Right")
	var across := Vector3(right.x - left.x, 0, right.z - left.z).normalized()
	var mid := (left + right) * 0.5
	var basis := Basis(across, Vector3.UP, across.cross(Vector3.UP))
	return Transform3D(basis, mid + Vector3.DOWN * 0.03)


# --- Someone coming in from the street -----------------------------------------------------------------------

func _customers() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(35.0, 80.0)).timeout
		await _visit()


func _visit() -> void:
	var guest := Walker.new()
	guest.speed = 0.75
	guest.position = door + Vector3(0, 0, -0.1)
	guest.rotation.y = 0.0 # facing into the room (-Z)
	add_child(guest)
	await guest.setup(CUSTOMER, "Casual_Walk_inplace", "Idle")
	guest.visible = false
	await _swing_door(true)
	guest.visible = true
	_everyone_looks(guest)
	await guest.walk([door + Vector3(0, 0, -0.8), coat_rack + Vector3(0, 0, -0.1)])
	await guest.face(coat_rack + Vector3(0, 0, 1))
	_swing_door(false)
	await get_tree().create_timer(2.0).timeout
	await guest.walk([counter + Vector3(-0.2, 0, 0.6)])
	await guest.face(counter + Vector3(1, 0, 0.6))
	await get_tree().create_timer(randf_range(4.0, 7.0)).timeout
	await guest.walk([door + Vector3(0, 0, -0.8)])
	await _swing_door(true)
	await guest.walk([door + Vector3(0, 0, -0.05)])
	guest.queue_free()
	await _swing_door(false)


func _swing_door(open: bool) -> void:
	if door_hinge == null:
		return
	var at := door_hinge.global_position + Vector3.UP
	ambience.play_at(["door_open"] if open else ["door_close"], at, -4.0, 3.0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	tween.tween_property(door_hinge, "rotation:y", DOOR_OPEN if open else 0.0, 0.9 if open else 0.6)
	await tween.finished


# Every dayı at our table turns to see who came in, then back to the game.
func _everyone_looks(guest: Node3D) -> void:
	var dayis := get_tree().get_nodes_in_group("dayis")
	for dayi: Buddy in dayis:
		dayi.look_toward(guest.global_position + Vector3.UP * 1.5)
	await get_tree().create_timer(2.5).timeout
	for dayi: Buddy in dayis:
		if is_instance_valid(dayi):
			dayi.look_home()
