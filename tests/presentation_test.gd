extends SceneTree
## The shows and the settings (headless, so they are switched on by hand): the intro runs before the menu and any
## key skips it to the menu with the camera in the menu's pose; the deal show holds the first turn, a key skips it
## and every tile ends up in its slot; Prefs keep what was set and put it into effect; the settings page writes
## them. Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/presentation_test.gd

var _failures: Array[String] = []
var _kept_prefs := ""
var _had_prefs := false


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
	_keep_prefs()
	await _prefs()
	await _intro()
	await _deal_show()
	_restore_prefs()
	print("FAILS: ", _failures.size())
	quit(1 if _failures.size() > 0 else 0)


# --- Prefs ----------------------------------------------------------------------------------------------------------

func _prefs() -> void:
	await wait(1) # (the tree is up: the settings reach the window and the viewport)
	Prefs.reload()
	Prefs.reset_all()
	check(Prefs.get_value("master_volume") == 80 and Prefs.get_value("intro") == true, "the settings start at their defaults")
	Prefs.set_value("master_volume", 40)
	Prefs.set_value("grain", false)
	Prefs.set_value("render_scale", 70)
	Prefs.reload()
	check(Prefs.get_value("master_volume") == 40 and Prefs.get_value("grain") == false and Prefs.get_value("render_scale") == 70,
		"what was set comes back from the file")
	check(not Prefs.is_default("grain") and Prefs.is_default("vsync"), "and only those rows count as changed")
	var master := AudioServer.get_bus_index("Master")
	check(absf(AudioServer.get_bus_volume_db(master) - linear_to_db(0.4)) < 0.01, "the master bus follows (%.1f dB)" % AudioServer.get_bus_volume_db(master))
	check(not PostFx.grain_enabled, "the grain is off")
	check(absf(root.scaling_3d_scale - 0.7) < 0.001, "the 3D picture is scaled (%.2f)" % root.scaling_3d_scale)
	Prefs.set_value("effects_volume", 0)
	check(AudioServer.get_bus_index(Sfx.BUS) >= 0 and AudioServer.is_bus_mute(AudioServer.get_bus_index(Sfx.BUS)), "the game's sounds have a bus of their own, muted at 0")
	Prefs.reset_all()
	check(Prefs.get_value("master_volume") == 80 and PostFx.grain_enabled and absf(root.scaling_3d_scale - 1.0) < 0.001, "Hepsini sıfırla puts everything back")
	# A broken file is the default game.
	var file := FileAccess.open(Prefs.PATH, FileAccess.WRITE)
	file.store_string("{\"master_volume\": \"yüksek\", \"nonsense\": 3")
	file.close()
	Prefs.reload()
	check(Prefs.get_value("master_volume") == 80, "a broken file is ignored")
	Prefs.reset_all()


# --- The intro ----------------------------------------------------------------------------------------------------------

func _intro() -> void:
	Intro.enabled = true
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script._intro_played = false
	var boot: Node = load("res://scenes/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	await wait(3)
	var main: Node = boot.get_child(0)
	check(main.intro != null and main._menu == null, "the game opens with the intro, not the menu")
	check(not main.hud.visible and main.director.game == null, "nothing is dealt and no HUD shows")
	var camera: Camera3D = main.camera
	var before := camera.global_position
	await wait(6)
	check(camera.global_position.distance_to(before) > 0.0005, "the camera moves (%.4f m)" % camera.global_position.distance_to(before))
	main.intro._time = 5.6
	await wait(2)
	check(main.intro.title_visible(), "the name of the game is on at 5.6 s")
	main.intro._time = Intro.DURATION - 0.05
	await wait(4)
	check(main.intro == null and main._menu != null, "it runs out into the menu")
	check(camera.global_position.distance_to(MainMenu.orbit_pose(0.0).origin) < 0.03, "with the camera in the menu's first pose (%s)" % camera.global_position)
	boot.queue_free()
	await wait(2)

	# Again, skipped by a key.
	main_script._intro_played = false
	boot = load("res://scenes/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	await wait(3)
	main = boot.get_child(0)
	check(main.intro != null, "the intro again")
	main.intro._input(key(KEY_SPACE))
	await wait(4)
	check(main.intro == null and main._menu != null, "a key skips it to the menu")
	check(main.camera.global_position.distance_to(MainMenu.orbit_pose(0.0).origin) < 0.06, "camera in the menu's pose after the skip (%s)" % main.camera.global_position)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or DisplayServer.get_name() == "headless", "the mouse is free")
	# The settings page writes the settings.
	var settings: SettingsMenu = main._menu.settings_screen()
	settings.set_pref("render_scale", 60)
	check(Prefs.get_value("render_scale") == 60 and absf(root.scaling_3d_scale - 0.6) < 0.001, "the settings page writes a setting and it is applied")
	settings.set_pref("render_scale", 100)
	check(settings._resets.render_scale.modulate.a == 0.0, "a row put back hides its Sıfırla")
	boot.queue_free()
	await wait(2)
	# After "Ana menüye dön" there is no intro.
	boot = load("res://scenes/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	await wait(3)
	main = boot.get_child(0)
	check(main.intro == null and main._menu != null, "it plays once per run: the menu comes straight back")
	boot.queue_free()
	await wait(2)
	Intro.enabled = false


# --- The deal show -------------------------------------------------------------------------------------------------------

func _deal_show() -> void:
	DealShow.enabled = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(3)
	var director: GameDirector = main.director
	var game: OkeyGame = director.game
	var camera: FocusCamera = main.camera
	check(director.deal_show != null and director.deal_show.running, "the hand starts with the deal show")
	check(camera.cine_blend == 1.0, "the camera has left the player's eyes")
	check(main.hand.process_mode == Node.PROCESS_MODE_DISABLED, "the hand is kept out of it")
	var busy := false
	for i in 20:
		await process_frame
		for p in range(1, 4):
			if director.bot(p).busy():
				busy = true
	check(not busy, "no bot plays while the tiles fly")
	director._unhandled_key_input(key(KEY_SPACE))
	await wait(4)
	check(director.deal_show == null, "a key skips the show")
	check(camera.cine_blend == 0.0, "the camera is back in the player's eyes")
	check(main.hand.process_mode == Node.PROCESS_MODE_INHERIT, "and the hand works")
	check(_tiles_home(director, game), "every tile sits in its slot")
	check(director.table.indicator.global_basis.z.y > 0.99, "the gösterge lies face up (%.2f)" % director.table.indicator.global_basis.z.y)
	check(game.turn == 0 or director.bot(game.turn).busy(), "the first turn has begun (seat %d)" % game.turn)
	main.queue_free()
	await wait(2)

	# Left alone it runs out by itself.
	Sfx.reset_counts()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(3)
	director = main.director
	game = director.game
	camera = main.camera
	check(director.deal_show != null and director.deal_show.running, "another table, another show")
	var home_at_end := [false]
	director.deal_show.finished.connect(func() -> void: home_at_end[0] = _tiles_home(director, game))
	var frames := 0
	var played := false # the player's clock must not run out under the show and hand his turn to the stand-in
	while director.deal_show != null and frames < 400:
		await process_frame
		frames += 1
		played = played or director._stand_in_playing
	check(not played, "the player's clock waits for the show")
	check(director.deal_show == null and frames < 400, "it runs out (%d frames)" % frames)
	check(home_at_end[0], "every tile is home as it ends (the first turn moves one right after)")
	check(Sfx.count("tile_rack") >= 10, "the tiles clicked into the racks (%d; at most %d sounds play at once)" % [Sfx.count("tile_rack"), Sfx.MAX_PLAYING])
	check(camera.cine_blend == 0.0, "the camera came back")
	main.queue_free()
	await wait(2)
	DealShow.enabled = false


func _tiles_home(director: GameDirector, game: OkeyGame) -> bool:
	var ok := true
	for p in 4:
		var rack: Rack = director.seats[p].rack
		if rack.tiles().size() != game.expected[p]:
			print("      rack %d holds %d tiles, expected %d" % [p, rack.tiles().size(), game.expected[p]])
			ok = false
		for tile in rack.tiles():
			var slot := rack.slot_global_transform(rack.slot_of(tile))
			var off := tile.global_position.distance_to(slot.origin)
			if off > 0.002:
				print("      rack %d: tile %d is %.3f m from its slot" % [p, tile.id, off])
				ok = false
	return ok


# --- The player's file --------------------------------------------------------------------------------------------------

func _keep_prefs() -> void:
	_had_prefs = FileAccess.file_exists(Prefs.PATH)
	if _had_prefs:
		_kept_prefs = FileAccess.get_file_as_string(Prefs.PATH)


func _restore_prefs() -> void:
	if _had_prefs:
		var file := FileAccess.open(Prefs.PATH, FileAccess.WRITE)
		file.store_string(_kept_prefs)
	else:
		DirAccess.remove_absolute(Prefs.PATH)
	Prefs.reload()
