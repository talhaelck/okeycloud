class_name Atmosphere
## The air of the kahvehane: cigarette smoke curling up from ashtrays, steam over hot tea, dust drifting in the lamp
## light, and a layer of old smoke hanging under the ceiling that the lamps' beams cut through.
## All soft billboard particles lit by the scene's lights (so they glow inside the lamp cones and fade outside),
## plus FogVolumes for the hanging haze; volumetric fog in main.tscn does the rest.

static var _puff: Texture2D


## A thin wisp rising from a smouldering cigarette at `pos` (parent space), spreading and fading as it climbs.
static func smoke(parent: Node3D, pos: Vector3) -> GPUParticles3D:
	var particles := _particles(parent, pos, 14, 5.0, 0.02)
	var process := particles.process_material as ParticleProcessMaterial
	process.direction = Vector3.UP
	process.spread = 6.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.09
	process.gravity = Vector3(0, 0.012, 0)
	process.damping_min = 0.01
	process.damping_max = 0.02
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.35
	process.turbulence_noise_scale = 3.5
	process.turbulence_noise_speed = Vector3(0.05, 0.12, 0.05)
	process.turbulence_influence_min = 0.03
	process.turbulence_influence_max = 0.08
	process.scale_min = 0.8
	process.scale_max = 1.3
	process.scale_curve = _curve([Vector2(0, 0.3), Vector2(0.4, 1.2), Vector2(1, 3.2)])
	process.color_ramp = _ramp(Color(0.72, 0.72, 0.75), [0.0, 0.12, 0.07, 0.0])
	return particles


## Steam over a hot glass of tea at `pos`: faint, short, rising quickly and vanishing.
static func steam(parent: Node3D, pos: Vector3) -> GPUParticles3D:
	var particles := _particles(parent, pos, 6, 1.4, 0.02)
	var process := particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.015
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = 0.06
	process.initial_velocity_max = 0.1
	process.gravity = Vector3(0, 0.02, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.2
	process.turbulence_noise_scale = 6.0
	process.scale_min = 0.8
	process.scale_max = 1.2
	process.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.4)])
	process.color_ramp = _ramp(Color(0.95, 0.95, 0.95), [0.0, 0.06, 0.03, 0.0])
	return particles


## Dust motes drifting through a box of `size` around `center`: only visible where a lamp lights them.
## Tiny opaque dots, not soft see-through puffs: those cost ~6 ms a frame here (measured), these almost nothing.
static func dust(parent: Node3D, center: Vector3, size: Vector3) -> GPUParticles3D:
	var particles := _particles(parent, center, 45, 14.0, 0.0018)
	var dot := QuadMesh.new()
	dot.size = Vector2.ONE * 0.0018
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.55, 0.52, 0.47)
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.disable_receive_shadows = true
	dot.material = material
	particles.draw_pass_1 = dot
	particles.visibility_aabb = AABB(-size, size * 2.0)
	var process := particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = size * 0.5
	process.direction = Vector3.DOWN
	process.spread = 180.0
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.01
	process.gravity = Vector3(0, -0.002, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 1.5
	process.turbulence_noise_speed = Vector3(0.02, 0.01, 0.02)
	process.turbulence_influence_min = 0.01
	process.turbulence_influence_max = 0.03
	process.scale_min = 0.7
	process.scale_max = 1.4
	particles.preprocess = 14.0
	return particles


## Old smoke hanging in a layer: a FogVolume box of `size` at `center`, densest in the middle, soft at its edges.
static func haze(parent: Node3D, center: Vector3, size: Vector3, density := 0.06) -> FogVolume:
	var volume := FogVolume.new()
	volume.position = center
	volume.size = size
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var material := FogMaterial.new()
	material.density = density
	material.albedo = Color(0.82, 0.78, 0.72)
	material.edge_fade = 0.6
	volume.material = material
	parent.add_child(volume)
	return volume


## `size` is the particle's base width in metres; it is set on the quad itself, and the process material's scale
## only varies and grows it (relying on that scale alone drew 1 m squares here).
static func _particles(parent: Node3D, pos: Vector3, amount: int, lifetime: float, size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.position = pos
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.fixed_fps = 30
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-0.6, -0.1, -0.6), Vector3(1.2, 1.6, 1.2))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.process_material = ParticleProcessMaterial.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_puff()
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.disable_receive_shadows = true
	material.proximity_fade_enabled = true
	material.proximity_fade_distance = 0.05
	quad.material = material
	particles.draw_pass_1 = quad
	parent.add_child(particles)
	return particles


static func _soft_puff() -> Texture2D:
	if _puff == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.45))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 64
		texture.height = 64
		_puff = texture
	return _puff


static func _curve(points: Array) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = 5.0
	for point: Vector2 in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _ramp(color: Color, alphas: Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	var colors := PackedColorArray()
	for alpha: float in alphas:
		colors.append(Color(color, alpha))
	gradient.colors = colors
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
