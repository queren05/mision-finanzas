class_name CharacterModel
extends Node3D
## El cuerpo de un jugador (el propio en tercera persona y los compañeros de cooperativo).
## Soldados: modelo con esqueleto y animaciones de verdad (quieto, andar, correr, agachado, disparar, recargar, caído)
## y el arma en la mano derecha, apuntando hacia donde mira. Gambas y langostas: el modelo de siempre con balanceo.

var char_id = "comando"
var human = false
var anim: AnimationPlayer
var skel: Skeleton3D
var hand_bone = -1
var piv: Node3D
var gun: Node3D
var gun_id = ""
var length = 1.5          # gambas: largo del cuerpo
var bob = 0.0
var shoot_t = 0.0
var cur_anim = ""
var shadow_only = false
var base_y = 0.0

const HUMAN_ANIMS := { "idle": "idle simple", "walk": "simple walk", "run": "run", "crouch_idle": "crouch idle", "crouch_walk": "walk crouch",
	"shoot": "simple shoot", "crouch_shoot": "crouch shoot", "reload": "reload idle", "reload_walk": "reload walk", "reload_crouch": "reload crouch",
	"jump": "jump", "down": "pron idle", "death": "simple death" }

func setup(id: String) -> void:
	char_id = id if Data.CHARACTERS.has(id) else "comando"
	var c: Dictionary = Data.CHARACTERS[char_id]
	human = c.get("human", false)
	piv = Node3D.new(); add_child(piv)
	if human:
		var m: Node3D = load("res://assets/models/chars/%s/scene.gltf" % c.file).instantiate(); piv.add_child(m)
		var h = Zombies._height(m)
		piv.scale = Vector3.ONE * (float(c.get("height", 1.8)) / max(0.01, h))
		piv.rotation_degrees.y = 180.0   # el modelo mira a +Z; el jugador, a -Z
		anim = m.find_child("AnimationPlayer", true, false)
		for a in HUMAN_ANIMS.values():
			if anim.has_animation(a) and a in ["idle simple", "simple walk", "run", "crouch idle", "walk crouch", "pron idle"]: anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		skel = m.find_children("*", "Skeleton3D", true, false)[0]
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).begins_with("mixamorig_RightHand_"): hand_bone = i
		play("idle")
		if not OS.get_cmdline_user_args().has("notree"): _build_tree()
	else:
		var m: Node3D = load("res://assets/models/chars/%s.glb" % c.file).instantiate(); piv.add_child(m)
		piv.rotation_degrees.y = 180.0 if float(c.head) > 0 else 0.0   # que la cabeza mire hacia delante (-Z)
		var lo = Vector3.INF; var hi = -Vector3.INF
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var t = Transform3D.IDENTITY; var n: Node = mi
			while n != null and n != self:
				if n is Node3D: t = (n as Node3D).transform * t
				n = n.get_parent()
			var b: AABB = t * (mi as MeshInstance3D).get_aabb(); lo = lo.min(b.position); hi = hi.max(b.end)
		var k = float(c.len) / max(0.001, max(hi.x - lo.x, hi.z - lo.z))
		piv.scale = Vector3.ONE * k
		piv.position = -Vector3((lo.x + hi.x) / 2, lo.y, (lo.z + hi.z) / 2) * k
		length = float(c.len); base_y = piv.position.y

func play(name: String, blend := 0.18, speed := 1.0) -> void:
	if not anim: return
	var a = HUMAN_ANIMS.get(name, name)
	if not anim.has_animation(a): return
	if speed == 0.0:
		# postura congelada (apuntar quieto): sin mezcla, porque a velocidad 0 la mezcla nunca termina
		if cur_anim != a + "@pose":
			anim.play(a, 0.0); anim.seek(min(0.12, anim.current_animation_length * 0.5), true); cur_anim = a + "@pose"
		anim.speed_scale = 0.0
		return
	if cur_anim != a: anim.play(a, blend); cur_anim = a
	anim.speed_scale = speed

## solo sombra (primera persona: no se ve el cuerpo pero sí su sombra en el suelo)
func set_shadow_only(on: bool) -> void:
	shadow_only = on
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func set_weapon(wid: String) -> void:
	if wid == gun_id or not Data.WEAPONS.has(wid): return
	gun_id = wid
	if gun: gun.queue_free()
	gun = Guns.make_world(wid); add_child(gun)
	if not human: gun.scale = Vector3.ONE * 1.8   # en manos de la gamba se ve mejor un poco más grande
	if shadow_only: set_shadow_only(true)

func fired() -> void:
	shoot_t = 0.25
	if tree: tree.set("parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# ------------------------------------------------------------------ árbol de animación (soldados)
var tree: AnimationTree
var k_crouch = 0.0
var k_reload = 0.0
var k_down = 0.0
var k_speed = 0.0

## Árbol de mezcla: las piernas mezclan quieto / andar / correr según la velocidad (sin saltos entre animaciones),
## agachado se mezcla aparte, y el torso dispara o recarga por encima mientras las piernas siguen andando.
func _build_tree() -> void:
	for a in ["reload idle", "pron idle", "crouch idle", "walk crouch", "simple walk", "run"]:
		if not anim.has_animation(a): return
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	# postura de apuntar (un fotograma de «simple shoot») para cuando está quieto
	var src: Animation = anim.get_animation("simple shoot")
	var pose = Animation.new(); pose.length = 0.2; pose.loop_mode = Animation.LOOP_LINEAR
	for i in src.get_track_count():
		var ty = src.track_get_type(i)
		if ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_SCALE_3D: continue
		var ti = pose.add_track(ty); pose.track_set_path(ti, src.track_get_path(i))
		match ty:
			Animation.TYPE_POSITION_3D: pose.position_track_insert_key(ti, 0.0, src.position_track_interpolate(i, 0.12))
			Animation.TYPE_ROTATION_3D: pose.rotation_track_insert_key(ti, 0.0, src.rotation_track_interpolate(i, 0.12))
			Animation.TYPE_SCALE_3D: pose.scale_track_insert_key(ti, 0.0, src.scale_track_interpolate(i, 0.12))
	var lib: AnimationLibrary = anim.get_animation_library(anim.get_animation_library_list()[0])
	var prefix = String(anim.get_animation_library_list()[0]); prefix = prefix + "/" if prefix != "" else ""
	if not lib.has_animation("aim pose"): lib.add_animation("aim pose", pose)
	var A = func(n: String) -> AnimationNodeAnimation:
		var an = AnimationNodeAnimation.new(); an.animation = prefix + n; return an
	var bt = AnimationNodeBlendTree.new()
	var stand = AnimationNodeBlendSpace1D.new(); stand.min_space = 0.0; stand.max_space = 6.5; stand.sync = true
	stand.add_blend_point(A.call("aim pose"), 0.0, -1, "quieto"); stand.add_blend_point(A.call("simple walk"), 1.8, -1, "andar"); stand.add_blend_point(A.call("run"), 6.0, -1, "correr")
	var cr = AnimationNodeBlendSpace1D.new(); cr.min_space = 0.0; cr.max_space = 3.0; cr.sync = true
	cr.add_blend_point(A.call("crouch idle"), 0.0, -1, "quieto"); cr.add_blend_point(A.call("walk crouch"), 1.6, -1, "andar")
	# huesos del torso para arriba (columna, cabeza, brazos y manos)
	var sp = String(anim.get_node(anim.root_node).get_path_to(skel))
	var upper = []
	var spine = -1
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with("mixamorig_Spine_"): spine = i
	for i in skel.get_bone_count():
		var b = i
		while b >= 0 and b != spine: b = skel.get_bone_parent(b)
		if b == spine and spine >= 0: upper.append(NodePath("%s:%s" % [sp, skel.get_bone_name(i)]))
	var crouch_mix = AnimationNodeBlend2.new()
	var reload_mix = AnimationNodeBlend2.new(); reload_mix.filter_enabled = true
	var shoot = AnimationNodeOneShot.new(); shoot.filter_enabled = true; shoot.fadein_time = 0.04; shoot.fadeout_time = 0.14
	for u in upper: reload_mix.set_filter_path(u, true); shoot.set_filter_path(u, true)
	var down_mix = AnimationNodeBlend2.new()
	bt.add_node("stand", stand); bt.add_node("crouch", cr); bt.add_node("crouch_mix", crouch_mix)
	bt.add_node("reload_anim", A.call("reload idle")); bt.add_node("reload_mix", reload_mix)
	bt.add_node("shoot_anim", A.call("simple shoot")); bt.add_node("shoot", shoot)
	bt.add_node("down_anim", A.call("pron idle")); bt.add_node("down_mix", down_mix)
	bt.connect_node("crouch_mix", 0, "stand"); bt.connect_node("crouch_mix", 1, "crouch")
	bt.connect_node("reload_mix", 0, "crouch_mix"); bt.connect_node("reload_mix", 1, "reload_anim")
	bt.connect_node("shoot", 0, "reload_mix"); bt.connect_node("shoot", 1, "shoot_anim")
	bt.connect_node("down_mix", 0, "shoot"); bt.connect_node("down_mix", 1, "down_anim")
	bt.connect_node("output", 0, "down_mix")
	anim.stop()
	tree = AnimationTree.new(); tree.tree_root = bt
	anim.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim); tree.active = true

func _tree_update(delta: float, speed: float, crouch: bool, downed: bool, reloading: bool) -> void:
	var k = min(1.0, delta * 9.0)
	k_speed = lerp(k_speed, speed, min(1.0, delta * 10.0))
	k_crouch = lerp(k_crouch, 1.0 if crouch else 0.0, k)
	k_reload = lerp(k_reload, 1.0 if reloading and not downed else 0.0, k)
	k_down = lerp(k_down, 1.0 if downed else 0.0, min(1.0, delta * 5.0))
	tree.set("parameters/stand/blend_position", k_speed)
	tree.set("parameters/crouch/blend_position", k_speed)
	tree.set("parameters/crouch_mix/blend_amount", k_crouch)
	tree.set("parameters/reload_mix/blend_amount", k_reload)
	tree.set("parameters/down_mix/blend_amount", k_down)

## cada fotograma: animación según lo que hace, y el arma en la mano apuntando adonde mira
func update(delta: float, speed: float, crouch: bool, downed: bool, reloading: bool, pitch: float) -> void:
	shoot_t -= delta
	if human:
		var moving = speed > 0.4
		if tree: _tree_update(delta, speed, crouch, downed, reloading)
		elif downed: play("down", 0.3)
		elif reloading: play("reload_crouch" if crouch else ("reload_walk" if moving else "reload"), 0.2)
		elif shoot_t > 0.0 and not moving: play("crouch_shoot" if crouch else "shoot", 0.08)
		elif crouch: play("crouch_walk" if moving else "crouch_idle", 0.2, clamp(speed / 1.6, 0.6, 1.5) if moving else 1.0)
		elif speed > 4.8: play("run", 0.2, clamp(speed / 6.0, 0.8, 1.3))
		elif moving: play("walk", 0.2, clamp(speed / 1.8, 0.7, 1.6))
		else: play("shoot", 0.25, 0.0)   # quieto: postura de apuntar con el arma levantada
		if gun:
			gun.visible = not downed
			if hand_bone >= 0:
				var hand: Vector3 = skel.global_transform * skel.get_bone_global_pose(hand_bone).origin
				var aim = Basis(Vector3.UP, global_rotation.y) * Basis(Vector3.RIGHT, clamp(pitch, -1.2, 1.2))
				var L = float(Data.WEAPONS[gun_id].len)
				gun.global_transform = Transform3D(aim, hand + aim * Vector3(0.0, 0.03, -L * 0.25))
	else:
		bob += delta * min(speed, 6.0) * 2.2
		piv.position.y = base_y + abs(sin(bob)) * 0.05 * min(1.0, speed / 3.0)
		rotation.z = sin(bob) * 0.06 * min(1.0, speed / 3.0)
		rotation.x = lerp(rotation.x, (0.6 if downed else clamp(pitch * 0.35, -0.3, 0.3)), min(1.0, delta * 8.0))
		if gun:
			gun.visible = not downed
			gun.position = Vector3(0.16, 0.36, -length * 0.45 - float(Data.WEAPONS[gun_id].len) * 0.6)
			gun.rotation.x = pitch * 0.65 - rotation.x
