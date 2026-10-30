class_name FirstPersonArms
extends SkeletonModifier3D
## The local player's own dayı seen from his eyes: his arms follow the hand pivots that the player's controls move
## (Seat.glove / Seat.left_hand, driven by ArmMotion: palm centre at the pivot, fingers along its -Z, palm facing its
## -Y), his fingers pinch and drum with the pivots' FingerGrips, he leans in for far reaches, and his head is
## folded away so the camera sitting at his eyes sees past it.
## Runs on a RiggedDayi built with `first_person` (after Posture).

const BONE := "mixamorig_"
## A natural elbow direction (out, down, back) in the dayı's space for his right arm; x flips for the left.
const ELBOW := Vector3(0.7, -0.5, 0.4)
## Curl in degrees per finger joint: lying relaxed on the felt, and pinching a tile (from DayiHands).
const RELAXED := {"Thumb": [4.0, 8.0, 6.0], "Index": [6.0, 10.0, 6.0], "Middle": [8.0, 12.0, 6.0],
	"Ring": [10.0, 14.0, 8.0], "Pinky": [12.0, 16.0, 8.0]}
const DRUM_ORDER := ["Pinky", "Ring", "Middle", "Index"]
const MAX_LEAN := 0.45 # radians forward for the farthest reach
const EASY_REACH := 0.85 # of his arm's length: closer than this he does not lean

var dayi: Node3D
var pivots := {} # "Left"/"Right" -> Node3D
var grips := {} # "Left"/"Right" -> FingerGrip
var _arms := {} # side -> {upper, lower, wrist, fingers, palm_sign, palm, length}
var _lean := 0.0
## False while someone else's view is shown (switching seats): then his head is there for them to see.
var hide_head := true


func setup(owner_dayi: Node3D, right_pivot: Node3D, right_grip: FingerGrip, left_pivot: Node3D, left_grip: FingerGrip) -> void:
	dayi = owner_dayi
	pivots = {"Right": right_pivot, "Left": left_pivot}
	grips = {"Right": right_grip, "Left": left_grip}
	var skeleton := get_skeleton()
	for side in ["Left", "Right"]:
		var arm := {
			"upper": skeleton.find_bone(BONE + side + "Arm"),
			"lower": skeleton.find_bone(BONE + side + "ForeArm"),
			"wrist": skeleton.find_bone(BONE + side + "Hand"),
			"fingers": {},
		}
		for finger in RELAXED:
			var joints: Array[int] = []
			for j in range(1, 5):
				joints.append(skeleton.find_bone("%s%sHand%s%d" % [BONE, side, finger, j]))
			if joints.min() >= 0:
				arm.fingers[finger] = joints
		var at := func(bone: int) -> Vector3: return skeleton.get_bone_global_pose(bone).origin
		# Palm side from the seated clip, where the hands lie palm down on the table.
		var along: Vector3 = at.call(arm.fingers.Middle[0]) - at.call(arm.wrist)
		var across: Vector3 = at.call(arm.fingers.Index[0]) - at.call(_outer(arm)[0])
		var down := skeleton.global_basis.inverse() * Vector3.DOWN
		arm.palm_sign = 1.0 if along.cross(across).dot(down) > 0.0 else -1.0
		arm.palm = along.length() * 0.55 # wrist to the middle of the palm
		arm.length = at.call(arm.upper).distance_to(at.call(arm.lower)) + at.call(arm.lower).distance_to(at.call(arm.wrist))
		_arms[side] = arm


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if dayi == null or _arms.is_empty():
		return
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var from_dayi := to_skeleton * dayi.global_transform
	# The head folds into the neck: the camera sits where his eyes were.
	if hide_head:
		skeleton.set_bone_pose_scale(skeleton.find_bone(BONE + "Head"), Vector3.ONE * 0.001)
	# Lean in as far as the farther hand needs.
	var need := 0.0
	for side: String in _arms:
		var arm: Dictionary = _arms[side]
		var target := to_skeleton * (pivots[side] as Node3D).global_position
		var reach := skeleton.get_bone_global_pose(arm.upper).origin.distance_to(target) / float(arm.length)
		need = maxf(need, clampf((reach - EASY_REACH) / 0.5, 0.0, 1.0))
	_lean = move_toward(_lean, need * MAX_LEAN, get_process_delta_time() * 1.2)
	var right := (from_dayi.basis * Vector3.RIGHT).normalized()
	for part: Array in [["Spine", 0.5], ["Spine1", 0.3], ["Spine2", 0.2]]:
		ArmIK.turn(skeleton, skeleton.find_bone(BONE + part[0]), right, -_lean * float(part[1]))
	for side: String in _arms:
		_pose_arm(skeleton, _arms[side], side, to_skeleton, from_dayi)


func _pose_arm(skeleton: Skeleton3D, arm: Dictionary, side: String, to_skeleton: Transform3D, from_dayi: Transform3D) -> void:
	var pivot := to_skeleton * (pivots[side] as Node3D).global_transform
	var fingers := (-pivot.basis.z).normalized()
	var palm := (-pivot.basis.y).normalized()
	var pole := from_dayi.basis * (ELBOW * Vector3(-1.0 if side == "Left" else 1.0, 1, 1))
	ArmIK.reach(skeleton, arm.upper, arm.lower, arm.wrist, pivot.origin - fingers * float(arm.palm), pole)
	# The hand turned to the pivot: fingers along it, palm down.
	var wrist := skeleton.get_bone_global_pose(arm.wrist)
	var now := _frame(skeleton, arm)
	var want := _frame_of(fingers, palm)
	wrist.basis = Basis((want * now.inverse()).get_rotation_quaternion()) * wrist.basis
	skeleton.set_bone_global_pose(arm.wrist, wrist)
	# Fingers from their straight rest, relaxed, then pinching and drumming as the pivot's grip says.
	var grip: FingerGrip = grips[side]
	var palm_now := _palm_normal(skeleton, arm)
	for finger: String in arm.fingers:
		var joints: Array = arm.fingers[finger]
		for j in 3:
			skeleton.set_bone_pose_rotation(joints[j], skeleton.get_bone_rest(joints[j]).basis.get_rotation_quaternion())
		var base: Vector3 = skeleton.get_bone_global_pose(joints[1]).origin - skeleton.get_bone_global_pose(joints[0]).origin
		var axis := base.cross(palm_now)
		var tap := 0.0
		if grip.drum > 0.0 and finger in DRUM_ORDER:
			var phase := grip._time * 9.0 - DRUM_ORDER.find(finger) * 0.85
			tap = pow(maxf(0.0, sin(phase)), 3.0) * 24.0 * grip.drum
		for j in 3:
			var curl: float = lerpf(RELAXED[finger][j], DayiHands.PINCH[finger][j], grip.grip) - (tap if j == 0 else tap * 0.3)
			ArmIK.turn(skeleton, joints[j], axis, deg_to_rad(curl))


# The hand's orientation as a basis: -z along the fingers, -y out of the palm.
func _frame(skeleton: Skeleton3D, arm: Dictionary) -> Basis:
	var along := skeleton.get_bone_global_pose(arm.fingers.Middle[0]).origin - skeleton.get_bone_global_pose(arm.wrist).origin
	return _frame_of(along, _palm_normal(skeleton, arm))


func _frame_of(fingers: Vector3, palm: Vector3) -> Basis:
	var f := fingers.normalized()
	var p := (palm - f * palm.dot(f)).normalized()
	return Basis(f.cross(-p), -p, -f)


func _palm_normal(skeleton: Skeleton3D, arm: Dictionary) -> Vector3:
	var along := skeleton.get_bone_global_pose(arm.fingers.Middle[0]).origin - skeleton.get_bone_global_pose(arm.wrist).origin
	var across := skeleton.get_bone_global_pose(arm.fingers.Index[0]).origin - skeleton.get_bone_global_pose(_outer(arm)[0]).origin
	return (along.cross(across) * float(arm.palm_sign)).normalized()


func _outer(arm: Dictionary) -> Array:
	return arm.fingers.get("Pinky", arm.fingers.Ring)
