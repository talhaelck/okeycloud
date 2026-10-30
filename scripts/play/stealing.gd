class_name Stealing
extends Node
## Taking what is not yours (docs/design/stealing.md), for the player and the bots alike:
## - which grabs are thefts, by the house rules: a tile from a neighbour's rack, any tile in a discard row that is
##   not a legal side take, the pile out of turn; putting one of your own tiles into someone's rack ("plant", to keep
##   your count right after a theft) or slipping it into the pile ("dump") is watched the same way;
## - Visibility watches every theft; whoever had the hand in plain view long enough is a witness;
## - "Yakala!" (F, at the player you look at): right only if you witnessed his theft in the last catch_window
##   seconds. The tile goes back and he pays catch_penalty; a wrong call costs the caller false_accusation_penalty;
## - "Taş say!" (C): if he holds more tiles than he should, he pays count_check_penalty and what he took is given
##   back; if not, the one who asked pays. A thief who planted a tile in return cannot be counted out;
## - friend mode writes no penalties, it only tells everyone;
## - what the player feels: the "!" over the heads of those watching his hand, "?" for a glance; a movement out of
##   the corner of his eye ("◀ kıpırtı"); a tile clicking where it should not (Shift steals quietly and slowly).
## Bots react the same way: they turn toward a glimpse or a click, call "Yakala!" when they are witnesses, count a
## neighbour's tiles when their own rack is short, and greedy ones steal (Bot.mischief).

const PLAYER := 0
const COOLDOWN := 2.5 # seconds between two calls by the same player
const CLICK_HEARD := 0.6 # chance a vigilant dayı turns toward a tile clicking where it should not

var director: GameDirector
var visibility: Visibility = Visibility.new()
## For the HUD score line.
var stolen := 0
var caught := 0

var _held: Visibility.TheftEvent # the theft the player's hand is in the middle of
var _ledger: Array[Visibility.TheftEvent] = [] # every finished theft of this hand not given back yet (Taş say!)
var _cooldown := {}
var _cue_timer := 0.0


func setup() -> void:
	visibility.seats = director.seats
	visibility.memory = maxf(director.game.settings.catch_window, 1.0)
	add_child(visibility)
	visibility.witnessed.connect(_on_witnessed)
	visibility.glimpsed.connect(_on_glimpsed)
	director.hand.picking.connect(_on_picking)
	director.hand.steal_check = func(tile: Tile) -> bool: return theft_kind(tile) != ""


func new_hand() -> void:
	_held = null
	_ledger.clear()
	visibility.events.clear()


func rules() -> GameSettings:
	return director.game.settings


# --- What counts as stealing -----------------------------------------------------------------------------------

## The kind of theft picking this tile up would be: "rack", "discard", "pile", or "" if it is not a theft or the
## house rules do not allow that kind. Legal moves (your rack, your draw) are never thefts.
func theft_kind(tile: Tile, thief := PLAYER) -> String:
	var r := rules()
	if not r.stealing_enabled or tile == null:
		return ""
	var game := director.game
	if tile.holder is Rack:
		return "rack" if tile.holder != director.seats[thief].rack and r.steal_from_racks else ""
	if tile.holder != director.table:
		return ""
	if tile == director.table.pile_top():
		if thief == game.turn and game.phase == OkeyGame.Phase.DRAW:
			return ""
		return "pile" if r.steal_from_pile else ""
	for seat in OkeyGame.PLAYERS:
		if director.table.discards(seat).has(tile):
			var legal := seat == OkeyGame.left_of(thief) and tile.id == game.top_discard(seat) \
				and thief == game.turn and game.phase == OkeyGame.Phase.DRAW
			return "" if legal or not r.steal_from_discards else "discard"
	return ""


## Why the player may not take this tile even as a theft ("" if he may).
func refusal(tile: Tile) -> String:
	if not rules().stealing_enabled:
		return "Bu masada taş çalmak yok"
	return "Bu masada buradan çalmak yok"


func _on_picking(tile: Tile, origin: Node) -> void:
	var kind := theft_kind(tile)
	if kind == "":
		return
	var victim := -1
	var slot := -1
	if kind == "rack":
		victim = _seat_of_rack(origin as Rack)
		slot = (origin as Rack).slot_of(tile)
	elif kind == "discard":
		for seat in OkeyGame.PLAYERS:
			slot = director.table.discards(seat).find(tile)
			if slot >= 0:
				victim = seat
				break
	_held = visibility.begin(PLAYER, kind, tile, victim, slot)
	if not director.hand.sneaking:
		click(tile.global_position, PLAYER)


## Called by GameDirector for every drop of the player's hand before anything else; true if it placed the tile.
func on_drop(tile: Tile, origin: Node, drop: Dictionary) -> bool:
	if _held == null or _held.tile != tile:
		return false
	var event := _held
	_held = null
	var game := director.game
	var table := director.table
	match event.kind:
		"rack":
			if drop.get("rack") == origin or drop.is_empty():
				visibility.cancel(event)
				return false # back into the rack it came from
		"discard":
			var back: bool = drop.is_empty() or (drop.get("zone", {}).get("kind") == "discard" and drop.zone.seat == event.victim)
			if back or event.caught:
				table.restore_discard(tile, event.victim, event.from_slot)
				if not event.caught:
					visibility.cancel(event)
				return true
			game.lose_from_discards(event.victim, tile.id)
		"pile":
			var back: bool = drop.is_empty() or drop.get("zone", {}).get("kind") == "pile"
			if back or event.caught:
				director.show_pile()
				if not event.caught:
					visibility.cancel(event)
				return true
			game.lose_from_pile(tile.id)
			director.show_pile()
		"plant":
			if drop.get("rack") != director.seats[event.victim].rack:
				visibility.cancel(event)
				return false
		"dump":
			if drop.get("zone", {}).get("kind") != "pile":
				visibility.cancel(event)
				return false
			_finish(event, tile.global_position)
			_into_pile(tile)
			return true
	if event.caught:
		return false
	_finish(event, tile.global_position)
	if event.kind != "plant":
		stolen += 1
	return false


func _finish(event: Visibility.TheftEvent, at: Vector3) -> void:
	visibility.finish(event)
	_ledger.append(event)
	if not director.hand.sneaking:
		click(at, event.thief)


# A tile slipped into the bottom of the pile disappears into it (the pile only has its top as a real tile).
func _into_pile(tile: Tile) -> void:
	director.game.slip_into_pile(tile.id)
	director.forget_tile(tile)
	director.show_pile()


## Bots start and end their thefts through these, so they are watched like the player's.
func bot_begin(thief: int, kind: String, tile: Tile, victim: int, slot: int, hand: Callable) -> Visibility.TheftEvent:
	var event := visibility.begin(thief, kind, tile, victim, slot)
	event.hand = hand
	click(tile.global_position, thief)
	return event


func bot_finish(event: Visibility.TheftEvent) -> void:
	if event.caught:
		return
	_finish(event, event.tile.global_position)


## Would a hand at `point` go unnoticed right now? Nobody but the thief may have it in plain view, and the victim
## must not even glimpse it.
func unseen(thief: int, point: Vector3, victim: int, risk := 0.0) -> bool:
	for viewer in OkeyGame.PLAYERS:
		if viewer == thief:
			continue
		var seen := visibility.sees(viewer, point)
		if seen >= Visibility.SEEN or (viewer == victim and seen > 0.0) or seen > risk:
			return false
	return true


## A chance for `thief` (a bot) to steal right now: {kind, victim, tile}, or {} if every target is watched.
## Targets are what his long reach can get: the near ends of his neighbours' racks (he sees only their backs, so
## he takes blind) and the row his left-hand neighbour discards into (faces up: he takes what helps him most).
## The greedier he is, the more he risks a glance out of the corner of someone's eye.
func opportunity(thief: int, greed := 0.5) -> Dictionary:
	var r := rules()
	if not r.stealing_enabled:
		return {}
	var risk := Visibility.GLIMPSE if greed > 0.5 else 0.0
	var head := director.seats[thief].head_anchor.global_position
	var options := []
	if r.steal_from_racks:
		for victim in [OkeyGame.left_of(thief), OkeyGame.next_of(thief)]:
			var tiles := director.seats[victim].rack.tiles()
			if tiles.is_empty():
				continue
			tiles.sort_custom(func(a: Tile, b: Tile) -> bool: return a.global_position.distance_to(head) < b.global_position.distance_to(head))
			options.append({"kind": "rack", "victim": victim, "tile": tiles[0]})
	if r.steal_from_discards:
		var victim := OkeyGame.left_of(thief)
		var row: Array = director.table.discards(victim)
		var best: Tile = null
		var best_gain := 0
		var mine := director.rack_ids(director.seats[thief].rack)
		var base: int = Solver.best(mine, director.game.okey).points
		for tile: Tile in row:
			var with := mine.duplicate()
			with.append(tile.id)
			var gain: int = Solver.best(with, director.game.okey).points - base
			if gain > best_gain:
				best = tile
				best_gain = gain
		if best:
			options.append({"kind": "discard", "victim": victim, "tile": best})
	options.shuffle()
	for option: Dictionary in options:
		if unseen(thief, (option.tile as Tile).global_position, option.victim, risk):
			return option
	return {}


## At the start of a bot's turn he looks at his rack: a tile short (and he is the careful kind), he counts his
## neighbours' racks (anyone can count the backs) and calls "Taş say!" on one with too many. Now and then a
## vigilant dayı counts the table anyway.
func bot_turn_start(p: int, vigilance: float) -> void:
	var missing := director.game.expected[p] - held_count(p)
	var suspects := [OkeyGame.left_of(p), OkeyGame.next_of(p)]
	if missing <= 0:
		if randf() > 0.08 * vigilance:
			return
		suspects = range(OkeyGame.PLAYERS)
	elif randf() > 0.3 + 0.7 * vigilance:
		return
	for other: int in suspects:
		if other != p and held_count(other) > director.game.expected[other]:
			count_check(p, other)
			return


# --- Watching the player's hand ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if director == null or director.game == null:
		return
	_watch_plant()
	_show_awareness()
	_cue_timer -= delta
	if _cue_timer <= 0.0:
		director.hud.set_cue("")


# Carrying one of his own tiles onto someone else's rack or the pile is watched like a theft from the moment it
# hovers there.
func _watch_plant() -> void:
	var hand := director.hand
	var own := director.seats[PLAYER].rack
	if hand.held == null or hand.origin() != own or not rules().stealing_enabled:
		if _held and _held.kind in ["plant", "dump"] and hand.held == null:
			_held = null
		return
	var target := hand.drop_target()
	var kind := ""
	var victim := -1
	if target.has("rack") and target.rack != own:
		kind = "plant"
		victim = _seat_of_rack(target.rack)
	elif target.get("zone", {}).get("kind") == "pile":
		kind = "dump"
	if _held and (_held.kind != kind or _held.victim != victim):
		visibility.cancel(_held)
		_held = null
	if kind != "" and _held == null:
		_held = visibility.begin(PLAYER, kind, hand.held, victim, -1)


# The "!" over the head of everyone who is watching the player's hand while it is stealing.
func _show_awareness() -> void:
	var event := _held
	if event == null:
		var last := visibility.catchable(PLAYER, Visibility.AFTER)
		event = last
	for p in range(1, OkeyGame.PLAYERS):
		var buddy := director.seats[p].buddy
		if buddy == null:
			continue
		if event == null:
			buddy.set_alert_level(-1.0)
			continue
		var level := event.exposure[p] / Visibility.WITNESS_TIME
		buddy.set_alert_level(level if level > 0.0 else -1.0, event.glimpsed.has(p))


## A tile clicking where it should not: dayıs who hear it (by their vigilance) turn to look.
func click(at: Vector3, by: int) -> void:
	director.play_click(at)
	for p in range(1, OkeyGame.PLAYERS):
		if p == by:
			continue
		var bot := director.bot(p)
		if bot and bot.watcher and randf() < CLICK_HEARD * bot.vigilance:
			bot.watcher.notice(at)


func _on_witnessed(event: Visibility.TheftEvent, viewer: int) -> void:
	var thief_name := director.name_of(event.thief)
	if viewer == PLAYER:
		director.hud.set_cue("Gördün: %s taş çalıyor!" % thief_name, 0, [["F"], "Yakala!"])
		_cue_timer = rules().catch_window
		return
	var bot := director.bot(viewer)
	if bot == null or bot.watcher == null:
		return
	bot.watcher.stare_at(director.seats[event.thief])
	# A witness calls it, if he is the kind who does, after a moment to take it in.
	if randf() > 0.3 + 0.7 * bot.vigilance:
		return
	await get_tree().create_timer(randf_range(0.3, 0.8) / (0.6 + bot.vigilance)).timeout
	accuse(viewer, event.thief)


func _on_glimpsed(event: Visibility.TheftEvent, viewer: int) -> void:
	if viewer == PLAYER:
		var camera := director.hand.camera
		var side := (event.hand_point() - camera.global_position).dot(camera.global_basis.x)
		director.hud.set_cue("Solunda bir kıpırtı" if side < 0.0 else "Sağında bir kıpırtı", -1 if side < 0.0 else 1)
		_cue_timer = 1.5
		return
	var bot := director.bot(viewer)
	if bot and bot.watcher and randf() < 0.4 + 0.5 * bot.vigilance:
		bot.watcher.notice(event.hand_point())


# --- Calling it ---------------------------------------------------------------------------------------------------

## "Yakala!": `accuser` says `accused` is stealing right now.
func accuse(accuser: int, accused: int) -> void:
	if not _ready_to_call(accuser) or accused == accuser or director.game.phase == OkeyGame.Phase.OVER:
		return
	var event := visibility.catchable(accused, rules().catch_window)
	var right := event != null and event.witnesses.has(accuser)
	director.note("%s: \"Yakala!\" (%s)" % [director.name_of(accuser), director.name_of(accused)])
	if right:
		_caught(event, accuser, "Taş çalarken yakalandı", rules().catch_penalty)
	else:
		_penalty(accuser, rules().false_accusation_penalty, "Haksız yere \"Yakala!\" dedi")
		if accuser == PLAYER:
			director.hud.toast("Yanlış suçlama!")
		_table_looks_at(accuser)


## "Taş say!": `challenger` has `target`'s tiles counted.
func count_check(challenger: int, target: int) -> void:
	if not rules().count_check_enabled or not _ready_to_call(challenger) or challenger == target \
			or director.game.phase == OkeyGame.Phase.OVER:
		return
	var extra := held_count(target) - director.game.expected[target]
	director.note("%s: \"Taş say!\" (%s, %s)" % [director.name_of(challenger), director.name_of(target),
		"fazla %d" % extra if extra > 0 else "tamam"])
	if extra <= 0:
		_penalty(challenger, rules().count_check_penalty, "Boşuna taş saydırdı")
		if challenger == PLAYER:
			director.hud.toast("Taşları tam çıktı!")
		_table_looks_at(challenger)
		return
	var given := 0
	# The newest thefts first: the tile he holds too many is most likely the last one he took.
	var newest := _ledger.duplicate()
	newest.reverse()
	for event: Visibility.TheftEvent in newest:
		if event.thief == target and event.kind in ["rack", "discard", "pile"] and given < extra:
			if give_back(event):
				given += 1
	# Anything over that nobody can name goes into the pile.
	var rack := director.seats[target].rack
	while given < extra and not rack.tiles().is_empty():
		var tile: Tile = rack.tiles().pick_random()
		rack.release(tile)
		_into_pile(tile)
		given += 1
	_penalty(target, rules().count_check_penalty, "Taş sayımında %d fazla çıktı" % extra)
	_reactions(target, challenger)


## How many tiles a player physically holds: his rack, plus a tile in the player's hand that is his or stolen
## (not a legal draw on its way to his rack, which the rules do not count yet).
func held_count(seat: int) -> int:
	var count := director.seats[seat].rack.tiles().size()
	var hand := director.hand
	if seat == PLAYER and hand.held and (hand.origin() == director.seats[PLAYER].rack or _held != null):
		count += 1
	return count


func _caught(event: Visibility.TheftEvent, by: int, reason: String, points: int) -> void:
	event.caught = true
	give_back(event)
	_penalty(event.thief, points, reason)
	if event.thief == PLAYER:
		caught += 1
	_reactions(event.thief, by)


func _reactions(culprit: int, by: int) -> void:
	Sfx.ui("sting_caught", -2.0)
	director.fx_caught(culprit, by)
	_table_looks_at(culprit)
	var buddy := director.seats[culprit].buddy
	if culprit != PLAYER and buddy:
		buddy.shake_head()
	if culprit == PLAYER:
		director.hud.stamp("YAKALANDIN!", Color("e0402f"))
	elif by == PLAYER:
		director.hud.stamp("YAKALADIN!", Color("57d98a"))
	else:
		director.note("%s yakalandı!" % director.name_of(culprit), culprit)


func _table_looks_at(seat: int) -> void:
	for p in range(1, OkeyGame.PLAYERS):
		var bot := director.bot(p)
		if p != seat and bot and bot.watcher:
			bot.watcher.stare_at(director.seats[seat], 2.0)


func _penalty(p: int, points: int, reason: String) -> void:
	if rules().friend_mode:
		director.note("%s: %s (arkadaş modu, ceza yok)" % [director.name_of(p), reason])
		return
	director.game.penalise(p, points, reason)


func _ready_to_call(seat: int) -> bool:
	var t := visibility.now()
	if t < float(_cooldown.get(seat, 0.0)):
		return false
	_cooldown[seat] = t + COOLDOWN
	return true


## Puts a stolen tile back where it was taken from (or takes a planted/dumped one back to the thief). False if it
## is no longer anywhere it can be taken from (laid down, discarded).
func give_back(event: Visibility.TheftEvent) -> bool:
	_ledger.erase(event)
	event.caught = true
	var tile := event.tile
	if not is_instance_valid(tile) and event.kind != "dump":
		return false
	var hand := director.hand
	if event.thief == PLAYER and hand.held == tile:
		if event.kind in ["plant", "dump"]:
			_held = null
			hand.give_back()
			return true
		hand.give_back() # on_drop sees the event caught and sends it home
		return true
	var game := director.game
	var table := director.table
	match event.kind:
		"rack":
			if tile.holder == director.seats[event.victim].rack:
				return true # caught before he had it out of the rack
			if not tile.holder is Rack:
				return false
			(tile.holder as Rack).release(tile)
			var rack := director.seats[event.victim].rack
			rack.put(tile, rack.nearest_free(maxi(event.from_slot, 0)), true, 0.35)
		"discard":
			if table.discards(event.victim).has(tile):
				return true # caught before he had it out of the row
			if not tile.holder is Rack:
				return false
			(tile.holder as Rack).release(tile)
			table.restore_discard(tile, event.victim, event.from_slot)
			game.restore_discard(event.victim, tile.id, event.from_slot)
		"pile":
			if not tile.holder is Rack:
				return false
			(tile.holder as Rack).release(tile)
			game.slip_into_pile(tile.id, true)
			director.show_pile()
		"plant":
			if not tile.holder is Rack:
				return false
			(tile.holder as Rack).release(tile)
			var own := director.seats[event.thief].rack
			own.put(tile, own.free_slot(), true, 0.35)
		"dump":
			var id := event.tile_id
			if not game.lose_from_pile(id):
				return false
			var back := director.make_tile(id)
			var own := director.seats[event.thief].rack
			own.put(back, own.free_slot(), false)
			director.show_pile()
	return true


func _seat_of_rack(rack: Rack) -> int:
	for p in OkeyGame.PLAYERS:
		if director.seats[p].rack == rack:
			return p
	return -1
