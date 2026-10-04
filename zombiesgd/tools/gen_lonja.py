#!/usr/bin/env python3
"""Genera assets/maps/lonja/map.json: La Lonja (nave de marisco abandonada, modelo ×1.45).
Zonas: A Sala de Subastas (inicio), B Nave de Envasado (con la oficina de arriba), C Cámaras Frigoríficas,
Y Patio de Carga (fuera), N Sala de Calderas (Pack-a-Punch), W Oficina de Ventas."""
import json, random
random.seed(42)
B = []   # geometría añadida
def box(x, y, z, w, h, d, m, r=0, c=True): B.append({"t": "box", "p": [round(x,3), round(y,3), round(z,3)], "s": [round(w,3), round(h,3), round(d,3)], "r": r, "m": m, "c": c})
def cyl(x, y, z, rad, h, m, c=True): B.append({"t": "cyl", "p": [round(x,3), round(y,3), round(z,3)], "s": [rad, h], "m": m, "c": c})

# --- tabiques de chapa con hueco para la puerta
def wall_x(x, z0, z1, gap0, gap1, h=4.6, m="corrugated"):   # tabique a lo largo de z en x fija
    if gap0 > z0: box(x, 0, (z0 + gap0) / 2, 0.3, h, gap0 - z0, m)
    if z1 > gap1: box(x, 0, (gap1 + z1) / 2, 0.3, h, z1 - gap1, m)
    box(x, 3.0, (gap0 + gap1) / 2, 0.3, h - 3.0, gap1 - gap0, m)   # dintel
def wall_z(z, x0, x1, gap0, gap1, h=4.6, m="corrugated"):
    if gap0 > x0: box((x0 + gap0) / 2, 0, z, gap0 - x0, h, 0.3, m)
    if x1 > gap1: box((gap1 + x1) / 2, 0, z, x1 - gap1, h, 0.3, m)
    box((gap0 + gap1) / 2, 3.0, z, gap1 - gap0, h - 3.0, 0.3, m)
wall_x(-19.0, 6.1, 25.5, 13.9, 17.9)          # A | B
wall_z(6.1, -10.7, 10.4, 0.0, 4.0)            # B | C
box(4.2, 0, -22.2, 8.4, 4.8, 0.4, "corrugated")   # portón principal de las cámaras: cerrado (daba al vacío)

# --- patio: suelo y muro perimetral
box(-21.0, -0.3, -7.85, 20.8, 0.3, 28.0, "asphalt")
box(-31.6, 0, -7.85, 0.6, 5.0, 28.0, "wall")
box(-21.0, 0, -22.05, 21.2, 5.0, 0.6, "wall")
# contenedores en el patio (cobertura)
for (x, z, r, m) in [(-26.5, -15.0, 0, "cont_red"), (-17.0, -9.0, 90, "cont_blue"), (-25.0, -3.0, 15, "cont_green"), (-15.5, -18.5, 0, "cont_blue")]:
    box(x, 0, z, 6.0, 2.6, 2.4, m, r)
box(-26.5, 2.6, -15.0, 6.0, 2.6, 2.4, "cont_blue", 4)   # uno encima de otro
for (x, z) in [(-21.0, -18.0), (-13.5, -3.0), (-29.0, 2.5)]:   # palés con cajas
    box(x, 0, z, 1.2, 0.15, 1.0, "wood"); box(x, 0.15, z, 1.1, 0.9, 0.9, "crate_blue")

# --- A: Sala de Subastas — mesas de subasta con cajas de pescado y hielo
for row in range(3):
    z = 10.0 + row * 5.0
    for col in range(2):
        x = -28.0 + col * 5.0
        box(x, 0, z, 3.2, 0.9, 1.1, "steel")
        box(x, 0.9, z, 3.0, 0.08, 0.9, "ice", c=False)
        for k in range(3): box(x - 1.0 + k * 1.0, 0.98, z, 0.6, 0.25, 0.4, random.choice(["crate_blue", "crate_red"]), c=False)
for (x, z) in [(-30.0, 23.5), (-21.0, 23.8), (-20.7, 8.0)]:   # pilas de cajas
    for k in range(random.randint(2, 4)): box(x + random.uniform(-0.1, 0.1), k * 0.32, z, 0.65, 0.32, 0.45, random.choice(["crate_blue", "crate_red"]), random.randint(-8, 8))
box(-25.5, 0, 24.6, 4.0, 1.1, 0.8, "wood")   # mostrador

# --- B: Nave de Envasado — cintas transportadoras y cocederos
for z in (10.5, 21.5):
    box(-6.0, 0, z, 9.0, 0.9, 1.0, "steel")
    for k in range(9): box(-10.0 + k, 0.9, z, 0.8, 0.12, 0.85, "rust", c=False)
for x in (-14.5, -11.5):
    cyl(x, 0, 16.0, 1.0, 1.4, "steel")
box(6.5, 0, 8.5, 2.4, 1.6, 1.2, "rust", 90)

# --- C: Cámaras Frigoríficas — cámaras blancas (bloques) y palés de latas
for (x, z, w, d) in [(-6.5, -16.5, 6.0, 5.0), (6.0, -16.5, 6.0, 5.0), (6.5, -4.0, 5.0, 7.0)]:
    box(x, 0, z, w, 3.2, d, "white")
for (x, z) in [(-5.0, -6.0), (-1.0, 0.5), (2.5, -9.5), (-7.5, 2.5)]:
    box(x, 0, z, 1.2, 0.15, 1.0, "wood"); box(x, 0.15, z, 1.1, 1.1, 0.9, "steel")

# --- zonas (cajas de navegación) y puertas
Z = [
 {"id": "A", "name": "Sala de Subastas", "open": True, "boxes": [[-31.0, -1, 6.6, -19.6, 4.4, 25.2]],
  "spawns": [[-30.3, 0, 7.5], [-20.4, 0, 7.6], [-30.3, 0, 24.3], [-24.0, 0, 24.6], [-20.4, 0, 20.5]]},
 {"id": "B", "name": "Nave de Envasado", "boxes": [[-18.4, -1, 6.7, 10.2, 8.0, 25.2]],
  "spawns": [[-17.5, 0, 7.5], [9.4, 0, 7.5], [9.4, 0, 24.5], [-10.0, 0, 24.5], [-17.6, 0, 24.5]]},
 {"id": "C", "name": "Cámaras Frigoríficas", "boxes": [[-10.4, -1, -21.5, 10.2, 6.0, 5.5]],
  "spawns": [[-9.8, 0, -10.0], [9.5, 0, -10.0], [0.0, 0, -21.0], [9.5, 0, 4.7], [-9.8, 0, 4.7]]},
 {"id": "Y", "name": "Patio de Carga", "boxes": [[-31.0, -1, -21.5, -11.3, 6.0, 5.5]],
  "spawns": [[-30.5, 0, -21.0], [-30.5, 0, 4.8], [-20.0, 0, -21.0], [-12.0, 0, -12.0], [-22.0, 0, -8.0]]},
 {"id": "N", "name": "Sala de Calderas", "boxes": [[-10.2, -1, -25.4, -4.9, 4.0, -22.35]], "spawns": [[-5.6, 0, -24.8]]},
 {"id": "W", "name": "Oficina de Ventas", "boxes": [[-34.5, -1, 12.9, -31.95, 4.0, 17.8]], "spawns": [[-34.0, 0, 13.5]]},
]
D = [
 {"cost": 750, "pos": [-19.0, 0, 15.9], "size": [4.0, 3.0, 1.2], "yaw": 90, "opens": ["A", "B"]},
 {"cost": 1000, "pos": [2.0, 0, 6.1], "size": [4.0, 3.0, 1.2], "yaw": 0, "opens": ["B", "C"]},
 {"cost": 1000, "pos": [-22.3, 0, 6.1], "size": [5.0, 3.4, 1.2], "yaw": 0, "opens": ["A", "Y"]},
 {"cost": 1250, "pos": [-16.4, 0, 6.1], "size": [4.6, 3.4, 1.2], "yaw": 0, "opens": ["B", "Y"]},
 {"cost": 1250, "pos": [-10.85, 0, -17.7], "size": [1.8, 2.3, 1.2], "yaw": 90, "opens": ["C", "Y"], "kind": "hide", "hide_meshes": ["Door2/", "Door2_001"]},
 {"cost": 1500, "pos": [-8.85, 0, -21.85], "size": [2.0, 2.3, 1.0], "yaw": 0, "opens": ["C", "N"], "kind": "hide", "hide_meshes": ["Door2_002", "Door2_003", "Door2_004"]},
 {"cost": 750, "pos": [-31.35, 0, 16.4], "size": [2.0, 2.3, 1.0], "yaw": 90, "opens": ["A", "W"], "kind": "hide", "hide_meshes": ["Door2_008", "Door2_009", "Door2_010"]},
]
cfg = {
 "name": "La Lonja",
 "scene": "res://assets/maps/lonja/scene.gltf",
 "scale": 1.45,
 "nocollide": ["cable", "Windows", "OfficeWindows"],
 "soft": ["Railings"],
 "spawn": [-25.0, 0.2, 19.5, 180],
 "ambient": "amb1",
 "env": {"sky_top": [0.16, 0.18, 0.24], "sky_horizon": [0.42, 0.38, 0.36], "sky_energy": 0.7, "ambient": 0.7, "exposure": 1.0,
         "fog": [0.32, 0.33, 0.36], "fog_density": 0.014, "sun": 0.9, "sun_color": [1.0, 0.8, 0.62], "sun_rot": [-32, 210], "saturation": 0.8,
         "ambient_color": [0.42, 0.42, 0.46]},
 "zones": Z, "doors": D, "build": B,
 "lights": [{"pos": [x, 4.2, z], "color": [1.0, 0.82, 0.6], "range": 10, "energy": 1.6} for (x, z) in
            [(-26, 11), (-26, 21), (-12, 11), (-12, 21), (2, 11), (2, 21), (0, 0), (0, -12), (-8, -23.8), (-33, 15.3), (5, 19)]],
 "wallbuys": [
  {"gun": "olympia", "near": [-31.0, 21.5], "y": 0}, {"gun": "m14", "near": [-24.0, 25.3], "y": 0},
  {"gun": "mp40", "near": [-4.0, 25.3], "y": 0}, {"gun": "ak74u", "near": [10.2, 13.0], "y": 0},
  {"gun": "m16", "near": [10.2, -10.0], "y": 0}, {"gun": "stakeout", "near": [-10.5, -5.0], "y": 0},
  {"gun": "python", "near": [-31.2, -10.0], "y": 0}, {"gun": "mp5k", "near": [-20.0, -21.6], "y": 0}],
 "perks": [
  {"id": "revive", "near": [-31.0, 9.5], "y": 0}, {"id": "speed", "near": [3.0, 25.3], "y": 0},
  {"id": "jugg", "near": [10.2, -19.0], "y": 0}, {"id": "stamin", "near": [-31.2, -3.0], "y": 0},
  {"id": "dtap", "near": [-14.0, 25.3], "y": 0}, {"id": "mule", "near": [-34.2, 16.8], "y": 0}],
 "box": [{"near": [-22.5, 25.3], "y": 0}, {"near": [10.2, 21.0], "y": 0}, {"near": [0.0, -21.6], "y": 0}, {"near": [-20.0, 5.6], "y": 0}],
 "box_start": 0,
 "pap": {"near": [-7.0, -25.3], "y": 0},
 "power": {"near": [9.5, 23.0], "y": 5.1},
 "gum": {"near": [-20.6, 12.0], "y": 0},
}
json.dump(cfg, open("/home/david/juegos-gambas/zombiesgd/assets/maps/lonja/map.json", "w"), ensure_ascii=False, indent=1)
print("piezas", len(B))
