class_name Profile
## What the game remembers about the player between runs (user://profile.json): for now his name, which is what the
## score sign, the name plate and the chalkboard call him. Online it will be what the others see.

const PATH := "user://profile.json"
const DEFAULT_NAME := "Oyuncu"
const MAX_LENGTH := 14

static var _name := ""
static var _loaded := false


static func player_name() -> String:
	_load()
	return _name if _name != "" else DEFAULT_NAME


## Keeps a new name (trimmed, at most MAX_LENGTH letters; empty goes back to the default).
static func set_player_name(value: String) -> void:
	_load()
	_name = value.strip_edges().substr(0, MAX_LENGTH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"name": _name}))


## Forgets what was loaded, so the next read goes to the file again (tests).
static func reload() -> void:
	_loaded = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_name = ""
	if FileAccess.file_exists(PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary:
			_name = str(data.get("name", "")).strip_edges().substr(0, MAX_LENGTH)
