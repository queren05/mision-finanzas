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
	var scn: PackedScene = load(cfg.scene)
	var root: Node3D = scn.instantiate()
	root.name = "Escenario"
	if cfg.has("scale"): root.scale = Vector3.ONE * float(cfg.scale)
	if cfg.has("offset"): root.position = Vector3(cfg.offset[0], cfg.offset[1], cfg.offset[2])
	if cfg.has("rot_y"): root.rotation_degrees.y = float(cfg.rot_y)
	parent.add_child(root)
	var nocol: Array = cfg.get("nocollide", [])
	var soft: Array = cfg.get("soft", [])
	var hide: Array = cfg.get("hide", [])
	var door_parts := []
	for d in cfg.get("doors", []): door_parts.append_array(d.get("hide_meshes", []))
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		var full = String(root.get_path_to(mi))
		if _matches(full, hide): mi.visible = false; continue
		if not OS.get_cmdline_user_args().has("notune"): _tune_materials(mi)
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
	if cfg.has("build"): parent.add_child(build_extra(cfg.build))
	# paredes invisibles (bordes del mapa, huecos que no se deben cruzar)
	for b in cfg.get("walls", []):
		parent.add_child(make_box(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), float(b[6]) if b.size() > 6 else 0.0, LAYER_SOFT))
	return root

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
static func extra_mat(name: String, cache: Dictionary) -> StandardMaterial3D:
	if cache.has(name): return cache[name]
	var m = StandardMaterial3D.new(); m.uv1_triplanar = true; m.uv1_scale = Vector3(0.5, 0.5, 0.5); m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var T = "res://assets/maps/lonja/textures/"
	match name:
		"corrugated": m.albedo_texture = load(T + "rusty_metal_plate_corrugated_baseColor.jpeg"); m.uv1_scale = Vector3(0.35, 0.35, 0.35); m.metallic = 0.3
		"wall": m.albedo_texture = load(T + "factory_wall_baseColor.jpeg"); m.normal_enabled = true; m.normal_texture = load(T + "factory_wall_normal.png"); m.uv1_scale = Vector3(0.25, 0.25, 0.25)
		"concrete": m.albedo_texture = load(T + "WarehouseMainConcrete_baseColor.jpeg") if ResourceLoader.exists(T + "WarehouseMainConcrete_baseColor.jpeg") else null; m.albedo_color = Color(0.55, 0.54, 0.52); m.uv1_scale = Vector3(0.15, 0.15, 0.15)
		"asphalt": m.albedo_color = Color(0.2, 0.2, 0.21); m.albedo_texture = load(T + "WarehouseMainConcrete_baseColor.jpeg") if ResourceLoader.exists(T + "WarehouseMainConcrete_baseColor.jpeg") else null; m.uv1_scale = Vector3(0.1, 0.1, 0.1)
		"rust": m.albedo_texture = load(T + "MetalRusted_baseColor.jpeg"); m.normal_enabled = true; m.normal_texture = load(T + "MetalRusted_normal.jpeg"); m.metallic = 0.4
		"wood": m.albedo_texture = load("res://assets/textures/planks_d.jpg"); m.normal_enabled = true; m.normal_texture = load("res://assets/textures/planks_n.jpg"); m.uv1_scale = Vector3(0.7, 0.7, 0.7)
		"crate_blue": m.albedo_color = Color(0.12, 0.35, 0.65); m.roughness = 0.6
		"crate_red": m.albedo_color = Color(0.7, 0.15, 0.1); m.roughness = 0.6
		"white": m.albedo_color = Color(0.82, 0.84, 0.86); m.albedo_texture = load(T + "MetalRusted_baseColor.jpeg"); m.uv1_scale = Vector3(0.2, 0.2, 0.2); m.albedo_color = Color(1.6, 1.65, 1.7)
		"steel": m.albedo_color = Color(0.6, 0.62, 0.65); m.metallic = 0.7; m.roughness = 0.35
		"cont_red": m.albedo_texture = load(T + "rusty_metal_plate_corrugated_baseColor.jpeg"); m.albedo_color = Color(1.3, 0.45, 0.35); m.uv1_scale = Vector3(0.3, 0.3, 0.3)
		"cont_blue": m.albedo_texture = load(T + "rusty_metal_plate_corrugated_baseColor.jpeg"); m.albedo_color = Color(0.45, 0.65, 1.2); m.uv1_scale = Vector3(0.3, 0.3, 0.3)
		"cont_green": m.albedo_texture = load(T + "rusty_metal_plate_corrugated_baseColor.jpeg"); m.albedo_color = Color(0.55, 1.0, 0.55); m.uv1_scale = Vector3(0.3, 0.3, 0.3)
		"water": m.albedo_color = Color(0.05, 0.12, 0.16); m.metallic = 0.6; m.roughness = 0.15
		"fish": m.albedo_color = Color(0.75, 0.78, 0.8); m.metallic = 0.5; m.roughness = 0.3
		"ice": m.albedo_color = Color(0.85, 0.92, 1.0); m.roughness = 0.2
	cache[name] = m
	return m

## piezas: {t:"box"|"cyl", p:[x,y,z] (centro de la base), s:[ancho,alto,fondo] (cyl: [radio,alto]), r:giro en grados, m:material, c:colisión (por defecto sí)}
static func build_extra(list: Array) -> Node3D:
	var root = Node3D.new(); root.name = "Extra"
	var cache = {}
	for e in list:
		var mi = MeshInstance3D.new()
		var s: Array = e.s
		var shape: Shape3D
		if e.t == "cyl":
			var cm = CylinderMesh.new(); cm.top_radius = float(s[0]); cm.bottom_radius = float(s[0]); cm.height = float(s[1]); cm.radial_segments = 20; mi.mesh = cm
			var cs = CylinderShape3D.new(); cs.radius = float(s[0]); cs.height = float(s[1]); shape = cs
		else:
			var bm = BoxMesh.new(); bm.size = Vector3(float(s[0]), float(s[1]), float(s[2])); mi.mesh = bm
			var bs = BoxShape3D.new(); bs.size = bm.size; shape = bs
		mi.material_override = extra_mat(String(e.get("m", "concrete")), cache)
		var h = float(s[1])
		var node = Node3D.new(); node.position = v3(e.p) + Vector3(0, h / 2, 0); node.rotation_degrees.y = float(e.get("r", 0)); root.add_child(node)
		node.add_child(mi)
		if max(float(s[0]), h) < 0.9: mi.visibility_range_end = 50.0
		if e.get("c", true):
			var body = StaticBody3D.new(); body.collision_layer = LAYER_WORLD; body.collision_mask = 0
			var col = CollisionShape3D.new(); col.shape = shape; body.add_child(col); node.add_child(body)
	return root
