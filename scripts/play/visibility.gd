class_name Visibility
extends Node
## Who can see what at the table (docs/design/stealing.md). Each seat says how it is looking (Seat.look_mode,
## Seat.look_dir); sees() turns that into how well a point is seen from there:
##   SEEN (1) in plain view, GLIMPSE (0.5) out of the corner of the eye, 0 not at all.
## - Observing: plain view within 35° of the head direction, the corner of the eye out to 70°.
## - Reading his rack: only his own rack and what is right at it (a hand in his rack is seen).
## - Bent over the table: the whole table from above, except his own rack under him and the strip in front of it.
## Someone walking between (group "view_blockers", the çaycı) hides what is behind him.
## Thefts are watched every frame: whoever has the evidence in plain view for WITNESS_TIME in total (glances add
## up, a single blink does not count) becomes a witness, which is what "Yakala!" needs. The evidence is the thief's
## hand once it is away from his own place (a hand busy at one's own rack is nothing to see), the tile once it
## has left where it lay, and for the first PLUCK_TIME the spot it was taken from (the hand is there, plucking it:
## however fast a thief is, that moment can be seen).

signal witnessed(event: TheftEvent, viewer: int)
## Someone caught a movement out of the corner of the eye (once per event and viewer).
signal glimpsed(event: TheftEvent, viewer: int)

const SEEN := 1.0
const GLIMPSE := 0.5
const DIRECT := deg_to_rad(35.0)
const SIDE := deg_to_rad(70.0)
const WITNESS_TIME := 0.3
const OWN_RACK := 0.32 # how close to his rack's middle (seat space, across) a point is still "at his rack"
const AFTER := 0.4 # a theft stays watchable this long after the hand let go (the hand is still pulling back)
const PLUCK_TIME := 0.5
## A player's own place, in his seat space: his rack, the felt in front of it and the corners beside it.
const OWN_PLACE_X := 0.55
const OWN_PLACE_Z := 0.3

var seats: Array[Seat] = []
var events: Array[TheftEvent] = []
## How long finished events are remembered (the "Yakala!" window).
var memory := 4.0
var _clock := 0.0


class TheftEvent:
	var thief := -1
	## "rack" (from someone's rack), "discard" (from a discard row), "pile" (the pile out of turn), "plant" (one of
	## his own tiles put into someone's rack), "dump" (one of his tiles slipped into the pile).
	var kind := ""
	var tile: Tile
	var tile_id := -1 # kept: a tile slipped into the pile stops being a node
	var victim := -1 # whose rack or discard row, -1 for the pile
	var origin_point := Vector3.ZERO # where the tile was when the theft began
	var from_slot := -1 # where in it (rack slot or discard index)
	var started := 0.0
	var ended := -1.0
	var exposure: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var witnesses: Array[int] = []
	var glimpsed: Array[int] = []
	var caught := false
	## Where the thief's hand is (world); by default the stolen tile itself.
	var hand: Callable

	func active() -> bool:
		return ended < 0.0

	func hand_point() -> Vector3:
		if hand.is_valid():
			return hand.call()
		return tile.global_position if is_instance_valid(tile) else Vector3.ZERO


## Game time in seconds (what exposure, the pluck moment and the catch window are measured in).
func now() -> float:
	return _clock


## How well `viewer` sees a world point right now: SEEN, GLIMPSE or 0.
func sees(viewer: int, point: Vector3) -> float:
	var seat := seats[viewer]
	var local := seat.to_local(point)
	var at_own_rack := absf(local.x) < Rack.LENGTH * 0.5 + 0.08 and absf(local.z - Seat.RACK_DISTANCE) < OWN_RACK
	match seat.look_mode:
		FocusCamera.Mode.RACK:
			return SEEN if at_own_rack and _clear(seat.eye_point(), point) else 0.0
		FocusCamera.Mode.LEAN:
			if at_own_rack or local.z > Seat.LEAN_BLIND:
				return 0.0
			return SEEN if _clear(seat.eye_point(), point) else 0.0
	var eye := seat.eye_point()
	var to := point - eye
	if to.length() < 0.001:
		return SEEN
	var angle := seat.look_dir.angle_to(to)
	if angle > SIDE or not _clear(eye, point):
		return 0.0
	return SEEN if angle <= DIRECT else GLIMPSE


## Starts watching a theft (the tile is in the thief's hand now).
func begin(thief: int, kind: String, tile: Tile, victim := -1, from_slot := -1) -> TheftEvent:
	var event := TheftEvent.new()
	event.thief = thief
	event.kind = kind
	event.tile = tile
	event.tile_id = tile.id
	event.origin_point = tile.global_position
	event.victim = victim
	event.from_slot = from_slot
	event.started = now()
	events.append(event)
	return event


## The hand has let go: the theft is done (it stays watchable for a moment while the hand pulls back).
func finish(event: TheftEvent) -> void:
	if event and event.active():
		event.ended = now()


## Forgets an attempt that never happened (the tile went straight back).
func cancel(event: TheftEvent) -> void:
	events.erase(event)


## The thief's newest theft that "Yakala!" can still catch: in progress or ended within `window` seconds.
func catchable(thief: int, window: float) -> TheftEvent:
	var t := now()
	for i in range(events.size() - 1, -1, -1):
		var event := events[i]
		if event.thief == thief and not event.caught and (event.active() or t - event.ended <= window):
			return event
	return null


## Everything the thief did that has not been caught yet and is still remembered.
func open_events(thief: int) -> Array[TheftEvent]:
	var out: Array[TheftEvent] = []
	for event in events:
		if event.thief == thief and not event.caught:
			out.append(event)
	return out


func _process(delta: float) -> void:
	_clock += delta
	var t := now()
	for i in range(events.size() - 1, -1, -1):
		var event := events[i]
		if not event.active() and t - event.ended > maxf(memory, AFTER):
			events.remove_at(i)
			continue
		if event.caught or not (is_instance_valid(event.tile) or event.hand.is_valid()):
			continue
		if not event.active() and t - event.ended > AFTER:
			continue
		var points := evidence(event)
		for viewer in seats.size():
			if viewer == event.thief:
				continue
			var seen := 0.0
			for point in points:
				seen = maxf(seen, sees(viewer, point))
			if seen >= SEEN:
				event.exposure[viewer] += delta
				if event.exposure[viewer] >= WITNESS_TIME and not event.witnesses.has(viewer):
					event.witnesses.append(viewer)
					witnessed.emit(event, viewer)
			elif seen >= GLIMPSE and not event.glimpsed.has(viewer):
				event.glimpsed.append(viewer)
				glimpsed.emit(event, viewer)


## What there is to see of a theft right now (world points): the thief's hand away from his own place, the tile
## once it is off where it lay (in a hand or gliding).
func evidence(event: TheftEvent) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if event.hand.is_valid():
		points.append(event.hand.call())
	if is_instance_valid(event.tile) and event.tile.holder == null:
		points.append(event.tile.global_position)
	if event.kind in ["rack", "discard", "pile"] and now() - event.started < PLUCK_TIME:
		points.append(event.origin_point)
	return points.filter(func(point: Vector3) -> bool: return not at_own_place(event.thief, point))


func at_own_place(seat: int, point: Vector3) -> bool:
	var local := seats[seat].to_local(point)
	return absf(local.x) < OWN_PLACE_X and local.z > OWN_PLACE_Z


# Nobody walking (the çaycı) stands between the eye and the point.
func _clear(eye: Vector3, point: Vector3) -> bool:
	for blocker: Node3D in get_tree().get_nodes_in_group("view_blockers"):
		var base := blocker.global_position
		var a := Vector2(eye.x - base.x, eye.z - base.z)
		var b := Vector2(point.x - base.x, point.z - base.z)
		var ab := b - a
		var t := clampf(-a.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var closest := a + ab * t
		var height := lerpf(eye.y, point.y, t) - base.y
		if closest.length() < 0.25 and height > 0.0 and height < 1.75:
			return false
	return true
