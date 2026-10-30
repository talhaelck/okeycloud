extends SceneTree
## Screenshots of the screens, to check by eye (windowed):
##   godot --path . --script tests/ui_shots.gd -- <out prefix> [rack|menu|room|pause|end]
## rack: reading the rack with the buttons and the lines under the groups. The others are added with their screens.

var prefix := "screenshots/ui"
var what: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		prefix = args[0]
	what.assign(args.slice(1))
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	if what.is_empty() or what.has("rack"):
		await _rack()
	if what.is_empty() or what.has("menu"):
		await _menus()
	if what.is_empty() or what.has("fx"):
		await _effects()
	if what.is_empty() or what.has("end"):
		await _end_of_hand()
	quit()


func _shot(name: String, frames := 40) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, name])
	print("saved ", name)


func _rack() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var director: GameDirector = main.director
	director.game.settings.turn_time_limit = 0
	for watcher: Watcher in main.watchers:
		watcher.process_mode = Node.PROCESS_MODE_DISABLED
	main.camera.mouse_control = false
	await process_frame
	director._arrange("sets")
	main.camera.set_mode(FocusCamera.Mode.RACK, true)
	await _shot("rack", 50)
	# And the same room without the helpers.
	director.game.settings.auto_arrange_allowed = false
	director.game.settings.group_hints = false
	await _shot("rack_plain", 20)


func _menus() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.show_menu = true
	root.add_child(main)
	await process_frame
	main.camera.mouse_control = false
	await _shot("menu", 150)
	var setup: RoomSetup = main._menu.open_setup()
	await _shot("room", 20)
	setup.choose_level(2, "kolay")
	setup.choose_level(3, "zor")
	await _shot("room_table", 10)
	setup.show_page(1)
	setup.set_rule("catch_window", 6.0)
	await _shot("room_rules", 20)
	setup.choose_preset("kahvehane")
	setup.show_page(0)
	await _shot("room_helpers", 20)
	main._menu._setup.visible = false
	main._menu._open_howto()
	await _shot("howto", 10)
	var rules := setup.rules
	main.start_game(rules, ["zor", "kolay", "normal"])
	await _shot("game_start", 50)
	var game: OkeyGame = main.director.game
	var made := [[-101, 34, 12, 87], [0, 148, 40, 22], [63, 9, 101, -101]]
	for hand_scores: Array in made:
		var result := []
		for p in 4:
			var lines := [["Elde kalan 5 taş", hand_scores[p]]] if hand_scores[p] < 100 else [["Taş çalarken yakalandı", 101]]
			game.totals[p] += hand_scores[p]
			result.append({"score": hand_scores[p], "lines": lines})
		game.history.append(result)
	game.hand_number = 3
	main.director._update_hud()
	main.director.hud.show_ledger(main.director._ledger_data())
	await _shot("ledger", 10)
	main.director.hud.show_ledger({})
	main._open_pause()
	await _shot("pause", 10)
	main._pause._show_rules()
	await _shot("pause_rules", 10)


func _effects() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var director: GameDirector = main.director
	director.game.settings.turn_time_limit = 0
	for watcher: Watcher in main.watchers:
		watcher.process_mode = Node.PROCESS_MODE_DISABLED
	main.camera.mouse_control = false
	main.camera.look(0.0, -0.75)
	await process_frame
	director.fx_opened(0)
	director.fx_opened(2)
	director._on_penalised(2, 101, "deneme")
	director._on_penalised(0, 101, "deneme")
	director.post_fx.pulse(Color(1.0, 0.12, 0.08), 3.0)
	await _shot("fx", 18)


func _end_of_hand() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var director: GameDirector = main.director
	var game := director.game
	game.settings.turn_time_limit = 0
	for watcher: Watcher in main.watchers:
		watcher.process_mode = Node.PROCESS_MODE_DISABLED
	main.camera.mouse_control = false
	main.camera.look(0.0, -0.5)
	# Some melds on the table first, so the overview shows a real end of hand.
	director._arrange("sets")
	await create_timer(0.5).timeout
	game.opened[0] = OkeyGame.Opened.SETS
	game.finisher = 2
	game.phase = OkeyGame.Phase.OVER
	game.opened[2] = OkeyGame.Opened.SETS
	game.opened[1] = OkeyGame.Opened.SETS
	director._end_hand()
	for step: Array in [[0.7, "end_1_swing"], [1.3, "end_2_face"], [1.1, "end_3_tip"], [1.6, "end_4_overview"], [2.5, "end_5_board"], [5.0, "end_6_done"]]:
		await create_timer(step[0]).timeout
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, step[1]])
		print("saved ", step[1])
