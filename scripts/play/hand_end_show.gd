class_name HandEndShow
extends Node
## The end of a hand as a small show instead of a sheet of paper:
##  1. the camera leaves the player's eyes in an arc and turns to whoever finished (or rises over the table when the
##     pile ran out) while the sting plays;
##  2. every rack falls forward onto the felt, tiles face up, one after another;
##  3. the camera settles over the table so all four racks and every laid meld are in view;
##  4. the chalkboard on the right writes itself: each player's hand score counting up with the reasons under it
##     (tiles left, penalties, doubled), then the match totals, with the lowest in brass;
##  5. "Enter: sonraki el" (or, after the last hand, the winner and Yeni maç / Ana menü).
## Enter while it runs skips to the end. close() puts everything back for the next deal.

signal finished

## The overview, relative to the table: high and steep, and slid to one side so that the table sits in the left part
## of the picture, clear of the chalkboard on the right.
const OVERVIEW_EYE := Vector3(0.3, 2.05, 0.7)
const OVERVIEW_LOOK := Vector3(0.3, 0.76, 0.0)

var director: GameDirector
var running := false

var _skipped := false


## Jumps to the end of the show (Enter).
func skip() -> void:
	_skipped = true


func run() -> void:
	running = true
	var d := director
	var game := d.game
	var camera := d.hand.camera
	d.hand.give_back()
	camera.cine_transform = camera.global_transform # keep what the player sees, then take over from there
	camera.cine_blend = 1.0

	var finisher := game.finisher
	if finisher > 0:
		await _fly(camera.cine_transform, _face_pose(finisher), 1.3)
	elif finisher == 0:
		await _fly(camera.cine_transform, _overview_pose(), 1.1)
	else:
		await _fly(camera.cine_transform, _overview_pose(), 1.2)
	await _wait(0.5)

	for seat in d.seats:
		seat.rack.tip_over(0.0 if _skipped else 0.75)
		await _wait(0.2)
	await _wait(0.6)
	await _fly(camera.cine_transform, _overview_pose(), 1.1)
	await _write_board()
	running = false
	finished.emit()


## Everything back for the next deal: racks upright, the board away, the camera back into the player's eyes.
func close() -> void:
	_skipped = true
	for seat in director.seats:
		seat.rack.stand_up()
	director.hud.board_close()
	var camera := director.hand.camera
	if camera.cine_blend > 0.0:
		var tween := camera.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, "cine_blend", 0.0, 0.8)
	if camera.mouse_control and not camera.focused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


# --- Camera poses ---------------------------------------------------------------------------------------------------

# Across the table from the one who finished, a little above him, looking at his face.
func _face_pose(seat: int) -> Transform3D:
	var head := director.seats[seat].head_anchor.global_position
	var centre := director.table.global_position
	var away := Vector3(centre.x - head.x, 0.0, centre.z - head.z).normalized()
	var from := head + away * 1.25 + Vector3(0, 0.2, 0)
	return Transform3D(Basis.looking_at(head + Vector3(0, -0.08, 0) - from, Vector3.UP), from)


func _overview_pose() -> Transform3D:
	var table := director.table.global_position
	var from := table + OVERVIEW_EYE
	return Transform3D(Basis.looking_at(table + OVERVIEW_LOOK - from, Vector3.UP), from)


# An arc, not a straight line: rises a little in the middle, and eases in and out.
func _fly(from: Transform3D, to: Transform3D, seconds: float) -> void:
	var camera := director.hand.camera
	var elapsed := 0.0
	while elapsed < seconds and not _skipped:
		var v := smoothstep(0.0, 1.0, elapsed / seconds)
		var pose := from.interpolate_with(to, v)
		pose.origin += Vector3.UP * sin(PI * v) * 0.18
		camera.cine_transform = pose
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	camera.cine_transform = to


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not _skipped:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


# --- The chalkboard ---------------------------------------------------------------------------------------------------

func _write_board() -> void:
	var d := director
	var game := d.game
	var hud := d.hud
	var last: Array = game.history.back()
	hud.board_open("%d. el" % game.history.size())
	await _wait(0.3)
	var best := 0
	for p in OkeyGame.PLAYERS:
		if last[p].score < last[best].score:
			best = p
	for p in OkeyGame.PLAYERS:
		var header := hud.board_row(d.name_of(p), "", 25, KahveTheme.BRASS_BRIGHT if p == best else HudChalk.WHITE)
		_appear(header.row)
		await _count(header.right, last[p].score)
		for line: Array in last[p].lines:
			var row := hud.board_row(line[0], "%+d" % line[1], 16, HudChalk.DIM, 16.0)
			_appear(row.row)
			await _wait(0.2)
		await _wait(0.15)

	var rule := hud.board_row("────────────────────────────", "", 14, HudChalk.DIM)
	_appear(rule.row)
	var heading := hud.board_row("Toplam", "", 22, KahveTheme.BRASS_BRIGHT)
	_appear(heading.row)
	var order := range(OkeyGame.PLAYERS)
	order.sort_custom(func(a: int, b: int) -> bool: return game.totals[a] < game.totals[b])
	for rank in order.size():
		var p: int = order[rank]
		var row := hud.board_row(d.name_of(p), str(game.totals[p]), 20, KahveTheme.BRASS_BRIGHT if rank == 0 else HudChalk.WHITE, 8.0)
		_appear(row.row)
		await _wait(0.2)
	await _wait(0.2)
	if game.match_over():
		var winner: int = order[0]
		var text := "Maçı sen kazandın!" if winner == d.PLAYER else "Maçı %s kazandı!" % d.name_of(winner)
		var end := hud.board_row(text, "", 24, KahveTheme.BRASS_BRIGHT)
		_appear(end.row)
		hud.board_buttons([["Yeni maç", d.new_match], ["Ana menü", func() -> void: d.menu_requested.emit()]])
	else:
		_appear(hud.board_row("Enter: sonraki el", "", 18, HudChalk.DIM).row)


# A row fades in with a chalk scratch.
func _appear(row: Control) -> void:
	Sfx.ui("chalk", -7.0)
	if _skipped:
		return
	row.modulate.a = 0.0
	row.create_tween().tween_property(row, "modulate:a", 1.0, 0.25)


# A figure counts up to its value.
func _count(label: Label, value: int) -> void:
	var elapsed := 0.0
	var seconds := 0.0 if _skipped else clampf(absf(value) / 250.0, 0.4, 0.9)
	while elapsed < seconds and not _skipped:
		label.text = "%+d" % int(lerpf(0.0, value, ease(elapsed / seconds, -2.0)))
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	label.text = "%+d" % value
	await _wait(0.1)


## The chalk colours, kept where the show and the board agree on them.
class HudChalk:
	const WHITE := Color(0.92, 0.96, 0.9)
	const DIM := Color(0.72, 0.8, 0.74)
