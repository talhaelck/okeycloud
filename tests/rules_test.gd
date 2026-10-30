extends SceneTree
## 101 rules engine: melds, işleme, okey swaps, the solver (against brute force), opening bars, penalties, scoring,
## and a few hundred whole hands played by four BotBrains (tile counts and conservation checked after every move).
## Run: godot --path . --headless --script res://tests/rules_test.gd

const R := 0
const K := 1 # siyah
const B := 2
const Y := 3
const OKEY := Vector2i(R, 6) # gösterge kırmızı 5
const J1 := 5 # the two red 6s are the jokers
const J2 := 57
const FAKE := 104

var fails := 0


func _init() -> void:
	seed(101)
	_melds()
	_extend_and_swap()
	_solver()
	_opening()
	_penalties_and_scoring()
	_simulate(300)
	print("FAILS: ", fails)
	quit(fails)


func t(color: int, number: int, copy := 0) -> int:
	return copy * 52 + color * 13 + number - 1


func ids(list: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(list)
	return out


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func points_of(list: Array, wrap := false, pairs := false) -> int:
	var meld := Meld.make(ids(list), OKEY, wrap, pairs)
	return meld.points() if meld else -1


func _melds() -> void:
	check(points_of([t(R, 7), t(K, 7), t(B, 7)]) == 21, "per of 7s")
	check(points_of([t(R, 7), t(R, 7, 1), t(B, 7)]) == -1, "per with a repeated colour")
	check(points_of([t(R, 7), t(K, 7), t(B, 7), t(Y, 7), t(R, 7, 1)]) == -1, "per of five")
	check(points_of([t(Y, 3), t(Y, 4), t(Y, 5)]) == 12, "seri 3-4-5")
	check(points_of([t(Y, 3), J1, t(Y, 5)]) == 12, "joker fills a gap")
	check(points_of([t(Y, 3), t(Y, 4), J1]) == 12, "joker extends a seri upward")
	check(points_of([t(Y, 12), t(Y, 13), J1]) == 36, "joker after 13 (or before 12) scores 36")
	check(points_of([t(K, 12), t(K, 13), t(K, 1)]) == -1, "12-13-1 is not a run in normal 101")
	check(points_of([t(K, 12), t(K, 13), t(K, 1)], true) == 36, "12-13-1 with the house rule: the ace is worth 11")
	check(points_of([t(Y, 12), t(Y, 13), J1]) == 36, "joker after 13 (or before 12) scores 36 (12-13-joker)")
	check(points_of([J1, t(K, 13), t(K, 1)]) == -1, "joker-13-1 is no run in normal 101")
	check(points_of([t(K, 1), t(K, 2), t(K, 3)]) == 6, "1-2-3 starts with the ace worth 1")
	check(points_of([t(K, 1), J1, t(K, 3)]) == 6, "1-joker-3")
	check(points_of([t(K, 1), t(K, 1, 1), t(K, 2)]) == -1, "two aces in a run")
	check(points_of([t(K, 13), t(K, 1), t(K, 2)]) == -1, "13-1-2 is never a seri")
	check(points_of([t(R, 5), FAKE, t(R, 7)]) == 18, "sahte okey plays as red 6")
	check(points_of([t(R, 9), t(B, 9), J1]) == 27, "per with a joker")
	check(points_of([J1, J2, t(B, 9)]) == 30, "two jokers make 9-10-11 rather than a per of 9s")
	check(points_of([t(B, 1), t(B, 2), t(B, 3), t(B, 4)]) == 10, "seri from 1")
	check(points_of([t(R, 4), t(R, 4, 1)], true, true) > 0, "pair")
	check(points_of([t(R, 4), t(B, 4)], true, true) == -1, "not a pair")
	check(points_of([t(R, 4), J1], true, true) > 0, "pair with a joker")


func _extend_and_swap() -> void:
	var run := Meld.make(ids([t(Y, 3), t(Y, 4), t(Y, 5)]), OKEY)
	check(run.extend_side(t(Y, 6), OKEY) == 1, "seri takes the next tile at the back")
	check(run.extend_side(t(Y, 2), OKEY) == 0, "seri takes the previous tile at the front")
	check(run.extend_side(t(Y, 7), OKEY) == -1, "seri refuses a gap")
	check(run.extend_side(t(B, 6), OKEY) == -1, "seri refuses another colour")
	var top := Meld.make(ids([t(B, 11), t(B, 12), t(B, 13)]), OKEY)
	check(top.extend_side(t(B, 1), OKEY) == -1, "the ace does not go after 13 in normal 101")
	var top_wrap := Meld.make(ids([t(B, 11), t(B, 12), t(B, 13)]), OKEY, true)
	check(top_wrap.extend_side(t(B, 1), OKEY, true) == 1, "with the house rule the ace goes after 13")
	check(top.extend_side(J1, OKEY) == 0, "a joker can only go before 11 in normal 101")
	var per := Meld.make(ids([t(R, 7), t(K, 7), t(B, 7)]), OKEY)
	check(per.extend(t(Y, 7), OKEY) and per.size() == 4, "per takes its fourth colour")
	check(not per.extend(t(R, 7, 1), OKEY), "a full per takes nothing")
	var with_joker := Meld.make(ids([t(Y, 3), J1, t(Y, 5)]), OKEY)
	check(with_joker.swap_joker(t(Y, 6), OKEY) == -1, "wrong tile cannot free the joker")
	check(with_joker.swap_joker(t(Y, 4), OKEY) == J1 and with_joker.tiles.has(t(Y, 4)), "yellow 4 frees the joker")
	var per_joker := Meld.make(ids([t(R, 9), t(B, 9), J2]), OKEY)
	check(per_joker.swap_joker(t(R, 9, 1), OKEY) == -1, "a colour already in the per cannot free the joker")
	check(per_joker.swap_joker(t(Y, 9), OKEY) == J2, "a missing colour frees the joker")


func _solver() -> void:
	var hand := ids([t(R, 10), t(R, 11), t(R, 12), t(R, 13), t(K, 13), t(B, 13), t(Y, 13), t(Y, 2)])
	var best := Solver.best(hand, OKEY)
	check(best.points == 85, "solver 85 (got %d)" % best.points)
	check(best.left == ids([t(Y, 2)]), "solver leaves yellow 2")
	var pairs := Solver.pairs(ids([t(R, 4), t(R, 4, 1), t(B, 5), t(B, 5, 1), J1, t(Y, 7), t(K, 2)]), OKEY)
	check(pairs.count == 3, "three pairs (got %d)" % pairs.count)

	var deck: Array[int] = []
	for id in OkeyTiles.COUNT:
		deck.append(id)
	# Small hands from a narrow slice of numbers so that melds actually happen: high numbers, and the ends of the
	# range (1, 2, 3, 11, 12, 13) where the 12-13-1 house rule matters.
	var slices := [{"wrap": false, "numbers": range(8, 14)}, {"wrap": false, "numbers": [1, 2, 3, 11, 12, 13]},
		{"wrap": true, "numbers": [1, 2, 3, 11, 12, 13]}, {"wrap": true, "numbers": range(8, 14)}]
	for slice: Dictionary in slices:
		for round in 100:
			deck.shuffle()
			var okey := OkeyTiles.okey_of(OkeyTiles.value(deck[0])) if OkeyTiles.value(deck[0]) != OkeyTiles.FAKE else OKEY
			var wrap: bool = slice.wrap
			var narrow := deck.filter(func(id: int) -> bool:
				return OkeyTiles.plays_as(id, okey).y in slice.numbers or OkeyTiles.is_joker(id, okey))
			var sample := ids(narrow.slice(0, 8))
			var solved := Solver.best(sample, okey, wrap)
			var brute := _brute(sample, okey, wrap)
			if solved.points != brute:
				check(false, "solver %d vs brute force %d (wrap %s) on %s" % [solved.points, brute, wrap, sample])
				continue
			var total := 0
			var seen: Array[int] = solved.left.duplicate()
			for group: Array in solved.groups:
				var meld := Meld.make(ids(group), okey, wrap)
				check(meld != null, "solver group is a valid meld")
				total += meld.points() if meld else 0
				seen.append_array(group)
			seen.sort()
			var sorted := sample.duplicate()
			sorted.sort()
			check(total == solved.points and seen == sorted, "solver groups add up and use every tile once")

	var started := Time.get_ticks_usec()
	for round in 20:
		deck.shuffle()
		Solver.best(ids(deck.slice(0, 22)), OKEY)
	print("solver: %.1f ms per 22-tile hand" % ((Time.get_ticks_usec() - started) / 20000.0))


# Best total by trying every group the first tile can join.
func _brute(hand: Array[int], okey: Vector2i, wrap: bool) -> int:
	if hand.is_empty():
		return 0
	var first := hand[0]
	var rest := hand.slice(1)
	var best := _brute(rest, okey, wrap)
	for mask in 1 << rest.size():
		var group: Array[int] = [first]
		var others: Array[int] = []
		for i in rest.size():
			(group if mask & (1 << i) else others).append(rest[i])
		if group.size() < 3:
			continue
		var meld := Meld.make(group, okey, wrap)
		if meld:
			best = maxi(best, meld.points() + _brute(others, okey, wrap))
	return best


func _game(turn := 0) -> OkeyGame:
	var game := OkeyGame.new()
	game.deal()
	game.okey = OKEY
	game.turn = turn
	game.phase = OkeyGame.Phase.PLAY
	return game


func _opening() -> void:
	var game := _game()
	var low := [[t(R, 10), t(R, 11), t(R, 12)], [t(K, 9), t(B, 9), t(Y, 9)], [t(Y, 5), t(Y, 6), t(Y, 7)]] # 33+27+18 = 78
	check(game.open(0, low).begins_with("Açmak için 101"), "78 does not open")
	var enough := [[t(R, 10), t(R, 11), t(R, 12), t(R, 13)], [t(K, 13), t(B, 13), t(Y, 13)], [t(K, 9), t(B, 9), t(Y, 9)]] # 46+39+27
	check(game.open(0, enough) == "" and game.opened[0] == OkeyGame.Opened.SETS, "112 opens")
	check(game.best_open == 112 and game.opening_needed().points == 113, "the next opener must beat 112")
	check(game.melds.size() == 3, "three melds on the table")
	check(game.open(0, [[t(B, 1), t(B, 2), t(B, 3)]]) == "", "after opening any seri can be laid")
	check(game.extend(0, 0, t(R, 9)) == "", "işleme onto own seri")
	check(game.extend(0, 1, t(R, 13, 1)) == "", "işleme the red 13 onto the per of 13s")
	check(game.extend(0, 1, t(R, 13)) != "", "a full per refuses")

	var pairs_game := _game(1)
	var five := [[t(R, 1), t(R, 1, 1)], [t(K, 2), t(K, 2, 1)], [t(B, 3), t(B, 3, 1)], [t(Y, 4), t(Y, 4, 1)]]
	check(pairs_game.open(1, five) != "", "four pairs do not open")
	five.append([t(Y, 8), J1])
	check(pairs_game.open(1, five) == "" and pairs_game.opened[1] == OkeyGame.Opened.PAIRS, "five pairs open")
	check(pairs_game.open(1, [[t(B, 11), t(B, 12), t(B, 13)]]) != "", "a pair opener cannot lay a seri")
	check(pairs_game.extend(1, 0, t(R, 1)) != "", "nothing is işled onto a pair")


func _penalties_and_scoring() -> void:
	var game := _game()
	var enough := [[t(R, 10), t(R, 11), t(R, 12), t(R, 13)], [t(K, 13), t(B, 13), t(Y, 13)], [t(K, 9), t(B, 9), t(Y, 9)]]
	game.open(0, enough)
	check(game.discard_costs(0, J1).size() == 1, "discarding an okey costs")
	check(game.discard_costs(0, t(R, 9)).size() == 1, "discarding an işlek tile costs")
	check(game.discard_costs(0, t(B, 4)).is_empty(), "discarding a dead tile is free")
	check(game.discard(0, t(B, 4), [t(Y, 1)]) == "" and game.turn == 1 and game.phase == OkeyGame.Phase.DRAW,
		"discard passes the turn to the right, who draws")
	check(game.discard(1, t(B, 5), [t(Y, 2)]) == "Önce taş çek", "cannot discard before drawing")
	check(game.take_discard(1) == "" and game.expected[1] == game.settings.dealer_tiles, "side take")
	check(game.discard_costs(1, t(B, 6))[0][1] == "Yandan aldığı taşı kullanmadı", "unused side tile costs")

	# Player 0 finishes by discarding an okey: everyone pays double, the finisher gets double the bonus.
	var end := _game()
	end.open(0, enough)
	end.discard(0, J1, [])
	check(end.phase == OkeyGame.Phase.OVER and end.finisher == 0, "empty rack after the discard finishes")
	var racks := [[], [t(R, 2), t(B, 3)], [], [t(Y, 13)]]
	end.opened[1] = OkeyGame.Opened.SETS
	end.opened[3] = OkeyGame.Opened.PAIRS
	var result := end.score(racks)
	# Finished with an okey (×2) in the turn he first opened (elden, ×2): ×4.
	check(result[0].score == -404, "finisher -101 × 4 (got %d)" % result[0].score)
	check(result[1].score == 20, "opened player pays his rack × 4 (got %d)" % result[1].score)
	check(result[2].score == 808, "player who never opened pays 202 × 4 (got %d)" % result[2].score)
	check(result[3].score == 104, "pair opener pays double: 13 × 2 × 4 (got %d)" % result[3].score)


# Whole hands with four bots on the bare rules; racks are plain arrays.
func _simulate(hands: int) -> void:
	var brain := BotBrain.new()
	var finished := 0
	var opened := 0
	var moves := 0
	var started := Time.get_ticks_msec()
	for h in hands:
		var game := OkeyGame.new()
		game.dealer = h % 4
		var racks := game.deal()
		var guard := 0
		while game.phase != OkeyGame.Phase.OVER and guard < 400:
			guard += 1
			var p := game.turn
			var rack: Array[int] = racks[p]
			if game.phase == OkeyGame.Phase.DRAW:
				if brain.wants_side(game, p, rack):
					var tile := game.top_discard(OkeyGame.left_of(p))
					check(game.take_discard(p) == "", "bot side take")
					rack.append(tile)
				else:
					var tile := game.pile_top()
					check(game.draw_pile(p) == "", "bot draw")
					rack.append(tile)
			var plan := brain.plan(game, p, rack)
			if not plan.open.is_empty() and game.open(p, plan.open) == "":
				for group: Array in plan.open:
					for id: int in group:
						rack.erase(id)
			for step: Array in plan.extend:
				if rack.has(step[1]) and game.extend(p, step[0], step[1]) == "":
					rack.erase(step[1])
			check(rack.has(plan.discard), "bot discards a tile it holds")
			rack.erase(plan.discard)
			check(game.discard(p, plan.discard, rack) == "", "bot discard")
			moves += 1
			for q in 4:
				if game.expected[q] != racks[q].size():
					check(false, "hand %d: expected %d tiles for %d, rack has %d" % [h, game.expected[q], q, racks[q].size()])
			_check_conservation(game, racks)
		check(game.phase == OkeyGame.Phase.OVER, "hand %d ends" % h)
		game.score(racks)
		finished += 1 if game.finisher >= 0 else 0
		opened += game.opened.filter(func(o: int) -> bool: return o != OkeyGame.Opened.NO).size()
	print("simulation: %d hands, %d finished, %.1f players opened per hand, %d turns, %d ms" % [
		hands, finished, opened / float(hands), moves, Time.get_ticks_msec() - started])
	# The 101 pile is only ~20 tiles, so most hands run it out; bots must still finish some.
	check(finished > hands / 10, "bots finish some hands")


func _check_conservation(game: OkeyGame, racks: Array) -> void:
	var all: Array[int] = game.pile.duplicate()
	all.append(game.indicator)
	for list: Array in discards_of(game):
		all.append_array(list)
	for meld in game.melds:
		all.append_array(meld.tiles)
	for rack: Array in racks:
		all.append_array(rack)
	all.sort()
	for i in all.size():
		if all[i] != i:
			check(false, "tile %d missing or duplicated" % i)
			return
	if all.size() != OkeyTiles.COUNT:
		check(false, "%d tiles in play instead of 106" % all.size())


func discards_of(game: OkeyGame) -> Array:
	return game.discards
