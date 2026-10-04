extends Node3D
## Una partida: mapa, zonas y navegación, jugador, rondas, zombis, potenciadores, efectos y fin de partida.

signal finished(stats: Dictionary)

var cfg: Dictionary
var map_id = ""
var player: Player
var hud: Node
var paused = false
var god = false
var power_on = false
var fire_sale = 0.0
var insta = 0.0
var dpoints = 0.0
var zones = {}                 # id -> {open, boxes:[AABB], spawns:[Vector3]}
var nav_regions = {}           # id -> NavigationRegion3D
var interactables: Array = []
var doors: Array = []
var zombies: Array = []
var round_n = 0
var to_spawn = 0
var spawn_t = 0.0
var break_t = 0.0
var drops = 0
var time = 0.0
var max_alive = 24
var hide_nodes = {}            # puerta -> nodos del mapa que se esconden al abrirla
var env: Environment

func start(id: String) -> void:
	map_id = id
	cfg = MapBuilder.load_config(id)
	_build_environment()
	var root = MapBuilder.build_scene(cfg, self)
	_build_zones(root)
	_build_interactables()
	player = Player.new(); player.game = self; add_child(player)
	var sp = cfg.spawn
	player.global_position = MapBuilder.v3(sp); player.yaw = deg_to_rad(float(sp[3]) if sp.size() > 3 else 0.0)
	hud = preload("res://scripts/hud.gd").new(); hud.game = self; add_child(hud)
	player.setup(GS.start_weapon, GS.start_perk)
	player.points = 500 + (GS.start_round - 1) * 450
	player.died.connect(_on_player_died)
	player.points_changed.connect(func(p, dl): hud.update_points(p, dl))
	hud.update_points(player.points, 0); hud.update_ammo(); hud.update_perks(player.perks)
	Sfx.play_ambient(cfg.get("ambient", "amb1"))
	round_n = GS.start_round - 1
	break_t = 2.5

# ------------------------------------------------------------------ escenario e iluminación
func _build_environment() -> void:
	var e: Dictionary = cfg.get("env", {})
	env = Environment.new()
	var sky = Sky.new(); var psky = ProceduralSkyMaterial.new()
	psky.sky_top_color = _col(e.get("sky_top", [0.18, 0.22, 0.3])); psky.sky_horizon_color = _col(e.get("sky_horizon", [0.42, 0.42, 0.45]))
	psky.ground_horizon_color = psky.sky_horizon_color; psky.ground_bottom_color = Color(0.08, 0.08, 0.09)
	psky.sun_angle_max = 6.0; psky.sun_curve = 0.35; psky.sky_energy_multiplier = float(e.get("sky_energy", 0.8))
	sky.sky_material = psky; env.sky = sky; env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = float(e.get("ambient", 0.55)) * 1.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = float(e.get("exposure", 1.0)); env.tonemap_white = 6.0
	env.fog_enabled = true; env.fog_light_color = _col(e.get("fog", [0.4, 0.42, 0.45])); env.fog_density = float(e.get("fog_density", 0.012)); env.fog_aerial_perspective = 0.4; env.fog_sky_affect = 0.6
	env.glow_enabled = true; env.glow_intensity = 0.35; env.glow_strength = 0.8; env.glow_bloom = 0.0; env.glow_hdr_threshold = 1.6
	env.adjustment_enabled = true; env.adjustment_contrast = 1.06; env.adjustment_saturation = float(e.get("saturation", 0.85))
	var we = WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun = DirectionalLight3D.new(); sun.light_color = _col(e.get("sun_color", [1.0, 0.92, 0.8])); sun.light_energy = float(e.get("sun", 1.1))
	var sr: Array = e.get("sun_rot", [-42, 35]); sun.rotation_degrees = Vector3(sr[0], sr[1], 0)
	sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5; sun.shadow_bias = 0.03; sun.shadow_normal_bias = 1.2
	add_child(sun)
	for l in cfg.get("lights", []):
		var o = OmniLight3D.new(); o.position = MapBuilder.v3(l.pos); o.light_color = _col(l.get("color", [1, 0.85, 0.65])); o.omni_range = float(l.get("range", 8)); o.light_energy = float(l.get("energy", 1.2)); o.shadow_enabled = false; add_child(o)

func _col(a) -> Color: return Color(float(a[0]), float(a[1]), float(a[2]))

# ------------------------------------------------------------------ zonas y navegación
func _build_zones(map_root: Node3D) -> void:
	for z in cfg.get("zones", []):
		var boxes = []
		for b in z.boxes: boxes.append(AABB(Vector3(b[0], b[1], b[2]), Vector3(b[3] - b[0], b[4] - b[1], b[5] - b[2])))
		var sps = []
		for s in z.get("spawns", []): sps.append(MapBuilder.v3(s))
		zones[z.id] = { "open": z.get("open", false), "boxes": boxes, "spawns": sps, "name": z.get("name", z.id) }
	for b in MapBuilder.nav_boxes(cfg):
		var path = "res://assets/maps/%s/nav/%s.res" % [map_id, b.id]
		if not ResourceLoader.exists(path): continue
		var r = NavigationRegion3D.new(); r.navigation_mesh = load(path); add_child(r)
		nav_regions[b.id] = r
	_update_nav()
	# piezas del mapa que se esconden al abrir cada puerta (verjas que se abren)
	var i = 0
	for d in cfg.get("doors", []):
		var list = []
		for pat in d.get("hide_meshes", []):
			for m in map_root.find_children("*", "MeshInstance3D", true, false):
				if String(map_root.get_path_to(m)).contains(pat): list.append(m)
		hide_nodes[i] = list; i += 1

func _update_nav() -> void:
	for id in nav_regions:
		var r: NavigationRegion3D = nav_regions[id]
		if id.begins_with("door_"):
			var di = int(id.substr(5)); r.enabled = di < doors.size() and doors[di].open
		else:
			var zid: String = id.rsplit("_", true, 1)[0]
			r.enabled = zones.has(zid) and zones[zid].open

func door_hide_nodes(i: int) -> Array: return hide_nodes.get(i, [])

func on_door_opened(i: int, opens: Array) -> void:
	for z in opens:
		if zones.has(z) and not zones[z].open:
			zones[z].open = true; hud.banner(zones[z].name.to_upper(), "", 1.6)
	_update_nav()

func zone_at(p: Vector3) -> String:
	for id in zones:
		for b in zones[id].boxes:
			if b.grow(0.3).has_point(p + Vector3(0, 0.5, 0)): return id
	return ""

# ------------------------------------------------------------------ elementos
func _build_interactables() -> void:
	for w in cfg.get("wallbuys", []):
		var n = Interactables.WallBuy.new(); add_child(n); n.global_position = MapBuilder.v3(w.pos); n.rotation_degrees.y = float(w.yaw); n.build(self, w.gun); interactables.append(n)
	for p in cfg.get("perks", []):
		var n = Interactables.Perk.new(); add_child(n); n.global_position = MapBuilder.v3(p.pos); n.rotation_degrees.y = float(p.yaw); n.build(self, p.id, float(PERK_YAW.get(p.id, 0))); interactables.append(n)
	if cfg.has("box"):
		var n = Interactables.MysteryBox.new(); add_child(n); n.build(self, cfg.box, int(cfg.get("box_start", 0))); interactables.append(n)
	if cfg.has("pap"):
		var n = Interactables.PackAPunch.new(); add_child(n); n.global_position = MapBuilder.v3(cfg.pap.pos); n.rotation_degrees.y = float(cfg.pap.yaw); n.build(self); interactables.append(n)
	if cfg.has("power"):
		var n = Interactables.Power.new(); add_child(n); n.global_position = MapBuilder.v3(cfg.power.pos); n.rotation_degrees.y = float(cfg.power.yaw); n.build(self); interactables.append(n)
	else: power_on = true
	var i = 0
	for d in cfg.get("doors", []):
		var n = Interactables.Door.new(); add_child(n); n.build(self, i, d); doors.append(n); interactables.append(n); i += 1

# hacia dónde mira de fábrica el frente de cada máquina (para que el cartel quede al frente)
const PERK_YAW := { "jugg": 0, "revive": 0, "speed": 0, "dtap": 0, "mule": 0, "stamin": 0 }

func find_interactable(p: Player) -> Node:
	var best: Node = null; var bd = 99.0
	for it in interactables:
		if not is_instance_valid(it) or not it.can_use(p): continue
		var d = (it.global_position - p.global_position).length()
		var tp: String = it.prompt(p)
		if tp != "" and d < bd: bd = d; best = it
	return best

func turn_power_on() -> void:
	power_on = true; hud.banner("CORRIENTE ENCENDIDA", "Las máquinas ya funcionan", 3.0); Sfx.play("powerup", 1.0, 0.5)

# ------------------------------------------------------------------ rondas (como en Black Ops)
static func round_count(r: int) -> int:
	if r <= 5: return [6, 8, 13, 18, 24][r - 1]
	return int(24 + (r - 5) * 3.2 + max(0, r - 15) * 2)
static func round_hp(r: int) -> float:
	if r < 10: return 150.0 + 100.0 * (r - 1)
	return 950.0 * pow(1.1, r - 9)
static func round_speed(r: int) -> float:
	var x = randf()
	if r <= 2: return randf_range(0.6, 0.95)
	if r <= 4: return randf_range(0.5, 0.9) if x < 0.55 else randf_range(1.7, 2.3)
	if r <= 8: return randf_range(0.6, 0.9) if x < 0.2 else randf_range(1.9, 2.8)
	return randf_range(2.3, 2.9) if x < 0.35 else randf_range(2.9, 3.6)

func _next_round() -> void:
	round_n += 1; to_spawn = round_count(round_n); spawn_t = 1.0; drops = 0
	hud.set_round(round_n, true)
	Sfx.play("z_roar3", 0.9, 0.7)

func _process(delta: float) -> void:
	if paused or not player: return
	if Controls.was_pressed("pause"): pause(true)
	time += delta
	insta = max(0.0, insta - delta); dpoints = max(0.0, dpoints - delta); fire_sale = max(0.0, fire_sale - delta)
	hud.update_timers(insta, dpoints, fire_sale)
	if break_t > 0.0:
		break_t -= delta
		if break_t <= 0.0: _next_round()
		return
	zombies = zombies.filter(func(z): return is_instance_valid(z))
	var alive = zombies.filter(func(z): return not z.dead).size()
	if to_spawn > 0:
		spawn_t -= delta
		if spawn_t <= 0.0 and alive < max_alive:
			if _spawn_zombie(): to_spawn -= 1
			spawn_t = max(0.35, 2.2 - round_n * 0.12) * randf_range(0.7, 1.2)
	elif alive == 0:
		break_t = 9.0; hud.set_round(round_n, false); Sfx.play("z_roar1", 0.5, 0.5)
		player.refill_grenades()

func _spawn_zombie() -> bool:
	var pz = zone_at(player.global_position)
	var cands = []
	for id in zones:
		if not zones[id].open: continue
		for s in zones[id].spawns:
			var d: float = s.distance_to(player.global_position)
			if d < 8.0 or d > 32.0: continue
			var w = 3.0 if id == pz else 1.0
			if not _visible_from_player(s + Vector3(0, 1.2, 0)): w *= 2.0
			cands.append([s, w / (1.0 + abs(d - 15.0) * 0.12)])
	if cands.is_empty(): return false
	var tot = 0.0
	for c in cands: tot += c[1]
	var r = randf() * tot; var pos: Vector3 = cands[0][0]
	for c in cands:
		r -= c[1]
		if r <= 0.0: pos = c[0]; break
	pos += Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
	var z = Zombie.new()
	add_child(z)
	z.setup(self, "a" if randf() < 0.5 else "c", pos, round_hp(round_n), round_speed(round_n))
	zombies.append(z)
	return true

func _visible_from_player(p: Vector3) -> bool:
	var to = p - player.cam.global_position
	if to.normalized().dot(-player.cam.global_transform.basis.z) < 0.5: return false
	return ray_world(player.cam.global_position, to.normalized(), to.length()) == Vector3.INF

# ------------------------------------------------------------------ disparos
## rayo de bala: atraviesa vallas y cristal, se para en muros y zombis
func shoot_ray(from: Vector3, dir: Vector3, rng: float, by: Player) -> Dictionary:
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(from, from + dir * rng, MapBuilder.LAYER_WORLD | MapBuilder.LAYER_ZOMBIE | MapBuilder.LAYER_BARRIER)
	q.exclude = [by.get_rid()]
	var res = space.intersect_ray(q)
	var out = { "hit": false, "kill": false, "head": false }
	if res.is_empty(): return out
	var col = res.collider
	if col is Zombie:
		var z: Zombie = col
		var hp_pos = z.head_pos()
		var head: bool = res.position.distance_to(hp_pos) < 0.24 or res.position.y > hp_pos.y - 0.08
		var w = by.cur_w()
		var dmg = float(Player.stat_of(w.id, w.pap, "dmg"))
		if head: dmg *= float(Player.stat_of(w.id, w.pap, "head"))
		if insta > 0.0: dmg = 1e9
		var k = z.take_hit(dmg, res.position, head, by)
		out.hit = true; out.kill = k; out.head = head
	else:
		impact(res.position, res.normal)
	return out

func ray_world(from: Vector3, dir: Vector3, rng: float) -> Vector3:
	var q = PhysicsRayQueryParameters3D.create(from, from + dir * rng, MapBuilder.LAYER_WORLD | MapBuilder.LAYER_BARRIER)
	var res = get_world_3d().direct_space_state.intersect_ray(q)
	return Vector3.INF if res.is_empty() else res.position

func zombie_under_crosshair(cam: Camera3D, rng: float) -> bool:
	var from = cam.global_position; var dir = -cam.global_transform.basis.z
	for z in zombies:
		if not is_instance_valid(z) or z.dead: continue
		var c: Vector3 = z.global_position + Vector3(0, 1.2, 0)
		var to = c - from; var d = to.length()
		if d > rng: continue
		if to.normalized().dot(dir) > cos(atan2(0.5, d)): return true
	return false

func nearest_zombie(p: Vector3, r: float) -> Zombie:
	var best: Zombie = null; var bd = r
	for z in zombies:
		if is_instance_valid(z) and not z.dead:
			var d: float = (z.global_position + Vector3(0, 1, 0)).distance_to(p)
			if d < bd: bd = d; best = z
	return best

func on_zombie_hurt(_z: Zombie, by: Node, kind: String) -> void:
	if by is Player and kind == "bullet": by.add_points(10 * (2 if dpoints > 0 else 1))

func on_zombie_killed(z: Zombie, head: bool, by: Node, kind: String) -> void:
	if by is Player:
		var pts = 130 if kind == "knife" else (100 if head else 60)
		by.add_points(pts * (2 if dpoints > 0 else 1))
		by.kills += 1
		if head: by.headshots += 1
		if kind == "bullet": GS.add_kill(by.cur_w().id)
	if drops < 4 and randf() < 0.035: _drop_powerup(z.global_position)

# ------------------------------------------------------------------ explosiones y granadas
func explode(at: Vector3, radius: float, dmg: float, by: Node) -> void:
	for z in zombies:
		if is_instance_valid(z) and not z.dead and z.global_position.distance_to(at) < radius:
			z.take_hit(dmg if insta <= 0 else 1e9, z.global_position + Vector3(0, 1, 0), false, by, "explo")
	Fx.explosion(self, at)
	Sfx.play_at("shot_rifle", at, 1.0, 0.45)

func throw_grenade(from: Vector3, vel: Vector3, by: Node) -> void:
	var g = RigidBody3D.new(); g.collision_layer = 0; g.collision_mask = MapBuilder.LAYER_WORLD | MapBuilder.LAYER_SOFT | MapBuilder.LAYER_BARRIER
	g.mass = 0.4; g.physics_material_override = PhysicsMaterial.new(); g.physics_material_override.bounce = 0.35
	var cs = CollisionShape3D.new(); var sp = SphereShape3D.new(); sp.radius = 0.06; cs.shape = sp; g.add_child(cs)
	var m = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 0.06; sm.height = 0.12; m.mesh = sm
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.25, 0.3, 0.2); mat.roughness = 0.6; m.material_override = mat; g.add_child(m)
	add_child(g); g.global_position = from; g.linear_velocity = vel
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(g): explode(g.global_position, 4.5, 400.0 + round_n * 60.0, by); g.queue_free())

# ------------------------------------------------------------------ potenciadores
func _drop_powerup(at: Vector3) -> void:
	drops += 1
	var kind: String = Data.POWERUPS[randi() % Data.POWERUPS.size()]
	var pu = preload("res://scripts/powerup.gd").new(); pu.game = self; pu.kind = kind; add_child(pu); pu.global_position = at + Vector3(0, 0.9, 0)

func apply_powerup(kind: String) -> void:
	hud.banner(Data.POWERUP_NAMES[kind], "", 2.0); Sfx.play("powerup", 1.0)
	match kind:
		"max_ammo": player.refill_ammo()
		"insta_kill": insta = 30.0
		"double_points": dpoints = 30.0
		"fire_sale": fire_sale = 30.0
		"nuke":
			for z in zombies:
				if is_instance_valid(z) and not z.dead: z.take_hit(1e9, z.global_position + Vector3(0, 1, 0), false, null, "nuke")
			player.add_points(400)
			hud.white_flash()
		"carpenter": player.add_points(200)

# ------------------------------------------------------------------ efectos
func blood(at: Vector3, head: bool) -> void: Fx.blood(self, at, head)
func impact(at: Vector3, n: Vector3) -> void: Fx.impact(self, at, n)
func dust(at: Vector3) -> void: Fx.dust(self, at)

# ------------------------------------------------------------------ pausa y fin
func pause(on: bool) -> void:
	paused = on; get_tree().paused = on; hud.show_pause(on)

func _on_player_died() -> void:
	var stats = { "map": map_id, "round": round_n, "kills": player.kills, "heads": player.headshots, "time": time, "points": player.points }
	var xp = player.kills * 10 + player.headshots * 5 + round_n * 100
	stats["xp"] = xp; stats["levels"] = GS.add_xp(xp)
	if round_n > int(GS.best.get(map_id, 0)): GS.best[map_id] = round_n; stats["record"] = true
	GS.save_game()
	hud.show_game_over(stats)
	finished.emit(stats)
