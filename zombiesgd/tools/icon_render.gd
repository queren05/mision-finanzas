extends Node3D
## Renderiza el arte del icono: un zombi de cerca a contraluz, con luna roja y niebla.
## Uso: godot --path zombiesgd res://tools/icon_render.tscn -- <kind> <anim> <t> <salida.png> [camx camy camz]
func _ready() -> void:
	var a = OS.get_cmdline_user_args()
	var kind = a[0] if a.size() > 0 else "a"
	var out = a[3] if a.size() > 3 else "/tmp/icon.png"
	get_window().size = Vector2i(1024, 1024)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.05, 0.0, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.25, 0.12, 0.14); env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 0.75
	env.glow_enabled = true; env.glow_intensity = 0.9; env.glow_bloom = 0.15
	env.fog_enabled = true; env.fog_light_color = Color(0.35, 0.05, 0.05); env.fog_density = 0.015; env.fog_sky_affect = 0.0
	var we = WorldEnvironment.new(); we.environment = env; add_child(we)
	var z: Node3D = Zombies.make(kind, "normal"); add_child(z)
	var ap: AnimationPlayer = z.find_child("AnimationPlayer", true, false)
	if ap:
		var names = ap.get_animation_list()
		var want = a[1] if a.size() > 1 else ""
		var pick = names[0]
		for n in names: if want != "" and String(n).to_lower().contains(want): pick = n
		print("ANIMS ", names, " -> ", pick)
		ap.play(pick); ap.seek(float(a[2]) if a.size() > 2 else 0.5, true); ap.pause()
	z.rotation_degrees.y = float(a[7]) if a.size() > 7 else 15.0
	# contraluz rojo-naranja fuerte, relleno frío por delante y un poco de luz de abajo en la cara
	var rim = DirectionalLight3D.new(); rim.light_color = Color(1.0, 0.35, 0.12); rim.light_energy = 2.2; rim.rotation_degrees = Vector3(-10, 20, 0); add_child(rim)
	var rim2 = OmniLight3D.new(); rim2.light_color = Color(1.0, 0.2, 0.1); rim2.light_energy = 3.0; rim2.omni_range = 4.0; rim2.position = Vector3(0.6, 1.9, -1.0); add_child(rim2)
	var fill = OmniLight3D.new(); fill.light_color = Color(0.45, 0.6, 1.0); fill.light_energy = 0.7; fill.omni_range = 4.0; fill.position = Vector3(-0.8, 1.5, 1.4); add_child(fill)
	var under = OmniLight3D.new(); under.light_color = Color(1.0, 0.6, 0.3); under.light_energy = 0.6; under.omni_range = 2.0; under.position = Vector3(0.1, 1.0, 0.7); add_child(under)
	# la cámara apunta a la cabeza (hueso "head"), desde delante y un poco por debajo: más amenazante
	await get_tree().process_frame
	var sk: Skeleton3D = z.find_children("*", "Skeleton3D", true, false)[0]
	var head = Vector3(0, 1.6, 0)
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).to_lower().contains("head"): head = sk.global_transform * sk.get_bone_global_pose(i).origin; break
	var face = z.global_transform.basis.z.normalized()
	var off = Vector3(float(a[4]), float(a[5]), float(a[6])) if a.size() > 6 else Vector3(0.25, -0.12, 1.0)
	var cam = Camera3D.new(); cam.fov = 34
	cam.position = head + face * off.z + z.global_transform.basis.x.normalized() * off.x + Vector3(0, off.y, 0)
	add_child(cam); cam.look_at(head + Vector3(0, 0.1, 0)); cam.current = true
	# luna roja detrás
	var moon = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 3.0; sm.height = 6.0; moon.mesh = sm
	var mm = StandardMaterial3D.new(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mm.albedo_color = Color(0.9, 0.18, 0.1); mm.emission_enabled = true; mm.emission = Color(1.0, 0.25, 0.1); mm.emission_energy_multiplier = 1.5
	moon.material_override = mm; moon.position = head - face * 30.0 + Vector3(-6, 7, 0); add_child(moon)
	for i in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("OK ", out)
	get_tree().quit()
