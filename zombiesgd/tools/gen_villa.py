#!/usr/bin/env python3
"""Genera assets/maps/villa/map.json: «Villa Coral», mapa de estilo low-poly (modelos de Quaternius, CC0),
inspirado en los mapas grandes de los zombis de Black Ops 2 (Green Run: parada, pueblo y granja).
  A El Cruce (inicio): el cruce de dos carreteras con coches abandonados, la gasolinera y la parada del bus
  B Calle Mayor: calle ancha entre edificios altos, hasta la barricada del final
  C El Bar: interior con barra, mesas y sofás (se entra desde la calle y sale al bosque)
  D La Granja: graneros, silos, molino y campos; el generador está en el granero grande
  E La Estación: vías, locomotora y vagones, andén y patio de contenedores
  F El Bosque: pinos, campamento con hoguera y la cabaña de la Forja
Coordenadas: X al este, Z al sur. Las zonas se unen en anillo (como en los mapas de Black Ops):
  A-B, A-D, A-E, A-F, B-C, C-F, B-D, D-E, E-F."""
import json, math, os, random
DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "maps", "villa", "models")
random.seed(7)
M = "res://assets/maps/villa/models/"
B = []; P = []

def box(x, y, z, w, h, d, m, r=0, c=True): B.append({"t": "box", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [round(w, 3), round(h, 3), round(d, 3)], "r": r, "m": m, "c": c})
def cyl(x, y, z, rad, h, m, c=True): B.append({"t": "cyl", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [rad, h], "m": m, "c": c})
def inv(x, z, w, d, h=3.0, r=0): B.append({"t": "box", "p": [round(x, 3), 0, round(z, 3)], "s": [round(w, 3), h, round(d, 3)], "r": r, "m": "concrete", "c": True, "inv": True})
SMALL = ("crate", "cone", "barrel", "hydrant", "chair", "stool", "bag", "log", "tires", "pallet", "cinder", "fern", "bush", "rock", "blood", "radio", "axe", "backpack", "propane", "lamp")
def prop(name, pos, rot=0, scale=1.0, **kw):
    ext = ".scn" if os.path.exists(os.path.join(DIR, name + ".scn")) else ".glb"   # (los de colores lisos, convertidos con tools/glb_to_scn.gd)
    d = {"scene": M + name + ext, "name": kw.pop("tag", name), "pos": [round(v, 3) for v in pos], "rot": round(rot, 1), "scale": scale}
    if any(s in name for s in SMALL): d["vis"] = 45.0
    d["pivot"] = True
    d.update(kw); P.append(d)
def wall(x0, z0, x1, z1, h, m, t=0.4, y=0.0):
    L = math.hypot(x1 - x0, z1 - z0); a = math.degrees(math.atan2(x1 - x0, z1 - z0))
    box((x0 + x1) / 2, y, (z0 + z1) / 2, t, h, L, m, a)
def seg_inv(x0, z0, x1, z1, h=3.0):
    L = math.hypot(x1 - x0, z1 - z0); a = math.degrees(math.atan2(x1 - x0, z1 - z0))
    inv((x0 + x1) / 2, (z0 + z1) / 2, 0.3, L, h, a)

# vallas que hacen de borde entre zonas: modelos repetidos a lo largo de la línea + pared invisible; los huecos (puertas) se dejan libres
FENCES = {"metal": ("s_metal_fence", 3.5 * 0.85, 0.85), "chain": ("s_barrier_large", 3.8, 1.0), "farm": ("farm_fence", 5.9, 1.0)}
def fence(x0, z0, x1, z1, kind="metal", gaps=()):
    L = math.hypot(x1 - x0, z1 - z0); ux, uz = (x1 - x0) / L, (z1 - z0) / L
    a = math.degrees(math.atan2(ux, uz)) + 90
    model, w, sc = FENCES[kind]
    # tramos sin huecos
    cuts = sorted([(c - g / 2, c + g / 2) for (c, g) in gaps])
    spans = []; t = 0.0
    for (g0, g1) in cuts: spans.append((t, g0)); t = g1
    spans.append((t, L))
    for (s0, s1) in spans:
        if s1 - s0 < 0.2: continue
        n = max(1, round((s1 - s0) / w))
        for i in range(n):
            tt = s0 + (i + 0.5) * (s1 - s0) / n
            stretch = ((s1 - s0) / n) / w
            prop(model, (x0 + ux * tt, 0, z0 + uz * tt), a, [round(sc * stretch, 3), sc, sc] if kind != "farm" else [round(stretch, 3), 1.0, 1.0], collide=False, tag="valla", vis=70.0)
        seg_inv(x0 + ux * s0, z0 + uz * s0, x0 + ux * s1, z0 + uz * s1, 3.2)

def hedge(x0, z0, x1, z1, gaps=(), h=3.2):   # seto o muro de piedra (color liso): sirve de pared para colgar cosas
    L = math.hypot(x1 - x0, z1 - z0); ux, uz = (x1 - x0) / L, (z1 - z0) / L
    cuts = sorted([(c - g / 2, c + g / 2) for (c, g) in gaps]); spans = []; t = 0.0
    for (g0, g1) in cuts: spans.append((t, g0)); t = g1
    spans.append((t, L))
    for (s0, s1) in spans:
        if s1 - s0 < 0.2: continue
        wall(x0 + ux * s0, z0 + uz * s0, x0 + ux * s1, z0 + uz * s1, h, "#4e6b33", 1.2)

def road(x0, z0, x1, z1, wide=12.0, lines=True):   # carretera con aceras (cajas planas de color)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2; horiz = abs(x1 - x0) > abs(z1 - z0)
    L = abs(x1 - x0) if horiz else abs(z1 - z0)
    w, d = (L, wide) if horiz else (wide, L)
    box(cx, -0.28, cz, w, 0.29, d, "#3b3c40", 0, False)
    if lines:
        for k in range(int(L // 6)):
            o = -L / 2 + 3 + k * 6
            box(cx + (o if horiz else 0), 0.01, cz + (0 if horiz else o), 2.6 if horiz else 0.22, 0.01, 0.22 if horiz else 2.6, "#e8d27a", 0, False)

def tree(x, z, kind=None, s=None):
    kind = kind or random.choice(["n_pine", "n_pine_2", "n_pine_3", "n_pine_5", "n_tree", "n_tree_3", "n_tree_4"])
    s = s or random.uniform(0.9, 1.25)
    prop(kind, (x, 0, z), random.uniform(0, 360), round(s, 2), collide=False, tag="arbol", vis=80.0)
    cyl(x, 0, z, 0.35 * s, 2.2, "#5b4130")   # el tronco choca (las copas no)

# ------------------------------------------------------------------ suelo
box(0, -0.3, -2.5, 190, 0.3, 165, "#5f7d3c")                 # hierba (x -95..95, z -85..80): el suelo que se pisa; lo demás es pintura encima
WALLS = []

# ------------------------------------------------------------------ A · El Cruce (x -24..24, z -24..24)
road(-24, 0, 24, 0); road(0, -24, 0, 24)
box(0, -0.28, 0, 12, 0.3, 12, "#3b3c40", 0, False)
for (x, z) in ((-9.5, -9.5), (9.5, -9.5), (-9.5, 9.5), (9.5, 9.5)): box(x * 1.0, -0.27, z, 7, 0.3, 7, "#a7a196", 0, False)   # aceras de las esquinas
for (x, z, r) in ((-6.8, -6.8, 0), (6.8, -6.8, 90), (-6.8, 6.8, 270), (6.8, 6.8, 180)): prop("z_traffic_light", (x, 0, z), r, 1.1, tag="semaforo")
# coches abandonados y barreras en mitad del cruce
prop("car_taxi", (-3.0, 0, -9.0), 20, 1.15); prop("car_police_car", (3.5, 0, 6.0), 200, 1.15); prop("s_broken_car", (-14.0, 0, 2.5), 80, 0.85)
prop("car_suv", (13.0, 0, -2.5), 95, 1.15); prop("z_plastic_barrier", (2.5, 0, -15.0), 10, 1.2); prop("z_traffic_barrier", (-2.0, 0, 15.5), 0, 1.3)
for (x, z) in ((-1, -3), (1.5, -2.5), (4, 1), (-4, 3)): prop("z_traffic_cone", (x, 0, z), random.uniform(0, 90), 1.3)
# gasolinera (esquina noreste): marquesina sobre surtidores, tienda
box(16.5, -0.27, -16.5, 15, 0.3, 15, "#b8b2a6", 0, False)
for (x, z) in ((12.5, -12.5), (20.5, -12.5), (12.5, -20.5), (20.5, -20.5)): box(x, 0, z, 0.5, 4.6, 0.5, "#dcdcdc")
box(16.5, 4.6, -16.5, 11, 0.5, 11, "#c0392b"); box(16.5, 4.45, -16.5, 10.6, 0.15, 10.6, "#eeeeee", 0, False)
for (x, z) in ((15.0, -16.5), (18.0, -16.5)): prop("s_gas_tank", (x, 0, z), 0, 0.7, tag="surtidor")
box(16.5, 0, -22.8, 14.4, 3.6, 2.2, "#e9e3d3"); box(16.5, 3.6, -22.8, 15.0, 0.4, 2.8, "#c0392b")   # tienda (pared del fondo)
prop("s_cardboard_boxes_3", (22.0, 0, -13.5), 20, 0.7); prop("z_barrel", (11.5, 0, -22.0), 0, 1.1)
# esquina noroeste: casa moderna; suroeste: parque con depósito de agua; sureste: parada del bus
prop("b_modern", (-17.0, 0, -17.0), 135, 2.6, tag="casa")
inv(-17.0, -17.0, 9.0, 9.0, 6.0, 45)
prop("z_water_tower", (-16.5, 0, 16.5), 30, 1.25); box(-16.5, -0.27, 16.5, 14, 0.3, 14, "#6f8f43", 0, False)
for (x, z) in ((-21, 11), (-12, 21), (-21, 21)): tree(x, z, "n_tree_3", 0.8)
prop("f_sofa", (-12.0, 0, 12.5), 45, 0.55, tag="banco")
box(16.0, 0, 21.5, 9.0, 0.2, 2.6, "#7d7d82"); box(16.0, 2.6, 21.5, 9.4, 0.15, 3.0, "#2e86c1")   # parada del bus
for x in (11.8, 20.2): box(x, 0, 22.6, 0.15, 2.6, 0.15, "#7d7d82")
box(16.0, 0, 22.7, 9.0, 2.6, 0.12, "glass")
prop("z_town_sign", (-10.0, 0, -22.0), 0, 1.0, tag="cartel")
prop("s_dumpster", (21.0, 0, 13.5), 270, 0.85); prop("z_trash_bags", (22.0, 0, 16.0), 0, 1.0)
prop("z_fire_hydrant", (-7.5, 0, 11.0), 0, 1.3); prop("z_fire_hydrant", (7.5, 0, -11.0), 0, 1.3)
for (x, z, r) in ((-7.6, -18, 90), (7.6, 18, 270), (-18, 7.6, 0), (18, -7.6, 180)): prop("z_street_light", (x, 0, z), r, 1.0, tag="farola")

# ------------------------------------------------------------------ B · Calle Mayor (x 24..90, z -24..24 sin el bar)
road(24, 0, 90, 0, 12.0)
box(57, -0.27, -8.0, 66, 0.3, 4.0, "#a7a196", 0, False); box(57, -0.27, 8.0, 66, 0.3, 4.0, "#a7a196", 0, False)   # aceras
# edificios al norte (fachada en z -10) y al sur (fachada en z 10), dejando el callejón de la granja (x 38..42) y el bar (x 52..72)
NB = [("b_large", 31.0, 2.4, 13.7, 5.3), ("b_big", 47.5, 2.4, 11.3, 10.6), ("b_house2", 61.5, 2.4, 19.2, 6.5), ("b_white", 77.0, 2.6, 12.0, 10.1), ("b_house3", 86.5, 2.4, 8.9, 6.5)]
SB = [("b_house1", 29.5, 2.4, 7.4, 10.6), ("b_house3", 38.5, 2.4, 8.9, 6.5), ("b_big", 46.5, 2.2, 10.3, 9.7), ("b_house2", 81.0, 2.4, 19.2, 6.5)]
for (m, x, s, w, d) in NB:
    if 38.0 < x < 42.0: continue
    prop(m, (x, 0, -10.0 - d / 2), 0, s, tag="edificio"); inv(x, -10.0 - d / 2, w - 0.4, d - 0.4, 12.0)
for (m, x, s, w, d) in SB:
    prop(m, (x, 0, 10.0 + d / 2), 180, s, tag="edificio"); inv(x, 10.0 + d / 2, w - 0.4, d - 0.4, 12.0)
# fondos de manzana (los huecos entre edificios no llevan a ninguna parte)
wall(24.2, 24.0, 52.0, 24.0, 4.0, "#8a7f72", 0.6); wall(72.0, 24.0, 90.0, 24.0, 4.0, "#8a7f72", 0.6)
# callejón hacia la granja (entre el edificio grande y el de la esquina)
box(40.0, -0.27, -17.0, 4.6, 0.3, 14.0, "#8f877a", 0, False)
prop("s_dumpster", (39.0, 0, -13.0), 90, 0.85); prop("z_trash_bags", (41.0, 0, -15.5), 30, 1.0)
# la barricada del final de la calle (sacos, coches, neumáticos)
prop("s_sack_trench", (87.0, 0, -3.5), 90, 1.0); prop("s_sack_trench", (87.0, 0, 3.0), 90, 1.0)
prop("s_broken_car", (84.0, 0, 0.0), 10, 0.9); prop("z_wheels_stack", (88.0, 0, 6.5), 0, 1.2); prop("s_barrier_trash", (88.5, 0, -6.5), 90, 1.0)
inv(88.5, 0, 1.0, 24.0, 3.0)
# calle: coches, conos, farolas, bocas de riego, basura
prop("car_car", (33.0, 0, 4.5), 92, 1.15); prop("car_car_2", (52.0, 0, -4.0), 265, 1.15); prop("car_sports_car", (70.0, 0, 3.8), 85, 1.15)
prop("z_damaged_couch", (60.0, 0, -7.5), 0, 0.8); prop("z_traffic_barrier", (66.0, 0, 1.0), 70, 1.3)
for x in (30, 50, 70, 86): prop("z_street_light", (x, 0, -6.6), 90, 1.0, tag="farola"); prop("z_street_light", (x - 10, 0, 6.6), 270, 1.0, tag="farola")
for (x, z) in ((44, -7.2), (58, 7.2), (75, -7.2)): prop("z_fire_hydrant", (x, 0, z), 0, 1.3)
for (x, z) in ((36, -8.5), (63, 8.6), (78, -8.4)): prop("z_trash_bags", (x, 0, z), random.uniform(0, 90), 1.0)
for (x, z) in ((47, 1.0), (75, -1.5)): prop("z_blood_splat", (x, 0.02, z), random.uniform(0, 360), 1.6, collide=False)

# ------------------------------------------------------------------ C · El Bar (x 52..72, z 10..24): interior hecho a mano
CX0, CX1, CZ0, CZ1, CH = 52.0, 72.0, 10.0, 24.0, 4.4
WALLC = "#9c4a3a"
wall(CX0, CZ0, 60.8, CZ0, CH, WALLC); wall(63.2, CZ0, CX1, CZ0, CH, WALLC); wall(60.8, CZ0, 63.2, CZ0, CH - 2.5, WALLC, 0.4, 2.5)    # fachada con puerta
wall(CX0, CZ1, 60.8, CZ1, CH, WALLC); wall(63.2, CZ1, CX1, CZ1, CH, WALLC); wall(60.8, CZ1, 63.2, CZ1, CH - 2.5, WALLC, 0.4, 2.5)    # puerta trasera
wall(CX0, CZ0, CX0, CZ1, CH, WALLC); wall(CX1, CZ0, CX1, CZ1, CH, WALLC)
box((CX0 + CX1) / 2, CH, (CZ0 + CZ1) / 2, CX1 - CX0 + 0.4, 0.4, CZ1 - CZ0 + 0.4, "#5b3a2e")                  # tejado
box((CX0 + CX1) / 2, CH + 0.4, CZ0 - 0.1, CX1 - CX0 + 1.0, 1.4, 0.4, "#2c3e50")                             # cartel de la fachada
box((CX0 + CX1) / 2, 0.0, (CZ0 + CZ1) / 2, CX1 - CX0 - 0.4, 0.03, CZ1 - CZ0 - 0.4, "#7a5434", 0, False)      # suelo de madera
for (x0, z0, x1, z1) in ((CX0 + 0.25, CZ0 + 0.3, CX0 + 0.25, CZ1 - 0.3), (CX1 - 0.25, CZ0 + 0.3, CX1 - 0.25, CZ1 - 0.3)):
    wall(x0, z0, x1, z1, CH, "#d9c49a", 0.1)
box(57.0, 0, 20.0, 8.0, 1.1, 1.0, "#6b3d24"); box(57.0, 1.1, 20.0, 8.4, 0.1, 1.2, "#3b2416")                  # la barra
box(57.0, 0, 23.3, 8.0, 2.4, 0.6, "#4a2c1a"); box(57.0, 2.4, 23.3, 8.0, 0.08, 0.7, "#3b2416")               # botellero
for k in range(10): box(53.6 + k * 0.75, 1.6, 23.2, 0.12, 0.36, 0.12, random.choice(["#2e7d32", "#8d6e63", "#c0392b", "#f1c40f"]), 0, False)
for x in (54.0, 55.6, 57.2, 58.8, 60.4): prop("f_stool", (x, 0, 18.9), random.uniform(0, 90), 1.4)
for (x, z) in ((66.0, 13.5), (69.0, 17.5), (65.5, 20.5)):
    prop("i_table_round_small", (x, 0, z), 0, 0.6)
    for k in range(3): prop("f_chair", (x + math.cos(k * 2.1) * 1.1, 0, z + math.sin(k * 2.1) * 1.1), -math.degrees(k * 2.1) - 90, 0.95)
prop("i_couch_large", (54.8, 0, 12.0), 180, 0.42, tag="sofa"); prop("i_kitchen_fridge", (52.8, 0, 22.8), 90, 0.55)
prop("f_bookcase_with_books", (71.6, 0, 22.5), -90, 0.6)
for (x, z) in ((57.0, 15.0), (66.0, 18.0)): box(x, CH - 0.25, z, 1.6, 0.12, 0.4, "#fff3c4", 0, False)

# ------------------------------------------------------------------ D · La Granja (x -24..90, z -80..-24)
box(33, -0.27, -52, 114, 0.3, 56, "#6d8a3f", 0, False)
box(0, -0.26, -40, 6, 0.3, 32, "#9b8158", 0, False); box(24, -0.26, -56, 54, 0.3, 6, "#9b8158", 0, False)       # caminos de tierra
# campos de cultivo (hileras)
for (fx, fz, w, d) in ((-10, -66, 22, 18), (52, -66, 26, 16), (78, -40, 18, 22)):
    box(fx, -0.25, fz, w, 0.3, d, "#7a5a3c", 0, False)
    for k in range(int(d // 1.6)):
        box(fx, 0.0, fz - d / 2 + 0.8 + k * 1.6, w - 1.0, 0.55, 0.5, "#8fb24a", 0, False)
# el granero grande (abierto: dentro, el generador) y el resto de edificios
prop("farm_open_barn", (24.0, 0, -42.0), 0, 2.0, tag="granero")
prop("farm_big_barn", (48.0, 0, -42.0), 90, 1.6, tag="granero"); inv(48.0, -42.0, 12.5, 12.0, 10.0)
prop("farm_silo", (60.5, 0, -50.0), 0, 1.3); cyl(60.5, 0, -50.0, 2.3, 9.0, "#8f3b2b")
prop("farm_silo_house", (62.0, 0, -36.0), 90, 1.3); inv(62.0, -36.0, 4.4, 6.6, 9.0)
prop("farm_tower_windmill", (-12.0, 0, -45.0), 30, 1.4); cyl(-12.0, 0, -45.0, 3.0, 8.0, "#7f8c8d")
prop("farm_small_barn", (8.0, 0, -70.0), 0, 1.5); inv(8.0, -70.0, 9.0, 9.2, 8.0)
for (x, z) in ((32.0, -62.0), (35.0, -62.5), (38.0, -62.0)): prop("farm_chickencoop", (x, 0, z), 180, 1.2)
for (x, z) in ((10, -30), (16, -31), (30, -30), (71, -30), (-18, -60)): box(x, 0, z, 2.2, 1.2, 1.6, "#e4c35a"); box(x, 1.2, z, 2.0, 0.9, 1.4, "#d9b64c")   # pacas de paja
prop("s_water_tank", (70.0, 0, -58.0), 0, 1.0); prop("s_wood_planks", (40.0, 0, -30.0), 20, 1.4)
prop("z_pallet_broken", (12.0, 0, -50.0), 30, 1.2); prop("z_barrel", (30.0, 0, -36.0), 0, 1.1); prop("z_barrel", (31.2, 0, -36.6), 0, 1.1)
prop("s_tires", (68.0, 0, -28.0), 0, 1.0); prop("car_suv", (78.0, 0, -60.0), 150, 1.15)
for (x, z) in ((-20, -76), (-4, -78), (20, -78), (44, -77), (66, -76), (86, -74), (88, -55), (86, -30), (-21, -30), (-20, -52)): tree(x, z)
# vallas de madera alrededor de los campos
fence(-21.0, -57.0, 1.0, -57.0, "farm"); fence(39.0, -58.0, 65.0, -58.0, "farm")

# ------------------------------------------------------------------ E · La Estación (x -90..-24, z -80..24)
box(-57, -0.27, -28, 66, 0.3, 104, "#8a8a7e", 0, False)                         # explanada de grava
for z in range(-78, 24, 18):
    prop("t_railway_track_straight", (-66.0, 0, z + 9), 90, [1.0, 1.0, 1.2], collide=False, tag="via")
    prop("t_railway_track_straight", (-72.0, 0, z + 9), 90, [1.0, 1.0, 1.2], collide=False, tag="via")
# el tren parado (locomotora y vagones) en la vía de la izquierda; el de mercancías en la otra
for (m, z) in (("t_locomotive_front", -50.0), ("t_locomotive_passenger_carriage", -39.0), ("t_locomotive_passenger_carriage", -28.4), ("t_locomotive_wagon", -17.8)):
    prop(m, (-66.0, 0.1, z), 90, 1.3, tag="tren")
inv(-66.0, -34.0, 3.6, 45.0, 5.0)
for (m, z) in (("t_cargo_train_wagon", -64.0), ("t_cargo_train_container", -50.0), ("t_cargo_train_wagon", 2.0)):
    prop(m, (-72.0, 0.1, z), 90, 1.25, tag="tren")
inv(-72.0, -57.0, 3.4, 27.0, 5.0); inv(-72.0, 2.0, 3.4, 13.5, 5.0)
# andén (bajo, se sube sin escalones) con el edificio de la estación
box(-58.5, 0, -30.0, 5.0, 0.25, 60.0, "#b3aa9a"); box(-56.2, 0.25, -30.0, 0.4, 0.02, 60.0, "#f1c40f", 0, False)
prop("b_white", (-45.0, 0, -36.0), 270, 2.4, tag="estacion"); inv(-45.0, -36.0, 9.0, 10.8, 12.0)
box(-50.6, 3.4, -36.0, 3.0, 0.3, 14.0, "#7b4a2e")                                  # marquesina sobre el andén
for z in (-42.0, -30.0): box(-51.8, 0.25, z, 0.3, 3.2, 0.3, "#5d4037")
for z in (-48.0, -22.0, -12.0): prop("f_sofa", (-57.0, 0.25, z), 90, 0.5, tag="banco")
# patio de contenedores al sur
for (x, z, r, k, m) in ((-48.0, 6.0, 0, 2, "z_container_red"), (-48.0, 12.0, 0, 1, "z_container_green"), (-38.0, 14.0, 90, 2, "z_container_green"),
                        (-82.0, -10.0, 90, 2, "z_container_red"), (-82.0, -70.0, 90, 1, "z_container_green"), (-40.0, -66.0, 0, 2, "z_container_red")):
    for j in range(k): prop(m if j % 2 == 0 else ("z_container_green" if m == "z_container_red" else "z_container_red"), (x, j * 3.1, z), r + (180 if j else 0), 1.2, collide=j == 0, tag="contenedor")
prop("s_shipping_container_structure", (-34.0, 0, -6.0), 0, 1.0, tag="contenedor")
prop("s_structure_2", (-82.0, 0, -42.0), 90, 1.0, tag="torre"); inv(-82.0, -42.0, 8.0, 10.6, 8.0)
prop("z_pallet_broken", (-44.0, 0, 0.0), 20, 1.2); prop("s_pallet", (-30.0, 0, 8.0), 0, 1.0); prop("s_crate", (-30.0, 0.2, 8.0), 15, 1.2)
prop("z_pipes", (-36.0, 0, -18.0), 30, 1.2); prop("z_cinder_block", (-30.0, 0, -50.0), 0, 1.2); prop("s_exploding_barrel", (-31.0, 0, -72.0), 0, 1.0)
for (x, z) in ((-86, 18), (-86, -26), (-60, -78), (-34, -78), (-28, -40)): tree(x, z)

# ------------------------------------------------------------------ F · El Bosque (x -90..75, z 24..80)
box(-7, -0.27, 52, 166, 0.3, 56, "#4f6e33", 0, False)
box(0, -0.26, 40, 6, 0.3, 32, "#8a7350", 0, False); box(-30, -0.26, 56, 60, 0.3, 5, "#8a7350", 0, False)      # sendas
random.seed(21)
CLEAR = [(-30, 56, 9), (0, 40, 6), (-8, 66, 10), (62, 32, 8), (-50, 30, 6), (35, 50, 8), (-70, 50, 7)]
for i in range(130):
    x = random.uniform(-88, 73); z = random.uniform(27, 78)
    if any(math.hypot(x - cx, z - cz) < r for (cx, cz, r) in CLEAR): continue
    if abs(x) < 4 and z < 56: continue
    if abs(z - 56) < 3.5 and -60 < x < 0: continue
    tree(x, z)
for i in range(40):
    x = random.uniform(-88, 73); z = random.uniform(27, 78)
    prop(random.choice(["n_bush", "n_fern", "n_plant_big", "n_rock_medium", "n_rock_medium_2"]), (x, 0, z), random.uniform(0, 360), random.uniform(0.6, 1.1), collide=False, tag="arbusto", vis=40.0)
for (x, z) in ((-60, 70), (20, 70), (50, 74)): prop(random.choice(["n_dead_tree", "n_dead_tree_3", "n_twisted_tree"]), (x, 0, z), random.uniform(0, 360), 1.2, collide=False, tag="arbol"); cyl(x, 0, z, 0.4, 2.2, "#4a3626")
# campamento: tiendas, hoguera, troncos, mochila y la radio
prop("v_bonfire", (-30.0, 0, 56.0), 0, 0.45, collide=False, tag="hoguera")
for (x, z, r) in ((-36.0, 52.0, 60), (-24.0, 51.0, -40), (-31.0, 63.0, 180)): prop("v_tent", (x, 0, z), r, 0.17, tag="tienda")
for (x, z, r) in ((-33.0, 57.5, 30), (-27.0, 57.5, -30)): prop("v_wood_log", (x, 0, z), r, 0.32, tag="tronco")
prop("v_backpack", (-28.5, 0, 53.5), 40, 0.18); prop("v_radio", (-31.5, 0.0, 53.8), 0, 0.3); prop("v_propane_tank", (-22.5, 0, 55.0), 0, 0.4); prop("v_axe", (-26.5, 0, 59.5), 70, 0.3)
# la cabaña de la Forja (madera, abierta por delante)
KX0, KX1, KZ0, KZ1, KH = -14.0, -2.0, 60.0, 72.0, 3.8
WOOD = "#7a5230"
wall(KX0, KZ1, KX1, KZ1, KH, WOOD); wall(KX0, KZ0, KX0, KZ1, KH, WOOD); wall(KX1, KZ0, KX1, KZ1, KH, WOOD)
wall(KX0, KZ0, -10.0, KZ0, KH, WOOD); wall(-6.0, KZ0, KX1, KZ0, KH, WOOD)                     # entrada de 4 m
box((KX0 + KX1) / 2, KH, (KZ0 + KZ1) / 2, KX1 - KX0 + 1.2, 0.35, KZ1 - KZ0 + 1.2, "#4a2f1c")
box((KX0 + KX1) / 2, 0.0, (KZ0 + KZ1) / 2, KX1 - KX0 - 0.4, 0.03, KZ1 - KZ0 - 0.4, "#8b6a45", 0, False)
prop("f_table", (-12.0, 0, 64.0), 0, 1.0); prop("f_closet", (-3.0, 0, 70.8), 180, 0.65); prop("v_axe", (-12.0, 0.8, 64.0), 90, 0.3, collide=False)
# vagón de mercancías abandonado y coche en el camino del bosque
prop("car_car_2", (55.0, 0, 34.0), 40, 1.15); prop("s_broken_car", (30.0, 0, 46.0), 150, 0.85)

# ------------------------------------------------------------------ bordes entre zonas (con los huecos de las puertas)
# A|B (x 24): la verja de la calle con la puerta en la carretera; A|E (x -24); A|D (z -24); A|F (z 24)
fence(24.0, -24.0, 24.0, 24.0, "chain", gaps=[(24.0, 5.0)])
fence(-24.0, -24.0, -24.0, 24.0, "metal", gaps=[(24.0, 5.0)])
fence(-24.0, -24.0, 24.0, -24.0, "metal", gaps=[(24.0, 5.0)])
hedge(-24.0, 24.0, 24.0, 24.0, gaps=[(24.0, 5.0)])
# B|D: muro de fondo de la manzana norte con la puerta del callejón (x 40); C|F: puerta trasera del bar
# D|E (x -24, z -80..-24) con puerta en z -50; E|F (z 24, x -90..-24) con puerta en x -50
fence(-24.0, -80.0, -24.0, -24.0, "farm", gaps=[(30.0, 5.0)])
fence(-90.0, 24.0, -24.0, 24.0, "metal", gaps=[(40.0, 5.0)])
# bordes del mapa (setos altos y bosque denso)
hedge(-90.0, -80.0, 90.0, -80.0, h=4.0); hedge(-90.0, -80.0, -90.0, 80.0, h=4.0); hedge(90.0, -80.0, 90.0, 24.0, h=4.0)
hedge(75.0, 24.0, 75.0, 80.0, h=4.0); hedge(-90.0, 80.0, 75.0, 80.0, h=4.0)
hedge(24.2, -24.0, 90.0, -24.0, gaps=[(15.65, 3.6)])   # detrás de los edificios del norte (B|D), con el paso del callejón (x 40)

# ------------------------------------------------------------------ zonas y puertas
Z = [
 {"id": "A", "name": "El Cruce", "open": True, "boxes": [[-23.5, -1, -23.5, 23.5, 6.0, 23.5]],
  "spawns": [[-22.5, 0, -22.5], [22.5, 0, 22.5], [-22.5, 0, 10.0], [10.0, 0, -22.5]]},
 {"id": "B", "name": "Calle Mayor", "boxes": [[24.5, -1, -23.5, 89.5, 6.0, 9.5], [24.5, -1, 9.5, 51.5, 6.0, 23.5], [72.5, -1, 9.5, 89.5, 6.0, 23.5]],
  "spawns": [[87.0, 0, 9.0], [87.0, 0, -9.0], [40.0, 0, -22.0], [33.0, 0, 9.0], [76.0, 0, -9.0]]},
 {"id": "C", "name": "El Bar", "boxes": [[CX0 + 0.5, -1, CZ0 + 0.5, CX1 - 0.5, CH - 0.3, CZ1 - 0.5]], "spawns": [[53.0, 0, 11.0], [71.0, 0, 23.0]]},
 {"id": "D", "name": "La Granja", "boxes": [[-23.5, -1, -79.5, 89.5, 8.0, -24.5]],
  "spawns": [[-22.0, 0, -78.0], [88.0, 0, -78.0], [88.0, 0, -26.0], [30.0, 0, -78.0], [60.0, 0, -66.0]]},
 {"id": "E", "name": "La Estación", "boxes": [[-89.5, -1, -79.5, -24.5, 8.0, 23.5]],
  "spawns": [[-88.0, 0, -78.0], [-88.0, 0, 22.0], [-88.0, 0, -30.0], [-40.0, 0, -78.0], [-30.0, 0, 22.0]]},
 {"id": "F", "name": "El Bosque", "boxes": [[-89.5, -1, 24.5, 74.5, 8.0, 79.5]],
  "spawns": [[-88.0, 0, 78.0], [73.0, 0, 78.0], [0.0, 0, 78.0], [-88.0, 0, 40.0], [73.0, 0, 30.0], [40.0, 0, 78.0]]},
]
D = [
 {"cost": 750, "pos": [24.0, 0, 0.0], "size": [5.0, 3.0, 1.0], "yaw": 90, "opens": ["A", "B"]},
 {"cost": 750, "pos": [0.0, 0, -24.0], "size": [5.0, 3.0, 1.0], "yaw": 0, "opens": ["A", "D"]},
 {"cost": 1000, "pos": [-24.0, 0, 0.0], "size": [5.0, 3.0, 1.0], "yaw": 90, "opens": ["A", "E"]},
 {"cost": 1000, "pos": [0.0, 0, 24.0], "size": [5.0, 3.0, 1.0], "yaw": 0, "opens": ["A", "F"]},
 {"cost": 1000, "pos": [62.0, 0, CZ0], "size": [2.4, 2.5, 1.0], "yaw": 0, "opens": ["B", "C"]},
 {"cost": 1250, "pos": [62.0, 0, CZ1], "size": [2.4, 2.5, 1.0], "yaw": 0, "opens": ["C", "F"]},
 {"cost": 1250, "pos": [39.85, 0, -24.0], "size": [3.6, 3.0, 1.0], "yaw": 0, "opens": ["B", "D"]},
 {"cost": 1250, "pos": [-24.0, 0, -50.0], "size": [5.0, 3.0, 1.0], "yaw": 90, "opens": ["D", "E"]},
 {"cost": 1500, "pos": [-50.0, 0, 24.0], "size": [5.0, 3.0, 1.0], "yaw": 0, "opens": ["E", "F"]},
]

fires = [[-30.0, 0.0, 56.0], [-14.0, 0.0, 2.5], [84.0, 0.0, 0.0], [12.0, 0.0, -50.0], [-44.0, 0.0, 0.0], [30.0, 0.0, 46.0]]
lights = [{"pos": [f[0], 1.6, f[2]], "color": [1.0, 0.5, 0.2], "range": 10, "energy": 2.2} for f in fires]
lights += [{"pos": [x, 5.6, z], "color": [1.0, 0.8, 0.5], "range": 14, "energy": 1.4} for (x, z) in [(-7.6, -18), (7.6, 18), (-18, 7.6), (18, -7.6), (30, -5), (50, -5), (70, -5), (40, 5), (60, 5)]]
lights += [{"pos": [16.5, 4.2, -16.5], "color": [0.9, 0.95, 1.0], "range": 12, "energy": 1.6}]
lights += [{"pos": [x, CH - 0.5, z], "color": [1.0, 0.85, 0.6], "range": 10, "energy": 1.4} for (x, z) in ((57.0, 15.0), (66.0, 18.0))]
lights += [{"pos": [24.0, 6.0, -42.0], "color": [1.0, 0.85, 0.6], "range": 14, "energy": 1.4}, {"pos": [-8.0, 3.2, 66.0], "color": [1.0, 0.6, 0.3], "range": 9, "energy": 1.6}]
lights += [{"pos": [-50.6, 3.0, z], "color": [1.0, 0.9, 0.7], "range": 11, "energy": 1.3} for z in (-42.0, -30.0)]

cfg = {
 "name": "Villa Coral",
 "props": P, "build": B,
 "walls": WALLS,
 "spawn": [14.0, 0.2, 18.5, 0],
 "ambient": "amb1",
 "env": {"sky_top": [0.22, 0.32, 0.55], "sky_horizon": [0.95, 0.62, 0.42], "sky_energy": 1.0, "ambient": 0.75, "exposure": 1.0,
         "fog": [0.85, 0.6, 0.48], "fog_density": 0.011, "sun": 1.1, "sun_color": [1.0, 0.78, 0.55], "sun_rot": [-28, 120], "saturation": 1.05,
         "ambient_color": [0.62, 0.58, 0.62]},
 "zones": Z, "doors": D,
 "fires": fires, "hazards": [], "lights": lights,
 "noshadow": ["valla", "arbusto", "stool", "chair", "cone", "hydrant", "blood", "via", "bag", "log", "barrel", "semaforo", "farola"],
 "wallbuys": [
  {"gun": "olympia", "near": [16.5, -21.6], "y": 0}, {"gun": "mp5k", "near": [-21.0, -12.5], "y": 0},
  {"gun": "m14", "near": [-16.5, 21.5], "y": 0}, {"gun": "ak74u", "near": [45.0, -9.6], "y": 0},
  {"gun": "stakeout", "near": [52.6, 16.0], "y": 0}, {"gun": "m16", "near": [55.0, -39.0], "y": 0},
  {"gun": "mp40", "near": [-40.0, -36.0], "y": 0}, {"gun": "galil", "near": [-2.6, 66.0], "y": 0}, {"gun": "python", "near": [77.0, -9.6], "y": 0}],
 "perks": [
  {"id": "revive", "near": [12.5, -22.0], "y": 0}, {"id": "speed", "near": [31.0, -9.6], "y": 0},
  {"id": "jugg", "near": [71.5, 13.0], "y": 0}, {"id": "dtap", "near": [-40.0, -31.0], "y": 0},
  {"id": "stamin", "near": [41.0, -45.0], "y": 0}, {"id": "mule", "near": [-13.5, 70.0], "y": 0}],
 "box": [{"near": [20.5, -21.6], "y": 0}, {"near": [86.5, -9.6], "y": 0}, {"near": [55.0, -46.0], "y": 0}, {"near": [-40.0, -40.0], "y": 0}, {"near": [-13.5, 62.0], "y": 0}],
 "box_start": 0,
 "pap": {"near": [-8.0, 71.6], "y": 0},
 "power": {"near": [24.0, -47.5], "y": 0},
 "gum": {"near": [9.5, -21.6], "y": 0},
}
json.dump(cfg, open("/home/david/juegos-gambas/zombiesgd/assets/maps/villa/map.json", "w"), ensure_ascii=False, indent=1)
print("piezas", len(P), "bloques", len(B))
