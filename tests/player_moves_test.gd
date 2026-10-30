extends SceneTree
## The local player's moves through GameDirector, the way his hand and keys make them: R lays the rack out in
## groups, Enter opens them onto the table in front of him, a discard goes to his row and passes the turn, and the
## pile and other discards cannot be picked up out of turn. Uses a deal where the player can open (seeded).
## Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/player_moves_test.gd

var _failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var director: GameDirector = main.director
	var game := director.game
	var rack: Rack = director.seats[0].rack

	# A deal where the player (the dealer, 22 tiles) can open straight away.
	var found := -1
	for s in 400:
		seed(s)
		var probe := OkeyGame.new()
		var racks := probe.deal()
		var ids: Array[int] = []
		ids.assign(racks[0])
		if Solver.best(ids, probe.okey).points >= 101:
			found = s
			break
	check(found >= 0, "no seed with an opening hand")
	game.dealer = 0
	seed(found)
	await director._deal()
	await process_frame
	check(game.turn == 0 and game.phase == OkeyGame.Phase.PLAY, "the dealer starts by discarding")
	check(director.stealing.theft_kind(director.table.pile_top()) == "pile", "the dealer drawing is stealing from the pile")
	game.settings.stealing_enabled = false
	check(director._grab_check(director.table.pile_top()) != "", "the dealer cannot draw (no stealing)")
	game.settings.stealing_enabled = true

	director._arrange("sets")
	for i in 10:
		await process_frame
	var laid_sets: Dictionary = director._valid_groups()
	check(laid_sets.groups.size() >= 1 and laid_sets.points > 0, "sets found after R: %d groups, %d points" % [laid_sets.groups.size(), laid_sets.points])
	director._open_from_rack()
	for i in 20:
		await process_frame
	check(game.opened[0] == OkeyGame.Opened.SETS, "Enter opened the hand")
	check(Effects.count("sparkle") > 0 and Sfx.count("sting_open") > 0, "opening sparkles and has its sting")
	check(game.best_open >= 101, "opening counted %d" % game.best_open)
	var laid := 0
	for group: Array in director.table.melds(0):
		for tile: Tile in group:
			laid += 1
			check(tile.holder == director.table, "laid tile belongs to the table")
			var zone := director.table.zone_at(tile.global_position)
			check(zone.kind == "meld" and zone.seat == 0, "laid tile lies in the player's meld area, not %s" % zone)
	check(laid > 0 and rack.tiles().size() == game.expected[0], "rack %d vs expected %d after opening" % [rack.tiles().size(), game.expected[0]])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): # windowed only: the player's view of his opened melds
			main.camera.mouse_control = false
			main.camera.look(0.0, -0.75)
			for i in 30:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--shot="))

	# Discard the first leftover: it lands in his row and the turn passes to the right.
	var tile: Tile = rack.tiles()[0]
	rack.release(tile)
	director._confirm = tile.id # skip the penalty warning if it is an işlek tile
	director._try_discard(tile)
	await process_frame
	check(director.table.discards(0).back() == tile, "discard lies in the player's row")
	check(game.discards[0].back() == tile.id, "rules saw the discard")
	check(game.turn == 1, "turn passed to seat 1")
	check(director.stealing.theft_kind(director.table.pile_top()) == "pile", "pile out of turn is a theft")
	check(director.stealing.theft_kind(tile) == "discard", "taking back your own discard is a theft")
	game.settings.stealing_enabled = false
	check(director._grab_check(director.table.pile_top()) == "Sıra sende değil", "pile out of turn (no stealing)")
	check(director._grab_check(tile) != "", "own discard cannot be taken back (no stealing)")
	game.settings.stealing_enabled = true
	check(rack.tiles().size() == game.expected[0], "rack count after discard")

	for failure in _failures:
		print("FAIL ", failure)
	print("FAILS: ", _failures.size())
	quit(1 if _failures.size() > 0 else 0)
