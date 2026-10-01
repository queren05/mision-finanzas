// Brainrot Battle: colecciona personajes «italian brainrot» y lucha 3 contra 3 por turnos.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import * as SkeletonUtils from './lib/SkeletonUtils.js';
import * as M from './modelos.js';
import { BUILD, RAR } from './personajes.js';
import { CHARS, CARDS_NEED, MAX_LV, upCost, statAt, BOXES, FREE_BOX_H, stageTeam, stageReward, STAGE_NAMES, SPECIALS } from './datos.js';
import { Particles, Floaters } from './particulas.js';
import * as SND from './sonido.js';

const Q = new URLSearchParams(location.search);
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const rnd = (a, b) => a + Math.random() * (b - a), clamp = (v, a, b) => Math.max(a, Math.min(b, v)), lerp = (a, b, t) => a + (b - a) * t;
const S = SND.S, buzz = SND.buzz, V = (x, y, z) => new THREE.Vector3(x, y, z), col = h => new THREE.Color(h);
const charById = id => CHARS.find(c => c.id === id);
const fmt = n => n >= 1e6 ? (n / 1e6).toFixed(1).replace('.', ',') + 'M' : n >= 1e4 ? Math.round(n / 1000) + 'K' : String(Math.floor(n));
if (Q.has('shot')) addEventListener('error', e => { const d = document.createElement('div'); d.style.cssText = 'position:fixed;top:0;left:0;right:0;color:#f55;z-index:99;font:12px monospace;background:#000c;padding:4px'; d.textContent = e.message + ' @' + (e.filename || '').split('/').pop() + ':' + e.lineno; document.body.appendChild(d); });

/* ---------- guardado ---------- */
const K = 'brb.';
const get = (k, d) => { try { const v = JSON.parse(localStorage.getItem(K + k)); return v ?? d; } catch (e) { return d; } };
const DEF = { coins: 100, owned: { patapim: { lvl: 1, cards: 0 }, bana: { lvl: 1, cards: 0 }, boneca: { lvl: 1, cards: 0 } }, team: ['patapim', 'bana', 'boneca'], stage: 1, stars: {}, free: 0, opt: { sfx: true, music: true, haptic: true } };
const save = {}; for (const k of Object.keys(DEF)) save[k] = get(k, DEF[k]);
save.opt = Object.assign({}, DEF.opt, save.opt);
const persist = () => { for (const k of Object.keys(DEF)) try { localStorage.setItem(K + k, JSON.stringify(save[k])); } catch (e) { } };
Object.assign(SND.cfg, save.opt);

/* ---------- motor ---------- */
const cv = $('#cv');
const R = new THREE.WebGLRenderer({ canvas: cv, antialias: true });
R.setPixelRatio(Math.min(devicePixelRatio, 2)); R.outputColorSpace = THREE.SRGBColorSpace; R.toneMapping = THREE.ACESFilmicToneMapping; R.toneMappingExposure = 1.1;
R.shadowMap.enabled = true; R.shadowMap.type = THREE.PCFSoftShadowMap;
const scene = new THREE.Scene();
const cam = new THREE.PerspectiveCamera(40, 1, .1, 200);
const camBase = { pos: V(0, 6, 10), look: V(0, .7, 0) }, camLook = V(0, .7, 0), menuCam = { dist: 8 };
function resize() {
  R.setSize(innerWidth, innerHeight, false); cam.aspect = innerWidth / innerHeight; cam.fov = cam.aspect < 1 ? 55 : 40; cam.updateProjectionMatrix();
  const hf = 2 * Math.atan(Math.tan(THREE.MathUtils.degToRad(cam.fov) / 2) * cam.aspect), d = 3.3 / Math.tan(hf / 2);
  camBase.pos.set(0, Math.max(5, d * .6), Math.max(7.5, d * .8) + 1); camBase.look.set(0, .2, .9);
  menuCam.dist = 2.6 / Math.tan(hf / 2);
  if (PN) { PN.setPixelRatio(R.getPixelRatio()); PA.setPixelRatio(R.getPixelRatio()); }
}
addEventListener('resize', resize);
let PN, PA, FL;

/* ---------- arena ---------- */
function buildArena() {
  scene.background = M.canvasTex(4, 256, (x, w, h) => { const g = x.createLinearGradient(0, 0, 0, h); g.addColorStop(0, '#2a1060'); g.addColorStop(.55, '#c84a8a'); g.addColorStop(1, '#ffb070'); x.fillStyle = g; x.fillRect(0, 0, w, h); }, false);
  scene.fog = new THREE.Fog(0x8a3a7a, 25, 60);
  scene.add(new THREE.HemisphereLight(0xffe0f0, 0x4a2a5a, 1.5));
  const sun = new THREE.DirectionalLight(0xfff0d8, 2.4); sun.position.set(-5, 10, 6); sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024); Object.assign(sun.shadow.camera, { left: -8, right: 8, top: 8, bottom: -8 }); scene.add(sun);
  const stone = M.canvasTex(256, 256, (c, w, h) => { c.fillStyle = '#b8a890'; c.fillRect(0, 0, w, h); for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) { const v = rnd(.85, 1.08); c.fillStyle = `rgb(${190 * v | 0},${172 * v | 0},${146 * v | 0})`; c.fillRect(x * 32 + 1 + (y % 2) * 16, y * 32 + 1, 30, 30); } });
  stone.repeat.set(3, 3);
  const floor = new THREE.Mesh(new THREE.CylinderGeometry(7, 7.4, .5, 48), new THREE.MeshStandardMaterial({ map: stone, roughness: .9 })); floor.position.y = -.25; floor.receiveShadow = true; scene.add(floor);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(5.2, .06, 8, 64), new THREE.MeshBasicMaterial({ color: 0xffd84a })); ring.rotation.x = Math.PI / 2; ring.position.y = .02; scene.add(ring);
  const mid = new THREE.Mesh(new THREE.CircleGeometry(1.2, 32), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: .15 })); mid.rotation.x = -Math.PI / 2; mid.position.y = .02; scene.add(mid);
  // columnas y gradas con público
  const colMat = new THREE.MeshStandardMaterial({ color: 0xe8dcc8, roughness: .8 });
  for (let i = 0; i < 14; i++) { const a = i / 14 * Math.PI * 2; if (Math.sin(a) > .55) continue; const c = new THREE.Mesh(new THREE.CylinderGeometry(.35, .4, 5, 12), colMat); c.position.set(Math.cos(a) * 8.6, 2.5, Math.sin(a) * 8.6); c.castShadow = true; scene.add(c); const cap = new THREE.Mesh(new THREE.BoxGeometry(1, .3, 1), colMat); cap.position.set(c.position.x, 5.1, c.position.z); scene.add(cap); }
  const stand = new THREE.Mesh(new THREE.CylinderGeometry(14, 10, 4, 48, 1, true), new THREE.MeshStandardMaterial({ color: 0x6a4a6a, side: THREE.BackSide, roughness: 1 })); stand.position.y = 1.5; scene.add(stand);
  const crowd = new THREE.InstancedMesh(new THREE.CapsuleGeometry(.13, .22, 3, 6), new THREE.MeshStandardMaterial({ roughness: .8 }), 520), m4 = new THREE.Matrix4(), cc = new THREE.Color();
  for (let i = 0; i < 520; i++) { const a = rnd(0, Math.PI * 2), r = rnd(10.3, 13.5), y = (r - 10) * 1.1 + .5; if (Math.sin(a) > .5) { i--; continue; } m4.makeTranslation(Math.cos(a) * r, y, Math.sin(a) * r); crowd.setMatrixAt(i, m4); crowd.setColorAt(i, cc.setHSL(Math.random(), .7, .55)); }
  scene.add(crowd); world.crowd = crowd;
  // banderines
  for (let i = 0; i < 6; i++) { const a = -Math.PI * .9 + i * .36; const f = new THREE.Mesh(new THREE.PlaneGeometry(1, 1.6), new THREE.MeshStandardMaterial({ color: [0xff5ab8, 0xffd84a, 0x4ad8ff][i % 3], side: THREE.DoubleSide })); f.position.set(Math.cos(a) * 8.6, 4.2, Math.sin(a) * 8.6); f.lookAt(0, 4.2, 0); scene.add(f); }
}
const world = {};

/* ---------- modelos de personajes ---------- */
const GL = {};
function makeModel(id) {
  const g = new THREE.Group(); let inner, pose = null;
  if (id === 'tung') { const t = new M.Tung({ scene: GL.tung.scene.clone(true) }); inner = t.root; inner.scale.setScalar(.72); pose = (ph, mode, tt, dt) => t.pose(ph, mode, tt, dt); }
  else if (id === 'trippi') {
    const sh = new M.Shrimp({ gamba: { scene: SkeletonUtils.clone(GL.gamba.scene), animations: [] }, hood: GL.hood });
    inner = sh.root; sh.ensure('gamba'); sh.useNow('gamba'); sh.setHat('gato'); sh.setSkin({ h: -.03, s: 1.6, v: 1 });   // ensure() termina sin esperar porque el modelo ya está cargado inner.scale.setScalar(1.3); pose = (ph, mode, tt, dt) => sh.pose(ph, mode === 'hit' ? 'run' : 'idle', tt, dt, 2);
  } else inner = BUILD[id]();
  inner.traverse(o => { if (o.isMesh) { o.castShadow = true; } });
  g.add(inner); g.userData = { inner, pose };
  return g;
}

/* ---------- combate ---------- */
let B = null;   // estado del combate
const SLOTS = [-1.9, 0, 1.9];
function unitFrom(id, lvl, side, slot, boss) {
  const c = charById(id), hp = statAt(c.hp, lvl) * (boss ? 1.6 : 1), m = makeModel(id);
  m.position.set(SLOTS[slot] * (side === 'foe' ? 1 : 1), 0, side === 'foe' ? -2.3 : 2.3); m.rotation.y = side === 'foe' ? 0 : Math.PI;
  if (boss) m.scale.setScalar(1.25);
  scene.add(m);
  const el = document.createElement('div'); el.className = 'ub ' + side; el.innerHTML = `<b>${boss ? 'JEFE · ' : ''}${c.name} · ${lvl}</b><div class="hp"><i></i></div><div class="en"><i></i></div><div class="st"></div>`; $('#bars').appendChild(el);
  return { id, c, lvl, side, slot, boss, hp, maxHp: hp, atk: statAt(c.atk, lvl) * (boss ? 1.2 : 1), spd: c.spd, energy: side === 'foe' ? 20 : 0, alive: true, m, el, home: m.position.clone(), burn: 0, stun: 0, anim: null, flash: 0, t: rnd(0, 6) };
}
function startBattle(stage) {
  clearBattle(); closeAll();
  const foes = stageTeam(stage);
  B = { stage, units: [], queue: [], turn: null, phase: 'wait', wait: 1.2, auto: !!save.auto, speed: save.speed || 1, shield: { me: 0, foe: 0 }, round: 0, lost: 0 };
  save.team.forEach((id, i) => { const o = save.owned[id]; if (o) B.units.push(unitFrom(id, o.lvl, 'me', i, false)); });
  foes.forEach((f, i) => B.units.push(unitFrom(f.id, f.lvl, 'foe', i, f.boss)));
  hideMenuModels(); $('#hud').hidden = false; $('#bStage').textContent = `Nivel ${stage}${stage % 10 === 0 ? ' · JEFE' : ''}`;
  $('#autoBtn').classList.toggle('on', B.auto); $('#speedBtn').textContent = 'x' + B.speed;
  bigText(stage % 10 === 0 ? '¡JEFE!' : '¡A LUCHAR!'); S.levelup && S.levelup(); mode = 'battle'; SND.setMusic(true);
}
function clearBattle() { if (!B) return; for (const u of B.units) { scene.remove(u.m); u.el.remove(); } B = null; $('#bars').innerHTML = ''; }
const alive = side => B.units.filter(u => u.side === side && u.alive);
function nextTurn() {
  if (!alive('me').length || !alive('foe').length) return endBattle(alive('me').length > 0);
  if (!B.queue.length) { B.round++; B.queue = B.units.filter(u => u.alive).sort((a, b) => b.spd * rnd(.9, 1.1) - a.spd * rnd(.9, 1.1)); if (B.shield.me) B.shield.me--; if (B.shield.foe) B.shield.foe--; }
  const u = B.queue.shift(); if (!u.alive) return nextTurn();
  B.turn = u;
  // quemadura y aturdimiento
  if (u.burn > 0) { u.burn--; const d = Math.round(u.maxHp * .08); damage(u, d, null, '#ff8a2a'); if (!u.alive) { B.phase = 'wait'; B.wait = .7; return; } }
  if (u.stun > 0) { u.stun--; FL.add('¡Aturdido!', u.m.position.x, 2.2, u.m.position.z, { color: '#ffe07a', size: .8, life: 1 }); B.phase = 'wait'; B.wait = .8; return; }
  if (u.side === 'me' && !B.auto) { B.phase = 'choose'; showActions(u); }
  else { B.phase = 'ai'; B.wait = .45; }
}
function showActions(u) {
  const sp = SPECIALS[u.id], ready = u.energy >= 100;
  $('#actions').hidden = false; $('#pickTxt').hidden = true;
  $('#spcName').textContent = u.c.sp.toUpperCase(); $('#spcSub').textContent = ready ? u.c.spd2 : `Energía ${Math.floor(u.energy)}/100`;
  $('#actSpc').disabled = !ready; $('#actSpc').classList.toggle('ready', ready);
  $('#turnTxt').textContent = `Turno de ${u.c.name}`;
}
let pending = null;
function choose(kind) {
  const u = B.turn; if (!u || B.phase !== 'choose') return;
  const sp = SPECIALS[u.id];
  if (kind === 'spc' && (u.energy < 100)) return;
  const needTarget = kind === 'atk' || sp.kind === 'single';
  $('#actions').hidden = true;
  if (needTarget && alive('foe').length > 1) { pending = kind; B.phase = 'pick'; $('#pickTxt').hidden = false; return; }
  act(u, kind, alive('foe')[0]);
}
function act(u, kind, target) {
  B.phase = 'anim'; $('#pickTxt').hidden = true; $('#turnTxt').textContent = '';
  const sp = SPECIALS[u.id], foes = B.units.filter(x => x.side !== u.side && x.alive), mates = B.units.filter(x => x.side === u.side && x.alive);
  if (kind === 'atk') { u.energy = Math.min(100, u.energy + 25); lunge(u, target, () => hit(u, target, 1)); return; }
  u.energy = 0; bigText(u.c.sp.toUpperCase(), u.side === 'me' ? '' : 'foe'); S.levelup && S.levelup(); buzz('MEDIUM');
  if (sp.kind === 'single') { let n = 0; const go = () => { lunge(u, target, () => { hit(u, target, sp.mult, sp); n++; if (n < sp.hits && target.alive) { u.anim.after = go; } }); }; go(); }
  else if (sp.kind === 'all') { spin(u, () => { for (const f of foes) { PA.burst(f.m.position.x, 1, f.m.position.z, 30, col(u.id === 'bonbon' ? 0xff8a2a : u.id === 'croco' ? 0xffd84a : 0x4ad8ff), 3, .2, .7, 2); hit(u, f, sp.mult, sp); } shake(.5); }); }
  else if (sp.kind === 'heal') { spin(u, () => { for (const m of mates) { const h = Math.round(m.maxHp * sp.amount); m.hp = Math.min(m.maxHp, m.hp + h); FL.add('+' + h, m.m.position.x, 2, m.m.position.z, { color: '#7cff9a', size: .9, life: 1.2 }); PA.burst(m.m.position.x, 1, m.m.position.z, 20, col(0x7cff9a), 1.5, .15, .9, -1); } S.happy && S.happy(); }); }
  else if (sp.kind === 'shield') { spin(u, () => { B.shield[u.side] = sp.turns + 1; for (const m of mates) PA.burst(m.m.position.x, 1, m.m.position.z, 20, col(0x9ad0ff), 1.5, .15, .9, 0); FL.add('¡ESCUDO!', u.m.position.x, 2.3, u.m.position.z, { color: '#9ad0ff', size: 1, life: 1.2 }); }); }
}
function hit(u, t, mult, sp) {
  if (!t || !t.alive) return;
  const crit = Math.random() < .1, base = u.atk * mult * rnd(.9, 1.1) * (crit ? 1.6 : 1) * (B.shield[t.side] ? .5 : 1);
  damage(t, Math.round(base), crit, crit ? '#ffe07a' : '#ffffff');
  t.energy = Math.min(100, t.energy + 15);
  if (sp && sp.stun && t.alive) { t.stun = sp.stun; FL.add('¡Aturdido!', t.m.position.x, 2.4, t.m.position.z, { color: '#ffe07a', size: .7, life: 1 }); }
  if (sp && sp.burn && t.alive) t.burn = sp.burn;
}
function damage(t, d, crit, color) {
  t.hp = Math.max(0, t.hp - d); t.flash = .25;
  FL.add((crit ? '¡' : '') + d + (crit ? '!' : ''), t.m.position.x + rnd(-.3, .3), 2.1, t.m.position.z, { color, size: crit ? 1.1 : .8, life: 1, font: '400 84px "Luckiest Guy", Fredoka, sans-serif' });
  PN.burst(t.m.position.x, 1, t.m.position.z, 10, col(0xffffff), 2, .12, .4, 4); S.pop && S.pop(); buzz('LIGHT');
  if (t.hp <= 0 && t.alive) { t.alive = false; t.dieT = 0; S.bad && S.bad(); shake(.3); if (t.side === 'me') B.lost++; }
}
function lunge(u, t, onHit) { const from = u.home.clone(), to = t.m.position.clone().lerp(from, .35); u.anim = { type: 'lunge', t: 0, from, to, onHit, hitDone: false }; }
function spin(u, onHit) { u.anim = { type: 'spin', t: 0, onHit, hitDone: false }; }
function updUnit(u, dt) {
  u.t += dt; const m = u.m, inner = m.userData.inner;
  if (!u.alive) { u.dieT += dt; inner.rotation.z = Math.min(1, u.dieT * 3) * (u.side === 'me' ? -1.4 : 1.4); inner.position.y = Math.max(-.2, -u.dieT * .3 + .0); return; }
  // respirar / botar
  let mode = 'idle';
  inner.position.y = Math.abs(Math.sin(u.t * 2.2)) * .05; inner.scale.y = inner.scale.x * (1 + Math.sin(u.t * 4.4) * .02);
  if (u.anim) {
    const a = u.anim; a.t += dt;
    if (a.type === 'lunge') { const k = a.t < .28 ? a.t / .28 : a.t < .4 ? 1 : Math.max(0, 1 - (a.t - .4) / .3); m.position.lerpVectors(a.from, a.to, k * k * (3 - 2 * k)); m.position.y = Math.sin(k * Math.PI) * .4; mode = 'hit';
      if (!a.hitDone && a.t >= .28) { a.hitDone = true; a.onHit && a.onHit(); }
      if (a.t >= .7) { m.position.copy(u.home); u.anim = null; if (a.after) a.after(); else finishAct(); } }
    else if (a.type === 'spin') { inner.rotation.y = a.t / .6 * Math.PI * 2; m.position.y = Math.sin(Math.min(1, a.t / .6) * Math.PI) * .7; mode = 'hit';
      if (!a.hitDone && a.t >= .45) { a.hitDone = true; a.onHit && a.onHit(); }
      if (a.t >= .8) { inner.rotation.y = 0; m.position.copy(u.home); u.anim = null; finishAct(); } }
  }
  if (m.userData.pose) m.userData.pose(u.t * 8, mode, u.t, dt);
  // destello rojo al recibir
  if (u.flash > 0) { u.flash -= dt; inner.position.x = Math.sin(u.t * 80) * .06 * (u.flash / .25); } else inner.position.x = 0;
}
function finishAct() { B.phase = 'wait'; B.wait = .5; }
function aiAct(u) {
  const foes = B.units.filter(x => x.side !== u.side && x.alive);
  const target = Math.random() < .65 ? foes.reduce((a, b) => (b.hp < a.hp ? b : a)) : foes[Math.floor(Math.random() * foes.length)];
  const sp = SPECIALS[u.id];
  if (u.energy >= 100 && !(sp.kind === 'heal' && B.units.filter(x => x.side === u.side && x.alive).every(m => m.hp > m.maxHp * .8))) act(u, 'spc', target);
  else act(u, 'atk', target);
}
function updBattle(dt) {
  if (!B) return;
  const sdt = dt * B.speed;
  for (const u of B.units) updUnit(u, sdt);
  if (B.phase === 'wait' || B.phase === 'ai') { B.wait -= sdt; if (B.wait <= 0) { if (B.phase === 'ai') aiAct(B.turn); else nextTurn(); } }
  // barras sobre las cabezas
  for (const u of B.units) {
    const p = u.m.position.clone(); p.y += (u.boss ? 2.3 : 1.9); p.project(cam);
    u.el.style.left = ((p.x + 1) / 2 * innerWidth) + 'px'; u.el.style.top = ((1 - p.y) / 2 * innerHeight - 40) + 'px';
    u.el.querySelector('.hp i').style.width = (u.hp / u.maxHp * 100) + '%'; u.el.querySelector('.en i').style.width = u.energy + '%'; u.el.querySelector('.en').classList.toggle('full', u.energy >= 100);
    u.el.querySelector('.st').textContent = (u.burn ? 'QUEMADO ' : '') + (u.stun ? 'ATURDIDO ' : '') + (B.shield[u.side] ? 'ESCUDO' : '');
    u.el.classList.toggle('dead', !u.alive);
  }
  // anillo bajo quien tiene el turno
  if (B.turn && B.turn.alive) { turnRing.visible = true; turnRing.position.set(B.turn.m.position.x, .03, B.turn.home.z); turnRing.material.color.set(B.turn.side === 'me' ? 0x5fe37a : 0xff5a5a); turnRing.scale.setScalar(1 + Math.sin(T * 6) * .06); } else turnRing.visible = false;
  // anillo bajo los enemigos que se pueden elegir
  pickRings.forEach((r, i) => { const f = B.units.filter(u => u.side === 'foe')[i]; r.visible = B.phase === 'pick' && f && f.alive; if (r.visible) { r.position.set(f.m.position.x, .03, f.m.position.z); r.scale.setScalar(1 + Math.sin(T * 8) * .1); } });
}
const turnRing = new THREE.Mesh(new THREE.RingGeometry(.65, .8, 40), new THREE.MeshBasicMaterial({ color: 0x5fe37a, transparent: true, opacity: .9 })); turnRing.rotation.x = -Math.PI / 2; scene.add(turnRing);
const pickRings = [0, 1, 2].map(() => { const r = new THREE.Mesh(new THREE.RingGeometry(.7, .9, 40), new THREE.MeshBasicMaterial({ color: 0xffd84a, transparent: true, opacity: .9 })); r.rotation.x = -Math.PI / 2; r.visible = false; scene.add(r); return r; });
function endBattle(win) {
  B.phase = 'over'; $('#actions').hidden = true; $('#turnTxt').textContent = '';
  setTimeout(() => {
    const st = B.stage, stars = win ? 3 - Math.min(2, B.lost) : 0, first = win && !save.stars[st];
    let coins = win ? stageReward(st) * (first ? 2 : 1) : Math.round(stageReward(st) * .15);
    const rew = [`<div><span class="coin"></span> +${coins}</div>`];
    if (win) { save.stars[st] = Math.max(save.stars[st] || 0, stars); if (st === save.stage) save.stage = st + 1; }
    let box = null; if (first && st % 5 === 0) { box = st % 10 === 0 ? 'plata' : 'basica'; rew.push(`<div>+ ${BOXES.find(b => b.id === box).name}</div>`); }
    save.coins += coins; persist();
    $('#resT').textContent = win ? '¡VICTORIA!' : 'DERROTA'; $('#resT').classList.toggle('lose', !win);
    $('#resStars').innerHTML = win ? '★'.repeat(stars) + '<span style="opacity:.25">' + '★'.repeat(3 - stars) + '</span>' : '';
    $('#resRew').innerHTML = rew.join('') + (win ? '' : '<div style="font-size:14px;font-weight:500;color:var(--muted)">Mejora a tus personajes o abre cajas para conseguir más</div>');
    $('#resNext').textContent = win ? 'SIGUIENTE' : 'REINTENTAR'; $('#result').hidden = false; $('#hud').hidden = true; mode = 'result';
    world.pendingBox = box;
    if (win) { S.levelup && S.levelup(); for (let i = 0; i < 40; i++) PA.emit(rnd(-4, 4), rnd(3, 6), rnd(-3, 3), rnd(-1, 1), rnd(0, 2), rnd(-1, 1), col([0xffd84a, 0xff5ab8, 0x4ad8ff][i % 3]), .2, 2, 2); } else S.sad && S.sad();
  }, 1200);
}

/* ---------- cajas ---------- */
function rollBox(id) {
  const bx = BOXES.find(b => b.id === id), got = {};
  for (let i = 0; i < bx.cards; i++) {
    let r = Math.random(), rar = 0; for (let k = 0; k < 4; k++) { if (r < bx.prob[k]) { rar = k; break; } r -= bx.prob[k]; }
    if (bx.minRar && i === 0) rar = Math.max(rar, bx.minRar);
    const pool = CHARS.filter(c => c.rar === rar); const c = pool[Math.floor(Math.random() * pool.length)];
    got[c.id] = (got[c.id] || 0) + 1;
  }
  return got;
}
function openBox(id) {
  const bx = BOXES.find(b => b.id === id), got = rollBox(id);
  $('#open').hidden = false; $('#openBox').style.background = `linear-gradient(180deg,${bx.col},#6a4a2a)`; $('#openBox').hidden = false; $('#openCards').innerHTML = ''; $('#openOk').hidden = true;
  S.crack && S.crack(); buzz('MEDIUM');
  setTimeout(() => {
    $('#openBox').hidden = true; S.hatch && S.hatch();
    const entries = Object.entries(got).sort((a, b) => charById(b[0]).rar - charById(a[0]).rar);
    $('#openCards').innerHTML = entries.map(([cid, n], i) => { const c = charById(cid), isNew = !save.owned[cid]; return `<div class="ocard ${isNew ? 'new' : ''}" style="--rc:${RAR[c.rar].col};animation-delay:${i * .18}s"><img src="${thumbs[cid] || ''}"><b>${c.name}</b><em>x${n}</em></div>`; }).join('');
    for (const [cid, n] of entries) { if (!save.owned[cid]) save.owned[cid] = { lvl: 1, cards: n - 1 }; else save.owned[cid].cards += n; }
    persist(); setTimeout(() => { $('#openOk').hidden = false; }, entries.length * 180 + 300);
  }, 1100);
}
$('#openOk').onclick = () => { $('#open').hidden = true; renderMenu(); if (!$('#boxes').hidden) renderBoxes(); };
function freeLeft() { return Math.max(0, save.free + FREE_BOX_H * 3600e3 - Date.now()); }
function renderBoxes() {
  $('#xCoins').textContent = fmt(save.coins);
  const fl = freeLeft(), h = Math.floor(fl / 3600e3), m = Math.ceil(fl % 3600e3 / 60e3);
  $('#blist').innerHTML = `<div class="bitem"><div class="bimg" style="background:linear-gradient(180deg,#7cff9a,#2a8a4a)"></div><div class="binfo"><b>Caja gratis</b><small>${fl ? `Disponible en ${h} h ${m} min` : 'Una cada ' + FREE_BOX_H + ' horas'}</small></div><button class="btn ${fl ? 'sec' : ''}" id="freeBox" ${fl ? 'disabled' : ''}>${fl ? 'Espera' : 'ABRIR'}</button></div>` +
    BOXES.map(b => `<div class="bitem"><div class="bimg" style="background:linear-gradient(180deg,${b.col},#6a4a2a)"></div><div class="binfo"><b>${b.name}</b><small>${b.cards} cartas${b.minRar ? ' · ¡una épica segura!' : ''} · Legendaria ${Math.round(b.prob[3] * 100)} %</small></div><button class="btn" data-box="${b.id}"><span class="coin"></span>${fmt(b.price)}</button></div>`).join('');
  const fb = $('#freeBox'); if (fb) fb.onclick = () => { if (freeLeft()) return; save.free = Date.now(); persist(); openBox('basica'); };
  $$('[data-box]').forEach(b => b.onclick = () => { const bx = BOXES.find(x => x.id === b.dataset.box); if (save.coins < bx.price) { toast(`Te faltan ${fmt(bx.price - save.coins)} monedas`); S.err && S.err(); return; } save.coins -= bx.price; persist(); openBox(bx.id); renderBoxes(); });
}

/* ---------- colección ---------- */
const thumbs = {};
function canUp(id) { const o = save.owned[id]; return o && o.lvl < MAX_LV && o.cards >= CARDS_NEED[o.lvl - 1] && save.coins >= upCost(o.lvl, charById(id).rar); }
function renderCol() {
  $('#cCoins').textContent = fmt(save.coins);
  $('#teamRow').innerHTML = [0, 1, 2].map(i => `<div class="slot">${save.team[i] ? `<img src="${thumbs[save.team[i]]}">` : '+'}</div>`).join('');
  const list = [...CHARS].sort((a, b) => (save.owned[b.id] ? 1 : 0) - (save.owned[a.id] ? 1 : 0) || b.rar - a.rar);
  $('#cgrid').innerHTML = list.map(c => { const o = save.owned[c.id]; if (!o) return `<div class="ccard locked" style="--rc:${RAR[c.rar].col}"><img src="${thumbs[c.id]}"><b>???</b><small style="font-size:10px;color:${RAR[c.rar].col}">${RAR[c.rar].name}</small></div>`;
    const need = CARDS_NEED[o.lvl - 1] || 1; return `<div class="ccard ${save.team.includes(c.id) ? 'team' : ''} ${canUp(c.id) ? 'can' : ''}" style="--rc:${RAR[c.rar].col}" data-c="${c.id}"><span class="lv">Nv ${o.lvl}</span><img src="${thumbs[c.id]}"><b>${c.name}</b><span class="cbar"><i class="${o.cards >= need ? 'full' : ''}" style="width:${Math.min(100, o.cards / need * 100)}%"></i></span></div>`; }).join('');
  $$('[data-c]').forEach(el => el.onclick = () => showDet(el.dataset.c));
}
function showDet(id) {
  const c = charById(id), o = save.owned[id], need = CARDS_NEED[o.lvl - 1], cost = upCost(o.lvl, c.rar), sp = SPECIALS[id];
  $('#det').hidden = false; $('#dImg').src = thumbs[id]; $('#dName').textContent = c.name; $('#dRar').textContent = `${RAR[c.rar].name} · Nivel ${o.lvl}`; $('#dRar').style.color = RAR[c.rar].col;
  $('#dStats').innerHTML = `<div><small>Vida</small><b>${statAt(c.hp, o.lvl)}</b></div><div><small>Ataque</small><b>${statAt(c.atk, o.lvl)}</b></div><div><small>Velocidad</small><b>${c.spd}</b></div>`;
  $('#dSpc').innerHTML = `<b>${c.sp}:</b> ${c.spd2}`;
  $('#dBar').style.width = Math.min(100, o.cards / (need || 1) * 100) + '%'; $('#dBar').className = o.cards >= need ? 'full' : '';
  $('#dCardsTxt').textContent = o.lvl >= MAX_LV ? 'Nivel máximo' : `Cartas: ${o.cards}/${need}`;
  $('#dUp').innerHTML = o.lvl >= MAX_LV ? 'Máximo' : `Mejorar · <span class="coin"></span>${fmt(cost)}`; $('#dUp').disabled = !canUp(id);
  const inT = save.team.includes(id); $('#dTeam').textContent = inT ? 'Quitar del equipo' : 'Al equipo';
  $('#dTeam').onclick = () => { if (inT) { if (save.team.length <= 1) return toast('Necesitas al menos uno en el equipo'); save.team = save.team.filter(x => x !== id); } else { if (save.team.length >= 3) save.team.shift(); save.team.push(id); } persist(); renderCol(); showDet(id); S.tap && S.tap(); };
  $('#dUp').onclick = () => { if (!canUp(id)) return; save.coins -= cost; o.cards -= need; o.lvl++; persist(); S.levelup && S.levelup(); buzz('MEDIUM'); toast(`¡${c.name} sube a nivel ${o.lvl}!`); renderCol(); showDet(id); };
}
$('#dClose').onclick = () => { $('#det').hidden = true; };

/* ---------- menú ---------- */
let mode = 'menu', T = 0, menuModels = [];
function renderMenu() {
  $('#mCoins').textContent = fmt(save.coins); const st = save.stage;
  $('#mWorld').textContent = STAGE_NAMES[Math.floor((st - 1) / 10) % STAGE_NAMES.length]; $('#mStage').textContent = `Nivel ${st}` + (st % 10 === 0 ? ' · JEFE' : '');
  $('#mStars').textContent = ''; $('#boxDot').hidden = !!freeLeft(); $('#colDot').hidden = !save.team.concat(Object.keys(save.owned)).some(canUp);
}
function showMenuModels() {
  hideMenuModels();
  save.team.forEach((id, i) => { const m = makeModel(id); m.position.set(SLOTS[i] * .9, 0, 1.2 + (i === 1 ? .4 : 0)); m.rotation.y = 0; scene.add(m); menuModels.push(m); });
}
function hideMenuModels() { for (const m of menuModels) scene.remove(m); menuModels = []; }
function closeAll() { for (const s of ['#menu', '#result', '#col', '#boxes', '#det', '#open', '#settings']) $(s).hidden = true; }
function toMenu() { clearBattle(); closeAll(); $('#hud').hidden = true; $('#menu').hidden = false; mode = 'menu'; renderMenu(); showMenuModels(); SND.setMusic(true); }
let toastT = 0;
function toast(m) { const t = $('#toast'); t.textContent = m; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 1800); }
function bigText(t, cls = '') { const b = $('#bigTxt'); b.textContent = t; b.className = cls; void b.offsetWidth; b.classList.add('on'); }
let shakeA = 0; const shake = a => shakeA = Math.max(shakeA, a);
$('#playBtn').onclick = () => { SND.ac(); startBattle(save.stage); };
$('#colBtn').onclick = () => { closeAll(); $('#col').hidden = false; renderCol(); };
$('#colClose').onclick = () => toMenu();
$('#boxBtn').onclick = () => { closeAll(); $('#boxes').hidden = false; renderBoxes(); };
$('#boxClose').onclick = () => toMenu();
$('#resNext').onclick = () => { const box = world.pendingBox; world.pendingBox = null; if (box) { openBox(box); $('#result').hidden = true; $('#openOk').onclick = () => { $('#open').hidden = true; $('#openOk').onclick = null; startBattle(save.stage); }; return; } startBattle(save.stage); };
$('#resMenu').onclick = () => { const box = world.pendingBox; world.pendingBox = null; toMenu(); if (box) openBox(box); };
$('#actAtk').onclick = () => choose('atk');
$('#actSpc').onclick = () => choose('spc');
$('#autoBtn').onclick = () => { B.auto = !B.auto; save.auto = B.auto; $('#autoBtn').classList.toggle('on', B.auto); if (B.auto && B.phase === 'choose') { $('#actions').hidden = true; B.phase = 'ai'; B.wait = .2; } };
$('#speedBtn').onclick = () => { B.speed = B.speed === 1 ? 2 : 1; save.speed = B.speed; $('#speedBtn').textContent = 'x' + B.speed; };
$('#quitBtn').onclick = () => { if (confirm('¿Abandonar el combate?')) toMenu(); };
$('#setBtn').onclick = () => { $('#optSfx').checked = save.opt.sfx; $('#optMusic').checked = save.opt.music; $('#optHaptic').checked = save.opt.haptic; $('#settings').hidden = false; };
$('#setClose').onclick = () => { $('#settings').hidden = true; };
for (const [id, k] of [['#optSfx', 'sfx'], ['#optMusic', 'music'], ['#optHaptic', 'haptic']]) $(id).onchange = e => { save.opt[k] = e.target.checked; Object.assign(SND.cfg, save.opt); persist(); if (k === 'music') SND.setMusic(true); };
// elegir enemigo tocándolo
const ray = new THREE.Raycaster(), ndc = new THREE.Vector2();
cv.addEventListener('pointerdown', e => {
  if (!B || B.phase !== 'pick') return;
  ndc.set(e.clientX / innerWidth * 2 - 1, -(e.clientY / innerHeight) * 2 + 1); ray.setFromCamera(ndc, cam);
  let best = null, bd = 1e9; for (const u of alive('foe')) { const c = u.m.position.clone(); c.y = .9; const d = ray.ray.distanceSqToPoint(c); if (d < bd) { bd = d; best = u; } }
  if (best && bd < 1.6) act(B.turn, pending, best);
});
document.addEventListener('visibilitychange', () => { if (document.hidden) persist(); SND.suspend(document.hidden); });

/* ---------- bucle ---------- */
const clock = new THREE.Clock();
function frame(dt) {
  T += dt;
  if (mode === 'battle' || mode === 'result') updBattle(dt);
  if (mode === 'menu') menuModels.forEach((m, i) => { m.position.y = Math.abs(Math.sin(T * 2.2 + i)) * .08; m.rotation.y = Math.sin(T * .6 + i) * .4; if (m.userData.pose) m.userData.pose(T * 3, 'idle', T, dt); });
  // público que salta
  if (world.crowd && Math.random() < .3) { /* barato: solo se mueve el grupo */ world.crowd.position.y = Math.abs(Math.sin(T * 6)) * .05; }
  const look = mode === 'menu' ? V(0, 1.1, 1.3) : camBase.look, pos = mode === 'menu' ? V(0, 1.9 + menuCam.dist * .12, 1.3 + menuCam.dist) : camBase.pos;
  cam.position.lerp(pos, Math.min(1, dt * 3)); camLook.lerp(look, Math.min(1, dt * 3)); cam.lookAt(camLook);
  if (shakeA > 0) { cam.position.x += rnd(-1, 1) * shakeA * .15; cam.position.y += rnd(-1, 1) * shakeA * .1; shakeA = Math.max(0, shakeA - dt * 2); }
  PN.update(dt); PA.update(dt); FL.update(dt);
}
function loop() { requestAnimationFrame(loop); const dt = Math.min(1 / 30, clock.getDelta()); frame(dt); R.render(scene, cam); }

/* ---------- miniaturas ---------- */
function makeThumbs() {
  const sc = new THREE.Scene(); sc.add(new THREE.HemisphereLight(0xffffff, 0x664488, 2.2)); const dl = new THREE.DirectionalLight(0xffffff, 2); dl.position.set(2, 3, 4); sc.add(dl);
  const c2 = new THREE.PerspectiveCamera(30, 1, .05, 30), sz = R.getSize(new THREE.Vector2()), pr = R.getPixelRatio();
  R.setPixelRatio(1); R.setSize(160, 160, false); R.setClearColor(0, 0); const bg = scene.background;
  for (const c of CHARS) {
    const m = makeModel(c.id); m.rotation.y = .4; sc.add(m); if (m.userData.pose) m.userData.pose(0, 'idle', 0, .016);
    m.updateMatrixWorld(true); const b = new THREE.Box3().setFromObject(m), s = b.getSize(V(0, 0, 0)), ce = b.getCenter(V(0, 0, 0)), r = Math.max(s.x, s.y) * .62;
    c2.position.set(ce.x, ce.y + r * .15, ce.z + r / Math.tan(THREE.MathUtils.degToRad(15)) + s.z / 2); c2.lookAt(ce);
    R.clear(); R.render(sc, c2); thumbs[c.id] = cv.toDataURL(); sc.remove(m);
  }
  R.setPixelRatio(pr); R.setSize(sz.x, sz.y, false); R.setClearColor(0x000000, 1);
}

/* ---------- arranque ---------- */
async function boot() {
  resize(); buildArena();
  const L = new GLTFLoader(), files = [['tung', 'models/tung.glb'], ['gamba', 'models/gamba.glb'], ['hood', 'models/gorro_tiburon.glb']]; let n = 0;
  await Promise.all(files.map(([k, u]) => new Promise((ok, ko) => L.load(u, g => { GL[k] = g; $('#loadBar').style.width = (++n / files.length * 100) + '%'; ok(); }, undefined, ko))));
  PN = new Particles(scene, 300, false, R.getPixelRatio()); PA = new Particles(scene, 500, true, R.getPixelRatio()); FL = new Floaters(scene);
  if (Q.has('coins')) save.coins = +Q.get('coins');
  if (Q.has('all')) { for (const c of CHARS) save.owned[c.id] = save.owned[c.id] || { lvl: 3, cards: 7 }; }
  if (Q.get('team')) save.team = Q.get('team').split(',');
  if (Q.get('stage')) save.stage = +Q.get('stage');
  // la gamba con sombrero de gato necesita el modelo listo
  await new Promise(r => setTimeout(r, 50));
  makeThumbs();
  try { await Promise.all(['500 16px Fredoka', '700 16px Fredoka', '16px "Luckiest Guy"'].map(f => document.fonts.load(f))); } catch (e) { }
  $('#loading').hidden = true; toMenu(); requestAnimationFrame(loop);
  if (Q.has('shot')) testShot();
}
async function testShot() {
  document.head.insertAdjacentHTML('beforeend', '<style>*{animation:none!important;transition:none!important}</style>');
  if (Q.has('serif')) document.head.insertAdjacentHTML('beforeend', '<style>*{font-family:serif!important}</style>');
  await new Promise(r => setTimeout(r, 1500));
  if (Q.has('battle')) { startBattle(save.stage); B.auto = Q.has('auto'); for (let i = 0; i < (+Q.get('steps') || 0); i++) frame(1 / 30); }
  if (Q.get('screen') === 'col') $('#colBtn').click(); if (Q.get('screen') === 'boxes') $('#boxBtn').click(); if (Q.get('screen') === 'open') openBox('plata');
  for (let i = 0; i < 30; i++) frame(1 / 30);
  R.render(scene, cam); const im = $('#shotImg'); im.src = cv.toDataURL(); im.style.display = 'block'; document.title = 'LISTO';
}
boot().catch(e => { document.body.insertAdjacentHTML('beforeend', `<pre style="position:fixed;top:0;z-index:999;background:#fff;color:red">${e.message}\n${e.stack}</pre>`); });
