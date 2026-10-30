class_name Buddy
extends Node3D
## A dayı sitting in an opponent seat (model from tools/blender/dayi.py, looks from an Appearance).
## Visual only: Watcher decides where he looks and when he reacts. Faces the table along -Z when idle.
## All motion is procedural: breathing, head bob, turning (head leads, body follows) and head shakes.

const MODEL := preload("res://assets/models/dayi/dayi.glb")
const TURN_TIME := 0.3
const MAX_TURN := 1.75
const HEAD_SHARE := 0.45 # how much of a turn the head does on its own
const ALERT_HEIGHT := 1.05 # just over a seated dayı's head
## The realistic MPFB arms are sized for a real man; the dayı's cartoon build needs them a bit bigger.
const ARM_SCALE := 1.3

var appearance: Appearance

var _body: Node3D
var _head: Node3D
var _head_yaw := 0.0
var _shake := 0.0
var _time := randf() * 10.0
var _turn_tween: Tween
var _alert := Label3D.new()
var _level_shown := false # set_alert_level owns the label (a theft is being watched)
var _dayi: Node3D # MeshyDayi or RiggedDayi: both have build(kind), turn_head(yaw, time) and react()


func setup(look: Appearance) -> void:
	appearance = look
	_body = MODEL.instantiate()
	_body.rotation.y = PI # glTF models face +Z
	add_child(_body)
	look.apply(_body)
	_mount_arms()
	_head = _body.find_child("Head", true, false)
	_setup_alert()


## A Meshy dayı instead of the procedural one: the Mixamo rig with fingers (RiggedDayi) when it has been made,
## otherwise Meshy's own fingerless rig (MeshyDayi).
func setup_meshy(kind: String) -> void:
	add_to_group("dayis") # Visitors turns them toward the door
	_dayi = RiggedDayi.new() if ResourceLoader.exists("res://assets/models/dayi_rig/dayi_%s.glb" % kind) else MeshyDayi.new()
	add_child(_dayi)
	_dayi.build(kind)
	_setup_alert()


## His tile-handling hands, or null if his rig cannot pinch (then the game slides his tiles for him).
func tile_hands() -> DayiHands:
	var rigged := _dayi as RiggedDayi
	return rigged.hands if rigged and not rigged.hands.hands.is_empty() else null


## Bows his head (+ down) and leans him over the table (radians); only rigged dayıs can.
func bow(pitch: float, amount := 0.0) -> void:
	if _dayi is RiggedDayi:
		(_dayi as RiggedDayi).bow(pitch, amount)


## Turns his head to a yaw (radians, + to his left) right away, for a dayı who follows a player's look.
func face(yaw: float) -> void:
	if _dayi is RiggedDayi:
		(_dayi as RiggedDayi).yaw = clampf(yaw, -RiggedDayi.MAX_TURN, RiggedDayi.MAX_TURN)


## Converts a world point into his own space (the space DayiHands works in).
func dayi_space(point: Vector3) -> Vector3:
	return (_dayi as Node3D).to_local(point) if _dayi else to_local(point)


func _setup_alert() -> void:
	_alert.text = "!"
	_alert.font_size = 160
	_alert.pixel_size = 0.001
	_alert.modulate = Color(1.0, 0.85, 0.1)
	_alert.outline_size = 36
	_alert.outline_modulate = Color(0.25, 0.1, 0.05)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.position = Vector3(0, ALERT_HEIGHT, 0)
	_alert.visible = false
	add_child(_alert)


func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	_body.scale = Vector3(1.0, 1.0 + sin(_time * 2.2) * 0.012, 1.0)
	_head.rotation = Vector3(sin(_time * 0.9) * 0.04, _head_yaw + sin(_time * 24.0) * _shake, sin(_time * 0.6) * 0.03)


## Puts the same realistic forearms and hands as the player's on the dayı's hand mounts (tools/blender/dayi.py).
func _mount_arms() -> void:
	var arms: Node3D = Seat.ARMS.instantiate()
	add_child(arms)
	for side in ["l", "r"]:
		var mount := _body.find_child("hand_mount_" + side, true, false) as Node3D
		var arm := arms.find_child("arm_" + side, true, false) as Node3D
		if mount == null or arm == null:
			continue
		arm.reparent(mount, false)
		# Both use fingers along +Z and the back of the hand +Y; lift a little so the bigger palm rests on the felt.
		arm.transform = Transform3D(Basis().scaled(Vector3.ONE * ARM_SCALE), Vector3.UP * 0.012)
	arms.queue_free()
	for mi: MeshInstance3D in _body.find_children("skin_*", "MeshInstance3D", true, false):
		mi.material_override = Seat.skin_material(mi.get_active_material(0))
	for mi: MeshInstance3D in _body.find_children("sleeve*", "MeshInstance3D", true, false):
		mi.material_override = Mat.textured("rough_linen", 0.08, Appearance.SHIRT, false, false)


## Turns toward a world point; amount 0 keeps facing the table, 1 looks straight at it.
func look_toward(point: Vector3, amount := 1.0) -> void:
	var d := get_parent_node_3d().to_local(point) - position
	_turn(clampf(atan2(-d.x, -d.z), -MAX_TURN, MAX_TURN) * amount)


func look_home() -> void:
	_turn(0.0)


## Disapproving "tsk tsk" head shake.
func shake_head() -> void:
	if _dayi:
		_dayi.react()
		return
	var tween := create_tween()
	tween.tween_property(self, "_shake", 0.35, 0.08)
	tween.tween_property(self, "_shake", 0.0, 0.9).set_ease(Tween.EASE_IN)


func set_alert(on: bool) -> void:
	if _level_shown:
		return
	_alert.text = "!"
	_alert.modulate = Color(1.0, 0.85, 0.1)
	_alert.scale = Vector3.ONE
	_alert.visible = on


## How much he has noticed of what the local player's hand is up to, shown over his head while the player steals:
## "?" for a movement out of the corner of his eye, a "!" growing from yellow to red as he watches (level 0-1), a
## big red "!" once he is a witness. level < 0 hides it again.
func set_alert_level(level: float, glimpse := false) -> void:
	_level_shown = level >= 0.0 or glimpse
	if not _level_shown:
		_alert.visible = false
		return
	_alert.visible = true
	if level <= 0.0:
		_alert.text = "?"
		_alert.modulate = Color(0.85, 0.85, 0.8)
		_alert.scale = Vector3.ONE * 0.8
		return
	_alert.text = "!"
	_alert.modulate = Color(1.0, 0.85, 0.1).lerp(Color(1.0, 0.15, 0.1), clampf(level, 0.0, 1.0))
	_alert.scale = Vector3.ONE * (0.8 + 0.6 * clampf(level, 0.0, 1.0))


func _turn(yaw: float) -> void:
	if _dayi:
		_dayi.turn_head(yaw, TURN_TIME)
		return
	if _turn_tween:
		_turn_tween.kill()
	_turn_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_property(self, "_head_yaw", yaw * HEAD_SHARE, TURN_TIME * 0.7)
	_turn_tween.tween_property(self, "rotation:y", yaw * (1.0 - HEAD_SHARE), TURN_TIME)
