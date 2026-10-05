extends Node3D
## Una partida: mapa, zonas y navegación, jugadores (también en cooperativo por wifi), rondas (con rondas de perros,
## Brutos e Hinchados), zombis, armas maravilla, chicles, potenciadores, easter egg, canción oculta y fin de partida.
## En cooperativo el servidor manda en el mundo y avisa a los demás con eventos (ver net.gd).

signal finished(stats: Dictionary)

var cfg: Dictionary
var map_id = ""
var player: Player
var remotes = {}               # peer -> RemotePlayer
var hud: Node
var paused = false
var over = false
var level0 = 1
var completed = []          # desafíos completados en esta partida
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
var zmap = {}                  # zid -> Zombie
var next_zid = 1
var round_n = 0
var to_spawn = 0
var spawn_t = 0.0
var break_t = 0.0
var started = false
var drops = 0
var time = 0.0
var max_alive = 24
var hide_nodes = {}            # puerta -> nodos del mapa que se esconden al abrirla
var env: Environment
var sun: DirectionalLight3D
# rondas especiales
var dog_round = false
var next_dog_round = 0
var brutes_left = 0
var pending = {}               # peticiones al servidor esperando respuesta: "idx:acción" -> callback
var pus = {}                   # potenciadores en el suelo: id -> nodo
var next_pu = 1
var gum_uses = 0
var low_quality = false
var base_scale = 1.0
var dyn_scale = 1.0          # resolución dinámica: baja sola si los fps caen
var fps_acc = 0.0
var fps_frames = 0               # chicles comprados esta ronda

func start(id: String) -> void:
	map_id = id
	cfg = MapBuilder.load_config(id)
	_build_environment()
	var root = MapBuilder.build_scene(cfg, self)
	_build_zones(root)
	_build_interactables()
	player = Player.new(); player.game = self; add_child(player)
	var sp = cfg.spawn
	var my_slot = 0
	if Net.active:
		Net.game = self
		var ids = Net.players.keys(); ids.sort()
		my_slot = ids.find(Net.my_id())
		for pid in ids:
			if pid == Net.my_id(): continue
			var rp = RemotePlayer.new(); rp.peer = pid; rp.pname = Net.players[pid].name; rp.character = Net.players[pid].character; rp.game = self
			add_child(rp); remotes[pid] = rp
			rp.global_position = _slot_pos(sp, ids.find(pid))
	player.global_position = _slot_pos(sp, my_slot); player.yaw = deg_to_rad(float(sp[3]) if sp.size() > 3 else 0.0)
	hud = preload("res://scripts/hud.gd").new(); hud.game = self; add_child(hud)
	player.setup(GS.start_weapon, GS.start_perk)
	player.points = 500 + (GS.start_round - 1) * 450 + GS.start_points_bonus()
	level0 = GS.level
	stat("games")
	player.died.connect(_on_player_died)
	player.points_changed.connect(func(p, dl): hud.update_points(p, dl))
	hud.update_points(player.points, 0); hud.update_ammo(); hud.update_perks(player.perks)
	Sfx.play_ambient(cfg.get("ambient", "amb1"))
	Sfx.music_map(map_id)
	round_n = GS.start_round - 1
	next_dog_round = max(round_n + 1, 0) + randi_range(5, 7)
	if not Net.active: all_loaded()
	elif Net.is_host(): Net.loaded()
	else: Net.loaded.rpc_id(1)

## posición de salida de cada jugador (en círculo alrededor del punto de inicio)
func _slot_pos(sp: Array, slot: int) -> Vector3:
	var base = MapBuilder.v3(sp)
	if slot <= 0: return base
	var a = slot * TAU / 4.0
	var p = base + Vector3(cos(a), 0, sin(a)) * 1.3
	var map = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		var q = NavigationServer3D.map_get_closest_point(map, p)
		if q.distance_to(p) < 1.0: return q + Vector3(0, 0.1, 0)
	return p

## todos han cargado: el servidor arranca las rondas y prepara el easter egg
func all_loaded() -> void:
	if not Net.is_host(): return
	started = true
	break_t = 2.5
	_egg_setup()

func _host() -> bool: return Net.is_host()

## manda un evento del mundo a todos (y lo aplica aquí)
func evt(name: String, data: Variant = null) -> void:
	if Net.active: Net.world_evt.rpc(name, data)
	else: on_world_evt(name, data)

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
	apply_quality(env)
	var sun = DirectionalLight3D.new(); sun.light_color = _col(e.get("sun_color", [1.0, 0.92, 0.8])); sun.light_energy = float(e.get("sun", 1.1))
	var sr: Array = e.get("sun_rot", [-42, 35]); sun.rotation_degrees = Vector3(sr[0], sr[1], 0)
	# sombras: 4 cascadas mezcladas, suaves y no del todo negras
	sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS; sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_split_1 = 0.08; sun.directional_shadow_split_2 = 0.22; sun.directional_shadow_split_3 = 0.5; sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.2; sun.shadow_bias = 0.04; sun.shadow_normal_bias = 1.5; sun.shadow_opacity = 0.82
	sun.directional_shadow_pancake_size = 30.0
	var q = GS.settings.get("quality", "alta")
	sun.shadow_enabled = q != "baja"
	if q == "media": sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; sun.directional_shadow_max_distance = 40.0; sun.directional_shadow_split_1 = 0.2
	self.sun = sun
	add_child(sun)
	var lp = "res://assets/maps/%s/nav/lights.json" % map_id
	if FileAccess.file_exists(lp):
		for c in JSON.parse_string(FileAccess.open(lp, FileAccess.READ).get_as_text()):
			var o = OmniLight3D.new(); o.position = Vector3(c[0], c[1], c[2]); o.light_color = Color(1.0, 0.74, 0.5); o.omni_range = 10.0; o.light_energy = 2.4; o.omni_attenuation = 1.2; add_child(o)
	for l in cfg.get("lights", []):
		var o = OmniLight3D.new(); o.position = MapBuilder.v3(l.pos); o.light_color = _col(l.get("color", [1, 0.85, 0.65])); o.omni_range = float(l.get("range", 8)); o.light_energy = float(l.get("energy", 1.2)); o.shadow_enabled = false; add_child(o)
		if l.get("color", [1, 1, 1])[2] < 0.3: fire_lights.append([o, o.light_energy, randf() * 10.0])   # luz de fuego: parpadea
	# fuegos (coches quemados, la grieta de lava)
	for f in cfg.get("fires", []): Fx.fire(self, MapBuilder.v3(f), 1.0)

## resolución dinámica: cada 2 s mira los fps; por debajo de ~50 baja la resolución 3D (hasta el 55 %), y la sube si va sobrado
func _dynamic_resolution(delta: float) -> void:
	fps_acc += delta; fps_frames += 1
	if fps_acc < 2.0: return
	var fps = fps_frames / fps_acc; fps_acc = 0.0; fps_frames = 0
	var target = 58.0 if OS.has_feature("mobile") else 55.0
	if fps < target - 8.0 and dyn_scale > 0.55: dyn_scale = max(0.55, dyn_scale - 0.1)
	elif fps > target + 1.0 and dyn_scale < 1.0: dyn_scale = min(1.0, dyn_scale + 0.05)
	else: return
	var vp = get_viewport()
	vp.scaling_3d_scale = base_scale * dyn_scale
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if vp.scaling_3d_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR

## calidad gráfica: escala de render, suavizado, sombras y resplandor (alta / media / baja)
func apply_quality(e: Environment) -> void:
	var q = GS.settings.get("quality", "alta")
	low_quality = q == "baja"
	var vp = get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q != "alta" else Viewport.SCALING_3D_MODE_BILINEAR
	base_scale = { "alta": 1.0, "media": 0.8, "baja": 0.62 }[q]
	dyn_scale = 1.0
	vp.scaling_3d_scale = base_scale
	vp.mesh_lod_threshold = { "alta": 1.0, "media": 2.5, "baja": 5.0 }[q]   # modelos simplificados antes cuanto más baja la calidad
	var pc = not OS.has_feature("mobile")
	vp.msaa_3d = (Viewport.MSAA_2X if pc else Viewport.MSAA_4X) if q == "alta" else (Viewport.MSAA_2X if q == "media" and not pc else Viewport.MSAA_DISABLED)   # en GPUs de móvil el MSAA sale barato; en PC con resoluciones altas, no
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == "media" else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(4096 if q == "alta" else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if q == "alta" else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	if sun:
		sun.shadow_enabled = q != "baja"
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q == "alta" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	e.glow_enabled = q != "baja"
	Engine.max_fps = 60 if OS.has_feature("mobile") else 0   # en PC manda la sincronización vertical

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
	# máquina de chicles (cerca de la salida si el mapa no dice dónde)
	var gp: Dictionary = cfg.get("gum", { "near": [float(cfg.spawn[0]) - 2.5, float(cfg.spawn[2]) - 1.5], "y": float(cfg.spawn[1]) })
	var plg = place(gp, 0.35)
	var gm = Interactables.GumMachine.new(); add_child(gm); gm.global_position = plg.pos; gm.rotation_degrees.y = plg.yaw; gm.build(self); interactables.append(gm)
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
	# solo lo que está a tu altura (no se compra desde el piso de arriba) y sin una pared en medio
	var best: Node = null; var bd = 99.0
	for it in interactables + egg_nodes:
		if not is_instance_valid(it): continue
		var dv: Vector3 = it.global_position - p.global_position
		if abs(dv.x) > 6.0 or abs(dv.z) > 6.0 or dv.y < -1.6 or dv.y > 2.6: continue
		if not it.can_use(p): continue
		var d = Vector2(dv.x, dv.z).length()
		if d < bd and it.prompt(p) != "": bd = d; best = it
	if best and not (best is Interactables.Door):
		var from = p.global_position + Vector3(0, 1.3, 0)
		var to: Vector3 = best.global_position + Vector3(0, 0.6, 0)
		var dir = to - from; var L = dir.length()
		if L > 0.5:
			var h = ray_world(from, dir / L, L)
			# vale si no hay nada o si lo que toca es la propia máquina o la pared donde está
			if h != Vector3.INF and Vector2(h.x - to.x, h.z - to.z).length() > 1.1: return null
	return best

func turn_power_on() -> void:
	if power_on: return
	power_on = true; hud.banner("CORRIENTE ENCENDIDA", "Las máquinas ya funcionan", 3.0); Sfx.play("powerup", 1.0, 0.5)
	Voice.say("power")

# ------------------------------------------------------------------ jugadores (local y compañeros)
## todos los que pueden ser objetivo de los zombis
func all_players() -> Array:
	var out: Array = [player]
	for k in remotes: out.append(remotes[k])
	return out

func target_for(from: Vector3) -> Node3D:
	var best: Node3D = null; var bd = INF
	for p in all_players():
		if not p.alive or p.downed: continue
		var d = p.global_position.distance_squared_to(from)
		if d < bd: bd = d; best = p
	return best

func can_attack(p: Node3D) -> bool: return p != null and p.alive and not p.downed

var fire_lights = []
var burn_t = 0.0
var lava_toast_t = -99.0
## zonas que queman (la lava del cruce del Pueblo): solo a quien la pisa, no a los zombis
func _hazards(delta: float) -> void:
	var hz: Array = cfg.get("hazards", [])
	if hz.is_empty() or not player.alive or player.downed or not player.is_on_floor(): burn_t = 0.0; return
	var p = Vector2(player.global_position.x, player.global_position.z)
	for h in hz:
		var a = Vector2(h.a[0], h.a[1]); var b = Vector2(h.b[0], h.b[1])
		var q = Geometry2D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(q) < float(h.r):
			burn_t -= delta
			if burn_t <= 0.0:
				burn_t = 0.5
				player.take_damage(12.0)
				Fx.fire_puff(self, player.global_position + Vector3(0, 0.3, 0))
				if time - lava_toast_t > 8.0: lava_toast_t = time; hud.toast("¡QUEMA!", "La lava del cruce hace daño: no la pises.")
			return
	burn_t = 0.0

func damage_player(p: Node3D, dmg: float) -> void:
	if p == player: player.take_damage(dmg)
	elif p is RemotePlayer: Net.hurt.rpc_id(p.peer, dmg)

func downed_friend_near(at: Vector3) -> RemotePlayer:
	for k in remotes:
		var r: RemotePlayer = remotes[k]
		if r.alive and r.downed and r.global_position.distance_to(at) < 2.0: return r
	return null

func on_remote_state(peer: int, pos: Vector3, yaw: float, pitch: float, flags: int, wid: String, hp: float) -> void:
	if remotes.has(peer): remotes[peer].net_state(pos, yaw, pitch, flags, wid, hp)

func on_remote_shot(peer: int, sound: String, pitch: float) -> void:
	if remotes.has(peer):
		Sfx.play_at(sound, remotes[peer].global_position + Vector3(0, 1.2, 0), 0.8, pitch)
		remotes[peer].muzzle()

func remove_remote(peer: int) -> void:
	if remotes.has(peer):
		hud.toast("COOPERATIVO", "%s ha salido de la partida" % remotes[peer].pname)
		remotes[peer].queue_free(); remotes.erase(peer)
		if _host(): _check_all_down()

## un jugador cae, se levanta o muere
func on_life(peer: int, state: String) -> void:
	if peer != Net.my_id() and remotes.has(peer):
		var r: RemotePlayer = remotes[peer]
		r.downed = state == "down"; r.alive = state != "dead"
		if state == "down": hud.toast("¡COMPAÑERO CAÍDO!", "%s necesita ayuda" % r.pname)
	if _host(): _check_all_down()

## si no queda nadie en pie, se acaba la partida para todos
func _check_all_down() -> void:
	if over or not started: return
	for p in all_players():
		if p.alive and not p.downed: return
	if Net.active: Net.game_over.rpc()
	else: on_game_over()

var ending = false
func on_game_over() -> void:
	if over: return
	ending = true
	_on_player_died()

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

func _nplayers() -> int: return all_players().size()

## servidor: empieza la ronda siguiente (con perros cada pocas rondas y Brutos a partir de la 8)
func _next_round() -> void:
	round_n += 1; drops = 0
	dog_round = round_n == next_dog_round
	var mult = 1.0 + 0.5 * (_nplayers() - 1)   # más zombis con más jugadores
	if dog_round:
		next_dog_round = round_n + randi_range(4, 6)
		to_spawn = int((6 + round_n * 0.6) * (0.8 + 0.4 * _nplayers()))
	else:
		to_spawn = int(round_count(round_n) * mult)
	brutes_left = 0 if dog_round or round_n < 8 else (1 + (1 if _nplayers() > 2 else 0) if round_n % 4 == 0 else (1 if randf() < 0.25 else 0))
	spawn_t = 1.0 if not dog_round else 4.0
	evt("round", { "n": round_n, "phase": "start", "dogs": dog_round })

func _end_round() -> void:
	break_t = 9.0 if not dog_round else 11.0
	evt("round", { "n": round_n, "phase": "end", "dogs": dog_round })

func _process(delta: float) -> void:
	if not player: return
	_dynamic_resolution(delta)
	if paused and not Net.active: return
	time += delta
	for fl in fire_lights:
		fl[2] += delta * 9.0
		fl[0].light_energy = fl[1] * (0.82 + 0.12 * sin(fl[2]) + 0.08 * sin(fl[2] * 2.3 + 1.0))
	_hazards(delta)
	insta = max(0.0, insta - delta); dpoints = max(0.0, dpoints - delta); fire_sale = max(0.0, fire_sale - delta)
	hud.update_timers(insta, dpoints, fire_sale)
	_egg_process(delta)
	if not _host() or not started or over: return
	if break_t > 0.0:
		break_t -= delta
		if break_t <= 0.0: _next_round()
		return
	zombies = zombies.filter(func(z): return is_instance_valid(z))
	var alive = zombies.filter(func(z): return not z.dead).size()
	if to_spawn > 0:
		spawn_t -= delta
		var cap = max_alive if not dog_round else 2 * _nplayers() + 4
		if spawn_t <= 0.0 and alive < cap:
			if _spawn_zombie(): to_spawn -= 1
			var rate = max(0.35, 2.2 - round_n * 0.12) * randf_range(0.7, 1.2)
			if dog_round: rate = randf_range(1.2, 2.4)
			if egg.step == 4: rate *= 0.5   # defendiendo el easter egg: vienen más rápido
			spawn_t = rate
	elif alive == 0 and egg.step != 4 and egg.step != 5:
		_end_round()

## punto de interés para hacer aparecer zombis: un jugador vivo al azar
func _focus() -> Vector3:
	var list = all_players().filter(func(p): return p.alive and not p.downed)
	if list.is_empty(): return player.global_position
	return list[randi() % list.size()].global_position

func _near_any_player(p: Vector3, r: float) -> bool:
	for pl in all_players():
		if pl.global_position.distance_to(p) < r: return true
	return false

func _spawn_zombie() -> bool:
	var type = "normal"
	if dog_round: type = "dog"
	elif brutes_left > 0 and to_spawn <= max(3, to_spawn / 2): type = "brute"; brutes_left -= 1
	elif round_n >= 6 and randf() < 0.07: type = "bloat"
	var pos = _spawn_point(type)
	if pos == Vector3.INF:
		if type == "brute": brutes_left += 1
		return false
	var hp = round_hp(round_n) * (1.0 + 0.25 * (_nplayers() - 1))
	var speed = round_speed(round_n)
	if type == "dog": speed = 6.5 if round_n > 8 else 5.0
	elif type == "brute": speed = 0.9
	elif type == "bloat": speed = min(speed, 0.85)
	make_zombie("a" if randf() < 0.5 else "c", type, pos, hp, speed)
	return true

## crea un enemigo en el servidor y avisa a los demás
func make_zombie(kind: String, type: String, pos: Vector3, hp: float, speed: float) -> Zombie:
	var z = Zombie.new(); z.zid = next_zid; next_zid += 1
	add_child(z)
	z.setup(self, kind, pos, hp, speed, type)
	zombies.append(z); zmap[z.zid] = z
	if Net.active: Net.z_spawn.rpc(z.zid, kind, type, pos, speed)
	if type == "brute":
		hud.toast("¡CUIDADO!", "Ha aparecido un Bruto"); Sfx.play_at("z_roar3", pos + Vector3(0, 2, 0), 1.0, 0.55)
	return z

func _spawn_point(type: String) -> Vector3:
	var focus = _focus()
	if type == "dog":   # los perros aparecen cerca de los jugadores, con un rayo
		for attempt in 12:
			var p = _random_nav_near(focus, 6.0, 14.0)
			if p != Vector3.INF and not _near_any_player(p, 5.0) and _reachable_from(p, focus): return p
		return Vector3.INF
	if cfg.has("auto_zones"): return _spawn_in_rooms(focus)
	var pz = zone_at(focus)
	var cands = []
	for id in zones:
		if not zones[id].open: continue
		for s in zones[id].spawns:
			var d: float = s.distance_to(focus)
			if d < 8.0 or d > 32.0 or _near_any_player(s, 6.0): continue
			var w = 3.0 if id == pz else 1.0
			if not _visible_from_player(s + Vector3(0, 1.2, 0)): w *= 2.0
			cands.append([s, w / (1.0 + abs(d - 15.0) * 0.12)])
	if cands.is_empty():   # sala pequeña: entran por las ventanas aunque estén cerca, o aparecen en cualquier sitio de la zona
		for id in zones:
			if not zones[id].open: continue
			for s2 in zones[id].spawns:
				if s2.distance_to(focus) >= 3.5: cands.append([s2, 1.0])
			if cands.is_empty() and nav_regions.has(id + "_0"):
				var p2 = NavigationServer3D.region_get_random_point(nav_regions[id + "_0"].get_rid(), 1, true)
				if p2.distance_to(focus) >= 5.0: cands.append([p2, 1.0])
	if cands.is_empty(): return Vector3.INF
	var tot = 0.0
	for c in cands: tot += c[1]
	var r = randf() * tot; var pos: Vector3 = cands[0][0]
	for c in cands:
		r -= c[1]
		if r <= 0.0: pos = c[0]; break
	return pos + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))

func _spawn_in_rooms(focus: Vector3) -> Vector3:
	var pz = zone_at(focus)
	var opts = []
	for id in zones:
		if zones[id].open and zones[id].playable: opts.append([id, zones[id].area * (3.0 if id == pz else 1.0)])
	if opts.is_empty(): return Vector3.INF
	for attempt in 14:
		var tot = 0.0
		for o in opts: tot += o[1]
		var r = randf() * tot; var pick = opts[0][0]
		for o in opts:
			r -= o[1]
			if r <= 0.0: pick = o[0]; break
		var reg: NavigationRegion3D = zones[pick].region
		var p = NavigationServer3D.region_get_random_point(reg.get_rid(), 1, true)
		var d = p.distance_to(focus)
		if d < 7.0 or d > 30.0 or _near_any_player(p, 6.0): continue
		if _visible_from_player(p + Vector3(0, 1.2, 0)) and attempt < 10: continue
		if not _reachable_from(p, focus): continue
		return p + Vector3(0, 0.05, 0)
	return Vector3.INF

## punto transitable al azar entre dos distancias de "c"
func _random_nav_near(c: Vector3, rmin: float, rmax: float) -> Vector3:
	var map = get_world_3d().navigation_map
	for k in 8:
		var a = randf() * TAU; var r = randf_range(rmin, rmax)
		var want = c + Vector3(cos(a) * r, 0, sin(a) * r)
		var q = NavigationServer3D.map_get_closest_point(map, want)
		if q.distance_to(want) < 2.5 and abs(q.y - c.y) < 3.0: return q + Vector3(0, 0.05, 0)
	return Vector3.INF

## hay camino de verdad desde ese punto hasta el jugador (descarta huecos bajo el suelo y rincones sueltos)
func _reachable_from(p: Vector3, to: Vector3) -> bool:
	var map = get_world_3d().navigation_map
	var path = NavigationServer3D.map_get_path(map, p, to, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(to) < 1.8

func _reachable(p: Vector3) -> bool: return _reachable_from(p, player.global_position)

func respawn_zombie(z: Zombie) -> void:
	if z.type == "dog" or z.type == "brute": return
	var pos = _spawn_point(z.type)
	if pos == Vector3.INF: return
	var nz = make_zombie(z.kind, z.type, pos, z.max_hp, z.max_speed)
	nz.hp = z.hp
	_remove_zombie(z)

func _remove_zombie(z: Zombie) -> void:
	zombies.erase(z); zmap.erase(z.zid)
	if Net.active: Net.z_dead.rpc(-z.zid, false)   # id negativo: desaparece sin animación
	z.queue_free()

func _visible_from_player(p: Vector3) -> bool:
	var to = p - player.cam.global_position
	if to.normalized().dot(-player.cam.global_transform.basis.z) < 0.5: return false
	return ray_world(player.cam.global_position, to.normalized(), to.length()) == Vector3.INF

# ------------------------------------------------------------------ zombis en red
func send_zombie_snapshot() -> void:
	var data = PackedFloat32Array()
	for z in zombies:
		if not is_instance_valid(z) or z.dead: continue
		data.append_array([z.zid, z.global_position.x, z.global_position.y, z.global_position.z, z.yaw, z.anim_code(), z.anim.speed_scale if z.anim else 1.0, z.model.position.y])
	Net.z_snap.rpc(data)

func on_z_spawn(zid: int, kind: String, type: String, pos: Vector3, speed: float) -> void:
	if _host() or zmap.has(zid): return
	var z = Zombie.new(); z.zid = zid
	add_child(z); z.setup(self, kind, pos, 100.0, speed, type, true)
	zombies.append(z); zmap[zid] = z

func on_z_snap(data: PackedFloat32Array) -> void:
	var i = 0
	while i + 7 < data.size():
		var z = zmap.get(int(data[i]))
		if z and is_instance_valid(z): z.net_update(Vector3(data[i + 1], data[i + 2], data[i + 3]), data[i + 4], int(data[i + 5]), data[i + 6], data[i + 7])
		i += 8

func on_z_dead(zid: int, head: bool) -> void:
	var z = zmap.get(abs(zid))
	if z == null or not is_instance_valid(z): return
	zmap.erase(abs(zid))
	if zid < 0: zombies.erase(z); z.queue_free()
	else: z.die_visual(head)

# ------------------------------------------------------------------ disparos y daño
## rayo de bala: atraviesa vallas y cristal, se para en muros y zombis
func shoot_ray(from: Vector3, dir: Vector3, rng: float, by: Player) -> Dictionary:
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(from, from + dir * rng, MapBuilder.LAYER_WORLD | MapBuilder.LAYER_ZOMBIE | MapBuilder.LAYER_BARRIER)
	q.exclude = [by.get_rid()]
	var res = space.intersect_ray(q)
	var out = { "hit": false, "kill": false, "head": false }
	if Engine.has_meta("dbg_shots"): print("RAYO ", "nada" if res.is_empty() else str(res.collider) + " " + str(res.collider.get_parent().name if res.collider.get_parent() else "") + " en " + str(res.position))
	if res.is_empty(): return out
	var col = res.collider
	if col is Zombie:
		var z: Zombie = col
		var hp_pos = z.head_pos()
		# cabeza: el recorrido de la bala pasa cerca del hueso de la cabeza (más fiable que el punto donde toca la cápsula)
		var rel = hp_pos - from
		var miss = (rel - dir * rel.dot(dir)).length()
		var head: bool = miss < 0.2 * (1.4 if z.type == "brute" else 1.0) or res.position.y > hp_pos.y - 0.05
		var w = by.cur_w()
		var dmg = float(Player.stat_of(w.id, w.pap, "dmg"))
		if head: dmg *= float(Player.stat_of(w.id, w.pap, "head"))
		var k = damage_zombie(z, dmg, res.position, head, "bullet", w.id)
		out.hit = true; out.kill = k; out.head = head
		Sfx.play_at("hit_body", res.position, 0.55, randf_range(0.9, 1.15))
	else:
		impact(res.position, res.normal)
	return out

## daño hecho por el jugador local: en el servidor se aplica, en un cliente se manda al servidor
func damage_zombie(z: Zombie, dmg: float, at: Vector3, head: bool, kind: String, wid: String) -> bool:
	if z == null or z.dead: return false
	if insta > 0.0 or player.gum("pinza"):
		if kind != "bubble": dmg = 1e9
	if _host():
		if kind == "bubble": _bubble(z, Net.my_id(), wid); return false
		return z.take_hit(dmg, at, head, Net.my_id(), kind, wid)
	z.take_hit(dmg, at, head, Net.my_id(), kind, wid)   # en la marioneta solo sale la sangre
	Net.hit.rpc_id(1, z.zid, dmg, head, kind, wid)
	return false

func on_net_hit(peer: int, zid: int, dmg: float, head: bool, kind: String, wid: String) -> void:
	var z = zmap.get(zid)
	if z == null or not is_instance_valid(z) or z.dead: return
	if kind == "bubble": _bubble(z, peer, wid); return
	z.take_hit(dmg, z.global_position + Vector3(0, 1.2, 0), head, peer, kind, wid)

## burbuja del Burbujeador: el zombi flota unos segundos y revienta
func _bubble(z: Zombie, by: int, wid: String) -> void:
	if z.bubbled > 0.0: return
	z.bubbled = 2.6 if z.type != "brute" else 1.0
	get_tree().create_timer(z.bubbled).timeout.connect(func():
		if is_instance_valid(z) and not z.dead:
			evt("pop", z.global_position + Vector3(0, 1.4, 0))
			z.take_hit(1e9 if z.type != "brute" else z.max_hp * 0.12, z.global_position + Vector3(0, 1.4, 0), false, by, "bubble", wid))

func on_zombie_hurt(_z: Zombie, by, kind: String, wid: String) -> void:
	if kind == "bullet" or kind == "proj": award(by, 10, false, false, kind, wid, _z.type)

func on_zombie_killed(z: Zombie, head: bool, by, kind: String, wid: String) -> void:
	zmap.erase(z.zid)
	if Net.active: Net.z_dead.rpc(z.zid, head)
	var pts = 130 if kind == "knife" else (100 if head else 60)
	pts += int(Zombie.TYPE_DATA[z.type].pts)
	award(by, pts * (2 if dpoints > 0 else 1), true, head, kind, wid, z.type)
	if z.type == "brute":
		_drop_powerup(z.global_position, "")
		if egg.step == 5 and z.zid == egg.boss: _egg_done()
	elif z.type == "dog":
		var left = zombies.filter(func(o): return is_instance_valid(o) and not o.dead and o.type == "dog").size()
		if to_spawn == 0 and left == 0: _drop_powerup(z.global_position, "max_ammo")   # el último perro deja munición
	elif drops < 4 and randf() < 0.035: _drop_powerup(z.global_position, "")

## puntos y bajas para quien ha dado el golpe (puede ser otro móvil)
func award(by, pts: int, kill: bool, head: bool, kind: String, wid: String, ztype := "normal") -> void:
	if by == null or (by is int and by <= 0): return
	if by == Net.my_id(): on_award(pts, kill, head, kind + ":" + ztype, wid)
	elif Net.active: Net.award.rpc_id(by, pts, kill, head, kind + ":" + ztype, wid)

func on_award(pts: int, kill: bool, head: bool, kind_type: String, wid: String) -> void:
	var parts = kind_type.split(":"); var kind = parts[0]; var ztype = parts[1] if parts.size() > 1 else "normal"
	player.add_points(pts)
	if not kill: return
	player.kills += 1
	if head: player.headshots += 1
	if (kind == "bullet" or kind == "proj" or kind == "bubble") and Data.WEAPONS.has(wid): _challenges(GS.add_kill(wid))
	stat("kills")
	if head: stat("heads")
	if kind == "knife": stat("knife")
	if kind == "explo" or kind == "proj": stat("explo")
	if ztype == "dog": stat("dogs")
	if ztype == "brute": stat("brutes"); Voice.say("brute")
	if not _host(): hud.hitmarker(true, head)
	if player.kills % 25 == 0: Voice.say("streak")

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

# ------------------------------------------------------------------ explosiones, granadas, proyectiles y gas
## explosión del jugador local (granada, Mustang & Sally, Rayo Gamba): daña a los zombis cercanos
func explode(at: Vector3, radius: float, dmg: float, _by = null, kind := "explo", wid := "") -> void:
	if OS.get_cmdline_user_args().has("verbose"): print("EXPLOSIÓN en ", at, " zombis cerca ", zombies.filter(func(z): return is_instance_valid(z) and not z.dead and z.global_position.distance_to(at) < radius).size())
	for z in zombies.duplicate():
		if is_instance_valid(z) and not z.dead and z.global_position.distance_to(at) < radius:
			damage_zombie(z, dmg, z.global_position + Vector3(0, 1, 0), false, kind, wid)
	Fx.explosion(self, at)
	Sfx.play_at("explosion", at, 1.0, randf_range(0.9, 1.05))
	var dd = player.global_position.distance_to(at)
	if dd < 18.0: player.shake = min(1.0, player.shake + (1.0 - dd / 18.0))

func throw_grenade(from: Vector3, vel: Vector3, by: Node) -> void:
	# si hay una pared delante, sale desde este lado (antes aparecía detrás y se perdía)
	var eye = player.cam.global_position
	var h = ray_world(eye, (from - eye).normalized(), eye.distance_to(from) + 0.15)
	if h != Vector3.INF: from = h - (from - eye).normalized() * 0.2
	var g = RigidBody3D.new(); g.collision_layer = 0; g.collision_mask = MapBuilder.LAYER_WORLD | MapBuilder.LAYER_SOFT | MapBuilder.LAYER_BARRIER
	g.mass = 0.4; g.physics_material_override = PhysicsMaterial.new(); g.physics_material_override.bounce = 0.3; g.physics_material_override.friction = 0.8
	g.continuous_cd = true   # no atraviesa el suelo aunque vaya rápida
	g.linear_damp = 0.3; g.angular_damp = 2.0
	var cs = CollisionShape3D.new(); var sp = SphereShape3D.new(); sp.radius = 0.08; cs.shape = sp; g.add_child(cs)
	var m = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 0.08; sm.height = 0.16; sm.radial_segments = 12; sm.rings = 6; m.mesh = sm
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.35, 0.42, 0.28); mat.roughness = 0.5; mat.metallic = 0.3; m.material_override = mat; g.add_child(m)
	var led = OmniLight3D.new(); led.light_color = Color(1, 0.2, 0.1); led.omni_range = 1.2; led.light_energy = 1.5; g.add_child(led)   # lucecita para verla
	add_child(g); g.global_position = from; g.linear_velocity = vel
	var last_ok = from
	var tw = create_tween().set_loops(11); tw.tween_property(led, "light_energy", 0.2, 0.1); tw.tween_property(led, "light_energy", 1.8, 0.1)
	get_tree().create_timer(2.2).timeout.connect(func():
		if not is_instance_valid(g): return
		var at = g.global_position
		if at.y < from.y - 15.0: at = last_ok   # se ha caído del mapa: explota donde estaba
		explode(at, 4.5, 400.0 + round_n * 60.0, by); g.queue_free())
	get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(g): last_ok = g.global_position)

func fire_projectile(by: Player, from: Vector3, dir: Vector3, proj: Dictionary, dmg: float, wid: String) -> void:
	var p = preload("res://scripts/projectile.gd").new()
	p.game = self; p.owner_player = by; p.dir = dir; p.data = proj; p.dmg = dmg; p.wid = wid
	add_child(p); p.global_position = from

## el Hinchado revienta: gas que hace daño a los que estén cerca
func gas_burst(at: Vector3, authoritative: bool) -> void:
	Fx.gas(self, at); Sfx.play_at("z_hit2", at, 1.0, 0.5)
	if player.global_position.distance_to(at) < 2.8: player.take_damage(35.0)
	if not authoritative: return
	for z in zombies.duplicate():
		if is_instance_valid(z) and not z.dead and z.type != "brute" and z.global_position.distance_to(at) < 2.6:
			z.take_hit(400.0, z.global_position + Vector3(0, 1, 0), false, 0, "gas")

## rayo de los perros infernales
func lightning(at: Vector3) -> void:
	var l = OmniLight3D.new(); l.light_color = Color(0.6, 0.75, 1.0); l.omni_range = 14.0; l.light_energy = 8.0; add_child(l); l.global_position = at + Vector3(0, 3, 0)
	var beam = MeshInstance3D.new(); var cm = CylinderMesh.new(); cm.top_radius = 0.05; cm.bottom_radius = 0.25; cm.height = 30; cm.radial_segments = 12; cm.rings = 1; beam.mesh = cm
	var bm = StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.albedo_color = Color(0.75, 0.85, 1.0, 0.85); bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.material_override = bm; add_child(beam); beam.global_position = at + Vector3(0, 15, 0)
	Sfx.play_at("shot_rifle2", at, 1.0, 0.4)
	var tw = create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.5); tw.parallel().tween_property(bm, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(func(): l.queue_free(); beam.queue_free())

# ------------------------------------------------------------------ potenciadores
func _drop_powerup(at: Vector3, kind: String) -> void:
	if not _host(): return
	drops += 1
	if kind == "": kind = Data.POWERUPS[randi() % Data.POWERUPS.size()]
	var id = next_pu; next_pu += 1
	evt("pu", [id, at + Vector3(0, 0.9, 0), kind])

## un potenciador se coge: lo confirma el servidor y se aplica en todos
func take_powerup(id: int) -> void:
	world_request(null, "pu_take", id, func(_r): pass)

func apply_powerup(kind: String, by: int) -> void:
	if by == Net.my_id(): stat("powerups")
	hud.banner(Data.POWERUP_NAMES[kind], "", 2.0); Sfx.play("powerup", 1.0)
	Voice.say("powerup_" + kind)
	match kind:
		"max_ammo": player.refill_ammo()
		"insta_kill": insta = 30.0
		"double_points": dpoints = 30.0
		"fire_sale": fire_sale = 30.0
		"nuke":
			if _host():
				for z in zombies.duplicate():
					if is_instance_valid(z) and not z.dead and z.type != "brute": z.take_hit(1e9, z.global_position + Vector3(0, 1, 0), false, 0, "nuke")
			player.add_points(400)
			hud.white_flash()
		"carpenter": player.add_points(200)

## chicle Marea Roja: mata a los zombis cercanos al jugador (lo hace el servidor)
func request_nuke() -> void:
	world_request(null, "gum_nuke", player.global_position, func(_r): pass)

# ------------------------------------------------------------------ peticiones al servidor
## el jugador local quiere cambiar algo del mundo; en el servidor se hace al momento, en un cliente se pregunta
func world_request(it: Node, action: String, arg: Variant, on_ok: Callable) -> void:
	var idx = interactables.find(it) if it != null else -1
	if _host():
		var res: Dictionary = world_do(Net.my_id(), idx, action, arg)
		if res.ok: on_ok.call(res.get("result"))
		else: Sfx.play("dryfire", 0.6)
		return
	var key = "%d:%s" % [idx, action]
	if pending.has(key): return
	pending[key] = on_ok
	Net.world_req.rpc_id(1, idx, action, arg)
	get_tree().create_timer(3.0).timeout.connect(func(): pending.erase(key))

func on_world_req(peer: int, idx: int, action: String, arg: Variant) -> void:
	var res: Dictionary = world_do(peer, idx, action, arg)
	Net.world_res.rpc_id(peer, idx, action, res.ok, res.get("result"))

func on_world_res(idx: int, action: String, ok: bool, result: Variant) -> void:
	var key = "%d:%s" % [idx, action]
	var cb = pending.get(key); pending.erase(key)
	if not ok: Sfx.play("dryfire", 0.6); return
	if cb is Callable and cb.is_valid(): cb.call(result)

## servidor: hace el cambio (si se puede) y avisa a todos
func world_do(peer: int, idx: int, action: String, arg: Variant) -> Dictionary:
	if idx >= 0:
		if idx >= interactables.size() or not is_instance_valid(interactables[idx]): return { "ok": false }
		return interactables[idx].world_do(peer, action, arg)
	match action:
		"pu_take":
			if not pus.has(arg): return { "ok": false }
			evt("pu_take", [arg, pus[arg].kind, peer]); return { "ok": true }
		"gum_nuke":
			for z in zombies.duplicate():
				if is_instance_valid(z) and not z.dead and z.type != "brute" and z.global_position.distance_to(arg) < 22.0:
					z.take_hit(1e9, z.global_position + Vector3(0, 1, 0), false, peer, "nuke")
			evt("flash", null); return { "ok": true }
		"egg_part", "egg_build", "egg_start", "plush": return _egg_do(peer, action, arg)
	return { "ok": false }

## eventos del mundo (llegan a todos los móviles)
func on_world_evt(name: String, data: Variant) -> void:
	match name:
		"door":
			if data < doors.size() and not doors[data].open: doors[data].open_now()
		"power":
			turn_power_on()
			for it in interactables:
				if it is Interactables.Power: it.lever.rotation_degrees.x = 60
		"box_roll", "box_taken", "pap_insert", "pap_take":
			var it = interactables[int(data.i)] if data is Dictionary else interactables[int(data)]
			it.on_evt(name, data)
		"round": _on_round_evt(data)
		"pu":
			var pu = preload("res://scripts/powerup.gd").new(); pu.game = self; pu.kind = data[2]; pu.id = data[0]; add_child(pu); pu.global_position = data[1]
			pus[data[0]] = pu
		"pu_take":
			var n = pus.get(data[0])
			if n and is_instance_valid(n): n.queue_free()
			pus.erase(data[0])
			apply_powerup(data[1], int(data[2]))
		"pop": Fx.pop(self, data, Color(0.5, 0.85, 1.0)); Sfx.play_at("dryfire", data, 1.0, 1.8)
		"flash": hud.white_flash(); Sfx.play("powerup", 1.0, 0.4)
		"egg": _egg_evt(data)
		"song": _song_play()

func _on_round_evt(d: Dictionary) -> void:
	round_n = int(d.n)
	if d.phase == "start":
		dog_round = bool(d.dogs)
		gum_uses = 0
		hud.set_round(round_n, true)
		if dog_round:
			hud.banner("¡RONDA DE PERROS!", "Vienen los perros infernales", 3.0); Sfx.music_sting("dogs"); Voice.say("dogs")
			var tw = create_tween(); tw.tween_property(env, "fog_density", float(cfg.get("env", {}).get("fog_density", 0.012)) * 3.0, 3.0)
			env.fog_light_color = Color(0.55, 0.3, 0.2)
		else:
			Sfx.music_sting("round_start")
			if round_n > 1: Voice.say("round")
		# los que murieron vuelven a la partida (cooperativo)
		if not player.alive and Net.is_coop(): player.respawn(_respawn_spot())
	else:
		hud.set_round(round_n, false); Sfx.music_sting("round_end")
		player.refill_grenades()
		if dog_round:
			var tw = create_tween(); tw.tween_property(env, "fog_density", float(cfg.get("env", {}).get("fog_density", 0.012)), 4.0)
			env.fog_light_color = _col(cfg.get("env", {}).get("fog", [0.4, 0.42, 0.45]))
			dog_round = false

func _respawn_spot() -> Vector3:
	for k in remotes:
		if remotes[k].alive and not remotes[k].downed: return remotes[k].global_position + Vector3(1, 0.2, 0)
	return MapBuilder.v3(cfg.spawn)

# ------------------------------------------------------------------ easter egg principal y canción oculta
var egg = { "step": 0, "parts": [], "found": [], "bench": Vector3.ZERO, "defend_t": 0.0, "boss": -1, "plush": [], "plush_found": [] }
var egg_nodes: Array = []

## servidor: elige dónde están las piezas y las gambas de peluche y se lo dice a todos
func _egg_setup() -> void:
	if not Data.EGG.has(map_id): return
	var spots = _spread_points(6)
	if spots.size() < 6: return
	var bench = place({ "near": [cfg.spawn[0] + 2.0, cfg.spawn[2] + 2.0], "y": cfg.spawn[1] }, 0.45)
	evt("egg", { "setup": true, "parts": spots.slice(0, 3), "plush": spots.slice(3, 6), "bench": bench.pos, "bench_yaw": bench.yaw })

## puntos repartidos por todo el mapa (en zonas distintas, incluidas las que aún están cerradas)
func _spread_points(n: int) -> Array:
	var regs = []
	for id in nav_regions: regs.append(nav_regions[id])
	var spawn = MapBuilder.v3(cfg.spawn)
	# primero muy separados; si el mapa es pequeño (Isla Gamba) se van juntando un poco
	for spacing in [8.0, 5.0, 3.0, 1.5]:
		var out = []
		for attempt in 400:
			if out.size() >= n: break
			var r: NavigationRegion3D = regs[randi() % regs.size()]
			var nm: NavigationMesh = r.navigation_mesh
			if nm == null or nm.get_polygon_count() == 0: continue
			var verts = nm.get_vertices(); var poly = nm.get_polygon(randi() % nm.get_polygon_count())
			var p = Vector3.ZERO
			for vi in poly: p += verts[vi]
			p = r.global_transform * (p / poly.size())
			var ok = p.distance_to(spawn) > min(6.0, spacing + 1.0)
			for o in out:
				if o.distance_to(p) < spacing: ok = false
			if ok: out.append(p)
		if out.size() >= n: return out
	return []

func _egg_evt(d: Dictionary) -> void:
	var E: Dictionary = Data.EGG[map_id]
	if d.has("setup"):
		egg.parts = d.parts; egg.plush = d.plush; egg.bench = d.bench
		egg.found = [false, false, false]; egg.plush_found = [false, false, false]
		for k in 3:
			var it = Interactables.EggPart.new(); add_child(it); it.global_position = egg.parts[k]; it.build(self, k, E.part); egg_nodes.append(it)
		for k in 3:
			var pl = Interactables.Plush.new(); add_child(pl); pl.global_position = egg.plush[k]; pl.build(self, k); egg_nodes.append(pl)
		var b = Interactables.EggBench.new(); add_child(b); b.global_position = egg.bench; b.rotation_degrees.y = float(d.bench_yaw); b.build(self); egg_nodes.append(b)
		return
	if d.has("part"):
		egg.found[int(d.part)] = true
		for n in egg_nodes:
			if is_instance_valid(n) and n is Interactables.EggPart and n.k == int(d.part): n.queue_free()
		var c = egg.found.count(true)
		hud.toast("EASTER EGG", "Has encontrado %s (%d/3)" % [E.part, c])
		Sfx.play("powerup", 0.8, 1.6)
		if c == 1: hud.banner("¿QUÉ ES ESTO?", E.intro, 6.0)
	if d.has("step"):
		egg.step = int(d.step)
		match egg.step:
			3: hud.banner("¡MONTADO!", "Has montado %s. Actívalo en la mesa de trabajo cuando estéis listos." % E.item, 5.0)
			4: hud.banner("¡AGUANTA 60 SEGUNDOS!", E.defend, 5.0); Sfx.music_sting("egg"); egg.defend_t = 60.0; Voice.say("egg")
			5: hud.banner("¡EL GUARDIÁN!", "Mata al Bruto para terminar", 4.0)
			6:
				hud.banner("¡EASTER EGG COMPLETADO!", E.end, 9.0); Sfx.music_sting("egg_end")
				stat("egg_" + map_id)
				for pk in Data.PERKS: player.give_perk(pk)   # premio: todas las bebidas
				player.add_points(5000)
	if d.has("plush"):
		egg.plush_found[int(d.plush)] = true
		for n in egg_nodes:
			if is_instance_valid(n) and n is Interactables.Plush and n.k == int(d.plush): n.queue_free()
		Sfx.play("dryfire", 1.0, 2.2)

func _egg_do(peer: int, action: String, arg: Variant) -> Dictionary:
	match action:
		"egg_part":
			var k = int(arg)
			if egg.found.size() < 3 or egg.found[k]: return { "ok": false }
			egg.found[k] = true
			evt("egg", { "part": k })
			if egg.found.count(true) == 3: evt("egg", { "step": 2 })
			return { "ok": true }
		"egg_build":
			if egg.step != 2: return { "ok": false }
			evt("egg", { "step": 3 }); return { "ok": true }
		"egg_start":
			if egg.step != 3 or not power_on: return { "ok": false }
			evt("egg", { "step": 4 }); to_spawn = max(to_spawn, 30); break_t = 0.0
			return { "ok": true }
		"plush":
			var k = int(arg)
			if egg.plush_found.size() < 3 or egg.plush_found[k]: return { "ok": false }
			egg.plush_found[k] = true
			evt("egg", { "plush": k })
			if egg.plush_found.count(true) == 3: evt("song", null)
			return { "ok": true }
	return { "ok": false }

func _egg_process(delta: float) -> void:
	if egg.step == 4:
		egg.defend_t -= delta
		hud.egg_timer(egg.defend_t)
		if _host() and egg.defend_t <= 0.0:
			# aparece el guardián: un Bruto con muchísima vida
			var p = _random_nav_near(egg.bench, 5.0, 10.0)
			if p == Vector3.INF: p = egg.bench + Vector3(0, 0.1, 0)
			var z = make_zombie("a", "brute", p, round_hp(max(round_n, 10)) * 2.5 * _nplayers(), 1.1)
			egg.boss = z.zid
			evt("egg", { "step": 5 })
	elif egg.step == 5:
		hud.egg_timer(-1.0)

func _egg_done() -> void:
	evt("egg", { "step": 6 })

func _song_play() -> void:
	stat("song_" + map_id)
	hud.toast("CANCIÓN OCULTA", "¡Has encontrado las tres gambas de peluche!")
	Sfx.music_song()

# ------------------------------------------------------------------ efectos
func blood(at: Vector3, head: bool) -> void: Fx.blood(self, at, head)
func impact(at: Vector3, n: Vector3) -> void: Fx.impact(self, at, n)
func dust(at: Vector3) -> void: Fx.dust(self, at)

# ------------------------------------------------------------------ pausa y fin
## un ajuste cambiado desde la pausa se aplica al momento
func on_setting_changed(k: String) -> void:
	match k:
		"quality": apply_quality(env)
		"third": player.third = bool(GS.settings.third)
		"music": Sfx.set_ambient_volume()
		"fov": player.cam.fov = float(GS.settings.fov)
		"btn_scale", "btn_alpha", "left_fire": hud.touch_layer.queue_redraw()

## contadores de los desafíos
func stat(key: String, n := 1) -> void: _challenges(GS.add_stat(key, n))

func _challenges(list: Array) -> void:
	for c in list:
		completed.append(c)
		if hud: hud.toast("DESAFÍO COMPLETADO", "%s  ·  +%d XP" % [c.text, c.xp])

## en solitario la pausa para el juego; en cooperativo solo abre el menú (el mundo sigue)
func pause(on: bool) -> void:
	if on: GS.save_game()
	paused = on
	if not Net.is_coop(): get_tree().paused = on
	hud.show_pause(on)
	Controls.consume()   # que el botón que ha reanudado no vuelva a pausar ni dispare

func _on_player_died() -> void:
	# en cooperativo, la partida acaba cuando no queda nadie en pie (lo decide el servidor)
	if Net.is_coop() and not ending: return
	if over: return
	over = true
	Sfx.music_sting("game_over")
	var stats = { "map": map_id, "round": round_n, "kills": player.kills, "heads": player.headshots, "time": time, "points": player.points }
	var xp = player.kills * 10 + player.headshots * 5 + round_n * 100
	GS.add_xp(xp); stats["xp"] = xp + completed.reduce(func(a, c): return a + int(c.xp), 0); stats["levels"] = GS.level - level0; stats["challenges"] = completed
	if round_n > int(GS.best.get(map_id, 0)): GS.best[map_id] = round_n; stats["record"] = true
	GS.save_game()
	hud.show_game_over(stats)
	finished.emit(stats)

func _all_out() -> bool:
	for p in all_players():
		if p.alive and not p.downed: return false
	return true
