extends Node
## What the game starts with (project main scene): the table with the main menu over it. `godot --path . -- --play`
## (or --screenshot=..., --preset=..., --set=...) skips the menu and deals at once; `--menu` forces it.


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.show_menu = _wants_menu()
	add_child(main)


static func _wants_menu() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--menu"):
		return true
	for arg in args:
		if arg == "--play" or arg.begins_with("--screenshot") or arg.begins_with("--preset") or arg.begins_with("--set="):
			return false
	return true
