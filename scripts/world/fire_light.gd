extends Light3D
## Firelight: brightness and warmth wandering smoothly, with now and then a flare, like a stove burning wood.

var _base := 0.0
var _time := randf() * 100.0


func _ready() -> void:
	_base = light_energy


func _process(delta: float) -> void:
	_time += delta
	var wander := sin(_time * 2.3) * 0.12 + sin(_time * 5.7 + 1.3) * 0.08 + sin(_time * 13.1 + 0.4) * 0.05
	light_energy = _base * (1.0 + wander)
