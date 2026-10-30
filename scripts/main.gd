extends Node3D
## The table and everything around it: wires the local camera, hand, opponents and HUD. With `show_menu` set (the
## game as started by scenes/boot.tscn) it first shows the main menu over the room; Başlat in "Oda kur" calls
## start_game() with the chosen rules and bot levels. Without it (tests, screenshots, `--play`) the game starts at
## once with the house rules from the command line (`--preset=<name>`, `--set=<key>=<value>`, see GameSettings).
## Debug: `godot --path . -- --screenshot=<file.png> [--focus] [--yaw=<rad>] [--pitch=<rad>] [--hold] [--spill] [--caught] [--frames=<n>] [--view=<seat 0-3>] [--top] [--lean]`
## renders one frame and quits (--hold puts a tile from your rack in the hand; --frames sets how many frames
## run before the capture; --top looks straight down on the table; --lean bends over the table).

var hand := Hand.new()
var hud := Hud.new()
var post_fx := PostFx.new()
var director: GameDirector = GameDirector.new()
var watchers: Array[Watcher] = []
## Show the main menu instead of starting a game right away (set by Boot before the scene is added).
var show_menu := false
var _viewing := 0 # whose eyes the camera looks out of (keys 1-4)
var _menu: MainMenu
var _pause: PauseMenu
## The black curtain between the intro, the menu and the table (over everything).
var fade := Fade.new()
var intro: Intro
static var _intro_played := false # once per run: not again after "Ana menüye dön"
static var _lift_curtain := false # the scene starts under the curtain (after "Ana menüye dön") and lifts it

@onready var camera: FocusCamera = $FocusCamera
@onready var table: Table = $Table
@onready var seats: Array[Seat] = [$Seats/Seat0, $Seats/Seat1, $Seats/Seat2, $Seats/Seat3]


func _enter_tree() -> void:
	RiggedDayi.demo = false # the rules move their tiles now (set before the seats build their dayıs)


func _ready() -> void:
	camera.attach_to_seat(seats[0])
	for seat in seats.slice(1):
		var watcher := Watcher.new()
		watcher.seat = seat
		watcher.local_seat = seats[0]
		for other in seats:
			if other != seat and other != seats[0]:
				watcher.others.append(other)
		add_child(watcher)
		watchers.append(watcher)

	hand.camera = camera
	hand.seat = seats[0]
	hand.seats = seats
	hand.table = table
	add_child(hand)
	add_child(post_fx)
	add_child(hud)
	for i in seats.size():
		seats[i].set_viewed(i == 0)
	director.seats = seats
	director.table = table
	director.hand = hand
	director.hud = hud
	director.post_fx = post_fx
	director.menu_requested.connect(return_to_menu)
	director.watchers = watchers
	add_child(director)
	add_child(fade)
	if _lift_curtain:
		_lift_curtain = false
		fade.cover()
	Prefs.apply()

	if show_menu:
		if _wants_intro():
			_play_intro()
		else:
			_enter_menu()
		return
	start_game(GameSettings.from_command_line())
	var args := _user_args()
	if args.has("screenshot"):
		_capture(args)


## Starts a game with these house rules and a level id (GameDirector.LEVELS) for each of seats 1-3. From the menu the
## picture goes dark for a moment and comes back on the table.
func start_game(rules: GameSettings, bots: Array = []) -> void:
	if _menu:
		await fade.darken(0.45)
		_menu.queue_free()
		_menu = null
		fade.lighten(0.9)
	hud.visible = true
	post_fx.blindness = rules.rack_blindness
	camera.process_mode = Node.PROCESS_MODE_INHERIT
	hand.process_mode = Node.PROCESS_MODE_INHERIT if _viewing == 0 else Node.PROCESS_MODE_DISABLED
	for i in seats.size():
		seats[i].set_viewed(i == _viewing)
	camera.attach_to_seat(seats[_viewing])
	camera.look(0.0, -0.5)
	camera.set_focused(false, true)
	director.start(rules, bots)


## Back to the main menu: the whole scene starts over.
func return_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	await fade.darken(0.5)
	_lift_curtain = true
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/boot.tscn") # (a game started without Boot, as tests do)


func _enter_menu() -> void:
	hud.visible = false
	hand.process_mode = Node.PROCESS_MODE_DISABLED
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	for seat in seats:
		seat.set_viewed(false) # everyone shows his face in the menu
	_menu = MainMenu.new()
	_menu.camera = camera
	_menu.started.connect(start_game)
	_menu.quit_pressed.connect(_quit)
	add_child(_menu)
	if camera.mouse_control:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if fade.is_dark():
		fade.lighten(1.2)


## The opening: the walk in from the door (Intro), then the menu. `--no-intro` and the "intro" setting skip it; it
## plays once per run.
func _wants_intro() -> bool:
	if _intro_played or _user_args().has("no-intro") or not Prefs.get_value("intro"):
		return false
	return true


func _play_intro() -> void:
	_intro_played = true
	hud.visible = false
	hand.process_mode = Node.PROCESS_MODE_DISABLED
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	for seat in seats:
		seat.set_viewed(false)
	if camera.mouse_control:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	intro = Intro.new()
	intro.camera = camera
	intro.fade = fade
	intro.door_hinge = $Room.door_hinge
	intro.finished.connect(func() -> void:
		intro = null
		_enter_menu())
	add_child(intro)


func _quit() -> void:
	await fade.darken(0.4)
	get_tree().quit()


func _open_pause() -> void:
	_pause = PauseMenu.new()
	_pause.rules = director.game.settings
	_pause.closed.connect(_on_pause_closed)
	_pause.menu_requested.connect(return_to_menu)
	_pause.quit_requested.connect(_quit)
	add_child(_pause)


func _on_pause_closed() -> void:
	_pause = null
	if camera.mouse_control:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if camera.focused else Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	hud.show_crosshair(not camera.focused)
	if _viewing == 0:
		_show_attention(seats[0])
	var edge := camera.unproject_position(seats[_viewing].rack.top_edge()).y / get_viewport().get_visible_rect().size.y
	post_fx.set_rack_view(camera.rack_amount, edge)
	if _viewing == 0:
		hud.set_hint(hand.hint)
	else:
		hud.set_hint("%s gözünden bakıyorsun  ·  1: kendi yerine dön  ·  2-4: diğerleri" % seats[_viewing].display_name())


# Where the player looks is what the others go by (Visibility) and what his dayı shows them: head turned with his
# view, bowed over his rack, or bent over the table looking down on the middle.
func _show_attention(me: Seat) -> void:
	me.look_mode = camera.mode
	me.look_dir = -camera.global_basis.z
	if me.buddy == null:
		return
	match camera.mode:
		FocusCamera.Mode.RACK:
			me.buddy.face(0.0)
			me.buddy.bow(0.55)
		FocusCamera.Mode.LEAN:
			me.buddy.face(camera.lean_yaw)
			me.buddy.bow(0.5, 0.45)
		_:
			me.buddy.face(camera.yaw)
			me.buddy.bow(clampf(-(camera.pitch + 0.45), -0.3, 0.5))


# Keys 1-4 look out of that seat's eyes (what each player will see online). Only seat 1 plays; the others are
# for looking.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or director.game == null:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		view_seat(key.keycode - KEY_1)
	elif key.keycode == KEY_ESCAPE and _pause == null:
		if hand.selection.is_empty():
			_open_pause()
		else:
			hand.clear_selection()


func view_seat(index: int) -> void:
	_viewing = index
	for i in seats.size():
		seats[i].set_viewed(i == index)
	director.set_viewed(index)
	camera.attach_to_seat(seats[index])
	camera.look(0.0, -0.5)
	camera.set_focused(false, true)
	hand.process_mode = Node.PROCESS_MODE_INHERIT if index == 0 else Node.PROCESS_MODE_DISABLED
	if index != 0:
		hand.drop_view()


func _capture(args: Dictionary) -> void:
	var path: String = args["screenshot"]
	camera.mouse_control = false
	if args.has("view"):
		view_seat(int(args["view"]))
	camera.set_focused(args.has("focus"), true)
	camera.look(float(args.get("yaw", "0")), float(args.get("pitch", "-0.5")))
	hand.aim_override = get_viewport().get_visible_rect().size * Vector2(0.55, 0.42)
	if args.has("hold"):
		hand.grab(_first_rack_tile())
	if args.has("spill"):
		var glass := seats[0].tea
		glass.apply_impulse(Vector3(-0.3, 0, -0.1), glass.global_basis * Vector3(0, TeaGlass.GLASS_HEIGHT, 0))
	if args.has("caught"):
		hud.stamp("YAKALANDIN!", Color("e0402f"))
	if args.has("lean"):
		camera.set_mode(FocusCamera.Mode.LEAN, true)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for i in int(args.get("frames", "30")):
		await get_tree().process_frame
	if args.has("top"):
		# Straight down over the table, seat 0 at the bottom of the picture.
		camera.process_mode = Node.PROCESS_MODE_DISABLED
		camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, 1.5, 0))
		camera.fov = 100.0 # wide, from under the lamp
		(camera.attributes as CameraAttributesPractical).dof_blur_far_enabled = false
		(camera.attributes as CameraAttributesPractical).dof_blur_near_enabled = false
		post_fx.blindness = 0.0
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Screenshot saved: ", path)
	get_tree().quit()


func _first_rack_tile() -> Tile:
	return get_tree().get_nodes_in_group("tiles").filter(func(t: Tile) -> bool: return t.holder == seats[0].rack)[3]


func _user_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else ""
	return out
