class_name Viewmodel
extends Node3D
## Primera persona: brazos con guantes animados (pack de fusil o de pistola) sujetando el arma que llevas.
## El arma que trae el modelo se esconde y la nuestra se pega al hueso del arma, alineada con la suya.
## Animaciones: quieto, andar, correr, disparar, recargar (al ritmo de cada arma) y sacar el arma;
## además balanceo al mirar, retroceso con muelle y alineación de la mira al apuntar.

const KITS := {
	"rifle": { "scene": "res://assets/models/arms/rifle/scene.gltf", "hide": ["Rifle", "Silencer", "Scope", "Pmag"],
		"idle": "Armature|Arms_FPS_Anim_Idle", "walk": "Armature|Arms_FPS_Anim_Walk", "run": "Armature|Arms_FPS_Anim_Run",
		"shoot": "Armature|Arms_FPS_Anim_Shoot", "reload": "Armature|Arms_FPS_Anim_Reload_Fast", "draw": "Armature|Arms_FPS_Anim_Draw",
		"bone": "ACRRifle", "elev": 0.0, "shift": Vector3(0.045, -0.02, 0.0), "fwd": 0.1 },
	"pistol": { "scene": "res://assets/models/arms/pistol/scene.gltf", "hide": ["Material"],
		"idle": "Armature|FPS_Pistol_Idle", "walk": "Armature|FPS_Pistol_Walk", "run": "Armature|FPS_Pistol_Walk",
		"shoot": "Armature|FPS_Pistol_Fire", "reload": "Armature|FPS_Pistol_Reload_full", "draw": "",
		"bone": "PBody", "elev": -9.0, "shift": Vector3(0.07, 0.0, 0.03), "fwd": 0.0 },
}

var kind = ""
var arms: Node3D
var holder: Node3D               # se mueve entero (balanceo, retroceso, apuntar)
var ap: AnimationPlayer
var skel: Skeleton3D
var gun: Node3D
var gun_id = ""
var base_xf = Transform3D.IDENTITY   # brazos colocados respecto a la cámara
var ads_off = Vector3.ZERO           # desplazamiento para que la mira quede en el centro al apuntar
var cur = ""
var kick = 0.0
var kick_v = 0.0
var sway = Vector2.ZERO
var draw_t = 0.0
var bob_t = 0.0
var muzzle_local = Vector3(0, 0, -0.5)
var knife: Node3D
var knife_t = 0.0
const KNIFE_TIME := 0.42

func _ready() -> void:
	holder = Node3D.new(); add_child(holder)

static func kit_for(wid: String) -> String:
	var c = String(Data.WEAPONS[wid].get("class", ""))
	return "pistol" if c == "pistola" or wid == "raygun" else "rifle"

## pone el arma (cambia de brazos si hace falta) y la saca con su animación
func set_weapon(wid: String, pap: bool) -> void:
	var k = kit_for(wid)
	if k != kind: _build(k)
	if gun: gun.queue_free()
	gun_id = wid
	gun = Guns.make_view(wid, pap)
	_attach_gun()
	draw_t = 0.45
	_play("draw" if KITS[kind].draw != "" else "idle", 0.0)

func _build(k: String) -> void:
	if arms: arms.queue_free()
	kind = k
	var kit: Dictionary = KITS[k]
	holder.transform = Transform3D.IDENTITY   # se mide con el soporte en su sitio (si no, se arrastra la colocación de los brazos anteriores)
	arms = load(kit.scene).instantiate(); holder.add_child(arms)
	ap = arms.find_child("AnimationPlayer", true, false)
	skel = arms.find_children("*", "Skeleton3D", true, false)[0]
	for a in ["idle", "walk", "run"]:
		if ap.has_animation(kit[a]): ap.get_animation(kit[a]).loop_mode = Animation.LOOP_LINEAR
	ap.play(kit.idle); ap.seek(0.0, true); skel.force_update_all_bone_transforms()
	# materiales: que no se metan en las paredes y que se vean igual con cualquier campo de visión
	for mi in arms.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in m.mesh.get_surface_count():
			var src = m.get_active_material(si)
			var name = src.resource_name if src else ""
			var hide = false
			for h in kit.hide:
				if name.begins_with(h): hide = true
			if hide: m.set_meta("gun_part", true); continue
			if src is BaseMaterial3D:
				var mat: BaseMaterial3D = src.duplicate()
				mat.use_z_clip_scale = true; mat.z_clip_scale = 0.12; mat.use_fov_override = true; mat.fov_override = 60.0
				m.set_surface_override_material(si, mat)
	# los brazos miran a +Z y su "ojo" es el hueso Head_Cam: se giran 180° y se inclinan para que el arma quede donde
	# la dejó su autor pero un poco más arriba en la pantalla (como en Call of Duty)
	gun_bone = -1; var hc = -1
	for i in skel.get_bone_count():
		var nm = skel.get_bone_name(i)
		if nm.begins_with(kit.bone) and gun_bone < 0: gun_bone = i
		if nm.begins_with("Head_Cam") and hc < 0: hc = i
	# todo en el espacio del soporte (no del mundo): si no, al cambiar de brazos con la cámara lejos del origen el arma acababa a metros
	var to_local = holder.global_transform.affine_inverse() * skel.global_transform
	var eye: Vector3 = to_local * skel.get_bone_global_pose(hc).origin
	var bone_p: Vector3 = to_local * skel.get_bone_global_pose(gun_bone).origin
	# la cámara de su autor (los dos packs comparten esqueleto): mira hacia +Z con +Y arriba
	var cam_basis = Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))   # columnas: derecha, arriba, atrás
	var fwd = Vector3(0, 0, 1); var upv = Vector3.UP
	cam_basis = cam_basis * Basis(Vector3.RIGHT, deg_to_rad(float(kit.elev)))
	base_xf = Transform3D(cam_basis, eye).affine_inverse()
	base_xf.origin += kit.shift
	if OS.get_cmdline_user_args().has("vmdbg"): print("VM ojo ", eye, " adelante ", fwd, " arriba ", upv, " arma ", base_xf * bone_p)
	hip_pos = base_xf * bone_p
	holder.transform = base_xf; smooth_xf = base_xf
	for mi in arms.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("gun_part"): mi.visible = OS.get_cmdline_user_args().has("orig")

var hip_pos = Vector3.ZERO
var gun_local = Transform3D.IDENTITY
var gun_bone = -1
## nuestra arma va pegada al hueso del arma (así sigue la recarga y el retroceso de la animación),
## apuntando hacia delante y centrada en ese hueso
## centro y largo del arma que traen los brazos (con la piel aplicada como lo hace la GPU)
func _their_center() -> Dictionary:
	var lo = Vector3.INF; var hi = -Vector3.INF
	var inv_h = holder.global_transform.affine_inverse()
	for mi in arms.find_children("*", "MeshInstance3D", true, false):
		if not mi.has_meta("gun_part"): continue
		var m: MeshInstance3D = mi
		var mat = m.get_active_material(0)
		if mat == null or not String(mat.resource_name).begins_with(KITS[kind].hide[0]): continue   # solo el cuerpo del arma (no el silenciador ni la mira)
		var skin: Skin = m.skin
		if skin == null: continue
		for si in m.mesh.get_surface_count():
			var arr = m.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var bones = arr[Mesh.ARRAY_BONES]
			if bones == null or verts.size() == 0: continue
			var per = bones.size() / verts.size()
			for vi in range(0, verts.size(), max(1, verts.size() / 300)):
				var bi = bones[vi * per]; var bone = skin.get_bind_bone(bi)
				if bone < 0: bone = skel.find_bone(skin.get_bind_name(bi))
				if bone < 0: continue
				var p = inv_h * (skel.global_transform * skel.get_bone_global_pose(bone) * skin.get_bind_pose(bi) * verts[vi])   # en el espacio de los brazos
				lo = lo.min(p); hi = hi.max(p)
	if lo == Vector3.INF: return { "center": skel.global_transform * skel.get_bone_global_pose(max(0, gun_bone)).origin, "length": 0.5 }
	return { "center": holder.global_transform * ((lo + hi) / 2), "length": (hi - lo).z }   # los brazos miran a +Z

func _attach_gun() -> void:
	holder.add_child(gun)
	# se coloca con los brazos en reposo (quietos), no en mitad de la animación de sacar el arma
	ap.play(KITS[kind].idle); ap.seek(0.0, true); skel.force_update_all_bone_transforms()
	holder.transform = base_xf; smooth_xf = base_xf
	var bone_xf: Transform3D = (skel.global_transform * skel.get_bone_global_pose(max(0, gun_bone))).orthonormalized()
	var hold: Basis = holder.global_transform.basis.orthonormalized() * base_xf.basis.inverse()   # orientación de la cámara
	var L = float(Data.WEAPONS[gun_id].len)
	if OS.get_cmdline_user_args().has("vmdbg"): print("HUESO al pegar ", skel.get_bone_global_pose(gun_bone).origin, " anim ", ap.current_animation, " pos ", ap.current_animation_position, " activo ", ap.active, " modo ", ap.callback_mode_process)
	var theirs = _their_center()
	var c0: Vector3 = theirs.center
	if OS.get_cmdline_user_args().has("vmdbg"): print("SUYA centro ", c0, " largo ", theirs.length, " cámara ", hold)
	# las armas cortas se agarran más atrás que el centro de la suya; las largas, alineadas por el centro
	var shift = -(float(theirs.length) - L) * (0.14 if kind == "rifle" else 0.0)
	var want = Transform3D(hold, c0 + hold * Vector3(0, 0.0, -shift))
	gun_local = bone_xf.affine_inverse() * want   # respecto al hueso: así sigue la recarga y el retroceso de la animación
	gun.global_transform = want
	# apuntar: el centro de la parte de arriba del arma pasa al centro de la pantalla
	var cam_xf: Transform3D = (get_parent() as Node3D).global_transform if get_parent() is Node3D else global_transform
	var c: Vector3 = cam_xf.affine_inverse() * want.origin
	# al apuntar, el borde de arriba del arma queda justo por debajo de la cruz: se ve a lo que apuntas
	var top_y = 0.05
	var ab: AABB = Guns._aabb(gun)
	if ab.size.y > 0.0: top_y = ab.end.y
	ads_off = Vector3(-c.x, -0.022 - top_y - c.y, 0.03)

func _play(what: String, blend := 0.15, speed := 1.0) -> void:
	if ap == null: return
	var a: String = KITS[kind].get(what, "")
	if a == "" or not ap.has_animation(a): return
	if cur != a or what == "shoot":
		ap.play(a, blend)
		if what == "shoot": ap.seek(0.0)
	cur = a; ap.speed_scale = speed

## cuchillo: los brazos se apartan y el cuchillo cruza la pantalla de derecha a izquierda
func slash() -> void:
	if knife == null: knife = _make_knife()
	knife_t = KNIFE_TIME

var knife_base = Transform3D.IDENTITY
var smooth_xf = Transform3D.IDENTITY
var fist = Vector3.ZERO   # el puño del cuchillo, en el espacio de la cámara
var shoulder = Vector3.ZERO

## brazo del cuchillo: el brazo derecho del pack de pistola (el izquierdo se recoge) con un Ka-Bar en la mano
func _make_knife() -> Node3D:
	var k = Node3D.new(); add_child(k)
	var arm: Node3D = load(KITS.pistol.scene).instantiate(); k.add_child(arm)
	var kap: AnimationPlayer = arm.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = arm.find_children("*", "Skeleton3D", true, false)[0]
	kap.play(KITS.pistol.idle); kap.seek(0.0, true); kap.pause(); kap.active = false
	sk.force_update_all_bone_transforms()
	var hc = -1; var grip = -1; var sh = -1
	for i in sk.get_bone_count():
		var nm = sk.get_bone_name(i)
		if nm.begins_with("Head_Cam") and hc < 0: hc = i
		if nm.begins_with("PBody") and grip < 0: grip = i
		if nm.begins_with("UpArm_R") and sh < 0: sh = i
		if nm.begins_with("Arm_L") or nm.begins_with("IK_Hand_Cntrl_L"): sk.set_bone_pose_scale(i, Vector3.ONE * 0.001)
	sk.force_update_all_bone_transforms()
	for mi in arm.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in m.mesh.get_surface_count():
			var src = m.get_active_material(si)
			if src and String(src.resource_name).begins_with("Material"): m.visible = false; break
			if src is BaseMaterial3D:
				var mat: BaseMaterial3D = src.duplicate()
				mat.use_z_clip_scale = true; mat.z_clip_scale = 0.12; mat.use_fov_override = true; mat.fov_override = 60.0
				m.set_surface_override_material(si, mat)
	# misma colocación que los brazos de pistola: su ojo (Head_Cam) en la cámara, mirando a +Z
	k.transform = Transform3D.IDENTITY
	var to_k = k.global_transform.affine_inverse() * sk.global_transform   # el modelo trae nodos padre girados y escalados
	var eye: Vector3 = to_k * sk.get_bone_global_pose(hc).origin
	var cam_basis = Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)) * Basis(Vector3.RIGHT, deg_to_rad(float(KITS.pistol.elev)))
	knife_base = Transform3D(cam_basis, eye).affine_inverse()
	knife_base.origin += KITS.pistol.shift
	# Ka-Bar militar (vitvitskyi, CC-BY): 9,3 unidades con la punta hacia +Z; de 30 cm, con el puño en la mano
	var blade: Node3D = load("res://assets/models/knife/scene.gltf").instantiate()
	var sc = 0.30 / 9.3
	var kb = Basis(Vector3.UP, PI).scaled(Vector3.ONE * sc)
	blade.transform = Transform3D(kb, -(kb * Vector3(-2.88, 0.6, -4.3)))
	for mi in blade.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat = mi.get_active_material(0)
		if mat is BaseMaterial3D:
			mat = mat.duplicate(); mat.use_z_clip_scale = true; mat.z_clip_scale = 0.12; mat.use_fov_override = true; mat.fov_override = 60.0
			mi.material_override = mat
	var hand = Node3D.new(); k.add_child(hand); hand.add_child(blade)
	# agarre de martillo: el mango atraviesa el puño (de los nudillos del meñique a los del índice) y la hoja
	# sale por arriba un poco inclinada hacia delante, con el filo mirando hacia delante. Todo medido en los huesos de la mano.
	var bp = func(n: String) -> Vector3:
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).begins_with(n): return knife_base * (to_k * sk.get_bone_global_pose(i).origin)
		return Vector3.ZERO
	var index_k: Vector3 = bp.call("Bone_R.005"); var pinky_k: Vector3 = bp.call("Bone_R.017")
	var tips = (bp.call("Bone_R.007") + bp.call("Bone_R.019")) / 2
	var up = (index_k - pinky_k).normalized()
	var dir = (up + Vector3(0, 0, -KNIFE_FWD)).normalized()
	var center = ((index_k + pinky_k) / 2).lerp(tips, 0.5)
	var edge = Vector3(0, 0, -1)   # el filo hacia delante
	var xb = dir.cross(edge).normalized()   # en cámara: eje X del cuchillo
	var zb = -dir; var yb = zb.cross(xb).normalized()
	var cam_xf = Transform3D(Basis(xb, yb, zb), center + dir * KNIFE_SLIDE)
	hand.transform = knife_base.affine_inverse() * cam_xf
	var gp: Transform3D = to_k * sk.get_bone_global_pose(grip)
	fist = knife_base * gp.origin
	shoulder = knife_base * (to_k * sk.get_bone_global_pose(sh).origin)
	if OS.get_cmdline_user_args().has("vmdbg"):
		print("CUCHILLO puño ", fist, " hombro ", shoulder)
		for i in sk.get_bone_count():
			var nm = sk.get_bone_name(i)
			if nm.contains("_R") or nm.begins_with("PBody") or nm.begins_with("Hand_R"): print("HUESO_R ", nm, " ", (knife_base * (to_k * sk.get_bone_global_pose(i).origin)).snapped(Vector3.ONE * 0.001))
	k.visible = false
	return k

const KNIFE_FWD := 0.6    # cuánto se inclina la hoja hacia delante
const KNIFE_SLIDE := 0.0  # el mango sube o baja dentro del puño

func fire() -> void:
	_play("shoot", 0.02, 1.0)
	kick_v = min(kick_v + 9.0, 30.0)

func reload(duration: float) -> void:
	var a: String = KITS[kind].reload
	if ap and ap.has_animation(a): _play("reload", 0.1, ap.get_animation(a).length / max(0.3, duration))

## cada fotograma: animación según el movimiento, balanceo, retroceso y apuntar
func update(delta: float, speed: float, sprinting: bool, ads: float, reloading: bool, look: Vector2) -> void:
	if ap == null: return
	draw_t -= delta
	if not reloading and draw_t <= 0.0 and (ap.current_animation == "" or not cur.contains("Fire") and not cur.contains("Shoot") or not ap.is_playing()):
		if sprinting: _play("run", 0.2, 1.0)
		elif speed > 0.5 and ads < 0.5: _play("walk", 0.2, clamp(speed / 4.5, 0.6, 1.4))
		else: _play("idle", 0.25)
	# retroceso con muelle (sube y vuelve)
	# en pasos pequeños: con pocos fps un solo paso grande hacía que el muelle se disparase (brazos volando)
	var steps = int(ceil(min(delta, 0.25) / 0.005))
	var h = min(delta, 0.25) / max(1, steps)
	for i in steps:
		kick_v += (-kick * 120.0 - kick_v * 16.0) * h
		kick += kick_v * h
	kick = clamp(kick, -0.5, 1.5); kick_v = clamp(kick_v, -40.0, 40.0)
	# balanceo: el arma se queda un poco atrás al girar la cámara
	sway = sway.lerp(Vector2(clamp(-look.x * 3.0, -0.06, 0.06), clamp(-look.y * 3.0, -0.05, 0.05)), min(1.0, delta * 10.0))
	bob_t += delta * min(speed, 7.0) * (1.6 if sprinting else 1.2)
	var bobv = Vector3(sin(bob_t) * 0.006, -abs(cos(bob_t)) * 0.006, 0.0) * min(1.0, speed / 4.0) * (1.0 - ads)
	var t = base_xf
	t.origin += ads_off * ads + bobv + Vector3(sway.x * 0.15, sway.y * 0.12, kick * 0.03)
	if sprinting and kind == "pistol": t.origin += Vector3(0.02, -0.06, 0.0)
	t.basis = t.basis.rotated(Vector3.UP, sway.x * 0.6).rotated(Vector3.RIGHT, -sway.y * 0.6 + kick * 0.05 - (0.35 if sprinting and kind == "pistol" else 0.0))
	if draw_t > 0.0: t.origin.y -= draw_t * 0.25
	# cuchillo: el arma baja y se aparta mientras dura el tajo
	var lower = Transform3D.IDENTITY
	if knife_t > 0.0:
		knife_t -= delta
		var p = clamp(1.0 - knife_t / KNIFE_TIME, 0.0, 1.0)
		if OS.get_cmdline_user_args().has("knifestill"):
			knife_t = KNIFE_TIME; p = 0.5
			for a in OS.get_cmdline_user_args(): if a.begins_with("kp="): p = float(a.substr(3))
		var away = sin(p * PI)
		lower = Transform3D(Basis(), Vector3(0.04, -0.34, 0.06) * away)   # el arma baja recta y se quita de en medio
		if knife:
			knife.visible = knife_t > 0.0 and not OS.get_cmdline_user_args().has("noknife")
			# tajo: el brazo entra por la derecha y cruza hacia la izquierda girando desde el hombro,
			# con la muñeca tumbada para que el filo vaya por delante
			var sweep = smoothstep(0.05, 0.85, p)
			var inout = sin(p * PI)
			# el brazo gira desde el hombro: el puño cruza de derecha a izquierda y la muñeca rota sobre el antebrazo
			var fa = (fist - shoulder).normalized()
			var r = Basis(Vector3.UP, lerp(-0.2, 0.75, sweep)) * Basis(fa, lerp(0.15, 1.05, sweep))
			var pose = Transform3D(r, shoulder) * Transform3D(Basis(), -shoulder)
			pose.origin += Vector3(0.05, -0.3, 0.05) * pow(1.0 - inout, 2.0)   # entra y sale por abajo
			knife.transform = pose * knife_base
	elif knife: knife.visible = false
	smooth_xf = smooth_xf.interpolate_with(t, min(1.0, delta * 25.0))
	if OS.get_cmdline_user_args().has("vmdbg2") and Engine.get_process_frames() % 20 == 0: print("VM2 det ", t.basis.determinant(), " t ", t, " s ", smooth_xf)
	holder.transform = lower * smooth_xf   # la bajada del cuchillo va aparte: interpolarla deformaba el arco
	_follow_bone()

## el arma sigue al hueso del arma (sin su escala, que viene en centímetros)
func _follow_bone() -> void:
	if gun and is_instance_valid(gun) and gun_bone >= 0:
		gun.global_transform = (skel.global_transform * skel.get_bone_global_pose(gun_bone)).orthonormalized() * gun_local

func muzzle_global() -> Vector3:
	if gun and is_instance_valid(gun): return gun.global_transform * Vector3(0, 0.02, -float(Data.WEAPONS[gun_id].len) * 0.55)
	return global_position
