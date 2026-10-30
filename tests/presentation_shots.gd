extends SceneTree
## Screenshots of the shows and the new screens, to check by eye (windowed, with --fixed-fps 30 so the moments land):
##   godot --path . --fixed-fps 30 --script tests/presentation_shots.gd -- <out prefix> [intro|menu|deal|pause]
## intro: the doorway, the turn, the title, the lift; menu: the arrival, Ayarlar; deal: the tiles in flight and the
## okey stamp; pause: the Esc menu and its Ayarlar page.

var prefix := "screenshots/show"
var what: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		prefix = args[0]
	what.assign(args.slice(1))
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	Intro.enabled = true
	DealShow.enabled = what.is_empty() or what.has("deal")
	var boot: Node = load("res://scenes/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	await _frames(2)
	var main: Node = boot.get_child(0)
	main.camera.mouse_control = false
	var intro: Intro = main.intro
	main.fade.clear() # (the curtain lifts over 2 s of real time; the shots jump about in it)
	if what.is_empty() or what.has("intro"):
		for step: Array in [[0.9, "intro_1_door"], [3.2, "intro_2_turn"], [5.0, "intro_3_title"], [12.6, "intro_4_lift"]]:
			intro._time = step[0]
			await _shot(step[1], 40 if step[1] == "intro_3_title" else 2)
	intro._time = Intro.DURATION - 0.01
	await _frames(3)
	if what.is_empty() or what.has("menu"):
		await _shot("menu_1_arrive", 8)
		await _shot("menu_2_settled", 60)
		main._menu._open_settings()
		await _shot("menu_3_settings", 14)
		main._menu._close_settings()
		await _frames(14)
	main._menu.open_setup()
	await _frames(14)
	main._menu.setup_screen().start()
	if what.is_empty() or what.has("deal"):
		await _shot("deal_1_rise", 22)
		await _shot("deal_2_fly", 30)
		await _shot("deal_3_okey", 65)
	await _frames(60)
	if main.director.deal_show:
		main.director.deal_show.skip()
	await _frames(5)
	if what.is_empty() or what.has("pause"):
		main._open_pause()
		await _shot("pause_1_menu", 12)
		main._pause._show_settings()
		await _shot("pause_2_settings", 4)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String, frames := 4) -> void:
	await _frames(frames)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, name])
	print("saved ", name)
