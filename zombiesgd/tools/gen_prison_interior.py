#!/usr/bin/env python3
"""Interior de la Penitenciaría: dentro del edificio principal (que por fuera es el modelo original) se construye
un interior de verdad. Lee assets/maps/prison/map_base.json (el mapa de antes) y escribe map.json con:
  V Vestíbulo (centro): se entra por la puerta doble de la fachada; puesto de guardia con monitores
  Q Galería de celdas (ala oeste): dos pisos de celdas, pasarelas, escalera y puente
  K Comedor y cocina (ala este)
Coordenadas: X al este, Z al sur. Suelo interior a F = 0.85 (el edificio está sobre una losa)."""
import json, math, random
random.seed(3)
BASE = "/home/david/juegos-gambas/zombiesgd/assets/maps/prison/"
cfg = json.load(open(BASE + "map_base.json"))
P = "res://assets/maps/prison/props/"
props = []; build = []; lights = []
F = 0.85          # suelo interior
H1 = 3.6          # altura de un piso
def box(x, y, z, w, h, d, m, r=0, c=True): build.append({"t": "box", "p": [round(x, 3), round(y, 3), round(z, 3)], "s": [round(w, 3), round(h, 3), round(d, 3)], "r": r, "m": m, "c": c})
def span(x0, z0, x1, z1, y0, y1, m, c=True):   # caja de esquina a esquina
    box((x0 + x1) / 2, y0, (z0 + z1) / 2, abs(x1 - x0), y1 - y0, abs(z1 - z0), m, 0, c)
BUDGET = {"bunk": 700, "toilet": 500, "ctable": 1200, "monitor": 600, "lockers": 2000, "sink": 600, "desk": 1500, "trashbags": 1500, "celldoor": 900}
def prop(name, pos, rot=0, scale=1.0, **kw):
    d = {"scene": P + name + "/scene.gltf", "name": kw.pop("tag", name), "pos": [round(v, 3) for v in pos], "rot": rot, "scale": scale}
    if name in BUDGET: d["max_tris"] = BUDGET[name]
    d["vis"] = 30.0 if name not in ("hdoor",) else 60.0
    d.update(kw); props.append(d)
def light(x, y, z, rng=8.0, e=1.2, col=(1.0, 0.92, 0.8)): lights.append({"pos": [x, y, z], "color": list(col), "range": rng, "energy": e})

X0, X1 = 12.75, 63.25       # muros interiores oeste y este
ZN, ZS = -45.35, -34.25     # muros interiores norte y sur
XV0, XV1 = 33.7, 45.4       # vestíbulo (entre las dos alas)
ZV = -37.7                  # fachada del vestíbulo (la puerta doble está en x 37..39)
T = 0.3                     # grosor de muro
TOP = F + 2 * H1 + 0.4      # techo de la galería (8.65)

# ------------------------------------------------------------------ losa del suelo y techos
span(X0, ZN, XV0, ZS, 0, F, "floor"); span(XV1, ZN, X1, ZS, 0, F, "floor"); span(XV0, ZN, XV1, ZV, 0, F, "tiles_dark")
span(X0, ZN, XV0, ZS, TOP, TOP + 0.3, "ceiling")                    # galería (dos pisos)
span(XV0, ZN, XV1, ZV, F + H1 + 0.2, F + H1 + 0.5, "ceiling")        # vestíbulo
span(XV1, ZN, X1, ZS, F + 4.8, F + 5.1, "ceiling")                   # comedor
span(XV0, ZN, XV1, ZV, F + H1 + 0.5, TOP + 0.3, "brick_old")         # (macizo sobre el vestíbulo)

# ------------------------------------------------------------------ muros perimetrales (por dentro de la fachada)
def wall_x(x, z0, z1, y0, y1, m="brick_old"): span(x - T / 2, z0, x + T / 2, z1, y0, y1, m)
def wall_z(z, x0, x1, y0, y1, m="brick_old"): span(x0, z - T / 2, x1, z + T / 2, y0, y1, m)
wall_z(ZN, X0, X1, F, TOP); wall_x(X0, ZN, ZS, F, TOP); wall_x(X1, ZN, ZS, F, TOP)
wall_z(ZS, X0, XV0, F, TOP); wall_z(ZS, XV1, X1, F, TOP)
wall_x(XV0, ZV, ZS, F, TOP); wall_x(XV1, ZV, ZS, F, TOP)              # los lados de la plaza de entrada
# fachada del vestíbulo con la puerta doble (x 37..39, 2.1 m de alto)
wall_z(ZV, XV0, 37.0, F, F + H1 + 0.5); wall_z(ZV, 39.0, XV1, F, F + H1 + 0.5); wall_z(ZV, 37.0, 39.0, F + 2.1, F + H1 + 0.5)
# vestíbulo <-> galería y vestíbulo <-> comedor: puerta de 2 m (z -42..-40)
for x in (XV0, XV1):
    wall_x(x, ZN, -42.0, F, TOP if x == XV0 else F + 5.1); wall_x(x, -40.0, ZV, F, TOP if x == XV0 else F + 5.1); wall_x(x, -42.0, -40.0, F + 2.4, TOP if x == XV0 else F + 5.1)
# puertas metálicas (se abren al comprarlas)
prop("hdoor", (XV0, F, -42.0), -90, 1.0, tag="puerta_galeria"); prop("hdoor", (XV0, F, -40.0), 90, 1.0, tag="puerta_galeria")
prop("hdoor", (XV1, F, -42.0), -90, 1.0, tag="puerta_comedor"); prop("hdoor", (XV1, F, -40.0), 90, 1.0, tag="puerta_comedor")

# ------------------------------------------------------------------ galería de celdas (ala oeste)
NC = 8; CW = (XV0 - X0) / NC          # 8 celdas por fila (2.62 m)
ZCN = -42.4; ZCS = -37.05             # frente de las celdas norte y sur
CAT = 1.2                             # ancho de las pasarelas del piso de arriba
OPEN = {("n", 0, 1), ("n", 0, 5), ("s", 0, 2), ("s", 0, 6), ("n", 1, 3), ("s", 1, 0)}   # celdas abiertas (de ahí salen zombis)
spawns_q = []
for row, zf, zb, rot in (("n", ZCN, ZN, 0), ("s", ZCS, ZS, 180)):
    depth = abs(zf - zb)
    for tier in (0, 1):
        y = F + tier * H1
        for k in range(NC):
            x = X0 + (k + 0.5) * CW
            open_ = (row, tier, k) in OPEN
            if not open_:
                prop("celldoor", (x, y, zf), rot, [CW / 3.87, H1 / 3.01, 1.0], soft=[""])   # barrotes: las balas pasan
            else:
                spawns_q.append([x, y, (zf + zb) / 2])
            # dentro: litera, váter y lavabo (en unas pocas, colchón en el suelo)
            sgn = -1 if row == "n" else 1
            zback = zb + sgn * -0.0
            prop("bunk", (x - CW / 2 + 0.62, y + 0.84, zb - sgn * (depth * 0.5)), 90, 1.0, collide=False)
            prop("toilet", (x + CW / 2 - 0.5, y, zb), 0 if row == "n" else 180, 1.0, collide=False)
            if (k + tier) % 3 == 0: prop("mattress", (x + 0.3, y - 0.07, (zf + zb) / 2), random.choice([10, 80, -30]), 0.026, collide=False)
        # tabiques entre celdas
        for k in range(1, NC):
            xk = X0 + k * CW
            span(xk - 0.1, min(zf, zb), xk + 0.1, max(zf, zb), F + tier * H1, F + (tier + 1) * H1, "plaster")
        # techo/suelo de las celdas
        span(X0, min(zf, zb), XV0, max(zf, zb), F + (tier + 1) * H1 - 0.15, F + (tier + 1) * H1, "plaster")
        # luz dentro de la fila
        for k in range(0, NC, 2): light(X0 + (k + 1) * CW, F + tier * H1 + 2.8, (zf + zb) / 2, 5.0, 0.6, (0.9, 0.95, 1.0))
# pasarelas del primer piso (rejilla), barandillas, puente y descansillo oeste
YC = F + H1
span(X0, ZCN, XV0, ZCN + CAT, YC - 0.12, YC, "grate"); span(X0, ZCS - CAT, XV0, ZCS, YC - 0.12, YC, "grate")
BR0, BR1 = 22.6, 24.2                 # puente
LX = X0 + 1.6                         # descansillo oeste (x X0..LX)
span(BR0, ZCN + CAT, BR1, ZCS - CAT, YC - 0.12, YC, "grate"); span(X0, ZCN + CAT, LX, ZCS - CAT, YC - 0.12, YC, "grate")
def rail_x(z, x0, x1):   # barandilla a lo largo de X
    span(x0, z - 0.03, x1, z + 0.03, YC + 0.98, YC + 1.04, "metal", False); span(x0, z - 0.02, x1, z + 0.02, YC + 0.45, YC + 0.49, "metal", False)
    n = max(2, int((x1 - x0) / 1.5))
    for i in range(n + 1): span(x0 + i * (x1 - x0) / n - 0.025, z - 0.025, x0 + i * (x1 - x0) / n + 0.025, z + 0.025, YC, YC + 1.0, "metal", False)
    # pared invisible para no caerse (y los zombis no la cruzan)
    build.append({"t": "box", "p": [(x0 + x1) / 2, YC, z], "s": [x1 - x0, 1.1, 0.08], "r": 0, "m": "metal", "c": True, "inv": True})
def rail_z(x, z0, z1):
    span(x - 0.03, z0, x + 0.03, z1, YC + 0.98, YC + 1.04, "metal", False)
    n = max(2, int((z1 - z0) / 1.5))
    for i in range(n + 1): span(x - 0.025, z0 + i * (z1 - z0) / n - 0.025, x + 0.025, z0 + i * (z1 - z0) / n + 0.025, YC, YC + 1.0, "metal", False)
    build.append({"t": "box", "p": [x, YC, (z0 + z1) / 2], "s": [0.08, 1.1, z1 - z0], "r": 0, "m": "metal", "c": True, "inv": True})
for z in (ZCN + CAT, ZCS - CAT):
    rail_x(z, LX, BR0); rail_x(z, BR1, XV0)
rail_z(BR0, ZCN + CAT, ZCS - CAT); rail_z(BR1, ZCN + CAT, ZCS - CAT)
# escalera: del suelo (x 19.9) sube hacia el oeste hasta el descansillo (x LX), por el centro
ST0, ST1 = -40.55, -38.95             # ancho de la escalera (z)
steps = 12; run = (19.9 - LX) / steps
rail_z_side = []
for i in range(steps):
    x_hi = 19.9 - i * run
    span(x_hi - run, ST0, x_hi, ST1, F, F + (i + 1) * (H1 / steps), "grate")
rail_z(LX, ZCN + CAT, ST0); rail_z(LX, ST1, ZCS - CAT)
span(LX, ST0 - 0.04, 19.9, ST0, F, F + 0.1, "metal", False)
# luces de la galería: fluorescentes colgados del techo y bajo las pasarelas
for x in (16.5, 23.4, 30.0):
    prop("flamp", (x, TOP - 0.05, -39.7), 90, 1.0, collide=False); light(x, TOP - 0.8, -39.7, 11.0, 1.3)
for x in (17.0, 27.5):
    for z in (ZCN + 0.6, ZCS - 0.6):
        prop("flamp", (x, YC - 0.13, z), 0, 1.0, collide=False); light(x, YC - 0.6, z, 6.0, 0.7)

# ------------------------------------------------------------------ vestíbulo: puesto de guardia
prop("desk", (38.0, F, -41.6), 180, 1.0)
prop("desk", (40.4, F, -41.6), 180, 1.0)
for (x, r) in ((37.5, 200), (38.5, 160), (40.2, 180)): prop("monitor", (x, F + 0.81, -41.85), r, 1.0, collide=False)
prop("chair", (38.2, F + 0.15, -42.6), 10, 0.002, collide=False); prop("chair", (40.6, F + 0.15, -42.7), -20, 0.002, collide=False)
for x in (35.0, 36.7): prop("lockers", (x, F + 1.0, ZN + 0.6), 0, 1.0)
for z in (-44.2, -43.4, -42.6): prop("cabinet", (44.9, F + 0.66, z), -90, 0.0062)
prop("shelves", (34.3, F + 0.04, -38.6), 90, 1.0)
prop("flamp", (36.5, F + H1 + 0.15, -41.5), 90, 1.0, collide=False); prop("flamp", (42.5, F + H1 + 0.15, -41.5), 90, 1.0, collide=False)
light(39.5, F + 3.2, -41.5, 9.0, 1.2); light(38.0, F + 1.2, -41.9, 2.5, 0.6, (0.5, 0.8, 1.0))   # brillo azul de los monitores

# ------------------------------------------------------------------ comedor y cocina (ala este)
XK = 57.8                              # tabique de la cocina
wall_x(XK, ZN, -44.0, F, F + 5.1); wall_x(XK, -37.0, ZS, F, F + 5.1); wall_x(XK, -42.4, -39.0, F + 2.4, F + 5.1)
prop("counter", (XK + 0.2, F + 1.02, -40.7), 0, 1.0)  # mostrador de la comida (en el hueco)
span(XK, ZN, X1, ZS, F, F + 0.02, "tiles", False)     # suelo de baldosa en la cocina
for x in (48.2, 52.4, 55.6):
    for z in (-43.4, -40.6, -37.8, -35.6):
        if (x, z) == (55.6, -35.6): continue
        prop("ctable", (x, F, z), random.choice([0, 180]), 1.0)
for z in (-44.6, -42.4, -37.6, -35.4): prop("shelves", (X1 - 0.3, F + 0.04, z), -90, 1.0)
prop("trashbags", (60.4, F + 0.03, -35.6), 0, 0.0013, collide=False); prop("trashbags", (46.6, F + 0.03, -44.6), 70, 0.001, collide=False)
for (x, z) in ((49.0, -40.6), (53.8, -40.6), (60.5, -40.6)):
    prop("flamp", (x, F + 5.0, z), 90, 1.0, collide=False); light(x, F + 4.2, z, 10.0, 1.2)
light(55.0, F + 4.2, -36.0, 8.0, 0.9)

# ------------------------------------------------------------------ al mapa
cfg["textures"] = "res://assets/maps/prison/extra/"
cfg["props"] = props
cfg["build"] = build
cfg["hide"] = cfg.get("hide", []) + ["Jail_walls_mat", "Jail_pole_mat"]
# dentro no da el sol: los muebles no hacen sombra (los muros y techos sí, para que no entre la luz del sol)
cfg["noshadow"] = cfg.get("noshadow", []) + [n + "_" for n in ["bunk", "toilet", "mattress", "ctable", "monitor", "chair", "lockers", "cabinet", "shelves", "flamp", "trashbags", "celldoor", "desk", "counter", "puerta_galeria", "puerta_comedor"]]
cfg["lights"] = cfg.get("lights", []) + lights
cfg["zones"] = cfg["zones"] + [
 {"id": "V", "name": "Vestíbulo", "boxes": [[XV0 + 0.5, 0.0, ZN, XV1 - 0.5, F + 3.5, ZV - 0.5]], "spawns": [[44.6, F, -44.6], [34.5, F, -44.6]]},
 {"id": "Q", "name": "Galería de celdas", "boxes": [[X0 + 0.15, 0.0, ZN + 0.15, XV0 - 0.5, TOP - 0.3, ZS - 0.15]], "spawns": spawns_q + [[13.6, F, -36.0], [32.8, F, -44.2]]},
 {"id": "K", "name": "Comedor", "boxes": [[XV1 + 0.5, 0.0, ZN + 0.15, X1 - 0.15, F + 4.5, ZS - 0.15]], "spawns": [[62.4, F, -44.5], [62.4, F, -35.0], [46.2, F, -35.0]]},
]
cfg["doors"] = cfg["doors"] + [
 {"cost": 1500, "pos": [38.0, F, ZV], "size": [2.0, 2.1, 1.0], "yaw": 0, "opens": ["N", "V"], "kind": "hide", "hide_meshes": ["Door1", "Door2"]},
 {"cost": 1000, "pos": [XV0, F, -41.0], "size": [2.0, 2.4, 1.0], "yaw": 90, "opens": ["V", "Q"], "kind": "hide", "hide_meshes": ["puerta_galeria"]},
 {"cost": 1250, "pos": [XV1, F, -41.0], "size": [2.0, 2.4, 1.0], "yaw": 90, "opens": ["V", "K"], "kind": "hide", "hide_meshes": ["puerta_comedor"]},
]
cfg["wallbuys"] = cfg["wallbuys"] + [{"gun": "mp5k", "near": [XV0 + 0.2, -38.6], "y": F}, {"gun": "galil", "near": [X0 + 0.2, -39.7], "y": F},
                                     {"gun": "spas", "near": [X1 - 0.2, -39.0], "y": F}]
cfg["box"] = cfg["box"] + [{"near": [24.5, ZS + 3.4], "y": F}, {"near": [51.0, ZN + 0.25], "y": F}]
json.dump(cfg, open(BASE + "map.json", "w"), ensure_ascii=False, indent=1)
print("piezas", len(props), "bloques", len(build), "luces", len(lights))
