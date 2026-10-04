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
	if args.has("test"):
		GS.sel_map = args.test; GS.start_round = int(args.get("round", "1"))
		start_game(); return
	to_menu()

func _menu_shots() -> void:
	to_menu()
	for page in ["_home", "_maps", "_options", "_armory", "_settings"]:
		menu.call(page)
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(String(args.menushot) + page + ".png")
	get_tree().quit()

func to_menu() -> void:
	get_tree().paused = false
	if game: game.queue_free(); game = null
	Sfx.stop_ambient()
	Controls.mouse_captured = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = preload("res://scripts/menu.gd").new(); menu.main = self; ui.add_child(menu)

func start_game() -> void:
	if menu: menu.queue_free(); menu = null
	loading = _loading_screen(); ui.add_child(loading)
	await get_tree().process_frame; await get_tree().process_frame
	game = preload("res://scripts/game.gd").new(); game.name = "Game"
	add_child(game)
	game.god = args.has("god")
	game.start(GS.sel_map)
	loading.queue_free()
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
	if args.has("scenario"): await _scenario(p)
	Engine.time_scale = 1.0
	get_viewport().disable_3d = not args.has("live")   # la simulación no necesita dibujar; solo la foto final
	for i in steps:
		if bot: _bot(p)
		if args.has("wander"): Controls.touch_move = Vector2(0, 0.6); p.yaw += sin(i * 0.013) * 0.03 + 0.006
		await get_tree().physics_frame
		if args.has("trace") and i % 15 == 0:
			var ds = []
			for z in game.zombies:
				if is_instance_valid(z) and not z.dead and z.state == "chase": ds.append("%d(%.2f %s %s)" % [int(z.global_position.distance_to(p.global_position)), Vector2(z.velocity.x, z.velocity.z).length(), "FIN" if z.agent.is_navigation_finished() else "", str(z.global_position.snapped(Vector3.ONE * 0.1)) if z.agent.is_navigation_finished() else ""])
			print("T%d %s" % [i / 30, ds])
		if not is_instance_valid(game) or not p.alive: break
	get_viewport().disable_3d = false
	if args.has("clean"): game.hud.visible = false; p.vm.visible = false
	if args.has("watchz"):
		var zz = null; var bd = 99.0
		for z in game.zombies:
			if is_instance_valid(z) and not z.dead and z.state == "chase":
				var d = z.global_position.distance_to(p.global_position)
				if d < bd: bd = d; zz = z
		if zz:
			var f = Vector3(sin(zz.yaw), 0, cos(zz.yaw))
			p.cam.global_position = zz.global_position + f * float(args.watchz) + Vector3(0, 1.5, 0); p.cam.look_at(zz.global_position + Vector3(0, 1.1, 0))
	if args.has("look"):
		var v = String(args.look).split(","); p.cam.global_position = Vector3(float(v[0]), float(v[1]), float(v[2])); p.cam.look_at(Vector3(float(v[3]), float(v[4]), float(v[5])))
	for k in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if args.has("shot"): get_viewport().get_texture().get_image().save_png(args.shot)
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
	if args.has("looks"):
		var k = 0
		for spec in String(args.looks).split(";"):
			var v = spec.split(","); p.cam.global_position = Vector3(float(v[0]), float(v[1]), float(v[2])); p.cam.look_at(Vector3(float(v[3]), float(v[4]), float(v[5])))
			for j in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(String(args.get("out", "/tmp/shot")) + "_%d.png" % k); k += 1
	var alive: int = game.zombies.filter(func(z): return is_instance_valid(z) and not z.dead).size() if is_instance_valid(game) else 0
	print("TEST round=", game.round_n, " kills=", p.kills, " alive=", alive, " hp=", p.hp, " pos=", p.global_position)
	get_tree().quit()

## prueba de todos los elementos: compra puertas, corriente, bebidas, armas, caja y Pack-a-Punch
func _scenario(p: Player) -> void:
	p.points = 200000
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
