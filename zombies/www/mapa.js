// Mapas de Shrimp Zombies: rejilla de casillas de 1 m (x a la derecha, z hacia abajo en el plano).
// Leyenda de mapas.js:
//   ' ' fuera (por donde llegan los zombis) · '#' muro · '=' valla · 'w' ventana en muro · 'v' hueco en la valla
//   a-h suelo de una zona interior · A-H suelo de una zona al aire libre (a = zona de salida) · 1-9 puertas
//   Q J S T U K máquinas de ventajas · Z Pack-a-Punch · Y corriente · X sitios de la caja · g arma de pared (en un muro)
//   @ salida del jugador · o calabaza secreta · G tumba (salen zombis) · L adorno grande · p cajas
import * as THREE from './lib/three.module.min.js';
import { mergeGeometries } from './lib/BufferGeometryUtils.js';
import { MAPS } from './mapas.js';
export { MAPS };

export const WALL_H = 2.7;
export const VOID = 0, FLOOR = 1, WALL = 2, WIN = 3, DOOR = 4, OUT = 5, FENCE = 6, PROP = 7, BLD = 8;
export let GW = 1, GH = 1, grid = new Uint8Array(1), zoneOf = new Int8Array(1), ZONES = [], DOORS = [], WINDOWS = [], OBJ = {}, CFG = null, MAPID = '', ROWS = [];
export const chAt = (x, z) => (x < 0 || z < 0 || x >= GW || z >= GH) ? ' ' : ROWS[z][x];
export const idx = (x, z) => z * GW + x;
export const cellAt = (x, z) => (x < 0 || z < 0 || x >= GW || z >= GH) ? VOID : grid[idx(x, z)];
export function walkable(x, z) { const c = cellAt(x, z); if (c === FLOOR) return true; if (c === DOOR) return DOORS.some(d => d.open && d.cells.some(([a, b]) => a === x && b === z)); return false; }
const PERK_CH = { Q: 'revive', J: 'jugg', S: 'speed', T: 'dtap', U: 'stamin', K: 'mule' };
const N4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const isZone = ch => /[a-fA-F]/.test(ch) || ch === 'h';   // G (tumba), H (edificio) y g (arma de pared) no son zonas

export function loadMap(id) {
  CFG = MAPS[id]; MAPID = id; const rows = ROWS = CFG.rows;
  GH = rows.length; GW = rows[0].length; grid = new Uint8Array(GW * GH); zoneOf = new Int8Array(GW * GH).fill(-1);
  const ch = (x, z) => (x < 0 || z < 0 || x >= GW || z >= GH) ? ' ' : rows[z][x];
  // zonas, en orden alfabético (a = salida)
  const letters = [...new Set(rows.join('').split('').filter(isZone).map(c => c.toLowerCase()))].sort();
  ZONES = letters.map((l, i) => ({ id: l, name: CFG.zones[l] || l.toUpperCase(), outside: rows.join('').includes(l.toUpperCase()), open: i === 0, x0: 1e9, x1: -1, z0: 1e9, z1: -1 }));
  const zi = c => letters.indexOf(c.toLowerCase());
  const nearZone = (x, z) => { for (const [dx, dz] of [...N4, [1, 1], [1, -1], [-1, 1], [-1, -1]]) { const c = ch(x + dx, z + dz); if (isZone(c)) return zi(c); } return CFG.defaultZone ? zi(CFG.defaultZone) : -1; };
  OBJ = { spawn: [0, 0], perks: {}, pap: null, power: null, box: [], eggs: [], graves: [], props: [], wallbuys: [], buildings: [] };
  const doorCells = {}; WINDOWS = [];
  for (let z = 0; z < GH; z++) for (let x = 0; x < GW; x++) {
    const c = rows[z][x], i = idx(x, z);
    if (c === ' ') grid[i] = OUT;
    else if (c === '#') grid[i] = WALL;
    else if (c === '=') grid[i] = FENCE;
    else if (c === 'w' || c === 'v') grid[i] = WIN;
    else if (/[1-9]/.test(c)) { grid[i] = DOOR; (doorCells[c] = doorCells[c] || []).push([x, z]); }
    else if (c === 'g') { grid[i] = rows.join('').includes('H') ? BLD : WALL; OBJ.wallbuys.push({ x, z }); }
    else if (c === 'H') grid[i] = BLD;
    else if (c === '.' || c === ':') { grid[i] = FLOOR; zoneOf[i] = nearZone(x, z); }
    else if (isZone(c)) { grid[i] = FLOOR; zoneOf[i] = zi(c); }
    else { // objetos sobre el suelo
      const zn = nearZone(x, z); zoneOf[i] = zn; grid[i] = FLOOR;
      const o = { x, z, zone: zn };
      if (PERK_CH[c]) { OBJ.perks[PERK_CH[c]] = o; grid[i] = PROP; }
      else if (c === 'Z') { OBJ.pap = o; grid[i] = PROP; }
      else if (c === 'Y') { OBJ.power = o; grid[i] = PROP; }
      else if (c === 'X') OBJ.box.push(o);
      else if (c === '@') OBJ.spawn = [x + .5, z + .5];
      else if (c === 'o') OBJ.eggs.push(o);
      else if (c === 'G') OBJ.graves.push(o);
      else if ('Lptkl'.includes(c)) { o.kind = c; OBJ.props.push(o); grid[i] = PROP; }
    }
  }
  for (let z = 0; z < GH; z++) for (let x = 0; x < GW; x++) { const k = zoneOf[idx(x, z)]; if (k >= 0) { const Z = ZONES[k]; Z.x0 = Math.min(Z.x0, x); Z.x1 = Math.max(Z.x1, x); Z.z0 = Math.min(Z.z0, z); Z.z1 = Math.max(Z.z1, z); } }
  const seen = new Uint8Array(GW * GH);
  for (let z = 0; z < GH; z++) for (let x = 0; x < GW; x++) {
    if (grid[idx(x, z)] !== BLD || seen[idx(x, z)]) continue;
    let x1 = x; while (grid[idx(x1 + 1, z)] === BLD && !seen[idx(x1 + 1, z)]) x1++;
    let z1 = z; while (z1 + 1 < GH && [...Array(x1 - x + 1)].every((_, k) => grid[idx(x + k, z1 + 1)] === BLD && !seen[idx(x + k, z1 + 1)])) z1++;
    for (let zz = z; zz <= z1; zz++) for (let xx = x; xx <= x1; xx++) seen[idx(xx, zz)] = 1;
    OBJ.buildings.push({ x0: x, z0: z, x1, z1 });
  }
  // hacia dónde miran los objetos: hacia una casilla libre, con la espalda contra la pared si se puede
  const plain = (x, z) => cellAt(x, z) === FLOOR;
  const face = o => { let best = null; for (const [dx, dz] of N4) { if (!plain(o.x + dx, o.z + dz)) continue; const back = cellAt(o.x - dx, o.z - dz); const s = (back === WALL || back === FENCE || back === WIN) ? 2 : 1; if (!best || s > best.s) best = { d: [dx, dz], s }; } return best ? best.d : [0, 1]; };
  for (const o of [...Object.values(OBJ.perks), OBJ.pap, OBJ.power, ...OBJ.box]) if (o) o.face = face(o);
  // armas de pared: miran a la zona interior si hay dos lados
  OBJ.wallbuys.forEach((w, i) => { let f = null; for (const [dx, dz] of N4) { const c = ch(w.x + dx, w.z + dz); if (isZone(c) && (!f || c === c.toLowerCase())) f = [dx, dz]; } w.face = f || [0, 1]; w.gun = CFG.guns[i]; });
  // ventanas
  for (let z = 0; z < GH; z++) for (let x = 0; x < GW; x++) {
    const c = rows[z][x]; if (c !== 'w' && c !== 'v') continue;
    let out = null, inn = null; for (const [dx, dz] of N4) { const n = ch(x + dx, z + dz); if (n === ' ') { out = [x + dx, z + dz]; inn = [x - dx, z - dz]; } }
    WINDOWS.push({ x, z, out, inn, zone: zoneOf[idx(inn[0], inn[1])], fence: c === 'v', boards: 6, meshes: [] });
  }
  // puertas
  DOORS = Object.keys(doorCells).sort().map((k, n) => {
    const cells = doorCells[k], [x, z] = cells[0];
    const zs = [...new Set(N4.map(([dx, dz]) => ch(x + dx, z + dz)).filter(isZone).map(zi))];
    const axis = isZone(ch(x, z - 1)) || isZone(ch(x, z + 1)) ? 'z' : 'x';
    return { id: n, cost: CFG.doors[n] || 1000, cells, zones: zs, open: false, axis };
  });
}
loadMap('nacht');

/* ---------- texturas ---------- */
function tex(w, h, draw) { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = 4; return t; }
const rnd = (a, b) => a + Math.random() * (b - a);
const speckle = (c, w, h, n, a = .08) => { for (let i = 0; i < n; i++) { c.fillStyle = `rgba(${Math.random() < .5 ? '0,0,0' : '255,255,255'},${rnd(.02, a)})`; c.fillRect(rnd(0, w), rnd(0, h), rnd(2, 8), rnd(2, 8)); } };
export const TEX = {
  brick: tex(256, 256, (c, w, h) => { c.fillStyle = '#5a4038'; c.fillRect(0, 0, w, h); for (let r = 0; r < 8; r++) for (let k = 0; k < 5; k++) { const x = k * 64 + (r % 2) * 32 - 32, y = r * 32; const v = rnd(.75, 1.05); c.fillStyle = `rgb(${150 * v | 0},${78 * v | 0},${60 * v | 0})`; c.fillRect(x + 2, y + 2, 60, 28); } c.fillStyle = 'rgba(0,0,0,.18)'; for (let i = 0; i < 300; i++) c.fillRect(rnd(0, w), rnd(0, h), 2, 2); }),
  plaster: tex(256, 256, (c, w, h) => { c.fillStyle = '#8f8270'; c.fillRect(0, 0, w, h); speckle(c, w, h, 900); c.fillStyle = 'rgba(60,30,20,.35)'; c.fillRect(0, h - 40, w, 40); }),
  metal: tex(256, 256, (c, w, h) => { c.fillStyle = '#6a737c'; c.fillRect(0, 0, w, h); for (let x = 0; x < w; x += 16) { c.fillStyle = 'rgba(255,255,255,.1)'; c.fillRect(x, 0, 6, h); c.fillStyle = 'rgba(0,0,0,.18)'; c.fillRect(x + 10, 0, 4, h); } for (let i = 0; i < 40; i++) { c.fillStyle = `rgba(120,60,20,${rnd(.1, .3)})`; c.beginPath(); c.ellipse(rnd(0, w), rnd(0, h), rnd(4, 20), rnd(8, 40), 0, 0, 7); c.fill(); } c.fillStyle = '#c8a020'; for (let x = 0; x < w; x += 32) c.fillRect(x, h - 26, 16, 20); c.fillStyle = '#222'; for (let x = 16; x < w; x += 32) c.fillRect(x, h - 26, 16, 20); }),
  planks: tex(256, 256, (c, w, h) => { for (let i = 0; i < 8; i++) { const v = rnd(.8, 1.05); c.fillStyle = `rgb(${130 * v | 0},${96 * v | 0},${62 * v | 0})`; c.fillRect(0, i * 32, w, 32); c.fillStyle = 'rgba(0,0,0,.4)'; c.fillRect(0, i * 32, w, 3); c.fillStyle = '#2a1a10'; c.fillRect(10, i * 32 + 14, 5, 5); c.fillRect(w - 16, i * 32 + 14, 5, 5); } speckle(c, w, h, 300, .06); }),
  wood: tex(256, 256, (c, w, h) => { for (let i = 0; i < 8; i++) { const v = rnd(.8, 1.05); c.fillStyle = `rgb(${120 * v | 0},${82 * v | 0},${52 * v | 0})`; c.fillRect(0, i * 32, w, 32); c.fillStyle = 'rgba(0,0,0,.35)'; c.fillRect(0, i * 32, w, 2); c.fillRect((i * 97) % w, i * 32, 2, 32); } for (let i = 0; i < 400; i++) { c.fillStyle = `rgba(0,0,0,${rnd(.03, .1)})`; c.fillRect(rnd(0, w), rnd(0, h), rnd(4, 20), 1); } }),
  woodLight: tex(256, 256, (c, w, h) => { for (let i = 0; i < 8; i++) { const v = rnd(.85, 1.05); c.fillStyle = `rgb(${190 * v | 0},${150 * v | 0},${100 * v | 0})`; c.fillRect(i * 32, 0, 32, h); c.fillStyle = 'rgba(0,0,0,.3)'; c.fillRect(i * 32, 0, 2, h); } speckle(c, w, h, 300, .06); }),
  concrete: tex(256, 256, (c, w, h) => { c.fillStyle = '#7a7a76'; c.fillRect(0, 0, w, h); speckle(c, w, h, 1500, .07); c.strokeStyle = 'rgba(0,0,0,.35)'; c.lineWidth = 2; c.strokeRect(1, 1, w - 2, h - 2); c.strokeStyle = 'rgba(0,0,0,.25)'; c.beginPath(); c.moveTo(40, 30); c.lineTo(90, 70); c.lineTo(85, 120); c.stroke(); }),
  dirt: tex(256, 256, (c, w, h) => { c.fillStyle = '#3d4a2c'; c.fillRect(0, 0, w, h); for (let i = 0; i < 1400; i++) { c.fillStyle = Math.random() < .5 ? `rgba(70,90,45,${rnd(.3, .7)})` : `rgba(60,45,30,${rnd(.3, .6)})`; c.beginPath(); c.arc(rnd(0, w), rnd(0, h), rnd(1, 4), 0, 7); c.fill(); } }),
  asphalt: tex(256, 256, (c, w, h) => { c.fillStyle = '#3a3c40'; c.fillRect(0, 0, w, h); for (let i = 0; i < 2500; i++) { c.fillStyle = `rgba(${Math.random() < .5 ? '0,0,0' : '200,200,200'},${rnd(.05, .2)})`; c.fillRect(rnd(0, w), rnd(0, h), 2, 2); } }),
  sand: tex(256, 256, (c, w, h) => { c.fillStyle = '#c8b080'; c.fillRect(0, 0, w, h); for (let i = 0; i < 3000; i++) { const v = rnd(.75, 1.1); c.fillStyle = `rgba(${200 * v | 0},${172 * v | 0},${120 * v | 0},.7)`; c.fillRect(rnd(0, w), rnd(0, h), 2, 2); } }),
  tiles: tex(256, 256, (c, w, h) => { c.fillStyle = '#8a8680'; c.fillRect(0, 0, w, h); for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { const v = rnd(.85, 1.05); c.fillStyle = `rgb(${150 * v | 0},${146 * v | 0},${138 * v | 0})`; c.fillRect(x * 64 + 2, y * 64 + 2, 60, 60); } speckle(c, w, h, 500, .06); }),
  grass: tex(256, 256, (c, w, h) => { c.fillStyle = '#2f5a24'; c.fillRect(0, 0, w, h); for (let i = 0; i < 4000; i++) { const v = rnd(.7, 1.3); c.fillStyle = `rgba(${60 * v | 0},${110 * v | 0},${40 * v | 0},.7)`; c.fillRect(rnd(0, w), rnd(0, h), 1.5, rnd(2, 5)); } }),
  board: tex(128, 32, (c, w, h) => { c.fillStyle = '#8a6440'; c.fillRect(0, 0, w, h); c.fillStyle = 'rgba(0,0,0,.25)'; for (let i = 0; i < 6; i++) c.fillRect(0, rnd(0, h), w, 1); c.fillStyle = '#3a2a1a'; c.fillRect(6, h / 2 - 3, 6, 6); c.fillRect(w - 12, h / 2 - 3, 6, 6); }),
};
// temas visuales de cada mapa
export const THEMES = {
  nacht: { wall: 'plaster', wall2: 'brick', floor: 'wood', ground: 'dirt', ext: 'dirt', extCol: 0x6a7060, sky: 0x0b1020, lamp: 0xffc27a, fence: 0x6a6a78, trees: ['pine', 'pine-crooked'] },
  fabrica: { wall: 'metal', wall2: 'brick', floor: 'concrete', ground: 'asphalt', ext: 'asphalt', extCol: 0x9a9a9a, sky: 0x10141c, lamp: 0xd8e8ff, fence: 0x8a8a90, trees: ['pine'] },
  ciudad: { wall: 'brick', wall2: 'brick', floor: 'tiles', ground: 'asphalt', ext: 'asphalt', extCol: 0x6a6a6e, sky: 0x101826, lamp: 0xffe0a0, fence: 0xd8a020, trees: [], city: true },
  isla: { wall: 'planks', wall2: 'planks', floor: 'woodLight', ground: 'sand', ext: 'sand', extCol: 0xb8a070, sky: 0x0a1830, lamp: 0xffa04a, fence: 0x8a5a32, trees: ['palm-bend', 'palm-straight'], sea: true },
};
export const theme = () => THEMES[CFG.theme];

/* ---------- geometría del mapa ---------- */
export function buildLevel(scene) {
  const T = theme(), level = new THREE.Group(); scene.add(level);
  const wallGeos = { a: [], b: [] }, floorGeos = { in: [], out: [], side: [], grass: [] };
  const box = (x, y, z, w, h, d) => { const g = new THREE.BoxGeometry(w, h, d), uv = g.attributes.uv, n = g.attributes.normal; for (let i = 0; i < uv.count; i++) { const ny = Math.abs(n.getY(i)), nx = Math.abs(n.getX(i)); uv.setXY(i, uv.getX(i) * (ny > .5 || nx > .5 ? d : w), uv.getY(i) * (ny > .5 ? d : h) + (ny > .5 ? 0 : (y - h / 2))); } g.translate(x, y, z); return g; };
  const outdoorCell = (x, z) => { const k = zoneOf[idx(x, z)]; return k >= 0 && ZONES[k].outside; };
  for (let z = 0; z < GH; z++) for (let x = 0; x < GW; x++) {
    const c = grid[idx(x, z)], cx = x + .5, cz = z + .5;
    if (c === WALL) { let ext = false; for (const [dx, dz] of N4) if (cellAt(x + dx, z + dz) === OUT) ext = true; wallGeos[ext ? 'b' : 'a'].push(box(cx, WALL_H / 2, cz, 1, WALL_H, 1)); }
    if (c === WIN) { const w = WINDOWS.find(w => w.x === x && w.z === z); if (!w.fence) { wallGeos.b.push(box(cx, .45, cz, 1, .9, 1)); wallGeos.b.push(box(cx, 2.35, cz, 1, .7, 1)); } }
    if (c === FLOOR || c === DOOR || c === WIN || c === PROP) {
      let out = outdoorCell(x, z); if (c === WIN) { const w = WINDOWS.find(w => w.x === x && w.z === z); out = !!(ZONES[w.zone] && ZONES[w.zone].outside); }
      if (c === DOOR) out = false;
      let rc = chAt(x, z);
      if (!'.:t'.includes(rc) && !isZone(rc)) { const cnt = {}; for (const [dx, dz] of [...N4, [1, 1], [-1, -1], [1, -1], [-1, 1]]) { const n = chAt(x + dx, z + dz); cnt[n] = (cnt[n] || 0) + 1; } rc = (cnt['.'] || 0) >= 2 ? '.' : (cnt[':'] || 0) >= 2 ? ':' : rc; }
      const kind = rc === '.' ? 'side' : (rc === ':' || rc === 't') ? 'grass' : out ? 'out' : 'in';
      const g = new THREE.PlaneGeometry(1, 1); g.rotateX(-Math.PI / 2); g.translate(cx, kind === 'side' ? .06 : 0, cz); const p = g.attributes.position, uv = g.attributes.uv; for (let i = 0; i < p.count; i++) uv.setXY(i, p.getX(i), -p.getZ(i)); floorGeos[kind].push(g);
    }
  }
  const mat = (t, rep, extra = {}) => { const tx = TEX[t].clone(); tx.needsUpdate = true; tx.repeat.set(rep, rep); return new THREE.MeshStandardMaterial({ map: tx, roughness: .92, ...extra }); };
  const wm = { a: mat(T.wall, T.wall === 'brick' ? 1 : .5), b: mat(T.wall2, T.wall2 === 'brick' ? 1 : .5) };
  if (T.wall === 'metal') { wm.a.metalness = .35; wm.a.roughness = .6; }
  for (const k of ['a', 'b']) if (wallGeos[k].length) { const m = new THREE.Mesh(mergeGeometries(wallGeos[k]), wm[k]); m.castShadow = m.receiveShadow = true; level.add(m); }
  const fm = { in: mat(T.floor, .5, { roughness: .85 }), out: mat(T.ground, .5, { roughness: 1 }), side: mat('tiles', .5, { roughness: .9 }), grass: mat('grass', .5, { roughness: 1 }) };
  for (const k of ['in', 'out', 'side', 'grass']) if (floorGeos[k].length) { const m = new THREE.Mesh(mergeGeometries(floorGeos[k]), fm[k]); m.receiveShadow = true; level.add(m); }
  // suelo de fuera
  const ext = mat(T.ext, 40); ext.color.set(T.extCol);
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(GW + 60, GH + 60), ext); ground.rotation.x = -Math.PI / 2; ground.position.set(GW / 2, -.01, GH / 2); ground.receiveShadow = true; level.add(ground);
  if (T.sea) { const sea = new THREE.Mesh(new THREE.RingGeometry(Math.max(GW, GH) * .75, 140, 64), new THREE.MeshStandardMaterial({ color: 0x0a3a5a, roughness: .2, metalness: .3 })); sea.rotation.x = -Math.PI / 2; sea.position.set(GW / 2, .02, GH / 2); level.add(sea); }
  // vigas del techo en las zonas interiores
  const beamMat = new THREE.MeshStandardMaterial({ color: T.wall === 'metal' ? 0x3a4048 : 0x4a3020, roughness: .9, metalness: T.wall === 'metal' ? .4 : 0 });
  for (const Z of ZONES) if (!Z.outside && Z.x1 >= 0) for (let x = Z.x0; x <= Z.x1 + 1; x += 3) { const b = new THREE.Mesh(new THREE.BoxGeometry(.18, .22, Z.z1 - Z.z0 + 3), beamMat); b.position.set(x, WALL_H - .1, (Z.z0 + Z.z1 + 1) / 2); level.add(b); }
  return level;
}
// tablones de una ventana (6), de abajo arriba; se quitan y se ponen de uno en uno
export function buildBoards(level, w) {
  const mat = new THREE.MeshStandardMaterial({ map: TEX.board, roughness: .9 });
  const dx = w.inn[0] - w.x, dz = w.inn[1] - w.z, alongZ = dx !== 0;
  w.meshes = [];
  for (let i = 0; i < 6; i++) {
    const b = new THREE.Mesh(new THREE.BoxGeometry(alongZ ? .08 : 1.05, .16, alongZ ? 1.05 : .08), mat);
    const y = 1.0 + i * .2, rot = (i % 2 ? 1 : -1) * .12;
    b.position.set(w.x + .5 + dx * .45, y, w.z + .5 + dz * .45);
    if (alongZ) b.rotation.x = rot; else b.rotation.z = rot;
    b.castShadow = true; b.userData.home = b.position.clone(); b.userData.rot = b.rotation.clone(); level.add(b); w.meshes.push(b);
  }
}
// puertas: tablones que bloquean hasta comprarlas
export function buildDoor(level, d) {
  const g = new THREE.Group(), mat = new THREE.MeshStandardMaterial({ map: TEX.board, roughness: .9, color: 0xc8a070 });
  const [x, z] = d.cells[0], cx = x + .5, cz = z + .5;
  for (let i = 0; i < 9; i++) { const b = new THREE.Mesh(new THREE.BoxGeometry(d.axis === 'z' ? 1.05 : .1, .22, d.axis === 'z' ? .1 : 1.05), mat); b.position.set(cx, .3 + i * .27, cz); if (d.axis === 'z') b.rotation.z = (i % 2 ? .15 : -.15); else b.rotation.x = (i % 2 ? .15 : -.15); b.castShadow = true; g.add(b); }
  level.add(g); d.mesh = g; d.center = new THREE.Vector3(cx, 1.2, cz);
}
