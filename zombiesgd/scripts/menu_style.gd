class_name MenuStyle
extends RefCounted
## Estilo de los menús (el de la versión anterior): botones de solo texto en Black Ops One;
## al seleccionarlos (dedo, ratón o mando) aparece la barra roja a la izquierda con un degradado rojo.

static var _grad: GradientTexture2D

static func _focus_tex(centered: bool) -> GradientTexture2D:
	var g = Gradient.new()
	if centered:
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0]); g.colors = PackedColorArray([Color(0.78, 0.08, 0.12, 0.0), Color(0.78, 0.08, 0.12, 0.55), Color(0.78, 0.08, 0.12, 0.0)])
	else:
		g.set_color(0, Color(0.78, 0.08, 0.12, 0.6)); g.set_color(1, Color(0.78, 0.08, 0.12, 0.0))
	var t = GradientTexture2D.new(); t.gradient = g; t.width = 128; t.height = 4
	return t

static func button(text: String, cb: Callable, font: Font, size := 32, width := 420, centered := false) -> Button:
	var b = Button.new(); b.text = text; b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font); b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75)); b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE); b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9)); b.add_theme_constant_override("outline_size", 6)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, size * 1.75)
	var normal = StyleBoxFlat.new(); normal.bg_color = Color(0, 0, 0, 0); normal.content_margin_left = 22; normal.content_margin_right = 22
	if not centered: normal.border_width_left = 5; normal.border_color = Color(0, 0, 0, 0)
	var on = StyleBoxTexture.new(); on.texture = _focus_tex(centered); on.content_margin_left = 26 if not centered else 22; on.content_margin_right = 22
	if not centered:
		on.texture_margin_left = 0
	var bar = StyleBoxFlat.new(); bar.bg_color = Color(0, 0, 0, 0); bar.border_width_left = 5; bar.border_color = Color(1, 0.165, 0.165); bar.content_margin_left = 26
	b.add_theme_stylebox_override("normal", normal); b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("hover", on); b.add_theme_stylebox_override("focus", bar if not centered else StyleBoxEmpty.new()); b.add_theme_stylebox_override("pressed", on)
	# con mando el foco también se ve con el degradado
	b.focus_entered.connect(func(): b.add_theme_stylebox_override("normal", on); Sfx.play("click", 0.25))
	b.focus_exited.connect(func(): b.add_theme_stylebox_override("normal", normal))
	b.pressed.connect(cb)
	return b

## márgenes izquierdo y derecho que respetan la muesca y las esquinas del iPhone
static func safe_margins(vp: Viewport) -> Vector2:
	var vs = vp.get_visible_rect().size
	var sa = DisplayServer.get_display_safe_area(); var ws = DisplayServer.window_get_size()
	var ml = 40.0; var mr = 40.0
	if ws.x > 0 and sa.size.x > ws.x * 0.75 and sa.position.x < ws.x * 0.2:   # muesca real; se ignora si la zona segura no corresponde a esta ventana
		var k = vs.x / ws.x
		ml = max(ml, sa.position.x * k + 20.0); mr = max(mr, (ws.x - sa.end.x) * k + 20.0)
	return Vector2(min(ml, 140.0), min(mr, 140.0))
