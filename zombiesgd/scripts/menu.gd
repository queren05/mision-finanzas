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
	"pueblo": { "name": "Pueblo", "desc": "Un cruce de un pueblo americano en llamas: el banco, el bar, el diner y la gasolinera. Cuidado con la lava del cruce." },
	"puerto": { "name": "Puerto Viejo", "desc": "La terminal de contenedores donde Gamba Roja montó su Planta 2: el muelle, las calles entre contenedores, las oficinas, los camiones y la cámara frigorífica." },
	"villa": { "name": "Villa Coral", "desc": "Mapa de prueba en estilo low-poly: el cruce, la Calle Mayor, el bar, la granja, la estación de tren y el bosque." },
	"conservera": { "name": "La Conservera", "desc": "La fábrica de Gamba Roja junto al puerto, de noche: el muelle, el patio de carga, la nave de procesado, los depósitos y un laboratorio secreto." },

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
## como el vestíbulo de los shooters actuales: arriba el logo y tu tarjeta de jugador; a la izquierda los modos en
## tarjetas grandes con imagen (la historia, la primera: continúa donde lo dejaste); a la derecha tu personaje;
## abajo, una barra con el resto de secciones
func _home() -> void:
	_clear(true); back_cb = Callable()
	var m = MenuStyle.safe_margins(get_viewport())
	var vs = get_viewport().get_visible_rect().size
	# --- arriba a la izquierda: el logo
	var logo = VBoxContainer.new(); logo.add_theme_constant_override("separation", -18); page.add_child(logo)
	logo.position = Vector2(m.x, 14)
	logo.add_child(_lbl("SHRIMP", font_bo, 30, Color(1, 0.6, 0.48)))
	var logo2 = _lbl("ZOMBIES", font_bo, 66, RED2); logo2.add_theme_color_override("font_outline_color", Color(0.25, 0, 0)); logo2.add_theme_constant_override("outline_size", 4); logo.add_child(logo2)
	# --- arriba a la derecha: tarjeta de jugador (título, nivel y experiencia)
	var card = _player_card(); page.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); card.offset_left = -m.y - 420; card.offset_right = -m.y; card.offset_top = 18; card.offset_bottom = 118
	# --- a la izquierda: los modos
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 12); page.add_child(col)
	var cw = clamp(vs.x * 0.44, 520.0, 700.0)
	col.position = Vector2(m.x, 128); col.custom_minimum_size = Vector2(cw, 0)
	var nxt = _next_mission()
	var mi: Dictionary = Campaign.MISSIONS[nxt]
	var st = int(GS.campaign.get(mi.id, 0))
	var sub = ("CONTINUAR · " if nxt > 0 else "EMPEZAR · ") + "%d. %s" % [nxt + 1, String(mi.name).to_upper()]
	if st > 0: sub = "%d/%d MISIONES COMPLETADAS" % [GS.campaign.size(), Campaign.MISSIONS.size()]
	var story = _tile("res://assets/ui/menu_%s.jpg" % mi.map, "HISTORIA", sub, "Operación Gamba Roja", _story, Vector2(cw, 214), 46)
	col.add_child(story)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 12); col.add_child(row)
	var b = int(GS.best.get(GS.sel_map, 0))
	var waves = _tile("res://assets/ui/menu_%s.jpg" % GS.sel_map, "OLEADAS", MAP_INFO[GS.sel_map].name.to_upper(), ("Récord: ronda %d" % b) if b > 0 else "Sin récord", _play, Vector2((cw - 12) / 2.0, 150), 32)
	var coop = _tile("res://assets/ui/menu_pueblo.jpg", "COOPERATIVO", "2 A 4 JUGADORES", "Misma wifi · móvil y PC", _coop, Vector2((cw - 12) / 2.0, 150), 32)
	row.add_child(waves); row.add_child(coop)
	# --- a la derecha: tu personaje, grande, con lo siguiente que se desbloquea
	var right = VBoxContainer.new(); right.alignment = BoxContainer.ALIGNMENT_END; page.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE); right.offset_left = -m.y - 420; right.offset_right = -m.y; right.offset_top = 124; right.offset_bottom = -96
	var cimg = TextureRect.new(); cimg.size_flags_vertical = Control.SIZE_EXPAND_FILL; cimg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; cimg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cp = "res://assets/ui/char_%s.png" % GS.character
	if ResourceLoader.exists(cp): cimg.texture = load(cp)
	right.add_child(cimg)
	var cbtn = MenuStyle.button(Data.CHARACTERS[GS.character].name.to_upper() + "  ›", _chars, font_bo, 24, 420, true); right.add_child(cbtn)
	for u in Data.UNLOCKS:
		if u.level > GS.level:
			var nx = _lbl("Nivel %d: %s" % [u.level, u.text], font_ui, 19, BEIGE); nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; right.add_child(nx); break
	# --- abajo: barra de secciones
	var bar = PanelContainer.new(); var bsb = StyleBoxFlat.new(); bsb.bg_color = Color(0.02, 0.02, 0.03, 0.82); bsb.border_width_top = 2; bsb.border_color = Color(1, 0.165, 0.165, 0.55)
	bar.add_theme_stylebox_override("panel", bsb); page.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bar.offset_top = -78
	var bh = HBoxContainer.new(); bh.alignment = BoxContainer.ALIGNMENT_CENTER; bh.add_theme_constant_override("separation", 6); bar.add_child(bh)
	var items = [["ARSENAL", _arsenal, "Armas y personaje"], ["PROGRESO", _progress, "Desafíos %d/%d" % [GS.done.size(), Data.CHALLENGES.size()]],
		["DOCUMENTOS", _docs, "%d encontrados" % GS.intel.size()], ["AJUSTES", _settings, "Gráficos y controles"], ["CRÉDITOS", _credits, ""]]
	for it in items: bh.add_child(_bar_btn(it[0], it[2], it[1], clamp((vs.x - m.x - m.y) / items.size() - 8, 170.0, 260.0)))
	if Input.get_connected_joypads().size() > 0:
		var hint = _lbl("A elegir · B volver", font_ui, 16, Color(0.6, 0.58, 0.52)); page.add_child(hint)
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT); hint.offset_left = -m.y - 170; hint.offset_top = -102; hint.offset_bottom = -82
	story.grab_focus()

## la primera misión sin completar (o la última, si están todas)
func _next_mission() -> int:
	for i in Campaign.MISSIONS.size():
		if not GS.campaign.has(Campaign.MISSIONS[i].id): return i
	return Campaign.MISSIONS.size() - 1

## tarjeta de jugador: título, nivel y barra de experiencia
func _player_card() -> Control:
	var pc = PanelContainer.new(); var cc: Array = Data.CARDS.get(GS.card, Data.CARDS[""])
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(cc[0].r * 0.35, cc[0].g * 0.35, cc[0].b * 0.35, 0.85); sb.border_width_left = 6; sb.border_color = GOLD
	sb.set_corner_radius_all(4); sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 6; sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 14); pc.add_child(h)
	var lv = _lbl(str(GS.level), font_bo, 58, GOLD); lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; lv.custom_minimum_size.x = 74; lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h.add_child(lv)
	var v = VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 2); v.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(v)
	v.add_child(_lbl(Data.TITLES.get(GS.title, "Recluta").to_upper(), font_bo, 24, Color.WHITE))
	var need = Data.xp_for_level(GS.level)
	var bar = ProgressBar.new(); bar.max_value = need; bar.value = GS.xp; bar.show_percentage = false; bar.custom_minimum_size = Vector2(0, 10)
	var bgs = StyleBoxFlat.new(); bgs.bg_color = Color(0, 0, 0, 0.6); bgs.set_corner_radius_all(5); var fgs = StyleBoxFlat.new(); fgs.bg_color = GOLD; fgs.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bgs); bar.add_theme_stylebox_override("fill", fgs); v.add_child(bar)
	v.add_child(_lbl("NIVEL %d  ·  %d / %d XP" % [GS.level, GS.xp, need], font_ui, 17, BEIGE))
	return pc

## tarjeta grande de modo: imagen de fondo, degradado oscuro abajo, título grande y dos líneas
func _tile(img_path: String, title: String, sub: String, foot: String, cb: Callable, sz: Vector2, title_size: int) -> Button:
	var b = Button.new(); b.custom_minimum_size = sz; b.focus_mode = Control.FOCUS_ALL; b.clip_contents = true
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0); sb.border_color = Color(1, 1, 1, 0.18); sb.set_border_width_all(2); sb.set_corner_radius_all(6)
	var sf = sb.duplicate(); sf.border_color = RED2; sf.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sf); b.add_theme_stylebox_override("focus", sf); b.add_theme_stylebox_override("pressed", sf)
	var img = TextureRect.new(); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(img_path): img.texture = load(img_path)
	b.add_child(img); img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); img.show_behind_parent = true
	var g = Gradient.new(); g.offsets = PackedFloat32Array([0.0, 0.45, 1.0]); g.colors = PackedColorArray([Color(0, 0, 0, 0.92), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)])
	var gt = GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 1); gt.fill_to = Vector2(0, 0); gt.width = 4; gt.height = 64
	var shade = TextureRect.new(); shade.texture = gt; shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; shade.stretch_mode = TextureRect.STRETCH_SCALE; shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.show_behind_parent = true
	var v = VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_END; v.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_theme_constant_override("separation", -4); b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); v.offset_left = 16; v.offset_right = -16; v.offset_bottom = -10
	var t = _lbl(title, font_bo, title_size, Color.WHITE); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(t)
	var s = _lbl(sub, font_bo, 19 if title_size > 40 else 16, Color(1.0, 0.62, 0.15)); s.mouse_filter = Control.MOUSE_FILTER_IGNORE; s.clip_text = true; v.add_child(s)
	if foot != "":
		var f = _lbl(foot, font_ui, 17, Color(0.85, 0.82, 0.76)); f.mouse_filter = Control.MOUSE_FILTER_IGNORE; f.clip_text = true; v.add_child(f)
	# al seleccionarla se ilumina un poco
	b.focus_entered.connect(func(): img.modulate = Color(1.15, 1.1, 1.05); Sfx.play("click", 0.25))
	b.focus_exited.connect(func(): img.modulate = Color.WHITE)
	b.mouse_entered.connect(func(): img.modulate = Color(1.15, 1.1, 1.05))
	b.mouse_exited.connect(func(): if not b.has_focus(): img.modulate = Color.WHITE)
	b.pressed.connect(cb)
	return b

## botón de la barra de abajo: nombre y una línea de información
func _bar_btn(title: String, info: String, cb: Callable, w: float) -> Button:
	var b = Button.new(); b.custom_minimum_size = Vector2(w, 70); b.focus_mode = Control.FOCUS_ALL
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0); sb.content_margin_top = 6
	var sf = StyleBoxFlat.new(); sf.bg_color = Color(0.78, 0.08, 0.12, 0.35); sf.border_width_top = 4; sf.border_color = RED2
	b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sf); b.add_theme_stylebox_override("focus", sf); b.add_theme_stylebox_override("pressed", sf)
	var v = VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_theme_constant_override("separation", -2); b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var t = _lbl(title, font_bo, 24, Color(0.92, 0.9, 0.84)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(t)
	if info != "":
		var i = _lbl(info, font_ui, 15, BEIGE); i.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; i.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(i)
	b.focus_entered.connect(func(): Sfx.play("click", 0.25))
	b.pressed.connect(cb)
	return b

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
	var v = _page("PERSONAJE", _home)
	var row = HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 30); v.add_child(row)
	var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 12); g.add_theme_constant_override("v_separation", 12); row.add_child(g)
	# a la derecha, el personaje señalado en grande con su descripción
	var info = VBoxContainer.new(); info.custom_minimum_size = Vector2(420, 0); info.add_theme_constant_override("separation", 4); row.add_child(info)
	var big = TextureRect.new(); big.custom_minimum_size = Vector2(420, 300); big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; info.add_child(big)
	var nm = _lbl("", font_bo, 34, Color(1, 0.82, 0.48)); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; info.add_child(nm)
	var ds = _lbl("", font_ui, 20, Color(0.9, 0.86, 0.78)); ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ds.custom_minimum_size = Vector2(420, 0); info.add_child(ds)
	var stt = _lbl("", font_bo, 20, GOLD); stt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; info.add_child(stt)
	var first: Control = null
	for id in Data.CHARACTERS:
		var c = Data.CHARACTERS[id]
		var ok = GS.level >= int(c.level)
		var state = "ELEGIDO" if id == GS.character else ("PULSA PARA ELEGIR" if ok else "SE DESBLOQUEA EN EL NIVEL %d" % c.level)
		var b = Button.new(); b.custom_minimum_size = Vector2(170, 150); b.focus_mode = Control.FOCUS_ALL
		var sb = StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.06); sb.border_color = GOLD if id == GS.character else Color(1, 1, 1, 0.15); sb.set_border_width_all(3); sb.set_corner_radius_all(8)
		var sf = sb.duplicate(); sf.border_color = RED2; sf.bg_color = Color(0.78, 0.08, 0.12, 0.25)
		b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sf); b.add_theme_stylebox_override("focus", sf); b.add_theme_stylebox_override("pressed", sf)
		var tex = load("res://assets/ui/char_%s.png" % id)
		var im = TextureRect.new(); im.texture = tex; im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; im.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(im); im.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); im.offset_left = 8; im.offset_right = -8; im.offset_top = 8; im.offset_bottom = -30
		var l = _lbl(c.name.to_upper(), font_bo, 13, Color(0.95, 0.92, 0.85)); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.mouse_filter = Control.MOUSE_FILTER_IGNORE; l.clip_text = true
		b.add_child(l); l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); l.offset_top = -28; l.offset_bottom = -4
		if not ok: b.modulate = Color(0.45, 0.45, 0.45)
		var show = func(): big.texture = tex; nm.text = c.name.to_upper(); ds.text = c.desc; stt.text = state
		b.focus_entered.connect(show); b.mouse_entered.connect(show)
		b.pressed.connect(func():
			if ok: GS.character = id; GS.save_game(); _chars())
		g.add_child(b)
		if id == GS.character or first == null: first = b
	var hint = _lbl("Se ve en tercera persona (Ajustes → Vista, o en la pausa).", font_ui, 18, BEIGE); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(hint)
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

## JUGAR: en solitario o cooperativo (y el mapa, si hay más de uno)
func _play() -> void:
	var v = _page("OLEADAS", _home)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 26); v.add_child(h)
	var bb = int(GS.best.get(GS.sel_map, 0))
	var solo = _tile("res://assets/ui/menu_%s.jpg" % GS.sel_map, "EN SOLITARIO", MAP_INFO[GS.sel_map].name.to_upper(), "Elige ronda, arma y ventaja · " + (("récord: ronda %d" % bb) if bb > 0 else "sin récord"), _options, Vector2(440, 280), 38)
	var coop = _tile("res://assets/ui/menu_pueblo.jpg", "COOPERATIVO", "2 A 4 JUGADORES", "Misma wifi · iPhone, Android y PC juntos", _coop, Vector2(440, 280), 38)
	h.add_child(solo); h.add_child(coop)
	if Data.MAPS.size() > 1: v.add_child(_center(_btn("MAPA: %s" % MAP_INFO[GS.sel_map].name.to_upper(), _maps, 460, true)))
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	solo.grab_focus()

## HISTORIA: misiones de la campaña «Operación Gamba Roja» (se desbloquean en orden); la descripción de la elegida, debajo
func _story() -> void:
	var v = _page("HISTORIA", _home)
	v.add_theme_constant_override("separation", 14)
	var sub = _lbl("OPERACIÓN GAMBA ROJA", font_bo, 24, Color(1.0, 0.62, 0.15)); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sub)
	var vs = get_viewport().get_visible_rect().size
	var n = Campaign.MISSIONS.size() + 1
	var w = clamp((vs.x - 160.0 - 14.0 * (n - 1)) / n, 200.0, 300.0)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 14); v.add_child(h)
	var desc = _lbl("", font_ui, 22, Color(0.92, 0.88, 0.8)); desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(min(vs.x - 200.0, 1000.0), 70)
	var first: Control = null
	var i = 0
	for m in Campaign.MISSIONS:
		var unlocked = i == 0 or GS.campaign.has(Campaign.MISSIONS[i - 1].id)
		var st = int(GS.campaign.get(m.id, 0))
		var foot = ("★".repeat(st) + "☆".repeat(3 - st)) if st > 0 else ("NUEVA" if unlocked else "BLOQUEADA")
		var nd: int = m.get("intel", []).size()
		if nd > 0 and unlocked:
			var fd = 0
			for k in nd: if GS.intel.has("%s_%d" % [m.id, k]): fd += 1
			foot += "  ·  Docs %d/%d" % [fd, nd]
		var mid = m.id; var mmap = m.map
		var go = func():
			if not unlocked: return
			GS.mode = "historia"; GS.mission = mid; GS.sel_map = mmap; GS.checkpoint = 0; GS.save_game(); main.start_game()
		var card = _tile("res://assets/ui/menu_%s.jpg" % m.map, "MISIÓN %d" % (i + 1), String(m.name).to_upper(), foot, go, Vector2(w, 300), 30)
		if not unlocked: card.modulate = Color(0.55, 0.55, 0.55)
		var text = String(m.desc) if unlocked else "Completa la misión anterior para desbloquearla."
		card.focus_entered.connect(func(): desc.text = text)
		card.mouse_entered.connect(func(): desc.text = text)
		h.add_child(card)
		if first == null and unlocked and st == 0: first = card
		i += 1
	var soon = _tile("res://assets/ui/menu_conservera.jpg", "MISIÓN 5", "LA ISLA DEL FARO", "Próximamente", func(): pass, Vector2(w, 300), 30)
	soon.modulate = Color(0.45, 0.45, 0.5); soon.focus_mode = Control.FOCUS_NONE; h.add_child(soon)
	v.add_child(_center(desc))
	var brow = HBoxContainer.new(); brow.alignment = BoxContainer.ALIGNMENT_CENTER; brow.add_theme_constant_override("separation", 24); v.add_child(brow)
	brow.add_child(_btn("DOCUMENTOS", _docs.bind(true), 300, true)); brow.add_child(_btn("VOLVER", _home, 300, true))
	if first == null: first = h.get_child(0)
	first.grab_focus()

## documentos encontrados en las misiones (la historia de Gamba Roja)
func _docs(from_story := false) -> void:
	var back_to = _story if from_story else _home
	var v = _page("DOCUMENTOS", back_to)
	var sc = ScrollContainer.new(); sc.custom_minimum_size = Vector2(1100, 560); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var c = CenterContainer.new(); c.add_child(sc); v.add_child(c)
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation", 10); list.custom_minimum_size.x = 1060; sc.add_child(list)
	var i = 0
	for m in Campaign.MISSIONS:
		i += 1
		var head = _lbl("%d. %s" % [i, String(m.name).to_upper()], font_bo, 26, Color(1.0, 0.62, 0.15)); list.add_child(head)
		var docs: Array = m.get("intel", [])
		for k in docs.size():
			var got = GS.intel.has("%s_%d" % [m.id, k])
			var t = _lbl(("· " + String(docs[k].title)) if got else "· ??? (sin encontrar)", font_ui, 24, Color(0.95, 0.92, 0.85) if got else Color(0.5, 0.48, 0.45)); list.add_child(t)
			if got:
				var x = _lbl(String(docs[k].text), font_ui, 20, Color(0.75, 0.72, 0.66)); x.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; x.custom_minimum_size.x = 1020; list.add_child(x)
	var back = _btn("VOLVER", back_to, 300, true); v.add_child(_center(back)); back.grab_focus()

## ARSENAL: personaje y camuflajes
func _arsenal() -> void:
	var v = _page("ARSENAL", _home)
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 26); v.add_child(h)
	var ch = _tile("res://assets/ui/menu_prison.jpg", "PERSONAJE", Data.CHARACTERS[GS.character].name.to_upper(), "Elige con quién juegas", _chars, Vector2(440, 280), 38)
	var cimg = TextureRect.new(); cimg.texture = load("res://assets/ui/char_%s.png" % GS.character); cimg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; cimg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; cimg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cimg); cimg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); cimg.offset_left = 200; cimg.offset_top = 8; cimg.offset_bottom = -8; cimg.show_behind_parent = true
	ch.move_child(cimg, 1)
	var ar = _tile("res://assets/ui/menu_puerto.jpg", "ARMERÍA", "CAMUFLAJES", "Se ganan con bajas de cada arma", _armory, Vector2(440, 280), 38)
	h.add_child(ch); h.add_child(ar)
	v.add_child(_center(_btn("VOLVER", _home, 300, true)))
	ch.grab_focus()

func _options() -> void:
	var v = _page(MAP_INFO[GS.sel_map].name.to_upper(), _play)
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation", 8); v.add_child(_center(list))
	_cycler(list, "Empezar en la ronda", ["1", "5", "10", "15", "20", "25"], str(GS.start_round), "start_round", func(x): GS.start_round = int(x))
	_cycler(list, "Arma inicial", ["m1911", "python", "mp5k", "m16", "galil"], GS.start_weapon, "start_weapon", func(x): GS.start_weapon = x, func(x): return Data.WEAPONS[x].name.to_upper())
	_cycler(list, "Ventaja inicial", ["", "revive", "jugg"], GS.start_perk, "start_perk", func(x): GS.start_perk = x, func(x): return "NINGUNA" if x == "" else Data.PERKS[x].name.to_upper())
	var go = _btn("EMPEZAR PARTIDA", func(): GS.mode = "oleadas"; GS.save_game(); main.start_game(), 480, true, 38); v.add_child(_center(go))
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
	var sc = ScrollContainer.new(); sc.follow_focus = true; sc.custom_minimum_size = Vector2(820, 440); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	SettingsList.build(sc, font_bo, font_ui, func(_k): pass)
	var bar = SettingsList.tabs(sc, font_bo); v.add_child(bar); v.add_child(_center(sc))
	v.add_child(_center(_btn("VOLVER", func(): GS.save_game(); _home(), 300, true)))
	bar.get_child(0).grab_focus()

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
