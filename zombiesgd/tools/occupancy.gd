extends SceneTree
## Mapa de ocupación de un mapa (paredes a la altura del pecho): godot --path zombiesgd -s tools/occupancy.gd -- <mapa> <salida.png> y x0 z0 x1 z1
func _initialize() -> void:
	await process_frame
	var a = OS.get_cmdline_user_args()
	var cfg = MapBuilder.load_config(a[0])
	var holder = Node3D.new(); root.add_child(holder)
	MapBuilder.build_scene(cfg, holder)
	for k in 3: await physics_frame
	var y = float(a[2]); var x0 = float(a[3]); var z0 = float(a[4]); var x1 = float(a[5]); var z1 = float(a[6])
	var res = float(a[7]) if a.size() > 7 else 0.2; var w = int((x1 - x0) / res); var h = int((z1 - z0) / res)
	var img = Image.create(w, h, false, Image.FORMAT_RGB8)
	var space = holder.get_world_3d().direct_space_state
	var sh = SphereShape3D.new(); sh.radius = 0.12
	var q = PhysicsShapeQueryParameters3D.new(); q.shape = sh; q.collision_mask = 0xFFFF
	for j in h:
		for i in w:
			var x = x0 + (i + 0.5) * res; var z = z0 + (j + 0.5) * res
			# suelo debajo
			var r = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y + 2.0, z), Vector3(x, y - 3.0, z)))
			var c = Color(0.05, 0.05, 0.08)
			if not r.is_empty():
				var fy = r.position.y
				c = Color(0.55, 0.55, 0.5).lerp(Color(0.2, 0.4, 0.9), clamp((fy - (y - 1.2)) / 4.0, 0, 1))
				q.transform = Transform3D(Basis(), Vector3(x, fy + 1.0, z))
				if space.intersect_shape(q, 1).size() > 0: c = Color(0.9, 0.2, 0.15)
			if (int(x * 5) % 25 == 0) or (int(z * 5) % 25 == 0): c = c.lerp(Color(1, 1, 0), 0.35)
			img.set_pixel(i, j, c)
	img.save_png(a[1])
	print("OK ", w, "x", h)
	quit()
