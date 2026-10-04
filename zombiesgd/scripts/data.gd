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
		"spread": 1.6, "ads_spread": 0.3, "auto": false, "pellets": 1, "cost": 2200, "sound": "shot_rifle2", "reload_snd": "reload_pistol", "recoil": 3.0, "range": 60,
		"pap": { "name": "Cobra", "dmg": 600, "mag": 12, "res": 84 } },
	"olympia": { "name": "Olympia", "class": "escopeta", "model": "gun_olympia", "len": 0.95, "dmg": 50, "head": 1.5, "rpm": 120, "mag": 2, "res": 38, "reload": 2.6,
		"spread": 6.0, "ads_spread": 4.5, "auto": false, "pellets": 8, "cost": 500, "sound": "shot_rifle", "reload_snd": "shotgun_pump", "recoil": 4.0, "range": 18,
		"pap": { "name": "Hades", "dmg": 140, "mag": 4, "res": 76 } },
	"stakeout": { "name": "Stakeout", "class": "escopeta", "model": "gun_stakeout", "len": 0.95, "dmg": 60, "head": 1.5, "rpm": 80, "mag": 6, "res": 48, "reload": 3.4,
		"spread": 5.5, "ads_spread": 4.0, "auto": false, "pellets": 8, "cost": 1500, "sound": "shot_rifle", "reload_snd": "shotgun_pump", "recoil": 4.0, "range": 20,
		"pap": { "name": "Raid", "dmg": 160, "mag": 8, "res": 64 } },
	"m14": { "name": "M14", "class": "fusil", "model": "gun_m14", "len": 1.0, "dmg": 110, "head": 2.5, "rpm": 260, "mag": 8, "res": 92, "reload": 1.8,
		"spread": 1.6, "ads_spread": 0.2, "auto": false, "pellets": 1, "cost": 500, "sound": "shot_rifle", "reload_snd": "reload_rifle", "recoil": 2.2, "range": 80,
		"pap": { "name": "Mnesia", "dmg": 250, "mag": 15, "res": 150, "auto": true, "rpm": 400 } },
	"mp40": { "name": "MP40", "class": "subfusil", "model": "gun_mp40", "len": 0.8, "dmg": 45, "head": 2.0, "rpm": 520, "mag": 32, "res": 192, "reload": 2.3,
		"spread": 2.6, "ads_spread": 0.9, "auto": true, "pellets": 1, "cost": 1000, "sound": "shot_smg", "reload_snd": "reload_smg", "recoil": 0.9, "range": 40,
		"pap": { "name": "The Afterburner", "dmg": 110, "mag": 64, "res": 384 } },
	"mp5k": { "name": "MP5K", "class": "subfusil", "model": "gun_mp5k", "len": 0.45, "dmg": 50, "head": 2.0, "rpm": 750, "mag": 30, "res": 210, "reload": 2.1,
		"spread": 2.8, "ads_spread": 1.0, "auto": true, "pellets": 1, "cost": 1000, "sound": "shot_smg", "reload_snd": "reload_smg", "recoil": 0.8, "range": 35,
		"pap": { "name": "MP115 Kollider", "dmg": 120, "mag": 40, "res": 320 } },
	"ak74u": { "name": "AK-74u", "class": "subfusil", "model": "gun_ak74u", "len": 0.7, "dmg": 55, "head": 2.0, "rpm": 700, "mag": 20, "res": 160, "reload": 2.0,
		"spread": 2.5, "ads_spread": 0.8, "auto": true, "pellets": 1, "cost": 1200, "sound": "shot_rifle2", "reload_snd": "reload_rifle", "recoil": 1.0, "range": 40,
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
		"spread": 3.0, "ads_spread": 0.8, "auto": true, "pellets": 1, "cost": 0, "sound": "shot_rifle", "reload_snd": "reload_lmg", "recoil": 1.0, "range": 70,
		"pap": { "name": "R115 Resonator", "dmg": 160, "mag": 125, "res": 500 } },
	"spas": { "name": "SPAS-12", "class": "escopeta", "model": "gun_spas", "len": 1.0, "dmg": 70, "head": 1.5, "rpm": 150, "mag": 8, "res": 56, "reload": 3.4,
		"spread": 5.0, "ads_spread": 3.8, "auto": false, "pellets": 8, "cost": 0, "sound": "shot_rifle", "reload_snd": "shotgun_pump", "recoil": 3.6, "range": 20,
		"pap": { "name": "SPAZ-24", "dmg": 170, "mag": 24, "res": 96 } },
	"l96": { "name": "L96A1", "class": "francotirador", "model": "gun_l96", "len": 1.15, "dmg": 900, "head": 3.0, "rpm": 55, "mag": 5, "res": 40, "reload": 3.4,
		"spread": 8.0, "ads_spread": 0.0, "auto": false, "pellets": 1, "cost": 0, "sound": "shot_rifle2", "reload_snd": "reload_rifle", "recoil": 5.0, "range": 200, "scope": true,
		"pap": { "name": "Destructor", "dmg": 3000, "mag": 8, "res": 60 } },
}
# la caja: armas que pueden salir (las de pared también), más peso = más probable
const BOX_POOL := { "rpk": 3, "galil": 4, "commando": 4, "spas": 3, "l96": 2, "python": 2, "ak74u": 2, "m16": 2, "mp5k": 2, "stakeout": 2, "mp40": 1, "olympia": 1, "m14": 1 }

# ---------------------------------------------------------------- ventajas (bebidas)
const PERKS := {
	"jugg": { "name": "Juggernog", "cost": 2500, "color": Color(0.85, 0.12, 0.1), "desc": "Aguantas el doble de golpes" },
	"speed": { "name": "Speed Cola", "cost": 3000, "color": Color(0.15, 0.75, 0.25), "desc": "Recargas el doble de rápido" },
	"dtap": { "name": "Double Tap", "cost": 2000, "color": Color(0.95, 0.75, 0.1), "desc": "Disparas más rápido" },
	"revive": { "name": "Quick Revive", "cost": 1500, "color": Color(0.2, 0.55, 1.0), "desc": "Te levantas una vez al caer" },
	"stamin": { "name": "Stamin-Up", "cost": 2000, "color": Color(1.0, 0.55, 0.15), "desc": "Corres más y más tiempo" },
	"mule": { "name": "Mule Kick", "cost": 4000, "color": Color(0.25, 0.55, 0.3), "desc": "Llevas un tercer arma" },
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
	{ "level": 3, "kind": "start_round", "id": "5", "text": "Empezar en la ronda 5" },
	{ "level": 5, "kind": "start_weapon", "id": "python", "text": "Empezar con la Python" },
	{ "level": 7, "kind": "start_round", "id": "10", "text": "Empezar en la ronda 10" },
	{ "level": 9, "kind": "start_weapon", "id": "mp5k", "text": "Empezar con el MP5K" },
	{ "level": 11, "kind": "start_perk", "id": "revive", "text": "Empezar con Quick Revive" },
	{ "level": 13, "kind": "start_round", "id": "15", "text": "Empezar en la ronda 15" },
	{ "level": 15, "kind": "start_weapon", "id": "m16", "text": "Empezar con el M16" },
	{ "level": 18, "kind": "start_round", "id": "20", "text": "Empezar en la ronda 20" },
	{ "level": 20, "kind": "start_perk", "id": "jugg", "text": "Empezar con Juggernog" },
	{ "level": 25, "kind": "start_round", "id": "25", "text": "Empezar en la ronda 25" },
	{ "level": 30, "kind": "start_weapon", "id": "galil", "text": "Empezar con la Galil" },
]
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

# ---------------------------------------------------------------- mapas
const MAPS := ["prison", "mansion", "isla"]
