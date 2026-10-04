extends Control
## Controles táctiles al estilo de Call of Duty Mobile / Fortnite: joystick a la izquierda (aparece donde pones el pulgar
## y se queda marcado en reposo), mirar arrastrando a la derecha (también desde el botón de disparo) y botones redondos
## con iconos dibujados. Tamaño, opacidad y disparo a la izquierda se cambian en Ajustes.

var hud
var stick_id = -1
var stick_origin = Vector2.ZERO
var stick_pos = Vector2.ZERO
var look_ids = {}               # índice -> última posición
var btn_touch = {}              # índice -> nombre del botón
var buttons = []
var use_visible = false
var margin_left = 40.0
var margin_right = 40.0
var press_anim = {}             # nombre -> 0..1 (encoge el botón al pulsarlo)
const STICK_R := 80.0
const WHITE := Color(1, 1, 1)
const DARK := Color(0.04, 0.05, 0.07)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# posiciones respecto a la esquina inferior derecha (en píxeles de 1280x720), como en CoD Mobile
	# posiciones respecto a la esquina inferior derecha (en píxeles de 1280x720), en arcos alrededor del pulgar como en CoD Mobile:
	# lo que más se usa (disparar, saltar, agacharse, apuntar) queda donde descansa el pulgar; lo demás, en un arco más abierto
	buttons = [
		{ "name": "fire", "off": Vector2(-190, -250), "r": 70.0 },
		{ "name": "jump", "off": Vector2(-62, -215), "r": 46.0 },
		{ "name": "crouch", "off": Vector2(-70, -90), "r": 42.0 },
		{ "name": "ads", "off": Vector2(-75, -350), "r": 44.0 },
		{ "name": "knife", "off": Vector2(-195, -82), "r": 38.0 },
		{ "name": "reload", "off": Vector2(-325, -112), "r": 38.0 },
		{ "name": "grenade", "off": Vector2(-330, -250), "r": 36.0 },
		{ "name": "swap", "off": Vector2(-240, -395), "r": 34.0 },
		{ "name": "use", "off": Vector2(-470, -200), "r": 48.0 },
		{ "name": "fire", "id": "fire_l", "off": Vector2(230, -390), "r": 46.0, "left": true },
		{ "name": "pause", "off": Vector2(0, 0), "r": 28.0, "top_left": true },
		{ "name": "view", "off": Vector2(70, 0), "r": 28.0, "top_left": true },
	]

func set_use_visible(on: bool) -> void:
	if on != use_visible: use_visible = on; queue_redraw()

func _scale() -> float: return float(GS.settings.get("btn_scale", 1.0))

func _shown(b: Dictionary) -> bool:
	if b.name == "use" and not use_visible: return false
	if b.get("left", false) and not GS.settings.get("left_fire", false): return false
	return true

func _bpos(b: Dictionary) -> Vector2:
	if b.get("top_left", false): return Vector2(margin_left + 14, 46) + b.off
	if b.get("left", false): return Vector2(margin_left - 40.0 + b.off.x, size.y + b.off.y)
	return size + b.off * lerp(1.0, _scale(), 0.6) - Vector2(margin_right - 40.0, 0)

func _br(b: Dictionary) -> float: return b.r * (1.0 if b.get("top_left", false) else _scale())

func _bid(b: Dictionary) -> String: return b.get("id", b.name)

func _input(e: InputEvent) -> void:
	if not visible: return
	if e is InputEventScreenTouch:
		Controls.device = "touch"
		if e.pressed:
			for b in buttons:
				if not _shown(b): continue
				if e.position.distance_to(_bpos(b)) < _br(b) * 1.18:
					press_anim[_bid(b)] = 1.0
					if b.name == "ads" and GS.settings.get("ads_toggle", true):   # apuntar con un toque (y otro para dejar de apuntar)
						Controls.press_touch("ads", not Controls.touch_held.get("ads", false)); queue_redraw(); return
					btn_touch[e.index] = b; Controls.press_touch(b.name, true)
					if b.name == "fire": look_ids[e.index] = e.position   # disparar y apuntar con el mismo dedo
					queue_redraw(); return
			if e.position.x < size.x * 0.45 and e.position.y > 110 and stick_id < 0:
				stick_id = e.index; stick_origin = e.position; stick_pos = e.position
			else:
				look_ids[e.index] = e.position
		else:
			if btn_touch.has(e.index): Controls.press_touch(btn_touch[e.index].name, false); btn_touch.erase(e.index)
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

func _process(d: float) -> void:
	if press_anim.is_empty(): return
	for k in press_anim.keys():
		press_anim[k] = max(0.0, press_anim[k] - d * 6.0)
		if press_anim[k] <= 0.0: press_anim.erase(k)
	queue_redraw()

func _draw() -> void:
	if Controls.device != "touch": return
	var alpha = float(GS.settings.get("btn_alpha", 0.8))
	var p: Player = hud.game.player if hud and hud.game else null
	for b in buttons:
		if not _shown(b): continue
		var c = _bpos(b); var on: bool = Controls.touch_held.get(b.name, false)
		var r = _br(b) * (1.0 - 0.08 * press_anim.get(_bid(b), 0.0))
		var acc = Color(1, 1, 1)
		if b.name == "fire": acc = Color(1.0, 0.27, 0.22)
		elif b.name == "use": acc = Color(1.0, 0.8, 0.2)
		# fondo: círculo oscuro translúcido con aro fino; pulsado se ilumina
		draw_circle(c, r, Color(DARK.r, DARK.g, DARK.b, (0.42 if not on else 0.62) * alpha))
		draw_circle(c, r, Color(acc.r, acc.g, acc.b, (0.10 if not on else 0.25) * alpha))
		draw_arc(c, r - 1.0, 0, TAU, 64, Color(acc.r, acc.g, acc.b, (0.55 if not on else 0.95) * alpha), 2.5 if b.name != "fire" else 3.5, true)
		var ic = Color(1, 1, 1, (0.92 if not on else 1.0) * alpha)
		_icon(b.name, c, r, ic, p)
		# estados: granadas que quedan, cuchillo listo, agachado
		if b.name == "grenade" and p: _badge(c + Vector2(r * 0.72, -r * 0.72), str(p.grenades), alpha)
		if b.name == "crouch" and p and p.crouch: draw_arc(c, r + 4, 0, TAU, 64, Color(1, 0.8, 0.2, 0.9 * alpha), 3.0, true)
		if b.name == "view" and p and p.third: draw_arc(c, r + 4, 0, TAU, 48, Color(1, 0.8, 0.2, 0.9 * alpha), 2.5, true)
	# joystick: marcado en reposo, sigue al pulgar al usarlo
	var base = stick_origin if stick_id >= 0 else Vector2(margin_left + 340, size.y - 165)   # a la derecha de los puntos y la ronda
	draw_circle(base, STICK_R, Color(DARK.r, DARK.g, DARK.b, (0.30 if stick_id >= 0 else 0.16) * alpha))
	draw_arc(base, STICK_R, 0, TAU, 64, Color(1, 1, 1, (0.45 if stick_id >= 0 else 0.22) * alpha), 2.0, true)
	var k = (stick_pos - stick_origin).limit_length(STICK_R) if stick_id >= 0 else Vector2.ZERO
	draw_circle(base + k, 36, Color(1, 1, 1, (0.5 if stick_id >= 0 else 0.22) * alpha))
	if stick_id >= 0 and Controls.touch_move.y > 0.92:   # correr
		_chevron(base + Vector2(0, -STICK_R - 26), 14, Color(1, 0.8, 0.2, 0.95 * alpha), -1)

func _badge(at: Vector2, t: String, alpha: float) -> void:
	draw_circle(at, 12, Color(0.95, 0.75, 0.15, 0.95 * alpha))
	var f: Font = hud.font_bo
	var sz = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(f, at + Vector2(-sz.x / 2, 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.06, 0))

func _chevron(c: Vector2, s: float, col: Color, dir := -1) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-s, -dir * s * 0.5), c + Vector2(0, dir * s * 0.5), c + Vector2(s, -dir * s * 0.5)]), col, 4.0, true)

## iconos dibujados con líneas (se ven nítidos a cualquier tamaño)
func _icon(n: String, c: Vector2, r: float, col: Color, p: Player) -> void:
	var s = r * 0.42; var w = max(2.5, r * 0.07)
	match n:
		"fire":   # bala
			var pts = PackedVector2Array([c + Vector2(-s * 0.32, s * 0.9), c + Vector2(-s * 0.32, -s * 0.2), c + Vector2(0, -s * 0.95), c + Vector2(s * 0.32, -s * 0.2), c + Vector2(s * 0.32, s * 0.9)])
			draw_colored_polygon(pts, col)
			draw_line(c + Vector2(-s * 0.42, s * 0.55), c + Vector2(s * 0.42, s * 0.55), Color(0, 0, 0, 0.5), 2.0)
		"ads":   # mira telescópica
			draw_arc(c, s * 0.85, 0, TAU, 40, col, w, true)
			draw_line(c + Vector2(-s * 1.15, 0), c + Vector2(-s * 0.35, 0), col, w); draw_line(c + Vector2(s * 0.35, 0), c + Vector2(s * 1.15, 0), col, w)
			draw_line(c + Vector2(0, -s * 1.15), c + Vector2(0, -s * 0.35), col, w); draw_line(c + Vector2(0, s * 0.35), c + Vector2(0, s * 1.15), col, w)
			draw_circle(c, w * 0.7, col)
		"jump":
			_chevron(c + Vector2(0, -s * 0.25), s * 0.85, col); _chevron(c + Vector2(0, s * 0.45), s * 0.85, col)
		"crouch":   # flecha hacia abajo sobre una raya
			_chevron(c + Vector2(0, -s * 0.2), s * 0.85, col, 1)
			draw_line(c + Vector2(-s, s * 0.7), c + Vector2(s, s * 0.7), col, w)
		"knife":
			var blade = PackedVector2Array([c + Vector2(-s * 0.9, s * 0.9), c + Vector2(-s * 0.55, s * 0.35), c + Vector2(s * 0.95, -s * 0.95), c + Vector2(-s * 0.25, s * 0.65)])
			draw_colored_polygon(blade, col)
			draw_line(c + Vector2(-s * 0.85, s * 0.25), c + Vector2(-s * 0.2, s * 0.95), col, w)
		"reload":   # flecha circular
			draw_arc(c, s * 0.8, -PI * 0.15, PI * 1.45, 32, col, w, true)
			var tip = c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * s * 0.8
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.45, -s * 0.1), tip + Vector2(s * 0.25, -s * 0.15), tip + Vector2(-s * 0.05, s * 0.5)]), col)
		"grenade":
			draw_circle(c + Vector2(0, s * 0.2), s * 0.62, col)
			draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.75), Vector2(s * 0.5, s * 0.35)), col)
			draw_arc(c + Vector2(s * 0.45, -s * 0.6), s * 0.28, PI, TAU, 12, col, w * 0.8, true)
		"swap":   # dos flechas opuestas
			draw_line(c + Vector2(-s, -s * 0.35), c + Vector2(s * 0.8, -s * 0.35), col, w); _arrow_head(c + Vector2(s, -s * 0.35), Vector2.RIGHT, s * 0.4, col)
			draw_line(c + Vector2(s, s * 0.35), c + Vector2(-s * 0.8, s * 0.35), col, w); _arrow_head(c + Vector2(-s, s * 0.35), Vector2.LEFT, s * 0.4, col)
		"use":   # mano
			var f: Font = hud.font_bo
			var t = "USAR"; var fs = int(r * 0.42)
			var sz = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, c + Vector2(-sz.x / 2, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		"pause":
			for i in 3: draw_line(c + Vector2(-s, (i - 1) * s * 0.6), c + Vector2(s, (i - 1) * s * 0.6), col, w)
		"view":   # cámara: ojo
			var pts = PackedVector2Array()
			for i in 17:
				pts.append(c + Vector2(-cos(PI * i / 16.0) * s * 1.1, -sin(PI * i / 16.0) * s * 0.6))
			for i in 17:
				pts.append(c + Vector2(cos(PI * i / 16.0) * s * 1.1, sin(PI * i / 16.0) * s * 0.6))
			draw_polyline(pts, col, w, true)
			draw_circle(c, s * 0.32, col)

func _arrow_head(tip: Vector2, dir: Vector2, s: float, col: Color) -> void:
	var n = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip + dir * s * 0.3, tip - dir * s + n * s * 0.6, tip - dir * s - n * s * 0.6]), col)

func _notification(w: int) -> void: if w == NOTIFICATION_RESIZED: queue_redraw()
