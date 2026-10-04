extends Node
## Frases de los personajes (voces generadas con Piper TTS, una voz y un tono distinto para cada personaje).
## No repite la misma frase seguida ni habla todo el rato.

var index = {}
var last_t = {}            # categoría -> momento en que se dijo
var player: AudioStreamPlayer
var cache = {}
# segundos mínimos entre dos frases de la misma categoría y probabilidad de decirla
const RULES := { "reload": [12.0, 0.35], "noammo": [15.0, 0.8], "streak": [20.0, 1.0], "box": [10.0, 0.6], "perk": [8.0, 0.8], "round": [30.0, 0.5] }

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new(); add_child(player)
	var f = FileAccess.open("res://assets/voice/index.json", FileAccess.READ)
	if f: index = JSON.parse_string(f.get_as_text())

func say(cat: String, character := "") -> void:
	if not index.has(cat) or float(GS.settings.get("sfx", 1.0)) <= 0.01: return
	var now = Time.get_ticks_msec() / 1000.0
	var rule: Array = RULES.get(cat, [4.0, 1.0])
	if now - float(last_t.get(cat, -999.0)) < float(rule[0]) or randf() > float(rule[1]): return
	if player.playing and now - float(last_t.get("_any", -999.0)) < 2.0: return
	last_t[cat] = now; last_t["_any"] = now
	var ch = character if character != "" else GS.character
	var path = "res://assets/voice/%s_%s_%d.ogg" % [ch, cat, randi() % int(index[cat])]
	if not ResourceLoader.exists(path): return
	if not cache.has(path): cache[path] = load(path)
	player.stream = cache[path]; player.volume_db = linear_to_db(max(0.001, float(GS.settings.get("sfx", 1.0)))) + 5.0; player.play()
