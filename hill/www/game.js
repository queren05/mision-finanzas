// Shrimp Hill Climb: carreras cuesta arriba (estilo Hill Climb Racing) con la gamba al volante.
// Física 2D: el coche es un cuerpo rígido con dos ruedas sobre muelles; el suelo es una función h(x) por escenario.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import * as M from './modelos.js';
import { Particles, Floaters } from './particulas.js';
import * as SND from './sonido.js';
import { STAGES, CARS, UPG, MAXLV, upCost, checkpoint, cpBonus, MISSION_TYPES, missionReward } from './datos.js';

const Q = new URLSearchParams(location.search);
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const rnd = (a, b) => a + Math.random() * (b - a), clamp = (v, a, b) => Math.max(a, Math.min(b, v)), lerp = (a, b, t) => a + (b - a) * t;
const S = SND.S, buzz = SND.buzz, V = (x, y, z) => new THREE.Vector3(x, y, z), col = h => new THREE.Color(h);
const fmt = n => n >= 1e6 ? (n / 1e6).toFixed(1).replace('.', ',') + 'M' : n >= 1e4 ? Math.round(n / 1000) + 'K' : String(Math.floor(n));

/* ---------- guardado (v2: la economía cambió, se empieza de cero) ---------- */
const K = 'hill2.';
const get = (k, d) => { try { const v = JSON.parse(localStorage.getItem(K + k)); return v ?? d; } catch (e) { return d; } };
const DEF = { coins: 0, best: {}, owned: { abuelo: true, campo: true }, lv: {}, sel: { car: 'abuelo', stage: 'campo' }, opt: { sfx: true, music: true, haptic: true }, daily: { last: '', streak: 0 }, mis: [], mdone: 0, total: 0, cps: {} };
const save = {}; for (const k of Object.keys(DEF)) save[k] = get(k, DEF[k]);
for (const k of ['best', 'owned', 'sel', 'opt', 'daily', 'cps']) save[k] = Object.assign({}, DEF[k], save[k]);
const persist = () => { for (const k of Object.keys(DEF)) try { localStorage.setItem(K + k, JSON.stringify(save[k])); } catch (e) { } };
Object.assign(SND.cfg, save.opt);
const best = id => save.best[id] || 0;

let ST = STAGES[0];
const hgt = x => ST.hgt(x), slope = x => (hgt(x + .05) - hgt(x - .05)) / .1;
const lvOf = (car, u) => (save.lv[car] || {})[u] || 0;
function stats(id) {
  const c = CARS.find(x => x.id === id) || CARS[0], L = u => lvOf(id, u);
  return { ...c, engine: c.engine * (1 + .085 * L('motor')), vmax: c.vmax * (1 + .05 * L('motor')), mu: c.mu * (1 + .055 * L('agarre')), c: c.c * (1 + .09 * L('susp')), k: c.k * (1 + .03 * L('susp')), air: c.air * (1 + .07 * L('susp')), tank: c.tank * (1 + .14 * L('tanque')), cons: c.cons * (1 - .035 * L('tanque')) };
}

/* ---------- misiones ---------- */
function newMission() {
  const n = save.mdone, owned = STAGES.filter(s => save.owned[s.id]);
  let type; do { type = MISSION_TYPES[Math.floor(Math.random() * MISSION_TYPES.length)]; } while (save.mis.some(m => m.t === type.t) && save.mis.length < MISSION_TYPES.length);
  const st = owned[Math.floor(Math.random() * owned.length)], m = type.make(n, st);
  return { t: type.t, goal: m.goal, stage: st.id, text: m.text(m.goal), prog: 0, base: save.total, reward: missionReward(n) };
}
while (save.mis.length < 3) save.mis.push(newMission());

/* ---------- motor 3D ---------- */
const cv = $('#cv');
const R = new THREE.WebGLRenderer({ canvas: cv, antialias: true, preserveDrawingBuffer: Q.has('shot') });
R.outputColorSpace = THREE.SRGBColorSpace;
const scene = new THREE.Scene();
const cam = new THREE.PerspectiveCamera(50, 1, .1, 400);
const hemi = new THREE.HemisphereLight(0xffffff, 0x887766, 1.8); scene.add(hemi);
const sun = new THREE.DirectionalLight(0xfff2dc, 2); sun.position.set(-3, 6, 8); scene.add(sun);
let camDist = 12;
function resize() {
  const w = innerWidth, h = innerHeight, a = w / h; R.setPixelRatio(Math.min(devicePixelRatio || 1, 2)); R.setSize(w, h, false);
  cam.aspect = a; cam.updateProjectionMatrix();
  const tanH = Math.tan(THREE.MathUtils.degToRad(cam.fov) / 2) * a; camDist = clamp(5 / tanH, 9, 22);
  if (PN) { PN.setPixelRatio(R.getPixelRatio()); PA.setPixelRatio(R.getPixelRatio()); }
}
addEventListener('resize', resize);
let PN = null, PA = null, FL = null, A = {}, player = null;
const loader = new GLTFLoader(), carGltf = {}, KIT = {};
const loadCar = file => carGltf[file] ? Promise.resolve(carGltf[file]) : new Promise((ok, ko) => loader.load('models/car/' + file + '.glb', g => ok(carGltf[file] = g), undefined, ko));

/* ---------- decorado por escenario ---------- */
let world = null, skyMesh = null, far = null, chunks = [], chunkX = -30, items = [], nextCoin = 12, nextFuel = 100, nextBig = 60, nextGem = 220, fuelN = 0, lava = null, water = null;
function skyTex(c) { return M.canvasTex(4, 256, (x, w, h) => { const g = x.createLinearGradient(0, 0, 0, h); g.addColorStop(0, c[0]); g.addColorStop(.65, c[1]); g.addColorStop(1, c[2]); x.fillStyle = g; x.fillRect(0, 0, w, h); }, false); }
const basic = c => new THREE.MeshBasicMaterial({ color: c });
function farLayer(make, n, spacing, k, y, z) { for (let i = 0; i < n; i++) { const m = make(i); m.position.set(i * spacing - 60, m.position.y + y, z); m.userData.k = k; far.add(m); } }
function buildWorld() {
  if (world) scene.remove(world);
  world = new THREE.Group(); scene.add(world); chunks = []; chunkX = -30; items = []; nextCoin = 12; nextFuel = 100; fuelN = 0; nextBig = 60; nextGem = 220; lava = water = null;
  scene.background = new THREE.Color(ST.sky[1]); scene.fog = null;
  skyMesh = new THREE.Mesh(new THREE.PlaneGeometry(200, 90), new THREE.MeshBasicMaterial({ map: skyTex(ST.sky), depthWrite: false, fog: false })); skyMesh.position.z = -40; world.add(skyMesh);
  far = new THREE.Group(); world.add(far);
  const [f1, f2] = ST.far.map(c => basic(c)), d = ST.deco;
  hemi.color.set(0xffffff); hemi.groundColor.set(0x887766); hemi.intensity = 1.8; sun.intensity = 2; sun.color.set(0xfff2dc);
  const hills = (rad, hmin, hmax, seg) => farLayer(i => { const h = rnd(hmin, hmax), m = new THREE.Mesh(new THREE.ConeGeometry(rnd(rad[0], rad[1]), h, seg), i % 2 ? f1 : f2); m.position.y = h / 2 - 4; return m; }, 10, 14, .35, 0, -30);
  const clouds = (c = 0xffffff) => farLayer(() => { const g = new THREE.Group(), w = basic(c); for (let k = 0; k < 4; k++) { const s = new THREE.Mesh(new THREE.SphereGeometry(rnd(1, 1.8), 12, 8), w); s.position.set(k * 1.4, Math.sin(k) * .5, 0); g.add(s); } g.position.y = rnd(9, 15); return g; }, 6, 22, .15, 0, -34);
  const stars = n => { const pos = new Float32Array(n * 3); for (let i = 0; i < n; i++) pos.set([rnd(-100, 100), rnd(-5, 40), -38], i * 3); const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(pos, 3)); const s = new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: .25 })); s.userData.k = .05; far.add(s); };
  if (d === 'campo' || d === 'bosque') { hills([7, 12], 6, 13, d === 'bosque' ? 4 : 6); clouds(); }
  else if (d === 'desierto') { farLayer(i => { const m = new THREE.Mesh(new THREE.SphereGeometry(rnd(9, 15), 16, 8, 0, Math.PI * 2, 0, Math.PI / 2), i % 2 ? f1 : f2); m.scale.y = .35; m.position.y = -4; return m; }, 10, 15, .35, 0, -30); const sunM = new THREE.Mesh(new THREE.CircleGeometry(3, 32), basic(0xfff2a0)); sunM.position.set(10, 14, -37); sunM.userData.k = .05; far.add(sunM); sun.color.set(0xffe0b0); }
  else if (d === 'playa') { const sea = new THREE.Mesh(new THREE.PlaneGeometry(300, 12), f1); sea.position.set(0, -2, -32); sea.userData.k = .3; far.add(sea); clouds(); }
  else if (d === 'artico') { farLayer(i => { const h = rnd(6, 14), m = new THREE.Mesh(new THREE.ConeGeometry(rnd(5, 9), h, 4), i % 2 ? f1 : f2); m.position.y = h / 2 - 4; m.rotation.y = rnd(0, 1); return m; }, 10, 14, .35, 0, -30); clouds(0xf4fbff); hemi.groundColor.set(0x8ab0d0); }
  else if (d === 'fondo') { hills([7, 12], 5, 10, 7); scene.fog = new THREE.Fog(0x1a6aa8, 14, 60); hemi.color.set(0xbfe8ff); hemi.groundColor.set(0x1a4a6a); sun.color.set(0xa8e0ff);
    farLayer(() => { const g = new THREE.Group(); for (let k = 0; k < 3; k++) { const r = new THREE.Mesh(new THREE.PlaneGeometry(rnd(1, 2.5), 40), new THREE.MeshBasicMaterial({ color: 0xcff6ff, transparent: true, opacity: .08, depthWrite: false, fog: false })); r.rotation.z = .25; r.position.x = k * 4; g.add(r); } g.position.y = 10; return g; }, 6, 20, .2, 0, -20); }
  else if (d === 'volcan') { farLayer(i => { const h = rnd(10, 18), m = new THREE.Mesh(new THREE.ConeGeometry(rnd(9, 13), h, 7, 1, true), i % 2 ? f1 : f2); m.position.y = h / 2 - 4; return m; }, 8, 18, .35, 0, -30); hemi.color.set(0xffb08a); hemi.groundColor.set(0x3a1010); sun.color.set(0xff9a6a); scene.fog = new THREE.Fog(0x7a2010, 25, 80);
    lava = new THREE.Mesh(new THREE.PlaneGeometry(120, 3), new THREE.MeshBasicMaterial({ color: 0xff5a1a })); lava.rotation.x = -Math.PI / 2; lava.userData.glow = true; world.add(lava); }
  else if (d === 'ciudad') { farLayer(i => { const h = rnd(6, 20), m = new THREE.Mesh(new THREE.BoxGeometry(rnd(3, 6), h, 2), i % 2 ? f1 : f2); m.position.y = h / 2 - 4; return m; }, 16, 7, .3, 0, -30); farLayer(i => { const h = rnd(4, 12), m = new THREE.Mesh(new THREE.BoxGeometry(rnd(3, 5), h, 2), basic(0x8a7090)); m.position.y = h / 2 - 4; return m; }, 16, 8, .45, 0, -24); }
  else if (d === 'marte') { hills([8, 13], 4, 9, 7); stars(150); hemi.color.set(0xffd0b0); hemi.groundColor.set(0x5a2a1a); }
  else if (d === 'luna') { hemi.color.set(0xdde4ff); hemi.groundColor.set(0x333344); hemi.intensity = 1.5; sun.intensity = 2.4; stars(400);
    const earth = new THREE.Mesh(new THREE.SphereGeometry(4, 32, 20), new THREE.MeshBasicMaterial({ map: M.canvasTex(256, 128, (x, w, h) => { x.fillStyle = '#2f7fe0'; x.fillRect(0, 0, w, h); x.fillStyle = '#4fbf5a'; for (let i = 0; i < 14; i++) { x.beginPath(); x.ellipse(rnd(0, w), rnd(20, h - 20), rnd(10, 30), rnd(6, 18), rnd(0, 3), 0, 7); x.fill(); } x.fillStyle = 'rgba(255,255,255,.75)'; for (let i = 0; i < 12; i++) { x.beginPath(); x.ellipse(rnd(0, w), rnd(0, h), rnd(10, 26), rnd(2, 5), 0, 0, 7); x.fill(); } }, false) }));
    earth.position.set(9, 15, -36); earth.userData.k = .1; far.add(earth); hills([8, 13], 4, 9, 7); }
  if (ST.drag) { water = true; }
  for (let i = 0; i < 4; i++) addChunk();
  // banderas: récord
  if (best(ST.id) > 30) flag(best(ST.id), 0xffd84a, 'RÉCORD');
}
function flag(x, color, text) {
  const g = new THREE.Group(), pole = new THREE.Mesh(new THREE.CylinderGeometry(.04, .04, 2.6, 8), new THREE.MeshStandardMaterial({ color: 0xdddddd, metalness: .5, roughness: .3 })); pole.position.y = 1.3; g.add(pole);
  const tex = M.canvasTex(256, 128, (c, w, h) => { c.fillStyle = '#' + col(color).getHexString(); c.fillRect(0, 0, w, h); c.fillStyle = '#222'; c.font = '700 44px Fredoka, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(text, w / 2, h / 2 + 3); }, false);
  const cloth = new THREE.Mesh(new THREE.PlaneGeometry(1.3, .65), new THREE.MeshBasicMaterial({ map: tex, side: THREE.DoubleSide })); cloth.position.set(.67, 2.25, 0); g.add(cloth);
  g.position.set(x, Math.max(hgt(x), -2), -1); world.add(g); return g;
}
const DECO_MAT = {};
const dm = (c, flat = true) => DECO_MAT[c] || (DECO_MAT[c] = new THREE.MeshStandardMaterial({ color: c, flatShading: flat, roughness: .9 }));
function decoPiece(x) {
  const d = ST.deco, r = Math.random();
  const ico = (s, c) => new THREE.Mesh(new THREE.IcosahedronGeometry(s, 0), dm(c));
  let o, lift = 0;
  if (d === 'campo') { if (r < .35) o = ico(rnd(.12, .3), 0x9a9488); else if (r < .7) { o = new THREE.Mesh(new THREE.SphereGeometry(.08, 8, 6), dm([0xff5a7a, 0xffd84a, 0xffffff, 0xb45aff][Math.floor(rnd(0, 4))], false)); lift = .05; } else { o = new THREE.Mesh(new THREE.ConeGeometry(.25, .9, 5), dm(0x3f8f3a)); lift = .45; } }
  else if (d === 'desierto') { if (r < .3) { o = new THREE.Group(); const m = dm(0x4a9a4a); const t = new THREE.Mesh(new THREE.CylinderGeometry(.12, .14, 1.1, 8), m); t.position.y = .55; o.add(t); for (const s of [-1, 1]) { const a = new THREE.Mesh(new THREE.CylinderGeometry(.07, .07, .4, 6), m); a.position.set(s * .2, .6 + s * .1, 0); o.add(a); const b = new THREE.Mesh(new THREE.CylinderGeometry(.07, .07, .3, 6), m); b.rotation.z = Math.PI / 2; b.position.set(s * .12, .45 + s * .1, 0); o.add(b); } } else o = ico(rnd(.1, .3), 0xc8965a); }
  else if (d === 'bosque') { if (r < .45) { o = new THREE.Group(); const t = new THREE.Mesh(new THREE.CylinderGeometry(.06, .08, .5, 6), dm(0x5a3a1a)); t.position.y = .25; o.add(t); for (let k = 0; k < 3; k++) { const c = new THREE.Mesh(new THREE.ConeGeometry(.45 - k * .1, .6, 7), dm(k % 2 ? 0x2a6a2a : 0x1f5a24)); c.position.y = .6 + k * .3; o.add(c); } } else if (r < .7) { o = new THREE.Mesh(new THREE.SphereGeometry(.09, 8, 6), dm(0xd83a2a, false)); lift = .07; } else o = ico(rnd(.1, .25), 0x6a6a5a); }
  else if (d === 'playa') { if (r < .15 && KIT.palm) { o = KIT.palm.scene.clone(true); o.scale.setScalar(.35); } else if (r < .5) { o = new THREE.Mesh(new THREE.ConeGeometry(.1, .08, 10), dm([0xff9a8a, 0xffe0c0, 0xf4c0e0][Math.floor(rnd(0, 3))], false)); lift = .04; } else o = ico(rnd(.08, .2), 0xc8b090); }
  else if (d === 'artico') { if (r < .3) { o = new THREE.Mesh(new THREE.ConeGeometry(.15, rnd(.5, 1.2), 4), new THREE.MeshStandardMaterial({ color: 0xbfe8ff, transparent: true, opacity: .8, roughness: .1, flatShading: true })); lift = .3; } else o = new THREE.Mesh(new THREE.SphereGeometry(rnd(.2, .45), 10, 6), dm(0xffffff)); if (o.geometry.type === 'SphereGeometry') o.scale.y = .45; }
  else if (d === 'fondo') { if (r < .4) { o = new THREE.Group(); const m = dm([0x3aa85a, 0x2a8a4a][Math.floor(rnd(0, 2))]); for (let k = 0; k < 3; k++) { const p = new THREE.Mesh(new THREE.BoxGeometry(.06, rnd(.6, 1.4), .02), m); p.position.set(k * .08 - .08, p.geometry.parameters.height / 2, 0); p.rotation.z = rnd(-.15, .15); o.add(p); } } else if (r < .65) { o = new THREE.Group(); const m = dm([0xff6a8a, 0xff9a4a, 0xc85aff][Math.floor(rnd(0, 3))]); for (let k = 0; k < 4; k++) { const b = new THREE.Mesh(new THREE.CylinderGeometry(.03, .05, rnd(.3, .6), 6), m); b.rotation.z = rnd(-.6, .6); b.position.set(rnd(-.1, .1), .2, 0); o.add(b); } } else { o = new THREE.Mesh(new THREE.ConeGeometry(.09, .07, 10), dm(0xfff0e0, false)); lift = .03; } }
  else if (d === 'volcan') { o = ico(rnd(.12, .4), r < .5 ? 0x2a2222 : 0x4a3a34); }
  else if (d === 'ciudad') { if (r < .2) { o = new THREE.Group(); const p = new THREE.Mesh(new THREE.CylinderGeometry(.04, .05, 2.2, 8), dm(0x3a3a44, false)); p.position.y = 1.1; o.add(p); const l = new THREE.Mesh(new THREE.SphereGeometry(.12, 10, 8), new THREE.MeshBasicMaterial({ color: 0xfff2c0 })); l.position.set(.15, 2.2, 0); o.add(l); } else if (r < .45) { o = new THREE.Mesh(new THREE.ConeGeometry(.12, .35, 8), dm(0xff7a2a, false)); lift = .17; } else return null; }
  else if (d === 'marte') o = ico(rnd(.12, .45), r < .5 ? 0x8a3a24 : 0xa8502e);
  else o = r < .5 ? ico(rnd(.15, .4), 0x8a8d98) : (() => { const t = new THREE.Mesh(new THREE.TorusGeometry(rnd(.3, .6), .06, 6, 16), dm(0x9a9daa)); t.rotation.x = Math.PI / 2; return t; })();
  o.position.set(x, hgt(x) + lift, -rnd(.5, 1.1)); return o;
}
function terrainChunk(x0, x1) {
  const n = Math.ceil((x1 - x0) / .2), pos = [], cl = [], idx = [], t1 = col(ST.top[0]), t2 = col(ST.top[1]), dirt = col(ST.dirt), deep = col(ST.deep);
  for (let i = 0; i <= n; i++) {
    const x = x0 + i * (x1 - x0) / n, y = hgt(x);
    pos.push(x, y, 1.2, x, y - .25, 1.2, x, y - 10, 1.2, x, y, -1.2, x, y - .02, 1.2);
    const g = i % 2 ? t1 : t2;
    cl.push(g.r, g.g, g.b, dirt.r, dirt.g, dirt.b, deep.r, deep.g, deep.b, g.r, g.g, g.b, g.r, g.g, g.b);
    if (i < n) { const a = i * 5, b = a + 5; idx.push(a, b + 1, b, a, a + 1, b + 1, a + 1, b + 2, b + 1, a + 1, a + 2, b + 2, a + 3, b + 3, b + 4, a + 3, b + 4, a + 4); }
  }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(cl, 3)); g.setIndex(idx); g.computeVertexNormals();
  const grp = new THREE.Group(); grp.add(new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: ST.grip < .6 ? .2 : .95, side: THREE.DoubleSide })));
  for (let x = x0 + 1; x < x1; x += rnd(1, 3)) { if (ST.pit && ST.pit(x)) continue; const o = decoPiece(x); if (o) grp.add(o); }
  // rampas de madera de la playa y de la ciudad
  if (ST.id === 'playa' || ST.id === 'ciudad') for (let x = Math.ceil(x0); x < x1; x += .5) { const c = ((x % (ST.id === 'playa' ? 58 : 72)) + 100) % (ST.id === 'playa' ? 58 : 72); if (x > 40 && (ST.id === 'playa' ? c >= 40 && c < 48 : c > 50 && c <= 57)) { const p = new THREE.Mesh(new THREE.BoxGeometry(.5, .06, 2.3), dm(ST.id === 'playa' ? 0xa8743a : 0xffc83a, false)); p.position.set(x, hgt(x) + .03, 0); p.rotation.z = Math.atan(slope(x)); grp.add(p); } }
  // pozos de lava y huecos
  if (ST.pit) for (let x = Math.ceil(x0 * 2) / 2; x < x1; x += .5) if (ST.pit(x)) {
    if (ST.hazard === 'lava') { const l = new THREE.Mesh(new THREE.BoxGeometry(.52, .1, 2.4), lavaMat); l.position.set(x, hgt(x) + .35, 0); grp.add(l); if (Math.random() < .3) { const r = new THREE.Mesh(new THREE.SphereGeometry(.1, 6, 4), lavaMat); r.position.set(x, hgt(x) + .42, rnd(-.8, .8)); grp.add(r); } }
  }
  return grp;
}
const lavaMat = new THREE.MeshBasicMaterial({ color: 0xff6a1a });
const coinMat = [new THREE.MeshStandardMaterial({ color: 0xffc21d, emissive: 0x8a5a00, emissiveIntensity: .5, roughness: .3, metalness: .3 }), new THREE.MeshStandardMaterial({ color: 0xff4d6d, emissive: 0x8a1030, emissiveIntensity: .5, roughness: .3, metalness: .3 }), new THREE.MeshStandardMaterial({ color: 0x4ad8ff, emissive: 0x0a5a8a, emissiveIntensity: .7, roughness: .2, metalness: .4 })];
const coinMult = x => 1 + Math.floor(x / 400);
const safe = x => !(ST.pit && (ST.pit(x) || ST.pit(x - 1.5) || ST.pit(x + 1.5)));
function addChunk() {
  const c = terrainChunk(chunkX, chunkX + 40); world.add(c); chunks.push({ m: c, x1: chunkX + 40 }); chunkX += 40;
  while (nextCoin < chunkX) {
    const n = Math.floor(rnd(4, 9)); for (let i = 0; i < n; i++) { const x = nextCoin + i * .75; if (!safe(x)) continue; const m = new THREE.Mesh(new THREE.CylinderGeometry(.22, .22, .06, 18), coinMat[0]); m.rotation.x = Math.PI / 2; m.position.set(x, hgt(x) + .8, 0); world.add(m); items.push({ m, x, kind: 'coin', v: 4 * coinMult(x) }); }
    nextCoin += rnd(10, 22) + Math.min(14, nextCoin / 200);
  }
  while (nextBig < chunkX) { const x = nextBig; if (safe(x)) { const m = new THREE.Mesh(new THREE.CylinderGeometry(.36, .36, .08, 20), coinMat[1]); m.rotation.x = Math.PI / 2; m.position.set(x, hgt(x) + 1, 0); world.add(m); items.push({ m, x, kind: 'coin', v: 20 * coinMult(x) }); } nextBig += rnd(55, 95); }
  while (nextGem < chunkX) { const x = nextGem; if (safe(x)) { const m = new THREE.Mesh(new THREE.OctahedronGeometry(.32), coinMat[2]); m.position.set(x, hgt(x) + 1.3, 0); world.add(m); items.push({ m, x, kind: 'coin', v: 80 * coinMult(x), gem: true }); } nextGem += rnd(200, 320); }
  while (nextFuel < chunkX) {
    let x = nextFuel; while (!safe(x)) x += 2;
    const m = new THREE.Group(), red = new THREE.MeshStandardMaterial({ color: 0xe8302e, roughness: .4 });
    m.add(new THREE.Mesh(new THREE.BoxGeometry(.45, .55, .28), red)); const cap = new THREE.Mesh(new THREE.CylinderGeometry(.06, .06, .14, 10), new THREE.MeshStandardMaterial({ color: 0xffd84a })); cap.position.set(.13, .33, 0); m.add(cap);
    const lab = new THREE.Mesh(new THREE.BoxGeometry(.3, .16, .3), new THREE.MeshStandardMaterial({ color: 0xffffff })); m.add(lab);
    m.position.set(x, hgt(x) + .5, 0); world.add(m); items.push({ m, x, kind: 'fuel' });
    fuelN++; nextFuel = x + (125 + fuelN * 16) * ST.fuel;   // cada bidón queda más lejos que el anterior
  }
  // puntos de control
  for (let k = 1; k < 40; k++) { const x = checkpoint(k); if (x >= chunkX - 40 && x < chunkX) { const f = flag(x, 0x5fe37a, k * 1 + 'º'); f.position.z = -1.1; items.push({ m: f, x, kind: 'cp', k, keep: true }); } if (x >= chunkX) break; }
}

/* ---------- coche ---------- */
function makeCar(gltf, st) {
  const g = new THREE.Group(), src = gltf.scene.clone(true), inner = new THREE.Group(); inner.add(src); g.add(inner);
  const wheels = [], back = [], front = []; let seat = null;
  src.traverse(o => {
    if (/^character/.test(o.name)) { o.visible = false; seat = o.position.clone(); }
    if (/^wheel-(back|front)-(left|right)/.test(o.name)) { wheels.push(o); (/front/.test(o.name) ? front : back).push(o); }
  });
  const avg = (arr, f) => arr.reduce((a2, o) => a2 + f(o), 0) / arr.length;
  const zb = avg(back, o => o.position.z), zf = avg(front, o => o.position.z), yb = avg(back, o => o.position.y), yf = avg(front, o => o.position.y);
  const k = st.wb / (zf - zb), midz = (zb + zf) / 2, midy = (yb + yf) / 2;
  inner.rotation.y = Math.PI / 2; inner.scale.setScalar(k); inner.position.set(-midz * k, -midy * k, 0);
  src.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(src);
  g.userData = { wheels, k, wb: { x: (zb - midz) * k, y: (yb - midy) * k, r: yb * k }, wf: { x: (zf - midz) * k, y: (yf - midy) * k, r: yf * k },
    seat: seat ? new THREE.Vector3((seat.z - midz) * k - .05, (seat.y - midy) * k + .02, 0) : new THREE.Vector3(-.08 * st.wb, (box.max.y - midy) * k - .03, 0), roof: (box.max.y - midy) * k, hasSeat: !!seat };
  return g;
}
let car = null, carId = null;
async function setCar(id) {
  const c = CARS.find(x => x.id === id), gl = await loadCar(c.file);
  if (car) scene.remove(car);
  car = makeCar(gl, stats(id)); carId = id; scene.add(car);
}

/* ---------- partida ---------- */
let mode = 'loading', G = null, T = 0;
async function startRun() {
  ST = STAGES.find(s => s.id === save.sel.stage) || STAGES[0];
  buildWorld(); await setCar(save.sel.car);
  const st = stats(save.sel.car), u = car.userData;
  G = { st, b: { x: 0, y: Math.max(u.wb.r - u.wb.y, u.wf.r - u.wf.y) + .05, a: 0, vx: 0, vy: 0, w: 0 }, fuel: st.tank, maxFuel: st.tank, gas: 0, dist: 0, coins: 0, over: false, ground: true, airT: 0, airRot: 0, stopT: 0, flipT: 0, spinB: 0, spinF: 0, paused: false,
    flips: 0, bestAir: 0, cans: 0, cpNext: 1, lowWarn: false, done: [] };
  while (checkpoint(G.cpNext) < 1) G.cpNext++;
  mode = 'run'; for (const s of ['#menu', '#over', '#paused']) $(s).hidden = true; for (const s of ['#hud', '#pedals', '#fuelBox']) $(s).hidden = false;
  $('#hBest').textContent = 'Récord ' + best(ST.id) + ' m';
  engineOn(true); SND.setMusic(false);
}
function physics(dt) {
  const g = G, b = g.b, st = g.st, u = car.userData, steps = 8, h = dt / steps, I = .2 * st.wb * st.wb, GR = ST.g;
  const gas = g.over || g.fuel <= 0 ? (g.gas < 0 && !g.over ? g.gas : 0) : g.gas;
  let any = false; g.slip = 0;
  for (let k2 = 0; k2 < steps; k2++) {
    let Fx = 0, Fy = -GR, Tq = 0, grounded = false;
    const ca = Math.cos(b.a), sa = Math.sin(b.a);
    for (const wh of [u.wb, u.wf]) {
      const rx = wh.x * ca - wh.y * sa, ry = wh.x * sa + wh.y * ca, wx = b.x + rx, wy = b.y + ry;
      const gy = hgt(wx), sl = clamp(slope(wx), -8, 8), L = Math.hypot(1, sl), nx = -sl / L, ny = 1 / L, tx = 1 / L, ty = sl / L;
      const pen = wh.r - (wy - gy) * ny;
      if (pen <= 0) continue;
      grounded = true;
      if (ST.hazard === 'lava' && ST.pit(wx) && !g.over) g.burn = true;
      const vwx = b.vx - b.w * ry, vwy = b.vy + b.w * rx, vn = vwx * nx + vwy * ny, vt = vwx * tx + vwy * ty;
      const N = Math.max(0, st.k * Math.min(pen, wh.r * .8) - st.c * vn) + (pen > wh.r * .8 ? 400 * (pen - wh.r * .8) : 0);
      // reparto de la tracción según el tipo de coche
      const share = st.drive === '4x4' ? .55 : (st.drive === 'fwd') === (wh === u.wf) ? 1 : 0;
      let Ft;
      if (gas > 0) Ft = st.engine * share * gas * Math.max(0, 1 - Math.max(0, vt) / st.vmax);
      else if (gas < 0) Ft = vt > .4 ? -st.engine * .5 : -st.engine * .18 * share * Math.max(0, 1 - Math.max(0, -vt) / (st.vmax * .3));
      else Ft = -vt * .35;
      Ft -= vt * .04;
      const lim = st.mu * ST.grip * N * (GR / 14 * .4 + .6);
      if (Math.abs(Ft) > lim) { g.slip += (Math.abs(Ft) - lim) / (lim + 1); Ft = Math.sign(Ft) * lim; }
      const fx = N * nx + Ft * tx, fy = N * ny + Ft * ty;
      Fx += fx; Fy += fy; Tq += rx * fy - ry * fx;
      const spin = vt * h / wh.r + (share && gas > 0 && g.slip > .2 ? .02 : 0);
      if (wh === u.wb) g.spinB += spin; else g.spinF += spin;
    }
    if (!grounded && gas) Tq += gas * st.air * ST.air * I;
    b.vx += Fx * h; b.vy += Fy * h; b.w += Tq / I * h; b.w *= 1 - 1.2 * h;
    if (ST.drag) { b.vx *= 1 - ST.drag * h; b.vy *= 1 - ST.drag * h; b.w *= 1 - ST.drag * h; }
    b.x += b.vx * h; b.y += b.vy * h; b.a += b.w * h;
    any = any || grounded;
  }
  return { gas, grounded: any };
}
function bonus(txt, cls = '') { const b = $('#bonus'); b.textContent = txt; b.className = 'bonus ' + cls; void b.offsetWidth; b.classList.add('on'); }
function step(dt) {
  const g = G, { gas, grounded } = physics(dt), b = g.b, u = car.userData;
  // saltos y volteretas
  if (!grounded) { g.airT += dt; g.airRot += g.b.w * dt; }
  else if (g.airT > 0) {
    if (!g.over) {
      g.bestAir = Math.max(g.bestAir, g.airT);
      const flips = Math.floor(Math.abs(g.airRot) / (Math.PI * 2) + .15);
      if (flips > 0) { const c2 = 60 * flips * flips * coinMult(b.x); g.coins += c2; g.flips += flips; bonus(`${flips > 1 ? flips + '× ' : ''}¡VOLTERETA! +${c2}`); S.levelup && S.levelup(); buzz('MEDIUM'); }
      else if (g.airT > 1.3) { const c2 = Math.round(g.airT * 12 * coinMult(b.x)); g.coins += c2; bonus(`¡AIRE! ${g.airT.toFixed(1).replace('.', ',')} s +${c2}`); S.good && S.good(); }
    }
    g.airT = 0; g.airRot = 0;
  }
  if (!g.over) {
    g.fuel = Math.max(0, g.fuel - dt * g.st.cons * (gas > 0 ? 2.9 : .75));
    g.dist = Math.max(g.dist, Math.floor(b.x));
    const ca = Math.cos(b.a), sa = Math.sin(b.a), hx = b.x + u.seat.x * ca - (u.roof + .3) * sa, hy = b.y + u.seat.x * sa + (u.roof + .3) * ca;
    if (hy < hgt(hx) + .05) end('¡TE HAS DADO EN LA CABEZA!');
    if (g.burn) end('¡TE HAS QUEMADO!');
    if (b.y < -9) end('¡AL VACÍO!');
    const sp = Math.hypot(b.vx, b.vy);
    if (g.fuel <= 0) { g.stopT = sp < .4 ? g.stopT + dt : 0; if (g.stopT > 1.5) end('¡SIN GASOLINA!'); }
    if (!g.lowWarn && g.fuel < g.maxFuel * .2 && g.fuel > 0) { g.lowWarn = true; S.no && S.no(); }
    if (g.fuel > g.maxFuel * .3) g.lowWarn = false;
    if (Math.cos(b.a) < -.3 && grounded) { g.flipT += dt; if (g.flipT > 1.5) end('¡VUELCO!'); } else g.flipT = 0;
    for (const it of items) {
      if (it.got) continue;
      if (it.kind === 'coin') it.m.rotation[it.gem ? 'y' : 'z'] += dt * 4;
      if (it.kind === 'cp') { if (b.x > it.x) { it.got = true; const c2 = cpBonus(it.k); g.coins += c2; bonus(`¡CONTROL ${it.k}! +${c2}`, 'cp'); S.levelup && S.levelup(); buzz('HEAVY'); PA.burst(it.x, hgt(it.x) + 2, 0, 30, col(0x5fe37a), 3, .14, .8); G.cpNext = it.k + 1; } continue; }
      if (Math.abs(it.x - b.x) < 1.1 && Math.abs(it.m.position.y - (b.y + .5)) < 1.3) {
        it.got = true; world.remove(it.m);
        if (it.kind === 'coin') { g.coins += it.v; S.coin(); PA.burst(it.m.position.x, it.m.position.y, 0, it.v > 20 ? 16 : 6, col(it.gem ? 0x4ad8ff : it.v > 20 ? 0xff6f8a : 0xffd84a), 1.5, .1, .4); FL.add('+' + it.v, it.m.position.x, it.m.position.y + .3, 0, { color: '#ffe07a', size: .5, life: .8 }); }
        else { g.fuel = g.maxFuel; g.cans++; S.good && S.good(); buzz('MEDIUM'); bonus('¡GASOLINA!'); }
      }
    }
    items = items.filter(it => (!it.got || it.keep) && it.x > b.x - 30);
  }
  while (chunkX < b.x + 70) addChunk();
  while (chunks.length && chunks[0].x1 < b.x - 40) world.remove(chunks.shift().m);
  // polvo y nieve
  const ca = Math.cos(b.a), sa = Math.sin(b.a);
  if (gas > 0 && grounded && g.fuel > 0 && Math.random() < .5 + g.slip) PN.emit(b.x + u.wb.x * ca, b.y + u.wb.x * sa - .25, .5, -rnd(.5, 1.5) - g.slip * 2, rnd(.3, 1) + g.slip, 0, col({ campo: 0xc9b08a, desierto: 0xf0d090, artico: 0xffffff, playa: 0xf6e0b0, fondo: 0xe8d8a8, volcan: 0x5a4a44, ciudad: 0x9a9aa4, marte: 0xd8784a }[ST.id] || 0xcfd2dc), .3, .7, ST.g * .1, 1.2);
  if (ST.drag && Math.random() < .3) PA.emit(b.x + rnd(-1, 1), b.y + rnd(0, 1), .6, 0, .8, 0, col(0xdff8ff), .12, 1.4, -.2);
  if (ST.hazard === 'lava' && Math.random() < .4) { const x = b.x + rnd(-8, 14); if (ST.pit(x)) PA.emit(x, hgt(x) + .5, rnd(-.8, .8), 0, rnd(1, 2.5), 0, col(0xffa040), .18, .8, 3); }
  engineSound(gas, Math.hypot(b.vx, b.vy));
  // interfaz
  $('#hDist').textContent = g.dist + ' m'; $('#hCoins').textContent = fmt(g.coins);
  const nx = checkpoint(g.cpNext); $('#hCp').textContent = `Control ${g.cpNext}: ${Math.max(0, nx - g.dist)} m`;
  const fb = $('#fuelBar'); fb.style.width = (g.fuel / g.maxFuel * 100) + '%'; fb.classList.toggle('low', g.fuel < g.maxFuel * .22);
  $('.ped.gas').classList.toggle('on', g.gas > 0); $('.ped.brake').classList.toggle('on', g.gas < 0);
}
function end(why) {
  const g = G; if (g.over) return; g.over = true; g.why = why; S.bad && S.bad(); buzz('HEAVY'); engineOn(false);
  setTimeout(() => {
    const rec = g.dist > best(ST.id); if (rec) save.best[ST.id] = g.dist;
    save.total += g.dist;
    // misiones
    const done = [];
    for (let i = 0; i < save.mis.length; i++) {
      const m = save.mis[i]; let v = 0;
      if (m.t === 'dist') v = m.stage === ST.id ? g.dist : 0; else if (m.t === 'flips') v = g.flips; else if (m.t === 'air') v = +g.bestAir.toFixed(1); else if (m.t === 'coins') v = g.coins; else if (m.t === 'fuel') v = g.cans; else if (m.t === 'total') v = save.total - m.base;
      m.prog = Math.max(m.prog, v);
      if (m.prog >= m.goal) { done.push(m); save.coins += m.reward; save.mdone++; save.mis[i] = newMission(); }
    }
    save.coins += g.coins; persist();
    $('#oWhy').textContent = why; $('#oDist').textContent = g.dist + ' m'; $('#oCoins').textContent = '+' + fmt(g.coins); $('#oBest').textContent = best(ST.id) + ' m'; $('#oRec').hidden = !rec;
    $('#oFlips').textContent = g.flips; $('#oAir').textContent = g.bestAir.toFixed(1).replace('.', ',') + ' s';
    $('#oMis').innerHTML = done.map(m => `<div class="misDone">✓ ${m.text} <b>+${fmt(m.reward)}</b></div>`).join('');
    if (done.length) setTimeout(() => S.levelup && S.levelup(), 300);
    for (const s of ['#hud', '#pedals', '#fuelBox']) $(s).hidden = true; $('#over').hidden = false; mode = 'over';
  }, 1100);
}

/* ---------- sonido del motor ---------- */
let eng = null;
function engineOn(on) {
  const a = SND.ac(); if (!a || !SND.cfg.sfx) return;
  if (on && !eng) {
    const o1 = a.createOscillator(), o2 = a.createOscillator(), f = a.createBiquadFilter(), gn = a.createGain();
    o1.type = 'sawtooth'; o2.type = 'square'; f.type = 'lowpass'; f.frequency.value = 600; gn.gain.value = 0;
    o1.connect(f); o2.connect(f); f.connect(gn).connect(a.destination); o1.start(); o2.start(); eng = { o1, o2, f, gn };
  }
  if (!on && eng) { const e = eng; e.gn.gain.setTargetAtTime(0, a.currentTime, .1); setTimeout(() => { try { e.o1.stop(); e.o2.stop(); } catch (er) { } }, 400); eng = null; }
}
function engineSound(gas, sp) {
  if (!eng) return; const a = SND.ac(), t = a.currentTime, f0 = 34 + sp * 4.5 + (gas > 0 ? 18 : 0) + (G.slip > .3 && gas > 0 ? 25 : 0);
  eng.o1.frequency.setTargetAtTime(f0, t, .08); eng.o2.frequency.setTargetAtTime(f0 * .5, t, .08); eng.f.frequency.setTargetAtTime(400 + sp * 60 + (gas > 0 ? 500 : 0), t, .1);
  eng.gn.gain.setTargetAtTime(G.paused ? 0 : (gas > 0 ? .07 : .04), t, .1);
}

/* ---------- gamba al volante ---------- */
function seatPet(dt, speed) {
  if (!car) return; const u = car.userData;
  player.root.visible = true; player.root.scale.setScalar(Math.min(1.1, .55 + u.k * .9) * .8);
  const v = u.seat.clone().applyEuler(car.rotation).add(car.position); player.root.position.copy(v);
  player.root.quaternion.setFromEuler(car.rotation).multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(0, -Math.PI / 2, 0)));
  player.tilt.position.set(0, 0, 0); player.tilt.rotation.set(-.45 + Math.sin(T * 9) * (speed > 1 ? .04 : 0), 0, 0); player.tilt.scale.set(1, 1, 1);
  player.pose(T * 3, 'idle', T, dt, 2);
}

/* ---------- bucle ---------- */
const camPos = V(0, 2, 12), camLook = V(0, .5, 0);
function frame(dt) {
  T += dt; M.SKIN.t.value = T;
  if (mode === 'run' && G && !G.paused) {
    step(dt);
    const b = G.b; car.position.set(b.x, b.y, 0); car.rotation.set(0, 0, b.a);
    for (const w of car.userData.wheels) w.rotation.x = /front/.test(w.name) ? G.spinF : G.spinB;
    seatPet(dt, Math.hypot(b.vx, b.vy));
    const look = V(b.x + 2.2 + clamp(b.vx * .12, 0, 2), Math.max(b.y + 1, -4), 0), d = camDist + clamp(Math.abs(b.vx) * .25, 0, 4);
    camPos.lerp(V(look.x, look.y + 1.8, d), Math.min(1, dt * 6)); camLook.lerp(look, Math.min(1, dt * 6));
  } else if (mode === 'menu' && car) {
    car.position.set(0, 0, 0); car.rotation.set(0, Math.sin(T * .5) * .5 + .3, 0);
    const u = car.userData; car.position.y = Math.max(u.wb.r - u.wb.y, u.wf.r - u.wf.y);
    seatPet(dt, 0);
    camPos.lerp(V(0, 2.2, 10), Math.min(1, dt * 4)); camLook.lerp(V(0, .55, 0), Math.min(1, dt * 4));
  }
  cam.position.copy(camPos); cam.lookAt(camLook);
  if (skyMesh) skyMesh.position.set(camLook.x, camLook.y + 8, -40);
  if (lava) { lava.position.set(camLook.x, -40, 0); lavaMat.color.setHSL(.05 + Math.sin(T * 3) * .015, 1, .52); }
  if (ST.hazard === 'lava') lavaMat.color.setHSL(.05 + Math.sin(T * 3) * .015, 1, .52);
  if (far) for (const o of far.children) { if (o.userData.base === undefined) o.userData.base = o.position.x; o.position.x = o.userData.base + camLook.x * (1 - o.userData.k); if (o.position.x < camLook.x - 70) o.userData.base += 140; o.position.y += (camLook.y * (1 - o.userData.k) - (o.userData.ly || 0)); o.userData.ly = camLook.y * (1 - o.userData.k); }
  PN.update(dt); PA.update(dt); FL.update(dt);
}
const clock = new THREE.Clock();
function loop() { requestAnimationFrame(loop); const dt = Math.min(1 / 30, clock.getDelta()); frame(dt); R.render(scene, cam); }

/* ---------- controles: táctil, teclado y mando ---------- */
const touches = new Map();
let keyGas = 0, padGas = 0;
function pedals() { let g = 0; for (const x of touches.values()) g = x > innerWidth / 2 ? 1 : (g === 1 ? 1 : -1); if (G) G.gas = g || keyGas || padGas; }
addEventListener('touchstart', e => { if (mode !== 'run') return; for (const t of e.changedTouches) touches.set(t.identifier, t.clientX); pedals(); }, { passive: true });
addEventListener('touchmove', e => { if (mode !== 'run') return; for (const t of e.changedTouches) touches.set(t.identifier, t.clientX); pedals(); }, { passive: true });
addEventListener('touchend', e => { for (const t of e.changedTouches) touches.delete(t.identifier); pedals(); }, { passive: true });
addEventListener('touchcancel', () => { touches.clear(); pedals(); }, { passive: true });
addEventListener('keydown', e => { if (e.key === 'ArrowRight' || e.key === 'd') keyGas = 1; if (e.key === 'ArrowLeft' || e.key === 'a') keyGas = -1; pedals(); });
addEventListener('keyup', e => { if (['ArrowRight', 'ArrowLeft', 'a', 'd'].includes(e.key)) keyGas = 0; pedals(); });
function pollPad() { const p = navigator.getGamepads ? [...navigator.getGamepads()].find(x => x) : null; if (!p) return; const rt = p.buttons[7] && p.buttons[7].value, lt = p.buttons[6] && p.buttons[6].value; padGas = rt > .2 || (p.buttons[0] && p.buttons[0].pressed) ? 1 : lt > .2 || (p.buttons[2] && p.buttons[2].pressed) ? -1 : 0; if (mode === 'run') pedals(); }

/* ---------- menú ---------- */
let stIdx = 0, carIdx = 0;
const bar = (v, m) => `<i style="width:${Math.min(100, v / m * 100)}%"></i>`;
let toastT = 0;
function toast(m) { const t = $('#toast'); t.textContent = m; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 1800); }
function pay(cost) { if (save.coins < cost) { toast(`Te faltan ${fmt(cost - save.coins)} monedas`); S.err && S.err(); buzz('HEAVY'); return false; } save.coins -= cost; persist(); S.buy && S.buy(); buzz('MEDIUM'); return true; }
const DRIVE = { rwd: 'Tracción trasera', fwd: 'Tracción delantera', '4x4': '4x4' };
function renderStage() {
  const s = STAGES[stIdx], own = !!save.owned[s.id];
  $('#stName').textContent = `${s.name}`; $('#stCount').textContent = `${stIdx + 1}/${STAGES.length}`;
  $('#stInfo').textContent = s.info;
  $('#stMeta').innerHTML = `<span>Gravedad ${s.g >= 14 ? 'normal' : s.g >= 9 ? 'baja' : 'muy baja'}</span><span>Agarre ${s.grip >= .95 ? 'alto' : s.grip >= .8 ? 'medio' : 'bajo'}</span><span>Récord ${best(s.id)} m</span>`;
  const b = $('#stBuy'); b.hidden = own; b.innerHTML = `Desbloquear <span class="coin"></span>${fmt(s.price)}`;
  b.onclick = () => { if (pay(s.price)) { save.owned[s.id] = true; save.sel.stage = s.id; persist(); toast(`¡${s.name} desbloqueado!`); renderAll(); } };
  if (own && save.sel.stage !== s.id) { save.sel.stage = s.id; persist(); }
  $('#playBtn').disabled = !own || !save.owned[CARS[carIdx].id];
  if (ST.id !== s.id) { ST = s; buildWorld(); }
}
async function renderCar() {
  const c = CARS[carIdx], own = !!save.owned[c.id], st = stats(c.id);
  $('#carName').textContent = c.name; $('#carCount').textContent = `${carIdx + 1}/${CARS.length}`; $('#carDesc').textContent = `${c.desc} · ${DRIVE[c.drive]}`;
  $('#carStats').innerHTML = [['Velocidad', st.vmax, 40], ['Fuerza', st.engine, 60], ['Agarre', st.mu, 2.2], ['Gasolina', st.tank / st.cons, 300]].map(([n, v, m]) => `<div><small>${n}</small><span class="sb">${bar(v, m)}</span></div>`).join('');
  const ups = $('#carUps');
  ups.innerHTML = own ? UPG.map(u => { const lv = lvOf(c.id, u.id); return `<button class="garUp" data-u="${u.id}" ${lv >= MAXLV ? 'disabled' : ''}><b>${u.name}</b><span class="lvd">${Array.from({ length: MAXLV }, (_, i) => `<i class="${i < lv ? 'f' : ''}"></i>`).join('')}</span><em>${lv >= MAXLV ? 'Máx.' : `<span class="coin"></span>${fmt(upCost(c, lv))}`}</em></button>`; }).join('') : '<div class="garLock">Cómpralo para poder mejorarlo</div>';
  ups.querySelectorAll('[data-u]').forEach(b2 => b2.onclick = () => { const u = b2.dataset.u, lv = lvOf(c.id, u); if (!pay(upCost(c, lv))) return; save.lv[c.id] = save.lv[c.id] || {}; save.lv[c.id][u] = lv + 1; persist(); renderAll(); });
  const b = $('#carBuy'); b.hidden = own; b.innerHTML = `Comprar <span class="coin"></span>${fmt(c.price)}`;
  b.onclick = () => { if (pay(c.price)) { save.owned[c.id] = true; save.sel.car = c.id; persist(); toast(`¡${c.name} comprado!`); renderAll(); } };
  if (own && save.sel.car !== c.id) { save.sel.car = c.id; persist(); }
  $('#playBtn').disabled = !own || !save.owned[STAGES[stIdx].id];
  if (carId !== c.id) await setCar(c.id);
}
function renderMissions() {
  $('#misList').innerHTML = save.mis.map(m => { const v = m.t === 'total' ? save.total - m.base : m.prog; return `<div class="mis"><div><b>${m.text}</b><span class="sb">${bar(v, m.goal)}</span></div><em><span class="coin"></span>${fmt(m.reward)}</em></div>`; }).join('') + `<div class="misFoot">Misiones cumplidas: ${save.mdone}</div>`;
}
function renderAll() { $('#mCoins').textContent = fmt(save.coins); renderStage(); renderCar(); renderMissions(); }
const today = () => new Date().toISOString().slice(0, 10);
function toMenu() {
  mode = 'menu'; G = null; engineOn(false); touches.clear();
  for (const s of ['#over', '#paused', '#hud', '#pedals', '#fuelBox', '#settings']) $(s).hidden = true; $('#menu').hidden = false;
  stIdx = Math.max(0, STAGES.findIndex(s => s.id === save.sel.stage)); carIdx = Math.max(0, CARS.findIndex(c => c.id === save.sel.car));
  ST = STAGES[stIdx]; buildWorld(); $('#giftDot').hidden = save.daily.last === today(); renderAll(); SND.setMusic(true);
}
$$('.tab2').forEach(b => b.onclick = () => { $$('.tab2').forEach(x => x.classList.toggle('on', x === b)); for (const p of ['stage', 'car', 'mis']) $('#p' + p[0].toUpperCase() + p.slice(1)).hidden = b.dataset.p !== p; });
$('#stPrev').onclick = () => { stIdx = (stIdx + STAGES.length - 1) % STAGES.length; renderAll(); };
$('#stNext').onclick = () => { stIdx = (stIdx + 1) % STAGES.length; renderAll(); };
$('#carPrev').onclick = () => { carIdx = (carIdx + CARS.length - 1) % CARS.length; renderAll(); };
$('#carNext').onclick = () => { carIdx = (carIdx + 1) % CARS.length; renderAll(); };
$('#playBtn').onclick = () => { SND.ac(); startRun(); };
$('#again').onclick = () => startRun();
$('#overMenu').onclick = toMenu;
$('#pauseBtn').onclick = () => { if (G && !G.over) { G.paused = true; $('#paused').hidden = false; } };
$('#resume').onclick = () => { G.paused = false; $('#paused').hidden = true; clock.getDelta(); };
$('#quit').onclick = toMenu;
$('#giftBtn').onclick = () => {
  if (save.daily.last === today()) { toast('Vuelve mañana a por otro regalo'); return; }
  const y = new Date(Date.now() - 864e5).toISOString().slice(0, 10); save.daily.streak = save.daily.last === y ? save.daily.streak + 1 : 1; save.daily.last = today();
  const amt = 150 + Math.min(7, save.daily.streak) * 100; save.coins += amt; persist(); S.buy && S.buy(); toast(`+${amt} monedas · racha de ${save.daily.streak} día${save.daily.streak > 1 ? 's' : ''}`); $('#mCoins').textContent = fmt(save.coins); $('#giftDot').hidden = true;
};
$('#setBtn').onclick = () => { $('#optSfx').checked = save.opt.sfx; $('#optMusic').checked = save.opt.music; $('#optHaptic').checked = save.opt.haptic; $('#settings').hidden = false; };
$('#setClose').onclick = () => { $('#settings').hidden = true; };
for (const [id, k] of [['#optSfx', 'sfx'], ['#optMusic', 'music'], ['#optHaptic', 'haptic']]) $(id).onchange = e => { save.opt[k] = e.target.checked; Object.assign(SND.cfg, save.opt); persist(); if (k === 'music') SND.setMusic(true); };
document.addEventListener('visibilitychange', () => { if (document.hidden) { persist(); if (G && mode === 'run' && !G.over) { G.paused = true; $('#paused').hidden = false; } SND.suspend(true); } else SND.suspend(false); });

/* ---------- arranque ---------- */
async function boot() {
  resize();
  A = await M.loadAll({ gamba: 'models/char/gamba.glb', hood: 'models/char/gorro_tiburon.glb', sedan: 'models/car/sedan.glb', palm: 'models/k/palm-bend.glb' }, p => { $('#loadBar').style.width = Math.round(p * 100) + '%'; });
  carGltf.sedan = A.sedan; KIT.palm = A.palm;
  PN = new Particles(scene, 300, false, R.getPixelRatio()); PA = new Particles(scene, 400, true, R.getPixelRatio()); FL = new Floaters(scene);
  player = new M.Shrimp(A); scene.add(player.root); player.setSkin({ h: 0, s: 1, v: 1 }); await player.use('gamba');
  if (Q.has('coins')) save.coins = +Q.get('coins');
  if (Q.get('stage')) { save.sel.stage = Q.get('stage'); save.owned[Q.get('stage')] = true; }
  if (Q.get('car')) { save.sel.car = Q.get('car'); save.owned[Q.get('car')] = true; }
  if (Q.get('lv')) { for (const u of UPG) (save.lv[save.sel.car] = save.lv[save.sel.car] || {})[u.id] = +Q.get('lv'); }
  setInterval(pollPad, 16);
  $('#loading').hidden = true; toMenu(); requestAnimationFrame(loop);
  if (Q.has('shot')) testShot();
}
async function testShot() {
  document.head.insertAdjacentHTML('beforeend', '<style>*{animation:none!important;transition:none!important}</style>');
  await new Promise(r => setTimeout(r, (+Q.get('shot') || 1) * 1000));
  if (Q.get('tab')) $(`.tab2[data-p="${Q.get('tab')}"]`).click();
  if (Q.has('play')) { await startRun(); if (Q.get('x')) { G.b.x = +Q.get('x'); G.b.y = hgt(G.b.x) + 1; while (chunkX < G.b.x + 70) addChunk(); }
    const steps = +Q.get('steps') || 0; for (let i = 0; i < steps; i++) { if (G) G.gas = G.over ? 0 : (Math.cos(G.b.a) < .75 && G.b.a > 0 ? -1 : 1); frame(1 / 60); } }
  for (let i = 0; i < (+Q.get('frames') || 40); i++) frame(1 / 60);
  R.render(scene, cam);
  const im = $('#shotImg'); im.src = cv.toDataURL('image/png'); im.style.cssText = 'display:block;position:fixed;inset:0;width:100%;height:100%;z-index:4;pointer-events:none';
  document.title = 'LISTO ' + mode + (G ? ` x=${G.b.x.toFixed(0)} over=${G.over} ${G.why || ''}` : '');
  const d = document.createElement('div'); d.style.cssText = 'position:fixed;left:0;bottom:0;z-index:99;background:#fff;color:#000;font:11px monospace'; d.textContent = document.title + (G ? ` dist=${G.dist} fuel=${G.fuel.toFixed(0)} coins=${G.coins}` : ''); document.body.appendChild(d);
}
boot().catch(e => { document.body.insertAdjacentHTML('beforeend', `<pre style="position:fixed;top:0;z-index:999;background:#fff;color:red">${e.message}</pre>`); console.error(e); });
