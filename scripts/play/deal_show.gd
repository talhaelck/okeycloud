class_name DealShow
extends Node
## The start of a hand as a short show: the camera rises out of the player's eyes over the table, the tiles fly from
## the pile into the four racks one after another with their clicks, the gösterge turns face up beside the pile and a
## stamp names the okey, then the camera sinks back into the player's eyes and the first turn begins. GameDirector
## holds the first turn until `run()` is over, so nobody plays while the tiles are still in the air. Any key or click
## skips: the tiles are home at once and the camera comes straight back. Off headless (`enabled`, as Effects) and when
## the player switched it off (Prefs "deal_show"); tests switch it on to run it for real.

signal finished

static var enabled := DisplayServer.get_name() != "headless"

const EYE := Vector3(0.0, 1.92, 1.2) # the overview, relative to the table (under the lamp, not in it)
const LOOK := Vector3(0.0, 0.75, -0.15)
const TILE_GAP := 0.028 # seconds between two tiles leaving the pile
const FLIGHT := 0.32 # seconds a tile is in the air

var director: GameDirector
var running := false

var _skipped := false
var _flights: Array = [] # [tile, home transform, its rack's position] for every tile still to fly or in flight


func skip() -> void:
	_skipped = true


func run() -> void:
	running = true
	var d := director
	var camera := d.hand.camera
	var table := d.table
	var indicator := table.indicator
	var shown := indicator.transform
	# Everything starts on the pile, face down.
	var pile := table.global_position + Vector3(0, Table.TOP + 0.02, 0)
	var order: Array[int] = [1, 2, 3, 0]
	for p in order:
		for tile in d.seats[p].rack.tiles():
			_flights.append([tile, tile.transform, d.seats[p].rack.global_position])
			tile.global_transform = Transform3D(Basis(Vector3.UP, randf_range(-0.2, 0.2)) * Table.FACE_DOWN, pile + Vector3(0, 0.001 * _flights.size(), 0))
	indicator.transform = Transform3D(Basis(Vector3.UP, 0.25) * Table.FACE_DOWN, shown.origin)
	await get_tree().process_frame # (from the menu the camera is still on its way into the player's eyes)
	if _skipped:
		_land_all()
		indicator.transform = shown
		running = false
		finished.emit()
		queue_free()
		return
	camera.cine_transform = camera.global_transform
	camera.cine_blend = 1.0

	var from := camera.cine_transform
	var over := _overview_pose()
	await _fly(from, over, 1.0)
	# The deal: one tile after another, each sliding home with a click as it seats.
	var index := 0
	while index < _flights.size() and not _skipped:
		var entry: Array = _flights[index]
		var tile: Tile = entry[0]
		if is_instance_valid(tile):
			tile.slide_to(entry[1], FLIGHT)
			Sfx.at("tile_rack", entry[2], -14.0, FLIGHT)
		index += 1
		await _wait(TILE_GAP)
	_land_all()
	await _wait(0.35)
	# The gösterge turns over.
	if not _skipped:
		var flip := indicator.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var lifted := shown
		lifted.origin.y += 0.04
		flip.tween_method(func(t: float) -> void:
			indicator.transform = Transform3D(Basis(Vector3.UP, 0.25) * Table.FACE_DOWN.slerp(Table.FACE_UP, t),
				shown.origin + Vector3(0, sin(PI * t) * 0.05, 0)), 0.0, 1.0, 0.45)
		Sfx.at("tile_felt", indicator.global_position, -4.0, 0.45)
		await _wait(0.5)
	indicator.transform = shown
	if not _skipped:
		var okey := d.game.okey
		d.hud.stamp("Okey: %s %d" % [OkeyTiles.colour_name(okey.x), okey.y], KahveTheme.BRASS_BRIGHT)
		await _wait(1.1)
	await _fly(camera.cine_transform, from, 0.0 if _skipped else 0.9)
	camera.cine_blend = 0.0
	running = false
	finished.emit()
	queue_free()


## Everything in its place at once (a skipped show, or the hand ending under it).
func close() -> void:
	_skipped = true
	_land_all()
	if director and director.hand and director.hand.camera:
		director.hand.camera.cine_blend = 0.0
	running = false


func _land_all() -> void:
	for entry: Array in _flights:
		var tile: Tile = entry[0]
		if is_instance_valid(tile):
			tile.stop_sliding()
			tile.transform = entry[1]
	_flights.clear()


func _overview_pose() -> Transform3D:
	var table := director.table.global_position
	var from := table + EYE
	return Transform3D(Basis.looking_at(table + LOOK - from, Vector3.UP), from)


func _fly(from: Transform3D, to: Transform3D, seconds: float) -> void:
	var camera := director.hand.camera
	var elapsed := 0.0
	while elapsed < seconds and not _skipped:
		var v := smoothstep(0.0, 1.0, elapsed / seconds)
		camera.cine_transform = from.interpolate_with(to, v)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	camera.cine_transform = to


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not _skipped:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
