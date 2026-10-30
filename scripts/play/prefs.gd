class_name Prefs
## The player's own settings (not the house rules): sound, picture and the shows. Kept in user://prefs.json and
## applied to the window, the audio buses and the post FX by apply(). Everything has a default, so a missing or
## broken file is simply the default game. Tests use `reload()` and `PATH` to start from nothing.

const PATH := "user://prefs.json"

## key -> [Turkish title, explanation, default, kind ("switch" | [min, max, step, suffix] | ["choice", ...])]
const ROWS := {
	"master_volume": ["Ses", "Her şeyin sesi.", 80, [0, 100, 5, "%"]],
	"effects_volume": ["Oyun sesleri", "Taşlar, düğmeler, ıstaka, tebeşir.", 100, [0, 100, 5, "%"]],
	"room_volume": ["Kahvehane", "Yağmur, soba, saat, televizyon, mırıltı.", 100, [0, 100, 5, "%"]],
	"fullscreen": ["Tam ekran", "Oyun bütün ekranı kaplar (F11 de yapar).", false, "switch"],
	"vsync": ["Dikey eşitleme", "Görüntü ekranın hızına bağlanır; yırtılma olmaz.", true, "switch"],
	"render_scale": ["Çözünürlük", "Üç boyutlu görüntünün ölçeği. Düşük: daha hızlı, daha bulanık.", 100, [50, 100, 10, "%"]],
	"grain": ["Film tanesi", "Görüntünün üstündeki ince kumlanma.", true, "switch"],
	"intro": ["Açılış filmi", "Oyun açılınca kahvehaneye giriş. Herhangi bir tuş atlar.", true, "switch"],
	"deal_show": ["Dağıtım gösterisi", "Her elin başında taşlar dağıtılırken masanın üstünden bak.", true, "switch"],
}
const GROUPS := [["Ses", ["master_volume", "effects_volume", "room_volume"]],
	["Görüntü", ["fullscreen", "vsync", "render_scale", "grain"]], ["Gösteriler", ["intro", "deal_show"]]]

static var _values := {}
static var _loaded := false


static func get_value(key: String) -> Variant:
	_load()
	return _values.get(key, ROWS[key][2])


static func default_of(key: String) -> Variant:
	return ROWS[key][2]


## Changes one setting, applies it and writes the file.
static func set_value(key: String, value: Variant) -> void:
	_load()
	_values[key] = value
	apply(key)
	save()


static func is_default(key: String) -> bool:
	return get_value(key) == default_of(key)


static func reset_all() -> void:
	_load()
	_values.clear()
	apply()
	save()


## Puts the settings into effect: `key` alone, or everything.
static func apply(key := "") -> void:
	_load()
	_ensure_game_bus()
	for k: String in ROWS:
		if key != "" and k != key:
			continue
		match k:
			"master_volume":
				_set_bus("Master", get_value(k))
			"effects_volume":
				_set_bus(Sfx.BUS, get_value(k))
			"room_volume":
				_set_bus(Ambience.BUS, get_value(k))
			"fullscreen":
				if DisplayServer.get_name() != "headless":
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if get_value(k) else DisplayServer.WINDOW_MODE_WINDOWED)
			"vsync":
				if DisplayServer.get_name() != "headless":
					DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value(k) else DisplayServer.VSYNC_DISABLED)
			"render_scale":
				var tree := Engine.get_main_loop() as SceneTree
				if tree and tree.root:
					tree.root.scaling_3d_scale = float(get_value(k)) / 100.0
			"grain":
				PostFx.grain_enabled = get_value(k)


# The game's own sounds (Sfx) get a bus of their own, sent on to the room's reverb bus, so that they and the
# kahvehane can be turned up and down apart.
static func _ensure_game_bus() -> void:
	if AudioServer.get_bus_index(Sfx.BUS) >= 0:
		return
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, Sfx.BUS)
	if AudioServer.get_bus_index(Ambience.BUS) >= 0:
		AudioServer.set_bus_send(bus, Ambience.BUS)


static func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_values))


## Forgets what was loaded, so the next read goes to the file again (tests).
static func reload() -> void:
	_loaded = false


static func _set_bus(bus: StringName, percent: Variant) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var amount := clampf(float(percent) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(amount) if amount > 0.0 else -80.0)
	AudioServer.set_bus_mute(index, amount <= 0.0)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_values = {}
	if FileAccess.file_exists(PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary:
			for k: String in data:
				if ROWS.has(k) and typeof(data[k]) in [typeof(ROWS[k][2]), TYPE_FLOAT, TYPE_INT]:
					var v: Variant = data[k]
					_values[k] = v if ROWS[k][2] is bool else int(v)
