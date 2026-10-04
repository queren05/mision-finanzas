extends Node
## Modelos de enemigos (Sketchfab + animaciones de Mixamo): se escalan a la altura real y se varía el tono.
## Tipos: zombi normal, perro infernal, Bruto (jefe enorme) e Hinchado (revienta al morir).

const KINDS := { "a": "res://assets/models/zombies/zr_A.glb", "c": "res://assets/models/zombies/zr_C.glb", "dog": "res://assets/models/zombies/hound/scene.gltf" }
# altura de cada tipo (m) y tinte
const TYPES := {
	"normal": { "height": 1.82 },
	"dog": { "height": 1.05 },
	"brute": { "height": 2.55, "tint": Color(0.85, 0.45, 0.4) },
	"bloat": { "height": 1.95, "tint": Color(0.6, 0.85, 0.35), "fat": 1.35 },
}
var scenes = {}

func _ready() -> void:
	for k in KINDS: scenes[k] = load(KINDS[k])
	# las animaciones de andar, correr y estar quieto se repiten
	for k in scenes:
		var n: Node = scenes[k].instantiate()
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		if ap:
			for a in ap.get_animation_list():
				if a in ["Idle", "Idle2", "Walk", "Shamble", "Run", "idle01", "walk_7", "run_fast"]: ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		n.free()

func make(kind: String, type := "normal") -> Node3D:
	var n: Node3D = scenes[kind].instantiate()
	var t: Dictionary = TYPES.get(type, TYPES.normal)
	var h = _height(n)
	n.scale = Vector3.ONE * (float(t.height) / max(0.01, h))
	if t.has("fat"): n.scale.x *= float(t.fat); n.scale.z *= float(t.fat)
	var tint = Color.from_hsv(0.25 + randf_range(-0.04, 0.04), randf_range(0.0, 0.12), randf_range(0.8, 1.0)) if kind != "dog" else Color(1, 1, 1)
	if t.has("tint"): tint = t.tint
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if GS.settings.get("quality", "alta") == "alta" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 70.0; mi.visibility_range_end_margin = 5.0
		for si in mi.mesh.get_surface_count():
			var src = mi.get_active_material(si)
			if src is StandardMaterial3D:
				var mat: StandardMaterial3D = src.duplicate(); mat.albedo_color = mat.albedo_color * tint
				mat.metallic = 0.0; mat.roughness = max(mat.roughness, 0.75)   # piel y ropa: nada de brillos
				if type == "dog": mat.rim_enabled = true; mat.rim = 0.4
				mi.set_surface_override_material(si, mat)
	return n

var heights = {}
## altura real con el esqueleto en reposo (de los pies a la coronilla), relativa al nodo raíz del modelo
func _height(n: Node3D) -> float:
	var key = n.scene_file_path
	if heights.has(key): return heights[key]
	var sk: Skeleton3D = null
	for c in n.find_children("*", "Skeleton3D", true, false): sk = c; break
	var h = 1.8
	if sk:
		var t = Transform3D.IDENTITY; var c: Node = sk
		while c != null and c != n:
			if c is Node3D: t = (c as Node3D).transform * t
			c = c.get_parent()
		var lo = INF; var hi = -INF
		for i in sk.get_bone_count():
			var y = (t * sk.get_bone_global_rest(i).origin).y
			lo = min(lo, y); hi = max(hi, y)
		h = (hi - lo) * 1.04
	heights[key] = h
	return h
