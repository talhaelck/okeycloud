class_name Bot
extends Node
## Plays one seat's 101 turns: BotBrain decides, the dayı's own hands (DayiHands) do it. He thinks a moment, draws
## (pulling the pile's top tile toward himself first, since the middle of the table is out of his reach), lays out
## and işles, then sets his discard down in his row. A rule step is committed when its tiles have arrived, so
## nobody can take a tile still in his hand. Seats whose rig cannot pinch (and the player's own seat when his
## time runs out) get their tiles slid into place instead.
## His character (set_personality): `vigilance` (how often he looks up, hears a click, calls what he saw, counts
## when his rack comes up short), `greed` (how keen he is to steal when nobody is looking) and `swaps` (an usta
## thief puts one of his own useless tiles back into the victim's rack a little later, so counting cannot catch
## him). Out of his turn a greedy dayı watches for his chance (mischief) and steals with his real hands.

const THINK := Vector2(0.7, 1.8)
## Where he drags a tile from the pile to before picking it up: on the felt in front of his rack (seat space).
const PULL_SPOT := Vector3(0.2, Table.TOP, 0.47)
const MISCHIEF_EVERY := Vector2(1.2, 2.6) # seconds between looks for a chance to steal

var seat_index := 0
var seat: Seat
var director: GameDirector
var brain := BotBrain.new()
## Paused while he plays, so his glances do not fight his hands for his head.
var watcher: Watcher
var vigilance := 0.5
var greed := 0.0
var swaps := false
var title := ""

var _busy := false # his turn or a theft is under way (never both)


func set_personality(traits: Dictionary) -> void:
	title = traits.get("name", "")
	vigilance = traits.get("vigilance", 0.5)
	greed = traits.get("greed", 0.0)
	swaps = traits.get("swaps", false)
	brain.skill = traits.get("skill", 1.0)
	if watcher:
		watcher.vigilance = vigilance


func _ready() -> void:
	if seat_index != GameDirector.PLAYER and greed > 0.0:
		_mischief()


func play_turn() -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true
	var game := director.game
	var p := seat_index
	if watcher:
		watcher.paused = true
	if p != GameDirector.PLAYER:
		director.stealing.bot_turn_start(p, vigilance)
	await _wait(randf_range(THINK.x, THINK.y))
	if game.phase == OkeyGame.Phase.DRAW and game.turn == p:
		if brain.wants_side(game, p, director.rack_ids(seat.rack)):
			var tile: Tile = director.table.discards(OkeyGame.left_of(p)).back()
			if game.take_discard(p) == "":
				await _fetch(tile)
		else:
			var tile := director.table.pile_top()
			if tile and game.draw_pile(p) == "":
				director.table.set_pile_count(game.pile.size())
				await _fetch(tile)
				director.show_pile()
	if game.phase != OkeyGame.Phase.PLAY or game.turn != p:
		_done()
		return
	await _wait(randf_range(0.4, 1.0))
	var plan := brain.plan(game, p, director.rack_ids(seat.rack))
	# Someone may have taken a tile of his while he was thinking: only what is still on his rack can go down.
	if _still_mine(plan.open) and not plan.open.is_empty() and game.open(p, plan.open) == "":
		director.note("%s el açtı" % director.name_of(p))
		await _lay(director.melds_shown_by(p), p)
		director.fx_opened(p)
	var changed := {}
	for step: Array in plan.extend:
		if _still_mine([[step[1]]]) and game.extend(p, step[0], step[1]) == "":
			changed[game.melds[step[0]].owner] = true
	for owner: int in changed:
		await _lay(director.melds_shown_by(owner), owner)
	var tile: Tile = director.tile_of(plan.discard)
	if tile == null or tile.holder != seat.rack:
		tile = seat.rack.tiles().back()
	await _discard(tile)
	var after := director.rack_ids(seat.rack)
	_done()
	game.discard(p, tile.id, after)


## Is his turn or a theft under way?
func busy() -> bool:
	return _busy


func _done() -> void:
	_busy = false
	if watcher:
		watcher.paused = false


func _still_mine(groups: Array) -> bool:
	for group: Array in groups:
		for id: int in group:
			var tile := director.tile_of(id)
			if tile == null or tile.holder != seat.rack:
				return false
	return true


# --- Stealing ----------------------------------------------------------------------------------------------------

# Out of his turn, every few seconds: is there a chance nobody would see? Then, as greedy as he is, he takes it.
func _mischief() -> void:
	await _wait(randf_range(5.0, 10.0))
	while is_inside_tree():
		await _wait(randf_range(MISCHIEF_EVERY.x, MISCHIEF_EVERY.y))
		var game := director.game
		if _busy or game == null or game.phase == OkeyGame.Phase.OVER or game.turn == seat_index \
				or OkeyGame.next_of(game.turn) == seat_index and game.phase == OkeyGame.Phase.PLAY:
			continue # not while his own turn is coming up
		if director.deal_show != null:
			continue # not while the tiles are still being dealt
		if _hands() == null or randf() > greed:
			continue
		var chance := director.stealing.opportunity(seat_index, greed)
		if not chance.is_empty():
			await steal(chance)


## Takes `chance.tile` ({kind, victim, tile} from Stealing.opportunity) with his real hands, watched like any
## theft; an usta thief later plants one of his own tiles in the victim's rack in return.
func steal(chance: Dictionary) -> void:
	var hands := _hands()
	var tile: Tile = chance.tile
	var slot := seat.rack.free_slot()
	if _busy or hands == null or slot < 0 or not is_instance_valid(tile):
		return
	_busy = true
	await _steal(hands, tile, slot, chance)
	_busy = false


func _steal(hands: DayiHands, tile: Tile, slot: int, chance: Dictionary) -> void:
	var table := director.table
	var victim: int = chance.victim
	var rack := director.seats[victim].rack
	var from_slot := rack.slot_of(tile) if chance.kind == "rack" else table.discards(victim).find(tile)
	var state := hands.hand_for(seat.buddy.dayi_space(tile.global_position))
	var event := director.stealing.bot_begin(seat_index, chance.kind, tile, victim, from_slot,
		func() -> Vector3: return hands.pinch_world(state))
	var hand_number := director.game.hand_number
	# Caught while still reaching (or the hand is over, or someone else took it first): his hand comes back empty.
	var detach := func() -> bool:
		if event.caught or director.game.hand_number != hand_number or director.game.phase == OkeyGame.Phase.OVER:
			return false
		if chance.kind == "rack":
			if tile.holder != rack:
				return false
			rack.release(tile)
		else:
			if not table.discards(victim).has(tile):
				return false
			table.release(tile)
			director.game.lose_from_discards(victim, tile.id)
		return true
	if watcher:
		watcher.paused = true
	await hands.snatch(tile, detach, seat.rack, slot)
	if watcher:
		watcher.paused = false
	if tile.holder != seat.rack:
		director.stealing.visibility.cancel(event) # called off: nothing was taken
		if event.caught:
			return
	director.stealing.bot_finish(event)
	if event.caught:
		director.stealing.give_back(event) # called while the tile was in his hand: it goes back now
		return
	if swaps and chance.kind == "rack":
		await _wait(randf_range(1.5, 4.0))
		await _plant(victim)


# Puts his least useful tile into the victim's rack, if nobody is looking at it right now.
func _plant(victim: int) -> void:
	var rack := director.seats[victim].rack
	var to := rack.free_slot()
	var hands := _hands()
	if to < 0 or hands == null or director.game.phase == OkeyGame.Phase.OVER:
		return
	var spare: Array = Solver.best(director.rack_ids(seat.rack), director.game.okey).left
	spare = spare.filter(func(id: int) -> bool: return not OkeyTiles.is_joker(id, director.game.okey))
	if spare.is_empty():
		return
	spare.sort_custom(func(a: int, b: int) -> bool: return OkeyTiles.plays_as(a, director.game.okey).y > OkeyTiles.plays_as(b, director.game.okey).y)
	var tile: Tile = director.tile_of(spare[0])
	if tile == null or tile.holder != seat.rack or not director.stealing.unseen(seat_index, rack.slot_global_transform(to).origin, victim):
		return
	var toward := seat.buddy.dayi_space(rack.slot_global_transform(to).origin)
	var state := hands.hand_for(toward)
	var event := director.stealing.bot_begin(seat_index, "plant", tile, victim, -1,
		func() -> Vector3: return hands.pinch_world(state))
	if watcher:
		watcher.paused = true
	var hand_number := director.game.hand_number
	await hands.hand_over(seat.rack, seat.rack.slot_of(tile), toward, func(t: Tile) -> void:
		# The hand may have ended meanwhile: then the tile just goes back to his own rack.
		var into := rack if director.game.hand_number == hand_number else seat.rack
		into.put(t, into.nearest_free(to if into == rack else 0), true, 0.3))
	if watcher:
		watcher.paused = false
	director.stealing.bot_finish(event)
	if event.caught:
		director.stealing.give_back(event)


func _hands() -> DayiHands:
	return seat.buddy.tile_hands() if seat.buddy else null


# Brings a tile (on the pile or a discard row) into a free slot of his rack.
func _fetch(tile: Tile) -> void:
	Sfx.at("tile_slide", tile.global_position, -8.0, 0.3)
	var rack := seat.rack
	var slot := rack.free_slot()
	var hands := _hands()
	if hands == null:
		director.table.release(tile)
		rack.put(tile, slot, true, 0.35)
		await _wait(0.4)
		return
	if not hands.reachable(seat.buddy.dayi_space(tile.global_position)):
		await hands.pull(tile, seat.buddy.dayi_space(seat.to_global(PULL_SPOT)))
	await hands.pick_up(tile, director.table, rack, slot)


# Shows a seat's melds as laid now, reaching toward them while they slide into place.
func _lay(groups: Array, owner: int) -> void:
	var hands := _hands()
	var centre := director.table.to_global(Table.seat_basis(owner) * Vector3(0, Table.TOP, Table.MELD_ROWS[0]))
	if hands:
		hands.gesture(seat.buddy.dayi_space(centre))
		await _wait(Bot.reach_time() * 0.7)
	director.table.lay_melds(owner, groups, 0.35)
	await _wait(0.6)


func _discard(tile: Tile) -> void:
	var table := director.table
	var p := seat_index
	var hands := _hands()
	var target := table.next_discard(p).origin
	target.y = table.to_global(Vector3(0, Table.TOP, 0)).y
	var spot := seat.buddy.dayi_space(target) if seat.buddy else Vector3.ZERO
	if hands:
		# His row starts at the far corner: he sets the tile down as far as he reaches and slides it the rest.
		var down := spot
		if not hands.reachable(spot):
			down = hands.clamp_reach(spot)
			down.y = spot.y
		var slide := 0.12 if down == spot else 0.3
		await hands.discard(seat.rack, seat.rack.slot_of(tile), table, down, func(t: Tile) -> void: table.put_discard(t, p, slide))
		if tile.holder == table:
			return
	seat.rack.release(tile)
	table.put_discard(tile, p, 0.35)
	await _wait(0.4)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


static func reach_time() -> float:
	return DayiHands.REACH_TIME
