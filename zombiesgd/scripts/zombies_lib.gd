extends Node
## Modelos de zombi (Sketchfab + animaciones de Mixamo): se escalan a la altura real y se varía el tono.

const KINDS := { "a": "res://assets/models/zombies/zr_A.glb", "c": "res://assets/models/zombies/zr_C.glb" }
var scenes = {}

func _ready() -> void:
	for k in KINDS: scenes[k] = load(KINDS[k])

func make(kind: String) -> Node3D:
	var n: Node3D = scenes[kind].instantiate()
	# altura real: medir la malla en reposo
	var h = _height(n)
	n.scale = Vector3.ONE * (Zombie.HEIGHT / max(0.01, h))
	var tint = Color.from_hsv(0.25 + randf_range(-0.04, 0.04), randf_range(0.0, 0.12), randf_range(0.8, 1.0))
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in mi.mesh.get_surface_count():
			var src = mi.get_active_material(si)
			if src is StandardMaterial3D:
				var mat: StandardMaterial3D = src.duplicate(); mat.albedo_color = mat.albedo_color * tint
				mat.metallic = 0.0; mat.roughness = max(mat.roughness, 0.75)   # piel y ropa: nada de brillos
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
