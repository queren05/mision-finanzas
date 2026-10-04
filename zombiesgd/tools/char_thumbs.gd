extends SceneTree
## Imágenes de los personajes para el menú: godot --path zombiesgd -s tools/char_thumbs.gd
func _initialize() -> void:
	await process_frame
	var vp = SubViewport.new(); vp.size = Vector2i(480, 300); vp.transparent_bg = true; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var w = Node3D.new(); vp.add_child(w)
	var env = WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_CLEAR_COLOR; env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.8, 0.8, 0.85); env.environment.ambient_light_energy = 0.9; w.add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 35, 0); sun.light_energy = 1.4; w.add_child(sun)
	var rim = DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-20, 200, 0); rim.light_energy = 0.8; rim.light_color = Color(1, 0.5, 0.4); w.add_child(rim)
	var cam = Camera3D.new(); cam.fov = 32; w.add_child(cam)
	for id in Data.CHARACTERS:
		var c = Data.CHARACTERS[id]
		var piv = Node3D.new(); w.add_child(piv)
		var cm = load("res://scripts/character_model.gd").new(); piv.add_child(cm); cm.setup(id)
		piv.rotation_degrees.y = 145.0
		var m: Node3D = cm
		if cm.human:
			cm.set_weapon("m16")
			for q in 3: await process_frame
			cm.update(0.016, 0.0, false, false, false, 0.0)
		await process_frame
		var lo = Vector3.INF; var hi = -Vector3.INF
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb(); lo = lo.min(b.position); hi = hi.max(b.end)
		var ctr = (lo + hi) / 2; var size = (hi - lo).length()
		if cm.human: ctr = Vector3(0, 0.95, 0); size = 2.4
		cam.position = ctr + Vector3(0, size * 0.25, size * 1.55); cam.look_at(ctr)
		for k in 3: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("res://assets/ui/char_%s.png" % id)
		print("IMG ", id)
		piv.queue_free()
	quit()
