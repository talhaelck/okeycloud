class_name FocusCamera
extends Camera3D
## First-person camera with three ways of looking:
##  - Observe: free head look around the table; your own rack (close by) is blurred.
##  - Rack: zoomed onto your rack; everything beyond it is blurred (and PostFx blinds the rest).
##  - Lean: you rise and bend over the table to see the middle from above (the laid melds, the pile, the discard
##    rows); the head can still look around a little. Your own rack is under you, out of sight, and everyone sees
##    you bent over the table.
## Space or right mouse button toggles the rack. W or the mouse wheel (up) leans over, W again or wheel down sits
## back. (Esc belongs to the pause menu, which frees the mouse; closing it grabs it again.)

enum Mode { OBSERVE, RACK, LEAN }

const LOOK_SENSITIVITY := 0.0025
const YAW_LIMIT := 1.3
const PITCH_MIN := -0.95
const PITCH_MAX := 0.6
const LEAN_YAW := 0.7 # how far the head turns while bent over the table
const LEAN_PITCH := 0.35
const BLEND_TIME := 0.35
const LEAN_TIME := 0.45 # rising and bending over takes a moment

# Depth-of-field distances (metres) for each mode; interpolated during the transition.
const OBSERVE_NEAR := 0.9
const OBSERVE_FAR := 60.0
const RACK_NEAR := 0.05
const RACK_FAR := 0.45
const LEAN_NEAR := 0.3
# Blur strength: light in observe mode (only your own rack), heavy in rack mode so the table beyond is a smear.
const OBSERVE_BLUR := 0.18
const RACK_BLUR := 0.6

signal mode_changed(mode: Mode)

## When false the camera never touches the mouse mode (used by the screenshot tool).
var mouse_control := true
var focused := false
var mode := Mode.OBSERVE
## How far into rack mode the camera is: 0 observing, 1 reading the rack (follows the transition).
var rack_amount: float:
	get:
		return _blend
## How far bent over the table: 0 sitting, 1 looking down on the middle.
var lean_amount: float:
	get:
		return _lean
## Head direction while observing (yaw, + left; pitch, + up), for others to read off the player's dayı.
var yaw: float:
	get:
		return _yaw
var pitch: float:
	get:
		return _pitch
var lean_yaw: float:
	get:
		return _lean_yaw

var _head: Node3D
var _rack: Node3D
var _over: Node3D
var _yaw := 0.0
var _pitch := -0.5
var _lean_yaw := 0.0
var _lean_pitch := 0.0
var _blend := 0.0
var _lean := 0.0
var _tween: Tween
var _lean_tween: Tween
## A pose that takes the camera over (the end-of-hand show): `cine_blend` 0 = the player's own view, 1 = this.
var cine_transform := Transform3D()
var cine_blend := 0.0
var _shake_amount := 0.0
var _shake_left := 0.0
var _shake_total := 1.0


## The camera shakes for `seconds` (a rotation of up to `amount` radians that dies away). Not in a headless run.
func shake(amount: float, seconds: float) -> void:
	Effects.note("shake")
	if not Effects.enabled:
		return
	_shake_amount = amount
	_shake_left = seconds
	_shake_total = maxf(seconds, 0.01)


func attach_to_seat(seat: Seat) -> void:
	_head = seat.head_anchor
	_rack = seat.rack_focus_anchor
	_over = seat.lean_anchor


## Points the head directly (yaw/pitch in radians, clamped to the usual limits).
func look(yaw_to: float, pitch_to: float) -> void:
	_yaw = clampf(yaw_to, -YAW_LIMIT, YAW_LIMIT)
	_pitch = clampf(pitch_to, PITCH_MIN, PITCH_MAX)


func set_focused(value: bool, instant := false) -> void:
	set_mode(Mode.RACK if value else Mode.OBSERVE, instant)


func set_mode(value: Mode, instant := false) -> void:
	var changed := value != mode
	mode = value
	focused = value == Mode.RACK
	if mouse_control:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if focused else Input.MOUSE_MODE_CAPTURED
	if value == Mode.LEAN and changed:
		_lean_yaw = 0.0
		_lean_pitch = 0.0
	_tween = _ease(_tween, "_blend", 1.0 if focused else 0.0, BLEND_TIME, instant)
	_lean_tween = _ease(_lean_tween, "_lean", 1.0 if value == Mode.LEAN else 0.0, LEAN_TIME, instant)
	if changed:
		mode_changed.emit(value)


func _ease(tween: Tween, property: String, target: float, time: float, instant: bool) -> Tween:
	if tween:
		tween.kill()
	if instant:
		set(property, target)
		return null
	var out := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	out.tween_property(self, property, target, time)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not focused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if mode == Mode.LEAN:
				_lean_yaw = clampf(_lean_yaw - event.relative.x * LOOK_SENSITIVITY, -LEAN_YAW, LEAN_YAW)
				_lean_pitch = clampf(_lean_pitch - event.relative.y * LOOK_SENSITIVITY, -LEAN_PITCH, LEAN_PITCH)
			else:
				_yaw = clampf(_yaw - event.relative.x * LOOK_SENSITIVITY, -YAW_LIMIT, YAW_LIMIT)
				_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, PITCH_MIN, PITCH_MAX)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			set_mode(Mode.OBSERVE if mode == Mode.RACK else Mode.RACK)
		elif event.keycode == KEY_W:
			set_mode(Mode.OBSERVE if mode == Mode.LEAN else Mode.LEAN)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			set_mode(Mode.OBSERVE if mode == Mode.RACK else Mode.RACK)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and mode != Mode.LEAN:
			set_mode(Mode.LEAN)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mode == Mode.LEAN:
			set_mode(Mode.OBSERVE)
		elif event.button_index == MOUSE_BUTTON_LEFT and not focused and mouse_control \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled() # this click is not a grab


func _process(_delta: float) -> void:
	if _head == null:
		return
	var look := _head.global_transform * Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), Vector3.ZERO)
	var over := _over.global_transform * Transform3D(Basis.from_euler(Vector3(_lean_pitch, _lean_yaw, 0.0)), Vector3.ZERO)
	global_transform = look.interpolate_with(over, _lean).interpolate_with(_rack.global_transform, _blend)
	if cine_blend > 0.0:
		global_transform = global_transform.interpolate_with(cine_transform, cine_blend)
	if _shake_left > 0.0:
		_shake_left -= get_process_delta_time()
		var fade := pow(maxf(_shake_left, 0.0) / _shake_total, 2.0)
		global_transform.basis = global_transform.basis * Basis.from_euler(
			Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * _shake_amount * fade)

	var dof := attributes as CameraAttributesPractical
	dof.dof_blur_near_distance = lerpf(lerpf(OBSERVE_NEAR, LEAN_NEAR, _lean), RACK_NEAR, _blend)
	# Log-space so the far blur creeps in gradually instead of snapping at the end.
	dof.dof_blur_far_distance = exp(lerpf(log(OBSERVE_FAR), log(RACK_FAR), _blend))
	dof.dof_blur_amount = lerpf(OBSERVE_BLUR, RACK_BLUR, _blend)
