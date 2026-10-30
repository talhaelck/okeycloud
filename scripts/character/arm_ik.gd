class_name ArmIK
## Small skeleton-space helpers for the dayıs' arm modifiers (RiggedDayi.HandsOnTable, DayiHands).


## Two-bone IK: puts the wrist (`hand`'s joint) at `target`, the elbow bending the way it already does, steadied by
## `pole` (a natural elbow direction, skeleton space) so it cannot flip over when the arm is nearly straight.
## The hand keeps its rotation relative to the forearm, so the wrist bends as much as it did before, no more.
static func reach(skeleton: Skeleton3D, upper: int, lower: int, hand: int, target: Vector3, pole := Vector3.ZERO) -> void:
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(lower).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(skeleton.get_bone_global_pose(hand).origin)
	var to_target := target - shoulder
	var d := clampf(to_target.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to_target.normalized()
	var along := (a * a - b * b + d * d) / (2.0 * d)
	var bend := sqrt(maxf(a * a - along * along, 0.0))
	var hint := (elbow - shoulder).normalized() + pole.normalized() * 0.7 if pole != Vector3.ZERO else elbow - shoulder
	var bend_dir := (hint - dir * hint.dot(dir)).normalized()
	aim(skeleton, upper, lower, shoulder + dir * along + bend_dir * bend)
	aim(skeleton, lower, hand, shoulder + dir * d)


## Rotates `bone` about its joint so that its child joint ends up at `desired` (skeleton space).
static func aim(skeleton: Skeleton3D, bone: int, child: int, desired: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var current := skeleton.get_bone_global_pose(child).origin - pose.origin
	var wanted := desired - pose.origin
	if current.length() < 0.0001 or wanted.length() < 0.0001:
		return
	pose.basis = Basis(Quaternion(current.normalized(), wanted.normalized())) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)


## Rotates `bone` (and so everything below it) about `axis` through its own joint (skeleton space).
static func turn(skeleton: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or is_zero_approx(angle) or axis.length() < 0.0001:
		return
	var pose := skeleton.get_bone_global_pose(bone)
	pose.basis = Basis(axis.normalized(), angle) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)
