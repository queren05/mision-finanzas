extends Node
## Entrada unificada: táctil (lo rellena la interfaz táctil), mando y teclado/ratón.
## El jugador solo lee: move, look, y los botones (held/pressed).

var move = Vector2.ZERO            # x derecha, y adelante
var look = Vector2.ZERO            # radianes acumulados este fotograma (x = giro, y = cabeceo)
var held = {}                      # botón -> true mientras se mantiene
var pressed = {}                   # botón -> true solo el fotograma en que se pulsa
var device = "touch"               # "touch" | "pad" | "kb"
var touch_move = Vector2.ZERO
var touch_look = Vector2.ZERO
var touch_held = {}
var mouse_captured = false
const BUTTONS := ["fire", "ads", "reload", "use", "swap", "knife", "grenade", "jump", "sprint", "crouch", "pause"]

var look_boost = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not DisplayServer.is_touchscreen_available(): device = "kb"
	# menús con mando: cruceta y también el stick izquierdo (por si el mando no los trae)
	for e in [["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0], ["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var ev = InputEventJoypadMotion.new(); ev.axis = e[1]; ev.axis_value = e[2]; ev.device = -1
		if not InputMap.action_has_event(e[0], ev): InputMap.action_add_event(e[0], ev)
	for e in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B], ["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN], ["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		var ev = InputEventJoypadButton.new(); ev.button_index = e[1]; ev.device = -1
		if not InputMap.action_has_event(e[0], ev): InputMap.action_add_event(e[0], ev)

func press_touch(b: String, on: bool) -> void:
	if on and not touch_held.get(b, false): pressed[b] = true
	touch_held[b] = on
	device = "touch"

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and mouse_captured:
		var s = 0.0025 * float(GS.settings.sens)
		look += Vector2(-e.relative.x * s, -e.relative.y * s * (-1.0 if GS.settings.invert else 1.0))
		device = "kb"
	elif e is InputEventMouseButton and mouse_captured:
		if e.button_index == MOUSE_BUTTON_LEFT: _setb("fire", e.pressed)
		elif e.button_index == MOUSE_BUTTON_RIGHT: _setb("ads", e.pressed)
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: pressed["swap"] = true
	elif e is InputEventKey and not e.echo:
		var map = { KEY_R: "reload", KEY_F: "use", KEY_E: "use", KEY_1: "swap", KEY_2: "swap", KEY_Q: "swap", KEY_V: "knife", KEY_G: "grenade", KEY_SPACE: "jump", KEY_SHIFT: "sprint", KEY_C: "crouch", KEY_CTRL: "crouch", KEY_ESCAPE: "pause", KEY_P: "pause", KEY_T: "view" }
		if map.has(e.keycode): _setb(map[e.keycode], e.pressed); device = "kb"
	elif e is InputEventJoypadButton:
		var jm = { JOY_BUTTON_A: "jump", JOY_BUTTON_X: "reload", JOY_BUTTON_Y: "swap", JOY_BUTTON_B: "crouch", JOY_BUTTON_RIGHT_SHOULDER: "grenade", JOY_BUTTON_LEFT_STICK: "sprint", JOY_BUTTON_RIGHT_STICK: "knife", JOY_BUTTON_START: "pause", JOY_BUTTON_BACK: "view", JOY_BUTTON_LEFT_SHOULDER: "use", JOY_BUTTON_DPAD_UP: "use" }
		if jm.has(e.button_index): _setb(jm[e.button_index], e.pressed); device = "pad"
		if e.button_index == JOY_BUTTON_X: _setb("use", e.pressed)   # en los Black Ops la X recarga y también usa
	elif e is InputEventJoypadMotion:
		if e.axis == JOY_AXIS_TRIGGER_RIGHT: _setb("fire", e.axis_value > 0.4); device = "pad"
		elif e.axis == JOY_AXIS_TRIGGER_LEFT: _setb("ads", e.axis_value > 0.4); device = "pad"

func _setb(b: String, on: bool) -> void:
	if on and not held.get(b, false): pressed[b] = true
	held[b] = on

func is_held(b: String) -> bool: return held.get(b, false) or touch_held.get(b, false)
func was_pressed(b: String) -> bool: return pressed.get(b, false)

## lo llama el jugador al principio de cada fotograma físico
func poll(delta: float) -> void:
	var kb = Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)))
	# todos los mandos conectados (las consolas portátiles a veces dan a sus controles otro número que no es el 0)
	var pad = Vector2.ZERO; var rs = Vector2.ZERO
	for j in Input.get_connected_joypads():
		var a = Vector2(Input.get_joy_axis(j, JOY_AXIS_LEFT_X), -Input.get_joy_axis(j, JOY_AXIS_LEFT_Y))
		var b = Vector2(Input.get_joy_axis(j, JOY_AXIS_RIGHT_X), Input.get_joy_axis(j, JOY_AXIS_RIGHT_Y))
		if a.length() > pad.length(): pad = a
		if b.length() > rs.length(): rs = b
	pad = _deadzone(pad, 0.16)
	rs = _deadzone(rs, 0.12)
	if pad != Vector2.ZERO or rs != Vector2.ZERO: device = "pad"
	move = touch_move + kb + pad
	if move.length() > 1.0: move = move.normalized()
	# stick derecho: curva suave para apuntar fino y aceleración al llevarlo a tope (como en los Call of Duty)
	var mag = rs.length()
	look_boost = move_toward(look_boost, 1.0 if mag > 0.95 else 0.0, delta * (2.5 if mag > 0.95 else 6.0))
	var curve = pow(mag, 1.7) * (1.0 + look_boost * 0.7)
	var ps = 3.4 * float(GS.settings.sens) * delta
	var lv = rs.normalized() * curve if mag > 0.0 else Vector2.ZERO
	look += touch_look + Vector2(-lv.x * ps, -lv.y * ps * 0.8 * (-1.0 if GS.settings.invert else 1.0))
	touch_look = Vector2.ZERO

## zona muerta radial: por debajo no se mueve, por encima va de 0 a 1 sin saltos
func _deadzone(v: Vector2, dz: float) -> Vector2:
	var l = v.length()
	if l < dz: return Vector2.ZERO
	return v / l * min(1.0, (l - dz) / (1.0 - dz))

## lo llama el jugador al final del fotograma
func consume() -> void:
	look = Vector2.ZERO; pressed.clear()
