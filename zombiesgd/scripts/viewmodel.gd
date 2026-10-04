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
		"bone": "ACRRifle", "elev": 0.0, "shift": Vector3(0.01, -0.01, 0.0), "fwd": 0.1 },
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
	var eye_xf: Transform3D = skel.global_transform * skel.get_bone_global_pose(hc)
	var eye: Vector3 = eye_xf.origin
	var bone_p: Vector3 = skel.global_transform * skel.get_bone_global_pose(gun_bone).origin
	# la cámara de su autor (los dos packs comparten esqueleto): mira hacia +Z con +Y arriba
	var cam_basis = Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))   # columnas: derecha, arriba, atrás
	var fwd = Vector3(0, 0, 1); var upv = Vector3.UP
	cam_basis = cam_basis * Basis(Vector3.RIGHT, deg_to_rad(float(kit.elev)))
	base_xf = Transform3D(cam_basis, eye).affine_inverse()
	base_xf.origin += kit.shift
	if OS.get_cmdline_user_args().has("vmdbg"): print("VM ojo ", eye, " adelante ", fwd, " arriba ", upv, " arma ", base_xf * bone_p)
	hip_pos = base_xf * bone_p
	holder.transform = base_xf
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
	holder.transform = base_xf
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
	ads_off = Vector3(-c.x, -0.052 - c.y, 0.05 if kind == "rifle" else 0.04)

func _play(what: String, blend := 0.15, speed := 1.0) -> void:
	if ap == null: return
	var a: String = KITS[kind].get(what, "")
	if a == "" or not ap.has_animation(a): return
	if cur != a or what == "shoot":
		ap.play(a, blend)
		if what == "shoot": ap.seek(0.0)
	cur = a; ap.speed_scale = speed

func fire() -> void:
	_play("shoot", 0.02, 1.0)
	kick_v += 9.0

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
	kick_v += (-kick * 120.0 - kick_v * 16.0) * delta
	kick += kick_v * delta
	# balanceo: el arma se queda un poco atrás al girar la cámara
	sway = sway.lerp(Vector2(clamp(-look.x * 3.0, -0.06, 0.06), clamp(-look.y * 3.0, -0.05, 0.05)), min(1.0, delta * 10.0))
	bob_t += delta * min(speed, 7.0) * (1.6 if sprinting else 1.2)
	var bobv = Vector3(sin(bob_t) * 0.006, -abs(cos(bob_t)) * 0.006, 0.0) * min(1.0, speed / 4.0) * (1.0 - ads)
	var t = base_xf
	t.origin += ads_off * ads + bobv + Vector3(sway.x * 0.15, sway.y * 0.12, kick * 0.03)
	if sprinting and kind == "pistol": t.origin += Vector3(0.02, -0.06, 0.0)
	t.basis = t.basis.rotated(Vector3.UP, sway.x * 0.6).rotated(Vector3.RIGHT, -sway.y * 0.6 + kick * 0.05 - (0.35 if sprinting and kind == "pistol" else 0.0))
	if draw_t > 0.0: t.origin.y -= draw_t * 0.25
	holder.transform = holder.transform.interpolate_with(t, min(1.0, delta * 25.0))
	_follow_bone()

## el arma sigue al hueso del arma (sin su escala, que viene en centímetros)
func _follow_bone() -> void:
	if gun and is_instance_valid(gun) and gun_bone >= 0:
		gun.global_transform = (skel.global_transform * skel.get_bone_global_pose(gun_bone)).orthonormalized() * gun_local

func muzzle_global() -> Vector3:
	if gun and is_instance_valid(gun): return gun.global_transform * Vector3(0, 0.02, -float(Data.WEAPONS[gun_id].len) * 0.55)
	return global_position
