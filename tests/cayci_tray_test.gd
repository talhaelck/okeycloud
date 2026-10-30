extends SceneTree
## The çaycı walks his round and stops at tables; in every frame each of his wrists must be at an end of the tray
## (within MAX_GAP) and the tray's near edge must stay in front of his chest. Exit code 1 on failure.
##   godot --path . --headless --fixed-fps 30 --script tests/cayci_tray_test.gd

const MAX_GAP := 0.04 # palm to the tray's end
const PALM := 0.08 # wrist joint to the middle of the palm
const CHEST_CLEAR := 0.02 # tray's near edge at least this far in front of his spine

var _v: Visitors
var _gap := 0.0
var _into := -INF
var _frames := 0


func _init() -> void:
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	_v = Visitors.new()
	_v.round_trip = [[Vector3(1.0, 0, 0.0), null], [Vector3(1.0, 0, -1.5), Vector3(2.0, 0, -1.5)], [Vector3(-0.5, 0, -1.0), null]]
	_v.counter = Vector3.ZERO
	world.add_child(_v)
	_v._start_cayci()
	while _v._tray == null:
		await process_frame
	_v._cayci._skeleton.skeleton_updated.connect(_measure)
	for i in 30 * 22:
		await process_frame
	var ok := _gap <= MAX_GAP and _into <= -CHEST_CLEAR
	print("CAYCI_TRAY %s frames %d: farthest wrist from its tray end %.1f cm, tray edge %.1f cm in front of the spine" % [
		"PASS" if ok else "FAIL", _frames, _gap * 100.0, -_into * 100.0])
	quit(0 if ok else 1)


func _measure() -> void:
	_frames += 1
	var pose := _v.tray_pose()
	for side in ["Left", "Right"]:
		# The palm lies PALM in from the wrist, toward the other hand: that is what holds the tray's end.
		var wrist := pose.affine_inverse() * _v._cayci.hand(side)
		var sign := -1.0 if side == "Left" else 1.0
		var palm := wrist - Vector3(sign * PALM, 0, 0)
		var end := Vector3(sign * Visitors.TRAY_SIZE.x * 0.5, 0, 0)
		_gap = maxf(_gap, Vector2(palm.x - end.x, palm.z - end.z).length())
	# How far the tray's back edge (toward him) reaches past his spine, along the way he faces.
	var spine := _v._cayci.to_global(_v._cayci._bone("Spine02"))
	var facing := -_v._cayci.global_basis.z
	var back_edge := pose.origin - facing * Visitors.TRAY_SIZE.y * 0.5
	_into = maxf(_into, (spine - back_edge).dot(facing))
