class_name Meld
extends RefCounted
## One group of tiles laid on the table (or checked before opening): a per (same number, different colours, 3-4),
## a seri (same colour, consecutive, 3+) or a çift (two identical tiles). Jokers stand in for any tile and score as
## the tile they replace.
## `tiles` are tile ids in table order, `reps` the value each one stands for. In a seri an ace after 13 is number
## 14 (12-13-1, with run_wraps_13_1) and scores ACE_HIGH; a joker in a per stands for an unnamed colour (-1).

enum Kind { NONE, SET, RUN, PAIR }

const ACE_HIGH := 11

var kind := Kind.NONE
var tiles: Array[int] = []
var reps: Array[Vector2i] = []
var owner := -1


## Builds the best-scoring valid meld from these tiles, or null. Pairs only count when `pairs` is set.
static func make(ids: Array[int], okey: Vector2i, wrap := false, pairs := false) -> Meld:
	if pairs:
		return _make_pair(ids, okey)
	var as_set := _make_set(ids, okey)
	var as_run := _make_run(ids, okey, wrap)
	if as_set and as_run:
		return as_set if as_set.points() >= as_run.points() else as_run
	return as_set if as_set else as_run


static func number_points(number: int) -> int:
	return ACE_HIGH if number == 14 else number


func points() -> int:
	var total := 0
	for r in reps:
		total += number_points(r.y)
	return total


func size() -> int:
	return tiles.size()


func copy() -> Meld:
	var out := Meld.new()
	out.kind = kind
	out.tiles = tiles.duplicate()
	out.reps = reps.duplicate()
	out.owner = owner
	return out


## Where `id` could be added: 0 at the front, 1 at the back, -1 if it does not fit. Pairs never grow.
func extend_side(id: int, okey: Vector2i, wrap := false) -> int:
	if kind == Kind.SET:
		if size() >= 4:
			return -1
		if OkeyTiles.is_joker(id, okey):
			return 1
		var v := OkeyTiles.plays_as(id, okey)
		return 1 if v.y == reps[0].y and not _colours().has(v.x) else -1
	if kind == Kind.RUN:
		if size() >= 13:
			return -1
		var first := reps[0].y
		var last := reps[-1].y
		var top := 14 if wrap else 13
		if OkeyTiles.is_joker(id, okey):
			return 1 if last < top else (0 if first > 1 else -1)
		var v := OkeyTiles.plays_as(id, okey)
		if v.x != reps[0].x:
			return -1
		if last < top and (v.y == last + 1 or (last == 13 and v.y == 1)):
			return 1
		return 0 if first > 1 and v.y == first - 1 and not (first == 2 and last == 14) else -1
	return -1


## Adds a tile at the end it fits (işleme); false if it does not fit.
func extend(id: int, okey: Vector2i, wrap := false) -> bool:
	var side := extend_side(id, okey, wrap)
	if side < 0:
		return false
	var rep: Vector2i
	if kind == Kind.SET:
		rep = Vector2i(-1, reps[0].y) if OkeyTiles.is_joker(id, okey) else OkeyTiles.plays_as(id, okey)
	elif side == 1:
		rep = Vector2i(reps[0].x, reps[-1].y + 1)
	else:
		rep = Vector2i(reps[0].x, reps[0].y - 1)
	if side == 1:
		tiles.append(id)
		reps.append(rep)
	else:
		tiles.insert(0, id)
		reps.insert(0, rep)
	return true


## Index of a joker that the real tile `id` can replace, or -1.
func joker_for(id: int, okey: Vector2i) -> int:
	if kind == Kind.PAIR or OkeyTiles.is_joker(id, okey):
		return -1
	var v := OkeyTiles.plays_as(id, okey)
	for i in size():
		if not OkeyTiles.is_joker(tiles[i], okey):
			continue
		if kind == Kind.SET and v.y == reps[i].y and not _colours().has(v.x):
			return i
		if kind == Kind.RUN and v.x == reps[i].x and (v.y == reps[i].y or (v.y == 1 and reps[i].y == 14)):
			return i
	return -1


## Puts the real tile `id` in place of a joker it matches and returns the joker's id (-1 if none matches).
func swap_joker(id: int, okey: Vector2i) -> int:
	var i := joker_for(id, okey)
	if i < 0:
		return -1
	var joker := tiles[i]
	tiles[i] = id
	if kind == Kind.SET:
		reps[i] = OkeyTiles.plays_as(id, okey)
	return joker


func _colours() -> Array[int]:
	var out: Array[int] = []
	for r in reps:
		if r.x >= 0:
			out.append(r.x)
	return out


static func _split(ids: Array[int], okey: Vector2i) -> Array:
	var real: Array[int] = []
	var jokers: Array[int] = []
	for id in ids:
		(jokers if OkeyTiles.is_joker(id, okey) else real).append(id)
	return [real, jokers]


static func _make_set(ids: Array[int], okey: Vector2i) -> Meld:
	if ids.size() < 3 or ids.size() > 4:
		return null
	var parts := _split(ids, okey)
	var real: Array[int] = parts[0]
	if real.is_empty():
		return null
	var number := OkeyTiles.plays_as(real[0], okey).y
	var meld := Meld.new()
	meld.kind = Kind.SET
	for id in real:
		var v := OkeyTiles.plays_as(id, okey)
		if v.y != number or meld._colours().has(v.x):
			return null
		meld.tiles.append(id)
		meld.reps.append(v)
	for id: int in parts[1]:
		meld.tiles.append(id)
		meld.reps.append(Vector2i(-1, number))
	return meld


static func _make_run(ids: Array[int], okey: Vector2i, wrap: bool) -> Meld:
	if ids.size() < 3 or ids.size() > 13:
		return null
	var parts := _split(ids, okey)
	var real: Array[int] = parts[0]
	var jokers: Array[int] = parts[1]
	if real.is_empty():
		return null
	var best: Meld
	for ace_high in ([false, true] if wrap else [false]):
		var meld := _run_layout(real, jokers, okey, ace_high)
		if meld and (best == null or meld.points() > best.points()):
			best = meld
	return best


# Lays real tiles of one colour in order and fills gaps with jokers, extra jokers going on top (they score more
# there) then below. With ace_high a real ace is 14.
static func _run_layout(real: Array[int], jokers: Array[int], okey: Vector2i, ace_high: bool) -> Meld:
	var colour := OkeyTiles.plays_as(real[0], okey).x
	var by_number := {}
	for id in real:
		var v := OkeyTiles.plays_as(id, okey)
		var n := 14 if ace_high and v.y == 1 else v.y
		if v.x != colour or by_number.has(n):
			return null
		by_number[n] = id
	var numbers: Array = by_number.keys()
	numbers.sort()
	var low: int = numbers[0]
	var high: int = numbers[-1]
	var spare := jokers.size() - (high - low + 1 - numbers.size())
	if spare < 0:
		return null
	var top := 14 if ace_high else 13
	var bottom := 2 if ace_high else 1
	var up := mini(spare, top - high)
	high += up
	low -= spare - up
	if low < bottom:
		return null
	var meld := Meld.new()
	meld.kind = Kind.RUN
	var next_joker := 0
	for n in range(low, high + 1):
		if by_number.has(n):
			meld.tiles.append(by_number[n])
		else:
			meld.tiles.append(jokers[next_joker])
			next_joker += 1
		meld.reps.append(Vector2i(colour, n))
	return meld


static func _make_pair(ids: Array[int], okey: Vector2i) -> Meld:
	if ids.size() != 2:
		return null
	var a := ids[0]
	var b := ids[1]
	var a_joker := OkeyTiles.is_joker(a, okey)
	var b_joker := OkeyTiles.is_joker(b, okey)
	if not (a_joker or b_joker) and OkeyTiles.plays_as(a, okey) != OkeyTiles.plays_as(b, okey):
		return null
	var meld := Meld.new()
	meld.kind = Kind.PAIR
	meld.tiles.assign(ids)
	var shown := OkeyTiles.plays_as(b if a_joker else a, okey)
	meld.reps.assign([shown, shown])
	return meld
