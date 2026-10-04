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
	if e.has("ambient_color"): env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = _col(e.ambient_color); env.ambient_light_energy = float(e.get("ambient", 1.0))
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
	var lp = "res://assets/maps/%s/nav/lights.json" % map_id
	if FileAccess.file_exists(lp):
		for c in JSON.parse_string(FileAccess.open(lp, FileAccess.READ).get_as_text()):
			var o = OmniLight3D.new(); o.position = Vector3(c[0], c[1], c[2]); o.light_color = Color(1.0, 0.74, 0.5); o.omni_range = 10.0; o.light_energy = 2.4; o.omni_attenuation = 1.2; add_child(o)
	for l in cfg.get("lights", []):
		var o = OmniLight3D.new(); o.position = MapBuilder.v3(l.pos); o.light_color = _col(l.get("color", [1, 0.85, 0.65])); o.omni_range = float(l.get("range", 8)); o.light_energy = float(l.get("energy", 1.2)); o.shadow_enabled = false; add_child(o)

func _col(a) -> Color: return Color(float(a[0]), float(a[1]), float(a[2]))

# ------------------------------------------------------------------ zonas y navegación
var rooms = {}               # salas automáticas (mapas por habitaciones)
var door_links = []          # enlaces de navegación de cada puerta
func _build_zones(map_root: Node3D) -> void:
	if cfg.has("auto_zones"): _build_rooms(map_root); return
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

func _build_rooms(map_root: Node3D) -> void:
	var f = FileAccess.open("res://assets/maps/%s/nav/rooms.json" % map_id, FileAccess.READ)
	rooms = JSON.parse_string(f.get_as_text())
	var names = cfg.get("room_names", {}); var starts = cfg.get("start_rooms", [])
	for k in rooms.rooms.size():
		var r = rooms.rooms[k]; var rid: String = r.id
		var b = r.box
		var reg = NavigationRegion3D.new(); reg.navigation_mesh = load("res://assets/maps/%s/nav/room_%d.res" % [map_id, k]); add_child(reg)
		nav_regions[rid] = reg
		zones[rid] = { "open": rid in starts, "boxes": [AABB(Vector3(b[0], b[1] - 0.5, b[2]), Vector3(b[3] - b[0], b[4] - b[1] + 2.5, b[5] - b[2]))], "spawns": [], "name": names.get(rid, ""), "region": reg, "area": r.area, "playable": names.has(rid) }
	var i = 0
	for d in cfg.get("doors", []):
		var info = rooms.doors[i] if i < rooms.doors.size() else {}
		var hide = []
		for pat in d.get("hide_meshes", []):
			for m in map_root.find_children("*", "MeshInstance3D", true, false):
				if String(map_root.get_path_to(m)).contains(pat): hide.append(m)
		hide_nodes[i] = hide
		var link = NavigationLink3D.new(); link.bidirectional = true; link.enabled = false
		if info.has("a"): link.start_position = MapBuilder.v3(info.a); link.end_position = MapBuilder.v3(info.b)
		add_child(link); door_links.append(link)
		i += 1

func _update_nav() -> void:
	if cfg.has("auto_zones"):
		for id in nav_regions: nav_regions[id].enabled = zones[id].open
		for k in door_links.size(): door_links[k].enabled = k < doors.size() and doors[k].open
		return
	for id in nav_regions:
		var r: NavigationRegion3D = nav_regions[id]
		if id.begins_with("door_"):
			var di = int(id.substr(5)); r.enabled = di < doors.size() and doors[di].open
		else:
			var zid: String = id.rsplit("_", true, 1)[0]
			r.enabled = zones.has(zid) and zones[zid].open

func door_hide_nodes(i: int) -> Array: return hide_nodes.get(i, [])

func on_door_opened(i: int, opens: Array, silent = false) -> void:
	for z in opens:
		if zones.has(z) and not zones[z].open:
			zones[z].open = true
			if not silent and zones[z].name != "": hud.banner(zones[z].name.to_upper(), "", 1.6)
	_update_nav()

func zone_at(p: Vector3) -> String:
	for id in zones:
		for b in zones[id].boxes:
			if b.grow(0.3).has_point(p + Vector3(0, 0.5, 0)): return id
	return ""

# ------------------------------------------------------------------ elementos
## coloca un elemento pegado a la pared más cercana a "near" (mirando hacia la sala) en el suelo real
func place(spec: Dictionary, depth: float) -> Dictionary:
	if not spec.has("near"): return { "pos": MapBuilder.v3(spec.pos), "yaw": float(spec.get("yaw", 0)) }
	var n = spec.near; var y = float(spec.get("y", 0.0))
	var space = get_world_3d().direct_space_state
	var top = Vector3(float(n[0]), y + 1.6, float(n[1]))
	var q = PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 4, 0), MapBuilder.LAYER_WORLD)
	var hit = space.intersect_ray(q)
	var floor_y = hit.position.y if not hit.is_empty() else y
	var origin = Vector3(top.x, floor_y + 1.2, top.z)
	var best = {}; var bd = 99.0
	for k in 24:
		var a = k * TAU / 24.0; var dir = Vector3(sin(a), 0, cos(a))
		var h = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * 3.5, MapBuilder.LAYER_WORLD))
		if not h.is_empty():
			var d = origin.distance_to(h.position)
			if d < bd and abs(h.normal.y) < 0.3: bd = d; best = h
	if best.is_empty(): return { "pos": Vector3(top.x, floor_y, top.z), "yaw": float(spec.get("yaw", 0)) }
	var nrm: Vector3 = best.normal; nrm.y = 0; nrm = nrm.normalized()
	var pos = Vector3(best.position.x, floor_y, best.position.z) + nrm * depth
	if spec.has("wall_y"): pos.y = floor_y + float(spec.wall_y)
	return { "pos": pos, "yaw": rad_to_deg(atan2(nrm.x, nrm.z)) }

func _build_interactables() -> void:
	for w in cfg.get("wallbuys", []):
		var pl = place(w if w.has("pos") or not w.has("near") else w.merged({ "wall_y": 1.45 }), 0.02)
		var n = Interactables.WallBuy.new(); add_child(n); n.global_position = pl.pos; n.rotation_degrees.y = pl.yaw; n.build(self, w.gun); interactables.append(n)
	for p in cfg.get("perks", []):
		var pl = place(p, 0.5)
		var n = Interactables.Perk.new(); add_child(n); n.global_position = pl.pos; n.rotation_degrees.y = pl.yaw; n.build(self, p.id, float(PERK_YAW.get(p.id, 0))); interactables.append(n)
	if cfg.has("box"):
		var spots = []
		for b in cfg.box: var pl = place(b, 0.45); spots.append({ "pos": [pl.pos.x, pl.pos.y, pl.pos.z], "yaw": pl.yaw })
		var n = Interactables.MysteryBox.new(); add_child(n); n.build(self, spots, int(cfg.get("box_start", 0))); interactables.append(n)
	if cfg.has("pap"):
		var pl = place(cfg.pap, 0.6)
		var n = Interactables.PackAPunch.new(); add_child(n); n.global_position = pl.pos; n.rotation_degrees.y = pl.yaw; n.build(self); interactables.append(n)
	if cfg.has("power"):
		var pl = place(cfg.power, 0.08)
		var n = Interactables.Power.new(); add_child(n); n.global_position = pl.pos; n.rotation_degrees.y = pl.yaw; n.build(self); interactables.append(n)
	else: power_on = true
	var i = 0
	for d in cfg.get("doors", []):
		var dd = d.duplicate()
		if cfg.has("auto_zones"):
			var info = rooms.doors[i] if i < rooms.doors.size() else {}
			if info.has("center"):
				dd.pos = info.center; dd.size = [info.width + 0.3, info.height, 1.0]; dd.yaw = 90 if abs(info.normal[0]) > 0.5 else 0
				dd.opens = [info.ra, info.rb]; dd.kind = "hide"; dd.auto = true
		var n = Interactables.Door.new(); add_child(n); n.build(self, i, dd); doors.append(n)
		if dd.get("free", false): n.open_now(true)
		elif dd.get("locked", false): pass
		else: interactables.append(n)
		i += 1
	_update_nav()

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
	if cfg.has("auto_zones"): return _spawn_in_rooms()
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
	if cands.is_empty():   # sala pequeña: entran por las ventanas aunque estén cerca, o aparecen en cualquier sitio de la zona
		for id in zones:
			if not zones[id].open: continue
			for s2 in zones[id].spawns:
				if s2.distance_to(player.global_position) >= 3.5: cands.append([s2, 1.0])
			if cands.is_empty() and nav_regions.has(id + "_0"):
				var p2 = NavigationServer3D.region_get_random_point(nav_regions[id + "_0"].get_rid(), 1, true)
				if p2.distance_to(player.global_position) >= 5.0: cands.append([p2, 1.0])
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

func _spawn_in_rooms() -> bool:
	var pz = zone_at(player.global_position)
	var opts = []
	for id in zones:
		if zones[id].open and zones[id].playable: opts.append([id, zones[id].area * (3.0 if id == pz else 1.0)])
	if opts.is_empty(): return false
	for attempt in 14:
		var tot = 0.0
		for o in opts: tot += o[1]
		var r = randf() * tot; var pick = opts[0][0]
		for o in opts:
			r -= o[1]
			if r <= 0.0: pick = o[0]; break
		var reg: NavigationRegion3D = zones[pick].region
		var p = NavigationServer3D.region_get_random_point(reg.get_rid(), 1, true)
		var d = p.distance_to(player.global_position)
		if d < 7.0 or d > 30.0: continue
		if _visible_from_player(p + Vector3(0, 1.2, 0)) and attempt < 10: continue
		if not _reachable(p): continue
		var z = Zombie.new(); add_child(z)
		z.setup(self, "a" if randf() < 0.5 else "c", p + Vector3(0, 0.05, 0), round_hp(round_n), round_speed(round_n))
		zombies.append(z); return true
	return false

## hay camino de verdad desde ese punto hasta el jugador (descarta huecos bajo el suelo y rincones sueltos)
func _reachable(p: Vector3) -> bool:
	var map = get_world_3d().navigation_map
	var path = NavigationServer3D.map_get_path(map, p, player.global_position, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(player.global_position) < 1.8

func respawn_zombie(z: Zombie) -> void:
	var n = zombies.size()
	if _spawn_zombie():
		var nz: Zombie = zombies[zombies.size() - 1]
		nz.hp = z.hp; nz.max_speed = z.max_speed
		zombies.erase(z); z.queue_free()

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
