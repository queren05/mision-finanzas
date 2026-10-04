class_name Zombie
extends CharacterBody3D
## Zombi: sale del suelo, persigue al jugador con la malla de navegación (con evitación entre ellos),
## ataca con el golpe sincronizado a la animación y muere. Animaciones de Mixamo al ritmo de su velocidad real.

const HEIGHT := 1.82
# velocidad (m/s) que cubre cada animación con el zombi a HEIGHT (medidas con el pie de apoyo)
const GAITS := { "Walk": 0.37, "Shamble": 0.48, "Run": 2.5 }
const ATTACKS := { "Attack": [1.0, 1.35], "Attack2": [1.5, 1.95], "Attack3": [1.0, 1.35] }   # golpe y fin (s de clip)
const ATK_RATE := 1.55

var game: Node
var model: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var head_bone = -1
var agent: NavigationAgent3D
var hp = 150.0
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
var rise_from = 0.0
var dbg_align = 0.0
var stuck_t = 0.0
var last_check = Vector3.ZERO
var check_t = 0.0
var anim_acc = 0.0
var anim_frame = 0
var lod = 0                  # 0 cerca, 1 media distancia, 2 lejos o fuera de pantalla

func setup(g: Node, kind: String, pos: Vector3, health: float, speed: float) -> void:
	game = g; hp = health; max_speed = speed
	collision_layer = MapBuilder.LAYER_ZOMBIE
	collision_mask = MapBuilder.LAYER_WORLD | MapBuilder.LAYER_SOFT | MapBuilder.LAYER_BARRIER
	var cs = CollisionShape3D.new(); var cap = CapsuleShape3D.new(); cap.radius = 0.3; cap.height = HEIGHT; cs.shape = cap; cs.position.y = HEIGHT / 2; add_child(cs)
	model = Zombies.make(kind); add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	# optimización: la animación se avanza a mano, más a menudo cuanto más cerca y visible está
	if anim: anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim_frame = randi() % 4
	skel = _find_skel(model)
	if skel:
		for i in skel.get_bone_count():
			var n = skel.get_bone_name(i)
			if n.contains("Head") and not n.contains("Top"): head_bone = i; break
	agent = NavigationAgent3D.new()
	agent.radius = 0.32; agent.height = HEIGHT; agent.path_desired_distance = 0.6; agent.target_desired_distance = 0.9
	agent.avoidance_enabled = true; agent.neighbor_distance = 3.5; agent.max_neighbors = 8; agent.time_horizon_agents = 1.2; agent.max_speed = speed * 1.2
	agent.path_max_distance = 3.0
	add_child(agent)
	agent.velocity_computed.connect(func(v): safe_vel = v)
	# elegir la marcha cuya animación cubre esa velocidad
	if speed >= 1.6: gait = "Run"
	elif speed >= 0.55: gait = "Shamble"
	else: gait = "Walk"
	gait_rate = clamp(speed / GAITS[gait], 0.75, 1.7)
	global_position = pos
	rise_from = pos.y
	yaw = randf() * TAU
	_play("Idle2" if randf() < 0.5 else "Scream", 0.0, 1.0)
	model.position.y = -HEIGHT - 0.1
	groan_t = randf_range(1.0, 5.0)

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

func head_pos() -> Vector3:
	if skel and head_bone >= 0: return skel.global_transform * skel.get_bone_global_pose(head_bone).origin
	return global_position + Vector3(0, HEIGHT - 0.15, 0)

## devuelve si ha muerto
func take_hit(dmg: float, at: Vector3, head: bool, by: Node, kind := "bullet") -> bool:
	if dead: return false
	hp -= dmg
	hit_flinch = 0.25
	game.blood(at, head)
	if hp <= 0.0:
		_die(head, by, kind); return true
	game.on_zombie_hurt(self, by, kind)
	return false

func _die(head: bool, by: Node, kind: String) -> void:
	dead = true; state = "dead"; t = 0.0; lod = 0
	collision_layer = 0; collision_mask = MapBuilder.LAYER_WORLD
	agent.avoidance_enabled = false
	_play("Death", 0.12, 1.15)
	Sfx.play_at("z_death%d" % randi_range(1, 3), global_position + Vector3(0, 1.4, 0), 0.8)
	game.on_zombie_killed(self, head, by, kind)

func _process(delta: float) -> void:
	if anim == null: return
	anim_acc += delta; anim_frame += 1
	var every = [1, 2, 4][lod]
	if anim_frame % every == 0: anim.advance(anim_acc); anim_acc = 0.0

func _update_lod() -> void:
	var cam: Camera3D = game.player.cam
	var to = global_position + Vector3(0, 1.0, 0) - cam.global_position
	var d = to.length()
	var on_screen = d < 3.0 or to.normalized().dot(-cam.global_transform.basis.z) > 0.35
	lod = 0 if (d < 14.0 and on_screen) else (1 if (d < 30.0 and on_screen) else 2)

func _physics_process(delta: float) -> void:
	t += delta
	if dead:
		if t > 4.5: model.position.y -= delta * 0.6
		if t > 6.5: queue_free()
		return
	var P: Player = game.player
	groan_t -= delta
	if groan_t < 0.0:
		groan_t = randf_range(3.0, 8.0)
		if global_position.distance_to(P.global_position) < 18.0: Sfx.play_at("z_roar%d" % randi_range(1, 3), global_position + Vector3(0, 1.5, 0), 0.55, randf_range(0.85, 1.1))
	if state == "rise":
		model.position.y = lerp(-HEIGHT - 0.1, 0.0, clamp(t / 1.6, 0.0, 1.0))
		if randf() < 0.3: game.dust(global_position)
		_face((P.global_position - global_position), delta * 3.0)
		rotation.y = yaw
		if t >= 1.7: state = "chase"; model.position.y = 0.0; _play(gait, 0.3, gait_rate)
		return
	# perseguir
	var to_p = P.global_position - global_position; to_p.y = 0
	var d = to_p.length()
	atk_cd -= delta
	if atk_t >= 0.0:
		atk_t += delta
		if atk_t >= atk_hit and not atk_done:
			atk_done = true
			if global_position.distance_to(P.global_position) < 1.45 and abs(P.global_position.y - global_position.y) < 1.2 and P.alive:
				P.take_damage(55.0)   # como en Black Ops: 2 golpes te tumban, 5 con Juggernog
				Sfx.play_at("z_hit%d" % randi_range(1, 2), P.global_position + Vector3(0, 1.2, 0), 0.8)
		if atk_t >= atk_end: atk_t = -1.0; _play(gait, 0.2, gait_rate)
		_face(to_p, delta * 6.0); rotation.y = yaw
		velocity = velocity.lerp(Vector3(0, velocity.y, 0), min(1.0, delta * 10.0)); _gravity(delta); move_and_slide()
		return
	if d < 1.05 and P.alive and not P.downed and atk_cd <= 0.0:
		var names = ATTACKS.keys(); var n: String = names[randi() % names.size()]
		atk_t = 0.0; atk_done = false; atk_cd = 1.1
		atk_hit = ATTACKS[n][0] / ATK_RATE; atk_end = ATTACKS[n][1] / ATK_RATE
		_play(n, 0.12, ATK_RATE)
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
	if d < 1.0: spd = 0.0
	hit_flinch -= delta
	# gira con velocidad limitada y avanza hacia donde mira (sin patinar de lado)
	if want.length() > 0.01: _face(want, delta * (3.0 + max_speed))
	var fwd = Vector3(sin(yaw), 0, cos(yaw))
	var align: float = max(0.0, fwd.dot(want)) if want.length() > 0.01 else 0.0
	dbg_align = align
	agent.velocity = fwd * spd * (align * align)
	var v = safe_vel if agent.avoidance_enabled else agent.velocity
	velocity.x = lerp(velocity.x, v.x, min(1.0, delta * 8.0)); velocity.z = lerp(velocity.z, v.z, min(1.0, delta * 8.0))
	_gravity(delta)
	move_and_slide()
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
	if real < 0.08: _play("Idle", 0.3, 1.0)
	else: _play(gait, 0.25, clamp(real / GAITS[gait], 0.3, 1.9))

func _gravity(delta: float) -> void:
	if not is_on_floor(): velocity.y -= 18.0 * delta
	else: velocity.y = -0.5

func _face(dir: Vector3, k: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.001: return
	var a = atan2(dir.x, dir.z)
	yaw = lerp_angle(yaw, a, clamp(k, 0.0, 1.0))
