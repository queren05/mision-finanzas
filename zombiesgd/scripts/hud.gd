extends CanvasLayer
## Interfaz de la partida (estilo Black Ops) y controles táctiles.

var game: Node
var font_bo: Font
var font_ui: Font
var root: Control
var round_ctl: Control
var round_n = 0
var round_flash = 0.0
var points_lbl: Label
var pts_pop: VBoxContainer
var ammo_lbl: Label
var wname_lbl: Label
var nades_lbl: Label
var perks_box: HBoxContainer
var prompt_lbl: Label
var banner_lbl: Label
var banner_sub: Label
var banner_t = 0.0
var hit_ctl: Control
var hit_t = 0.0
var hit_kill = false
var hit_head = false
var hurt_rect: ColorRect
var hurt_t = 0.0
var white_rect: ColorRect
var scope_rect: Control
var timers_lbl: Label
var pause_panel: Control
var over_panel: Control
var touch_layer: Control
var cross: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_bo = load("res://assets/fonts/BlackOpsOne.ttf"); font_ui = load("res://assets/fonts/Oswald.ttf")
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	hurt_rect = ColorRect.new(); hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT); hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh = Shader.new(); sh.code = "shader_type canvas_item; uniform float a = 0.0; void fragment(){ vec2 d = UV - 0.5; float v = smoothstep(0.25, 0.75, length(d * vec2(1.6, 1.0))); COLOR = vec4(0.45, 0.0, 0.0, v * a); }"
	var sm = ShaderMaterial.new(); sm.shader = sh; hurt_rect.material = sm; root.add_child(hurt_rect)
	white_rect = ColorRect.new(); white_rect.set_anchors_preset(Control.PRESET_FULL_RECT); white_rect.color = Color(1, 1, 1, 0); white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(white_rect)
	scope_rect = _ScopeDraw.new(); scope_rect.set_anchors_preset(Control.PRESET_FULL_RECT); scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; scope_rect.visible = false; root.add_child(scope_rect)
	cross = _Cross.new(); cross.set_anchors_preset(Control.PRESET_CENTER); cross.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(cross)
	hit_ctl = _Hit.new(); hit_ctl.hud = self; hit_ctl.set_anchors_preset(Control.PRESET_CENTER); hit_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hit_ctl)
	# ronda (abajo a la izquierda, roja, palotes hasta la 5)
	round_ctl = _Round.new(); round_ctl.hud = self; round_ctl.position = Vector2(34, 560); round_ctl.size = Vector2(260, 130); round_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_ctl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); round_ctl.offset_left = 34; round_ctl.offset_top = -170; round_ctl.offset_right = 300; round_ctl.offset_bottom = -30; root.add_child(round_ctl)
	points_lbl = _label(font_bo, 34, Color(1, 1, 1)); points_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); points_lbl.offset_left = 36; points_lbl.offset_top = -220; points_lbl.offset_right = 300; points_lbl.offset_bottom = -176; root.add_child(points_lbl)
	pts_pop = VBoxContainer.new(); pts_pop.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); pts_pop.offset_left = 190; pts_pop.offset_top = -300; pts_pop.offset_right = 330; pts_pop.offset_bottom = -180; pts_pop.alignment = BoxContainer.ALIGNMENT_END; pts_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(pts_pop)
	perks_box = HBoxContainer.new(); perks_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); perks_box.offset_left = 36; perks_box.offset_top = -268; perks_box.offset_right = 400; perks_box.offset_bottom = -228; perks_box.add_theme_constant_override("separation", 6); root.add_child(perks_box)
	ammo_lbl = _label(font_bo, 40, Color(1, 1, 1)); ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT); ammo_lbl.offset_left = -360; ammo_lbl.offset_top = 52; ammo_lbl.offset_right = -36; ammo_lbl.offset_bottom = 104; root.add_child(ammo_lbl)
	wname_lbl = _label(font_ui, 20, Color(0.85, 0.82, 0.75)); wname_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wname_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT); wname_lbl.offset_left = -460; wname_lbl.offset_top = 24; wname_lbl.offset_right = -36; wname_lbl.offset_bottom = 52; root.add_child(wname_lbl)
	nades_lbl = _label(font_ui, 18, Color(0.6, 0.8, 0.5)); nades_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nades_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT); nades_lbl.offset_left = -360; nades_lbl.offset_top = 104; nades_lbl.offset_right = -36; nades_lbl.offset_bottom = 128; root.add_child(nades_lbl)
	prompt_lbl = _label(font_ui, 24, Color(1, 1, 1)); prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.set_anchors_preset(Control.PRESET_CENTER); prompt_lbl.offset_left = -420; prompt_lbl.offset_right = 420; prompt_lbl.offset_top = 70; prompt_lbl.offset_bottom = 110; root.add_child(prompt_lbl)
	banner_lbl = _label(font_bo, 44, Color(1, 0.85, 0.4)); banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP); banner_lbl.offset_left = -500; banner_lbl.offset_right = 500; banner_lbl.offset_top = 70; banner_lbl.offset_bottom = 130; root.add_child(banner_lbl)
	banner_sub = _label(font_ui, 22, Color(0.95, 0.92, 0.85)); banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.set_anchors_preset(Control.PRESET_CENTER_TOP); banner_sub.offset_left = -500; banner_sub.offset_right = 500; banner_sub.offset_top = 128; banner_sub.offset_bottom = 160; root.add_child(banner_sub)
	timers_lbl = _label(font_bo, 24, Color(0.5, 1, 0.5)); timers_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timers_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); timers_lbl.offset_left = -300; timers_lbl.offset_right = 300; timers_lbl.offset_top = -70; timers_lbl.offset_bottom = -36; root.add_child(timers_lbl)
	touch_layer = preload("res://scripts/touch.gd").new(); touch_layer.hud = self; touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(touch_layer)
	_build_pause(); _build_over()

func _label(f: Font, size: int, c: Color) -> Label:
	var l = Label.new(); l.add_theme_font_override("font", f); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85)); l.add_theme_constant_override("shadow_offset_x", 2); l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _process(d: float) -> void:
	banner_t -= d
	banner_lbl.modulate.a = clamp(banner_t * 2.0, 0.0, 1.0); banner_sub.modulate.a = banner_lbl.modulate.a
	hit_t -= d; hit_ctl.queue_redraw()
	hurt_t = max(0.0, hurt_t - d * 2.0)
	if game and game.player:
		var p: Player = game.player
		var low: float = 1.0 - p.hp / p.max_hp
		(hurt_rect.material as ShaderMaterial).set_shader_parameter("a", clamp(low * 0.9 + hurt_t, 0.0, 1.0) if not p.downed else 0.9)
		cross.modulate.a = 1.0 - p.ads
		touch_layer.set_use_visible(p.interact_target != null)
	white_rect.color.a = max(0.0, white_rect.color.a - d * 0.8)
	round_flash = max(0.0, round_flash - d); round_ctl.queue_redraw()

# ------------------------------------------------------------------ actualizar
func update_points(p: int, delta: int) -> void:
	points_lbl.text = str(p)
	if delta != 0:
		var l = _label(font_bo, 22, Color(1, 0.85, 0.3) if delta > 0 else Color(1, 0.3, 0.3)); l.text = ("+" if delta > 0 else "") + str(delta)
		pts_pop.add_child(l); var tw = l.create_tween(); tw.tween_property(l, "modulate:a", 0.0, 0.9); tw.tween_callback(l.queue_free)

func flash_points() -> void:
	var tw = points_lbl.create_tween(); points_lbl.modulate = Color(1, 0.2, 0.2); tw.tween_property(points_lbl, "modulate", Color.WHITE, 0.5)

func update_ammo() -> void:
	var p: Player = game.player
	if p == null or p.weapons.is_empty(): return
	var w = p.cur_w()
	ammo_lbl.text = "%d / %d" % [w.mag, w.res]
	ammo_lbl.add_theme_color_override("font_color", Color(1, 0.25, 0.25) if w.mag <= int(p.stat("mag")) * 0.25 else Color.WHITE)
	var nm: String = Data.WEAPONS[w.id].pap.name if w.pap else Data.WEAPONS[w.id].name
	wname_lbl.text = nm + ("  [%s]" % GS.camo_of(w.id).name if GS.camo_of(w.id).id != "none" else "")
	nades_lbl.text = "Granadas: %d" % p.grenades

func update_perks(perks: Array) -> void:
	for c in perks_box.get_children(): c.queue_free()
	for id in perks:
		var pc = PanelContainer.new(); var sb = StyleBoxFlat.new(); sb.bg_color = Data.PERKS[id].color; sb.set_corner_radius_all(18); sb.border_color = Color(0, 0, 0, 0.7); sb.set_border_width_all(2)
		pc.add_theme_stylebox_override("panel", sb); pc.custom_minimum_size = Vector2(36, 36)
		var l = _label(font_bo, 16, Color.WHITE); l.text = Data.PERKS[id].name.substr(0, 1); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pc.add_child(l); perks_box.add_child(pc)

func set_round(n: int, flash: bool) -> void:
	round_n = n; if flash: round_flash = 3.0
	round_ctl.queue_redraw()

func update_timers(insta: float, dp: float, fs: float) -> void:
	var t = []
	if insta > 0: t.append("MUERTE INSTANTÁNEA %d" % ceil(insta))
	if dp > 0: t.append("x2 PUNTOS %d" % ceil(dp))
	if fs > 0: t.append("REBAJAS %d" % ceil(fs))
	timers_lbl.text = "    ".join(t)

func show_prompt(t: String) -> void: prompt_lbl.text = t
func banner(t: String, sub: String, dur: float) -> void: banner_lbl.text = t; banner_sub.text = sub; banner_t = dur
func hitmarker(kill: bool, head: bool) -> void: hit_t = 0.18; hit_kill = kill; hit_head = head
func hurt_flash() -> void: hurt_t = 0.5
func white_flash() -> void: white_rect.color.a = 0.9
func set_scope(on: bool) -> void: scope_rect.visible = on

# ------------------------------------------------------------------ pausa y fin
func _button(text: String, cb: Callable) -> Button:
	var b = Button.new(); b.text = text; b.add_theme_font_override("font", font_bo); b.add_theme_font_size_override("font_size", 30)
	b.custom_minimum_size = Vector2(380, 62); b.pressed.connect(cb); b.focus_mode = Control.FOCUS_ALL
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.08, 0.1, 0.85); sb.border_color = Color(0.55, 0.08, 0.08); sb.set_border_width_all(2); sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb); var sh = sb.duplicate(); sh.bg_color = Color(0.35, 0.05, 0.05, 0.9); b.add_theme_stylebox_override("hover", sh); b.add_theme_stylebox_override("focus", sh); b.add_theme_stylebox_override("pressed", sh)
	return b

func _build_pause() -> void:
	pause_panel = ColorRect.new(); pause_panel.color = Color(0, 0, 0, 0.7); pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT); pause_panel.visible = false; root.add_child(pause_panel)
	var v = VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER); v.offset_left = -190; v.offset_right = 190; v.offset_top = -160; v.offset_bottom = 160; v.add_theme_constant_override("separation", 14); pause_panel.add_child(v)
	var t = _label(font_bo, 54, Color(0.9, 0.15, 0.15)); t.text = "PAUSA"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	v.add_child(_button("CONTINUAR", func(): game.pause(false)))
	v.add_child(_button("SALIR AL MENÚ", func(): game.pause(false); game._on_player_died()))

func show_pause(on: bool) -> void:
	pause_panel.visible = on
	Controls.mouse_captured = not on; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else (Input.MOUSE_MODE_CAPTURED if Controls.device == "kb" else Input.MOUSE_MODE_VISIBLE)
	if on: pause_panel.get_child(0).get_child(1).grab_focus()

func _build_over() -> void:
	over_panel = ColorRect.new(); over_panel.color = Color(0, 0, 0, 0.82); over_panel.set_anchors_preset(Control.PRESET_FULL_RECT); over_panel.visible = false; root.add_child(over_panel)

func show_game_over(s: Dictionary) -> void:
	Controls.mouse_captured = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_layer.visible = false
	over_panel.visible = true
	var v = VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER); v.offset_left = -360; v.offset_right = 360; v.offset_top = -230; v.offset_bottom = 230; v.add_theme_constant_override("separation", 10); over_panel.add_child(v)
	var t = _label(font_bo, 60, Color(0.85, 0.1, 0.1)); t.text = "FIN DE LA PARTIDA"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var r = _label(font_ui, 30, Color.WHITE); r.text = "Has sobrevivido %d %s" % [s.round, "ronda" if s.round == 1 else "rondas"]; r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(r)
	var st = _label(font_ui, 22, Color(0.8, 0.78, 0.7)); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.text = "Bajas: %d    A la cabeza: %d    Tiempo: %d:%02d" % [s.kills, s.heads, int(s.time) / 60, int(s.time) % 60]; v.add_child(st)
	var xp = _label(font_bo, 26, Color(1, 0.85, 0.35)); xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp.text = "+%d XP   ·   NIVEL %d%s" % [s.xp, GS.level, ("   ¡HAS SUBIDO DE NIVEL!" if s.levels > 0 else "")]; v.add_child(xp)
	if s.get("record", false):
		var rec = _label(font_bo, 26, Color(0.4, 1, 0.5)); rec.text = "¡NUEVO RÉCORD!"; rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(rec)
	var b = _button("VOLVER AL MENÚ", func(): get_tree().paused = false; get_tree().root.get_node("Main").to_menu())
	v.add_child(b); b.grab_focus()

# ------------------------------------------------------------------ dibujos
class _Round extends Control:
	var hud
	func _draw() -> void:
		var n: int = hud.round_n
		var c = Color(0.72, 0.03, 0.03)
		if hud.round_flash > 0.0 and int(hud.round_flash * 4.0) % 2 == 0: c = Color(1, 0.95, 0.9)
		if n <= 0: return
		if n <= 5:
			for i in n:
				var x = 10.0 + i * 26.0
				if i == 4: draw_line(Vector2(-2, 90), Vector2(118, 20), c, 9.0)
				else: draw_line(Vector2(x, 15), Vector2(x + 6, 100), c, 9.0)
		else:
			draw_string(hud.font_bo, Vector2(0, 110), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 110, c)

class _Hit extends Control:
	var hud
	func _draw() -> void:
		if hud.hit_t <= 0.0: return
		var c = Color(1, 0.2, 0.2) if hud.hit_kill else Color(1, 1, 1)
		var s = 14.0 if not hud.hit_head else 18.0
		for v in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]: draw_line(v * 6, v * s, c, 3.0)

class _Cross extends Control:
	func _draw() -> void:
		var c = Color(1, 1, 1, 0.85)
		for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: draw_line(v * 7, v * 16, c, 2.0)

class _ScopeDraw extends Control:
	func _draw() -> void:
		var s = size; var c = s / 2; var r: float = min(s.x, s.y) * 0.46
		draw_rect(Rect2(0, 0, c.x - r, s.y), Color.BLACK); draw_rect(Rect2(c.x + r, 0, s.x, s.y), Color.BLACK)
		for i in 64:
			var a = i * TAU / 64; var b = (i + 1) * TAU / 64
			draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a), sin(a)) * r * 3, c + Vector2(cos(b), sin(b)) * r * 3, c + Vector2(cos(b), sin(b)) * r]), Color.BLACK)
		draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), Color.BLACK, 2); draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), Color.BLACK, 2)
	func _notification(w: int) -> void: if w == NOTIFICATION_RESIZED: queue_redraw()
