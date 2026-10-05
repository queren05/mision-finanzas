class_name MapBuilder
extends RefCounted
## Construye un mapa a partir de su ficha (assets/maps/<id>/map.json):
## - el escenario (glTF) con la colisión EXACTA de cada malla (lo que se ve es lo que choca)
## - paredes invisibles solo donde la ficha lo dice (bordes del mapa)
## Lo usan el juego y la herramienta que hornea la navegación, así que los dos ven las mismas colisiones.

const LAYER_WORLD := 1          # choca y para las balas
const LAYER_SOFT := 2           # choca pero las balas pasan (vallas de alambre, cristal, rejas)
const LAYER_ZOMBIE := 4
const LAYER_PLAYER := 8
const LAYER_BARRIER := 16       # puertas de pago (choca con todos y las balas no pasan)

static func load_config(map_id: String) -> Dictionary:
	var f = FileAccess.open("res://assets/maps/%s/map.json" % map_id, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func _matches(name: String, pats: Array) -> bool:
	var n = name.to_lower()
	for p in pats:
		if n.contains(String(p).to_lower()): return true
	return false

## instancia el escenario y le añade la colisión de cada malla
static func build_scene(cfg: Dictionary, parent: Node3D) -> Node3D:
	var root: Node3D
	if cfg.has("scene"): root = (load(cfg.scene) as PackedScene).instantiate()
	else: root = Node3D.new()   # mapa montado solo con piezas (props)
	root.name = "Escenario"
	if cfg.has("scale"): root.scale = Vector3.ONE * float(cfg.scale)
	if cfg.has("offset"): root.position = Vector3(cfg.offset[0], cfg.offset[1], cfg.offset[2])
	if cfg.has("rot_y"): root.rotation_degrees.y = float(cfg.rot_y)
	parent.add_child(root)
	var nocol: Array = cfg.get("nocollide", [])
	var soft: Array = cfg.get("soft", [])
	var hide: Array = cfg.get("hide", [])
	var noshadow: Array = cfg.get("noshadow", [])
	var door_parts := []
	for d in cfg.get("doors", []): door_parts.append_array(d.get("hide_meshes", []))
	# piezas: modelos sueltos colocados a mano (edificios, coches, farolas...) con sus mallas unidas por material
	var pi = 0
	for pr in cfg.get("props", []):
		_add_prop(root, pr, pi, door_parts); pi += 1
	# escenario principal: se ajustan los materiales y se une por material en trozos de 20 m (menos llamadas de dibujo)
	if cfg.has("scene") and cfg.get("merge", false):   # (no por defecto: unir pierde los LOD que genera la importación)
		var ms = []
		for m in root.find_children("*", "MeshInstance3D", true, false):
			if m.has_meta("prop_done"): continue
			var full = String(root.get_path_to(m))
			if _matches(full, hide): m.visible = false; continue
			if not OS.get_cmdline_user_args().has("notune"): _tune_materials(m)
			ms.append(m)
		_merge(root, ms, nocol, soft, door_parts, false, 20.0)
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		var full = String(root.get_path_to(mi))
		if _matches(full, hide): mi.visible = false; continue
		if not OS.get_cmdline_user_args().has("notune"): _tune_materials(mi)
		if _matches(full, noshadow): mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # detalles finos: su sombra cuesta mucho y apenas se ve
		if mi.has_meta("prop_done"): continue   # las piezas ya traen su colisión
		if mi.mesh == null or _matches(full, nocol): continue
		var shape = mi.mesh.create_trimesh_shape()
		if shape == null: continue
		var body = StaticBody3D.new(); body.name = "col"
		var cs = CollisionShape3D.new(); cs.shape = shape; body.add_child(cs)
		if _matches(full, door_parts): body.set_meta("door_part", true)   # verjas que se abren: la navegación cuenta con el hueco
		var is_soft = _matches(full, soft)
		body.collision_layer = LAYER_SOFT if is_soft else LAYER_WORLD
		body.collision_mask = 0
		mi.add_child(body)
	# geometría añadida a mano (tabiques, contenedores, cajas, mesas...) con su colisión
	if cfg.has("build"): parent.add_child(build_extra(cfg.build, cfg.get("textures", "")))
	# paredes invisibles (bordes del mapa, huecos que no se deben cruzar)
	for b in cfg.get("walls", []):
		parent.add_child(make_box(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), float(b[6]) if b.size() > 6 else 0.0, LAYER_SOFT))
	return root

## una pieza: {scene, pos:[x,y,z], rot (grados), scale, only:[...] (solo esas mallas), hide:[...], nocollide:[...], soft:[...],
## collide:false (nada choca), pivot (por defecto con only): la base centrada de lo que queda va a pos; merge (por defecto sí): une las mallas por material}
static func _add_prop(root: Node3D, pr: Dictionary, idx: int, door_parts: Array) -> void:
	var holder = Node3D.new(); holder.name = "%s_%d" % [String(pr.get("name", String(pr.scene).get_base_dir().get_file())), idx]
	root.add_child(holder)
	holder.position = v3(pr.get("pos", [0, 0, 0])); holder.rotation_degrees.y = float(pr.get("rot", 0.0))
	var sc = pr.get("scale", 1.0)
	holder.scale = v3(sc) if sc is Array else Vector3.ONE * float(sc)
	var inst: Node3D = (load(pr.scene) as PackedScene).instantiate(); holder.add_child(inst)
	var only: Array = pr.get("only", []); var hide: Array = pr.get("hide", [])
	var meshes = []
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var full = String(inst.get_path_to(m))
		if (only.size() > 0 and not _matches(full, only)) or _matches(full, hide): m.get_parent().remove_child(m); m.free(); continue
		meshes.append(m)
	# la base de lo que queda, centrada en pos
	if pr.get("pivot", only.size() > 0):
		var lo = Vector3.INF; var hi = -Vector3.INF
		var inv = holder.global_transform.affine_inverse()
		for m in meshes:
			var b: AABB = (inv * m.global_transform) * m.get_aabb(); lo = lo.min(b.position); hi = hi.max(b.end)
		if lo != Vector3.INF: inst.position -= Vector3((lo.x + hi.x) / 2, lo.y, (lo.z + hi.z) / 2)
	var nocol: Array = pr.get("nocollide", []); var soft: Array = pr.get("soft", [])
	var no_collide_all = pr.get("collide", true) == false
	if not pr.get("merge", true):
		for m in meshes:
			var full = String(inst.get_path_to(m))
			m.set_meta("prop_done", true)
			if no_collide_all or _matches(full, nocol): continue
			_collide(m, LAYER_SOFT if _matches(full, soft) else LAYER_WORLD, _matches(full, door_parts))
		return
	_merge(inst, meshes, nocol, soft, door_parts, no_collide_all, 0.0)

## une mallas por material, por si chocan o no y (si cell > 0) por trozos de cell metros: de cientos de mallas a unas
## pocas llamadas de dibujo, sin perder el recorte de lo que no se ve. Las puertas que se abren se quedan sueltas.
static func _merge(inst: Node3D, meshes: Array, nocol: Array, soft: Array, door_parts: Array, no_collide_all: bool, cell: float) -> void:
	var groups = {}
	var merged = []
	for m in meshes:
		var mi: MeshInstance3D = m
		if mi.mesh == null or mi.skin != null or not mi.visible: continue
		var full = String(inst.get_path_to(mi))
		if _matches(full, door_parts):
			mi.set_meta("prop_done", true); _collide(mi, LAYER_WORLD, true); continue
		merged.append(mi)
		var kind = "n" if (no_collide_all or _matches(full, nocol)) else ("s" if _matches(full, soft) else "c")
		var xf: Transform3D = _rel(inst, mi)
		var ck = ""
		var wb: AABB = (inst.global_transform * xf if inst.is_inside_tree() else xf) * mi.get_aabb()
		if cell > 0.0:
			var c = wb.get_center()
			ck = "%d_%d" % [floori(c.x / cell), floori(c.z / cell)]
		var small = max(wb.size.x, max(wb.size.y, wb.size.z)) < 0.8   # los objetos pequeños no se dibujan de lejos
		for si in mi.mesh.get_surface_count():
			var am = mi.mesh as ArrayMesh   # (las mallas simples, como BoxMesh, son siempre triángulos con normales y UV)
			if am and am.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES: continue
			var mat = mi.get_active_material(si)
			var fmt = (am.surface_get_format(si) & (Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2)) if am else -1
			var key = "%d_%d_%s_%s_%s_%s" % [mat.get_instance_id() if mat else 0, fmt, kind, ck, mi.cast_shadow, small]
			if not groups.has(key):
				var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = { "st": st, "mat": mat, "kind": kind, "shadow": mi.cast_shadow, "small": small }
			groups[key].st.append_from(mi.mesh, si, xf)
	for m in merged:
		m.get_parent().remove_child(m); m.free()
	var gi = 0
	for key in groups:
		var g = groups[key]
		var mesh: ArrayMesh = g.st.commit()
		if mesh == null or mesh.get_surface_count() == 0: continue
		if g.mat: mesh.surface_set_material(0, g.mat)
		var mi = MeshInstance3D.new(); mi.name = "m%d_%s" % [gi, g.kind]; mi.mesh = mesh; mi.cast_shadow = g.shadow; inst.add_child(mi); gi += 1
		if g.small: mi.visibility_range_end = 45.0; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("prop_done", true)
		if g.kind != "n": _collide(mi, LAYER_SOFT if g.kind == "s" else LAYER_WORLD, false)

## transformación de una malla respecto a un nodo antepasado (sirve aunque no estén en la escena todavía)
static func _rel(anc: Node3D, n: Node3D) -> Transform3D:
	var t = Transform3D.IDENTITY
	var c: Node = n
	while c != anc and c != null:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

## une un modelo (máquinas, armas de pared...) por material: de ~100 llamadas de dibujo a unas pocas. Sin colisión.
static func merge_model(model: Node3D, max_tris := 0) -> void:
	var ms = model.find_children("*", "MeshInstance3D", true, false)
	if ms.size() >= 4: _merge(model, ms, [], [], [], true, 0.0)
	if max_tris > 0: simplify(model, max_tris)

static func _tris(m: Mesh, si: int) -> int:
	var a = m.surface_get_arrays(si)
	return (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] else a[Mesh.ARRAY_VERTEX].size()) / 3

## simplifica las mallas de un modelo hasta un presupuesto de triángulos (reparto proporcional entre sus superficies)
static func simplify(model: Node3D, max_tris: int) -> void:
	var ms = model.find_children("*", "MeshInstance3D", true, false)
	var total = 0
	for m in ms:
		if m.mesh == null or m.skin != null: continue
		for si in m.mesh.get_surface_count(): total += _tris(m.mesh, si)
	if total <= max_tris: return
	var ratio = float(max_tris) / total
	for m in ms:
		var mi: MeshInstance3D = m
		if mi.mesh == null or mi.skin != null: continue
		var out = ArrayMesh.new()
		for si in mi.mesh.get_surface_count():
			var st = SurfaceTool.new(); st.create_from(mi.mesh, si); st.index()
			var arr = st.commit_to_arrays()
			var target = max(36, int(_tris(mi.mesh, si) * ratio) * 3)
			var lod: PackedInt32Array = st.generate_lod(50.0, target)
			if lod.size() >= 3 and lod.size() < arr[Mesh.ARRAY_INDEX].size(): arr[Mesh.ARRAY_INDEX] = lod
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(si, mi.get_active_material(si))
		mi.mesh = out

static func _collide(mi: MeshInstance3D, layer: int, door_part: bool) -> void:
	if mi.mesh == null: return
	var shape = mi.mesh.create_trimesh_shape()
	if shape == null: return
	var body = StaticBody3D.new(); body.name = "col"
	var cs = CollisionShape3D.new(); cs.shape = shape; body.add_child(cs)
	if door_part: body.set_meta("door_part", true)
	body.collision_layer = layer; body.collision_mask = 0
	mi.add_child(body)

## materiales: transparencias baratas y sin dientes de sierra; las vallas y redes finas no hacen sombra
## (sus sombras salen pixeladas y con efecto muaré en el móvil)
static func _tune_materials(mi: MeshInstance3D) -> void:
	if mi.mesh == null: return
	var alpha = false
	for si in mi.mesh.get_surface_count():
		var mat = mi.get_active_material(si)
		if not (mat is BaseMaterial3D): continue
		var m: BaseMaterial3D = mat
		if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: alpha = true
		if m.has_meta("tuned"): continue
		m.set_meta("tuned", true)
		if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS or m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; m.alpha_scissor_threshold = 0.5
		if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.metallic_specular = min(m.metallic_specular, 0.35)   # pocos brillos
	var ab = mi.get_aabb(); var sz = ab.size * mi.global_transform.basis.get_scale()
	if alpha and min(sz.x, min(sz.y, sz.z)) < 0.2:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# objetos pequeños: no se dibujan de lejos
	if max(sz.x, max(sz.y, sz.z)) < 0.8: mi.visibility_range_end = 45.0

static func make_box(center: Vector3, size: Vector3, yaw_deg: float, layer: int) -> StaticBody3D:
	var body = StaticBody3D.new()
	var cs = CollisionShape3D.new(); var bs = BoxShape3D.new(); bs.size = size; cs.shape = bs; body.add_child(cs)
	body.position = center; body.rotation_degrees.y = yaw_deg
	body.collision_layer = layer; body.collision_mask = 0
	return body

static func v3(a) -> Vector3: return Vector3(float(a[0]), float(a[1]), float(a[2]))

## cajas de navegación: una por zona (y una por puerta, que se activa al comprarla)
static func nav_boxes(cfg: Dictionary) -> Array:
	var out = []
	for z in cfg.get("zones", []):
		var i = 0
		for b in z.boxes:
			out.append({ "id": "%s_%d" % [z.id, i], "aabb": AABB(Vector3(b[0], b[1], b[2]), Vector3(b[3] - b[0], b[4] - b[1], b[5] - b[2])) }); i += 1
	var j = 0
	for d in cfg.get("doors", []):
		# la puerta ocupa justo el hueco entre las cajas de las dos zonas (ancho x alto x grosor, girada si hace falta)
		var c = v3(d.pos); var sz = v3(d.size)
		if abs(int(round(float(d.get("yaw", 0))))) % 180 == 90: sz = Vector3(sz.z, sz.y, sz.x)
		out.append({ "id": "door_%d" % j, "aabb": AABB(Vector3(c.x - sz.x / 2, c.y - 1.0, c.z - sz.z / 2), Vector3(sz.x, sz.y + 2.0, sz.z)) }); j += 1
	return out

const BORDER := 1.0   # se hornea la caja ampliada en BORDER y Recast recorta justo a la caja: las zonas encajan sin huecos

static func nav_settings() -> NavigationMesh:
	var nm = NavigationMesh.new()
	nm.agent_radius = 0.3; nm.agent_height = 1.75; nm.agent_max_climb = 0.45; nm.agent_max_slope = 42.0
	nm.cell_size = 0.15; nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = LAYER_WORLD | LAYER_SOFT
	nm.border_size = BORDER
	nm.edge_max_error = 1.0
	nm.region_min_size = 1.0
	return nm

# ------------------------------------------------------------------ geometría añadida (mapas que necesitan tabiques y decorado)
## (sin caché estática: guardar recursos en variables estáticas bloquea el cierre del juego)
static func extra_mat(name: String, cache: Dictionary, T := "") -> Material:
	if cache.has(name): return cache[name]
	if name == "lava":
		var sm = ShaderMaterial.new(); sm.shader = load("res://assets/shaders/lava.gdshader")
		sm.set_shader_parameter("tex", load(T + "lava_d.jpg")); sm.set_shader_parameter("emit", load(T + "lava_e.jpg"))
		cache[name] = sm; return sm
	var m = StandardMaterial3D.new(); m.uv1_triplanar = true; m.uv1_scale = Vector3(0.5, 0.5, 0.5); m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# texturas PBR del propio mapa (<nombre>_d / _n / _arm)
	if T != "" and ResourceLoader.exists(T + name + "_d.jpg"):
		m.albedo_texture = load(T + name + "_d.jpg")
		if ResourceLoader.exists(T + name + "_n.jpg"): m.normal_enabled = true; m.normal_texture = load(T + name + "_n.jpg")
		if ResourceLoader.exists(T + name + "_arm.jpg"):
			var arm = load(T + name + "_arm.jpg")
			m.roughness_texture = arm; m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN; m.roughness = 1.0
			m.ao_enabled = true; m.ao_texture = arm; m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
		match name:
			"asphalt": m.uv1_scale = Vector3(0.18, 0.18, 0.18)
			"sidewalk": m.uv1_scale = Vector3(0.3, 0.3, 0.3)
			"burned": m.uv1_scale = Vector3(0.12, 0.12, 0.12)
		cache[name] = m; return m
	match name:
		"concrete": m.albedo_color = Color(0.55, 0.54, 0.52)
		"asphalt": m.albedo_color = Color(0.2, 0.2, 0.21)
		"rust": m.albedo_color = Color(0.45, 0.25, 0.15); m.metallic = 0.4
		"brick": m.albedo_color = Color(0.45, 0.22, 0.17)
		"plaster": m.albedo_color = Color(0.6, 0.56, 0.5)
		"black": m.albedo_color = Color(0.03, 0.03, 0.03)
		"wood": m.albedo_texture = load("res://assets/textures/planks_d.jpg"); m.normal_enabled = true; m.normal_texture = load("res://assets/textures/planks_n.jpg"); m.uv1_scale = Vector3(0.7, 0.7, 0.7)
		"crate_blue": m.albedo_color = Color(0.12, 0.35, 0.65); m.roughness = 0.6
		"crate_red": m.albedo_color = Color(0.7, 0.15, 0.1); m.roughness = 0.6
		"white": m.albedo_color = Color(0.82, 0.84, 0.86)
		"steel": m.albedo_color = Color(0.6, 0.62, 0.65); m.metallic = 0.7; m.roughness = 0.35
		"water": m.albedo_color = Color(0.05, 0.12, 0.16); m.metallic = 0.6; m.roughness = 0.15
		"fish": m.albedo_color = Color(0.75, 0.78, 0.8); m.metallic = 0.5; m.roughness = 0.3
		"ice": m.albedo_color = Color(0.85, 0.92, 1.0); m.roughness = 0.2
	cache[name] = m
	return m

## piezas: {t:"box"|"cyl", p:[x,y,z] (centro de la base), s:[ancho,alto,fondo] (cyl: [radio,alto]), r:giro en grados, m:material, c:colisión (por defecto sí)}
static func build_extra(list: Array, tex_dir := "") -> Node3D:
	var root = Node3D.new(); root.name = "Extra"
	var cache = {}
	for e in list:
		if e.t == "crack": root.add_child(_crack(e, cache, tex_dir)); continue
		var mi = MeshInstance3D.new()
		var s: Array = e.s
		var shape: Shape3D
		if e.t == "cyl":
			var cm = CylinderMesh.new(); cm.top_radius = float(s[0]); cm.bottom_radius = float(s[0]); cm.height = float(s[1]); cm.radial_segments = 20; mi.mesh = cm
			var cs = CylinderShape3D.new(); cs.radius = float(s[0]); cs.height = float(s[1]); shape = cs
		else:
			var bm = BoxMesh.new(); bm.size = Vector3(float(s[0]), float(s[1]), float(s[2])); mi.mesh = bm
			var bs = BoxShape3D.new(); bs.size = bm.size; shape = bs
		mi.material_override = extra_mat(String(e.get("m", "concrete")), cache, tex_dir)
		if e.get("m", "") == "lava": mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var h = float(s[1])
		var node = Node3D.new(); node.position = v3(e.p) + Vector3(0, h / 2, 0); node.rotation_degrees.y = float(e.get("r", 0)); root.add_child(node)
		node.add_child(mi)
		if max(float(s[0]), h) < 0.9: mi.visibility_range_end = 50.0
		if e.get("c", true):
			var body = StaticBody3D.new(); body.collision_layer = LAYER_WORLD; body.collision_mask = 0
			var col = CollisionShape3D.new(); col.shape = shape; body.add_child(col); node.add_child(body)
	return root

## grieta: una tira de bordes irregulares a lo largo de unos puntos (lava por dentro, quemado alrededor). Sin colisión.
static func _crack(e: Dictionary, cache: Dictionary, tex_dir: String) -> Node3D:
	var node = Node3D.new()
	var pts: Array = e.pts
	var rng = RandomNumberGenerator.new(); rng.seed = int(e.get("seed", 3))
	# muestras cada 0,35 m a lo largo del camino, con anchura que cambia
	var path = []
	for i in pts.size() - 1:
		var a = Vector2(pts[i][0], pts[i][1]); var b = Vector2(pts[i + 1][0], pts[i + 1][1])
		var n = max(1, int(a.distance_to(b) / 0.35))
		for k in n: path.append(a.lerp(b, float(k) / n))
	path.append(Vector2(pts[-1][0], pts[-1][1]))
	for layer in [["black", 1.0, 0.012], ["lava", 0.45, 0.03]]:
		var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev_l = Vector3.ZERO; var prev_r = Vector3.ZERO
		for i in path.size():
			var p: Vector2 = path[i]
			var d: Vector2 = (path[min(i + 1, path.size() - 1)] - path[max(i - 1, 0)]).normalized()
			var nrm = Vector2(-d.y, d.x)
			var t = float(i) / (path.size() - 1)
			var w = float(e.get("w", 1.2)) * (0.35 + 0.65 * sin(t * PI)) * float(layer[1])   # fina en las puntas
			var wl = w * rng.randf_range(0.6, 1.25); var wr = w * rng.randf_range(0.6, 1.25)
			var l = Vector3(p.x + nrm.x * wl, layer[2], p.y + nrm.y * wl); var r = Vector3(p.x - nrm.x * wr, layer[2], p.y - nrm.y * wr)
			if i > 0:
				for v in [prev_l, prev_r, l, l, prev_r, r]:
					st.set_normal(Vector3.UP); st.set_uv(Vector2(v.x, v.z) * 0.3); st.add_vertex(v)
			prev_l = l; prev_r = r
		var mi = MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = extra_mat(layer[0], cache, tex_dir)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	return node
