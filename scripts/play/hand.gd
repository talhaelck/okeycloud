class_name Hand
extends Node3D
## The local player's reach: the right hand picks tiles up and puts them on any rack or the felt.
## Aims with the mouse in rack mode, with the screen centre (crosshair) in observe mode.
## Tile moves are instant drag and drop: press on a tile to pick it up, release over a rack slot or the felt to
## put it down (a quick click that ends where it started keeps the tile in hand for a second click instead).
## Racks open a gap under the dragged tile. The visible hand (ArmMotion) only follows; it never holds anything up.
## Whether a move is a theft, and who saw it, is the game's business (GameDirector, Visibility): the hand only says
## what it is about to pick up (`picking`). Holding Shift moves a tile slowly and quietly (sneaking).
## Quick ways to handle tiles: click a tile of the pile or the left row (a short press that ends where it started) and
## it comes to your rack; double-click a tile of your rack to throw it; Ctrl+click picks tiles of your rack, and
## dragging one of them carries all of them together, keeping their shape.
## Looking at a face-up tile away from your own rack (a discard across the table, the indicator) shows its face up close
## on a card above it (TilePeek); not in rack view or for your own rack, where the tiles are readable anyway.

## Just before a tile leaves where it lies (it still has its holder and place).
signal picking(tile: Tile, origin: Node)

const REACH := 1.65 # every laid meld, but not the opposite rack
const FOLLOW := 30.0 # how snappily the dragged tile follows the cursor
const SNEAK_FOLLOW := 4.0 # ... and while sneaking (Shift): slow, so the hand is out longer
const CARRY_DISTANCE := 0.55 # a held tile floats this far from the eyes (closer, his big hand filled the view)
const RACK_LIFT := 0.02
const FELT_LIFT := 0.04
const CLICK_TIME := 0.25 # seconds; a shorter press that ends where it started keeps the tile in hand
const PINCH_UPRIGHT := 1.35 # radians the fingers point down when pinching a standing tile's top edge
const PINCH_FLAT := 1.15 # ... and a tile lying on the felt
const LOOK_RANGE := 5.0 # how far away a face-up tile is still shown up close

var camera: FocusCamera
var seat: Seat
var seats: Array[Seat] = []
var table: Table

var held: Tile
## True while Shift is held: tiles move slowly and make no sound.
var sneaking: bool:
	get:
		return Input.is_key_pressed(KEY_SHIFT)
## Short action text for the HUD ("" when nothing to do).
var hint := ""
## Set by the game (GameDirector) to apply the rules; the hand works freely without them.
## grab_check(tile) -> String: "" if the tile may be picked up, else why not (shown instead of the grab hint).
var grab_check: Callable
## drop_check(tile, origin, drop) -> bool: true if the game placed the tile itself. `drop` is {rack, slot} or
## {point, zone}; an empty drop means the tile has to go back where it came from.
var drop_check: Callable
## drop_hint(tile, origin, drop) -> String: what letting go here would do ("" for the usual hint).
var drop_hint: Callable
## steal_check(tile) -> bool: would picking this tile up be stealing (for the hint).
var steal_check: Callable
## quick_click(tile, origin) -> bool: a quick click on a tile that is held; true if the game took it (it then has
## called take_held()), e.g. to draw it onto the rack.
var quick_click: Callable
## throw_click(tile): a double-click on a tile of the player's rack; the tile is out of the hand and the game puts it
## somewhere (his discard row, or back).
var throw_click: Callable
## hover_hint(tile) -> String: what a click on this tile would do ("" for the usual hint).
var hover_hint: Callable
## Tiles of the player's rack picked with Ctrl+click.
var selection: Array[Tile] = []
## Fixed screen point to aim at instead of the mouse in rack mode (debug screenshots only).
var aim_override := Vector2(-1, -1)

var arm := ArmMotion.new()
var left_arm := ArmMotion.new()

var _origin: Node
var _origin_slot := -1
## Tiles carried along with the held one (a selection), their old slots and where they hang relative to it.
var _group: Array[Tile] = []
var _group_slots: Array[int] = []
var _group_steps: Array[Vector2i] = [] # (row, column) steps from the held tile's old slot
var _group_offsets: Array[Transform3D] = []
var _drop := {}
var _gap_rack: Rack
var _pressed_at := 0.0
var _hovered: Tile
var _peek := TilePeek.new()


func _ready() -> void:
	for motion: ArmMotion in [arm, left_arm]:
		motion.table = table
		for other in seats:
			motion.racks.append(other.rack)
		add_child(motion)
	arm.setup(seat.glove, seat.grip)
	left_arm.setup(seat.left_hand, seat.left_grip)
	add_child(_peek)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not camera.focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return # this click only grabs the mouse (FocusCamera handles it)
	var now := Time.get_ticks_msec() / 1000.0
	if event.pressed:
		if held:
			if event.double_click and _origin == seat.rack and throw_click.is_valid():
				throw_click.call(take_held()) # the first click kept the tile in hand: this second one throws it
			else:
				drop()
			return
		var ray := _ray()
		var tile := _pick(ray[0], ray[1])
		if event.ctrl_pressed:
			if tile and tile.holder == seat.rack:
				toggle_selected(tile)
			return
		if tile == null or not selection.has(tile):
			clear_selection()
		grab(tile)
		_pressed_at = now
		if event.double_click and held and _origin == seat.rack and throw_click.is_valid():
			throw_click.call(take_held())
	elif held:
		if now - _pressed_at < CLICK_TIME and _origin != seat.rack and quick_click.is_valid() \
				and quick_click.call(held, _origin):
			return
		if not _drop.is_empty():
			var back_home: bool = _drop.get("rack") == _origin and _drop.get("slot") == _origin_slot
			if not (back_home and now - _pressed_at < CLICK_TIME):
				drop()


func _process(delta: float) -> void:
	var ray := _ray()
	if held:
		_drop = _find_drop(ray[0], ray[1])
		_show_gap(_drop.get("rack"), _drop.get("slot", -1))
		var target := _carry_target(ray[0], ray[1])
		var follow := SNEAK_FOLLOW if sneaking else FOLLOW
		held.global_transform = held.global_transform.interpolate_with(target, 1.0 - exp(-follow * delta))
		for i in _group.size():
			var goal := held.global_transform * _group_offsets[i]
			_group[i].global_transform = _group[i].global_transform.interpolate_with(goal, 1.0 - exp(-follow * 0.8 * delta))
	else:
		_set_hovered(_pick(ray[0], ray[1]))
		var stealing: bool = _hovered != null and steal_check.is_valid() and steal_check.call(_hovered)
		hint = "" if _hovered == null else ("Sol tık: çal  (Shift: sinsice)" if stealing else "Sol tık: al")
		if _hovered and _hovered.holder == seat.rack:
			hint = "Sol tık: al   ·   Çift tık: at   ·   Ctrl+tık: seç" if selection.is_empty() \
				else "Sürükle: seçilenleri birlikte taşı   ·   Ctrl+tık: seçimi değiştir"
		elif _hovered and hover_hint.is_valid():
			var what: String = hover_hint.call(_hovered)
			if what:
				hint = what
		if _hovered and grab_check.is_valid():
			var why: String = grab_check.call(_hovered)
			if why:
				hint = why
	var looked: Tile = null if held or camera.focused else _pick(ray[0], ray[1], LOOK_RANGE, true)
	_peek.show_tile(null if looked == null or looked.holder == seat.rack else looked)
	# The hand just follows the tile; it never gates the move.
	arm.resting = held == null
	arm.grip_goal = 1.0 if held else 0.0
	if held:
		arm.goal = _pinch_pose(held.global_transform)


## Takes the tile into the hand right away.
func grab(tile: Tile) -> void:
	if tile == null or held:
		return
	if grab_check.is_valid() and grab_check.call(tile) != "":
		return
	_set_hovered(null)
	picking.emit(tile, tile.holder)
	_origin = tile.holder
	_group.clear()
	_group_slots.clear()
	_group_steps.clear()
	_group_offsets.clear()
	var own := seat.rack
	if _origin == own and selection.has(tile) and selection.size() > 1:
		var from := own.slot_of(tile)
		var from_pose := own.slot_global_transform(from)
		for other in selection:
			var slot := own.slot_of(other)
			if other == tile or slot < 0:
				continue
			_group.append(other)
			_group_slots.append(slot)
			_group_steps.append(Vector2i(slot / Rack.SLOTS - from / Rack.SLOTS, slot % Rack.SLOTS - from % Rack.SLOTS))
			_group_offsets.append(from_pose.affine_inverse() * own.slot_global_transform(slot))
		for other in _group:
			own.release(other)
			other.pin()
			other.stop_sliding()
			other.reparent(self)
	_origin_slot = _origin.release(tile) if _origin else -1
	tile.pin()
	tile.stop_sliding()
	tile.reparent(self)
	held = tile


## Puts the held tile where _drop says, right away.
func drop() -> void:
	if held == null or _drop.is_empty():
		return
	var tile := held
	held = null
	_show_gap(null, -1)
	if not _group.is_empty():
		if _drop.get("rack") == seat.rack:
			_drop_group(tile)
			return
		_return_group() # only the tile in the hand goes where the cursor is; the rest wait on the rack
	if drop_check.is_valid() and drop_check.call(tile, _origin, _drop):
		return
	if _drop.has("rack"):
		_drop.rack.insert(tile, _drop.slot)
	else:
		table.put_loose(tile, _drop.point, seat.rotation.y)


## Takes the held tile (and its companions, which go back where they were) out of the hand without placing it.
func take_held() -> Tile:
	var tile := held
	held = null
	_show_gap(null, -1)
	_return_group()
	return tile


## The Ctrl+click selection.
func toggle_selected(tile: Tile) -> void:
	if selection.has(tile):
		selection.erase(tile)
		tile.set_selected(false)
	else:
		selection.append(tile)
		tile.set_selected(true)


func clear_selection() -> void:
	for tile in selection:
		if is_instance_valid(tile):
			tile.set_selected(false)
	selection.clear()


# The whole group lands on the rack, keeping its shape around the cursor's slot.
func _drop_group(tile: Tile) -> void:
	var entries := [{"tile": tile, "dr": 0, "dc": 0}]
	for i in _group.size():
		entries.append({"tile": _group[i], "dr": _group_steps[i].x, "dc": _group_steps[i].y})
	seat.rack.insert_group(entries, _drop.slot)
	_group.clear()
	clear_selection()


# Companions go back to their slots (or the nearest free ones).
func _return_group() -> void:
	for i in _group.size():
		var slot := _group_slots[i] if seat.rack.tile_at(_group_slots[i]) == null else seat.rack.nearest_free(_group_slots[i])
		seat.rack.put(_group[i], slot, true, 0.15)
	_group.clear()
	clear_selection()


## Where the held tile would go if let go now ({rack, slot} or {point, zone}; empty if nowhere).
func drop_target() -> Dictionary:
	return _drop if held else {}


## Where the held tile came from (its holder before it was picked up) and its slot there.
func origin() -> Node:
	return _origin


func origin_slot() -> int:
	return _origin_slot


## Lets go of the held tile and sends it back where it came from.
func give_back() -> void:
	if held == null:
		return
	var tile := held
	held = null
	_show_gap(null, -1)
	_return_group()
	if drop_check.is_valid() and drop_check.call(tile, _origin, {}):
		return
	if _origin is Rack:
		(_origin as Rack).put(tile, (_origin as Rack).nearest_free(maxi(_origin_slot, 0)))
	else:
		table.put_loose(tile, tile.global_position, 0.0)


# Keeps a gap open in the rack under the dragged tile (a null rack closes any gap).
func _show_gap(rack: Rack, slot: int) -> void:
	if _gap_rack and _gap_rack != rack:
		_gap_rack.show_gap(-1)
	_gap_rack = rack
	if rack:
		rack.show_gap(slot)


func _carry_target(from: Vector3, dir: Vector3) -> Transform3D:
	if _drop.has("rack"):
		var slot: Transform3D = _drop.rack.slot_global_transform(_drop.slot)
		slot.origin += slot.basis.z * RACK_LIFT
		hint = "Bırak: ıstakaya koy"
		return slot
	if _drop.has("point"):
		hint = "Bırak: masaya koy"
		if drop_hint.is_valid():
			var what: String = drop_hint.call(held, _origin, _drop)
			if what:
				hint = what
		return Transform3D(_flat_basis(), _drop.point + Vector3.UP * FELT_LIFT)
	hint = "Taşı bir ıstakaya ya da masaya götür"
	var pos := from + dir * CARRY_DISTANCE
	return Transform3D(Basis.looking_at(pos - camera.global_position), pos)


func _flat_basis() -> Basis:
	return Basis(Vector3.UP, seat.rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5)


## Where the hand pivot (palm centre) goes to pinch a tile at `tile_pose` between thumb and index:
## over the top edge of a standing tile, or onto the top of a lying one, coming from the player's shoulder.
func _pinch_pose(tile_pose: Transform3D) -> Transform3D:
	var center := tile_pose.origin
	var face := tile_pose.basis.z
	var touch: Vector3
	var pitch: float
	if absf(face.y) > 0.7:
		touch = center + Vector3.UP * (TileFactory.SIZE.z * 0.5 + 0.004)
		pitch = PINCH_FLAT
	else:
		var toward_me := face if face.dot(camera.global_position - center) > 0.0 else -face
		# Fingertips just over the top edge, so the hand never covers the number.
		touch = center + tile_pose.basis.y * (TileFactory.SIZE.y * 0.5 + 0.012) + toward_me * 0.004
		pitch = PINCH_UPRIGHT
	var shoulder := arm.rest.origin + arm.rest.basis.z * 0.35
	var forward := touch - shoulder
	forward.y = 0.0
	forward = forward.normalized()
	var fingers := (forward * cos(pitch) + Vector3.DOWN * sin(pitch)).normalized()
	return Transform3D(Basis.looking_at(fingers, Vector3.UP), touch - fingers * ArmMotion.FINGERTIPS)


## Leaving this seat's view: a tile in hand goes back where it came from, and nothing stays highlighted.
func drop_view() -> void:
	give_back()
	_set_hovered(null)
	_peek.show_tile(null)
	hint = ""


func _ray() -> Array[Vector3]:
	var viewport := get_viewport()
	var pos := viewport.get_mouse_position() if camera.focused else viewport.get_visible_rect().size * 0.5
	if camera.focused and aim_override.x >= 0.0:
		pos = aim_override
	return [camera.project_ray_origin(pos), camera.project_ray_normal(pos)]


# Closest tile under the ray within `reach` of where he sits (arm's reach by default: bending over the table moves
# his eyes, not his shoulders); only tiles showing their face to `from` if asked.
func _pick(from: Vector3, dir: Vector3, reach := REACH, face_up := false) -> Tile:
	var best: Tile
	var best_distance := INF
	var box := AABB(-TileFactory.SIZE * 0.5, TileFactory.SIZE)
	for tile: Tile in get_tree().get_nodes_in_group("tiles"):
		if tile == held or tile.holder == null:
			continue
		# A tile's face is its +Z: on someone else's rack it faces them, in the draw pile it faces the felt.
		if face_up and tile.global_basis.z.dot(from - tile.global_position) <= 0.0:
			continue
		var inv := tile.global_transform.affine_inverse()
		var hit: Variant = box.intersects_ray(inv * from, inv.basis * dir)
		if hit == null:
			continue
		var point: Vector3 = tile.global_transform * hit
		var distance := from.distance_to(point)
		if distance < best_distance and _within(point, reach):
			best = tile
			best_distance = distance
	return best


func _within(point: Vector3, reach := REACH) -> bool:
	return seat.head_anchor.global_position.distance_to(point) <= reach


# Nearest place under the ray to set the held tile: a rack slot (neighbours make room) or a spot on the felt.
func _find_drop(from: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF
	for other in seats:
		var hit := other.rack.board_hit(from, dir)
		if hit.is_empty():
			continue
		var distance := from.distance_to(hit.point)
		if other.rack.can_insert(hit.slot) and distance < best_distance and _within(hit.point):
			best = {"rack": other.rack, "slot": hit.slot}
			best_distance = distance
	var felt: Variant = table.felt_hit(from, dir)
	if felt != null and from.distance_to(felt) < best_distance and _within(felt):
		best = {"point": felt, "zone": table.zone_at(felt)}
	return best


func _set_hovered(tile: Tile) -> void:
	if tile == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.set_highlight(false)
	_hovered = tile
	if tile:
		tile.set_highlight(true)
