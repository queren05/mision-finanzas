extends Node3D
## Vista de depuración: godot --path . res://tools/debug_view.tscn -- <mapa> <salida.png> [x,y,z,tx,ty,tz]
## Pinta la navegación (verde) y las zonas sobre el mapa.
func _ready() -> void:
	var a = OS.get_cmdline_user_args(); var id: String = a[0]; var out: String = a[1]
	var cfg = MapBuilder.load_config(id)
	var root = MapBuilder.build_scene(cfg, self)
	var env = WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(.08,.08,.1); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(.7,.7,.7); add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-60, 30, 0); add_child(sun)
	var aabb = AABB(); var first = true
	for b in MapBuilder.nav_boxes(cfg):
		var path = "res://assets/maps/%s/nav/%s.res" % [id, b.id]
		aabb = b.aabb if first else aabb.merge(b.aabb); first = false
		if not ResourceLoader.exists(path): continue
		var nm: NavigationMesh = load(path)
		var im = ImmediateMesh.new(); var mi = MeshInstance3D.new(); mi.mesh = im; add_child(mi)
		var mat = StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = Color(0.1, 1, 0.3, 0.45) if not b.id.begins_with("door") else Color(1, .6, 0, .6); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.no_depth_test = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mi.material_override = mat
		var v = nm.get_vertices()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in nm.get_polygon_count():
			var poly = nm.get_polygon(p)
			for k in range(1, poly.size() - 1):
				for q in [poly[0], poly[k], poly[k + 1]]: im.surface_add_vertex(v[q] + Vector3(0, 0.05, 0))
		im.surface_end()
	var cam = Camera3D.new(); add_child(cam); cam.far = 3000
	if a.size() > 2:
		var p = a[2].split(","); cam.fov = 70; cam.position = Vector3(float(p[0]), float(p[1]), float(p[2])); cam.look_at(Vector3(float(p[3]), float(p[4]), float(p[5])))
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL; var c = aabb.get_center(); cam.size = max(aabb.size.x, aabb.size.z); cam.position = Vector3(c.x, aabb.end.y + 30, c.z); cam.rotation_degrees = Vector3(-90, 0, 0)
	get_viewport().size = Vector2i(1600, 1600) if a.size() <= 2 else Vector2i(1280, 720)
	await get_tree().process_frame; await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out); get_tree().quit()
