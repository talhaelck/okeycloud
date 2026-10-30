extends SceneTree
## Screenshots of how people look at the table, to check by eye (windowed):
##   godot --path . --script tests/poses_shot.gd -- <out prefix>
## <prefix>_table.png: from the player's seat, Hasan Amca reading his rack (head bowed), Hoca Dayı bent over the
## table, Mahmut Usta watching. <prefix>_lean.png: the player bent over the table (his own view).
## <prefix>_seen.png: the player bent over the table, seen by Mahmut Usta. <prefix>_rack.png: the player reading
## his rack, seen by Hasan Amca.

func _init() -> void:
	var prefix := "screenshots/poses"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		prefix = args[0]
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.director.game.settings.turn_time_limit = 0
	main.director.game.settings.stealing_enabled = false
	for watcher: Watcher in main.watchers:
		watcher.process_mode = Node.PROCESS_MODE_DISABLED
	var seats: Array[Seat] = main.seats
	var camera: FocusCamera = main.camera
	camera.mouse_control = false
	seats[1].buddy.look_home()
	seats[1].buddy.bow(Watcher.RACK_BOW)
	seats[2].buddy.look_home()
	seats[2].buddy.bow(Watcher.LEAN_BOW, Watcher.LEAN_BEND)
	seats[3].buddy.look_toward(seats[0].head_anchor.global_position)
	seats[3].buddy.bow(0.0)
	camera.look(0.0, -0.3)
	await _shot(prefix + "_table.png", 60)

	camera.set_mode(FocusCamera.Mode.LEAN)
	await _shot(prefix + "_lean.png", 60)

	main.view_seat(3)
	camera.set_mode(FocusCamera.Mode.OBSERVE, true)
	camera.look(-0.75, -0.35)
	seats[0].buddy.bow(0.5, 0.45)
	await _shot(prefix + "_seen.png", 60)

	main.view_seat(1)
	camera.look(0.8, -0.35)
	seats[0].buddy.face(0.0)
	seats[0].buddy.bow(0.55)
	await _shot(prefix + "_rack.png", 60)

	# The player lifts a tile out of Hasan Amca's rack while Hoca Dayı watches: his "!" fills up.
	main.view_seat(0)
	main.director.game.settings.stealing_enabled = true
	camera.set_mode(FocusCamera.Mode.OBSERVE, true)
	camera.look(-0.35, -0.35)
	var hand: Hand = main.hand
	hand.process_mode = Node.PROCESS_MODE_DISABLED
	for watcher: Watcher in main.watchers:
		watcher.paused = true
	seats[1].look_mode = FocusCamera.Mode.RACK
	seats[3].look_mode = FocusCamera.Mode.RACK
	var tiles := seats[1].rack.tiles()
	tiles.sort_custom(func(a: Tile, b: Tile) -> bool: return a.global_position.z > b.global_position.z)
	hand.grab(tiles[0])
	var over := tiles[0].global_position + Vector3(-0.1, 0.12, 0.05)
	seats[2].look_mode = FocusCamera.Mode.OBSERVE
	seats[2].look_dir = (over - seats[2].head_anchor.global_position).normalized()
	seats[2].buddy.look_toward(over)
	for i in 6:
		hand.held.global_position = over
		await process_frame
	await _shot(prefix + "_watched.png", 1)
	quit()


func _shot(path: String, frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
