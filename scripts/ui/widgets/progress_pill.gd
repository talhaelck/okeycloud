class_name ProgressPill
extends Control
## A bar that fills with felt-green toward a goal and shows a text over it ("Açılış 87 / 101"). `goal` marks the point to
## reach: the notch turns brass once the value gets there. Used for the opening score.

var value := 0.0:
	set(v):
		value = v
		queue_redraw()
var maximum := 100.0:
	set(v):
		maximum = maxf(v, 1.0)
		queue_redraw()
## Where the goal is, in value units (0 = none).
var goal := 0.0:
	set(v):
		goal = v
		queue_redraw()
var text := "":
	set(v):
		text = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(420, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reached() -> bool:
	return goal > 0.0 and value >= goal


func _draw() -> void:
	draw_style_box(KahveTheme.slice("bar_groove", Vector4(16, 16, 16, 16), Vector4()), Rect2(Vector2.ZERO, size))
	var share := clampf(value / maximum, 0.0, 1.0)
	if share > 0.0:
		var width := maxf(size.y * 0.7, (size.x - 8.0) * share)
		var fill := KahveTheme.slice("bar_fill", Vector4(16, 16, 16, 16), Vector4())
		draw_style_box(fill, Rect2(Vector2(4, 0), Vector2(width, size.y)))
	if goal > 0.0:
		var x := 4.0 + (size.x - 8.0) * clampf(goal / maximum, 0.0, 1.0)
		draw_line(Vector2(x, 4), Vector2(x, size.y - 4), KahveTheme.BRASS_BRIGHT if reached() else KahveTheme.CREAM, 4.0)
	if text != "":
		var font := KahveTheme.font("ui_bold")
		var at := Vector2(0, size.y * 0.5 + KahveTheme.SIZE_SMALL * 0.36)
		draw_string(font, at + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, KahveTheme.SIZE_SMALL, Color(0, 0, 0, 0.6))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, KahveTheme.SIZE_SMALL, KahveTheme.CREAM_LIGHT)
