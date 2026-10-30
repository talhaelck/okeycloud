class_name Rack
extends Node3D
## Two-row tile rack (ıstaka) with 2 x 15 slots. Its owner sits on the +Z side; the board leans away toward -Z.
## Slot index = row * SLOTS + column, where row 1 is the upper row.

const LENGTH := 0.8
const HEIGHT := 0.18
const SLOTS := 15
const ROWS := 2
const TILT := 0.24 # radians the board leans back
const SLOT_GAP := 0.003
const ROW_GAP := 0.018

var _board := Basis(Vector3.RIGHT, -TILT)
var _board_origin := Vector3(0, 0.014, -0.016) # bottom of the board's front face
var _tiles := Node3D.new()
var _hint_root := Node3D.new()
## True while the rack lies tipped forward (the end of a hand shows everyone's tiles).
var tipped := false
var _rest := Transform3D()
var _tip_tween: Tween
var _hint_signature := ""

var _slots: Array[Tile] = []
var _gap := -1 # slot kept open for a tile hovering over the rack, -1 when none


func _ready() -> void:
	var wood := Mat.textured("wood_table_worn", 0.6, Color(1.0, 0.85, 0.7))
	var wood_dark := Mat.textured("wood_table_worn", 0.6, Color(0.6, 0.48, 0.4))
	Mat.part(self, RoundedBox.build(Vector3(LENGTH, 0.014, 0.1), 0.005), wood_dark, Vector3(0, 0.007, 0))
	var board := Mat.part(self, RoundedBox.build(Vector3(LENGTH, HEIGHT, 0.018), 0.006), wood,
		_board_origin + _board.y * HEIGHT * 0.5 - _board.z * 0.009)
	board.basis = _board
	for row in ROWS:
		var lip := Mat.part(self, RoundedBox.build(Vector3(LENGTH, 0.01, 0.03), 0.004), wood_dark,
			_board_origin + _board.y * (_row_bottom(row) - 0.005) + _board.z * 0.015)
		lip.basis = _board
	add_child(_tiles)
	add_child(_hint_root)
	_slots.resize(ROWS * SLOTS)
	# Collision for loose tiles and glasses (tiles on the rack are pinned and need none).
	var body := Colliders.static_body(self)
	Colliders.box(body, Vector3(LENGTH, 0.014, 0.1), Transform3D(Basis(), Vector3(0, 0.007, 0)))
	Colliders.box(body, Vector3(LENGTH, HEIGHT, 0.018), Transform3D(_board, _board_origin + _board.y * HEIGHT * 0.5 - _board.z * 0.009))


## The end of a hand: the rack falls forward onto the felt, tiles face up for everyone, sliding a little toward its
## owner as it goes so the melds in front of it stay clear.
func tip_over(seconds := 0.75) -> void:
	if tipped:
		return
	tipped = true
	_rest = transform
	if _tip_tween:
		_tip_tween.kill()
	if seconds <= 0.0:
		transform = _rest * _tip_transform(1.0)
		return
	_tip_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tip_tween.tween_method(func(v: float) -> void: transform = _rest * _tip_transform(v), 0.0, 1.0, seconds)
	_tip_tween.finished.connect(func() -> void: Sfx.at("tile_felt", global_position + Vector3(0, 0.05, 0), -2.0))


## Upright again, at once.
func stand_up() -> void:
	if _tip_tween:
		_tip_tween.kill()
		_tip_tween = null
	if tipped:
		transform = _rest
	tipped = false


func _tip_transform(v: float) -> Transform3D:
	var pivot := Vector3(0, 0, -0.05) # the base's front edge
	var slide := Transform3D(Basis(), Vector3(0, 0, 0.07 * v))
	var turn := Transform3D(Basis(Vector3.RIGHT, -1.38 * v), Vector3.ZERO)
	return slide * Transform3D(Basis(), pivot) * turn * Transform3D(Basis(), -pivot)


## Lays a fresh hand out from tile values: first half on the upper row, the rest on the lower row, each row centred.
func set_tiles(values: Array) -> void:
	var tiles: Array[Tile] = []
	for value: Vector2i in values:
		tiles.append(TileFactory.create(value))
	_lay_out(tiles)


## The same from tile ids (OkeyTiles), sorted by colour and number.
func set_tile_ids(ids: Array) -> void:
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var va := OkeyTiles.value(a)
		var vb := OkeyTiles.value(b)
		return va.x < vb.x or (va.x == vb.x and va.y < vb.y))
	var tiles: Array[Tile] = []
	for id: int in sorted:
		tiles.append(TileFactory.of_id(id))
	_lay_out(tiles)


func _lay_out(tiles: Array[Tile]) -> void:
	for tile in _slots:
		if tile:
			tile.queue_free()
	_slots.fill(null)
	var upper_count := ceili(tiles.size() / 2.0)
	for i in tiles.size():
		var row := 1 if i < upper_count else 0
		var in_row := upper_count if row == 1 else tiles.size() - upper_count
		var column := (i if row == 1 else i - upper_count) + floori((SLOTS - in_row) / 2.0)
		put(tiles[i], row * SLOTS + column, false)


## Every tile on the rack, in slot order.
func tiles() -> Array[Tile]:
	var out: Array[Tile] = []
	for tile in _slots:
		if tile:
			out.append(tile)
	return out


func slot_of(tile: Tile) -> int:
	return _slots.find(tile)


## The tiles as the player has grouped them: runs of neighbouring tiles in a row, split by empty slots (upper row
## first, left to right). This is how a player shows what he means to open.
func groups() -> Array:
	var out := []
	for row in [1, 0]:
		var group := []
		for column in SLOTS:
			var tile := _slots[row * SLOTS + column]
			if tile:
				group.append(tile)
			elif not group.is_empty():
				out.append(group)
				group = []
		if not group.is_empty():
			out.append(group)
	return out


## Lines under the groups of tiles on this rack, for counting: `hints` are {tiles: Array[Tile], color: Color,
## text: String}. A group (tiles of one row side by side) gets a glowing strip on the lip below it and, lying on
## the lip, its text (the points of a valid meld). An empty array clears them. Only redrawn when something changed.
func show_hints(hints: Array) -> void:
	var signature := ""
	for hint: Dictionary in hints:
		signature += "%s:%s:%s;" % [hint.tiles.map(func(t: Tile) -> int: return _slots.find(t)), hint.color.to_html(), hint.text]
	if signature == _hint_signature:
		return
	_hint_signature = signature
	for child in _hint_root.get_children():
		child.queue_free()
	for hint: Dictionary in hints:
		var slots: Array = hint.tiles.map(func(t: Tile) -> int: return _slots.find(t))
		if slots.has(-1) or slots.is_empty():
			continue
		slots.sort()
		var row: int = slots[0] / SLOTS
		var first := _slot_transform(slots[0]).origin
		var last := _slot_transform(slots[-1]).origin
		var middle := (first + last) * 0.5
		var width := absf(last.x - first.x) + TileFactory.SIZE.x
		# On the lip under the row, a little in front of the tiles.
		var base := Vector3(middle.x, 0, 0) + _board_origin + _board.y * (_row_bottom(row) - 0.0005) + _board.z * 0.021
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width - 0.004, 0.0025, 0.011)
		strip.mesh = box
		var glow := StandardMaterial3D.new()
		glow.albedo_color = hint.color
		glow.emission_enabled = true
		glow.emission = hint.color
		glow.emission_energy_multiplier = 1.6
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		strip.material_override = glow
		strip.transform = Transform3D(_board, base)
		_hint_root.add_child(strip)
		if hint.text != "":
			var label := Label3D.new()
			label.text = hint.text
			label.font_size = 48
			label.pixel_size = 0.00030
			label.modulate = hint.color.lightened(0.35)
			label.outline_size = 10
			label.outline_modulate = Color(0.05, 0.03, 0.02)
			label.no_depth_test = true
			label.shaded = false
			# Standing on the lip in front of the tiles' feet, leaning back a little toward the owner's eyes.
			label.transform = Transform3D(_board * Basis(Vector3.RIGHT, -0.7), base + _board.y * 0.009 + _board.z * 0.012)
			_hint_root.add_child(label)


## Lays the rack out as `groups` (Tile arrays) with an empty slot between them, upper row first, a group never
## split over two rows, then the `rest` packed after them. Falls back to no gaps when that does not fit.
func arrange(groups: Array, rest: Array) -> void:
	var layout: Array[Tile] = []
	layout.resize(ROWS * SLOTS)
	var order: Array[int] = []
	for row in [1, 0]:
		for column in SLOTS:
			order.append(row * SLOTS + column)
	var at := 0
	var fits := true
	for group: Array in groups:
		var column := at % SLOTS
		if column > 0 and column + group.size() > SLOTS:
			at += SLOTS - column # next row
		if at + group.size() > order.size():
			fits = false
			break
		for tile: Tile in group:
			layout[order[at]] = tile
			at += 1
		if at % SLOTS != 0:
			at += 1 # the gap
	if fits and at + rest.size() <= order.size():
		for tile: Tile in rest:
			layout[order[at]] = tile
			at += 1
	else:
		layout.fill(null)
		at = 0
		for group: Array in groups + [rest]:
			for tile: Tile in group:
				layout[order[at]] = tile
				at += 1
	_slots = layout
	_layout(_slots)


## A free slot at the right end of the upper row (or nearest to it), -1 when full: where a drawn tile goes.
func free_slot() -> int:
	return nearest_free(ROWS * SLOTS - 1)


## Moves a tile into a free slot, sliding it there unless instant.
func put(tile: Tile, index: int, animate := true, time := 0.18) -> void:
	_slots[index] = tile
	tile.holder = self
	tile.pin()
	if tile.get_parent():
		tile.reparent(_tiles)
	else:
		_tiles.add_child(tile)
	var target := _slot_transform(index)
	if animate:
		tile.slide_to(target, time)
		Sfx.at("tile_rack", slot_global_transform(index).origin, -6.0, time) # it sits down when the slide ends
	else:
		tile.transform = target


## Can a tile be dropped at `index`: free, or its row has room for the neighbours to shift?
func can_insert(index: int) -> bool:
	return not _with_gap(index).is_empty()


## Opens a gap at `index` while a dragged tile hovers there (-1 closes it). Only moves tiles visually.
func show_gap(index: int) -> void:
	if index == _gap:
		return
	_gap = index
	var layout := _with_gap(index) if index >= 0 else _slots
	if layout.is_empty():
		layout = _slots
	_layout(layout)


## Drops a tile at `index`, pushing its row neighbours aside toward the nearest free slot.
func insert(tile: Tile, index: int) -> void:
	var layout := _with_gap(index)
	_gap = -1
	if layout.is_empty():
		_layout(_slots)
		put(tile, nearest_free(index))
		return
	_slots = layout
	_layout(_slots)
	put(tile, index, true, 0.08)


## Drops several tiles at once (picked with Ctrl+click and carried together), keeping their shape: `entries` are
## {tile, dr, dc}, the row and column steps from the one at `anchor` (which they have been released from the rack
## for, so their old slots are free). The shape is slid in as far as it must to stay on the rack; a tile that was
## in the way goes to the nearest free slot, which is usually one the group just left.
func insert_group(entries: Array, anchor: int) -> void:
	_gap = -1
	var row := anchor / SLOTS
	var column := anchor % SLOTS
	var dr_low := 0
	var dr_high := 0
	var dc_low := 0
	var dc_high := 0
	for entry: Dictionary in entries:
		dr_low = mini(dr_low, entry.dr)
		dr_high = maxi(dr_high, entry.dr)
		dc_low = mini(dc_low, entry.dc)
		dc_high = maxi(dc_high, entry.dc)
	row = clampi(row, -dr_low, ROWS - 1 - dr_high)
	column = clampi(column, -dc_low, SLOTS - 1 - dc_high)
	var displaced: Array[Tile] = []
	var displaced_from: Array[int] = []
	for entry: Dictionary in entries:
		var slot: int = (row + entry.dr) * SLOTS + column + entry.dc
		if _slots[slot] != null and not entries.any(func(e: Dictionary) -> bool: return e.tile == _slots[slot]):
			displaced.append(_slots[slot])
			displaced_from.append(slot)
			_slots[slot] = null
	for entry: Dictionary in entries:
		put(entry.tile, (row + entry.dr) * SLOTS + column + entry.dc, true, 0.1)
	for i in displaced.size():
		put(displaced[i], nearest_free(displaced_from[i]), true, 0.15)
	_layout(_slots)


## Takes a tile off the rack and returns the slot it was in.
func release(tile: Tile) -> int:
	var index := _slots.find(tile)
	if index >= 0:
		_slots[index] = null
	tile.holder = null
	return index


## Closest empty slot to index, preferring the same row; -1 when the rack is full.
func nearest_free(index: int) -> int:
	var row := index / SLOTS
	var column := index % SLOTS
	for r in [row, 1 - row]:
		for offset in SLOTS:
			for c in [column - offset, column + offset]:
				if c >= 0 and c < SLOTS and _slots[r * SLOTS + c] == null:
					return r * SLOTS + c
	return -1


func tile_at(index: int) -> Tile:
	return _slots[index]


## Middle of the board's top edge, in world space.
func top_edge() -> Vector3:
	return to_global(_board_origin + _board.y * HEIGHT)


func slot_global_transform(index: int) -> Transform3D:
	return global_transform * _slot_transform(index)


## Where a world-space ray meets the board's tile face: {point, slot}, or empty if it misses.
func board_hit(from: Vector3, dir: Vector3) -> Dictionary:
	var inv := global_transform.affine_inverse()
	var face := _board_origin + _board.z * (TileFactory.SIZE.z * 0.5 + 0.001)
	var hit: Variant = Plane(_board.z, face).intersects_ray(inv * from, inv.basis * dir)
	if hit == null:
		return {}
	var rel: Vector3 = hit - face
	var u := rel.dot(Vector3.RIGHT)
	var v := rel.dot(_board.y)
	if absf(u) > LENGTH * 0.5 + 0.02 or v < -0.03 or v > HEIGHT + 0.03:
		return {}
	var row := 1 if v > _row_bottom(1) - ROW_GAP * 0.5 else 0
	var column := clampi(roundi(u / (TileFactory.SIZE.x + SLOT_GAP) + (SLOTS - 1) * 0.5), 0, SLOTS - 1)
	return {"point": global_transform * hit, "slot": row * SLOTS + column}


## Lowest height a hand may be at above a world point without passing through the board (-INF where clear).
## Tiles themselves are not obstacles: fingers touch them.
func clearance(point: Vector3) -> float:
	var local := to_local(point)
	if absf(local.x) > LENGTH * 0.5 + 0.02:
		return -INF
	var depth := (local - _board_origin).dot(_board.z) # 0 at the board's front face, + toward the owner
	if depth > -0.035 and depth < 0.0:
		return to_global(_board_origin + _board.y * (HEIGHT + 0.012)).y
	if absf(local.z) < 0.05:
		return global_position.y + 0.016 # the base under the tiles
	return -INF


## How far a world point has to move toward the owner (the rack's +Z) to be `margin` clear of the owner's side of
## the rack: anything below the top of the board that is in or past the board, its tiles and lips, or on the base.
## Points beyond the board count too, so the owner's hand never ends up through it (pass `beyond = false` for
## someone else's rack: then only the board, its tiles and the base count). 0 when clear; seated hands use this.
func penetration(point: Vector3, margin := 0.0, beyond := true) -> float:
	var local := to_local(point)
	if absf(local.x) > LENGTH * 0.5 + margin:
		return 0.0
	var rel := local - _board_origin
	var depth := rel.dot(_board.z) # 0 at the board's front face, + toward the owner
	var front := 0.035 + margin # tiles and lips stand this far out of the board face
	if rel.dot(_board.y) < HEIGHT + margin and depth < front and (beyond or depth > -0.018 - margin):
		return (front - depth) / _board.z.z
	if absf(local.z) < 0.05 + margin and local.y < 0.014 + margin:
		return 0.05 + margin - local.z
	return 0.0


# Slot contents after making room at `index`: the tiles between it and the nearest free slot in the same row
# move one step toward that free slot. Empty when the row is full.
func _with_gap(index: int) -> Array[Tile]:
	var slots: Array[Tile] = _slots.duplicate()
	if slots[index] == null:
		return slots
	var row := index / SLOTS * SLOTS
	var column := index % SLOTS
	for offset in range(1, SLOTS):
		for direction in [-1, 1]:
			var free: int = column + direction * offset
			if free < 0 or free >= SLOTS or slots[row + free] != null:
				continue
			var c := free
			while c != column:
				slots[row + c] = slots[row + c - direction]
				c -= direction
			slots[index] = null
			return slots
	return []


func _layout(layout: Array[Tile]) -> void:
	for i in layout.size():
		if layout[i]:
			layout[i].slide_to(_slot_transform(i), 0.1)


func _slot_transform(index: int) -> Transform3D:
	var row := index / SLOTS
	var x := (index % SLOTS - (SLOTS - 1) * 0.5) * (TileFactory.SIZE.x + SLOT_GAP)
	var origin := _board_origin + Vector3.RIGHT * x \
		+ _board.y * (_row_bottom(row) + TileFactory.SIZE.y * 0.5) \
		+ _board.z * (TileFactory.SIZE.z * 0.5 + 0.001)
	return Transform3D(_board, origin)


func _row_bottom(row: int) -> float:
	return 0.005 + row * (TileFactory.SIZE.y + ROW_GAP)
