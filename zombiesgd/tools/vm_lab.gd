extends Node3D
## Laboratorio del arma en primera persona (sin mapa, rápido): godot --path . res://tools/vm_lab.tscn -- out=<prefijo> [guns=a,b] [fov=75]
## Para cada arma guarda <prefijo>_<arma>_cadera.png y _mira.png con una cruz en el centro de la pantalla.
func _ready() -> void:
	var args = {}
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	get_window().size = Vector2i(960, 540)
	var env = Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.45, 0.5, 0.58)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(1, 1, 1); env.ambient_light_energy = 0.6
	var we = WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 20, 0); add_child(sun)
	# un suelo y una pared con una diana, para ver el centro
	var floor_m = MeshInstance3D.new(); var pm = PlaneMesh.new(); pm.size = Vector2(60, 60); floor_m.mesh = pm; floor_m.position.y = -1.6; add_child(floor_m)
	var target = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(0.3, 0.3, 0.05); target.mesh = bm; target.position = Vector3(0, 0, -10); add_child(target)
	if args.has("vmfov"): Viewmodel.VM_FOV = float(args.vmfov)
	if args.has("hb"): Viewmodel.HAND_BACK = float(args.hb)
	if args.has("hg"): Viewmodel.HANDGUARD = float(args.hg)
	var cam = Camera3D.new(); cam.fov = float(args.get("fov", GS.settings.fov)); cam.current = true; add_child(cam)
	if args.has("sides"):   # todas las armas de lado (boca a la izquierda): para ver si alguna está girada
		var i = 0
		for wid in Data.WEAPONS:
			var g: Node3D = Guns._template(wid).duplicate(); add_child(g)
			g.position = Vector3((i % 4) * 1.3 - 1.95, 1.2 - (i / 4) * 0.75, -6); g.basis = (Basis(Vector3.RIGHT, PI / 2) if args.has("top") else Basis()) * Basis(Vector3.UP, -PI / 2)
			i += 1
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 3.4; cam.position.y = 0.1
		for f in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(String(args.get("out", "/tmp/vm")) + "_lados.png"); get_tree().quit(); return
	var vm = Viewmodel.new(); cam.add_child(vm)
	var cross = _Cross.new(); var cl = CanvasLayer.new(); add_child(cl); cl.add_child(cross); cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var only = String(args.get("guns", "")).split(",", false)
	for wid in Data.WEAPONS:
		if only.size() and not wid in only: continue
		vm.set_weapon(wid, false)
		for k in 2:
			var ads = float(k)
			for f in 50:
				vm.update(1.0 / 60.0, 0.0, false, ads, false, Vector2.ZERO)
				if ads > 0.5: cam.fov = lerp(float(GS.settings.fov), float(GS.settings.fov) * 0.8, ads)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if args.has("dbg") and vm.gun:
				var L = float(Data.WEAPONS[wid].len); var ic = cam.global_transform.affine_inverse()
				print("LAB ", wid, " ads ", ads, " boca ", (ic * (vm.gun.global_transform * Vector3(0, 0, -L / 2))).snapped(Vector3.ONE * 0.001), " culata ", (ic * (vm.gun.global_transform * Vector3(0, 0, L / 2))).snapped(Vector3.ONE * 0.001))
			get_viewport().get_texture().get_image().save_png("%s_%s_%s.png" % [args.get("out", "/tmp/vm"), wid, "mira" if k else "cadera"])
			cam.fov = float(args.get("fov", GS.settings.fov))
	get_tree().quit()

class _Cross extends Control:
	func _draw() -> void:
		var c = get_viewport_rect().size / 2
		draw_line(c - Vector2(12, 0), c + Vector2(12, 0), Color(1, 0, 0), 1.0); draw_line(c - Vector2(0, 12), c + Vector2(0, 12), Color(1, 0, 0), 1.0)
