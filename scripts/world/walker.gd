class_name Walker
extends Node3D
## Someone walking about the kahvehane: a Meshy dayı (Meshy rig) whose in-place walk clip plays while this node
## moves him along a path, turning smoothly toward where he is going; he stands idle when he stops.
## Feet on the floor at this node's origin, facing -Z.

const TURN_SPEED := 4.0 # radians per second
const HOLD_AT := 1.63 # seconds into the walk clip where the carrying pose is even (both hands level, centred)

var speed := 0.9 # metres per second
## Someone carrying something stays in the walk clip's carrying pose when he stops (frozen), instead of dropping
## his arms into the idle clip.
var hold_pose := false
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _walk := ""
var _idle := ""


## `clips` = [walk, idle, ...] animation names in the model.
func setup(model: String, walk: String, idle: String) -> void:
	var body: Node3D = load(model).instantiate()
	body.rotation.y = PI # glTF models face +Z
	add_child(body)
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Icosphere": # Meshy's rig helper ball
			mesh.visible = false
	_player = body.find_children("*", "AnimationPlayer", true, false)[0]
	_walk = _find(walk)
	_idle = _find(idle)
	for clip in [_walk, _idle]:
		_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_player.play(_idle)
	# Stand him on the floor once the clip's pose has reached the skeleton.
	visible = false
	await get_tree().process_frame
	var toe := minf(_bone("LeftToeBase").y, _bone("RightToeBase").y)
	body.position.y -= toe - 0.02
	visible = true


## Plays a clip once (e.g. opening a door), then stands idle again.
func act(clip: String) -> void:
	var name := _find(clip)
	if name.is_empty():
		return
	_player.play(name, 0.3)
	await _player.animation_finished
	_player.play(_idle, 0.3)


## Walks through `points` (parent space) in order, then stands.
func walk(points: Array) -> void:
	_player.speed_scale = 1.0
	_player.play(_walk, 0.3)
	for target: Vector3 in points:
		while is_inside_tree():
			var to := target - position
			to.y = 0.0
			var step := speed * get_process_delta_time()
			if to.length() <= step:
				position = Vector3(target.x, position.y, target.z)
				break
			var want := atan2(-to.x, -to.z)
			rotation.y = rotate_toward(rotation.y, want, TURN_SPEED * get_process_delta_time())
			# Slow down while turning sharply, like people do.
			var facing := Vector3(-sin(rotation.y), 0, -cos(rotation.y))
			position += to.normalized() * step * clampf(facing.dot(to.normalized()), 0.3, 1.0)
			await get_tree().process_frame
	stand()


func stand() -> void:
	if hold_pose:
		# Freeze the carrying pose as it is (no blend: a blend at speed 0 never finishes and left him in the idle
		# pose, arms down, tray in his belly).
		if _player.current_animation != _walk:
			_player.play(_walk, 0.0)
			_player.seek(HOLD_AT, true)
		_player.speed_scale = 0.0
	else:
		_player.play(_idle, 0.3)


## Turns on the spot to face a point (parent space).
func face(point: Vector3) -> void:
	var to := point - position
	var want := atan2(-to.x, -to.z)
	while is_inside_tree() and absf(angle_difference(rotation.y, want)) > 0.02:
		rotation.y = rotate_toward(rotation.y, want, TURN_SPEED * get_process_delta_time())
		await get_tree().process_frame


func hand(side: String) -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone(side + "Hand")).origin)


func _bone(bone: String) -> Vector3:
	return to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone(bone)).origin))


func _find(clip: String) -> String:
	for name in _player.get_animation_list():
		if name == clip or name.begins_with(clip):
			return name
	return ""
