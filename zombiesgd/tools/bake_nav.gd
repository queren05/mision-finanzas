extends SceneTree
## Hornea la navegación de un mapa: godot --headless --path zombiesgd -s tools/bake_nav.gd -- <mapa>
## Guarda assets/maps/<mapa>/nav/<caja>.res (una malla por zona y por puerta).

func _initialize() -> void:
	await process_frame
	var id: String = OS.get_cmdline_user_args()[0]
	var cfg = MapBuilder.load_config(id)
	var holder = Node3D.new(); root.add_child(holder)
	MapBuilder.build_scene(cfg, holder)
	for b in holder.find_children("*", "StaticBody3D", true, false):
		if b.has_meta("door_part"): b.get_parent().remove_child(b); b.free()
	await process_frame
	var nm = MapBuilder.nav_settings()
	var src = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, holder)
	DirAccess.make_dir_recursive_absolute("res://assets/maps/%s/nav" % id)
	for b in MapBuilder.nav_boxes(cfg):
		var m = MapBuilder.nav_settings()
		m.filter_baking_aabb = b.aabb.grow(MapBuilder.BORDER)
		NavigationServer3D.bake_from_source_geometry_data(m, src)
		var path = "res://assets/maps/%s/nav/%s.res" % [id, b.id]
		ResourceSaver.save(m, path)
		print("NAV ", b.id, " polígonos ", m.get_polygon_count(), " vértices ", m.get_vertices().size())
	quit()
