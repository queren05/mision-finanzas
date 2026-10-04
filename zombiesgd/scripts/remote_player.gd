class_name RemotePlayer
extends Node3D
## Un compañero de cooperativo: su personaje (animado) con el arma, su nombre encima y si está caído.
## Se mueve suavemente hacia la última posición que manda su móvil.

var game: Node
var peer = 0
var pname = ""
var character = "comando"
var alive = true
var downed = false
var hp = 1.0
var crouch = false
var reloading = false
var model: CharacterModel
var label: Label3D
var flash_l: OmniLight3D
var net_pos = Vector3.ZERO
var net_yaw = 0.0
var pitch = 0.0
var last_pos = Vector3.ZERO
var speed = 0.0

func _ready() -> void:
	model = CharacterModel.new(); add_child(model); model.setup(character)
	label = Label3D.new(); label.text = pname; label.font = load("res://assets/fonts/BlackOpsOne.ttf"); label.font_size = 48; label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true; label.modulate = Color(0.55, 0.85, 1.0); label.outline_size = 8; add_child(label)
	label.position.y = 2.2 if model.human else 1.2
	flash_l = OmniLight3D.new(); flash_l.light_color = Color(1, 0.75, 0.4); flash_l.omni_range = 5; flash_l.light_energy = 0; flash_l.position = Vector3(0, 1.4, -1.0); add_child(flash_l)
	net_pos = global_position; last_pos = global_position

func net_state(pos: Vector3, yaw: float, pitch_: float, flags: int, wid: String, hp_: float) -> void:
	net_pos = pos; net_yaw = yaw; pitch = pitch_; hp = hp_
	downed = flags & 1 != 0; alive = flags & 2 == 0; crouch = flags & 4 != 0; reloading = flags & 16 != 0
	if wid != "": model.set_weapon(wid)

func muzzle() -> void:
	model.fired()
	flash_l.light_energy = 3.0
	get_tree().create_timer(0.05).timeout.connect(func(): if is_instance_valid(flash_l): flash_l.light_energy = 0.0)

func _process(d: float) -> void:
	global_position = global_position.lerp(net_pos, min(1.0, d * 12.0)) if global_position.distance_to(net_pos) < 5.0 else net_pos
	rotation.y = lerp_angle(rotation.y, net_yaw, min(1.0, d * 12.0))
	var v = (global_position - last_pos).length() / max(d, 0.001); last_pos = global_position
	speed = lerp(speed, v, min(1.0, d * 8.0))
	model.visible = alive
	model.update(d, speed, crouch, downed, reloading, pitch)
	label.text = pname + ("  ¡CAÍDO!" if downed else ("" if alive else "  (muerto)"))
	label.modulate = Color(1, 0.3, 0.3) if downed else Color(0.55, 0.85, 1.0)
