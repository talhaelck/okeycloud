class_name Watcher
extends Node
## Where an opponent's eyes are: mostly on his own rack (head bowed), now and then a glance at another player (a
## short half-turn first), sometimes bent over the table reading the laid melds. A movement out of the corner of
## his eye or a tile clicking makes him look (notice()). How often he looks up depends on `vigilance` (0-1).
## Sets Seat.look_mode / look_dir, which is what Visibility goes by, and poses his dayı to match, so a human can
## read it too: bowed head = busy with his rack, bent over = not watching his rack, head up = watching.

enum State { RACK, HINT, LOOK, LEAN }

const HINT_TIME := 0.55
const LOOK_TIME := Vector2(1.2, 2.4)
const RACK_TIME := Vector2(2.5, 6.0) # for an average watcher; vigilance shortens or stretches it
const LEAN_TIME := Vector2(1.5, 3.0)
const LOCAL_BIAS := 0.55 # chance a glance goes to the local player
const RACK_BOW := 0.5 # radians the head bows to read the rack
const LEAN_BOW := 0.45
const LEAN_BEND := 0.35

var seat: Seat
var local_seat: Seat
var others: Array[Seat] = []
var target: Seat
var vigilance := 0.5
## Chance he leans over the table instead of looking up (higher once melds are down).
var lean_chance := 0.1
## While his own turn is played (his head follows his hands then), he does not glance around.
var paused := false:
	set(value):
		paused = value
		if value:
			_state = State.RACK
			_timer = 0.5
			seat.buddy.bow(0.15)
			seat.buddy.set_alert(false)
			seat.look_mode = FocusCamera.Mode.OBSERVE
			seat.look_dir = (seat.rack.global_position - seat.head_anchor.global_position).normalized()

var _state := State.RACK
var _timer := 0.0
var _point := Vector3.ZERO # what he looks at when it is not a person


func _ready() -> void:
	_set_state(State.RACK, _rack_time())


func _process(delta: float) -> void:
	if paused:
		return
	if _state == State.LOOK or _state == State.HINT:
		seat.look_dir = (_look_point() - seat.head_anchor.global_position).normalized()
		if _state == State.HINT:
			seat.look_dir = seat.look_dir.slerp(_rack_dir(), 0.55)
	_timer -= delta
	if _timer > 0.0:
		return
	match _state:
		State.RACK:
			if randf() < lean_chance:
				_set_state(State.LEAN, randf_range(LEAN_TIME.x, LEAN_TIME.y))
				return
			target = local_seat if randf() < LOCAL_BIAS else others.pick_random()
			_point = Vector3.ZERO
			seat.buddy.look_toward(target.head_anchor.global_position, 0.25)
			_set_state(State.HINT, HINT_TIME)
		State.HINT:
			seat.buddy.look_toward(_look_point())
			_set_state(State.LOOK, randf_range(LOOK_TIME.x, LOOK_TIME.y))
		State.LOOK, State.LEAN:
			seat.buddy.look_home()
			_set_state(State.RACK, _rack_time())


## Something caught his eye or ear at a world point: he looks there for a moment (unless busy with his turn).
func notice(point: Vector3, time := 1.6) -> void:
	if paused:
		return
	target = null
	_point = point
	seat.buddy.look_toward(point)
	_set_state(State.LOOK, time)


## Looks straight at a seat for a while (when the table reacts to something he did).
func stare_at(other: Seat, time := 1.5) -> void:
	if paused:
		return
	target = other
	_point = Vector3.ZERO
	seat.buddy.look_toward(other.head_anchor.global_position)
	_set_state(State.LOOK, time)


func is_watching(other: Seat) -> bool:
	return _state == State.LOOK and target == other


## Shakes his head at the thief and keeps staring a little longer.
func caught_thief() -> void:
	seat.buddy.shake_head()
	_timer = maxf(_timer, 1.5)


func _look_point() -> Vector3:
	return target.head_anchor.global_position if target else _point


func _rack_dir() -> Vector3:
	return (seat.rack.global_position - seat.head_anchor.global_position).normalized()


func _rack_time() -> float:
	var scale := lerpf(1.6, 0.5, vigilance)
	return randf_range(RACK_TIME.x, RACK_TIME.y) * scale


func _set_state(state: State, time: float) -> void:
	_state = state
	_timer = time
	match state:
		State.RACK:
			seat.look_mode = FocusCamera.Mode.RACK
			seat.buddy.bow(RACK_BOW)
		State.LEAN:
			seat.look_mode = FocusCamera.Mode.LEAN
			seat.buddy.look_home()
			seat.buddy.bow(LEAN_BOW, LEAN_BEND)
		_:
			seat.look_mode = FocusCamera.Mode.OBSERVE
			seat.buddy.bow(0.0)
	seat.buddy.set_alert(state == State.LOOK and target == local_seat)
