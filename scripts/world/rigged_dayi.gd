class_name RiggedDayi
extends Node3D
## A Meshy dayı rigged by Mixamo (tools/blender/mixamo_import.py), moved by Mixamo's motion-captured clips
## (tools/blender/mixamo_anim.py -> assets/models/dayi_rig/anim/*.glb), so his body moves like a real person's.
## Code only adds what a clip cannot know: it sizes and seats him on our chair, sits him a little more upright
## (Posture), moves his hands onto our felt and out of his rack (HandsOnTable: a small arm IK that keeps the clip's
## wrist and fingers), and turns his head toward whoever he looks at (HeadTurn: at most MAX_TURN on top of the clip).
## Bones are only ever rotated on top of the clip, never scaled. His hands pick up, carry and put down real tiles
## (DayiHands); while `demo` is on he does so now and then on his own.
## Local space = Buddy space: the origin is the seat top, -Z points at the table centre.

const BONE := "mixamorig_"
const CLIPS := "res://assets/models/dayi_rig/anim/"
const IDLE := "seated_idle"
const MAX_TURN := 0.8 # radians, about 45°
const KNEE_ABOVE_SEAT := 0.06
## The caricature torso is big for its legs; sized by the legs alone his shoulders end up ~1.2 m high. A real man's
## shoulders sit about this far above the seat, so taller dayıs are shrunk to it (their feet hang a little, under the table).
const SHOULDER_ABOVE_SEAT := 0.52
const HIPS_ABOVE_SEAT := 0.11

## Off in tests that check the resting hands.
static var demo := true

## How far the upper body leans in right now (DayiHands sets it while reaching), radians, and which way (his
## space, level): toward what he reaches for, so a reach to the side does not put his face into his own rack.
var lean := 0.0
var lean_dir := Vector3.FORWARD
## Where he is turned to look, radians about the vertical (0 = the table); shared by Posture (spine) and HeadTurn.
var yaw := 0.0
## How far his head is bowed (radians, + down: reading his rack) and how far he leans over the table on purpose
## (reading the melds), on top of `lean`. Both ease toward what bow() last asked for. Everyone at the table can read
## these: a bowed head is a man studying his tiles, a man bent over the table is not watching his own rack.
var head_pitch := 0.0
var bend := 0.0
var _pitch_goal := 0.0
var _bend_goal := 0.0
## Each wrist as the clip has it before he leans or turns (skeleton space, set every frame by Posture), so resting
## hands stay where they lie on the table while his body moves, like a person's would.
var planted := {"Left": Vector3.ZERO, "Right": Vector3.ZERO}
var hands := DayiHands.new()
## Set before build() to make him the local player seen from his own eyes: his arms follow the player's hand
## pivots and his head folds away; he sits like the others and `eye` (this node's space) is where the camera goes.
var first_person: FirstPersonArms
var eye := Vector3.ZERO
## The model (dayi_rig/<model>.glb) and the table in front of him, in this node's space: the height of its top and
## how far ahead its near edge is (negative = in front). Defaults are our okey table; regulars at the round
## background tables set their own before build().
var model := ""
var felt_height := Table.TOP - Seat.SEAT_TOP
var table_edge := -(Seat.CHAIR_DISTANCE - Table.SIZE * 0.5)
var _skeleton: Skeleton3D
var _player := AnimationPlayer.new()
var _posture := Posture.new()
var _head_turn := HeadTurn.new()
var _hands_on_table := HandsOnTable.new()
var _turn: Tween


func build(kind: String) -> void:
	var body: Node3D = load("res://assets/models/dayi_rig/%s.glb" % (model if model else "dayi_" + kind)).instantiate()
	body.rotation.y = PI # glTF models face +Z
	add_child(body)
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
	# Modifiers run in child order: straighten the back, then fix the hands for that back, then turn the head.
	_posture.dayi = self
	_skeleton.add_child(_posture)
	if first_person:
		_build_first_person(body)
		return
	_hands_on_table.dayi = self
	var seat := get_parent().get_parent() as Seat
	if seat:
		_hands_on_table.rack = seat.rack
	_skeleton.add_child(_hands_on_table)
	_skeleton.add_child(hands)
	_head_turn.dayi = self
	_skeleton.add_child(_head_turn)
	body.add_child(_player)
	_player.add_animation_library("", _load_clips())
	_fit_to_chair(body)
	_player.play(IDLE)
	_player.seek(randf() * _player.current_animation_length, true)
	_seat_on_floor(body)
	_hands_on_table.calibrate(_player, _posture)
	hands.setup(self)
	if demo:
		_play_around()


func _build_first_person(body: Node3D) -> void:
	_skeleton.add_child(first_person)
	body.add_child(_player)
	_player.add_animation_library("", _load_clips())
	_fit_to_chair(body)
	_player.play(IDLE)
	_player.seek(randf() * _player.current_animation_length, true)
	_seat_on_floor(body)
	# His eyes: above the skull's base and toward the face, for a head held up (the camera turns, not the head).
	var head := _local("Head")
	var size := head.distance_to(_local("HeadTop_End"))
	eye = head + (Vector3.UP + Vector3.FORWARD) * size * 0.3


## Every clip in CLIPS, retargeted from the exported bone nodes onto this skeleton. Only the hips keep their
## position track; the others would undo the shrunk head and hands. Bones this rig lacks (a missing pinky) are dropped.
func _load_clips() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for file in ResourceLoader.list_directory(CLIPS):
		if not file.ends_with(".glb"):
			continue
		var scene: Node = load(CLIPS + file).instantiate()
		var source: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		for clip_name in source.get_animation_list():
			var clip := source.get_animation(clip_name).duplicate() as Animation
			for track in range(clip.get_track_count() - 1, -1, -1):
				var path := clip.track_get_path(track)
				var bone := String(path.get_name(path.get_name_count() - 1))
				var keep := _skeleton.find_bone(bone) >= 0 and (clip.track_get_type(track) == Animation.TYPE_ROTATION_3D
					or (clip.track_get_type(track) == Animation.TYPE_POSITION_3D and bone == BONE + "Hips"))
				if keep:
					clip.track_set_path(track, NodePath("Armature/Skeleton3D:" + bone))
				else:
					clip.remove_track(track)
			clip.loop_mode = Animation.LOOP_LINEAR if clip_name == IDLE else Animation.LOOP_NONE
			library.add_animation(clip_name, clip)
		scene.free()
	return library


# Size from the legs at rest: the knee-to-sole length is what has to fit under our chair's seat.
func _fit_to_chair(body: Node3D) -> void:
	var knee := _local("LeftLeg")
	var sole := _local("LeftToeBase").y - 0.015
	body.scale *= (Seat.SEAT_TOP + KNEE_ABOVE_SEAT) / (knee.y - sole)


# In the seated clip: soles on the floor, then no taller than a real man, hips on the middle of the seat.
func _seat_on_floor(body: Node3D) -> void:
	var sole := minf(_local("LeftToeBase").y, _local("RightToeBase").y) - 0.015
	body.position.y -= sole + Seat.SEAT_TOP
	var shoulders := _local("LeftArm").y
	if shoulders > SHOULDER_ABOVE_SEAT:
		body.scale *= SHOULDER_ABOVE_SEAT / shoulders
	var hips := _local("Hips")
	body.position -= hips - Vector3(0, HIPS_ABOVE_SEAT, 0)


func _local(bone: String) -> Vector3:
	return to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone(BONE + bone)).origin))


# --- Watcher API (through Buddy) ---------------------------------------------------------------------------

func turn_head(yaw: float, time: float) -> void:
	if _turn:
		_turn.kill()
	_turn = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn.tween_property(self, "yaw", clampf(yaw, -MAX_TURN, MAX_TURN), time * 1.6)


## Head shake: "no", or being caught.
func react() -> void:
	_head_turn.shake = 0.9


## Bows the head (`pitch` radians, + down) and leans the body over the table (`amount` radians); eased.
func bow(pitch: float, amount := 0.0) -> void:
	_pitch_goal = pitch
	_bend_goal = amount


func _process(delta: float) -> void:
	head_pitch = move_toward(head_pitch, _pitch_goal, delta * 1.6)
	bend = move_toward(bend, _bend_goal, delta * 1.1)


## Turns his head toward a point in his own space (or back to the table).
func look_at_point(point: Vector3, home := false) -> void:
	turn_head(0.0 if home else atan2(-point.x, -point.z), 0.2)


# --- Demo: until the rules engine drives him, he fiddles with his own tiles ---------------------------------

func _play_around() -> void:
	var seat := get_parent().get_parent() as Seat
	if seat == null or hands.hands.is_empty():
		return
	await get_tree().create_timer(randf_range(3.0, 7.0)).timeout
	while is_inside_tree():
		var rack := seat.rack
		var table := get_tree().get_first_node_in_group("table") as Table
		var right := randf() < 0.6
		var filled: Array[int] = []
		var free: Array[int] = []
		for slot in Rack.SLOTS * Rack.ROWS:
			if (slot % Rack.SLOTS >= 7) == right:
				(filled if rack.tile_at(slot) else free).append(slot)
		if not filled.is_empty() and not free.is_empty():
			var slot: int = filled.pick_random()
			if randf() < 0.4 and table:
				var felt := Table.TOP - Seat.SEAT_TOP
				var spot := Vector3((0.48 if right else -0.48), felt, -0.51) # on the felt just past the rim, beside his rack
				var tile := await hands.discard(rack, slot, table, spot)
				if tile:
					await get_tree().create_timer(1.5).timeout
					await hands.pick_up(tile, table, rack, rack.nearest_free(slot))
			else:
				free.sort_custom(func(a: int, b: int) -> bool: return absi(a - slot) < absi(b - slot))
				await hands.rearrange(rack, slot, free[randi() % mini(3, free.size())])
		await get_tree().create_timer(randf_range(4.0, 9.0)).timeout


## The seated clip hunches far over its table, which brings the side players' heads at the camera. Leans the upper
## back and neck back a little, leans in when reaching, and takes the spine's share of turning to look (rotation
## only). It runs before HandsOnTable, so the hands are kept out of the rack after the body has moved.
class Posture extends SkeletonModifier3D:
	const UPRIGHT := [["Spine1", 0.08], ["Spine2", 0.1], ["Neck", -0.04]] # radians back; the neck keeps eyes on the table
	var dayi: RiggedDayi

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		var right := (skeleton.global_basis.inverse() * (dayi.global_basis * Vector3.RIGHT)).normalized()
		for part: Array in UPRIGHT:
			var bone := skeleton.find_bone(BONE + part[0])
			if bone < 0:
				continue
			var pose := skeleton.get_bone_global_pose(bone)
			pose.basis = Basis(right, float(part[1])) * pose.basis
			skeleton.set_bone_global_pose(bone, pose)
		# Where the wrists are before leaning or turning: HandsOnTable keeps resting hands planted there.
		for side in ["Left", "Right"]:
			dayi.planted[side] = skeleton.get_bone_global_pose(skeleton.find_bone(BONE + side + "Hand")).origin
		# Leaning in to reach (toward what he reaches for) or to look over the table (straight ahead): the lower
		# back takes most of it.
		var toward := (skeleton.global_basis.inverse() * (dayi.global_basis * Vector3.UP.cross(dayi.lean_dir))).normalized()
		for part: Array in [["Spine", 0.6], ["Spine1", 0.4]]:
			var bone := skeleton.find_bone(BONE + part[0])
			ArmIK.turn(skeleton, bone, toward, dayi.lean * float(part[1]))
			ArmIK.turn(skeleton, bone, right, -dayi.bend * float(part[1]))
		# Turning to look: the chest turns a little with the head.
		for part: Array in [["Spine1", 0.15], ["Spine2", 0.2]]:
			ArmIK.turn(skeleton, skeleton.find_bone(BONE + part[0]), Vector3.UP, dayi.yaw * float(part[1]))


## Puts the clip's hands on our table: each wrist is moved by a constant offset (two-bone IK; the hand keeps its
## rotation against the forearm, the elbow keeps its direction), so the hand follows the clip exactly and smoothly.
## The offsets are found once by calibrate(), which plays the whole clip through and grows them until no frame puts a
## hand joint under the felt or into the rack, and pulls the hands in front of his own rack and onto the felt.
## (Correcting each frame from the fingertips made the whole hand jump every time a drumming finger came down.)
class HandsOnTable extends SkeletonModifier3D:
	const MARGIN := 0.012 # fingertips and wrist stay this far above the felt
	const RACK_MARGIN := 0.015 # and this far out of the rack
	const ON_FELT := 0.06 # how far past the table edge a hand that rests on the table is moved
	const MAX_X := 0.34 # the clip spreads the hands ~0.5 m; keep them in front of his own rack, out of the neighbours' way
	const SAMPLES_PER_SECOND := 30.0
	## A natural elbow direction (out, down, back) in the dayı's space for his right arm; x flips for the left.
	const ELBOW := Vector3(0.6, -0.6, 0.5)
	var dayi: RiggedDayi
	var rack: Rack
	## The constant wrist offset per side, in the dayı's space.
	var shift := {"Left": Vector3.ZERO, "Right": Vector3.ZERO}

	func _process_modification() -> void:
		_apply(get_skeleton())

	func _apply(skeleton: Skeleton3D) -> void:
		var to_skeleton := skeleton.global_transform.affine_inverse() * dayi.global_transform
		for side: String in shift:
			var offset: Vector3 = shift[side]
			var hand := skeleton.find_bone(BONE + side + "Hand")
			# The wrist where the clip has it before leaning and turning, so the hand stays planted on the table.
			var target: Vector3 = dayi.planted[side] + to_skeleton.basis * offset
			var pole := to_skeleton.basis * (ELBOW * Vector3(-1.0 if side == "Left" else 1.0, 1, 1))
			ArmIK.reach(skeleton, skeleton.find_bone(BONE + side + "Arm"), skeleton.find_bone(BONE + side + "ForeArm"),
				hand, target, pole)

	## Plays `player`'s current clip through (with `posture` first, as in a real frame) and settles the offsets.
	func calibrate(player: AnimationPlayer, posture: SkeletonModifier3D) -> void:
		var skeleton := get_skeleton()
		var at := player.current_animation_position
		var times: Array[float] = []
		for i in int(player.current_animation_length * SAMPLES_PER_SECOND):
			times.append(i / SAMPLES_PER_SECOND)
		var felt := dayi.felt_height
		var edge := dayi.table_edge
		# Start from the clip's average wrist: in front of his own rack and onto the felt.
		var mean := {"Left": Vector3.ZERO, "Right": Vector3.ZERO}
		for time in times:
			_pose_at(skeleton, player, posture, time, false)
			for side: String in shift:
				mean[side] += _points(skeleton, side)[0] / times.size()
		for side: String in shift:
			var wrist: Vector3 = mean[side]
			shift[side] = Vector3(signf(wrist.x) * minf(0.0, MAX_X - absf(wrist.x)), 0, minf(0.0, edge - ON_FELT - wrist.z))
		# Then grow each offset until every frame is clear (the arm moving changes the hand a little, so repeat).
		var owner := Vector3.BACK
		if rack:
			owner = (dayi.global_basis.inverse() * rack.global_basis.z).normalized()
		for round in 8:
			var grew := false
			for time in times:
				_pose_at(skeleton, player, posture, time, true)
				for side: String in shift:
					var lowest := INF
					var back := 0.0
					for point in _points(skeleton, side):
						lowest = minf(lowest, point.y)
						if rack:
							back = maxf(back, rack.penetration(dayi.global_transform * point, RACK_MARGIN))
					var up := maxf(0.0, felt + MARGIN - lowest)
					if up > 0.0005 or back > 0.0005:
						shift[side] += Vector3.UP * up + owner * back
						grew = true
			if not grew:
				break
		player.seek(at, true)

	func _pose_at(skeleton: Skeleton3D, player: AnimationPlayer, posture: SkeletonModifier3D, time: float, hands: bool) -> void:
		player.seek(time, true)
		posture._process_modification()
		if hands:
			_apply(skeleton)

	## Wrist first, then every finger joint and tip of that hand, in the dayı's space.
	func _points(skeleton: Skeleton3D, side: String) -> Array[Vector3]:
		var to_dayi := dayi.global_transform.affine_inverse() * skeleton.global_transform
		var hand := skeleton.find_bone(BONE + side + "Hand")
		var points: Array[Vector3] = [to_dayi * skeleton.get_bone_global_pose(hand).origin]
		for bone in range(hand + 1, skeleton.get_bone_count()):
			if skeleton.get_bone_name(bone).begins_with(BONE + side + "Hand"):
				points.append(to_dayi * skeleton.get_bone_global_pose(bone).origin)
		return points


## Turns his neck and head toward RiggedDayi.yaw on top of the chest's share (Posture): the head takes the most,
## the neck little, since twisting a neckless caricature's neck alone stretches the collar. Also shakes "no".
class HeadTurn extends SkeletonModifier3D:
	var dayi: RiggedDayi
	var shake := 0.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		shake = maxf(0.0, shake - delta)

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		var wobble := sin(_time * 22.0) * 0.3 * shake / 0.9
		for part: Array in [[BONE + "Neck", 0.2, 0.35], [BONE + "Head", 0.45, 0.65]]:
			var bone := skeleton.find_bone(part[0])
			if bone < 0:
				continue
			var pose := skeleton.get_bone_global_pose(bone)
			pose.basis = Basis(Vector3.UP, (dayi.yaw + wobble) * float(part[1])) * pose.basis
			# Bowing: about his right-hand axis as turned by the look, so he nods toward what he looks at.
			var right := (Basis(Vector3.UP, dayi.yaw) * (skeleton.global_basis.inverse() * (dayi.global_basis * Vector3.RIGHT))).normalized()
			pose.basis = Basis(right, -dayi.head_pitch * float(part[2])) * pose.basis
			skeleton.set_bone_global_pose(bone, pose)
