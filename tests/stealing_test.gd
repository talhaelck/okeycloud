extends SceneTree
## Stealing, watching and calling it, on the real table with the real dayıs (docs/design/stealing.md):
## who sees what in each way of looking, the player's lean over the table, thefts nobody saw, a witness calling
## "Yakala!", a wrong call, "Taş say!" catching a thief who kept the tile and missing one who planted a tile back,
## stealing from the pile and dumping into it, taking from a discard row and getting it back, a bot stealing from
## the player while he leans over the table (and being counted out), the player witnessing a bot's theft, and
## friend mode. Watchers are held still and every look is set by hand, so nothing depends on chance.
## Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/stealing_test.gd

const FPS := 30

var _failures: Array[String] = []
var main: Node
var director: GameDirector
var game: OkeyGame
var stealing: Stealing
var seats: Array[Seat]
var hand: Hand


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		_failures.append(what)


func wait(seconds: float) -> void:
	for i in int(seconds * FPS):
		await process_frame


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	director = main.director
	game = director.game
	stealing = director.stealing
	seats = director.seats
	hand = director.hand
	game.settings.turn_time_limit = 0 # the player (the dealer) never times out: no bot plays a turn
	for watcher in main.watchers:
		watcher.process_mode = Node.PROCESS_MODE_DISABLED
	hush()
	for p in range(1, 4):
		director.bot(p).greed = 0.0 # nobody steals unless the test says so
		director.bot(p).vigilance = 1.0
	hand.process_mode = Node.PROCESS_MODE_DISABLED # the test moves the hand
	await wait(0.5)
	for blocker in get_nodes_in_group("view_blockers"):
		blocker.remove_from_group("view_blockers") # the çaycı walks by at random
	main.camera.mouse_control = false

	await _looks()
	await _lean()
	await _unseen_theft_counted()
	await _witness_calls_it()
	await _wrong_call()
	await _swap_beats_counting()
	await _pile_and_dump()
	await _discard_row()
	await _bot_steals_while_player_leans()
	await _player_witnesses_bot()
	await _usta_swaps()
	await _friend_mode()

	print("FAILS: ", _failures.size())
	quit(1 if _failures.size() > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------------

func everyone(mode: int) -> void:
	hush()
	for p in range(1, 4):
		seats[p].look_mode = mode


# Watchers held still: a click or a glance does not turn their heads (that is chance), and every look is set here.
func hush() -> void:
	for watcher in main.watchers:
		watcher.paused = true


# Looking up at the ceiling: sees nothing on the table.
func away(viewer: int) -> void:
	seats[viewer].look_mode = FocusCamera.Mode.OBSERVE
	seats[viewer].look_dir = Vector3.UP


func look_at(viewer: int, point: Vector3) -> void:
	seats[viewer].look_mode = FocusCamera.Mode.OBSERVE
	seats[viewer].look_dir = (point - seats[viewer].head_anchor.global_position).normalized()


func counts_right(what: String) -> void:
	for p in 4:
		var held := stealing.held_count(p)
		check(held == game.expected[p], "%s: seat %d holds %d, expected %d" % [what, p, held, game.expected[p]])


func penalties_of(p: int) -> Array:
	return game.penalties[p].map(func(entry: Array) -> String: return entry[1])


func reset_calls() -> void:
	stealing._cooldown.clear()


# The player picks a tile up, carries it to `over` for `seconds` (while `during` may set looks every frame),
# and lets go on `drop`.
func carry(tile: Tile, over: Vector3, seconds: float, drop: Dictionary, during := Callable()) -> void:
	hand.grab(tile)
	if hand.held != tile:
		print("note: grab refused: '%s' holder=%s held=%s mode=%d" % [director._grab_check(tile), tile.holder, hand.held, main.camera.mode])
		return
	for i in int(seconds * FPS):
		if hand.held == null:
			print("note: caught in the act at frame %d, events %s" % [i, stealing.visibility.events.map(func(e): return [e.kind, e.witnesses, e.caught])])
			return
		hand.held.global_position = over
		if during.is_valid():
			during.call()
		await process_frame
	hand._drop = drop
	hand.drop()
	await process_frame


func rack_drop(rack: Rack) -> Dictionary:
	return {"rack": rack, "slot": rack.free_slot()}


func the_player_looks(mode: int) -> void:
	main.camera.set_mode(mode, true)
	await wait(0.1)


# --- scenarios ---------------------------------------------------------------------------------------------------

func _looks() -> void:
	var vis := stealing.visibility
	var rack1 := seats[1].rack.slot_global_transform(Rack.SLOTS + 7).origin
	var rack0 := seats[0].rack.slot_global_transform(Rack.SLOTS + 7).origin
	var middle := director.table.to_global(Vector3(0, Table.TOP, 0))
	seats[1].look_mode = FocusCamera.Mode.RACK
	check(vis.sees(1, rack1) == Visibility.SEEN, "reading his rack, he sees a hand in it")
	check(vis.sees(1, rack0) == 0.0, "reading his rack, he sees nothing else")
	seats[1].look_mode = FocusCamera.Mode.LEAN
	check(vis.sees(1, rack1) == 0.0, "bent over the table, his own rack is out of sight")
	check(vis.sees(1, middle) == Visibility.SEEN and vis.sees(1, rack0) == Visibility.SEEN, "bent over the table, he sees the table")
	look_at(1, seats[0].head_anchor.global_position)
	check(vis.sees(1, rack0) >= Visibility.GLIMPSE, "looking at the player, his rack is in view (%.1f)" % vis.sees(1, rack0))
	check(vis.sees(1, seats[2].head_anchor.global_position) == 0.0, "looking at the player, the man on his right is out of view")
	check(vis.sees(1, seats[3].head_anchor.global_position) == Visibility.GLIMPSE, "the man opposite is in the corner of his eye")
	var blocker := Node3D.new()
	root.add_child(blocker)
	blocker.global_position = (seats[1].head_anchor.global_position + rack0) * 0.5 * Vector3(1, 0, 1)
	blocker.add_to_group("view_blockers")
	check(vis.sees(1, rack0) == 0.0, "someone walking between blocks the view")
	blocker.queue_free()
	await process_frame


func _lean() -> void:
	await the_player_looks(FocusCamera.Mode.LEAN)
	await wait(1.2)
	var camera: FocusCamera = main.camera
	check(camera.global_position.distance_to(seats[0].lean_anchor.global_position) < 0.01, "W puts the eyes over the table")
	check(seats[0].look_mode == FocusCamera.Mode.LEAN, "the others know the player is bent over the table")
	var rack0 := seats[0].rack.slot_global_transform(Rack.SLOTS + 7).origin
	check(stealing.visibility.sees(0, rack0) == 0.0, "bent over, the player cannot see his own rack")
	check(not camera.is_position_in_frustum(rack0), "his own rack is out of the picture")
	var middle := director.table.to_global(Vector3(0, Table.TOP, 0))
	check(camera.is_position_in_frustum(middle), "the middle of the table is in the picture")
	var front := seats[0].to_global(Vector3(0, Table.TOP, Seat.LEAN_BLIND + 0.03))
	check(not camera.is_position_in_frustum(front), "so is not the strip in front of his rack")
	var far_tile: Tile = seats[2].rack.tiles()[5]
	var eye := camera.global_position
	check(hand._pick(eye, (far_tile.global_position - eye).normalized()) == null, "bent over, the opposite rack is still out of reach")
	var near_tiles := seats[1].rack.tiles()
	near_tiles.sort_custom(func(a: Tile, b: Tile) -> bool: return a.global_position.z > b.global_position.z)
	var near: Tile = near_tiles[0]
	check(hand._pick(eye, (near.global_position - eye).normalized()) == near, "the near end of the neighbour's rack is in reach")
	var body := seats[0].buddy.find_children("*", "RiggedDayi", true, false)
	if not body.is_empty():
		check((body[0] as RiggedDayi).bend > 0.3, "his dayı is bent over the table (%.2f)" % (body[0] as RiggedDayi).bend)
	await the_player_looks(FocusCamera.Mode.RACK)
	if not body.is_empty():
		await wait(0.6)
		check((body[0] as RiggedDayi).head_pitch > 0.4 and (body[0] as RiggedDayi).bend < 0.2, "reading his rack, his head is bowed")
	await the_player_looks(FocusCamera.Mode.OBSERVE)


func _unseen_theft_counted() -> void:
	everyone(FocusCamera.Mode.RACK)
	away(1) # the victim is not watching his rack
	await the_player_looks(FocusCamera.Mode.OBSERVE)
	var tile: Tile = seats[1].rack.tiles()[0]
	var over := tile.global_position + Vector3.UP * 0.1
	await carry(tile, over, 0.8, rack_drop(seats[0].rack))
	var event: Visibility.TheftEvent = stealing._ledger.back() if not stealing._ledger.is_empty() else null
	check(event != null and event.kind == "rack" and event.witnesses.is_empty(), "a theft nobody saw")
	check(tile.holder == seats[0].rack, "the stolen tile is in the player's rack")
	check(stealing.held_count(0) == game.expected[0] + 1, "the player holds one too many")
	# The victim finds his rack a tile short at his turn and counts his neighbours.
	stealing.bot_turn_start(1, 1.0)
	await wait(0.5)
	check(penalties_of(0).has("Taş sayımında 1 fazla çıktı"), "\"Taş say!\" catches the player who kept the tile")
	check(tile.holder == seats[1].rack, "the tile went back to its owner")
	counts_right("after the count")
	reset_calls()


func _witness_calls_it() -> void:
	everyone(FocusCamera.Mode.RACK)
	away(1)
	var tile: Tile = seats[1].rack.tiles()[1]
	var over := tile.global_position + Vector3.UP * 0.12
	var before: int = game.penalties[0].size()
	# The man opposite watches the player's hand the whole time.
	await carry(tile, over, 1.2, rack_drop(seats[0].rack), func() -> void: look_at(2, over))
	await wait(1.5) # his reaction
	check(penalties_of(0).has("Taş çalarken yakalandı"), "a witness calls \"Yakala!\"")
	check(Effects.count("pulse") > 0 and Effects.count("shake") > 0 and Effects.count("slowmo") > 0, "the player being caught shakes, pulses and slows down the screen")
	check(Effects.count("float_text") > 0, "and the penalty floats up over him")
	check(game.penalties[0].size() == before + 1, "one penalty, not two")
	check(tile.holder == seats[1].rack, "the caught tile goes back")
	counts_right("after the catch")
	reset_calls()


func _wrong_call() -> void:
	var before: int = game.penalties[0].size()
	stealing.accuse(0, 2)
	check(game.penalties[0].size() == before + 1 and penalties_of(0).back().begins_with("Haksız"), "a wrong \"Yakala!\" costs the caller")
	reset_calls()
	stealing.count_check(0, 3)
	check(penalties_of(0).back() == "Boşuna taş saydırdı", "a wrong \"Taş say!\" costs the caller")
	reset_calls()


func _swap_beats_counting() -> void:
	everyone(FocusCamera.Mode.RACK)
	away(1)
	var tile: Tile = seats[1].rack.tiles()[2]
	await carry(tile, tile.global_position + Vector3.UP * 0.1, 0.5, rack_drop(seats[0].rack))
	# One of his own back into the victim's rack: hovering there, then letting go.
	var own: Tile = seats[0].rack.tiles()[0]
	var target := rack_drop(seats[1].rack)
	hand.grab(own)
	hand._drop = target
	await wait(0.4)
	hand.drop()
	await process_frame
	var plant: Visibility.TheftEvent = stealing._ledger.back()
	check(plant.kind == "plant" and own.holder == seats[1].rack, "the player planted a tile of his own")
	counts_right("after the swap")
	var before: int = game.penalties[1].size()
	stealing.count_check(1, 0)
	check(game.penalties[1].size() == before + 1 and penalties_of(1).back() == "Boşuna taş saydırdı", "counting cannot catch a swap")
	reset_calls()


func _pile_and_dump() -> void:
	everyone(FocusCamera.Mode.RACK)
	var top := director.table.pile_top()
	var size := game.pile.size()
	check(stealing.theft_kind(top) == "pile", "the pile out of turn is a theft")
	await carry(top, top.global_position + Vector3.UP * 0.1, 0.4, rack_drop(seats[0].rack))
	check(game.pile.size() == size - 1 and not game.pile.has(top.id), "the stolen tile is gone from the pile")
	check(director.table.pile_top() and director.table.pile_top().id == game.pile_top(), "the next tile is on top")
	# Rid of a tile: slip it into the pile.
	var own: Tile = seats[0].rack.tiles()[3]
	var id := own.id
	hand.grab(own)
	hand._drop = {"point": director.table.to_global(Vector3(0, Table.TOP, 0)), "zone": {"kind": "pile"}}
	await wait(0.3)
	hand.drop()
	await process_frame
	check(game.pile.size() == size and game.pile[0] == id, "a dumped tile goes under the pile")
	counts_right("after stealing from the pile and dumping")
	reset_calls()


func _discard_row() -> void:
	everyone(FocusCamera.Mode.RACK)
	away(2) # his row starts at the corner of his rack
	var table := director.table
	for i in 3: # three discards in seat 2's row
		var t: Tile = seats[2].rack.tiles()[0]
		seats[2].rack.release(t)
		table.put_discard(t, 2, 0.0)
		game.discards[2].append(t.id)
		game.expected[2] -= 1
	var middle: Tile = table.discards(2)[1]
	check(stealing.theft_kind(middle) == "discard", "a tile in the middle of a row is a theft")
	await carry(middle, middle.global_position + Vector3.UP * 0.1, 0.4, rack_drop(seats[0].rack))
	check(not game.discards[2].has(middle.id) and table.discards(2).size() == 2, "it is gone from the row")
	stealing.count_check(2, 0)
	check(table.discards(2)[1] == middle and game.discards[2][1] == middle.id, "counted out, it goes back to its place in the row")
	counts_right("after the discard row")
	reset_calls()


func _bot_steals_while_player_leans() -> void:
	everyone(FocusCamera.Mode.RACK)
	await the_player_looks(FocusCamera.Mode.LEAN)
	await wait(0.3)
	var thief := director.bot(3)
	thief.swaps = false # a plain thief keeps what he took (the usta is next)
	var chance := stealing.opportunity(3, 1.0)
	check(not chance.is_empty() and chance.victim == 0, "the player bent over the table is the chance (%s)" % chance)
	if chance.is_empty():
		return
	var tile: Tile = chance.tile
	var lean := [0.0] # lambdas capture locals by value: an array is shared
	var body: RiggedDayi = seats[3].buddy.find_children("*", "RiggedDayi", true, false)[0]
	var nearest := [9.0]
	var watch := func() -> void:
		lean[0] = maxf(lean[0], body.lean)
		if not stealing.visibility.events.is_empty():
			var e: Visibility.TheftEvent = stealing.visibility.events.back()
			nearest[0] = minf(nearest[0], seats[0].to_local(e.hand_point()).z)
	process_frame.connect(watch)
	await thief.steal(chance)
	process_frame.disconnect(watch)
	hush()
	check(tile.holder == seats[3].rack, "he took it with his own hands")
	print("note: the thief's hand came to z = %.2f in the player's space" % nearest[0])
	check(lean[0] > 0.45, "he leaned right over the table to reach (%.2f)" % lean[0])
	var event: Visibility.TheftEvent = stealing._ledger.back()
	check(event.thief == 3 and event.witnesses.is_empty(), "nobody saw (witnesses %s, exposure %s)" % [event.witnesses, event.exposure])
	check(stealing.held_count(0) == game.expected[0] - 1, "the player's rack is a tile short")
	await the_player_looks(FocusCamera.Mode.OBSERVE)
	main.camera.look(0.9, -0.45) # at the man on his left
	await wait(0.1)
	check(director.looked_at_seat() == 3, "the player is looking at Mahmut Usta")
	stealing.count_check(0, director.looked_at_seat())
	check(penalties_of(3).has("Taş sayımında 1 fazla çıktı") and tile.holder == seats[0].rack, "counted out, his tile comes back")
	counts_right("after the bot's theft")
	reset_calls()


func _player_witnesses_bot() -> void:
	everyone(FocusCamera.Mode.RACK)
	await the_player_looks(FocusCamera.Mode.OBSERVE)
	main.camera.look(0.75, -0.6) # watching his left: Mahmut Usta's hands and the end of his own rack
	await wait(0.2)
	var tiles := seats[0].rack.tiles()
	tiles.sort_custom(func(a: Tile, b: Tile) -> bool: return a.global_position.x < b.global_position.x)
	var thief := director.bot(3)
	var cue := [""]
	var watch := func() -> void:
		if director.hud._cue.text != "":
			cue[0] = director.hud._cue.text
	process_frame.connect(watch)
	await thief.steal({"kind": "rack", "victim": 0, "tile": tiles[0]})
	process_frame.disconnect(watch)
	hush()
	var event: Visibility.TheftEvent = stealing._ledger.back() if not stealing._ledger.is_empty() else null
	check(event != null and event.witnesses.has(0), "the player saw the bot's hand")
	check(cue[0].begins_with("Gördün"), "the HUD told him (\"%s\")" % cue[0])
	stealing.accuse(0, 3)
	check(penalties_of(3).has("Taş çalarken yakalandı"), "his \"Yakala!\" catches the bot")
	check(tiles[0].holder == seats[0].rack, "and his tile is back")
	counts_right("after catching the bot")
	reset_calls()


func _usta_swaps() -> void:
	everyone(FocusCamera.Mode.RACK)
	await the_player_looks(FocusCamera.Mode.LEAN)
	await wait(0.3)
	var thief := director.bot(3)
	thief.swaps = true
	var mine := seats[0].rack.tiles()
	await thief.steal(stealing.opportunity(3, 1.0))
	hush()
	var gone := mine.filter(func(t: Tile) -> bool: return t.holder != seats[0].rack)
	var came := seats[0].rack.tiles().filter(func(t: Tile) -> bool: return not mine.has(t))
	check(gone.size() == 1 and came.size() == 1, "the usta took one of the player's tiles and left one of his own")
	counts_right("after the usta's swap")
	await the_player_looks(FocusCamera.Mode.OBSERVE)
	var before: int = game.penalties[0].size()
	stealing.count_check(0, 3)
	check(game.penalties[0].size() == before + 1, "counting the usta out fails")
	reset_calls()


func _friend_mode() -> void:
	game.settings.friend_mode = true
	var before: int = game.penalties[0].size()
	stealing.accuse(0, 1)
	check(game.penalties[0].size() == before, "friend mode writes no penalties")
	game.settings.friend_mode = false
	reset_calls()
