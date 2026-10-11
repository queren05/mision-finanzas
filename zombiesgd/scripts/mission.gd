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

# interfaz
var obj_title: Label
var obj_text: Label
var radio_box: PanelContainer
var radio_who: Label
var radio_txt: Label
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
	radio_box = PanelContainer.new(); radio_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	radio_box.offset_left = -430; radio_box.offset_right = 430; radio_box.offset_top = -190; radio_box.offset_bottom = -110
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.03, 0.03, 0.04, 0.78); sb.border_color = Color(1.0, 0.55, 0.12, 0.8); sb.border_width_left = 4; sb.set_corner_radius_all(6)
	sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	radio_box.add_theme_stylebox_override("panel", sb); radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; radio_box.visible = false; add_child(radio_box)
	var rv = VBoxContainer.new(); radio_box.add_child(rv)
	radio_who = Label.new(); radio_who.add_theme_font_override("font", font_bo); radio_who.add_theme_font_size_override("font_size", 20); radio_who.add_theme_color_override("font_color", Color(1.0, 0.62, 0.15)); rv.add_child(radio_who)
	radio_txt = Label.new(); radio_txt.add_theme_font_override("font", font_ui); radio_txt.add_theme_font_size_override("font_size", 26); radio_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_txt.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9)); rv.add_child(radio_txt)
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
	radio(step.get("radio", []))
	bar.visible = step.type in ["survive", "defend"]
	target = Vector3.INF
	match step.type:
		"collect":
			for p in step.pos: items.append(_spawn_item(_snap(Vector3(p[0], 0, p[1]))))
		"door":
			var d = game.doors[int(step.door)]
			target = d.global_position
		"goto", "defend":
			target = _snap(Vector3(step.pos[0], 0, step.pos[1]))
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
	if beacon and step.get("type", "") != "defend":
		beacon.visible = target != Vector3.INF
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
	obj_text.text = txt

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

# ------------------------------------------------------------------ radio
func radio(lines: Array) -> void:
	for l in lines: radio_queue.append(l)

func _radio_tick(delta: float) -> void:
	radio_t -= delta
	if radio_t > 0.0: return
	if radio_queue.is_empty(): radio_box.visible = false; return
	var l: Array = radio_queue.pop_front()
	radio_who.text = String(l[0]); radio_txt.text = String(l[1])
	radio_who.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0) if l[0] == "COMANDO" else Color(1.0, 0.62, 0.15))
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

# ------------------------------------------------------------------ marcador en pantalla
class _Marker extends Control:
	var mission
	func _process(_d: float) -> void: queue_redraw()
	func _draw() -> void:
		if mission == null or mission.done or mission.target == Vector3.INF: return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null: return
		var wp: Vector3 = mission.target + Vector3(0, 1.4, 0)
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
