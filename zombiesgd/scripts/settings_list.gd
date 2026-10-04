class_name SettingsList
extends RefCounted
## Lista de ajustes (la misma en el menú principal y en la pausa). Cada cambio se guarda y se aplica al momento.

const GOLD = Color(1.0, 0.8, 0.2)
const RED2 = Color(1.0, 0.165, 0.165)

## construye la lista dentro de un ScrollContainer y devuelve el primer control (para darle el foco con mando)
static func build(sc: ScrollContainer, font_bo: Font, font_ui: Font, changed: Callable) -> Control:
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation", 8); sc.add_child(list)
	var first = _toggle(list, font_bo, font_ui, "Vista", "third", "TERCERA PERSONA", "PRIMERA PERSONA", changed)
	_cycle(list, font_bo, font_ui, "Calidad gráfica", "quality", ["baja", "media", "alta"], changed)
	_slider(list, font_ui, "Sensibilidad", 0.3, 2.5, "sens", changed)
	_slider(list, font_ui, "Sensibilidad apuntando", 0.3, 1.2, "ads_sens", changed)
	_slider(list, font_ui, "Campo de visión", 60, 95, "fov", changed)
	_toggle(list, font_bo, font_ui, "Ayuda al apuntar", "aim_assist", "SÍ", "NO", changed)
	_toggle(list, font_bo, font_ui, "Invertir eje vertical", "invert", "SÍ", "NO", changed)
	if OS.has_feature("mobile"):   # opciones de pantalla táctil (en el móvil)
		_toggle(list, font_bo, font_ui, "Apuntar (pantalla táctil)", "ads_toggle", "TOCAR", "MANTENER", changed)
		_toggle(list, font_bo, font_ui, "Botón de disparo a la izquierda", "left_fire", "SÍ", "NO", changed)
		_slider(list, font_ui, "Tamaño de los botones", 0.8, 1.3, "btn_scale", changed)
		_slider(list, font_ui, "Opacidad de los botones", 0.3, 1.0, "btn_alpha", changed)
		_toggle(list, font_bo, font_ui, "Vibración", "vibration", "SÍ", "NO", changed)
	_toggle(list, font_bo, font_ui, "Mostrar FPS", "show_fps", "SÍ", "NO", changed)
	if not OS.has_feature("mobile"):
		_toggle(list, font_bo, font_ui, "Pantalla completa (F11)", "fullscreen", "SÍ", "NO", func(k): Controls.apply_window(); changed.call(k))
	_slider(list, font_ui, "Efectos de sonido", 0, 1, "sfx", changed)
	_slider(list, font_ui, "Ambiente", 0, 1, "music", changed)
	if not OS.has_feature("mobile"):
		var help = _label("Teclado y ratón:  WASD moverse · ratón apuntar · clic izq. disparar · clic der. apuntar · R recargar · F o E usar · Q o rueda cambiar de arma · G granada · V cuchillo · Espacio saltar · Mayús correr · C agacharse (corriendo: deslizarse) · T vista · Esc pausa · F11 pantalla completa.\nMando: gatillos disparar/apuntar · A saltar · X recargar/usar · Y cambiar arma · B agacharse · RB granada · R3 cuchillo · L3 correr · Select vista · Start pausa.", font_ui, 19, Color(0.8, 0.77, 0.7))
		help.autowrap_mode = TextServer.AUTOWRAP_WORD; help.custom_minimum_size = Vector2(780, 0); list.add_child(help)
	return first

static func _label(text: String, f: Font, size: int, c: Color) -> Label:
	var l = Label.new(); l.text = text; l.add_theme_font_override("font", f); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", c)
	return l

static func _row(list: VBoxContainer, font_ui: Font, label: String, value: Control) -> void:
	var pc = PanelContainer.new(); var sb = StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.06); sb.set_corner_radius_all(8); sb.content_margin_left = 18; sb.content_margin_right = 12
	pc.add_theme_stylebox_override("panel", sb); pc.custom_minimum_size = Vector2(780, 60)
	var h = HBoxContainer.new(); pc.add_child(h)
	var l = _label(label, font_ui, 25, Color(0.95, 0.92, 0.86)); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; h.add_child(l)
	h.add_child(value); list.add_child(pc)

static func _value_btn(text: String, font_bo: Font) -> Button:
	var b = MenuStyle.button(text, func(): pass, font_bo, 25, 340, true)
	b.add_theme_color_override("font_color", GOLD); b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.6)); b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.6))
	return b

static func _toggle(list: VBoxContainer, font_bo: Font, font_ui: Font, label: String, key: String, yes: String, no: String, changed: Callable) -> Button:
	var b = _value_btn(yes if GS.settings.get(key, false) else no, font_bo)
	b.pressed.connect(func():
		GS.settings[key] = not GS.settings.get(key, false); b.text = yes if GS.settings[key] else no; GS.save_game(); changed.call(key))
	_row(list, font_ui, label, b); return b

static func _cycle(list: VBoxContainer, font_bo: Font, font_ui: Font, label: String, key: String, opts: Array, changed: Callable) -> Button:
	var b = _value_btn(str(GS.settings.get(key, opts[-1])).to_upper(), font_bo)
	b.pressed.connect(func():
		var i = opts.find(GS.settings.get(key, opts[-1])); GS.settings[key] = opts[(i + 1) % opts.size()]; b.text = str(GS.settings[key]).to_upper(); GS.save_game(); changed.call(key))
	_row(list, font_ui, label, b); return b

static func _slider(list: VBoxContainer, font_ui: Font, label: String, a: float, b: float, key: String, changed: Callable) -> HSlider:
	var s = HSlider.new(); s.min_value = a; s.max_value = b; s.step = (b - a) / 40.0; s.value = float(GS.settings.get(key, (a + b) / 2)); s.custom_minimum_size = Vector2(340, 46); s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(x): GS.settings[key] = x; changed.call(key))
	s.drag_ended.connect(func(_c): GS.save_game())
	s.focus_exited.connect(func(): GS.save_game())
	var grab = StyleBoxFlat.new(); grab.bg_color = RED2; grab.content_margin_top = 4; grab.content_margin_bottom = 4
	var track = StyleBoxFlat.new(); track.bg_color = Color(1, 1, 1, 0.18); track.content_margin_top = 3; track.content_margin_bottom = 3; track.set_corner_radius_all(3)
	s.add_theme_stylebox_override("slider", track); s.add_theme_stylebox_override("grabber_area", grab); s.add_theme_stylebox_override("grabber_area_highlight", grab)
	_row(list, font_ui, label, s); return s
