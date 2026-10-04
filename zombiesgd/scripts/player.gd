class_name Player
extends CharacterBody3D
## El jugador en primera persona: movimiento (con escalones), salud, armas, cuchillo, granadas e interacción.

signal died
signal points_changed(p: int, delta: int)

const EYE := 1.62
var game: Node
var head: Node3D
var cam: Camera3D
var vm: Node3D                      # soporte del arma en mano
var gun_node: Node3D
var muzzle_light: OmniLight3D
var flash: Sprite3D

var yaw = 0.0
var pitch = 0.0
var hp = 100.0
var max_hp = 100.0
var hurt_t = 99.0
var alive = true
var downed = false
var down_t = 0.0
var revives_left = 0
var points = 500
var perks: Array[String] = []
var weapons: Array = []             # {id, pap, mag, res}
var cur = 0
var grenades = 2
var stamina = 1.0
var kills = 0
var headshots = 0
var downs = 0

# estado del arma
var fire_cd = 0.0
var reload_t = 0.0
var swap_t = 0.0
var knife_t = 0.0
var ads = 0.0
var recoil = Vector2.ZERO
var kick = 0.0
var bob_t = 0.0
var spread_add = 0.0
var fire_prev = false
var nade_t = 0.0
var interact_target: Node = null

func _ready() -> void:
	collision_layer = MapBuilder.LAYER_PLAYER
	collision_mask = MapBuilder.LAYER_WORLD | MapBuilder.LAYER_SOFT | MapBuilder.LAYER_BARRIER | MapBuilder.LAYER_ZOMBIE
	floor_max_angle = deg_to_rad(46); floor_snap_length = 0.45; safe_margin = 0.02
	var cs = CollisionShape3D.new(); var cap = CapsuleShape3D.new(); cap.radius = 0.34; cap.height = 1.78; cs.shape = cap; cs.position.y = 0.89; add_child(cs)
	head = Node3D.new(); head.position.y = EYE; add_child(head)
	cam = Camera3D.new(); cam.fov = float(GS.settings.fov); cam.near = 0.03; cam.far = 400.0; cam.current = true; head.add_child(cam)
	vm = Node3D.new(); cam.add_child(vm)
	muzzle_light = OmniLight3D.new(); muzzle_light.light_color = Color(1, 0.75, 0.4); muzzle_light.omni_range = 6; muzzle_light.light_energy = 0; cam.add_child(muzzle_light); muzzle_light.position = Vector3(0.15, -0.1, -0.9)
	flash = Sprite3D.new(); flash.texture = _flash_tex(); flash.pixel_size = 0.0016; flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED; flash.visible = false
	flash.modulate = Color(1, 0.85, 0.55); flash.shaded = false; flash.no_depth_test = true; flash.render_priority = 10; cam.add_child(flash)

func setup(start_weapon: String, start_perk: String) -> void:
	weapons = [_new_w(start_weapon, false)]
	if start_weapon != "m1911": weapons.append(_new_w("m1911", false))
	cur = 0
	if start_perk != "": give_perk(start_perk)
	_equip()

func _new_w(id: String, pap: bool) -> Dictionary:
	return { "id": id, "pap": pap, "mag": int(stat_of(id, pap, "mag")), "res": int(stat_of(id, pap, "res")) }

static func stat_of(id: String, pap: bool, k: String):
	var w: Dictionary = Data.WEAPONS[id]
	if pap and w.pap.has(k): return w.pap[k]
	return w.get(k)

func stat(k: String): var w: Dictionary = weapons[cur]; return stat_of(w.id, w.pap, k)
func cur_w() -> Dictionary: return weapons[cur]
func max_guns() -> int: return 3 if "mule" in perks else 2

# ------------------------------------------------------------------ física
func _physics_process(delta: float) -> void:
	Controls.poll(delta)
	if game.paused: Controls.consume(); return
	_look(delta)
	_move(delta)
	_health(delta)
	if alive and not downed:
		_weapon(delta)
		_interact()
	_view(delta)
	Controls.consume()

func _look(delta: float) -> void:
	var lk = Controls.look
	if GS.settings.aim_assist and Controls.device != "kb" and game.zombie_under_crosshair(cam, 40.0): lk *= 0.55
	if ads > 0.5: lk *= 0.7
	yaw += lk.x; pitch = clamp(pitch + lk.y, deg_to_rad(-85), deg_to_rad(85))
	pitch += recoil.y * delta * 10.0; yaw += recoil.x * delta * 10.0
	recoil = recoil.lerp(Vector2.ZERO, min(1.0, delta * 14.0))
	rotation.y = yaw; head.rotation.x = pitch

func _move(delta: float) -> void:
	var mv = Controls.move if alive and not downed else Vector2.ZERO
	var sprint = Controls.is_held("sprint") or (Controls.device == "touch" and mv.y > 0.92)
	sprint = sprint and mv.y > 0.4 and ads < 0.3 and reload_t <= 0.0 and stamina > 0.05
	var base = 4.1 if not downed else 0.9
	var spd = base * (1.55 if sprint else 1.0) * lerp(1.0, 0.6, ads) * (0.82 if mv.y < -0.1 else 1.0)
	if "stamin" in perks: spd *= 1.12
	stamina = clamp(stamina + (-delta / (8.0 if "stamin" in perks else 4.0) if sprint else delta / 3.0), 0.0, 1.0)
	var fwd = -transform.basis.z; var right = transform.basis.x
	var want = (fwd * mv.y + right * mv.x) * spd
	var acc = 14.0 if is_on_floor() else 3.0
	velocity.x = lerp(velocity.x, want.x, min(1.0, acc * delta)); velocity.z = lerp(velocity.z, want.z, min(1.0, acc * delta))
	if is_on_floor():
		if Controls.was_pressed("jump") and alive and not downed: velocity.y = 4.6
	else:
		velocity.y -= 18.0 * delta
	var pre = global_position
	move_and_slide()
	# escalones: si se choca contra algo bajo estando en el suelo, intenta subirlo (hasta 45 cm)
	if is_on_floor() and is_on_wall() and Vector2(want.x, want.z).length() > 0.5:
		var step = Vector3(want.x, 0, want.z).normalized() * 0.25
		var up = Vector3(0, 0.46, 0)
		if not test_move(global_transform, up) and not test_move(global_transform.translated(up), step):
			global_position += up + step
			apply_floor_snap()
	if sprint and Vector2(velocity.x, velocity.z).length() > 3: bob_t += delta * 13.0
	elif Vector2(velocity.x, velocity.z).length() > 0.5: bob_t += delta * 9.0
	if Vector2(velocity.x, velocity.z).length() > 0.6 and is_on_floor():
		var stepping = int(bob_t / PI)
		if stepping != int((bob_t - delta * 9.0) / PI): Sfx.play("step_%d" % randi_range(0, 3), 0.25)

var safe_pos = Vector3.ZERO
var safe_t = 0.0
## nunca salir del mapa: si caes o te alejas de cualquier zona transitable, vuelves al último sitio seguro
func _keep_in_map(delta: float) -> void:
	safe_t -= delta
	if safe_t > 0.0: return
	safe_t = 0.2
	var map = get_world_3d().navigation_map
	var q = NavigationServer3D.map_get_closest_point(map, global_position)
	var off = Vector2(q.x - global_position.x, q.z - global_position.z).length()
	if global_position.y < q.y - 3.0 or off > 2.6:
		if safe_pos != Vector3.ZERO: global_position = safe_pos; velocity = Vector3.ZERO
	elif is_on_floor() and off < 0.9:
		safe_pos = global_position

func _health(delta: float) -> void:
	_keep_in_map(delta)
	hurt_t += delta
	if alive and not downed and hurt_t > 3.0: hp = min(max_hp, hp + delta * 70.0)
	if downed:
		down_t += delta
		if revives_left > 0 and down_t > 3.5: _revive()
		elif revives_left <= 0 and down_t > 2.2 and alive: alive = false; died.emit()

func take_damage(n: float) -> void:
	if not alive or downed or game.god: return
	hp -= n; hurt_t = 0.0
	Sfx.play("pain%d" % randi_range(1, 2), 0.7)
	game.hud.hurt_flash()
	if hp <= 0:
		hp = 0; downed = true; down_t = 0.0; downs += 1
		revives_left = 1 if "revive" in perks else 0
		perks.clear(); max_hp = 100.0
		game.hud.update_perks(perks)

func _revive() -> void:
	downed = false; hp = max_hp; revives_left = 0
	game.hud.banner("¡TE HAS LEVANTADO!", "Has perdido tus ventajas", 2.5)

# ------------------------------------------------------------------ armas
func _weapon(delta: float) -> void:
	fire_cd -= delta; swap_t -= delta; knife_t -= delta; nade_t -= delta
	var w = cur_w()
	var want_ads = Controls.is_held("ads") and swap_t <= 0.0 and knife_t <= 0.0
	ads = move_toward(ads, 1.0 if want_ads else 0.0, delta * 6.0)
	spread_add = move_toward(spread_add, 0.0, delta * 6.0)
	# recarga
	if reload_t > 0.0:
		reload_t -= delta * (2.0 if "speed" in perks else 1.0)
		if reload_t <= 0.0:
			var need: int = int(stat("mag")) - int(w.mag); var take: int = min(need, int(w.res))
			w.mag += take; w.res -= take
			game.hud.update_ammo()
	if Controls.was_pressed("reload") and reload_t <= 0.0 and w.mag < int(stat("mag")) and w.res > 0 and swap_t <= 0.0: _start_reload()
	if Controls.was_pressed("swap") and weapons.size() > 1 and reload_t <= 0.0:
		cur = (cur + 1) % weapons.size(); _equip(); swap_t = 0.55
	if Controls.was_pressed("knife") and knife_t <= 0.0: _knife()
	if Controls.was_pressed("grenade") and grenades > 0 and nade_t <= 0.0: _throw_grenade()
	# disparo
	var fire = Controls.is_held("fire")
	var auto: bool = stat("auto")
	if fire and (auto or not fire_prev) and fire_cd <= 0.0 and swap_t <= 0.0 and knife_t <= 0.0 and reload_t <= 0.0:
		if w.mag > 0: _shoot()
		elif w.res > 0: _start_reload()
		elif not fire_prev: Sfx.play("dryfire", 0.6)
	fire_prev = fire

func _start_reload() -> void:
	reload_t = float(stat("reload")); Sfx.play(str(stat("reload_snd")), 0.7)

func _shoot() -> void:
	var w = cur_w()
	w.mag -= 1
	var rpm = float(stat("rpm")) * (1.33 if "dtap" in perks else 1.0)
	fire_cd = 60.0 / rpm
	Sfx.play(str(stat("sound")), 0.9, 1.0 if not w.pap else 0.85)
	var rc = float(stat("recoil"))
	recoil += Vector2(randf_range(-0.3, 0.3) * rc * 0.01, rc * 0.018 * (0.6 if ads > 0.5 else 1.0))
	kick = 1.0; spread_add = min(spread_add + 0.6, 3.0)
	muzzle_light.light_energy = 3.0; flash.visible = true; flash.rotation.z = randf() * TAU
	get_tree().create_timer(0.05).timeout.connect(func(): muzzle_light.light_energy = 0.0; flash.visible = false)
	var base_spread = lerp(float(stat("spread")), float(stat("ads_spread")), ads) + spread_add * (1.0 - ads * 0.7)
	if not is_on_floor(): base_spread += 3.0
	var pellets = int(stat("pellets"))
	var dmg = float(stat("dmg")) * (1.0 if not ("dtap" in perks) else 1.15)
	var hit_any = false; var kill_any = false; var head_any = false
	for i in pellets:
		var dir = -cam.global_transform.basis.z
		var sp = deg_to_rad(base_spread) * sqrt(randf())
		var ang = randf() * TAU
		dir = dir.rotated(cam.global_transform.basis.x, sin(ang) * sp).rotated(cam.global_transform.basis.y, cos(ang) * sp)
		var res = game.shoot_ray(cam.global_position, dir, float(stat("range")), self)
		if res.hit: hit_any = true
		if res.kill: kill_any = true
		if res.head: head_any = true
	if stat("explosive") != null:
		var r = game.ray_world(cam.global_position, -cam.global_transform.basis.z, 60.0)
		game.explode(r if r != Vector3.INF else cam.global_position - cam.global_transform.basis.z * 20.0, float(stat("explosive")), dmg, self)
	if hit_any: game.hud.hitmarker(kill_any, head_any)
	game.hud.update_ammo()
	if w.mag == 0 and w.res > 0: get_tree().create_timer(0.25).timeout.connect(func(): if reload_t <= 0.0 and cur_w() == w and w.mag == 0: _start_reload())

func _knife() -> void:
	knife_t = 0.6; Sfx.play("knife", 0.8)
	var z = game.nearest_zombie(global_position + Vector3(0, 1, 0) - transform.basis.z * 0.8, 1.4)
	if z: z.take_hit(150.0 if not ("jugg" in perks) else 150.0, z.global_position + Vector3(0, 1.2, 0), false, self, "knife"); game.hud.hitmarker(z.dead, false)

func _throw_grenade() -> void:
	grenades -= 1; nade_t = 1.0; game.hud.update_ammo()
	game.throw_grenade(cam.global_position - cam.global_transform.basis.z * 0.5, (-cam.global_transform.basis.z + Vector3(0, 0.25, 0)).normalized() * 14.0 + velocity * 0.5, self)

func give_weapon(id: String, pap := false) -> void:
	for i in weapons.size():
		if weapons[i].id == id:
			weapons[i] = _new_w(id, pap or weapons[i].pap if not pap else true); cur = i; _equip(); return
	if weapons.size() >= max_guns(): weapons[cur] = _new_w(id, pap)
	else: weapons.append(_new_w(id, pap)); cur = weapons.size() - 1
	_equip()

func has_weapon(id: String) -> int:
	for i in weapons.size():
		if weapons[i].id == id: return i
	return -1

func refill_ammo() -> void:
	for w in weapons: w.mag = int(stat_of(w.id, w.pap, "mag")); w.res = int(stat_of(w.id, w.pap, "res"))
	grenades = max(grenades, 4) if grenades < 4 else grenades
	game.hud.update_ammo()

func refill_grenades() -> void:
	grenades = min(4, grenades + 2)
	if game and game.hud: game.hud.update_ammo()

func give_perk(id: String) -> void:
	if id in perks: return
	perks.append(id)
	if id == "jugg": max_hp = 250.0; hp = max_hp
	if game and game.hud: game.hud.update_perks(perks)

func add_points(n: int) -> void:
	points += n; points_changed.emit(points, n)

func _equip() -> void:
	reload_t = 0.0
	if gun_node: gun_node.queue_free()
	var w = cur_w()
	gun_node = Guns.make_view(w.id, w.pap)
	vm.add_child(gun_node)
	if game and game.hud: game.hud.update_ammo()

# ------------------------------------------------------------------ interacción
func _interact() -> void:
	interact_target = game.find_interactable(self)
	game.hud.show_prompt(interact_target.prompt(self) if interact_target else "")
	if interact_target and Controls.was_pressed("use"): interact_target.use(self)

# ------------------------------------------------------------------ vista del arma
func _view(delta: float) -> void:
	var w = cur_w() if weapons.size() > 0 else null
	var scope: bool = w != null and stat("scope") == true and ads > 0.9
	cam.fov = lerp(float(GS.settings.fov), 22.0 if scope else float(GS.settings.fov) * 0.78, ads)
	game.hud.set_scope(scope)
	if gun_node == null: return
	gun_node.visible = not scope and not downed
	var len = float(Data.WEAPONS[w.id].len)
	var hip = Vector3(0.16, -0.145, -0.3 - len * 0.3)
	var aim = Vector3(0.0, -0.085, -0.22 - len * 0.3)
	var spd = Vector2(velocity.x, velocity.z).length()
	var bob = Vector3(sin(bob_t) * 0.012, abs(cos(bob_t)) * -0.01, 0) * min(1.0, spd / 4.0) * (1.0 - ads * 0.85)
	kick = move_toward(kick, 0.0, delta * 9.0)
	var p = hip.lerp(aim, ads) + bob + Vector3(0, 0, kick * 0.04)
	var rot = Vector3(kick * 0.06, 0, 0)
	if reload_t > 0.0:
		var k: float = sin(clamp(1.0 - reload_t / max(0.01, float(stat("reload"))), 0.0, 1.0) * PI)
		p += Vector3(-0.05, -0.12, 0.04) * k; rot += Vector3(-0.5, 0.2, 0.6) * k
	if swap_t > 0.0: p.y -= swap_t * 0.5
	if knife_t > 0.3: p += Vector3(-0.15, -0.05, -0.1); rot += Vector3(0, 0.6, -0.4)
	vm.position = vm.position.lerp(p, min(1.0, delta * 18.0))
	vm.rotation = vm.rotation.lerp(rot, min(1.0, delta * 14.0))
	flash.position = vm.position + Vector3(0, 0.02, -len * 0.85)

func _flash_tex() -> Texture2D:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d = Vector2(x - 32, y - 32).length() / 32.0
			var star: float = max(0.0, 1.0 - abs(atan2(y - 32, x - 32) * 3.0 - round(atan2(y - 32, x - 32) * 3.0 / PI) * PI) * 1.2)
			var a: float = clamp((1.0 - d) * 1.6 + star * (1.0 - d) * 0.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
