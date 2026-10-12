#!/usr/bin/env python3
"""Genera assets/maps/puerto/map.json: «Puerto Viejo», la terminal de contenedores donde Gamba Roja montó su Planta 2.
  A Muelle (inicio): el carguero amarrado, la grúa portuaria y los bolardos
  B Terminal: calles entre pilas de contenedores y la grúa pórtico
  C Oficinas del puerto: despachos con monitores, taquillas y archivadores
  D Aparcamiento de camiones: tráileres frigoríficos y torres de luz (generador)
  E Cámara frigorífica (Planta 2): cámaras de frío, laboratorio y la Forja
Coordenadas: X al este, Z al sur (el mar al sur)."""
import json, math, random
random.seed(11)
M = "res://assets/maps/puerto/models/"
CM = "res://assets/maps/conservera/models/"
PR = "res://assets/maps/prison/props/"
B = []; P = []
def box(x, y, z, w, h, d, m, r=0, c=True): B.append({"t": "box", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [round(w, 3), round(h, 3), round(d, 3)], "r": r, "m": m, "c": c})
def cyl(x, y, z, rad, h, m, c=True): B.append({"t": "cyl", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [rad, h], "m": m, "c": c})
def inv(x, z, w, d, h=3.0, r=0): B.append({"t": "box", "p": [round(x, 3), 0, round(z, 3)], "s": [round(w, 3), h, round(d, 3)], "r": r, "m": "concrete", "c": True, "inv": True})
SMALL = ("crate", "pallet", "pcrate", "fridge", "barrels", "biobarrel", "jar", "microscope", "monitor", "chair", "cabinet", "flamp")
def prop(path, pos, rot=0, scale=1.0, **kw):
    name = path.rstrip("/").split("/")[-1]
    d = {"scene": path + "/scene.gltf", "name": kw.pop("tag", name), "pos": [round(v, 3) for v in pos], "rot": rot, "scale": scale}
    if name in SMALL: d["vis"] = 35.0
    d.update(kw); P.append(d)
def wall(x0, z0, x1, z1, h=4.0, m="concrete", t=0.4, y=0.0):
    L = math.hypot(x1 - x0, z1 - z0); a = math.degrees(math.atan2(x1 - x0, z1 - z0))
    box((x0 + x1) / 2, y, (z0 + z1) / 2, t, h, L, m, a)
def chain(x0, z0, x1, z1):   # valla metálica de verdad (modelo del Pueblo) con pared invisible
    L = math.hypot(x1 - x0, z1 - z0); a = math.degrees(math.atan2(x1 - x0, z1 - z0))
    n = max(1, round(L / 10.9))
    for i in range(n):
        t = (i + 0.5) / n
        P.append({"scene": "res://assets/maps/pueblo/models/chainlink/scene.gltf", "name": "chainlink", "pos": [round(x0 + (x1 - x0) * t, 3), 0, round(z0 + (z1 - z0) * t, 3)],
                  "rot": a, "scale": [0.35, 0.35, round(0.35 * (L / n) / 10.9, 4)], "collide": False})
    inv((x0 + x1) / 2, (z0 + z1) / 2, 0.25, L, 3.0, a)

# ------------------------------------------------------------------ suelo, muelle y mar
box(0, -0.3, -8.0, 96, 0.3, 77, "asphalt")                       # explanada (x -48..48, z -46.5..30.5)
box(0, -1.25, 75, 320, 0.05, 90, "water", 0, False)              # el mar
box(0, -1.25, -8, 320, 0.05, 80, "black", 0, False)
box(0, -0.3, 30.55, 96, 0.3, 0.3, "concrete", 0, False)          # borde del muelle
for x in range(-44, 46, 8): cyl(x, 0, 29.9, 0.28, 0.6, "rust")    # bolardos
prop(M + "ship", (-6.0, 1.0, 46.0), 90, 0.32, collide=False, max_tris=8000)     # el carguero amarrado
prop(M + "portcrane", (16.0, 0, 25.0), 90, 0.8, collide=False, max_tris=6000)   # grúa portuaria
cyl(16.0 - 3.6, 0, 25.0 - 3.0, 0.6, 3.0, "rust"); cyl(16.0 + 3.6, 0, 25.0 - 3.0, 0.6, 3.0, "rust")   # (patas de la grúa: chocan)
cyl(16.0 - 3.6, 0, 25.0 + 3.0, 0.6, 3.0, "rust"); cyl(16.0 + 3.6, 0, 25.0 + 3.0, 0.6, 3.0, "rust")
prop(CM + "trawler", (30.0, 0.9, 34.6), 0, 0.011, collide=False)   # el pesquero de la huida

# ------------------------------------------------------------------ terminal de contenedores (pilas de 1 a 3 alturas, calles de 4,5 m)
CONT = [(M + "cont_blue", 0.05, 0.0, 2474, 0), (M + "cont_red", 2.15, 0.0, 2000, 0), (CM + "container", 0.47, 0.47, 3000, 90)]
def stack(x, z, n, rot_long_z=True):
    for k in range(n):
        path, s, y0, tri, base_rot = random.choice(CONT)
        prop(path, (x, k * 2.62 + y0, z), base_rot + (0 if rot_long_z else 90) + random.choice([0, 180]), s, max_tris=tri, collide=k == 0, tag="cont")
cols = [-40.5, -27.5, -14.5, -1.5]            # centro de cada bloque (2 contenedores de ancho, 5,4 m)
rows = [(-18.0, True), (-9.5, True), (5.0, True), (12.0, False)]
OPEN_SPOTS = []
for ci, cx in enumerate(cols):
    for ri, (rz, full) in enumerate(rows):
        for side in (-1.35, 1.35):
            x = cx + side
            if (ci + ri) % 4 == 1 and side > 0:   # contenedor abierto (con la puerta a la calle): ahí está el cultivo
                prop(M + "cont_open", (x, 1.18, rz), 90, 1.04, max_tris=4000, tag="cont_abierto"); OPEN_SPOTS.append((x, rz)); continue
            if not full and side < 0: continue
            stack(x, rz, random.choice([1, 2, 2, 3]))
# grúa pórtico sobre la segunda columna
prop(M + "gantry", (-27.5, 0, -2.0), 0, 3.0, collide=False, max_tris=6000)
for (x, z) in ((-27.5 - 12.8, -2.0 - 3.5), (-27.5 + 11.4, -2.0 - 3.5), (-27.5 - 12.8, -2.0 + 3.0), (-27.5 + 11.4, -2.0 + 3.0)): inv(x, z, 1.2, 1.2, 6.0)
prop(CM + "forklift", (-8.5, 0, 1.0), 120, 0.01)
for (x, z) in ((-34.0, -1.0), (-20.5, 16.0), (2.5, -22.0)):
    prop(CM + "pallet", (x, 0, z), random.randint(0, 90), 1.2, max_tris=500); prop(CM + "crate", (x, 0.14, z), random.randint(0, 40), 1.0, max_tris=600)
prop(CM + "barrels", (-45.0, 0, 3.0), 0, 1.0, max_tris=2500)
prop(M + "lighttower", (-21.0, 1.2, 1.0), 30, 1.3, max_tris=3000)
prop(M + "lighttower", (5.5, 1.2, -14.0), 200, 1.3, max_tris=3000)

# ------------------------------------------------------------------ oficinas del puerto (edificio de ladrillo con interior)
OX0, OX1, OZ0, OZ1 = 14.0, 30.0, 5.0, 17.6
OH = 4.2
wall(OX0, OZ0, OX0, OZ1, OH, "brick_old"); wall(OX1, OZ0, OX1, OZ1, OH, "brick_old")
wall(OX0, OZ1, 21.0, OZ1, OH, "brick_old"); wall(23.0, OZ1, OX1, OZ1, OH, "brick_old"); wall(21.0, OZ1, 23.0, OZ1, OH - 2.4, "brick_old", 0.4, 2.4)   # puerta al muelle
wall(OX0, OZ0, 17.0, OZ0, OH, "brick_old"); wall(19.0, OZ0, OX1, OZ0, OH, "brick_old"); wall(17.0, OZ0, 19.0, OZ0, OH - 2.4, "brick_old", 0.4, 2.4)   # puerta trasera
box((OX0 + OX1) / 2, OH, (OZ0 + OZ1) / 2, OX1 - OX0 + 0.4, 0.3, OZ1 - OZ0 + 0.4, "concrete")
box((OX0 + OX1) / 2, 0.0, (OZ0 + OZ1) / 2, OX1 - OX0 - 0.2, 0.03, OZ1 - OZ0 - 0.2, "tiles", 0, False)
wall(OX0 + 0.25, OZ0 + 0.25, OX0 + 0.25, OZ1 - 0.25, OH, "plaster", 0.1); wall(OX1 - 0.25, OZ0 + 0.25, OX1 - 0.25, OZ1 - 0.25, OH, "plaster", 0.1)
wall(24.5, OZ0 + 0.3, 24.5, 12.0, OH, "plaster", 0.2)   # tabique: despacho del jefe de puerto
for (x, z, r) in ((17.0, 9.0, 0), (17.0, 13.5, 0), (27.0, 9.5, 90)):
    prop(PR + "desk", (x, 0, z), r, 1.0, max_tris=1500)
    prop(PR + "monitor", (x - 0.3, 0.81, z - 0.2), r + 160, 1.0, collide=False, max_tris=600)
    prop(PR + "chair", (x, 0.15, z + 0.9), r + 180, 0.002, collide=False)
for z in (6.0, 6.8, 7.6): prop(PR + "cabinet", (29.4, 0.66, z), -90, 0.0062)
prop(PR + "lockers", (14.7, 1.0, 16.6), 90, 1.0, max_tris=2000)
prop(PR + "shelves", (20.8, 0.04, 5.6), 0, 1.0)
for x in (18.0, 26.5): prop(PR + "flamp", (x, OH - 0.05, 11.0), 90, 1.0, collide=False)

# ------------------------------------------------------------------ aparcamiento de camiones (generador y torres de luz)
prop(M + "truck", (22.0, 0, -18.0), 90, 1.0, max_tris=1500)
prop(M + "reefer", (33.0, 0, -6.0), 90, 1.5, max_tris=600)
prop(M + "reefer", (33.0, 0, -1.0), 90, 1.5, max_tris=600)
prop(M + "reefer", (40.0, 0, 9.0), 0, 1.5, max_tris=600)
prop(M + "lighttower", (12.0, 1.2, -21.0), 120, 1.3, max_tris=3000)
prop(M + "lighttower", (44.0, 1.2, -20.0), 220, 1.3, max_tris=3000)
prop(CM + "tank", (43.0, 0, -12.0), 0, 1.2, max_tris=2000)
prop(CM + "barrels", (36.0, 0, 15.0), 0, 1.0, max_tris=2500)

# ------------------------------------------------------------------ cámara frigorífica (Planta 2): nave con interior
EX0, EX1, EZ0, EZ1 = -34.0, -8.0, -46.0, -26.5
EH = 6.0
wall(EX0, EZ0, EX0, EZ1, EH, "metal"); wall(EX1, EZ0, EX1, EZ1, EH, "metal"); wall(EX0, EZ0, EX1, EZ0, EH, "metal")
wall(EX0, EZ1, -23.0, EZ1, EH, "metal"); wall(-19.0, EZ1, EX1, EZ1, EH, "metal"); wall(-23.0, EZ1, -19.0, EZ1, EH - 3.2, "metal", 0.4, 3.2)   # portón de 4 m
box((EX0 + EX1) / 2, EH, (EZ0 + EZ1) / 2, EX1 - EX0 + 0.4, 0.3, EZ1 - EZ0 + 0.4, "metal")
box((EX0 + EX1) / 2, 0.0, (EZ0 + EZ1) / 2, EX1 - EX0 - 0.2, 0.03, EZ1 - EZ0 - 0.2, "tiles", 0, False)
for (x0, z0, x1, z1) in ((EX0 + 0.25, EZ0 + 0.25, EX0 + 0.25, EZ1 - 0.25), (EX1 - 0.25, EZ0 + 0.25, EX1 - 0.25, EZ1 - 0.25), (EX0 + 0.25, EZ0 + 0.25, EX1 - 0.25, EZ0 + 0.25)):
    wall(x0, z0, x1, z1, EH, "plaster", 0.1)
# cámaras de frío a lo largo de las paredes, neveras, palés con cajas congeladas
for (x, z, r) in ((-30.0, -44.2, 0), (-22.0, -44.2, 0), (-12.0, -44.2, 0)): prop(M + "coldroom", (x, 0, z), r, 1.0, max_tris=5000)
for z in (-38.5, -35.5): prop(M + "fridge", (-33.4, 0, z), 90, 1.4, max_tris=600)
for (x, z) in ((-14.0, -30.0), (-28.5, -30.5)):
    prop(CM + "pallet", (x, 0, z), 0, 1.2, max_tris=500)
    for k in range(3): prop(CM + "pcrate", (x, 0.14 + k * 0.25, z), random.choice([0, 90]), 1.3, collide=k == 0, max_tris=600)
# laboratorio del fondo: mesas, microscopios y tanques de cultivo
for x in (-26.0, -16.0):
    prop(CM + "labtable", (x, -0.064, -38.0), 0, 0.06, max_tris=3000)
    prop(CM + "microscope", (x + 0.6, 0.9, -38.0), 0, 0.3, collide=False, max_tris=1500)
    for k in range(3): prop(CM + "jar", (x - 0.8 + k * 0.32, 0.9, -38.1), random.randint(0, 359), 0.012, collide=False, max_tris=800)
for x in (-31.6, -9.6):
    cyl(x, 0, -40.5, 0.75, 0.25, "steel"); cyl(x, 0.25, -40.5, 0.62, 2.1, "liquid", False); cyl(x, 2.35, -40.5, 0.75, 0.3, "steel"); cyl(x, 0.25, -40.5, 0.66, 2.1, "glass")
for (x, z) in ((-26.0, -32.0), (-16.0, -32.0), (-21.0, -40.0)): prop(PR + "flamp", (x, EH - 0.05, z), 90, 1.0, collide=False)
for (x, z, r) in ((-33.5, -29.5, 90), (-33.5, -31.6, 90), (-8.5, -29.5, -90), (-8.5, -31.6, -90)): prop(PR + "shelves", (x, 0.04, z), r, 1.0)
for (x, z) in ((-24.0, -34.5), (-18.0, -34.5), (-21.0, -30.0)):
    prop(CM + "pallet", (x, 0, z), 15, 1.2, max_tris=500)
    for k in range(2): prop(CM + "crate", (x, 0.14 + k * 0.88, z), random.randint(0, 30), 1.0, collide=k == 0, max_tris=600)
prop(CM + "biobarrel", (-10.0, 0, -33.5), 0, 0.003, max_tris=1500); prop(CM + "biobarrel2", (-9.6, 0, -34.4), 0, 1.0, max_tris=800)

# ------------------------------------------------------------------ cierres del recinto
WALLS = [[0, 1.5, 30.8, 96, 4.0, 0.4]]   # el borde del muelle (agua)
wall(-48.0, -46.5, -48.0, 30.5, 4.0, "concrete"); wall(48.0, -46.5, 48.0, 30.5, 4.0, "concrete"); wall(-48.0, -46.5, 48.0, -46.5, 4.0, "concrete")
chain(-48.0, 18.0, -22.0, 18.0); chain(-18.0, 18.0, OX0, 18.0); chain(OX1, 18.0, 48.0, 18.0)     # muelle | terminal y aparcamiento (verja en x -20)
chain(8.0, -26.2, 8.0, -12.0); chain(8.0, -8.0, 8.0, 18.0)                                       # terminal | aparcamiento (verja en z -10)
chain(-48.0, -26.2, EX0, -26.2); chain(EX1, -26.2, 8.0, -26.2)                                    # detrás de la terminal
chain(8.0, -24.2, 48.0, -24.2)                                                                    # detrás del aparcamiento
chain(OX0 - 0.3, OZ0, 8.0, OZ0)                                                                    # (hueco entre la oficina y la valla)

# ------------------------------------------------------------------ zonas
Z = [
 {"id": "A", "name": "Muelle", "open": True, "boxes": [[-47.6, -1, 18.0, 47.6, 5.0, 30.4]],
  "spawns": [[-47.0, 0, 20.0], [47.0, 0, 20.0], [-30.0, 0, 29.8], [-6.0, 0, 29.8], [36.0, 0, 29.8]]},
 {"id": "B", "name": "Terminal de contenedores", "boxes": [[-47.6, -1, -26.0, 8.0, 7.0, 18.0]],
  "spawns": [[-47.0, 0, -25.0], [-47.0, 0, 0.0], [7.0, 0, -25.0], [-21.0, 0, -25.0], [7.0, 0, 16.0], [-47.0, 0, 16.0]]},
 {"id": "C", "name": "Oficinas del puerto", "boxes": [[OX0 + 0.3, -1, OZ0 + 0.3, OX1 - 0.3, OH - 0.2, OZ1 - 0.3]], "spawns": [[29.0, 0, 16.6], [15.0, 0, 6.0]]},
 {"id": "D", "name": "Aparcamiento de camiones", "boxes": [[8.0, -1, -24.0, 47.6, 5.0, OZ0 - 0.45], [OX1 + 0.3, -1, OZ0 - 0.45, 47.6, 5.0, 18.0]],
  "spawns": [[47.0, 0, -23.5], [47.0, 0, 17.0], [9.0, 0, -23.5], [30.0, 0, -23.5]]},
 {"id": "E", "name": "Cámara frigorífica", "boxes": [[EX0 + 0.3, -1, EZ0 + 0.3, EX1 - 0.3, EH - 0.5, EZ1 - 0.3]], "spawns": [[-33.0, 0, -45.0], [-9.0, 0, -45.0], [-21.0, 0, -45.0]]},
]
D = [
 {"cost": 750, "pos": [-20.0, 0, 18.0], "size": [4.0, 3.0, 1.2], "yaw": 0, "opens": ["A", "B"]},
 {"cost": 750, "pos": [22.0, 0, OZ1], "size": [2.0, 2.4, 1.0], "yaw": 0, "opens": ["A", "C"]},
 {"cost": 1000, "pos": [18.0, 0, OZ0], "size": [2.0, 2.4, 1.0], "yaw": 0, "opens": ["C", "D"]},
 {"cost": 1000, "pos": [8.0, 0, -10.0], "size": [4.0, 3.0, 1.2], "yaw": 90, "opens": ["B", "D"]},
 {"cost": 1500, "pos": [-21.0, 0, EZ1], "size": [4.0, 3.2, 1.0], "yaw": 0, "opens": ["B", "E"]},
]

fires = [[-36.0, 0.0, 22.0], [3.0, 0.0, 24.0], [-14.0, 0.0, -6.0], [26.0, 0.0, -10.0], [-40.0, 0.0, -22.5]]
lights = [{"pos": [f[0], 1.6, f[2]], "color": [1.0, 0.45, 0.15], "range": 9, "energy": 2.0} for f in fires]
lights += [{"pos": [x, 6.0, z], "color": [0.85, 0.9, 1.0], "range": 16, "energy": 1.5} for (x, z) in [(-21.0, 1.0), (5.5, -14.0), (12.0, -21.0), (44.0, -20.0)]]   # torres de luz
lights += [{"pos": [x, 5.0, z], "color": [1.0, 0.7, 0.4], "range": 13, "energy": 1.3} for (x, z) in [(-36, 24), (-12, 24), (12, 24), (36, 24)]]
lights += [{"pos": [x, OH - 0.6, 11.0], "color": [1.0, 0.92, 0.8], "range": 9, "energy": 1.2} for x in (18.0, 26.5)]
lights += [{"pos": [x, EH - 0.8, z], "color": [0.65, 0.85, 1.0], "range": 11, "energy": 1.3} for (x, z) in [(-26.0, -32.0), (-16.0, -32.0), (-21.0, -40.0)]]
lights += [{"pos": [x, 1.4, -40.5], "color": [1.0, 0.2, 0.25], "range": 4.5, "energy": 1.2} for x in (-31.6, -9.6)]

cfg = {
 "name": "Puerto Viejo",
 "props": P, "build": B, "textures": "res://assets/maps/puerto/textures/",
 "walls": WALLS,
 "spawn": [-36.0, 0.2, 24.0, -90],
 "ambient": "amb1",
 "env": {"sky_top": [0.1, 0.12, 0.16], "sky_horizon": [0.42, 0.42, 0.44], "sky_energy": 0.7, "ambient": 0.6, "exposure": 1.0,
         "fog": [0.38, 0.4, 0.44], "fog_density": 0.024, "sun": 0.5, "sun_color": [0.85, 0.85, 0.95], "sun_rot": [-25, 60], "saturation": 0.8,
         "ambient_color": [0.4, 0.42, 0.48]},
 "zones": Z, "doors": D,
 "fires": fires, "hazards": [], "lights": lights,
 "noshadow": ["chainlink", "crate", "pallet", "pcrate", "fridge", "jar", "microscope", "monitor", "chair", "cabinet", "flamp", "barrels", "biobarrel", "lighttower", "labtable", "desk", "lockers", "shelves"],
 "wallbuys": [
  {"gun": "olympia", "near": [-47.6, 14.0], "y": 0}, {"gun": "mp5k", "near": [14.3, 10.0], "y": 0},
  {"gun": "m14", "near": [-47.6, -10.0], "y": 0}, {"gun": "ak74u", "near": [-12.0, -26.2], "y": 0},
  {"gun": "m16", "near": [47.6, -6.0], "y": 0}, {"gun": "galil", "near": [-8.3, -36.0], "y": 0},
  {"gun": "stakeout", "near": [1.4, 5.0], "y": 0}, {"gun": "mp40", "near": [47.6, 10.0], "y": 0}, {"gun": "python", "near": [29.7, 14.0], "y": 0}],
 "perks": [
  {"id": "revive", "near": [26.0, 17.9], "y": 0}, {"id": "speed", "near": [-47.6, 10.0], "y": 0},
  {"id": "jugg", "near": [-47.6, -18.0], "y": 0}, {"id": "dtap", "near": [47.6, 2.0], "y": 0},
  {"id": "stamin", "near": [24.0, 5.3], "y": 0}, {"id": "mule", "near": [-33.7, -32.0], "y": 0}],
 "box": [{"near": [-47.6, 24.0], "y": 0}, {"near": [-47.6, -4.0], "y": 0}, {"near": [27.0, 17.3], "y": 0}, {"near": [47.6, -14.0], "y": 0}, {"near": [-8.3, -40.0], "y": 0}],
 "box_start": 0,
 "pap": {"near": [-21.0, -45.7], "y": 0},
 "power": {"near": [47.6, -17.0], "y": 0},
 "gum": {"near": [18.6, 17.9], "y": 0},
 "open_spots": [list(p) for p in OPEN_SPOTS],
}
json.dump(cfg, open("/home/david/juegos-gambas/zombiesgd/assets/maps/puerto/map.json", "w"), ensure_ascii=False, indent=1)
print("piezas", len(P), "bloques", len(B), "contenedores abiertos", OPEN_SPOTS)
