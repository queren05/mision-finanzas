// Mapa de Shrimp Zombies: rejilla de casillas de 1 m (x hacia la derecha, z hacia abajo en el plano).
// Zonas: A (inicio), B (salón), C (sala de la caja), D (patio del cementerio). El anillo exterior es por donde llegan los zombis.
import * as THREE from './lib/three.module.min.js';
import { mergeGeometries } from './lib/BufferGeometryUtils.js';

export const GW = 26, GH = 24, WALL_H = 2.7;
// tipos de casilla
export const VOID = 0, FLOOR = 1, WALL = 2, WIN = 3, DOOR = 4, OUT = 5, FENCE = 6, PROP = 7;
export const grid = new Uint8Array(GW * GH);
export const zoneOf = new Int8Array(GW * GH).fill(-1);
export const idx = (x, z) => z * GW + x;
export const ZONES = [
  { id: 'A', name: 'Habitación', x0: 2, x1: 11, z0: 13, z1: 21, open: true },
  { id: 'B', name: 'Salón', x0: 2, x1: 11, z0: 2, z1: 10, open: false },
  { id: 'C', name: 'Despensa', x0: 14, x1: 23, z0: 2, z1: 10, open: false },
  { id: 'D', name: 'Cementerio', x0: 14, x1: 23, z0: 13, z1: 21, open: false, outside: true },
];
export const DOORS = [
  { id: 0, cost: 750, cells: [[6, 11], [6, 12]], zones: [0, 1], open: false, axis: 'z' },
  { id: 1, cost: 1000, cells: [[12, 6], [13, 6]], zones: [1, 2], open: false, axis: 'x' },
  { id: 2, cost: 1250, cells: [[18, 11], [18, 12]], zones: [2, 3], open: false, axis: 'z' },
  { id: 3, cost: 1000, cells: [[12, 17], [13, 17]], zones: [0, 3], open: false, axis: 'x' },
];
// ventanas: casilla de la pared, casilla de fuera (por donde llega el zombi) y casilla de dentro
export const WINDOWS = [
  [1, 15, 0], [1, 19, 0], [5, 22, 0], [9, 22, 0],
  [1, 4, 1], [1, 8, 1], [6, 1, 1],
  [17, 1, 2], [21, 1, 2], [24, 6, 2],
  [24, 16, 3], [24, 20, 3], [18, 22, 3],
].map(([x, z, zone]) => {
  const out = x === 1 ? [0, z] : x === 24 ? [25, z] : z === 1 ? [x, 0] : [x, 23];
  const inn = x === 1 ? [2, z] : x === 24 ? [23, z] : z === 1 ? [x, 2] : [x, 21];
  return { x, z, zone, out, inn, boards: 6, meshes: [] };
});
export function buildGrid() {
  grid.fill(VOID);
  for (let z = 0; z < GH; z++) for (let x = 0; x < GW; x++) if (x === 0 || z === 0 || x === GW - 1 || z === GH - 1) grid[idx(x, z)] = OUT;
  ZONES.forEach((Z, zi) => {
    for (let z = Z.z0 - 1; z <= Z.z1 + 1; z++) for (let x = Z.x0 - 1; x <= Z.x1 + 1; x++) {
      const inside = x >= Z.x0 && x <= Z.x1 && z >= Z.z0 && z <= Z.z1;
      if (inside) { grid[idx(x, z)] = FLOOR; zoneOf[idx(x, z)] = zi; }
      else if (grid[idx(x, z)] !== FLOOR) grid[idx(x, z)] = Z.outside ? FENCE : WALL;
    }
  });
  // el cementerio tiene muro de ladrillo por el lado de la casa
  for (let z = 12; z <= 22; z++) grid[idx(13, z)] = WALL;
  for (let x = 13; x <= 24; x++) grid[idx(x, 12)] = WALL;
  for (const w of WINDOWS) { grid[idx(w.x, w.z)] = WIN; w.fence = w.zone === 3; }
  for (const d of DOORS) for (const [x, z] of d.cells) grid[idx(x, z)] = DOOR;
}
buildGrid();
export const cellAt = (x, z) => (x < 0 || z < 0 || x >= GW || z >= GH) ? VOID : grid[idx(x, z)];
// ¿puede el jugador / un zombi de dentro pisar esta casilla?
export function walkable(x, z) { const c = cellAt(x, z); if (c === FLOOR) return true; if (c === DOOR) return DOORS.some(d => d.open && d.cells.some(([a, b]) => a === x && b === z)); return false; }
export const zoneOpen = zi => ZONES[zi].open;

/* ---------- texturas ---------- */
function tex(w, h, draw, rep = [1, 1]) { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(...rep); t.anisotropy = 4; return t; }
const rnd = (a, b) => a + Math.random() * (b - a);
export const TEX = {
  brick: tex(256, 256, (c, w, h) => { c.fillStyle = '#5a4038'; c.fillRect(0, 0, w, h); for (let r = 0; r < 8; r++) for (let k = 0; k < 4; k++) { const x = k * 64 + (r % 2) * 32 - 32, y = r * 32; const v = rnd(.75, 1.05); c.fillStyle = `rgb(${150 * v | 0},${78 * v | 0},${60 * v | 0})`; c.fillRect(x + 2, y + 2, 60, 28); } c.fillStyle = 'rgba(0,0,0,.18)'; for (let i = 0; i < 300; i++) c.fillRect(rnd(0, w), rnd(0, h), 2, 2); }),
  plaster: tex(256, 256, (c, w, h) => { c.fillStyle = '#8f8270'; c.fillRect(0, 0, w, h); for (let i = 0; i < 900; i++) { c.fillStyle = `rgba(${Math.random() < .5 ? '0,0,0' : '255,255,255'},${rnd(.02, .08)})`; c.fillRect(rnd(0, w), rnd(0, h), rnd(2, 8), rnd(2, 8)); } c.fillStyle = 'rgba(60,30,20,.35)'; c.fillRect(0, h - 40, w, 40); }),
  wood: tex(256, 256, (c, w, h) => { for (let i = 0; i < 8; i++) { const v = rnd(.8, 1.05); c.fillStyle = `rgb(${120 * v | 0},${82 * v | 0},${52 * v | 0})`; c.fillRect(0, i * 32, w, 32); c.fillStyle = 'rgba(0,0,0,.35)'; c.fillRect(0, i * 32, w, 2); c.fillRect((i * 97) % w, i * 32, 2, 32); } for (let i = 0; i < 400; i++) { c.fillStyle = `rgba(0,0,0,${rnd(.03, .1)})`; c.fillRect(rnd(0, w), rnd(0, h), rnd(4, 20), 1); } }),
  dirt: tex(256, 256, (c, w, h) => { c.fillStyle = '#3d4a2c'; c.fillRect(0, 0, w, h); for (let i = 0; i < 1400; i++) { c.fillStyle = Math.random() < .5 ? `rgba(70,90,45,${rnd(.3, .7)})` : `rgba(60,45,30,${rnd(.3, .6)})`; c.beginPath(); c.arc(rnd(0, w), rnd(0, h), rnd(1, 4), 0, 7); c.fill(); } }),
  board: tex(128, 32, (c, w, h) => { c.fillStyle = '#8a6440'; c.fillRect(0, 0, w, h); c.fillStyle = 'rgba(0,0,0,.25)'; for (let i = 0; i < 6; i++) c.fillRect(0, rnd(0, h), w, 1); c.fillStyle = '#3a2a1a'; c.fillRect(6, h / 2 - 3, 6, 6); c.fillRect(w - 12, h / 2 - 3, 6, 6); }),
};

/* ---------- geometría del mapa ---------- */
export function buildLevel(scene) {
  const level = new THREE.Group(); scene.add(level);
  const wallGeos = { brick: [], plaster: [] }, floorGeos = { wood: [], dirt: [] };
  // caja con UV en metros (la textura no se estira con la altura)
  const box = (x, y, z, w, h, d) => { const g = new THREE.BoxGeometry(w, h, d), uv = g.attributes.uv, n = g.attributes.normal; for (let i = 0; i < uv.count; i++) { const ny = Math.abs(n.getY(i)), nx = Math.abs(n.getX(i)); uv.setXY(i, uv.getX(i) * (ny > .5 || nx > .5 ? d : w), uv.getY(i) * (ny > .5 ? d : h) + (ny > .5 ? 0 : (y - h / 2))); } g.translate(x, y, z); return g; };
  for (let z = 0; z < GH; z++) for (let x = 0; x < GW; x++) {
    const c = grid[idx(x, z)], cx = x + .5, cz = z + .5;
    if (c === WALL) wallGeos[x === 13 || z === 12 ? 'brick' : (x < 13 ? 'plaster' : 'brick')].push(box(cx, WALL_H / 2, cz, 1, WALL_H, 1));
    if (c === WIN && zoneOf[idx(x, z)] !== 3 && !WINDOWS.find(w => w.x === x && w.z === z).fence) { wallGeos.plaster.push(box(cx, .45, cz, 1, .9, 1)); wallGeos.plaster.push(box(cx, 2.35, cz, 1, .7, 1)); }
    if (c === FLOOR || c === DOOR || c === WIN || c === PROP) { const zi = zoneOf[idx(x, z)]; floorGeos[zi === 3 || (c === WIN && x > 13 && z > 12) ? 'dirt' : 'wood'].push((() => { const g = new THREE.PlaneGeometry(1, 1); g.rotateX(-Math.PI / 2); g.translate(cx, 0, cz); const p = g.attributes.position, uv = g.attributes.uv; for (let i = 0; i < p.count; i++) uv.setXY(i, p.getX(i), -p.getZ(i)); return g; })()); }
  }
  const wallMat = { brick: new THREE.MeshStandardMaterial({ map: TEX.brick, roughness: .95 }), plaster: new THREE.MeshStandardMaterial({ map: TEX.plaster, roughness: .95 }) };
  for (const k of ['brick', 'plaster']) if (wallGeos[k].length) { const m = new THREE.Mesh(mergeGeometries(wallGeos[k]), wallMat[k]); m.castShadow = m.receiveShadow = true; level.add(m); }
  TEX.wood.repeat.set(.5, .5); TEX.dirt.repeat.set(.5, .5); TEX.brick.repeat.set(1, 1); TEX.plaster.repeat.set(.5, .5);
  const fm = { wood: new THREE.MeshStandardMaterial({ map: TEX.wood, roughness: .85 }), dirt: new THREE.MeshStandardMaterial({ map: TEX.dirt, roughness: 1 }) };
  for (const k of ['wood', 'dirt']) if (floorGeos[k].length) { const m = new THREE.Mesh(mergeGeometries(floorGeos[k]), fm[k]); m.receiveShadow = true; level.add(m); }
  // suelo exterior grande (bosque oscuro)
  const outTex = TEX.dirt.clone(); outTex.needsUpdate = true; outTex.repeat.set(40, 40);
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), new THREE.MeshStandardMaterial({ map: outTex, color: 0x6a7060, roughness: 1 })); ground.rotation.x = -Math.PI / 2; ground.position.set(GW / 2, -.01, GH / 2); ground.receiveShadow = true; level.add(ground);
  // vigas del techo (sin techo, para ver desde arriba) y marcos de puertas
  const beamMat = new THREE.MeshStandardMaterial({ color: 0x4a3020, roughness: .9 });
  for (const Z of ZONES) if (!Z.outside) for (let x = Z.x0; x <= Z.x1 + 1; x += 3) { const b = new THREE.Mesh(new THREE.BoxGeometry(.18, .22, Z.z1 - Z.z0 + 3), beamMat); b.position.set(x, WALL_H - .1, (Z.z0 + Z.z1 + 1) / 2); level.add(b); }
  return level;
}
// tablones de una ventana (6), de abajo arriba; se quitan y se ponen de uno en uno
export function buildBoards(level, w) {
  const mat = new THREE.MeshStandardMaterial({ map: TEX.board, roughness: .9 });
  const horiz = w.x === 1 || w.x === 24;   // la ventana está en una pared que va a lo largo de z
  for (let i = 0; i < 6; i++) {
    const b = new THREE.Mesh(new THREE.BoxGeometry(horiz ? .08 : 1.05, .16, horiz ? 1.05 : .08), mat);
    const y = 1.0 + i * .2, rot = (i % 2 ? 1 : -1) * .12;
    b.position.set(w.x + .5 + (horiz ? (w.x === 1 ? .45 : -.45) : 0), y, w.z + .5 + (horiz ? 0 : (w.z === 1 ? .45 : -.45)));
    if (horiz) b.rotation.x = rot; else b.rotation.z = rot;
    b.castShadow = true; b.userData.home = b.position.clone(); b.userData.rot = b.rotation.clone(); level.add(b); w.meshes.push(b);
  }
}
// puertas: tablones/escombros que bloquean hasta comprarlas
export function buildDoor(level, d) {
  const g = new THREE.Group(), mat = new THREE.MeshStandardMaterial({ map: TEX.board, roughness: .9, color: 0xc8a070 });
  const xs = d.cells.map(c => c[0]), zs = d.cells.map(c => c[1]), cx = (Math.min(...xs) + Math.max(...xs) + 1) / 2, cz = (Math.min(...zs) + Math.max(...zs) + 1) / 2;
  for (let i = 0; i < 9; i++) { const b = new THREE.Mesh(new THREE.BoxGeometry(d.axis === 'z' ? 1.05 : .1, .22, d.axis === 'z' ? .1 : 1.05), mat); b.position.set(cx, .3 + i * .27, cz); if (d.axis === 'z') b.rotation.z = (i % 2 ? .15 : -.15); else b.rotation.x = (i % 2 ? .15 : -.15); b.castShadow = true; g.add(b); }
  level.add(g); d.mesh = g; d.center = new THREE.Vector3(cx, 1.2, cz);
}
