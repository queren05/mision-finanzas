extends CanvasLayer
## Interfaz de la partida, con el mismo estilo que la versión anterior:
## abajo a la izquierda ventajas, ronda (palotes rojos) y puntos con barra dorada; el arma y la munición en grande
## (abajo a la derecha con mando o teclado, arriba a la derecha en pantalla táctil para no tapar los botones).

const RED = Color(0.784, 0.078, 0.118)
const RED2 = Color(1.0, 0.165, 0.165)
const GOLD = Color(1.0, 0.8, 0.2)
const TXT = Color(0.95, 0.925, 0.88)

var game: Node
var font_bo: Font
var font_ui: Font
var root: Control
var round_ctl: Control
var round_n = 0
var round_flash = 0.0
var points_box: Control
var points_lbl: Label
var pts_pop: Control
var gun_box: VBoxContainer
var ammo_mag: Label
var ammo_res: Label
var wname_lbl: Label
var nades_lbl: Label
var perks_box: HBoxContainer
var prompt_lbl: RichTextLabel
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
var pups_box: HBoxContainer
var downed_box: VBoxContainer
var pause_panel: Control
var over_panel: Control
var touch_layer: Control
var cross: Control
var bottom_left: VBoxContainer
var last_device = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_bo = load("res://assets/fonts/BlackOpsOne.ttf"); font_ui = load("res://assets/fonts/Oswald.ttf")
	root = Control.new(); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_rect = ColorRect.new(); hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hurt_rect); hurt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh = Shader.new(); sh.code = "shader_type canvas_item; uniform float a = 0.0; void fragment(){ vec2 d = UV - 0.5; float v = smoothstep(0.22, 0.75, length(d * vec2(1.7, 1.0))); COLOR = vec4(0.5, 0.0, 0.02, v * a); }"
	var sm = ShaderMaterial.new(); sm.shader = sh; hurt_rect.material = sm
	white_rect = ColorRect.new(); white_rect.color = Color(1, 1, 1, 0); white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(white_rect); white_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_rect = _ScopeDraw.new(); scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; scope_rect.visible = false; root.add_child(scope_rect); scope_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross = _Cross.new(); cross.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(cross); cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hit_ctl = _Hit.new(); hit_ctl.hud = self; hit_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hit_ctl); hit_ctl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# abajo a la izquierda: puntos, ventajas y ronda
	bottom_left = VBoxContainer.new(); bottom_left.mouse_filter = Control.MOUSE_FILTER_IGNORE; bottom_left.alignment = BoxContainer.ALIGNMENT_END; bottom_left.add_theme_constant_override("separation", 6)
	root.add_child(bottom_left); bottom_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); bottom_left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pts_pop = Control.new(); pts_pop.custom_minimum_size = Vector2(200, 0); pts_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE; bottom_left.add_child(pts_pop)
	points_box = PanelContainer.new(); var psb = StyleBoxTexture.new(); psb.texture = _grad_tex(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0)); psb.content_margin_right = 34
	points_box.add_theme_stylebox_override("panel", psb); points_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; points_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pbar = HBoxContainer.new(); pbar.add_theme_constant_override("separation", 12); points_box.add_child(pbar)
	var gold_bar = ColorRect.new(); gold_bar.color = GOLD; gold_bar.custom_minimum_size = Vector2(5, 0); pbar.add_child(gold_bar)
	points_lbl = _label(font_bo, 40, Color.WHITE); pbar.add_child(points_lbl)
	bottom_left.add_child(points_box)
	perks_box = HBoxContainer.new(); perks_box.add_theme_constant_override("separation", 6); perks_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; bottom_left.add_child(perks_box)
	round_ctl = _Round.new(); round_ctl.hud = self; round_ctl.custom_minimum_size = Vector2(260, 118); round_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; bottom_left.add_child(round_ctl)
	# el arma
	gun_box = VBoxContainer.new(); gun_box.alignment = BoxContainer.ALIGNMENT_END; gun_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; gun_box.add_theme_constant_override("separation", -4)
	root.add_child(gun_box)
	wname_lbl = _label(font_ui, 24, Color(0.9, 0.86, 0.78)); wname_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; gun_box.add_child(wname_lbl)
	var ammo_row = HBoxContainer.new(); ammo_row.alignment = BoxContainer.ALIGNMENT_END; ammo_row.add_theme_constant_override("separation", 6); ammo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE; gun_box.add_child(ammo_row)
	ammo_mag = _label(font_bo, 60, Color.WHITE); ammo_row.add_child(ammo_mag)
	var slash = _label(font_bo, 34, Color(1, 1, 1, 0.5)); slash.text = "/"; ammo_row.add_child(slash)
	ammo_res = _label(font_bo, 32, Color(1, 1, 1, 0.85)); ammo_row.add_child(ammo_res)
	nades_lbl = _label(font_bo, 22, Color(0.7, 0.85, 0.55)); nades_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; gun_box.add_child(nades_lbl)
	# potenciadores activos
	pups_box = HBoxContainer.new(); pups_box.alignment = BoxContainer.ALIGNMENT_CENTER; pups_box.add_theme_constant_override("separation", 22); pups_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pups_box); pups_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); pups_box.offset_top = -110; pups_box.offset_bottom = -40; pups_box.offset_left = -300; pups_box.offset_right = 300
	# mensajes
	prompt_lbl = RichTextLabel.new(); prompt_lbl.bbcode_enabled = true; prompt_lbl.fit_content = true; prompt_lbl.scroll_active = false; prompt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_lbl.add_theme_font_override("normal_font", font_ui); prompt_lbl.add_theme_font_override("bold_font", font_bo); prompt_lbl.add_theme_font_size_override("normal_font_size", 28); prompt_lbl.add_theme_font_size_override("bold_font_size", 26)
	prompt_lbl.add_theme_color_override("default_color", TXT); prompt_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9)); prompt_lbl.add_theme_constant_override("shadow_offset_y", 2); prompt_lbl.add_theme_constant_override("shadow_offset_x", 2)
	root.add_child(prompt_lbl); prompt_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER); prompt_lbl.offset_left = -520; prompt_lbl.offset_right = 520; prompt_lbl.offset_top = 70; prompt_lbl.offset_bottom = 120
	banner_lbl = _label(font_bo, 54, GOLD); banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(banner_lbl)
	banner_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); banner_lbl.anchor_top = 0.18; banner_lbl.anchor_bottom = 0.18; banner_lbl.offset_left = -640; banner_lbl.offset_right = 640; banner_lbl.offset_top = 0; banner_lbl.offset_bottom = 70
	banner_sub = _label(font_ui, 26, TXT); banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(banner_sub)
	banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); banner_sub.anchor_top = 0.18; banner_sub.anchor_bottom = 0.18; banner_sub.offset_left = -640; banner_sub.offset_right = 640; banner_sub.offset_top = 68; banner_sub.offset_bottom = 104
	# caído
	downed_box = VBoxContainer.new(); downed_box.alignment = BoxContainer.ALIGNMENT_CENTER; downed_box.visible = false; downed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(downed_box); downed_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER); downed_box.offset_left = -400; downed_box.offset_right = 400; downed_box.offset_top = -170; downed_box.offset_bottom = -70
	var dl = _label(font_bo, 56, RED2); dl.text = "¡HAS CAÍDO!"; dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; downed_box.add_child(dl)
	var ds = _label(font_ui, 24, TXT); ds.name = "sub"; ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; downed_box.add_child(ds)
	touch_layer = preload("res://scripts/touch.gd").new(); touch_layer.hud = self; root.add_child(touch_layer); touch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_pause(); _build_over()
	get_viewport().size_changed.connect(_layout); _layout()

## márgenes seguros (muesca del iPhone) y posición del arma según el dispositivo
func _layout() -> void:
	var m = MenuStyle.safe_margins(get_viewport())
	var ml = m.x; var mr = m.y
	bottom_left.offset_left = ml; bottom_left.offset_bottom = -22; bottom_left.offset_right = ml + 420; bottom_left.offset_top = -22
	if Controls.device == "touch":
		gun_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); gun_box.offset_top = 18; gun_box.offset_bottom = 160; gun_box.grow_vertical = Control.GROW_DIRECTION_END
	else:
		gun_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT); gun_box.offset_top = -170; gun_box.offset_bottom = -22; gun_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	gun_box.offset_right = -mr; gun_box.offset_left = -mr - 460
	touch_layer.margin_left = ml; touch_layer.margin_right = mr; touch_layer.queue_redraw()
	last_device = Controls.device

func _label(f: Font, size: int, c: Color) -> Label:
	var l = Label.new(); l.add_theme_font_override("font", f); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9)); l.add_theme_constant_override("shadow_offset_x", 2); l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _grad_tex(a: Color, b: Color) -> GradientTexture2D:
	var g = Gradient.new(); g.set_color(0, a); g.set_color(1, b)
	var t = GradientTexture2D.new(); t.gradient = g; t.width = 64; t.height = 4
	return t

func _process(d: float) -> void:
	if Controls.device != last_device: _layout()
	banner_t -= d
	banner_lbl.modulate.a = clamp(banner_t * 2.0, 0.0, 1.0); banner_sub.modulate.a = banner_lbl.modulate.a
	hit_t -= d; hit_ctl.queue_redraw()
	hurt_t = max(0.0, hurt_t - d * 2.0)
	if game and game.player:
		var p: Player = game.player
		var low: float = 1.0 - p.hp / p.max_hp
		(hurt_rect.material as ShaderMaterial).set_shader_parameter("a", clamp(low * 0.95 + hurt_t, 0.0, 1.0) if not p.downed else 0.95)
		cross.modulate.a = 1.0 - p.ads
		cross.spread = p.spread_add
		touch_layer.set_use_visible(p.interact_target != null)
		downed_box.visible = p.downed
		if p.downed: downed_box.get_node("sub").text = ("Te levantas en %d…" % ceil(3.5 - p.down_t)) if p.revives_left > 0 else ""
	white_rect.color.a = max(0.0, white_rect.color.a - d * 0.8)
	round_flash = max(0.0, round_flash - d); round_ctl.queue_redraw()

# ------------------------------------------------------------------ actualizar
func update_points(p: int, delta: int) -> void:
	points_lbl.text = str(p)
	if delta != 0:
		var l = _label(font_bo, 26, GOLD if delta > 0 else RED2); l.text = ("+" if delta > 0 else "") + str(delta)
		pts_pop.add_child(l); l.position = Vector2(150 + randf_range(0, 40), -14 - randf_range(0, 14))
		var tw = l.create_tween().set_parallel(); tw.tween_property(l, "modulate:a", 0.0, 1.0); tw.tween_property(l, "position:y", l.position.y - 46, 1.0)
		tw.chain().tween_callback(l.queue_free)

func flash_points() -> void:
	var tw = points_lbl.create_tween(); points_lbl.modulate = Color(1, 0.2, 0.2); tw.tween_property(points_lbl, "modulate", Color.WHITE, 0.5)

func update_ammo() -> void:
	var p: Player = game.player
	if p == null or p.weapons.is_empty(): return
	var w = p.cur_w()
	ammo_mag.text = str(w.mag); ammo_res.text = str(w.res)
	ammo_mag.add_theme_color_override("font_color", RED2 if w.mag <= int(p.stat("mag")) * 0.25 else Color.WHITE)
	var nm: String = Data.WEAPONS[w.id].pap.name if w.pap else Data.WEAPONS[w.id].name
	wname_lbl.text = nm
	wname_lbl.add_theme_color_override("font_color", Color(0.84, 0.54, 1.0) if w.pap else Color(0.9, 0.86, 0.78))
	nades_lbl.text = " ".join(range(p.grenades).map(func(_i): return "●"))

func update_perks(perks: Array) -> void:
	for c in perks_box.get_children(): c.queue_free()
	for id in perks:
		var pc = PanelContainer.new(); var sb = StyleBoxFlat.new(); sb.bg_color = Data.PERKS[id].color; sb.set_corner_radius_all(7)
		sb.border_color = Color(1, 1, 1, 0.35); sb.set_border_width_all(2); sb.shadow_color = Color(0, 0, 0, 0.8); sb.shadow_size = 6
		pc.add_theme_stylebox_override("panel", sb); pc.custom_minimum_size = Vector2(40, 40); pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l = _label(font_bo, 20, Color.WHITE); l.text = Data.PERKS[id].name.substr(0, 1); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pc.add_child(l); perks_box.add_child(pc)

func set_round(n: int, flash: bool) -> void:
	round_n = n
	if flash: round_flash = 3.0
	round_ctl.queue_redraw()

func update_timers(insta: float, dp: float, fs: float) -> void:
	for c in pups_box.get_children(): c.queue_free()
	for e in [[insta, "☠", "INSTA"], [dp, "x2", "PUNTOS"], [fs, "$", "REBAJAS"]]:
		if e[0] <= 0: continue
		var v = VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic = _label(font_bo, 44, Color(0.45, 1, 0.45)); ic.text = e[1]; ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ic)
		var tl = _label(font_ui, 16, TXT); tl.text = "%s %d" % [e[2], ceil(e[0])]; tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tl)
		if e[0] < 5 and int(e[0] * 4) % 2 == 0: v.modulate.a = 0.3
		pups_box.add_child(v)

func show_prompt(t: String) -> void:
	if t == "": prompt_lbl.text = ""; return
	var key = "USAR" if Controls.device == "touch" else ("X" if Controls.device == "pad" else "F")
	var txt = t.replace("Pulsa USAR", "Pulsa [b]%s[/b]" % key)
	var r = RegEx.new(); r.compile("\\[(\\d+)\\]")
	txt = r.sub(txt, "[color=#ffcc33][b]$1[/b][/color]", true)
	prompt_lbl.text = "[center]%s[/center]" % txt

func banner(t: String, sub: String, dur: float) -> void: banner_lbl.text = t; banner_sub.text = sub; banner_t = dur
func hitmarker(kill: bool, head: bool) -> void: hit_t = 0.18; hit_kill = kill; hit_head = head
func hurt_flash() -> void: hurt_t = 0.5
func white_flash() -> void: white_rect.color.a = 0.9
func set_scope(on: bool) -> void: scope_rect.visible = on

# ------------------------------------------------------------------ pausa y fin
func _button(text: String, cb: Callable) -> Button:
	return MenuStyle.button(text, cb, font_bo, 34, 460, true)

func _build_pause() -> void:
	pause_panel = ColorRect.new(); pause_panel.color = Color(0.015, 0.02, 0.035, 0.84); pause_panel.visible = false; root.add_child(pause_panel); pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v = VBoxContainer.new(); v.name = "box"; v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 10); pause_panel.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var t = _label(font_bo, 64, RED2); t.text = "PAUSA"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var info = _label(font_ui, 24, Color(0.73, 0.66, 0.54)); info.name = "info"; info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(info)
	for e in [["CONTINUAR", "go", func(): game.pause(false)], ["VISTA", "view", func(): game.player.toggle_view(); _refresh_view_btn()], ["SALIR AL MENÚ", "quit", func(): game.pause(false); game._on_player_died()]]:
		var c = CenterContainer.new(); var b = _button(e[0], e[2]); b.name = e[1]; c.add_child(b); v.add_child(c)

func show_pause(on: bool) -> void:
	pause_panel.visible = on
	Controls.mouse_captured = not on; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else (Input.MOUSE_MODE_CAPTURED if Controls.device == "kb" else Input.MOUSE_MODE_VISIBLE)
	if on:
		pause_panel.find_child("info", true, false).text = "Ronda %d  ·  %d bajas  ·  %d puntos" % [game.round_n, game.player.kills, game.player.points]
		_refresh_view_btn()
		pause_panel.find_child("go", true, false).grab_focus()

func _unhandled_input(e: InputEvent) -> void:
	# con mando: Start o B reanudan la partida
	if pause_panel.visible and (e.is_action_pressed("ui_cancel") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_START)):
		get_viewport().set_input_as_handled(); game.pause(false)

func _refresh_view_btn() -> void:
	var b = pause_panel.find_child("view", true, false)
	if b: b.text = "VISTA: %s" % ("TERCERA PERSONA" if game.player.third else "PRIMERA PERSONA")

func _build_over() -> void:
	over_panel = ColorRect.new(); over_panel.color = Color(0.03, 0.0, 0.01, 0.86); over_panel.visible = false; root.add_child(over_panel); over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func show_game_over(s: Dictionary) -> void:
	Controls.mouse_captured = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_layer.visible = false
	over_panel.visible = true
	var v = VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 12); over_panel.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var t = _label(font_bo, 70, RED2); t.text = "FIN DE LA PARTIDA"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var r = RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.scroll_active = false; r.custom_minimum_size = Vector2(900, 0)
	r.add_theme_font_override("normal_font", font_ui); r.add_theme_font_override("bold_font", font_bo); r.add_theme_font_size_override("normal_font_size", 32); r.add_theme_font_size_override("bold_font_size", 46)
	r.text = "[center]Has sobrevivido [b][color=#ffcc33]%d[/color][/b] %s[/center]" % [s.round, "ronda" if s.round == 1 else "rondas"]
	var rc = CenterContainer.new(); rc.add_child(r); v.add_child(rc)
	var stats = HBoxContainer.new(); stats.alignment = BoxContainer.ALIGNMENT_CENTER; stats.add_theme_constant_override("separation", 44); v.add_child(stats)
	for e in [[s.kills, "Bajas"], [s.heads, "A la cabeza"], ["%d:%02d" % [int(s.time) / 60, int(s.time) % 60], "Tiempo"], [s.xp, "XP"]]:
		var c = VBoxContainer.new(); var a = _label(font_bo, 40, Color.WHITE); a.text = str(e[0]); a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_child(a)
		var b = _label(font_ui, 20, Color(0.73, 0.66, 0.54)); b.text = e[1]; b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_child(b); stats.add_child(c)
	var lv = _label(font_bo, 28, GOLD); lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.text = "NIVEL %d%s" % [GS.level, ("   ·   ¡HAS SUBIDO DE NIVEL!" if s.levels > 0 else "")]; v.add_child(lv)
	if s.get("record", false):
		var rec = _label(font_bo, 30, GOLD); rec.text = "¡NUEVO RÉCORD!"; rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(rec)
		var tw = rec.create_tween().set_loops(); tw.tween_property(rec, "modulate:a", 0.4, 0.6); tw.tween_property(rec, "modulate:a", 1.0, 0.6)
	var c2 = CenterContainer.new(); var bt = _button("VOLVER AL MENÚ", func(): get_tree().paused = false; get_tree().root.get_node("Main").to_menu()); c2.add_child(bt); v.add_child(c2)
	bt.grab_focus()

# ------------------------------------------------------------------ dibujos
class _Round extends Control:
	var hud
	func _draw() -> void:
		var n: int = hud.round_n
		var c = Color(0.784, 0.078, 0.118)
		if hud.round_flash > 0.0 and int(hud.round_flash * 4.0) % 2 == 0: c = Color(1, 0.96, 0.92)
		if n <= 0: return
		var glow = Color(c.r, c.g, c.b, 0.3)
		if n <= 5:
			for i in n:
				var x = 14.0 + i * 30.0
				if i == 4:
					draw_line(Vector2(0, 92), Vector2(134, 18), glow, 17.0); draw_line(Vector2(0, 92), Vector2(134, 18), c, 10.0)
				else:
					draw_line(Vector2(x, 10), Vector2(x + 8, 108), glow, 17.0); draw_line(Vector2(x, 10), Vector2(x + 8, 108), c, 10.0)
		else:
			draw_string(hud.font_bo, Vector2(4, 112), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 124, Color(0.15, 0, 0, 0.9))
			draw_string(hud.font_bo, Vector2(0, 108), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 124, c)

class _Hit extends Control:
	var hud
	func _draw() -> void:
		if hud.hit_t <= 0.0: return
		var c = Color(1, 0.2, 0.2) if hud.hit_kill else Color(1, 1, 1)
		var s = 16.0 if not hud.hit_head else 21.0
		for v in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(v * 7, v * s, Color(0, 0, 0, 0.6), 5.0); draw_line(v * 7, v * s, c, 3.0)

class _Cross extends Control:
	var spread = 0.0
	func _process(_d: float) -> void: queue_redraw()
	func _draw() -> void:
		var g = 8.0 + spread * 6.0
		for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(v * g, v * (g + 11), Color(0, 0, 0, 0.55), 4.0); draw_line(v * g, v * (g + 11), Color(1, 1, 1, 0.9), 2.0)
		draw_circle(Vector2.ZERO, 1.6, Color(1, 1, 1, 0.9))

class _ScopeDraw extends Control:
	func _draw() -> void:
		var s = size; var c = s / 2; var r: float = min(s.x, s.y) * 0.46
		draw_rect(Rect2(0, 0, c.x - r, s.y), Color.BLACK); draw_rect(Rect2(c.x + r, 0, s.x, s.y), Color.BLACK)
		for i in 64:
			var a = i * TAU / 64; var b = (i + 1) * TAU / 64
			draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a), sin(a)) * r * 3, c + Vector2(cos(b), sin(b)) * r * 3, c + Vector2(cos(b), sin(b)) * r]), Color.BLACK)
		draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), Color.BLACK, 2); draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), Color.BLACK, 2)
	func _notification(w: int) -> void:
		if w == NOTIFICATION_RESIZED: queue_redraw()
