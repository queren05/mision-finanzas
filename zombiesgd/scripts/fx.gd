extends Node
## Efectos: sangre, impactos en paredes, polvo y explosiones (partículas por CPU, seguras en cualquier móvil).

var soft_tex: Texture2D

func _ready() -> void:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d: float = Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clamp(1.0 - d, 0.0, 1.0) ** 1.6))
	soft_tex = ImageTexture.create_from_image(img)

func _burst(parent: Node, at: Vector3, n: int, color: Color, vel: float, size: float, life: float, grav: float, dir := Vector3.UP, spread := 60.0, unshaded := false) -> void:
	var p = CPUParticles3D.new()
	p.one_shot = true; p.emitting = false; p.amount = n; p.lifetime = life; p.explosiveness = 0.95
	var q = QuadMesh.new(); q.size = Vector2(size, size)
	var mat = StandardMaterial3D.new(); mat.albedo_texture = soft_tex; mat.albedo_color = color; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; mat.vertex_color_use_as_albedo = true
	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = mat; p.mesh = q
	p.direction = dir; p.spread = spread; p.initial_velocity_min = vel * 0.4; p.initial_velocity_max = vel
	p.gravity = Vector3(0, -grav, 0); p.scale_amount_min = 0.6; p.scale_amount_max = 1.4
	var g = Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0)); p.color_ramp = g
	parent.add_child(p); p.global_position = at; p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

func blood(parent: Node, at: Vector3, head: bool) -> void:
	_burst(parent, at, 10 if head else 6, Color(0.42, 0.02, 0.02), 2.6 if head else 1.6, 0.13, 0.6, 9.0, Vector3.UP, 70.0)

func impact(parent: Node, at: Vector3, n: Vector3) -> void:
	_burst(parent, at + n * 0.02, 5, Color(0.55, 0.52, 0.48), 1.8, 0.08, 0.45, 6.0, n, 35.0)
	_burst(parent, at + n * 0.02, 3, Color(1.0, 0.8, 0.4), 3.0, 0.03, 0.12, 0.0, n, 30.0, true)

func dust(parent: Node, at: Vector3) -> void:
	_burst(parent, at + Vector3(randf_range(-0.4, 0.4), 0.05, randf_range(-0.4, 0.4)), 2, Color(0.35, 0.3, 0.25, 0.7), 1.0, 0.35, 0.9, 1.0, Vector3.UP, 40.0)

func explosion(parent: Node, at: Vector3) -> void:
	_burst(parent, at, 26, Color(1.0, 0.6, 0.25), 6.0, 0.6, 0.5, 0.0, Vector3.UP, 180.0, true)
	_burst(parent, at, 18, Color(0.18, 0.17, 0.16, 0.85), 2.5, 1.4, 1.6, -0.6, Vector3.UP, 90.0)
	var l = OmniLight3D.new(); l.light_color = Color(1, 0.6, 0.3); l.omni_range = 9; l.light_energy = 6; parent.add_child(l); l.global_position = at + Vector3(0, 0.5, 0)
	var tw = l.create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.35); tw.tween_callback(l.queue_free)
