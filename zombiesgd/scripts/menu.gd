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

func _btn(text: String, cb: Callable, w := 470, centered := false, size := 27) -> Button:
	return MenuStyle.button(text, cb, font_bo, size, w, centered)

# ------------------------------------------------------------------ portada
func _home() -> void:
	_clear(true); back_cb = Callable()
	var m = MenuStyle.safe_margins(get_viewport())
	var left = VBoxContainer.new(); left.alignment = BoxContainer.ALIGNMENT_CENTER; left.add_theme_constant_override("separation", 2)
	page.add_child(left); left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); left.offset_left = m.x + 10; left.offset_right = m.x + 660
	left.add_child(_lbl("SHRIMP", font_bo, 44, Color(1, 0.6, 0.48)))
	var logo2 = _lbl("ZOMBIES", font_bo, 96, RED2); logo2.add_theme_color_override("font_outline_color", Color(0.25, 0, 0)); logo2.add_theme_constant_override("outline_size", 4)
	logo2.add_theme_constant_override("line_spacing", -24); left.add_child(logo2)
	left.add_child(_lbl(MAP_INFO[GS.sel_map].name.to_upper(), font_bo, 22, BEIGE))
	var gap = Control.new(); gap.custom_minimum_size = Vector2(0, 6); left.add_child(gap)
	var play = _btn("JUGAR", _play); left.add_child(play)
	left.add_child(_btn("ARSENAL", _arsenal))
	left.add_child(_btn("PROGRESO", _progress))
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
	# tarjeta de jugador con el título elegido
	var pcard = PanelContainer.new(); var cc: Array = Data.CARDS.get(GS.card, Data.CARDS[""])
	var csb = StyleBoxTexture.new(); var g = Gradient.new(); g.set_color(0, Color(cc[1].r, cc[1].g, cc[1].b, 0.0)); g.set_color(1, Color(cc[0].r, cc[0].g, cc[0].b, 0.9))
	var gt = GradientTexture2D.new(); gt.gradient = g; gt.width = 64; gt.height = 4; csb.texture = gt; csb.content_margin_right = 14; csb.content_margin_top = 4; csb.content_margin_bottom = 4
	pcard.add_theme_stylebox_override("panel", csb); right.add_child(pcard)
	var ttl = _lbl(Data.TITLES.get(GS.title, "Recluta").to_upper(), font_bo, 24, Color.WHITE); ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; pcard.add_child(ttl)
	var lv = _lbl("NIVEL %d" % GS.level, font_bo, 54, GOLD); lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; right.add_child(lv)
	var need = Data.xp_for_level(GS.level)
	var bar = ProgressBar.new(); bar.max_value = need; bar.value = GS.xp; bar.show_percentage = false; bar.custom_minimum_size = Vector2(470, 12)
	var bgs = StyleBoxFlat.new(); bgs.bg_color = Color(0, 0, 0, 0.55); bgs.set_corner_radius_all(6); var fgs = StyleBoxFlat.new(); fgs.bg_color = GOLD; fgs.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bgs); bar.add_theme_stylebox_override("fill", fgs); right.add_child(bar)
	var xp = _lbl("%d / %d XP" % [GS.xp, need], font_ui, 20, BEIGE); xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; right.add_child(xp)
	for u in Data.UNLOCKS:
		if u.level > GS.level:
			var nx = _lbl("Nivel %d: %s" % [u.level, u.text], font_ui, 22, Color(0.92, 0.88, 0.8)); nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; right.add_child(nx); break
	var dn = _lbl("Desafíos: %d / %d" % [GS.done.size(), Data.CHALLENGES.size()], font_ui, 20, BEIGE); dn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; right.add_child(dn)
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
	var v = _page("MAPA", _play)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 26); v.add_child(h)
	var first: Control = null
	for id in Data.MAPS:
		var bb = int(GS.best.get(id, 0))
		var card = _card("res://assets/ui/menu_%s.jpg" % id, MAP_INFO[id].name.to_upper(), MAP_INFO[id].desc, "Récord: ronda %d" % bb if bb > 0 else "Sin récord", id == GS.sel_map,
			func(): GS.sel_map = id; GS.save_game(); _set_bg(id); _play())
		card.focus_entered.connect(func(): _set_bg(id))
		h.add_child(card)
		if id == GS.sel_map or first == null: first = card
	v.add_child(_center(_btn("VOLVER", _play, 300, true)))
	if first: first.grab_focus()

func _chars() -> void:
	var v = _page("PERSONAJE", _arsenal)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 18); v.add_child(h)
	var first: Control = null
	for id in Data.CHARACTERS:
		var c = Data.CHARACTERS[id]
		var ok = GS.level >= int(c.level)
		var card = _card("res://assets/ui/char_%s.png" % id, c.name.to_upper(), c.desc, "Elegido" if id == GS.character else ("Disponible" if ok else "Se desbloquea en el nivel %d" % c.level), id == GS.character,
			func():
				if ok: GS.character = id; GS.save_game(); _arsenal(), 250, 180)
		if not ok: card.modulate = Color(0.55, 0.55, 0.55)
		h.add_child(card)
		if id == GS.character or first == null: first = card
	var hint = _lbl("Se ve en tercera persona (Ajustes → Vista, o en la pausa).", font_ui, 19, BEIGE); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(hint)
	v.add_child(_center(_btn("VOLVER", _arsenal, 300, true)))
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

## JUGAR: en solitario o cooperativo (y el mapa, si hay más de uno)
func _play() -> void:
	var v = _page("JUGAR", _home)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 26); v.add_child(h)
	var solo = _card("res://assets/ui/menu_%s.jpg" % GS.sel_map, "EN SOLITARIO", "Tú contra la horda. Elige ronda, arma y ventaja inicial.", MAP_INFO[GS.sel_map].name, false, _options, 380, 200)
	var coop = _card("res://assets/ui/char_comando.png", "COOPERATIVO", "De 2 a 4 jugadores en la misma wifi. iPhone, Android y PC juntos.", "Crear o unirse a una partida", false, _coop, 380, 200)
	h.add_child(solo); h.add_child(coop)
	if Data.MAPS.size() > 1: v.add_child(_center(_btn("MAPA: %s" % MAP_INFO[GS.sel_map].name.to_upper(), _maps, 460, true)))
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	solo.grab_focus()

## ARSENAL: personaje y camuflajes
func _arsenal() -> void:
	var v = _page("ARSENAL", _home)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 26); v.add_child(h)
	var ch = _card("res://assets/ui/char_%s.png" % GS.character, "PERSONAJE", "Elige con quién juegas.", Data.CHARACTERS[GS.character].name, false, _chars, 380, 200)
	var ar = _card("res://assets/ui/menu_%s.jpg" % GS.sel_map, "ARMERÍA", "Camuflajes de cada arma: se ganan con bajas.", "", false, _armory, 380, 200)
	h.add_child(ch); h.add_child(ar)
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	ch.grab_focus()

func _options() -> void:
	var v = _page(MAP_INFO[GS.sel_map].name.to_upper(), _play)
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation", 8); v.add_child(_center(list))
	_cycler(list, "Empezar en la ronda", ["1", "5", "10", "15", "20", "25"], str(GS.start_round), "start_round", func(x): GS.start_round = int(x))
	_cycler(list, "Arma inicial", ["m1911", "python", "mp5k", "m16", "galil"], GS.start_weapon, "start_weapon", func(x): GS.start_weapon = x, func(x): return Data.WEAPONS[x].name.to_upper())
	_cycler(list, "Ventaja inicial", ["", "revive", "jugg"], GS.start_perk, "start_perk", func(x): GS.start_perk = x, func(x): return "NINGUNA" if x == "" else Data.PERKS[x].name.to_upper())
	var go = _btn("EMPEZAR PARTIDA", func(): GS.save_game(); main.start_game(), 480, true, 38); v.add_child(_center(go))
	v.add_child(_center(_btn("VOLVER", _play, 300, true)))
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
	var v = _page("ARMERÍA", _arsenal)
	var hint = _lbl("Camuflajes: se desbloquean con bajas de cada arma. Pulsa un arma para cambiarlo.", font_ui, 20, BEIGE); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(hint)
	var sc = ScrollContainer.new(); sc.follow_focus = true; sc.custom_minimum_size = Vector2(1200, 430); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(_center(sc))
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
	v.add_child(_center(_btn("VOLVER", _arsenal, 300, true)))
	first.grab_focus()

func _settings() -> void:
	var v = _page("AJUSTES", func(): GS.save_game(); _home())
	var sc = ScrollContainer.new(); sc.follow_focus = true; sc.custom_minimum_size = Vector2(820, 470); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(_center(sc))
	var first = SettingsList.build(sc, font_bo, font_ui, func(_k): pass)
	v.add_child(_center(_btn("VOLVER", func(): GS.save_game(); _home(), 300, true)))
	first.grab_focus()

# ------------------------------------------------------------------ progreso: camino de recompensas y desafíos
func _progress(tab := 0) -> void:
	var v = _page("PROGRESO", _home)
	v.add_theme_constant_override("separation", 10)
	var tabs = HBoxContainer.new(); tabs.alignment = BoxContainer.ALIGNMENT_CENTER; tabs.add_theme_constant_override("separation", 20); v.add_child(tabs)
	var t0 = MenuStyle.button("RECOMPENSAS", func(): _progress(0), font_bo, 28, 300, true); tabs.add_child(t0)
	var t1 = MenuStyle.button("DESAFÍOS  %d/%d" % [GS.done.size(), Data.CHALLENGES.size()], func(): _progress(1), font_bo, 28, 340, true); tabs.add_child(t1)
	(t0 if tab == 0 else t1).add_theme_color_override("font_color", GOLD)
	# nivel y experiencia
	var need = Data.xp_for_level(GS.level)
	var lv = HBoxContainer.new(); lv.alignment = BoxContainer.ALIGNMENT_CENTER; lv.add_theme_constant_override("separation", 16); v.add_child(lv)
	lv.add_child(_lbl("NIVEL %d" % GS.level, font_bo, 30, GOLD))
	var bar = ProgressBar.new(); bar.max_value = need; bar.value = GS.xp; bar.show_percentage = false; bar.custom_minimum_size = Vector2(520, 14); bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bgs = StyleBoxFlat.new(); bgs.bg_color = Color(0, 0, 0, 0.55); bgs.set_corner_radius_all(7); var fgs = StyleBoxFlat.new(); fgs.bg_color = GOLD; fgs.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bgs); bar.add_theme_stylebox_override("fill", fgs); lv.add_child(bar)
	lv.add_child(_lbl("%d / %d XP" % [GS.xp, need], font_ui, 22, BEIGE))
	if tab == 0: _rewards(v)
	else: _challenge_list(v)
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	(t0 if tab == 0 else t1).grab_focus()

const KIND_NAMES := { "start_weapon": "ARMA INICIAL", "start_round": "RONDA INICIAL", "start_perk": "VENTAJA INICIAL", "character": "PERSONAJE", "title": "TÍTULO", "card": "TARJETA", "points": "PUNTOS", "gum": "CHICLE" }

## camino de niveles con su recompensa (como un pase de batalla, pero para siempre); los títulos y tarjetas se equipan pulsándolos
func _rewards(v: VBoxContainer) -> void:
	var sc = ScrollContainer.new(); sc.follow_focus = true; sc.custom_minimum_size = Vector2(1200, 330); sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(_center(sc))
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 12); sc.add_child(h)
	var cur_card: Control = null
	for u in Data.UNLOCKS:
		if u.level <= 1: continue
		var got = GS.level >= int(u.level)
		var equipped = (u.kind == "title" and GS.title == u.id) or (u.kind == "card" and GS.card == u.id)
		var b = Button.new(); b.custom_minimum_size = Vector2(190, 300); b.focus_mode = Control.FOCUS_ALL
		var sb = StyleBoxFlat.new(); sb.set_corner_radius_all(12); sb.set_border_width_all(3)
		sb.bg_color = Color(0.12, 0.1, 0.06, 0.85) if got else Color(0.05, 0.05, 0.07, 0.8)
		sb.border_color = Color(0.3, 1, 0.45) if equipped else (GOLD if got else Color(1, 1, 1, 0.12))
		if u.kind == "card":
			var cc: Array = Data.CARDS[u.id]; sb.bg_color = cc[1].lerp(cc[0], 0.5) if got else cc[1] * 0.6
		var sf = sb.duplicate(); sf.border_color = RED2
		b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sf); b.add_theme_stylebox_override("focus", sf); b.add_theme_stylebox_override("pressed", sf)
		var c = VBoxContainer.new(); c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.alignment = BoxContainer.ALIGNMENT_CENTER; c.add_theme_constant_override("separation", 8); b.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); c.offset_left = 10; c.offset_right = -10; c.offset_top = 10; c.offset_bottom = -10
		var nl = _lbl("NIVEL %d" % u.level, font_bo, 24, GOLD if got else Color(0.6, 0.58, 0.52)); nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_child(nl)
		if u.kind == "character" and ResourceLoader.exists("res://assets/ui/char_%s.png" % u.id):
			var img = TextureRect.new(); img.texture = load("res://assets/ui/char_%s.png" % u.id); img.custom_minimum_size = Vector2(170, 100); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not got: img.modulate = Color(0.3, 0.3, 0.3)
			c.add_child(img)
		else:
			var ic = _lbl({ "start_weapon": "▲", "start_round": "Ⅴ", "start_perk": "✚", "title": "❝", "card": "▬", "points": "+", "gum": "●" }.get(u.kind, "★"), font_bo, 56, Color.WHITE if got else Color(0.4, 0.4, 0.42))
			ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_child(ic)
		var kn = _lbl(KIND_NAMES.get(u.kind, ""), font_ui, 16, BEIGE); kn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_child(kn)
		var tx = _lbl(u.text.split(": ")[-1], font_bo, 19, Color(0.95, 0.92, 0.86) if got else Color(0.55, 0.55, 0.55)); tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD; tx.custom_minimum_size = Vector2(170, 0); c.add_child(tx)
		var st = _lbl("EQUIPADO" if equipped else ("PULSA PARA EQUIPAR" if got and (u.kind == "title" or u.kind == "card") else ("CONSEGUIDO" if got else "BLOQUEADO")), font_ui, 15, Color(0.3, 1, 0.45) if equipped else (GOLD if got else Color(0.5, 0.5, 0.5)))
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_child(st)
		var uu = u
		b.pressed.connect(func():
			if not got: return
			if uu.kind == "title": GS.title = "" if GS.title == uu.id else uu.id
			elif uu.kind == "card": GS.card = "" if GS.card == uu.id else uu.id
			else: return
			GS.save_game(); _progress(0))
		b.focus_entered.connect(func(): sc.ensure_control_visible(b))
		h.add_child(b)
		if cur_card == null and not got: cur_card = b
	if cur_card:   # empieza mostrando el siguiente premio
		await get_tree().process_frame
		if is_instance_valid(sc) and is_instance_valid(cur_card): sc.scroll_horizontal = int(max(0.0, cur_card.position.x - 400))

func _challenge_list(v: VBoxContainer) -> void:
	var sc = ScrollContainer.new(); sc.follow_focus = true; sc.custom_minimum_size = Vector2(1200, 340); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(_center(sc))
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 10); sc.add_child(g)
	var list = GS.visible_challenges()
	# primero los que faltan (en su orden), al final los completados
	list = list.filter(func(c): return not GS.done.has(c.id)) + list.filter(func(c): return GS.done.has(c.id))
	for c in list:
		var got = GS.done.has(c.id)
		var val = min(GS.stat_value(c.stat), int(c.goal))
		var pc = Button.new(); pc.custom_minimum_size = Vector2(585, 86); pc.focus_mode = Control.FOCUS_ALL
		var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.1, 0.16, 0.08, 0.85) if got else Color(0.06, 0.06, 0.08, 0.82); sb.set_corner_radius_all(10)
		sb.border_width_left = 5; sb.border_color = Color(0.3, 1, 0.45) if got else RED2
		var sf = sb.duplicate(); sf.bg_color = Color(0.78, 0.08, 0.12, 0.25)
		pc.add_theme_stylebox_override("normal", sb); pc.add_theme_stylebox_override("hover", sf); pc.add_theme_stylebox_override("focus", sf); pc.add_theme_stylebox_override("pressed", sf)
		var row = VBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_theme_constant_override("separation", 4); pc.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); row.offset_left = 18; row.offset_right = -14; row.offset_top = 8; row.offset_bottom = -8
		var top = HBoxContainer.new(); top.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(top)
		var tl = _lbl(c.text, font_ui, 22, Color(0.95, 0.92, 0.86)); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(tl)
		var xl = _lbl("+%d XP" % c.xp, font_bo, 20, GOLD); top.add_child(xl)
		var bot = HBoxContainer.new(); bot.mouse_filter = Control.MOUSE_FILTER_IGNORE; bot.add_theme_constant_override("separation", 12); row.add_child(bot)
		var bar = ProgressBar.new(); bar.max_value = int(c.goal); bar.value = val; bar.show_percentage = false; bar.custom_minimum_size = Vector2(0, 10); bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bgs = StyleBoxFlat.new(); bgs.bg_color = Color(1, 1, 1, 0.12); bgs.set_corner_radius_all(5); var fgs = StyleBoxFlat.new(); fgs.bg_color = Color(0.3, 1, 0.45) if got else RED2; fgs.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", bgs); bar.add_theme_stylebox_override("fill", fgs); bot.add_child(bar)
		bot.add_child(_lbl("COMPLETADO" if got else "%d / %d" % [val, c.goal], font_bo, 17, Color(0.3, 1, 0.45) if got else BEIGE))
		pc.focus_entered.connect(func(): sc.ensure_control_visible(pc))
		g.add_child(pc)

# ------------------------------------------------------------------ cooperativo por wifi
var coop_msg = ""
func _coop() -> void:
	Net.start_discovery()
	if not Net.hosts_changed.is_connected(_coop_refresh): Net.hosts_changed.connect(_coop_refresh)
	if not Net.lobby_changed.is_connected(_lobby_refresh): Net.lobby_changed.connect(_lobby_refresh)
	if not Net.join_failed.is_connected(_on_join_failed): Net.join_failed.connect(_on_join_failed)
	if not Net.left.is_connected(_on_left): Net.left.connect(_on_left)
	if Net.active: _lobby(); return
	var v = _page("COOPERATIVO", func(): Net.stop_discovery(); _play())
	v.set_meta("coop", true)
	var info = _lbl("De 2 a 4 jugadores en la misma wifi (iPhone y Android pueden jugar juntos).", font_ui, 21, BEIGE); info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(info)
	var nh = HBoxContainer.new(); nh.alignment = BoxContainer.ALIGNMENT_CENTER; nh.add_theme_constant_override("separation", 12); v.add_child(nh)
	nh.add_child(_lbl("Tu nombre:", font_ui, 24, Color(0.95, 0.92, 0.86)))
	var name_edit = LineEdit.new(); name_edit.text = GS.settings.get("name", Net.my_name); name_edit.custom_minimum_size = Vector2(320, 50); name_edit.max_length = 14
	name_edit.add_theme_font_override("font", font_bo); name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.text_changed.connect(func(t): GS.settings.name = t; Net.my_name = t if t != "" else "Jugador")
	nh.add_child(name_edit)
	var create = _btn("CREAR PARTIDA", func():
		if Net.host(): _lobby()
		else: coop_msg = "No se pudo crear la partida"; _coop(), 460, true)
	v.add_child(_center(create))
	var t = _lbl("PARTIDAS EN TU WIFI", font_bo, 26, GOLD); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var list = VBoxContainer.new(); list.name = "hosts"; list.add_theme_constant_override("separation", 6); v.add_child(_center(list))
	_fill_hosts(list)
	var ih = HBoxContainer.new(); ih.alignment = BoxContainer.ALIGNMENT_CENTER; ih.add_theme_constant_override("separation", 12); v.add_child(ih)
	ih.add_child(_lbl("¿No aparece? IP del anfitrión:", font_ui, 22, BEIGE))
	var ip = LineEdit.new(); ip.placeholder_text = "192.168.1.20"; ip.custom_minimum_size = Vector2(260, 50); ip.add_theme_font_size_override("font_size", 24); ih.add_child(ip)
	ih.add_child(MenuStyle.button("UNIRSE", func(): coop_msg = "Conectando…"; Net.join(ip.text.strip_edges()); _wait_join(), font_bo, 26, 180, true))
	if coop_msg != "":
		var m = _lbl(coop_msg, font_ui, 22, RED2); m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(m)
	v.add_child(_center(_btn("VOLVER", func(): Net.stop_discovery(); _play(), 300, true)))
	create.grab_focus()

func _fill_hosts(list: VBoxContainer) -> void:
	for c in list.get_children(): c.queue_free()
	if Net.hosts.is_empty():
		list.add_child(_lbl("Buscando partidas…", font_ui, 21, Color(0.6, 0.58, 0.52)))
	for ip in Net.hosts:
		var h = Net.hosts[ip]
		var txt = "%s  ·  %s  ·  %d/4" % [str(h.name).to_upper(), MAP_INFO.get(h.map, {"name": h.map}).name.to_upper(), int(h.n)]
		list.add_child(MenuStyle.button(txt, func(): coop_msg = "Conectando…"; Net.join(ip); _wait_join(), font_bo, 24, 620, true))

func _coop_refresh() -> void:
	if page and page.get_child_count() > 0 and page.get_child(0).has_meta("coop"):
		var l = page.find_child("hosts", true, false)
		if l: _fill_hosts(l)

func _wait_join() -> void:
	await get_tree().create_timer(6.0).timeout
	if Net.active and Net.players.is_empty(): Net.leave(); coop_msg = "No hay respuesta. ¿Estáis en la misma wifi?"; _coop()

func _on_join_failed(msg: String) -> void: coop_msg = msg; _coop()
func _on_left() -> void:
	if is_inside_tree(): coop_msg = "Te has desconectado de la partida"; _coop()

## sala: los jugadores, el mapa y (si eres el anfitrión) el botón de empezar
func _lobby() -> void:
	Net.stop_discovery()
	var v = _page("SALA", func(): Net.leave(); coop_msg = ""; _coop())
	v.set_meta("lobby", true)
	if Net.is_host():
		var ipl = _lbl("Tu IP para que se unan: %s" % Net.local_ip(), font_ui, 22, GOLD); ipl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ipl)
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation", 6); v.add_child(_center(list))
	var ids = Net.players.keys(); ids.sort()
	for id in ids:
		var pl = Net.players[id]
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 16)
		var img = TextureRect.new(); img.custom_minimum_size = Vector2(120, 64); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var cp = "res://assets/ui/char_%s.png" % pl.character
		if ResourceLoader.exists(cp): img.texture = load(cp)
		row.add_child(img)
		row.add_child(_lbl("%s%s  ·  nivel %d" % [str(pl.name).to_upper(), "  (anfitrión)" if id == 1 else "", int(pl.get("level", 1))], font_bo, 26, Color(1, 0.82, 0.48) if id == Net.my_id() else Color(0.92, 0.9, 0.85)))
		list.add_child(row)
	var mh = HBoxContainer.new(); mh.alignment = BoxContainer.ALIGNMENT_CENTER; mh.add_theme_constant_override("separation", 20); v.add_child(mh)
	mh.add_child(_lbl("Mapa: %s  ·  Ronda %d" % [MAP_INFO.get(Net.lobby.map, {"name": "?"}).name.to_upper(), int(Net.lobby.start_round)], font_bo, 26, GOLD))
	var first: Control = null
	if Net.is_host():
		var cm = MenuStyle.button("CAMBIAR MAPA", func():
			var i = Data.MAPS.find(Net.lobby.map); Net.set_lobby(Data.MAPS[(i + 1) % Data.MAPS.size()], int(Net.lobby.start_round)), font_bo, 24, 300, true)
		mh.add_child(cm)
		var go = _btn("EMPEZAR PARTIDA", func():
			if Net.players.size() < 2: coop_msg = ""; _toast_lobby("Espera a que se una alguien (o juega en solitario)"); return
			Net.start_match(), 480, true, 36)
		v.add_child(_center(go)); first = go
	else:
		var w = _lbl("Esperando a que el anfitrión empiece…", font_ui, 22, BEIGE); w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(w)
	var ch = _btn("PERSONAJE: %s" % Data.CHARACTERS[GS.character].name.to_upper(), func():
		var ok = Data.CHARACTERS.keys().filter(func(k): return GS.level >= int(Data.CHARACTERS[k].level))
		GS.character = ok[(ok.find(GS.character) + 1) % ok.size()]; GS.save_game()
		if Net.is_host(): Net.set_character(GS.character)
		else: Net.set_character.rpc_id(1, GS.character)
		_lobby(), 460, true, 28)
	v.add_child(_center(ch))
	v.add_child(_center(_btn("SALIR DE LA SALA", func(): Net.leave(); coop_msg = ""; _coop(), 360, true)))
	(first if first else ch).grab_focus()

func _toast_lobby(t: String) -> void:
	var l = _lbl(t, font_ui, 22, RED2); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); l.offset_top = -80; l.offset_left = -500; l.offset_right = 500
	page.add_child(l)
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())

func _lobby_refresh() -> void:
	if not is_inside_tree(): return
	if Net.active and not Net.players.is_empty(): _lobby()

func _credits() -> void:
	var v = _page("CRÉDITOS", _home)
	var f = FileAccess.open("res://assets/CREDITOS.txt", FileAccess.READ)
	var sc = ScrollContainer.new(); sc.follow_focus = true; sc.custom_minimum_size = Vector2(1100, 440); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(_center(sc))
	var l = _lbl(f.get_as_text() if f else "", font_ui, 19, Color(0.88, 0.85, 0.78)); l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size = Vector2(1080, 0); sc.add_child(l)
	var back = _btn("VOLVER", _home, 300, true); v.add_child(_center(back)); back.grab_focus()
