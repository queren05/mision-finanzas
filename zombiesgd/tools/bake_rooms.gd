extends SceneTree
## Zonas automáticas por habitaciones: godot --headless --path zombiesgd -s tools/bake_rooms.gd -- <mapa>
## Hornea la navegación con todas las puertas cerradas, separa las islas (cada habitación es una zona)
## y calcula, para cada puerta, qué dos zonas une. Guarda nav/room_<k>.res y nav/rooms.json.

func _initialize() -> void:
	await process_frame
	var id: String = OS.get_cmdline_user_args()[0]
	var cfg = MapBuilder.load_config(id)
	var holder = Node3D.new(); root.add_child(holder)
	var scene_root = MapBuilder.build_scene(cfg, holder)
	await process_frame
	var nm = MapBuilder.nav_settings()
	var ar = cfg.auto_zones.aabb
	nm.filter_baking_aabb = AABB(Vector3(ar[0], ar[1], ar[2]), Vector3(ar[3] - ar[0], ar[4] - ar[1], ar[5] - ar[2])).grow(MapBuilder.BORDER)
	var src = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, holder)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var v: PackedVector3Array = nm.get_vertices()
	var pc = nm.get_polygon_count()
	print("polígonos ", pc, " vértices ", v.size())
	# islas: polígonos que comparten una arista
	var parent = range(pc)
	var find = func(x):
		while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
		return x
	var edge_owner = {}
	for i in pc:
		var poly = nm.get_polygon(i)
		for k in poly.size():
			var a = poly[k]; var b = poly[(k + 1) % poly.size()]
			var key = Vector2i(min(a, b), max(a, b))
			if edge_owner.has(key):
				var ra = find.call(i); var rb = find.call(edge_owner[key]); if ra != rb: parent[ra] = rb
			else: edge_owner[key] = i
	var groups = {}
	for i in pc:
		var r = find.call(i)
		if not groups.has(r): groups[r] = []
		groups[r].append(i)
	# área de cada isla
	var islands = []
	for r in groups:
		var area = 0.0; var box = AABB(); var first = true; var ys = 0.0
		for i in groups[r]:
			var poly = nm.get_polygon(i)
			for k in range(1, poly.size() - 1): area += (v[poly[k]] - v[poly[0]]).cross(v[poly[k + 1]] - v[poly[0]]).length() / 2.0
			for q in poly:
				box = AABB(v[q], Vector3.ZERO) if first else box.expand(v[q]); first = false; ys += v[q].y
		if area < float(cfg.auto_zones.get("min_area", 6.0)): continue
		islands.append({ "polys": groups[r], "area": area, "box": box })
	islands.sort_custom(func(a, b): return a.area > b.area)
	DirAccess.make_dir_recursive_absolute("res://assets/maps/%s/nav" % id)
	var out = { "rooms": [], "doors": [] }
	for k in islands.size():
		var isl = islands[k]; var m = MapBuilder.nav_settings(); var remap = {}; var verts = PackedVector3Array()
		for i in isl.polys:
			var poly = nm.get_polygon(i); var np = PackedInt32Array()
			for q in poly:
				if not remap.has(q): remap[q] = verts.size(); verts.append(v[q])
				np.append(remap[q])
			isl["np"] = isl.get("np", []) + [np]
		m.set_vertices(verts)
		for np in isl.np: m.add_polygon(np)
		ResourceSaver.save(m, "res://assets/maps/%s/nav/room_%d.res" % [id, k])
		var b: AABB = isl.box
		out.rooms.append({ "id": "r%d" % k, "area": snapped(isl.area, 0.1), "box": [b.position.x, b.position.y, b.position.z, b.end.x, b.end.y, b.end.z] })
		print("SALA r%d área %.0f m² caja %s" % [k, isl.area, b])
	# puertas: centro y normal a partir de sus mallas; cada lado se pega a la sala más cercana
	var map_rid = root.get_world_3d().navigation_map
	var regions = []
	for k in islands.size():
		var r = NavigationRegion3D.new(); r.navigation_mesh = load("res://assets/maps/%s/nav/room_%d.res" % [id, k]); holder.add_child(r); regions.append(r)
	for w in 6: await physics_frame
	NavigationServer3D.map_force_update(map_rid)
	print("regiones en el mapa ", NavigationServer3D.map_get_regions(map_rid).size())
	for di in cfg.get("doors", []).size():
		var d = cfg.doors[di]
		var box = AABB(); var first = true
		for mi in scene_root.find_children("*", "MeshInstance3D", true, false):
			var path = String(scene_root.get_path_to(mi))
			var hit = false
			for pat in d.get("hide_meshes", []): if path.contains(pat): hit = true
			if not hit: continue
			var bb: AABB = mi.global_transform * mi.get_aabb(); box = bb if first else box.merge(bb); first = false
		if first: print("PUERTA %d sin mallas" % di); out.doors.append({}); continue
		var c = box.get_center(); c.y = box.position.y
		var nrm = Vector3(1, 0, 0) if box.size.x < box.size.z else Vector3(0, 0, 1)
		var width = max(box.size.x, box.size.z)
		var sides = []
		for sgn in [-1.0, 1.0]:
			var p = c + nrm * sgn * 0.9
			var best_room = -1; var best_d = 1e9; var best_p = p
			for k in islands.size():
				for np in islands[k].np:
					pass
			# buscar el triángulo más cercano (en planta, a una altura parecida) de todas las salas
			for k in islands.size():
				for i in islands[k].polys:
					var poly = nm.get_polygon(i)
					for t in range(1, poly.size() - 1):
						var A = v[poly[0]]; var B = v[poly[t]]; var C = v[poly[t + 1]]
						var cen = (A + B + C) / 3.0
						if abs(cen.y - p.y) > 1.6: continue
						var inside = Geometry2D.point_is_inside_triangle(Vector2(p.x, p.z), Vector2(A.x, A.z), Vector2(B.x, B.z), Vector2(C.x, C.z))
						var dd = 0.0 if inside else min(Vector2(p.x - A.x, p.z - A.z).length(), min(Vector2(p.x - B.x, p.z - B.z).length(), min(Vector2(p.x - C.x, p.z - C.z).length(), Vector2(p.x - cen.x, p.z - cen.z).length())))
						if dd < best_d: best_d = dd; best_room = k; best_p = Vector3(p.x, cen.y, p.z) if inside else cen
			sides.append({ "p": best_p, "room": best_room, "dist": best_d })
		out.doors.append({ "center": [c.x, c.y, c.z], "normal": [nrm.x, nrm.z], "width": width, "height": box.size.y,
			"a": [sides[0].p.x, sides[0].p.y, sides[0].p.z], "b": [sides[1].p.x, sides[1].p.y, sides[1].p.z],
			"ra": "r%d" % sides[0].room, "rb": "r%d" % sides[1].room })
		print("PUERTA %d %s r%d (%.1f m) <-> r%d (%.1f m)" % [di, d.hide_meshes, sides[0].room, sides[0].dist, sides[1].room, sides[1].dist])
	var f = FileAccess.open("res://assets/maps/%s/nav/rooms.json" % id, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  "))
	quit()
