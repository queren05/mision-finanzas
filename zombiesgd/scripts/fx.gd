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

var quads = {}
var fade: Gradient
## rendimiento: una malla y un material por tipo de partícula (antes se creaban en cada disparo)
func _quad(color: Color, size: float, unshaded: bool) -> QuadMesh:
	var key = "%s|%.2f|%s" % [color.to_html(), size, unshaded]
	if quads.has(key): return quads[key]
	var q = QuadMesh.new(); q.size = Vector2(size, size)
	var mat = StandardMaterial3D.new(); mat.albedo_texture = soft_tex; mat.albedo_color = color; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; mat.vertex_color_use_as_albedo = true
	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = mat; quads[key] = q
	return q

## rendimiento: las ráfagas se reutilizan (antes cada disparo creaba y destruía nodos de partículas, con tirones del recolector)
var pool: Array = []          # [nodo, libre a partir de (ms)]
func _burst(parent: Node, at: Vector3, n: int, color: Color, vel: float, size: float, life: float, grav: float, dir := Vector3.UP, spread := 60.0, unshaded := false) -> void:
	var now = Time.get_ticks_msec()
	var p: CPUParticles3D = null
	var slot = -1
	for i in pool.size():
		var e = pool[i]
		if not is_instance_valid(e[0]) or e[0].get_parent() != parent: pool[i] = pool[-1]; pool.pop_back(); break   # (partida anterior)
		if e[1] <= now and e[0].amount == n: p = e[0]; slot = i; break
	if p == null:
		if pool.size() >= 48:   # tope: con todo ocupado se salta el efecto en vez de crear más
			return
		p = CPUParticles3D.new(); p.one_shot = true; p.emitting = false; p.explosiveness = 0.95; p.amount = n
		p.scale_amount_min = 0.6; p.scale_amount_max = 1.4
		if fade == null: fade = Gradient.new(); fade.set_color(0, Color(1, 1, 1, 1)); fade.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = fade
		parent.add_child(p); pool.append([p, 0]); slot = pool.size() - 1
	p.lifetime = life
	p.mesh = _quad(color, size, unshaded)
	p.direction = dir; p.spread = spread; p.initial_velocity_min = vel * 0.4; p.initial_velocity_max = vel
	p.gravity = Vector3(0, -grav, 0)
	p.global_position = at; p.restart(); p.emitting = true
	pool[slot][1] = now + int((life + 0.25) * 1000.0)

## parada de impacto: el tiempo se congela un instante (tiro en la cabeza que mata, explosión). Solo en solitario.
var _stop_until = 0
func hitstop(ms := 45, scale := 0.08) -> void:
	if Net.active: return
	if float(GS.settings.get("shake", 1.0)) <= 0.01: return
	var was = _stop_until > Time.get_ticks_msec()
	_stop_until = Time.get_ticks_msec() + ms
	if was: return
	Engine.time_scale = scale
	while Time.get_ticks_msec() < _stop_until: await get_tree().process_frame
	Engine.time_scale = 1.0

## agujeros de bala: unas pocas marcas reutilizadas (la más vieja se recoloca), sin sombra y solo de cerca
var holes: Array = []
var hole_i = 0
var hole_mesh: QuadMesh
func bullet_hole(parent: Node, at: Vector3, n: Vector3) -> void:
	if hole_mesh == null:
		hole_mesh = QuadMesh.new(); hole_mesh.size = Vector2(0.11, 0.11)
		var mat = StandardMaterial3D.new(); mat.albedo_texture = soft_tex; mat.albedo_color = Color(0.03, 0.03, 0.03, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.disable_receive_shadows = true; mat.render_priority = 1
		hole_mesh.material = mat
	if holes.size() > 0 and (not is_instance_valid(holes[0]) or holes[0].get_parent() != parent): holes.clear(); hole_i = 0
	var mi: MeshInstance3D
	if holes.size() < 24:
		mi = MeshInstance3D.new(); mi.mesh = hole_mesh; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 30.0; parent.add_child(mi); holes.append(mi)
	else:
		mi = holes[hole_i]; hole_i = (hole_i + 1) % holes.size()
	var up = Vector3.UP if abs(n.y) < 0.95 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(-n, up).rotated(n, randf() * TAU), at + n * 0.012)
	mi.scale = Vector3.ONE * randf_range(0.8, 1.25)

func blood(parent: Node, at: Vector3, head: bool) -> void:
	if not GS.settings.get("gore", true): _burst(parent, at, 4, Color(0.25, 0.25, 0.22), 1.2, 0.1, 0.4, 6.0); return   # sin sangre: polvo
	_burst(parent, at, 10 if head else 6, Color(0.42, 0.02, 0.02), 2.6 if head else 1.6, 0.13, 0.6, 9.0, Vector3.UP, 70.0)

func impact(parent: Node, at: Vector3, n: Vector3) -> void:
	bullet_hole(parent, at, n)
	_burst(parent, at + n * 0.02, 5, Color(0.55, 0.52, 0.48), 1.8, 0.08, 0.45, 6.0, n, 35.0)
	_burst(parent, at + n * 0.02, 3, Color(1.0, 0.8, 0.4), 3.0, 0.03, 0.12, 0.0, n, 30.0, true)

func dust(parent: Node, at: Vector3) -> void:
	_burst(parent, at + Vector3(randf_range(-0.4, 0.4), 0.05, randf_range(-0.4, 0.4)), 2, Color(0.35, 0.3, 0.25, 0.7), 1.0, 0.35, 0.9, 1.0, Vector3.UP, 40.0)

func explosion(parent: Node, at: Vector3) -> void:
	_burst(parent, at, 26, Color(1.0, 0.6, 0.25), 6.0, 0.6, 0.5, 0.0, Vector3.UP, 180.0, true)
	_burst(parent, at, 18, Color(0.18, 0.17, 0.16, 0.85), 2.5, 1.4, 1.6, -0.6, Vector3.UP, 90.0)
	var l = OmniLight3D.new(); l.light_color = Color(1, 0.6, 0.3); l.omni_range = 9; l.light_energy = 6; parent.add_child(l); l.global_position = at + Vector3(0, 0.5, 0)
	var tw = l.create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.35); tw.tween_callback(l.queue_free)

func gas(parent: Node, at: Vector3) -> void:
	_burst(parent, at, 30, Color(0.45, 0.85, 0.25, 0.75), 3.0, 1.2, 1.8, -0.4, Vector3.UP, 180.0)

func pop(parent: Node, at: Vector3, color: Color) -> void:
	_burst(parent, at, 16, Color(color.r, color.g, color.b, 0.8), 4.0, 0.18, 0.5, 2.0, Vector3.UP, 180.0, true)

func sparkle(parent: Node, at: Vector3, color: Color) -> void:
	_burst(parent, at, 8, color, 1.2, 0.12, 0.8, -0.5, Vector3.UP, 180.0, true)

## fuego que no se apaga (coches quemados, grietas): lenguas de fuego, núcleo brillante, brasas y humo.
## Partículas por CPU (seguras en cualquier móvil) con mezcla aditiva.
func _fire_mesh(color: Color, size: Vector2) -> QuadMesh:
	var key = "fire|%s|%s" % [color.to_html(), size]
	if quads.has(key): return quads[key]
	var q = QuadMesh.new(); q.size = size
	var mat = StandardMaterial3D.new(); mat.albedo_texture = soft_tex; mat.albedo_color = color; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; mat.vertex_color_use_as_albedo = true; mat.disable_receive_shadows = true
	q.material = mat; quads[key] = q
	return q

func fire(parent: Node, at: Vector3, size := 1.0) -> Node3D:
	var root = Node3D.new(); parent.add_child(root); root.global_position = at
	var shrink = Curve.new(); shrink.add_point(Vector2(0, 1.0)); shrink.add_point(Vector2(0.6, 0.7)); shrink.add_point(Vector2(1, 0.15))
	# lenguas: alargadas, suben deprisa y se encogen
	var flame = CPUParticles3D.new(); flame.amount = 26; flame.lifetime = 0.75; flame.preprocess = 1.0
	flame.mesh = _fire_mesh(Color(1.0, 0.5, 0.15, 0.85), Vector2(0.45, 0.8) * size)
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; flame.emission_box_extents = Vector3(0.45, 0.05, 0.45) * size
	flame.direction = Vector3.UP; flame.spread = 8.0; flame.initial_velocity_min = 1.0 * size; flame.initial_velocity_max = 2.2 * size
	flame.gravity = Vector3(0, 1.2, 0); flame.damping_min = 0.5; flame.damping_max = 1.0
	flame.scale_amount_min = 0.6; flame.scale_amount_max = 1.3; flame.scale_amount_curve = shrink
	var g = Gradient.new(); g.set_color(0, Color(1.0, 0.85, 0.4, 0.0)); g.add_point(0.12, Color(1.0, 0.75, 0.3, 1.0)); g.add_point(0.55, Color(1.0, 0.35, 0.06, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.5, 0.05, 0.0, 0.0))
	flame.color_ramp = g; root.add_child(flame)
	# núcleo: blanco-amarillo, abajo
	var core = CPUParticles3D.new(); core.amount = 6; core.lifetime = 0.45; core.preprocess = 0.5
	core.mesh = _fire_mesh(Color(1.0, 0.7, 0.35, 0.55), Vector2(0.35, 0.4) * size)
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; core.emission_box_extents = Vector3(0.3, 0.02, 0.3) * size
	core.direction = Vector3.UP; core.spread = 5.0; core.initial_velocity_min = 0.4; core.initial_velocity_max = 0.9; core.scale_amount_curve = shrink
	var gc = Gradient.new(); gc.set_color(0, Color(1, 1, 1, 0.0)); gc.add_point(0.2, Color(1, 1, 1, 1.0)); gc.set_color(gc.get_point_count() - 1, Color(1, 1, 1, 0.0))
	core.color_ramp = gc; root.add_child(core)
	# humo oscuro que sube y se abre
	var smoke = CPUParticles3D.new(); smoke.amount = 10; smoke.lifetime = 4.0; smoke.preprocess = 4.0
	smoke.mesh = _quad(Color(0.09, 0.08, 0.08), 1.4 * size, false); smoke.position.y = 1.3 * size
	smoke.direction = Vector3.UP; smoke.spread = 10.0; smoke.initial_velocity_min = 0.7; smoke.initial_velocity_max = 1.2
	smoke.gravity = Vector3(0.3, 0.25, 0.0); smoke.scale_amount_min = 1.0; smoke.scale_amount_max = 2.0
	var grow = Curve.new(); grow.add_point(Vector2(0, 0.5)); grow.add_point(Vector2(1, 2.2)); smoke.scale_amount_curve = grow
	var sg = Gradient.new(); sg.set_color(0, Color(1, 1, 1, 0.0)); sg.add_point(0.15, Color(1, 1, 1, 0.5)); sg.set_color(sg.get_point_count() - 1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = sg; root.add_child(smoke)
	# brasas que saltan
	var embers = CPUParticles3D.new(); embers.amount = 8; embers.lifetime = 1.8; embers.preprocess = 1.0
	embers.mesh = _fire_mesh(Color(1.0, 0.6, 0.2), Vector2(0.05, 0.05))
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; embers.emission_box_extents = Vector3(0.5, 0.2, 0.5) * size
	embers.direction = Vector3.UP; embers.spread = 30.0; embers.initial_velocity_min = 1.5; embers.initial_velocity_max = 3.5; embers.gravity = Vector3(0.2, 0.3, 0)
	if fade == null: fade = Gradient.new(); fade.set_color(0, Color(1, 1, 1, 1)); fade.set_color(1, Color(1, 1, 1, 0))
	embers.color_ramp = fade; root.add_child(embers)
	return root

func fire_puff(parent: Node, at: Vector3) -> void:
	_burst(parent, at, 8, Color(1.0, 0.5, 0.15), 1.6, 0.3, 0.5, -1.0, Vector3.UP, 40.0, true)
