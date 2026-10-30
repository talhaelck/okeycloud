extends SceneTree
## The shell around the game, through the real Boot scene: the main menu opens over the room with nothing dealt,
## "Masa kur" edits the rules and the bot levels (every rule has a row and a text), Başlat starts a game with exactly
## those, Esc pauses and resumes, the table's rules show up in the pause menu, "Ana menüye dön" starts over, and a
## saved rule set comes back. Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/ui_test.gd

var _failures: Array[String] = []
var boot: Node
var main: Node


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		_failures.append(what)


func wait(frames := 4) -> void:
	for i in frames:
		await process_frame


func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _init() -> void:
	boot = load("res://scenes/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	await wait(6)
	main = boot.get_child(0)

	check(main.show_menu and main._menu != null, "the game starts with the main menu")
	check(main.director.game == null, "nothing is dealt behind it")
	check(get_nodes_in_group("tiles").is_empty(), "there are no tiles on the table yet")
	check(not main.hud.visible, "the game's HUD is hidden")
	main.director._unhandled_key_input(key(KEY_ENTER)) # keys must not break a table that has no game
	main._unhandled_key_input(key(KEY_ESCAPE))
	check(main._pause == null, "Esc does nothing in the menu")

	var setup: RoomSetup = main._menu.open_setup()
	await wait(3)
	check(setup.visible and setup.size.x >= 1920.0 and setup.size.y >= 1080.0, "Masa kur fills its window (%s)" % setup.size)
	setup.show_page(1)
	await wait(2)

	# Every rule on the page has a row, a title and a text; nothing hidden or unknown sneaks in.
	var groups := setup.rules.groups()
	var rows := 0
	var missing := []
	for group: Dictionary in groups:
		for k: String in group.keys:
			rows += 1
			if not setup._controls.has(k) or not GameSettings.LABELS.has(k):
				missing.append(k)
	check(missing.is_empty(), "every setting has a row and a Turkish text (missing %s)" % [missing])
	check(groups.size() == 9 and rows >= 38, "nine tabs, %d rows" % rows)
	check(not setup._controls.has("blackout_mode") and not setup._controls.has("steal_from_melds"), "settings the game does not play yet have no row")
	# Search and filters narrow the list.
	setup._search.text = "ceza"
	setup._apply_filter()
	var shown := 0
	for k: String in setup._rows:
		if setup._rows[k].visible:
			shown += 1
	check(shown > 0 and shown < rows, "searching narrows the rows (%d of %d)" % [shown, rows])
	setup._search.text = ""
	setup._apply_filter()

	# Rule sets and edits.
	check(setup.rules.open_threshold == 101 and not setup.rules.run_wraps_13_1, "it starts with the standard rules (101, no 12-13-1)")
	setup.choose_preset("kahvehane")
	check(setup.rules.turn_time_limit == 45 and not setup.rules.auto_arrange_allowed and not setup.rules.group_hints, "the Kahvehane set loads")
	check(setup._controls.turn_time_limit.value == 45, "and the controls follow")
	setup.choose_preset("klasik")
	setup.set_rule("open_threshold", 81)
	check(setup.rules.open_threshold == 81 and setup._controls.open_threshold.value == 81, "a changed row writes the rule")
	check(setup._dots.open_threshold.modulate.a == 1.0 and setup._dots.penalty_unit.modulate.a == 0.0, "a yellow dot marks only the changed row")
	setup._controls.open_threshold.nudge(1) # as the player pressing +
	check(setup.rules.open_threshold == 82, "the stepper itself writes the rule")
	setup.set_rule("open_threshold", 81)
	setup._controls.friend_mode.toggled.emit(true)
	check(setup.rules.friend_mode, "a switch writes the rule")
	setup.set_rule("friend_mode", false)
	setup.set_rule("open_threshold", GameSettings.new().open_threshold)
	check(setup._dots.open_threshold.modulate.a == 0.0, "putting a row back clears its dot")
	setup.set_rule("open_threshold", 81)
	setup.set_rule("run_wraps_13_1", true)
	setup.choose_level(2, "kolay")
	setup.choose_level(3, "zor")
	check(setup.bots == ["normal", "kolay", "zor"], "levels are chosen per seat")
	setup._name_edit.text = "Talha"

	# Saving a rule set of one's own.
	setup.save_as("Ui Deneme Seti")
	var saved := GameSettings.preset("ui_deneme_seti")
	check(saved.open_threshold == 81 and saved.run_wraps_13_1, "a saved set comes back with the same rules")
	check(GameSettings.preset_names().has("ui_deneme_seti") and setup._preset_names.has("ui_deneme_seti"), "and shows in the list of sets")
	setup.choose_preset("klasik")
	check(setup.rules.open_threshold == 101, "(the standard set is untouched)")
	setup.choose_preset("ui_deneme_seti")
	check(setup.rules.open_threshold == 81, "choosing the saved set restores it")
	DirAccess.remove_absolute("user://presets/ui_deneme_seti.json")

	# Başlat.
	setup.start()
	await wait(8)
	var director: GameDirector = main.director
	check(director.game != null and main._menu == null, "Başlat starts the game and closes the menu")
	check(director.game.settings.open_threshold == 81 and director.game.settings.run_wraps_13_1, "with the chosen rules")
	check(director.bot(2).title == "Kolay" and absf(director.bot(2).brain.skill - 0.6) < 0.001, "and the chosen levels (seat 2: %s)" % director.bot(2).title)
	check(director.bot(1).title == "Normal" and director.bot(3).title == "Zor", "(the others too)")
	check(director.name_of(0) == "Talha" and Profile.player_name() == "Talha", "the player's name is his profile name")
	check(main.hud.visible and not get_nodes_in_group("tiles").is_empty(), "the HUD is back and the tiles are dealt")
	check(main.camera.process_mode == Node.PROCESS_MODE_INHERIT and main.hand.process_mode == Node.PROCESS_MODE_INHERIT, "the camera and hand work again")

	# Esc.
	main._unhandled_key_input(key(KEY_ESCAPE))
	await wait(3)
	check(main._pause != null and paused, "Esc opens the pause menu and stops the game")
	var tile_at_pause := director.table.pile_top().global_position
	await wait(10)
	check(director.table.pile_top().global_position == tile_at_pause and director.game.turn == 0, "nothing moves while it is open")
	check(main._pause._rules_text().contains("Açma barajı: 81") and main._pause._rules_text().contains("12-13-1"), "the pause menu lists the table's rules")
	main._pause._unhandled_key_input(key(KEY_ESCAPE))
	await wait(3)
	check(main._pause == null and not paused, "Esc again resumes")

	main._unhandled_key_input(key(KEY_ESCAPE))
	await wait(2)
	var pause: PauseMenu = main._pause
	pause._show_rules()
	check(pause._rules.visible and not pause._main.visible, "the rules page opens")
	pause._unhandled_key_input(key(KEY_ESCAPE))
	check(not pause._rules.visible and pause._main.visible, "Esc goes back one page first")
	pause._show_settings()
	check(pause._settings.visible and not pause._main.visible and pause._settings._controls.size() == Prefs.ROWS.size(), "Ayarlar opens from the pause menu with every setting")
	pause._unhandled_key_input(key(KEY_ESCAPE))
	check(not pause._settings.visible and pause._main.visible, "and Esc leaves it")
	pause.menu_requested.emit()
	await wait(8)
	check(not paused, "going back to the menu unpauses")
	boot = current_scene
	check(boot != null and boot.get_child_count() > 0, "a fresh scene is up")
	main = boot.get_child(0)
	check(main.show_menu and main._menu != null and main.director.game == null, "the main menu again, with nothing dealt")
	check(Engine.time_scale == 1.0, "and normal speed")

	print("FAILS: ", _failures.size())
	quit(1 if _failures.size() > 0 else 0)
