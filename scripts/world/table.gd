class_name Table
extends Node3D
## Square okey table: green felt, raised wooden rim, and where the tiles of a hand lie:
## - the draw pile in the middle (one short stack, the count written above it) with the gösterge beside it,
## - each seat's discards in a row on his right-hand diagonal, between him and the next player, who may take the top,
## - each seat's opened melds in the wedge between his rack and the pile.
## Positions "in seat space" are as seen from seat 0 (on +Z, facing -Z) and turned by seat_basis for the others.

const TOP := 0.75 # height of the felt surface
const SIZE := 1.5
const RIM := 0.07
const FELT := Color(0.07, 0.3, 0.17)
const DROP_HEIGHT := 0.025 # tiles are let go this far above the felt
const FACE_UP := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)) # face +Y, numbers upright from +Z
const FACE_DOWN := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
const PILE_SHOWN := 5
## Discard row along the seat's right diagonal (seat-space x = z): first tile at START, the 8th at END, then a
## second layer on top.
const DISCARD_START := 0.49
const DISCARD_END := 0.22
const DISCARD_ROW := 8
## Meld rows in front of a seat (seat-space z), in the order they fill. A row at z spans |x| <= z - MELD_MARGIN,
## so the four seats' areas never meet. From his own eyes the owner's rack hides the felt beyond about z = 0.3, so
## the two rows he can see fill first and the ones behind his rack only take what does not fit there.
const MELD_ROWS := [0.28, 0.2, 0.36, 0.44]
const MELD_NEAR := 0.44
const MELD_FAR := 0.2
const MELD_MARGIN := 0.065
const MELD_PITCH := TileFactory.SIZE.x + 0.003
const MELD_GAP := 0.025

## The gösterge tile (face up beside the pile).
var indicator: Tile

var _pile := Node3D.new()
var _loose := Node3D.new()
var _zones := Node3D.new() # discards and melds
var _stack := Node3D.new() # the blank tiles under the top of the pile
var _count := Label3D.new()
var _pile_top: Tile
var _discards := [[], [], [], []]
var _melds := [[], [], [], []]


func _ready() -> void:
	add_to_group("table")
	var wood := Mat.textured("wood_table_worn", 0.9)
	var wood_dark := Mat.textured("wood_table_worn", 0.9, Color(0.55, 0.45, 0.4))
	var cloth := Mat.textured("rough_linen", 0.12, FELT, false)
	var felt := SIZE - RIM * 2.0
	Mat.part(self, RoundedBox.build(Vector3(SIZE, 0.05, SIZE), 0.02), wood, Vector3(0, TOP - 0.035, 0))
	Mat.part(self, RoundedBox.build(Vector3(felt, 0.01, felt), 0.003), cloth, Vector3(0, TOP - 0.005, 0))
	for side in 4:
		# Pinwheel layout so the four rim pieces never overlap at the corners.
		var pivot := Node3D.new()
		pivot.rotation.y = side * PI * 0.5
		add_child(pivot)
		Mat.part(pivot, RoundedBox.build(Vector3(SIZE - RIM, 0.03, RIM), 0.012), wood,
			Vector3(RIM * 0.5, TOP + 0.005, (SIZE - RIM) * 0.5))
	Mat.part(self, RoundedBox.build(Vector3(SIZE - 0.12, 0.08, SIZE - 0.12), 0.015), wood_dark, Vector3(0, TOP - 0.1, 0))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var leg_height := TOP - 0.06
		Mat.part(self, Mat.cylinder(0.03, leg_height, 0.035), wood_dark,
			Vector3(corner.x * 0.62, leg_height * 0.5, corner.y * 0.62))
	add_child(_pile)
	add_child(_loose)
	add_child(_zones)
	_pile.add_child(_stack)
	_count.font_size = 64
	_count.pixel_size = 0.0008
	_count.outline_size = 14
	_count.modulate = Color(1.0, 0.93, 0.75)
	_count.outline_modulate = Color(0.12, 0.07, 0.03)
	_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count.visible = false
	_pile.add_child(_count)
	_build_collision()


# Solid felt and rim for loose tiles, glasses and hands (the legs and frame never get touched).
func _build_collision() -> void:
	var body := Colliders.static_body(self)
	var felt := SIZE - RIM * 2.0
	Colliders.box(body, Vector3(SIZE, 0.06, SIZE), Transform3D(Basis(), Vector3(0, TOP - 0.03, 0)))
	for side in 4:
		var turn := Basis(Vector3.UP, side * PI * 0.5)
		Colliders.box(body, Vector3(SIZE, 0.03, RIM), Transform3D(turn, turn * Vector3(0, TOP + 0.005, (felt + RIM) * 0.5)))


## The draw pile in the middle: a short face-down stack (at most PILE_SHOWN tiles) with how many are left written
## above it, and `top`, the real next tile, on top of it (null when the pile is empty).
func set_pile(count: int, top: Tile) -> void:
	for child in _stack.get_children():
		child.queue_free()
	_pile_top = top
	var shown := mini(count, PILE_SHOWN)
	var lying := TileFactory.SIZE.z
	for layer in shown - (1 if top else 0):
		var blank := TileFactory.blank()
		blank.transform = Transform3D(Basis(Vector3.UP, 0.05 * sin(layer * 2.3)) * FACE_DOWN, Vector3(0, TOP + lying * (layer + 0.5), 0))
		_stack.add_child(blank)
	if top:
		top.holder = self
		top.pin()
		if top.get_parent() != _pile:
			if top.get_parent():
				top.reparent(_pile)
			else:
				_pile.add_child(top)
		top.transform = Transform3D(FACE_DOWN, Vector3(0, TOP + lying * (shown - 0.5), 0))
	_count.text = str(count)
	_count.visible = count > 0
	_count.position = Vector3(0, TOP + lying * shown + 0.07, 0)


## Rewrites the number above the pile (the stack itself catches up with set_pile).
func set_pile_count(count: int) -> void:
	_count.text = str(count)
	_count.visible = count > 0


## The real tile on top of the pile (null when it is empty or the top has just been taken).
func pile_top() -> Tile:
	return _pile_top


## The gösterge: face up beside the pile.
func show_indicator(tile: Tile) -> void:
	if indicator and indicator != tile:
		indicator.queue_free()
	indicator = tile
	tile.holder = self
	if tile.get_parent():
		tile.reparent(_pile)
	else:
		_pile.add_child(tile)
	tile.pin()
	tile.transform = Transform3D(Basis(Vector3.UP, 0.25) * FACE_UP, Vector3(0.08, TOP + TileFactory.SIZE.z * 0.5, 0.02))


## Puts a tile on top of a seat's discards: a row on the seat's right-hand diagonal, from the corner toward the
## middle, so the newest tile is the one nearest the centre and every one of them can be seen (and reached).
func put_discard(tile: Tile, seat: int, time := 0.18) -> void:
	_take_in(tile)
	_discards[seat].append(tile)
	var target := _discard_transform(seat, _discards[seat].size() - 1)
	if time > 0.0:
		tile.slide_to(target, time)
	else:
		tile.transform = target
	Sfx.at("tile_felt", global_transform * target.origin, -4.0, time)


## Puts a tile back into a seat's discard row at `index` (a caught thief giving it back); the row closes up again.
func restore_discard(tile: Tile, seat: int, index: int) -> void:
	_take_in(tile)
	_discards[seat].insert(clampi(index, 0, _discards[seat].size()), tile)
	_relayout_row(seat)


func discards(seat: int) -> Array:
	return _discards[seat]


func _relayout_row(seat: int, time := 0.25) -> void:
	for i in _discards[seat].size():
		(_discards[seat][i] as Tile).slide_to(_discard_transform(seat, i), time)


## Where the next tile a seat discards will lie (world space).
func next_discard(seat: int) -> Transform3D:
	return global_transform * _discard_transform(seat, _discards[seat].size())


## Clears the table for a new hand: every tile on it goes.
func clear() -> void:
	for parent: Node3D in [_pile, _zones, _loose]:
		for child in parent.get_children():
			if child is Tile:
				child.queue_free()
	_discards = [[], [], [], []]
	_melds = [[], [], [], []]
	_pile_top = null
	indicator = null


## Lays out the melds opened in front of a seat: rows across the wedge between his rack and the pile, nearest row
## first, a small gap between melds. `groups` is an Array of Tile arrays in table order.
func lay_melds(seat: int, groups: Array, time := 0.25) -> void:
	for group: Array in groups:
		for tile: Tile in group:
			_take_in(tile)
	_melds[seat] = groups
	var rows := []
	var row := 0
	var used := 0.0
	for group: Array in groups:
		var width := group.size() * MELD_PITCH
		while row < MELD_ROWS.size() - 1 and used > 0.0 and used + MELD_GAP + width > _row_width(row):
			row += 1
			used = 0.0
		while rows.size() <= row:
			rows.append([])
		rows[row].append(group)
		used += (MELD_GAP if used > 0.0 else 0.0) + width
	for r in rows.size():
		var total := -MELD_GAP
		for group: Array in rows[r]:
			total += MELD_GAP + group.size() * MELD_PITCH
		var x := -total * 0.5 + MELD_PITCH * 0.5
		for group: Array in rows[r]:
			for tile: Tile in group:
				var at := seat_basis(seat) * Vector3(x, TOP + TileFactory.SIZE.z * 0.5, MELD_ROWS[r])
				var target := Transform3D(seat_basis(seat) * FACE_UP, at)
				if time > 0.0:
					tile.slide_to(target, time)
				else:
					tile.transform = target
				x += MELD_PITCH
			x += MELD_GAP


func melds(seat: int) -> Array:
	return _melds[seat]


## What part of the table a world point is on: {kind: "pile"} for the centre, {kind: "discard", seat} for a seat's
## discard row, {kind: "meld", seat} for the area in front of a seat, {kind: "felt"} anywhere else.
func zone_at(point: Vector3) -> Dictionary:
	var local := to_local(point)
	if absf(local.x) < 0.07 and absf(local.z) < 0.07:
		return {"kind": "pile"}
	for seat in 4:
		var p := seat_basis(seat).inverse() * local
		var along := (p.x + p.z) * 0.5
		if absf(p.x - p.z) < 0.07 and along > DISCARD_END - 0.04 and along < DISCARD_START + 0.06:
			return {"kind": "discard", "seat": seat}
		if p.z > MELD_FAR - 0.05 and p.z < MELD_NEAR + 0.05 and absf(p.x) <= p.z - MELD_MARGIN + 0.03:
			return {"kind": "meld", "seat": seat}
	return {"kind": "felt"}


## A seat's turn about the vertical (seat 0 sits on +Z, play goes to +X).
static func seat_basis(seat: int) -> Basis:
	return Basis(Vector3.UP, seat * PI * 0.5)


func _row_width(row: int) -> float:
	return 2.0 * (MELD_ROWS[row] - MELD_MARGIN)


func _discard_transform(seat: int, index: int) -> Transform3D:
	var spot := index % DISCARD_ROW
	var layer := index / DISCARD_ROW
	var along := DISCARD_START + (DISCARD_END - DISCARD_START) * spot / (DISCARD_ROW - 1.0)
	var offset := Vector3(0.003 * sin(index * 3.7), 0, 0.003 * cos(index * 2.9)) # laid by hand, not by machine
	var origin := seat_basis(seat) * (Vector3(along, TOP + TileFactory.SIZE.z * (layer + 0.5), along) + offset)
	# Side by side along the diagonal, readable for the discarder.
	return Transform3D(seat_basis(seat) * Basis(Vector3.UP, -PI * 0.25 + 0.05 * sin(index * 5.1)) * FACE_UP, origin)


# Makes the table the holder of a tile coming from anywhere (a hand, a rack, the felt).
func _take_in(tile: Tile) -> void:
	for list: Array in _discards:
		list.erase(tile)
	tile.holder = self
	tile.pin()
	if tile.get_parent() == null:
		_zones.add_child(tile)
	elif tile.get_parent() != _zones:
		tile.reparent(_zones)


## Drops a tile face up onto the felt at a world point, numbers upright for someone facing along yaw;
## from there physics takes over (it lands, bounces a little and settles).
func put_loose(tile: Tile, point: Vector3, yaw: float) -> void:
	tile.holder = self
	tile.reparent(_loose)
	var local := to_local(point)
	local.y = TOP + TileFactory.SIZE.z * 0.5 + DROP_HEIGHT
	tile.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), local)
	tile.set_loose(Vector3.DOWN * 0.3)
	Sfx.at("tile_felt", point, -4.0, 0.08)


func release(tile: Tile) -> int:
	tile.holder = null
	tile.pin()
	if tile == _pile_top:
		_pile_top = null
	for seat in _discards.size():
		if _discards[seat].has(tile):
			_discards[seat].erase(tile)
			_relayout_row(seat) # the row closes up behind a tile taken from its middle
	for groups: Array in _melds:
		for group: Array in groups:
			group.erase(tile)
	return -1


## Lowest height a hand may be at above a world point: the felt, the raised rim, and the tiles lying on it.
func clearance(point: Vector3) -> float:
	var local := to_local(point)
	var y := TOP
	if absf(local.x) > SIZE * 0.5 - RIM - 0.01 or absf(local.z) > SIZE * 0.5 - RIM - 0.01:
		y = TOP + 0.022
	for parent: Node3D in [_stack, _pile, _zones]:
		for tile: Node3D in parent.get_children():
			var t := tile.position
			if absf(local.x - t.x) < 0.04 and absf(local.z - t.z) < 0.04:
				y = maxf(y, t.y + TileFactory.SIZE.z * 0.5)
	return y


## Where a world-space ray meets the felt, or null if it lands outside the playing area.
func felt_hit(from: Vector3, dir: Vector3) -> Variant:
	var hit: Variant = Plane(Vector3.UP, TOP).intersects_ray(to_local(from), dir)
	if hit == null:
		return null
	var half := SIZE * 0.5 - RIM - TileFactory.SIZE.y * 0.5
	if absf(hit.x) > half or absf(hit.z) > half:
		return null
	return to_global(hit)
