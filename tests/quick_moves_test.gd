extends SceneTree
## The quick ways to handle tiles, driven by real mouse events through the real Hand: a quick click on the pile or the
## left discard draws it; a double-click on a rack tile throws it (a costly one only on the second try); Ctrl+click
## picks tiles and dragging one carries them all, keeping their shape; the rack buttons (best groups, pairs, by colour,
## by number); the lines under groups and the "El aç" button, which a room can switch off.
## Exits with code 1 on any failure.
##   godot --path . --headless --fixed-fps 30 --script tests/quick_moves_test.gd

var _failures: Array[String] = []
var main: Node
var director: GameDirector
var game: OkeyGame
var hand: Hand
var camera: FocusCamera
var rack: Rack


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		_failures.append(what)


func wait(frames := 3) -> void:
	for i in frames:
		await process_frame


# A left mouse button event on a world point (the hand aims by screen position in rack mode).
func mouse(point: Vector3, pressed: bool, ctrl := false, double := false) -> void:
	hand.aim_override = camera.unproject_position(point)
	await wait(2)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	event.double_click = double
	hand._unhandled_input(event)
	await wait(1)


func click(point: Vector3, ctrl := false, double := false) -> void:
	await mouse(point, true, ctrl, double)
	await mouse(point, false, ctrl, double)


func slot_point(index: int) -> Vector3:
	return rack.slot_global_transform(index).origin


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(5)
	director = main.director
	game = director.game
	hand = main.hand
	camera = main.camera
	rack = director.seats[0].rack
	game.settings.turn_time_limit = 0
	game.settings.stealing_enabled = false
	for watcher: Watcher in main.watchers:
		watcher.process_mode = Node.PROCESS_MODE_DISABLED
	camera.mouse_control = false
	camera.set_mode(FocusCamera.Mode.RACK, true)
	await wait(5)

	await _click_to_draw()
	await _double_click_to_throw()
	await _select_and_move_group()
	await _arrange_buttons()
	await _hints_and_tools()

	print("FAILS: ", _failures.size())
	quit(1 if _failures.size() > 0 else 0)


# The player is made the second to play: it is his turn to draw, with one tile fewer than a dealer.
func _click_to_draw() -> void:
	var tile := rack.tiles()[0]
	rack.release(tile)
	tile.queue_free()
	game.turn = 0
	game.phase = OkeyGame.Phase.DRAW
	game.expected[0] = 21
	# Something on the left player's row to take, and the pile top.
	var left := OkeyGame.left_of(0)
	var offered := director.seats[left].rack.tiles()[0]
	director.seats[left].rack.release(offered)
	director.table.put_discard(offered, left, 0.0)
	game.discards[left].append(offered.id)
	game.expected[left] -= 1
	await wait(3)

	var top := director.table.pile_top()
	var top_id := top.id
	var pile_before := game.pile.size()
	check(hand._pick(camera.global_position, (top.global_position - camera.global_position).normalized()) == top, "the pile top can be picked from the rack view")
	await click(top.global_position)
	await wait(8)
	check(top.holder == rack and rack.slot_of(top) >= 0, "a quick click on the pile puts its top tile on the rack")
	check(game.phase == OkeyGame.Phase.PLAY and game.pile.size() == pile_before - 1 and not game.pile.has(top_id), "the rules saw the draw")
	check(rack.tiles().size() == game.expected[0], "tile count after the click draw (%d, expects %d)" % [rack.tiles().size(), game.expected[0]])
	check(hand.held == null, "nothing stays in the hand")
	check(director.table.pile_top() != null and director.table.pile_top().id == game.pile_top(), "the next tile is on top")

	# Back to drawing, this time from the left.
	var cost := rack.tiles()[1]
	rack.release(cost)
	cost.queue_free()
	game.phase = OkeyGame.Phase.DRAW
	game.expected[0] = 21
	await wait(3)
	var row_top: Tile = director.table.discards(left).back()
	# (From the rack view the ray to this corner can pass through a rack tile first, so grab it directly.)
	hand.grab(row_top)
	hand._pressed_at = Time.get_ticks_msec() / 1000.0
	await mouse(row_top.global_position, false)
	await wait(8)
	check(row_top.holder == rack, "a quick click on the left discard takes it")
	check(game.discards[left].is_empty() and game.phase == OkeyGame.Phase.PLAY, "the rules saw the side take")
	check(rack.tiles().size() == game.expected[0], "tile count after the side take")

	# Out of turn the same click is no draw.
	game.turn = 1
	game.phase = OkeyGame.Phase.DRAW
	var other_top := director.table.pile_top()
	var size := game.pile.size()
	await click(other_top.global_position)
	await wait(8)
	check(game.pile.size() == size and other_top.holder == director.table, "out of turn a click does not draw")
	game.turn = 0
	game.phase = OkeyGame.Phase.PLAY


func _double_click_to_throw() -> void:
	game.turn = 0
	game.phase = OkeyGame.Phase.PLAY
	game._side_tile = -1 # (the tile taken from the left is not what this part is about)
	director._confirm = -1
	# A tile that is no costly throw: neither okey nor işlek (no meld is laid).
	var tile: Tile = null
	for candidate in rack.tiles():
		if not OkeyTiles.is_joker(candidate.id, game.okey):
			tile = candidate
			break
	var home := rack.slot_of(tile)
	var rack_count := rack.tiles().size()
	await mouse(tile.global_position, true)
	await mouse(tile.global_position, false)
	check(hand.held == tile, "a quick click keeps the tile in the hand")
	await mouse(tile.global_position, true, false, true) # the second click of the double-click
	await wait(6)
	check(director.table.discards(0).has(tile) and game.discards[0].has(tile.id), "the double-click threw it into his row")
	check(game.turn == 1, "and the turn passed")
	check(rack.tiles().size() == rack_count - 1 and rack.tiles().size() == game.expected[0], "his rack is one tile fewer")

	# A costly throw (an okey): the first double-click warns and puts it back in its slot, the second throws it.
	# (The bots must play out their turns first: when a bot ends his turn the director forgets the warning.)
	for i in 4000:
		if game.turn == 0 and not director._bots.any(func(b: Bot) -> bool: return b.busy()):
			break
		await process_frame
	game.turn = 0
	game.phase = OkeyGame.Phase.PLAY
	var okey: Tile = null
	for candidate in rack.tiles():
		if OkeyTiles.is_joker(candidate.id, game.okey):
			okey = candidate
	if okey == null:
		okey = rack.tiles()[0]
		# Make it an okey for this test by making a tile of the rack the okey.
		game.okey = okey.value
	var okey_slot := rack.slot_of(okey)
	await mouse(okey.global_position, true)
	await mouse(okey.global_position, false)
	await mouse(okey.global_position, true, false, true)
	await wait(8)
	check(okey.holder == rack and rack.slot_of(okey) == okey_slot, "a costly throw warns and the tile goes back to its own slot")
	check(game.turn == 0, "the turn did not pass")
	await mouse(okey.global_position, true)
	await mouse(okey.global_position, false)
	await mouse(okey.global_position, true, false, true)
	await wait(8)
	check(director.table.discards(0).has(okey) and game.turn == 1, "the second double-click throws it (penalty written: %s)" % str(game.penalties[0]))
	game.turn = 0
	game.phase = OkeyGame.Phase.PLAY


func _select_and_move_group() -> void:
	# A rack to work with: three neighbours in the upper row, a hole to move them to.
	game.turn = 0
	game.phase = OkeyGame.Phase.PLAY
	var upper := []
	for i in Rack.SLOTS:
		if rack.tile_at(Rack.SLOTS + i):
			upper.append(Rack.SLOTS + i)
	check(upper.size() >= 5, "the upper row has tiles to work with (%d)" % upper.size())
	var a: Tile = rack.tile_at(upper[0])
	var b: Tile = rack.tile_at(upper[1])
	var c: Tile = rack.tile_at(upper[2])
	await click(a.global_position, true)
	await click(b.global_position, true)
	await click(c.global_position, true)
	check(hand.selection.size() == 3 and a.selected and b.selected and c.selected, "Ctrl+click picks three tiles")
	await click(b.global_position, true)
	check(hand.selection.size() == 2 and not b.selected, "Ctrl+click again drops one from the selection")
	await click(b.global_position, true)
	check(hand.selection.size() == 3, "and picks it again")

	# Drag the first of them to the free slots at the end of the row.
	var free := []
	for i in Rack.SLOTS:
		if rack.tile_at(Rack.SLOTS + i) == null:
			free.append(Rack.SLOTS + i)
	var target := Rack.SLOTS + Rack.SLOTS - 3 # three from the right end
	var slots_before := [rack.slot_of(a), rack.slot_of(b), rack.slot_of(c)]
	await mouse(a.global_position, true)
	await wait(2)
	check(hand.held == a and hand._group.size() == 2, "dragging a selected tile takes the others along")
	hand.aim_override = camera.unproject_position(slot_point(target))
	await wait(10)
	await mouse(slot_point(target), false)
	await wait(14)
	check(rack.slot_of(a) == target and rack.slot_of(b) == target + 1 and rack.slot_of(c) == target + 2,
		"they land side by side where the first one was dropped (%d %d %d)" % [rack.slot_of(a), rack.slot_of(b), rack.slot_of(c)])
	check(hand.selection.is_empty() and not a.selected, "the selection is gone afterwards")
	check(rack.tiles().size() == game.expected[0], "no tile lost")

	# Dropping a selection somewhere that is not the rack sends all but the held tile back home.
	await click(a.global_position, true)
	await click(b.global_position, true)
	var home_b := rack.slot_of(b)
	await mouse(a.global_position, true)
	await wait(2)
	var felt := director.table.to_global(Vector3(0.0, Table.TOP, 0.1))
	hand.aim_override = camera.unproject_position(felt)
	await wait(6)
	hand.give_back()
	await wait(14)
	check(rack.slot_of(b) == home_b and a.holder == rack, "cancelling puts the whole group back")
	check(rack.tiles().size() == game.expected[0], "no tile lost after cancelling")


func _arrange_buttons() -> void:
	game.settings.auto_arrange_allowed = true
	director._on_tool("color")
	await wait(14)
	var groups := rack.groups()
	var colours_ok := true
	for group: Array in groups:
		var colour: int = (group[0] as Tile).value.x
		for tile: Tile in group:
			if tile.value.x != colour and not (OkeyTiles.is_joker(tile.id, game.okey) or tile.value.x == TileFactory.FAKE_OKEY):
				colours_ok = false
	check(colours_ok and groups.size() <= 5, "by colour: one group per colour (%d groups)" % groups.size())
	check(rack.tiles().size() == game.expected[0], "by colour: no tile lost")

	director._on_tool("number")
	await wait(14)
	# Thirteen numbers do not fit with gaps, so the groups may run together: what counts is the order.
	var numbers_ok := true
	var previous := 0
	for row in [1, 0]:
		for column in Rack.SLOTS:
			var tile := rack.tile_at(row * Rack.SLOTS + column)
			if tile == null or OkeyTiles.is_joker(tile.id, game.okey) or tile.value.x == TileFactory.FAKE_OKEY:
				continue
			if tile.value.y < previous:
				numbers_ok = false
			previous = tile.value.y
	check(numbers_ok, "by number: the tiles run in number order")
	check(rack.tiles().size() == game.expected[0], "by number: no tile lost")

	director._on_tool("sets")
	await wait(14)
	var valid := 0
	for group: Array in rack.groups():
		var ids: Array[int] = []
		for tile: Tile in group:
			ids.append(tile.id)
		if ids.size() >= 3 and Meld.make(ids, game.okey, game.settings.run_wraps_13_1):
			valid += 1
	var best := Solver.best(director.rack_ids(rack), game.okey, game.settings.run_wraps_13_1)
	check(valid >= best.groups.size() - 0, "best groups: every group the solver found is laid out (%d of %d)" % [valid, best.groups.size()])

	director._on_tool("pairs")
	await wait(14)
	var pairs := Solver.pairs(director.rack_ids(rack), game.okey)
	var laid_pairs := 0
	for group: Array in rack.groups():
		if group.size() == 2:
			laid_pairs += 1
	check(laid_pairs >= pairs.count, "pairs: the pairs are side by side (%d of %d)" % [laid_pairs, pairs.count])

	game.settings.auto_arrange_allowed = false
	var before := director.rack_ids(rack)
	director._on_tool("color")
	await wait(10)
	check(director.rack_ids(rack) == before, "the buttons do nothing in a room without them")
	game.settings.auto_arrange_allowed = true


func _hints_and_tools() -> void:
	game.settings.group_hints = true
	director._on_tool("sets")
	await wait(14)
	director._update_hints()
	var lines: int = rack._hint_root.get_child_count()
	check(lines > 0, "lines under the groups (%d nodes)" % lines)
	var greens := 0
	for child in rack._hint_root.get_children():
		if child is MeshInstance3D and (child.material_override as StandardMaterial3D).albedo_color.g > 0.8:
			greens += 1
	var best := Solver.best(director.rack_ids(rack), game.okey, game.settings.run_wraps_13_1)
	check(greens >= best.groups.size(), "a green line for each valid group (%d of %d)" % [greens, best.groups.size()])

	director._update_tools()
	check(hand.camera.mode == FocusCamera.Mode.RACK and director.hud.tools_visible(), "the buttons show in rack view")
	check(director.hud.opening_visible(), "and so does the opening bar")
	camera.set_mode(FocusCamera.Mode.OBSERVE, true)
	director._update_tools()
	check(not director.hud.tools_visible(), "and not otherwise")
	camera.set_mode(FocusCamera.Mode.RACK, true)

	game.settings.group_hints = false
	game.settings.auto_arrange_allowed = false
	director._update_hints()
	director._update_tools()
	await wait(2)
	check(rack._hint_root.get_child_count() == 0, "the lines are gone in a room without counting")
	check(not director.hud.tools_visible(), "and so are the buttons")
	check(not director.hud.opening_visible(), "and the opening bar")
