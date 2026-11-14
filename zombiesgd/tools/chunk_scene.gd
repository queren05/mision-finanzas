extends SceneTree
## Trocea las mallas enormes de un escenario (edificios enteros en una sola malla que cruza el mapa) en celdas de unos
## metros, cada una con sus niveles de detalle. Así el motor deja de dibujar lo que queda fuera de la pantalla o lejos:
## una malla que cruza el mapa se dibuja SIEMPRE entera, aunque solo se vea una esquina.
## godot --headless --path zombiesgd -s tools/chunk_scene.gd -- <mapa> [celda en metros, por defecto 14]
## Lee "scene_src" (o "scene") de la ficha del mapa y guarda assets/maps/<mapa>/scene_chunks.scn
const KEYS := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]

func _initialize() -> void:
	var a = OS.get_cmdline_user_args(); var id: String = a[0]
	var cell = float(a[1]) if a.size() > 1 else 14.0
	var cfg = MapBuilder.load_config(id)
	var src: String = cfg.get("scene_src", cfg.scene)
	var root: Node3D = (load(src) as PackedScene).instantiate()
	var k = float(cfg.get("scale", 1.0))
	var before = 0; var made = 0; var split = 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null or mi.skin != null: continue
		var tris = 0
		for si in mi.mesh.get_surface_count(): tris += mi.mesh.surface_get_array_index_len(si) / 3
		var xf: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * MapBuilder._rel(root, mi)
		var wb: AABB = xf * mi.get_aabb()
		if tris < 2500 or max(wb.size.x, wb.size.z) < cell * 1.5: continue
		before += 1; split += tris
		var cells = {}   # celda -> ImporterMesh
		for si in mi.mesh.get_surface_count():
			if (mi.mesh as ArrayMesh).surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES: continue
			var arr = mi.mesh.surface_get_arrays(si)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if I == null or I.is_empty():
				I = PackedInt32Array(); I.resize(V.size())
				for i in V.size(): I[i] = i
			# triángulos por celda (según su centro, en metros del mundo)
			var by = {}
			for t in range(0, I.size() - 2, 3):
				var c = xf * ((V[I[t]] + V[I[t + 1]] + V[I[t + 2]]) / 3.0)
				var key = Vector2i(floori(c.x / cell), floori(c.z / cell))
				if not by.has(key): by[key] = PackedInt32Array()
				by[key].append(I[t]); by[key].append(I[t + 1]); by[key].append(I[t + 2])
			var mat = mi.get_active_material(si)
			for key in by:
				var idx: PackedInt32Array = by[key]
				var remap = {}; var order = PackedInt32Array(); var nidx = PackedInt32Array(); nidx.resize(idx.size())
				for i in idx.size():
					var v = idx[i]
					if not remap.has(v): remap[v] = order.size(); order.append(v)
					nidx[i] = remap[v]
				var out = []; out.resize(Mesh.ARRAY_MAX)
				for kk in KEYS:
					var s = arr[kk]
					if s == null or s.size() == 0: continue
					var per = 4 if kk == Mesh.ARRAY_TANGENT else 1
					var d = s.duplicate(); d.resize(order.size() * per)
					for i in order.size():
						for j in per: d[i * per + j] = s[order[i] * per + j]
					out[kk] = d
				out[Mesh.ARRAY_INDEX] = nidx
				if not cells.has(key): cells[key] = ImporterMesh.new()
				(cells[key] as ImporterMesh).add_surface(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, mat, "s%d" % si)
		var ci = 0
		for key in cells:
			var im: ImporterMesh = cells[key]
			im.generate_lods(25.0, 60.0, [])
			var n = MeshInstance3D.new(); n.name = "%s_c%d" % [mi.name, ci]; ci += 1
			n.mesh = im.get_mesh(); n.transform = mi.transform; n.cast_shadow = mi.cast_shadow
			mi.get_parent().add_child(n); made += 1
		mi.get_parent().remove_child(mi); mi.free()
	for c in root.find_children("*", "", true, false): c.owner = root
	var ps = PackedScene.new(); ps.pack(root)
	var path = "res://assets/maps/%s/scene_chunks.scn" % id
	print("TROCEADAS ", before, " mallas (", split, " triángulos) en ", made, " trozos de ", cell, " m -> ", path, " ", ResourceSaver.save(ps, path, ResourceSaver.FLAG_COMPRESS))
	root.free()
	quit()
