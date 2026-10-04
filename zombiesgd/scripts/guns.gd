extends Node
## Modelos de armas: los carga, los orienta (cañón hacia -Z, empuñadura abajo), los escala a su largo real,
## aplica el camuflaje y prepara los materiales para primera persona (no atraviesan paredes).

var cache = {}      # id -> Node3D orientado (plantilla)

func _template(id: String) -> Node3D:
	if cache.has(id): return cache[id]
	var d: Dictionary = Data.WEAPONS[id]
	var scn: PackedScene = load("res://assets/models/guns/%s.glb" % d.model)
	var src: Node3D = scn.instantiate()
	var holder = Node3D.new(); holder.add_child(src)
	_orient(src, d)
	# centrar y escalar al largo real
	var b = _aabb(holder)
	var s = float(d.len) / max(0.001, b.size.z)
	src.scale *= s
	b = _aabb(holder)
	src.position -= b.get_center()
	cache[id] = holder
	return holder

func _points(n: Node3D) -> PackedVector3Array:
	var pts = PackedVector3Array()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null: continue
		var xf = _rel_xform(mi, n)
		for si in mi.mesh.get_surface_count():
			var arr = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			var step: int = max(1, arr.size() / 3000)
			for i in range(0, arr.size(), step): pts.append(xf * arr[i])
	return pts

func _rel_xform(node: Node3D, top: Node3D) -> Transform3D:
	var t = Transform3D.IDENTITY; var c: Node = node
	while c != null and c != top:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _aabb(top: Node3D) -> AABB:
	var pts = _points(top)
	var a = AABB(pts[0], Vector3.ZERO)
	for p in pts: a = a.expand(p)
	return a

## eje largo = cañón; la boca es el extremo más fino; el perfil de arriba es recto y el de abajo irregular
func _orient(src: Node3D, d: Dictionary) -> void:
	var holder = src.get_parent() as Node3D
	var pts = _points(holder)
	if pts.is_empty(): return
	var lo = Vector3.INF; var hi = -Vector3.INF
	for p in pts: lo = lo.min(p); hi = hi.max(p)
	var ext = hi - lo
	var order = [0, 1, 2]; order.sort_custom(func(a, b): return ext[a] > ext[b])
	var L: int = order[0]; var Hh: int = order[1]
	var unit = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var z_axis: Vector3 = unit[L]; var y_axis: Vector3 = unit[Hh]
	var len: float = ext[L]
	var band = func(from: float, to: float) -> float:
		var a = INF; var b = -INF
		for p in pts:
			if p[L] >= from and p[L] <= to: a = min(a, p[Hh]); b = max(b, p[Hh])
		return b - a if b > a else 0.0
	var h_lo: float = band.call(lo[L], lo[L] + len * 0.15)
	var h_hi: float = band.call(hi[L] - len * 0.15, hi[L])
	if h_hi < h_lo: z_axis = -z_axis           # la boca hacia -Z: el eje +Z apunta a la culata
	var NS = 24; var tops = []; var bots = []
	tops.resize(NS); bots.resize(NS); tops.fill(-INF); bots.fill(INF)
	for p in pts:
		var s: int = clamp(int((p[L] - lo[L]) / len * NS), 0, NS - 1)
		tops[s] = max(tops[s], p[Hh]); bots[s] = min(bots[s], p[Hh])
	if _var(tops) > _var(bots): y_axis = -y_axis
	if d.get("flip", false): z_axis = -z_axis
	if d.get("swap", false): var t = z_axis; z_axis = -y_axis; y_axis = t
	var x_axis = y_axis.cross(z_axis)
	var basis = Basis(x_axis, y_axis, z_axis).transposed()   # filas = ejes viejos que pasan a x, y, z
	src.transform = Transform3D(basis, Vector3.ZERO) * src.transform

func _var(arr: Array) -> float:
	var v = arr.filter(func(x): return abs(x) < 1e8)
	if v.is_empty(): return 0.0
	var m = 0.0
	for x in v: m += x
	m /= v.size(); var s = 0.0
	for x in v: s += (x - m) * (x - m)
	return s / v.size()

## copia lista para la mano (primera persona) con camuflaje
func make_view(id: String, pap: bool) -> Node3D:
	var n: Node3D = _template(id).duplicate()
	var camo = GS.camo_of(id)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in mi.mesh.get_surface_count():
			var src_mat = mi.get_active_material(si)
			var mat: StandardMaterial3D = src_mat.duplicate() if src_mat is StandardMaterial3D else StandardMaterial3D.new()
			mat.use_z_clip_scale = true; mat.z_clip_scale = 0.12          # no se mete en las paredes
			mat.use_fov_override = true; mat.fov_override = 60.0           # mismo tamaño con cualquier campo de visión
			if camo.id != "none":
				mat.albedo_color = mat.albedo_color * camo.color
				mat.metallic = max(mat.metallic, camo.metal); mat.roughness = min(mat.roughness, camo.rough) if camo.metal > 0.5 else mat.roughness
			if pap:
				mat.emission_enabled = true; mat.emission = Color(0.35, 0.12, 0.75); mat.emission_energy_multiplier = 0.12
				mat.albedo_color = mat.albedo_color.lerp(Color(0.5, 0.35, 0.85), 0.18)
			mi.set_surface_override_material(si, mat)
	return n

## copia para el mundo (paredes, caja): sin trucos de primera persona
func make_world(id: String) -> Node3D:
	return _template(id).duplicate()
