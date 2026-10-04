class_name Zombie
extends CharacterBody3D
## Enemigo: sale del suelo (o aparece con un rayo si es un perro), persigue al jugador más cercano con la malla de
## navegación (con evitación entre ellos), ataca con el golpe sincronizado a la animación y muere.
## Tipos: normal, perro infernal (rondas de perros), Bruto (jefe) e Hinchado (revienta en gas al morir).
## En cooperativo solo el servidor piensa; en los demás móviles es una "marioneta" que copia posición y animación.

const HEIGHT := 1.82
# velocidad (m/s) que cubre cada animación con el zombi a su altura (medidas con el pie de apoyo)
const GAITS := { "Walk": 0.37, "Shamble": 0.48, "Run": 2.5, "walk_7": 1.6, "run_fast": 6.0 }
const ATTACKS := { "Attack": [1.0, 1.35], "Attack2": [1.5, 1.95], "Attack3": [1.0, 1.35] }   # golpe y fin (s de clip)
const DOG_ATTACKS := { "attack01": [0.45, 0.9], "attack02": [0.6, 1.2] }
const ATK_RATE := 1.55
# todas las animaciones con un número (para mandarlas por red)
const ANIMS := ["Idle", "Idle2", "Scream", "Walk", "Shamble", "Run", "Attack", "Attack2", "Attack3", "Death", "Hit",
	"idle01", "walk_7", "run_fast", "hit01", "attack01", "attack02", "death_1_1"]
# datos de cada tipo: vida (veces la de la ronda), daño por golpe, radio y altura del cuerpo, puntos extra al matarlo
const TYPE_DATA := {
	"normal": { "hp": 1.0, "dmg": 55.0, "radius": 0.3, "height": 1.82, "pts": 0 },
	"dog": { "hp": 0.35, "dmg": 30.0, "radius": 0.35, "height": 1.0, "pts": 50 },
	"brute": { "hp": 14.0, "dmg": 90.0, "radius": 0.5, "height": 2.5, "pts": 500 },
	"bloat": { "hp": 2.0, "dmg": 55.0, "radius": 0.42, "height": 1.9, "pts": 40 },
}

var game: Node
var zid = 0
var type = "normal"
var kind = "a"
var model: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var head_bone = -1
var hips_bone = -1
var fall_off = 0.0
var rise_off = 0.0
var agent: NavigationAgent3D
var hp = 150.0
var max_hp = 150.0
var max_speed = 0.6
var gait = "Walk"
var gait_rate = 1.0
var state = "rise"
var t = 0.0
var dead = false
var atk_t = -1.0
var atk_hit = 0.0
var atk_end = 0.0
var atk_done = false
var atk_cd = 0.0
var repath_t = 0.0
var groan_t = 0.0
var hit_flinch = 0.0
var yaw = 0.0
var safe_vel = Vector3.ZERO
var stuck_t = 0.0
var last_check = Vector3.ZERO
var check_t = 0.0
var anim_acc = 0.0
var anim_frame = 0
var lod = 0                  # 0 cerca, 1 media distancia, 2 lejos o fuera de pantalla
var target: Node3D = null
var target_t = 0.0
var enraged = false
var bubbled = 0.0            # atrapado en una burbuja (arma maravilla)
# marioneta (cooperativo, en los clientes)
var puppet = false
var net_pos = Vector3.ZERO
var net_yaw = 0.0

func setup(g: Node, kind_: String, pos: Vector3, health: float, speed: float, type_ := "normal", puppet_ := false) -> void:
	game = g; type = type_; kind = kind_; puppet = puppet_
	var td: Dictionary = TYPE_DATA[type]
	max_hp = health * float(td.hp); hp = max_hp; max_speed = speed
	collision_layer = MapBuilder.LAYER_ZOMBIE
	collision_mask = 0 if puppet else (MapBuilder.LAYER_WORLD | MapBuilder.LAYER_SOFT | MapBuilder.LAYER_BARRIER)
	var cs = CollisionShape3D.new(); var cap = CapsuleShape3D.new(); cap.radius = float(td.radius); cap.height = max(float(td.height), cap.radius * 2.1); cs.shape = cap; cs.position.y = cap.height / 2
	if type == "dog": cs.rotation.x = PI / 2; cap.height = 1.4; cs.position.y = 0.55
	add_child(cs)
	model = Zombies.make("dog" if type == "dog" else kind, type); add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim: anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim_frame = randi() % 4
	skel = _find_skel(model)
	if skel:
		for i in skel.get_bone_count():
			var n = skel.get_bone_name(i)
			if n.contains("Head") and not n.contains("Top") and not n.contains("Nub") and head_bone < 0: head_bone = i
			if (n.contains("Hips") or n.contains("Pelvis")) and hips_bone < 0: hips_bone = i
	if not puppet:
		agent = NavigationAgent3D.new()
		agent.radius = float(td.radius) + 0.02; agent.height = float(td.height); agent.path_desired_distance = 0.6; agent.target_desired_distance = 0.9
		agent.avoidance_enabled = true; agent.neighbor_distance = 3.5; agent.max_neighbors = 8; agent.time_horizon_agents = 1.2; agent.max_speed = speed * 1.2
		agent.path_max_distance = 3.0
		add_child(agent)
		agent.velocity_computed.connect(func(v): safe_vel = v)
	_pick_gait()
	global_position = pos; net_pos = pos
	yaw = randf() * TAU
	if type == "dog":
		# los perros aparecen con un rayo
		model.position.y = 0.0; _play("idle01", 0.0, 1.0)
		game.lightning(pos)
	else:
		_play("Idle2" if randf() < 0.5 else "Scream", 0.0, 1.0)
		model.position.y = -float(td.height) - 0.1
	groan_t = randf_range(1.0, 5.0)

func _pick_gait() -> void:
	if type == "dog": gait = "run_fast" if max_speed > 3.0 else "walk_7"
	elif max_speed >= 1.6: gait = "Run"
	elif max_speed >= 0.55: gait = "Shamble"
	else: gait = "Walk"
	gait_rate = clamp(max_speed / (GAITS[gait] * _hscale()), 0.6, 1.7)

func _hscale() -> float: return float(TYPE_DATA[type].height) / 1.82 if type != "dog" else 1.0

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var s = _find_skel(c)
		if s: return s
	return null

func _play(name: String, blend := 0.2, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(name): return
	if anim.current_animation != name: anim.play(name, blend)
	anim.speed_scale = speed

func anim_code() -> int: return ANIMS.find(anim.current_animation) if anim else -1

func head_pos() -> Vector3:
	if skel and head_bone >= 0: return skel.global_transform * skel.get_bone_global_pose(head_bone).origin
	return global_position + Vector3(0, float(TYPE_DATA[type].height) - 0.15, 0)

## devuelve si ha muerto (solo en el servidor; en los clientes el daño se manda por red)
func take_hit(dmg: float, at: Vector3, head: bool, by, kind_ := "bullet", wid := "") -> bool:
	if dead: return false
	game.blood(at, head)
	if puppet: return false
	hp -= dmg
	hit_flinch = 0.25 if type != "brute" else 0.05
	if type == "brute" and not enraged and hp < max_hp * 0.5:
		enraged = true; max_speed = 2.6; _pick_gait(); _play("Scream", 0.15, 1.0); atk_t = -1.0
		Sfx.play_at("z_roar3", global_position + Vector3(0, 2, 0), 1.0, 0.6)
	if hp <= 0.0:
		die_visual(head)
		game.on_zombie_killed(self, head, by, kind_, wid)
		return true
	game.on_zombie_hurt(self, by, kind_, wid)
	return false

## lo que se ve al morir (también en las marionetas)
func die_visual(head: bool) -> void:
	if dead: return
	rise_off = model.position.y
	dead = true; state = "dead"; t = 0.0; lod = 0
	collision_layer = 0; collision_mask = MapBuilder.LAYER_WORLD
	if agent: agent.avoidance_enabled = false
	_play("death_1_1" if type == "dog" else "Death", 0.12, 1.15)
	Sfx.play_at("z_death%d" % randi_range(1, 3), global_position + Vector3(0, 1.4, 0), 0.8, 1.6 if type == "dog" else (0.7 if type == "brute" else 1.0))
	if type == "dog": Fx.explosion(game, global_position + Vector3(0, 0.5, 0))
	if type == "bloat": game.gas_burst(global_position + Vector3(0, 1.0, 0), not puppet)

func _process(delta: float) -> void:
	if anim == null: return
	anim_acc += delta; anim_frame += 1
	var every = [1, 2, 4][lod] * (2 if game.low_quality and lod > 0 else 1)
	if anim_frame % every == 0: anim.advance(anim_acc); anim_acc = 0.0

func _update_lod() -> void:
	var cam: Camera3D = game.player.cam
	var to = global_position + Vector3(0, 1.0, 0) - cam.global_position
	var d = to.length()
	var on_screen = d < 3.0 or to.normalized().dot(-cam.global_transform.basis.z) > 0.35
	lod = 0 if (d < 14.0 and on_screen) else (1 if (d < 30.0 and on_screen) else 2)

var skip_acc = 0.0
func _physics_process(delta: float) -> void:
	# rendimiento: los que están lejos o fuera de pantalla piensan a la mitad de ritmo
	if lod >= 1 and not dead and state == "chase" and atk_t < 0.0:
		if (Engine.get_physics_frames() + zid) % 2 == 1: skip_acc += delta; return
		delta += skip_acc
	skip_acc = 0.0
	t += delta
	if puppet: _puppet(delta); return
	if dead:
		# el cuerpo cae al suelo (aunque muera en el aire o en una escalera)
		velocity = Vector3.ZERO
		if t < 0.1:
			var r = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position - Vector3(0, 1.5, 0), MapBuilder.LAYER_WORLD))
			if not r.is_empty(): global_position.y = r.position.y
		_lie_down(delta)
		if t > 6.5: queue_free()
		return
	target_t -= delta
	if target_t <= 0.0 or target == null or not is_instance_valid(target):
		target_t = 0.5; target = game.target_for(global_position)
	var P: Node3D = target
	if P == null: return
	groan_t -= delta
	if groan_t < 0.0:
		groan_t = randf_range(3.0, 8.0) if type != "dog" else randf_range(1.5, 3.5)
		if global_position.distance_to(game.player.global_position) < 18.0:
			Sfx.play_at("z_roar%d" % randi_range(1, 3), global_position + Vector3(0, 1.5, 0), 0.55, randf_range(0.85, 1.1) * (1.7 if type == "dog" else (0.65 if type == "brute" else 1.0)))
	if state == "rise":
		var rise_time = 0.8 if type == "dog" else 1.6
		if type != "dog":
			model.position.y = lerp(-float(TYPE_DATA[type].height) - 0.1, 0.0, clamp(t / rise_time, 0.0, 1.0))
			if randf() < 0.3: game.dust(global_position)
		_face((P.global_position - global_position), delta * 3.0)
		rotation.y = yaw
		if t >= rise_time + 0.1: state = "chase"; model.position.y = 0.0; _play(gait, 0.3, gait_rate)
		return
	# burbuja del arma maravilla: flota sin poder moverse
	if bubbled > 0.0:
		bubbled -= delta; velocity = Vector3.ZERO
		model.position.y = lerp(model.position.y, 1.3, min(1.0, delta * 2.0)); yaw += delta * 1.5; rotation.y = yaw
		if bubbled <= 0.0: model.position.y = 0.0
		return
	# perseguir
	var to_p = P.global_position - global_position; to_p.y = 0
	var d = to_p.length()
	var reach = 1.05 if type == "normal" else (1.5 if type == "brute" else 1.2)
	atk_cd -= delta
	if atk_t >= 0.0:
		atk_t += delta
		if atk_t >= atk_hit and not atk_done:
			atk_done = true
			if global_position.distance_to(P.global_position) < reach + 0.45 and abs(P.global_position.y - global_position.y) < 1.2:
				game.damage_player(P, float(TYPE_DATA[type].dmg))   # como en Black Ops: 2 golpes te tumban, 5 con Juggernog
		if atk_t >= atk_end: atk_t = -1.0; _play(gait, 0.2, gait_rate)
		_face(to_p, delta * 6.0); rotation.y = yaw
		velocity = velocity.lerp(Vector3.ZERO, min(1.0, delta * 10.0)); _nav_move(delta)
		return
	if d < reach and game.can_attack(P) and atk_cd <= 0.0:
		var table = DOG_ATTACKS if type == "dog" else ATTACKS
		var names = table.keys(); var n: String = names[randi() % names.size()]
		var rate = 1.0 if type == "dog" else (ATK_RATE * (0.8 if type == "brute" else 1.0))
		atk_t = 0.0; atk_done = false; atk_cd = 1.1 if type != "dog" else 0.7
		atk_hit = table[n][0] / rate; atk_end = table[n][1] / rate
		_play(n, 0.12, rate)
		return
	repath_t -= delta
	if repath_t <= 0.0:
		repath_t = (0.25 if d < 15.0 else 0.6) + randf() * 0.1   # los lejanos recalculan el camino menos a menudo
		agent.target_position = P.global_position
		_update_lod()
	var want = Vector3.ZERO
	if not agent.is_navigation_finished():
		var nxt = agent.get_next_path_position()
		want = (nxt - global_position); want.y = 0
		if want.length() > 0.01: want = want.normalized()
	elif d > 0.9:
		want = to_p.normalized()
	var spd = max_speed * (0.35 if hit_flinch > 0.0 else 1.0)
	if d < reach * 0.95: spd = 0.0
	hit_flinch -= delta
	# gira con velocidad limitada y avanza hacia donde mira (sin patinar de lado)
	if want.length() > 0.01: _face(want, delta * (3.0 + max_speed))
	var fwd = Vector3(sin(yaw), 0, cos(yaw))
	var align: float = max(0.0, fwd.dot(want)) if want.length() > 0.01 else 0.0
	agent.velocity = fwd * spd * (align * align)
	var v = safe_vel if agent.avoidance_enabled else agent.velocity
	velocity.x = lerp(velocity.x, v.x, min(1.0, delta * 8.0)); velocity.z = lerp(velocity.z, v.z, min(1.0, delta * 8.0))
	_nav_move(delta)
	rotation.y = yaw
	# atascado (sin camino o sin avanzar): como en Black Ops, reaparece en otro sitio si no lo estás mirando
	check_t += delta
	if check_t > 1.0:
		var moved = global_position.distance_to(last_check)
		if d > 2.5 and (moved < 0.25 or agent.is_navigation_finished()): stuck_t += check_t
		else: stuck_t = 0.0
		last_check = global_position; check_t = 0.0
		if stuck_t > 5.0 and not game._visible_from_player(global_position + Vector3(0, 1.2, 0)):
			stuck_t = 0.0; game.respawn_zombie(self)
	# animación al ritmo de la velocidad real
	var real = Vector2(velocity.x, velocity.z).length()
	if real < 0.08: _play("idle01" if type == "dog" else "Idle", 0.3, 1.0)
	else: _play(gait, 0.25, clamp(real / (GAITS[gait] * _hscale()), 0.3, 1.9))

## tumbado en el suelo: algunas animaciones de muerte no bajan la cadera, se baja el cuerpo a mano
func _lie_down(delta: float) -> void:
	if hips_bone >= 0 and t > 0.35 and type != "dog":
		var hy = (skel.global_transform * skel.get_bone_global_pose(hips_bone).origin).y - model.global_position.y
		var want = min(0.0, 0.24 - hy) * clamp((t - 0.35) / 0.8, 0.0, 1.0)
		fall_off = lerp(fall_off, want, min(1.0, delta * 10.0))
	model.position.y = fall_off + rise_off - (max(0.0, t - 4.5) * 0.6)

## marioneta: va hacia la última posición recibida y pone la animación que le dicen
func _puppet(delta: float) -> void:
	if dead:
		_lie_down(delta)
		if t > 6.5: queue_free()
		return
	global_position = global_position.lerp(net_pos, min(1.0, delta * 12.0)) if global_position.distance_to(net_pos) < 4.0 else net_pos
	yaw = lerp_angle(yaw, net_yaw, min(1.0, delta * 12.0)); rotation.y = yaw
	if state == "rise" and type != "dog":
		model.position.y = lerp(-float(TYPE_DATA[type].height) - 0.1, 0.0, clamp(t / 1.6, 0.0, 1.0))
		if t > 1.7: state = "chase"; model.position.y = 0.0
	if int(t * 2) != int((t - delta) * 2): _update_lod()

func net_update(pos: Vector3, yaw_: float, code: int, speed: float, lift: float) -> void:
	net_pos = pos; net_yaw = yaw_
	if state != "rise": model.position.y = lift
	if code >= 0 and code < ANIMS.size() and not dead: _play(ANIMS[code], 0.2, speed)

## rendimiento: los zombis no usan la física para moverse (era lo que más costaba con muchos en pantalla);
## avanzan sobre la malla de navegación, que ya evita paredes y huecos, y se pegan a su altura
var nav_map: RID
var floor_t = 0
var floor_y = 0.0
func _nav_move(delta: float) -> void:
	var want = global_position + Vector3(velocity.x, 0, velocity.z) * delta
	if not nav_map.is_valid(): nav_map = get_world_3d().navigation_map
	var q = NavigationServer3D.map_get_closest_point(nav_map, want + Vector3(0, 0.4, 0))
	if q == Vector3.ZERO and NavigationServer3D.map_get_iteration_id(nav_map) == 0: return
	if Vector2(q.x - want.x, q.z - want.z).length() > 1.0: q = Vector3(want.x, q.y, want.z) if abs(q.y - want.y) < 1.0 else global_position
	# la malla de navegación va un poco por encima del suelo: los pies se apoyan en el suelo de verdad (un rayo hacia abajo)
	floor_t -= 1
	if floor_t <= 0:
		floor_t = 1 if lod == 0 else 3
		var r = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, q.y + 0.6, q.z), Vector3(q.x, q.y - 1.2, q.z), MapBuilder.LAYER_WORLD))
		floor_y = r.position.y if not r.is_empty() else q.y - 0.15
	global_position = Vector3(q.x, lerp(global_position.y, floor_y, min(1.0, delta * 18.0)), q.z)

func _gravity(delta: float) -> void:
	if not is_on_floor(): velocity.y -= 18.0 * delta
	else: velocity.y = -0.5

func _face(dir: Vector3, k: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.001: return
	var a = atan2(dir.x, dir.z)
	yaw = lerp_angle(yaw, a, clamp(k, 0.0, 1.0))
