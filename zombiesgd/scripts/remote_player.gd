class_name RemotePlayer
extends Node3D
## Un compañero de cooperativo: su personaje con el arma, su nombre encima y si está caído.
## Se mueve suavemente hacia la última posición que manda su móvil.

var game: Node
var peer = 0
var pname = ""
var character = "gamba"
var alive = true
var downed = false
var hp = 1.0
var crouch = false
var body: Node3D
var piv: Node3D
var gun: Node3D
var gun_id = ""
var label: Label3D
var flash_l: OmniLight3D
var net_pos = Vector3.ZERO
var net_yaw = 0.0
var pitch = 0.0
var body_len = 1.5
var bob = 0.0
var last_pos = Vector3.ZERO

func _ready() -> void:
	var c: Dictionary = Data.CHARACTERS.get(character, Data.CHARACTERS["gamba"])
	body = Node3D.new(); add_child(body)
	piv = Node3D.new(); body.add_child(piv)
	var m: Node3D = load("res://assets/models/chars/%s.glb" % c.file).instantiate(); piv.add_child(m)
	piv.rotation_degrees.y = 180.0 if float(c.head) > 0 else 0.0
	var lo = Vector3.INF; var hi = -Vector3.INF
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var t = Transform3D.IDENTITY; var n: Node = mi
		while n != null and n != body:
			if n is Node3D: t = (n as Node3D).transform * t
			n = n.get_parent()
		var b: AABB = t * (mi as MeshInstance3D).get_aabb(); lo = lo.min(b.position); hi = hi.max(b.end)
	var k = float(c.len) / max(0.001, max(hi.x - lo.x, hi.z - lo.z))
	piv.scale = Vector3.ONE * k
	piv.position = -Vector3((lo.x + hi.x) / 2, lo.y, (lo.z + hi.z) / 2) * k
	body_len = float(c.len)
	label = Label3D.new(); label.text = pname; label.font = load("res://assets/fonts/BlackOpsOne.ttf"); label.font_size = 48; label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true; label.modulate = Color(0.55, 0.85, 1.0); label.outline_size = 8; label.position.y = 1.2; add_child(label)
	flash_l = OmniLight3D.new(); flash_l.light_color = Color(1, 0.75, 0.4); flash_l.omni_range = 5; flash_l.light_energy = 0; flash_l.position = Vector3(0, 0.5, -1.0); body.add_child(flash_l)
	net_pos = global_position; last_pos = global_position

func net_state(pos: Vector3, yaw: float, pitch_: float, flags: int, wid: String, hp_: float) -> void:
	net_pos = pos; net_yaw = yaw; pitch = pitch_; hp = hp_
	downed = flags & 1 != 0; alive = flags & 2 == 0; crouch = flags & 4 != 0
	if wid != gun_id and wid != "" and Data.WEAPONS.has(wid):
		gun_id = wid
		if gun: gun.queue_free()
		gun = Guns.make_world(wid); body.add_child(gun); gun.scale = Vector3.ONE * 1.8
		gun.position = Vector3(0.16, 0.36, -body_len * 0.45 - float(Data.WEAPONS[wid].len) * 0.6)

func muzzle() -> void:
	flash_l.light_energy = 3.0
	get_tree().create_timer(0.05).timeout.connect(func(): if is_instance_valid(flash_l): flash_l.light_energy = 0.0)

func _process(d: float) -> void:
	global_position = global_position.lerp(net_pos, min(1.0, d * 12.0)) if global_position.distance_to(net_pos) < 5.0 else net_pos
	rotation.y = lerp_angle(rotation.y, net_yaw, min(1.0, d * 12.0))
	var spd = (global_position - last_pos).length() / max(d, 0.001); last_pos = global_position
	bob += d * min(spd, 6.0) * 2.2
	body.visible = alive
	body.position.y = abs(sin(bob)) * 0.05 * min(1.0, spd / 3.0)
	body.rotation.z = sin(bob) * 0.06 * min(1.0, spd / 3.0)
	body.rotation.x = lerp(body.rotation.x, (0.6 if downed else clamp(pitch * 0.35, -0.3, 0.3)), min(1.0, d * 8.0))
	if gun: gun.visible = not downed; gun.rotation.x = pitch * 0.65 - body.rotation.x
	label.text = pname + ("  ¡CAÍDO!" if downed else ("" if alive else "  (muerto)"))
	label.modulate = Color(1, 0.3, 0.3) if downed else Color(0.55, 0.85, 1.0)
	label.position.y = 1.2 if not downed else 0.9
