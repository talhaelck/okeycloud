extends SceneTree
## Every UI part on one screen, to judge the look as a whole (windowed):
##   godot --path . --script tests/ui_gallery.gd -- <out prefix> [WIDTHxHEIGHT ...]
## Saves <prefix>_<WIDTHxHEIGHT>.png for each size (default 1280x720 and 1920x1080), so scaling is checked too.

const PANGRAM := "Pijamalı hasta yağız şoföre çabucak güvendi. ĞÜŞİÖÇ ığüşöç"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if not args.is_empty() else "screenshots/gallery"
	var sizes: Array[String] = []
	for arg in args.slice(1):
		sizes.append(arg)
	if sizes.is_empty():
		sizes = ["1280x720", "1920x1080"]
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())

	var layer := CanvasLayer.new()
	root.add_child(layer)
	var screen := _build()
	layer.add_child(screen)
	for size in sizes:
		var parts := size.split("x")
		root.size = Vector2i(int(parts[0]), int(parts[1]))
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, size])
		print("saved ", size)
	quit()


func _build() -> Control:
	var screen := Control.new()
	screen.theme = KahveTheme.theme()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var floor := ColorRect.new()
	floor.color = Color("3a2a1e")
	floor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(floor)

	var page := HBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	page.add_theme_constant_override("separation", 40)
	screen.add_child(page)

	# Column 1: signs, tile buttons in every state, small tiles.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 18)
	left.custom_minimum_size = Vector2(760, 0)
	page.add_child(left)
	var sign := PanelContainer.new()
	var banner := Label.new()
	banner.text = "SNEAKY OKEY"
	banner.theme_type_variation = "TitleLabel"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(banner)
	left.add_child(sign)
	var red := PanelContainer.new()
	red.add_theme_stylebox_override("panel", KahveTheme.sign_style("red"))
	var red_text := Label.new()
	red_text.text = "Başlat"
	red_text.theme_type_variation = "HeadingLabel"
	red_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	red.add_child(red_text)
	left.add_child(red)

	var states := HBoxContainer.new()
	states.add_theme_constant_override("separation", 10)
	left.add_child(states)
	for entry: Array in [["Oyna", "normal"], ["Üstünde", "hover"], ["Basılı", "pressed"], ["Kapalı", "disabled"]]:
		var button := Button.new()
		button.text = entry[0]
		button.add_theme_stylebox_override("normal", KahveTheme.tile_style(entry[1]))
		button.custom_minimum_size = Vector2(170, 130)
		button.disabled = entry[1] == "disabled"
		states.add_child(button)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 10)
	left.add_child(small)
	for entry: String in ["Seri diz", "Çift diz", "Renge göre", "Geri"]:
		var button := Button.new()
		button.text = entry
		button.theme_type_variation = "SmallTile"
		small.add_child(button)

	var stepper_row := HBoxContainer.new()
	stepper_row.add_theme_constant_override("separation", 30)
	left.add_child(stepper_row)
	stepper_row.add_child(Stepper.new().setup(0, 300, 1, 101))
	stepper_row.add_child(Stepper.new().setup(0.5, 15, 0.5, 4.0, "sn"))
	var switches := HBoxContainer.new()
	switches.add_theme_constant_override("separation", 30)
	left.add_child(switches)
	var off := Switch.new()
	switches.add_child(off)
	var on := Switch.new()
	on.button_pressed = true
	switches.add_child(on)
	var pill := ProgressPill.new()
	pill.maximum = 130
	pill.goal = 101
	pill.value = 87
	pill.text = "Açılış 87 / 101"
	switches.add_child(pill)

	# Column 2: type, paper, ledger hand, keys, slips, stamp.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(right)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", KahveTheme.paper_style())
	var paper_box := VBoxContainer.new()
	paper.add_child(paper_box)
	for entry: Array in [["Açma barajı", "ui_bold", 34], [PANGRAM, "ui", 26], ["Hasan Amca  +101  borç", "hand", 36], ["çift açan iki kat öder", "script", 36]]:
		var label := Label.new()
		label.text = entry[0]
		label.add_theme_font_override("font", KahveTheme.font(entry[1]))
		label.add_theme_font_size_override("font_size", entry[2])
		label.add_theme_color_override("font_color", KahveTheme.PAPER_INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paper_box.add_child(label)
	right.add_child(paper)

	var slate := PanelContainer.new()
	var slate_box := VBoxContainer.new()
	slate.add_child(slate_box)
	var chalk := Label.new()
	chalk.text = "1. el   Hoca Dayı  -202"
	chalk.theme_type_variation = "HandLabel"
	slate_box.add_child(chalk)
	slate_box.add_child(KeyCap.line(["Çek", ["Sol tık"], "desteye ya da soldakine"]))
	slate_box.add_child(KeyCap.line(["At", ["Çift tık"], "ya da", ["Space"], "ıstakaya bak"]))
	right.add_child(slate)

	var feed := SlipFeed.new()
	right.add_child(feed)
	feed.add_slip("Hasan Amca el açtı (112)", KahveTheme.SUIT_BLUE)
	feed.add_slip("Mahmut Usta: \"Yakala!\" (Sen)", KahveTheme.SUIT_YELLOW)
	feed.add_slip("Sen: Okey attı +101", KahveTheme.SUIT_RED)

	var stamp := Stamp.new()
	screen.add_child(stamp)
	stamp.slam.call_deferred("YAKALANDIN!", Color("d9382c"))
	return screen
