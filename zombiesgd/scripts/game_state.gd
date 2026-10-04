extends Node
## Progreso guardado (nivel, experiencia, bajas por arma, camuflajes, récords) y ajustes.

const SAVE_PATH := "user://partida.json"
var xp = 0
var level = 1
var weapon_kills = {}          # id -> bajas totales
var camo = {}                  # id -> camuflaje elegido
var best = {}                  # mapa -> mejor ronda
var settings = { "sens": 1.0, "invert": false, "aim_assist": true, "sfx": 0.9, "music": 0.6, "quality": "alta", "fov": 75.0, "third": false }
var character = "gamba"
# opciones de la próxima partida
var sel_map = "prison"
var start_round = 1
var start_weapon = "m1911"
var start_perk = ""

func _ready() -> void: load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return
	xp = int(d.get("xp", 0)); level = int(d.get("level", 1))
	weapon_kills = d.get("weapon_kills", {}); camo = d.get("camo", {}); best = d.get("best", {})
	for k in d.get("settings", {}): settings[k] = d["settings"][k]
	sel_map = d.get("sel_map", sel_map); start_round = int(d.get("start_round", 1)); start_weapon = d.get("start_weapon", "m1911"); start_perk = d.get("start_perk", ""); character = d.get("character", "gamba")

func save_game() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "xp": xp, "level": level, "weapon_kills": weapon_kills, "camo": camo, "best": best, "settings": settings,
		"sel_map": sel_map, "start_round": start_round, "start_weapon": start_weapon, "start_perk": start_perk, "character": character }))

## suma experiencia y devuelve los niveles subidos
func add_xp(n: int) -> int:
	xp += n; var ups = 0
	while xp >= Data.xp_for_level(level): xp -= Data.xp_for_level(level); level += 1; ups += 1
	return ups

func add_kill(weapon_id: String) -> void:
	weapon_kills[weapon_id] = int(weapon_kills.get(weapon_id, 0)) + 1

func is_unlocked(kind: String, id: String) -> bool:
	if kind == "start_round" and id == "1": return true
	if kind == "start_weapon" and id == "m1911": return true
	if kind == "start_perk" and id == "": return true
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
