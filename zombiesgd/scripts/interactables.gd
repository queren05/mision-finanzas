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
	## servidor: cambia el mundo si se puede (en cooperativo lo piden los demás móviles)
	func world_do(_peer: int, _action: String, _arg: Variant) -> Dictionary: return { "ok": false }
	func on_evt(_name: String, _data: Variant) -> void: pass
	func can_pay(p: Player, cost: int) -> bool:
		if p.points < cost: Sfx.play("dryfire", 0.6); game.hud.flash_points(); return false
		return true
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
			game.stat("perks")
			p.give_perk(id); game.hud.banner(Data.PERKS[id].name.to_upper(), Data.PERKS[id].desc, 2.0)
			Voice.say("perk")

# ------------------------------------------------------------------ caja misteriosa
class MysteryBox extends Base:
	var spots: Array = []         # [[pos, yaw], ...]
	var spot = 0
	var state = "idle"           # idle, rolling, offer, leaving
	var st = 0.0
	var offer = ""
	var final = ""                # lo que sale de verdad (lo decide el servidor)
	var next_spot = 0
	var shown: Node3D
	var lid: Node3D
	var beam: MeshInstance3D
	var uses = 0
	var buyer = 0                 # peer del que ha pagado
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
		if state == "offer" and buyer == Net.my_id() and final != "teddy": return "Pulsa USAR: coger %s" % Data.WEAPONS[final].name
		return ""
	func use(p: Player) -> void:
		if state == "idle":
			if not can_pay(p, cost()): return
			var c = cost()
			var have = p.weapons.map(func(w): return w.id)
			game.world_request(self, "roll", { "have": have, "ww": p.gum("caja") }, func(_r):
				p.add_points(-c); Sfx.play("powerup", 0.5)
				if p.gum("caja"): p.gums.erase("caja"); game.hud.update_gums()
				game.stat("box"))
		elif state == "offer" and buyer == Net.my_id():
			var w = final
			game.world_request(self, "take", null, func(_r): p.give_weapon(w); Voice.say("box_good" if w in ["raygun", "bubble", "rpk", "galil"] else "box"))
	func world_do(peer: int, action: String, arg: Variant) -> Dictionary:
		var i = game.interactables.find(self)
		if action == "roll":
			if state != "idle": return { "ok": false }
			var teddy = uses > 3 and game.fire_sale <= 0.0 and spots.size() > 1 and randf() < 0.14 and not arg.get("ww", false)
			var pool: Array = []
			for k in Data.BOX_POOL:
				for n in int(Data.BOX_POOL[k]):
					if not k in arg.get("have", []): pool.append(k)
			var f = "teddy" if teddy else (pool[randi() % pool.size()] if pool.size() > 0 else "m1911")
			var wws = ["raygun", "bubble"].filter(func(x): return not x in arg.get("have", []))
			if arg.get("ww", false) and wws.size() > 0: f = wws.pick_random()
			var ns = spot
			if teddy:
				while ns == spot: ns = randi() % spots.size()
			game.evt("box_roll", { "i": i, "final": f, "peer": peer, "next": ns })
			return { "ok": true }
		if action == "take":
			if state != "offer" or buyer != peer: return { "ok": false }
			game.evt("box_taken", { "i": i })
			return { "ok": true }
		return { "ok": false }
	func on_evt(name: String, data: Variant) -> void:
		if name == "box_roll":
			state = "rolling"; st = 0.0; final = data.final; buyer = int(data.peer); next_spot = int(data.next); uses += 1
			Sfx.play_at("powerup", global_position + Vector3(0, 1, 0), 0.8, 0.7)
		elif name == "box_taken":
			_clear(); state = "idle"
	func _clear() -> void:
		if shown: shown.queue_free(); shown = null
	func _show(id: String, y: float) -> void:
		_clear()
		if id == "teddy":
			shown = Interactables.teddy(); add_child(shown); shown.position = Vector3(0, y, 0); return
		shown = Guns.make_world(id); shown.rotation_degrees.y = 90; add_child(shown); shown.position = Vector3(0, y, 0)
	func _process(d: float) -> void:
		st += d
		lid.rotation.x = lerp(lid.rotation.x, -1.6 if state != "idle" else 0.0, min(1.0, d * 6.0))
		if state == "rolling":
			if int(st * 7.0) != int((st - d) * 7.0):
				var keys: Array = Data.BOX_POOL.keys(); offer = keys[randi() % keys.size()]
				_show(offer, 0.7)
			if shown: shown.position = Vector3(0, 0.7 + min(st, 3.5) * 0.18, 0)
			if st > 4.2:
				_show(final, 1.33)
				if final == "teddy":
					# el osito: la caja se va a otro sitio y te devuelve el dinero
					state = "leaving"; st = 0.0
					game.hud.banner("¡ADIÓS, ADIÓS!", "La caja se va a otro sitio", 2.5); Voice.say("teddy")
					if buyer == Net.my_id(): game.player.add_points(950)
					return
				state = "offer"; st = 0.0
		elif state == "offer":
			if shown: shown.position.y = 1.33 - min(st / 9.0, 1.0) * 0.6
			if st > 9.0: _clear(); state = "idle"
		elif state == "leaving":
			position.y += d * 1.5
			if st > 2.5:
				_clear(); spot = next_spot
				_place(); state = "idle"; uses = 0
		beam.visible = state != "leaving"

# ------------------------------------------------------------------ Pack-a-Punch
class PackAPunch extends Base:
	var busy = 0.0
	var holding = ""              # arma dentro de la máquina
	var holder = 0                # peer de su dueño
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
		if busy > 0.0: return ""
		if holding != "" and holder == Net.my_id(): return "Pulsa USAR: coger %s" % Data.WEAPONS[holding].pap.name
		if holding != "": return ""
		if p.cur_w().pap: return "Esta arma ya está mejorada"
		return "Pulsa USAR: mejorar el arma [5000]"
	func use(p: Player) -> void:
		if not game.power_on or busy > 0.0: return
		if holding != "" and holder == Net.my_id():
			var w = holding
			game.world_request(self, "take", null, func(_r): p.give_weapon(w, true); Voice.say("pap"))
			return
		if holding != "" or p.cur_w().pap or not can_pay(p, 5000): return
		var wid: String = p.cur_w().id
		game.world_request(self, "insert", wid, func(_r):
			p.add_points(-5000); Sfx.play("powerup", 0.5)
			game.stat("pap")
			var k = p.has_weapon(wid)
			if k >= 0: p.weapons.remove_at(k)
			if p.weapons.is_empty(): p.weapons.append(p._new_w("m1911", false))
			p.cur = 0; p._equip())
	func world_do(peer: int, action: String, arg: Variant) -> Dictionary:
		var i = game.interactables.find(self)
		if action == "insert":
			if busy > 0.0 or holding != "" or not game.power_on: return { "ok": false }
			game.evt("pap_insert", { "i": i, "peer": peer, "w": arg }); return { "ok": true }
		if action == "take":
			if holding == "" or holder != peer or busy > 0.0: return { "ok": false }
			game.evt("pap_take", { "i": i }); return { "ok": true }
		return { "ok": false }
	func on_evt(name: String, data: Variant) -> void:
		if name == "pap_insert": holding = data.w; holder = int(data.peer); busy = 3.5; Sfx.play_at("powerup", global_position + Vector3(0, 1, 0), 1.0, 0.6)
		elif name == "pap_take": holding = ""; holder = 0
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
		game.world_request(self, "power", null, func(_r): pass)
	func world_do(_peer: int, action: String, _arg: Variant) -> Dictionary:
		if action != "power" or game.power_on: return { "ok": false }
		game.evt("power"); return { "ok": true }

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
		# el bloqueo invisible solo ocupa lo que se ve (tablones y sacos); antes medía 1,2 m de grueso y chocabas sin tocar nada
		var thick = 0.55 if d.get("kind", "barricade") != "hide" else 0.3
		if not d.get("auto", false): blocker = MapBuilder.make_box(Vector3(0, size.y / 2, 0.18 if d.get("kind", "barricade") != "hide" else 0.0), Vector3(size.x, size.y, thick), 0.0, MapBuilder.LAYER_BARRIER); add_child(blocker)
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
		if open or not can_pay(p, cost): return
		game.world_request(self, "open", null, func(_r): p.add_points(-cost); Sfx.play("powerup", 0.5); game.stat("doors"))
	func world_do(_peer: int, action: String, _arg: Variant) -> Dictionary:
		if action != "open" or open: return { "ok": false }
		game.evt("door", idx); return { "ok": true }
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

# ------------------------------------------------------------------ máquina de chicles (como la de Black Ops 3)
class GumMachine extends Base:
	var globe: MeshInstance3D
	func build(g: Node) -> void:
		game = g
		var red = StandardMaterial3D.new(); red.albedo_color = Color(0.75, 0.08, 0.1); red.metallic = 0.3; red.roughness = 0.4
		var base = MeshInstance3D.new(); var bm = CylinderMesh.new(); bm.top_radius = 0.28; bm.bottom_radius = 0.35; bm.height = 1.0; base.mesh = bm; base.position.y = 0.5; base.material_override = red; add_child(base)
		globe = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 0.36; sm.height = 0.72; globe.mesh = sm; globe.position.y = 1.36
		var glass = StandardMaterial3D.new(); glass.albedo_color = Color(0.8, 0.9, 1.0, 0.25); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glass.roughness = 0.05; glass.metallic_specular = 0.9; globe.material_override = glass; add_child(globe)
		var rng = RandomNumberGenerator.new(); rng.seed = 7
		var gums = Data.GUMS.keys()
		for k in 26:   # bolas de chicle de colores dentro
			var b = MeshInstance3D.new(); var bs = SphereMesh.new(); bs.radius = 0.06; bs.height = 0.12; b.mesh = bs
			var m = StandardMaterial3D.new(); m.albedo_color = Data.GUMS[gums[k % gums.size()]].color; m.roughness = 0.35; b.material_override = m
			var dir = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 0.3), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.0, 0.27)
			b.position = Vector3(0, 1.36, 0) + dir; add_child(b)
		var lab = Label3D.new(); lab.text = "CHICLES"; lab.font = load("res://assets/fonts/BlackOpsOne.ttf"); lab.font_size = 56; lab.pixel_size = 0.003; lab.modulate = Color(1, 0.85, 0.3); lab.outline_size = 6
		lab.position = Vector3(0, 0.7, 0.36); add_child(lab)
		var l = OmniLight3D.new(); l.light_color = Color(1, 0.5, 0.7); l.omni_range = 2.5; l.light_energy = 0.8; l.position = Vector3(0, 1.4, 0.6); add_child(l)
		Interactables._solid(self, Vector3(0.7, 1.8, 0.7), Vector3(0, 0.9, 0))
		reach = 1.7
	func cost() -> int: return 500 * (game.gum_uses + 1)
	func prompt(_p: Player) -> String:
		if game.gum_uses >= 3: return "Ya no quedan chicles en esta ronda"
		return "Pulsa USAR: chicle al azar [%d]" % cost()
	func use(p: Player) -> void:
		if game.gum_uses >= 3 or not pay(p, cost()): return
		game.gum_uses += 1
		var list = Data.GUMS.keys().filter(func(id): return GS.level >= int(Data.GUMS[id].level))
		p.give_gum(list.pick_random())
	func _process(d: float) -> void: globe.rotation.y += d * 0.5

# ------------------------------------------------------------------ easter egg: piezas, gambas de peluche y mesa de trabajo
class EggPart extends Base:
	var k = 0
	var spin: Node3D
	func build(g: Node, k_: int, what: String) -> void:
		game = g; k = k_
		spin = Node3D.new(); spin.position.y = 0.9; add_child(spin)
		var m = MeshInstance3D.new(); var bm = PrismMesh.new() if k == 1 else (TorusMesh.new() if k == 2 else BoxMesh.new())
		if bm is BoxMesh: bm.size = Vector3(0.25, 0.18, 0.12)
		if bm is PrismMesh: bm.size = Vector3(0.22, 0.25, 0.1)
		if bm is TorusMesh: bm.inner_radius = 0.07; bm.outer_radius = 0.14
		m.mesh = bm
		var mat = StandardMaterial3D.new(); mat.albedo_color = Color(1.0, 0.78, 0.25); mat.metallic = 0.9; mat.roughness = 0.25; mat.emission_enabled = true; mat.emission = Color(1.0, 0.6, 0.1); mat.emission_energy_multiplier = 0.6
		m.material_override = mat; spin.add_child(m)
		var l = OmniLight3D.new(); l.light_color = Color(1, 0.7, 0.3); l.omni_range = 2.2; l.light_energy = 1.0; l.position.y = 1.0; add_child(l)
		reach = 1.6
	func prompt(_p: Player) -> String: return "Pulsa USAR: coger %s" % Data.EGG[game.map_id].part
	func use(_p: Player) -> void: game.world_request(null, "egg_part", k, func(_r): pass)
	func _process(d: float) -> void:
		spin.rotation.y += d * 1.5; spin.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.003 + k) * 0.06
		if randf() < d * 2.0: Fx.sparkle(game, global_position + Vector3(0, 0.9, 0), Color(1, 0.8, 0.3))

class Plush extends Base:
	var k = 0
	func build(g: Node, k_: int) -> void:
		game = g; k = k_
		var piv = Node3D.new(); add_child(piv)
		var m: Node3D = load("res://assets/models/chars/gamba.glb").instantiate(); piv.add_child(m)
		Interactables._fit(piv, 0.3); piv.rotation_degrees.y = randf() * 360.0
		reach = 1.4
	func prompt(_p: Player) -> String: return "Pulsa USAR: ¿una gamba de peluche?"
	func use(_p: Player) -> void: game.world_request(null, "plush", k, func(_r): pass)

class EggBench extends Base:
	func build(g: Node) -> void:
		game = g
		var wood = Interactables._wood_mat()
		var top = MeshInstance3D.new(); var tm = BoxMesh.new(); tm.size = Vector3(1.6, 0.08, 0.7); top.mesh = tm; top.position.y = 0.9; top.material_override = wood; add_child(top)
		for x in [-0.7, 0.7]:
			for z in [-0.28, 0.28]:
				var leg = MeshInstance3D.new(); var lm = BoxMesh.new(); lm.size = Vector3(0.08, 0.9, 0.08); leg.mesh = lm; leg.position = Vector3(x, 0.45, z); leg.material_override = wood; add_child(leg)
		var lab = Label3D.new(); lab.text = "MESA DE TRABAJO"; lab.font = load("res://assets/fonts/Oswald.ttf"); lab.font_size = 36; lab.pixel_size = 0.003; lab.position = Vector3(0, 1.25, 0); lab.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; add_child(lab)
		Interactables._solid(self, Vector3(1.6, 0.95, 0.7), Vector3(0, 0.47, 0))
		reach = 1.9
	func prompt(_p: Player) -> String:
		var E: Dictionary = Data.EGG[game.map_id]
		match int(game.egg.step):
			0, 1: return "Faltan %s (%d/3)" % [E.parts, game.egg.found.count(true)] if game.egg.found.count(true) > 0 else ""
			2: return "Pulsa USAR: montar %s" % E.item
			3: return "Pulsa USAR: activar %s" % E.item if game.power_on else "Necesitas encender la corriente"
		return ""
	func use(_p: Player) -> void:
		match int(game.egg.step):
			2: game.world_request(null, "egg_build", null, func(_r): pass)
			3: game.world_request(null, "egg_start", null, func(_r): pass)

## osito de la caja misteriosa (cuando la caja se va)
static func teddy() -> Node3D:
	var n = Node3D.new()
	var brown = StandardMaterial3D.new(); brown.albedo_color = Color(0.45, 0.3, 0.15); brown.roughness = 0.9
	for e in [[Vector3(0, 0, 0), 0.16], [Vector3(0, 0.22, 0), 0.11], [Vector3(-0.08, 0.31, 0), 0.04], [Vector3(0.08, 0.31, 0), 0.04], [Vector3(-0.14, 0.03, 0), 0.05], [Vector3(0.14, 0.03, 0), 0.05]]:
		var m = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = e[1]; sm.height = e[1] * 2; m.mesh = sm; m.material_override = brown; m.position = e[0]; n.add_child(m)
	return n

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
