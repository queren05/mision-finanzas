extends SceneTree
## Cajas de las mallas de un modelo: godot --headless --path . -s tools/mesh_boxes.gd -- <ruta.gltf> [escala] [filtro]
func _initialize() -> void:
	var a = OS.get_cmdline_user_args()
	var n: Node3D = load(a[0]).instantiate(); n.scale = Vector3.ONE * (float(a[1]) if a.size() > 1 else 1.0); root.add_child(n)
	await process_frame
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var p = String(n.get_path_to(m))
		if a.size() > 2 and not p.to_lower().contains(a[2].to_lower()): continue
		var b: AABB = m.global_transform * m.get_aabb()
		print("%-60s min %s max %s" % [p.right(60), b.position.snapped(Vector3.ONE * 0.01), b.end.snapped(Vector3.ONE * 0.01)])
	quit()
