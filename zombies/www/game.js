// Shrimp Zombies: supervivencia por rondas al estilo de los zombis del Black Ops, con una gamba armada.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import { Shrimp, PLAYERS } from './modelos.js';
import { Particles } from './particulas.js';
import * as MAP from './mapa.js';
import { buildBuildings } from './edificios.js';
import { RGBELoader } from './lib/RGBELoader.js';
import { Zombie, flow, resetFlow, separate, collide, roundCount, roundHp, roundSpeed, REAL, RUNNER, CITY as CITYZ } from './zombis.js';
import { GUNS, BOX_POOL, PERKS, PU_NAME } from './armas.js';
import { S, ambient, cfg as AUD, tone } from './audio.js';
import { EffectComposer } from './lib/EffectComposer.js';
import { RenderPass } from './lib/RenderPass.js';
import { UnrealBloomPass } from './lib/UnrealBloomPass.js';
import { OutputPass } from './lib/OutputPass.js';
import { ShaderPass } from './lib/ShaderPass.js';
import { I, opts, poll, bindTouch, resetTouch, setMenu, key, rumble, lockPointer, unlockPointer, onDevice, setNavSound, touchAim, pad } from './controles.js';

const $ = id => document.getElementById(id);
if (location.search.includes('shot')) addEventListener('error', e => { const d = document.createElement('div'); d.style.cssText = 'position:fixed;top:0;left:0;right:0;color:#f55;z-index:99;font:12px monospace;background:#000c;padding:4px'; d.textContent = e.message + ' @' + (e.filename || '').split('/').pop() + ':' + e.lineno; document.body.appendChild(d); });
const Q = new URLSearchParams(location.search);
const V3 = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
const rnd = (a, b) => a + Math.random() * (b - a);
const { clamp, lerp } = THREE.MathUtils;

/* ---------- guardado ---------- */
const LS = {
  get(k, d) { try { const v = localStorage.getItem('zomb.' + k); return v === null ? d : JSON.parse(v); } catch (e) { return d; } },
  set(k, v) { try { localStorage.setItem('zomb.' + k, JSON.stringify(v)); } catch (e) { } },
};
const save = { bests: LS.get('bests', { nacht: LS.get('best', 0) }), map: LS.get('map', 'nacht'), char: LS.get('char', 'gamba'), opt: Object.assign({ sens: 1, invertY: false, assist: true, sfx: true, music: true }, LS.get('opt', {})) };
function applyOpts() { Object.assign(opts, { sens: save.opt.sens, invertY: save.opt.invertY, assist: save.opt.assist }); AUD.sfx = save.opt.sfx; AUD.music = save.opt.music; }
applyOpts();

/* ---------- motor ---------- */
const cv = $('cv');
const renderer = new THREE.WebGLRenderer({ canvas: cv, antialias: devicePixelRatio < 2.5, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.7));
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.15;
const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0x0b1020, 9, 44);
const camera = new THREE.PerspectiveCamera(66, 1, .05, 140);
function resize() { renderer.setSize(innerWidth, innerHeight, false); camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); if (composer) { composer.setSize(innerWidth, innerHeight); bloom.resolution.set(innerWidth / 2, innerHeight / 2); } }
/* ---------- posprocesado: resplandor, viñeta y un poco de color de cine ---------- */
let composer = null, bloom = null;
const GRADE = { uniforms: { tDiffuse: { value: null }, vig: { value: .55 }, hurt: { value: 0 } }, vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: `uniform sampler2D tDiffuse; uniform float vig; uniform float hurt; varying vec2 vUv;
  void main(){ vec4 c = texture2D(tDiffuse, vUv); vec2 d = vUv - .5; float v = 1. - dot(d, d) * vig * 1.9;
    float l = dot(c.rgb, vec3(.299, .587, .114)); c.rgb = mix(vec3(l), c.rgb, 1.12 - hurt * .6); c.rgb *= v; c.rgb = mix(c.rgb, c.rgb * vec3(1.05, .98, .92), .5); c.r += hurt * .06 * (1. - v); gl_FragColor = c; }` };
let gradePass = null;
function setupFX() {
  composer = new EffectComposer(renderer); composer.addPass(new RenderPass(scene, camera));
  bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth / 2, innerHeight / 2), .6, .45, .78); composer.addPass(bloom);
  gradePass = new ShaderPass(GRADE); composer.addPass(gradePass); composer.addPass(new OutputPass()); resize();
}
addEventListener('resize', resize); resize();

const hemi = new THREE.HemisphereLight(0x8090c0, 0x2a2018, 1.0); scene.add(hemi);
const moon = new THREE.DirectionalLight(0xb0c0ff, 1.5); scene.add(moon, moon.target);
moon.castShadow = true; moon.shadow.mapSize.set(2048, 2048); moon.shadow.bias = -.0012; moon.shadow.normalBias = .04;
// una lámpara por zona; con la corriente se encienden del todo
let LAMPS = [];
const muzzleLight = new THREE.PointLight(0xffc070, 0, 8, 2); scene.add(muzzleLight);
const boomLight = new THREE.PointLight(0xff8a3a, 0, 12, 2); scene.add(boomLight);
const fx = new Particles(scene, 900, false, renderer.getPixelRatio());
const glow = new Particles(scene, 500, true, renderer.getPixelRatio());

/* ---------- carga ---------- */
const loader = new GLTFLoader();
const KITS = ['character-zombie', 'character-skeleton', 'blaster-l', 'blaster-a',
  'gravestone-cross', 'gravestone-round', 'gravestone-broken', 'grave', 'pine', 'pine-crooked', 'lightpost-single', 'fire-basket', 'iron-fence', 'crate-medium', 'crate-small', 'crypt-door',
  'candle-multiple', 'pumpkin-carved', 'rocks', 'debris-wood', 'coffin', 'lantern-candle', 'grenade-a', 'palm-bend', 'palm-straight', 'rocks-a', 'barrel'];
const CITY = [...'abcdefghijklmn'].map(c => 'building-' + c).concat(['building-skyscraper-a', 'building-skyscraper-c', 'building-skyscraper-e', 'tree-large', 'tree-small', 'dumpster', 'light-curved', 'traffic-light', 'construction-barrier', 'construction-cone', 'planter', 'car-sedan', 'car-taxi', 'car-police', 'car-van', 'car-suv', 'car-truck', 'car-ambulance']);
const PROPS = ['street_lamp_01', 'street_lamp_02', 'metal_trash_can', 'utility_box_01', 'utility_box_02', 'water_manhole_cover', 'old_tyre', 'covered_car', 'barrel_stove', 'trashbag', 'rusted_wheel_rim_01', 'Barrel_01', 'WetFloorSign_01', 'fire_hydrant', 'concrete_road_barrier_02'].map(n => 'p_' + n);   // Poly Haven (CC0)
const GUN_FILES = [...new Set(Object.values(GUNS).map(g => g.model).filter(m => m.startsWith('g/')))];
const K = {}, CH = {};
async function loadAll() {
  const jobs = KITS.map(n => [n, 'models/k/' + n + '.glb']).concat([['zombie_real', 'models/z/zombie_real.glb'], ['zombie_runner', 'models/z/zombie_runner.glb'], ['zombie_city', 'models/z/zombie_city.glb']]).concat(CITY.map(n => [n, 'models/c/' + n + '.glb'])).concat(PROPS.map(n => [n, 'models/p/' + n.slice(2) + '.glb'])).concat(GUN_FILES.map(n => [n, 'models/' + n + '.glb'])).concat([['gamba', PLAYERS.gamba.file]]);
  let done = 0;
  await Promise.all(jobs.map(([n, url]) => new Promise((ok, ko) => loader.load(url, g => { if (n === 'gamba') CH.gamba = g; else K[n] = g; $('loadBar').style.width = (++done / jobs.length * 100) + '%'; ok(); }, undefined, ko))));
}
// árboles reales de Poly Haven convertidos en dos planos cruzados con su foto (los originales tienen millones de triángulos)
const TREES = {};
async function loadTrees() {
  const info = await (await fetch('models/i/info.json')).json(), L = new THREE.TextureLoader();
  await Promise.all(Object.entries(info).map(async ([k, v]) => {
    const tx = await Promise.all([0, 1].map(i => new Promise(ok => L.load(`models/i/${k}_${i}.png`, t => { t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; ok(t); }, undefined, () => ok(null)))));
    if (tx[0] && tx[1]) TREES[k] = { v, mats: tx.map(map => new THREE.MeshStandardMaterial({ map, alphaTest: .45, side: THREE.DoubleSide, roughness: 1, metalness: 0 })) };
  }));
}
function tree(name, x, z, ry = 0, h = 5) {
  const T = TREES[name]; if (!T) return null;
  const g = new THREE.Group(), s = h / T.v.h, w = T.v.w * s;
  T.mats.forEach((m, i) => { const p = new THREE.Mesh(new THREE.PlaneGeometry(w, h), m); p.position.y = h / 2; if (i) p.rotation.y = Math.PI / 2; g.add(p); });
  g.position.set(x, 0, z); g.rotation.y = ry; level.add(g); return g;
}
function kit(name, x, z, ry = 0, s = 1, y = 0, parent) {
  const o = K[name].scene.clone(true); o.position.set(x, y, z); o.rotation.y = ry; o.scale.setScalar(s);
  o.traverse(m => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
  (parent || level).add(o); return o;
}

/* ---------- escenario ---------- */
let level = null, SKY = new THREE.Color(0x0b1020);
function block(x, z, on = true) { MAP.grid[MAP.idx(x, z)] = on ? MAP.PROP : MAP.FLOOR; }
function canvasTex(w, h, draw) { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; return t; }
const ryOf = f => Math.atan2(f[0], f[1]);
function buildWorld(mapId) {
  if (level) { scene.remove(level); level = null; }
  for (const l of LAMPS) scene.remove(l); LAMPS = []; machines.length = 0;
  MAP.loadMap(mapId); resetFlow();
  const T = MAP.theme(), W = MAP.GW, H = MAP.GH;
  hemi.intensity = 1.0; moon.intensity = 1.5;
  SKY = new THREE.Color(T.sky); scene.background = SKY; scene.fog = new THREE.Fog(SKY, 9, 44);
  moon.position.set(W / 2 - 10, 28, H / 2 - 14); moon.target.position.set(W / 2, 0, H / 2);
  const R = Math.max(W, H) / 2 + 2; Object.assign(moon.shadow.camera, { left: -R, right: R, top: R, bottom: -R, near: 2, far: 80 }); moon.shadow.camera.updateProjectionMatrix();
  hemi.color.set(T.wall === 'planks' ? 0x7a9ad0 : 0x8090c0);
  level = MAP.buildLevel(scene);
  for (const w of MAP.WINDOWS) MAP.buildBoards(level, w);
  for (const d of MAP.DOORS) MAP.buildDoor(level, d);
  // vallas
  const isBar = (x, z) => [MAP.FENCE, MAP.WALL, MAP.WIN].includes(MAP.cellAt(x, z));
  for (let z = 0; z < H; z++) for (let x = 0; x < W; x++) {
    if (MAP.grid[MAP.idx(x, z)] !== MAP.FENCE) continue;
    const alongX = isBar(x - 1, z) || isBar(x + 1, z);
    if (T.city) { kit('construction-barrier', x + .5, z + .5, alongX ? Math.PI / 2 : 0, 4.8); continue; }
    const o = tint(kit('iron-fence', x + .5, z + .5, alongX ? 0 : Math.PI / 2, 1, 0), T.fence); o.scale.set(1.02, 2, 1.4); o.children[0] && o.children[0].position.set(0, 0, .32);
  }
  const postMat = new THREE.MeshStandardMaterial({ color: T.fence, roughness: .6, metalness: .4 });
  for (const w of MAP.WINDOWS) if (w.fence) { const alongZ = w.inn[0] !== w.x; for (const s of [-.5, .5]) { const p = new THREE.Mesh(new THREE.BoxGeometry(.12, 2.2, .12), postMat); p.position.set(w.x + .5 + (alongZ ? 0 : s), 1.1, w.z + .5 + (alongZ ? s : 0)); p.castShadow = true; level.add(p); } }
  // adornos que bloquean (L) y cajas (p)
  const crateMat = new THREE.MeshStandardMaterial({ map: MAP.TEX.wood, color: 0xb08a60, roughness: .9 });
  const crate = (x, z, r, big) => { const c = new THREE.Mesh(new THREE.BoxGeometry(.85, .85, .85), crateMat); c.position.set(x + .5, .425, z + .5); c.rotation.y = r; c.castShadow = c.receiveShadow = true; level.add(c); if (big) { const c2 = new THREE.Mesh(new THREE.BoxGeometry(.55, .55, .55), crateMat); c2.position.set(x + .5, 1.12, z + .5); c2.rotation.y = r + .5; c2.castShadow = true; level.add(c2); } };
  const rng = mulberry(MAP.MAPID.length * 7 + 3);
  if (T.city) buildCity(rng);
  for (const o of MAP.OBJ.props) {
    if (T.city) { cityProp(o, rng); continue; }
    if (o.kind === 'p') { crate(o.x, o.z, rng() * .6, true); if (MAP.CFG.theme === 'nacht') kit('candle-multiple', o.x + .5, o.z + .5, 0, 1.6, 1.4); }
    else if (MAP.CFG.theme === 'nacht') kit(['gravestone-cross', 'gravestone-round', 'gravestone-broken'][Math.floor(rng() * 3)], o.x + .5, o.z + .5, rng() - .5, 1.7);
    else if (MAP.CFG.theme === 'fabrica') { crate(o.x, o.z, rng(), true); kit('barrel', o.x + .5 + .3, o.z + .5 - .3, 0, .35); }
    else kit(rng() < .5 ? 'palm-bend' : 'palm-straight', o.x + .5, o.z + .5, rng() * 6, .55);
  }
  // tumbas por donde salen zombis
  for (const g of MAP.OBJ.graves) {
    if (MAP.CFG.theme === 'nacht') tint(kit('grave', g.x + .5, g.z + .5, rng() * 3, 1.6), 0x6a5444);
    else if (T.city && K.p_water_manhole_cover) { const m = kit('p_water_manhole_cover', g.x + .5, g.z + .5, rng() * 6, 1.25); m.position.y = .01; }
    else if (MAP.CFG.theme === 'fabrica' || T.city) { const m = new THREE.Mesh(new THREE.CylinderGeometry(.45, .45, .04, 20), new THREE.MeshStandardMaterial({ color: 0x2a2a2e, metalness: .6, roughness: .5 })); m.position.set(g.x + .5, .02, g.z + .5); level.add(m); }
    else { const m = new THREE.Mesh(new THREE.SphereGeometry(.5, 12, 6, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshStandardMaterial({ color: 0xa89060, roughness: 1 })); m.scale.y = .25; m.position.set(g.x + .5, 0, g.z + .5); level.add(m); }
  }
  // calles: basura, neumáticos, barriles y señales sueltos junto a los edificios (decoración, no bloquea)
  if (T.city && K.p_trashbag) {
    const junk = [['p_trashbag', .9], ['p_old_tyre', 1.1], ['p_barrel_stove', 1.1], ['p_Barrel_01', 1.1], ['p_WetFloorSign_01', 1.2], ['p_rusted_wheel_rim_01', 1.1], ['p_concrete_road_barrier_02', 1.2]];
    for (let i = 0, n = 0; i < 900 && n < 70; i++) {
      const x = 2 + Math.floor(rng() * (W - 4)), z = 2 + Math.floor(rng() * (H - 4));
      if (MAP.cellAt(x, z) !== MAP.FLOOR || MAP.chAt(x, z) !== 'A') continue;
      if (![[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dz]) => MAP.cellAt(x + dx, z + dz) === MAP.BLD)) continue;   // pegado a un edificio
      const [nm, s] = junk[Math.floor(rng() * junk.length)];
      kit(nm, x + .2 + rng() * .6, z + .2 + rng() * .6, rng() * 6, s); n++;
    }
  }
  // exterior: árboles, rocas o cajas alrededor
  if (T.city) {   // horizonte: solares sueltos alrededor del mapa, con los mismos edificios
    if (MAP.PBR.brick) { const far = []; for (let i = 0; i < 46; i++) { const w = 5 + Math.floor(rng() * 6), d = 5 + Math.floor(rng() * 6); let x, z; do { x = Math.floor(-22 + rng() * (W + 44)); z = Math.floor(-22 + rng() * (H + 44)); } while (x + w > -2 && x < W + 2 && z + d > -2 && z < H + 2); far.push({ x0: x, z0: z, x1: x + w - 1, z1: z + d - 1 }); } buildBuildings(level, far, rng); }
    else for (let i = 0; i < 70; i++) { let x, z; do { x = -18 + rng() * (W + 36); z = -18 + rng() * (H + 36); } while (x > 1 && x < W - 1 && z > 1 && z < H - 1); const n = CITY[Math.floor(rng() * 17)]; kit(n, x, z, Math.floor(rng() * 4) * Math.PI / 2, 4 + rng() * 2); }
  }
  else for (let i = 0; i < 90; i++) {
    let x, z; do { x = -16 + rng() * (W + 32); z = -16 + rng() * (H + 32); } while (x > -.5 && x < W + .5 && z > -.5 && z < H + .5);
    if (MAP.CFG.theme === 'isla' && (Math.hypot(x - W / 2, z - H / 2) > Math.max(W, H) * .72)) continue;
    if (MAP.CFG.theme === 'fabrica' && rng() < .5) { kit(rng() < .5 ? 'barrel' : 'crate-medium', x, z, rng() * 6, rng() < .5 ? .5 : 1.4); continue; }
    const nm = T.trees[Math.floor(rng() * T.trees.length)], isla = MAP.CFG.theme === 'isla';
    if (!tree(isla ? (rng() < .5 ? 'island_tree_01' : 'island_tree_02') : 'fir_sapling_medium', x, z, rng() * 6, isla ? 4 + rng() * 2 : 7 + rng() * 4)) kit(nm, x, z, rng() * 6, isla ? .5 + rng() * .3 : 1.7 + rng() * 1.2);
  }
  if (!T.city) for (let i = 0; i < 16; i++) { let x, z; do { x = -6 + rng() * (W + 12); z = -6 + rng() * (H + 12); } while (x > -1 && x < W + 1 && z > -1 && z < H + 1); kit(MAP.CFG.theme === 'isla' ? 'rocks-a' : 'rocks', x, z, rng() * 6, MAP.CFG.theme === 'isla' ? .25 : 1.5 + rng()); }
  // lámparas: una por zona
  const bulbMat = new THREE.MeshStandardMaterial({ color: 0xfff0c0, emissive: T.lamp, emissiveIntensity: .3 });
  cityLamps = [];
  if (T.city) {
    hemi.intensity = 1.5; moon.intensity = 2.1; hemi.color.set(0x9aa8d8);
    MAP.OBJ.props.filter(o => o.kind === 'l').forEach((o, i) => {
      const col = i % 7 === 3 ? 0x6ad8ff : i % 7 === 5 ? 0xff7ad0 : 0xffc880, x = o.x + .5, z = o.z + .5;
      const pool = new THREE.Mesh(poolGeo, new THREE.MeshBasicMaterial({ map: poolTex, color: col, transparent: true, opacity: .55, blending: THREE.AdditiveBlending, depthWrite: false })); pool.position.set(x, .09, z); pool.renderOrder = 2; level.add(pool);
      const bulb = new THREE.Sprite(new THREE.SpriteMaterial({ map: poolTex, color: col, blending: THREE.AdditiveBlending, depthWrite: false })); bulb.position.set(x, 3.85, z); bulb.scale.setScalar(1.1); level.add(bulb);
      cityLamps.push({ x, z, col });
    });
    // un grupo de luces de verdad que se reparte entre las farolas más cercanas
    for (let i = 0; i < 10; i++) { const l = new THREE.PointLight(0xffc880, 9, 15, 1.3); l.userData.street = true; scene.add(l); LAMPS.push(l); }
    updCityLights(true);
  }
  if (!T.city) for (const Zn of MAP.ZONES) {
    const x = (Zn.x0 + Zn.x1 + 1) / 2, z = (Zn.z0 + Zn.z1 + 1) / 2, l = new THREE.PointLight(Zn.outside ? 0xff8a4a : T.lamp, 0, Math.max(14, (Zn.x1 - Zn.x0 + Zn.z1 - Zn.z0) * .7), 1.4);
    l.position.set(x, Zn.outside ? 1.6 : 2.35, z); scene.add(l); LAMPS.push(l); l.userData.out = Zn.outside;
    if (Zn.outside) { if (MAP.CFG.theme === 'fabrica') kit('lightpost-single', x, z, 0, 1.8); else kit('fire-basket', x, z, 0, 2.2); l.userData.fire = true; MAP.grid[MAP.idx(Math.floor(x), Math.floor(z))] = MAP.PROP; }
    else { const b = new THREE.Mesh(new THREE.SphereGeometry(.12, 12, 8), bulbMat); b.position.copy(l.position); level.add(b); const c = new THREE.Mesh(new THREE.CylinderGeometry(.01, .01, .4), new THREE.MeshBasicMaterial({ color: 0x111111 })); c.position.set(x, l.position.y + .3, z); level.add(c); }
  }
  world.bulbMat = bulbMat;
  buildPerks(); buildWallBuys(); buildBox(); buildPap(); buildPower(); buildEggs();
}
const SIZE = {};
function sizeOf(n) { if (!SIZE[n]) { const o = K[n].scene; o.updateMatrixWorld(true); SIZE[n] = new THREE.Box3().setFromObject(o).getSize(V3()); } return SIZE[n]; }
// edificios de Kenney ajustados a cada solar
function buildCity(rng) {
  if (MAP.PBR.brick) return buildBuildings(level, MAP.OBJ.buildings, rng);   // edificios con fachadas PBR; los de Kenney quedan de reserva
  const tall = ['building-skyscraper-a', 'building-skyscraper-c', 'building-skyscraper-e'], wide = ['building-j', 'building-k', 'building-n', 'building-e'], sq = [...'abcdfghilm'].map(c => 'building-' + c);
  for (const b of MAP.OBJ.buildings) {
    const w = b.x1 - b.x0 + 1, d = b.z1 - b.z0 + 1, ratio = Math.max(w, d) / Math.min(w, d);
    const pool = ratio > 1.6 ? wide : rng() < .18 ? tall : sq, n = pool[Math.floor(rng() * pool.length)], sz = sizeOf(n);
    const rot = (w >= d) === (sz.x >= sz.z) ? 0 : Math.PI / 2, sx = rot ? sz.z : sz.x, sd = rot ? sz.x : sz.z;
    const o = kit(n, (b.x0 + b.x1 + 1) / 2, (b.z0 + b.z1 + 1) / 2, rot + (rng() < .5 ? Math.PI : 0), 1);
    const k = Math.min(w / sx, d / sd) * 1.02; o.scale.set(rot ? (d / sd) : (w / sx), k * 1.25, rot ? (w / sx) : (d / sd));
    o.position.y = 0;
  }
}
function cityProp(o, rng) {
  const x = o.x + .5, z = o.z + .5;
  if (o.kind === 't') { if (!tree('tree_small_02', x, z, rng() * 6, 5.5 + rng() * 2.5)) kit(rng() < .6 ? 'tree-large' : 'tree-small', x, z, rng() * 6, 5 + rng() * 1.5); }
  else if (o.kind === 'k' && rng() < .4) { const c = kit('p_covered_car', x, z, (rng() < .5 ? 0 : Math.PI) + rng() * .2 - .1 + Math.PI / 2, .62); }
  else if (o.kind === 'k') { const n = ['car-sedan', 'car-taxi', 'car-police', 'car-van', 'car-suv', 'car-truck', 'car-ambulance'][Math.floor(rng() * 7)], sz = sizeOf(n); const c = kit(n, x, z, (rng() < .5 ? 0 : Math.PI) + rng() * .2 - .1, 2.2 / Math.max(sz.x, sz.z)); tintDirty(c, rng); }
  else if (o.kind === 'l') kit('p_street_lamp_01', x, z, Math.floor(rng() * 4) * Math.PI / 2, 1.15);
  else if (o.kind === 'p') { const r = rng(); kit(r < .45 ? 'p_metal_trash_can' : r < .7 ? 'p_utility_box_01' : r < .9 ? 'p_utility_box_02' : 'p_fire_hydrant', x, z, Math.floor(rng() * 4) * Math.PI / 2, r < .45 ? 1.15 : 1.2); }
}
// coches abandonados: un poco más oscuros y sucios
function tintDirty(o, rng) { o.traverse(m => { if (m.isMesh) { m.material = m.material.clone(); m.material.color.multiplyScalar(.7 + rng() * .15); } }); }
let cityLamps = [], cityT = 0;
const poolTex = canvasTex(64, 64, (c, w, h) => { const g = c.createRadialGradient(32, 32, 0, 32, 32, 32); g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(.35, 'rgba(255,255,255,.45)'); g.addColorStop(1, 'rgba(255,255,255,0)'); c.fillStyle = g; c.fillRect(0, 0, w, h); });
const poolGeo = new THREE.PlaneGeometry(6, 6).rotateX(-Math.PI / 2);
function updCityLights(force, dt = 0) {
  if (!cityLamps.length) return; if (!force && (cityT -= dt) > 0) return; cityT = .4;
  const px = P.pos ? P.pos.x : MAP.OBJ.spawn[0], pz = P.pos ? P.pos.z : MAP.OBJ.spawn[1];
  const near = [...cityLamps].sort((a, b) => Math.hypot(a.x - px, a.z - pz) - Math.hypot(b.x - px, b.z - pz));
  LAMPS.filter(l => l.userData.street).forEach((l, i) => { const o = near[i]; if (!o) { l.intensity = 0; return; } l.position.set(o.x, 3.8, o.z); l.color.set(o.col); l.intensity = 9; });
}
function tint(o, col) { const c = new THREE.Color(col); o.traverse(m => { if (m.isMesh) { m.material = m.material.clone(); m.material.color.copy(c); } }); return o; }
function mulberry(a) { return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const world = {};

/* ---------- máquinas de ventajas ---------- */
const PERK_ICON = {
  revive: '<path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z" fill="#fff"/>',
  jugg: '<path d="M12 2 4 5v6c0 5 3.500 9 8 11 4.500-2 8-6 8-11V5z" fill="#fff"/>',
  speed: '<path d="M13 2 4 14h7l-2 8 9-12h-7z" fill="#fff"/>',
  dtap: '<rect x="5" y="6" width="5" height="14" rx="2.500" fill="#fff"/><rect x="14" y="6" width="5" height="14" rx="2.500" fill="#fff"/>',
  stamin: '<path d="M4 6l7 6-7 6M12 6l7 6-7 6" fill="none" stroke="#fff" stroke-width="3" stroke-linejoin="round"/>',
  mule: '<rect x="3" y="5" width="18" height="3" rx="1" fill="#fff"/><rect x="3" y="11" width="18" height="3" rx="1" fill="#fff"/><rect x="3" y="17" width="18" height="3" rx="1" fill="#fff"/>',
};
const machines = [];
function buildPerks() {
  for (const [id, o] of Object.entries(MAP.OBJ.perks)) {
    const P = PERKS[id], col = new THREE.Color(P.col), g = new THREE.Group(), ry = ryOf(o.face);
    const bodyMat = new THREE.MeshStandardMaterial({ color: col.clone().multiplyScalar(.75), roughness: .45, metalness: .35 });
    const body = new THREE.Mesh(new THREE.BoxGeometry(.92, 2.05, .72), bodyMat); body.position.y = 1.025; body.castShadow = body.receiveShadow = true; g.add(body);
    const tex = canvasTex(256, 384, (c, w, h) => {
      const gr = c.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#' + col.clone().multiplyScalar(1.2).getHexString()); gr.addColorStop(1, '#' + col.clone().multiplyScalar(.45).getHexString());
      c.fillStyle = gr; c.fillRect(0, 0, w, h); c.strokeStyle = 'rgba(255,255,255,.75)'; c.lineWidth = 8; c.strokeRect(10, 10, w - 20, h - 20);
      c.fillStyle = '#fff'; c.beginPath(); c.arc(w / 2, 130, 70, 0, 7); c.fill(); c.fillStyle = '#' + col.getHexString(); c.beginPath(); c.arc(w / 2, 130, 58, 0, 7); c.fill();
      c.save(); c.translate(w / 2 - 50, 80); c.scale(100 / 24, 100 / 24); const mt = PERK_ICON[id].match(/d="([^"]+)"/); const p = new Path2D(mt ? mt[1] : ''); c.fillStyle = '#fff'; if (id === 'stamin') { c.strokeStyle = '#fff'; c.lineWidth = 3; c.stroke(p); } else c.fill(p); if (id === 'dtap') { c.fillRect(5, 6, 5, 14); c.fillRect(14, 6, 5, 14); } if (id === 'mule') { c.fillRect(3, 5, 18, 3); c.fillRect(3, 11, 18, 3); c.fillRect(3, 17, 18, 3); } c.restore();
      c.font = '700 44px Oswald, Impact, sans-serif'; c.textAlign = 'center'; c.fillStyle = '#fff'; c.shadowColor = '#000'; c.shadowBlur = 8;
      P.name.split(/[ -]/).forEach((wd, i) => c.fillText(wd.toUpperCase(), w / 2, 270 + i * 48));
    });
    const panelMat = new THREE.MeshStandardMaterial({ map: tex, emissiveMap: tex, emissive: 0xffffff, emissiveIntensity: .05, roughness: .5 });
    const panel = new THREE.Mesh(new THREE.PlaneGeometry(.8, 1.2), panelMat); panel.position.set(0, 1.3, .362); g.add(panel);
    const signMat = new THREE.MeshStandardMaterial({ color: col, emissive: col, emissiveIntensity: .05 });
    const sign = new THREE.Mesh(new THREE.BoxGeometry(.98, .32, .78), signMat); sign.position.y = 2.2; g.add(sign);
    const slot = new THREE.Mesh(new THREE.BoxGeometry(.5, .25, .05), new THREE.MeshStandardMaterial({ color: 0x111111 })); slot.position.set(0, .45, .37); g.add(slot);
    g.position.set(o.x + .5, 0, o.z + .5); g.rotation.y = ry; level.add(g);
    machines.push({ id, g, panelMat, signMat, pos: V3(o.x + .5 + o.face[0] * .95, 0, o.z + .5 + o.face[1] * .95) });
  }
}
function machinesPower() { for (const m of machines) { const on = power || m.id === 'revive'; m.panelMat.emissiveIntensity = on ? .9 : .05; m.signMat.emissiveIntensity = on ? 1.4 : .05; } if (pap) pap.glow.material.opacity = power ? .9 : 0; }

/* ---------- armas: modelos ---------- */
// devuelve el arma mirando hacia -z, centrada y con su largo real (G.len, en metros)
const GUN_CACHE = {};
function gunModel(id, pap) {
  const G0 = GUNS[id], key = id + (pap ? '+' : '');
  if (!GUN_CACHE[key]) {
    const src = K[G0.model].scene.clone(true), inner = new THREE.Group(); inner.add(src);
    if (G0.model.startsWith('g/')) src.rotation.y = Math.PI / 2; else src.rotation.y = Math.PI;   // Quaternius apunta a +x, Kenney a +z
    inner.updateMatrixWorld(true); const b = new THREE.Box3().setFromObject(inner), s = b.getSize(V3()), c = b.getCenter(V3());
    src.position.sub(c); inner.scale.setScalar(G0.len / s.z); const outer = new THREE.Group(); outer.add(inner);
    src.traverse(m => { if (m.isMesh) { m.castShadow = true; if (pap) { m.material = m.material.clone(); m.material.emissive = new THREE.Color(0x7a1aff); m.material.emissiveIntensity = .55; m.material.color.lerp(new THREE.Color(0x8a5aff), .4); } } });
    GUN_CACHE[key] = outer;
  }
  return GUN_CACHE[key].clone(true);
}
function buildWallBuys() {
  world.wallbuys = MAP.OBJ.wallbuys.map(w => {
    const G0 = GUNS[w.gun], ry = ryOf(w.face), px = w.x + .5 + w.face[0] * .51, pz = w.z + .5 + w.face[1] * .51;
    const tex = canvasTex(256, 160, (c, Wd, Hd) => {
      c.strokeStyle = 'rgba(240,235,220,.85)'; c.lineWidth = 3; c.setLineDash([10, 5]);
      c.beginPath(); c.roundRect ? c.roundRect(14, 14, Wd - 28, Hd - 28, 10) : c.rect(14, 14, Wd - 28, Hd - 28); c.stroke(); c.setLineDash([]);
      c.fillStyle = 'rgba(240,235,220,.9)'; c.font = '700 26px Oswald, Impact, sans-serif'; c.textAlign = 'center'; c.fillText(G0.name.toUpperCase(), Wd / 2, Hd - 46); c.font = '600 22px Oswald, Impact, sans-serif'; c.fillStyle = 'rgba(255,214,90,.95)'; c.fillText(G0.wall + '', Wd / 2, Hd - 22);
      for (let i = 0; i < 600; i++) c.clearRect(Math.random() * Wd, Math.random() * Hd, 1.5, 1.5);
    });
    const m = new THREE.Mesh(new THREE.PlaneGeometry(1.4, .88), new THREE.MeshStandardMaterial({ map: tex, transparent: true, emissive: 0xffffff, emissiveMap: tex, emissiveIntensity: .25, roughness: 1 }));
    m.position.set(px, 1.45, pz); m.rotation.y = ry; level.add(m);
    const g = gunModel(w.gun); g.rotation.y = Math.PI / 2; const holder = new THREE.Group(); holder.add(g);
    holder.position.set(px + w.face[0] * .08, 1.6, pz + w.face[1] * .08); holder.rotation.y = ry; level.add(holder);
    return { gun: w.gun, pos: V3(w.x + .5 + w.face[0] * 1.3, 0, w.z + .5 + w.face[1] * 1.3) };
  });
}

/* ---------- caja misteriosa ---------- */
const box = { spot: 0, state: 'idle', t: 0, uses: 0, gun: null, show: null, lid: null };
function buildBox() {
  const g = new THREE.Group(), wood = new THREE.MeshStandardMaterial({ map: MAP.TEX.wood, color: 0x9a7048, roughness: .8 });
  const qTex = canvasTex(128, 128, (c, w, h) => { c.fillStyle = '#2a1a10'; c.fillRect(0, 0, w, h); c.fillStyle = '#ffd24a'; c.shadowColor = '#ffb000'; c.shadowBlur = 18; c.font = '900 96px Impact, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('?', w / 2, h / 2 + 6); });
  const qMat = new THREE.MeshStandardMaterial({ map: qTex, emissive: 0xffb000, emissiveMap: qTex, emissiveIntensity: .9 });
  const base = new THREE.Mesh(new THREE.BoxGeometry(1.1, .55, .62), wood); base.position.y = .3; base.castShadow = base.receiveShadow = true; g.add(base);
  for (const s of [-1, 1]) { const q = new THREE.Mesh(new THREE.PlaneGeometry(.38, .38), qMat); q.position.set(s * .27, .32, .312); g.add(q); }
  const lidPivot = new THREE.Group(); lidPivot.position.set(0, .58, -.31); g.add(lidPivot);
  const lid = new THREE.Mesh(new THREE.BoxGeometry(1.12, .1, .64), wood); lid.position.set(0, 0, .31); lid.castShadow = true; lidPivot.add(lid);
  const beam = new THREE.Mesh(new THREE.CylinderGeometry(.35, .5, 30, 16, 1, true), new THREE.MeshBasicMaterial({ color: 0x6ab8ff, transparent: true, opacity: .22, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false }));
  beam.position.y = 15; g.add(beam);
  const shine = new THREE.PointLight(0x9ad0ff, 3, 4, 2); shine.position.set(0, 1.2, .5); g.add(shine);
  level.add(g); Object.assign(box, { g, lid: lidPivot, beam, shine, holder: new THREE.Group(), spot: 0 }); g.add(box.holder); box.holder.position.set(0, .9, 0);
  placeBox(0, true);
}
function placeBox(i, first) {
  const S0 = MAP.OBJ.box; if (!first) { const o = S0[box.spot]; block(o.x, o.z, false); }
  box.spot = i; const s = S0[i]; block(s.x, s.z, true);
  box.g.position.set(s.x + .5 - s.face[0] * .15, 0, s.z + .5 - s.face[1] * .15); box.g.rotation.y = ryOf(s.face); box.pos = V3(s.x + .5 + s.face[0] * 1.0, 0, s.z + .5 + s.face[1] * 1.0); resetFlow();
}
function teddy() {
  const g = new THREE.Group(), m = new THREE.MeshStandardMaterial({ color: 0x8a5a32, roughness: 1 }), m2 = new THREE.MeshStandardMaterial({ color: 0xd8b088 });
  const s = (r, x, y, z, mm = m) => { const b = new THREE.Mesh(new THREE.SphereGeometry(r, 12, 10), mm); b.position.set(x, y, z); g.add(b); };
  s(.16, 0, 0, 0); s(.12, 0, .22, 0); s(.05, -.09, .32, 0); s(.05, .09, .32, 0); s(.05, 0, .2, .1, m2); s(.06, -.15, -.02, .05); s(.06, .15, -.02, .05); s(.07, -.08, -.15, .05); s(.07, .08, -.15, .05);
  return g;
}

/* ---------- Pack-a-Punch, corriente y huevo de pascua ---------- */
let pap = null, power = false;
function buildPap() {
  const o = MAP.OBJ.pap, g = new THREE.Group(), dark = new THREE.MeshStandardMaterial({ color: 0x2a2630, roughness: .5, metalness: .6 });
  const body = new THREE.Mesh(new THREE.BoxGeometry(1.15, 1.25, .9), dark); body.position.y = .625; body.castShadow = true; g.add(body);
  const tex = canvasTex(256, 64, (c, w, h) => { c.fillStyle = '#120a1a'; c.fillRect(0, 0, w, h); c.fillStyle = '#d68aff'; c.font = '700 27px Oswald, Impact'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('PACK-A-PUNCH', w / 2, h / 2); });
  const lab = new THREE.Mesh(new THREE.PlaneGeometry(1.05, .26), new THREE.MeshStandardMaterial({ map: tex, emissive: 0xffffff, emissiveMap: tex, emissiveIntensity: .6 })); lab.position.set(0, .95, .455); g.add(lab);
  const slot = new THREE.Mesh(new THREE.BoxGeometry(.95, .22, .1), new THREE.MeshBasicMaterial({ color: 0x050308 })); slot.position.set(0, .45, .45); g.add(slot);
  for (const s of [-1, 1]) { const r = new THREE.Mesh(new THREE.CylinderGeometry(.12, .12, .9, 16), new THREE.MeshStandardMaterial({ color: 0x8a8090, metalness: .8, roughness: .3 })); r.rotation.z = Math.PI / 2; r.position.set(0, 1.32, s * .28); g.add(r); }
  const gl = new THREE.Mesh(new THREE.PlaneGeometry(.95, .22), new THREE.MeshBasicMaterial({ color: 0xb24aff, transparent: true, opacity: 0, blending: THREE.AdditiveBlending })); gl.position.set(0, .45, .51); g.add(gl);
  g.position.set(o.x + .5, 0, o.z + .5); g.rotation.y = ryOf(o.face); level.add(g);
  pap = { g, glow: gl, pos: V3(o.x + .5 + o.face[0] * 1.1, 0, o.z + .5 + o.face[1] * 1.1), state: 'idle', t: 0, w: null, holder: new THREE.Group() }; g.add(pap.holder); pap.holder.position.set(0, .45, .7);
}
function buildPower() {
  const o = MAP.OBJ.power, g = new THREE.Group(), m = new THREE.MeshStandardMaterial({ color: 0x5a5a62, roughness: .6, metalness: .5 });
  const post = new THREE.Mesh(new THREE.BoxGeometry(.5, 1.9, .3), m); post.position.set(0, .95, -.2); post.castShadow = true; g.add(post);
  const plate = new THREE.Mesh(new THREE.BoxGeometry(.7, .9, .12), m); plate.position.set(0, 1.4, 0); g.add(plate);
  const leverP = new THREE.Group(); leverP.position.set(0, 1.4, .1); g.add(leverP);
  const lever = new THREE.Mesh(new THREE.BoxGeometry(.08, .45, .08), new THREE.MeshStandardMaterial({ color: 0xc81e1e })); lever.position.y = .2; leverP.add(lever); leverP.rotation.x = .9;
  const tex = canvasTex(128, 32, (c, w, h) => { c.fillStyle = '#ffd24a'; c.fillRect(0, 0, w, h); c.fillStyle = '#111'; c.font = '700 22px Oswald, Impact'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('CORRIENTE', w / 2, h / 2 + 1); });
  const lab = new THREE.Mesh(new THREE.PlaneGeometry(.6, .15), new THREE.MeshBasicMaterial({ map: tex })); lab.position.set(0, 1.95, .07); g.add(lab);
  g.position.set(o.x + .5, 0, o.z + .5); g.rotation.y = ryOf(o.face); level.add(g);
  world.power = { g, leverP, pos: V3(o.x + .5 + o.face[0] * .9, 0, o.z + .5 + o.face[1] * .9) };
}
function buildEggs() { world.eggs = MAP.OBJ.eggs.map(e => { const x = e.x + .5, z = e.z + .5, o = kit('pumpkin-carved', x, z, rnd(0, 6), 1.3); return { o, pos: V3(x, 0, z), found: false }; }); }

/* ---------- jugador ---------- */
const P = {};
let shrimp = null, gunPivot = null, gunHolder = null;
async function buildPlayer(id) {
  if (shrimp) scene.remove(shrimp.root);
  shrimp = new Shrimp({ gamba: CH.gamba });
  await shrimp.use(id);
  // de pie: la cabeza arriba, las patitas hacia delante sujetando el arma
  const L = shrimp.cur.cfg.len; shrimp.cur.wrap.rotation.x = 1.42; if (shrimp.cur.cfg.flip) shrimp.cur.holder.rotation.y = 0; shrimp.cur.wrap.position.set(0, L * .5, .05);
  shrimp.root.scale.setScalar(1.12 / L); scene.add(shrimp.root);
  shrimp.root.traverse(m => { if (m.isMesh) m.castShadow = true; });
  gunPivot = new THREE.Group(); gunPivot.position.set(.1 * L, .5 * L, -.22 * L); shrimp.root.add(gunPivot);
  gunHolder = new THREE.Group(); gunPivot.add(gunHolder);
}
function setGunMesh() {
  gunHolder.clear(); const w = curW(); if (!w) return;
  const g = gunModel(w.id, w.pap), rs = shrimp.root.scale.x, len = GUNS[w.id].len;   // el arma se mide en metros aunque la gamba esté escalada
  g.scale.setScalar(1 / rs); g.position.z = (-len / 2 + .16) / rs; P.muzzleZ = (-len + .14) / rs; gunHolder.add(g);
  setViewGun();
}
function resetPlayer() {
  Object.assign(P, {
    pos: V3(MAP.OBJ.spawn[0], 0, MAP.OBJ.spawn[1]), vel: V3(), y: 0, vy: 0, yaw: 0, pitch: -.05, hp: 100, maxHp: 100, alive: true, downT: 0, points: Q.has('pts') ? +Q.get('pts') : 500,
    weapons: [{ id: 'm1911', pap: false, mag: 8, res: 32 }], cur: 0, perks: [], nades: 2, reloadT: 0, fireT: 0, knifeT: -1, swapT: 0, nadeT: 0, adsK: 0, hurtT: 9, regen: 0,
    kills: 0, heads: 0, revives: 0, reviveUses: 0, shake: 0, recoil: 0, firePrev: false, ph: 0, snap: null, aimPrev: false, buildCap: 0, buildT: 0, usePrev: false,
  });
}
const curW = () => P.weapons[P.cur];
const stat = (w, k) => (w.pap && GUNS[w.id].pap[k] !== undefined) ? GUNS[w.id].pap[k] : GUNS[w.id][k];
const maxGuns = () => P.perks.includes('mule') ? 3 : 2;

/* ---------- partida ---------- */
const G = { state: 'load', round: 0, toSpawn: 0, spawnT: 0, breakT: 0, special: false, nextSpecial: 5, drops: 0, instaT: 0, dblT: 0, time: 0, slow: 1, overT: 0, egg: 0, songT: 0 };
const Z = [], proj = [], pups = [], boardsFly = [];
const game = { scene, fx, tearBoard, groan, hurtPlayer };
function resetLevelState() {
  for (const z of Z) z.dispose(); Z.length = 0;
  for (const p of proj) scene.remove(p.mesh); proj.length = 0;
  for (const p of pups) scene.remove(p.s); pups.length = 0;
  for (const p of splats) scene.remove(p.m); splats.length = 0;
  for (const w of MAP.WINDOWS) { w.boards = 6; w.user = null; w.meshes.forEach(m => { m.visible = true; m.position.copy(m.userData.home); m.rotation.copy(m.userData.rot); }); }
  for (const d of MAP.DOORS) { d.open = false; d.mesh.visible = true; d.mesh.position.y = 0; for (const [x, z] of d.cells) MAP.grid[MAP.idx(x, z)] = MAP.DOOR; }
  MAP.ZONES.forEach((z, i) => z.open = i === 0);
  power = false; machinesPower(); LAMPS.forEach((l, i) => l.intensity = l.userData.street ? 7 : l.userData.fire ? 4 : i === 0 ? 5 : 1.2); world.bulbMat.emissiveIntensity = .3; world.power.leverP.rotation.x = .9;
  Object.assign(box, { state: 'idle', t: 0, uses: 0, gun: null }); box.holder.clear(); box.lid.rotation.x = 0; box.g.visible = true; placeBox(0);
  Object.assign(pap, { state: 'idle', t: 0, w: null }); pap.holder.clear();
  world.eggs.forEach(e => { e.found = false; e.o.traverse(m => { if (m.isMesh && m.userData.em0 !== undefined) m.material.emissiveIntensity = m.userData.em0; }); });
  resetFlow();
}
function startGame() {
  resetLevelState(); resetPlayer();
  Object.assign(G, { state: 'play', round: 0, toSpawn: 0, spawnT: 3, breakT: 0, special: false, nextSpecial: 5 + Math.floor(Math.random() * 2), drops: 0, instaT: 0, dblT: 0, time: 0, slow: 1, egg: 0, songT: 0 });
  if (Q.has('power')) setPower(true);
  if (Q.has('doors')) MAP.DOORS.forEach(openDoor);
  if (Q.has('perks')) for (const p of Q.get('perks').split(',')) givePerk(p, true);
  if (Q.has('gun')) { const id = Q.get('gun'); P.weapons.push({ id, pap: Q.has('pap'), mag: stat({ id, pap: Q.has('pap') }, 'mag'), res: stat({ id, pap: Q.has('pap') }, 'res') }); P.cur = 1; }
  if (Q.has('pos')) { const [x, z, yw] = Q.get('pos').split(',').map(Number); P.pos.set(x, 0, z); P.yaw = (yw || 0) * Math.PI / 180; }
  if (Q.has('pitch')) P.pitch = +Q.get('pitch') * Math.PI / 180;
  if (Q.has('fp')) FP = true; if (Q.has('tp')) FP = false;
  setGunMesh(); showScreen(null); $('hud').hidden = false; $('downed').hidden = true; $('blood').style.opacity = 0; setMenu(null); resetTouch(); document.querySelectorAll('.tbtn.on').forEach(b => b.classList.remove('on'));
  shrimp.tilt.rotation.set(0, 0, 0); camera.rotation.z = 0;
  lockPointer(cv); ambient(true);
  startRound(Q.has('round') ? +Q.get('round') : 1);
  updHud(true);
}
function startRound(n) {
  G.round = n; G.special = n === G.nextSpecial || (Q.has('special') && n === +Q.get('round')); if (G.special) G.nextSpecial += 5 + Math.floor(Math.random() * 2);
  G.toSpawn = G.special ? Math.min(24, 6 + n) : roundCount(n); G.spawnT = G.special ? 3 : 1.5; G.drops = 0; P.buildCap = 0;
  P.nades = Math.min(4, P.nades + (n > 1 ? 2 : 0));
  S.roundStart(); setRoundHud(true);
  if (G.special) { banner('RONDA DE ESQUELETOS', '¡Salen de la tierra!', 3.5); scene.fog.color.set(0x2a0a10); scene.background = scene.fog.color; }
  else { scene.fog.color.copy(SKY); scene.background = SKY; }
}
function endRound() {
  S.roundEnd(); setRoundHud(true, true);
  if (G.special) { spawnPowerup('ammo', P.pos.x + Math.sin(P.yaw) * -1.5, P.pos.z - Math.cos(P.yaw) * 1.5); banner('¡RONDA SUPERADA!', '', 2.5); }
  G.breakT = G.special ? 9 : 10;
}
function aliveCount() { let n = 0; for (const z of Z) if (!z.dead) n++; return n; }

/* ---------- aparición de zombis ---------- */
function playerZone() { return MAP.zoneOf[MAP.idx(Math.floor(P.pos.x), Math.floor(P.pos.z))]; }
function spawnZombie() {
  const r = G.round, pz = playerZone();
  if (G.special) {
    // esqueletos: salen de la tierra cerca del jugador
    for (let tries = 0; tries < 30; tries++) {
      const a = Math.random() * 6.28, d = rnd(5, 10), x = P.pos.x + Math.cos(a) * d, z = P.pos.z + Math.sin(a) * d;
      const cx = Math.floor(x), cz = Math.floor(z); if (!MAP.walkable(cx, cz) || MAP.zoneOf[MAP.idx(cx, cz)] < 0 || !MAP.ZONES[MAP.zoneOf[MAP.idx(cx, cz)]].open) continue;
      const zb = new Zombie(game, K['character-skeleton'], { hp: Math.floor(roundHp(r) * .4 + 100), speed: 4.2, kind: 'skel', scale: .9 });
      zb.spawnGround(cx + .5, cz + .5); zb.t = .9; Z.push(zb); lightning(cx + .5, cz + .5); return true;
    }
    return false;
  }
  const opts2 = { hp: roundHp(r), speed: roundSpeed(r), scale: rnd(.95, 1.06) };
  const graves = MAP.OBJ.graves.filter(g => MAP.ZONES[g.zone] && MAP.ZONES[g.zone].open && Math.hypot(g.x - P.pos.x, g.z - P.pos.z) < 22);
  const groundOk = graves.length && (graves.some(g => g.zone === pz) || Math.random() < .2);
  if (groundOk && Math.random() < .4) {
    const gr = graves[Math.floor(Math.random() * graves.length)], x = gr.x + .5, z = gr.z + .5;
    if (Math.hypot(x - P.pos.x, z - P.pos.z) > 2.5) { const zb = newZombie(opts2); zb.spawnGround(x, z); Z.push(zb); return true; }
  }
  const wins = MAP.WINDOWS.filter(w => MAP.ZONES[w.zone].open);
  const weights = wins.map(w => (w.zone === pz ? 4 : 1) / (1 + Math.hypot(w.x - P.pos.x, w.z - P.pos.z) * .08));
  let s = Math.random() * weights.reduce((a, b) => a + b, 0), w = wins[0];
  for (let i = 0; i < wins.length; i++) { s -= weights[i]; if (s <= 0) { w = wins[i]; break; } }
  const zb = newZombie(opts2); zb.spawnAtWindow(w); Z.push(zb); return true;
}
// según la velocidad: los lentos son del modelo realista, los que reptan también (marcha Running_Crawl) y los que corren, del «corredor»
function newZombie(o) {
  const s = o.speed, x = Math.random();
  const kind = s < .95 ? (x < .5 ? 'city' : 'real') : s < 1.8 ? (x < .35 ? 'real' : x < .6 ? 'city' : 'runner') : 'runner';
  const def = { real: REAL, city: CITYZ, runner: RUNNER }[kind];
  return new Zombie(game, K['zombie_' + (kind === 'real' ? 'real' : kind)], { ...o, def });
}
function lightning(x, z) { $('flash').style.transition = 'none'; $('flash').style.opacity = .25; requestAnimationFrame(() => { $('flash').style.transition = 'opacity .4s'; $('flash').style.opacity = 0; }); glow.burst(x, .5, z, 30, new THREE.Color(0x9ad0ff), 3, .3, .5, 2); tone(80, .5, 'sawtooth', .12, -40); }

/* ---------- ventanas ---------- */
function tearBoard(w, z) {
  if (w.boards <= 0) return; w.boards--; const m = w.meshes[w.boards];
  const out = V3(w.out[0] - w.inn[0], 0, w.out[1] - w.inn[1]);
  boardsFly.push({ m, v: out.multiplyScalar(rnd(2.5, 4)).add(V3(rnd(-1, 1), rnd(2, 3.5), rnd(-1, 1))), r: V3(rnd(-6, 6), rnd(-6, 6), rnd(-6, 6)), t: 0 });
  S.board(); fx.burst(m.position.x, m.position.y, m.position.z, 8, new THREE.Color(0x8a6440), 1.6, .1, .6, 8);
}
function repairBoard(w) {
  if (w.boards >= 6) return false; const m = w.meshes[w.boards]; w.boards++;
  const i = boardsFly.findIndex(b => b.m === m); if (i >= 0) boardsFly.splice(i, 1);
  m.visible = true; m.rotation.copy(m.userData.rot); m.position.copy(m.userData.home).add(V3((w.inn[0] - w.out[0]) * .6, .3, (w.inn[1] - w.out[1]) * .6)); boardsFly.push({ m, back: true, t: 0, from: m.position.clone() });
  S.build(); if (P.buildCap < 500) { addPts(10); P.buildCap += 10; }
  // golpear a un zombi que está justo detrás
  if (w.user && w.user.state === 'tear') w.user.boardT = Math.max(w.user.boardT, .9);
  return true;
}
function updBoards(dt) {
  for (let i = boardsFly.length - 1; i >= 0; i--) {
    const b = boardsFly[i]; b.t += dt;
    if (b.back) { const k = Math.min(1, b.t / .22); b.m.position.lerpVectors(b.from, b.m.userData.home, k * k); if (k >= 1) boardsFly.splice(i, 1); continue; }
    b.v.y -= 12 * dt; b.m.position.addScaledVector(b.v, dt); b.m.rotation.x += b.r.x * dt; b.m.rotation.y += b.r.y * dt;
    if (b.m.position.y < .05) { b.m.position.y = .05; b.v.set(0, 0, 0); b.r.set(0, 0, 0); }
    if (b.t > 1.4) { b.m.visible = false; boardsFly.splice(i, 1); }
  }
}

/* ---------- puertas, corriente, ventajas ---------- */
function openDoor(d) {
  if (d.open) return; d.open = true; for (const [x, z] of d.cells) MAP.grid[MAP.idx(x, z)] = MAP.DOOR;
  for (const zi of d.zones) MAP.ZONES[zi].open = true;
  d.anim = 0; S.door(); resetFlow();
  fx.burst(d.center.x, 1.2, d.center.z, 30, new THREE.Color(0x8a6440), 3, .14, .9, 8);
}
function setPower(on) {
  power = on; machinesPower(); world.power.leverP.rotation.x = on ? -.9 : .9;
  LAMPS.forEach(l => { if (!l.userData.fire && !l.userData.street) l.intensity = on ? 9 : 1.2; }); world.bulbMat.emissiveIntensity = on ? 2.5 : .3;
  if (on) { S.power(); banner('¡HAY CORRIENTE!', 'Las máquinas de ventajas y el Pack-a-Punch funcionan', 3); }
}
function givePerk(id, silent) {
  if (P.perks.includes(id)) return; P.perks.push(id);
  if (id === 'jugg') { P.maxHp = 250; P.hp = 250; }
  if (!silent) { S.drink(); setTimeout(() => S.perk(), 900); banner(PERKS[id].name.toUpperCase(), PERKS[id].desc, 2.2); }
  updPerksHud();
}
function losePerks() { P.perks = []; P.maxHp = 100; P.hp = Math.min(P.hp, 100); if (P.weapons.length > 2) { P.weapons.length = 2; if (P.cur > 1) P.cur = 0; setGunMesh(); } updPerksHud(); }

/* ---------- puntos ---------- */
function addPts(n) {
  if (n > 0 && G.dblT > 0) n *= 2;
  P.points += n; if (n > 0) P.score = (P.score || 0) + n; const sp = document.createElement('span'); sp.textContent = (n > 0 ? '+' : '') + n; if (n < 0) sp.className = 'neg';
  sp.style.bottom = (Math.random() * 14) + 'px'; $('ptsPop').appendChild(sp); setTimeout(() => sp.remove(), 1000);
  $('points').textContent = P.points;
  if (n > 0 && n <= 130) S.pts();
}
function pay(cost) { if (P.points < cost) { S.no(); return false; } addPts(-cost); S.buy(); return true; }

/* ---------- interacción ---------- */
function interactables() {
  const L = [], w = curW();
  for (const d of MAP.DOORS) if (!d.open) L.push({ pos: d.center, r: 1.9, label: 'abrir la puerta', cost: d.cost, act: () => { if (pay(d.cost)) openDoor(d); } });
  for (const wb of world.wallbuys) {
    const has = P.weapons.find(x => x.id === wb.gun), G0 = GUNS[wb.gun];
    if (has) { const c = has.pap ? 4500 : Math.round(G0.wall / 2); L.push({ pos: wb.pos, r: 1.3, label: 'comprar munición de ' + (has.pap ? G0.pap.name : G0.name), cost: c, act: () => { if (stat(has, 'res') === has.res && stat(has, 'mag') === has.mag) return S.no(); if (pay(c)) { has.res = stat(has, 'res'); has.mag = stat(has, 'mag'); updHud(); } } }); }
    else L.push({ pos: wb.pos, r: 1.3, label: 'comprar ' + G0.name, cost: G0.wall, act: () => { if (pay(G0.wall)) giveGun(wb.gun); } });
  }
  for (const m of machines) {
    const Pk = PERKS[m.id];
    if (P.perks.includes(m.id)) continue;
    if (!power && m.id !== 'revive') { L.push({ pos: m.pos, r: 1.2, label: 'Primero hay que activar la corriente', info: true }); continue; }
    if (m.id === 'revive' && P.reviveUses >= 3) continue;
    L.push({ pos: m.pos, r: 1.2, label: 'beber ' + Pk.name, cost: Pk.cost, act: () => { if (pay(Pk.cost)) givePerk(m.id); } });
  }
  if (!power) L.push({ pos: world.power.pos, r: 1.4, label: 'activar la corriente', act: () => setPower(true) });
  // caja
  if (box.state === 'idle') L.push({ pos: box.pos, r: 1.5, label: 'abrir la caja misteriosa', cost: 950, act: () => { if (pay(950)) openBox(); } });
  else if (box.state === 'offer') L.push({ pos: box.pos, r: 1.6, label: 'coger ' + GUNS[box.gun].name, act: takeBoxGun });
  // Pack-a-Punch
  if (pap.state === 'idle' && w && !w.pap) { if (!power) L.push({ pos: pap.pos, r: 1.5, label: 'Primero hay que activar la corriente', info: true }); else L.push({ pos: pap.pos, r: 1.5, label: 'mejorar ' + GUNS[w.id].name + ' en el Pack-a-Punch', cost: 5000, act: () => { if (pay(5000)) papStart(); } }); }
  else if (pap.state === 'ready') L.push({ pos: pap.pos, r: 1.6, label: 'coger ' + GUNS[pap.w.id].pap.name, act: papTake });
  // ventanas
  for (const wi of MAP.WINDOWS) if (wi.boards < 6 && MAP.ZONES[wi.zone].open) L.push({ pos: V3(wi.inn[0] + .5, 0, wi.inn[1] + .5), r: 1.4, label: 'reconstruir la ventana', hold: true, win: wi });
  // calabazas secretas
  for (const e of world.eggs) if (!e.found) L.push({ pos: e.pos, r: 1.1, label: '', hidden: true, act: () => findEgg(e) });
  return L;
}
let curInt = null;
function pickInteract() {
  let best = null, bd = 1e9; const f = V3(-Math.sin(P.yaw), 0, -Math.cos(P.yaw));
  for (const it of interactables()) {
    const dx = it.pos.x - P.pos.x, dz = it.pos.z - P.pos.z, d = Math.hypot(dx, dz); if (d > it.r) continue;
    const score = d - (dx * f.x + dz * f.z) / (d || 1) * .4; if (score < bd) { bd = score; best = it; }
  }
  return best;
}
function promptHtml(it) {
  if (!it || it.hidden) return '';
  if (it.info) return it.label;
  const cost = it.cost ? ` <span class="cost">[${it.cost}]</span>` : '';
  const k = key('use');
  if (!k) return it.label.charAt(0).toUpperCase() + it.label.slice(1) + cost;
  return `${it.hold ? 'Mantén' : 'Pulsa'} <kbd class="${I.device === 'pad' && I.padKind === 'ps' ? 'ps' : ''}">${k}</kbd> para ${it.label}${cost}`;
}

/* ---------- armas ---------- */
function giveGun(id, pap = false) {
  const nw = { id, pap, mag: stat({ id, pap }, 'mag'), res: stat({ id, pap }, 'res') };
  if (P.weapons.length < maxGuns()) { P.weapons.push(nw); P.cur = P.weapons.length - 1; }
  else P.weapons[P.cur] = nw;
  P.reloadT = 0; P.swapT = .5; setGunMesh(); updHud();
}
function openBox() {
  box.state = 'spin'; box.t = 0; box.uses++; S.boxOpen();
  const pool = BOX_POOL.filter(id => !P.weapons.find(w => w.id === id));
  box.final = pool[Math.floor(Math.random() * pool.length)] || 'raygun';
  box.teddy = box.uses > 3 && Math.random() < .22;
}
function takeBoxGun() { giveGun(box.gun); box.holder.clear(); box.state = 'close'; box.t = 0; S.buy(); }
function updBox(dt) {
  box.t += dt; box.beam.material.opacity = .16 + Math.sin(G.time * 3) * .05;
  if (box.state === 'spin') {
    box.lid.rotation.x = -Math.min(1.6, box.t * 4);
    const rate = .06 + Math.pow(box.t / 4, 2) * .35;
    if (!box.nextSwap || box.t > box.nextSwap) {
      box.nextSwap = box.t + rate; box.holder.clear();
      const id = box.t > 3.9 ? box.final : BOX_POOL[Math.floor(Math.random() * BOX_POOL.length)];
      const g = (box.t > 3.9 && box.teddy) ? teddy() : gunModel(id); if (!(box.t > 3.9 && box.teddy)) { g.rotation.y = Math.PI / 2; g.scale.setScalar(1.4); }
      box.holder.add(g); S.boxSpin();
    }
    box.holder.position.y = .5 + Math.min(1, box.t / 3.5) * .6;
    if (box.t > 4.1) {
      if (box.teddy) { box.state = 'teddy'; box.t = 0; S.no(); banner('¡ADIÓS, ADIÓS!', 'La caja se va a otro sitio', 2.5); addPts(950); }
      else { box.state = 'offer'; box.t = 0; box.gun = box.final; }
    }
  } else if (box.state === 'offer') {
    box.holder.position.y = 1.1 - Math.max(0, box.t - 9) / 3 * .6; box.holder.rotation.y = Math.sin(G.time * 2) * .2;
    if (box.t > 12) { box.state = 'close'; box.t = 0; box.holder.clear(); }
  } else if (box.state === 'close') {
    box.lid.rotation.x = -1.6 + Math.min(1.6, box.t * 4); if (box.t > .5) { box.state = 'idle'; box.lid.rotation.x = 0; }
  } else if (box.state === 'teddy') {
    box.holder.position.y = 1.1 + box.t * .5;
    if (box.t > 1.5) box.g.position.y = (box.t - 1.5) * (box.t - 1.5) * 4;
    if (box.t > 3.5) { box.holder.clear(); box.lid.rotation.x = 0; box.g.position.y = 0; let n; do { n = Math.floor(Math.random() * MAP.OBJ.box.length); } while (n === box.spot); placeBox(n); box.state = 'idle'; box.uses = 0; }
  }
}
function papStart() {
  const w = curW(); pap.state = 'work'; pap.t = 0; pap.w = w; S.pap();
  P.weapons.splice(P.cur, 1); P.cur = 0; setGunMesh(); updHud();
  const g = gunModel(w.id, false); g.rotation.y = Math.PI / 2; g.scale.setScalar(1.3); pap.holder.add(g); pap.holder.position.z = .7;
}
function papTake() { const w = pap.w; pap.holder.clear(); pap.state = 'idle'; pap.w = null; giveGun(w.id, true); banner(GUNS[w.id].pap.name.toUpperCase(), '', 2); }
function updPap(dt) {
  pap.t += dt; if (power) pap.glow.material.opacity = .6 + Math.sin(G.time * 6) * .3;
  if (pap.state === 'work') {
    pap.holder.position.z = pap.t < .8 ? .7 - pap.t / .8 * .7 : pap.t > 3.2 ? Math.min(.7, (pap.t - 3.2) / .8 * .7) : 0;
    if (Math.random() < .5) glow.emit(pap.pos.x + rnd(-.5, .5), .5, pap.pos.z, rnd(-.3, .3), rnd(.5, 1.5), rnd(0, .5), new THREE.Color(0xb24aff), .14, .6);
    if (pap.t > 3.2 && pap.holder.children.length && !pap.swapped) { pap.swapped = true; pap.holder.clear(); const g = gunModel(pap.w.id, true); g.rotation.y = Math.PI / 2; g.scale.setScalar(1.3); pap.holder.add(g); }
    if (pap.t > 4) { pap.state = 'ready'; pap.t = 0; pap.swapped = false; }
  } else if (pap.state === 'ready') pap.holder.rotation.y = Math.sin(G.time * 2) * .2;
}
function findEgg(e) {
  e.found = true; G.egg++; tone(523, .4, 'sine', .15); tone(784, .4, 'sine', .1, 0, .15);
  e.o.traverse(m => { if (m.isMesh) { m.material = m.material.clone(); m.userData.em0 = 0; m.material.emissive = new THREE.Color(0xff8a00); m.material.emissiveIntensity = 1.2; } });
  if (G.egg === 3) { banner('¡CANCIÓN SECRETA!', 'Has encontrado las tres calabazas', 3); G.songT = 0.01; addPts(500); }
}
// canción secreta (sintetizada)
const SONG = [64, 0, 67, 64, 0, 62, 60, 0, 59, 60, 62, 0, 64, 0, 67, 69, 67, 64, 62, 0, 60, 62, 64, 0, 64, 0, 67, 64, 0, 62, 60, 0, 59, 57, 59, 60, 0, 0, 0, 0];
function updSong(dt) {
  if (!G.songT) return; const prev = Math.floor(G.songT / .22); G.songT += dt; const i = Math.floor(G.songT / .22);
  if (i !== prev && i < SONG.length * 3) { const n = SONG[i % SONG.length]; if (n) { tone(440 * Math.pow(2, (n - 69) / 12), .2, 'square', .05); tone(440 * Math.pow(2, (n - 81) / 12), .2, 'triangle', .07); } if (i % 4 === 0) tone(55, .15, 'sine', .2, -20); }
  if (i >= SONG.length * 3) G.songT = 0;
}

/* ---------- disparos ---------- */
const ray = new THREE.Ray(), _v = V3(), _f = V3(), _r = V3(), _u = V3();
function solid(x, y, z, forCam) {
  if (y < 0) return true; if (y > MAP.WALL_H) return false;
  const cx = Math.floor(x), cz = Math.floor(z), c = MAP.cellAt(cx, cz);
  if (c === MAP.WALL || c === MAP.BLD) return true;
  if (c === MAP.WIN) { const w = MAP.WINDOWS.find(w => w.x === cx && w.z === cz); return !w.fence && (y < .9 || y > 2.0); }
  if (c === MAP.DOOR) return !MAP.DOORS.some(d => d.open && d.cells.some(([a, b]) => a === cx && b === cz));
  if (c === MAP.PROP) return y < (forCam ? .3 : .9);
  return false;
}
function wallT(o, d, max) { for (let t = .05; t < max; t += .07) if (solid(o.x + d.x * t, o.y + d.y * t, o.z + d.z * t)) return t; return max; }
function muzzlePos(out) { if (FP) { vmHolder.updateMatrixWorld(true); out.set(0, .03, -(vmGun.userData.len || .5) / 2).applyMatrix4(vmHolder.matrixWorld); return out.applyMatrix4(camera.matrixWorld); } gunHolder.updateWorldMatrix(true, false); return out.set(0, .04, P.muzzleZ || -.5).applyMatrix4(gunHolder.matrixWorld); }
function camDir(out, spread) {
  camera.getWorldDirection(out);
  if (spread) { _r.set(1, 0, 0).applyQuaternion(camera.quaternion); _u.set(0, 1, 0).applyQuaternion(camera.quaternion); const a = Math.random() * 6.28, s = Math.sqrt(Math.random()) * spread; out.addScaledVector(_r, Math.cos(a) * s).addScaledVector(_u, Math.sin(a) * s).normalize(); }
  return out;
}
function shoot() {
  const w = curW(); if (!w) return;
  if (w.mag <= 0) { if (!P.firePrev) S.dry(); if (w.res > 0) startReload(); return; }
  const dtap = P.perks.includes('dtap');
  P.fireT = 1 / (stat(w, 'rate') * (dtap ? 1.33 : 1)); w.mag--;
  const dmg = stat(w, 'dmg') * (dtap ? 1.5 : 1), pel = stat(w, 'pel') || 1, spread = stat(w, 'spread') * lerp(1, .3, P.adsK) * (Math.hypot(P.vel.x, P.vel.z) > 1 ? 1.4 : 1);
  const proj0 = stat(w, 'proj'), m = muzzlePos(V3());
  if (proj0) { fireProj(proj0, m, camDir(V3(), spread * .3), dmg, stat(w, 'splash'), stat(w, 'col')); }
  else {
    const o = camera.position; let anyHit = false, kill = false, head = false;
    for (let p = 0; p < pel; p++) {
      camDir(_f, spread); ray.origin.copy(o); ray.direction.copy(_f);
      const wt = wallT(o, _f, 60); let best = null, bz = null;
      for (const z of Z) { const h = z.hit(ray, wt); if (h && (!best || h.t < best.t)) { best = h; bz = z; } }
      const t = best ? best.t : wt, hp = V3().copy(o).addScaledVector(_f, t);
      if (p < 3) tracer(m, hp, w.pap ? 0xd08aff : 0xffe2a0);
      if (bz) { anyHit = true; if (Math.random() < .3) splat(bz.pos.x, bz.pos.z, .6); head = head || best.head; const k = hitZombie(bz, dmg * (best.head ? 2.2 : 1) * (pel > 1 ? Math.max(.4, 1 - t / 14) : 1), best.head, 'bullet'); kill = kill || k; fx.burst(hp.x, hp.y, hp.z, best.head ? 10 : 5, new THREE.Color(best.head ? 0x7a1010 : 0x5a0a0a), 1.6, .1, .5, 6); }
      else if (t < 59) { fx.burst(hp.x, hp.y, hp.z, 4, new THREE.Color(0xc8b090), 1.2, .07, .4, 6); glow.emit(hp.x, hp.y, hp.z, 0, 0, 0, new THREE.Color(0xffc070), .16, .08); }
    }
    if (anyHit) hitmark(kill, head);
  }
  // efectos
  const big = pel > 1 || stat(w, 'dmg') > 100;
  if (proj0 === 'ray') S.ray(); else S.shot(GUNS[w.id].pitch, big);
  flash.position.copy(m); flash.scale.setScalar(big ? .55 : .35); flash.material.rotation = Math.random() * 6; flash.visible = true; flash.userData.t = .05; flash.material.color.set(w.pap ? 0xd090ff : 0xffffff);
  muzzleLight.position.copy(m); muzzleLight.intensity = 6; glow.emit(m.x, m.y, m.z, 0, 0, 0, new THREE.Color(w.pap ? 0xc070ff : 0xffb050), .45, .05);
  P.recoil += (big ? .05 : .018) * (1 - P.adsK * .4); P.shake = Math.max(P.shake, big ? .5 : .2);
  rumble(big ? .6 : .25, big ? .4 : .3, big ? 120 : 50);
  updHud();
}
const splatTex = canvasTex(64, 64, (c, w, h) => { c.fillStyle = 'rgba(90,0,0,.85)'; for (let i = 0; i < 14; i++) { c.beginPath(); c.arc(32 + rnd(-18, 18), 32 + rnd(-18, 18), rnd(3, 12), 0, 7); c.fill(); } });
const splatMat = new THREE.MeshBasicMaterial({ map: splatTex, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2 }), splatGeo = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2);
const splats = [];
function splat(x, z, s = 1) { const m = new THREE.Mesh(splatGeo, splatMat.clone()); m.position.set(x + rnd(-.3, .3), .075, z + rnd(-.3, .3)); m.rotation.y = rnd(0, 6); m.scale.setScalar(rnd(.4, .9) * s); scene.add(m); splats.push({ m, t: 0 }); if (splats.length > 45) { const o = splats.shift(); scene.remove(o.m); } }
function updSplats(dt) { for (const p of splats) { p.t += dt; if (p.t > 25) p.m.material.opacity = Math.max(0, 1 - (p.t - 25) / 5); } }
const flashTex = canvasTex(64, 64, (c, w, h) => { const g = c.createRadialGradient(32, 32, 0, 32, 32, 32); g.addColorStop(0, 'rgba(255,255,220,1)'); g.addColorStop(.3, 'rgba(255,190,80,.9)'); g.addColorStop(1, 'rgba(255,120,0,0)'); c.fillStyle = g; c.fillRect(0, 0, w, h); c.strokeStyle = 'rgba(255,220,150,.9)'; c.lineWidth = 3; for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; c.beginPath(); c.moveTo(32, 32); c.lineTo(32 + Math.cos(a) * 30, 32 + Math.sin(a) * 30); c.stroke(); } });
const flash = new THREE.Sprite(new THREE.SpriteMaterial({ map: flashTex, blending: THREE.AdditiveBlending, depthWrite: false, fog: false })); flash.visible = false; scene.add(flash);
function hitZombie(z, dmg, head, kind) {
  const insta = G.instaT > 0;
  const killed = z.damage(insta ? 1e9 : dmg, head);
  if (!killed) { if (kind !== 'explo') addPts(10); S.hit(); return false; }
  P.kills++; if (head) P.heads++;
  addPts(kind === 'knife' ? 130 : head ? 100 : kind === 'explo' ? 60 : 60);
  splat(z.pos.x, z.pos.z, head ? 1.3 : 1);
  if (head) { S.head(); fx.burst(z.pos.x, z.pos.y + 1.15, z.pos.z, 18, new THREE.Color(0x6a0a0a), 2.4, .14, .7, 7); }
  if (!G.special && G.drops < 4 && Math.random() < .035) { G.drops++; const list = ['ammo', 'insta', 'double', 'nuke', 'carpenter']; spawnPowerup(list[Math.floor(Math.random() * list.length)], z.pos.x, z.pos.z); }
  return true;
}
const trMat = new THREE.LineBasicMaterial({ color: 0xffe2a0, transparent: true, opacity: .8, blending: THREE.AdditiveBlending });
const tracers = [];
function tracer(a, b, col) { const g = new THREE.BufferGeometry().setFromPoints([a.clone(), b.clone()]); const m = new THREE.Line(g, trMat.clone()); m.material.color.set(col); scene.add(m); tracers.push({ m, t: .06 }); }
function fireProj(type, from, dir, dmg, splash, col) {
  const speed = type === 'ray' ? 36 : type === 'nade' ? 30 : 24;
  let mesh;
  if (type === 'ray') mesh = new THREE.Mesh(new THREE.CapsuleGeometry(.06, .5, 4, 8), new THREE.MeshBasicMaterial({ color: col || 0x3aff5a }));
  else if (type === 'shrimp') { mesh = new THREE.Group(); const b = new THREE.Mesh(new THREE.CapsuleGeometry(.09, .28, 4, 8), new THREE.MeshStandardMaterial({ color: 0xff7a4a, emissive: 0xff4a1a, emissiveIntensity: .6 })); b.rotation.x = Math.PI / 2; mesh.add(b); }
  else mesh = new THREE.Mesh(new THREE.SphereGeometry(.09, 10, 8), new THREE.MeshBasicMaterial({ color: col || 0xff3a3a }));
  mesh.position.copy(from); mesh.lookAt(_v.copy(from).add(dir)); if (type === 'ray') mesh.rotateX(Math.PI / 2);
  scene.add(mesh); proj.push({ type, pos: from.clone(), vel: dir.clone().multiplyScalar(speed), dmg, splash: splash || 2, col: col || 0xff8a3a, mesh, life: 3, grav: type === 'nade' ? 3 : 0 });
}
function throwNade() {
  if (P.nades <= 0 || P.nadeT > 0) return; P.nades--; P.nadeT = .7;
  const f = camDir(V3()), from = V3(P.pos.x, 1.0 + P.y, P.pos.z).addScaledVector(f, .4);
  const mesh = K['grenade-a'].scene.clone(true); mesh.scale.setScalar(1.6); scene.add(mesh);
  proj.push({ type: 'grenade', pos: from, vel: f.multiplyScalar(13).add(V3(0, 3.5, 0)).add(P.vel.clone().multiplyScalar(.5)), dmg: 300 + G.round * 120, splash: 3.6, mesh, life: 1.8, grav: 13, fuse: true });
  tone(400, .1, 'square', .05, -200); updHud();
}
function updProj(dt) {
  for (let i = proj.length - 1; i >= 0; i--) {
    const p = proj[i]; p.life -= dt; p.vel.y -= p.grav * dt;
    const np = _v.copy(p.pos).addScaledVector(p.vel, dt); let boom = false;
    if (p.fuse) {
      if (solid(np.x, p.pos.y, p.pos.z)) p.vel.x *= -.5; if (solid(p.pos.x, p.pos.y, np.z)) p.vel.z *= -.5;
      if (np.y < .12) { p.vel.y = Math.abs(p.vel.y) * .4; p.vel.x *= .7; p.vel.z *= .7; if (Math.abs(p.vel.y) > 1) tone(900, .03, 'square', .03); }
      p.pos.addScaledVector(p.vel, dt); p.pos.y = Math.max(.12, p.pos.y); p.mesh.rotation.x += dt * 8;
      if (p.life <= 0) boom = true;
    } else {
      if (solid(np.x, np.y, np.z) || p.life <= 0) boom = true;
      else for (const z of Z) if (!z.dead && Math.hypot(z.pos.x - np.x, z.pos.z - np.z) < .45 && np.y > z.pos.y && np.y < z.pos.y + 1.9) { boom = true; break; }
      p.pos.copy(np);
      if (p.type === 'ray') glow.emit(p.pos.x, p.pos.y, p.pos.z, 0, 0, 0, new THREE.Color(p.col), .3, .15);
      else if (Math.random() < .6) fx.emit(p.pos.x, p.pos.y, p.pos.z, 0, .3, 0, new THREE.Color(0x777777), .15, .4, 0, 2);
    }
    p.mesh.position.copy(p.pos);
    if (boom) { explode(p.pos, p.splash, p.dmg, p.type === 'ray' ? p.col : 0xff8a3a, p.type !== 'ray'); scene.remove(p.mesh); proj.splice(i, 1); }
  }
  for (let i = tracers.length - 1; i >= 0; i--) { const t = tracers[i]; t.t -= dt; t.m.material.opacity = Math.max(0, t.t / .06) * .8; if (t.t <= 0) { scene.remove(t.m); t.m.geometry.dispose(); tracers.splice(i, 1); } }
}
function explode(pos, r, dmg, col, big) {
  const c = new THREE.Color(col);
  glow.burst(pos.x, pos.y + .2, pos.z, big ? 40 : 16, c, big ? 4 : 2, big ? .5 : .3, .5, 1);
  if (big) { fx.burst(pos.x, pos.y + .2, pos.z, 26, new THREE.Color(0x333333), 2.5, .5, 1.2, -1); S.boom(); boomLight.position.copy(pos); boomLight.position.y += .5; boomLight.intensity = 30; }
  const d0 = pos.distanceTo(P.pos); if (d0 < 9) { P.shake = Math.max(P.shake, (big ? 1.2 : .4) * (1 - d0 / 9)); rumble(big ? .9 : .3, .6, 220); }
  let hits = 0, kills = 0;
  for (const z of Z) { if (z.dead) continue; const d = Math.hypot(z.pos.x - pos.x, z.pos.z - pos.z); if (d < r && Math.abs(z.pos.y + .9 - pos.y) < 2.2) { hits++; if (hitZombie(z, dmg * (1 - d / r * .5), false, 'explo')) kills++; } }
  if (hits) hitmark(kills > 0, false);
}
function knife() {
  if (P.knifeT >= 0) return; P.knifeT = 0; P.reloadT = 0; S.knife();
  const f = V3(-Math.sin(P.yaw), 0, -Math.cos(P.yaw)); let best = null, bd = 2.3;
  for (const z of Z) { if (z.dead || z.state === 'rise' && z.pos.y < -.8) continue; const dx = z.pos.x - P.pos.x, dz = z.pos.z - P.pos.z, d = Math.hypot(dx, dz); if (d < bd && (dx * f.x + dz * f.z) / d > .45) { bd = d; best = z; } }
  if (best) { P.knifeTarget = best; if (bd > 1.1) P.vel.addScaledVector(f, 7); }
}
function knifeHit() {
  const z = P.knifeTarget; P.knifeTarget = null;
  if (z && !z.dead && Math.hypot(z.pos.x - P.pos.x, z.pos.z - P.pos.z) < 1.6) { const k = hitZombie(z, 150, false, 'knife'); hitmark(k, false); fx.burst(z.pos.x, .8, z.pos.z, 10, new THREE.Color(0x5a0a0a), 2, .1, .5, 6); rumble(.5, .5, 90); z.vel.addScaledVector(V3(z.pos.x - P.pos.x, 0, z.pos.z - P.pos.z).normalize(), 3); }
}
function startReload() { const w = curW(); if (!w || P.reloadT > 0 || w.res <= 0 || w.mag >= stat(w, 'mag') || P.knifeT >= 0) return; P.reloadT = stat(w, 'rel') * (P.perks.includes('speed') ? .5 : 1); P.reloadMax = P.reloadT; S.reload(); }
function finishReload() { const w = curW(); if (!w) return; const n = Math.min(stat(w, 'mag') - w.mag, w.res); w.mag += n; w.res -= n; updHud(); }
function toggleView() { FP = !FP; save.opt.fp = FP; LS.set('opt', save.opt); tone(600, .05, 'square', .04); toast2(FP ? 'Primera persona' : 'Tercera persona'); }
function toast2(t) { banner('', t, 1.2); }
function swap() { if (P.weapons.length < 2) return; P.cur = (P.cur + 1) % P.weapons.length; P.reloadT = 0; P.swapT = .45; setGunMesh(); updHud(); tone(300, .05, 'square', .04); tone(500, .05, 'square', .04, 0, .1); }

/* ---------- potenciadores ---------- */
const PU_TEX = {};
function puTex(type) {
  if (PU_TEX[type]) return PU_TEX[type];
  return (PU_TEX[type] = canvasTex(128, 128, (c, w, h) => {
    const g = c.createRadialGradient(64, 64, 10, 64, 64, 64); g.addColorStop(0, 'rgba(120,255,140,.9)'); g.addColorStop(.55, 'rgba(40,200,80,.45)'); g.addColorStop(1, 'rgba(0,120,40,0)'); c.fillStyle = g; c.fillRect(0, 0, w, h);
    c.fillStyle = '#ffe680'; c.strokeStyle = '#3a2a00'; c.lineWidth = 4; c.textAlign = 'center'; c.textBaseline = 'middle';
    if (type === 'ammo') { for (const x of [44, 64, 84]) { c.beginPath(); c.roundRect ? c.roundRect(x - 7, 46, 14, 40, [7, 7, 2, 2]) : c.rect(x - 7, 46, 14, 40); c.fill(); c.stroke(); } }
    else if (type === 'insta') { c.beginPath(); c.arc(64, 58, 26, 0, 7); c.fill(); c.stroke(); c.fillRect(48, 76, 32, 16); c.strokeRect(48, 76, 32, 16); c.fillStyle = '#3a2a00'; c.beginPath(); c.arc(54, 58, 7, 0, 7); c.arc(74, 58, 7, 0, 7); c.fill(); }
    else if (type === 'double') { c.font = '900 58px Impact, sans-serif'; c.strokeText('x2', 64, 66); c.fillText('x2', 64, 66); }
    else if (type === 'nuke') { c.beginPath(); c.arc(64, 64, 30, 0, 7); c.fill(); c.stroke(); c.fillStyle = '#3a2a00'; for (let i = 0; i < 3; i++) { const a = i * 2.094 - 1.57; c.beginPath(); c.moveTo(64, 64); c.arc(64, 64, 26, a - .5, a + .5); c.fill(); } c.fillStyle = '#ffe680'; c.beginPath(); c.arc(64, 64, 7, 0, 7); c.fill(); }
    else if (type === 'carpenter') { c.save(); c.translate(64, 64); c.rotate(-.6); c.fillRect(-6, -10, 12, 46); c.strokeRect(-6, -10, 12, 46); c.fillRect(-26, -30, 52, 20); c.strokeRect(-26, -30, 52, 20); c.restore(); }
  }));
}
function spawnPowerup(type, x, z) {
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: puTex(type), transparent: true, depthWrite: false, fog: false })); s.scale.setScalar(.9); s.position.set(x, .8, z); scene.add(s);
  pups.push({ type, s, t: 0 }); tone(660, .2, 'triangle', .08); tone(990, .2, 'triangle', .06, 0, .1);
}
function updPowerups(dt) {
  for (let i = pups.length - 1; i >= 0; i--) {
    const p = pups[i]; p.t += dt; p.s.position.y = .8 + Math.sin(p.t * 3) * .12; p.s.material.rotation = Math.sin(p.t * 2) * .2;
    if (Math.random() < .3) glow.emit(p.s.position.x + rnd(-.3, .3), .3, p.s.position.z + rnd(-.3, .3), 0, .8, 0, new THREE.Color(0x5aff7a), .12, .6);
    p.s.visible = p.t < 20 || Math.floor(p.t * (p.t > 25 ? 8 : 4)) % 2 === 0;
    if (Math.hypot(p.s.position.x - P.pos.x, p.s.position.z - P.pos.z) < 1.1 && P.alive) { grabPowerup(p.type); scene.remove(p.s); pups.splice(i, 1); }
    else if (p.t > 30) { scene.remove(p.s); pups.splice(i, 1); }
  }
}
function grabPowerup(type) {
  S.powerup(); setTimeout(() => S.puSpeak(), 200); banner(PU_NAME[type], '', 2);
  if (type === 'ammo') { for (const w of P.weapons) w.res = stat(w, 'res'); P.nades = Math.max(P.nades, 4); }
  if (type === 'insta') G.instaT = 30;
  if (type === 'double') G.dblT = 30;
  if (type === 'carpenter') { for (const w of MAP.WINDOWS) while (w.boards < 6) { const m = w.meshes[w.boards]; w.boards++; m.visible = true; m.position.copy(m.userData.home); m.rotation.copy(m.userData.rot); const k = boardsFly.findIndex(b => b.m === m); if (k >= 0) boardsFly.splice(k, 1); } addPts(200); S.build(); }
  if (type === 'nuke') { $('flash').style.transition = 'none'; $('flash').style.opacity = .9; requestAnimationFrame(() => { $('flash').style.transition = 'opacity 1.4s'; $('flash').style.opacity = 0; }); S.boom(); let delay = 0; for (const z of Z) if (!z.dead) { z.nuked = true; setTimeout(() => { if (!z.dead) { z.die(false); P.kills++; } }, (delay += 60)); } addPts(400); rumble(1, 1, 500); }
  updHud();
}

/* ---------- daño al jugador ---------- */
function hurtPlayer(z) {
  if (!P.alive) return;
  P.hp -= 50; P.hurtT = 0; S.hurt(); rumble(.9, .7, 200); P.shake = Math.max(P.shake, .6);
  if (P.hp <= 0) goDown();
}
function goDown() {
  P.alive = false; P.downT = 0; S.down(); touchAim(false); $('downed').hidden = false; P.reloadT = 0;
  if (P.perks.includes('revive')) { P.selfRevive = true; P.reviveUses++; $('downTxt').textContent = 'Quick Revive te está levantando…'; }
  else { P.selfRevive = false; $('downTxt').textContent = ''; }
  rumble(1, 1, 600);
}
function revive() { P.alive = true; P.hp = 100; losePerks(); $('downed').hidden = true; for (const z of Z) if (!z.dead && Math.hypot(z.pos.x - P.pos.x, z.pos.z - P.pos.z) < 2.5) z.vel.add(V3(z.pos.x - P.pos.x, 0, z.pos.z - P.pos.z).normalize().multiplyScalar(5)); banner('¡DE PIE!', 'Has perdido tus ventajas', 2); }
function gameOver() {
  G.state = 'over'; ambient(false); unlockPointer(); $('hud').hidden = true;
  const best = G.round > (save.bests[MAP.MAPID] || 0) && G.round > 1; if (best) { save.bests[MAP.MAPID] = G.round; LS.set('bests', save.bests); }
  $('oRounds').textContent = G.round; $('oRw').textContent = G.round === 1 ? 'ronda' : 'rondas'; $('oBest').hidden = !best;
  const m = Math.floor(G.time / 60), s = Math.floor(G.time % 60);
  $('oStats').innerHTML = `<div><b>${P.kills}</b>Muertes</div><div><b>${P.heads}</b>Tiros a la cabeza</div><div><b>${P.score || 0}</b>Puntos ganados</div><div><b>${m}:${String(s).padStart(2, '0')}</b>Tiempo</div>`;
  showScreen('over');
}

/* ---------- bucle del juego ---------- */
const clock = new THREE.Clock();
let menuT = 0;
function update(dt) {
  G.time += dt;
  const alive = P.alive;
  // entrada
  if (I.pressed.has('pause')) return pauseGame();
  // mirar
  const ads = I.aim && alive && P.reloadT <= 0 && P.swapT <= 0;
  if (ads && !P.aimPrev && opts.assist && (I.device !== 'kb')) aimSnap();
  P.aimPrev = ads;
  P.adsK = clamp(P.adsK + (ads ? dt : -dt) * 7, 0, 1);
  let lk = lerp(1, .6, P.adsK);
  if (opts.assist && I.device !== 'kb' && overZombie()) lk *= .55;
  if (alive) { P.yaw += I.lx * lk; P.pitch = clamp(P.pitch + I.ly * lk, -1.1, 1.0); }
  if (P.snap) { P.snap.t += dt; const k = Math.min(1, P.snap.t / .12); P.yaw = lerpAngle(P.snap.y0, P.snap.y1, k); P.pitch = lerp(P.snap.p0, P.snap.p1, k); if (k >= 1) P.snap = null; }
  P.pitch += P.recoil * dt * 12 * .5; P.recoil = Math.max(0, P.recoil - dt * P.recoil * 14);
  // moverse
  const f = V3(-Math.sin(P.yaw), 0, -Math.cos(P.yaw)), r = V3(Math.cos(P.yaw), 0, -Math.sin(P.yaw));
  let mx = alive ? I.mx : 0, my = alive ? I.my : 0; const m = Math.hypot(mx, my); if (m > 1) { mx /= m; my /= m; }
  const sprint = I.sprint && my > .3 && P.adsK < .3 && P.reloadT <= 0; P.sprintNow = sprint;
  let sp = (sprint ? (P.perks.includes('stamin') ? 6.6 : 5.5) : (P.perks.includes('stamin') ? 4.4 : 3.8)) * lerp(1, .55, P.adsK) * (my < -.1 ? .8 : 1);
  if (!alive) sp = 0;
  const tv = V3().addScaledVector(f, my * sp).addScaledVector(r, mx * sp);
  P.vel.x = lerp(P.vel.x, tv.x, Math.min(1, dt * 12)); P.vel.z = lerp(P.vel.z, tv.z, Math.min(1, dt * 12));
  P.pos.addScaledVector(P.vel, dt); collide(P.pos, .34);
  if (I.pressed.has('jump') && P.y <= 0 && alive) { P.vy = 4.6; tone(200, .08, 'sine', .05, 100); }
  P.vy -= 15 * dt; P.y = Math.max(0, P.y + P.vy * dt); if (P.y <= 0) P.vy = 0;
  // empujar a los zombis que pisas
  for (const z of Z) { if (z.dead || z.state !== 'chase') continue; const dx = P.pos.x - z.pos.x, dz = P.pos.z - z.pos.z, d = Math.hypot(dx, dz); if (d < .6 && d > 1e-4) { P.pos.x += dx / d * (.6 - d); P.pos.z += dz / d * (.6 - d); } }
  collide(P.pos, .34);
  // acciones
  const w = curW();
  P.fireT -= dt; P.swapT -= dt; P.nadeT -= dt;
  curInt = alive ? pickInteract() : null;
  if (curInt && curInt.hold && I.held.has('use')) { P.buildT -= dt; if (P.buildT <= 0) { P.buildT = .55; repairBoard(curInt.win); } }
  else P.buildT = 0;
  if (alive) {
    if (I.pressed.has('use') && curInt && !curInt.hold && !curInt.info) curInt.act();
    else if (I.pressed.has('reload') && !(curInt && !curInt.info && I.device === 'pad')) startReload();
    if (I.pressed.has('swap')) swap();
    if (I.pressed.has('view')) toggleView();
    if (I.pressed.has('knife')) knife();
    if (I.pressed.has('nade')) throwNade();
    if (P.reloadT > 0) { P.reloadT -= dt; if (P.reloadT <= 0) finishReload(); }
    if (P.knifeT >= 0) { const k0 = P.knifeT; P.knifeT += dt; if (k0 < .12 && P.knifeT >= .12) knifeHit(); if (P.knifeT > .45) P.knifeT = -1; }
    const auto = w && stat(w, 'auto');
    if (I.fire && w && P.fireT <= 0 && P.reloadT <= 0 && P.swapT <= 0 && P.knifeT < 0 && !sprint && (auto || !P.firePrev)) shoot();
    if (w && w.mag === 0 && w.res > 0 && P.reloadT <= 0 && P.fireT <= 0 && !I.fire) startReload();
  }
  P.firePrev = I.fire;
  // vida
  P.hurtT += dt; if (P.hurtT > 2.6 && alive) P.hp = Math.min(P.maxHp, P.hp + dt * 120);
  if (!alive) { P.downT += dt; if (P.selfRevive && P.downT > 3.5) revive(); else if (!P.selfRevive && P.downT > 2.6) return gameOver(); }
  // zombis
  flow(P.pos.x, P.pos.z);
  for (let i = Z.length - 1; i >= 0; i--) if (!Z[i].update(dt, P)) { Z[i].dispose(); Z.splice(i, 1); }
  separate(Z);
  // rondas
  if (G.breakT > 0) { G.breakT -= dt; if (G.breakT <= 0) startRound(G.round + 1); }
  else {
    G.spawnT -= dt;
    if (G.toSpawn > 0 && G.spawnT <= 0 && aliveCount() < 24) { if (spawnZombie()) G.toSpawn--; G.spawnT = G.special ? rnd(.6, 1.4) : Math.max(.45, 2.2 - G.round * .14) * rnd(.7, 1.3); }
    if (G.toSpawn <= 0 && aliveCount() === 0) endRound();
  }
  G.instaT = Math.max(0, G.instaT - dt); G.dblT = Math.max(0, G.dblT - dt);
  // resto
  updBox(dt); updPap(dt); updBoards(dt); updProj(dt); updPowerups(dt); updSong(dt);
  for (const d of MAP.DOORS) if (d.open && d.mesh.visible) { d.anim += dt; d.mesh.position.y = d.anim * d.anim * 6; d.mesh.children.forEach((b, i) => b.rotation.y += dt * (i % 2 ? 3 : -3)); if (d.anim > 1) d.mesh.visible = false; }
  if (flash.visible && (flash.userData.t -= dt) <= 0) flash.visible = false; updSplats(dt); updCityLights(false, dt);
  muzzleLight.intensity = Math.max(0, muzzleLight.intensity - dt * 80); boomLight.intensity = Math.max(0, boomLight.intensity - dt * 90);
  for (const l of LAMPS) if (l.userData.fire) { l.intensity = 5 + Math.sin(G.time * 13 + l.position.x) * 1.2 + Math.sin(G.time * 7.3) * .8; if (Math.random() < dt * 6) glow.emit(l.position.x + rnd(-.2, .2), .5, l.position.z + rnd(-.2, .2), rnd(-.2, .2), rnd(1, 2), rnd(-.2, .2), new THREE.Color(0xff8a2a), .14, .7); }
  fx.update(dt); glow.update(dt);
  updPlayerModel(dt, sprint);
  updCamera(dt);
  updHudFrame(dt);
}
const lerpAngle = (a, b, k) => a + Math.atan2(Math.sin(b - a), Math.cos(b - a)) * k;
function aimTargets() {
  const o = camera.position, f = camera.getWorldDirection(V3()), L = [];
  for (const z of Z) {
    if (z.dead || z.state === 'rise' && z.pos.y < -.6) continue;
    const t = V3(z.pos.x, z.pos.y + 1.25 * z.hs, z.pos.z), d = t.distanceTo(o); if (d > 26) continue;
    const dir = t.clone().sub(o).normalize(), ang = Math.acos(clamp(dir.dot(f), -1, 1));
    if (wallT(o, dir, d) < d - .3) continue; L.push({ z, t, ang, d, dir });
  }
  return L;
}
function aimSnap() { let best = null; for (const a of aimTargets()) if (a.ang < .2 && (!best || a.ang < best.ang)) best = a; if (!best) return; const yaw = Math.atan2(-best.dir.x, -best.dir.z), pitch = Math.asin(best.dir.y) - camPitchBias(); P.snap = { t: 0, y0: P.yaw, y1: yaw, p0: P.pitch, p1: pitch }; }
function overZombie() { if (!I.stickLook && I.device === 'pad') return false; for (const a of aimTargets()) if (a.ang < .06 + .25 / a.d) return true; return false; }
const camPitchBias = () => 0;
function updPlayerModel(dt, sprint) {
  const sp = Math.hypot(P.vel.x, P.vel.z);
  shrimp.root.position.set(P.pos.x, P.y, P.pos.z);
  shrimp.root.rotation.y = P.yaw;
  P.ph += dt * sp * 3.2;
  shrimp.pose(P.ph, sp > .4 ? 'run' : 'idle', G.time, dt, sp);
  const kn = P.knifeT >= 0 ? Math.sin(Math.min(1, P.knifeT / .3) * Math.PI) : 0;
  shrimp.tilt.rotation.x = !P.alive ? Math.min(1, P.downT * 2) * -1.2 : -kn * .35 + (sprint ? -.08 : 0);
  shrimp.tilt.rotation.z = !P.alive ? Math.min(1, P.downT * 2) * 1.4 : 0;
  gunPivot.rotation.x = P.pitch * .85 + (P.reloadT > 0 ? -.6 * Math.sin(Math.PI * (1 - P.reloadT / P.reloadMax)) : 0) + (P.swapT > 0 ? -P.swapT * 2 : 0) + (sprint ? -.35 : 0);
  gunPivot.rotation.z = P.reloadT > 0 ? .4 * Math.sin(Math.PI * (1 - P.reloadT / P.reloadMax)) : 0;
  gunHolder.position.z = Math.max(0, P.fireT) * .6 * (1 - P.adsK * .5);
  gunHolder.position.x = kn * .25; gunHolder.rotation.z = kn * 1.2;
  gunHolder.visible = !!curW();
}
const camPos = V3(), camLook = V3();
/* ---------- primera persona: arma en primer plano (escena aparte para que no atraviese paredes) ---------- */
let FP = !!save.opt.fp;
const vmScene = new THREE.Scene(), vmCam = new THREE.PerspectiveCamera(60, 1, .01, 10), vmHolder = new THREE.Group(), vmGun = new THREE.Group();
vmScene.add(new THREE.HemisphereLight(0xc8d0ff, 0x302820, 1.6)); const vmSun = new THREE.DirectionalLight(0xfff0e0, 1.6); vmSun.position.set(1, 2, 1); vmScene.add(vmSun);
vmScene.add(vmHolder); vmHolder.add(vmGun);
const clawMat = new THREE.MeshStandardMaterial({ color: 0xf0a080, roughness: .6 });
function setViewGun() {
  vmGun.clear(); const w = curW(); if (!w) return;
  const g = gunModel(w.id, w.pap); vmGun.add(g); vmGun.userData.len = GUNS[w.id].len;
  // pinzas de gamba sujetando el arma
  const c = new THREE.Mesh(new THREE.CapsuleGeometry(.03, .14, 4, 8), clawMat); c.position.set(.01, -.07, GUNS[w.id].len * .12); c.rotation.set(.9, 0, .3); vmGun.add(c);
}
function updViewModel(dt) {
  const w = curW(), scoped = w && GUNS[w.id].scope && P.adsK > .85;
  vmHolder.visible = FP && !!w && !scoped && P.alive; $('scope').hidden = !(FP && scoped);
  if (!vmHolder.visible) return;
  const ads = P.adsK, sp = Math.hypot(P.vel.x, P.vel.z), bob = Math.min(1, sp / 4) * (1 - ads * .8);
  const rel = P.reloadT > 0 ? Math.sin(Math.PI * (1 - P.reloadT / P.reloadMax)) : 0, kick = Math.max(0, P.fireT) * (GUNS[w.id].pel > 1 || GUNS[w.id].dmg > 100 ? 1.6 : 1);
  const len = vmGun.userData.len || .5;
  vmHolder.position.set(lerp(.15, 0, ads) + Math.sin(P.ph * .5) * .012 * bob - I.lx * .05, lerp(-.14, -.07, ads) - Math.abs(Math.cos(P.ph * .5)) * .012 * bob - rel * .08 - Math.max(0, P.swapT) * .5 + I.ly * .04, lerp(-.3 - len * .5, -.22 - len * .5, ads) + kick * .5);
  vmHolder.rotation.set(-rel * .6 + kick * 1.2 + (P.sprintNow ? -.4 : 0), (P.sprintNow ? .6 : 0) + lerp(.05, 0, ads), rel * .5);
  vmCam.aspect = camera.aspect; vmCam.fov = lerp(60, 50, ads); vmCam.updateProjectionMatrix();
}
function updCamera(dt) {
  const ads = P.adsK, down = !P.alive ? Math.min(1, P.downT * 1.5) : 0;
  shrimp.root.visible = !FP || G.state !== 'play';
  if (FP && G.state === 'play') {
    const cp = Math.cos(P.pitch), f = V3(-Math.sin(P.yaw) * cp, Math.sin(P.pitch), -Math.cos(P.yaw) * cp);
    const bob = Math.min(1, Math.hypot(P.vel.x, P.vel.z) / 4) * (1 - ads * .8) * .03;
    camPos.set(P.pos.x, P.y + 1.02 - down * .6 + Math.abs(Math.sin(P.ph * .5)) * bob, P.pos.z);
    camera.position.copy(camPos); camLook.copy(camPos).add(f); camera.lookAt(camLook);
    if (P.shake > 0) { camera.rotation.x += rnd(-1, 1) * P.shake * .012; camera.rotation.y += rnd(-1, 1) * P.shake * .012; P.shake = Math.max(0, P.shake - dt * 3); }
    if (down) camera.rotation.z += down * .5;
    const w = curW(), fov = w && GUNS[w.id].scope && ads > .85 ? 18 : lerp(72, 52, ads); if (Math.abs(camera.fov - fov) > .05) { camera.fov = fov; camera.updateProjectionMatrix(); }
    updViewModel(dt); return;
  }
  updViewModel(dt);
  const pivot = V3(P.pos.x, P.y + lerp(1.12, 1.08, ads) - down * .35, P.pos.z);
  const cp = Math.cos(P.pitch), f = V3(-Math.sin(P.yaw) * cp, Math.sin(P.pitch), -Math.cos(P.yaw) * cp), r = V3(Math.cos(P.yaw), 0, -Math.sin(P.yaw));
  const want = lerp(1.85, 1.05, ads), sh = lerp(.55, .45, ads);
  const side = V3().copy(pivot).addScaledVector(r, sh);
  // que la cámara no atraviese las paredes
  let dist = want; const back = f.clone().negate();
  for (let t = 0; t <= want + .25; t += .05) { if (solid(side.x + back.x * t, side.y + back.y * t + .15, side.z + back.z * t, true) || solid(side.x + back.x * t + r.x * .15, side.y + back.y * t, side.z + back.z * t + r.z * .15, true)) { dist = Math.max(.2, t - .25); break; } }
  let shSafe = sh; for (let s = 0; s <= sh + .2; s += .05) if (solid(pivot.x + r.x * s, pivot.y, pivot.z + r.z * s, true)) { shSafe = Math.max(0, s - .25); break; }
  side.copy(pivot).addScaledVector(r, shSafe);
  camPos.copy(side).addScaledVector(back, dist).add(V3(0, .12, 0));
  camera.position.copy(camPos); camLook.copy(camPos).add(f); camera.lookAt(camLook);
  if (P.shake > 0) { camera.rotation.x += rnd(-1, 1) * P.shake * .012; camera.rotation.y += rnd(-1, 1) * P.shake * .012; P.shake = Math.max(0, P.shake - dt * 3); }
  if (down) camera.rotation.z += down * .35;
  const fov = lerp(66, 46, ads); if (Math.abs(camera.fov - fov) > .05) { camera.fov = fov; camera.updateProjectionMatrix(); }
}

/* ---------- HUD ---------- */
let hudCache = {};
function setHud(id, v, prop = 'textContent') { if (hudCache[id + prop] !== v) { hudCache[id + prop] = v; $(id)[prop] = v; } }
function updHud(force) {
  if (force) hudCache = {};
  const w = curW();
  setHud('points', String(P.points));
  setHud('gunName', w ? (w.pap ? GUNS[w.id].pap.name : GUNS[w.id].name) : 'Cuchillo');
  $('gunName').classList.toggle('pap', !!(w && w.pap));
  setHud('mag', w ? String(w.mag) : '—'); setHud('res', w ? String(w.res) : '');
  $('ammo').classList.toggle('low', !!w && w.mag <= Math.ceil(stat(w, 'mag') * .25));
  setHud('nades', '<i></i>'.repeat(P.nades), 'innerHTML');
}
function updPerksHud() { $('perks').innerHTML = P.perks.map(id => `<i style="background:#${new THREE.Color(PERKS[id].col).getHexString()}"><svg viewBox="0 0 24 24">${PERK_ICON[id]}</svg></i>`).join(''); }
function setRoundHud(flash, ending) {
  const n = G.round, el = $('round');
  if (n <= 5) { let s = '<svg viewBox="0 0 70 60">'; for (let i = 0; i < Math.min(4, n); i++) s += `<path d="M${10 + i * 13} 8 L${8 + i * 13} 54" stroke-width="7" stroke-linecap="round"/>`; if (n === 5) s += '<path d="M2 44 L62 14" stroke-width="7" stroke-linecap="round"/>'; el.innerHTML = s + '</svg>'; }
  else el.textContent = n;
  if (flash) { el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash'); }
}
let bannerT = 0;
function banner(t, sub = '', dur = 2) { $('banner').textContent = t; $('sub').textContent = sub; $('banner').style.opacity = 1; $('sub').style.opacity = sub ? 1 : 0; bannerT = dur; }
let hitT = 0;
function hitmark(kill, head) { const h = $('hitm'); h.classList.toggle('kill', kill); h.style.opacity = 1; hitT = .18; if (!kill) S.hitmark(); }
function updHudFrame(dt) {
  if ((bannerT -= dt) <= 0 && bannerT > -1) { $('banner').style.opacity = 0; $('sub').style.opacity = 0; bannerT = -2; }
  if (hitT > 0 && (hitT -= dt) <= 0) $('hitm').style.opacity = 0;
  const hpK = 1 - P.hp / P.maxHp; $('blood').style.opacity = P.alive ? clamp(hpK * 1.3, 0, 1) : 1;
  const w = curW(), sp = w ? stat(w, 'spread') : .02;
  $('cross').style.setProperty('--s', (lerp(10, 3, P.adsK) + sp * 260 * lerp(1, .3, P.adsK) + Math.hypot(P.vel.x, P.vel.z) * 2.2 + P.recoil * 120) + 'px');
  $('cross').style.opacity = P.alive && P.reloadT <= 0 ? 1 : .25;
  setHud('prompt', promptHtml(curInt), 'innerHTML');
  const showUse = I.device === 'touch' && curInt && !curInt.info && !curInt.hidden;
  $('useBtn').classList.toggle('show', !!showUse);
  if (showUse) setHud('useBtn', curInt.hold ? 'MANTÉN' : curInt.cost ? `USAR · ${curInt.cost}` : 'USAR');
  let pu = ''; if (G.instaT > 0) pu += `<div class="${G.instaT < 5 ? 'blink' : ''}"><svg viewBox="0 0 24 24" width="24"><path d="M12 2a8 8 0 0 0-8 8c0 3 1.500 5 3 6v3h10v-3c1.500-1 3-3 3-6a8 8 0 0 0-8-8z" fill="#c8ffd4"/><circle cx="9" cy="10" r="2" fill="#0a3a1a"/><circle cx="15" cy="10" r="2" fill="#0a3a1a"/></svg></div>`; if (G.dblT > 0) pu += `<div class="${G.dblT < 5 ? 'blink' : ''}">x2</div>`;
  setHud('pups', pu, 'innerHTML');
  document.querySelector('.tbtn.aim').classList.toggle('on', touchAim());
  if (P.reloadT > 0) setHud('res', 'Recargando…'); else if (w) setHud('res', String(w.res));
  setHud('mag', w ? String(w.mag) : '—');
}

/* ---------- ruidos de los zombis ---------- */
let groanCd = 0;
function groan(z) { if (groanCd > 0) return; groanCd = .6; S.groan(z.kind === 'skel' ? 1.8 : 1); }
setInterval(() => groanCd = Math.max(0, groanCd - .1), 100);

/* ---------- pantallas y menús ---------- */
const SCREENS = ['menu', 'maps', 'chars', 'ctrls', 'sets', 'pause', 'over'];
let screenBack = 'menu';
function showScreen(id) {
  for (const s of SCREENS) $(s).hidden = s !== id;
  setMenu(id ? $(id) : null);
  document.body.classList.toggle('inmenu', !!id);
}
function pauseGame() { if (G.state !== 'play') return; G.state = 'pause'; unlockPointer(); ambient(false); $('pauseInfo').textContent = `Ronda ${G.round} · ${P.kills} muertes · ${P.points} puntos`; showScreen('pause'); }
function resumeGame() { G.state = 'play'; showScreen(null); resetTouch(); document.querySelectorAll('.tbtn.on').forEach(b => b.classList.remove('on')); lockPointer(cv); ambient(true); clock.getDelta(); }
function toMenu() { G.state = 'menu'; ambient(false); unlockPointer(); $('hud').hidden = true; resetLevelState(); resetPlayer(); setGunMesh(); $('mBest').textContent = save.bests[MAP.MAPID] ? `Ronda ${save.bests[MAP.MAPID]}` : '—'; $('mapName').textContent = MAP.CFG.name; document.querySelector('.mapname').textContent = MAP.CFG.name; showScreen('menu'); menuT = 0; }
function bindUI() {
  $('playBtn').onclick = () => { S.buy(); startGame(); };
  $('charBtn').onclick = () => { buildCharRow(); showScreen('chars'); };
  $('ctrlBtn').onclick = () => { screenBack = 'menu'; buildCtrlTable(); showScreen('ctrls'); };
  $('setBtn').onclick = () => { screenBack = 'menu'; syncSets(); showScreen('sets'); };
  $('pCtrlBtn').onclick = () => { screenBack = 'pause'; buildCtrlTable(); showScreen('ctrls'); };
  $('pSetBtn').onclick = () => { screenBack = 'pause'; syncSets(); showScreen('sets'); };
  $('charBack').onclick = () => showScreen('menu');
  $('ctrlBack').onclick = () => showScreen(screenBack);
  $('setBack').onclick = () => { LS.set('opt', save.opt); showScreen(screenBack); };
  $('resumeBtn').onclick = resumeGame;
  $('restartBtn').onclick = () => startGame();
  $('quitBtn').onclick = () => { if (G.round > (save.bests[MAP.MAPID] || 0)) { save.bests[MAP.MAPID] = G.round; LS.set('bests', save.bests); } toMenu(); };
  $('againBtn').onclick = () => startGame();
  $('menuBtn').onclick = () => toMenu();
  $('pauseBtn').addEventListener('touchstart', e => { e.stopPropagation(); e.preventDefault(); pauseGame(); }, { passive: false });
  $('pauseBtn').onclick = pauseGame;
  $('optSens').oninput = e => { save.opt.sens = +e.target.value; $('optSensV').textContent = save.opt.sens.toFixed(1); applyOpts(); };
  const tog = (id, k) => $(id).onclick = () => { save.opt[k] = !save.opt[k]; applyOpts(); syncSets(); if (k === 'music') ambient(false); S.buy(); };
  tog('optInv', 'invertY'); tog('optAssist', 'assist'); tog('optSfx', 'sfx'); tog('optMusic', 'music');
  $('optView').onclick = () => { toggleView(); syncSets(); };
  $('optGfx').onclick = () => { save.opt.gfx = save.opt.gfx === 'low' ? 'high' : 'low'; renderer.shadowMap.enabled = save.opt.gfx !== 'low'; scene.traverse(o => { if (o.material) o.material.needsUpdate = true; }); renderer.setPixelRatio(Math.min(devicePixelRatio, save.opt.gfx === 'low' ? 1.25 : 1.7)); resize(); LS.set('opt', save.opt); syncSets(); };
  $('viewBtn').addEventListener('touchstart', e => { e.stopPropagation(); e.preventDefault(); toggleView(); }, { passive: false }); $('viewBtn').onclick = toggleView;
  $('mapBtn').onclick = () => { buildMapList(); showScreen('maps'); };
  $('mapsBack').onclick = () => showScreen('menu');
  bindTouch($('touch'), $('stick'), $('knob'));
  onDevice(d => { document.body.classList.toggle('nottouch', d !== 'touch'); document.body.classList.toggle('touch', d === 'touch'); updPadHint(); if (G.state === 'play') { hudCache.prompt = null; if (d === 'kb') lockPointer(cv); } });
  setNavSound(() => tone(700, .03, 'square', .03));
  document.addEventListener('visibilitychange', () => { if (document.hidden) pauseGame(); });
  cv.addEventListener('click', () => { if (G.state === 'play') lockPointer(cv); });
  document.addEventListener('pointerlockchange', () => { if (!document.pointerLockElement && G.state === 'play' && I.device === 'kb') pauseGame(); });
}
function updPadHint() { const g = pad(); $('padHint').textContent = g ? `Mando conectado: ${g.id.replace(/\(.*\)/, '').replace(/extended gamepad/i, '').trim().slice(0, 40)}` : ''; }
function buildMapList() {
  $('mapRow').innerHTML = Object.entries(MAP.MAPS).map(([id, m]) => `<button class="mapCard nav ${id === MAP.MAPID ? 'sel primary' : ''}" data-id="${id}"><b>${m.name}</b><small>${m.desc}</small><span>${Object.keys(m.zones).length} zonas · Récord: ${save.bests[id] ? 'ronda ' + save.bests[id] : '—'}</span></button>`).join('');
  $('mapRow').querySelectorAll('.mapCard').forEach(b => b.onclick = () => { const id = b.dataset.id; if (id !== MAP.MAPID) { save.map = id; LS.set('map', id); for (const z of Z) z.dispose(); Z.length = 0; buildWorld(id); toMenu(); } else showScreen('menu'); S.buy(); });
}
function syncSets() {
  $('optSens').value = save.opt.sens; $('optSensV').textContent = (+save.opt.sens).toFixed(1);
  const yn = v => v ? 'SÍ' : 'NO';
  $('optInv').querySelector('b').textContent = yn(save.opt.invertY); $('optAssist').querySelector('b').textContent = yn(save.opt.assist);
  $('optView').querySelector('b').textContent = FP ? '1ª PERSONA' : '3ª PERSONA';
  $('optGfx').querySelector('b').textContent = save.opt.gfx === 'low' ? 'RÁPIDOS' : 'ALTOS';
  $('optSfx').querySelector('b').textContent = yn(save.opt.sfx); $('optMusic').querySelector('b').textContent = yn(save.opt.music);
}
function buildCtrlTable() {
  const ps = I.padKind === 'ps', gx = ps ? { RT: 'R2', LT: 'L2', A: '✕', B: '○', X: '□', Y: '△', RB: 'R1', LB: 'L1', ST: 'OPTIONS' } : { RT: 'RT', LT: 'LT', A: 'A', B: 'B', X: 'X', Y: 'Y', RB: 'RB', LB: 'LB', ST: 'MENÚ' };
  const rows = [['Moverse', 'Stick izq.', 'W A S D', 'Joystick izq.'], ['Mirar', 'Stick dcho.', 'Ratón', 'Arrastrar a la dcha.'], ['Disparar', gx.RT, 'Clic', 'Botón rojo'], ['Apuntar', gx.LT, 'Clic dcho.', 'APUNTAR'], ['Recargar / Usar / Comprar', gx.X, 'R / F', 'Botones'], ['Cambiar de arma', gx.Y, 'Q', 'Flechas'], ['Cuchillo', 'R3 / ' + gx.B, 'V', 'Cuchillo'], ['Granada', gx.RB + ' / ' + gx.LB, 'G', 'Granada'], ['Saltar', gx.A, 'Espacio', 'Flecha arriba'], ['Correr', 'L3 / stick a tope', 'Mayús', 'Joystick a tope'], ['Cambiar vista', 'Cruceta ↑', 'C', 'Botón del ojo'], ['Pausa', gx.ST, 'Esc', 'Pausa']];
  $('ctrlTable').innerHTML = '<div class="h">Acción</div><div class="h">Mando</div><div class="h">Teclado</div><div class="h">Táctil</div>' + rows.map(r => `<div>${r[0]}</div><div><kbd>${r[1]}</kbd></div><div><kbd>${r[2]}</kbd></div><div>${r[3]}</div>`).join('');
}
const CHARS = [{ id: 'gamba', name: 'Gamba', desc: 'La de siempre' }, { id: 'chaqueta', name: 'Gamba Chaqueta', desc: 'Con su chupa de cuero' }, { id: 'langostino', name: 'Langostino', desc: 'Grande y duro' }, { id: 'langosta', name: 'Langosta', desc: 'Pinzas de acero' }, { id: 'cangrejo', name: 'Cangrejo de río', desc: 'Pequeño pero matón' }];
const thumbs = {};
async function makeThumbs() {
  const sc2 = new THREE.Scene(); sc2.add(new THREE.HemisphereLight(0xffffff, 0x553333, 2.2)); const dl = new THREE.DirectionalLight(0xffffff, 2); dl.position.set(2, 3, 3); sc2.add(dl);
  const cam = new THREE.PerspectiveCamera(30, 1, .05, 20);
  const size = renderer.getSize(new THREE.Vector2()), pr = renderer.getPixelRatio();
  renderer.setPixelRatio(1); renderer.setSize(220, 220, false);
  for (const c of CHARS) {
    const s = new Shrimp({ gamba: CH.gamba }); await s.use(c.id); s.root.rotation.y = -2.2; sc2.add(s.root); s.pose(0, 'idle', 0, .016);
    cam.position.set(0, .9, 2.3); cam.lookAt(0, .3, 0); renderer.setClearColor(0x000000, 0); sc2.background = null;
    renderer.clear(); renderer.render(sc2, cam); thumbs[c.id] = cv.toDataURL(); sc2.remove(s.root);
  }
  renderer.setPixelRatio(pr); renderer.setSize(size.x, size.y, false); renderer.setClearColor(0x000000, 1);
}
function buildCharRow() {
  $('charRow').innerHTML = CHARS.map(c => `<button class="char nav ${save.char === c.id ? 'sel primary' : ''}" data-id="${c.id}"><img src="${thumbs[c.id] || ''}" alt=""><b>${c.name}</b><small>${c.desc}</small></button>`).join('');
  $('charRow').querySelectorAll('.char').forEach(b => b.onclick = async () => { save.char = b.dataset.id; LS.set('char', save.char); S.buy(); await buildPlayer(save.char); setGunMesh(); buildCharRow(); setMenu($('chars')); });
}

/* ---------- menú: cámara de cine ---------- */
function updMenu(dt) {
  menuT += dt;
  P.yaw = -2.4 + Math.sin(menuT * .2) * .15; P.pitch = 0;
  updPlayerModel(dt, false);
  const a = menuT * .08 + .6, R = 3.4;
  camera.position.set(P.pos.x + Math.sin(a) * R, 1.25, P.pos.z + Math.cos(a) * R); camera.lookAt(P.pos.x - .4, .55, P.pos.z);
  if (camera.fov !== 50) { camera.fov = 50; camera.updateProjectionMatrix(); }
  if (LAMPS[0] && !LAMPS[0].userData.street) LAMPS[0].intensity = 5 + Math.sin(menuT * 9) * .4 * (Math.random() < .03 ? 6 : 1);
  fx.update(dt); glow.update(dt);
}

renderer.autoClear = false;
function draw() { renderer.clear(); if (save.opt.gfx !== 'low' && composer) { if (gradePass) gradePass.uniforms.hurt.value = P.alive === false ? 1 : clamp(1 - (P.hp || 100) / (P.maxHp || 100), 0, 1) * .8; composer.render(); } else renderer.render(scene, camera); if (FP && G.state !== 'menu' && vmHolder.visible) { renderer.clearDepth(); renderer.render(vmScene, vmCam); } }
function frame() {
  requestAnimationFrame(frame);
  const dt = Math.min(.05, clock.getDelta());
  poll(dt, G.state === 'play');
  if (G.state === 'play') update(dt);
  else if (G.state === 'menu') { updMenu(dt); if (I.pressed.has('pause') && false) { } }
  else if (G.state === 'pause') { if (I.pressed.has('pause')) resumeGame(); }
  if (G.state !== 'load') draw();
}

/* ---------- arranque ---------- */
// luz ambiental y reflejos de un HDRI nocturno real (Poly Haven, CC0)
async function loadEnv() {
  const pm = new THREE.PMREMGenerator(renderer), hdr = await new RGBELoader().loadAsync('models/h/noche.hdr');
  scene.environment = pm.fromEquirectangular(hdr).texture; scene.environmentIntensity = .12; hdr.dispose(); pm.dispose();
}
async function boot() {
  try { await loadAll(); } catch (e) { $('loadTxt').textContent = 'Error al cargar: ' + e.message; return; }
  $('loadTxt').textContent = 'Preparando el escenario…';
  if (Q.get('map')) save.map = Q.get('map');
  if (Q.get('char')) save.char = Q.get('char');
  try { await MAP.loadPBR(); } catch (e) { console.warn('PBR', e); }
  try { await loadEnv(); } catch (e) { console.warn('HDRI', e); }
  try { await loadTrees(); } catch (e) { console.warn('trees', e); }
  buildWorld(MAP.MAPS[save.map] ? save.map : 'nacht');
  try { setupFX(); } catch (e) { composer = null; }
  await makeThumbs();
  await buildPlayer(save.char);
  resetPlayer(); resetLevelState(); setGunMesh();
  bindUI(); updPadHint(); setInterval(updPadHint, 2000);
  document.body.classList.toggle('nottouch', !matchMedia('(pointer: coarse)').matches); document.body.classList.toggle('touch', matchMedia('(pointer: coarse)').matches);
  if (!matchMedia('(pointer: coarse)').matches) I.device = 'kb';
  if (Q.has('touch')) { I.device = 'touch'; document.body.classList.add('touch'); document.body.classList.remove('nottouch'); }
  $('loading').hidden = true;
  toMenu();
  if (Q.has('play')) startGame();
  if (Q.has('shot')) testShot();
  else frame();
}
// pruebas: simula unos segundos sin dibujar y saca una foto del resultado
async function testShot() {
  const T = +(Q.get('t') || 0), dt = 1 / 30, steps = Math.round(T / dt);
  if (Q.has('menu')) { const m = Q.get('menu'); if (m === 'chars') { buildCharRow(); showScreen('chars'); } else if (m === 'ctrls') { buildCtrlTable(); showScreen('ctrls'); } else if (m === 'sets') { syncSets(); showScreen('sets'); } else if (m === 'pause') { pauseGame(); } else if (m === 'over') { G.round = 7; P.kills = 93; P.heads = 31; P.score = 8450; G.time = 615; gameOver(); } }
  for (let i = 0; i < steps; i++) {
    I.pressed.clear(); I.held.clear(); I.lx = I.ly = 0; I.mx = Q.has('mx') ? +Q.get('mx') : 0; I.my = Q.has('my') ? +Q.get('my') : 0; I.fire = Q.has('fire'); I.aim = Q.has('ads'); I.sprint = false;
    if (Q.has('use') && i === 2) I.pressed.add('use');
    if (Q.has('nade') && i % 90 === 45) I.pressed.add('nade');
    if (Q.has('knife') && i % 20 === 10) I.pressed.add('knife');
    if (Q.has('bot') && G.state === 'play') {   // piloto automático: apunta al zombi más cercano que se vea y dispara
      updCamera(0); let best = null; for (const a of aimTargets()) if (!best || a.d < best.d) best = a;
      if (best) { P.yaw = Math.atan2(-best.dir.x, -best.dir.z); P.pitch = Math.asin(best.dir.y) + .02; I.fire = i % 2 === 0; }
      if (Q.has('repair') && curInt && curInt.hold) I.held.add('use');
    }
    if (G.state === 'play') update(dt); else if (G.state === 'menu') updMenu(dt);
  }
  if (Q.has('again')) { if (G.state !== 'over') gameOver(); startGame(); for (let i = 0; i < 30; i++) update(dt); }
  if (Q.has('ads')) P.adsK = 1;
  if (G.state === 'play') { updCamera(0); updHudFrame(0); }
  if (Q.has('look')) scene.fog = null;
  if (Q.has('look')) { const [a, b, c, d, e, f] = Q.get('look').split(',').map(Number); camera.position.set(a, b, c); camera.lookAt(d, e, f); camera.fov = +(Q.get('fov') || 50); camera.updateProjectionMatrix(); }
  draw();
  const im = $('shotImg'); im.src = cv.toDataURL(); im.style.display = 'block';
  document.title = 'LISTO';
}
boot();
