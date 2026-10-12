class_name Mission
extends CanvasLayer
## Misión del modo historia: va paso a paso (ver Campaign), marca el objetivo en pantalla, pone los subtítulos de la
## radio y decide cuántos zombis salen. Solo para un jugador.

signal finished(ok: bool)

var game: Node
var data: Dictionary
var step_i = -1
var step: Dictionary = {}
var t = 0.0                  # tiempo dentro del paso
var progress = 0.0           # defensa: segundos acumulados dentro de la zona
var items: Array = []        # objetos que coger en este paso
var picked = 0
var target = Vector3.INF     # a dónde apunta el marcador
var downs = 0
var done = false
var brute_sent = false
var boss: Zombie = null      # jefe del paso «boss»
var npc: Node3D = null       # superviviente del paso «escort»
var boss_max = 1.0
var plant_t = 0.0            # colocar cargas: segundos quieto junto a la carga actual
var last_cp = 0              # último punto de control (paso desde el que se puede reintentar)
var intel_items: Array = []  # documentos escondidos por el mapa
var doc_panel: PanelContainer
var doc_t = 0.0

# interfaz
var obj_title: Label
var obj_text: Label
var radio_box: PanelContainer
var radio_txt: RichTextLabel
var radio_queue: Array = []
var radio_t = 0.0
var radio_voice: AudioStreamPlayer
var radio_index = {}         # texto -> archivo de voz (assets/voice/radio)
var marker: Control
var bar: ProgressBar
var beacon: MeshInstance3D

func setup(g: Node, m: Dictionary) -> void:
	game = g; data = m
	layer = 5
	game.hud.toast_box.offset_top = 128; game.hud.toast_box.offset_bottom = 320   # los avisos, debajo del objetivo
	var font_bo = load("res://assets/fonts/BlackOpsOne.ttf"); var font_ui = load("res://assets/fonts/Oswald.ttf")
	# objetivo arriba en el centro
	var top = VBoxContainer.new(); top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); top.offset_top = 18; top.offset_left = -360; top.offset_right = 360
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(top)
	obj_title = Label.new(); obj_title.add_theme_font_override("font", font_bo); obj_title.add_theme_font_size_override("font_size", 22)
	obj_title.add_theme_color_override("font_color", Color(1.0, 0.62, 0.15)); obj_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; obj_title.text = "OBJETIVO"; top.add_child(obj_title)
	obj_text = Label.new(); obj_text.add_theme_font_override("font", font_ui); obj_text.add_theme_font_size_override("font_size", 30)
	obj_text.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88)); obj_text.add_theme_color_override("font_outline_color", Color(0, 0, 0)); obj_text.add_theme_constant_override("outline_size", 6)
	obj_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; top.add_child(obj_text)
	bar = ProgressBar.new(); bar.custom_minimum_size = Vector2(420, 14); bar.show_percentage = false; bar.visible = false
	var fill = StyleBoxFlat.new(); fill.bg_color = Color(1.0, 0.55, 0.12); fill.set_corner_radius_all(4)
	var bg = StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.55); bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill); bar.add_theme_stylebox_override("background", bg)
	var bc = CenterContainer.new(); bc.add_child(bar); top.add_child(bc)
	# radio abajo en el centro
	# subtítulos de la radio: discretos, abajo en el centro, nombre en color (como en los Black Ops)
	radio_box = PanelContainer.new(); radio_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	radio_box.offset_left = -440; radio_box.offset_right = 440; radio_box.offset_top = -150; radio_box.offset_bottom = -112
	radio_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0.42); sb.set_corner_radius_all(4)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 3; sb.content_margin_bottom = 4
	radio_box.add_theme_stylebox_override("panel", sb); radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; radio_box.visible = false; add_child(radio_box)
	radio_txt = RichTextLabel.new(); radio_txt.bbcode_enabled = true; radio_txt.fit_content = true; radio_txt.scroll_active = false
	radio_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; radio_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_txt.add_theme_font_override("normal_font", font_ui); radio_txt.add_theme_font_override("bold_font", font_bo)
	radio_txt.add_theme_font_size_override("normal_font_size", 21); radio_txt.add_theme_font_size_override("bold_font_size", 17)
	radio_txt.add_theme_color_override("default_color", Color(0.96, 0.94, 0.9)); radio_txt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	radio_txt.add_theme_constant_override("outline_size", 4); radio_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_box.add_child(radio_txt)
	# marcador del objetivo (rombo con distancia; si está fuera de la pantalla, en el borde)
	marker = _Marker.new(); marker.mission = self; marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); marker.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(marker)
	# columna de luz en el objetivo (se ve de lejos)
	beacon = MeshInstance3D.new(); var cm = CylinderMesh.new(); cm.top_radius = 0.25; cm.bottom_radius = 0.45; cm.height = 30; cm.radial_segments = 12; cm.rings = 1; cm.cap_top = false; cm.cap_bottom = false
	beacon.mesh = cm
	var bm = StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.albedo_color = Color(1.0, 0.6, 0.15, 0.22); bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; bm.cull_mode = BaseMaterial3D.CULL_DISABLED; beacon.material_override = bm; beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.visible = false; game.add_child(beacon)
	# cartel de título al empezar (se desvanece)
	var card = VBoxContainer.new(); card.set_anchors_and_offsets_preset(Control.PRESET_CENTER); card.offset_left = -600; card.offset_right = 600; card.offset_top = -110; card.offset_bottom = 60
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(card)
	var c1 = Label.new(); c1.text = "OPERACIÓN GAMBA ROJA  ·  MISIÓN %d" % (Campaign.index_of(data.id) + 1); c1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c1.add_theme_font_override("font", font_bo); c1.add_theme_font_size_override("font_size", 26); c1.add_theme_color_override("font_color", Color(1.0, 0.62, 0.15)); card.add_child(c1)
	var c2 = Label.new(); c2.text = String(data.name).to_upper(); c2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c2.add_theme_font_override("font", font_bo); c2.add_theme_font_size_override("font_size", 84); c2.add_theme_color_override("font_color", Color(0.86, 0.12, 0.1))
	c2.add_theme_color_override("font_outline_color", Color(0, 0, 0)); c2.add_theme_constant_override("outline_size", 10); card.add_child(c2)
	var tw = card.create_tween(); tw.tween_interval(3.2); tw.tween_property(card, "modulate:a", 0.0, 1.2); tw.tween_callback(card.queue_free)
	radio_voice = AudioStreamPlayer.new(); radio_voice.bus = "Master"; add_child(radio_voice)
	var f = FileAccess.open("res://assets/voice/radio/index.json", FileAccess.READ)
	if f: radio_index = JSON.parse_string(f.get_as_text())
	# documentos escondidos (cuentan la historia de Gamba Roja)
	var docs: Array = data.get("intel", [])
	for k in docs.size():
		if GS.intel.has("%s_%d" % [data.id, k]): continue
		var it = _spawn_doc(_snap(_xz(docs[k].pos))); it.set_meta("doc", k); intel_items.append(it)
	doc_panel = PanelContainer.new(); doc_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT); doc_panel.offset_left = 40; doc_panel.offset_right = 560
	doc_panel.offset_top = -90; doc_panel.offset_bottom = -80; doc_panel.grow_vertical = Control.GROW_DIRECTION_BOTH; doc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; doc_panel.visible = false
	var ds = StyleBoxFlat.new(); ds.bg_color = Color(0.9, 0.86, 0.74, 0.94); ds.set_corner_radius_all(3); ds.content_margin_left = 22; ds.content_margin_right = 22; ds.content_margin_top = 16; ds.content_margin_bottom = 18
	doc_panel.add_theme_stylebox_override("panel", ds); add_child(doc_panel)
	var dv = VBoxContainer.new(); dv.name = "V"; doc_panel.add_child(dv)
	var dt = Label.new(); dt.name = "T"; dt.add_theme_font_override("font", font_bo); dt.add_theme_font_size_override("font_size", 22); dt.add_theme_color_override("font_color", Color(0.45, 0.08, 0.06)); dv.add_child(dt)
	var dx = Label.new(); dx.name = "X"; dx.add_theme_font_override("font", font_ui); dx.add_theme_font_size_override("font_size", 22); dx.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	dx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; dx.custom_minimum_size.x = 470; dv.add_child(dx)
	# reintentar desde un punto de control: lo de antes ya está hecho
	var steps: Array = data.steps
	if GS.checkpoint > 0 and GS.checkpoint < steps.size():
		var cp: int = GS.checkpoint
		for i in cp:
			var st: Dictionary = steps[i]
			match st.type:
				"door": game.evt("door", int(st.door))
				"power": game.turn_power_on()
				"collect": if st.has("give"): game.player.give_weapon(String(st.give))
		game.player.points += 750 * cp; game.hud.update_points(game.player.points, 0)
		var back: Dictionary = steps[cp - 1]
		var at = Vector3.INF
		if back.has("pos"): at = _xz(back.pos[0] if back.pos[0] is Array else back.pos)
		elif back.type == "door": at = game.doors[int(back.door)].global_position
		if at != Vector3.INF:   # (cuando la navegación ya está lista)
			get_tree().create_timer(0.5).timeout.connect(func():
				var q = game._random_nav_near(at, 1.0, 4.0)
				if q != Vector3.INF: game.player.global_position = q + Vector3(0, 0.2, 0); game.player.velocity = Vector3.ZERO)
		step_i = cp - 1; last_cp = cp
		game.hud.toast("PUNTO DE CONTROL", "Sigues desde: " + String(steps[cp].get("text", "")))
	else:
		radio(data.get("intro", []))
	_next_step()

## dificultad: cuántos zombis a la vez y cada cuánto sale uno (los pasos tranquilos, menos)
func cap() -> int:
	var c = int(data.get("cap", 10))
	if step.get("calm", false): c = max(3, c / 3)
	if step.get("type", "") == "defend": c = int(c * 1.4)
	return c
func rate() -> float:
	var r = float(data.get("rate", 2.0))
	if step.get("type", "") == "defend": r *= 0.6
	if step.get("calm", false): r *= 2.0
	return r * randf_range(0.7, 1.2)
func spawning() -> bool: return not done and step_i >= 0

# ------------------------------------------------------------------ pasos
func _next_step() -> void:
	for it in items:
		if is_instance_valid(it): it.queue_free()
	items.clear(); picked = 0; t = 0.0; progress = 0.0; brute_sent = false
	step_i += 1
	var steps: Array = data.steps
	if step_i >= steps.size(): _finish(true); return
	step = steps[step_i]
	if step_i > 0 and step.type in ["door", "power", "defend", "boss", "plant", "destroy", "survive", "escort"]: last_cp = step_i
	radio(step.get("radio", []))
	bar.visible = step.type in ["survive", "defend", "boss", "escort"]
	obj_title.text = "OBJETIVO"; obj_title.add_theme_color_override("font_color", Color(1.0, 0.62, 0.15))
	target = Vector3.INF
	match step.type:
		"collect":
			for p in step.pos: items.append(_spawn_item(_snap(_xz(p))))
		"destroy":
			for p in step.pos: items.append(_spawn_target(_snap(_xz(p)), float(step.get("hp", 1500.0))))
		"plant":
			for p in step.pos: items.append(_spawn_charge(_snap(_xz(p))))
		"boss":
			_spawn_boss()
		"escort":
			npc = _Survivor.new(); npc.mission = self; npc.who = String(step.get("name", "GUARDIA")); game.add_child(npc)
			npc.global_position = _snap(_xz(step.pos)) + Vector3(0, 0.1, 0)
		"door":
			var d = game.doors[int(step.door)]
			target = d.global_position
		"goto", "defend":
			target = _snap(_xz(step.pos))
		"power":
			for n in game.interactables:
				if n is Interactables.Power: target = n.global_position; break
	if step.type == "defend" and beacon:
		beacon.global_position = target + Vector3(0, 15, 0)
	Sfx.play("powerup", 0.4, 1.3)
	_update_text()

func _process(delta: float) -> void:
	if done or not game or not game.player: return
	if game.paused: return
	_radio_tick(delta)
	var p: Player = game.player
	# documentos
	for it in intel_items:
		if is_instance_valid(it) and it.visible and p.global_position.distance_to(it.global_position) < 1.5:
			it.visible = false; it.queue_free()
			var k: int = it.get_meta("doc"); var doc: Dictionary = data.intel[k]
			GS.intel["%s_%d" % [data.id, k]] = true; GS.save_game()
			Sfx.play("powerup", 0.6, 0.8)
			doc_panel.get_node("V/T").text = "DOCUMENTO: " + String(doc.title).to_upper()
			doc_panel.get_node("V/X").text = String(doc.text)
			doc_panel.visible = true; doc_t = 9.0
	if doc_t > 0.0:
		doc_t -= delta
		if doc_t <= 0.0: doc_panel.visible = false
	if p.downed and not _was_down: downs += 1
	_was_down = p.downed
	t += delta
	var pos = p.global_position
	match step.get("type", ""):
		"collect":
			for it in items:
				if is_instance_valid(it) and it.visible and pos.distance_to(it.global_position) < 1.6:
					it.visible = false; picked += 1
					Sfx.play("powerup", 0.7)
					if step.has("give"): p.give_weapon(String(step.give))
					game.hud.toast("CONSEGUIDO", "%s (%d/%d)" % [String(step.get("label", "objeto")).capitalize(), picked, items.size()])
					_update_text()
			if picked >= items.size(): _next_step(); return
			target = Vector3.INF; var best = INF
			for it in items:
				if is_instance_valid(it) and it.visible and pos.distance_to(it.global_position) < best: best = pos.distance_to(it.global_position); target = it.global_position
		"door":
			var d = game.doors[int(step.door)]
			if d.open: _next_step(); return
			if pos.distance_to(d.global_position) < 3.2:
				game.evt("door", int(step.door)); Sfx.play("z_hit1", 0.8, 0.6)
		"goto":
			if Vector2(pos.x - target.x, pos.z - target.z).length() < float(step.get("r", 3.0)): _next_step(); return
		"survive":
			bar.max_value = float(step.time); bar.value = t; _update_text()
			if t >= float(step.time): _next_step(); return
		"defend":
			var inside = Vector2(pos.x - target.x, pos.z - target.z).length() < float(step.get("r", 7.0))
			if inside: progress += delta
			bar.max_value = float(step.time); bar.value = progress
			obj_title.text = "OBJETIVO" if inside else "¡VUELVE A LA ZONA!"
			obj_title.add_theme_color_override("font_color", Color(1.0, 0.62, 0.15) if inside else Color(1.0, 0.2, 0.15))
			if step.get("brute", false) and not brute_sent and progress > float(step.time) * 0.6:
				brute_sent = true; game.brutes_left = 1
				radio([["CONTROL", "¡Algo grande se acerca a tu posición!"]])
			_update_text()
			if progress >= float(step.time):
				if beacon: beacon.visible = false
				_next_step(); return
		"power":
			if game.power_on: _next_step(); return
		"destroy":
			if picked >= items.size(): _next_step(); return
			target = _nearest_item(pos)
		"plant":
			var cur: Node3D = null
			for it in items:
				if is_instance_valid(it) and not it.get_meta("armed", false) and Vector2(pos.x - it.global_position.x, pos.z - it.global_position.z).length() < 1.8 and abs(pos.y - it.global_position.y) < 1.5: cur = it; break
			bar.visible = cur != null
			if cur:
				plant_t += delta; bar.max_value = float(step.get("time", 3.0)); bar.value = plant_t
				obj_title.text = "COLOCANDO CARGA…"
				if plant_t >= float(step.get("time", 3.0)):
					cur.set_meta("armed", true); picked += 1; plant_t = 0.0
					cur.get_node("Light").light_color = Color(1.0, 0.1, 0.05); cur.get_node("Mesh").material_override.emission = Color(1.0, 0.1, 0.05)
					Sfx.play("hitmark", 0.8, 0.5)
					game.hud.toast("CARGA COLOCADA", "%d/%d" % [picked, items.size()])
					_update_text()
			else:
				plant_t = 0.0; obj_title.text = "OBJETIVO"
			if picked >= items.size():
				var spots = items.map(func(it): return it.global_position)
				for it in items: it.set_meta("keep", true)
				var kept = items.duplicate(); items.clear()
				get_tree().create_timer(float(step.get("fuse", 4.0))).timeout.connect(func(): _detonate(spots, kept))
				radio([["COMANDO", "Cargas listas. ¡Aléjate!"]] if not step.has("radio_done") else step.radio_done)
				_next_step(); return
			target = Vector3.INF; var bd = INF
			for it in items:
				if is_instance_valid(it) and not it.get_meta("armed", false) and pos.distance_to(it.global_position) < bd: bd = pos.distance_to(it.global_position); target = it.global_position
		"escort":
			if npc == null or not is_instance_valid(npc): return
			bar.max_value = npc.MAX_HP; bar.value = npc.hp
			if OS.get_cmdline_user_args().has("verbose") and Engine.get_process_frames() % 120 == 0: print("NPC ", npc.global_position.snapped(Vector3.ONE * 0.1), " sigue ", npc.following, " vida ", int(npc.hp), " siguiente ", (npc.path[npc.path_i] if npc.path_i < npc.path.size() else Vector3.ZERO).snapped(Vector3.ONE * 0.1), " jugador ", pos.snapped(Vector3.ONE * 0.1))
			if npc.hp <= 0.0:
				radio([["CONTROL", "Hemos perdido al superviviente…"]]); _finish(false); return
			var goal = _snap(_xz(step.to))
			if not npc.following:
				target = npc.global_position
				obj_title.text = "OBJETIVO"
				if pos.distance_to(npc.global_position) < 2.2:
					npc.following = true; Sfx.play("powerup", 0.5, 1.1)
					game.hud.toast("SUPERVIVIENTE", "Te sigue. ¡Que no lo maten!")
					radio(step.get("radio_follow", []))
			else:
				target = goal
			if npc.global_position.distance_to(goal) < float(step.get("r", 2.5)):
				npc.following = false; npc.done = true; npc = null
				game.hud.toast("A SALVO", String(step.get("label", "El superviviente")) + " está a salvo")
				_next_step(); return
		"boss":
			if boss == null or not is_instance_valid(boss) or boss.dead:
				boss = null; _next_step(); return
			bar.max_value = boss_max; bar.value = max(0.0, boss.hp)
			target = boss.global_position
	if beacon and step.get("type", "") != "defend":
		beacon.visible = target != Vector3.INF and not (step.get("type", "") == "escort" and npc and not npc.following)
		if beacon.visible: beacon.global_position = target + Vector3(0, 15, 0)
	elif beacon: beacon.visible = true
var _was_down = false

func _update_text() -> void:
	var txt: String = step.get("text", "")
	match step.get("type", ""):
		"collect":
			if items.size() > 1: txt += "  (%d/%d)" % [picked, items.size()]
		"survive": txt += "  %d s" % max(0, int(ceil(float(step.time) - t)))
		"defend": txt += "  %d %%" % int(progress / float(step.time) * 100.0)
		"destroy", "plant":
			if items.size() > 1: txt += "  (%d/%d)" % [picked, items.size()]
	obj_text.text = txt

## [x, z] o [x, z, altura] (objetos en pisos de arriba)
func _xz(p: Array) -> Vector3: return Vector3(float(p[0]), float(p[2]) if p.size() > 2 else 0.0, float(p[1]))

## punto de la navegación más cercano (para no dejar objetos dentro de paredes)
func _snap(p: Vector3) -> Vector3:
	var map = game.get_world_3d().navigation_map
	var q = NavigationServer3D.map_get_closest_point(map, p + Vector3(0, 1.0, 0))
	return q if q != Vector3.ZERO and q.distance_to(p) < 6.0 else p

func _spawn_item(at: Vector3) -> Node3D:
	var n = Node3D.new(); game.add_child(n); n.global_position = at
	var m = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(0.35, 0.3, 0.35); m.mesh = bm; m.position.y = 0.6
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(1.0, 0.7, 0.25); mat.metallic = 0.6; mat.roughness = 0.3; mat.emission_enabled = true; mat.emission = Color(1.0, 0.55, 0.1); mat.emission_energy_multiplier = 1.5
	m.material_override = mat; n.add_child(m)
	var l = OmniLight3D.new(); l.light_color = Color(1.0, 0.6, 0.2); l.light_energy = 1.4; l.omni_range = 3.5; l.position.y = 0.9; n.add_child(l)
	var tw = m.create_tween().set_loops(); tw.tween_property(m, "rotation:y", TAU, 2.5).from(0.0)
	return n

func _nearest_item(pos: Vector3) -> Vector3:
	var best = INF; var out = Vector3.INF
	for it in items:
		if is_instance_valid(it) and it.visible and pos.distance_to(it.global_position) < best: best = pos.distance_to(it.global_position); out = it.global_position
	return out

## depósito de cultivo (paso «destroy»): un tanque de cristal con líquido rojo que hay que reventar a tiros o con explosiones
func _spawn_target(at: Vector3, hp: float) -> Node3D:
	var n = StaticBody3D.new(); n.collision_layer = MapBuilder.LAYER_WORLD; n.collision_mask = 0
	n.set_meta("mission_target", true); n.set_meta("hp", hp); n.set_meta("max_hp", hp)
	game.add_child(n); n.global_position = at
	var cs = CollisionShape3D.new(); var cy = CylinderShape3D.new(); cy.radius = 0.75; cy.height = 2.6; cs.shape = cy; cs.position.y = 1.3; n.add_child(cs)
	var metal = StandardMaterial3D.new(); metal.albedo_color = Color(0.32, 0.3, 0.28); metal.metallic = 0.8; metal.roughness = 0.45
	for y in [0.15, 2.5]:
		var ring = MeshInstance3D.new(); var rm = CylinderMesh.new(); rm.top_radius = 0.8; rm.bottom_radius = 0.8; rm.height = 0.3; rm.radial_segments = 16; ring.mesh = rm
		ring.position.y = y; ring.material_override = metal; n.add_child(ring)
	var liq = MeshInstance3D.new(); liq.name = "Mesh"; var lm = CylinderMesh.new(); lm.top_radius = 0.66; lm.bottom_radius = 0.66; lm.height = 2.1; lm.radial_segments = 16; liq.mesh = lm; liq.position.y = 1.32
	var lmat = StandardMaterial3D.new(); lmat.albedo_color = Color(0.85, 0.12, 0.18, 0.75); lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lmat.emission_enabled = true; lmat.emission = Color(1.0, 0.2, 0.25); lmat.emission_energy_multiplier = 1.2; lmat.roughness = 0.1
	liq.material_override = lmat; n.add_child(liq)
	# una gamba gigante flotando dentro
	var g = MeshInstance3D.new(); var cap = CapsuleMesh.new(); cap.radius = 0.22; cap.height = 1.1; cap.radial_segments = 10; cap.rings = 4; g.mesh = cap
	g.position = Vector3(0, 1.3, 0); g.rotation_degrees = Vector3(0, 0, 70)
	var gm = StandardMaterial3D.new(); gm.albedo_color = Color(1.0, 0.45, 0.3); gm.emission_enabled = true; gm.emission = Color(0.6, 0.15, 0.1); g.material_override = gm; n.add_child(g)
	var tw = g.create_tween().set_loops(); tw.tween_property(g, "position:y", 1.5, 1.6).set_trans(Tween.TRANS_SINE); tw.tween_property(g, "position:y", 1.1, 1.6).set_trans(Tween.TRANS_SINE)
	var l = OmniLight3D.new(); l.light_color = Color(1.0, 0.25, 0.3); l.light_energy = 1.6; l.omni_range = 5.0; l.position.y = 1.6; n.add_child(l)
	return n

## un tiro o una explosión le quita vida a un depósito
func hit_target(col: Node, dmg: float) -> void:
	if done or not is_instance_valid(col) or not col.visible: return
	var hp = float(col.get_meta("hp")) - dmg
	col.set_meta("hp", hp)
	var lm: StandardMaterial3D = col.get_node("Mesh").material_override
	lm.emission_energy_multiplier = 4.0
	col.create_tween().tween_property(lm, "emission_energy_multiplier", 1.2, 0.25)
	game.hud.hitmarker(hp <= 0.0, false)
	if hp <= 0.0:
		col.visible = false; col.collision_layer = 0; picked += 1
		Fx.explosion(game, col.global_position + Vector3(0, 1.2, 0))
		Sfx.play_at("explosion", col.global_position, 1.0, 0.8)
		game.explode(col.global_position + Vector3(0, 1.0, 0), 4.0, 5000.0, null, "explo", "")
		game.hud.toast("DEPÓSITO DESTRUIDO", "%d/%d" % [picked, items.size()])
		_update_text()

func explosion(at: Vector3, radius: float, dmg: float) -> void:
	if step.get("type", "") != "destroy": return
	for it in items.duplicate():
		if is_instance_valid(it) and it.visible and it.global_position.distance_to(at) < radius + 0.8: hit_target(it, dmg)

## carga explosiva (paso «plant»): luz naranja; se pone roja al colocarla
func _spawn_charge(at: Vector3) -> Node3D:
	var n = Node3D.new(); game.add_child(n); n.global_position = at
	var m = MeshInstance3D.new(); m.name = "Mesh"; var bm = BoxMesh.new(); bm.size = Vector3(0.45, 0.3, 0.3); m.mesh = bm; m.position.y = 0.2
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.2, 0.22, 0.18); mat.emission_enabled = true; mat.emission = Color(1.0, 0.55, 0.1); mat.emission_energy_multiplier = 0.8
	m.material_override = mat; n.add_child(m)
	var l = OmniLight3D.new(); l.name = "Light"; l.light_color = Color(1.0, 0.6, 0.2); l.light_energy = 1.4; l.omni_range = 3.0; l.position.y = 0.7; n.add_child(l)
	var tw = l.create_tween().set_loops(); tw.tween_property(l, "light_energy", 0.3, 0.4); tw.tween_property(l, "light_energy", 1.6, 0.4)
	return n

func _detonate(spots: Array, nodes: Array) -> void:
	for i in spots.size():
		get_tree().create_timer(i * 0.35).timeout.connect(func():
			game.explode(spots[i] + Vector3(0, 0.6, 0), 6.0, 1e6, null, "explo", "")
			Fx.fire_puff(game, spots[i])
			if i < nodes.size() and is_instance_valid(nodes[i]): nodes[i].queue_free())

## jefe: un Bruto enorme y rojizo con barra de vida
func _spawn_boss() -> void:
	var at = _snap(_xz(step.pos)) if step.has("pos") else game._random_nav_near(game.player.global_position, 10.0, 16.0)
	var hp = game.round_hp(max(game.round_n, 10)) * float(step.get("hp", 3.0))
	boss = game.make_zombie("a", "brute", at, hp, 1.0)
	boss_max = boss.max_hp
	boss.model.scale *= float(step.get("scale", 1.35))
	var over = StandardMaterial3D.new(); over.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; over.albedo_color = Color(1.0, 0.15, 0.05, 0.22)
	over.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; over.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for mi in boss.model.find_children("*", "MeshInstance3D", true, false): mi.material_overlay = over
	obj_title.text = String(step.get("name", "JEFE")).to_upper()
	if step.get("ammo", false):   # munición para el combate
		game._drop_powerup(game.player.global_position + game.player.global_transform.basis.z * -2.0, "max_ammo")

## documento escondido: un papel amarillento que brilla un poco (para que se vea en la oscuridad)
func _spawn_doc(at: Vector3) -> Node3D:
	var n = Node3D.new(); game.add_child(n); n.global_position = at
	var m = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(0.3, 0.02, 0.4); m.mesh = bm; m.position.y = 0.05; m.rotation.y = randf() * TAU
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.92, 0.88, 0.72); mat.emission_enabled = true; mat.emission = Color(0.9, 0.8, 0.5); mat.emission_energy_multiplier = 0.6
	m.material_override = mat; n.add_child(m)
	var l = OmniLight3D.new(); l.light_color = Color(1.0, 0.9, 0.6); l.light_energy = 0.7; l.omni_range = 2.2; l.position.y = 0.5; n.add_child(l)
	var tw = l.create_tween().set_loops(); tw.tween_property(l, "light_energy", 0.2, 1.2); tw.tween_property(l, "light_energy", 0.8, 1.2)
	return n

# ------------------------------------------------------------------ radio
func radio(lines: Array) -> void:
	for l in lines: radio_queue.append(l)

func _radio_tick(delta: float) -> void:
	radio_t -= delta
	if radio_t > 0.0: return
	if radio_queue.is_empty(): radio_box.visible = false; return
	var l: Array = radio_queue.pop_front()
	var col = "#73d9ff" if l[0] == "COMANDO" else ("#9fe07a" if l[0] == "PILOTO" else "#ff9e26")
	radio_txt.text = "[b][color=%s]%s:[/color][/b]  %s" % [col, String(l[0]), String(l[1])]
	radio_box.visible = true
	radio_t = clamp(String(l[1]).length() * 0.065, 2.8, 7.0)
	var id = radio_index.get(String(l[1]), "") if radio_index is Dictionary else ""
	var path = "res://assets/voice/radio/%s.ogg" % id
	if id != "" and ResourceLoader.exists(path):
		radio_voice.stream = load(path); radio_voice.volume_db = linear_to_db(max(0.001, float(GS.settings.get("voice", 1.0)))) + 3.0; radio_voice.play()
		radio_t = max(radio_t * 0.6, radio_voice.stream.get_length() + 0.5)
	else:
		Sfx.play("hitmark", 0.25, 0.6)   # chasquido de radio

# ------------------------------------------------------------------ final
func _finish(ok: bool) -> void:
	if done: return
	done = true
	if beacon: beacon.visible = false
	finished.emit(ok)

## estrellas: completarla, sin caer ni una vez, y en menos del tiempo objetivo
func stars() -> int:
	var s = 1
	if downs == 0: s += 1
	if game.time <= float(data.get("par_time", 600)): s += 1
	return s

# ------------------------------------------------------------------ superviviente que te sigue (paso «escort»)
class _Survivor extends CharacterBody3D:
	const MAX_HP := 600.0
	var mission
	var hp = MAX_HP
	var following = false
	var done = false
	var model: CharacterModel
	var agent: NavigationAgent3D
	var shoot_t = 0.0
	var hurt_t = 0.0
	var stuck_t = 0.0
	var path = PackedVector3Array()
	var path_i = 0
	var repath_t = 0.0
	var who = "GUARDIA"
	var label: Label3D
	func _ready() -> void:
		collision_layer = 0; collision_mask = 0
		model = CharacterModel.new(); add_child(model); model.setup("comando"); model.set_weapon("m1911")
		agent = NavigationAgent3D.new(); agent.radius = 0.32; agent.path_desired_distance = 0.6; agent.target_desired_distance = 1.0; add_child(agent)
		label = Label3D.new(); label.text = "GUARDIA"; label.font = load("res://assets/fonts/BlackOpsOne.ttf"); label.font_size = 44; label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true; label.modulate = Color(0.55, 1.0, 0.6); label.outline_size = 8; label.position.y = 2.15; add_child(label)
	func _physics_process(d: float) -> void:
		if mission == null or mission.done: return
		var game = mission.game
		if done or game.paused: model.update(d, 0.0, false, false, false, 0.0); return
		var p = game.player
		var v = Vector3.ZERO
		if following and global_position.distance_to(p.global_position) > 2.6:
			repath_t -= d
			if repath_t <= 0.0 or path_i >= path.size():
				repath_t = 1.0; path_i = 1
				path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, p.global_position, true)
			while path_i < path.size() and Vector2(path[path_i].x - global_position.x, path[path_i].z - global_position.z).length() < 0.35: path_i += 1
			if path_i < path.size():
				v = (path[path_i] - global_position); v.y = 0
				v = v.normalized() * (4.6 if global_position.distance_to(p.global_position) > 7.0 else 3.2)
		# sigue el camino de la navegación (que ya esquiva los obstáculos) sin chocar con los muebles: así no se atasca nunca
		velocity = v
		if v.length() > 0.0:
			global_position += v * d
			var map = get_world_3d().navigation_map
			var q = NavigationServer3D.map_get_closest_point(map, global_position + Vector3(0, 0.5, 0))
			if q.distance_to(global_position) < 1.5: global_position = global_position.lerp(Vector3(global_position.x, q.y, global_position.z), min(1.0, d * 12.0))
		# dispara a los zombis cercanos que vea (ayuda, pero no lo hace todo él)
		shoot_t -= d
		var near_z = null; var nd = 11.0
		for z in game.zombies:
			if not is_instance_valid(z) or z.dead: continue
			var dz = global_position.distance_to(z.global_position)
			if dz < 1.4: hp -= 30.0 * d; hurt_t = 0.2   # le están mordiendo
			if dz < nd and z.state == "chase": nd = dz; near_z = z
		if near_z and shoot_t <= 0.0:
			var eye = global_position + Vector3(0, 1.5, 0)
			if game.ray_world(eye, (near_z.global_position + Vector3(0, 1.3, 0) - eye).normalized(), nd) == Vector3.INF:
				shoot_t = 0.9
				near_z.take_hit(55.0, near_z.global_position + Vector3(0, 1.3, 0), false, 0, "bullet", "m1911")
				Sfx.play_at("shot_pistol", eye, 0.7, 1.05); model.fired()
		var look = (near_z.global_position if near_z and shoot_t > 0.5 else (p.global_position if following else global_position + -global_transform.basis.z))
		var dir = look - global_position; dir.y = 0
		if dir.length() > 0.1: rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), min(1.0, d * 8.0))
		model.update(d, Vector2(velocity.x, velocity.z).length(), not following and not done, false, false, 0.0)
		hurt_t -= d
		label.modulate = Color(1, 0.3, 0.3) if hurt_t > 0.0 else Color(0.55, 1.0, 0.6)
		label.text = who if following else who + " (acércate)"

# ------------------------------------------------------------------ marcador en pantalla
class _Marker extends Control:
	var mission
	func _process(_d: float) -> void: queue_redraw()
	func _draw() -> void:
		if mission == null or mission.done or mission.target == Vector3.INF: return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null: return
		var wp: Vector3 = mission.target + Vector3(0, 1.4, 0)
		if cam.global_position.distance_to(wp) < 0.6: return
		var behind = cam.is_position_behind(wp)
		var sp: Vector2 = cam.unproject_position(wp)
		var r = get_viewport_rect().size
		var c = r / 2.0
		if behind: sp = c + (c - sp) * 1000.0
		var m = 60.0
		var clamped = sp.x < m or sp.y < m or sp.x > r.x - m or sp.y > r.y - m or behind
		if clamped:
			var d = (sp - c).normalized()
			var k = min(abs((c.x - m) / max(0.001, abs(d.x))), abs((c.y - m) / max(0.001, abs(d.y))))
			sp = c + d * k
		var col = Color(1.0, 0.6, 0.15)
		var pts = PackedVector2Array([sp + Vector2(0, -14), sp + Vector2(11, 0), sp + Vector2(0, 14), sp + Vector2(-11, 0)])
		draw_colored_polygon(pts, Color(0, 0, 0, 0.5)); draw_polyline(pts + PackedVector2Array([pts[0]]), col, 3.0, true)
		draw_circle(sp, 4.0, col)
		var dist = int(cam.global_position.distance_to(mission.target))
		var f = ThemeDB.fallback_font
		draw_string(f, sp + Vector2(-40, 34), "%d m" % dist, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color(1, 1, 1))
