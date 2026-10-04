extends Node3D
## Potenciador que cae de un zombi: gira, parpadea antes de desaparecer y se coge al pasar por encima.

var game: Node
var kind = "max_ammo"
var t = 0.0
var icon: Label3D
var light: OmniLight3D
const ICONS := { "max_ammo": "MUNICIÓN", "insta_kill": "☠", "double_points": "x2", "nuke": "☢", "carpenter": "🔨", "fire_sale": "$" }

func _ready() -> void:
	icon = Label3D.new(); icon.text = ICONS.get(kind, "?"); icon.font = load("res://assets/fonts/BlackOpsOne.ttf"); icon.font_size = 96; icon.pixel_size = 0.004
	icon.modulate = Color(1, 0.85, 0.3); icon.outline_size = 12; icon.outline_modulate = Color(0.2, 0.1, 0); icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED; add_child(icon)
	light = OmniLight3D.new(); light.light_color = Color(0.3, 1, 0.4); light.omni_range = 3.5; light.light_energy = 1.2; add_child(light)

func _process(d: float) -> void:
	t += d
	icon.position.y = sin(t * 3.0) * 0.08
	icon.visible = t < 22.0 or int(t * 8.0) % 2 == 0
	if t > 28.0: queue_free(); return
	var p: Player = game.player
	if p and p.global_position.distance_to(global_position - Vector3(0, 0.9, 0)) < 1.3:
		game.apply_powerup(kind); queue_free()
