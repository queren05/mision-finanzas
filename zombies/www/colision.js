// Colisiones con la forma real de cada objeto (no con la casilla entera):
// círculos para postes, troncos y bidones; cajas orientadas para máquinas, coches, cajas y muebles.
// La rejilla sigue sirviendo para muros y para que los zombis busquen camino.
import * as THREE from './lib/three.module.min.js';

const CELL = 2;                      // rejilla de búsqueda rápida (m)
let SHAPES = [], HASH = new Map();
const key = (x, z) => x * 73856093 ^ z * 19349663;
export function clearObstacles() { SHAPES = []; HASH = new Map(); }
export const obstacles = () => SHAPES;

function index(s) {
  const r = s.type === 'c' ? s.r : Math.hypot(s.hx, s.hz);
  for (let x = Math.floor((s.x - r) / CELL); x <= Math.floor((s.x + r) / CELL); x++)
    for (let z = Math.floor((s.z - r) / CELL); z <= Math.floor((s.z + r) / CELL); z++) {
      const k = key(x, z); let l = HASH.get(k); if (!l) HASH.set(k, l = []); l.push(s);
    }
}
export function addCircle(x, z, r, y0 = 0, y1 = 3) { const s = { type: 'c', x, z, r, y0, y1 }; SHAPES.push(s); index(s); return s; }
export function addBox(x, z, hx, hz, rot = 0, y0 = 0, y1 = 3) { const s = { type: 'b', x, z, hx, hz, c: Math.cos(rot), s: Math.sin(rot), y0, y1 }; SHAPES.push(s); index(s); return s; }

// caja orientada a partir de la geometría real de un objeto (en su propio giro), recortada a lo que llega al suelo
const _b = new THREE.Box3(), _v = new THREE.Vector3(), _m = new THREE.Matrix4();
export function addFromObject(o, opt = {}) {
  o.updateMatrixWorld(true);
  const ry = o.rotation.y, inv = _m.makeRotationY(-ry); _b.makeEmpty();
  o.traverse(m => {
    if (!m.isMesh || !m.geometry.attributes.position) return;
    const p = m.geometry.attributes.position, st = Math.max(1, Math.floor(p.count / 3000));
    for (let i = 0; i < p.count; i += st) { _v.fromBufferAttribute(p, i).applyMatrix4(m.matrixWorld); _v.x -= o.position.x; _v.z -= o.position.z; _v.applyMatrix4(inv); _b.expandByPoint(_v); }
  });
  if (_b.isEmpty()) return null;
  const y0 = _b.min.y, y1 = _b.max.y; if (y1 - y0 < (opt.minH ?? .22)) return null;   // lo muy bajito se pisa
  const sh = opt.shrink ?? .92, hx = (_b.max.x - _b.min.x) / 2 * sh, hz = (_b.max.z - _b.min.z) / 2 * sh;
  if (opt.maxHalf && Math.max(hx, hz) > opt.maxHalf) return null;   // no es un objeto suelto (escenario entero, suelo...)
  const cl = (_b.min.x + _b.max.x) / 2, cz = (_b.min.z + _b.max.z) / 2, c = Math.cos(ry), s = Math.sin(ry);
  const wx = o.position.x + cl * c + cz * s, wz = o.position.z - cl * s + cz * c;
  if (opt.circle || (Math.abs(hx - hz) < .12 && Math.max(hx, hz) < .45)) return addCircle(wx, wz, opt.r ?? Math.max(hx, hz), y0, y1);
  return addBox(wx, wz, hx, hz, ry, y0, y1);
}

// empuja un círculo (jugador o zombi) fuera de los obstáculos que tocan su altura
export function resolve(p, r, y = 0, h = 1.6) {
  const x0 = Math.floor((p.x - r) / CELL), x1 = Math.floor((p.x + r) / CELL), z0 = Math.floor((p.z - r) / CELL), z1 = Math.floor((p.z + r) / CELL);
  let hit = false;
  for (let gx = x0; gx <= x1; gx++) for (let gz = z0; gz <= z1; gz++) {
    const l = HASH.get(key(gx, gz)); if (!l) continue;
    for (const s of l) {
      if (s.y1 <= y + .3 || s.y0 >= y + h) continue;   // por encima de la cabeza o lo bastante bajo para subirse
      if (s.type === 'c') {
        const dx = p.x - s.x, dz = p.z - s.z, d = Math.hypot(dx, dz), m = s.r + r;
        if (d < m) { hit = true; if (d < 1e-5) { p.x += m; continue; } p.x = s.x + dx / d * m; p.z = s.z + dz / d * m; }
      } else {
        // a coordenadas de la caja
        const dx = p.x - s.x, dz = p.z - s.z, lx = dx * s.c - dz * s.s, lz = dx * s.s + dz * s.c;
        const qx = Math.max(-s.hx, Math.min(s.hx, lx)), qz = Math.max(-s.hz, Math.min(s.hz, lz));
        let ex = lx - qx, ez = lz - qz, d = Math.hypot(ex, ez), nx, nz;
        if (d >= r) continue; hit = true;
        if (d > 1e-5) { nx = qx + ex / d * r; nz = qz + ez / d * r; }
        else { const px = s.hx - Math.abs(lx), pz = s.hz - Math.abs(lz); if (px < pz) { nx = Math.sign(lx || 1) * (s.hx + r); nz = lz; } else { nx = lx; nz = Math.sign(lz || 1) * (s.hz + r); } }
        p.x = s.x + nx * s.c + nz * s.s; p.z = s.z - nx * s.s + nz * s.c;
      }
    }
  }
  return hit;
}
// ¿un punto está dentro de algún obstáculo? (para disparos y para cámaras)
export function inside(x, y, z, pad = 0) {
  const l = HASH.get(key(Math.floor(x / CELL), Math.floor(z / CELL))); if (!l) return false;
  for (const s of l) {
    if (y < s.y0 || y > s.y1) continue;
    if (s.type === 'c') { if (Math.hypot(x - s.x, z - s.z) < s.r + pad) return true; }
    else { const dx = x - s.x, dz = z - s.z, lx = dx * s.c - dz * s.s, lz = dx * s.s + dz * s.c; if (Math.abs(lx) < s.hx + pad && Math.abs(lz) < s.hz + pad) return true; }
  }
  return false;
}
// casillas que un obstáculo ocupa casi por completo: no sirven para buscar camino
export function blocksCell(x, z) { return inside(x + .5, .8, z + .5, .12); }
