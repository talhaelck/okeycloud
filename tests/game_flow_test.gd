extends SceneTree
## The 101 game on the real table: the main scene plays hands with bots in every seat (the player's turns are
## played for him when his short timer runs out). After every turn each rack must hold as many tiles as the rules
## expect, the pile counter must match the rules, the newest discard must lie in the right seat's row, and the hand
## must keep moving (no seat may hold the turn for long), and all 106 tiles must exist exactly once (as tile nodes
## or inside the pile). Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/game_flow_test.gd -- --set=turn_time_limit=1 [--hands=<n>]
## `--stealing`: every bot is greedy and steals, counts and calls "Yakala!" while the game goes on; then racks may
## hold more or fewer tiles than the rules expect, but no tile may be lost or doubled and the game must not stall.
## Without --headless, `--shots=<prefix> [--yaw=<rad>]` also saves every 10th frame of the first turns as
## <prefix>_<frame>.png, looking out of the player's eyes (negative yaw looks right); `--sheet=<file.png>` saves
## the score sheet at the end of the hand.

const STUCK := 25.0 # seconds one turn may take before the test calls it stuck

var _failures: Array[String] = []
var _exact := true


func _init() -> void:
	var hands := 1
	var thieves := false
	var shots := ""
	var yaw := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hands="):
			hands = int(arg.trim_prefix("--hands="))
		elif arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg == "--stealing":
			thieves = true
		elif arg.begins_with("--yaw="):
			yaw = float(arg.trim_prefix("--yaw="))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var director: GameDirector = main.director
	var game := director.game
	# Counts must match the rules exactly unless stealing is on (stealing_test.gd covers thefts one by one).
	game.settings.stealing_enabled = thieves
	_exact = not thieves
	if thieves:
		for p in range(1, 4):
			director.bot(p).greed = 0.9
		_look_around(main.camera) # a player keeps looking at his rack and bending over the table
	game.penalised.connect(func(p: int, points: int, reason: String) -> void:
		if thieves:
			print("  %s %+d: %s" % [director.name_of(p), points, reason]))
	if shots:
		main.camera.mouse_control = false
		main.camera.set_focused(false, true)
		main.camera.look(yaw, -0.6)
		DirAccess.make_dir_recursive_absolute(shots.get_base_dir())
	var last_turn := -1
	var last_phase := -1
	var since := 0.0
	var turns := 0
	var played := 0
	var frame := 0
	while played < hands:
		await process_frame
		frame += 1
		since += 1.0 / 30.0
		if shots and frame % 10 == 0 and frame <= 900:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s_%04d.png" % [shots, frame])
		if game.phase == OkeyGame.Phase.OVER:
			played += 1
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--sheet="): # windowed only: the score sheet at the end of the hand
					for i in 10:
						await process_frame
					await RenderingServer.frame_post_draw
					root.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--sheet="))
			print("hand %d over after %d turns, finisher %d, totals %s, thefts so far %d" % [played, turns, game.finisher,
				game.totals, director.stealing.visibility.events.size() + director.stealing._ledger.size()])
			_check_counts(director, "end of hand")
			if played < hands and not game.match_over():
				game.next_hand()
				await director._deal()
			turns = 0
			since = 0.0
			continue
		if game.turn != last_turn or game.phase != last_phase:
			if game.turn != last_turn:
				turns += 1
				# A new turn: the previous player's discard is down, nothing is in flight.
				for i in 20:
					await process_frame
				_check_counts(director, "turn %d" % turns)
			last_turn = game.turn
			last_phase = game.phase
			since = 0.0
		if since > STUCK:
			_failures.append("stuck: seat %d phase %d for %.0f s" % [game.turn, game.phase, since])
			break
	for failure in _failures:
		print("FAIL ", failure)
	print("FAILS: ", _failures.size())
	quit(1 if _failures.size() > 0 else 0)


func _check_counts(director: GameDirector, when: String) -> void:
	var game := director.game
	_check_tiles(director, when)
	for p in OkeyGame.PLAYERS:
		if not _exact:
			break
		var held := director.seats[p].rack.tiles().size()
		if held != game.expected[p]:
			_failures.append("%s: seat %d holds %d tiles, rules expect %d" % [when, p, held, game.expected[p]])
	var pile := director.table.pile_top()
	if game.pile.is_empty() != (pile == null) or (pile and pile.id != game.pile_top()):
		_failures.append("%s: pile top on the table is not the rules' pile top" % when)
	for p in OkeyGame.PLAYERS:
		var row: Array = director.table.discards(p)
		var ids: Array = row.map(func(t: Tile) -> int: return t.id)
		if ids != game.discards[p]:
			_failures.append("%s: seat %d's discard row %s, rules %s" % [when, p, ids, game.discards[p]])


# Every tile id 0-105 exists exactly once: as a tile node (on a rack, the table, in a hand or in the air) or inside
# the pile; the pile's top is both.
func _check_tiles(director: GameDirector, when: String) -> void:
	var seen := {}
	for tile: Tile in root.get_tree().get_nodes_in_group("tiles"):
		if tile.id < 0 or tile.is_queued_for_deletion():
			continue
		if seen.has(tile.id):
			var other: Tile = seen[tile.id]
			_failures.append("%s: tile %d exists twice (%s in %s, %s in %s)" % [when, tile.id, tile.holder, tile.get_parent(),
				other.holder, other.get_parent()])
		seen[tile.id] = tile
	var top := director.table.pile_top()
	for id in director.game.pile:
		if seen.has(id) and not (top and top.id == id and seen[id] == top):
			_failures.append("%s: tile %d is both in the pile and out of it" % [when, id])
		seen[id] = true
	if seen.size() != OkeyTiles.COUNT:
		var missing := []
		for id in OkeyTiles.COUNT:
			if not seen.has(id):
				missing.append(id)
		_failures.append("%s: %d tiles missing %s" % [when, missing.size(), missing])


func _look_around(camera: FocusCamera) -> void:
	camera.mouse_control = false
	var modes := [FocusCamera.Mode.OBSERVE, FocusCamera.Mode.RACK, FocusCamera.Mode.LEAN, FocusCamera.Mode.RACK]
	var i := 0
	while true:
		camera.set_mode(modes[i % modes.size()])
		i += 1
		for frame in 90:
			await process_frame
