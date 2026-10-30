class_name GameDirector
extends Node
## Runs 101 Okey on the physical table. The rules are OkeyGame's; this deals the racks, keeps the pile, the
## gösterge, the discard rows and the laid melds in step with it, checks what the player's hand picks up and lets
## go against the rules (drawing, taking from the left, discarding are all done by dragging tiles), plays the other
## seats with Bots and shows turns, penalties and scores on the HUD.
## Seat 0 is the local player. He opens by grouping tiles on his rack (an empty slot between groups) and pressing
## Enter; R lays his rack out as the solver's best groups (again: as pairs); dropping a tile on a laid meld işles it
## or swaps it for the okey there. Enter after the hand: next hand. Tab: the score sheet.
## Stealing, "Yakala!" (F) and "Taş say!" (C) are Stealing's; both keys go to the player you are looking at.

## The player asked for the main menu (the end-of-match button); Main goes back to it.
signal menu_requested

const PLAYER := 0
const MELD_PICK := 0.07 # a tile dropped this close to a laid tile goes to that meld
const NAME_ANGLE := 0.2 # radians: his name shows over his head while his head is this close to the middle of your view
const ACCUSE_ANGLE := 0.45 # radians: F and C go to the player whose head is this close to the middle of your view
## How a bot plays (every seat that is not a person gets one of these; the room setup lets you choose per seat): how
## often he looks up and calls what he sees (vigilance), how keen he is to steal (greed, 0 when the room's
## `bots_steal` rule is off), how well he plays (skill), and whether he puts one of his own tiles back after
## stealing so counting cannot catch him (swaps).
const LEVELS := {
	"kolay": {"name": "Kolay", "vigilance": 0.3, "greed": 0.10, "skill": 0.6, "swaps": false,
		"blurb": "Dalgın oynar, bazen yanlış taş atar. Kolay kandırılır."},
	"normal": {"name": "Normal", "vigilance": 0.55, "greed": 0.20, "skill": 0.85, "swaps": false,
		"blurb": "Düzgün oynar, arada etrafına bakar, fırsat bulursa çalar."},
	"zor": {"name": "Zor", "vigilance": 0.8, "greed": 0.35, "skill": 0.95, "swaps": true,
		"blurb": "Gözünden bir şey kaçmaz. Çaldığında yerine kendi taşını bırakır."},
}
const LEVEL_ORDER := ["kolay", "normal", "zor"]
## Seats 1-3 unless the room says otherwise.
const DEFAULT_LEVELS := ["normal", "normal", "normal"]

var game: OkeyGame
var seats: Array[Seat] = []
var table: Table
var hand: Hand
var hud: Hud
var post_fx: PostFx
var watchers: Array[Watcher] = []
var stealing: Stealing = Stealing.new()
var end_show: HandEndShow
var deal_show: DealShow
var _plates: Array[Nameplate] = []

var _bots: Array[Bot] = []
var _stand_in: Bot = Bot.new() # plays the player's turn when his time runs out
var _tiles := {} # tile id -> Tile, every tile of the hand
var _confirm := -1 # a costly discard the player has been warned about once
var _time_left := 0.0
var _stand_in_playing := false
var _info_timer := 0.0
var _arrange_pairs := false # R alternates between sets/runs and pairs


## `bots` are level ids from LEVELS for seats 1-3 (DEFAULT_LEVELS if empty).
func start(rules: GameSettings, bots: Array = []) -> void:
	game = OkeyGame.new(rules)
	game.penalised.connect(_on_penalised)
	game.hand_ended.connect(func(_finisher: int) -> void: _end_hand.call_deferred())
	hand.grab_check = _grab_check
	hand.drop_check = _drop_check
	hand.drop_hint = _drop_hint
	hand.quick_click = _quick_click
	hand.throw_click = _throw_click
	hand.hover_hint = _hover_hint
	hud.tool_pressed.connect(_on_tool)
	for p in OkeyGame.PLAYERS:
		var bot := _stand_in if p == PLAYER else Bot.new()
		bot.seat_index = p
		bot.seat = seats[p]
		bot.director = self
		for watcher in watchers:
			if watcher.seat == seats[p]:
				bot.watcher = watcher
		if p != PLAYER:
			var id: String = bots[p - 1] if bots.size() >= p else DEFAULT_LEVELS[p - 1]
			var level: Dictionary = LEVELS.get(id, LEVELS.normal).duplicate()
			if not rules.bots_steal:
				level.greed = 0.0
				level.swaps = false
			bot.set_personality(level)
		add_child(bot)
		_bots.append(bot)
	stealing.director = self
	add_child(stealing)
	stealing.setup()
	for p in OkeyGame.PLAYERS:
		var plate := Nameplate.new()
		plate.position = Vector3(0, Table.TOP + 0.3, Seat.RACK_DISTANCE) # a name tent standing over his rack
		seats[p].add_child(plate)
		_plates.append(plate)
	_plates[0].visible = false # you are looking out of his eyes
	_deal()


func _process(delta: float) -> void:
	if game == null:
		return
	_show_names()
	if game.phase != OkeyGame.Phase.OVER and game.turn == PLAYER and game.settings.turn_time_limit > 0 \
			and not _stand_in_playing and deal_show == null: # (the clock starts with the first turn, after the deal)
		_time_left -= delta
		if _time_left <= 0.0:
			_play_for_player()
	_update_hud()
	_update_tools()
	_info_timer -= delta
	if _info_timer <= 0.0:
		_info_timer = 0.25
		_update_hints()
		# Once melds are down there is more reason to bend over the table and read them.
		for watcher in watchers:
			watcher.lean_chance = 0.08 if game.melds.is_empty() else 0.2


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if game == null or key == null or not key.pressed or key.echo:
		return
	if deal_show and deal_show.running:
		deal_show.skip()
		return
	if key.keycode in [KEY_H, KEY_F1]:
		hud.toggle_help()
	elif key.keycode == KEY_TAB:
		hud.show_ledger({} if hud.sheet_visible() and game.phase != OkeyGame.Phase.OVER else _ledger_data())
	elif key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if game.phase == OkeyGame.Phase.OVER:
			if end_show and end_show.running:
				end_show.skip()
			elif not game.match_over():
				game.next_hand()
				_deal()
		else:
			_open_from_rack()
	elif key.keycode == KEY_R:
		_arrange("pairs" if _arrange_pairs else "sets")
		_arrange_pairs = not _arrange_pairs
	elif key.keycode in [KEY_F, KEY_C]:
		var target := looked_at_seat()
		if target < 0:
			hud.toast("Kime? Önce ona bak")
		elif key.keycode == KEY_F:
			stealing.accuse(PLAYER, target)
		else:
			stealing.count_check(PLAYER, target)


# A click also skips the deal show (the hand is kept out of it, so the click reaches nobody else).
func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and deal_show and deal_show.running:
		deal_show.skip()
		get_viewport().set_input_as_handled()


## The seat whose head is nearest the middle of the player's view (within ACCUSE_ANGLE), -1 if none or he is
## reading his rack.
func looked_at_seat() -> int:
	var camera := hand.camera
	if camera.mode == FocusCamera.Mode.RACK:
		return -1
	var forward := -camera.global_basis.z
	var best := -1
	var best_angle := ACCUSE_ANGLE
	for p in range(1, OkeyGame.PLAYERS):
		var angle := forward.angle_to(seats[p].head_anchor.global_position - camera.global_position)
		# Looking at his hands or rack counts too.
		angle = minf(angle, forward.angle_to(seats[p].rack.global_position - camera.global_position))
		if angle < best_angle:
			best = p
			best_angle = angle
	return best


## Names appear over the heads of the dayıs you look straight at (not while you read your rack), and fade again.
func _show_names() -> void:
	var camera := hand.camera
	var forward := -camera.global_basis.z
	var reading := camera.mode == FocusCamera.Mode.RACK
	var best := -1
	var best_angle := NAME_ANGLE
	if not reading:
		for p in _plates.size():
			if not _plates[p].visible:
				continue
			var angle := minf(forward.angle_to(seats[p].head_anchor.global_position - camera.global_position),
				forward.angle_to(_plates[p].global_position - camera.global_position))
			if angle < best_angle:
				best = p
				best_angle = angle
	for p in _plates.size():
		_plates[p].looked_at = p == best


## Looking out of this seat's eyes (Main keys 1-4): his own plate is not shown to him.
func set_viewed(seat: int) -> void:
	for p in _plates.size():
		_plates[p].visible = p != seat


func bot(p: int) -> Bot:
	return _bots[p] if p > PLAYER and p < _bots.size() else null


## A tile clicking at a world point (lighter and higher than a tavla checker).
func play_click(at: Vector3, volume_db := 0.0) -> void:
	Sfx.at("tile_click", at, volume_db)


## A new Tile for an id (one that comes back out of the pile).
func make_tile(id: int) -> Tile:
	var tile := TileFactory.of_id(id)
	_tiles[id] = tile
	return tile


## A tile that went into the pile stops being a node until it comes out again.
func forget_tile(tile: Tile) -> void:
	if _tiles.get(tile.id) == tile:
		_tiles.erase(tile.id)
	tile.queue_free()


# --- What the board shows ------------------------------------------------------------------------------------

## Tile ids on a rack, in slot order.
func rack_ids(rack: Rack) -> Array[int]:
	var out: Array[int] = []
	for tile in rack.tiles():
		out.append(tile.id)
	return out


func tile_of(id: int) -> Tile:
	return _tiles.get(id)


## A seat's laid melds as Tile arrays, in the order the rules keep them.
func melds_shown_by(seat: int) -> Array:
	var groups := []
	for meld in game.melds:
		if meld.owner != seat:
			continue
		var group := []
		for id in meld.tiles:
			var tile: Tile = _tiles[id]
			if tile.holder is Rack:
				(tile.holder as Rack).release(tile)
			group.append(tile)
		groups.append(group)
	return groups


## Puts the rules' pile top on the table.
func show_pile() -> void:
	var id := game.pile_top()
	var top: Tile = null
	if id >= 0:
		top = _tiles.get(id)
		if top == null or not is_instance_valid(top):
			top = make_tile(id)
	# A tile that was on top but is now under another (one came back onto the pile) goes back into the stack.
	var old := table.pile_top()
	if old and old != top and old.holder == table:
		table.release(old)
		forget_tile(old)
	table.set_pile(game.pile.size(), top)


func note(text: String, seat := -1) -> void:
	hud.note(text, KahveTheme.SEAT_COLOURS[seat] if seat >= 0 else Color.TRANSPARENT)


## How a seat is called on screen (the player by his profile name).
func name_of(seat: int) -> String:
	return Profile.player_name() if seat == PLAYER else seats[seat].display_name()


## A fresh match from the end-of-match board.
func new_match() -> void:
	game.new_match()
	_deal()


func _deal() -> void:
	if end_show:
		end_show.close()
		end_show = null
	if deal_show:
		deal_show.close()
		deal_show = null
	# A dayı in the middle of something (a theft that outlasted the hand) finishes it first: a tile still in his hand
	# would otherwise live on into the new hand next to its fresh twin.
	while _bots.any(func(b: Bot) -> bool: return b.busy()):
		await get_tree().process_frame
	hud.show_ledger({})
	hand.give_back()
	stealing.new_hand()
	table.clear()
	_tiles.clear()
	_confirm = -1
	var racks := game.deal()
	for p in OkeyGame.PLAYERS:
		seats[p].rack.set_tile_ids(racks[p])
		for tile in seats[p].rack.tiles():
			_tiles[tile.id] = tile
	var shown := TileFactory.of_id(game.indicator)
	_tiles[game.indicator] = shown
	table.show_indicator(shown)
	show_pile()
	_update_totals()
	var okey := OkeyTiles.value(game.indicator)
	Sfx.at("shuffle", table.global_position + Vector3(0, Table.TOP, 0), -2.0)
	note("%d. el. Gösterge %s, okey %s %d" % [game.hand_number + 1, OkeyTiles.name(game.indicator),
		OkeyTiles.colour_name(game.okey.x), game.okey.y])
	if okey == OkeyTiles.FAKE:
		push_warning("gösterge is a sahte okey")
	if DealShow.enabled and Prefs.get_value("deal_show"):
		await _show_deal()
	_begin_turn()


# The tiles fly into the racks while the camera looks on from above; the first turn waits for it. The player's hand
# is kept out of it (a tile grabbed in flight would be lost).
func _show_deal() -> void:
	var hand_mode := hand.process_mode
	hand.process_mode = Node.PROCESS_MODE_DISABLED
	deal_show = DealShow.new()
	deal_show.director = self
	add_child(deal_show)
	await deal_show.run()
	deal_show = null
	hand.process_mode = hand_mode


func _begin_turn() -> void:
	if game.phase == OkeyGame.Phase.OVER:
		return
	_time_left = game.settings.turn_time_limit
	_confirm = -1
	if game.turn != PLAYER:
		_play_bot(game.turn)


func _play_bot(p: int) -> void:
	var hand_number := game.hand_number
	await _bots[p].play_turn()
	if game.hand_number == hand_number:
		_begin_turn()


func _play_for_player() -> void:
	_stand_in_playing = true
	hand.give_back()
	hud.toast("Süren doldu!")
	await _stand_in.play_turn()
	_stand_in_playing = false
	_begin_turn()


## Everything the HUD shows about the game, from the game's state (only what changed is redrawn).
func _update_hud() -> void:
	var over := game.phase == OkeyGame.Phase.OVER
	for p in OkeyGame.PLAYERS:
		_plates[p].set_info(name_of(p), not over and game.turn == p and deal_show == null, KahveTheme.SEAT_COLOURS[p])
	# The banner: your turn with the clock, or whose turn it is (nothing while the tiles are still being dealt).
	if deal_show != null:
		hud.set_turn("")
		hud.set_prompt([])
		return
	if not over and game.turn == PLAYER:
		var clock := "" if game.settings.turn_time_limit <= 0 else "  ·  %d" % ceili(maxf(_time_left, 0.0))
		hud.set_turn("Sıra sende" + clock, KahveTheme.SEAT_COLOURS[PLAYER])
	elif not over:
		hud.set_turn("Sıra: " + name_of(game.turn), KahveTheme.SEAT_COLOURS[game.turn])
	else:
		hud.set_turn("")
	hud.set_prompt(_prompt())


func _update_totals() -> void:
	_update_hud()


## The one line that says what to press now.
func _prompt() -> Array:
	if game.phase == OkeyGame.Phase.OVER:
		return []
	if game.turn != PLAYER:
		return ["Bak", ["Fare"], "|", "Istaka", ["Space"], "|", "Eğil", ["W"], "|", "Yakala", ["F"], "|", "Yardım", ["H"]]
	if game.phase == OkeyGame.Phase.DRAW:
		return ["Çek", ["Sol tık"], "desteden ya da soldakinden", "|", "Istaka", ["Space"]]
	var parts := ["At", ["Çift tık"], "bir taş", "|", "El aç", ["Enter"]]
	if game.settings.auto_arrange_allowed:
		parts.append_array(["|", "Diz", ["R"]])
	return parts


## A seat just laid melds: gold sparks over its area and the sting.
func fx_opened(seat: int) -> void:
	Sfx.ui("sting_open", -4.0 if seat == PLAYER else -9.0)
	var at := table.to_global(Table.seat_basis(seat) * Vector3(0, Table.TOP + 0.03, 0.26))
	Effects.sparkle(table, at, Vector3(0.2, 0.004, 0.07), 36, seat * PI * 0.5 + table.global_rotation.y)


## Someone was caught: the louder it is for the one it concerns (the thief, or the one who called it).
func fx_caught(culprit: int, by: int) -> void:
	var camera := hand.camera
	if culprit == PLAYER:
		camera.shake(0.035, 0.6)
		post_fx.pulse(Color(1.0, 0.12, 0.08), 1.0)
		Effects.slowmo(get_tree(), 0.35, 0.6)
	elif by == PLAYER:
		camera.shake(0.012, 0.3)
		post_fx.pulse(Color(0.2, 1.0, 0.35), 0.9)
		Effects.slowmo(get_tree(), 0.5, 0.4)
	else:
		camera.shake(0.008, 0.25)


# An okey on the rack is worth a moment: sparks on it and a soft chime, for the player only.
func _okey_drawn(tile: Tile) -> void:
	if not OkeyTiles.is_joker(tile.id, game.okey):
		return
	Sfx.ui("sting_open", -13.0)
	Effects.sparkle(table, tile.global_position + Vector3(0, 0.03, 0), Vector3(0.03, 0.004, 0.03), 22, seats[PLAYER].global_rotation.y)
	hud.stamp("Okey geldi!", Color(1.0, 0.82, 0.35))


func _on_penalised(p: int, points: int, reason: String) -> void:
	var above := seats[p].to_global(Vector3(0, Table.TOP + 0.3, 0.1)) if p == PLAYER else seats[p].head_anchor.global_position + Vector3(0, 0.15, 0)
	Effects.float_text(table, above, "%+d" % points, Color(1.0, 0.4, 0.3) if points > 0 else Color(0.5, 1.0, 0.5))
	if p == PLAYER and points > 0:
		post_fx.pulse(Color(0.9, 0.2, 0.1), 0.5)
	var name := name_of(p)
	note("%s: %s (%+d)" % [name, reason, points], p)
	if p == PLAYER:
		hud.flash("%s  %+d" % [reason, points], Color(1.0, 0.35, 0.3))


func _end_hand() -> void:
	hand.give_back()
	var racks := []
	for p in OkeyGame.PLAYERS:
		racks.append(rack_ids(seats[p].rack))
	game.score(racks)
	_update_totals()
	Sfx.ui("sting_win" if game.finisher >= 0 else "sting_deck", -3.0)
	if game.finisher >= 0:
		var who := "Bitirdin!" if game.finisher == PLAYER else "%s bitirdi" % name_of(game.finisher)
		hud.flash(who, Color(0.5, 1.0, 0.5) if game.finisher == PLAYER else Color(1.0, 0.85, 0.4))
	else:
		hud.flash("Deste bitti", Color(1.0, 0.85, 0.4))
	end_show = HandEndShow.new()
	end_show.director = self
	add_child(end_show)
	end_show.run()


## What the ledger (Tab) writes: the standings and every finished hand of the match.
func _ledger_data() -> Dictionary:
	var over := game.phase == OkeyGame.Phase.OVER
	var best: int = game.totals.min()
	var players := []
	for p in OkeyGame.PLAYERS:
		players.append({"name": name_of(p), "colour": KahveTheme.SEAT_COLOURS[p], "total": game.totals[p],
			"lead": not game.history.is_empty() and game.totals[p] == best, "turn": not over and game.turn == p})
	var history := []
	for result: Array in game.history:
		var scores := []
		var notes := []
		for p in OkeyGame.PLAYERS:
			scores.append(result[p].score)
			notes.append(result[p].lines)
		history.append({"scores": scores, "notes": notes})
	var footer := "Tab: kapat"
	if game.match_over():
		var order := range(OkeyGame.PLAYERS)
		order.sort_custom(func(a: int, b: int) -> bool: return game.totals[a] < game.totals[b])
		footer = "Maçı sen kazandın!" if order[0] == PLAYER else "Maçı %s kazandı!" % name_of(order[0])
	elif over:
		footer = "Enter: sonraki el"
	return {"hand": mini(game.hand_number + 1, game.settings.hands_per_match), "hands": game.settings.hands_per_match,
		"players": players, "history": history, "footer": footer}


# --- The player's hand ----------------------------------------------------------------------------------------

# "" if the player may pick this tile up (a legal move, or a theft the house rules allow), else why not.
func _grab_check(tile: Tile) -> String:
	if tile.holder == seats[PLAYER].rack:
		return ""
	if stealing.theft_kind(tile) != "":
		return ""
	if tile.holder is Rack:
		return stealing.refusal(tile)
	if tile.holder != table:
		return ""
	if tile == table.indicator:
		return "Gösterge yerinden oynamaz"
	if tile == table.pile_top():
		return _draw_check()
	var left := OkeyGame.left_of(PLAYER)
	if tile.id == game.top_discard(left) and table.discards(left).has(tile):
		return _draw_check()
	for seat in OkeyGame.PLAYERS:
		if table.discards(seat).has(tile):
			return "Sadece soldakinin attığı son taş alınır"
	for meld in game.melds:
		if meld.tiles.has(tile.id):
			return "Açılmış perler yerinde kalır"
	return ""


func _draw_check() -> String:
	if game.phase == OkeyGame.Phase.OVER:
		return "El bitti"
	if game.turn != PLAYER:
		return "Sıra sende değil"
	if game.phase != OkeyGame.Phase.DRAW:
		return "Taşını çektin, şimdi at"
	if _stand_in_playing:
		return "Süren doldu"
	return ""


# Places the tile itself when the move means something to the rules; false lets the hand do its usual drop.
func _drop_check(tile: Tile, origin: Node, drop: Dictionary) -> bool:
	if stealing.on_drop(tile, origin, drop):
		return true
	var rack := seats[PLAYER].rack
	var to_own_rack: bool = drop.get("rack") == rack
	if origin == table:
		var from_pile := tile.id == game.pile_top()
		var from_left := not from_pile and tile.id == game.top_discard(OkeyGame.left_of(PLAYER))
		if from_pile or from_left:
			var why := "" if not to_own_rack else (game.draw_pile(PLAYER) if from_pile else game.take_discard(PLAYER))
			if to_own_rack and why == "":
				rack.insert(tile, drop.slot)
				show_pile()
				Sfx.at("tile_slide", tile.global_position, -6.0)
				_okey_drawn(tile)
				return true
			if why:
				hud.toast(why)
			if from_pile:
				show_pile()
			else:
				table.put_discard(tile, OkeyGame.left_of(PLAYER))
			return true
		return false
	if origin != rack:
		return false
	var zone: Dictionary = drop.get("zone", {})
	if zone.get("kind") == "discard" and zone.get("seat") == PLAYER:
		_try_discard(tile)
		return true
	if zone.get("kind") == "meld" and _meld_near(drop.point) >= 0:
		_try_extend(tile, _meld_near(drop.point))
		return true
	if drop.is_empty() or zone.get("kind") in ["discard", "pile", "meld"]:
		rack.put(tile, rack.free_slot())
		if zone.get("kind") == "meld":
			hud.toast("Açmak için ıstakada diz ve Enter'a bas")
		return true
	return false


func _drop_hint(tile: Tile, origin: Node, drop: Dictionary) -> String:
	var zone: Dictionary = drop.get("zone", {})
	if origin == seats[PLAYER].rack and zone.get("kind") == "discard" and zone.get("seat") == PLAYER:
		if game.turn != PLAYER or game.phase != OkeyGame.Phase.PLAY:
			return "Atmak için sıranı bekle"
		var costs := game.discard_costs(PLAYER, tile.id, _finishing_with(tile))
		return "Bırak: at" if costs.is_empty() else "Bırak: at (%s, %+d)" % [costs[0][1], costs[0][0]]
	if origin == seats[PLAYER].rack and zone.get("kind") == "meld":
		var index := _meld_near(drop.point)
		if index < 0:
			return "Açmak için ıstakada diz, Enter'a bas"
		if game.opened[PLAYER] == OkeyGame.Opened.NO:
			return "İşlemek için önce açmalısın"
		var meld := game.melds[index]
		if game.settings.okey_swap_from_table and meld.joker_for(tile.id, game.okey) >= 0:
			return "Bırak: okeyi al"
		if meld.kind != Meld.Kind.PAIR and meld.extend_side(tile.id, game.okey, game.settings.run_wraps_13_1) >= 0:
			return "Bırak: işle"
		return "Bu pere uymuyor"
	if origin == table and zone.get("kind") != "felt":
		return "Istakana götür"
	return ""


# --- Opening and işleme -----------------------------------------------------------------------------------------

## The laid meld with a tile nearest to a point on the felt (within MELD_PICK), or -1.
func _meld_near(point: Vector3) -> int:
	var best := -1
	var best_distance := MELD_PICK
	for i in game.melds.size():
		for id in game.melds[i].tiles:
			var tile: Tile = _tiles.get(id)
			if tile == null:
				continue
			var d := Vector2(tile.global_position.x - point.x, tile.global_position.z - point.z).length()
			if d < best_distance:
				best = i
				best_distance = d
	return best


# The player's rack groups that are valid melds: {groups: id arrays, points, pairs: bool}. Pairs only when every
# valid group is a pair and he has not opened with sets.
func _valid_groups() -> Dictionary:
	var wrap := game.settings.run_wraps_13_1
	var sets := []
	var pairs := []
	var points := 0
	for group: Array in seats[PLAYER].rack.groups():
		var ids: Array[int] = []
		for tile: Tile in group:
			ids.append(tile.id)
		if ids.size() == 2:
			if Meld.make(ids, game.okey, wrap, true):
				pairs.append(ids)
		else:
			var meld := Meld.make(ids, game.okey, wrap)
			if meld:
				sets.append(ids)
				points += meld.points()
	var opened: int = game.opened[PLAYER]
	if opened == OkeyGame.Opened.PAIRS or (opened == OkeyGame.Opened.NO and sets.is_empty() and not pairs.is_empty()):
		return {"groups": pairs, "points": 0, "pairs": true}
	return {"groups": sets, "points": points, "pairs": false}


# The opening bar over the rack ("Açılış 87 / 101"), when counting is on and he has not opened yet.
func _update_opening() -> void:
	var rules := game.settings
	var show := hand.camera.mode == FocusCamera.Mode.RACK and rules.group_hints and game.phase != OkeyGame.Phase.OVER \
		and game.opened[PLAYER] == OkeyGame.Opened.NO and not hand.held
	if not show:
		hud.set_opening(false)
		return
	var valid := _valid_groups()
	var need := game.opening_needed()
	if valid.pairs:
		hud.set_opening(true, valid.groups.size(), need.pairs, "Çift %d / %d" % [valid.groups.size(), need.pairs])
	else:
		hud.set_opening(true, valid.points, need.points, "Açılış %d / %d" % [valid.points, need.points])


func _open_from_rack() -> void:
	if game.turn != PLAYER or game.phase != OkeyGame.Phase.PLAY:
		hud.toast("Sıra sende değil" if game.turn != PLAYER else "Önce taş çek")
		return
	var valid := _valid_groups()
	if valid.groups.is_empty():
		hud.toast("Istakada geçerli per yok: grupların arasında bir boşluk bırak")
		return
	var laid := 0
	for group: Array in valid.groups:
		laid += group.size()
	if laid >= seats[PLAYER].rack.tiles().size():
		hud.toast("Atmak için bir taş bırakmalısın")
		return
	var first: bool = game.opened[PLAYER] == OkeyGame.Opened.NO
	var why := game.open(PLAYER, valid.groups)
	if why:
		hud.toast(why)
		return
	table.lay_melds(PLAYER, melds_shown_by(PLAYER), 0.3)
	if first:
		hud.stamp("El açtın!", Color(0.5, 0.95, 0.6))
	fx_opened(PLAYER)
	var amount := "%d çift" % valid.groups.size() if valid.pairs else str(valid.points)
	note("Sen el açtın (%s)" % amount if first else "Sen %d taş indirdin" % laid)
	_update_totals()


func _try_extend(tile: Tile, index: int) -> void:
	var rack := seats[PLAYER].rack
	var meld := game.melds[index]
	var why := ""
	var swapping := game.settings.okey_swap_from_table and meld.joker_for(tile.id, game.okey) >= 0
	if not swapping and rack.tiles().is_empty():
		why = "Son taşını atmalısın"
	else:
		why = game.swap_okey(PLAYER, index, tile.id) if swapping else game.extend(PLAYER, index, tile.id)
	if why:
		hud.toast(why)
		_return_home(tile)
		return
	if swapping:
		var joker: Tile = _tiles[game.taken]
		table.release(joker)
		rack.put(joker, rack.free_slot(), true, 0.3)
		note("Okeyi aldın")
	table.lay_melds(meld.owner, melds_shown_by(meld.owner), 0.2)


# Lays the rack out: "sets" (the best pers and seris, then the rest), "pairs", "color" (a group per colour, okeys
# first) or "number" (a group per number).
func _arrange(how: String) -> void:
	if not game.settings.auto_arrange_allowed:
		hud.toast("Bu masada otomatik dizmek yok")
		return
	if hand.held:
		return
	var rack := seats[PLAYER].rack
	var ids := rack_ids(rack)
	var wrap := game.settings.run_wraps_13_1
	var groups := []
	var rest: Array = []
	match how:
		"sets", "pairs":
			var plan := Solver.pairs(ids, game.okey) if how == "pairs" else Solver.best(ids, game.okey, wrap)
			for group: Array in plan.groups:
				var ordered: Array[int] = []
				ordered.assign(group)
				var meld := Meld.make(ordered, game.okey, wrap, group.size() == 2)
				groups.append((meld.tiles if meld else ordered).map(func(id: int) -> Tile: return _tiles[id]))
			rest = plan.left.map(func(id: int) -> Tile: return _tiles[id])
		"color":
			var jokers := []
			var by_colour := {}
			for id in ids:
				if OkeyTiles.is_joker(id, game.okey) or OkeyTiles.value(id) == OkeyTiles.FAKE:
					jokers.append(_tiles[id])
				else:
					by_colour.get_or_add(OkeyTiles.value(id).x, []).append(_tiles[id])
			if not jokers.is_empty():
				groups.append(jokers)
			for colour in range(TileFactory.COLORS):
				if by_colour.has(colour):
					groups.append(by_colour[colour])
		"number":
			var by_number := {}
			var jokers := []
			for id in ids:
				if OkeyTiles.is_joker(id, game.okey) or OkeyTiles.value(id) == OkeyTiles.FAKE:
					jokers.append(_tiles[id])
				else:
					by_number.get_or_add(OkeyTiles.value(id).y, []).append(_tiles[id])
			if not jokers.is_empty():
				groups.append(jokers)
			for number in range(1, TileFactory.NUMBERS + 1):
				if by_number.has(number):
					groups.append(by_number[number])
	if how in ["color", "number"]:
		for group: Array in groups:
			group.sort_custom(func(a: Tile, b: Tile) -> bool: return a.value.x < b.value.x or (a.value.x == b.value.x and a.value.y < b.value.y))
	rest.sort_custom(func(a: Tile, b: Tile) -> bool: return a.value.x < b.value.x or (a.value.x == b.value.x and a.value.y < b.value.y))
	hand.clear_selection()
	rack.arrange(groups, rest)
	Sfx.at("tile_slide", rack.global_position + Vector3(0, 0.1, 0), -8.0)


func _on_tool(id: String) -> void:
	if id == "open":
		_open_from_rack()
	else:
		_arrange(id)


# --- Quick ways ----------------------------------------------------------------------------------------------------

# A quick click on the pile or the left discard draws it (when drawing is allowed), instead of dragging it over.
func _quick_click(tile: Tile, origin: Node) -> bool:
	if origin != table or _draw_check() != "":
		return false
	var from_pile := tile.id == game.pile_top() # (the hand already took it off the pile, so compare by id)
	var from_left := not from_pile and tile.id == game.top_discard(OkeyGame.left_of(PLAYER))
	if not (from_pile or from_left):
		return false
	var rack := seats[PLAYER].rack
	var slot := rack.free_slot()
	if slot < 0:
		return false
	if (game.draw_pile(PLAYER) if from_pile else game.take_discard(PLAYER)) != "":
		return false
	hand.take_held()
	rack.put(tile, slot, true, 0.25)
	show_pile()
	Sfx.at("tile_slide", tile.global_position, -6.0)
	_okey_drawn(tile)
	return true


# Double-click on a tile of the rack throws it (the hand has already let go of it).
func _throw_click(tile: Tile) -> void:
	_try_discard(tile)


func _hover_hint(tile: Tile) -> String:
	if tile.holder != table or _draw_check() != "":
		return ""
	if tile == table.pile_top() or tile.id == game.top_discard(OkeyGame.left_of(PLAYER)):
		return "Tıkla: taşı çek"
	return ""


# The buttons while he reads his rack (if the room has them).
func _update_tools() -> void:
	var rules := game.settings
	var show := hand.camera.mode == FocusCamera.Mode.RACK and game.phase != OkeyGame.Phase.OVER and not hand.held
	var ids := []
	if show and rules.auto_arrange_allowed:
		ids.append_array(["sets", "pairs", "color", "number"])
	if show and rules.group_hints and game.turn == PLAYER and game.phase == OkeyGame.Phase.PLAY and _can_open_now():
		ids.append("open")
	hud.show_tools(ids)
	_update_opening()
	_update_opening()


# Does what is grouped on his rack open the hand (or add to it) right now?
func _can_open_now() -> bool:
	var valid := _valid_groups()
	if valid.groups.is_empty():
		return false
	var laid := 0
	for group: Array in valid.groups:
		laid += group.size()
	if laid >= seats[PLAYER].rack.tiles().size():
		return false # he must keep a tile to discard
	if game.opened[PLAYER] != OkeyGame.Opened.NO:
		return true
	var need := game.opening_needed()
	return valid.groups.size() >= need.pairs if valid.pairs else valid.points >= need.points


# Strips under the groups on the rack: green for a valid per or seri (with its points), blue for a pair, red for a
# group that is not one.
func _update_hints() -> void:
	var rack := seats[PLAYER].rack
	if not game.settings.group_hints or game.phase == OkeyGame.Phase.OVER or hand.held:
		if not hand.held:
			rack.show_hints([])
		return
	var wrap := game.settings.run_wraps_13_1
	var hints := []
	for group: Array in rack.groups():
		if group.size() < 2:
			continue
		var ids: Array[int] = []
		for tile: Tile in group:
			ids.append(tile.id)
		var meld := Meld.make(ids, game.okey, wrap, group.size() == 2)
		if group.size() == 2:
			hints.append({"tiles": group, "color": Color(0.35, 0.65, 1.0) if meld else Color(0.95, 0.25, 0.2),
				"text": "çift" if meld else ""})
		elif meld:
			hints.append({"tiles": group, "color": Color(0.3, 0.9, 0.4), "text": str(meld.points())})
		else:
			hints.append({"tiles": group, "color": Color(0.95, 0.25, 0.2), "text": ""})
	rack.show_hints(hints)


func _finishing_with(tile: Tile) -> bool:
	var left := seats[PLAYER].rack.tiles()
	left.erase(tile)
	return left.is_empty() and game.opened[PLAYER] != OkeyGame.Opened.NO


# A tile the player took out of his rack and may not (or did not) discard goes back to the slot it came from.
func _return_home(tile: Tile) -> void:
	var rack := seats[PLAYER].rack
	var home := hand.origin_slot()
	rack.put(tile, home if home >= 0 and rack.tile_at(home) == null else rack.free_slot())


func _try_discard(tile: Tile) -> void:
	var rack := seats[PLAYER].rack
	var why := ""
	if game.turn != PLAYER:
		why = "Sıra sende değil"
	elif game.phase != OkeyGame.Phase.PLAY:
		why = "Önce taş çek"
	if why:
		hud.toast(why)
		_return_home(tile)
		return
	var costs := game.discard_costs(PLAYER, tile.id, _finishing_with(tile))
	if not costs.is_empty() and _confirm != tile.id:
		_confirm = tile.id
		hud.toast("%s: %+d ceza. Yine de atmak için tekrar at" % [costs[0][1], costs[0][0]])
		_return_home(tile)
		return
	table.put_discard(tile, PLAYER)
	game.discard(PLAYER, tile.id, rack_ids(rack))
	_begin_turn()
