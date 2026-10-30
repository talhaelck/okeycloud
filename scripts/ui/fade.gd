class_name Fade
extends CanvasLayer
## A black curtain over everything (above every screen): the cuts between the intro, the menu and the table are
## fades, not jumps. `await fade.darken()` drops it, `fade.lighten()` lifts it; `cover()` drops it at once. Headless and
## in tests it still runs (it is only a tween on a ColorRect), but `instant` makes every fade immediate.

static var instant := DisplayServer.get_name() == "headless"

var _rect := ColorRect.new()
var _tween: Tween


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.color = Color.BLACK
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func cover() -> void:
	_stop()
	_rect.modulate.a = 1.0


func clear() -> void:
	_stop()
	_rect.modulate.a = 0.0


func is_dark() -> bool:
	return _rect.modulate.a > 0.999


## To black over `seconds`.
func darken(seconds := 0.5) -> void:
	await _go(1.0, seconds)


## Back to the picture over `seconds`.
func lighten(seconds := 0.8) -> void:
	await _go(0.0, seconds)


func _go(target: float, seconds: float) -> void:
	_stop()
	if instant or seconds <= 0.0:
		_rect.modulate.a = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_rect, "modulate:a", target, seconds)
	await _tween.finished


func _stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null
