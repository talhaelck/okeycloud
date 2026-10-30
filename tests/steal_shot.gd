extends SceneTree
## Frames of Mahmut Usta (seat 3) stealing from the player's rack, seen from Hoca Dayı's seat opposite (windowed), to check
## by eye how the long reach looks:
##   godot --path . --fixed-fps 30 --script tests/steal_shot.gd -- <out prefix>
## Saves <prefix>_<frame>.png every 6th frame and <prefix>_sheet.png with all of them.

func _init() -> void:
	var prefix := "screenshots/steal/steal"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		prefix = args[0]
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var director: GameDirector = main.director
	director.game.settings.turn_time_limit = 0
	for watcher: Watcher in main.watchers:
		watcher.paused = true
	for p in range(1, 4):
		director.bot(p).greed = 0.0
	var camera: FocusCamera = main.camera
	camera.mouse_control = false
	main.view_seat(2)
	camera.look(-0.35, -0.55)
	for i in 30:
		await process_frame
	var tiles := director.seats[0].rack.tiles()
	tiles.sort_custom(func(a: Tile, b: Tile) -> bool: return a.global_position.x < b.global_position.x)
	var thief := director.bot(3)
	thief.swaps = false
	var frames: Array[Image] = []
	thief.steal({"kind": "rack", "victim": 0, "tile": tiles[0]}) # runs on while we film it
	var n := 0
	while thief._busy and n < 400:
		await process_frame
		if n % 6 == 0:
			await RenderingServer.frame_post_draw
			var image := root.get_viewport().get_texture().get_image()
			image.save_png("%s_%03d.png" % [prefix, n])
			frames.append(image)
		n += 1
	# contact sheet, 4 across
	var w := 480
	var h := int(frames[0].get_height() * w / float(frames[0].get_width()))
	var rows := ceili(frames.size() / 4.0)
	var sheet := Image.create(w * 4, h * rows, false, frames[0].get_format())
	for i in frames.size():
		var small := frames[i].duplicate() as Image
		small.resize(w, h)
		sheet.blit_rect(small, Rect2i(0, 0, w, h), Vector2i((i % 4) * w, (i / 4) * h))
	sheet.save_png(prefix + "_sheet.png")
	print("saved ", frames.size(), " frames")
	quit()
