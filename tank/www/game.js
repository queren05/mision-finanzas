// Shrimp Tank: una pecera de gambas que da monedas aunque no juegues.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import { Particles } from './particulas.js';
import { ShrimpActor, TANK, sandY } from './gambas.js';
import { SPECIES, speciesPrice, shrimpRate, levelCost, UPGRADES, upCost, DECOR, fmt, fmtTime } from './datos.js';
import { tone, noise, cfg as AUD, ac } from './audio.js';

const $ = id => document.getElementById(id);
const Q = new URLSearchParams(location.search);
const rnd = (a, b) => a + Math.random() * (b - a);
if (Q.has('shot')) addEventListener('unhandledrejection', e => { const d = document.createElement('div'); d.style.cssText = 'position:fixed;top:40px;left:0;right:0;color:#ff0;z-index:99;font:12px monospace;background:#000c;padding:4px'; d.textContent = 'REJ ' + (e.reason && (e.reason.message + ' ' + (e.reason.stack || '').slice(0, 600))); document.body.appendChild(d); });
if (Q.has('shot')) addEventListener('error', e => { const d = document.createElement('div'); d.style.cssText = 'position:fixed;top:0;left:0;right:0;color:#f55;z-index:99;font:12px monospace;background:#000c;padding:4px'; d.textContent = e.message + ' @' + (e.filename || '').split('/').pop() + ':' + e.lineno; document.body.appendChild(d); });

/* ---------- guardado ---------- */
const KEY = 'tank.save';
function load() { try { return JSON.parse(localStorage.getItem(KEY)) || null; } catch (e) { return null; } }
let S = load() || { coins: 0, total: 0, shrimps: [{ sp: 'comun', lvl: 1, uid: 1 }], up: {}, decor: [], last: Date.now(), uid: 1, seen: ['comun'], opt: { sfx: true, music: true } };
if (Q.has('coins')) S.coins = +Q.get('coins');
if (Q.has('fresh')) S = { coins: +(Q.get('coins') || 0), total: 0, shrimps: [{ sp: 'comun', lvl: 1, uid: 1 }], up: {}, decor: [], last: Date.now(), uid: 1, seen: ['comun'], opt: { sfx: true, music: true } };
function persist() { S.last = Date.now(); try { localStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { } }
AUD.sfx = S.opt.sfx; AUD.music = S.opt.music;
const lv = id => S.up[id] || 0;

/* ---------- motor ---------- */
const cv = $('cv');
const renderer = new THREE.WebGLRenderer({ canvas: cv, antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.1;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(36, 1, .1, 60);
function canvasTex(w, h, draw, rep) { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; if (rep) { t.wrapS = t.wrapT = THREE.RepeatWrapping; } return t; }
scene.background = canvasTex(4, 256, (c, w, h) => { const g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, '#16324a'); g.addColorStop(.6, '#0f2638'); g.addColorStop(1, '#2a1c14'); c.fillStyle = g; c.fillRect(0, 0, w, h); });
const TW = 3.2, TH = 3.45, TD = 1.5, WATER = 3.22;   // pecera: ancho, alto, fondo y nivel del agua
function resize() {
  renderer.setSize(innerWidth, innerHeight, false); camera.aspect = innerWidth / innerHeight;
  const vf = THREE.MathUtils.degToRad(camera.fov), hf = 2 * Math.atan(Math.tan(vf / 2) * camera.aspect);
  const dW = (TW / 2 + .14) / Math.tan(hf / 2), dH = (TH / 2 + 1.3) / Math.tan(vf / 2), d = Math.max(dW, dH) + TD / 2;
  const portrait = camera.aspect < .8; camera.position.set(0, portrait ? 1.7 : 2.05, d); camera.lookAt(0, portrait ? 1.05 : 1.62, 0); camera.updateProjectionMatrix();
}
addEventListener('resize', resize); resize();

/* ---------- luces ---------- */
scene.add(new THREE.HemisphereLight(0xbfe8ff, 0x5a4030, 1.3));
const sun = new THREE.DirectionalLight(0xfff4e0, 2.4); sun.position.set(.6, 8, 1.5); sun.target.position.set(0, 0, 0); scene.add(sun, sun.target);
sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024); Object.assign(sun.shadow.camera, { left: -2, right: 2, top: 1.5, bottom: -1.5, near: 3, far: 10 }); sun.shadow.bias = -.002; sun.shadow.radius = 4;
const fill = new THREE.PointLight(0x6ad0ff, 3, 6, 1.5); fill.position.set(0, 2.4, 1.2); scene.add(fill);

/* ---------- reflejos de luz en el agua (cáusticas) ---------- */
const TIME = { value: 0 };
function caustics(m, k = .55) {
  m.onBeforeCompile = sh => {
    sh.uniforms.uT = TIME;
    sh.vertexShader = 'varying vec3 vWP;\n' + sh.vertexShader.replace('#include <worldpos_vertex>', '#include <worldpos_vertex>\nvWP = (modelMatrix * vec4(transformed, 1.0)).xyz;');
    sh.fragmentShader = 'uniform float uT; varying vec3 vWP;\nfloat cau(vec2 p){ float c=0.; for(int i=0;i<3;i++){ float fi=float(i); vec2 q=p*(2.2+fi*1.3)+vec2(uT*(.35+fi*.1), -uT*(.25+fi*.07)); c+=abs(sin(q.x+sin(q.y*1.3+uT))*sin(q.y+sin(q.x*1.1-uT*.8))); } return pow(1.-c/3.,6.); }\n' +
      sh.fragmentShader.replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>\n totalEmissiveRadiance += vec3(.75,.95,1.) * cau(vWP.xz*1.6 + vWP.y*.4) * ${k.toFixed(2)} * smoothstep(${WATER.toFixed(2)}, 2.0, vWP.y + .6);`);
  };
  m.customProgramCacheKey = () => 'cau' + k; return m;
}

/* ---------- la pecera ---------- */
const tank = new THREE.Group(); scene.add(tank);
function buildTank() {
  // mueble de madera
  const wood = canvasTex(256, 256, (c, w, h) => { for (let i = 0; i < 16; i++) { const v = rnd(.85, 1.05); c.fillStyle = `rgb(${92 * v | 0},${60 * v | 0},${38 * v | 0})`; c.fillRect(0, i * 16, w, 16); } c.fillStyle = 'rgba(0,0,0,.15)'; for (let i = 0; i < 300; i++) c.fillRect(rnd(0, w), rnd(0, h), rnd(10, 60), 1); }, true);
  const stand = new THREE.Mesh(new THREE.BoxGeometry(TW + .5, 1.6, TD + .5), new THREE.MeshStandardMaterial({ map: wood, roughness: .7 })); stand.position.y = -.82; stand.receiveShadow = true; tank.add(stand);
  const top = new THREE.Mesh(new THREE.BoxGeometry(TW + .62, .08, TD + .62), new THREE.MeshStandardMaterial({ map: wood, color: 0xc8a080, roughness: .6 })); top.position.y = -.02; tank.add(top);
  for (const s of [-1, 1]) { const door = new THREE.Mesh(new THREE.BoxGeometry(TW / 2 - .15, 1.25, .02), new THREE.MeshStandardMaterial({ map: wood, color: 0xd8b090, roughness: .6 })); door.position.set(s * (TW / 4 + .05), -.82, TD / 2 + .26); tank.add(door); const knob = new THREE.Mesh(new THREE.SphereGeometry(.04, 12, 8), new THREE.MeshStandardMaterial({ color: 0xd8b060, metalness: .8, roughness: .3 })); knob.position.set(s * .2, -.82, TD / 2 + .29); tank.add(knob); }
  // arena
  const sandTex = canvasTex(256, 256, (c, w, h) => { c.fillStyle = '#e8cf9a'; c.fillRect(0, 0, w, h); for (let i = 0; i < 4000; i++) { const v = rnd(.7, 1.15); c.fillStyle = `rgba(${200 * v | 0},${170 * v | 0},${120 * v | 0},.7)`; c.fillRect(rnd(0, w), rnd(0, h), 2, 2); } for (let i = 0; i < 60; i++) { c.fillStyle = ['#b08a60', '#f4e8d0', '#a0a0a0', '#d89a7a'][i % 4]; c.beginPath(); c.ellipse(rnd(0, w), rnd(0, h), rnd(2, 5), rnd(2, 4), rnd(0, 3), 0, 7); c.fill(); } }, true); sandTex.repeat.set(3, 1.5);
  const sg = new THREE.PlaneGeometry(TW - .04, TD - .04, 48, 24); sg.rotateX(-Math.PI / 2);
  const p = sg.attributes.position; for (let i = 0; i < p.count; i++) p.setY(i, sandY(p.getX(i), p.getZ(i)) - .02); sg.computeVertexNormals();
  const sand = new THREE.Mesh(sg, caustics(new THREE.MeshStandardMaterial({ map: sandTex, roughness: 1 }), .7)); sand.receiveShadow = true; tank.add(sand);
  const sandSide = new THREE.Mesh(new THREE.BoxGeometry(TW - .04, .2, TD - .04), new THREE.MeshStandardMaterial({ map: sandTex, color: 0xd8b880 })); sandSide.position.y = .08; tank.add(sandSide);
  // fondo decorado (póster de pecera)
  const back = canvasTex(512, 512, (c, w, h) => {
    const g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, '#2a9ad8'); g.addColorStop(.7, '#155a8a'); g.addColorStop(1, '#0d3a5a'); c.fillStyle = g; c.fillRect(0, 0, w, h);
    for (let k = 0; k < 3; k++) { c.fillStyle = `rgba(10,40,60,${.25 + k * .15})`; c.beginPath(); c.moveTo(0, h); for (let x = 0; x <= w; x += 16) c.lineTo(x, h - 80 - k * 30 - 60 * Math.abs(Math.sin(x * .01 + k * 2)) - 20 * Math.sin(x * .05 + k)); c.lineTo(w, h); c.fill(); }
    for (let i = 0; i < 26; i++) { c.strokeStyle = `rgba(40,120,80,${rnd(.25, .5)})`; c.lineWidth = rnd(3, 7); c.beginPath(); const x = rnd(0, w); c.moveTo(x, h); c.bezierCurveTo(x + rnd(-30, 30), h - 120, x + rnd(-40, 40), h - 200, x + rnd(-30, 30), h - rnd(150, 330)); c.stroke(); }
  });
  const backM = new THREE.Mesh(new THREE.PlaneGeometry(TW - .02, TH - .1), caustics(new THREE.MeshStandardMaterial({ map: back, roughness: 1, emissive: 0x0a3050, emissiveIntensity: .6 }), .25)); backM.position.set(0, TH / 2, -TD / 2 + .01); tank.add(backM);
  // cristal y marco
  const glassM = new THREE.MeshStandardMaterial({ color: 0xbfefff, transparent: true, opacity: .07, roughness: .05, metalness: .1, depthWrite: false });
  for (const [w, h, x, z, ry] of [[TW, TH, 0, TD / 2, 0], [TD, TH, -TW / 2, 0, Math.PI / 2], [TD, TH, TW / 2, 0, Math.PI / 2]]) { const g = new THREE.Mesh(new THREE.PlaneGeometry(w, h), glassM); g.position.set(x, TH / 2, z); g.rotation.y = ry; g.renderOrder = 3; tank.add(g); }
  const streaks = canvasTex(256, 256, (c, w, h) => { c.fillStyle = 'rgba(255,255,255,0)'; c.fillRect(0, 0, w, h); c.rotate(-.5); for (const [x, ww, a] of [[40, 26, .14], [80, 8, .1], [190, 40, .07], [250, 10, .1]]) { c.fillStyle = `rgba(255,255,255,${a})`; c.fillRect(x, -100, ww, 600); } });
  const shine = new THREE.Mesh(new THREE.PlaneGeometry(TW, TH), new THREE.MeshBasicMaterial({ map: streaks, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending })); shine.position.set(0, TH / 2, TD / 2 + .005); shine.renderOrder = 4; tank.add(shine);
  const frameM = new THREE.MeshStandardMaterial({ color: 0x1a1e24, roughness: .4, metalness: .5 });
  const bar = (w, h, d, x, y, z) => { const b = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), frameM); b.position.set(x, y, z); tank.add(b); };
  for (const y of [.02, TH]) { bar(TW + .06, .06, .06, 0, y, TD / 2); bar(TW + .06, .06, .06, 0, y, -TD / 2); bar(.06, .06, TD, -TW / 2, y, 0); bar(.06, .06, TD, TW / 2, y, 0); }
  for (const x of [-TW / 2, TW / 2]) for (const z of [-TD / 2, TD / 2]) bar(.05, TH, .05, x, TH / 2, z);
  // tapa con lámpara
  const lid = new THREE.Mesh(new THREE.BoxGeometry(TW + .1, .12, TD + .1), frameM); lid.position.y = TH + .1; tank.add(lid);
  const lampStrip = new THREE.Mesh(new THREE.BoxGeometry(TW - .3, .03, .25), new THREE.MeshBasicMaterial({ color: 0xeaffff })); lampStrip.position.set(0, TH + .03, 0); tank.add(lampStrip);
  // agua: volumen teñido y superficie
  const water = new THREE.Mesh(new THREE.BoxGeometry(TW - .03, WATER - .02, TD - .03), new THREE.MeshBasicMaterial({ color: 0x3ab0e0, transparent: true, opacity: .13, depthWrite: false })); water.position.y = WATER / 2 + .01; water.renderOrder = 2; tank.add(water);
  const surfTex = canvasTex(256, 128, (c, w, h) => { c.clearRect(0, 0, w, h); for (let i = 0; i < 40; i++) { c.strokeStyle = `rgba(255,255,255,${rnd(.15, .4)})`; c.lineWidth = rnd(1, 3); c.beginPath(); const y = rnd(0, h); c.moveTo(0, y); for (let x = 0; x <= w; x += 16) c.lineTo(x, y + Math.sin(x * .05 + i) * 4); c.stroke(); } }, true);
  world.surf = new THREE.Mesh(new THREE.PlaneGeometry(TW - .03, TD - .03), new THREE.MeshBasicMaterial({ map: surfTex, color: 0xbfffff, transparent: true, opacity: .55, depthWrite: false, side: THREE.DoubleSide })); world.surf.rotation.x = -Math.PI / 2; world.surf.position.y = WATER; world.surf.renderOrder = 5; tank.add(world.surf);
  const line = new THREE.Mesh(new THREE.PlaneGeometry(TW - .02, .05), new THREE.MeshBasicMaterial({ color: 0xdfffff, transparent: true, opacity: .55 })); line.position.set(0, WATER, TD / 2 + .006); line.renderOrder = 5; tank.add(line);
  // rayos de luz
  const rayTex = canvasTex(64, 256, (c, w, h) => { const g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, 'rgba(255,255,255,.55)'); g.addColorStop(1, 'rgba(255,255,255,0)'); c.fillStyle = g; c.fillRect(0, 0, w, h); const gx = c.createLinearGradient(0, 0, w, 0); gx.addColorStop(0, 'rgba(0,0,0,1)'); gx.addColorStop(.5, 'rgba(0,0,0,0)'); gx.addColorStop(1, 'rgba(0,0,0,1)'); c.globalCompositeOperation = 'destination-out'; c.fillStyle = gx; c.fillRect(0, 0, w, h); });
  world.rays = [];
  for (let i = 0; i < 6; i++) { const r = new THREE.Mesh(new THREE.PlaneGeometry(rnd(.25, .5), WATER - .1), new THREE.MeshBasicMaterial({ map: rayTex, transparent: true, opacity: .3, depthWrite: false, blending: THREE.AdditiveBlending, color: 0xcff6ff })); r.position.set(-1.3 + i * .52 + rnd(-.1, .1), WATER / 2, rnd(-.4, .2)); r.rotation.z = .18; r.renderOrder = 1; tank.add(r); world.rays.push(r); }
  // piedra difusora de burbujas
  const stone = new THREE.Mesh(new THREE.CylinderGeometry(.08, .1, .07, 12), new THREE.MeshStandardMaterial({ color: 0x8a8a96, roughness: .9 })); stone.position.set(1.25, sandY(1.25, -.45) + .03, -.45); tank.add(stone);
  // unas piedrecitas siempre
  for (let i = 0; i < 9; i++) { const x = rnd(-1.4, 1.4), z = rnd(-.6, .6), s = new THREE.Mesh(new THREE.DodecahedronGeometry(rnd(.03, .07)), new THREE.MeshStandardMaterial({ color: [0x8a8078, 0xa89070, 0x6a6a72][i % 3], roughness: .9, flatShading: true })); s.position.set(x, sandY(x, z) + .02, z); s.scale.y = .6; s.castShadow = true; tank.add(s); }
}
const world = {};

/* ---------- decoración ---------- */
const K = {}, decoMeshes = {};
const swayMats = [];
function seaweedMat(col) {
  const m = new THREE.MeshStandardMaterial({ color: col, roughness: .7, side: THREE.DoubleSide });
  m.onBeforeCompile = sh => { sh.uniforms.uT = TIME; sh.vertexShader = 'uniform float uT;\n' + sh.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\nfloat k_ = position.y * position.y; transformed.x += sin(uT * 1.4 + position.y * 2.5 + modelMatrix[3].x * 3.) * .09 * k_; transformed.z += cos(uT * 1.1 + position.y * 2. + modelMatrix[3].x) * .05 * k_;'); };
  m.customProgramCacheKey = () => 'sway'; return m;
}
function buildDecor(d) {
  const g = new THREE.Group();
  if (d.kind === 'algas') {
    for (const [x, z, h, c] of [[-1.35, -.5, 1.9, 0x3a9a4a], [-1.15, -.55, 1.4, 0x4ab85a], [-1.42, -.2, 1.1, 0x2a8a3a], [1.3, -.55, 2.2, 0x3a9a4a], [1.05, -.6, 1.5, 0x5ac86a], [.3, -.6, 1.2, 0x3aa85a], [-.45, -.62, 1.7, 0x2a8a4a]]) {
      for (let k = 0; k < 3; k++) { const geo = new THREE.PlaneGeometry(.09, h * rnd(.7, 1), 1, 12); geo.translate(0, h / 2, 0); const p = geo.attributes.position; for (let i = 0; i < p.count; i++) p.setX(i, p.getX(i) * (1 - p.getY(i) / h * .6)); const m = new THREE.Mesh(geo, seaweedMat(c)); m.position.set(x + rnd(-.08, .08), sandY(x, z), z + rnd(-.05, .05)); m.rotation.y = rnd(0, 3); g.add(m); }
    }
  } else if (d.kind === 'coral') {
    const mk = (x, z, col) => { const cm = new THREE.MeshStandardMaterial({ color: col, roughness: .6 }); const base = new THREE.Group(); base.position.set(x, sandY(x, z), z);
      const branch = (parent, len, r, depth) => { const c = new THREE.Mesh(new THREE.CylinderGeometry(r * .7, r, len, 8), cm); c.position.y = len / 2; c.castShadow = true; parent.add(c); const tip = new THREE.Group(); tip.position.y = len; parent.add(tip); const s = new THREE.Mesh(new THREE.SphereGeometry(r * .75, 8, 6), cm); tip.add(s); if (depth > 0) for (let i = 0; i < 2; i++) { const j = new THREE.Group(); j.rotation.set(rnd(-.7, .7), rnd(0, 6), rnd(-.7, .7)); tip.add(j); branch(j, len * .75, r * .7, depth - 1); } };
      for (let i = 0; i < 3; i++) { const j = new THREE.Group(); j.rotation.set(rnd(-.5, .5), rnd(0, 6), rnd(-.5, .5)); base.add(j); branch(j, .22, .035, 2); } g.add(base); };
    mk(-.55, .35, 0xff6a8a); mk(.95, .3, 0xff9a4a); mk(.35, -.35, 0xc85aff);
  } else {
    const o = K[d.kind].scene.clone(true); o.traverse(m => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; m.material = caustics(m.material.clone(), .3); } });
    o.scale.setScalar(d.s); o.rotation.y = d.ry || 0; if (d.tilt) o.rotation.z = d.tilt;
    const [x, z] = d.at; o.position.set(x, sandY(x, z) - .02, z); g.add(o);
    if (d.kind === 'chest') world.chest = o;
  }
  tank.add(g); decoMeshes[d.id] = g;
}

/* ---------- partículas, comida, burbuja dorada ---------- */
const bubbles = new Particles(scene, 400, false, renderer.getPixelRatio());
const sparks = new Particles(scene, 300, true, renderer.getPixelRatio());
const food = [];
const foodGeo = new THREE.BoxGeometry(.035, .008, .03), foodMats = [0xff8a3a, 0xffc24a, 0x8ad04a, 0xd85a3a].map(c => new THREE.MeshStandardMaterial({ color: c, roughness: .8 }));
function dropFood(x, n = 4, spread = .25) {
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(foodGeo, foodMats[i % 4]); const px = THREE.MathUtils.clamp(x + rnd(-spread, spread), -TANK.x, TANK.x), pz = rnd(-.5, .5);
    m.position.set(px, WATER - .02, pz); m.rotation.set(rnd(0, 3), rnd(0, 3), 0); tank.add(m);
    food.push({ m, pos: m.position, t: 0, gone: false, rot: rnd(-3, 3) });
  }
  blub(1.3);
}
function updFood(dt) {
  for (let i = food.length - 1; i >= 0; i--) {
    const f = food[i]; f.t += dt;
    const floor = sandY(f.pos.x, f.pos.z) + .01;
    if (f.pos.y > floor) { f.pos.y = Math.max(floor, f.pos.y - dt * (f.t < .4 ? .05 : .22)); f.pos.x += Math.sin(f.t * 3 + i) * dt * .05; f.m.rotation.x += f.rot * dt; }
    if (f.gone || f.t > 30) { if (f.gone) sparks.burst(f.pos.x, f.pos.y + .03, f.pos.z, 4, new THREE.Color(0xffd27a), .3, .05, .4, 0); tank.remove(f.m); food.splice(i, 1); }
  }
}
let golden = null, goldenT = rnd(25, 45);
function spawnGolden() {
  const g = new THREE.Group();
  const shell = new THREE.Mesh(new THREE.SphereGeometry(.17, 24, 16), new THREE.MeshStandardMaterial({ color: 0xfff4c0, transparent: true, opacity: .35, roughness: .05, metalness: .2, emissive: 0xffc83a, emissiveIntensity: .25, depthWrite: false }));
  const coin = new THREE.Mesh(new THREE.CylinderGeometry(.09, .09, .02, 24), new THREE.MeshStandardMaterial({ color: 0xffc83a, metalness: .6, roughness: .3, emissive: 0x8a5a00, emissiveIntensity: .6 })); coin.rotation.x = Math.PI / 2;
  g.add(coin, shell); const x = rnd(-1.2, 1.2); g.position.set(x, .4, .35); tank.add(g); golden = { g, coin, t: 0, x };
}
function updGolden(dt, t) {
  if (!golden) { if ((goldenT -= dt) < 0) spawnGolden(); return; }
  golden.t += dt; golden.g.position.y += dt * .16; golden.g.position.x = golden.x + Math.sin(golden.t * 1.3) * .15; golden.coin.rotation.z += dt * 3;
  if (Math.random() < .3) sparks.emit(golden.g.position.x + rnd(-.1, .1), golden.g.position.y + rnd(-.1, .1), golden.g.position.z, 0, .05, 0, new THREE.Color(0xffe08a), .05, .6);
  if (golden.g.position.y > WATER - .1) { popGolden(false); }
}
function popGolden(got) {
  const p = golden.g.position; bubbles.burst(p.x, p.y, p.z, 14, new THREE.Color(0xdff8ff), .4, .05, .7, -.5);
  tank.remove(golden.g); golden = null; goldenT = rnd(40, 80);
  if (got) { const r = Math.max(50, income() * 60); addCoins(r); floatText('+' + fmt(r), lastTap.x, lastTap.y, true); sndCoin(true); sparks.burst(p.x, p.y, p.z, 30, new THREE.Color(0xffc83a), .8, .07, .8, 0); toast('¡Burbuja dorada! +' + fmt(r)); }
}

/* ---------- gambas ---------- */
const SRC = {}; const actors = [];
const spById = id => SPECIES.find(s => s.id === id);
function addActor(rec, baby) {
  const a = new ShrimpActor(SRC, spById(rec.sp), { lvl: rec.lvl, baby, uid: rec.uid });
  a.rec = rec; a.root.traverse(o => { if (o.isMesh) o.castShadow = true; }); tank.add(a.root); actors.push(a);
  a.onEat = () => { sparks.burst(a.pos.x, a.pos.y + .05, a.pos.z, 5, new THREE.Color(0xffe08a), .3, .05, .5, 0); };
  return a;
}
const cap = () => 5 + 2 * lv('capacidad');
function mult() { let d = 0; for (const id of S.decor) d += DECOR.find(x => x.id === id).bonus; return (1 + d) * (1 + .2 * lv('filtro')) * (1 + .15 * lv('luz')); }
function income(live = true) { let s = 0; for (const a of actors) s += shrimpRate(a.sp, a.rec.lvl) * (live && a.fedT > 0 ? 2 : 1) * (a.grow < 1 ? .5 : 1); return s * mult(); }
function addCoins(n) { S.coins += n; S.total += n; }

/* ---------- interfaz ---------- */
let tab = null, sel = null;
const thumbs = {};
function updTop() {
  $('coins').textContent = fmt(S.coins); $('rate').textContent = fmt(income()) + '/s';
  $('cap').textContent = `${S.shrimps.length}/${cap()}`;
  // avisos de cosas que se pueden comprar
  const next = SPECIES.find(sp => !S.seen.includes(sp.id));
  const canG = SPECIES.some(sp => unlocked(sp) && S.coins >= speciesPrice(sp, owned(sp.id))) && S.shrimps.length < cap();
  const canM = UPGRADES.some(u => lv(u.id) < u.max && S.coins >= upCost(u, lv(u.id)));
  const canD = DECOR.some(d => !S.decor.includes(d.id) && S.coins >= d.price);
  $('dotG').classList.toggle('on', canG && tab !== 'gambas'); $('dotM').classList.toggle('on', canM && tab !== 'mejoras'); $('dotD').classList.toggle('on', canD && tab !== 'deco');
  const fed = actors.filter(a => a.fedT > 0).length;
  $('boosts').innerHTML = fed ? `<span>¡${fed === actors.length ? 'Todas' : fed} con la tripa llena! x2</span>` : '';
}
const owned = id => S.shrimps.filter(s => s.sp === id).length;
const unlocked = sp => { const i = SPECIES.indexOf(sp); return i === 0 || S.seen.includes(SPECIES[i - 1].id); };
const coinIc = '<span class="coin"></span>';
const ic = d => `<svg viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const UP_ICON = {
  filtro: ic('<rect x="6" y="3" width="12" height="18" rx="3"/><path d="M9 8h6M9 12h6M9 16h6"/>'),
  luz: ic('<circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2"/>'),
  capacidad: ic('<path d="M4 4h6M4 4v6M20 4h-6M20 4v6M4 20h6M4 20v-6M20 20h-6M20 20v-6"/>'),
  comedero: ic('<circle cx="12" cy="13" r="8"/><path d="M12 9v4l3 2M9 2h6"/>'),
  toque: ic('<path d="M9 11V5a2 2 0 0 1 4 0v6M13 10a2 2 0 0 1 4 0v4c0 4-2 7-6 7s-6-3-6-6v-3a2 2 0 0 1 4 0"/>'),
  bomba: ic('<circle cx="8" cy="15" r="3"/><circle cx="15" cy="9" r="4"/><circle cx="17" cy="18" r="2"/>'),
};
function openTab(t) {
  if (tab === t) return closeSheet(); tab = t; closeCard();
  document.querySelectorAll('.tab').forEach(b => b.classList.toggle('on', b.dataset.tab === t));
  $('sheet').hidden = false; $('feedBtn').hidden = true; $('sheetTitle').textContent = { gambas: 'Gambas', mejoras: 'Mejoras', deco: 'Decoración' }[t]; renderList(); blub(1.6);
}
function closeSheet() { tab = null; $('sheet').hidden = true; $('feedBtn').hidden = false; document.querySelectorAll('.tab').forEach(b => b.classList.remove('on')); }
function renderList() {
  const L = $('list'); let h = '';
  if (tab === 'gambas') {
    for (const sp of SPECIES) {
      const un = unlocked(sp), n = owned(sp.id), pr = speciesPrice(sp, n), full = S.shrimps.length >= cap();
      if (!un) { h += `<div class="item locked"><img src="${thumbs[sp.id] || ''}"><div class="info"><b>???</b><small>Compra antes la ${SPECIES[SPECIES.indexOf(sp) - 1].name.toLowerCase()}</small></div></div>`; continue; }
      h += `<div class="item"><img src="${thumbs[sp.id] || ''}"><div class="info"><b>${sp.name}</b><small>${sp.desc} <span class="lv">+${fmt(sp.rate * mult())}/s</span>${n ? ` · Tienes ${n}` : ''}</small></div><button class="buy ${S.coins >= pr && !full ? '' : 'no'}" data-sp="${sp.id}">${full ? 'Llena' : coinIc + fmt(pr)}</button></div>`;
    }
  } else if (tab === 'mejoras') {
    for (const u of UPGRADES) { const l = lv(u.id), c = upCost(u, l), max = l >= u.max; h += `<div class="item"><div class="ic">${UP_ICON[u.id]}</div><div class="info"><b>${u.name} <span class="lv">Nv ${l}</span></b><small>${u.desc}</small></div><button class="buy ${max ? 'done' : S.coins >= c ? '' : 'no'}" data-up="${u.id}">${max ? 'Máx.' : coinIc + fmt(c)}</button></div>`; }
  } else if (tab === 'deco') {
    for (const d of DECOR) { const has = S.decor.includes(d.id); h += `<div class="item"><img src="${thumbs['d_' + d.id] || ''}"><div class="info"><b>${d.name}</b><small>+${Math.round(d.bonus * 100)} % de monedas para siempre</small></div><button class="buy ${has ? 'done' : S.coins >= d.price ? '' : 'no'}" data-deco="${d.id}">${has ? 'Puesta' : coinIc + fmt(d.price)}</button></div>`; }
  }
  L.innerHTML = h;
}
$('list').addEventListener('click', e => {
  const b = e.target.closest('.buy'); if (!b) return;
  if (b.dataset.sp) buySpecies(b.dataset.sp); else if (b.dataset.up) buyUp(b.dataset.up); else if (b.dataset.deco) buyDeco(b.dataset.deco);
});
function buySpecies(id) {
  const sp = spById(id), pr = speciesPrice(sp, owned(id));
  if (S.shrimps.length >= cap()) { toast('La pecera está llena: amplíala en Mejoras'); return sndNo(); }
  if (S.coins < pr) return sndNo();
  S.coins -= pr; const rec = { sp: id, lvl: 1, uid: ++S.uid }; S.shrimps.push(rec); if (!S.seen.includes(id)) S.seen.push(id);
  const a = addActor(rec, false); a.pos.set(rnd(-1, 1), WATER - .1, rnd(-.3, .3)); bubbles.burst(a.pos.x, WATER - .1, a.pos.z, 20, new THREE.Color(0xdff8ff), .5, .05, .8, -.6);
  sndBuy(); toast(`¡${sp.name} a la pecera!`); renderList(); persist();
}
function buyUp(id) { const u = UPGRADES.find(x => x.id === id), l = lv(id), c = upCost(u, l); if (l >= u.max || S.coins < c) return sndNo(); S.coins -= c; S.up[id] = l + 1; sndBuy(); if (id === 'luz') applyLight(); renderList(); persist(); }
function buyDeco(id) { const d = DECOR.find(x => x.id === id); if (S.decor.includes(id) || S.coins < d.price) return sndNo(); S.coins -= d.price; S.decor.push(id); buildDecor(d); const g = decoMeshes[id]; g.position.y = 2.5; g.userData.drop = 0; drops.push(g); sndBuy(); renderList(); persist(); }
const drops = [];
function applyLight() { const l = lv('luz'); sun.intensity = 2.4 + l * .08; fill.color.setHSL(.55 - l * .02, .8, .65); }
function showCard(a) {
  sel = a; closeSheet(); $('card').hidden = false; $('feedBtn').hidden = true; updCard();
}
function updCard() {
  if (!sel) return; const a = sel, l = a.rec.lvl, c = levelCost(a.sp, l);
  $('cardImg').src = thumbs[a.sp.id] || ''; $('cardName').textContent = a.sp.name + (a.grow < 1 ? ' (cría)' : '');
  $('cardLvl').textContent = `Nivel ${l}` + (l % 10 === 9 ? ' · ¡x2 al subir!' : ''); $('cardRate').textContent = `+${fmt(shrimpRate(a.sp, l) * mult())}/s → +${fmt(shrimpRate(a.sp, l + 1) * mult())}/s`;
  $('cardUp').innerHTML = `Subir ${coinIc}${fmt(c)}`; $('cardUp').classList.toggle('no', S.coins < c);
}
function closeCard() { sel = null; $('card').hidden = true; if (!tab) $('feedBtn').hidden = false; }
$('cardUp').onclick = () => { const a = sel; if (!a) return; const c = levelCost(a.sp, a.rec.lvl); if (S.coins < c) return sndNo(); S.coins -= c; a.rec.lvl++; a.hop = .3; sparks.burst(a.pos.x, a.pos.y + .1, a.pos.z, 16, new THREE.Color(0xffe08a), .5, .06, .6, 0); sndBuy(); updCard(); persist(); };
$('cardClose').onclick = closeCard; $('sheetClose').onclick = closeSheet;
document.querySelectorAll('.tab').forEach(b => b.onclick = () => openTab(b.dataset.tab));
$('feedBtn').onclick = () => { dropFood(0, 6, 1.3); };
let toastT = 0;
function toast(t) { const el = $('toast'); el.textContent = t; el.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => el.classList.remove('on'), 2200); }
function floatText(t, x, y, big) { const d = document.createElement('div'); d.className = 'float'; d.textContent = t; d.style.left = (x - 20) + 'px'; d.style.top = (y - 30) + 'px'; if (big) d.style.fontSize = '26px'; document.body.appendChild(d); setTimeout(() => d.remove(), 1000); }
function modal(title, text, body, ok = '¡Genial!', cb) { $('mTitle').textContent = title; $('mText').textContent = text; $('mBody').innerHTML = body || ''; $('mOk').textContent = ok; $('modal').hidden = false; $('mOk').onclick = () => { $('modal').hidden = true; blub(1.5); cb && cb(); }; }
$('setBtn').onclick = () => {
  const row = (id, t, v) => `<button class="setRow" id="${id}"><span>${t}</span><b>${v ? 'SÍ' : 'NO'}</b></button>`;
  modal('Ajustes', `Monedas ganadas en total: ${fmt(S.total)}`, row('oSfx', 'Sonidos', S.opt.sfx) + row('oMus', 'Música', S.opt.music), 'Cerrar');
  $('oSfx').onclick = () => { S.opt.sfx = AUD.sfx = !S.opt.sfx; $('oSfx').querySelector('b').textContent = S.opt.sfx ? 'SÍ' : 'NO'; persist(); };
  $('oMus').onclick = () => { S.opt.music = AUD.music = !S.opt.music; $('oMus').querySelector('b').textContent = S.opt.music ? 'SÍ' : 'NO'; persist(); };
};

/* ---------- toques en la pecera ---------- */
const ray = new THREE.Raycaster(), ndc = new THREE.Vector2(); let lastTap = { x: 0, y: 0 };
cv.addEventListener('pointerdown', e => {
  lastTap = { x: e.clientX, y: e.clientY }; ac();
  ndc.set(e.clientX / innerWidth * 2 - 1, -(e.clientY / innerHeight) * 2 + 1); ray.setFromCamera(ndc, camera);
  if (golden && ray.ray.distanceSqToPoint(golden.g.position) < .3 * .3) return popGolden(true);
  let best = null, bd = 1e9; for (const a of actors) { const d = a.hitTest(ray.ray); if (d !== null && d < bd) { bd = d; best = a; } }
  if (best) { tapShrimp(best, e); return; }
  // tocar el agua: cae comida en ese sitio
  const p = new THREE.Vector3(); if (ray.ray.intersectPlane(new THREE.Plane(new THREE.Vector3(0, 0, 1), -TD / 2), p) && Math.abs(p.x) < TW / 2 && p.y > 0 && p.y < WATER) { dropFood(p.x, 3, .12); if (tab) closeSheet(); if (sel) closeCard(); }
});
function tapShrimp(a, e) {
  a.hop = .3; blub(1 + Math.random() * .5);
  if (!a.tapCd || performance.now() > a.tapCd) { a.tapCd = performance.now() + 600; const r = shrimpRate(a.sp, a.rec.lvl) * mult() * (3 + lv('toque') * 3); addCoins(r); floatText('+' + fmt(r), e.clientX, e.clientY); sndCoin(); }
  showCard(a);
}

/* ---------- sonido ---------- */
const N = n => 440 * Math.pow(2, (n - 69) / 12);
function blub(p = 1) { tone(320 * p, .12, 'sine', .12, 500 * p); }
function sndCoin(big) { tone(1568, .08, 'square', .03); tone(2093, .18, 'square', .03, 0, .06); if (big) [0, .1, .2].forEach((w, i) => tone(N(84 + i * 4), .2, 'triangle', .07, 0, w)); }
function sndBuy() { [0, .08, .16].forEach((w, i) => tone(N([72, 76, 79][i]), .18, 'triangle', .09, 0, w)); }
function sndNo() { tone(220, .15, 'square', .05); }
// música tranquila generada
const SCALE = [60, 62, 64, 67, 69, 72, 74, 76, 79];
let musT = 0, musStep = 0;
function updMusic(dt) {
  if (!AUD.music || !AUD.sfx) return; musT -= dt; if (musT > 0) return; musT = .55; musStep++;
  const a = ac(); if (!a || a.state !== 'running') return;
  if (musStep % 2 === 0 || Math.random() < .3) tone(N(SCALE[Math.floor(Math.random() * SCALE.length)]), 1.4, 'triangle', .025);
  if (musStep % 8 === 0) { const r = [48, 45, 41, 43][(musStep / 8 | 0) % 4]; tone(N(r), 4, 'sine', .04); tone(N(r + 7), 4, 'sine', .025); }
  if (Math.random() < .25) noise(.08, .015, 2500 + Math.random() * 2000, 'bandpass', 0, null, 8);
}

/* ---------- bucle ---------- */
const clock = new THREE.Clock(); let t = 0, saveT = 0, feedT = 0, breedT = 30, coinVisT = 0;
function update(dt) {
  t += dt; TIME.value = t;
  addCoins(income() * dt);
  for (const a of actors) a.update(dt, t, food);
  updFood(dt); updGolden(dt, t);
  // burbujas de la piedra
  if (Math.random() < dt * 18) bubbles.emit(1.25 + rnd(-.04, .04), sandY(1.25, -.45) + .08, -.45 + rnd(-.04, .04), rnd(-.03, .03), rnd(.5, .8), 0, new THREE.Color(0xe8fbff), rnd(.03, .06), 5.5, -.02);
  for (let i = 0; i < 400; i++) if (bubbles.pos[i * 3 + 1] > WATER - .02 && bubbles.life[i] > 0) bubbles.life[i] = 0;
  bubbles.update(dt); sparks.update(dt);
  world.rays.forEach((r, i) => { r.material.opacity = .14 + .12 * Math.sin(t * .6 + i * 1.7); r.position.x += Math.sin(t * .3 + i) * dt * .02; });
  world.surf.material.map.offset.set(t * .02, t * .015);
  // decoración que cae al comprarla
  for (let i = drops.length - 1; i >= 0; i--) { const g = drops[i]; g.position.y = Math.max(0, g.position.y - dt * 1.2); if (g.position.y <= 0) { drops.splice(i, 1); const b = g.children[0] && g.children[0].position; bubbles.burst(b ? b.x : 0, .3, b ? b.z : 0, 18, new THREE.Color(0xe8d8b0), .5, .06, .7, 2); } }
  if (world.chest && Math.random() < dt * .3) { const p = world.chest.position; bubbles.burst(p.x, p.y + .2, p.z, 6, new THREE.Color(0xfff2c0), .1, .05, 4, -.2); }
  // comedero automático
  if (lv('comedero')) { feedT += dt; if (feedT > 70 - lv('comedero') * 10) { feedT = 0; dropFood(rnd(-1, 1), 5, .6); } }
  // crías
  if ((breedT -= dt) < 0) { breedT = 35; tryBreed(); }
  // monedas que salen de las gambas (solo para verlas)
  if ((coinVisT -= dt) < 0 && actors.length) { coinVisT = 1.6 / Math.min(actors.length, 8); const a = actors[Math.floor(Math.random() * actors.length)]; sparks.emit(a.pos.x, a.pos.y + .1, a.pos.z, 0, .25, 0, new THREE.Color(0xffd24a), .07, 1.1, -.05); }
  updMusic(dt);
  if ((saveT += dt) > 5) { saveT = 0; persist(); }
  updTop(); if (sel) updCard();
  if (tab && Math.floor(t * 2) !== Math.floor((t - dt) * 2)) refreshButtons();
}
function refreshButtons() { $('list').querySelectorAll('.buy').forEach(b => { let c = null; if (b.dataset.sp) { const sp = spById(b.dataset.sp); if (S.shrimps.length < cap()) c = speciesPrice(sp, owned(sp.id)); } else if (b.dataset.up) { const u = UPGRADES.find(x => x.id === b.dataset.up); if (lv(u.id) < u.max) c = upCost(u, lv(u.id)); } else if (b.dataset.deco && !S.decor.includes(b.dataset.deco)) c = DECOR.find(x => x.id === b.dataset.deco).price; if (c !== null) b.classList.toggle('no', S.coins < c); }); }
function tryBreed() {
  if (S.shrimps.length >= cap()) return;
  const groups = {}; for (const a of actors) if (a.fedT > 0 && a.grow >= 1) (groups[a.sp.id] = groups[a.sp.id] || []).push(a);
  const ok = Object.keys(groups).filter(k => groups[k].length >= 2); if (!ok.length || Math.random() > .35) return;
  const id = ok[Math.floor(Math.random() * ok.length)], par = groups[id][0];
  const rec = { sp: id, lvl: 1, uid: ++S.uid }; S.shrimps.push(rec);
  const a = addActor(rec, true); a.pos.set(par.pos.x, sandY(par.pos.x, par.pos.z), par.pos.z);
  sparks.burst(a.pos.x, a.pos.y + .1, a.pos.z, 20, new THREE.Color(0xff9ac8), .4, .06, .9, 0); toast(`¡Ha nacido una ${spById(id).name.toLowerCase()}!`); sndBuy(); persist();
}
function frame() { requestAnimationFrame(frame); const dt = Math.min(.05, clock.getDelta()); update(dt); renderer.render(scene, camera); }

/* ---------- miniaturas ---------- */
function makeThumbs() {
  const sc = new THREE.Scene(); sc.add(new THREE.HemisphereLight(0xffffff, 0x445566, 2.2)); const dl = new THREE.DirectionalLight(0xffffff, 2); dl.position.set(1, 2, 3); sc.add(dl);
  const cam = new THREE.PerspectiveCamera(30, 1, .01, 20); const size = renderer.getSize(new THREE.Vector2()), pr = renderer.getPixelRatio();
  renderer.setPixelRatio(1); renderer.setSize(128, 128, false); renderer.setClearColor(0, 0); const bg = scene.background;
  for (const sp of SPECIES) {
    const a = new ShrimpActor(SRC, sp, { uid: 3 }); a.root.position.set(0, 0, 0); a.root.rotation.y = -1.9; a.pose(.5, 0, false); a.pitchG.rotation.x = 0; sc.add(a.root);
    cam.position.set(0, .45, 1.15); cam.lookAt(0, .07, 0); renderer.render(sc, cam); thumbs[sp.id] = cv.toDataURL(); sc.remove(a.root);
  }
  for (const d of DECOR) {
    let o; if (K[d.kind]) { o = K[d.kind].scene.clone(true); } else { const g = new THREE.Group(); const prev = tank; o = g; if (d.kind === 'algas') for (let i = 0; i < 5; i++) { const m = new THREE.Mesh(new THREE.PlaneGeometry(.1, 1, 1, 6), new THREE.MeshStandardMaterial({ color: 0x3aa85a, side: THREE.DoubleSide })); m.position.set(-.2 + i * .1, .5, 0); m.rotation.z = (i - 2) * .12; g.add(m); } else for (let i = 0; i < 6; i++) { const m = new THREE.Mesh(new THREE.CylinderGeometry(.04, .06, .5), new THREE.MeshStandardMaterial({ color: [0xff6a8a, 0xff9a4a, 0xc85aff][i % 3] })); m.position.set((i - 2.5) * .1, .25, 0); m.rotation.z = (i - 2.5) * .25; g.add(m); } }
    o.updateMatrixWorld(true); const b = new THREE.Box3().setFromObject(o), s = b.getSize(new THREE.Vector3()), c = b.getCenter(new THREE.Vector3()); const r = Math.max(s.x, s.y, s.z);
    sc.add(o); cam.position.set(c.x + r * .9, c.y + r * .6, c.z + r * 1.5); cam.lookAt(c); renderer.render(sc, cam); thumbs['d_' + d.id] = cv.toDataURL(); sc.remove(o);
  }
  renderer.setPixelRatio(pr); renderer.setSize(size.x, size.y, false); renderer.setClearColor(0x000000, 1); scene.background = bg;
}

/* ---------- arranque ---------- */
async function boot() {
  const L = new GLTFLoader(), files = [['gamba', 'models/gamba.glb'], ['chaqueta', 'models/gamba_chaqueta.glb'], ['langostino', 'models/langostino.glb'], ...DECOR.filter(d => d.at).map(d => [d.kind, 'models/k/' + d.kind + '.glb'])];
  let n = 0;
  await Promise.all(files.map(([k, u]) => new Promise((ok, ko) => L.load(u, g => { if (k === 'gamba' || k === 'chaqueta' || k === 'langostino') SRC[k] = g; else K[k] = g; $('loadBar').style.width = (++n / files.length * 100) + '%'; ok(); }, undefined, ko))));
  buildTank(); applyLight();
  makeThumbs();
  if (!Q.has('many') && !Q.has('deco')) for (const id of S.decor) buildDecor(DECOR.find(d => d.id === id));
  if (Q.has('many')) S.shrimps = Q.get('many').split(',').map((id, i) => ({ sp: id, lvl: 1, uid: i + 1 }));
  if (Q.has('deco')) S.decor = Q.get('deco') === 'all' ? DECOR.map(d => d.id) : Q.get('deco').split(',');
  if (Q.has('many') || Q.has('deco')) for (const id of S.decor) buildDecor(DECOR.find(d => d.id === id));
  for (const rec of S.shrimps) if (!S.seen.includes(rec.sp)) S.seen.push(rec.sp);
  for (const rec of S.shrimps) { const a = addActor(rec, false); a.pos.y = sandY(a.pos.x, a.pos.z); a.mode = 'walk'; }
  // ganancias mientras no estabas
  const away = (Date.now() - S.last) / 1000, capS = (2 + 2 * lv('bomba')) * 3600;
  if (away > 60 && !Q.has('shot')) {
    const secs = Math.min(away, capS), earned = income(false) * secs * (1 + .2 * lv('comedero'));
    addCoins(earned);
    modal('¡Bienvenido de vuelta!', `Tus gambas han estado trabajando ${fmtTime(secs)}${away > capS ? ' (máximo ' + fmtTime(capS) + ')' : ''}.`, `<div class="big-coins"><span class="coin"></span>${fmt(earned)}</div>`);
  } else if (S.total === 0 && !Q.has('shot')) modal('Tu pecera de gambas', 'Las gambas dan monedas solas. Toca el agua para darles de comer (¡comen y producen el doble!), toca una gamba para mimarla y subirla de nivel, y llena la pecera de especies y decoración.', '', '¡A por ello!');
  persist();
  $('loading').hidden = true;
  document.addEventListener('visibilitychange', () => { if (document.hidden) persist(); else { const away2 = (Date.now() - S.last) / 1000; if (away2 > 60) { const e2 = income(false) * Math.min(away2, (2 + 2 * lv('bomba')) * 3600); addCoins(e2); toast('Mientras no estabas: +' + fmt(e2)); } } });
  addEventListener('pagehide', persist);
  if (Q.has('shot')) return testShot();
  frame();
}
function testShot() {
  document.body.classList.add('shot');
  if (Q.has('feed')) dropFood(0, 10, 1.3);
  if (Q.has('golden')) spawnGolden();
  const T = +(Q.get('t') || 0); for (let i = 0; i < T * 30; i++) update(1 / 30);
  if (Q.has('tab')) openTab(Q.get('tab')); if (Q.has('card') && actors[0]) showCard(actors[0]);
  renderer.render(scene, camera); const im = $('shotImg'); im.src = cv.toDataURL(); im.style.display = 'block'; document.title = 'LISTO';
}
boot();
