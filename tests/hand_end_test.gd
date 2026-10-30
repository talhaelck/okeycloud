extends SceneTree
## The end of a hand as a show (HandEndShow): the camera leaves the player's eyes, every rack tips over with its tiles
## face up, the chalkboard writes the scores (what the rules scored, line by line), Enter skips the show or deals the
## next hand with everything back in place, and the last hand of a match ends with the winner and its two buttons.
## Hands are ended by force (no bot plays). Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/hand_end_test.gd

var _failures: Array[String] = []
var main: Node
var director: GameDirector
var game: OkeyGame
var camera: FocusCamera


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		_failures.append(what)


func wait(frames: int) -> void:
	for i in frames:
		await process_frame


func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func end_hand(finisher: int) -> void:
	game.finisher = finisher
	game.phase = OkeyGame.Phase.OVER
	game.opened[2] = OkeyGame.Opened.SETS
	if finisher >= 0:
		game.opened[finisher] = OkeyGame.Opened.SETS
	director._end_hand()


# The first row of the board that starts with this text.
func row_of(text: String) -> Dictionary:
	for row in director.hud._board_rows.get_children():
		if not row is HBoxContainer:
			continue # the title
		var label := row.get_child(row.get_child_count() - 2) as Label
		if label and label.text == text:
			return {"left": label, "right": row.get_child(row.get_child_count() - 1)}
	return {}


func _init() -> void:
	Effects.reset_counts()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(5)
	director = main.director
	game = director.game
	camera = main.camera
	game.settings.turn_time_limit = 0
	game.settings.stealing_enabled = false
	for watcher: Watcher in main.watchers:
		watcher.process_mode = Node.PROCESS_MODE_DISABLED
	camera.mouse_control = false

	# A hand someone finished: wait for the whole show.
	Sfx.reset_counts()
	end_hand(2)
	await wait(5)
	var show := director.end_show
	check(show != null and show.running, "the show starts at once")
	check(camera.cine_blend == 1.0, "the camera has left the player's eyes")
	check(not director.seats[1].rack.tipped, "the racks are still standing at first")
	await wait(500)
	check(not show.running, "the show runs out (about %d s)" % 16)
	for p in 4:
		check(director.seats[p].rack.tipped, "rack %d has tipped over" % p)
	var tile: Tile = director.seats[2].rack.tiles()[3]
	check(tile.global_basis.z.y > 0.7, "its tiles lie face up (%.2f)" % tile.global_basis.z.y)
	var eye: Vector3 = director.table.global_position + HandEndShow.OVERVIEW_EYE
	check(camera.global_position.distance_to(eye) < 0.1, "the camera overlooks the table (%s)" % camera.global_position)
	check(director.hud.board_visible(), "the chalkboard is up")
	var last: Array = game.history.back()
	for p in 4:
		var row := row_of(director.name_of(p))
		check(not row.is_empty() and row.right.text == "%+d" % last[p].score, "%s's line says %+d (board: %s)" % [director.name_of(p), last[p].score, row.right.text if not row.is_empty() else "-"])
	var reasons := 0
	for p in 4:
		reasons += last[p].lines.size()
	check(director.hud.board_row_count() >= 1 + 4 + reasons + 3, "every reason has its line (%d rows)" % director.hud.board_row_count())
	check(row_of("Toplam").size() > 0 and row_of("Enter: sonraki el").size() > 0, "totals and the way on")
	check(Sfx.count("chalk") >= 8, "chalk scratches (%d)" % Sfx.count("chalk"))
	check(director.hud.board_row_count() > 0 and director.hud._board_buttons.get_child_count() == 0, "no match buttons mid-match")

	# Enter deals the next hand: everything back.
	game.next_hand()
	director._unhandled_key_input(key(KEY_ENTER))
	await wait(60)
	check(game.phase != OkeyGame.Phase.OVER or director.end_show == null, "the next hand was dealt")
	for p in 4:
		check(not director.seats[p].rack.tipped, "rack %d stands again" % p)
		check(director.seats[p].rack.tiles().size() == game.expected[p], "rack %d holds %d tiles" % [p, game.expected[p]])
	check(not director.hud.board_visible(), "the board is gone")
	check(camera.cine_blend < 0.02, "the camera is back in the player's eyes (%.2f)" % camera.cine_blend)

	# Enter during the show skips it.
	end_hand(-1)
	await wait(40)
	check(director.end_show.running and director.hud.board_row_count() == 0, "(a pile that ran out: the show runs)")
	director._unhandled_key_input(key(KEY_ENTER))
	await wait(40)
	check(not director.end_show.running and row_of("Enter: sonraki el").size() > 0, "Enter skips straight to the board")
	for p in 4:
		check(director.seats[p].rack.tipped, "skipped: rack %d is tipped" % p)

	# The last hand of the match.
	game.next_hand()
	director._unhandled_key_input(key(KEY_ENTER))
	await wait(40)
	while game.history.size() < game.settings.hands_per_match - 1:
		game.history.append(game.history.back())
	end_hand(1)
	await wait(5)
	director._unhandled_key_input(key(KEY_ENTER))
	await wait(30)
	check(game.match_over(), "that was the last hand of the match")
	check(director.hud._board_buttons.get_child_count() == 2, "Yeni maç and Ana menü appear")
	var winner_text := ""
	for row in director.hud._board_rows.get_children():
		if not row is HBoxContainer:
			continue
		var label := row.get_child(row.get_child_count() - 2) as Label
		if label and label.text.begins_with("Maçı"):
			winner_text = label.text
	check(winner_text != "", "the winner is named (%s)" % winner_text)
	director._unhandled_key_input(key(KEY_ENTER))
	await wait(5)
	check(game.phase == OkeyGame.Phase.OVER, "Enter does not deal after the last hand")
	var menu_asked := [false]
	director.menu_requested.connect(func() -> void: menu_asked[0] = true)
	director.hud._board_buttons.get_child(1).pressed.emit()
	check(menu_asked[0], "Ana menü asks for the menu")
	director.hud._board_buttons.get_child(0).pressed.emit()
	await wait(60)
	check(game.totals == [0, 0, 0, 0] and game.history.is_empty() and game.hand_number == 0, "Yeni maç starts from nothing")
	check(not director.hud.board_visible() and not director.seats[0].rack.tipped, "and the table is ready")

	print("FAILS: ", _failures.size())
	quit(1 if _failures.size() > 0 else 0)
