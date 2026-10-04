extends Control
## Menú principal con el estilo de la versión anterior (logo SHRIMP / ZOMBIES, botones de texto con barra roja),
## repartido por todo el ancho: a la izquierda el menú, a la derecha el nivel, la experiencia y tu personaje.
## Se maneja con el dedo, con ratón y con mando (cruceta o stick para moverse, A para elegir, B para volver).

var main: Node
var font_bo: Font
var font_ui: Font
var page: Control
var bg: TextureRect
var t = 0.0
var back_cb := Callable()
const RED2 = Color(1.0, 0.165, 0.165)
const GOLD = Color(1.0, 0.8, 0.2)
const BEIGE = Color(0.725, 0.663, 0.541)
const MAP_INFO := {
	"prison": { "name": "Penitenciaría", "desc": "Una cárcel de máxima seguridad tomada por los muertos. Patios, pistas valladas y el bloque de celdas." },
	"mansion": { "name": "La Mansión", "desc": "Dos plantas, biblioteca, salón de baile y dormitorios. Cada puerta que abras deja entrar a más." },
	"isla": { "name": "Isla Gamba", "desc": "La cabaña, el muelle, el bar y el faro de la isla. El clásico de siempre." },
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font_bo = load("res://assets/fonts/BlackOpsOne.ttf"); font_ui = load("res://assets/fonts/Oswald.ttf")
	bg = TextureRect.new(); bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_bg(GS.sel_map)
	var shade = ColorRect.new(); shade.name = "shade"; add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh = Shader.new(); sh.code = "shader_type canvas_item; uniform float home = 1.0; void fragment(){ float g = mix(0.92, 0.05, smoothstep(0.0, 0.7, UV.x)); float a = mix(0.74, g, home); a = max(a, smoothstep(0.6, 1.0, UV.y) * 0.55); COLOR = vec4(0.016, 0.02, 0.035, a); }"
	var sm = ShaderMaterial.new(); sm.shader = sh; shade.material = sm
	get_viewport().size_changed.connect(func(): if page and page.has_meta("home"): _home())
	_home()

func _set_bg(id: String) -> void:
	var p = "res://assets/ui/menu_%s.jpg" % id
	if ResourceLoader.exists(p): bg.texture = load(p)

func _process(d: float) -> void:
	t += d
	if bg: bg.position = Vector2(sin(t * 0.05) * 18.0 - 18.0, cos(t * 0.04) * 10.0 - 10.0); bg.scale = Vector2.ONE * 1.04

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and back_cb.is_valid():
		get_viewport().set_input_as_handled(); back_cb.call()

func _clear(home := false) -> void:
	if page: page.queue_free()
	page = Control.new(); add_child(page); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if home: page.set_meta("home", true)
	(get_node("shade").material as ShaderMaterial).set_shader_parameter("home", 1.0 if home else 0.0)

func _lbl(text: String, f: Font, size: int, c: Color) -> Label:
	var l = Label.new(); l.text = text; l.add_theme_font_override("font", f); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85)); l.add_theme_constant_override("shadow_offset_y", 4); l.add_theme_constant_override("shadow_offset_x", 0)
	return l

func _btn(text: String, cb: Callable, w := 470, centered := false, size := 34) -> Button:
	return MenuStyle.button(text, cb, font_bo, size, w, centered)

# ------------------------------------------------------------------ portada
func _home() -> void:
	_clear(true); back_cb = Callable()
	var m = MenuStyle.safe_margins(get_viewport())
	var left = VBoxContainer.new(); left.alignment = BoxContainer.ALIGNMENT_CENTER; left.add_theme_constant_override("separation", 2)
	page.add_child(left); left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); left.offset_left = m.x + 10; left.offset_right = m.x + 660
	left.add_child(_lbl("SHRIMP", font_bo, 54, Color(1, 0.6, 0.48)))
	var logo2 = _lbl("ZOMBIES", font_bo, 116, RED2); logo2.add_theme_color_override("font_outline_color", Color(0.25, 0, 0)); logo2.add_theme_constant_override("outline_size", 4)
	logo2.add_theme_constant_override("line_spacing", -24); left.add_child(logo2)
	left.add_child(_lbl(MAP_INFO[GS.sel_map].name.to_upper(), font_bo, 22, BEIGE))
	var gap = Control.new(); gap.custom_minimum_size = Vector2(0, 16); left.add_child(gap)
	var play = _btn("JUGAR", _options); left.add_child(play)
	left.add_child(_btn("MAPA: %s" % MAP_INFO[GS.sel_map].name.to_upper(), _maps))
	left.add_child(_btn("PERSONAJE", _chars))
	left.add_child(_btn("ARMERÍA", _armory))
	left.add_child(_btn("AJUSTES", _settings))
	left.add_child(_btn("CRÉDITOS", _credits))
	var best = RichTextLabel.new(); best.bbcode_enabled = true; best.fit_content = true; best.scroll_active = false; best.custom_minimum_size = Vector2(470, 0)
	best.add_theme_font_override("normal_font", font_ui); best.add_theme_font_size_override("normal_font_size", 22); best.add_theme_color_override("default_color", BEIGE)
	var b = int(GS.best.get(GS.sel_map, 0))
	best.text = "    Récord: [color=#ffcc33]%s[/color]" % ("Ronda %d" % b if b > 0 else "—"); left.add_child(best)
	if Input.get_connected_joypads().size() > 0:
		left.add_child(_lbl("    Mando: cruceta para moverte · A elegir · B volver", font_ui, 18, Color(0.6, 0.58, 0.52)))
	# a la derecha: tu personaje, el nivel y lo siguiente que se desbloquea
	var right = VBoxContainer.new(); right.alignment = BoxContainer.ALIGNMENT_END; right.add_theme_constant_override("separation", 6)
	page.add_child(right); right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE); right.offset_left = -m.y - 470; right.offset_right = -m.y; right.offset_bottom = -36; right.offset_top = 30
	var cimg = TextureRect.new(); cimg.custom_minimum_size = Vector2(470, 230); cimg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; cimg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cp = "res://assets/ui/char_%s.png" % GS.character
	if ResourceLoader.exists(cp): cimg.texture = load(cp)
	right.add_child(cimg)
	var cn = _lbl(Data.CHARACTERS[GS.character].name.to_upper(), font_bo, 26, Color(1, 0.82, 0.48)); cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; right.add_child(cn)
	var lv = _lbl("NIVEL %d" % GS.level, font_bo, 54, GOLD); lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; right.add_child(lv)
	var need = Data.xp_for_level(GS.level)
	var bar = ProgressBar.new(); bar.max_value = need; bar.value = GS.xp; bar.show_percentage = false; bar.custom_minimum_size = Vector2(470, 12)
	var bgs = StyleBoxFlat.new(); bgs.bg_color = Color(0, 0, 0, 0.55); bgs.set_corner_radius_all(6); var fgs = StyleBoxFlat.new(); fgs.bg_color = GOLD; fgs.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bgs); bar.add_theme_stylebox_override("fill", fgs); right.add_child(bar)
	var xp = _lbl("%d / %d XP" % [GS.xp, need], font_ui, 20, BEIGE); xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; right.add_child(xp)
	for u in Data.UNLOCKS:
		if u.level > GS.level:
			var nx = _lbl("Nivel %d: %s" % [u.level, u.text], font_ui, 22, Color(0.92, 0.88, 0.8)); nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; right.add_child(nx); break
	play.grab_focus()

# ------------------------------------------------------------------ páginas centradas
func _page(title: String, back: Callable) -> VBoxContainer:
	_clear(false); back_cb = back
	var v = VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 12)
	page.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); v.offset_top = 24; v.offset_bottom = -24
	var tl = _lbl(title, font_bo, 60, RED2); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tl)
	return v

func _center(n: Control) -> CenterContainer:
	var c = CenterContainer.new(); c.add_child(n); return c

## tarjeta con imagen, título y texto (mapas y personajes)
func _card(img_path: String, title: String, desc: String, foot: String, selected: bool, cb: Callable, w := 330, img_h := 172) -> Button:
	var card = Button.new(); card.custom_minimum_size = Vector2(w, img_h + 190); card.focus_mode = Control.FOCUS_ALL
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.06); sb.border_color = GOLD if selected else Color(1, 1, 1, 0.12); sb.set_border_width_all(3); sb.set_corner_radius_all(12)
	var sf = sb.duplicate(); sf.border_color = RED2; sf.bg_color = Color(0.78, 0.08, 0.12, 0.18)
	card.add_theme_stylebox_override("normal", sb); card.add_theme_stylebox_override("hover", sf); card.add_theme_stylebox_override("focus", sf); card.add_theme_stylebox_override("pressed", sf)
	var cv = VBoxContainer.new(); cv.mouse_filter = Control.MOUSE_FILTER_IGNORE; cv.add_theme_constant_override("separation", 6); card.add_child(cv)
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); cv.offset_left = 12; cv.offset_right = -12; cv.offset_top = 12; cv.offset_bottom = -12
	var img = TextureRect.new(); img.custom_minimum_size = Vector2(w - 24, img_h); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(img_path): img.texture = load(img_path)
	if img_path.ends_with(".png"): img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cv.add_child(img)
	var n = _lbl(title, font_bo, 24 if w > 280 else 19, Color(1, 0.82, 0.48)); n.mouse_filter = Control.MOUSE_FILTER_IGNORE; n.autowrap_mode = TextServer.AUTOWRAP_WORD; n.custom_minimum_size = Vector2(w - 24, 0); cv.add_child(n)
	var d = _lbl(desc, font_ui, 17, Color(0.9, 0.86, 0.78)); d.autowrap_mode = TextServer.AUTOWRAP_WORD; d.custom_minimum_size = Vector2(w - 24, 0); d.mouse_filter = Control.MOUSE_FILTER_IGNORE; cv.add_child(d)
	var r = _lbl(foot, font_ui, 17, BEIGE); r.mouse_filter = Control.MOUSE_FILTER_IGNORE; cv.add_child(r)
	card.pressed.connect(cb)
	return card

func _maps() -> void:
	var v = _page("MAPA", _home)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 26); v.add_child(h)
	var first: Control = null
	for id in Data.MAPS:
		var bb = int(GS.best.get(id, 0))
		var card = _card("res://assets/ui/menu_%s.jpg" % id, MAP_INFO[id].name.to_upper(), MAP_INFO[id].desc, "Récord: ronda %d" % bb if bb > 0 else "Sin récord", id == GS.sel_map,
			func(): GS.sel_map = id; GS.save_game(); _set_bg(id); _home())
		card.focus_entered.connect(func(): _set_bg(id))
		h.add_child(card)
		if id == GS.sel_map or first == null: first = card
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	if first: first.grab_focus()

func _chars() -> void:
	var v = _page("PERSONAJE", _home)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 18); v.add_child(h)
	var first: Control = null
	for id in Data.CHARACTERS:
		var c = Data.CHARACTERS[id]
		var ok = GS.level >= int(c.level)
		var card = _card("res://assets/ui/char_%s.png" % id, c.name.to_upper(), c.desc, "Elegido" if id == GS.character else ("Disponible" if ok else "Se desbloquea en el nivel %d" % c.level), id == GS.character,
			func():
				if ok: GS.character = id; GS.save_game(); _home(), 250, 180)
		if not ok: card.modulate = Color(0.55, 0.55, 0.55)
		h.add_child(card)
		if id == GS.character or first == null: first = card
	var hint = _lbl("Se ve en tercera persona (Ajustes → Vista, o en la pausa).", font_ui, 19, BEIGE); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(hint)
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	if first: first.grab_focus()

## fila de ajuste: nombre a la izquierda, valor a la derecha (como en la versión anterior)
func _row(label: String, value: Control) -> PanelContainer:
	var pc = PanelContainer.new(); var sb = StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.06); sb.set_corner_radius_all(8); sb.content_margin_left = 18; sb.content_margin_right = 12
	pc.add_theme_stylebox_override("panel", sb); pc.custom_minimum_size = Vector2(780, 62)
	var h = HBoxContainer.new(); pc.add_child(h)
	var l = _lbl(label, font_ui, 26, Color(0.95, 0.92, 0.86)); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; h.add_child(l)
	h.add_child(value)
	return pc

func _value_btn(text: String) -> Button:
	var b = MenuStyle.button(text, func(): pass, font_bo, 26, 340, true)
	b.add_theme_color_override("font_color", GOLD); b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.6)); b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.6))
	return b

func _options() -> void:
	var v = _page(MAP_INFO[GS.sel_map].name.to_upper(), _home)
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation", 8); v.add_child(_center(list))
	_cycler(list, "Empezar en la ronda", ["1", "5", "10", "15", "20", "25"], str(GS.start_round), "start_round", func(x): GS.start_round = int(x))
	_cycler(list, "Arma inicial", ["m1911", "python", "mp5k", "m16", "galil"], GS.start_weapon, "start_weapon", func(x): GS.start_weapon = x, func(x): return Data.WEAPONS[x].name.to_upper())
	_cycler(list, "Ventaja inicial", ["", "revive", "jugg"], GS.start_perk, "start_perk", func(x): GS.start_perk = x, func(x): return "NINGUNA" if x == "" else Data.PERKS[x].name.to_upper())
	var hint = _lbl("Sube de nivel para desbloquear más opciones, como en Black Ops 4.", font_ui, 19, BEIGE); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(hint)
	var go = _btn("EMPEZAR PARTIDA", func(): GS.save_game(); main.start_game(), 480, true, 38); v.add_child(_center(go))
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	go.grab_focus()

## valor que se cambia pulsando; solo deja elegir lo desbloqueado
func _cycler(list: VBoxContainer, label: String, opts: Array, cur: String, kind: String, set_cb: Callable, label_cb := Callable()) -> Button:
	var avail = opts.filter(func(o): return GS.is_unlocked(kind, o))
	if not cur in avail:
		cur = avail[0]; set_cb.call(cur)
	var name_of = func(o): return label_cb.call(o) if label_cb.is_valid() else o
	var locked = opts.size() - avail.size()
	var suffix = ""
	var b = _value_btn(str(name_of.call(cur)) + suffix)
	b.set_meta("v", cur)
	b.pressed.connect(func():
		var i = avail.find(b.get_meta("v")); var nx: String = avail[(i + 1) % avail.size()]
		b.set_meta("v", nx); b.text = str(name_of.call(nx)) + suffix; set_cb.call(nx))
	list.add_child(_row(label, b))
	return b

func _armory() -> void:
	var v = _page("ARMERÍA", _home)
	var hint = _lbl("Camuflajes: se desbloquean con bajas de cada arma. Pulsa un arma para cambiarlo.", font_ui, 20, BEIGE); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(hint)
	var sc = ScrollContainer.new(); sc.custom_minimum_size = Vector2(1200, 430); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(_center(sc))
	var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 8); sc.add_child(g)
	var first: Button = null
	for id in Data.WEAPONS:
		var kills = int(GS.weapon_kills.get(id, 0))
		var nxt = ""
		for c in Data.CAMOS:
			if c.kills > kills: nxt = "  ·  %s a %d" % [c.name, c.kills]; break
		var b = MenuStyle.button("", func(): pass, font_bo, 19, 390, false)
		b.custom_minimum_size = Vector2(390, 74)
		var refresh = func(): b.text = "%s  ·  %s\n%d bajas%s" % [Data.WEAPONS[id].name.to_upper(), GS.camo_of(id).name.to_upper(), kills, nxt]
		refresh.call()
		b.pressed.connect(func():
			var unlocked = Data.CAMOS.filter(func(c): return GS.camo_unlocked(id, c.id))
			var i = -1
			for k in unlocked.size():
				if unlocked[k].id == GS.camo_of(id).id: i = k
			GS.camo[id] = unlocked[(i + 1) % unlocked.size()].id; GS.save_game(); refresh.call())
		g.add_child(b)
		if first == null: first = b
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	first.grab_focus()

func _settings() -> void:
	var v = _page("AJUSTES", func(): GS.save_game(); _home())
	var sc = ScrollContainer.new(); sc.custom_minimum_size = Vector2(820, 470); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(_center(sc))
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation", 8); sc.add_child(list)
	var first = _toggle(list, "Vista", "third", "TERCERA PERSONA", "PRIMERA PERSONA")
	_cycle_setting(list, "Calidad gráfica", "quality", ["baja", "media", "alta"])
	_slider(list, "Sensibilidad", 0.3, 2.5, float(GS.settings.sens), func(x): GS.settings.sens = x)
	_slider(list, "Campo de visión", 60, 95, float(GS.settings.fov), func(x): GS.settings.fov = x)
	_toggle(list, "Ayuda al apuntar", "aim_assist", "SÍ", "NO")
	_toggle(list, "Invertir eje vertical", "invert", "SÍ", "NO")
	_slider(list, "Efectos de sonido", 0, 1, float(GS.settings.sfx), func(x): GS.settings.sfx = x)
	_slider(list, "Ambiente", 0, 1, float(GS.settings.music), func(x): GS.settings.music = x)
	v.add_child(_center(_btn("VOLVER", func(): GS.save_game(); _home(), 300, true)))
	first.grab_focus()

func _toggle(list: VBoxContainer, label: String, key: String, yes: String, no: String) -> Button:
	var b = _value_btn(yes if GS.settings.get(key, false) else no)
	b.pressed.connect(func(): GS.settings[key] = not GS.settings.get(key, false); b.text = yes if GS.settings[key] else no)
	list.add_child(_row(label, b)); return b

func _cycle_setting(list: VBoxContainer, label: String, key: String, opts: Array) -> Button:
	var b = _value_btn(str(GS.settings.get(key, opts[-1])).to_upper())
	b.pressed.connect(func():
		var i = opts.find(GS.settings.get(key, opts[-1])); GS.settings[key] = opts[(i + 1) % opts.size()]; b.text = str(GS.settings[key]).to_upper())
	list.add_child(_row(label, b)); return b

func _slider(list: VBoxContainer, label: String, a: float, b: float, val: float, cb: Callable) -> HSlider:
	var s = HSlider.new(); s.min_value = a; s.max_value = b; s.step = (b - a) / 40.0; s.value = val; s.custom_minimum_size = Vector2(340, 48); s.value_changed.connect(cb); s.focus_mode = Control.FOCUS_ALL
	var grab = StyleBoxFlat.new(); grab.bg_color = RED2; grab.content_margin_top = 4; grab.content_margin_bottom = 4
	var track = StyleBoxFlat.new(); track.bg_color = Color(1, 1, 1, 0.18); track.content_margin_top = 3; track.content_margin_bottom = 3; track.set_corner_radius_all(3)
	s.add_theme_stylebox_override("slider", track); s.add_theme_stylebox_override("grabber_area", grab); s.add_theme_stylebox_override("grabber_area_highlight", grab)
	list.add_child(_row(label, s)); return s

func _credits() -> void:
	var v = _page("CRÉDITOS", _home)
	var f = FileAccess.open("res://assets/CREDITOS.txt", FileAccess.READ)
	var sc = ScrollContainer.new(); sc.custom_minimum_size = Vector2(1100, 440); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(_center(sc))
	var l = _lbl(f.get_as_text() if f else "", font_ui, 19, Color(0.88, 0.85, 0.78)); l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size = Vector2(1080, 0); sc.add_child(l)
	var back = _btn("VOLVER", _home, 300, true); v.add_child(_center(back)); back.grab_focus()
