extends SceneTree
## The opposite dayı handles real tiles: moves one along his rack, drops one on the felt, picks it back up.
## Checks that his pinch closes right on each tile, that the tile ends where it should and stays in his hand while
## carried (except while his fingers lay it flat). Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/dayi_hands_test.gd

const MAX_MISS := 0.02 # pinch point to the tile's top edge when the fingers close
const MAX_DRIFT := 0.005 # a held tile may not move relative to the hand (half a centimetre of rounding)
## Touching tile faces is fine while handling tiles; past this a joint is through the board itself.
const THROUGH_BOARD := 0.06
## A held tile must be between his fingers: its surface this close to the pinch point (thumb and index tips).
const MAX_GAP := 0.02

var _failures: Array[String] = []
var _hands: DayiHands
var _held := {} # HandState -> [tile, offset from the hand]
var _racks: Array[Rack] = []
var _skeleton: Skeleton3D
var _through := 0.0
var _through_where := ""
var _doing := ""
var _gap := 0.0
var _gap_where := ""
var _own_rack: Rack


func _init() -> void:
	RiggedDayi.demo = false
	var world := Node3D.new()
	root.add_child(world)
	var table := Table.new()
	world.add_child(table)
	var seats: Array[Seat] = []
	for index in 4:
		var seat := Seat.new()
		seat.seat_index = index
		seat.is_local = index == 0
		world.add_child(seat)
		seats.append(seat)
	await process_frame
	var tiles: Array = []
	for i in 14:
		tiles.append(Vector2i(i % 4, i % 13 + 1))
	for seat in seats:
		seat.rack.set_tiles(tiles)
		_racks.append(seat.rack)
	var dayi: RiggedDayi = seats[2].buddy.find_children("*", "RiggedDayi", true, false)[0]
	var rack := seats[2].rack
	_own_rack = rack
	_hands = dayi.hands
	var skeleton: Skeleton3D = dayi.find_children("*", "Skeleton3D", true, false)[0]
	_skeleton = skeleton
	skeleton.skeleton_updated.connect(_watch_held)
	for frame in 20:
		await process_frame

	var from := _filled(rack, 9)
	var to := rack.nearest_free(from)
	var tile := rack.tile_at(from)
	_doing = "rearrange"
	await _hands.rearrange(rack, from, to)
	_expect(rack.tile_at(to) == tile and rack.tile_at(from) == null, "rearrange: tile is in slot %d" % to)
	_expect_pinch("rearrange")

	var slot := _filled(rack, 10)
	var spot := Vector3(0.48, Table.TOP - Seat.SEAT_TOP, -0.51) # on the felt just past the rim, beside his rack
	_doing = "discard"
	var dropped: Tile = await _hands.discard(rack, slot, table, spot)
	_expect(dropped != null and dropped.holder == table, "discard: tile is on the table")
	_expect_pinch("discard")
	for frame in 60:
		await process_frame
	var landed := dayi.to_local(dropped.global_position)
	_expect(Vector2(landed.x - spot.x, landed.z - spot.z).length() < 0.1 and absf(landed.y - (spot.y + TileFactory.SIZE.z * 0.5)) < 0.01,
		"discard: tile settled on the felt by the spot (at %s)" % landed)

	var back := rack.nearest_free(slot)
	_doing = "pick up"
	await _hands.pick_up(dropped, table, rack, back)
	_expect(rack.tile_at(back) == dropped, "pick up: tile is back in slot %d" % back)
	_expect_pinch("pick up")

	_expect(_gap < MAX_GAP, "held tiles stayed between the fingers (farthest %.1f cm from the pinch: %s)" % [_gap * 100.0, _gap_where])
	_expect(_through < THROUGH_BOARD, "no finger went through a rack board (deepest %.1f cm into a rack: %s)" % [_through * 100.0, _through_where])
	print("DAYI_HANDS %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	for failure in _failures:
		print("  FAIL: ", failure)
	quit(0 if _failures.is_empty() else 1)


## A filled slot at or right of `column` in either row.
func _filled(rack: Rack, column: int) -> int:
	for c in range(column, Rack.SLOTS):
		for row in Rack.ROWS:
			if rack.tile_at(row * Rack.SLOTS + c):
				return row * Rack.SLOTS + c
	return -1


func _expect(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _expect_pinch(action: String) -> void:
	var miss := 0.0
	for hand in _hands.hands:
		miss = maxf(miss, hand.miss)
		hand.miss = 0.0
	_expect(miss < MAX_MISS, "%s: pinch closed %.1f cm from the tile" % [action, miss * 100.0])


# Every frame a hand holds a tile, the tile must keep the same offset from the hand; no hand joint goes through a board.
func _watch_held() -> void:
	for bone in _skeleton.get_bone_count():
		if _skeleton.get_bone_name(bone).contains("Hand"):
			var point := _skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin)
			for rack in _racks:
				var depth := rack.penetration(point, 0.0, rack == _own_rack)
				if depth > _through:
					_through = depth
					_through_where = "%s during %s" % [_skeleton.get_bone_name(bone).trim_prefix(RiggedDayi.BONE), _doing]
	for hand in _hands.hands:
		if hand.tile and hand.flat <= 0.0:
			# Measured on the real (modified) pose: pinch point to the nearest point of the tile.
			var pinch := _skeleton.to_global(_hands._pinch_point(_skeleton, hand))
			var local := hand.tile.global_transform.affine_inverse() * pinch
			var half := TileFactory.SIZE * 0.5
			var nearest := local.clamp(-half, half)
			var gap := (hand.tile.global_transform * nearest).distance_to(pinch)
			if gap > _gap:
				_gap = gap
				_gap_where = _doing
		if hand.tile == null or hand.flat > 0.0: # laying it flat turns it in the fingers on purpose
			_held.erase(hand)
			continue
		var hand_world: Transform3D = _hands._hand_world(hand)
		var offset := hand_world.affine_inverse() * hand.tile.global_transform
		if _held.has(hand) and _held[hand][0] == hand.tile:
			var drift: float = (offset.origin - (_held[hand][1] as Transform3D).origin).length()
			if drift > MAX_DRIFT:
				_failures.append("held tile drifted %.1f cm in the hand" % (drift * 100.0))
		else:
			_held[hand] = [hand.tile, offset]
