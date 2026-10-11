#!/usr/bin/env python3
"""Genera assets/maps/conservera/map.json: «La Conservera», la fábrica de Gamba Roja junto al puerto, de noche.
La nave de procesado (modelo de almacén en L) está en el centro; alrededor:
  A Muelle (inicio): tablones sobre el agua, al sur, con el pesquero amarrado
  B Patio de carga: el callejón del oeste y el patio en la esquina de la L (contenedores, carretilla, bidones)
  C Nave de procesado: dentro del almacén (líneas de procesado, oficina en alto con el interruptor de la corriente)
  D Depósitos: al este, los tanques grandes
  E Laboratorio: detrás del portón norte de la nave (aquí está la Forja)
Coordenadas: X al este, Z al sur; el almacén está en su sitio original (x -22..8, z -15..18)."""
import json, math, random
random.seed(5)
M = "res://assets/maps/conservera/models/"
B = []   # geometría añadida
P = []   # piezas (modelos)
def box(x, y, z, w, h, d, m, r=0, c=True): B.append({"t": "box", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [round(w, 3), round(h, 3), round(d, 3)], "r": r, "m": m, "c": c})
def cyl(x, y, z, rad, h, m, c=True): B.append({"t": "cyl", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [rad, h], "m": m, "c": c})
def prop(name, pos, rot=0, scale=1.0, **kw):
    d = {"scene": M + name + "/scene.gltf", "name": name, "pos": [round(v, 3) for v in pos], "rot": rot, "scale": scale}
    d.update(kw); P.append(d)
def wall(x0, z0, x1, z1, h=3.5, m="concrete", t=0.4):
    L = math.hypot(x1 - x0, z1 - z0); a = math.degrees(math.atan2(x1 - x0, z1 - z0))
    box((x0 + x1) / 2, 0, (z0 + z1) / 2, t, h, L, m, a)

# ------------------------------------------------------------------ suelo, muelle y mar
box(1.5, -0.3, -8.5, 82, 0.3, 55, "asphalt")                  # tierra firme (x -39.5..42.5, z -36..19)
box(1.5, -0.3, 24.75, 82, 0.3, 11.5, "wood")                    # muelle de tablones (z 19..30.5)
box(1.5, -1.25, 70, 300, 0.05, 80, "water", 0, False)          # el mar
box(1.5, -1.25, -4.0, 300, 0.05, 46, "black", 0, False)        # (debajo de todo, por si se ve algún hueco)
for x in range(-38, 42, 4):                                     # pilotes del muelle
    cyl(x, -1.3, 30.4, 0.18, 2.0, "wood", False)
    if x % 8 == 2: cyl(x, 0, 30.3, 0.16, 0.55, "rust")         # bolardos
for z in (21.5, 25.0, 28.5):
    cyl(-38.3, -1.3, z, 0.18, 2.0, "wood", False); cyl(41.3, -1.3, z, 0.18, 2.0, "wood", False)
box(1.5, -0.3, 30.55, 82, 0.15, 0.25, "rust", 0, False)        # borde metálico del muelle

# el pesquero amarrado (ahí acaba la misión) y otro más lejos
prop("trawler", (-14.0, 0.9, 34.0), 0, 0.011, collide=False)
prop("boat2", (24.0, -0.6, 44.0), 60, 8.0, collide=False)

# ------------------------------------------------------------------ la nave (almacén en L)
prop("warehouse", (0, 0, 0), 0, 1.0, merge=False, max_tris=90000)

# ------------------------------------------------------------------ muros del recinto
wall(-38.3, -26.3, -38.3, 19.0)                                 # oeste
wall(-38.3, -26.3, -8.0, -26.3)                                 # norte del patio
wall(14.0, -26.3, 41.3, -26.3)                                  # norte de los depósitos
wall(41.3, -26.3, 41.3, 19.0)                                   # este
# laboratorio: un bloque de hormigón pegado al norte de la nave
LAB_H = 5.0
wall(-8.0, -34.0, -8.0, -15.0, LAB_H)
wall(-8.0, -34.0, 14.0, -34.0, LAB_H)
wall(14.0, -34.0, 14.0, -15.0, LAB_H)
wall(7.6, -15.2, 14.0, -15.2, LAB_H)
box(3.0, LAB_H, -24.6, 22.4, 0.3, 19.2, "concrete")            # techo
box(3.0, 0.0, -24.6, 21.6, 0.03, 18.8, "white", 0, False)      # suelo de baldosa
# vallas de tablones entre el muelle y el patio / los depósitos (con su puerta)
def fence(x0, z0, x1, z1, h=2.6): wall(x0, z0, x1, z1, h, "wood", 0.2)
fence(-38.3, 19.0, -34.0, 19.0); fence(-26.0, 19.0, -21.0, 19.0); fence(-21.0, 19.0, -21.0, 18.1)
fence(7.8, 19.0, 12.0, 19.0); fence(20.0, 19.0, 41.3, 19.0)

# ------------------------------------------------------------------ dentro de la nave: líneas de procesado
for (x, z, r) in [(-3.0, -10.0, 0), (3.5, -10.0, 0), (-3.0, -3.0, 0), (3.5, -3.0, 0), (-16.0, 11.0, 90), (-11.5, 11.0, 90)]:
    prop("machine", (x, 0, z), r, 0.035, max_tris=6000)
# mesas de acero con cajas de gambas
for (x, z) in [(0.2, 3.5), (-4.5, 3.5), (-19.0, 15.5)]:
    box(x, 0, z, 3.2, 0.9, 1.2, "steel")
    for k in range(3): box(x - 1.0 + k, 0.9, z, 0.6, 0.25, 0.45, "crate_red")
# palés y cajas apiladas
for (x, z, n) in [(6.2, -13.5, 3), (-6.0, 15.5, 2), (-20.3, 6.2, 2), (6.0, 6.5, 2)]:
    for k in range(n): box(x, k * 0.8, z, 1.2, 0.8, 1.2, "crate_red" if k % 2 else "crate_blue")
prop("barrels", (5.6, 0, -0.5), 0, 1.0, max_tris=2500)

# ------------------------------------------------------------------ patio de carga
prop("container", (-30.0, 0, -18.0), 90, 0.47, max_tris=3000)
prop("container", (-30.0, 0, -11.5), 90, 0.47, max_tris=3000)
prop("container", (-30.0, 2.8, -14.7), 90, 0.47, max_tris=3000)
prop("container", (-16.0, 0, -22.5), 0, 0.47, max_tris=3000)
prop("container", (-33.5, 0, 6.0), 0, 0.47, max_tris=3000)
prop("container", (-17.4, 0, 2.2), 0, 0.55, max_tris=3000)        # tapa los dos portones de la nave sin puerta
prop("forklift", (-15.0, 0, -8.0), 30, 0.01)
prop("barrels", (-36.5, 0, -2.0), 0, 1.0, max_tris=2500)
prop("barrels", (-12.0, 0, -24.5), 90, 1.0, max_tris=2500)
prop("tank", (-35.5, 0, -24.0), 0, 1.2, max_tris=2000)
prop("tank", (-35.5, 0, 14.0), 0, 1.0, max_tris=2000)
for (x, z) in [(-24.0, -3.0), (-25.2, -3.0), (-24.6, -1.8)]:
    box(x, 0, z, 1.1, 1.1, 1.1, "crate_blue")

# ------------------------------------------------------------------ depósitos
prop("tanks", (31.4, 0, 0.95), 0, 0.7, max_tris=6000)
prop("tank", (19.0, 0, -22.0), 0, 1.4, max_tris=2000)
prop("tank", (23.0, 0, -22.5), 0, 1.4, max_tris=2000)
prop("container", (37.5, 0, 12.0), 0, 0.47, max_tris=3000)
prop("barrels", (11.0, 0, 6.0), 0, 1.0, max_tris=2500)

# ------------------------------------------------------------------ muelle: cajas de pescado, redes, bidones
for (x, z) in [(-30.0, 22.0), (-29.0, 22.6), (-5.0, 27.5), (-4.0, 28.2), (8.0, 21.0), (30.0, 27.0), (31.0, 27.4)]:
    box(x, 0, z, 0.9, 0.45, 0.6, "white")
    box(x, 0.45, z, 0.8, 0.06, 0.5, "fish", 0, False)
prop("barrels", (-22.0, 0, 28.5), 90, 1.0, max_tris=2500)
prop("container", (32.0, 0, 23.0), 90, 0.47, max_tris=3000)

# ------------------------------------------------------------------ laboratorio: mesas, tuberías y tanques vacíos
for (x, z) in [(-5.0, -24.0), (-5.0, -28.0), (11.0, -24.0), (11.0, -28.0)]:
    box(x, 0, z, 1.0, 0.95, 2.6, "white")
for x in (-4.0, 2.0, 8.0):
    box(x, 4.4, -24.6, 0.35, 0.35, 18.8, "steel", 0, False)    # tuberías del techo
box(3.0, 0, -33.4, 12.0, 2.2, 0.6, "steel")                     # maquinaria del fondo

# ------------------------------------------------------------------ zonas
Z = [
 {"id": "A", "name": "Muelle", "open": True, "boxes": [[-38.0, -1, 19.0, 41.0, 4.0, 30.4]],
  "spawns": [[-37.0, 0, 21.0], [40.0, 0, 21.0], [-25.0, 0, 29.8], [-3.0, 0, 29.8], [12.0, 0, 29.8], [28.0, 0, 29.8], [-37.0, 0, 29.5], [40.0, 0, 29.5]]},
 {"id": "B", "name": "Patio de carga", "boxes": [[-38.0, -1, -26.0, -22.2, 5.0, 19.0], [-22.2, -1, -26.0, -8.3, 5.0, -15.0], [-22.2, -1, -15.0, -7.6, 5.0, 4.2]],
  "spawns": [[-37.0, 0, -25.0], [-37.0, 0, 17.0], [-20.0, 0, -25.0], [-9.5, 0, -25.0], [-37.0, 0, -6.0]]},
 {"id": "C", "name": "Nave de procesado", "boxes": [[-7.5, -1, -15.0, 7.5, 7.0, 18.0], [-21.6, -1, 4.2, -7.5, 7.0, 18.0]],
  "spawns": [[-21.0, 0, 17.4], [7.0, 0, 17.4], [7.0, 0, -14.5], [-7.0, 0, -14.5], [-21.0, 0, 5.0]]},
 {"id": "D", "name": "Depósitos", "boxes": [[8.0, -1, -15.0, 41.0, 5.0, 19.0], [14.4, -1, -26.0, 41.0, 5.0, -15.0]],
  "spawns": [[40.5, 0, -25.5], [40.5, 0, 18.0], [15.0, 0, -25.5], [9.0, 0, 18.0]]},
 {"id": "E", "name": "Laboratorio", "boxes": [[-7.6, -1, -33.6, 13.6, 4.5, -15.0]],
  "spawns": [[-7.0, 0, -33.0], [13.0, 0, -33.0], [13.0, 0, -16.0]]},
]
D = [
 {"cost": 750, "pos": [-30.0, 0, 19.0], "size": [8.0, 3.0, 1.2], "yaw": 0, "opens": ["A", "B"]},
 {"cost": 1000, "pos": [16.0, 0, 19.0], "size": [8.0, 3.0, 1.2], "yaw": 0, "opens": ["A", "D"]},
 {"cost": 1000, "pos": [-10.87, 0, 4.2], "size": [3.0, 3.6, 1.0], "yaw": 0, "opens": ["B", "C"], "kind": "hide", "hide_meshes": ["SmallGateVar2"]},
 {"cost": 1500, "pos": [3.2, 0, -15.0], "size": [6.0, 4.4, 1.0], "yaw": 0, "opens": ["C", "E"], "kind": "hide", "hide_meshes": ["MainGate"]},
]
# bordes del muelle (el agua): pared invisible
WALLS = [[1.5, 1.5, 30.7, 82, 4.0, 0.4], [-38.5, 1.5, 24.75, 0.4, 4.0, 11.5], [41.5, 1.5, 24.75, 0.4, 4.0, 11.5]]

fires = [[-24.5, 0.0, 26.0], [6.0, 0.0, 22.5], [-26.0, 0.0, -6.0], [26.0, 0.0, 14.0]]
lights = [{"pos": [f[0], 1.6, f[2]], "color": [1.0, 0.45, 0.15], "range": 9, "energy": 2.0} for f in fires]
# farolas de sodio del muelle y el patio
lights += [{"pos": [x, 5.0, z], "color": [1.0, 0.68, 0.35], "range": 13, "energy": 1.5} for (x, z) in [(-30, 24), (-10, 24), (10, 24), (30, 24), (-30, -18), (-14, -6), (25, -18), (25, 10)]]
# nave: lámparas colgadas
lights += [{"pos": [x, 5.0, z], "color": [1.0, 0.88, 0.7], "range": 11, "energy": 1.3} for (x, z) in [(0, -10), (0, 0), (0, 10), (-14, 11)]]
lights += [{"pos": [3.0, 5.6, 13.5], "color": [0.8, 0.9, 1.0], "range": 6, "energy": 1.0}]
# laboratorio: fluorescentes verdosos
lights += [{"pos": [x, 4.3, z], "color": [0.7, 1.0, 0.8], "range": 10, "energy": 1.4} for (x, z) in [(-2, -20), (8, -20), (-2, -29), (8, -29)]]

cfg = {
 "name": "La Conservera",
 "props": P, "build": B, "textures": "res://assets/maps/conservera/textures/",
 "walls": WALLS,
 "spawn": [-18.0, 0.2, 25.5, 90],
 "ambient": "amb1",
 "env": {"sky_top": [0.02, 0.03, 0.06], "sky_horizon": [0.1, 0.15, 0.2], "sky_energy": 0.55, "ambient": 0.5, "exposure": 1.05,
         "fog": [0.08, 0.12, 0.16], "fog_density": 0.02, "sun": 0.4, "sun_color": [0.6, 0.7, 1.0], "sun_rot": [-35, -140], "saturation": 0.9,
         "ambient_color": [0.26, 0.3, 0.38]},
 "zones": Z, "doors": D,
 "fires": fires, "hazards": [], "lights": lights,
 "noshadow": ["barrels", "Railings", "cable", "Windows"],
 "wallbuys": [
  {"gun": "olympia", "near": [-4.0, 18.6], "y": 0}, {"gun": "m14", "near": [-8.0, -6.0], "y": 0},
  {"gun": "mp40", "near": [-20.0, -25.9], "y": 0}, {"gun": "mp5k", "near": [7.2, -6.0], "y": 0},
  {"gun": "ak74u", "near": [-21.3, 9.0], "y": 0}, {"gun": "stakeout", "near": [-2.0, -14.7], "y": 0},
  {"gun": "m16", "near": [40.9, -4.0], "y": 0}, {"gun": "python", "near": [30.0, -25.9], "y": 0}],
 "perks": [
  {"id": "revive", "near": [2.0, 18.6], "y": 0}, {"id": "speed", "near": [-37.9, 2.0], "y": 0},
  {"id": "jugg", "near": [-7.2, -8.5], "y": 0}, {"id": "dtap", "near": [40.9, 3.0], "y": 0},
  {"id": "stamin", "near": [-37.9, -10.0], "y": 0}, {"id": "mule", "near": [13.6, -26.0], "y": 0}],
 "box": [{"near": [-12.0, 18.6], "y": 0}, {"near": [-37.9, -20.0], "y": 0}, {"near": [-21.3, 14.0], "y": 0}, {"near": [40.9, -12.0], "y": 0}, {"near": [-7.6, -30.0], "y": 0}],
 "box_start": 0,
 "pap": {"near": [3.0, -32.8], "y": 0},
 "power": {"near": [7.2, 1.0], "y": 0},
 "gum": {"near": [-20.0, 18.6], "y": 0},
}
json.dump(cfg, open("/home/david/juegos-gambas/zombiesgd/assets/maps/conservera/map.json", "w"), ensure_ascii=False, indent=1)
print("piezas", len(P), "bloques", len(B))
