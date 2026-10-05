extends Node3D
## Vistas de un modelo desde los 4 lados (+Z, +X, -Z, -X) y desde arriba, en una tira: para saber hacia dónde mira la fachada.
## Uso: godot --path zombiesgd res://tools/model_views.tscn -- <ruta.gltf> <escala> <salida_prefijo>
func _ready() -> void:
	var a = OS.get_cmdline_user_args()
	get_window().size = Vector2i(512, 384)
	var env = Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.32, 0.34, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(1, 1, 1); env.ambient_light_energy = 0.7
	var we = WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var n: Node3D = load(a[0]).instantiate(); n.scale = Vector3.ONE * float(a[1]); add_child(n)
	await get_tree().process_frame
	var lo = Vector3.INF; var hi = -Vector3.INF
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var b = m.global_transform * m.get_aabb(); lo = lo.min(b.position); hi = hi.max(b.end)
	var c = (lo + hi) / 2; var sz = (hi - lo)
	print("CAJA min ", lo.snapped(Vector3.ONE * 0.01), " max ", hi.snapped(Vector3.ONE * 0.01), " tamaño ", sz.snapped(Vector3.ONE * 0.01))
	var cam = Camera3D.new(); add_child(cam); cam.fov = 45; cam.current = true
	var r = sz.length() * 1.05
	var dirs = [Vector3(0, 0.35, 1), Vector3(1, 0.35, 0), Vector3(0, 0.35, -1), Vector3(-1, 0.35, 0), Vector3(0.001, 1, 0.001)]
	for k in dirs.size():
		cam.position = c + dirs[k].normalized() * r; cam.look_at(c, Vector3.UP if k < 4 else Vector3(0, 0, -1))
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(a[2] + "_%d.png" % k)
	get_tree().quit()
