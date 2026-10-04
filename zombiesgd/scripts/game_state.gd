extends Node
## Progreso guardado (nivel, experiencia, bajas por arma, camuflajes, récords) y ajustes.

const SAVE_PATH := "user://partida.json"
var xp = 0
var level = 1
var weapon_kills = {}          # id -> bajas totales
var camo = {}                  # id -> camuflaje elegido
var best = {}                  # mapa -> mejor ronda
var settings = { "sens": 1.0, "ads_sens": 0.7, "invert": false, "aim_assist": true, "sfx": 0.9, "music": 0.6, "quality": "alta", "fov": 75.0, "third": false, "left_fire": false, "btn_scale": 1.1, "btn_alpha": 0.8, "vibration": true, "ads_toggle": true, "fullscreen": false, "show_fps": false, "auto_q": false }
var character = "comando"
var stats = {}                 # contadores para los desafíos
var done = {}                  # desafío -> true
var title = ""
var card = ""
# opciones de la próxima partida
var sel_map = "prison"
var start_round = 1
var start_weapon = "m1911"
var start_perk = ""

func _ready() -> void:
	load_game()
	# la primera vez, calidad según la tarjeta gráfica (integrada o de móvil: media)
	if not settings.get("auto_q", false):
		settings.auto_q = true
		var t = RenderingServer.get_video_adapter_type()
		settings.quality = "media" if t == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or OS.has_feature("mobile") else "alta"
		save_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return
	xp = int(d.get("xp", 0)); level = int(d.get("level", 1))
	weapon_kills = d.get("weapon_kills", {}); camo = d.get("camo", {}); best = d.get("best", {})
	for k in d.get("settings", {}): settings[k] = d["settings"][k]
	sel_map = d.get("sel_map", sel_map); start_round = int(d.get("start_round", 1)); start_weapon = d.get("start_weapon", "m1911"); start_perk = d.get("start_perk", ""); character = d.get("character", "comando")
	stats = d.get("stats", {}); done = d.get("done", {}); title = d.get("title", ""); card = d.get("card", "")
	if int(d.get("version", 1)) < 3: character = "comando"   # la 2.2 estrena el soldado: pasa a ser el personaje de todos

func save_game() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "xp": xp, "level": level, "weapon_kills": weapon_kills, "camo": camo, "best": best, "settings": settings,
		"sel_map": sel_map, "start_round": start_round, "start_weapon": start_weapon, "start_perk": start_perk, "character": character, "stats": stats, "done": done, "title": title, "card": card, "version": 3 }))

## suma experiencia y devuelve los niveles subidos
func add_xp(n: int) -> int:
	xp += n; var ups = 0
	while xp >= Data.xp_for_level(level): xp -= Data.xp_for_level(level); level += 1; ups += 1
	return ups

func add_kill(weapon_id: String) -> Array:
	weapon_kills[weapon_id] = int(weapon_kills.get(weapon_id, 0)) + 1
	return check_challenges()

# ---------------------------------------------------------------- desafíos
func stat_value(key: String) -> int:
	if key.begins_with("w:"): return int(weapon_kills.get(key.substr(2), 0))
	return int(stats.get(key, 0))

## suma a un contador y devuelve los desafíos recién completados (ya con su experiencia sumada)
func add_stat(key: String, n := 1) -> Array:
	stats[key] = int(stats.get(key, 0)) + n
	return check_challenges()

func max_stat(key: String, v: int) -> Array:
	if v > int(stats.get(key, 0)): stats[key] = v
	return check_challenges()

func check_challenges() -> Array:
	var out = []
	for c in Data.CHALLENGES:
		if done.has(c.id): continue
		if stat_value(c.stat) >= int(c.goal):
			done[c.id] = true; add_xp(int(c.xp)); out.append(c)
	return out

## de cada serie, el primer nivel sin completar (o el último si ya están todos)
func visible_challenges() -> Array:
	var series = {}; var order = []
	for c in Data.CHALLENGES:
		var k = c.id.substr(0, c.id.rfind("_"))
		if not series.has(k): series[k] = []; order.append(k)
		series[k].append(c)
	var out = []
	for k in order:
		var pick = series[k][-1]
		for c in series[k]:
			if not done.has(c.id): pick = c; break
		out.append(pick)
	return out

func start_points_bonus() -> int:
	var b = 0
	for u in Data.UNLOCKS:
		if u.kind == "points" and level >= u.level: b = max(b, int(u.id))
	return b

func is_unlocked(kind: String, id: String) -> bool:
	if kind == "start_round" and id == "1": return true
	if kind == "start_weapon" and id == "m1911": return true
	if kind == "start_perk" and id == "": return true
	if (kind == "title" or kind == "card") and id == "": return true
	for u in Data.UNLOCKS:
		if u.kind == kind and u.id == id: return level >= u.level
	return false

func camo_unlocked(weapon_id: String, camo_id: String) -> bool:
	for c in Data.CAMOS:
		if c.id == camo_id: return int(weapon_kills.get(weapon_id, 0)) >= c.kills
	return false

func camo_of(weapon_id: String) -> Dictionary:
	var id: String = camo.get(weapon_id, "none")
	for c in Data.CAMOS:
		if c.id == id: return c
	return Data.CAMOS[0]
