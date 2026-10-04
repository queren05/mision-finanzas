extends Control
## Controles táctiles: joystick a la izquierda (aparece donde pones el pulgar), mirar arrastrando a la derecha
## (también arrastrando desde el botón de disparo) y botones.

var hud
var stick_id = -1
var stick_origin = Vector2.ZERO
var stick_pos = Vector2.ZERO
var look_ids = {}               # índice -> última posición
var btn_touch = {}              # índice -> nombre del botón
var buttons = []                # [{name, pos(rel), r, label}]
var use_visible = false
var margin_left = 40.0
var margin_right = 40.0
const STICK_R := 85.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# posiciones relativas a la esquina inferior derecha (en píxeles de 1280x720)
	buttons = [
		{ "name": "fire", "off": Vector2(-150, -230), "r": 70.0, "label": "" },
		{ "name": "ads", "off": Vector2(-70, -110), "r": 48.0, "label": "MIRA" },
		{ "name": "jump", "off": Vector2(-215, -85), "r": 42.0, "label": "SALTO" },
		{ "name": "reload", "off": Vector2(-62, -355), "r": 38.0, "label": "REC" },
		{ "name": "swap", "off": Vector2(-160, -400), "r": 36.0, "label": "ARMA" },
		{ "name": "knife", "off": Vector2(-300, -170), "r": 36.0, "label": "CUCH" },
		{ "name": "grenade", "off": Vector2(-280, -300), "r": 34.0, "label": "GRAN" },
		{ "name": "use", "off": Vector2(-420, -110), "r": 48.0, "label": "USAR" },
		{ "name": "pause", "off": Vector2(0, 0), "r": 30.0, "label": "II", "top_left": true },
		{ "name": "view", "off": Vector2(78, 0), "r": 30.0, "label": "VISTA", "top_left": true },
	]

func set_use_visible(on: bool) -> void:
	if on != use_visible: use_visible = on; queue_redraw()

func _bpos(b: Dictionary) -> Vector2:
	if b.get("top_left", false): return Vector2(margin_left + 14, 50) + b.off
	return size + b.off - Vector2(margin_right - 40.0, 0)

func _active() -> bool: return visible and Controls.device == "touch"

func _input(e: InputEvent) -> void:
	if not visible: return
	if e is InputEventScreenTouch:
		Controls.device = "touch"
		if e.pressed:
			for b in buttons:
				if b.name == "use" and not use_visible: continue
				if e.position.distance_to(_bpos(b)) < b.r * 1.15:
					btn_touch[e.index] = b.name; Controls.press_touch(b.name, true)
					if b.name == "fire": look_ids[e.index] = e.position
					queue_redraw(); return
			if e.position.x < size.x * 0.45 and e.position.y > 110 and stick_id < 0:
				stick_id = e.index; stick_origin = e.position; stick_pos = e.position
			else:
				look_ids[e.index] = e.position
		else:
			if btn_touch.has(e.index): Controls.press_touch(btn_touch[e.index], false); btn_touch.erase(e.index)
			if e.index == stick_id: stick_id = -1; Controls.touch_move = Vector2.ZERO
			look_ids.erase(e.index)
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == stick_id:
			stick_pos = e.position
			var v: Vector2 = (stick_pos - stick_origin) / STICK_R
			if v.length() > 1.0:
				stick_origin = stick_pos - v.normalized() * STICK_R   # el joystick sigue al pulgar
				v = v.normalized()
			Controls.touch_move = Vector2(v.x, -v.y)
			queue_redraw()
		elif look_ids.has(e.index):
			var s = 0.0042 * float(GS.settings.sens)
			Controls.touch_look += Vector2(-e.relative.x * s, -e.relative.y * s * (-1.0 if GS.settings.invert else 1.0))
			look_ids[e.index] = e.position

func _draw() -> void:
	if Controls.device != "touch": return
	var font: Font = hud.font_ui
	for b in buttons:
		if b.name == "use" and not use_visible: continue
		var p = _bpos(b); var on: bool = Controls.touch_held.get(b.name, false)
		draw_circle(p, b.r, Color(0, 0, 0, 0.35 if not on else 0.55))
		draw_arc(p, b.r, 0, TAU, 48, Color(1, 1, 1, 0.55 if not on else 0.9), 2.5, true)
		if b.name == "fire":
			draw_circle(p, b.r * 0.42, Color(0.75, 0.08, 0.08, 0.75))
		else:
			var tsz = font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, 17)
			draw_string(font, p - Vector2(tsz.x / 2, -6), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.9))
	if stick_id >= 0:
		draw_circle(stick_origin, STICK_R, Color(0, 0, 0, 0.25)); draw_arc(stick_origin, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0, true)
		var k = (stick_pos - stick_origin).limit_length(STICK_R)
		draw_circle(stick_origin + k, 34, Color(1, 1, 1, 0.45))

func _notification(w: int) -> void: if w == NOTIFICATION_RESIZED: queue_redraw()
