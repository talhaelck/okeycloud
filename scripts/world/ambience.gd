class_name Ambience
extends Node3D
## The kahvehane's sound, placed where it comes from (sounds from tools/make_sounds.py, assets/audio/): rain on the
## windows and the door, the stove crackling, the wall clock, the match on the TV, talk at the other tables, and
## now and then a spoon on a tea glass or tavla dice and checkers. Everything goes through a "Room" bus with a
## little reverb, so it sounds like one small room.

const AUDIO := "res://assets/audio/"
const BUS := "Room"

var _spots: Dictionary = {} # kind -> Array of positions for the one-shots


func _ready() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, BUS)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.35
		reverb.damping = 0.6
		reverb.wet = 0.18
		reverb.dry = 0.9
		AudioServer.add_bus_effect(bus, reverb)


## A looping sound at `pos`; `volume_db` sets how loud it is up close, `reach` how far it carries.
func loop(sound: String, pos: Vector3, volume_db := 0.0, reach := 3.0) -> AudioStreamPlayer3D:
	var stream: AudioStreamWAV = load(AUDIO + sound + ".wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2 # 16-bit mono samples
	var player := _player(stream, pos, volume_db, reach)
	player.play(randf() * stream.get_length())
	return player


## Remembers places where a kind of one-shot happens ("spoon", "dice", "checker").
func add_spot(kind: String, pos: Vector3) -> void:
	if not _spots.has(kind):
		_spots[kind] = []
	_spots[kind].append(pos)


## Plays one of `sounds` at `pos` once.
func play_at(sounds: Array, pos: Vector3, volume_db := 0.0, reach := 2.5) -> void:
	var player := _player(load(AUDIO + str(sounds.pick_random()) + ".wav"), pos, volume_db, reach)
	player.pitch_scale = randf_range(0.92, 1.08)
	player.play()
	player.finished.connect(player.queue_free)


## Starts the one-shots: spoons clink every few seconds somewhere, tavla tables roll dice and move checkers.
func start() -> void:
	_every("spoon", ["spoon_0", "spoon_1", "spoon_2"], 3.0, 9.0, -14.0)
	_every("dice", ["dice"], 6.0, 14.0, -12.0, true)


func _every(kind: String, sounds: Array, low: float, high: float, volume_db: float, then_checkers := false) -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(low, high)).timeout
		if not _spots.has(kind):
			continue
		var at: Vector3 = _spots[kind].pick_random()
		play_at(sounds, at, volume_db)
		if then_checkers:
			# After the roll the player moves two checkers.
			for i in 2:
				await get_tree().create_timer(randf_range(0.6, 1.4)).timeout
				play_at(["checker_0", "checker_1", "checker_2"], at, volume_db + 2.0)


func _player(stream: AudioStream, pos: Vector3, volume_db: float, reach: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = pos
	player.volume_db = volume_db
	player.unit_size = reach
	player.max_db = volume_db + 3.0
	player.attenuation_filter_cutoff_hz = 6000.0
	player.bus = BUS
	add_child(player)
	return player
