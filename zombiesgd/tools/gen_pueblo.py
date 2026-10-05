#!/usr/bin/env python3
"""Genera assets/maps/pueblo/map.json: «Pueblo», un cruce de un pueblo americano quemado (inspirado en el Town de
Black Ops 2, pero con modelos libres y distribución propia).
Calles: la principal va de oeste a este (eje X) y la secundaria de norte a sur (eje Z); el cruce está en (0, 0) y
tiene una grieta de lava. En cada esquina hay un edificio con su puerta: Banco (NE), Bar (NO), Diner (SO) y la
Gasolinera (SE, por la calle Este). Las tres calles que salen del cruce están cortadas con barricadas.
Zonas: A Cruce (inicio), B Banco, C Bar, D Diner, E Calle Este + Gasolinera, N Calle Norte (bomberos, Pack-a-Punch),
W Calle Oeste (iglesia), S Calle Sur (casa)."""
import json, math, random
random.seed(7)
M = "res://assets/maps/pueblo/models/"
B = []   # geometría añadida
P = []   # piezas (modelos)
def box(x, y, z, w, h, d, m, r=0, c=True): B.append({"t": "box", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [round(w, 3), round(h, 3), round(d, 3)], "r": r, "m": m, "c": c})
def prop(name, pos, rot=0, scale=1.0, **kw):
    d = {"scene": M + name + "/scene.gltf", "name": name, "pos": [round(v, 3) for v in pos], "rot": rot, "scale": scale}
    d.update(kw); P.append(d)

R = 5.0      # media calzada
SW = 8.3     # borde exterior de la acera
EXT = 60.0   # hasta dónde llega el suelo

# ------------------------------------------------------------------ suelo
box(0, -0.3, 0, 2 * EXT + 40, 0.3, 2 * EXT + 40, "burned")                 # tierra quemada alrededor
box(0, 0, 0, 2 * EXT, 0.02, 2 * R, "asphalt")                               # calle principal (O-E)
box(0, 0, 0, 2 * R, 0.02, 2 * EXT, "asphalt")                               # calle secundaria (N-S)
for sx in (-1, 1):
    for sz in (-1, 1):
        # aceras en L de cada esquina (un escalón de 12 cm)
        box(sx * (R + EXT) / 2 + sx * 0.0, 0, sz * (R + SW) / 2, EXT - R, 0.12, SW - R, "sidewalk")
        box(sx * (R + SW) / 2, 0, sz * (R + EXT) / 2, SW - R, 0.12, EXT - R, "sidewalk")

# ------------------------------------------------------------------ grieta de lava en el cruce (zigzag de trozos)
crack = [(-10.5, -6.6), (-7.4, -4.6), (-5.0, -3.6), (-2.8, -1.4), (-0.4, -0.6), (1.6, 1.4), (3.8, 2.2), (5.6, 4.4), (8.0, 5.4), (10.8, 7.6)]
B.append({"t": "crack", "pts": [list(p) for p in crack], "w": 1.5, "seed": 11})
HAZ = [{"a": list(a), "b": list(b), "r": 0.75} for a, b in zip(crack, crack[1:])]

# ------------------------------------------------------------------ edificios
# Banco (NE): fachada a +Z, mirando a la calle principal
BANK = (14.0, -13.2)
prop("bank", (BANK[0], 0, BANK[1]))
# tienda de ladrillo al lado (solo fachada)
prop("brick_shop", (33.5, -4.47, -12.0))
# Bar (NO): interior de saloon, abierto por +Z; se cierra con una fachada con puerta
BAR_X0, BAR_X1, BAR_Z0, BAR_Z1 = -17.33, -8.5, -22.09, -8.3
prop("saloon_interior", (-11.04, 0, -5.8), 0, 125.0)
DOOR_BAR = -12.9
box((BAR_X0 + DOOR_BAR - 1.0) / 2, 0, BAR_Z1 - 0.1, DOOR_BAR - 1.0 - BAR_X0, 5.0, 0.3, "brick")
box((DOOR_BAR + 1.0 + BAR_X1) / 2, 0, BAR_Z1 - 0.1, BAR_X1 - DOOR_BAR - 1.0, 5.0, 0.3, "brick")
box(DOOR_BAR, 2.7, BAR_Z1 - 0.1, 2.0, 2.3, 0.3, "brick")
# tiendas viejas al oeste del bar
prop("old_buildings", (-30.5, 0, -12.0), -90)
# Diner (SO): fachada a -Z (girado 180°)
DINER = (-20.5, 14.8)
prop("diner", (DINER[0], 0, DINER[1]), 180, nocollide=["Napkin", "ketchup", "Sauce", "Salt", "lemons", "Donus", "Package", "Bread", "caps", "MENU", "Paper", "Tray", "Glass", "Lights", "Coffee", "Tumbler"])
# Gasolinera (SE, por la calle Este): marquesina hacia la calle, tienda al fondo
prop("gas", (27.7, 0, 19.2), 180)
# fondo de las calles
prop("fire_station", (0, 0, -50.5))                           # bomberos al final de la calle Norte
prop("church", (-49.0, 3.12, 0), 0, 3.0)                       # iglesia al final de la calle Oeste
prop("house", (0, 0.14, 47.0), 0, 0.0065)                      # casa al final de la calle Sur
prop("saloon_exterior", (-36.0, 3.87, 14.0), 180, 5.0)         # bar viejo en la calle Oeste
prop("water_tower", (-44.0, 0, -42.0), 0, 0.5, collide=False)  # depósito de agua a lo lejos

# ------------------------------------------------------------------ coches quemados, farolas y barricadas de calle
prop("police_cars_burned", (-3.0, 0, -15.0), 20, 0.0085)
prop("burned_cars", (16.0, 0, 2.5), -75, 0.016)
for (x, z, r) in [(-7.4, -18.0, 0), (7.4, 18.0, 180), (-18.0, 7.4, 90), (18.0, -7.4, -90)]:
    prop("street_pack", (x, 0.12, z), r, 0.5, only=["Hydrant"])

# ------------------------------------------------------------------ vallas de tablones entre edificios (todo lo que corta el paso se ve)
def fence(x0, z0, x1, z1, h=2.6):
    L = math.hypot(x1 - x0, z1 - z0); a = math.degrees(math.atan2(x1 - x0, z1 - z0))
    box((x0 + x1) / 2, 0, (z0 + z1) / 2, 0.2, h, L, "wood", a)
fence(10.2, -8.6, 10.2, -18.5)      # entre la calle Norte y el banco
fence(17.8, -8.6, 21.2, -8.6)       # entre banco y tienda de ladrillo
fence(-8.3, -8.6, -8.3, -22.5)      # lateral del bar a la calle Norte
fence(-17.5, -8.6, -19.5, -8.6)     # entre bar y tiendas viejas
fence(-8.3, 8.6, -8.3, 22.0)        # lateral del diner a la calle Sur
fence(8.3, 8.6, 8.3, 22.0)          # lateral de la gasolinera a la calle Sur

# ------------------------------------------------------------------ zonas
Z = [
 {"id": "A", "name": "El Cruce", "open": True, "boxes": [[-22.0, -1, -SW, 22.0, 6, SW], [-SW, -1, -22.0, SW, 6, -SW], [-SW, -1, SW, SW, 6, 22.0]],
  "spawns": [[-21.0, 0, -6.5], [21.0, 0, 6.5], [-6.5, 0, -21.0], [6.5, 0, 21.0], [-21.0, 0, 6.5], [21.0, 0, -6.5]]},
 {"id": "B", "name": "Banco", "boxes": [[10.6, -1, -17.8, 17.4, 8.0, -8.5]], "spawns": [[11.2, 0, -17.2], [16.8, 0, -17.2]]},
 {"id": "C", "name": "Bar", "boxes": [[BAR_X0 + 0.2, -1, BAR_Z0 + 0.2, BAR_X1 - 0.2, 7.0, BAR_Z1 - 0.3]], "spawns": [[-16.6, 0, -21.4], [-9.2, 0, -21.4]]},
 {"id": "D", "name": "Diner", "boxes": [[-28.8, -1, 8.6, -12.4, 5.0, 25.0]], "spawns": [[-28.0, 0, 24.0], [-13.0, 0, 24.0]]},
 {"id": "E", "name": "Gasolinera", "boxes": [[22.0, -1, -SW, 58.0, 4.0, SW], [8.6, -1, SW, 58.0, 4.0, 34.0]], "spawns": [[57.0, 0, 0.0], [56.0, 0, 33.0], [10.0, 0, 33.0]]},
 {"id": "N", "name": "Calle Norte", "boxes": [[-SW, -1, -40.0, SW, 7.0, -22.0]], "spawns": [[-7.5, 0, -39.0], [7.5, 0, -39.0]]},
 {"id": "W", "name": "Calle Oeste", "boxes": [[-44.0, -1, -SW, -22.0, 7.0, SW]], "spawns": [[-43.0, 0, -7.5], [-43.0, 0, 7.5]]},
 {"id": "S", "name": "Calle Sur", "boxes": [[-SW, -1, 22.0, SW, 7.0, 40.0]], "spawns": [[-7.5, 0, 39.0], [7.5, 0, 39.0]]},
]
D = [
 {"cost": 750, "pos": [BANK[0], 0, -8.6], "size": [2.4, 2.6, 1.0], "yaw": 0, "opens": ["A", "B"]},
 {"cost": 1000, "pos": [DOOR_BAR, 0, BAR_Z1 - 0.1], "size": [2.0, 2.6, 1.0], "yaw": 0, "opens": ["A", "C"]},
 {"cost": 1000, "pos": [DINER[0] - 0.51, 0, DINER[1] - 2.6], "size": [1.2, 2.4, 1.0], "yaw": 0, "opens": ["A", "D"], "kind": "hide", "hide_meshes": ["Door_03"]},
 {"cost": 1250, "pos": [22.0, 0, 0], "size": [2 * SW, 3.0, 1.2], "yaw": 90, "opens": ["A", "E"]},
 {"cost": 1000, "pos": [0, 0, -22.0], "size": [2 * SW, 3.0, 1.2], "yaw": 0, "opens": ["A", "N"]},
 {"cost": 1000, "pos": [-22.0, 0, 0], "size": [2 * SW, 3.0, 1.2], "yaw": 90, "opens": ["A", "W"]},
 {"cost": 1250, "pos": [0, 0, 22.0], "size": [2 * SW, 3.0, 1.2], "yaw": 0, "opens": ["A", "S"]},
]
# bordes del mapa: al final de cada calle, barricada grande con coches (y pared por si acaso, detrás de lo que se ve)
WALLS = []
for (x, z, r, w) in [(0, -40.6, 0, 2 * SW), (-44.6, 0, 90, 2 * SW), (0, 40.6, 0, 2 * SW), (58.6, 0, 90, 2 * SW)]:
    for k in range(-2, 3):
        o = k * 3.3
        px, pz = (x + o, z) if r == 0 else (x, z + o)
        prop("street_pack", (px, 0, pz), r + random.choice([0, 180]), 0.5, only=["concrete_barrier"])
    WALLS.append([x, 2.0, z, w if r == 0 else 0.6, 6.0, 0.6 if r == 0 else w])

fires = [[-3.0, 0.6, -15.0], [16.0, 0.5, 2.5], [2.5, 0.2, 0.8], [-5.5, 0.2, -3.2], [6.0, 0.2, 4.4]]
lights = [{"pos": [f[0], 1.6, f[2]], "color": [1.0, 0.45, 0.15], "range": 9, "energy": 2.2} for f in fires]
lights += [{"pos": [x, 4.5, z], "color": [1.0, 0.8, 0.55], "range": 12, "energy": 1.4} for (x, z) in [(-7.5, -7.5), (7.5, 7.5), (30, -7.5), (-30, 7.5), (0, -30), (0, 30), (40, 20)]]
lights += [{"pos": [x, 2.4, z], "color": [1.0, 0.78, 0.5], "range": 7, "energy": 1.2} for (x, z) in [(14, -14), (-13, -15), (-20.5, 16), (45, 25)]]

cfg = {
 "name": "Pueblo",
 "props": P, "build": B, "textures": "res://assets/maps/pueblo/textures/",
 "walls": WALLS,
 "spawn": [0.0, 0.2, 5.5, 180],
 "ambient": "amb1",
 "env": {"sky_top": [0.05, 0.05, 0.09], "sky_horizon": [0.32, 0.14, 0.1], "sky_energy": 0.6, "ambient": 0.55, "exposure": 1.05,
         "fog": [0.25, 0.12, 0.08], "fog_density": 0.016, "sun": 0.55, "sun_color": [0.75, 0.75, 1.0], "sun_rot": [-38, 120], "saturation": 0.85,
         "ambient_color": [0.32, 0.27, 0.3]},
 "zones": Z, "doors": D,
 "fires": fires, "hazards": HAZ, "lights": lights,
 "wallbuys": [
  {"gun": "olympia", "near": [-8.6, -14.0], "y": 0}, {"gun": "m14", "near": [8.6, 14.0], "y": 0},
  {"gun": "mp5k", "near": [17.4, -12.0], "y": 0}, {"gun": "ak74u", "near": [-16.9, -18.0], "y": 0},
  {"gun": "mp40", "near": [-28.5, 18.0], "y": 0}, {"gun": "m16", "near": [40.0, 8.0], "y": 0},
  {"gun": "stakeout", "near": [-7.9, -32.0], "y": 0}, {"gun": "python", "near": [-36.0, -8.0], "y": 0}],
 "perks": [
  {"id": "revive", "near": [-7.6, 12.0], "y": 0}, {"id": "jugg", "near": [-9.2, -20.5], "y": 0},
  {"id": "speed", "near": [45.0, 30.0], "y": 0}, {"id": "dtap", "near": [16.8, -16.0], "y": 0},
  {"id": "stamin", "near": [-40.0, -7.6], "y": 0}, {"id": "mule", "near": [-14.0, 22.0], "y": 0}],
 "box": [{"near": [7.6, -14.0], "y": 0}, {"near": [-16.6, -12.0], "y": 0}, {"near": [-25.0, 22.0], "y": 0}, {"near": [50.0, 6.0], "y": 0}, {"near": [7.6, 34.0], "y": 0}],
 "box_start": 0,
 "pap": {"near": [0.0, -38.0], "y": 0},
 "power": {"near": [-42.0, 6.0], "y": 0},
 "gum": {"near": [7.6, -4.0], "y": 0},
}
json.dump(cfg, open("/home/david/juegos-gambas/zombiesgd/assets/maps/pueblo/map.json", "w"), ensure_ascii=False, indent=1)
print("piezas", len(P), "bloques", len(B))
