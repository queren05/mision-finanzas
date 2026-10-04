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
	# paredes invisibles (bordes del mapa, huecos que no se deben cruzar)
	for b in cfg.get("walls", []):
		parent.add_child(make_box(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), float(b[6]) if b.size() > 6 else 0.0, LAYER_SOFT))
	return root

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
	nm.agent_radius = 0.38; nm.agent_height = 1.75; nm.agent_max_climb = 0.45; nm.agent_max_slope = 42.0
	nm.cell_size = 0.15; nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = LAYER_WORLD | LAYER_SOFT
	nm.border_size = BORDER
	nm.edge_max_error = 1.0
	nm.region_min_size = 4.0
	return nm
