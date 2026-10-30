extends SceneTree
## What each player sees of the room: from every seat's eyes, looking ahead, left, behind and right.
## Saves <prefix>_seat<i>_<dir>.png and a 4x4 contact sheet <prefix>_sheet.png (rows = seats).
##   godot --path . --script tests/room_survey.gd -- <prefix>

const DIRECTIONS := {"on": 0.0, "sol": PI * 0.5, "arka": PI, "sag": -PI * 0.5}


func _init() -> void:
	var prefix: String = OS.get_cmdline_user_args()[0]
	RiggedDayi.demo = false
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 75
	root.add_child(cam)
	cam.make_current()
	var sheet := Image.create(320 * 4, 180 * 4, false, Image.FORMAT_RGB8)
	var seats: Array = game.seats
	for s in seats.size():
		var seat: Seat = seats[s]
		# That player's own dayı is hidden from himself, as it will be in multiplayer.
		for other in seats:
			if other.buddy:
				other.buddy.visible = other != seat
		var eye := seat.to_global(Seat.EYE)
		var column := 0
		for name: String in DIRECTIONS:
			var forward := seat.global_basis * (Basis(Vector3.UP, DIRECTIONS[name]) * Vector3.FORWARD)
			cam.look_at_from_position(eye, eye + forward + Vector3.DOWN * 0.15)
			await process_frame
			await process_frame
			var image := root.get_texture().get_image()
			image.save_png("%s_seat%d_%s.png" % [prefix, s, name])
			image.resize(320, 180)
			sheet.blit_rect(image, Rect2i(0, 0, 320, 180), Vector2i(column * 320, s * 180))
			column += 1
	sheet.save_png(prefix + "_sheet.png")
	quit()
