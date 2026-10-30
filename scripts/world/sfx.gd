class_name Sfx
## The game's sound effects (assets/audio/, made by tools/make_sounds.py), played from anywhere:
##   Sfx.at("tile_rack", point)   in the room, so a click on the left is heard on the left
##   Sfx.ui("ui_click")           flat, for menus and stings
## A kind is a file name without ".wav"; if there are numbered variants (tile_click_0.wav, tile_click_1.wav ...) one
## is picked at random and the pitch varies a little, so no two clicks sound the same. At most MAX_PLAYING sounds
## play at once. `played` counts every sound by kind (tests read it, since nobody can listen to a headless run).

const AUDIO := "res://assets/audio/"
const BUS := &"Room"
const MAX_PLAYING := 16

static var played := {}
static var _streams := {}
static var _holder: Node
static var _playing := 0


## Plays a sound at a world point. `delay` waits that long first (a tile that lands after its slide).
static func at(kind: String, point: Vector3, volume_db := 0.0, delay := 0.0, tries := 0) -> void:
	if delay > 0.0:
		_later(delay, func() -> void: at(kind, point, volume_db))
		return
	if not _ensure_holder():
		if tries < 5:
			_later(0.1, func() -> void: at(kind, point, volume_db, 0.0, tries + 1)) # the very first sound of a run
		return
	var player := AudioStreamPlayer3D.new()
	player.unit_size = 1.4
	player.max_distance = 9.0
	if _start(player, kind, volume_db):
		player.global_position = point


## Plays a sound with no place (menus, stings).
static func ui(kind: String, volume_db := 0.0, tries := 0) -> void:
	if not _ensure_holder():
		if tries < 5:
			_later(0.1, func() -> void: ui(kind, volume_db, tries + 1))
		return
	_start(AudioStreamPlayer.new(), kind, volume_db)


static func reset_counts() -> void:
	played.clear()


static func count(kind: String) -> int:
	return played.get(kind, 0)


static func _start(player: Node, kind: String, volume_db: float) -> bool:
	var stream := _stream(kind)
	if stream == null or _playing >= MAX_PLAYING or not _ensure_holder():
		player.free()
		return false
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.94, 1.06)
	player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	_holder.add_child(player)
	_playing += 1
	played[kind] = count(kind) + 1
	player.finished.connect(func() -> void:
		_playing -= 1
		player.queue_free())
	player.play()
	return true


# One of the kind's variants (or the file itself), loaded once.
static func _stream(kind: String) -> AudioStream:
	if not _streams.has(kind):
		var variants: Array[AudioStream] = []
		var single := AUDIO + kind + ".wav"
		if ResourceLoader.exists(single):
			variants.append(load(single))
		var i := 0
		while ResourceLoader.exists(AUDIO + "%s_%d.wav" % [kind, i]):
			variants.append(load(AUDIO + "%s_%d.wav" % [kind, i]))
			i += 1
		_streams[kind] = variants
	var list: Array = _streams[kind]
	return null if list.is_empty() else list.pick_random()


static func _ensure_holder() -> bool:
	if is_instance_valid(_holder):
		return _holder.is_inside_tree()
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return false
	_holder = Node.new()
	_holder.name = "Sfx"
	_holder.process_mode = Node.PROCESS_MODE_ALWAYS # menu sounds play while the game is paused
	loop.root.add_child.call_deferred(_holder)
	_playing = 0
	return false # the holder joins the tree next frame; this one sound is dropped (only at the very first call)


static func _later(seconds: float, call: Callable) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	if loop:
		loop.create_timer(seconds).timeout.connect(call)
