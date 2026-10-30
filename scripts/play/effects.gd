class_name Effects
## The game's showy moments, so that things that matter feel like they matter: a sparkle over melds that were just
## laid, a "+101" floating up over the one who got it, a rim of colour around the screen, slow motion and a shaken
## camera when someone is caught. `fired` counts them by kind (tests read it). Slow motion and shaking change global
## state, so they stay off in a headless run (`enabled`); everything else is made anyway.

static var enabled := DisplayServer.get_name() != "headless"
static var fired := {}
static var _glow: Texture2D
static var _slow: Tween


static func count(kind: String) -> int:
	return fired.get(kind, 0)


static func reset_counts() -> void:
	fired.clear()


static func note(kind: String) -> void:
	fired[kind] = count(kind) + 1


## Time runs slower for a moment (a catch, in slow motion), then eases back. `seconds` is real time.
static func slowmo(tree: SceneTree, scale := 0.35, seconds := 0.5) -> void:
	note("slowmo")
	if not enabled:
		return
	if _slow:
		_slow.kill()
	Engine.time_scale = scale
	_slow = tree.create_tween().set_ignore_time_scale(true)
	_slow.tween_interval(seconds * 0.6)
	_slow.tween_property(Engine, "time_scale", 1.0, seconds * 0.4)
	_slow.finished.connect(func() -> void: Engine.time_scale = 1.0)


## A short burst of gold sparks over a box of `extents` at `at` (world space): melds just laid, an okey drawn.
static func sparkle(parent: Node, at: Vector3, extents := Vector3(0.2, 0.005, 0.08), amount := 36, yaw := 0.0) -> void:
	note("sparkle")
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.fixed_fps = 30
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(-extents - Vector3.ONE * 0.5, (extents + Vector3.ONE * 0.5) * 2.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.UP
	process.spread = 40.0
	process.initial_velocity_min = 0.18
	process.initial_velocity_max = 0.5
	process.gravity = Vector3(0, -0.25, 0)
	process.damping_min = 0.4
	process.damping_max = 0.8
	process.scale_min = 0.5
	process.scale_max = 1.2
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.6, 0.2, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.016
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.72, 0.22)
	material.albedo_texture = _glow_texture()
	quad.material = material
	particles.draw_pass_1 = quad
	parent.add_child(particles)
	particles.global_position = at
	particles.global_rotation.y = yaw
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Text that floats up from a point and fades ("+101" over the one who got it). World space.
static func float_text(parent: Node, at: Vector3, text: String, color: Color, rise := 0.45, seconds := 1.8) -> void:
	note("float_text")
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.0016
	label.modulate = color
	label.outline_size = 18
	label.outline_modulate = Color(0.08, 0.04, 0.02)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	parent.add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", at.y + rise, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, seconds * 0.45).set_delay(seconds * 0.55)
	tween.chain().tween_callback(label.queue_free)


static func _glow_texture() -> Texture2D:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 32
		texture.height = 32
		_glow = texture
	return _glow
