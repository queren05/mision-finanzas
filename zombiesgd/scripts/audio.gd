extends Node
## Sonido: efectos 2D y 3D con un grupo de reproductores reutilizables, ambiente en bucle, música de cada mapa,
## campanas de cambio de ronda (estilo Black Ops), música del jefe y la canción oculta.

var streams = {}
var pool2d: Array[AudioStreamPlayer] = []
var pool3d: Array[AudioStreamPlayer3D] = []
var ambient: AudioStreamPlayer
var music: AudioStreamPlayer
var sting: AudioStreamPlayer
var music_track = ""
var duck = 1.0

func _ready() -> void:
	for f in DirAccess.get_files_at("res://assets/sfx"):
		var n = f.trim_suffix(".import")
		if n.ends_with(".ogg") and not streams.has(n.get_basename()): streams[n.get_basename()] = load("res://assets/sfx/" + n)
	for i in 16:
		var p = AudioStreamPlayer.new(); add_child(p); pool2d.append(p)
	for i in 24:
		var p = AudioStreamPlayer3D.new(); p.max_distance = 45.0; p.unit_size = 6.0; add_child(p); pool3d.append(p)
	ambient = AudioStreamPlayer.new(); add_child(ambient)
	music = AudioStreamPlayer.new(); add_child(music); music.process_mode = Node.PROCESS_MODE_ALWAYS
	sting = AudioStreamPlayer.new(); add_child(sting); sting.process_mode = Node.PROCESS_MODE_ALWAYS

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

func stop_ambient() -> void: ambient.stop(); music.stop(); music_track = ""

func set_ambient_volume() -> void:
	if ambient: ambient.volume_db = linear_to_db(max(0.001, 0.5 * float(GS.settings.music)))

func _music_db(k := 1.0) -> float: return linear_to_db(max(0.001, 0.42 * float(GS.settings.music) * k))

## música en bucle (mapa, menú o jefe)
func play_music(track: String) -> void:
	if track == music_track and music.playing: return
	var path = "res://assets/music/%s.ogg" % track
	if not ResourceLoader.exists(path): return
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis: s.loop = track != "m_song"
	music_track = track; music.stream = s; music.volume_db = _music_db(duck); music.play()

func music_map(map_id: String) -> void: play_music("m_" + map_id)

## campanas y frases musicales cortas: bajan la música un momento
func music_sting(name: String) -> void:
	match name:
		"egg": play_music("m_boss"); return
		"egg_end", "game_over":
			if music_track == "m_boss": music.stop(); music_track = ""
	var path = "res://assets/music/s_%s.ogg" % name
	if not ResourceLoader.exists(path): return
	sting.stream = load(path); sting.volume_db = linear_to_db(max(0.001, 0.9 * float(GS.settings.music))); sting.play()
	duck = 0.35
	var tw = create_tween(); tw.tween_interval(3.0); tw.tween_method(func(k): duck = k; music.volume_db = _music_db(k), 0.35, 1.0, 2.0)
	music.volume_db = _music_db(duck)

## la canción oculta del easter egg: suena entera y luego vuelve la música del mapa
func music_song() -> void:
	var prev = music_track
	play_music("m_song")
	music.finished.connect(func(): play_music(prev), CONNECT_ONE_SHOT)
