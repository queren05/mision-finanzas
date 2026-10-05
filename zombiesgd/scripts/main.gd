extends Node
## Escena principal: alterna entre el menú y la partida, con pantalla de carga.
## Pruebas (servidor): -- test=<mapa> t=<segundos> shot=<png> [bot] [god] [round=N] [look=x,y,z,tx,ty,tz]

var menu: Control
var game: Node3D
var loading: Control
var ui: CanvasLayer
var args = {}

func _ready() -> void:
	name = "Main"
	ui = CanvasLayer.new(); ui.layer = 5; add_child(ui)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("menushot"): _menu_shots(); return
	if args.has("nethost") or args.has("netjoin"): _net_test(); return
	if args.has("test"):
		GS.sel_map = args.test; GS.start_round = int(args.get("round", "1")); GS.settings.third = args.has("tp"); Controls.device = args.get("dev", Controls.device); GS.character = args.get("char", GS.character)
		start_game(); return
	to_menu()

## prueba de cooperativo: un proceso hace de anfitrión y otro se une por IP
func _net_test() -> void:
	GS.sel_map = args.get("test", "prison"); GS.start_round = int(args.get("round", "1")); GS.settings.name = "Bot" + ("H" if args.has("nethost") else "C")
	Net.my_name = GS.settings.name
	if args.has("nethost"):
		Net.host(); Net.set_lobby(GS.sel_map, GS.start_round)
		var t0 = Time.get_ticks_msec()
		while Net.players.size() < 2 and Time.get_ticks_msec() - t0 < 90000: await get_tree().create_timer(0.5).timeout
		print("NET jugadores ", Net.players.size())
		Net.start_match()
	else:
		await get_tree().create_timer(2.0).timeout
		Net.join(args.netjoin)

func _menu_shots() -> void:
	to_menu()
	for page in ["_home", "_play", "_arsenal", "_progress", "_chars", "_options", "_armory", "_settings"]:
		menu.call(page)
		for i in 4: await get_tree().process_frame
		if page == "_progress":
			for i in 4: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(String(args.menushot) + "_rewards.png")
			menu.call("_progress", 1)
			for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(String(args.menushot) + page + ".png")
	get_tree().quit()

func to_menu() -> void:
	get_tree().paused = false
	if Net.active: Net.leave()
	if game: game.queue_free(); game = null
	Sfx.stop_ambient()
	Controls.mouse_captured = false; Controls.in_game = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = preload("res://scripts/menu.gd").new(); menu.main = self; ui.add_child(menu)
	Sfx.play_music("m_menu")

func start_game() -> void:
	if menu: menu.queue_free(); menu = null
	loading = _loading_screen(); ui.add_child(loading)
	await get_tree().process_frame; await get_tree().process_frame
	game = preload("res://scripts/game.gd").new(); game.name = "Game"
	game.process_mode = Node.PROCESS_MODE_PAUSABLE   # Main procesa siempre; la partida sí se tiene que parar con la pausa
	add_child(game)
	game.god = args.has("god")
	if args.has("verbose"): print("ARRANCA ", GS.sel_map)
	game.start(GS.sel_map)
	if args.has("verbose"): print("CARGADO")
	loading.queue_free()
	Controls.in_game = not args.has("test")
	if Controls.device == "kb" and not args.has("test"): Controls.mouse_captured = true; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if args.has("test"): _run_test()

func _loading_screen() -> Control:
	var c = ColorRect.new(); c.color = Color(0.02, 0.02, 0.03); c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l = Label.new(); l.text = "CARGANDO…"; l.add_theme_font_override("font", load("res://assets/fonts/BlackOpsOne.ttf")); l.add_theme_font_size_override("font_size", 48)
	l.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1)); l.set_anchors_preset(Control.PRESET_CENTER); l.offset_left = -300; l.offset_right = 300; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_child(l)
	return c

# ------------------------------------------------------------------ pruebas automáticas en el servidor
func _run_test() -> void:
	var t = float(args.get("t", "1"))
	var bot = args.has("bot")
	var p: Player = game.player
	var steps = int(t * 30.0)
	if args.has("dogs"): game.next_dog_round = game.round_n + 1
	if args.has("noanim"): Engine.set_meta("noanim", true)
	if args.has("nozombies"): game.max_alive = 0
	if args.has("spawn"):   # spawn=brute|bloat|dog: aparece uno delante del jugador
		await get_tree().create_timer(0.5).timeout
		var at = game._random_nav_near(p.global_position, 5.0, 7.0)
		game.make_zombie("a", args.spawn, at, 1000.0, 0.9 if args.spawn != "dog" else 5.0)
	if args.has("gun"): p.give_weapon(args.gun); await get_tree().create_timer(1.0).timeout
	if args.has("pausetest"):
		await get_tree().create_timer(14.0).timeout
		var z = game.zombies.filter(func(q): return is_instance_valid(q) and not q.dead)
		var before = z.map(func(q): return q.global_position)
		Controls.press_touch("pause", true); await get_tree().physics_frame; await get_tree().physics_frame; Controls.press_touch("pause", false)
		await get_tree().create_timer(3.0).timeout
		var moved = 0.0
		for i in z.size(): if is_instance_valid(z[i]): moved = max(moved, z[i].global_position.distance_to(before[i]))
		print("PAUSA pausado=", game.paused, " árbol=", get_tree().paused, " zombis=", z.size(), " lo más que se ha movido uno=", moved)
		for key in [KEY_ESCAPE, KEY_P]:
			for down in [true, false]:
				var ev = InputEventKey.new(); ev.keycode = key; ev.physical_keycode = key; ev.pressed = down; Input.parse_input_event(ev)
				await get_tree().create_timer(0.1).timeout
			await get_tree().create_timer(0.5).timeout
			print("PAUSA tecla ", OS.get_keycode_string(key), " -> pausado=", game.paused, " árbol=", get_tree().paused)
		var jb = InputEventJoypadButton.new(); jb.button_index = JOY_BUTTON_START; jb.pressed = true; Input.parse_input_event(jb)
		await get_tree().create_timer(0.1).timeout
		jb = InputEventJoypadButton.new(); jb.button_index = JOY_BUTTON_START; jb.pressed = false; Input.parse_input_event(jb)
		await get_tree().create_timer(0.5).timeout
		print("PAUSA mando Start -> pausado=", game.paused)
		jb = InputEventJoypadButton.new(); jb.button_index = JOY_BUTTON_START; jb.pressed = true; Input.parse_input_event(jb)
		await get_tree().create_timer(0.1).timeout
		jb = InputEventJoypadButton.new(); jb.button_index = JOY_BUTTON_START; jb.pressed = false; Input.parse_input_event(jb)
		await get_tree().create_timer(0.5).timeout
		print("PAUSA mando Start otra vez -> pausado=", game.paused)
		get_tree().quit()
	if args.has("animdbg"):
		for k in 16:
			await get_tree().create_timer(0.25).timeout
			print("ANIM ", k, " ", p.vm.ap.current_animation, " pos ", snapped(p.vm.ap.current_animation_position, 0.01), " cur ", p.vm.cur, " playing ", p.vm.ap.is_playing(), " len ", p.vm.ap.current_animation_length, " draw_t ", snapped(p.vm.draw_t, 0.01))
	if args.has("countmesh"):
		var c = {}
		for m in game.find_children("*", "GeometryInstance3D", true, false):
			if not m.is_visible_in_tree(): continue
			var top = m
			while top.get_parent() != game: top = top.get_parent()
			var k = top.get_class() + ":" + String(top.name).left(14)
			c[k] = c.get(k, 0) + 1
		var arr = c.keys().map(func(k): return [c[k], k]); arr.sort_custom(func(a, b): return a[0] > b[0])
		print("MALLAS ", arr.slice(0, 20))
		var tris = {}
		for m in game.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree() or m.mesh == null: continue
			var top = m
			while top.get_parent() != game: top = top.get_parent()
			var k = String(top.get_script().resource_path.get_file() if top.get_script() else top.get_class()) + ":" + String(top.name).left(12)
			var tri = 0
			for si in m.mesh.get_surface_count():
				var aa = m.mesh.surface_get_arrays(si)
				tri += (aa[Mesh.ARRAY_INDEX].size() if aa[Mesh.ARRAY_INDEX] else aa[Mesh.ARRAY_VERTEX].size()) / 3
			tris[k] = tris.get(k, 0) + tri
		var ta = tris.keys().map(func(k): return [tris[k], k]); ta.sort_custom(func(a, b): return a[0] > b[0])
		print("TRIANGULOS ", ta.slice(0, 16))
		for gn in game.get_children():
			if gn is Node3D:
				for e in ta.slice(0, 8):
					if String(e[1]).ends_with(String(gn.name).left(12)) and e[0] > 15000:
						var ms = gn.find_children("*", "MeshInstance3D", true, false)
						print("PESADO ", e[0], " pos=", gn.global_position.snapped(Vector3.ONE * 0.1), " ", gn.get("id") if "id" in gn else "", gn.get("gun") if "gun" in gn else "", " ", ms[0].mesh.resource_name if ms.size() else "")
		for gn in game.get_children():
			if gn is Node3D and gn.find_children("*", "GeometryInstance3D", true, false).size() > 50:
				var ms = gn.find_children("*", "MeshInstance3D", true, false)
				print("GRUPO ", gn.name, " script=", gn.get_script().resource_path if gn.get_script() else "", " pos=", gn.global_position.snapped(Vector3.ONE * 0.1), " ej=", String(gn.get_path_to(ms[0])) if ms.size() > 0 else "")
		var lights = game.find_children("*", "Light3D", true, false)
		print("LUCES ", lights.size(), " con sombra ", lights.filter(func(l): return l.shadow_enabled).size())
	if args.has("knifeshot"):
		await get_tree().create_timer(3.0).timeout
		if not args.has("noslash"): p._knife()
		for k in 8:
			await get_tree().create_timer(0.05).timeout
			get_viewport().get_texture().get_image().save_png("/tmp/claude-1000/gview/knife_%d.png" % k)
	if args.has("swapdbg"):
		var shots = []
		for k in 3:
			await get_tree().create_timer(1.0).timeout
			var vis = p.vm.gun != null and is_instance_valid(p.vm.gun) and p.vm.gun.is_visible_in_tree()
			print("SWAP ", k, " arma ", p.cur_w().id, " kit ", p.vm.kind, " pistola_visible ", vis, " pos ", (p.cam.global_transform.affine_inverse() * p.vm.gun.global_position) if vis else null, " hijos soporte ", p.vm.holder.get_child_count())
			get_viewport().get_texture().get_image().save_png("/tmp/claude-1000/gview/swap_%d.png" % k)
			Controls.press_touch("swap", true); await get_tree().physics_frame; await get_tree().physics_frame; Controls.press_touch("swap", false)
	if args.has("adsdbg"):
		Controls.touch_held["ads"] = true; await get_tree().create_timer(1.0).timeout
		print("VMDBG holder ", p.vm.holder.transform.origin, " ads_off ", p.vm.ads_off, " base ", p.vm.base_xf.origin, " ads ", p.ads, " arma ", p.vm.gun.global_position if p.vm.gun else null, " cam ", p.cam.global_position)
	if args.has("feet"):   # altura de los pies de los zombis respecto al suelo de verdad
		get_viewport().disable_3d = true
		await get_tree().create_timer(25.0).timeout
		for z in game.zombies:
			if not is_instance_valid(z) or z.dead or z.state != "chase": continue
			var fl = game.ray_world(z.global_position + Vector3(0, 1.0, 0), Vector3.DOWN, 5.0)
			var lo = INF
			for k in z.skel.get_bone_count():
				var n = z.skel.get_bone_name(k)
				if n.contains("Foot") or n.contains("Toe"): lo = min(lo, (z.skel.global_transform * z.skel.get_bone_global_pose(k).origin).y)
			print("PIES tipo=%s nodo-suelo=%.2f pie-suelo=%.2f anim=%s" % [z.type, z.global_position.y - fl.y, lo - fl.y, z.anim.current_animation])
		get_tree().quit(); return
	if args.has("mechanics"): await _mechanics(p); get_tree().quit(); return
	if args.has("netdown"):   # el cliente cae y espera a que le levanten
		get_viewport().disable_3d = true
		await get_tree().create_timer(6.0).timeout
		print("NETDOWN golpe"); p.hp = 5.0; p.take_damage(50.0); print("NETDOWN caído=", p.downed)
		await get_tree().create_timer(10.0).timeout
		print("NETDOWN después: caído=", p.downed, " vivo=", p.alive); get_tree().quit(); return
	if args.has("netrevive"):   # el anfitrión va hasta su compañero caído y le levanta manteniendo USAR
		get_viewport().disable_3d = true
		await get_tree().create_timer(9.0).timeout
		for k in game.remotes:
			var r = game.remotes[k]
			print("NETREVIVE compañero caído=", r.downed)
			p.global_position = r.global_position + Vector3(1.0, 0.2, 0)
		Controls.touch_held["use"] = true
		await get_tree().create_timer(4.0).timeout
		Controls.touch_held["use"] = false
		await get_tree().create_timer(1.0).timeout
		for k in game.remotes: print("NETREVIVE después caído=", game.remotes[k].downed, " stat=", GS.stats.get("revives", 0))
		await get_tree().create_timer(4.0).timeout
		get_tree().quit(); return
	if args.has("scenario"): await _scenario(p)
	Engine.time_scale = 1.0
	get_viewport().disable_3d = not args.has("live")   # la simulación no necesita dibujar; solo la foto final
	for i in steps:
		if bot: _bot(p)
		if args.has("wander"): Controls.touch_move = Vector2(0, 0.6); p.yaw += sin(i * 0.013) * 0.03 + 0.006
		await get_tree().physics_frame
		if args.has("perf") and i % 60 == 59:
			var alive = game.zombies.filter(func(z): return is_instance_valid(z) and not z.dead).size()
			print("PERF zombis=%d proceso=%.1fms física=%.1fms nav=%.1fms dibujos=%d objetos=%d primitivas=%dk" % [alive, Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
		if args.has("trace") and i % 15 == 0:
			var ds = []
			for z in game.zombies:
				if is_instance_valid(z) and not z.dead and z.state == "chase": ds.append("%d(%.2f %s %s)" % [int(z.global_position.distance_to(p.global_position)), Vector2(z.velocity.x, z.velocity.z).length(), "FIN" if z.agent.is_navigation_finished() else "", str(z.global_position.snapped(Vector3.ONE * 0.1)) if z.agent.is_navigation_finished() else ""])
			print("T%d %s" % [i / 30, ds])
		if not is_instance_valid(game) or not p.alive: break
	get_viewport().disable_3d = false
	if args.has("clean"): game.hud.visible = false; p.set_physics_process(false); p.vm.visible = false; p.body.visible = false
	if args.has("watchz"):
		var zz = null; var bd = 99.0
		for z in game.zombies:
			if is_instance_valid(z) and not z.dead and z.state == "chase" and (not args.has("spawn") or z.type == args.spawn or (args.has("dogs") and z.type == "dog")):
				var d = z.global_position.distance_to(p.global_position)
				if d < bd: bd = d; zz = z
		if zz:
			p.set_physics_process(false)
			var f = Vector3(sin(zz.yaw), 0, cos(zz.yaw))
			p.cam.global_position = zz.global_position + f * float(args.watchz) + Vector3(0, 1.5, 0); p.cam.look_at(zz.global_position + Vector3(0, 1.1, 0))
	if args.has("deadtest"):
		var list = game.zombies.filter(func(z): return is_instance_valid(z) and not z.dead)
		var where = []
		for zz in list:
			where.append(zz.state); zz.take_hit(99999.0, zz.global_position + Vector3(0, 1, 0), false, p)
		for k in int(float(args.deadtest) * 60): await get_tree().physics_frame
		for i in list.size():
			var zz = list[i]
			if not is_instance_valid(zz): continue
			var hb = -1
			for j in zz.skel.get_bone_count():
				if zz.skel.get_bone_name(j).contains("Hips"): hb = j; break
			var fl = game.ray_world(zz.global_position + Vector3(0, 1, 0), Vector3.DOWN, 20)
			print("MUERTO ", zz.model.scene_file_path.get_file(), " estado=", where[i], " sobre_suelo=", snapped(zz.global_position.y - fl.y, 0.01), " caderas=", snapped((zz.skel.global_transform * zz.skel.get_bone_global_pose(hb).origin).y - fl.y, 0.01), " model.y=", snapped(zz.model.position.y, 0.01), " anim=", zz.anim.current_animation, " pos=", zz.anim.current_animation_position, " lod=", zz.lod, " spd=", zz.anim.speed_scale, " playing=", zz.anim.is_playing(), " assigned=", zz.anim.assigned_animation)
			p.cam.global_position = zz.global_position + Vector3(3.5, 1.2, 0.5); p.cam.look_at(zz.global_position + Vector3(0, 0.4, 0))
	if args.has("topdown"):
		p.set_physics_process(false); game.hud.visible = false
		var f = -p.global_transform.basis.z
		p.cam.global_position = p.global_position + Vector3(0, 4.0, 0) - f * 0.01; p.cam.look_at(p.global_position, f)   # arriba de la imagen = hacia donde mira el jugador
	if args.has("look"):
		var v = String(args.look).split(","); p.cam.global_position = Vector3(float(v[0]), float(v[1]), float(v[2])); p.cam.look_at(Vector3(float(v[3]), float(v[4]), float(v[5])))
	for k in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if args.has("shot"): get_viewport().get_texture().get_image().save_png(args.shot)
	if args.has("pauseshot"):
		game.pause(true)
		for k in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.pauseshot)
	if args.has("inspect"):
		var k = 0
		for it in game.interactables:
			if it is Interactables.Door: continue
			var f = it.global_transform.basis.z.normalized()
			p.cam.global_position = it.global_position + f * 2.6 + Vector3(0, 1.55, 0) + it.global_transform.basis.x * 0.8
			p.cam.look_at(it.global_position + Vector3(0, 1.05, 0))
			for j in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(String(args.get("out", "/tmp/shot")) + "_%02d.png" % k); k += 1
	if args.has("hidegrp"):   # depuración: esconde nodos de la partida por tipo (para medir qué cuesta dibujar)
		for gn in game.find_children("*", String(args.hidegrp), true, false): gn.visible = false
	if args.has("looks"):
		var k = 0
		for spec in String(args.looks).split(";"):
			var v = spec.split(","); p.cam.global_position = Vector3(float(v[0]), float(v[1]), float(v[2])); p.cam.look_at(Vector3(float(v[3]), float(v[4]), float(v[5])))
			if args.has("clean"): game.hud.visible = false; p.vm.scale = Vector3.ONE * 0.0001   # (el jugador vuelve a mostrar los brazos cada fotograma)
			for j in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			print("VISTA %d dibujos=%d objetos=%d primitivas=%dk" % [k, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
			get_viewport().get_texture().get_image().save_png(String(args.get("out", "/tmp/shot")) + "_%d.png" % k); k += 1
	var alive: int = game.zombies.filter(func(z): return is_instance_valid(z) and not z.dead).size() if is_instance_valid(game) else 0
	print("TEST round=", game.round_n, " kills=", p.kills, " alive=", alive, " hp=", p.hp, " pos=", p.global_position)
	if Net.active: print("NET soy=", Net.my_id(), " servidor=", Net.is_host(), " compañeros=", game.remotes.size(), " zombis=", game.zombies.size(), " puntos=", p.points, " bajas=", p.kills, " ronda=", game.round_n, " puertas=", game.doors.filter(func(d): return d.open).size(), " pos_compa=", game.remotes.values().map(func(r): return r.global_position.snapped(Vector3.ONE * 0.1)))
	get_tree().quit()

# ------------------------------------------------------------------ batería de pruebas de mecánicas
var results = []
func _ok(name: String, cond: bool, info := "") -> void:
	results.append([name, cond]); print("%s %s %s" % ["PASA " if cond else "FALLA", name, info])
	if args.has("verbose"): var p = game.player; print("   [vida %.0f vivo %s caído %s pos %s arma %s fin %s]" % [p.hp, p.alive, p.downed, p.global_position.snapped(Vector3.ONE * 0.1), p.cur_w().id, game.over])

func _frames(n: int) -> void:
	for k in n: await get_tree().physics_frame

## zombi de prueba delante del jugador (quieto) para disparar
func _dummy(p: Player, dist := 4.0, type := "normal", hp := 100.0) -> Zombie:
	var map = p.get_world_3d().navigation_map
	var at = Vector3.INF
	for k in 48:   # una dirección con línea de tiro limpia (sin puertas ni paredes en medio); si no hay, más cerca
		if k == 16 or k == 32: dist *= 0.6
		var f = Vector3(sin(k * TAU / 16), 0, cos(k * TAU / 16))
		var c = NavigationServer3D.map_get_closest_point(map, p.global_position + f * dist)
		var eye = p.cam.global_position
		var tgt = c + Vector3(0, 1.0, 0)
		if c.distance_to(p.global_position + f * dist) < 0.8 and game.ray_world(eye, (tgt - eye).normalized(), eye.distance_to(tgt)) == Vector3.INF: at = c; break
	if at == Vector3.INF: at = p.global_position + Vector3(2.5, 0, 0)
	var z = game.make_zombie("a", type, at, hp, 0.0)
	z.state = "chase"; z.model.position.y = 0.0; z.max_speed = 0.0
	await _frames(2)
	return z

func _aim_at(p: Player, z: Node3D, h := 1.2) -> void:
	var to: Vector3 = (z.global_position + Vector3(0, h, 0)) - p.cam.global_position
	p.yaw = atan2(-to.x, -to.z); p.pitch = asin(clamp(to.normalized().y, -1, 1))
	p.sync_head()

func _fire(n_frames: int) -> void:
	for k in n_frames:
		Controls.touch_held["fire"] = k % 4 < 2
		await get_tree().physics_frame
	Controls.touch_held["fire"] = false

func _mechanics(p: Player) -> void:
	game.max_alive = 0; game.to_spawn = 0; game.break_t = 999.0   # sin zombis de la ronda: los pone la prueba
	Controls.device = "touch"   # la prueba mueve con el joystick táctil (correr = llevarlo al borde)
	get_viewport().disable_3d = true
	game.god = false
	await _frames(30)
	var map = p.get_world_3d().navigation_map
	# --- movimiento
	var p0 = p.global_position
	Controls.touch_move = Vector2(0, 0.6); await _frames(30); Controls.touch_move = Vector2.ZERO
	_ok("andar", p.global_position.distance_to(p0) > 1.0, "%.2f m" % p.global_position.distance_to(p0))
	await _frames(20)
	p0 = p.global_position
	Controls.touch_move = Vector2(0, 1.0); await _frames(30); Controls.touch_move = Vector2.ZERO
	_ok("correr más rápido", p.global_position.distance_to(p0) > 2.5, "%.2f m" % p.global_position.distance_to(p0))
	await _frames(20)
	Controls.press_touch("crouch", true); await _frames(2); Controls.press_touch("crouch", false); await _frames(30)
	_ok("agacharse", p.head.position.y < 1.3, "cabeza %.2f" % p.head.position.y)
	Controls.press_touch("crouch", true); await _frames(2); Controls.press_touch("crouch", false); await _frames(30)
	var y0 = p.global_position.y
	Controls.press_touch("jump", true); await _frames(2); Controls.press_touch("jump", false); await _frames(12)
	var top = p.global_position.y
	await _frames(50)
	_ok("saltar y caer", top - y0 > 0.3 and abs(p.global_position.y - y0) < 0.3, "sube %.2f" % (top - y0))
	# --- disparar, puntos, munición, recargar
	var z = await _dummy(p, 5.0, "normal", 150.0)
	_aim_at(p, z)
	Engine.set_meta("dbg_shots", true)
	print("DUMMY en ", z.global_position, " jugador ", p.global_position, " cam ", p.cam.global_position)
	var pts0 = p.points; var mag0 = p.cur_w().mag
	await _fire(90)
	await _frames(10)
	Engine.remove_meta("dbg_shots")
	_ok("disparar mata zombi", z.dead, "vida %.0f" % z.hp)
	_ok("puntos por bajas", p.points > pts0, "%d -> %d" % [pts0, p.points])
	_ok("gasta munición", p.cur_w().mag < mag0)
	if args.mechanics == "shoot": return
	Controls.press_touch("reload", true); await _frames(2); Controls.press_touch("reload", false)
	await _frames(int(float(p.stat("reload")) * 60) + 10)
	_ok("recargar", p.cur_w().mag == int(p.stat("mag")), "%d/%d" % [p.cur_w().mag, int(p.stat("mag"))])
	# --- tiro a la cabeza
	z = await _dummy(p, 5.0, "normal", 2000.0); _aim_at(p, z, 0.0)
	var hz = z.head_pos(); var to = hz - p.cam.global_position
	p.yaw = atan2(-to.x, -to.z); p.pitch = asin(clamp(to.normalized().y, -1, 1)); p.sync_head()
	var hp0 = z.hp
	Controls.touch_held["ads"] = true; await _frames(30)
	to = z.head_pos() - p.cam.global_position; p.yaw = atan2(-to.x, -to.z); p.pitch = asin(clamp(to.normalized().y, -1, 1)); p.sync_head(); p.recoil = Vector2.ZERO
	Controls.touch_held["fire"] = true; await _frames(2); Controls.touch_held["fire"] = false; await _frames(5)
	Controls.touch_held["ads"] = false
	_ok("tiro a la cabeza hace más daño", hp0 - z.hp > 60.0, "daño %.0f" % (hp0 - z.hp))
	game._remove_zombie(z)
	# --- cuchillo
	z = await _dummy(p, 1.1, "normal", 100.0); _aim_at(p, z)
	Controls.press_touch("knife", true); await _frames(2); Controls.press_touch("knife", false); await _frames(10)
	_ok("cuchillo", z.dead)
	# --- granada
	await _frames(30)
	z = await _dummy(p, 9.0, "normal", 300.0); _aim_at(p, z, -1.2)
	var g0 = p.grenades
	Controls.press_touch("grenade", true); await _frames(2); Controls.press_touch("grenade", false)
	await _frames(170)
	_ok("granada explota y mata", z.dead and p.grenades == g0 - 1, "granadas %d->%d vida %.0f" % [g0, p.grenades, z.hp])
	# --- compras: puertas, corriente, bebidas, armas, caja, Pack-a-Punch, chicles
	p.points = 200000
	var d0 = game.doors.filter(func(d): return d.open).size()
	for it in game.interactables.duplicate():
		if it is Interactables.Door: it.use(p)
	await _frames(5)
	var d1 = game.doors.filter(func(d): return d.open).size()
	_ok("abrir puertas", d1 > d0 and p.points < 200000, "%d -> %d abiertas" % [d0, d1])
	var zones_open = game.zones.values().filter(func(zz): return zz.open).size()
	_ok("zonas abiertas", zones_open == game.zones.size() or zones_open > 1, "%d/%d" % [zones_open, game.zones.size()])
	for it in game.interactables:
		if it is Interactables.Power: it.use(p)
	await _frames(3)
	_ok("corriente", game.power_on)
	for it in game.interactables:
		if it is Interactables.Perk: it.use(p)
	await _frames(3)
	_ok("bebidas", p.perks.size() == 6 and p.max_hp == 250.0, str(p.perks))
	for it in game.interactables:
		if it is Interactables.WallBuy and it.gun == "mp40": it.use(p)
	await _frames(3)
	_ok("arma de pared", p.has_weapon("mp40") >= 0)
	var box: Interactables.MysteryBox = null
	for it in game.interactables:
		if it is Interactables.MysteryBox: box = it
	if box:
		var pb = p.points
		box.use(p); await _frames(280)
		var offered = box.final
		box.use(p); await _frames(5)
		_ok("caja misteriosa", (offered == "teddy") or p.has_weapon(offered) >= 0, "salió %s, cobra %d" % [offered, pb - p.points])
	var pap: Interactables.PackAPunch = null
	for it in game.interactables:
		if it is Interactables.PackAPunch: pap = it
	if pap:
		p.cur = p.has_weapon("mp40"); p._equip()
		pap.use(p); await _frames(240); pap.use(p); await _frames(5)
		var k = p.has_weapon("mp40")
		_ok("Pack-a-Punch", k >= 0 and p.weapons[k].pap, str(p.weapons.map(func(w): return w.id + ("+" if w.pap else ""))))
	var gm = null
	for it in game.interactables:
		if it.get_script() and it is Interactables.GumMachine: gm = it
	if gm:
		var pg = p.points; var ng = p.gums.size()
		gm.use(p); await _frames(3)
		_ok("máquina de chicles", p.points == pg - 500, "chicles activos %d" % p.gums.size())
	p.give_gum("eterno"); var m0 = p.cur_w().mag
	z = await _dummy(p, 5.0, "normal", 99999.0); _aim_at(p, z)
	await _fire(8)
	_ok("chicle Cargador Eterno (no gasta balas)", p.cur_w().mag == m0)
	game._remove_zombie(z); p.gums.erase("eterno")
	# --- armas maravilla
	for ww in ["raygun", "bubble"]:
		p.give_weapon(ww); await _frames(60)
		z = await _dummy(p, 7.0, "normal", 400.0); _aim_at(p, z, 1.0)
		print("   disparo ", ww, " zombi=", z.global_position, " colisión=", z.get_child(0).global_position, " estado=", z.state, " arma=", p.cur_w().id, " cargador=", p.cur_w().mag, " cd=", p.fire_cd, " swap=", p.swap_t, " recarga=", p.reload_t)
		var rq = PhysicsRayQueryParameters3D.create(p.cam.global_position, z.global_position + Vector3(0, 1.0, 0), 21); rq.exclude = [p.get_rid()]
		print("   rayo de prueba: ", p.get_world_3d().direct_space_state.intersect_ray(rq), " capa=", z.collision_layer, " forma=", z.get_child(0).shape, " desactivada=", z.get_child(0).disabled)
		Controls.touch_held["fire"] = true; await _frames(4); Controls.touch_held["fire"] = false
		await _frames(240)
		_ok("arma maravilla " + ww, z.dead, "vida %.0f" % z.hp)
	# --- potenciadores
	for w in p.weapons: w.res = 0
	game._drop_powerup(p.global_position + Vector3(0, 0, 0), "max_ammo"); await _frames(20)
	_ok("potenciador munición máxima", p.cur_w().res > 0)
	game._drop_powerup(p.global_position, "insta_kill"); await _frames(20)
	_ok("potenciador muerte instantánea", game.insta > 0.0)
	var zs = []
	for k in 3: zs.append(await _dummy(p, 6.0 + k, "normal", 5000.0))
	game._drop_powerup(p.global_position, "nuke"); await _frames(20)
	_ok("potenciador nuclear", zs.all(func(q): return q.dead))
	game.insta = 0.0
	# --- enemigos especiales
	await _frames(60)
	p.give_weapon("m16"); await _frames(40)
	z = await _dummy(p, 7.0, "dog", 300.0); _aim_at(p, z, 0.5)
	await _fire(60); await _frames(10)
	_ok("perro infernal (aparece y muere)", z.dead, "vida %.0f" % z.hp)
	z = await _dummy(p, 7.0, "bloat", 200.0); _aim_at(p, z)
	await _fire(60); await _frames(10)
	_ok("Hinchado revienta", z.dead)
	z = await _dummy(p, 8.0, "brute", 400.0); _aim_at(p, z, 1.6)
	p.give_weapon("raygun")
	for k in 6:
		_aim_at(p, z, 1.6); Controls.touch_held["fire"] = true; await _frames(2); Controls.touch_held["fire"] = false; await _frames(30)
	await _frames(60)
	_ok("Bruto (muere y cuenta)", z.dead and int(GS.stats.get("brutes", 0)) > 0)
	# ronda de perros
	game.next_dog_round = game.round_n + 1; game.max_alive = 24; game.break_t = 0.01
	await _frames(400)
	var dogs = game.zombies.filter(func(q): return is_instance_valid(q) and q.type == "dog")
	_ok("ronda de perros", game.dog_round and dogs.size() > 0, "perros %d" % dogs.size())
	for q in game.zombies.duplicate():
		if is_instance_valid(q) and not q.dead: q.take_hit(1e9, q.global_position, false, 1, "nuke")
	game.to_spawn = 0; await _frames(30)
	game.max_alive = 0; game.break_t = 999.0
	# --- caer y levantarse (Quick Revive en solitario)
	p.gums.clear(); p.give_perk("revive"); p.hp = 10.0; p.take_damage(50.0)
	_ok("caer al suelo", p.downed)
	await _frames(250)
	_ok("levantarse con Quick Revive", not p.downed and p.alive)
	# --- tercera persona
	p.toggle_view(); await _frames(10)
	_ok("tercera persona", p.third and p.cam.position.length() > 0.5)
	p.toggle_view(); await _frames(5)
	# --- easter egg
	if game.egg.parts.size() == 3:
		for k in 3: game.world_request(null, "egg_part", k, func(_r): pass)
		await _frames(5)
		_ok("easter egg: piezas", game.egg.step == 2, "paso %d" % game.egg.step)
		game.world_request(null, "egg_build", null, func(_r): pass); await _frames(3)
		game.world_request(null, "egg_start", null, func(_r): pass); await _frames(3)
		_ok("easter egg: defensa", game.egg.step == 4)
		game.egg.defend_t = 0.01; await _frames(10)
		_ok("easter egg: aparece el guardián", game.egg.step == 5 and game.zmap.has(game.egg.boss))
		var boss = game.zmap.get(game.egg.boss)
		if boss: boss.take_hit(1e12, boss.global_position, false, 1, "bullet", "m1911")
		await _frames(10)
		_ok("easter egg completado", game.egg.step == 6 and p.perks.size() == 6)
		for k in 3: game.world_request(null, "plush", k, func(_r): pass)
		await _frames(5)
		_ok("canción oculta", Sfx.music_track == "m_song")
	else:
		_ok("easter egg preparado", false, "sin piezas")
	_ok("desafíos y experiencia", game.completed.size() > 0 or GS.done.size() > 0, "%d completados" % game.completed.size())
	# --- caer sin Quick Revive = fin de partida
	p.perks.clear(); p.max_hp = 100.0; p.hp = 10.0; p.take_damage(50.0)
	await _frames(200)
	_ok("fin de partida", game.over)
	var bad = results.filter(func(r): return not r[1])
	print("RESUMEN %d/%d pasan" % [results.size() - bad.size(), results.size()])

## prueba de todos los elementos: compra puertas, corriente, bebidas, armas, caja y Pack-a-Punch
func _scenario(p: Player) -> void:
	p.points = 200000
	if args.has("reach"):
		var sp0 = p.global_position
		for it in game.interactables:
			if it is Interactables.Door: it.open_now(true)
		game.power_on = true
		for k in 30: await get_tree().physics_frame
		# alcance real: desde algún punto transitable cerca de cada cosa, el jugador debe poder usarla
		var nav = p.get_world_3d().navigation_map
		for it in game.interactables:
			if it is Interactables.Door: continue
			var ok = false
			for a in 16:
				var r = 0.8 + (a / 8) * 0.6
				var cand = it.global_position + Vector3(cos(a * TAU / 8), 0, sin(a * TAU / 8)) * r
				var q = NavigationServer3D.map_get_closest_point(nav, cand)
				if args.has("dbg") and it is Interactables.PackAPunch: print("  pap cand ", cand, " q ", q)
				if q.distance_to(cand) > 1.5: continue
				p.global_position = q + Vector3(0, 0.05, 0)
				await get_tree().physics_frame
				var got = game.find_interactable(p)
				if got == it: ok = true; break
				if args.has("dbg") and it is Interactables.PackAPunch: print("  pap? p=", p.global_position, " q=", q, " can=", it.can_use(p), " got=", got, " prompt=", it.prompt(p))
			print("ALCANCE ", it.get_script().get_global_name() if false else str(it.get("id") if it.get("id") != null else it.get("gun") if it.get("gun") != null else it.name), " ", it.global_position, " ", "ok" if ok else "NO SE PUEDE USAR")
		p.global_position = sp0
	var log = []
	for it in game.interactables:
		if it is Interactables.Door: it.use(p); log.append("puerta %d abierta=%s" % [it.idx, it.open])
	for it in game.interactables:
		if it is Interactables.Power: it.use(p); log.append("corriente=%s" % game.power_on)
	for it in game.interactables:
		if it is Interactables.Perk:
			p.global_position = it.global_position + it.global_transform.basis.z * 1.2
			log.append("bebida %s: '%s'" % [it.id, it.prompt(p)]); it.use(p)
	for it in game.interactables:
		if it is Interactables.WallBuy: it.use(p); log.append("pared %s -> armas %s" % [it.gun, p.weapons.map(func(w): return w.id)])
	for it in game.interactables:
		if it is Interactables.MysteryBox:
			it.use(p); for k in 300: await get_tree().physics_frame
			log.append("caja: estado %s oferta %s" % [it.state, it.offer]); it.use(p); log.append("tras coger: %s" % [p.weapons.map(func(w): return w.id)])
	for it in game.interactables:
		if it is Interactables.PackAPunch:
			it.use(p); for k in 260: await get_tree().physics_frame
			it.use(p); log.append("pap: %s" % [p.weapons.map(func(w): return w.id + ("+" if w.pap else ""))])
	print("ESCENARIO\n  " + "\n  ".join(log)); print("ventajas ", p.perks, " puntos ", p.points)


func _bot(p: Player) -> void:
	var best = null; var bd = 99.0
	for z in game.zombies:
		if not is_instance_valid(z) or z.dead or z.state != "chase": continue
		var d: float = z.global_position.distance_to(p.global_position)
		if d < bd: bd = d; best = z
	Controls.touch_held["fire"] = false
	if best:
		var to: Vector3 = (best.global_position + Vector3(0, 1.45, 0)) - p.cam.global_position
		p.yaw = atan2(-to.x, -to.z); p.pitch = asin(clamp(to.normalized().y, -1, 1))
		Controls.touch_held["fire"] = Engine.get_physics_frames() % 4 < 2
