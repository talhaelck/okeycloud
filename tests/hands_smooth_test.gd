extends SceneTree
## Measures how smoothly the dayıs' hands move, frame to frame, at 30 fps:
##   1. the clip alone (our modifiers off) is the reference,
##   2. resting with our modifiers on may not jerk more than the clip or bend the wrist much further,
##   3. while handling tiles, no wrist or fingertip may jump.
## "Jerk" is the second difference of a point's position between frames (cm per frame²): a hand gliding along is
## small, a hand that snaps from one frame to the next is large. The wrist angle is how far the hand is turned
## against the forearm (its local rotation from rest). Exits with code 1 on failure.
##   godot --path . --headless --fixed-fps 30 --script tests/hands_smooth_test.gd

const POINTS := ["Hand", "HandIndex4", "HandMiddle4", "HandThumb4"]
const CLIP_SECONDS := 4.2
const REST_JERK_FACTOR := 1.3 # resting may jerk at most this much more than the clip itself...
const REST_JERK_SLACK := 0.15 # ...plus this, in cm
## While handling tiles: a quick human reach peaks around 20-25 m/s², about 2.5 cm per frame² at 30 fps; fingers
## snapping shut on a tile move faster. The jitter this test was written for was 8-18 cm.
const ACTION_JERK := 2.5
const ACTION_JERK_FINGER := 3.5
const WRIST_SLACK := 20.0 # degrees our code may bend a wrist beyond the clip's own most

var _dayis: Array[RiggedDayi] = []
var _phase := ""
var _history := {} # key -> [previous, before previous]
var _jerk := {} # phase -> {key: [cm, at]}
var _wrist := {} # phase -> degrees
var _time := 0.0
var _failures: Array[String] = []


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
	for seat in seats.slice(1):
		for dayi in seat.buddy.find_children("*", "RiggedDayi", true, false):
			_dayis.append(dayi)
			var skeleton: Skeleton3D = dayi.find_children("*", "Skeleton3D", true, false)[0]
			skeleton.skeleton_updated.connect(_sample.bind(dayi, skeleton))

	_set_modifiers(false)
	await _run("clip", CLIP_SECONDS)
	_set_modifiers(true)
	await _run("rest", CLIP_SECONDS)
	_phase = "actions"
	_history.clear()
	var dayi := _dayis[1] # the opposite one, seat 2
	var rack := seats[2].rack
	await dayi.hands.rearrange(rack, 24, rack.nearest_free(24))
	var spot := Vector3(0.48, Table.TOP - Seat.SEAT_TOP, -0.51)
	var tile: Tile = await dayi.hands.discard(rack, 10, table, spot)
	for frame in 30:
		await process_frame
	await dayi.hands.pick_up(tile, table, rack, rack.nearest_free(10))
	_phase = ""

	_report()
	quit(0 if _failures.is_empty() else 1)


func _run(phase: String, seconds: float) -> void:
	_phase = phase
	_history.clear()
	for frame in int(seconds * 30.0):
		await process_frame
	_phase = ""


func _set_modifiers(on: bool) -> void:
	for dayi in _dayis:
		for modifier in dayi.find_children("*", "SkeletonModifier3D", true, false):
			if not modifier is RiggedDayi.HeadTurn:
				modifier.active = on


func _sample(dayi: RiggedDayi, skeleton: Skeleton3D) -> void:
	if _phase.is_empty():
		return
	_time = Time.get_ticks_msec() / 1000.0
	var seat := _dayis.find(dayi) + 1
	for side in ["Left", "Right"]:
		for point in POINTS:
			var bone := skeleton.find_bone(RiggedDayi.BONE + side + point)
			var at := dayi.to_local(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
			var key := "seat %d %s%s" % [seat, side, point]
			if _history.has(key):
				var before: Array = _history[key]
				if before.size() == 2:
					var jerk: float = (at - 2.0 * (before[0] as Vector3) + (before[1] as Vector3)).length() * 100.0
					var table: Dictionary = _jerk.get_or_add(_phase, {})
					if jerk > float(table.get(key, [0.0])[0]):
						table[key] = [jerk, _phase]
				_history[key] = [at, before[0]]
			else:
				_history[key] = [at]
		var hand := skeleton.find_bone(RiggedDayi.BONE + side + "Hand")
		var angle := rad_to_deg((skeleton.get_bone_rest(hand).basis.get_rotation_quaternion().inverse() * skeleton.get_bone_pose_rotation(hand)).get_angle())
		angle = minf(angle, 360.0 - angle)
		_wrist[_phase] = maxf(float(_wrist.get(_phase, 0.0)), angle)


func _report() -> void:
	var clip: Dictionary = _jerk.get("clip", {})
	var rest: Dictionary = _jerk.get("rest", {})
	var actions: Dictionary = _jerk.get("actions", {})
	for key in rest:
		var allowed: float = float(clip.get(key, [0.0])[0]) * REST_JERK_FACTOR + REST_JERK_SLACK
		if float(rest[key][0]) > allowed:
			_failures.append("rest %s jerks %.2f cm (clip alone %.2f)" % [key, rest[key][0], clip.get(key, [0.0])[0]])
	for key in actions:
		# Fingers drumming in the clip may jerk as much as they do there; nothing else may jump.
		var limit := ACTION_JERK if key.ends_with("Hand") else ACTION_JERK_FINGER
		if float(actions[key][0]) > maxf(limit, float(clip.get(key, [0.0])[0]) * REST_JERK_FACTOR + REST_JERK_SLACK):
			_failures.append("actions %s jerks %.2f cm" % [key, actions[key][0]])
	var wrist_clip: float = _wrist.get("clip", 0.0)
	for phase in ["rest", "actions"]:
		if float(_wrist.get(phase, 0.0)) > wrist_clip + WRIST_SLACK:
			_failures.append("%s bends a wrist %.0f° (clip alone at most %.0f°)" % [phase, _wrist[phase], wrist_clip])
	print("HANDS_SMOOTH %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	for phase in ["clip", "rest", "actions"]:
		var worst := 0.0
		var worst_key := ""
		for key in _jerk.get(phase, {}):
			if float(_jerk[phase][key][0]) > worst:
				worst = _jerk[phase][key][0]
				worst_key = key
		print("  %-8s worst jerk %.2f cm (%s), wrist up to %.0f°" % [phase, worst, worst_key, _wrist.get(phase, 0.0)])
	for failure in _failures.slice(0, 12):
		print("  FAIL: ", failure)
	if _failures.size() > 12:
		print("  ... and %d more" % (_failures.size() - 12))
