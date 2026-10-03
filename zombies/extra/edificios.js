// Edificios de la ciudad generados a medida de cada solar: fachadas PBR (ladrillo, hormigón, estuco),
// escaparates en la planta baja, ventanas con marco y cristal reflectante (algunas encendidas), cornisas y azotea con detalles.
import * as THREE from './lib/three.module.min.js';
import { mergeGeometries } from './lib/BufferGeometryUtils.js';
import { PBR } from './mapa.js';

const FACADES = ['brick', 'dbrick', 'cwall', 'stucco'];
const FLOOR0 = 4.2, FLOORH = 3.3;           // altura de la planta baja y de las demás
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _p = new THREE.Vector3(), _s = new THREE.Vector3(), _e = new THREE.Euler();

// caja con UV en metros, para que las texturas PBR salgan a su tamaño real en cualquier solar
function metric(g, w, h, d) {
  const uv = g.attributes.uv, n = g.attributes.normal;
  for (let i = 0; i < uv.count; i++) {
    const u = uv.getX(i), v = uv.getY(i);
    if (Math.abs(n.getY(i)) > .5) uv.setXY(i, u * w, v * d); else if (Math.abs(n.getX(i)) > .5) uv.setXY(i, u * d, v * h); else uv.setXY(i, u * w, v * h);
  }
  return g;
}
const box = (cx, cy, cz, w, h, d) => { const g = metric(new THREE.BoxGeometry(w, h, d), w, h, d); g.translate(cx, cy, cz); return g; };
function facadeMat(key) {
  const p = PBR[key];
  if (!p) return new THREE.MeshStandardMaterial({ color: 0x7a6a60, roughness: .9 });
  const set = t => { if (!t) return null; t = t.clone(); t.needsUpdate = true; t.repeat.set(1 / p.size, 1 / p.size); return t; };
  return new THREE.MeshStandardMaterial({ map: set(p.map), normalMap: set(p.normalMap), roughnessMap: set(p.roughnessMap), roughness: 1 });
}

export function buildBuildings(level, lots, rng) {
  const geos = {}; FACADES.forEach(k => geos[k] = []);
  const trim = [], roof = [], frames = [], panes = [], lit = [], doors = [], metal = [];
  const place = (list, x, y, z, ny, sx, sy, nx, nz) => {   // plano orientado hacia (nx, nz)
    _p.set(x + nx * .02, y, z + nz * .02); _q.setFromEuler(_e.set(0, Math.atan2(nx, nz), 0)); _s.set(sx, sy, 1);
    list.push(new THREE.Matrix4().compose(_p, _q, _s));
  };
  for (const b of lots) {
    const w = b.x1 - b.x0 + 1, d = b.z1 - b.z0 + 1, cx = (b.x0 + b.x1 + 1) / 2, cz = (b.z0 + b.z1 + 1) / 2;
    const big = w >= 4 && d >= 4, floors = big && rng() < .28 ? 9 + Math.floor(rng() * 6) : 3 + Math.floor(rng() * 5);
    const H = FLOOR0 + (floors - 1) * FLOORH, fk = FACADES[Math.floor(rng() * FACADES.length)];
    const W = w - .04, D = d - .04;
    // si es muy alto y ancho, la parte de arriba retranqueada (como los rascacielos)
    const tier = floors > 8 && W > 5 && D > 5, Hm = tier ? FLOOR0 + (Math.floor(floors * .6) - 1) * FLOORH : H;
    geos[fk].push(box(cx, Hm / 2, cz, W, Hm, D));
    if (tier) geos[FACADES[(FACADES.indexOf(fk) + 2) % 4]].push(box(cx, Hm + (H - Hm) / 2, cz, W - 2, H - Hm, D - 2));
    // cornisa bajo la planta primera y remate de azotea
    trim.push(box(cx, FLOOR0, cz, W + .25, .3, D + .25));
    trim.push(box(cx, Hm + .15, cz, W + .35, .35, D + .35));
    // ventanas, escaparates y puertas de cada fachada
    const faces = [[0, 1, W, D / 2, 'x'], [0, -1, W, D / 2, 'x'], [1, 0, D, W / 2, 'z'], [-1, 0, D, W / 2, 'z']];
    const tierInset = tier ? 1 : 0;
    for (const [nx, nz, len, off, ax] of faces) {
      const n = Math.max(1, Math.floor((len - .8) / 3)), step = len / n;
      for (let i = 0; i < n; i++) {
        const t = -len / 2 + step * (i + .5), px = cx + (ax === 'x' ? t : nx * off), pz = cz + (ax === 'x' ? nz * off : t);
        // planta baja: escaparate grande (y una puerta en el hueco central de las fachadas largas)
        if (n > 1 && i === Math.floor(n / 2) && rng() < .5) { place(doors, px, 1.15, pz, 0, 1.3, 2.3, nx, nz); }
        else { place(frames, px, 1.7, pz, 0, step * .82, 2.5, nx, nz); place(rng() < .08 ? lit : panes, px, 1.7, pz, 0, step * .82 - .2, 2.3, nx, nz); }
        for (let f = 1; f < floors; f++) {
          const y = FLOOR0 + (f - .5) * FLOORH + .15, onTier = tier && y > Hm;
          if (onTier) { // la parte retranqueada está 1 m más hacia dentro
            const o2 = off - tierInset, px2 = cx + (ax === 'x' ? t : nx * o2), pz2 = cz + (ax === 'x' ? nz * o2 : t);
            if (Math.abs(t) > (len - 2) / 2 - .6) continue;
            place(frames, px2, y, pz2, 0, 1.6, 1.95, nx, nz); place(rng() < .24 ? lit : panes, px2, y, pz2, 0, 1.4, 1.75, nx, nz); continue;
          }
          place(frames, px, y, pz, 0, 1.6, 1.95, nx, nz); place(rng() < .24 ? lit : panes, px, y, pz, 0, 1.4, 1.75, nx, nz);
        }
      }
    }
    // azotea: parapeto y equipos
    const ry = tier ? H : Hm, rw = tier ? W - 2 : W, rd = tier ? D - 2 : D;
    for (const [dx, dz, sx, sz] of [[0, rd / 2, rw, .2], [0, -rd / 2, rw, .2], [rw / 2, 0, .2, rd], [-rw / 2, 0, .2, rd]]) roof.push(box(cx + dx, ry + .45, cz + dz, sx, .9, sz));
    const units = 1 + Math.floor(rng() * 3);
    for (let i = 0; i < units; i++) metal.push(box(cx + (rng() - .5) * (rw - 1.5), ry + .5 + .45, cz + (rng() - .5) * (rd - 1.5), 1 + rng() * 1.2, .9 + rng() * .5, 1 + rng() * 1.2));
    if (rng() < .35) { const g = new THREE.CylinderGeometry(.8, .8, 1.8, 14); g.translate(cx + (rng() - .5) * (rw - 2), ry + 2, cz + (rng() - .5) * (rd - 2)); metal.push(g); }
  }
  const add = (geoList, mat, shadow = true) => { if (!geoList.length) return; const m = new THREE.Mesh(mergeGeometries(geoList), mat); m.castShadow = shadow; m.receiveShadow = true; level.add(m); return m; };
  for (const k of FACADES) add(geos[k], facadeMat(k));
  add(trim, facadeMat('cwall'));
  add(roof, facadeMat('cwall'));
  add(metal, new THREE.MeshStandardMaterial({ color: 0x6c7077, roughness: .55, metalness: .6 }));
  const inst = (list, mat, colors) => { if (!list.length) return; const m = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1), mat, list.length); list.forEach((x, i) => { m.setMatrixAt(i, x); if (colors) m.setColorAt(i, new THREE.Color(colors[Math.floor(rng() * colors.length)]).multiplyScalar(.4 + rng() * .4)); }); m.frustumCulled = false; level.add(m); };
  inst(frames, new THREE.MeshStandardMaterial({ color: 0x15171a, roughness: .5, metalness: .3 }));
  const env = level.parent && level.parent.environment;
  inst(panes, new THREE.MeshStandardMaterial({ color: 0x1a2c44, roughness: .06, metalness: .9, envMap: env, envMapIntensity: 2.2, polygonOffset: true, polygonOffsetFactor: -1 }));
  inst(lit, new THREE.MeshBasicMaterial({ color: 0xffffff, polygonOffset: true, polygonOffsetFactor: -1 }), [0xffd69a, 0xffc070, 0xcfe4ff, 0xffe9c0]);
  inst(doors, new THREE.MeshStandardMaterial({ color: 0x20262c, roughness: .6, metalness: .4 }));
}
