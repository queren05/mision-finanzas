extends Node
## Sonido: efectos 2D y 3D con un grupo de reproductores reutilizables, y ambiente en bucle.

var streams = {}
var pool2d: Array[AudioStreamPlayer] = []
var pool3d: Array[AudioStreamPlayer3D] = []
var ambient: AudioStreamPlayer

func _ready() -> void:
	for f in DirAccess.get_files_at("res://assets/sfx"):
		var n = f.trim_suffix(".import")
		if n.ends_with(".ogg") and not streams.has(n.get_basename()): streams[n.get_basename()] = load("res://assets/sfx/" + n)
	for i in 16:
		var p = AudioStreamPlayer.new(); add_child(p); pool2d.append(p)
	for i in 24:
		var p = AudioStreamPlayer3D.new(); p.max_distance = 45.0; p.unit_size = 6.0; add_child(p); pool3d.append(p)
	ambient = AudioStreamPlayer.new(); add_child(ambient)

func _vol(base: float) -> float: return linear_to_db(max(0.001, base * float(GS.settings.sfx)))

func play(name: String, vol := 1.0, pitch := 1.0) -> void:
	var s = streams.get(name); if s == null: return
	for p in pool2d:
		if not p.playing:
			p.stream = s; p.volume_db = _vol(vol); p.pitch_scale = pitch * randf_range(0.96, 1.04); p.play(); return

func play_at(name: String, pos: Vector3, vol := 1.0, pitch := 1.0) -> void:
	var s = streams.get(name); if s == null: return
	for p in pool3d:
		if not p.playing:
			p.stream = s; p.global_position = pos; p.volume_db = _vol(vol); p.pitch_scale = pitch * randf_range(0.92, 1.08); p.play(); return

func play_ambient(name: String) -> void:
	var s = streams.get(name); if s == null: return
	if s is AudioStreamOggVorbis: s.loop = true
	ambient.stream = s; ambient.volume_db = linear_to_db(max(0.001, 0.5 * float(GS.settings.music))); ambient.play()

func stop_ambient() -> void: ambient.stop()

func set_ambient_volume() -> void:
	if ambient: ambient.volume_db = linear_to_db(max(0.001, 0.5 * float(GS.settings.music)))
