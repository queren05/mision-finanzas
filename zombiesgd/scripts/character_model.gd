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

func fired() -> void: shoot_t = 0.25

## cada fotograma: animación según lo que hace, y el arma en la mano apuntando adonde mira
func update(delta: float, speed: float, crouch: bool, downed: bool, reloading: bool, pitch: float) -> void:
	shoot_t -= delta
	if human:
		var moving = speed > 0.4
		if downed: play("down", 0.3)
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
