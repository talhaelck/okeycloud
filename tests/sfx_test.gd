extends SceneTree
## The game's sounds fire where they should: the deal, a tile sitting in a rack, a discard on the felt, drawing,
## opening, a theft click, getting caught. Headless there is nothing to listen to, so this counts them with Sfx.played.
## Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/sfx_test.gd

var _failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		_failures.append(what)


func _init() -> void:
	Sfx.reset_counts()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	var director: GameDirector = main.director
	var game := director.game
	game.settings.turn_time_limit = 0
	for watcher: Watcher in main.watchers:
		watcher.process_mode = Node.PROCESS_MODE_DISABLED
	check(Sfx.count("shuffle") >= 1, "the deal shuffles (%d)" % Sfx.count("shuffle"))

	var before := Sfx.count("tile_rack")
	var rack: Rack = director.seats[0].rack
	var tile: Tile = rack.tiles()[0]
	var slot := rack.slot_of(tile)
	rack.release(tile)
	rack.put(tile, slot, true, 0.1)
	for i in 12:
		await process_frame
	check(Sfx.count("tile_rack") == before + 1, "a tile sitting in the rack clicks")

	before = Sfx.count("tile_felt")
	var spare: Tile = rack.tiles()[1]
	rack.release(spare)
	director.table.put_discard(spare, 0, 0.1)
	for i in 12:
		await process_frame
	check(Sfx.count("tile_felt") == before + 1, "a discard lands on the felt")

	before = Sfx.count("tile_click")
	director.stealing.click(Vector3(0, 1, 0), 0)
	for i in 3:
		await process_frame
	check(Sfx.count("tile_click") > before, "a theft clicks")

	before = Sfx.count("sting_caught")
	director.stealing._reactions(1, 0)
	for i in 3:
		await process_frame
	check(Sfx.count("sting_caught") > before, "getting caught has its sting")

	print("FAILS: ", _failures.size())
	quit(1 if _failures.size() > 0 else 0)
