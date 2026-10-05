extends Node
## Datos fijos del juego: armas, ventajas, potenciadores, niveles, camuflajes y mapas.

# ---------------------------------------------------------------- armas
# dmg = daño por bala (cuerpo); head = multiplicador a la cabeza; rpm = disparos por minuto; mag/res = cargador y reserva
# reload = segundos; spread = dispersión sin apuntar (grados); ads_spread = apuntando; pellets = perdigones
# cost = precio en la pared (0 = solo caja); class = tipo (pistola, escopeta, subfusil, fusil, ametralladora, francotirador, especial)
# len = largo del modelo en metros; sound = sonido de disparo; pap = versión mejorada
const WEAPONS := {
	"m1911": { "name": "M1911", "class": "pistola", "model": "gun_m1911", "len": 0.22, "dmg": 40, "head": 2.5, "rpm": 400, "mag": 8, "res": 80, "reload": 1.6,
		"spread": 2.0, "ads_spread": 0.6, "auto": false, "pellets": 1, "cost": 0, "sound": "shot_pistol", "reload_snd": "reload_pistol", "recoil": 1.2, "range": 40,
		"pap": { "name": "Mustang & Sally", "dmg": 900, "mag": 12, "res": 60, "explosive": 2.2 } },
	"python": { "name": "Python", "class": "pistola", "model": "gun_python", "len": 0.3, "dmg": 180, "head": 2.0, "rpm": 160, "mag": 6, "res": 36, "reload": 3.0,
		"spread": 1.6, "ads_spread": 0.3, "auto": false, "pellets": 1, "cost": 2200, "sound": "shot_magnum", "reload_snd": "reload_pistol", "recoil": 3.0, "range": 60,
		"pap": { "name": "Cobra", "dmg": 600, "mag": 12, "res": 84 } },
	"olympia": { "name": "Olympia", "class": "escopeta", "model": "gun_olympia", "len": 0.95, "dmg": 50, "head": 1.5, "rpm": 120, "mag": 2, "res": 38, "reload": 2.6,
		"spread": 6.0, "ads_spread": 4.5, "auto": false, "pellets": 8, "cost": 500, "sound": "shot_shotgun", "reload_snd": "reload_shotgun", "recoil": 4.0, "range": 18,
		"pap": { "name": "Hades", "dmg": 140, "mag": 4, "res": 76 } },
	"stakeout": { "name": "Stakeout", "class": "escopeta", "model": "gun_stakeout", "len": 0.95, "dmg": 60, "head": 1.5, "rpm": 80, "mag": 6, "res": 48, "reload": 3.4,
		"spread": 5.5, "ads_spread": 4.0, "auto": false, "pellets": 8, "cost": 1500, "sound": "shot_shotgun", "reload_snd": "reload_shotgun", "recoil": 4.0, "range": 20,
		"pap": { "name": "Raid", "dmg": 160, "mag": 8, "res": 64 } },
	"m14": { "name": "M14", "class": "fusil", "model": "gun_m14", "len": 1.0, "dmg": 110, "head": 2.5, "rpm": 260, "mag": 8, "res": 92, "reload": 1.8,
		"spread": 1.6, "ads_spread": 0.2, "auto": false, "pellets": 1, "cost": 500, "sound": "shot_rifle", "reload_snd": "reload_rifle", "recoil": 2.2, "range": 80,
		"pap": { "name": "Mnesia", "dmg": 250, "mag": 15, "res": 150, "auto": true, "rpm": 400 } },
	"mp40": { "name": "MP40", "class": "subfusil", "model": "gun_mp40", "len": 0.8, "dmg": 45, "head": 2.0, "rpm": 520, "mag": 32, "res": 192, "reload": 2.3,
		"spread": 2.6, "ads_spread": 0.9, "auto": true, "pellets": 1, "cost": 1000, "sound": "shot_smg", "reload_snd": "reload_rifle", "recoil": 0.9, "range": 40,
		"pap": { "name": "The Afterburner", "dmg": 110, "mag": 64, "res": 384 } },
	"mp5k": { "name": "MP5K", "class": "subfusil", "model": "gun_mp5k", "len": 0.45, "dmg": 50, "head": 2.0, "rpm": 750, "mag": 30, "res": 210, "reload": 2.1,
		"spread": 2.8, "ads_spread": 1.0, "auto": true, "pellets": 1, "cost": 1000, "sound": "shot_smg", "reload_snd": "reload_rifle", "recoil": 0.8, "range": 35,
		"pap": { "name": "MP115 Kollider", "dmg": 120, "mag": 40, "res": 320 } },
	"ak74u": { "name": "AK-74u", "class": "subfusil", "model": "gun_ak74u", "len": 0.7, "dmg": 55, "head": 2.0, "rpm": 700, "mag": 20, "res": 160, "reload": 2.0,
		"spread": 2.5, "ads_spread": 0.8, "auto": true, "pellets": 1, "cost": 1200, "sound": "shot_smg", "reload_snd": "reload_rifle", "recoil": 1.0, "range": 40,
		"pap": { "name": "AK-74fu2", "dmg": 130, "mag": 40, "res": 280 } },
	"m16": { "name": "M16", "class": "fusil", "model": "gun_m16", "len": 1.0, "dmg": 70, "head": 2.2, "rpm": 650, "mag": 30, "res": 120, "reload": 2.2,
		"spread": 2.0, "ads_spread": 0.4, "auto": true, "pellets": 1, "cost": 1200, "sound": "shot_rifle", "reload_snd": "reload_rifle", "recoil": 1.1, "range": 70,
		"pap": { "name": "Skullcrusher", "dmg": 160, "mag": 30, "res": 240 } },
	"commando": { "name": "Commando", "class": "fusil", "model": "gun_commando", "len": 0.85, "dmg": 85, "head": 2.2, "rpm": 750, "mag": 30, "res": 240, "reload": 2.3,
		"spread": 2.1, "ads_spread": 0.4, "auto": true, "pellets": 1, "cost": 0, "sound": "shot_rifle", "reload_snd": "reload_rifle", "recoil": 1.1, "range": 70,
		"pap": { "name": "Predator", "dmg": 190, "mag": 40, "res": 360 } },
	"galil": { "name": "Galil", "class": "fusil", "model": "gun_galil", "len": 0.95, "dmg": 75, "head": 2.2, "rpm": 650, "mag": 35, "res": 315, "reload": 2.6,
		"spread": 2.1, "ads_spread": 0.4, "auto": true, "pellets": 1, "cost": 0, "sound": "shot_rifle", "reload_snd": "reload_rifle", "recoil": 1.0, "range": 70,
		"pap": { "name": "Lamentation", "dmg": 170, "mag": 50, "res": 400 } },
	"rpk": { "name": "RPK", "class": "ametralladora", "model": "gun_rpk2", "len": 1.05, "dmg": 70, "head": 2.0, "rpm": 600, "mag": 100, "res": 400, "reload": 4.2,
		"spread": 3.0, "ads_spread": 0.8, "auto": true, "pellets": 1, "cost": 0, "sound": "shot_lmg", "reload_snd": "reload_lmg", "recoil": 1.0, "range": 70,
		"pap": { "name": "R115 Resonator", "dmg": 160, "mag": 125, "res": 500 } },
	"spas": { "name": "SPAS-12", "class": "escopeta", "model": "gun_spas", "len": 1.0, "dmg": 70, "head": 1.5, "rpm": 150, "mag": 8, "res": 56, "reload": 3.4,
		"spread": 5.0, "ads_spread": 3.8, "auto": false, "pellets": 8, "cost": 0, "sound": "shot_shotgun", "reload_snd": "reload_shotgun", "recoil": 3.6, "range": 20,
		"pap": { "name": "SPAZ-24", "dmg": 170, "mag": 24, "res": 96 } },
	"l96": { "name": "L96A1", "class": "francotirador", "model": "gun_l96", "len": 1.15, "dmg": 900, "head": 3.0, "rpm": 55, "mag": 5, "res": 40, "reload": 3.4,
		"spread": 8.0, "ads_spread": 0.0, "auto": false, "pellets": 1, "cost": 0, "sound": "shot_sniper", "reload_snd": "reload_rifle", "recoil": 5.0, "range": 200, "scope": true,
		"pap": { "name": "Destructor", "dmg": 3000, "mag": 8, "res": 60 } },
	# armas maravilla (solo en la caja, muy raras)
	"raygun": { "name": "Rayo Gamba", "class": "maravilla", "model": "proc_raygun", "len": 0.42, "dmg": 1100, "head": 1.0, "rpm": 180, "mag": 20, "res": 160, "reload": 2.6,
		"spread": 0.8, "ads_spread": 0.3, "auto": false, "pellets": 1, "cost": 0, "sound": "shot_ray", "reload_snd": "reload_pistol", "recoil": 1.0, "range": 80,
		"projectile": { "speed": 55.0, "splash": 1.8, "splash_dmg": 700, "color": Color(0.3, 1.0, 0.35) },
		"pap": { "name": "Rayo Gamba Mk II", "dmg": 2600, "mag": 40, "res": 240, "projectile": { "speed": 70.0, "splash": 2.4, "splash_dmg": 1800, "color": Color(1.0, 0.25, 0.25) } } },
	"bubble": { "name": "Burbujeador", "class": "maravilla", "model": "proc_bubble", "len": 0.62, "dmg": 0, "head": 1.0, "rpm": 70, "mag": 4, "res": 24, "reload": 3.2,
		"spread": 0.5, "ads_spread": 0.2, "auto": false, "pellets": 1, "cost": 0, "sound": "shot_bubble", "reload_snd": "reload_lmg", "recoil": 2.0, "range": 60,
		"projectile": { "speed": 16.0, "bubble": 3.0, "color": Color(0.5, 0.85, 1.0) },
		"pap": { "name": "Burbujeador XL", "mag": 8, "res": 48, "projectile": { "speed": 20.0, "bubble": 4.5, "color": Color(1.0, 0.5, 0.9) } } },
}
# la caja: armas que pueden salir (las de pared también), más peso = más probable
const BOX_POOL := { "raygun": 1, "bubble": 1, "rpk": 3, "galil": 4, "commando": 4, "spas": 3, "l96": 2, "python": 2, "ak74u": 2, "m16": 2, "mp5k": 2, "stakeout": 2, "mp40": 1, "olympia": 1, "m14": 1 }

# ---------------------------------------------------------------- ventajas (bebidas)
const PERKS := {
	"jugg": { "name": "Juggernog", "cost": 2500, "color": Color(0.85, 0.12, 0.1), "desc": "Aguantas el doble de golpes" },
	"speed": { "name": "Speed Cola", "cost": 3000, "color": Color(0.15, 0.75, 0.25), "desc": "Recargas el doble de rápido" },
	"dtap": { "name": "Double Tap", "cost": 2000, "color": Color(0.95, 0.75, 0.1), "desc": "Disparas más rápido" },
	"revive": { "name": "Quick Revive", "cost": 1500, "color": Color(0.2, 0.55, 1.0), "desc": "Te levantas una vez al caer" },
	"stamin": { "name": "Stamin-Up", "cost": 2000, "color": Color(1.0, 0.55, 0.15), "desc": "Corres más y más tiempo" },
	"mule": { "name": "Mule Kick", "cost": 4000, "color": Color(0.25, 0.55, 0.3), "desc": "Llevas un tercer arma" },
}

# ---------------------------------------------------------------- chicles (como los GobbleGum de Black Ops 3)
# dur: segundos que dura (0 = al momento, -1 = se gasta al ocurrir algo)
const GUMS := {
	"eterno": { "name": "Cargador Eterno", "desc": "No gastas balas durante 60 s", "dur": 60.0, "color": Color(0.95, 0.75, 0.15), "level": 1 },
	"doble": { "name": "Doble Ración", "desc": "Tus puntos valen el doble 60 s", "dur": 60.0, "color": Color(0.3, 0.85, 0.35), "level": 1 },
	"recarga": { "name": "Recarga Total", "desc": "Munición al máximo ahora", "dur": 0.0, "color": Color(0.85, 0.85, 0.85), "level": 2 },
	"vuelta": { "name": "Segunda Oportunidad", "desc": "Si caes, te levantas al instante", "dur": -1.0, "color": Color(0.2, 0.55, 1.0), "level": 3 },
	"patas": { "name": "Patas de Langosta", "desc": "Corres y recargas más rápido 90 s", "dur": 90.0, "color": Color(1.0, 0.45, 0.15), "level": 5 },
	"caja": { "name": "Caja Generosa", "desc": "La próxima caja da un arma maravilla", "dur": -1.0, "color": Color(0.6, 0.3, 1.0), "level": 8 },
	"marea": { "name": "Marea Roja", "desc": "Mata a todos los zombis cercanos", "dur": 0.0, "color": Color(0.9, 0.1, 0.1), "level": 12 },
	"pinza": { "name": "Pinza Mortal", "desc": "Matas de un golpe 45 s", "dur": 45.0, "color": Color(0.95, 0.95, 0.95), "level": 16 },
	"caparazon": { "name": "Caparazón", "desc": "Recibes la mitad de daño 60 s", "dur": 60.0, "color": Color(0.55, 0.35, 0.2), "level": 20 },
}

# ---------------------------------------------------------------- easter egg principal (historia de cada mapa)
const EGG := {
	"prison": { "part": "pieza de la radio", "parts": "piezas de la radio", "item": "la radio del alcaide", "altar": "la máquina Pack-a-Punch",
		"intro": "El alcaide escondió una radio por la cárcel. Si la montas, quizá alguien venga a por vosotros.",
		"defend": "¡La señal atrae a algo enorme! Aguanta junto a la radio.",
		"end": "El Bruto ha caído. La radio emite una voz: «Aquí la Patrulla Gamba… vamos a por vosotros». FIN… por ahora." },
	"pueblo": { "part": "pieza del autobús", "parts": "piezas del autobús", "item": "el viejo autobús del pueblo", "altar": "la máquina Pack-a-Punch",
		"intro": "El autobús que sacaba a la gente del pueblo quedó hecho pedazos. Reúne las piezas: quizá aún arranque.",
		"defend": "¡El motor ruge y la lava del cruce se agita! Aguanta junto a la máquina.",
		"end": "La bestia de la lava ha caído. A lo lejos se oye un claxon: el autobús viene a por vosotros. FIN… por ahora." },
}

# ---------------------------------------------------------------- potenciadores
const POWERUPS := ["max_ammo", "insta_kill", "double_points", "nuke", "carpenter", "fire_sale"]
const POWERUP_NAMES := { "max_ammo": "MUNICIÓN MÁXIMA", "insta_kill": "MUERTE INSTANTÁNEA", "double_points": "DOBLES PUNTOS", "nuke": "NUCLEAR", "carpenter": "CARPINTERO", "fire_sale": "REBAJAS" }

# ---------------------------------------------------------------- progresión (como en Black Ops 4: subes de nivel y desbloqueas)
const XP_PER_LEVEL_BASE := 1500
static func xp_for_level(lv: int) -> int: return int(XP_PER_LEVEL_BASE * pow(lv, 1.35))
# qué se desbloquea en cada nivel
const UNLOCKS := [
	{ "level": 1, "kind": "start_weapon", "id": "m1911", "text": "M1911 (arma inicial)" },
	{ "level": 2, "kind": "title", "id": "superviviente", "text": "Título: Superviviente" },
	{ "level": 2, "kind": "gum", "id": "recarga", "text": "Chicle: Recarga Total" },
	{ "level": 3, "kind": "start_round", "id": "5", "text": "Empezar en la ronda 5" },
	{ "level": 3, "kind": "gum", "id": "vuelta", "text": "Chicle: Segunda Oportunidad" },
	{ "level": 4, "kind": "character", "id": "chaqueta", "text": "Personaje: Gamba con Chaqueta" },
	{ "level": 5, "kind": "start_weapon", "id": "python", "text": "Empezar con la Python" },
	{ "level": 5, "kind": "gum", "id": "patas", "text": "Chicle: Patas de Langosta" },
	{ "level": 6, "kind": "card", "id": "oxido", "text": "Tarjeta: Óxido" },
	{ "level": 7, "kind": "start_round", "id": "10", "text": "Empezar en la ronda 10" },
	{ "level": 8, "kind": "character", "id": "langostino", "text": "Personaje: Langostino" },
	{ "level": 8, "kind": "gum", "id": "caja", "text": "Chicle: Caja Generosa" },
	{ "level": 9, "kind": "start_weapon", "id": "mp5k", "text": "Empezar con el MP5K" },
	{ "level": 10, "kind": "points", "id": "250", "text": "+250 puntos al empezar" },
	{ "level": 11, "kind": "start_perk", "id": "revive", "text": "Empezar con Quick Revive" },
	{ "level": 12, "kind": "character", "id": "langosta", "text": "Personaje: Langosta" },
	{ "level": 12, "kind": "gum", "id": "marea", "text": "Chicle: Marea Roja" },
	{ "level": 13, "kind": "start_round", "id": "15", "text": "Empezar en la ronda 15" },
	{ "level": 14, "kind": "title", "id": "cazazombis", "text": "Título: Cazazombis" },
	{ "level": 15, "kind": "start_weapon", "id": "m16", "text": "Empezar con el M16" },
	{ "level": 16, "kind": "character", "id": "cangrejo", "text": "Personaje: Bogavante" },
	{ "level": 16, "kind": "gum", "id": "pinza", "text": "Chicle: Pinza Mortal" },
	{ "level": 17, "kind": "card", "id": "abismo", "text": "Tarjeta: Abismo" },
	{ "level": 18, "kind": "start_round", "id": "20", "text": "Empezar en la ronda 20" },
	{ "level": 19, "kind": "points", "id": "500", "text": "+500 puntos al empezar" },
	{ "level": 20, "kind": "start_perk", "id": "jugg", "text": "Empezar con Juggernog" },
	{ "level": 20, "kind": "gum", "id": "caparazon", "text": "Chicle: Caparazón" },
	{ "level": 22, "kind": "title", "id": "pescador", "text": "Título: Pescador de Muertos" },
	{ "level": 23, "kind": "card", "id": "sangre", "text": "Tarjeta: Sangre" },
	{ "level": 25, "kind": "start_round", "id": "25", "text": "Empezar en la ronda 25" },
	{ "level": 27, "kind": "title", "id": "rey", "text": "Título: Rey del Marisco" },
	{ "level": 28, "kind": "points", "id": "750", "text": "+750 puntos al empezar" },
	{ "level": 30, "kind": "start_weapon", "id": "galil", "text": "Empezar con la Galil" },
	{ "level": 32, "kind": "card", "id": "eter", "text": "Tarjeta: Éter" },
	{ "level": 35, "kind": "title", "id": "leyenda", "text": "Título: Leyenda de la Isla" },
	{ "level": 40, "kind": "card", "id": "oro", "text": "Tarjeta: Oro" },
	{ "level": 45, "kind": "points", "id": "1000", "text": "+1000 puntos al empezar" },
	{ "level": 50, "kind": "title", "id": "inmortal", "text": "Título: Inmortal" },
]
const TITLES := { "": "Recluta", "superviviente": "Superviviente", "cazazombis": "Cazazombis", "pescador": "Pescador de Muertos", "rey": "Rey del Marisco", "leyenda": "Leyenda de la Isla", "inmortal": "Inmortal" }
# tarjetas de jugador: degradado de dos colores
const CARDS := { "": [Color(0.12, 0.13, 0.16), Color(0.05, 0.05, 0.07)], "oxido": [Color(0.55, 0.25, 0.08), Color(0.12, 0.05, 0.02)], "abismo": [Color(0.05, 0.3, 0.45), Color(0.01, 0.04, 0.1)],
	"sangre": [Color(0.6, 0.03, 0.05), Color(0.1, 0.0, 0.01)], "eter": [Color(0.45, 0.2, 0.75), Color(0.05, 0.02, 0.15)], "oro": [Color(0.95, 0.7, 0.2), Color(0.3, 0.17, 0.02)] }

# desafíos: se completan una vez y dan experiencia (stat "w:<arma>" = bajas con esa arma, "round_<mapa>" = mejor ronda)
var CHALLENGES = []
func _init() -> void:
	var add = func(id, text, stat, goals, xps):
		for i in goals.size(): CHALLENGES.append({ "id": "%s_%d" % [id, i], "text": (text % goals[i]) if text.contains("%d") else text, "stat": stat, "goal": goals[i], "xp": xps[i], "tier": i })
	add.call("kills", "Mata %d zombis", "kills", [100, 500, 2000, 5000], [500, 1500, 4000, 8000])
	add.call("heads", "Mata %d zombis de un tiro a la cabeza", "heads", [50, 250, 1000], [600, 2000, 5000])
	add.call("knife", "Mata %d zombis con el cuchillo", "knife", [25, 100, 300], [600, 1800, 4000])
	add.call("explo", "Mata %d zombis con explosivos", "explo", [25, 150, 500], [600, 2000, 4500])
	for m in [["prison", "la Penitenciaría"], ["pueblo", "el Pueblo"]]:
		add.call("round_" + m[0], "Llega a la ronda %d en " + m[1], "round_" + m[0], [10, 20, 30], [800, 2500, 6000])
	add.call("perks", "Bebe %d refrescos", "perks", [10, 50, 150], [500, 1500, 3500])
	add.call("box", "Usa la caja misteriosa %d veces", "box", [10, 50, 150], [500, 1500, 3500])
	add.call("pap", "Mejora %d armas en el Pack-a-Punch", "pap", [5, 25, 75], [800, 2500, 5000])
	add.call("doors", "Abre %d puertas", "doors", [20, 100], [500, 1500])
	add.call("powerups", "Recoge %d potenciadores", "powerups", [10, 50], [500, 1500])
	add.call("games", "Juega %d partidas", "games", [5, 25, 100], [400, 1500, 5000])
	add.call("dogs", "Mata %d perros infernales", "dogs", [20, 100, 300], [600, 1800, 4000])
	add.call("brutes", "Mata %d Brutos", "brutes", [1, 10, 30], [800, 2500, 6000])
	add.call("gums", "Mastica %d chicles", "gums", [5, 30, 100], [400, 1500, 4000])
	add.call("revives", "Reanima %d veces a un compañero", "revives", [1, 10, 50], [500, 1500, 4000])
	for m in [["prison", "la Penitenciaría"], ["pueblo", "el Pueblo"]]:
		add.call("egg_" + m[0], "Completa el easter egg de " + m[1], "egg_" + m[0], [1], [5000])
		add.call("song_" + m[0], "Encuentra la canción oculta de " + m[1], "song_" + m[0], [1], [1000])
	for id in WEAPONS:
		add.call("w_" + id, "Mata %d zombis con " + WEAPONS[id].name, "w:" + id, [75, 300], [700, 2000])

# camuflajes: se ganan con bajas de cada arma (como en los Black Ops)
const CAMOS := [
	{ "id": "none", "name": "Ninguno", "kills": 0, "color": Color(1, 1, 1), "metal": 0.0, "rough": 1.0 },
	{ "id": "desert", "name": "Desierto", "kills": 50, "color": Color(0.78, 0.66, 0.45), "metal": 0.1, "rough": 0.8, "pattern": "camo" },
	{ "id": "woodland", "name": "Bosque", "kills": 100, "color": Color(0.35, 0.45, 0.25), "metal": 0.1, "rough": 0.8, "pattern": "camo" },
	{ "id": "tiger", "name": "Tigre", "kills": 200, "color": Color(0.9, 0.5, 0.1), "metal": 0.1, "rough": 0.7, "pattern": "stripes" },
	{ "id": "red", "name": "Rojo Sangre", "kills": 350, "color": Color(0.6, 0.05, 0.05), "metal": 0.3, "rough": 0.5 },
	{ "id": "gold", "name": "Oro", "kills": 500, "color": Color(1.0, 0.78, 0.3), "metal": 1.0, "rough": 0.25 },
	{ "id": "diamond", "name": "Diamante", "kills": 1000, "color": Color(0.75, 0.9, 1.0), "metal": 1.0, "rough": 0.1, "pattern": "facets" },
]

# ---------------------------------------------------------------- personajes (los de la versión anterior)
# head: hacia dónde mira la cabeza en el modelo original (+1 = +X, -1 = -X); len = largo en metros
const CHARACTERS := {
	"comando": { "name": "Comando", "file": "comando", "human": true, "height": 1.82, "head": 1, "len": 0.5, "level": 1, "desc": "Fuerzas especiales. Boina, camuflaje y cero miedo a los muertos." },
	"gamba": { "name": "Gamba", "file": "gamba", "head": 1, "len": 1.5, "level": 1, "desc": "La de siempre. Rosa, valiente y con antenas larguísimas." },
	"chaqueta": { "name": "Gamba con Chaqueta", "file": "gamba_chaqueta", "head": 1, "len": 1.5, "level": 4, "desc": "Va de uniforme. Lista para la guerra." },
	"langostino": { "name": "Langostino", "file": "langostino", "head": 1, "len": 1.4, "level": 8, "desc": "Un langostino de verdad, cocido y de mal humor." },
	"langosta": { "name": "Langosta", "file": "langosta_a", "head": -1, "len": 1.5, "level": 12, "desc": "Roja como un tomate y el doble de dura." },
	"cangrejo": { "name": "Bogavante", "file": "langosta_c", "head": 1, "len": 1.6, "level": 16, "desc": "El jefe del fondo del mar." },
}

# ---------------------------------------------------------------- mapas
const MAPS := ["prison", "pueblo"]
