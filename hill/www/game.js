// Shrimp Hill Climb: carreras cuesta arriba (estilo Hill Climb Racing) con la gamba al volante.
// Física 2D: el coche es un cuerpo rígido con dos ruedas sobre muelles; el suelo es una función h(x) por escenario.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import * as M from './modelos.js';
import { Particles, Floaters } from './particulas.js';
import * as SND from './sonido.js';

const Q = new URLSearchParams(location.search);
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const rnd = (a, b) => a + Math.random() * (b - a), clamp = (v, a, b) => Math.max(a, Math.min(b, v)), lerp = (a, b, t) => a + (b - a) * t;
const S = SND.S, buzz = SND.buzz, V = (x, y, z) => new THREE.Vector3(x, y, z), col = h => new THREE.Color(h);

/* ---------- guardado ---------- */
const K = 'hill.';
const get = (k, d) => { try { const v = JSON.parse(localStorage.getItem(K + k)); return v ?? d; } catch (e) { return d; } };
const DEF = { coins: 0, best: { campo: 0, luna: 0 }, owned: { kart: true, campo: true }, lv: {}, sel: { car: 'kart', stage: 'campo' }, opt: { sfx: true, music: true, haptic: true }, daily: { last: '', streak: 0 } };
const save = {}; for (const k of Object.keys(DEF)) save[k] = get(k, DEF[k]);
for (const k of ['best', 'owned', 'sel', 'opt', 'daily']) save[k] = Object.assign({}, DEF[k], save[k]);
const persist = () => { for (const k of Object.keys(DEF)) try { localStorage.setItem(K + k, JSON.stringify(save[k])); } catch (e) { } };
Object.assign(SND.cfg, save.opt);

/* ---------- escenarios ---------- */
const STAGES = [
  { id: 'campo', name: 'Campo', price: 0, g: 14, air: 1, info: 'Colinas verdes. Gravedad normal.', sky: ['#4fb8ff', '#cdeeff', '#fff6d8'], top: [0x5fbf4a, 0x4aa63a], dirt: 0xa86d3e, deep: 0x6b4426,
    hgt: x => { if (x < 8) return 0; const k = .55 + Math.min(1.9, (x - 8) / 380), e = Math.min(1, (x - 8) / 12); return e * k * (1.3 * Math.sin(x * .15) + .75 * Math.sin(x * .36 + 1) + .3 * Math.sin(x * .83 + 2)); } },
  { id: 'luna', name: 'Luna', price: 1500, g: 6, air: 1.4, info: 'Poca gravedad: ¡saltos enormes! Cuidado con volcar.', sky: ['#05060f', '#0d1030', '#1a1d40'], top: [0xb9bcc6, 0xa8abb6], dirt: 0x8a8d98, deep: 0x4a4d58,
    hgt: x => { if (x < 8) return 0; const k = .7 + Math.min(1.8, (x - 8) / 420), e = Math.min(1, (x - 8) / 12); let h = e * k * (1.8 * Math.sin(x * .085) + .9 * Math.sin(x * .22 + 2) + .25 * Math.sin(x * .9)); const c = ((x % 37) + 37) % 37; if (x > 20 && c < 5) h -= Math.sin(c / 5 * Math.PI) * .55 * e; return h; } },
];
let ST = STAGES[0];
const hgt = x => ST.hgt(x), slope = x => (hgt(x + .05) - hgt(x - .05)) / .1;

/* ---------- coches ---------- */
const CARS = [
  { id: 'kart', name: 'Kart', file: 'kart', price: 0, wb: 1.5, engine: 19, vmax: 12, mu: 1.15, air: 7, k: 120, c: 11, desc: 'Ligero y fácil de llevar.' },
  { id: 'taxi', name: 'Taxi', file: 'taxi', price: 700, wb: 1.7, engine: 22, vmax: 14, mu: 1.1, air: 5.5, k: 130, c: 12, desc: 'Equilibrado. ¡Al aeropuerto!' },
  { id: 'deportivo', name: 'Deportivo', file: 'hatchback-sports', price: 1200, wb: 1.75, engine: 27, vmax: 17, mu: 1.05, air: 5, k: 140, c: 12, desc: 'Rápido, pero hay que saber frenar.' },
  { id: 'todoterreno', name: 'Todoterreno', file: 'suv', price: 1800, wb: 1.75, engine: 25, vmax: 14, mu: 1.5, air: 5, k: 105, c: 13, desc: 'Se agarra a todo. Suspensión blandita.' },
  { id: 'tractor', name: 'Tractor', file: 'tractor', price: 2400, wb: 1.6, engine: 34, vmax: 10, mu: 1.9, air: 4, k: 135, c: 15, desc: 'Lento, pero sube cualquier cuesta.' },
  { id: 'policia', name: 'Policía', file: 'police', price: 3200, wb: 1.75, engine: 31, vmax: 19, mu: 1.2, air: 5, k: 140, c: 13, desc: 'Potente y con sirena.' },
  { id: 'formula', name: 'Fórmula', file: 'race', price: 5000, wb: 1.7, engine: 40, vmax: 24, mu: 1.35, air: 4.5, k: 160, c: 14, desc: 'Un cohete con ruedas. Para expertos.' },
];
const UPG = [{ id: 'motor', name: 'Motor' }, { id: 'agarre', name: 'Ruedas' }, { id: 'susp', name: 'Suspensión' }, { id: 'tanque', name: 'Depósito' }];
const upCost = lv => Math.round(120 * Math.pow(lv + 1, 1.75) / 10) * 10;
const lvOf = (car, u) => (save.lv[car] || {})[u] || 0;
function stats(car) {
  const c = CARS.find(x => x.id === car) || CARS[0], L = u => lvOf(car, u);
  return { ...c, engine: c.engine * (1 + .1 * L('motor')), vmax: c.vmax * (1 + .07 * L('motor')), mu: c.mu + .09 * L('agarre'), c: c.c * (1 + .12 * L('susp')), air: c.air * (1 + .06 * L('susp')), tank: 100 + 20 * L('tanque') };
}

/* ---------- motor 3D ---------- */
const cv = $('#cv');
const R = new THREE.WebGLRenderer({ canvas: cv, antialias: true, preserveDrawingBuffer: Q.has('shot') });
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
const loader = new GLTFLoader(), carGltf = {};
const loadCar = file => carGltf[file] ? Promise.resolve(carGltf[file]) : new Promise((ok, ko) => loader.load('models/car/' + file + '.glb', g => ok(carGltf[file] = g), undefined, ko));

/* ---------- decorado por escenario ---------- */
let world = null, skyMesh = null, far = null, chunks = [], chunkX = -30, items = [], nextCoin = 12, nextFuel = 80, nextBig = 60;
function skyTex(c) { const t = M.canvasTex(4, 256, (x, w, h) => { const g = x.createLinearGradient(0, 0, 0, h); g.addColorStop(0, c[0]); g.addColorStop(.65, c[1]); g.addColorStop(1, c[2]); x.fillStyle = g; x.fillRect(0, 0, w, h); }, false); return t; }
function buildWorld() {
  if (world) scene.remove(world);
  world = new THREE.Group(); scene.add(world); chunks = []; chunkX = -30; items = []; nextCoin = 12; nextFuel = 80; nextBig = 60;
  scene.background = new THREE.Color(ST.sky[1]);
  skyMesh = new THREE.Mesh(new THREE.PlaneGeometry(200, 90), new THREE.MeshBasicMaterial({ map: skyTex(ST.sky), depthWrite: false })); skyMesh.position.z = -40; world.add(skyMesh);
  far = new THREE.Group(); world.add(far);
  if (ST.id === 'campo') {
    hemi.color.set(0xffffff); hemi.groundColor.set(0x887766); hemi.intensity = 1.8; sun.intensity = 2;
    for (let i = 0; i < 9; i++) { const h = rnd(6, 13), m = new THREE.Mesh(new THREE.ConeGeometry(rnd(7, 12), h, 6), new THREE.MeshBasicMaterial({ color: i % 2 ? 0x8fd07a : 0x7fc46a })); m.position.set(i * 14 - 50, h / 2 - 4, -30 + (i % 3)); m.userData.k = .35; far.add(m); }
    for (let i = 0; i < 6; i++) { const c = new THREE.Group(), w = new THREE.MeshBasicMaterial({ color: 0xffffff }); for (let k = 0; k < 4; k++) { const s = new THREE.Mesh(new THREE.SphereGeometry(rnd(1, 1.8), 12, 8), w); s.position.set(k * 1.4, Math.sin(k) * .5, 0); c.add(s); } c.position.set(i * 22 - 50, rnd(9, 15), -34); c.userData.k = .15; far.add(c); }
  } else {
    hemi.color.set(0xdde4ff); hemi.groundColor.set(0x333344); hemi.intensity = 1.5; sun.intensity = 2.4;
    const n = 400, pos = new Float32Array(n * 3); for (let i = 0; i < n; i++) pos.set([rnd(-100, 100), rnd(-5, 40), -38], i * 3);
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const stars = new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: .25 })); stars.userData.k = .05; far.add(stars);
    const earth = new THREE.Mesh(new THREE.SphereGeometry(4, 32, 20), new THREE.MeshBasicMaterial({ map: M.canvasTex(256, 128, (x, w, h) => { x.fillStyle = '#2f7fe0'; x.fillRect(0, 0, w, h); x.fillStyle = '#4fbf5a'; for (let i = 0; i < 14; i++) { x.beginPath(); x.ellipse(rnd(0, w), rnd(20, h - 20), rnd(10, 30), rnd(6, 18), rnd(0, 3), 0, 7); x.fill(); } x.fillStyle = 'rgba(255,255,255,.75)'; for (let i = 0; i < 12; i++) { x.beginPath(); x.ellipse(rnd(0, w), rnd(0, h), rnd(10, 26), rnd(2, 5), 0, 0, 7); x.fill(); } }, false) }));
    earth.position.set(9, 15, -36); earth.userData.k = .1; far.add(earth);
    for (let i = 0; i < 8; i++) { const h = rnd(4, 9), m = new THREE.Mesh(new THREE.ConeGeometry(rnd(8, 13), h, 7), new THREE.MeshBasicMaterial({ color: i % 2 ? 0x3a3d4a : 0x2e313c })); m.position.set(i * 16 - 50, h / 2 - 4, -30); m.userData.k = .3; far.add(m); }
  }
  for (let i = 0; i < 4; i++) addChunk();
}
function terrainChunk(x0, x1) {
  const n = Math.ceil((x1 - x0) / .25), pos = [], cl = [], idx = [], t1 = col(ST.top[0]), t2 = col(ST.top[1]), dirt = col(ST.dirt), deep = col(ST.deep);
  for (let i = 0; i <= n; i++) {
    const x = x0 + i * (x1 - x0) / n, y = hgt(x);
    pos.push(x, y, 1.2, x, y - .25, 1.2, x, y - 10, 1.2, x, y, -1.2, x, y - .02, 1.2);
    const g = i % 2 ? t1 : t2;
    cl.push(g.r, g.g, g.b, dirt.r, dirt.g, dirt.b, deep.r, deep.g, deep.b, g.r, g.g, g.b, g.r, g.g, g.b);
    if (i < n) { const a = i * 5, b = a + 5; idx.push(a, b + 1, b, a, a + 1, b + 1, a + 1, b + 2, b + 1, a + 1, a + 2, b + 2, a + 3, b + 3, b + 4, a + 3, b + 4, a + 4); }
  }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(cl, 3)); g.setIndex(idx); g.computeVertexNormals();
  const grp = new THREE.Group(); grp.add(new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: .95, side: THREE.DoubleSide })));
  for (let x = x0 + 1; x < x1; x += rnd(1, 3)) {
    let o;
    if (ST.id === 'campo') o = Math.random() < .4 ? new THREE.Mesh(new THREE.IcosahedronGeometry(rnd(.12, .3), 0), new THREE.MeshStandardMaterial({ color: 0x9a9488, flatShading: true })) : Math.random() < .6 ? new THREE.Mesh(new THREE.SphereGeometry(.08, 8, 6), new THREE.MeshStandardMaterial({ color: [0xff5a7a, 0xffd84a, 0xffffff, 0xb45aff][Math.floor(rnd(0, 4))] })) : new THREE.Mesh(new THREE.ConeGeometry(.25, .9, 5), new THREE.MeshStandardMaterial({ color: 0x3f8f3a, flatShading: true }));
    else o = Math.random() < .5 ? new THREE.Mesh(new THREE.IcosahedronGeometry(rnd(.15, .4), 0), new THREE.MeshStandardMaterial({ color: 0x8a8d98, flatShading: true })) : new THREE.Mesh(new THREE.TorusGeometry(rnd(.3, .6), .06, 6, 16), new THREE.MeshStandardMaterial({ color: 0x9a9daa }));
    o.position.set(x, hgt(x) + (o.geometry.type === 'TorusGeometry' ? .01 : .05), -rnd(.5, 1.1)); if (o.geometry.type === 'TorusGeometry') o.rotation.x = Math.PI / 2; if (o.geometry.type === 'ConeGeometry') o.position.y += .4;
    grp.add(o);
  }
  return grp;
}
const coinMat = [new THREE.MeshStandardMaterial({ color: 0xffc21d, emissive: 0x8a5a00, emissiveIntensity: .5, roughness: .3, metalness: .3 }), new THREE.MeshStandardMaterial({ color: 0xff4d6d, emissive: 0x8a1030, emissiveIntensity: .5, roughness: .3, metalness: .3 })];
function addChunk() {
  const c = terrainChunk(chunkX, chunkX + 40); world.add(c); chunks.push({ m: c, x1: chunkX + 40 }); chunkX += 40;
  while (nextCoin < chunkX) {
    const n = Math.floor(rnd(4, 9)); for (let i = 0; i < n; i++) { const x = nextCoin + i * .75, m = new THREE.Mesh(new THREE.CylinderGeometry(.22, .22, .06, 18), coinMat[0]); m.rotation.x = Math.PI / 2; m.position.set(x, hgt(x) + .8, 0); world.add(m); items.push({ m, x, kind: 'coin', v: 5 }); }
    nextCoin += rnd(9, 20);
  }
  while (nextBig < chunkX) { const x = nextBig, m = new THREE.Mesh(new THREE.CylinderGeometry(.36, .36, .08, 20), coinMat[1]); m.rotation.x = Math.PI / 2; m.position.set(x, hgt(x) + 1, 0); world.add(m); items.push({ m, x, kind: 'coin', v: 25 }); nextBig += rnd(50, 90); }
  while (nextFuel < chunkX) {
    const x = nextFuel, m = new THREE.Group(), red = new THREE.MeshStandardMaterial({ color: 0xe8302e, roughness: .4 });
    m.add(new THREE.Mesh(new THREE.BoxGeometry(.45, .55, .28), red)); const cap = new THREE.Mesh(new THREE.CylinderGeometry(.06, .06, .14, 10), new THREE.MeshStandardMaterial({ color: 0xffd84a })); cap.position.set(.13, .33, 0); m.add(cap);
    const lab = new THREE.Mesh(new THREE.BoxGeometry(.3, .16, .3), new THREE.MeshStandardMaterial({ color: 0xffffff })); m.add(lab);
    m.position.set(x, hgt(x) + .5, 0); world.add(m); items.push({ m, x, kind: 'fuel' });
    nextFuel += rnd(110, 150) + Math.min(120, nextFuel * .05);
  }
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
    seat: seat ? new THREE.Vector3((seat.z - midz) * k - .05, (seat.y - midy) * k + .02, 0) : new THREE.Vector3(-.15 * st.wb, (box.max.y - midy) * k - .02, 0), roof: (box.max.y - midy) * k };
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
  G = { st, b: { x: 0, y: Math.max(u.wb.r - u.wb.y, u.wf.r - u.wf.y) + .05, a: 0, vx: 0, vy: 0, w: 0 }, fuel: st.tank, maxFuel: st.tank, gas: 0, dist: 0, coins: 0, over: false, ground: true, airT: 0, airRot: 0, stopT: 0, flipT: 0, spinB: 0, spinF: 0, paused: false };
  mode = 'run'; for (const s of ['#menu', '#over', '#paused']) $(s).hidden = true; for (const s of ['#hud', '#pedals', '#fuelBox']) $(s).hidden = false;
  $('#hBest').textContent = 'Récord ' + save.best[ST.id] + ' m';
  engineOn(true); SND.setMusic(false);
}
function physics(dt) {
  const g = G, b = g.b, st = g.st, u = car.userData, steps = 8, h = dt / steps, I = .2 * st.wb * st.wb, GR = ST.g;
  const gas = g.over || g.fuel <= 0 ? (g.gas < 0 && !g.over ? g.gas : 0) : g.gas;
  let any = false;
  for (let k2 = 0; k2 < steps; k2++) {
    let Fx = 0, Fy = -GR, Tq = 0, grounded = false;
    const ca = Math.cos(b.a), sa = Math.sin(b.a);
    for (const wh of [u.wb, u.wf]) {
      const rx = wh.x * ca - wh.y * sa, ry = wh.x * sa + wh.y * ca, wx = b.x + rx, wy = b.y + ry;
      const gy = hgt(wx), sl = slope(wx), L = Math.hypot(1, sl), nx = -sl / L, ny = 1 / L, tx = 1 / L, ty = sl / L;
      const pen = wh.r - (wy - gy) * ny;
      if (pen <= 0) continue;
      grounded = true;
      const vwx = b.vx - b.w * ry, vwy = b.vy + b.w * rx, vn = vwx * nx + vwy * ny, vt = vwx * tx + vwy * ty;
      const N = Math.max(0, st.k * Math.min(pen, wh.r * .8) - st.c * vn) + (pen > wh.r * .8 ? 400 * (pen - wh.r * .8) : 0);
      let Ft;
      if (gas > 0) Ft = st.engine * .5 * gas * Math.max(0, 1 - Math.max(0, vt) / st.vmax);
      else if (gas < 0) Ft = vt > .4 ? -st.engine * .55 : -st.engine * .2 * Math.max(0, 1 - Math.max(0, -vt) / (st.vmax * .35));
      else Ft = -vt * .6;
      Ft -= vt * .05;
      const lim = st.mu * N * (GR / 14 * .4 + .6); Ft = Math.max(-lim, Math.min(lim, Ft));
      const fx = N * nx + Ft * tx, fy = N * ny + Ft * ty;
      Fx += fx; Fy += fy; Tq += rx * fy - ry * fx;
      if (wh === u.wb) g.spinB += vt * h / wh.r; else g.spinF += vt * h / wh.r;
    }
    if (!grounded && gas) Tq += gas * st.air * ST.air * I;
    b.vx += Fx * h; b.vy += Fy * h; b.w += Tq / I * h; b.w *= 1 - 1.2 * h;
    b.x += b.vx * h; b.y += b.vy * h; b.a += b.w * h;
    any = any || grounded;
  }
  return { gas, grounded: any };
}
function bonus(txt) { const b = $('#bonus'); b.textContent = txt; b.classList.remove('on'); void b.offsetWidth; b.classList.add('on'); }
function step(dt) {
  const g = G, { gas, grounded } = physics(dt), b = g.b, u = car.userData;
  // saltos y volteretas
  if (!grounded) { g.airT += dt; g.airRot += g.b.w * dt; }
  else if (g.airT > 0) {
    if (!g.over) {
      const flips = Math.floor(Math.abs(g.airRot) / (Math.PI * 2) + .15);
      if (flips > 0) { const c2 = 100 * flips; g.coins += c2; bonus(`${flips > 1 ? flips + '× ' : ''}¡VOLTERETA! +${c2}`); S.levelup && S.levelup(); buzz('MEDIUM'); }
      else if (g.airT > 1.2) { const c2 = Math.round(g.airT * 10); g.coins += c2; bonus(`¡AIRE! ${g.airT.toFixed(1)} s +${c2}`); S.good && S.good(); }
    }
    g.airT = 0; g.airRot = 0;
  }
  if (!g.over) {
    g.fuel = Math.max(0, g.fuel - dt * (gas > 0 ? 3.0 : .9));
    g.dist = Math.max(g.dist, Math.floor(b.x));
    const ca = Math.cos(b.a), sa = Math.sin(b.a), hx = b.x + u.seat.x * ca - (u.roof + .35) * sa, hy = b.y + u.seat.x * sa + (u.roof + .35) * ca;
    if (hy < hgt(hx) + .05) end('¡VUELCO!');
    const sp = Math.hypot(b.vx, b.vy);
    if (g.fuel <= 0) { g.stopT = sp < .4 ? g.stopT + dt : 0; if (g.stopT > 1.5) end('¡SIN GASOLINA!'); }
    if (Math.cos(b.a) < -.3 && grounded) { g.flipT += dt; if (g.flipT > 1.5) end('¡VUELCO!'); } else g.flipT = 0;
    for (const it of items) {
      if (it.got) continue;
      if (it.kind === 'coin') it.m.rotation.z += dt * 4;
      if (Math.abs(it.x - b.x) < 1.1 && Math.abs(it.m.position.y - (b.y + .5)) < 1.3) {
        it.got = true; world.remove(it.m);
        if (it.kind === 'coin') { g.coins += it.v; S.coin(); PA.burst(it.m.position.x, it.m.position.y, 0, it.v > 5 ? 16 : 6, col(it.v > 5 ? 0xff6f8a : 0xffd84a), 1.5, .1, .4); }
        else { g.fuel = g.maxFuel; S.good && S.good(); buzz('MEDIUM'); bonus('¡GASOLINA!'); }
      }
    }
    items = items.filter(it => !it.got && it.x > b.x - 30);
  }
  while (chunkX < b.x + 70) addChunk();
  while (chunks.length && chunks[0].x1 < b.x - 40) world.remove(chunks.shift().m);
  // polvo
  if (gas > 0 && grounded && g.fuel > 0 && Math.random() < .6) { const ca = Math.cos(b.a), sa = Math.sin(b.a); PN.emit(b.x + u.wb.x * ca, b.y + u.wb.x * sa - .25, .5, -rnd(.5, 1.5), rnd(.3, 1), 0, col(ST.id === 'campo' ? 0xc9b08a : 0xcfd2dc), .3, .7, ST.g * .1, 1.2); }
  engineSound(gas, Math.hypot(b.vx, b.vy));
  // interfaz
  $('#hDist').textContent = g.dist + ' m'; $('#hCoins').textContent = g.coins;
  const fb = $('#fuelBar'); fb.style.width = (g.fuel / g.maxFuel * 100) + '%'; fb.classList.toggle('low', g.fuel < g.maxFuel * .22);
  $('.ped.gas').classList.toggle('on', g.gas > 0); $('.ped.brake').classList.toggle('on', g.gas < 0);
}
function end(why) {
  const g = G; if (g.over) return; g.over = true; g.why = why; S.bad && S.bad(); buzz('HEAVY'); engineOn(false);
  setTimeout(() => {
    const rec = g.dist > save.best[ST.id]; if (rec) save.best[ST.id] = g.dist;
    save.coins += g.coins; persist();
    $('#oWhy').textContent = why; $('#oDist').textContent = g.dist + ' m'; $('#oCoins').textContent = '+' + g.coins; $('#oBest').textContent = save.best[ST.id] + ' m'; $('#oRec').hidden = !rec;
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
  if (!eng) return; const a = SND.ac(), t = a.currentTime, f0 = 38 + sp * 5 + (gas > 0 ? 18 : 0);
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
    const look = V(b.x + 2.2 + clamp(b.vx * .12, 0, 2), b.y + 1, 0), d = camDist + clamp(Math.abs(b.vx) * .25, 0, 4);
    camPos.lerp(V(look.x, look.y + 1.8, d), Math.min(1, dt * 6)); camLook.lerp(look, Math.min(1, dt * 6));
  } else if (mode === 'menu' && car) {
    car.position.set(0, 0, 0); car.rotation.set(0, Math.sin(T * .5) * .5 + .3, 0);
    const u = car.userData; car.position.y = Math.max(u.wb.r - u.wb.y, u.wf.r - u.wf.y);
    seatPet(dt, 0);
    camPos.lerp(V(0, 2.2, 10), Math.min(1, dt * 4)); camLook.lerp(V(0, .55, 0), Math.min(1, dt * 4));
  }
  cam.position.copy(camPos); cam.lookAt(camLook);
  if (skyMesh) skyMesh.position.set(camLook.x, camLook.y + 8, -40);
  if (far) for (const o of far.children) { if (o.userData.base === undefined) o.userData.base = o.position.x; o.position.x = o.userData.base + camLook.x * (1 - o.userData.k); if (o.position.x < camLook.x - 70) o.userData.base += 140; o.position.y += (camLook.y * (1 - o.userData.k) - (o.userData.ly || 0)); o.userData.ly = camLook.y * (1 - o.userData.k); }
  PN.update(dt); PA.update(dt); FL.update(dt);
}
const clock = new THREE.Clock();
function loop() { requestAnimationFrame(loop); const dt = Math.min(1 / 30, clock.getDelta()); frame(dt); R.render(scene, cam); }

/* ---------- controles ---------- */
const touches = new Map();
function pedals() { let g = 0; for (const x of touches.values()) g = x > innerWidth / 2 ? 1 : (g === 1 ? 1 : -1); if (G) G.gas = g; }
addEventListener('touchstart', e => { if (mode !== 'run') return; for (const t of e.changedTouches) touches.set(t.identifier, t.clientX); pedals(); }, { passive: true });
addEventListener('touchmove', e => { if (mode !== 'run') return; for (const t of e.changedTouches) touches.set(t.identifier, t.clientX); pedals(); }, { passive: true });
addEventListener('touchend', e => { for (const t of e.changedTouches) touches.delete(t.identifier); pedals(); }, { passive: true });
addEventListener('touchcancel', e => { touches.clear(); pedals(); }, { passive: true });
addEventListener('keydown', e => { if (mode === 'run' && G) { if (e.key === 'ArrowRight') G.gas = 1; if (e.key === 'ArrowLeft') G.gas = -1; } });
addEventListener('keyup', e => { if (G && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) G.gas = 0; });

/* ---------- menú ---------- */
let stIdx = 0, carIdx = 0;
const bar = (v, m) => `<i style="width:${Math.min(100, v / m * 100)}%"></i>`;
let toastT = 0;
function toast(m) { const t = $('#toast'); t.textContent = m; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 1800); }
function pay(cost) { if (save.coins < cost) { toast(`Te faltan ${cost - save.coins} monedas`); S.err && S.err(); buzz('HEAVY'); return false; } save.coins -= cost; persist(); S.buy && S.buy(); buzz('MEDIUM'); return true; }
function renderStage() {
  const s = STAGES[stIdx], own = !!save.owned[s.id];
  $('#stName').textContent = s.name; $('#stInfo').textContent = `${s.info} · Récord ${save.best[s.id]} m`;
  const b = $('#stBuy'); b.hidden = own; b.innerHTML = `Desbloquear <span class="coin"></span>${s.price}`;
  b.onclick = () => { if (pay(s.price)) { save.owned[s.id] = true; save.sel.stage = s.id; persist(); toast(`¡${s.name} desbloqueada!`); renderAll(); } };
  if (own && save.sel.stage !== s.id) { save.sel.stage = s.id; persist(); }
  $('#playBtn').disabled = !own || !save.owned[CARS[carIdx].id];
  if (ST.id !== s.id && own) { ST = s; buildWorld(); }
}
async function renderCar() {
  const c = CARS[carIdx], own = !!save.owned[c.id], st = stats(c.id);
  $('#carName').textContent = c.name; $('#carDesc').textContent = c.desc;
  $('#carStats').innerHTML = [['Velocidad', st.vmax, 30], ['Fuerza', st.engine, 50], ['Agarre', st.mu, 2.6], ['Gasolina', st.tank, 200]].map(([n, v, m]) => `<div><small>${n}</small><span class="sb">${bar(v, m)}</span></div>`).join('');
  const ups = $('#carUps');
  ups.innerHTML = own ? UPG.map(u => { const lv = lvOf(c.id, u.id); return `<button class="garUp" data-u="${u.id}" ${lv >= 5 ? 'disabled' : ''}><b>${u.name}</b><span class="lvd">${[0, 1, 2, 3, 4].map(i => `<i class="${i < lv ? 'f' : ''}"></i>`).join('')}</span><em>${lv >= 5 ? 'Máx.' : `<span class="coin"></span>${upCost(lv)}`}</em></button>`; }).join('') : '<div class="garLock">Cómpralo para poder mejorarlo</div>';
  ups.querySelectorAll('[data-u]').forEach(b2 => b2.onclick = () => { const u = b2.dataset.u, lv = lvOf(c.id, u); if (!pay(upCost(lv))) return; save.lv[c.id] = save.lv[c.id] || {}; save.lv[c.id][u] = lv + 1; persist(); renderAll(); });
  const b = $('#carBuy'); b.hidden = own; b.innerHTML = `Comprar <span class="coin"></span>${c.price}`;
  b.onclick = () => { if (pay(c.price)) { save.owned[c.id] = true; save.sel.car = c.id; persist(); toast(`¡${c.name} comprado!`); renderAll(); } };
  if (own && save.sel.car !== c.id) { save.sel.car = c.id; persist(); }
  $('#playBtn').disabled = !own || !save.owned[STAGES[stIdx].id];
  if (carId !== c.id) await setCar(c.id);
}
function renderAll() { $('#mCoins').textContent = save.coins; renderStage(); renderCar(); }
const today = () => new Date().toISOString().slice(0, 10);
function toMenu() {
  mode = 'menu'; G = null; engineOn(false); touches.clear();
  for (const s of ['#over', '#paused', '#hud', '#pedals', '#fuelBox', '#settings']) $(s).hidden = true; $('#menu').hidden = false;
  stIdx = Math.max(0, STAGES.findIndex(s => s.id === save.sel.stage)); carIdx = Math.max(0, CARS.findIndex(c => c.id === save.sel.car));
  ST = STAGES[stIdx]; buildWorld(); $('#giftDot').hidden = save.daily.last === today(); renderAll(); SND.setMusic(true);
}
$$('.tab2').forEach(b => b.onclick = () => { $$('.tab2').forEach(x => x.classList.toggle('on', x === b)); $('#pStage').hidden = b.dataset.p !== 'stage'; $('#pCar').hidden = b.dataset.p !== 'car'; });
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
  const amt = 100 + Math.min(7, save.daily.streak) * 50; save.coins += amt; persist(); S.buy && S.buy(); toast(`+${amt} monedas · racha de ${save.daily.streak} día${save.daily.streak > 1 ? 's' : ''}`); $('#mCoins').textContent = save.coins; $('#giftDot').hidden = true;
};
$('#setBtn').onclick = () => { $('#optSfx').checked = save.opt.sfx; $('#optMusic').checked = save.opt.music; $('#optHaptic').checked = save.opt.haptic; $('#settings').hidden = false; };
$('#setClose').onclick = () => { $('#settings').hidden = true; };
for (const [id, k] of [['#optSfx', 'sfx'], ['#optMusic', 'music'], ['#optHaptic', 'haptic']]) $(id).onchange = e => { save.opt[k] = e.target.checked; Object.assign(SND.cfg, save.opt); persist(); if (k === 'music') SND.setMusic(true); };
document.addEventListener('visibilitychange', () => { if (document.hidden) { persist(); if (G && mode === 'run' && !G.over) { G.paused = true; $('#paused').hidden = false; } SND.suspend(true); } else SND.suspend(false); });

/* ---------- arranque ---------- */
async function boot() {
  resize();
  A = await M.loadAll({ gamba: 'models/char/gamba.glb', hood: 'models/char/gorro_tiburon.glb', kart: 'models/car/kart.glb' }, p => { $('#loadBar').style.width = Math.round(p * 100) + '%'; });
  carGltf.kart = A.kart;
  PN = new Particles(scene, 250, false, R.getPixelRatio()); PA = new Particles(scene, 300, true, R.getPixelRatio()); FL = new Floaters(scene);
  player = new M.Shrimp(A); scene.add(player.root); player.setSkin({ h: 0, s: 1, v: 1 }); await player.use('gamba');
  if (Q.has('coins')) save.coins = +Q.get('coins');
  if (Q.get('stage')) { save.sel.stage = Q.get('stage'); save.owned[Q.get('stage')] = true; }
  if (Q.get('car')) { save.sel.car = Q.get('car'); save.owned[Q.get('car')] = true; }
  $('#loading').hidden = true; toMenu(); requestAnimationFrame(loop);
  if (Q.has('shot')) testShot();
}
async function testShot() {
  document.head.insertAdjacentHTML('beforeend', '<style>*{animation:none!important;transition:none!important}</style>');
  await new Promise(r => setTimeout(r, (+Q.get('shot') || 1) * 1000));
  if (Q.has('play')) { await startRun(); const steps = +Q.get('steps') || 0; for (let i = 0; i < steps; i++) { if (G) G.gas = G.over ? 0 : (Math.cos(G.b.a) < .75 && G.b.a > 0 ? -1 : 1); frame(1 / 60); } }
  for (let i = 0; i < (+Q.get('frames') || 40); i++) frame(1 / 60);
  R.render(scene, cam);
  const im = $('#shotImg'); im.src = cv.toDataURL('image/png'); im.style.cssText = 'display:block;position:fixed;inset:0;width:100%;height:100%;z-index:4;pointer-events:none';
  document.title = 'LISTO ' + mode + (G ? ` x=${G.b.x.toFixed(0)} over=${G.over} ${G.why || ''}` : '');
  const d = document.createElement('div'); d.style.cssText = 'position:fixed;left:0;bottom:0;z-index:99;background:#fff;color:#000;font:11px monospace'; d.textContent = document.title; document.body.appendChild(d);
}
boot().catch(e => { document.body.insertAdjacentHTML('beforeend', `<pre style="position:fixed;top:0;z-index:999;background:#fff;color:red">${e.message}</pre>`); console.error(e); });
