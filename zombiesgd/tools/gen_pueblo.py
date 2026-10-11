#!/usr/bin/env python3
"""Genera assets/maps/pueblo/map.json: «Pueblo», el cruce de un pueblo americano arrasado (versión 2).
Calles más estrechas (9 m de calzada y aceras) con los edificios en la línea de fachada, y llenas de cosas: coches,
barricadas, sacos terreros, escombros, postes, contenedores… Nada de vallas lisas: lo que corta el paso se ve.
  A El Cruce (inicio) · B Banco · C Bar · D Diner · E Calle Este y gasolinera · N Calle Norte (bomberos, la Forja)
  W Calle Oeste (iglesia, generador) · S Calle Sur (zona de aterrizaje)
Coordenadas: X al este, Z al sur; el cruce en (0, 0). (La versión 1 está en gen_pueblo_v1.py.)"""
import json, math, random
random.seed(7)
M = "res://assets/maps/pueblo/models/"
B = []; P = []
def box(x, y, z, w, h, d, m, r=0, c=True): B.append({"t": "box", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [round(w, 3), round(h, 3), round(d, 3)], "r": r, "m": m, "c": c})
def inv(x, z, w, d, h=3.0, r=0): B.append({"t": "box", "p": [round(x, 3), 0, round(z, 3)], "s": [round(w, 3), h, round(d, 3)], "r": r, "m": "concrete", "c": True, "inv": True})
def prop(name, pos, rot=0, scale=1.0, **kw):
    d = {"scene": M + name + "/scene.gltf", "name": kw.pop("tag", name), "pos": [round(v, 3) for v in pos], "rot": rot, "scale": scale}
    d.update(kw); P.append(d)

R = 4.5      # media calzada
L = 7.0      # línea de fachada (borde exterior de la acera)
EXT = 62.0

# ------------------------------------------------------------------ suelo
box(0, -0.3, 0, 2 * EXT + 40, 0.3, 2 * EXT + 40, "burned")
box(6, 0, 0, 2 * EXT, 0.02, 2 * R, "asphalt")            # calle principal (O-E)
box(0, 0, 0, 2 * R, 0.02, 2 * EXT, "asphalt")            # calle N-S
for sx in (-1, 1):
    for sz in (-1, 1):
        box(sx * (R + EXT) / 2 + 6 * (sx > 0), 0, sz * (R + L) / 2, EXT - R + 12 * (sx > 0), 0.12, L - R, "sidewalk")
        box(sx * (R + L) / 2, 0, sz * (R + EXT) / 2, L - R, 0.12, EXT - R, "sidewalk")

# grieta de lava en el cruce
crack = [(-9.5, -5.6), (-7.0, -4.2), (-4.8, -3.4), (-2.6, -1.3), (-0.4, -0.6), (1.6, 1.3), (3.6, 2.1), (5.4, 4.0), (7.6, 5.0)]
B.append({"t": "crack", "pts": [list(p) for p in crack], "w": 1.4, "seed": 11})
HAZ = [{"a": list(a), "b": list(b), "r": 0.7} for a, b in zip(crack, crack[1:])]

# ------------------------------------------------------------------ manzana NE: banco, almacén, tienda y edificio de ladrillo (fachadas a la calle principal)
BANK = (11.6, -11.66)
prop("bank", (BANK[0], 0, BANK[1]))
prop("general_store", (23.6, 0, -12.0), 0, 0.025)
prop("storefront", (34.2, 0, -7.7), 0, 0.01, max_tris=6000)
prop("brick_shop", (49.2, -4.47, -10.4))
# Calle Norte, lado este: casa de madera y solar con contenedores
prop("wood_store", (11.9, 0, -23.0), -90, 1.0, max_tris=6000)
prop("dumpster", (9.4, 0, -33.0), 90, 0.03, max_tris=3000)
# ------------------------------------------------------------------ manzana NO: el bar (saloon) y tiendas viejas
BAR_X0, BAR_X1, BAR_Z0, BAR_Z1 = -15.83, -7.0, -22.09, -8.3
prop("saloon_interior", (-9.54, 0, -5.8), 0, 125.0)
DOOR_BAR = -11.4
box((BAR_X0 + DOOR_BAR - 1.0) / 2, 0, BAR_Z1 - 0.1, DOOR_BAR - 1.0 - BAR_X0, 5.0, 0.3, "brick")
box((DOOR_BAR + 1.0 + BAR_X1) / 2, 0, BAR_Z1 - 0.1, BAR_X1 - DOOR_BAR - 1.0, 5.0, 0.3, "brick")
box(DOOR_BAR, 2.7, BAR_Z1 - 0.1, 2.0, 2.3, 0.3, "brick")
box(-7.2, 0, (BAR_Z0 + BAR_Z1) / 2, 0.3, 5.0, BAR_Z1 - BAR_Z0, "brick")   # lado del bar a la Calle Norte
prop("old_buildings", (-28.6, 0, -10.6), -90)
prop("general_store", (-12.0, 0, -32.0), 90, 0.025, tag="almacen_norte")   # Calle Norte, lado oeste
# ------------------------------------------------------------------ manzana SO: el diner (más grande: las puertas eran pequeñas) y el saloon viejo
DINER = (-21.1, 14.5)
DS = 1.12
prop("diner", (DINER[0], 0, DINER[1]), 180, DS, nocollide=["Napkin", "ketchup", "Sauce", "Salt", "lemons", "Donus", "Package", "Bread", "caps", "MENU", "Paper", "Tray", "Lights", "Coffee", "Tumbler"], soft=["Glass"])   # (los cristales paran a la gente; las balas pasan)
prop("saloon_exterior", (-39.0, 3.87, 11.8), 180, 5.0)
prop("wood_store", (-11.9, 0, 35.0), 90, 1.0, max_tris=6000, tag="casa_sur")
# ------------------------------------------------------------------ manzana SE: la gasolinera (por la calle Este y la Sur)
prop("gas", (27.7, 0, 19.2), 180)
# ------------------------------------------------------------------ fondos de las calles
prop("fire_station", (2.0, 0, -50.9))                            # bomberos al final de la Calle Norte
prop("church", (-51.0, 3.12, 0), 0, 3.0)                         # iglesia al final de la Calle Oeste
prop("house", (0, 0.14, 47.0), 0, 0.0065)                        # casa al final de la Calle Sur
prop("water_tower", (-46.0, 0, -40.0), 0, 0.5, collide=False)
prop("storefront", (64.0, 0, 0.0), -90, 0.01, max_tris=6000, tag="fondo_este")
prop("general_store", (70.0, 0, 13.0), -90, 0.025, tag="fondo_este2")

# ------------------------------------------------------------------ cierres de los huecos entre edificios (vallas de verdad, no cajas)
def chain(x0, z0, x1, z1):   # valla metálica de x0,z0 a x1,z1 (secciones de 10.9 m)
    Ln = math.hypot(x1 - x0, z1 - z0); a = math.degrees(math.atan2(x1 - x0, z1 - z0))
    n = max(1, round(Ln / 10.9))
    for i in range(n):
        t = (i + 0.5) / n
        prop("chainlink", (x0 + (x1 - x0) * t, 0, z0 + (z1 - z0) * t), a, [0.35, 0.35, 0.35 * (Ln / n) / 10.9], collide=False)
    inv((x0 + x1) / 2, (z0 + z1) / 2, 0.25, Ln, 3.0, a)
chain(7.2, -7.1, 7.2, -20.0); chain(7.2, -24.8, 7.2, -40.8)         # Calle Norte, lado este (banco / casa / solar)
chain(15.1, -7.1, 16.3, -7.1)                                         # entre el banco y el almacén
inv(9.25, -7.12, 2.5, 0.2, 3.0); inv(13.95, -7.12, 2.5, 0.2, 3.0)   # ventanas del banco (sin cristal)
inv(8.05, -11.6, 0.2, 9.0); inv(15.15, -11.6, 0.2, 9.0)              # y sus lados
inv(23.6, -7.15, 15.2, 0.2); inv(-7.15, -32.0, 0.2, 15.2)            # los almacenes son solo fachada (puertas sin hoja)
inv(-30.1, 18.5, 0.3, 21.0); inv(-30.45, 9.0, 0.9, 0.3)              # lado oeste del diner (sin callejón)
chain(31.0, -7.1, 31.8, -7.1)                                         # entre el almacén y la tienda
chain(-7.2, -22.1, -7.2, -26.0); chain(-7.2, -38.4, -7.2, -40.8)      # Calle Norte, lado oeste (bar / almacén)
chain(-15.6, -7.2, -17.9, -7.2); chain(-46.5, -7.2, -38.5, -7.2); chain(-46.5, 7.2, -43.6, 7.2)   # Calle Oeste
chain(7.3, 7.3, 22.0, 7.3); chain(7.3, 7.3, 7.3, 34.4)                # la gasolinera no da al cruce ni a la Calle Sur
chain(-7.4, 12.5, -7.4, 31.8); chain(-7.4, 36.5, -7.4, 42.0); chain(7.4, 34.4, 7.4, 42.0)   # Calle Sur (el lado del diner)
chain(-12.3, 12.5, -7.4, 12.5)                                        # callejón del diner
chain(-34.3, 7.2, -30.8, 7.2); chain(-30.8, 7.2, -30.8, 12.4); chain(-23.0, 7.2, -23.0, 11.6)   # patio del diner (y su separación con la Calle Oeste)
chain(58.5, 7.2, 60.6, 7.2); chain(58.5, 7.2, 58.5, 34.4); chain(8.6, 34.4, 58.5, 34.4)       # gasolinera, fondo

# ------------------------------------------------------------------ calle: coches, barricadas, escombros y basura
prop("police_cars_burned", (-2.5, 0, -15.0), 20, 0.0085)
prop("burned_cars", (16.0, 0, 2.2), -75, 0.016)
prop("crashed_car", (-15.0, 0, 3.0), 115, 0.6, max_tris=3500)
prop("crashed_car", (2.5, 0, 30.0), -10, 0.6, max_tris=3500)
prop("crashed_car", (40.0, 0, -2.0), 70, 0.6, max_tris=3500)
prop("bus", (-2.6, 0, -34.0), 8, 1.0, max_tris=6000)             # el autobús escolar del pueblo (el del easter egg)
prop("sandbags", (-4.6, 0, 15.5), 90, 0.55, max_tris=3000)
prop("sandbags", (14.0, 0, 4.4), 90, 0.5, max_tris=3000)
prop("barriers", (-20.0, 0, -4.4), 0, 1.0, max_tris=3500)
prop("barriers", (3.0, 0, -20.5), 180, 1.0, max_tris=3500)
prop("police_sign", (-3.0, 0.88, 20.6), 0, 0.012)
prop("police_sign", (24.0, 0.88, 5.8), 90, 0.012)
for (x, z, r) in [(-6.0, -9.5, 0), (5.8, 11.0, 40), (-26.0, 5.2, 10), (30.0, -5.4, 0), (-5.6, 26.0, 70), (4.5, -27.5, 20)]:
    prop("rubble", (x, 0, z), r, random.uniform(0.8, 1.2), collide=False)
for (x, z, r) in [(-12.5, 5.6, 0), (24.0, 5.6, 30), (-35.0, -5.2, 60), (6.0, -38.0, 0)]:
    prop("planks", (x - 13.4, 0, z), r, 1.0, collide=False, max_tris=3000)
for (x, z) in [(-8.0, -7.6), (8.2, 7.6), (-30.0, 6.3), (44.0, -6.2), (6.3, -18.0), (-6.3, 18.0)]:
    prop("street_pack", (x, 0.12, z), random.choice([0, 90, 180]), 0.5, only=["Bin_"])
for (x, z) in [(-7.6, -18.0), (7.6, 18.0), (-18.0, 7.6), (18.0, -7.6), (-40.0, -6.3), (50.0, 6.3)]:
    prop("street_pack", (x, 0.12, z), 0, 0.5, only=["Hydrant"])
for (x, z) in [(6.2, -12.0), (-6.2, 12.5), (15.0, 6.4), (-20.0, -6.3), (37.0, 6.4)]:
    prop("street_pack", (x, 0.12, z), random.choice([0, 180]), 0.5, only=["trashbag"])
for (x, z) in [(10.2, 5.8), (-29.0, -6.0)]: prop("street_pack", (x, 0.12, z), 0, 0.5, only=["Barrel_"])
prop("street_pack", (-6.4, 0.12, 6.4), 45, 0.5, only=["stop_"])
prop("street_pack", (6.4, 0.12, -6.4), 225, 0.5, only=["stop_"])
prop("mailbox", (-6.2, 0.12, -14.0), 90, 0.25)
prop("bench", (27.0, 0.57, -6.2), 0, 0.6)
prop("bench", (-26.0, 0.57, 6.2), 180, 0.6)
for (x, z, s) in [(-44.0, -14.0, 1.0), (14.0, 40.0, 0.8), (-20.0, 40.0, 1.0)]: prop("dead_trees", (x, 0, z), random.randint(0, 359), s, collide=False)
prop("old_tree", (-40.0, 0, 30.0), 0, 1.0, collide=False)
# postes de teléfono a lo largo de las aceras (pareja de postes con cables)
for (x, z, r) in [(-22.0, -6.6, 0), (22.0, 6.6, 0), (-6.6, -30.0, 90), (6.6, 25.0, 90)]:
    prop("poles", (x, 0, z), r, 0.3, collide=False, max_tris=2500)

# ------------------------------------------------------------------ final de cada calle: barricada de verdad (coches, sacos, barreras) y pared invisible detrás
WALLS = []
ENDS = [(-46.5, 0, 90), (0, 41.6, 0), (60.5, 0, 90)]   # (la Calle Norte la cierra el parque de bomberos)
for (x, z, r) in ENDS:
    for k in (-1, 1):
        o = k * 3.2
        px, pz = (x + o, z) if r == 0 else (x, z + o)
        prop("street_pack", (px, 0, pz), r + random.choice([0, 180]), 0.5, only=["concrete_barrier"])
    prop("barriers", (x, 0, z), r + 180, 1.0, max_tris=3500, collide=False)
    WALLS.append([x, 2.0, z, 2 * L if r == 0 else 0.6, 6.0, 0.6 if r == 0 else 2 * L])
prop("sandbags", (-44.0, 0, 3.0), 0, 0.8, max_tris=3000, collide=False)
prop("crashed_car", (57.0, 0, -3.0), 160, 0.6, max_tris=3500)

# ------------------------------------------------------------------ zonas (las mismas de antes, en la nueva distribución)
WX = -22.0     # puerta de la Calle Oeste
Z = [
 {"id": "A", "name": "El Cruce", "open": True, "boxes": [[WX, -1, -L, 22.0, 6, L], [-L, -1, -22.0, L, 6, -L], [-L, -1, L, L, 6, 22.0], [-23.0, -1, L, -L, 6, 11.1], [BAR_X0, -1, BAR_Z1, -L, 6, -L]],
  "spawns": [[WX + 1.0, 0, -5.5], [21.0, 0, 5.5], [-5.5, 0, -21.0], [5.5, 0, 21.0], [-8.4, 0, 7.6], [21.0, 0, -5.5]]},
 {"id": "B", "name": "Banco", "boxes": [[8.6, -1, -16.2, 14.6, 8.0, -7.2]], "spawns": [[9.2, 0, -15.7], [14.0, 0, -15.7]]},
 {"id": "C", "name": "Bar", "boxes": [[BAR_X0 + 0.2, -1, BAR_Z0 + 0.2, BAR_X1 - 0.4, 7.0, BAR_Z1 - 0.3]], "spawns": [[-15.1, 0, -21.4], [-7.7, 0, -21.4]]},
 {"id": "D", "name": "Diner", "boxes": [[-29.7, -1, 9.2, -22.9, 5.0, 25.9], [-22.9, -1, 12.1, -12.5, 5.0, 25.9]], "spawns": [[-29.6, 0, 25.0], [-13.4, 0, 25.0]]},
 {"id": "E", "name": "Gasolinera", "boxes": [[22.0, -1, -L, 60.0, 4.0, L], [8.6, -1, L, 58.3, 4.0, 34.2]], "spawns": [[59.0, 0, 0.0], [56.0, 0, 33.5], [10.0, 0, 33.5]]},
 {"id": "N", "name": "Calle Norte", "boxes": [[-L, -1, -40.8, L, 7.0, -22.0]], "spawns": [[-6.4, 0, -40.0], [6.4, 0, -40.0]]},
 {"id": "W", "name": "Calle Oeste", "boxes": [[-46.0, -1, -L, WX, 7.0, L], [-30.6, -1, L, -23.0, 7.0, 8.8]], "spawns": [[-45.0, 0, -6.4], [-45.0, 0, 6.4]]},
 {"id": "S", "name": "Calle Sur", "boxes": [[-L, -1, 22.0, L, 7.0, 41.2]], "spawns": [[-6.4, 0, 40.4], [6.4, 0, 40.4]]},
]
D = [
 {"cost": 750, "pos": [BANK[0], 0, -7.05], "size": [2.4, 2.6, 1.0], "yaw": 0, "opens": ["A", "B"], "hide_meshes": ["door_left", "door_right"]},
 {"cost": 1000, "pos": [DOOR_BAR, 0, BAR_Z1 - 0.1], "size": [2.0, 2.6, 1.0], "yaw": 0, "opens": ["A", "C"]},
 {"cost": 1000, "pos": [DINER[0] - 0.56, 0, DINER[1] - 2.9], "size": [1.3, 2.4, 1.0], "yaw": 0, "opens": ["A", "D"], "kind": "hide", "hide_meshes": ["Door_03"]},
 {"cost": 1250, "pos": [22.0, 0, 0], "size": [2 * L, 3.0, 1.2], "yaw": 90, "opens": ["A", "E"]},
 {"cost": 1000, "pos": [0, 0, -22.0], "size": [2 * L, 3.0, 1.2], "yaw": 0, "opens": ["A", "N"]},
 {"cost": 1000, "pos": [WX, 0, 0], "size": [2 * L, 3.0, 1.2], "yaw": 90, "opens": ["A", "W"]},
 {"cost": 1250, "pos": [0, 0, 22.0], "size": [2 * L, 3.0, 1.2], "yaw": 0, "opens": ["A", "S"]},
]
# paredes invisibles en las bocas de los solares (para que nadie salga del mapa por un hueco)
WALLS.append([0, 2.0, -40.6, 2 * L, 6.0, 0.4])   # (por si queda algún hueco delante de los bomberos)

fires = [[-2.5, 0.6, -15.0], [16.0, 0.5, 2.2], [2.3, 0.2, 0.7], [-5.0, 0.2, -3.0], [5.6, 0.2, 4.3], [-15.0, 0.4, 3.0], [-2.6, 0.5, -34.0], [40.0, 0.4, -2.0], [57.0, 0.4, -3.0]]
lights = [{"pos": [f[0], 1.6, f[2]], "color": [1.0, 0.45, 0.15], "range": 9, "energy": 2.2} for f in fires]
lights += [{"pos": [x, 4.5, z], "color": [1.0, 0.8, 0.55], "range": 11, "energy": 1.3} for (x, z) in [(-6.5, -6.5), (6.5, 6.5), (30, -6.5), (-30, 6.5), (0, -30), (0, 30), (40, 20), (-38, -6.5)]]
lights += [{"pos": [x, 2.4, z], "color": [1.0, 0.78, 0.5], "range": 7, "energy": 1.2} for (x, z) in [(11.6, -13), (-11.5, -15), (-21, 18), (45, 25), (34.2, -8.6)]]

cfg = {
 "name": "Pueblo",
 "props": P, "build": B, "textures": "res://assets/maps/pueblo/textures/",
 "walls": WALLS,
 "spawn": [0.0, 0.2, 4.5, 180],
 "ambient": "amb1",
 "env": {"sky_top": [0.05, 0.05, 0.09], "sky_horizon": [0.32, 0.14, 0.1], "sky_energy": 0.6, "ambient": 0.55, "exposure": 1.05,
         "fog": [0.25, 0.12, 0.08], "fog_density": 0.02, "sun": 0.55, "sun_color": [0.75, 0.75, 1.0], "sun_rot": [-38, 120], "saturation": 0.85,
         "ambient_color": [0.32, 0.27, 0.3]},
 "zones": Z, "doors": D,
 "fires": fires, "hazards": HAZ, "lights": lights,
 "noshadow": ["chainlink", "street_pack", "rubble", "planks", "poles", "police_sign", "mailbox", "bench", "dead_trees", "barriers"],
 "wallbuys": [
  {"gun": "olympia", "near": [-7.2, -16.0], "y": 0}, {"gun": "m14", "near": [7.6, 15.0], "y": 0},
  {"gun": "mp5k", "near": [16.2, -7.1], "y": 0}, {"gun": "ak74u", "near": [-15.5, -14.0], "y": 0},
  {"gun": "mp40", "near": [-30.0, 7.2], "y": 0}, {"gun": "m16", "near": [40.0, 8.6], "y": 0},
  {"gun": "stakeout", "near": [-7.0, -30.0], "y": 0}, {"gun": "python", "near": [-34.0, -7.2], "y": 0}],
 "perks": [
  {"id": "revive", "near": [-7.6, 14.0], "y": 0}, {"id": "jugg", "near": [-8.0, -20.5], "y": 0},
  {"id": "speed", "near": [45.0, 30.0], "y": 0}, {"id": "dtap", "near": [13.8, -15.6], "y": 0},
  {"id": "stamin", "near": [-40.0, -7.2], "y": 0}, {"id": "mule", "near": [-14.0, 25.0], "y": 0}],
 "box": [{"near": [6.6, -14.0], "y": 0}, {"near": [-15.0, -12.0], "y": 0}, {"near": [-25.0, 24.0], "y": 0}, {"near": [50.0, 6.0], "y": 0}, {"near": [7.4, 30.0], "y": 0}],
 "box_start": 0,
 "pap": {"near": [0.0, -39.6], "y": 0},
 "power": {"near": [-45.6, 4.0], "y": 0},
 "gum": {"near": [6.9, -10.0], "y": 0},
}
json.dump(cfg, open("/home/david/juegos-gambas/zombiesgd/assets/maps/pueblo/map.json", "w"), ensure_ascii=False, indent=1)
print("piezas", len(P), "bloques", len(B))
