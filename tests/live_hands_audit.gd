extends SceneTree
## The hands in a REAL game: the main scene plays with greedy stealing bots, and in every frame of every opponent's
## skeleton the audit checks that no hand joint or fingertip is in a rack (his own included) or under the felt, that
## no tile held in a hand is through another rack or under the felt, and how jerky his wrist moves (acceleration in
## m/s^2, worst and 99th percentile per seat). tests/hands_clear_test.gd only watches resting hands and
## tests/hands_smooth_test.gd one demo hand; this one catches what happens between actions, far reaches and thefts.
## Prints the worst offender per seat with the frame it happened in. Exits with code 1 when a hand snaps (and, with --strict, on any penetration).
##   godot --path . --headless --fixed-fps 30 --script tests/live_hands_audit.gd -- [--frames=<n>] [--jerk=<m/s2>]

const FELT_TOLERANCE := 0.003
const JERK_LIMIT := 60.0 # m/s^2 at the wrist while a hand is working, over this the hand visibly snaps

var _frames := 3600
var _jerk_limit := JERK_LIMIT
var _director: GameDirector
var _frame := 0
var _hand_hits := {} # "seat side bone" -> [depth, what, frame]
var _tile_hits := {}
var _tile_count := 0
var _hand_count := 0
var _accel := {} # seat -> Array[float] while working
var _worst_accel := {} # seat -> [value, side, frame]
var _last := {} # "seat side" -> [pos, vel] in the dayi's space
var _snaps := 0
var _crossings := {} # what went through a board -> times
var _first_cross := {}
var _before := {} # bone key -> its depth/height before
var _trace: Array[String] = []
var _first_snap := -1
var _shots := ""
var _window := Vector2i(-1, -1)
var _yaw := 0.0
var _view := -1
var _ring: Array[Image] = []
var _ring_frames: Array[int] = []
var _trigger := -1
var _dumped := false


func _init() -> void:
	seed(11) # the same game every run, so a frame number points at the same moment
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--shots="): # windowed: save the frames of --window=<from>-<to> as <prefix>_<frame>.png
			_shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--window="):
			var bounds := arg.trim_prefix("--window=").split("-")
			_window = Vector2i(int(bounds[0]), int(bounds[1]))
		elif arg.begins_with("--view="):
			_view = int(arg.trim_prefix("--view="))
		elif arg.begins_with("--yaw="):
			_yaw = float(arg.trim_prefix("--yaw="))
		elif arg.begins_with("--jerk="):
			_jerk_limit = float(arg.trim_prefix("--jerk="))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_director = main.director
	_director.game.settings.stealing_enabled = true
	_director.game.settings.turn_time_limit = 1
	for p in range(1, 4):
		_director.bot(p).greed = 0.9
	if _shots != "":
		main.camera.mouse_control = false
		main.camera.set_focused(false, true)
		main.camera.look(_yaw, -0.6)
		if _view >= 0:
			main.view_seat(_view)
		DirAccess.make_dir_recursive_absolute(_shots.get_base_dir())
	for s in range(1, 4):
		var st: Seat = _director.seats[s]
		print("  seat %d: pull spot %s, rack origin %s, slot0 top %s, pile top %s, board face z in dayi %s" % [s,
			st.buddy.dayi_space(st.to_global(Bot.PULL_SPOT)).snapped(Vector3.ONE * 0.001), st.buddy.dayi_space(st.rack.global_position).snapped(Vector3.ONE * 0.001),
			st.buddy.dayi_space(st.rack.slot_global_transform(0).origin).snapped(Vector3.ONE * 0.001),
			st.buddy.dayi_space(_director.table.pile_top().global_position).snapped(Vector3.ONE * 0.001), st.buddy.dayi_space(st.rack.to_global(st.rack._board_origin)).snapped(Vector3.ONE * 0.001)])
	var watched := 0
	for seat in _director.seats.slice(1):
		for dayi: RiggedDayi in seat.buddy.find_children("*", "RiggedDayi", true, false):
			var skeleton: Skeleton3D = dayi.find_children("*", "Skeleton3D", true, false)[0]
			skeleton.skeleton_updated.connect(_check.bind(seat.seat_index, dayi, skeleton))
			watched += 1
	while _frame < _frames:
		await process_frame
		_frame += 1
		if _shots != "" and _window.x < 0:
			await RenderingServer.frame_post_draw
			_ring.append(root.get_viewport().get_texture().get_image())
			_ring_frames.append(_frame)
			if _ring.size() > 10:
				_ring.pop_front()
				_ring_frames.pop_front()
			if _trigger >= 0 and _frame >= _trigger + 4 and not _dumped:
				_dumped = true
				for i in _ring.size():
					_ring[i].save_png("%s_%04d.png" % [_shots, _ring_frames[i]])
				print("dumped ", _ring_frames)
				quit()
				return
		if _shots != "" and _frame >= _window.x and _frame <= _window.y:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s_%04d.png" % [_shots, _frame])
		if _director.game.phase == OkeyGame.Phase.OVER:
			_director.game.next_hand()
			await _director._deal()
	_report(watched)


func _check(seat: int, dayi: RiggedDayi, skeleton: Skeleton3D) -> void:
	var hands := dayi.hands
	if hands == null or hands.hands.is_empty():
		return
	var to_dayi := dayi.global_transform.affine_inverse() * skeleton.global_transform
	for hand in hands.hands:
		_hand_count += 1
		var side: String = hand.side
		var working: bool = hand.weight > 0.01 or hand.busy
		for bone in _hand_bones(skeleton, side):
			var point := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
			var depth := 0.0
			var what := ""
			if _over_felt(point) and point.y < Table.TOP - FELT_TOLERANCE:
				depth = Table.TOP - point.y
				what = "under felt"
			var bone_key := "%d %d" % [dayi.get_instance_id(), bone]
			for other in _director.seats:
				var crossing := _crossed(other.rack, bone_key + " %d" % other.seat_index, point)
				if crossing > 0.0:
					var through := "seat %d %s %s through the board of seat %d" % [seat, side, skeleton.get_bone_name(bone).trim_prefix(RiggedDayi.BONE), other.seat_index]
					_crossings[through] = _crossings.get(through, 0) + 1
					if not _first_cross.has(through):
						_first_cross[through] = _frame
						var rl := other.rack.to_local(point) - other.rack._board_origin
						print("  cross %s f%d: depth %.3f height %.3f; pinch height %.3f boardtop(dayi) %.3f tile %s grip %.2f weight %.2f point %s action %s" % [through, _frame,
							rl.dot(other.rack._board.z), rl.dot(other.rack._board.y), hand.pinch.y, dayi.to_local(other.rack.top_edge()).y,
							hand.tile != null, hand.grip, hand.weight, hand.point.snapped(Vector3.ONE * 0.001), hand.action])
				var hit := _rack_hit(other.rack, point)
				if hit[0] > depth:
					depth = hit[0]
					what = "%s of seat %d's rack" % [hit[1], other.seat_index]
			if depth > 0.05 and what == "under felt" and _trigger < 0:
				_trigger = _frame
			if depth > 0.0:
				var key := "seat %d %s %s" % [seat, side, skeleton.get_bone_name(bone).trim_prefix(RiggedDayi.BONE)]
				if depth > float(_hand_hits.get(key, [0.0])[0]):
					_hand_hits[key] = [depth, what, _frame, hand.action if working else "resting"]
		if hand.tile:
			_check_tile(seat, side, hand.tile)
		var wrist := to_dayi * skeleton.get_bone_global_pose(hand.wrist).origin
		var key := "%d %s" % [dayi.get_instance_id(), side]
		var last: Array = _last.get(key, [])
		var dt := 1.0 / 30.0
		var velocity := Vector3.ZERO
		if not last.is_empty():
			velocity = (wrist - last[0]) / dt
			if last.size() > 1 and working:
				var accel: float = (velocity - last[1]).length() / dt
				if not _accel.has(seat):
					_accel[seat] = []
				_accel[seat].append(accel)
				if accel > _jerk_limit:
					_snaps += 1
					if seat == 1 and _first_snap < 0:
						_first_snap = _trace.size()
					print("  snap seat %d %s f%d accel %.0f weight %.2f grip %.2f fold %.2f busy %s lean %.2f tile %s speed %.2f" % [seat, side, _frame,
						accel, hand.weight, hand.grip, hand.fold, hand.busy, dayi.lean, hand.tile != null, velocity.length()])
				if accel > float(_worst_accel.get(seat, [0.0])[0]):
					_worst_accel[seat] = [accel, side, _frame]
		if seat == 1 and side == "Right":
			_trace.append("f%d point %s pinch %s wrist %s w%.2f lean %.2f" % [_frame, hand.point.snapped(Vector3.ONE * 0.001),
				hand.pinch.snapped(Vector3.ONE * 0.001), wrist.snapped(Vector3.ONE * 0.001), hand.weight, dayi.lean])
		_last[key] = [wrist, velocity] if not last.is_empty() else [wrist]


func _check_tile(seat: int, side: String, tile: Tile) -> void:
	_tile_count += 1
	var size := TileFactory.SIZE
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var corner := tile.global_transform * (Vector3(sx, sy, sz) * size)
				var depth := 0.0
				var what := ""
				if _over_felt(corner) and corner.y < Table.TOP - FELT_TOLERANCE - 0.003:
					depth = Table.TOP - corner.y
					what = "under felt"
				for other in _director.seats:
					if other.seat_index == seat:
						continue # leaving his own slot is meant to touch his own rack
					var hit := _rack_hit(other.rack, corner)
					if hit[0] > depth:
						depth = hit[0]
						what = "%s of seat %d's rack" % [hit[1], other.seat_index]
				if depth > 0.0:
					var key := "seat %d %s tile" % [seat, side]
					if depth > float(_tile_hits.get(key, [0.0])[0]):
						_tile_hits[key] = [depth, what, _frame]


## How far a world point is inside a rack's board (through its front face, up to its back) or its base, and which.
## The zone in front of the board belongs to the tiles and is where fingers pinch, so it does not count; the way over
## the board's top edge is free. [depth, label]
func _rack_hit(rack: Rack, point: Vector3) -> Array:
	var local := rack.to_local(point)
	if absf(local.x) > Rack.LENGTH * 0.5:
		return [0.0, ""]
	var rel: Vector3 = local - rack._board_origin
	var depth := rel.dot(rack._board.z)
	var height := rel.dot(rack._board.y)
	if height > 0.0 and height < Rack.HEIGHT and depth < -0.003 and depth > -0.025:
		return [-depth - 0.003, "the board"]
	if absf(local.z) < 0.05 and local.y < 0.012 and local.y > -0.05:
		return [0.012 - local.y, "the base"]
	return [0.0, ""]


## 1 when the point went through the board's front face (either way) below its top edge since last frame.
func _crossed(rack: Rack, key: String, point: Vector3) -> float:
	var local := rack.to_local(point)
	var rel: Vector3 = local - rack._board_origin
	var depth := rel.dot(rack._board.z)
	var height := rel.dot(rack._board.y)
	if absf(local.x) > Rack.LENGTH * 0.5 or height > Rack.HEIGHT - 0.01 or height < 0.0:
		_before.erase(key) # over the top, off the end or on the felt: free
		return 0.0
	# Which side it is certainly on: in front of the face (owner's side) or clear behind the board's thickness.
	var side := 1 if depth > 0.0 else (-1 if depth < -0.02 else 0)
	var was: int = _before.get(key, 0)
	if side != 0:
		_before[key] = side
	return 1.0 if side != 0 and was != 0 and side != was else 0.0


func _over_felt(point: Vector3) -> bool:
	return absf(point.x) < Table.SIZE * 0.5 and absf(point.z) < Table.SIZE * 0.5


func _hand_bones(skeleton: Skeleton3D, side: String) -> Array[int]:
	var out: Array[int] = []
	var hand := skeleton.find_bone(RiggedDayi.BONE + side + "Hand")
	out.append(hand)
	for bone in range(hand + 1, skeleton.get_bone_count()):
		if skeleton.get_bone_name(bone).contains(side + "Hand"):
			out.append(bone)
	return out


func _report(watched: int) -> void:
	var fails := 0
	print("LIVE_HANDS dayis=%d frames=%d hand-frames=%d held-tile-frames=%d" % [watched, _frames, _hand_count, _tile_count])
	for key in _hand_hits:
		var hit: Array = _hand_hits[key]
		print("  HAND   %-26s %.1f cm %s (frame %d, %s)" % [key, hit[0] * 100.0, hit[1], hit[2], hit[3]])
		fails += 1
	for key in _crossings:
		print("  CROSS  %-60s %d frames, first at frame %d" % [key, _crossings[key], _first_cross[key]])
		fails += 1
	for key in _tile_hits:
		var hit: Array = _tile_hits[key]
		print("  TILE   %-26s %.1f cm %s (frame %d)" % [key, hit[0] * 100.0, hit[1], hit[2]])
		fails += 1
	for seat in _accel:
		var values: Array = _accel[seat].duplicate()
		values.sort()
		var p99: float = values[int(values.size() * 0.99)]
		var worst: Array = _worst_accel[seat]
		print("  WRIST  seat %d: p99 %.0f m/s2, worst %.0f (%s hand, frame %d), %d working frames" % [seat, p99, worst[0], worst[1], worst[2], values.size()])
	if _first_snap >= 0:
		for i in range(maxi(_first_snap - 16, 0), mini(_first_snap + 12, _trace.size())):
			print("  trace ", _trace[i])
	print("SNAPS over %.0f m/s2: %d" % [_jerk_limit, _snaps])
	# Snapping hands are failures. Fingers grazing a board or the felt are listed above as things still to fix (the
	# worst are fingers 5-9 cm into the felt when a tile is picked up off it) and only fail with --strict.
	var strict := OS.get_cmdline_user_args().has("--strict")
	var failed := _snaps > 0 or (strict and fails > 0)
	print("LIVE_HANDS %s (%d penetrations listed)" % ["FAIL" if failed else "PASS", fails])
	quit(1 if failed else 0)
