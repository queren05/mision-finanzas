extends SceneTree
## Luces de un mapa a partir de sus mallas de velas/lámparas: agrupa los vértices en piezas y pone una luz en cada una.
## godot --headless --path zombiesgd -s tools/bake_lights.gd -- <mapa>   -> assets/maps/<mapa>/nav/lights.json
func _initialize() -> void:
	await process_frame
	var id: String = OS.get_cmdline_user_args()[0]
	var cfg = MapBuilder.load_config(id)
	var holder = Node3D.new(); root.add_child(holder)
	var scene_root = MapBuilder.build_scene(cfg, holder)
	await process_frame
	var pats: Array = cfg.get("light_meshes", [])
	var pts = []
	for mi in scene_root.find_children("*", "MeshInstance3D", true, false):
		var path = String(scene_root.get_path_to(mi))
		var ok = false
		for p in pats: if path.contains(p): ok = true
		if not ok: continue
		for si in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]: pts.append(mi.global_transform * v)
	# agrupar por celdas de 0.6 m
	var cells = {}
	for p in pts:
		var k = Vector3i(floor(p.x / 0.6), floor(p.y / 0.6), floor(p.z / 0.6))
		if not cells.has(k): cells[k] = []
		cells[k].append(p)
	var seen = {}; var lights = []
	for k in cells:
		if seen.has(k): continue
		var stack = [k]; seen[k] = true; var sum = Vector3(); var n = 0
		while stack.size() > 0:
			var c = stack.pop_back()
			for p in cells[c]: sum += p; n += 1
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						var nk = c + Vector3i(dx, dy, dz)
						if cells.has(nk) and not seen.has(nk): seen[nk] = true; stack.append(nk)
		var c = sum / n
		var a = cfg.auto_zones.aabb if cfg.has("auto_zones") else [-1e9, -1e9, -1e9, 1e9, 1e9, 1e9]
		if c.x < a[0] or c.x > a[3] or c.z < a[2] or c.z > a[5]: continue
		# no poner dos luces casi en el mismo sitio
		var dup = false
		for l in lights: if Vector3(l[0], l[1], l[2]).distance_to(c) < 1.6: dup = true
		if not dup: lights.append([snapped(c.x, 0.01), snapped(c.y, 0.01), snapped(c.z, 0.01)])
	print("LUCES ", lights.size())
	var f = FileAccess.open("res://assets/maps/%s/nav/lights.json" % id, FileAccess.WRITE); f.store_string(JSON.stringify(lights))
	quit()
