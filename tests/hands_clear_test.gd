extends SceneTree
## Plays every rigged opponent's clip for a few seconds and checks, in every frame, that no hand joint or fingertip
## is inside any rack (board, tiles, base) or below the felt. Also reports how close each head comes to the
## player's eye. Exits with code 1 if anything clips.
##   godot --path . --headless --fixed-fps 30 --script tests/hands_clear_test.gd

const SECONDS := 6.0
const FELT_TOLERANCE := 0.002

var _racks: Array[Rack] = []
var _violations := 0
var _worst := {}
var _closest := {}
var _eye := Vector3.ZERO
var _seats: Array[Seat] = []


func _init() -> void:
	RiggedDayi.demo = false # resting hands only; tests/dayi_hands_test.gd covers handling tiles
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(Table.new())
	var seats: Array[Seat] = []
	for index in 4:
		var seat := Seat.new()
		seat.seat_index = index
		seat.is_local = index == 0
		world.add_child(seat)
		seats.append(seat)
	await process_frame
	_eye = seats[0].to_global(Seat.EYE)
	_seats = seats
	var tiles: Array = []
	for i in 14:
		tiles.append(Vector2i(i % 4, i % 13 + 1))
	for seat in seats:
		_racks.append(seat.rack)
		seat.rack.set_tiles(tiles)
	var checked := 0
	for seat in seats.slice(1):
		for dayi in seat.buddy.find_children("*", "RiggedDayi", true, false):
			var skeleton: Skeleton3D = dayi.find_children("*", "Skeleton3D", true, false)[0]
			skeleton.skeleton_updated.connect(_check.bind(seat.seat_index, skeleton))
			checked += 1
	for frame in int(SECONDS * 30.0):
		await process_frame
	print("HANDS_CLEAR dayis=%d violations=%d" % [checked, _violations])
	for key in _worst:
		print("  worst %s: %s" % [key, _worst[key]])
	for key in _closest:
		print("  seat %d head to player's eye: %.2f m (closest)" % [key, _closest[key]])
	quit(1 if _violations > 0 or checked == 0 else 0)


func _check(seat: int, skeleton: Skeleton3D) -> void:
	var head := skeleton.find_bone(RiggedDayi.BONE + "Head")
	_closest[seat] = minf(_closest.get(seat, INF), skeleton.to_global(skeleton.get_bone_global_pose(head).origin).distance_to(_eye))
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		if not bone_name.contains("Hand"):
			continue
		var point := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
		var over_table := absf(point.x) < Table.SIZE * 0.5 and absf(point.z) < Table.SIZE * 0.5
		var depth := 0.0
		var what := ""
		if over_table and point.y < Table.TOP - FELT_TOLERANCE:
			depth = Table.TOP - point.y
			what = "under felt"
		for rack in _racks:
			var inside := rack.penetration(point, 0.0, rack.get_parent() == _seats[seat])
			if inside > depth:
				depth = inside
				what = "in a rack"
		if depth > 0.0:
			_violations += 1
			var key := "seat %d %s" % [seat, bone_name.trim_prefix(RiggedDayi.BONE)]
			if depth > float(_worst.get(key, [0.0])[0]):
				_worst[key] = [depth, what]
