class_name PostFx
extends CanvasLayer
## Cinematic finish over the 3D view (under the HUD): soft vignette and fine animated film grain.
## Rack blindness: while you read your rack, everything above its top edge on screen is smeared, drained of colour
## and darkened, so you can sense something moving over there but not tell who or what.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.55;
uniform float grain = 0.05;
uniform float blind = 0.0; // 0 = clear, 1 = fully blind above the edge
uniform float edge = 0.3; // screen height (0 top, 1 bottom) of the rack's top edge
uniform float pulse = 0.0; // 0..1 colour at the screen's edges (caught, caught someone)
uniform vec3 pulse_color = vec3(1.0, 0.1, 0.1);

void fragment() {
	vec3 color = texture(screen, SCREEN_UV).rgb;
	float above = blind * smoothstep(edge + 0.01, edge - 0.08, SCREEN_UV.y);
	if (above > 0.001) {
		vec3 smear = textureLod(screen, SCREEN_UV, 5.5 * above).rgb;
		smear = mix(smear, vec3(dot(smear, vec3(0.3, 0.59, 0.11))), 0.7 * above) * (1.0 - 0.7 * above);
		color = mix(color, smear, above);
	}
	vec2 uv = (SCREEN_UV - 0.5) * vec2(1.0, 0.85);
	float dark = smoothstep(0.3, 0.85, length(uv)) * vignette;
	color = mix(color, pulse_color, clamp(smoothstep(0.18, 0.75, length(uv)) * pulse, 0.0, 0.85));
	float n = fract(sin(dot(FRAGCOORD.xy + vec2(TIME * 61.0, TIME * 37.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(mix(color, vec3(n * grain * 6.0), max(dark, grain)), 1.0);
}
"""

## The film grain can be switched off (Prefs "grain").
static var grain_enabled := true

## How blind rack mode makes you (0-1); a room setting.
var blindness := 0.85

var _material := ShaderMaterial.new()
var _pulse: Tween


func _ready() -> void:
	layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	rect.material = _material
	add_child(rect)


func _process(_delta: float) -> void:
	_material.set_shader_parameter("grain", 0.05 if grain_enabled else 0.0)


## A colour floods the edges of the screen and drains away: red when you are caught, green when you catch.
func pulse(color: Color, seconds := 0.8) -> void:
	Effects.note("pulse")
	_material.set_shader_parameter("pulse_color", Vector3(color.r, color.g, color.b))
	if _pulse:
		_pulse.kill()
	_pulse = create_tween()
	_pulse.tween_method(func(v: float) -> void: _material.set_shader_parameter("pulse", v), 1.0, 0.0, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## `amount` is how far into rack mode the camera is; `edge` the rack's top edge as a screen height (0 top, 1 bottom).
func set_rack_view(amount: float, edge: float) -> void:
	_material.set_shader_parameter("blind", amount * blindness)
	_material.set_shader_parameter("edge", edge)
