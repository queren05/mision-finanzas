class_name Interactables
extends RefCounted
## Cosas con las que se interactúa: armas de pared, bebidas, caja misteriosa, Pack-a-Punch, corriente y puertas.

class Base extends Node3D:
	var game: Node
	var reach = 1.9
	func prompt(_p: Player) -> String: return ""
	func use(_p: Player) -> void: pass
	func can_use(p: Player) -> bool:
		var d = global_position - p.global_position; d.y = 0
		return d.length() < reach
	func pay(p: Player, cost: int) -> bool:
		if p.points < cost: Sfx.play("dryfire", 0.6); game.hud.flash_points(); return false
		p.add_points(-cost); Sfx.play("powerup", 0.5); return true

static func _fit(n: Node3D, height: float) -> void:
	var lo = INF; var hi = -INF
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		var t = Transform3D.IDENTITY; var c: Node = mi
		while c != null and c != n:
			if c is Node3D: t = (c as Node3D).transform * t
			c = c.get_parent()
		var b: AABB = t * mi.mesh.get_aabb()
		lo = min(lo, b.position.y); hi = max(hi, b.end.y)
	var s = height / max(0.001, hi - lo)
	n.scale = Vector3.ONE * s
	n.position.y = -lo * s

static func _solid(owner: Node3D, size: Vector3, center: Vector3) -> void:
	var body = MapBuilder.make_box(center, size, 0.0, MapBuilder.LAYER_WORLD)
	owner.add_child(body)

# ------------------------------------------------------------------ arma de pared (silueta de tiza y el arma colgada)
class WallBuy extends Base:
	var gun = ""
	var cost = 0
	func build(g: Node, id: String) -> void:
		game = g; gun = id; cost = int(Data.WEAPONS[id].cost)
		var L = float(Data.WEAPONS[id].len)
		# marco de tiza ajustado al largo del arma
		var chalk = Sprite3D.new(); chalk.texture = Interactables._chalk_tex(Data.WEAPONS[id].name, cost); chalk.pixel_size = (L + 0.35) / 384.0
		chalk.position = Vector3(0, 0, 0.012); chalk.shaded = false; chalk.modulate = Color(0.95, 0.94, 0.88, 0.85); chalk.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED; add_child(chalk)
		var m = Guns.make_world(id); m.rotation_degrees = Vector3(0, -90, 0); m.position = Vector3(0, 0.0, 0.06); add_child(m)
		var lab = Label3D.new(); lab.text = "%s  %d" % [Data.WEAPONS[id].name.to_upper(), cost]; lab.font = load("res://assets/fonts/Oswald.ttf"); lab.font_size = 40; lab.pixel_size = 0.0028
		lab.modulate = Color(0.95, 0.94, 0.88); lab.outline_size = 0; lab.position = Vector3(0, -0.3 - L * 0.08, 0.015); lab.shaded = false; add_child(lab)
		var lamp = OmniLight3D.new(); lamp.light_color = Color(1, 0.92, 0.8); lamp.omni_range = 2.0; lamp.light_energy = 0.9; lamp.position = Vector3(0, 0.25, 0.55); add_child(lamp)
		reach = 1.8
	func prompt(p: Player) -> String:
		var i = p.has_weapon(gun)
		if i >= 0: return "Pulsa USAR: munición de %s [%d]" % [Data.WEAPONS[gun].name, cost / 2 if not p.weapons[i].pap else 4500]
		return "Pulsa USAR: comprar %s [%d]" % [Data.WEAPONS[gun].name, cost]
	func use(p: Player) -> void:
		var i = p.has_weapon(gun)
		if i >= 0:
			if pay(p, cost / 2 if not p.weapons[i].pap else 4500):
				var w = p.weapons[i]; w.mag = int(Player.stat_of(gun, w.pap, "mag")); w.res = int(Player.stat_of(gun, w.pap, "res")); game.hud.update_ammo()
		elif pay(p, cost): p.give_weapon(gun)

# ------------------------------------------------------------------ máquina de bebida
class Perk extends Base:
	var id = ""
	var light: OmniLight3D
	var sign: Node3D
	func build(g: Node, perk: String, model_yaw: float) -> void:
		game = g; id = perk
		var scn: PackedScene = load("res://assets/models/props/%s.glb" % perk)
		var holder = Node3D.new(); add_child(holder)
		var m: Node3D = scn.instantiate(); holder.add_child(m)
		if perk == "mule": m.rotation_degrees.x = -90.0     # este modelo viene tumbado
		Interactables._fit(holder, 2.05); holder.rotation_degrees.y = model_yaw
		light = OmniLight3D.new(); light.light_color = Data.PERKS[perk].color; light.omni_range = 4.0; light.light_energy = 0.0; light.position = Vector3(0, 1.6, 0.8); add_child(light)
		Interactables._solid(self, Vector3(1.0, 2.0, 0.8), Vector3(0, 1.0, 0))
		reach = 1.9
	func powered() -> bool: return id == "revive" or game.power_on
	func _process(_d: float) -> void: light.light_energy = (1.4 + sin(Time.get_ticks_msec() * 0.004) * 0.15) if powered() else 0.25
	func prompt(p: Player) -> String:
		if id in p.perks: return ""
		if not powered(): return "Necesitas encender la corriente"
		return "Pulsa USAR: %s [%d] — %s" % [Data.PERKS[id].name, Data.PERKS[id].cost, Data.PERKS[id].desc]
	func use(p: Player) -> void:
		if id in p.perks or not powered(): return
		if pay(p, int(Data.PERKS[id].cost)):
			p.give_perk(id); game.hud.banner(Data.PERKS[id].name.to_upper(), Data.PERKS[id].desc, 2.0)

# ------------------------------------------------------------------ caja misteriosa
class MysteryBox extends Base:
	var spots: Array = []         # [[pos, yaw], ...]
	var spot = 0
	var state = "idle"           # idle, rolling, offer, leaving
	var st = 0.0
	var offer = ""
	var shown: Node3D
	var lid: Node3D
	var beam: MeshInstance3D
	var uses = 0
	var buyer: Player
	func build(g: Node, all_spots: Array, first: int) -> void:
		game = g; spots = all_spots; spot = first
		var body = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(1.7, 0.62, 0.72); body.mesh = bm; body.position.y = 0.31
		body.material_override = Interactables._wood_mat(); add_child(body)
		lid = Node3D.new(); lid.position = Vector3(0, 0.62, -0.36); add_child(lid)
		var lm = MeshInstance3D.new(); var lb = BoxMesh.new(); lb.size = Vector3(1.72, 0.1, 0.74); lm.mesh = lb; lm.position = Vector3(0, 0.05, 0.36); lm.material_override = Interactables._wood_mat(); lid.add_child(lm)
		for sx in [-0.55, 0.0, 0.55]:
			var q = Label3D.new(); q.text = "?"; q.font_size = 96; q.pixel_size = 0.004; q.modulate = Color(1, 0.95, 0.7); q.outline_size = 8; q.position = Vector3(sx, 0.33, 0.37); add_child(q)
		beam = MeshInstance3D.new(); var cm = CylinderMesh.new(); cm.top_radius = 0.35; cm.bottom_radius = 0.5; cm.height = 40; cm.cap_top = false; cm.cap_bottom = false; beam.mesh = cm; beam.position.y = 20
		var bmat = StandardMaterial3D.new(); bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bmat.albedo_color = Color(0.45, 0.75, 1.0, 0.18); bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bmat.cull_mode = BaseMaterial3D.CULL_DISABLED; bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; beam.material_override = bmat; add_child(beam)
		Interactables._solid(self, Vector3(1.7, 0.7, 0.72), Vector3(0, 0.35, 0))
		_place()
	func _place() -> void:
		var s = spots[spot]; global_position = MapBuilder.v3(s.pos); rotation_degrees.y = float(s.yaw)
	func cost() -> int: return 10 if game.fire_sale > 0.0 else 950
	func prompt(p: Player) -> String:
		if state == "idle": return "Pulsa USAR: caja misteriosa [%d]" % cost()
		if state == "offer" and buyer == p: return "Pulsa USAR: coger %s" % Data.WEAPONS[offer].name
		return ""
	func use(p: Player) -> void:
		if state == "idle":
			if pay(p, cost()): state = "rolling"; st = 0.0; buyer = p; uses += 1; Sfx.play("powerup", 0.8, 0.7)
		elif state == "offer" and buyer == p:
			p.give_weapon(offer); _clear(); state = "idle"
	func _clear() -> void:
		if shown: shown.queue_free(); shown = null
	func _process(d: float) -> void:
		st += d
		lid.rotation.x = lerp(lid.rotation.x, -1.6 if state != "idle" else 0.0, min(1.0, d * 6.0))
		if state == "rolling":
			if int(st * 7.0) != int((st - d) * 7.0):
				_clear(); var keys: Array = Data.BOX_POOL.keys(); offer = keys[randi() % keys.size()]
				shown = Guns.make_world(offer); shown.rotation_degrees.y = 90; add_child(shown)
			if shown: shown.position = Vector3(0, 0.7 + min(st, 3.5) * 0.18, 0)
			if st > 4.2:
				# el osito: la caja se va a otro sitio (no en rebajas ni las primeras veces)
				if uses > 3 and game.fire_sale <= 0.0 and spots.size() > 1 and randf() < 0.14:
					_clear(); state = "leaving"; st = 0.0; buyer.add_points(950); game.hud.banner("¡ADIÓS, ADIÓS!", "La caja se va a otro sitio", 2.5); return
				var pool: Array = []; for k in Data.BOX_POOL: for i in int(Data.BOX_POOL[k]): if buyer.has_weapon(k) < 0: pool.append(k)
				if pool.size() > 0:
					offer = pool[randi() % pool.size()]; _clear(); shown = Guns.make_world(offer); shown.rotation_degrees.y = 90; add_child(shown); shown.position = Vector3(0, 1.33, 0)
				state = "offer"; st = 0.0
		elif state == "offer":
			if shown: shown.position.y = 1.33 - min(st / 9.0, 1.0) * 0.6
			if st > 9.0: _clear(); state = "idle"
		elif state == "leaving":
			position.y += d * 1.5
			if st > 2.5:
				var old = spot
				while spot == old: spot = randi() % spots.size()
				_place(); state = "idle"; uses = 0
		beam.visible = state != "leaving"

# ------------------------------------------------------------------ Pack-a-Punch
class PackAPunch extends Base:
	var busy = 0.0
	var holding = {}
	var who: Player
	var glow: OmniLight3D
	func build(g: Node) -> void:
		game = g
		var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.18, 0.17, 0.2); mat.metallic = 0.6; mat.roughness = 0.45
		var body = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(1.4, 1.5, 1.0); body.mesh = bm; body.position.y = 0.75; body.material_override = mat; add_child(body)
		var top = MeshInstance3D.new(); var tm = BoxMesh.new(); tm.size = Vector3(1.0, 0.45, 0.8); top.mesh = tm; top.position.y = 1.72; top.material_override = mat; add_child(top)
		var slot = MeshInstance3D.new(); var sm = BoxMesh.new(); sm.size = Vector3(1.0, 0.18, 0.04); slot.mesh = sm; slot.position = Vector3(0, 1.0, 0.51)
		var smat = StandardMaterial3D.new(); smat.albedo_color = Color(0.6, 0.2, 1.0); smat.emission_enabled = true; smat.emission = Color(0.6, 0.2, 1.0); smat.emission_energy_multiplier = 1.5; slot.material_override = smat; add_child(slot)
		var lab = Label3D.new(); lab.text = "PACK-A-PUNCH"; lab.font = load("res://assets/fonts/BlackOpsOne.ttf"); lab.font_size = 64; lab.pixel_size = 0.0028; lab.modulate = Color(0.85, 0.7, 1.0); lab.outline_size = 6; lab.position = Vector3(0, 1.3, 0.52); add_child(lab)
		glow = OmniLight3D.new(); glow.light_color = Color(0.6, 0.25, 1.0); glow.omni_range = 4; glow.light_energy = 0; glow.position = Vector3(0, 1.2, 1.0); add_child(glow)
		Interactables._solid(self, Vector3(1.4, 1.9, 1.0), Vector3(0, 0.95, 0))
	func prompt(p: Player) -> String:
		if not game.power_on: return "Necesitas encender la corriente"
		if busy > 0.0: return "" if who != p or busy > 0.01 else ""
		if holding.size() > 0 and who == p: return "Pulsa USAR: coger %s" % Data.WEAPONS[holding.id].pap.name
		if p.cur_w().pap: return "Esta arma ya está mejorada"
		return "Pulsa USAR: mejorar el arma [5000]"
	func use(p: Player) -> void:
		if not game.power_on or busy > 0.0: return
		if holding.size() > 0 and who == p: p.give_weapon(holding.id, true); holding = {}; return
		if p.cur_w().pap: return
		if pay(p, 5000):
			holding = p.cur_w().duplicate(); who = p
			p.weapons.remove_at(p.cur)
			if p.weapons.is_empty(): p.weapons.append(p._new_w("m1911", false))
			p.cur = 0; p._equip(); busy = 3.5; Sfx.play("powerup", 1.0, 0.6)
	func _process(d: float) -> void:
		glow.light_energy = (1.0 + (2.0 if busy > 0 else 0.0)) if game.power_on else 0.3
		if busy > 0.0: busy -= d

# ------------------------------------------------------------------ palanca de la corriente
class Power extends Base:
	var lever: Node3D
	func build(g: Node) -> void:
		game = g
		var scn: PackedScene = load("res://assets/models/props/lever.glb")
		lever = scn.instantiate(); add_child(lever); Interactables._fit(lever, 0.9); lever.position.y += 1.1
		reach = 1.7
	func prompt(_p: Player) -> String: return "" if game.power_on else "Pulsa USAR: encender la corriente"
	func use(_p: Player) -> void:
		if game.power_on: return
		game.turn_power_on(); lever.rotation_degrees.x = 60

# ------------------------------------------------------------------ puerta / barricada de pago
class Door extends Base:
	var idx = 0
	var cost = 750
	var opens: Array = []
	var visual: Node3D
	var blocker: StaticBody3D
	var open = false
	var anim_t = -1.0
	var dsize = Vector3.ONE
	func build(g: Node, i: int, d: Dictionary) -> void:
		game = g; idx = i; cost = int(d.cost); opens = d.opens
		var size = MapBuilder.v3(d.size)
		global_position = MapBuilder.v3(d.pos); rotation_degrees.y = float(d.get("yaw", 0))
		if not d.get("auto", false): blocker = MapBuilder.make_box(Vector3(0, size.y / 2, 0), size, 0.0, MapBuilder.LAYER_BARRIER); add_child(blocker)
		dsize = size
		visual = Node3D.new(); add_child(visual)
		var kind: String = d.get("kind", "barricade")
		if kind == "hide":
			pass   # la puerta es una pieza del propio mapa (verja): se esconde al abrir
		else:
			Interactables.build_barricade(visual, size)
		var lab = Label3D.new(); lab.text = "%d" % cost; lab.font = load("res://assets/fonts/BlackOpsOne.ttf"); lab.font_size = 72; lab.pixel_size = 0.004; lab.modulate = Color(1, 0.85, 0.4); lab.outline_size = 10
		lab.position = Vector3(0, min(size.y, 2.4) + 0.35, 0); lab.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; visual.add_child(lab)
		reach = max(2.2, size.x * 0.55)
	func can_use(p: Player) -> bool:
		if open: return false
		var l = to_local(p.global_position)
		var size: Vector3 = dsize
		return abs(l.x) < size.x / 2 + 0.5 and abs(l.z) < 2.0 and abs(l.y) < size.y + 1.0
	func prompt(_p: Player) -> String: return "Pulsa USAR: despejar el paso [%d]" % cost
	func use(p: Player) -> void:
		if open: return
		if pay(p, cost): open_now()
	func open_now(silent = false) -> void:
		open = true; anim_t = 0.0
		if blocker: blocker.queue_free()
		for n in game.door_hide_nodes(idx):
			n.visible = false
			for c in n.get_children(): if c is StaticBody3D: c.queue_free()
		game.on_door_opened(idx, opens, silent)
		if not silent: Sfx.play("z_hit1", 0.8, 0.6)
	func _process(d: float) -> void:
		if anim_t >= 0.0:
			anim_t += d; visual.position.y -= d * 2.0; visual.rotation.x += d * 0.5
			if anim_t > 1.5: visual.queue_free(); anim_t = -1.0

# ------------------------------------------------------------------ barricada de tablones (estilo Black Ops)
static var _planks: StandardMaterial3D
static func planks_mat() -> StandardMaterial3D:
	if _planks: return _planks
	_planks = StandardMaterial3D.new()
	_planks.albedo_texture = load("res://assets/textures/planks_d.jpg"); _planks.normal_enabled = true; _planks.normal_texture = load("res://assets/textures/planks_n.jpg")
	_planks.roughness_texture = load("res://assets/textures/planks_r.jpg"); _planks.roughness = 1.0; _planks.uv1_scale = Vector3(0.7, 0.7, 0.7); _planks.uv1_triplanar = true
	_planks.albedo_color = Color(1.1, 1.0, 0.92)
	return _planks

static func _plank(parent: Node3D, center: Vector3, length: float, width: float, roll: float, yaw := 0.0) -> void:
	var m = MeshInstance3D.new(); var b = BoxMesh.new(); b.size = Vector3(length, width, 0.05); m.mesh = b; m.material_override = planks_mat()
	m.position = center; m.rotation = Vector3(0, yaw, roll); parent.add_child(m)

static func build_barricade(parent: Node3D, size: Vector3) -> void:
	var w = size.x; var h = min(size.y, 2.5)
	var rng = RandomNumberGenerator.new(); rng.seed = int(w * 1000)
	# postes
	var nposts = max(2, int(ceil(w / 2.2)) + 1)
	for i in nposts:
		var x = -w / 2 + 0.12 + i * (w - 0.24) / (nposts - 1)
		var m = MeshInstance3D.new(); var b = BoxMesh.new(); b.size = Vector3(0.14, h + 0.1, 0.14); m.mesh = b; m.material_override = planks_mat()
		m.position = Vector3(x, (h + 0.1) / 2, -0.05); m.rotation.z = rng.randf_range(-0.04, 0.04); parent.add_child(m)
	# tablones horizontales clavados a los postes, algo torcidos
	var rows = int(h / 0.19)
	for r in rows:
		var y = 0.28 + r * (h - 0.4) / max(1, rows - 1)
		var x = -w / 2; 
		while x < w / 2 - 0.2:
			var L = min(rng.randf_range(1.6, 2.6), w / 2 - x + 0.1)
			_plank(parent, Vector3(x + L / 2, y + rng.randf_range(-0.05, 0.05), 0.04 + r % 2 * 0.012), L, rng.randf_range(0.2, 0.27), rng.randf_range(-0.06, 0.06))
			x += L - 0.08
	# diagonales
	for i in nposts - 1:
		var x0 = -w / 2 + 0.12 + i * (w - 0.24) / (nposts - 1); var x1 = -w / 2 + 0.12 + (i + 1) * (w - 0.24) / (nposts - 1)
		var L = Vector2(x1 - x0, h - 0.4).length()
		_plank(parent, Vector3((x0 + x1) / 2, h / 2, 0.1), L, 0.2, atan2(h - 0.4, x1 - x0) * (1 if i % 2 == 0 else -1))
	# sacos de arena en la base, por delante
	var sb: PackedScene = load("res://assets/models/props/sandbag.glb")
	var n = int(w / 0.62)
	for k in n:
		var s: Node3D = sb.instantiate(); parent.add_child(s); Interactables._fit(s, 0.24)
		s.position += Vector3(-w / 2 + 0.31 + k * (w - 0.62) / max(1, n - 1), 0, 0.42); s.rotation_degrees.y = rng.randf_range(-12, 12)
		if k % 2 == 0 and k + 1 < n:
			var s2: Node3D = sb.instantiate(); parent.add_child(s2); Interactables._fit(s2, 0.24)
			s2.position += Vector3(-w / 2 + 0.62 + k * (w - 0.62) / max(1, n - 1), 0.22, 0.42); s2.rotation_degrees.y = rng.randf_range(-12, 12)

# ------------------------------------------------------------------ texturas generadas
static var _wood: StandardMaterial3D
static func _wood_mat() -> StandardMaterial3D:
	if _wood: return _wood
	_wood = StandardMaterial3D.new()
	var img = Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var plank = int(y / 32); var g = 0.55 + 0.1 * sin(x * 0.05 + plank * 7.0) + randf_range(-0.04, 0.04)
			if y % 32 < 2: g *= 0.4
			img.set_pixel(x, y, Color(0.42 * g, 0.28 * g, 0.16 * g))
	_wood.albedo_texture = ImageTexture.create_from_image(img); _wood.roughness = 0.85
	return _wood

static func _chalk_tex(name: String, cost: int) -> Texture2D:
	var w = 384; var h = 200
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = Color(0.93, 0.92, 0.86, 0.9)
	# silueta de tiza (marco con trazo irregular)
	for i in 2600:
		var t = randf()
		var p: Vector2
		match randi() % 4:
			0: p = Vector2(20 + t * (w - 40), 30)
			1: p = Vector2(20 + t * (w - 40), h - 60)
			2: p = Vector2(20, 30 + t * (h - 90))
			_: p = Vector2(w - 20, 30 + t * (h - 90))
		p += Vector2(randf_range(-2, 2), randf_range(-2, 2))
		for k in 4:
			for j in 3: img.set_pixel(clamp(int(p.x) + k, 0, w - 1), clamp(int(p.y) + j, 0, h - 1), c)
	return ImageTexture.create_from_image(img)
