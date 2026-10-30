class_name Regular
extends Node3D
## A kahvehane regular at a background table: a Meshy dayı (assets/models/mudavim/<kind>.glb, Meshy rig) playing
## Meshy's seated clips as they are: chatting with his hands as he sits, now and then sipping tea.
## (Meshy's Chair_Sit_Idle_M spends most of its length slumped with the chin on a hand, 0.5 m over the table, so it
## is not used.)
## Seen only from across the room, so no hand fixes: the clips play untouched.
## Origin on the seat top, facing -Z (like Buddy).

const KINDS := ["hirkali", "ceketli", "dericeketli", "takkeli"]
const IDLE := "Sitting_Answering_Questions"
const EXTRAS := ["Sit_and_Drink"]
const KNEE_ABOVE_SEAT := 0.04
const SHOULDER_ABOVE_SEAT := 0.5
## These caricatures are round: with the hips bone over the middle of the seat, the back went through the chair's
## backrest and the seat through the buttocks. Their hips sit higher and forward of it instead.
const HIPS_ABOVE_SEAT := 0.14
const SCOOT := 0.04
## The round background table: its top, and how far in front of his seat its edge is.
const TABLE_TOP := 0.753
const TABLE_GAP := 0.25

var _player: AnimationPlayer
var _skeleton: Skeleton3D


func setup(kind: String) -> void:
	# With a Mixamo rig he sits like the dayıs at our table: mocap Seated Idle, hands put on this round table.
	if ResourceLoader.exists("res://assets/models/dayi_rig/mudavim_%s.glb" % kind):
		var dayi := RiggedDayi.new()
		dayi.model = "mudavim_" + kind
		dayi.felt_height = TABLE_TOP - Seat.SEAT_TOP + 0.03 # this node sits 3 cm low on the chair (room.gd)
		dayi.table_edge = -TABLE_GAP
		add_child(dayi)
		dayi.build(kind)
		return
	var body: Node3D = load("res://assets/models/mudavim/%s.glb" % kind).instantiate()
	body.rotation.y = PI # glTF models face +Z
	add_child(body)
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Icosphere": # Meshy's rig helper ball
			mesh.visible = false
	_player = body.find_children("*", "AnimationPlayer", true, false)[0]
	_player.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
	_player.play(IDLE)
	_player.seek(randf() * _player.current_animation_length, true)
	# The clip's pose only reaches the skeleton on the next frame; measuring before that saw the rest pose.
	visible = false
	await get_tree().process_frame
	_fit(body)
	visible = true
	_player.animation_finished.connect(func(_name: StringName) -> void: _player.play(IDLE, 0.5))
	_live()


# Sized like the table's dayıs: legs under the seat, no taller than a real man, hips on the seat.
func _fit(body: Node3D) -> void:
	var knee := _local("LeftLeg")
	var sole := minf(_local("LeftToeBase").y, _local("RightToeBase").y) - 0.015
	body.scale *= (Seat.SEAT_TOP + KNEE_ABOVE_SEAT) / maxf(knee.y - sole, 0.1)
	sole = minf(_local("LeftToeBase").y, _local("RightToeBase").y) - 0.015
	body.position.y -= sole + Seat.SEAT_TOP
	var shoulders := _local("LeftArm").y
	if shoulders > SHOULDER_ABOVE_SEAT:
		body.scale *= SHOULDER_ABOVE_SEAT / shoulders
	var hips := _local("Hips")
	body.position -= hips - Vector3(0, HIPS_ABOVE_SEAT, -SCOOT)


func _local(bone: String) -> Vector3:
	return to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone(bone)).origin))


# Every so often he takes a sip or says something, then settles back.
func _live() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(8.0, 20.0)).timeout
		if is_inside_tree() and _player.current_animation == IDLE:
			_player.play(EXTRAS.pick_random(), 0.6)
