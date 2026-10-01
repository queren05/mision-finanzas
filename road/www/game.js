// Shrimp Road: cruza carreteras, ríos y vías con tu gamba (estilo Crossy Road). Rejilla de casillas de 1 m:
// x = columna (-4..4 jugables), fila r hacia delante en z = -r. Cámara ortográfica en diagonal.
import * as THREE from './lib/three.module.min.js';
import * as M from './modelos.js';
import { Particles, Floaters } from './particulas.js';
import * as SND from './sonido.js';
import { CHARS, HATS, TABS, save, persist, owns } from './datos.js';

const Q = new URLSearchParams(location.search);
if (Q.has('shot')) addEventListener('error', e => { document.title = 'ERR ' + e.message; const d = document.createElement('pre'); d.style.cssText = 'position:fixed;top:0;z-index:999;background:#fff;color:red;font:11px monospace'; d.textContent = 'ERR ' + e.message + ' ' + e.lineno; document.body.appendChild(d); });
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const rnd = (a, b) => a + Math.random() * (b - a), irnd = (a, b) => Math.floor(rnd(a, b + 1)), clamp = (v, a, b) => Math.max(a, Math.min(b, v)), lerp = (a, b, t) => a + (b - a) * t;
const pick = a => a[Math.floor(Math.random() * a.length)];
const S = SND.S, buzz = SND.buzz;
Object.assign(SND.cfg, save.opt);
const HALF = 4, WIDE = 12;            // columnas jugables -4..4; el mundo se dibuja hasta ±12

/* ---------- motor ---------- */
const cv = $('#cv');
const R = new THREE.WebGLRenderer({ canvas: cv, antialias: true, preserveDrawingBuffer: Q.has('shot') });
R.shadowMap.enabled = !Q.has('noshadow'); R.shadowMap.type = THREE.PCFSoftShadowMap;
const scene = new THREE.Scene(); scene.background = new THREE.Color(0x7fc8ff);
const hemi = new THREE.HemisphereLight(0xffffff, 0x7a8a6a, 1.9); scene.add(hemi);
const sun = new THREE.DirectionalLight(0xfff2dc, 2.2); scene.add(sun); scene.add(sun.target);
sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048); Object.assign(sun.shadow.camera, { left: -14, right: 14, top: 14, bottom: -14, near: 1, far: 60 }); sun.shadow.bias = -.0008; sun.shadow.normalBias = .03;
const cam = new THREE.PerspectiveCamera(24, 1, 1, 200);
const VIEW_W = 10.6; let camDist = 30;
function resize() {
  const w = innerWidth, h = innerHeight, pr = Math.min(devicePixelRatio || 1, 2), a = w / h;
  R.setPixelRatio(pr); R.setSize(w, h, false);
  cam.aspect = a; cam.updateProjectionMatrix();
  // distancia para que quepan unas 10,6 casillas de ancho
  const tanH = Math.tan(THREE.MathUtils.degToRad(cam.fov) / 2) * a; camDist = (VIEW_W / 2) / tanH;
  if (PN) { PN.setPixelRatio(pr); PA.setPixelRatio(pr); }
}
addEventListener('resize', resize);
let PN = null, PA = null, FL = null;

/* ---------- modelos ---------- */
let A = {}, player, P = {};
const NAT = ['tree_blocks', 'tree_blocks_dark', 'tree_blocks_fall', 'tree_cone', 'rock_smallA', 'rock_largeA', 'stump_square', 'log_large', 'lily_large', 'flower_redA', 'flower_yellowA', 'plant_bush', 'grass'];
const CARS = ['sedan', 'taxi', 'police', 'suv', 'van', 'hatchback-sports', 'ambulance'], BIG = ['truck', 'garbage-truck'];
const TRAIN = ['train-electric-city-a', 'train-electric-city-b', 'railroad-straight'];
const RECOLOR = { grass: 0x5cb83a, dirt: 0x8d8579, woodBark: 0x7a5232, woodInner: 0xc9a06a, leafsDark: 0x3f8f2a, leafs: 0x5cb83a, leafsFall: 0xe08a2a };
function proto(name, { size, axis = 'y', recolor = true } = {}) {
  const o = A['k_' + name].scene.clone(true);
  o.traverse(m => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; if (recolor && RECOLOR[m.material.name] !== undefined) { m.material = m.material.clone(); m.material.color.setHex(RECOLOR[m.material.name]); } } });
  return M.normalize(o, axis === 'y' ? { height: size } : { length: size, axis });
}
async function loadAll() {
  const files = { gamba: 'models/char/gamba.glb', hood: 'models/char/gorro_tiburon.glb' };
  for (const n of [...NAT, ...CARS, ...BIG, ...TRAIN]) files['k_' + n] = 'models/k/' + n + '.glb';
  A = await M.loadAll(files, p => { $('#loadBar').style.width = Math.round(p * 100) + '%'; });
  P.trees = [proto('tree_blocks', { size: 1.7 }), proto('tree_blocks_dark', { size: 2.1 }), proto('tree_blocks_fall', { size: 1.8 }), proto('tree_cone', { size: 1.9 })];
  P.rocks = [proto('rock_smallA', { size: .55 }), proto('stump_square', { size: .6 })];
  P.deco = [proto('flower_redA', { size: .35 }), proto('flower_yellowA', { size: .35 }), proto('plant_bush', { size: .45 }), proto('grass', { size: .3 })];
  P.cars = CARS.map(n => proto(n, { size: 1.6, axis: 'z', recolor: false }));
  P.big = BIG.map(n => proto(n, { size: 2.6, axis: 'z', recolor: false }));
  P.log = proto('log_large', { size: 1, axis: 'x' });
  P.lily = proto('lily_large', { size: .85, axis: 'x' });
  P.loco = proto('train-electric-city-a', { size: 4, axis: 'z', recolor: false }); P.wagon = proto('train-electric-city-b', { size: 4.4, axis: 'z', recolor: false });
  P.track = proto('railroad-straight', { size: 4, axis: 'z', recolor: false });
}

/* ---------- materiales del suelo ---------- */
const matCache = {};
const mat = (c, o = {}) => { const k = c + JSON.stringify(o); return matCache[k] || (matCache[k] = new THREE.MeshStandardMaterial(Object.assign({ color: c, roughness: .9 }, o))); };
const LANE = { grass: [0x9ee05a, 0x92d64f], road: [0x4b505c, 0x4b505c], river: [0x3fb2f0, 0x3fb2f0], rail: [0x8e7f6c, 0x8e7f6c] };
const dark = c => new THREE.Color(c).multiplyScalar(.72).getHex();
const BOX = new THREE.BoxGeometry(1, 1, 1);
function slab(c, x0, x1, y0, y1, z, d = 1) { const m = new THREE.Mesh(BOX, mat(c)); m.scale.set(x1 - x0, y1 - y0, d); m.position.set((x0 + x1) / 2, (y0 + y1) / 2, z); m.receiveShadow = true; return m; }

/* ---------- mundo: filas ---------- */
let rows = new Map(), genState = null, world = null;
function laneType(r) {
  const g = genState;
  if (r < 4) return 'grass';
  if (g.left <= 0) {
    const d = Math.min(1, r / 160), prev = g.type;
    const opts = [['grass', 3], ['road', 3 + d * 2], ['river', 2 + d], ['rail', 1 + d]].filter(o => o[0] !== prev || o[0] === 'road');
    let tot = opts.reduce((a, o) => a + o[1], 0), x = Math.random() * tot; let t = opts[0][0];
    for (const o of opts) { if ((x -= o[1]) <= 0) { t = o[0]; break; } }
    g.type = t; g.left = { grass: irnd(1, 2), road: irnd(1, 3 + Math.round(d)), river: irnd(1, 3), rail: irnd(1, 2) }[t]; g.dir = Math.random() < .5 ? 1 : -1;
  }
  g.left--; return g.type;
}
function makeRow(r) {
  const type = laneType(r), z = -r, grp = new THREE.Group(), row = { r, type, grp, blocked: new Set(), cars: [], logs: [], lilies: new Set(), coins: [], train: null };
  const c = LANE[type][r & 1];
  if (type === 'river') {
    grp.add(slab(c, -HALF - .5, HALF + .5, -1, -.18, z), slab(dark(c), -WIDE, -HALF - .5, -1, -.18, z), slab(dark(c), HALF + .5, WIDE, -1, -.18, z));
  } else {
    grp.add(slab(c, -HALF - .5, HALF + .5, -1, 0, z), slab(dark(c), -WIDE, -HALF - .5, -1, 0, z), slab(dark(c), HALF + .5, WIDE, -1, 0, z));
  }
  const prevRow = rows.get(r - 1);
  if (type === 'grass') {
    // árboles fuera de la zona jugable y algún obstáculo dentro (nunca más de 3, y nunca en la columna central de las primeras filas)
    for (let x = -WIDE + 1; x <= WIDE - 1; x++) if (Math.abs(x) > HALF && Math.random() < .55) addProp(grp, pick(P.trees), x, z, rnd(.85, 1.15));
    if (r >= 2) { let n = Math.min(3, irnd(0, r < 6 ? 1 : 3)); for (let k = 0; k < 12 && n > 0; k++) { const x = irnd(-HALF, HALF); if (row.blocked.has(x) || (r < 6 && x === 0)) continue; row.blocked.add(x); addProp(grp, Math.random() < .75 ? pick(P.trees) : pick(P.rocks), x, z, rnd(.85, 1.1)); n--; } }
    for (let k = 0; k < 4; k++) { const x = rnd(-HALF, HALF); if (!row.blocked.has(Math.round(x))) addProp(grp, pick(P.deco), x, z + rnd(-.35, .35), rnd(.8, 1.2), false); }
  } else if (type === 'road') {
    const next = genState.left > 0;   // la siguiente también es carretera: línea discontinua
    if (next) for (let x = -WIDE; x < WIDE; x += 1.4) grp.add(slab(0xe8e8e8, x, x + .7, 0, .015, z - .5, .1));
    const dir = Math.random() < .5 ? 1 : -1, d = Math.min(1, r / 160), speed = rnd(1.6, 3) * (1 + d * .9), big = Math.random() < .2;
    let x = rnd(-WIDE, -WIDE + 3);
    const gap = big ? rnd(5, 8) : rnd(3.6, 7) - d * 1.2;
    while (x < WIDE) { const len = big ? 2.6 : 1.6, m = pick(big ? P.big : P.cars).clone(); m.rotation.y = dir > 0 ? Math.PI / 2 : -Math.PI / 2; m.position.set(x, 0, z); grp.add(m); row.cars.push({ m, x, len }); x += len + gap + rnd(0, 2.5); }
    Object.assign(row, { dir, speed });
  } else if (type === 'river') {
    const lily = prevRow && prevRow.type === 'river' && prevRow.logs.length && Math.random() < .3;
    if (lily) { const cols = new Set(); while (cols.size < irnd(2, 4)) cols.add(irnd(-HALF, HALF)); for (const x of cols) { row.lilies.add(x); addProp(grp, P.lily, x, z, 1, false).position.y = -.16; } }
    else {
      const dir = prevRow && prevRow.type === 'river' && prevRow.dir ? -prevRow.dir : (Math.random() < .5 ? 1 : -1), speed = rnd(1.1, 2.2);
      let x = -WIDE + rnd(0, 2);
      while (x < WIDE) { const len = irnd(2, 4), lg = new THREE.Group(); for (let i = 0; i < len; i++) { const p2 = P.log.clone(); p2.position.x = i - (len - 1) / 2; p2.traverse(o => { if (o.isMesh) o.castShadow = true; }); lg.add(p2); } lg.scale.set(1, 1.5, 1.55); lg.position.set(x + len / 2, -.36, z); grp.add(lg); row.logs.push({ m: lg, x: x + len / 2, len }); x += len + rnd(1.6, 3.2); }
      Object.assign(row, { dir, speed });
    }
  } else if (type === 'rail') {
    for (let x = -WIDE; x < WIDE; x += 4) { const t = P.track.clone(); t.rotation.y = Math.PI / 2; t.position.set(x + 2, 0, z); grp.add(t); }
    const pole = new THREE.Group(); pole.add(slab(0x555a66, -.06, .06, 0, 1.3, 0)); const lamp = new THREE.Mesh(new THREE.SphereGeometry(.13, 12, 10), new THREE.MeshStandardMaterial({ color: 0x551111, emissive: 0xff2222, emissiveIntensity: 0 })); lamp.position.y = 1.35; pole.add(lamp); pole.position.set(HALF + 1, 0, z + .42); grp.add(pole);
    row.train = { t: rnd(2, 6), state: 'wait', lamp, x: 0, dir: Math.random() < .5 ? 1 : -1, m: null };
  }
  // monedas
  if ((type === 'grass' || type === 'road') && Math.random() < .14) { const x = irnd(-HALF, HALF); if (!row.blocked.has(x)) { const cm = coinMesh(); cm.position.set(x, .45, z); grp.add(cm); row.coins.push({ x, m: cm }); } }
  world.add(grp); rows.set(r, row); return row;
}
function addProp(grp, proto0, x, z, s = 1, shadow = true) { const m = proto0.clone(); m.position.set(x, 0, z); m.rotation.y = Math.floor(Math.random() * 4) * Math.PI / 2; m.scale.multiplyScalar(s); if (!shadow) m.traverse(o => { if (o.isMesh) o.castShadow = false; }); grp.add(m); return m; }
let coinGeo = null;
function coinMesh() {
  coinGeo = coinGeo || new THREE.CylinderGeometry(.24, .24, .07, 20);
  const m = new THREE.Mesh(coinGeo, mat(0xffc21d, { emissive: 0x6a4a00, emissiveIntensity: .5, metalness: .4, roughness: .35 })); m.rotation.x = Math.PI / 2; m.castShadow = true; return m;
}
function trainMesh() { const g = new THREE.Group(), l = P.loco.clone(); g.add(l); for (let i = 1; i <= 3; i++) { const w = P.wagon.clone(); w.position.z = -i * 4.35; g.add(w); } return g; }

/* ---------- partida ---------- */
let G = null, mode = 'loading', T = 0;
const pet = { x: 0, z: 0, y: 0, yaw: 0, sx: 1, sy: 1 };
function newWorld() {
  if (world) scene.remove(world);
  world = new THREE.Group(); scene.add(world); rows = new Map(); genState = { left: 0, type: 'grass', dir: 1 };
  for (let r = -8; r < 24; r++) makeRow(r);
}
function startGame() {
  newWorld();
  G = { row: 0, col: 0, x: 0, maxRow: 0, score: 0, coins: 0, hop: null, queue: null, onLog: null, logOff: 0, dead: false, cam: 0, started: false, t: 0, idle: 0 };
  Object.assign(pet, { x: 0, z: 0, y: 0, yaw: 0, sx: 1, sy: 1 });
  mode = 'run'; for (const s of ['#menu', '#over', '#shop', '#paused']) $(s).hidden = true; $('#hud').hidden = false;
  updHud(); SND.setMusic(true);
}
function rowAt(r) { return rows.get(r); }
function blocked(c, r) { const row = rowAt(r); return !row || Math.abs(c) > HALF || row.blocked.has(c); }
function move(dc, dr) {
  if (mode !== 'run' || G.dead) return;
  if (G.hop) { G.queue = [dc, dr]; return; }
  const cur = G.onLog ? Math.round(G.x) : G.col, nc = cur + dc, nr = G.row + dr;
  pet.yaw = dr > 0 ? 0 : dr < 0 ? Math.PI : dc > 0 ? -Math.PI / 2 : Math.PI / 2;
  if (nr < G.maxRow - 4 || blocked(nc, nr)) { S.no ? S.no() : null; pet.sy = .75; return; }   // contra un árbol: solo un saltito
  G.started = true; G.idle = 0;
  G.hop = { t: 0, x0: G.x, z0: -G.row, x1: nc, z1: -nr, c: nc, r: nr };
  G.onLog = null; SND.tone(520 + Math.random() * 80, .07, 'triangle', .08, 260); buzz('LIGHT');
}
function land(h) {
  G.col = h.c; G.row = h.r; G.x = h.x1;
  const row = rowAt(G.row);
  if (G.row > G.maxRow) { G.maxRow = G.row; G.score = G.row; }
  pet.sy = .7;
  if (row.type === 'river') {
    if (row.lilies.has(G.col)) { G.x = G.col; return; }
    const lg = row.logs.find(l => Math.abs(G.x - l.x) <= l.len / 2 + .05);
    if (lg) { G.onLog = lg; G.logOff = clamp(Math.round(G.x - lg.x + (lg.len % 2 ? 0 : .5)) - (lg.len % 2 ? 0 : .5), -lg.len / 2 + .5, lg.len / 2 - .5); SND.noiseHit(.06, .08, 900); return; }
    return die('splash');
  }
  for (const cn of row.coins) if (cn.x === G.col && cn.m.visible) { cn.m.visible = false; G.coins++; save.coins++; S.coin(); PA.burst(cn.x, .6, -G.row, 10, new THREE.Color(0xffd84a), 1.6, .12, .5, 3); }
  updHud();
}
function die(why) {
  if (G.dead) return; G.dead = true; G.why = why; G.deadT = 0; buzz('HEAVY');
  if (why === 'squash') { S.bad(); pet.sy = .12; pet.sx = 1.5; }
  if (why === 'splash') { SND.noiseHit(.45, .25, 500); SND.tone(300, .3, 'sine', .1, -200); PN.burst(G.x, -.2, -G.row, 30, new THREE.Color(0xd6f4ff), 2.6, .14, .8, 6); }
  if (why === 'train') { S.bad(); G.fly = { vx: (rowAt(G.row).train.dir) * 9, vy: 7 }; }
  if (why === 'bird') { SND.tone(900, .5, 'sawtooth', .08, -500); }
  SND.setMusic(false);
}
function finish() {
  mode = 'over';
  const rec = G.score > save.best; if (rec) save.best = G.score; save.games++; persist();
  $('#oWhy').textContent = { squash: '¡ATROPELLADA!', splash: '¡AL AGUA!', train: '¡EL TREN!', bird: '¡LA GAVIOTA!', drift: '¡A LA DERIVA!' }[G.why] || '¡AY!';
  $('#oScore').textContent = G.score; $('#oCoins').textContent = '+' + G.coins; $('#oBest').textContent = save.best; $('#oRec').hidden = !rec;
  $('#hud').hidden = true; $('#over').hidden = false; if (rec) S.levelup && S.levelup();
}

/* ---------- gaviota (si te quedas atrás) ---------- */
let bird = null;
function makeBird() {
  const g = new THREE.Group(), w = mat(0xffffff), gr = mat(0xbfc8d4), y = mat(0xffb020);
  const body = new THREE.Mesh(new THREE.SphereGeometry(.45, 16, 12), w); body.scale.set(1.6, .8, .8); g.add(body);
  const head = new THREE.Mesh(new THREE.SphereGeometry(.28, 14, 10), w); head.position.set(.7, .25, 0); g.add(head);
  const beak = new THREE.Mesh(new THREE.ConeGeometry(.09, .35, 8), y); beak.rotation.z = -Math.PI / 2; beak.position.set(1.05, .2, 0); g.add(beak);
  for (const s of [-1, 1]) { const wing = new THREE.Mesh(new THREE.BoxGeometry(.9, .06, 1.6), gr); wing.position.set(0, .15, s * .9); wing.userData.s = s; g.add(wing); }
  g.traverse(o => { if (o.isMesh) o.castShadow = true; }); return g;
}

/* ---------- bucle ---------- */
function step(dt) {
  const g = G; g.t += dt;
  // tráfico, troncos y trenes
  for (const row of rows.values()) {
    if (row.type === 'road') for (const c of row.cars) { c.x += row.dir * row.speed * dt; if (c.x > WIDE + 2) c.x -= 2 * WIDE + 4; if (c.x < -WIDE - 2) c.x += 2 * WIDE + 4; c.m.position.x = c.x; }
    if (row.type === 'river') for (const l of row.logs) { l.x += row.dir * row.speed * dt; if (l.x > WIDE + 3) l.x -= 2 * WIDE + 6; if (l.x < -WIDE - 3) l.x += 2 * WIDE + 6; l.m.position.x = l.x; l.m.position.y = -.36 + Math.sin(T * 2 + l.x) * .02; }
    if (row.train) {
      const tr = row.train; tr.t -= dt;
      if (tr.state === 'wait' && tr.t < 1.4) { tr.state = 'warn'; if (Math.abs(row.r - g.row) < 6) { SND.tone(700, .25, 'square', .05); } }
      if (tr.state === 'warn') { tr.lamp.material.emissiveIntensity = (Math.floor(T * 6) % 2) ? 2 : .2; if (tr.t <= 0) { tr.state = 'go'; tr.x = -tr.dir * (WIDE + 4); tr.m = trainMesh(); tr.m.rotation.y = tr.dir > 0 ? Math.PI / 2 : -Math.PI / 2; tr.m.position.set(tr.x, 0, -row.r); row.grp.add(tr.m); if (Math.abs(row.r - g.row) < 7) { SND.tone(220, .6, 'sawtooth', .08); SND.tone(277, .6, 'sawtooth', .06); } } }
      if (tr.state === 'go') { tr.x += tr.dir * 30 * dt; tr.m.position.x = tr.x; tr.lamp.material.emissiveIntensity = (Math.floor(T * 6) % 2) ? 2 : .2; if (Math.abs(tr.x) > WIDE + 22) { row.grp.remove(tr.m); tr.m = null; tr.state = 'wait'; tr.t = rnd(4, 8); tr.lamp.material.emissiveIntensity = 0; } }
    }
    for (const cn of row.coins) cn.m.rotation.z += dt * 3;
  }
  if (g.dead) return;
  // salto
  if (g.hop) {
    const h = g.hop; h.t += dt / .14; const k = Math.min(1, h.t);
    g.x = lerp(h.x0, h.x1, k); pet.y = Math.sin(k * Math.PI) * .45;
    pet.z = lerp(h.z0, h.z1, k);
    if (k >= 1) { g.hop = null; pet.y = 0; land(h); if (g.queue && !g.dead) { const q = g.queue; g.queue = null; move(q[0], q[1]); } }
  } else pet.z = -g.row;
  // encima de un tronco
  if (g.onLog && !g.hop) { g.x = g.onLog.x + g.logOff; if (Math.abs(g.x) > HALF + 1.2) return die('drift'); }
  pet.x = g.x;
  // choques
  const row = rowAt(Math.round(-pet.z));
  if (row && row.type === 'road' && pet.y < .3) for (const c of row.cars) if (Math.abs(c.x - pet.x) < c.len / 2 + .25) { pet.z = -row.r; return die('squash'); }
  if (row && row.train && row.train.state === 'go' && Math.abs(row.train.x - row.train.dir * 6.5 - pet.x) < 8.7 && Math.abs(row.train.x - pet.x) < 9) { const tx = row.train.x, front = tx, back = tx - row.train.dir * 13.5; if ((pet.x - back) * (pet.x - front) <= .3) { pet.z = -row.r; return die('train'); } }
  // la cámara avanza sola: si te quedas atrás, baja la gaviota
  if (g.started) g.cam = Math.max(g.cam + dt * (.35 + Math.min(.45, g.maxRow / 300)), g.row - 2);
  if (g.started && g.row < g.cam - 3.2) return die('bird');
  // generar filas por delante y quitar las de atrás
  for (let r = g.row + 18; r < g.row + 26; r++) if (!rows.has(r)) makeRow(r);
  for (const [r, rw] of rows) if (r < g.row - 10) { world.remove(rw.grp); rows.delete(r); }
}
function frame(dt) {
  T += dt; M.SKIN.t.value = T;
  if (mode === 'run' && G) {
    if (!G.paused) step(dt);
    if (G.dead) {
      G.deadT += dt;
      if (G.why === 'splash') pet.y = Math.max(-1.2, pet.y - dt * 2.5);
      if (G.why === 'train' && G.fly) { G.x += G.fly.vx * dt; pet.x = G.x; G.fly.vy -= 20 * dt; pet.y = Math.max(0, pet.y + G.fly.vy * dt); pet.yaw += dt * 12; }
      if (G.why === 'drift') pet.x = G.x = G.onLog ? G.onLog.x + G.logOff : G.x;
      if (G.why === 'bird') {
        if (!bird) { bird = makeBird(); scene.add(bird); }
        const k = G.deadT; bird.position.set(pet.x + 6 - k * 6, 5 - Math.min(k, .9) * 4.6 + Math.max(0, k - 1) * 6, pet.z - 1 + Math.min(k, 1));
        bird.rotation.y = -Math.PI / 2 + .3; bird.children.forEach(c => { if (c.userData.s) c.rotation.x = Math.sin(T * 18) * .5 * c.userData.s; });
        if (k > 1) { pet.y = bird.position.y - .7; pet.x = bird.position.x; }
      }
      if (G.deadT > (G.why === 'bird' ? 2 : 1.2) && mode === 'run') { finish(); }
    }
    if (mode === 'run' && !G.dead) updHud();
  }
  // gamba
  const sc = player.cur ? 1.05 / player.cur.cfg.len : .7;
  pet.sx = lerp(pet.sx, G && G.dead && G.why === 'squash' ? 1.5 : 1, .25); pet.sy = lerp(pet.sy, G && G.dead && G.why === 'squash' ? .12 : 1, .2);
  player.root.position.set(pet.x, pet.y, pet.z);
  player.root.scale.setScalar(sc);
  player.root.rotation.y = lerp(player.root.rotation.y, pet.yaw + (mode === 'menu' || mode === 'shop' ? Math.sin(T * .8) * .6 + .5 : 0), .35);
  player.tilt.scale.set(pet.sx, pet.sy, pet.sx);
  player.pose(T * 6, G && G.hop ? 'jump' : 'idle', T, dt, 1);
  if (bird && !(G && G.dead && G.why === 'bird')) { scene.remove(bird); bird = null; }
  // cámara
  const fz = mode === 'run' && G ? -Math.max(G.cam, G.row - 1) : 0, fx = mode === 'run' && G ? clamp(pet.x * .6, -2, 2) : 0;
  const target = new THREE.Vector3(fx, 0, fz - 1.6);
  if (mode === 'menu') target.set(0, .3, 1.2); if (mode === 'shop') target.set(0, .3, 1.9);
  camLook.lerp(target, Math.min(1, dt * 5));
  const zoom = mode === 'menu' ? 3.2 : mode === 'shop' ? 3.6 : 1.3; camZoom = lerp(camZoom, zoom, Math.min(1, dt * 4));
  cam.position.copy(camLook).addScaledVector(CAM_DIR, camDist / camZoom); cam.lookAt(camLook);
  sun.position.copy(camLook).add(new THREE.Vector3(-6, 14, 8)); sun.target.position.copy(camLook);
  PN.update(dt); PA.update(dt); FL.update(dt);
}
const CAM_DIR = new THREE.Vector3(5.5, 16, 11).normalize(), camLook = new THREE.Vector3(0, 0, -2); let camZoom = 1;
const clock = new THREE.Clock();
function loop() { requestAnimationFrame(loop); const dt = Math.min(1 / 30, clock.getDelta()); frame(dt); R.render(scene, cam); }

/* ---------- controles ---------- */
let t0 = null;
addEventListener('touchstart', e => { if (mode !== 'run') return; const t = e.touches[0]; t0 = { x: t.clientX, y: t.clientY }; }, { passive: true });
addEventListener('touchend', e => {
  if (mode !== 'run' || !t0 || e.target.closest('button')) { t0 = null; return; }
  const t = e.changedTouches[0], dx = t.clientX - t0.x, dy = t.clientY - t0.y; t0 = null;
  if (Math.hypot(dx, dy) < 22) move(0, 1);
  else if (Math.abs(dx) > Math.abs(dy)) move(dx > 0 ? 1 : -1, 0);
  else move(0, dy < 0 ? 1 : -1);
}, { passive: true });
addEventListener('mousedown', e => { if (mode === 'run' && !e.target.closest('button') && !('ontouchstart' in window)) move(0, 1); });
addEventListener('keydown', e => { if (mode !== 'run') return; const f = { ArrowUp: [0, 1], ' ': [0, 1], ArrowDown: [0, -1], ArrowLeft: [-1, 0], ArrowRight: [1, 0] }[e.key]; if (f) { e.preventDefault(); move(...f); } });

/* ---------- interfaz ---------- */
function updHud() { $('#hScore').textContent = G ? G.score : 0; $('#hCoins').textContent = save.coins; }
let toastT = 0;
function toast(m) { const t = $('#toast'); t.textContent = m; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 1800); }
const today = () => new Date().toISOString().slice(0, 10);
function toMenu() {
  mode = 'menu'; G = null; newWorld(); Object.assign(pet, { x: 0, z: 0, y: 0, yaw: 0, sx: 1, sy: 1 });
  for (const s of ['#over', '#paused', '#shop', '#hud', '#settings']) $(s).hidden = true; $('#menu').hidden = false;
  $('#mCoins').textContent = save.coins; $('#mBest').textContent = save.best; $('#giftDot').hidden = save.daily.last === today();
  applyLook(); SND.setMusic(true);
}
async function applyLook(eq = save.eq) {
  const ch = CHARS.find(c => c.id === eq.chars) || CHARS[0];
  player.setSkin({ h: 0, s: 1, v: 1 }); player.hatId = eq.hats; await player.use(ch.model);
  player.root.traverse(o => { if (o.isMesh) o.castShadow = true; });
}
$('#playBtn').onclick = () => { SND.ac(); startGame(); };
$('#again').onclick = () => startGame();
$('#overMenu').onclick = toMenu;
$('#pauseBtn').onclick = () => { if (G && !G.dead) { G.paused = true; $('#paused').hidden = false; SND.setMusic(false); } };
$('#resume').onclick = () => { G.paused = false; $('#paused').hidden = true; clock.getDelta(); SND.setMusic(true); };
$('#quit').onclick = toMenu;
$('#giftBtn').onclick = () => {
  if (save.daily.last === today()) { toast('Vuelve mañana a por otro regalo'); return; }
  const y = new Date(Date.now() - 864e5).toISOString().slice(0, 10); save.daily.streak = save.daily.last === y ? save.daily.streak + 1 : 1; save.daily.last = today();
  const amt = 30 + Math.min(7, save.daily.streak) * 15; save.coins += amt; persist(); S.buy && S.buy(); toast(`+${amt} monedas · racha de ${save.daily.streak} día${save.daily.streak > 1 ? 's' : ''}`); $('#mCoins').textContent = save.coins; $('#giftDot').hidden = true;
};
$('#setBtn').onclick = () => { $('#optSfx').checked = save.opt.sfx; $('#optMusic').checked = save.opt.music; $('#optHaptic').checked = save.opt.haptic; $('#settings').hidden = false; };
$('#setClose').onclick = () => { $('#settings').hidden = true; };
for (const [id, k] of [['#optSfx', 'sfx'], ['#optMusic', 'music'], ['#optHaptic', 'haptic']]) $(id).onchange = e => { save.opt[k] = e.target.checked; Object.assign(SND.cfg, save.opt); persist(); if (k === 'music') SND.setMusic(true); };
document.addEventListener('visibilitychange', () => { if (document.hidden) { persist(); if (G && mode === 'run' && !G.dead) { G.paused = true; $('#paused').hidden = false; } SND.suspend(true); } else SND.suspend(false); });

/* tienda: la gamba del menú hace de escaparate */
let tab = 'chars', selId = null, preview = {};
$('#shopBtn').onclick = () => { mode = 'shop'; preview = {}; $('#menu').hidden = true; $('#shop').hidden = false; pickTab('chars'); };
$('#shopClose').onclick = () => { applyLook(); toMenu(); };
function pickTab(t) { tab = t; selId = preview[t] || save.eq[t]; $('#tabs').innerHTML = TABS.map(x => `<button class="tab ${x.id === tab ? 'on' : ''}" data-t="${x.id}">${x.name}</button>`).join(''); $('#tabs').querySelectorAll('.tab').forEach(b => b.onclick = () => pickTab(b.dataset.t)); renderGrid(); }
const CARD_COL = ['#ff8a5c', '#5fd6ff', '#ffd84a', '#b45aff', '#5fe37a', '#ff5aa5'];
function renderGrid() {
  const T0 = TABS.find(x => x.id === tab);
  $('#sCoins').textContent = save.coins;
  $('#grid').innerHTML = T0.list.map((it, i) => {
    const pr = save.eq[tab] === it.id ? '<span class="pr eq">EN USO</span>' : owns(tab, it.id) ? '<span class="pr own">Tuyo</span>' : `<span class="pr"><span class="coin"></span>${it.price}</span>`;
    return `<button class="it ${it.id === selId ? 'sel' : ''} ${owns(tab, it.id) ? '' : 'lock'}" data-id="${it.id}"><span class="th" style="background:linear-gradient(160deg,${CARD_COL[i % 6]},#1a2a4a)">${it.name.split(' ')[0]}</span><span class="nm">${it.name}</span>${pr}</button>`;
  }).join('');
  $('#grid').querySelectorAll('.it').forEach(b => b.onclick = () => { selId = b.dataset.id; preview[tab] = selId; applyLook(Object.assign({}, save.eq, preview)); renderGrid(); });
  const it = T0.list.find(x => x.id === selId) || T0.list[0], btn = $('#dBtn');
  $('#dName').textContent = it.name; $('#dDesc').textContent = it.desc || '';
  btn.disabled = false;
  if (save.eq[tab] === it.id) { btn.textContent = 'En uso'; btn.disabled = true; btn.onclick = null; }
  else if (owns(tab, it.id)) { btn.textContent = 'Usar'; btn.onclick = () => { save.eq[tab] = it.id; persist(); renderGrid(); }; }
  else { btn.innerHTML = `Comprar <span class="coin"></span>${it.price}`; btn.onclick = () => { if (save.coins < it.price) { toast(`Te faltan ${it.price - save.coins} monedas`); S.err && S.err(); return; } save.coins -= it.price; save.owned[tab + ':' + it.id] = true; save.eq[tab] = it.id; persist(); S.buy && S.buy(); toast('¡Comprado!'); renderGrid(); }; }
}

/* ---------- arranque ---------- */
async function boot() {
  resize();
  await loadAll();
  PN = new Particles(scene, 200, false, R.getPixelRatio()); PA = new Particles(scene, 300, true, R.getPixelRatio()); FL = new Floaters(scene);
  player = new M.Shrimp(A); scene.add(player.root);
  if (Q.has('coins')) save.coins = +Q.get('coins');
  await applyLook();
  $('#loading').hidden = true;
  toMenu();
  requestAnimationFrame(loop);
  if (Q.has('play')) startGame();
  if (Q.has('shot')) testShot();
}
function testShot() {
  document.head.insertAdjacentHTML('beforeend', '<style>*{animation:none!important;transition:none!important}</style>');
  setTimeout(() => {
    const moves = (Q.get('moves') || '').split('');
    for (const m of moves) { move(...({ u: [0, 1], d: [0, -1], l: [-1, 0], r: [1, 0] }[m] || [0, 1])); for (let i = 0; i < 12; i++) frame(1 / 60); }
    for (let i = 0; i < (+Q.get('frames') || 60); i++) frame(1 / 60);
    R.render(scene, cam); const gl = R.getContext(), px = new Uint8Array(4); gl.readPixels(Math.floor(cv.width / 2), Math.floor(cv.height / 2), 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px); document.body.dataset.px = px.join(',') + ' err' + gl.getError() + ' cv' + cv.width + 'x' + cv.height;
    const im = $('#shotImg'); im.src = cv.toDataURL('image/png'); im.style.cssText = 'display:block;position:fixed;inset:0;width:100%;height:100%;z-index:4;pointer-events:none';
    const _p = new THREE.Vector3(0, 0, 0).project(cam); const _ri = R.info.render; document.body.dataset.ndc = _p.toArray().map(v=>v.toFixed(2)) + ' bg' + scene.background.getHexString() + ' ch' + scene.children.length; const _b = new THREE.Box3().setFromObject(world); document.title = `calls${_ri.calls} tris${_ri.triangles} box${_b.min.toArray().map(v=>v.toFixed(0))}/${_b.max.toArray().map(v=>v.toFixed(0))} w${world ? world.children.length : -1} ` + 'LISTO ' + mode + (G ? ` row=${G.row} dead=${G.dead} ${G.why || ''}` : '');
    const d = document.createElement('div'); d.style.cssText = 'position:fixed;left:0;bottom:0;z-index:99;background:#fff;color:#000;font:11px monospace'; d.textContent = document.title + ' ndc' + document.body.dataset.ndc + ' px' + document.body.dataset.px; document.body.appendChild(d);
  }, (+Q.get('shot') || 1) * 1000);
}
boot().catch(e => { $('#loadTxt').textContent = 'Error: ' + e.message; console.error(e); });
