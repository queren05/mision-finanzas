extends Control
## Menú principal estilo Black Ops: jugar (mapa y opciones de partida), armería (camuflajes), ajustes y créditos.

var main: Node
var font_bo: Font
var font_ui: Font
var page: Control
var bg: TextureRect
var t = 0.0

func _set_bg(id: String) -> void:
	var p = "res://assets/ui/menu_%s.jpg" % id
	if ResourceLoader.exists(p): bg.texture = load(p)

func _process(d: float) -> void:
	t += d; if bg: bg.position = Vector2(sin(t * 0.05) * 18.0 - 18.0, cos(t * 0.04) * 10.0 - 10.0); bg.scale = Vector2.ONE * 1.04
const MAP_INFO := {
	"prison": { "name": "Penitenciaría", "desc": "Una cárcel de máxima seguridad tomada por los muertos. Patios, pistas valladas y el bloque de celdas." },
	"postwar": { "name": "Ciudad en Ruinas", "desc": "Una manzana arrasada por la guerra: calles, plazas y edificios destrozados." },
	"mansion": { "name": "La Mansión", "desc": "Biblioteca, salones y un largo pasillo. Cada puerta que abras deja entrar a más." },
	"isla": { "name": "Isla Gamba", "desc": "La cabaña, el muelle y el faro de la isla. El clásico de siempre." },
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font_bo = load("res://assets/fonts/BlackOpsOne.ttf"); font_ui = load("res://assets/fonts/Oswald.ttf")
	bg = TextureRect.new(); bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_bg(GS.sel_map)
	var shade = ColorRect.new(); add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh = Shader.new(); sh.code = "shader_type canvas_item; void fragment(){ float v = smoothstep(0.0, 0.75, UV.x); COLOR = vec4(0.02, 0.02, 0.03, mix(0.88, 0.35, v)); }"
	var sm = ShaderMaterial.new(); sm.shader = sh; shade.material = sm
	_home()

func _clear() -> void:
	if page: page.queue_free()
	page = Control.new(); add_child(page); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _lbl(text: String, f: Font, size: int, c: Color) -> Label:
	var l = Label.new(); l.text = text; l.add_theme_font_override("font", f); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8)); l.add_theme_constant_override("shadow_offset_y", 3)
	return l

func _btn(text: String, cb: Callable, w := 360, enabled := true) -> Button:
	var b = Button.new(); b.text = text; b.add_theme_font_override("font", font_bo); b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(w, 58); b.pressed.connect(cb); b.disabled = not enabled; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.06, 0.06, 0.08, 0.75); sb.border_color = Color(0.45, 0.06, 0.06); sb.border_width_left = 5; sb.content_margin_left = 18
	b.add_theme_stylebox_override("normal", sb); var h = sb.duplicate(); h.bg_color = Color(0.4, 0.04, 0.04, 0.9); h.border_color = Color(1, 0.3, 0.2)
	b.add_theme_stylebox_override("hover", h); b.add_theme_stylebox_override("focus", h); b.add_theme_stylebox_override("pressed", h)
	var d = sb.duplicate(); d.bg_color = Color(0.05, 0.05, 0.05, 0.5); b.add_theme_stylebox_override("disabled", d)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
	return b

func _header(title: String) -> VBoxContainer:
	_clear()
	var v = VBoxContainer.new(); v.position = Vector2(70, 50); v.add_theme_constant_override("separation", 12); page.add_child(v)
	var tl = _lbl(title, font_bo, 64, Color(0.85, 0.12, 0.1)); v.add_child(tl)
	# nivel y experiencia
	var lv = _lbl("NIVEL %d   ·   %d / %d XP" % [GS.level, GS.xp, Data.xp_for_level(GS.level)], font_ui, 20, Color(1, 0.85, 0.4))
	page.add_child(lv); lv.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); lv.offset_left = -420; lv.offset_top = 30; lv.offset_right = -40; lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return v

func _home() -> void:
	var v = _header("SHRIMP ZOMBIES")
	v.add_child(_btn("JUGAR", _maps))
	v.add_child(_btn("ARMERÍA", _armory))
	v.add_child(_btn("AJUSTES", _settings))
	v.add_child(_btn("CRÉDITOS", _credits))
	v.get_child(1).grab_focus()

func _maps() -> void:
	var v = _header("ELIGE MAPA")
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 16); v.add_child(h)
	for id in Data.MAPS:
		if not FileAccess.file_exists("res://assets/maps/%s/map.json" % id) and not ResourceLoader.exists("res://assets/maps/%s/map.json" % id): continue
		var card = VBoxContainer.new(); card.custom_minimum_size = Vector2(270, 0); h.add_child(card)
		var img = TextureRect.new(); img.custom_minimum_size = Vector2(270, 152); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var p = "res://assets/ui/menu_%s.jpg" % id
		if ResourceLoader.exists(p): img.texture = load(p)
		card.add_child(img)
		var b = _btn(MAP_INFO[id].name.to_upper(), func(): GS.sel_map = id; _set_bg(id); _options(), 270); b.add_theme_font_size_override("font_size", 22); card.add_child(b)
		var d = _lbl(MAP_INFO[id].desc, font_ui, 16, Color(0.85, 0.82, 0.75)); d.autowrap_mode = TextServer.AUTOWRAP_WORD; d.custom_minimum_size = Vector2(270, 70); card.add_child(d)
		var best = _lbl("Récord: ronda %d" % int(GS.best.get(id, 0)) if GS.best.has(id) else "Sin récord", font_ui, 16, Color(1, 0.85, 0.4)); card.add_child(best)
	v.add_child(_btn("VOLVER", _home))
	h.get_child(0).get_child(1).grab_focus()

func _options() -> void:
	var v = _header(MAP_INFO[GS.sel_map].name.to_upper())
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 20); g.add_theme_constant_override("v_separation", 10); v.add_child(g)
	g.add_child(_lbl("Empezar en la ronda", font_ui, 24, Color.WHITE))
	g.add_child(_cycler(["1", "5", "10", "15", "20", "25"], str(GS.start_round), "start_round", func(x): GS.start_round = int(x)))
	g.add_child(_lbl("Arma inicial", font_ui, 24, Color.WHITE))
	g.add_child(_cycler(["m1911", "python", "mp5k", "m16", "galil"], GS.start_weapon, "start_weapon", func(x): GS.start_weapon = x, func(x): return Data.WEAPONS[x].name))
	g.add_child(_lbl("Ventaja inicial", font_ui, 24, Color.WHITE))
	g.add_child(_cycler(["", "revive", "jugg"], GS.start_perk, "start_perk", func(x): GS.start_perk = x, func(x): return "Ninguna" if x == "" else Data.PERKS[x].name))
	var hint = _lbl("Sube de nivel para desbloquear más opciones (como en Black Ops 4).", font_ui, 18, Color(0.75, 0.72, 0.65)); v.add_child(hint)
	var go = _btn("EMPEZAR PARTIDA", func(): GS.save_game(); main.start_game()); v.add_child(go)
	v.add_child(_btn("VOLVER", _maps))
	go.grab_focus()

## selector que solo deja elegir lo desbloqueado
func _cycler(opts: Array, cur: String, kind: String, set_cb: Callable, label_cb := Callable()) -> Button:
	var avail = opts.filter(func(o): return GS.is_unlocked(kind, o))
	if not cur in avail: cur = avail[0]; set_cb.call(cur)
	var name_of = func(o): return label_cb.call(o) if label_cb.is_valid() else o
	var b = _btn(str(name_of.call(cur)), func(): pass, 300)
	b.pressed.connect(func():
		var i = avail.find(b.get_meta("v")); var nx: String = avail[(i + 1) % avail.size()]
		b.set_meta("v", nx); b.text = str(name_of.call(nx)); set_cb.call(nx))
	b.set_meta("v", cur)
	var locked = opts.size() - avail.size()
	if locked > 0: b.tooltip_text = "%d bloqueadas" % locked
	return b

func _armory() -> void:
	var v = _header("ARMERÍA")
	v.add_child(_lbl("Camuflajes: se desbloquean con bajas de cada arma.", font_ui, 20, Color(0.8, 0.78, 0.7)))
	var sc = ScrollContainer.new(); sc.custom_minimum_size = Vector2(1100, 470); v.add_child(sc)
	var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 8); sc.add_child(g)
	for id in Data.WEAPONS:
		var kills = int(GS.weapon_kills.get(id, 0))
		var cam = GS.camo_of(id)
		var b = _btn("%s  ·  %s  (%d bajas)" % [Data.WEAPONS[id].name, cam.name, kills], func(): pass, 360)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			var unlocked = Data.CAMOS.filter(func(c): return GS.camo_unlocked(id, c.id))
			var i = -1
			for k in unlocked.size():
				if unlocked[k].id == GS.camo_of(id).id: i = k
			var nx: Dictionary = unlocked[(i + 1) % unlocked.size()]
			GS.camo[id] = nx.id; GS.save_game()
			b.text = "%s  ·  %s  (%d bajas)" % [Data.WEAPONS[id].name, nx.name, kills])
		g.add_child(b)
	v.add_child(_btn("VOLVER", _home))

func _settings() -> void:
	var v = _header("AJUSTES")
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 20); g.add_theme_constant_override("v_separation", 10); v.add_child(g)
	g.add_child(_lbl("Sensibilidad", font_ui, 24, Color.WHITE)); g.add_child(_slider(0.3, 2.5, float(GS.settings.sens), func(x): GS.settings.sens = x))
	g.add_child(_lbl("Campo de visión", font_ui, 24, Color.WHITE)); g.add_child(_slider(60, 95, float(GS.settings.fov), func(x): GS.settings.fov = x))
	g.add_child(_lbl("Efectos de sonido", font_ui, 24, Color.WHITE)); g.add_child(_slider(0, 1, float(GS.settings.sfx), func(x): GS.settings.sfx = x))
	g.add_child(_lbl("Ambiente", font_ui, 24, Color.WHITE)); g.add_child(_slider(0, 1, float(GS.settings.music), func(x): GS.settings.music = x))
	g.add_child(_lbl("Invertir eje vertical", font_ui, 24, Color.WHITE))
	var inv = _btn("SÍ" if GS.settings.invert else "NO", func(): pass, 300); inv.pressed.connect(func(): GS.settings.invert = not GS.settings.invert; inv.text = "SÍ" if GS.settings.invert else "NO"); g.add_child(inv)
	g.add_child(_lbl("Ayuda al apuntar", font_ui, 24, Color.WHITE))
	var aa = _btn("SÍ" if GS.settings.aim_assist else "NO", func(): pass, 300); aa.pressed.connect(func(): GS.settings.aim_assist = not GS.settings.aim_assist; aa.text = "SÍ" if GS.settings.aim_assist else "NO"); g.add_child(aa)
	v.add_child(_btn("VOLVER", func(): GS.save_game(); _home()))

func _slider(a: float, b: float, val: float, cb: Callable) -> HSlider:
	var s = HSlider.new(); s.min_value = a; s.max_value = b; s.step = (b - a) / 100.0; s.value = val; s.custom_minimum_size = Vector2(300, 40); s.value_changed.connect(cb)
	return s

func _credits() -> void:
	var v = _header("CRÉDITOS")
	var f = FileAccess.open("res://assets/CREDITOS.txt", FileAccess.READ)
	var sc = ScrollContainer.new(); sc.custom_minimum_size = Vector2(1100, 470); v.add_child(sc)
	var l = _lbl(f.get_as_text() if f else "", font_ui, 18, Color(0.85, 0.82, 0.75)); l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size = Vector2(1080, 0); sc.add_child(l)
	v.add_child(_btn("VOLVER", _home))
