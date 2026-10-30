class_name BotBrain
extends RefCounted
## What a 101 bot decides on its turn, as plain data (the seat's hands carry it out; tests run it headless).
## Draws the left discard only when it opens or işles with it, opens with the solver's best groups once they reach
## the bar (or with pairs), işles whatever fits, and discards the least useful tile: a lonely one while it has not
## opened (all that counts then is reaching the bar), the highest one after (what is left is penalty). It never
## discards an okey or an işlek tile if it can help it. Lower `skill` makes it throw a random tile now and then.

var skill := 1.0


## Should `p` take the left player's top discard instead of drawing from the pile?
func wants_side(game: OkeyGame, p: int, rack: Array[int]) -> bool:
	var tile := game.top_discard(OkeyGame.left_of(p))
	if tile < 0:
		return false
	var hand := rack.duplicate()
	hand.append(tile)
	if game.opened[p] == OkeyGame.Opened.NO:
		var groups := _opening(game, hand)
		return groups.any(func(g: Array) -> bool: return g.has(tile))
	if game.opened[p] == OkeyGame.Opened.SETS:
		for meld in game.melds:
			if meld.kind != Meld.Kind.PAIR and meld.extend_side(tile, game.okey, game.settings.run_wraps_13_1) >= 0:
				return true
		return not Solver.best(hand, game.okey, game.settings.run_wraps_13_1).left.has(tile)
	return false


## The rest of the turn after drawing: {open: groups to lay, extend: [meld index, id] pairs (indices count the
## groups just opened, appended in order), discard: id}. Steps that turn out illegal are simply skipped by the caller.
func plan(game: OkeyGame, p: int, rack: Array[int]) -> Dictionary:
	var rules := game.settings
	var hand := rack.duplicate()
	var out := {"open": [], "extend": [], "discard": -1}
	var opened: int = game.opened[p]
	if opened == OkeyGame.Opened.NO:
		out.open = _opening(game, hand)
		if not out.open.is_empty():
			opened = OkeyGame.Opened.PAIRS if out.open[0].size() == 2 else OkeyGame.Opened.SETS
	elif opened == OkeyGame.Opened.SETS:
		out.open = Solver.best(hand, game.okey, rules.run_wraps_13_1).groups
	else:
		out.open = Solver.pairs(hand, game.okey).groups
	for group: Array in out.open:
		for id: int in group:
			hand.erase(id)
	# Always keep one tile to discard: hand a group back if laying everything would leave none.
	while hand.is_empty() and not out.open.is_empty():
		hand.append_array(out.open.pop_back())
	if opened == OkeyGame.Opened.NO and game.opened[p] == OkeyGame.Opened.NO and not _reaches(game, out.open):
		for group: Array in out.open:
			hand.append_array(group)
		out.open = []

	var table: Array[Meld] = []
	for meld in game.melds:
		table.append(meld.copy())
	for group: Array in out.open:
		var ids: Array[int] = []
		ids.assign(group)
		var meld := Meld.make(ids, game.okey, rules.run_wraps_13_1, group.size() == 2)
		if meld:
			table.append(meld)
	var can_extend := opened == OkeyGame.Opened.SETS or (opened == OkeyGame.Opened.PAIRS and rules.pair_opener_can_extend)
	var grew := can_extend
	while grew and hand.size() > 1:
		grew = false
		for id in hand.duplicate():
			if hand.size() <= 1:
				break
			if OkeyTiles.is_joker(id, game.okey) and hand.size() > 2:
				continue # keep okeys for later unless they are the last thing between him and finishing
			for i in table.size():
				if table[i].kind != Meld.Kind.PAIR and table[i].extend(id, game.okey, rules.run_wraps_13_1):
					out.extend.append([i, id])
					hand.erase(id)
					grew = true
					break

	out.discard = _discard(game, opened, hand, table)
	return out


# Groups that open the hand now (sets if they reach the bar, else pairs if there are enough), or [].
func _opening(game: OkeyGame, hand: Array) -> Array:
	var ids: Array[int] = []
	ids.assign(hand)
	var need := game.opening_needed()
	var best := Solver.best(ids, game.okey, game.settings.run_wraps_13_1)
	if best.points >= need.points:
		return best.groups
	if game.settings.open_pairs_enabled:
		var pairs := Solver.pairs(ids, game.okey)
		if pairs.count >= need.pairs:
			return pairs.groups
	return []


func _reaches(game: OkeyGame, groups: Array) -> bool:
	if groups.is_empty():
		return false
	var need := game.opening_needed()
	if groups[0].size() == 2:
		return groups.size() >= need.pairs
	var total := 0
	for group: Array in groups:
		var ids: Array[int] = []
		ids.assign(group)
		var meld := Meld.make(ids, game.okey, game.settings.run_wraps_13_1)
		total += meld.points() if meld else 0
	return total >= need.points


func _discard(game: OkeyGame, opened: int, hand: Array, table: Array[Meld]) -> int:
	var candidates := hand.filter(func(id: int) -> bool: return not OkeyTiles.is_joker(id, game.okey))
	if candidates.is_empty():
		return hand[0]
	if randf() > skill:
		return candidates.pick_random()
	var ids: Array[int] = []
	ids.assign(hand)
	var spare: Array = Solver.best(ids, game.okey, game.settings.run_wraps_13_1).left
	var best := -1
	var best_score := -INF
	for id: int in candidates:
		var v := OkeyTiles.plays_as(id, game.okey)
		var score := 0.0
		if spare.has(id):
			score += 100.0
		if _fits(id, game, table):
			score -= 200.0
		if opened == OkeyGame.Opened.NO:
			score -= _neighbours(id, hand, game.okey) * 10.0 + v.y * 0.1
		else:
			score += v.y
		if score > best_score:
			best_score = score
			best = id
	return best


func _fits(id: int, game: OkeyGame, table: Array[Meld]) -> bool:
	for meld in table:
		if meld.kind != Meld.Kind.PAIR and meld.extend_side(id, game.okey, game.settings.run_wraps_13_1) >= 0:
			return true
	return false


# How many other tiles in the hand could go with this one: same colour within two, or same number.
func _neighbours(id: int, hand: Array, okey: Vector2i) -> int:
	var v := OkeyTiles.plays_as(id, okey)
	var count := 0
	for other: int in hand:
		if other == id or OkeyTiles.is_joker(other, okey):
			continue
		var w := OkeyTiles.plays_as(other, okey)
		if (w.x == v.x and absi(w.y - v.y) <= 2 and w.y != v.y) or (w.y == v.y and w.x != v.x):
			count += 1
	return count
