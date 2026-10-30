class_name MenuTile
extends Button
## A menu entry as a tall okey tile: the word big on its face and a coloured dot under it, like the dots on a real tile.
## It stands in the rack of the main menu; pointing at it lifts it (the tile's own look does that), a click clicks.

const SIZE := Vector2(290, 340)

## The colour of the dot, one of the four tile colours.
var pip := KahveTheme.SUIT_RED


func _init(label := "", pip_colour := KahveTheme.SUIT_RED) -> void:
	text = label
	pip = pip_colour
	custom_minimum_size = SIZE
	size = SIZE
	add_theme_font_size_override("font_size", 36)
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _draw() -> void:
	var lift := 0.0
	if is_pressed() or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		lift = -6.0
	elif is_hovered() or has_focus():
		lift = 6.0
	var at := Vector2(size.x * 0.5, size.y * 0.64 - lift)
	draw_circle(at + Vector2(1.5, 2.5), 17.0, Color(0, 0, 0, 0.18))
	draw_circle(at, 16.0, pip)
	draw_circle(at - Vector2(4, 5), 5.0, Color(1, 1, 1, 0.28))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_FOCUS_ENTER \
			or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
