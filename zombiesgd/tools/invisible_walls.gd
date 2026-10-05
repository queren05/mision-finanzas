extends SceneTree
## Busca colisiones "invisibles" en un mapa: mallas con colisión que no se ven (ocultas, transparentes o sin material)
## dentro de las zonas jugables. Uso: godot --headless --path zombiesgd -s tools/invisible_walls.gd -- <mapa>
func _initialize() -> void:
	await process_frame
	var id = OS.get_cmdline_user_args()[0]
	var cfg = MapBuilder.load_config(id)
	var holder = Node3D.new(); root.add_child(holder)
	var r = MapBuilder.build_scene(cfg, holder)
	await process_frame
	var zones = []
	for z in cfg.get("zones", []):
		for b in z.boxes: zones.append(AABB(Vector3(b[0], b[1], b[2]), Vector3(b[3] - b[0], b[4] - b[1], b[5] - b[2])))
	for body in holder.find_children("*", "StaticBody3D", true, false):
		var mi = body.get_parent()
		if not (mi is MeshInstance3D): continue
		var m: MeshInstance3D = mi
		var bb: AABB = m.global_transform * m.get_aabb()
		var inzone = false
		for z in zones: if z.intersects(bb): inzone = true
		if not inzone: continue
		var why = []
		if not m.is_visible_in_tree(): why.append("oculta")
		for si in m.mesh.get_surface_count():
			var mat = m.get_active_material(si)
			if mat == null: why.append("sin material"); continue
			if mat is BaseMaterial3D:
				var bm: BaseMaterial3D = mat
				if bm.albedo_color.a < 0.35: why.append("alfa %.2f" % bm.albedo_color.a)
				if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: why.append("transparente:" + str(bm.resource_name))
		var thin = min(bb.size.x, bb.size.z)
		if why.size() > 0 or (bb.size.y > 1.0 and thin < 0.05 and max(bb.size.x, bb.size.z) > 1.5):
			print("SOSPECHOSA %s capa=%d centro=%s tamaño=%s %s" % [String(r.get_path_to(m)).get_file(), body.collision_layer, bb.get_center().snapped(Vector3.ONE * 0.1), bb.size.snapped(Vector3.ONE * 0.1), ", ".join(why)])
	quit()
