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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not DisplayServer.is_touchscreen_available(): device = "kb"

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
		var map = { KEY_R: "reload", KEY_F: "use", KEY_E: "use", KEY_1: "swap", KEY_2: "swap", KEY_Q: "swap", KEY_V: "knife", KEY_G: "grenade", KEY_SPACE: "jump", KEY_SHIFT: "sprint", KEY_C: "crouch", KEY_CTRL: "crouch", KEY_ESCAPE: "pause", KEY_P: "pause" }
		if map.has(e.keycode): _setb(map[e.keycode], e.pressed); device = "kb"
	elif e is InputEventJoypadButton:
		var jm = { JOY_BUTTON_A: "jump", JOY_BUTTON_X: "reload", JOY_BUTTON_Y: "swap", JOY_BUTTON_B: "crouch", JOY_BUTTON_RIGHT_SHOULDER: "grenade", JOY_BUTTON_LEFT_STICK: "sprint", JOY_BUTTON_RIGHT_STICK: "knife", JOY_BUTTON_START: "pause", JOY_BUTTON_LEFT_SHOULDER: "use", JOY_BUTTON_DPAD_UP: "use" }
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
	var pad = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if pad.length() < 0.15: pad = Vector2.ZERO
	var rs = Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() < 0.12: rs = Vector2.ZERO
	else: device = "pad"
	if pad != Vector2.ZERO: device = "pad"
	move = touch_move + kb + pad
	if move.length() > 1.0: move = move.normalized()
	var ps = 3.2 * float(GS.settings.sens) * delta
	look += touch_look + Vector2(-rs.x * abs(rs.x) * ps, -rs.y * abs(rs.y) * ps * (-1.0 if GS.settings.invert else 1.0))
	touch_look = Vector2.ZERO

## lo llama el jugador al final del fotograma
func consume() -> void:
	look = Vector2.ZERO; pressed.clear()
