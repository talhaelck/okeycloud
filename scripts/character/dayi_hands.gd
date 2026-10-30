class_name DayiHands
extends SkeletonModifier3D
## A seated RiggedDayi's hands handling real tiles, on top of his mocap clip. Runs after the clip and HandsOnTable.
## Per hand, `weight` blends from the clip (0) to the action (1): the pinch point between thumb and index tips is
## carried to `point` by arm IK, the wrist bends the fingers down by `flex` (the clip's wrist otherwise kept), and the
## fingers close by `grip`.
## A held tile is locked to the hand (a socket: the tile keeps the offset it had when pinched), so it really is in
## his hand wherever the hand goes, and is handed to the rack or the felt when let go.
## The actions (rearrange, discard, pick_up) are timed like a person: the head turns first, the body leans in,
## the hand speeds up and settles, fingers close, the tile is lifted, carried on an arc and set down.
## Points and directions are in the dayı's space (Buddy space: origin on the seat, -Z toward the table centre).

const BONE := "mixamorig_"
## Extra curl in degrees per joint when pinching: thumb and index meet, the other three fold into the palm (left
## sticking out, the long middle finger went through the rack board).
const PINCH := {
	"Thumb": [8.0, 18.0, 16.0], "Index": [22.0, 30.0, 20.0], "Middle": [58.0, 68.0, 42.0],
	"Ring": [64.0, 72.0, 46.0], "Pinky": [68.0, 74.0, 48.0],
}
const REACH_TIME := 0.6
const SETTLE_TIME := 0.18
const CARRY_TIME := 0.55
const LIFT := 0.035 # tiles come this far up off the felt before being carried
## Out of a rack slot a tile comes all the way up before it moves sideways, so it never slides through its neighbours.
const RACK_LIFT := TileFactory.SIZE.y + 0.02
const ARC := 0.06 # carried tiles rise this high mid-way
const LEAN := 0.4 # radians the upper body leans in for the farthest reach
## How far the wrist bends the fingers down to pinch: a tile in the rack (bending more only drives the folded
## fingers into the board, measured), a tile on the felt.
## The wrist only flexes, about the hand's own axis; it is never twisted (the rig has no twist bones), so it can
## neither flip over nor wring the wrist.
const RACK_FLEX := 0.0
const FELT_FLEX := 25.0
## A natural elbow direction (out, down, back) in the dayı's space for his right arm; x flips for the left.
const ELBOW := Vector3(0.6, -0.6, 0.5)
const LEAN_SPEED := 0.9 # radians per second the body leans in or straightens up
const EASY_REACH := 0.75 # of his arm's length: closer than this he does not lean at all

## How far (radians) he leans in for a reach at arm's length: LEAN normally, STRETCH while snatching something far.
const STRETCH := 0.6
const PULL_BEYOND := 0.10 # how far past his rack's board he puts his fingers to drag a tile from the pile
const BOARD_CLEARANCE := 0.05 # the pinch point passes this far above a rack's top edge
const WRIST_CLEARANCE := 0.09 # the wrist, which has the fingers hanging in front of it
const OFFSET_EASE := 0.3 # share of the pinch offset's change taken per frame (see _pose)

const LEAN_TURN := 2.0 # how fast the way he leans swings round (per second, eased)

var dayi: RiggedDayi
var hands: Array[HandState] = []
var lean_limit := LEAN
var _lean_goal := Vector3.FORWARD


class HandState:
	var side := "Right"
	var sign := 1.0 # +1 for his right hand (+X), -1 for his left
	var upper := -1
	var lower := -1
	var wrist := -1
	var fingers := {} # finger name -> [joint 1, 2, 3, tip]
	var palm_sign := 1.0
	var weight := 0.0
	var grip := 0.0
	var offset := Vector3.ZERO # wrist to pinch point as it was last frame, in the dayı's space
	var fold := 0.0 # middle, ring and pinky folded into the palm while reaching, before thumb and index close
	var point := Vector3.ZERO
	var flex := 0.0 # degrees the wrist bends the fingers toward the palm (scaled by weight)
	var pinch := Vector3.ZERO # where the pinch point is now
	var tile: Tile
	var tile_offset := Transform3D()
	var attach: Tile # set by an action; locked to the hand inside the modifier, where the hand's real pose exists
	var flat := 0.0 # 0 = the tile as pinched, 1 = laid flat at flat_pose (fingers turning it to set it down)
	var flat_pose := Transform3D()
	var busy := false
	var action := "" # what he is doing now (tests and debugging read it)
	var lean := 0.0 # 0..1, how much this hand's current target needs him to lean in
	var arm := 0.5 # shoulder to wrist, fully stretched
	var miss := 0.0 # how far the pinch point was from the tile when it closed (tests check this)


func setup(owner_dayi: RiggedDayi) -> void:
	dayi = owner_dayi
	var skeleton := get_skeleton()
	for side in ["Left", "Right"]:
		var hand := HandState.new()
		hand.side = side
		hand.sign = -1.0 if side == "Left" else 1.0
		hand.upper = skeleton.find_bone(BONE + side + "Arm")
		hand.lower = skeleton.find_bone(BONE + side + "ForeArm")
		hand.wrist = skeleton.find_bone(BONE + side + "Hand")
		var rest := func(bone: int) -> Vector3: return skeleton.get_bone_global_rest(bone).origin
		hand.arm = (rest.call(hand.upper) - rest.call(hand.lower)).length() + (rest.call(hand.lower) - rest.call(hand.wrist)).length()
		hand.arm *= skeleton.global_basis.get_scale().x
		for finger in PINCH:
			var joints: Array[int] = []
			for j in range(1, 5):
				joints.append(skeleton.find_bone("%s%sHand%s%d" % [BONE, side, finger, j]))
			if joints.min() >= 0:
				hand.fingers[finger] = joints
		if not (hand.fingers.has("Thumb") and hand.fingers.has("Index") and hand.fingers.has("Middle")):
			return # a rig without a thumb cannot pinch: he sits and moves, but leaves the tiles alone (hands stays empty)
		# Which way the palm normal points is read off the seated clip, where his hands lie on the table palm down
		# (the A-pose rest has the palms facing the thighs, which leaves it ambiguous and could flip a hand over).
		var pose := func(bone: int) -> Vector3: return skeleton.get_bone_global_pose(bone).origin
		var along: Vector3 = pose.call(hand.fingers.Middle[0]) - pose.call(hand.wrist)
		var across: Vector3 = pose.call(hand.fingers.Index[0]) - pose.call(_outer(hand)[0])
		var down := skeleton.global_basis.inverse() * Vector3.DOWN
		hand.palm_sign = 1.0 if along.cross(across).dot(down) > 0.0 else -1.0
		hands.append(hand)


func hand_for(point: Vector3) -> HandState:
	return hands[1] if point.x >= 0.0 else hands[0]


# --- Actions -----------------------------------------------------------------------------------------------

## Picks the tile in `from` up and puts it into the free slot `to` on the same rack.
func rearrange(rack: Rack, from: int, to: int) -> void:
	var tile := rack.tile_at(from)
	var hand := hand_for(_slot_top(rack, from))
	if tile == null or hand.busy or rack.tile_at(to) != null:
		return
	hand.busy = true
	hand.action = "rearrange"
	await _take(hand, _slot_top(rack, from), RACK_FLEX, func() -> void: rack.release(tile), tile, RACK_LIFT)
	await _carry(hand, _slot_top(rack, to) + Vector3.UP * RACK_LIFT, CARRY_TIME)
	await _move(hand, _slot_top(rack, to), SETTLE_TIME * 1.4)
	rack.put(_let_go(hand), to, true, 0.1)
	await _retreat(hand)


## Takes the tile in `slot` off the rack and sets it down on the felt at `spot` (a point on the felt): while the
## hand comes down the fingers turn it face up, readable for him, and let go just above the felt; it lands by physics,
## or `place` (if given) is handed the tile to put it somewhere itself (his discard row).
func discard(rack: Rack, slot: int, table: Table, spot: Vector3, place := Callable()) -> Tile:
	var tile := rack.tile_at(slot)
	var hand := hand_for(spot)
	if tile == null or hand.busy:
		return null
	hand.busy = true
	hand.action = "discard"
	await _take(hand, _slot_top(rack, slot), RACK_FLEX, func() -> void: rack.release(tile), tile, RACK_LIFT)
	var yaw := dayi.global_rotation.y
	var at := table.to_local(dayi.to_global(spot))
	at.y = Table.TOP + TileFactory.SIZE.z * 0.5 + Table.DROP_HEIGHT
	hand.flat_pose = table.global_transform * Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), at)
	var release := spot + Vector3.UP * (TileFactory.SIZE.z + Table.DROP_HEIGHT + 0.006)
	# Out over the end of the rack at the height it left the slot, then down beside it.
	var over := Vector3(spot.x, hand.point.y, spot.z)
	_plan_lean(hand, spot)
	await _carry(hand, over, CARRY_TIME, FELT_FLEX)
	await _carry(hand, release + Vector3.UP * 0.05, CARRY_TIME * 0.6, -1.0, 0.0)
	var lay := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lay.tween_property(hand, "flat", 1.0, SETTLE_TIME * 1.5)
	await _move(hand, release, SETTLE_TIME * 1.5)
	if place.is_valid():
		place.call(_let_go(hand))
	else:
		table.put_loose(_let_go(hand), dayi.to_global(spot), yaw)
	hand.flat = 0.0
	await _retreat(hand)
	return tile


## Can he reach a point (his space) without stretching his arm out straight?
func reachable(point: Vector3) -> bool:
	if hands.is_empty():
		return false
	var hand := hand_for(point)
	return _shoulder(hand).distance_to(point) < hand.arm * 0.92


## A tile lying too far away (the middle of the pile): he reaches as far as he comfortably can, the tile slides
## under his fingers and he drags it across the felt to `spot` (his space), where he can pick it up.
func pull(tile: Tile, spot: Vector3) -> void:
	var start := dayi.to_local(tile.global_position)
	var hand := hand_for(spot)
	if hand.busy:
		return
	hand.busy = true
	hand.action = "pull"
	var shoulder := _shoulder(hand)
	var reach := shoulder + (start - shoulder).limit_length(hand.arm * 0.9)
	reach.z = minf(reach.z, _board_face_z() - PULL_BEYOND) # his fingers end up beyond his own rack, not in it
	reach.y = spot.y + TileFactory.SIZE.z
	dayi.look_at_point(start)
	_plan_lean(hand, reach)
	hand.point = hand.pinch
	hand.flex = FELT_FLEX
	var blend := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	blend.tween_property(hand, "weight", 1.0, REACH_TIME)
	blend.tween_property(hand, "fold", 0.6, REACH_TIME)
	# The tile comes to meet the fingertips while the hand goes out (he slides it toward himself with two fingers).
	var from := tile.global_position
	var meet := dayi.to_global(Vector3(reach.x, start.y, reach.z))
	var slide := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_interval(REACH_TIME * 0.5)
	slide.tween_method(func(t: float) -> void: tile.global_position = from.lerp(meet, t), 0.0, 1.0, REACH_TIME * 0.6)
	await _carry(hand, reach + Vector3.UP * 0.02, REACH_TIME)
	await _move(hand, reach, SETTLE_TIME)
	_plan_lean(hand, spot)
	var back := create_tween()
	var flat := start.y
	back.tween_method(func(t: float) -> void:
		var e := smoothstep(0.0, 1.0, t)
		hand.point = reach.lerp(Vector3(spot.x, reach.y, spot.z), e)
		tile.global_position = dayi.to_global(Vector3(hand.point.x, flat, hand.point.z))
	, 0.0, 1.0, CARRY_TIME * 1.3)
	await back.finished
	hand.busy = false


## The farthest point toward `point` (his space) he reaches without locking his arm straight.
func clamp_reach(point: Vector3, share := 0.92) -> Vector3:
	var hand := hand_for(point)
	var shoulder := _shoulder(hand)
	return shoulder + (point - shoulder).limit_length(hand.arm * share)


## Where a hand's pinch point (thumb and index tips) is now, in world space.
func pinch_world(hand: HandState) -> Vector3:
	return dayi.to_global(hand.pinch)


## Takes a tile from too far away (a neighbour's rack, a far discard row) into the free slot `to` of `rack`: he
## leans right over the table (STRETCH) and stretches out; the last stretch the tile comes to his fingertips by
## itself (out of its slot first if it stands in one), as if he had plucked it. `detach` takes it off its holder
## and returns true, or returns false to call it off (he was seen reaching): then his hand comes back empty.
func snatch(tile: Tile, detach: Callable, rack: Rack, to: int) -> void:
	var at := dayi.to_local(tile.global_position)
	var hand := hand_for(at)
	if hand.busy or rack.tile_at(to) != null:
		return
	hand.busy = true
	hand.action = "snatch"
	lean_limit = STRETCH
	var standing := absf(tile.global_basis.z.normalized().y) < 0.7
	var top := at + Vector3.UP * ((TileFactory.SIZE.y if standing else TileFactory.SIZE.z) * 0.5 + 0.004)
	var reach := clamp_reach(top, 0.97)
	reach.y = maxf(reach.y, top.y)
	dayi.look_at_point(top)
	_plan_lean(hand, top)
	hand.point = hand.pinch
	hand.flex = RACK_FLEX if standing else FELT_FLEX
	var blend := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	blend.tween_property(hand, "weight", 1.0, REACH_TIME * 1.2)
	blend.tween_property(hand, "fold", 1.0, REACH_TIME)
	await _carry(hand, reach + Vector3.UP * 0.04, REACH_TIME * 1.2)
	await _move(hand, reach, SETTLE_TIME)
	if not detach.call():
		await _retreat(hand)
		lean_limit = LEAN
		return
	tile.pin()
	tile.holder = null
	var from := tile.global_transform
	var up := from.basis.y.normalized() if standing else Vector3.UP
	var lifted := from.origin + Vector3.UP * (RACK_LIFT if standing else LIFT)
	var glide := create_tween()
	glide.tween_method(func(t: float) -> void:
		var e := smoothstep(0.0, 1.0, t)
		var into := pinch_world(hand) - up * (TileFactory.SIZE.y * 0.5 + 0.004 if standing else 0.0)
		var path := from.origin.lerp(lifted, minf(e * 2.0, 1.0)) if e < 0.5 else lifted.lerp(into, (e - 0.5) * 2.0)
		tile.global_position = path
	, 0.0, 1.0, CARRY_TIME)
	await glide.finished
	await _close(hand, 1.0)
	hand.attach = tile
	await get_tree().process_frame
	var above := _slot_top(rack, to) + Vector3.UP * RACK_LIFT
	_plan_lean(hand, above)
	await _carry(hand, above, CARRY_TIME * 1.3)
	await _move(hand, _slot_top(rack, to), SETTLE_TIME * 1.4)
	rack.put(_let_go(hand), to, true, 0.1)
	await _retreat(hand)
	lean_limit = LEAN


## Takes the tile in `slot` of his rack and hands it over toward `toward` (his space): he reaches as far as he
## comfortably can that way and lets go just above the table; `place` gets the tile and puts it where it belongs
## (it glides the rest of the way), e.g. into a neighbour's rack.
func hand_over(rack: Rack, slot: int, toward: Vector3, place: Callable) -> Tile:
	var tile := rack.tile_at(slot)
	var hand := hand_for(toward)
	if tile == null or hand.busy:
		return null
	hand.busy = true
	hand.action = "hand_over"
	lean_limit = STRETCH
	await _take(hand, _slot_top(rack, slot), RACK_FLEX, func() -> void: rack.release(tile), tile, RACK_LIFT)
	var reach := clamp_reach(toward, 0.97)
	reach.y = maxf(reach.y, toward.y + 0.06)
	_plan_lean(hand, toward)
	dayi.look_at_point(toward)
	await _carry(hand, reach, CARRY_TIME * 1.4)
	place.call(_let_go(hand))
	await _retreat(hand)
	lean_limit = LEAN
	return tile


## Reaches toward a point on the table (his space) and back, as when laying tiles out or pushing them over.
func gesture(point: Vector3, time := 0.8) -> void:
	var hand := hand_for(point)
	if hand.busy:
		return
	hand.busy = true
	hand.action = "gesture"
	var shoulder := _shoulder(hand)
	var reach := shoulder + (point - shoulder).limit_length(hand.arm * 0.88)
	reach.y = maxf(reach.y, point.y + 0.03)
	dayi.look_at_point(point)
	_plan_lean(hand, reach)
	hand.point = hand.pinch
	hand.flex = FELT_FLEX
	var blend := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	blend.tween_property(hand, "weight", 1.0, REACH_TIME)
	blend.tween_property(hand, "fold", 0.3, REACH_TIME)
	await _carry(hand, reach, REACH_TIME)
	await get_tree().create_timer(time * 0.5).timeout
	await _retreat(hand)


func _shoulder(hand: HandState) -> Vector3:
	var skeleton := get_skeleton()
	return dayi.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hand.upper).origin))


## Picks a loose tile up from the felt and puts it into the free slot `to`.
func pick_up(tile: Tile, table: Table, rack: Rack, to: int) -> void:
	var top := dayi.to_local(tile.global_position) + Vector3.UP * TileFactory.SIZE.z * 0.5
	var hand := hand_for(top)
	if hand.busy or rack.tile_at(to) != null:
		return
	hand.busy = true
	hand.action = "pick_up"
	await _take(hand, top, FELT_FLEX, func() -> void: table.release(tile), tile)
	# Straight up to above the rack's tiles, across, and down into the slot.
	var above := _slot_top(rack, to) + Vector3.UP * RACK_LIFT
	_plan_lean(hand, above)
	await _carry(hand, Vector3(top.x, above.y, top.z), CARRY_TIME * 0.6, RACK_FLEX, 0.0)
	await _carry(hand, above, CARRY_TIME)
	await _move(hand, _slot_top(rack, to), SETTLE_TIME * 1.4)
	rack.put(_let_go(hand), to, true, 0.1)
	await _retreat(hand)


# Head first, then the arm: reach just above `top`, settle onto it, pinch, and lift the tile out.
func _take(hand: HandState, top: Vector3, flex: float, detach: Callable, tile: Tile, lift := LIFT) -> void:
	dayi.look_at_point(top)
	_plan_lean(hand, top)
	await get_tree().create_timer(0.15).timeout
	hand.point = hand.pinch
	hand.flex = flex
	var blend := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	blend.tween_property(hand, "weight", 1.0, REACH_TIME)
	# The hand shapes itself on the way, as people's do: three fingers fold, thumb and index stay open to pinch.
	blend.tween_property(hand, "fold", 1.0, REACH_TIME * 0.8)
	await _carry(hand, top + Vector3.UP * 0.03, REACH_TIME)
	await _move(hand, top, SETTLE_TIME)
	hand.miss = hand.pinch.distance_to(top)
	await _close(hand, 1.0)
	detach.call()
	tile.pin()
	tile.holder = null
	# The offset has to be taken from the hand as posed by this modifier. Out here Godot only shows the clip's pose
	# (modifier results are dropped after each frame), which put the tile 30 cm from his fingers.
	hand.attach = tile
	await get_tree().process_frame
	await _move(hand, top + Vector3.UP * lift, SETTLE_TIME * (1.0 + lift * 6.0))


# Opens the fingers on the held tile and returns it (the caller puts it somewhere).
func _let_go(hand: HandState) -> Tile:
	var tile := hand.tile
	hand.tile = null
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(hand, "grip", 0.0, 0.2)
	return tile


# The hand comes back up and the clip takes the arm over again; the head goes back to the table.
func _retreat(hand: HandState) -> void:
	await get_tree().create_timer(0.12).timeout
	_move(hand, hand.point + Vector3(0, 0.05, 0.08), REACH_TIME)
	var blend := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	blend.tween_property(hand, "weight", 0.0, REACH_TIME)
	blend.tween_property(hand, "fold", 0.0, REACH_TIME)
	dayi.look_at_point(Vector3.ZERO, true)
	await blend.finished
	hand.busy = false


func _close(hand: HandState, amount: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hand, "grip", amount, 0.22)
	await tween.finished


## Moves the pinch point in a straight eased line.
func _move(hand: HandState, to: Vector3, time: float) -> void:
	await _carry(hand, to, time, -1.0, 0.0)


## Moves the pinch point along an arc that rises `arc` mid-way, easing in and out; bends the wrist to `flex` if given.
func _carry(hand: HandState, to: Vector3, time: float, flex := -1.0, arc := ARC) -> void:
	var from := hand.point
	var from_flex := hand.flex
	var to_flex := from_flex if flex < 0.0 else flex
	var path := _board_safe_path(from, to)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var e := smoothstep(0.0, 1.0, t)
		hand.point = _point_on(path, e) + Vector3.UP * arc * sin(PI * e)
		hand.flex = lerpf(from_flex, to_flex, e)
	, 0.0, 1.0, time)
	await tween.finished


# Where he pinches a tile in a rack slot: the top edge, on his side of it. The board stands 2 cm above the tiles, so
# pinching the middle of the top put his knuckles against the board.
func _slot_top(rack: Rack, slot: int) -> Vector3:
	var at := rack.slot_global_transform(slot)
	var toward_him := at.basis.z.normalized() * TileFactory.SIZE.z * 0.5
	return dayi.to_local(at.origin + at.basis.y.normalized() * (TileFactory.SIZE.y * 0.5 + 0.004) + toward_him)


# Where the front face of his own rack's board is along his forward axis (his space).
func _board_face_z() -> float:
	var seat := dayi.get_parent().get_parent() as Seat if dayi.get_parent() else null
	if seat == null or seat.rack == null:
		return -INF
	return dayi.to_local(seat.rack.to_global(seat.rack._board_origin)).z


# A straight line from `from` to `to` (his space), unless it would go through his own rack's board: then up over the
# board's top edge, across, and down on the other side. Hands cross the board only above it, like real ones.
func _board_safe_path(from: Vector3, to: Vector3, clearance := BOARD_CLEARANCE) -> Array[Vector3]:
	var seat := dayi.get_parent().get_parent() as Seat if dayi.get_parent() else null
	if seat == null or seat.rack == null:
		return [from, to]
	var rack := seat.rack
	var side_of := func(point: Vector3) -> float:
		var local := rack.to_local(dayi.to_global(point)) - rack._board_origin
		return local.dot(rack._board.z)
	var before: float = side_of.call(from)
	var after: float = side_of.call(to)
	if (before > -0.01) == (after > -0.01):
		return [from, to]
	var clear := _clear_height(rack, maxf(from.y, to.y), clearance)
	return _rounded([from, Vector3(from.x, clear, from.z), Vector3(to.x, clear, to.z), to])


# Cuts the corners of a path (two rounds of Chaikin) so the hand arcs over the board instead of turning sharply.
func _rounded(path: Array[Vector3]) -> Array[Vector3]:
	for round in 2:
		var next: Array[Vector3] = [path[0]]
		for i in path.size() - 1:
			next.append(path[i].lerp(path[i + 1], 0.25))
			next.append(path[i].lerp(path[i + 1], 0.75))
		next.append(path[-1])
		path = next
	return path


## The point `fraction` (0..1) of the way along a path, by length.
func _point_on(path: Array[Vector3], fraction: float) -> Vector3:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var along := clampf(fraction, 0.0, 1.0) * total
	for i in path.size() - 1:
		var length := path[i].distance_to(path[i + 1])
		if along <= length or i == path.size() - 2:
			return path[i].lerp(path[i + 1], clampf(along / maxf(length, 0.0001), 0.0, 1.0))
		along -= length
	return path[-1]


# The height (his space) at which the pinch point passes over `rack`'s board without touching it: the board's top edge
# plus a hand's thickness, or `at_least` if that is higher already. Moving across the board at tile height pushed the
# fingers through it (tests/live_hands_audit.gd).
func _clear_height(rack: Rack, at_least := 0.0, clearance := BOARD_CLEARANCE) -> float:
	return maxf(dayi.to_local(rack.top_edge()).y + clearance, at_least)


# How much a reach to `point` needs him to lean in: none within an easy reach of the shoulder, fully at arm's length.
func _plan_lean(hand: HandState, point: Vector3) -> void:
	var shoulder := _shoulder(hand)
	var level := Vector3(point.x, 0.0, point.z)
	if level.length() > 0.05:
		_lean_goal = level.normalized() # from his middle toward the point; the body swings there gently
	hand.lean = clampf((shoulder.distance_to(point) / hand.arm - EASY_REACH) / (1.0 - EASY_REACH), 0.0, 1.0)


func _hand_world(hand: HandState) -> Transform3D:
	var skeleton := get_skeleton()
	return skeleton.global_transform * skeleton.get_bone_global_pose(hand.wrist)


# --- Posing ------------------------------------------------------------------------------------------------

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if dayi == null or hands.is_empty():
		return
	var to_dayi := dayi.global_transform.affine_inverse() * skeleton.global_transform
	var to_skeleton := to_dayi.affine_inverse()
	var lean := 0.0
	for hand in hands:
		lean = maxf(lean, hand.weight * hand.lean)
		if hand.weight > 0.001 or hand.grip > 0.001 or hand.fold > 0.001:
			_pose(skeleton, hand, to_skeleton)
		hand.pinch = to_dayi * _pinch_point(skeleton, hand)
		if hand.attach:
			hand.tile = hand.attach
			hand.tile_offset = _hand_world(hand).affine_inverse() * hand.tile.global_transform
			hand.attach = null
		if hand.weight <= 0.001:
			hand.offset = to_dayi.basis * (_pinch_point(skeleton, hand) - skeleton.get_bone_global_pose(hand.wrist).origin)
		if hand.tile:
			var held := _hand_world(hand) * hand.tile_offset
			hand.tile.global_transform = held.interpolate_with(hand.flat_pose, hand.flat) if hand.flat > 0.0 else held
	# Ease the body toward the lean the reach needs; changing targets mid-reach must not jolt him.
	dayi.lean = move_toward(dayi.lean, lean * lean_limit, LEAN_SPEED * get_process_delta_time())
	dayi.lean_dir = dayi.lean_dir.slerp(_lean_goal, minf(1.0, LEAN_TURN * get_process_delta_time())).normalized()


func _pose(skeleton: Skeleton3D, hand: HandState, to_skeleton: Transform3D) -> void:
	var clip_wrist := skeleton.get_bone_global_pose(hand.wrist).origin
	var pole := to_skeleton.basis * (ELBOW * Vector3(hand.sign, 1, 1))
	_flex(skeleton, hand, skeleton.get_bone_pose_rotation(hand.wrist))
	# The clip drums its fingers; a hand doing something should not, or the pinch opens and shuts around the tile.
	# So the fingers start from their straight rest pose (blended in by the weight) and only our curl shapes them.
	for finger: String in hand.fingers:
		for j in 3:
			var bone: int = hand.fingers[finger][j]
			var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(rest, hand.weight))
	# Each finger bends about one axis taken from its base segment before bending: a joint's own direction turns
	# toward the palm normal as it folds, and crossing the two then flipped the axis and flicked the fingertip.
	var palm := _palm_normal(skeleton, hand)
	for finger: String in hand.fingers:
		var joints: Array = hand.fingers[finger]
		var base: Vector3 = skeleton.get_bone_global_pose(joints[1]).origin - skeleton.get_bone_global_pose(joints[0]).origin
		var axis := base.cross(palm)
		var amount := hand.grip if finger in ["Thumb", "Index"] else maxf(hand.grip, hand.fold)
		for j in 3:
			ArmIK.turn(skeleton, joints[j], axis, deg_to_rad(PINCH[finger][j] * amount))
	# Carry the pinch point to its goal with the arm. The wrist-to-pinch offset depends on where the arm ends up, so
	# use last frame's (it changes slowly) instead of re-solving in a loop, which flickered between two answers.
	var to_dayi := to_skeleton.affine_inverse()
	# The wrist leaves the clip's place and arrives at the goal along the same board-safe path the pinch point takes: a
	# straight blend between them went through the rack's board whenever the goal lay beyond it.
	var goal_d := hand.point - hand.offset
	var wrist_d := to_dayi * clip_wrist
	var target := to_skeleton * _point_on(_board_safe_path(wrist_d, goal_d, WRIST_CLEARANCE), hand.weight)
	ArmIK.reach(skeleton, hand.upper, hand.lower, hand.wrist, target, pole)
	# Only a fraction of the change is taken each frame: with the arm near full stretch the offset reacts so strongly to
	# where the wrist ends up that taking all of it made the hand flip between two poses every frame (the jitter at far
	# reaches that tests/live_hands_audit.gd found), the swing growing with every step.
	var measured := to_dayi.basis * (_pinch_point(skeleton, hand) - skeleton.get_bone_global_pose(hand.wrist).origin)
	hand.offset = hand.offset.lerp(measured, OFFSET_EASE)


# The clip's wrist, bent so the fingers come down toward the palm by `flex` (scaled by the weight): a rotation about
# the hand's own side-to-side axis only.
func _flex(skeleton: Skeleton3D, hand: HandState, clip_local: Quaternion) -> void:
	skeleton.set_bone_pose_rotation(hand.wrist, clip_local)
	var wrist := skeleton.get_bone_global_pose(hand.wrist)
	var along := skeleton.get_bone_global_pose(hand.fingers.Middle[0]).origin - wrist.origin
	var axis := along.cross(_palm_normal(skeleton, hand))
	ArmIK.turn(skeleton, hand.wrist, axis, deg_to_rad(hand.flex) * hand.weight)


func _pinch_point(skeleton: Skeleton3D, hand: HandState) -> Vector3:
	var thumb: Vector3 = skeleton.get_bone_global_pose(hand.fingers.Thumb[3]).origin
	var index: Vector3 = skeleton.get_bone_global_pose(hand.fingers.Index[3]).origin
	return (thumb + index) * 0.5


func _palm_normal(skeleton: Skeleton3D, hand: HandState) -> Vector3:
	var along := skeleton.get_bone_global_pose(hand.fingers.Middle[0]).origin - skeleton.get_bone_global_pose(hand.wrist).origin
	var across := skeleton.get_bone_global_pose(hand.fingers.Index[0]).origin - skeleton.get_bone_global_pose(_outer(hand)[0]).origin
	return (along.cross(across) * hand.palm_sign).normalized()


# The outermost finger: the pinky, or the ring finger on a rig without one.
func _outer(hand: HandState) -> Array:
	return hand.fingers.get("Pinky", hand.fingers.Ring)
