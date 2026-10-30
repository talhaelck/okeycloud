class_name OkeyGame
extends RefCounted
## The rules of one 101 Okey match, as pure data (no scene nodes; tests run it headless).
## It keeps what everyone can see (draw pile, discards, laid melds, who opened) and how many tiles each player
## should hold (`expected`). What a player actually holds is his physical rack: tiles that move without the rules
## knowing (stealing) only show up as a difference from `expected` (evidence for "Taş say!").
## Players 0-3 sit counter-clockwise, so play passes to the right: next = p + 1. Each player discards to his right,
## which is where the next player may take it from.
## Every action returns "" when allowed and done, otherwise the reason in Turkish for the HUD.

signal changed
## A penalty or bonus written on the score sheet during the hand (points < 0 is a bonus).
signal penalised(player: int, points: int, reason: String)
signal hand_ended(finisher: int)

enum Phase { DRAW, PLAY, OVER }
enum Opened { NO, SETS, PAIRS }

const PLAYERS := 4

var settings: GameSettings
var dealer := 0
var hand_number := 0
var indicator := -1
var okey := Vector2i.ZERO
var pile: Array[int] = []
## Each player's discards, oldest first (the last one is on top).
var discards: Array = [[], [], [], []]
var melds: Array[Meld] = []
var opened: Array[int] = [0, 0, 0, 0]
var expected: Array[int] = [0, 0, 0, 0]
var turn := 0
var phase := Phase.OVER
## Highest opening this hand (points) and largest pair opening, for open_must_beat_previous.
var best_open := 0
var best_pairs := 0
## This hand's penalties per player: Array of [points, reason].
var penalties: Array = [[], [], [], []]
var totals: Array[int] = [0, 0, 0, 0]
## One entry per finished hand: Array of 4 {score, lines: Array of [reason, points]}.
var history: Array = []
## Who finished the last hand (-1: the pile ran out).
var finisher := -1
## The joker a swap_okey handed back.
var taken := -1

var _side_tile := -1
var _side_used := false
var _opened_before_turn := false
var _turns_done: Array[int] = [0, 0, 0, 0]
var _okey_finish := false


func _init(rules: GameSettings = null) -> void:
	settings = rules if rules else GameSettings.new()


static func next_of(p: int) -> int:
	return (p + 1) % PLAYERS


## Whose discards `p` may take: the player on his left.
static func left_of(p: int) -> int:
	return (p + PLAYERS - 1) % PLAYERS


func top_discard(p: int) -> int:
	return discards[p].back() if not discards[p].is_empty() else -1


func pile_top() -> int:
	return pile.back() if not pile.is_empty() else -1


func match_over() -> bool:
	return phase == Phase.OVER and history.size() >= settings.hands_per_match


## Opening the player still needs: {points, pairs} (0 when no earlier opening raises the bar).
func opening_needed() -> Dictionary:
	var points := settings.open_threshold
	if settings.open_must_beat_previous and best_open >= points:
		points = best_open + 1
	var pairs := settings.open_pairs_min
	if settings.pairs_must_beat_previous and best_pairs >= pairs:
		pairs = best_pairs + 1
	return {"points": points, "pairs": pairs}


## Shuffles and deals a hand. Returns the four starting racks (tile ids); the dealer gets dealer_tiles, the others
## one fewer, and the dealer starts by discarding. The gösterge is never a sahte okey.
func deal() -> Array:
	var deck: Array[int] = []
	for id in OkeyTiles.COUNT:
		deck.append(id)
	deck.shuffle()
	for i in range(deck.size() - 1, -1, -1):
		if OkeyTiles.value(deck[i]) != OkeyTiles.FAKE:
			indicator = deck.pop_at(i)
			break
	okey = OkeyTiles.okey_of(OkeyTiles.value(indicator))
	var racks := []
	for p in PLAYERS:
		var count := settings.dealer_tiles if p == dealer else settings.dealer_tiles - 1
		racks.append(deck.slice(0, count))
		deck = deck.slice(count)
		expected[p] = count
	pile = deck
	discards = [[], [], [], []]
	melds.clear()
	opened = [0, 0, 0, 0]
	penalties = [[], [], [], []]
	_turns_done = [0, 0, 0, 0]
	best_open = 0
	best_pairs = 0
	finisher = -1
	turn = dealer
	_start_turn(Phase.PLAY)
	return racks


## Draw the top tile of the centre pile.
func draw_pile(p: int) -> String:
	var why := _check(p, Phase.DRAW)
	if why:
		return why
	if pile.is_empty():
		return "Destede taş kalmadı"
	pile.pop_back()
	expected[p] += 1
	phase = Phase.PLAY
	changed.emit()
	return ""


## Take the top discard of the player on the left.
func take_discard(p: int) -> String:
	var why := _check(p, Phase.DRAW)
	if why:
		return why
	var from := left_of(p)
	if discards[from].is_empty():
		return "Yanda alınacak taş yok"
	_side_tile = discards[from].pop_back()
	_side_used = false
	expected[p] += 1
	phase = Phase.PLAY
	changed.emit()
	return ""


## Lays groups of tiles (id arrays) as melds in front of `p`. Before the first opening they must reach the
## threshold together (or be enough pairs); afterwards any valid group may be laid.
func open(p: int, groups: Array) -> String:
	var why := _check(p, Phase.PLAY)
	if why:
		return why
	if groups.is_empty():
		return "Açılacak grup yok"
	# All groups of two are a çift opening; a player keeps laying the kind he opened with.
	var as_pairs: bool = opened[p] != Opened.SETS and groups.all(func(g: Array) -> bool: return g.size() == 2)
	if opened[p] == Opened.PAIRS and not as_pairs and not settings.pair_opener_can_open_sets:
		return "Çift açan per açamaz"
	var new_melds: Array[Meld] = []
	var total := 0
	for group: Array in groups:
		var ids: Array[int] = []
		ids.assign(group)
		var meld := Meld.make(ids, okey, settings.run_wraps_13_1, as_pairs)
		if meld == null:
			return "Geçersiz grup: " + ", ".join(ids.map(func(id: int) -> String: return OkeyTiles.name(id)))
		meld.owner = p
		new_melds.append(meld)
		total += meld.points()
	if opened[p] == Opened.NO:
		var need := opening_needed()
		if as_pairs:
			if not settings.open_pairs_enabled:
				return "Çift açmak kapalı"
			if groups.size() < need.pairs:
				return "Çift açmak için %d çift lazım, sende %d var" % [need.pairs, groups.size()]
		elif total < need.points:
			return "Açmak için %d lazım, sende %d var" % [need.points, total]
		opened[p] = Opened.PAIRS if as_pairs else Opened.SETS
		if as_pairs:
			best_pairs = maxi(best_pairs, groups.size())
		else:
			best_open = maxi(best_open, total)
	for meld in new_melds:
		melds.append(meld)
		expected[p] -= meld.size()
		if meld.tiles.has(_side_tile):
			_use_side_tile(p)
	changed.emit()
	return ""


## İşleme: adds one tile to any laid meld.
func extend(p: int, meld_index: int, id: int) -> String:
	var why := _check(p, Phase.PLAY)
	if why:
		return why
	if opened[p] == Opened.NO:
		return "İşlemek için önce açmalısın"
	if opened[p] == Opened.PAIRS and not settings.pair_opener_can_extend:
		return "Çift açan işleyemez"
	if meld_index < 0 or meld_index >= melds.size():
		return "Böyle bir per yok"
	if melds[meld_index].kind == Meld.Kind.PAIR:
		return "Çiftlere taş işlenmez"
	if not melds[meld_index].extend(id, okey, settings.run_wraps_13_1):
		return "%s buraya uymuyor" % OkeyTiles.name(id)
	expected[p] -= 1
	if id == _side_tile:
		_use_side_tile(p)
	changed.emit()
	return ""


## Puts a real tile in place of a joker in a laid meld; the joker (in `taken`) goes to the player.
func swap_okey(p: int, meld_index: int, id: int) -> String:
	var why := _check(p, Phase.PLAY)
	if why:
		return why
	if not settings.okey_swap_from_table:
		return "Masadan okey almak kapalı"
	if opened[p] == Opened.NO:
		return "Okey almak için önce açmalısın"
	if meld_index < 0 or meld_index >= melds.size():
		return "Böyle bir per yok"
	taken = melds[meld_index].swap_joker(id, okey)
	if taken < 0:
		return "Bu perdeki okeyin yerine %s geçmez" % OkeyTiles.name(id)
	if id == _side_tile:
		_use_side_tile(p)
	changed.emit()
	return ""


## Would this tile fit onto a laid meld (an "işlek taş")?
func playable(id: int) -> bool:
	if OkeyTiles.is_joker(id, okey):
		return false
	for meld in melds:
		if meld.kind != Meld.Kind.PAIR and meld.extend_side(id, okey, settings.run_wraps_13_1) >= 0:
			return true
	return false


## Penalties discarding this tile would cost now (empty when free): Array of [points, reason].
func discard_costs(p: int, id: int, finishing := false) -> Array:
	var out := []
	if finishing:
		return out
	if _side_tile >= 0 and not _side_used and settings.side_take_requires_open and turn == p:
		out.append([settings.side_take_penalty, "Yandan aldığı taşı kullanmadı"])
	if OkeyTiles.is_joker(id, okey):
		if settings.discard_okey_penalty:
			out.append([settings.penalty_unit, "Okey attı"])
	elif settings.discard_playable_penalty and playable(id):
		out.append([settings.penalty_unit, "İşlek taş attı"])
	return out


## Discards a tile to the right. `rack_after` is what the player holds once it is gone: empty (after opening)
## means he finished the hand.
func discard(p: int, id: int, rack_after: Array) -> String:
	var why := _check(p, Phase.PLAY)
	if why:
		return why
	var finishing := rack_after.is_empty() and opened[p] != Opened.NO
	for cost: Array in discard_costs(p, id, finishing):
		_penalise(p, cost[0], cost[1])
	discards[p].append(id)
	expected[p] -= 1
	_turns_done[p] += 1
	if finishing:
		finisher = p
		_okey_finish = OkeyTiles.is_joker(id, okey)
		_end_hand()
		return ""
	turn = next_of(p)
	if pile.is_empty():
		finisher = -1
		_end_hand()
		return ""
	_start_turn(Phase.DRAW)
	return ""


## Shows the gösterge's twin before your first turn is over (bonus, if the house rule is on).
func show_indicator(p: int, id: int) -> String:
	if not settings.indicator_show_bonus:
		return "Gösterge göstermek kapalı"
	if _turns_done[p] > 0:
		return "Göstergeyi ilk elinde göstermelisin"
	if OkeyTiles.value(id) != OkeyTiles.value(indicator) or id == indicator:
		return "Bu taş gösterge değil"
	for entry: Array in penalties[p]:
		if entry[1] == "Gösterge gösterdi":
			return "Zaten gösterdin"
	_penalise(p, -settings.penalty_unit, "Gösterge gösterdi")
	return ""


## Writes a penalty (or, negative, a bonus) on a player's sheet for this hand: stealing, "Yakala!", "Taş say!".
func penalise(p: int, points: int, reason: String) -> void:
	_penalise(p, points, reason)


## A tile taken off the pile behind the rules' back (stolen): the pile is the pile, so it is gone from it, but
## nobody's expected count changes. Returns false if it is not on the pile.
func lose_from_pile(id: int) -> bool:
	if not pile.has(id):
		return false
	pile.erase(id)
	changed.emit()
	return true


## A tile slipped into the pile (at the bottom) or put back on top after being caught.
func slip_into_pile(id: int, on_top := false) -> void:
	if on_top:
		pile.append(id)
	else:
		pile.insert(0, id)
	changed.emit()


## A tile taken out of a discard row behind the rules' back; returns where in the row it was (-1 if not there).
func lose_from_discards(seat: int, id: int) -> int:
	var index: int = discards[seat].find(id)
	if index >= 0:
		discards[seat].remove_at(index)
		changed.emit()
	return index


func restore_discard(seat: int, id: int, index: int) -> void:
	discards[seat].insert(clampi(index, 0, discards[seat].size()), id)
	changed.emit()


## Scores the finished hand from everyone's racks (tile ids left), adds it to `history` and `totals`, and returns
## the four {score, lines} entries.
func score(racks: Array) -> Array:
	var mult := 1
	var notes: Array[String] = []
	if finisher >= 0:
		if _okey_finish and settings.finish_with_okey_double:
			mult *= 2
			notes.append("okeyle bitti")
		if opened[finisher] == Opened.PAIRS and settings.finish_with_pairs_double:
			mult *= 2
			notes.append("çiftle bitti")
		if not _opened_before_turn and settings.finish_in_hand_bonus:
			mult *= 2
			notes.append("elden bitti")
	var suffix := "" if mult == 1 else " (×%d: %s)" % [mult, ", ".join(notes)]
	var result := []
	for p in PLAYERS:
		var lines := []
		if p == finisher:
			lines.append(["Bitirdi" + suffix, settings.finish_bonus * mult])
		elif opened[p] == Opened.NO:
			lines.append(["Açamadı" + suffix, settings.not_opened_penalty * mult])
		else:
			var left := 0
			for id: int in racks[p]:
				left += OkeyTiles.rack_points(id, okey, settings.okey_left_in_hand)
			var reason := "Elde kalan %d taş" % racks[p].size()
			if opened[p] == Opened.PAIRS and settings.pair_opener_double:
				left *= 2
				reason += ", çift açtı ×2"
			lines.append([reason + suffix, left * mult])
		for entry: Array in penalties[p]:
			lines.append([entry[1], entry[0]])
		var total := 0
		for line: Array in lines:
			total += line[1]
		totals[p] += total
		result.append({"score": total, "lines": lines})
	history.append(result)
	changed.emit()
	return result


## Starts over: scores, hands and the dealer.
func new_match() -> void:
	totals = [0, 0, 0, 0]
	history.clear()
	hand_number = 0
	dealer = 0
	phase = Phase.OVER


## Moves the deal to the next player for the following hand.
func next_hand() -> void:
	dealer = next_of(dealer)
	hand_number += 1


func _start_turn(new_phase: Phase) -> void:
	phase = new_phase
	_side_tile = -1
	_side_used = false
	_opened_before_turn = opened[turn] != Opened.NO
	changed.emit()


func _check(p: int, needed: Phase) -> String:
	if phase == Phase.OVER:
		return "El bitti"
	if p != turn:
		return "Sıra sende değil"
	if phase != needed:
		return "Önce taş çek" if phase == Phase.DRAW else "Taşını çektin, şimdi at"
	return ""


func _use_side_tile(p: int) -> void:
	_side_used = true
	if settings.feed_penalty and not _opened_before_turn:
		_penalise(left_of(p), settings.penalty_unit, "Yanındakine açtırdı")


func _penalise(p: int, points: int, reason: String) -> void:
	penalties[p].append([points, reason])
	penalised.emit(p, points, reason)


func _end_hand() -> void:
	phase = Phase.OVER
	changed.emit()
	hand_ended.emit(finisher)
