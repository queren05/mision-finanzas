extends Node3D
## Proyectil de las armas maravilla: el Rayo Gamba (rayo de energía con explosión) y el Burbujeador
## (burbuja que atrapa a los zombis de alrededor, los hace flotar y revientan).

var game: Node
var owner_player: Player
var dir = Vector3.FORWARD
var data: Dictionary = {}
var dmg = 0.0
var wid = ""
var life = 0.0
var mesh: MeshInstance3D
var light: OmniLight3D

func _ready() -> void:
	var col: Color = data.get("color", Color(0.3, 1.0, 0.35))
	var bubble = data.has("bubble")
	mesh = MeshInstance3D.new()
	var mat = StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = Color(col.r, col.g, col.b, 0.55 if bubble else 1.0)
	if bubble:
		var sm = SphereMesh.new(); sm.radius = 0.35; sm.height = 0.7; mesh.mesh = sm
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	else:
		var cm = CapsuleMesh.new(); cm.radius = 0.06; cm.height = 0.7; mesh.mesh = cm; mesh.rotation.x = PI / 2
	mesh.material_override = mat; add_child(mesh)
	light = OmniLight3D.new(); light.light_color = col; light.omni_range = 4.0; light.light_energy = 2.0; add_child(light)
	look_at(global_position + dir)

func _physics_process(d: float) -> void:
	life += d
	if life > 3.0: queue_free(); return
	var step = dir * float(data.get("speed", 40.0)) * d
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(global_position, global_position + step, MapBuilder.LAYER_WORLD | MapBuilder.LAYER_ZOMBIE | MapBuilder.LAYER_BARRIER)
	if owner_player: q.exclude = [owner_player.get_rid()]
	var hit = space.intersect_ray(q)
	# además, cualquier zombi cuyo cuerpo quede cerca del recorrido (más fiable que solo el rayo)
	var a0 = global_position; var a1 = global_position + step
	var best_t = 2.0; var best_z: Zombie = null
	var hit_t = (a0.distance_to(hit.position) / step.length()) if not hit.is_empty() else 2.0
	for z in game.zombies:
		if not is_instance_valid(z) or z.dead: continue
		var r = float(Zombie.TYPE_DATA[z.type].radius) + (0.25 if data.has("bubble") else 0.1)
		var h = float(Zombie.TYPE_DATA[z.type].height)
		for k in 3:   # tres puntos del cuerpo (pies, pecho, cabeza)
			var c = z.global_position + Vector3(0, h * (0.2 + 0.35 * k), 0)
			var tt = clamp((c - a0).dot(step) / step.length_squared(), 0.0, 1.0)
			if (a0 + step * tt).distance_to(c) < r and tt < best_t: best_t = tt; best_z = z
	if best_z and best_t < hit_t:
		_impact(a0 + step * best_t, best_z); return
	if hit.is_empty():
		global_position += step
		if data.has("bubble"): mesh.scale = Vector3.ONE * (1.0 + sin(life * 12.0) * 0.06)
		return
	_impact(hit.position, hit.collider)

func _impact(at: Vector3, col: Object) -> void:
	if OS.get_cmdline_user_args().has("verbose"): print("IMPACTO en ", at, " contra ", col, " (", col.get_parent().name if col and col.get_parent() else "", ")")
	var c: Color = data.get("color", Color.GREEN)
	if data.has("bubble"):
		# la burbuja atrapa a todos los de alrededor
		var r = float(data.bubble)
		for z in game.zombies.duplicate():
			if is_instance_valid(z) and not z.dead and z.global_position.distance_to(at) < r:
				game.damage_zombie(z, 0.0, z.global_position + Vector3(0, 1.4, 0), false, "bubble", wid)
		Fx.pop(game, at, c); Sfx.play_at("dryfire", at, 1.0, 1.6)
	else:
		if col is Zombie: game.damage_zombie(col, dmg, at, false, "proj", wid)
		var r2 = float(data.get("splash", 1.5))
		for z in game.zombies.duplicate():
			if is_instance_valid(z) and not z.dead and z != col and z.global_position.distance_to(at) < r2:
				game.damage_zombie(z, float(data.get("splash_dmg", 300)), z.global_position + Vector3(0, 1, 0), false, "proj", wid)
		Fx.pop(game, at, c); Fx.explosion(game, at)
		Sfx.play_at("shot_rifle2", at, 0.8, 1.6)
	if game.hud and col is Zombie: game.hud.hitmarker(false, false)
	queue_free()
