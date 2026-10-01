// Gambi: tu gamba de compañía en 3D. Se alimenta, se baña, duerme, juega y crece; las necesidades bajan con el tiempo
// (también con la app cerrada). Todo el estado se guarda en localStorage.
import * as THREE from './lib/three.module.min.js';
import * as M from './modelos.js';
import { save, persist, clamp, tickStats, mood, xpNeed, stageOf, STAGE, MAXLV, FOODS, CHARS, SKINS, MINIGAMES, NAMES, OFFLINE_CAP, ACH, FURNITURE } from './datos.js';
import { buildHouse } from './casa.js';
import { foodMesh } from './comida.js';
import { Particles, Floaters } from './particulas.js';
import { ICON } from './iconos.js';
import * as SND from './sonido.js';
import { createShop } from './tienda.js';

const Q = new URLSearchParams(location.search);
if (Q.has('shot')) { const dbg = []; const show = t => { dbg.push(t); let e = document.getElementById('dbg'); if (!e) { e = document.createElement('pre'); e.id = 'dbg'; e.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:99;background:#fffd;color:#900;font:10px monospace;margin:0;white-space:pre-wrap;max-height:40%;overflow:hidden'; document.body.appendChild(e); } e.textContent = dbg.join('\n'); }; addEventListener('error', e => show('ERR ' + e.message + ' @' + (e.filename || '').split('/').pop() + ':' + e.lineno)); addEventListener('unhandledrejection', e => show('REJ ' + (e.reason && e.reason.message || e.reason))); const w = console.warn; console.warn = (...a) => { show('WARN ' + a.map(x => x && x.message || x).join(' ')); w(...a); }; }
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const rnd = (a, b) => a + Math.random() * (b - a), lerp = (a, b, t) => a + (b - a) * t;
const S = SND.S, buzz = SND.buzz;
for (const e of $$('[data-i]')) e.innerHTML = ICON[e.dataset.i] || '';
Object.assign(SND.cfg, save.opt);

/* ---------- motor ---------- */
const cv = $('#cv');
const R = new THREE.WebGLRenderer({ canvas: cv, antialias: true, powerPreference: 'high-performance', preserveDrawingBuffer: Q.has('shot') });
const scene = new THREE.Scene(); scene.background = new THREE.Color(0x2a1f4d);
const cam = new THREE.PerspectiveCamera(50, 1, .1, 100);
R.shadowMap.enabled = true; R.shadowMap.type = THREE.PCFSoftShadowMap;
const hemi = new THREE.HemisphereLight(0xfff0dc, 0x8a7060, 1.65); scene.add(hemi);
const sun = new THREE.DirectionalLight(0xffe8c8, 2.1); sun.position.set(-2.5, 5, 4.5); scene.add(sun);
// sombras suaves de verdad (la gamba y los muebles las proyectan sobre el suelo)
sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024); Object.assign(sun.shadow.camera, { left: -4.5, right: 4.5, top: 5, bottom: -2.5, near: .5, far: 20 }); sun.shadow.camera.updateProjectionMatrix(); sun.shadow.bias = -.0012; sun.shadow.normalBias = .02; sun.shadow.radius = 5;
const lamp = new THREE.PointLight(0xffd9a0, 0, 7, 1.6); scene.add(lamp);
const TAN = .52;   // mitad del ancho visible / distancia a la gamba
const VIEW = { shift: .05 };   // cuánto se sube la escena para quedar entre la cabecera y la barra
function resize() {
  const w = innerWidth, h = innerHeight, pr = Math.min(devicePixelRatio || 1, save.opt.hq ? 2 : 1.25);
  R.setPixelRatio(pr); R.setSize(w, h, false); cam.aspect = w / h;
  cam.fov = clamp(THREE.MathUtils.radToDeg(2 * Math.atan(TAN / cam.aspect)), 34, 78);
  cam.updateProjectionMatrix();
  if (PN) { PN.setPixelRatio(pr); PA.setPixelRatio(pr); }
}
addEventListener('resize', resize);
let PN = null, PA = null, FL = null;

/* ---------- estado ---------- */
let house, player, shop, shadow, foam, eggM, A = {};
let mode = 'loading';                 // loading | egg | home | shop | mini
let room = Q.get('room') || 'salon';
let T = 0, lastReal = Date.now(), saveT = 0, hudT = 0, warnT = 12, nightK = 0, mini = null;
const clock = new THREE.Clock();
const pet = { x: 0, y: 0, z: .5, yaw: 2.5, tx: 0, tz: .5, wait: 1, hopY: 0, hopV: 0, ph: 0, act: null, sc: .55, pets: 0, cool: 0, bond: 0, sleepZ: 0, speed: 0, hearts: 0, wiggle: 0, foam: 0, scrubSfx: 0, shake: 0 };
const FACE = Math.atan2(.55, -.83);           // mirando a la cámara, un poco hacia la izquierda
const heading = () => new THREE.Vector3(-Math.sin(pet.yaw), 0, -Math.cos(pet.yaw));
const _v = new THREE.Vector3();

/* ---------- avisos ---------- */
let toastT = 0;
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 2200); }
let hintT = 0;
function hint(msg, ms = 4200) { const h = $('#hint'); h.textContent = msg; h.hidden = false; clearTimeout(hintT); hintT = setTimeout(() => { h.hidden = true; }, ms); }

/* ---------- arranque ---------- */
async function boot() {
  resize();
  A = await M.loadAll({ hood: 'models/gorro_tiburon.glb', gamba: 'models/gamba.glb' }, p => { $('#loadBar').style.width = Math.round(p * 100) + '%'; });
  $('#loadTxt').textContent = 'Amueblando…';
  await new Promise(r => setTimeout(r, 20));
  PN = new Particles(scene, 300, false, R.getPixelRatio()); PA = new Particles(scene, 400, true, R.getPixelRatio()); FL = new Floaters(scene);
  house = buildHouse(scene);
  player = new M.Shrimp(A); scene.add(player.root);
  shadow = M.blob(1.15, 1.95); player.root.add(shadow);
  foam = makeFoam(); player.tilt.add(foam);
  eggM = makeEgg(); scene.add(eggM.group); eggM.group.visible = false;
  if (Q.has('coins')) save.coins = +Q.get('coins');
  if (Q.has('hatched')) { save.hatched = true; save.name = save.name || 'Gambi'; }
  if (Q.get('lv')) { save.lv = +Q.get('lv'); }
  for (const k of ['char', 'hat', 'skin', 'theme']) if (Q.get(k)) save.eq[{ char: 'chars', hat: 'hats', skin: 'skins', theme: 'themes' }[k]] = Q.get(k);
  for (const k of ['food', 'fun', 'energy', 'hyg']) if (Q.has(k) && Number.isFinite(+Q.get(k))) save.st[k] = +Q.get(k);
  if (Q.get('give')) save.inv[Q.get('give')] = 3;
  if (Q.has('sleep')) save.sleeping = true;
  if (Q.has('sick')) save.sick = true;
  if (Q.get('furn')) for (const f of Q.get('furn').split(',')) save.furn[f] = true;
  // tiempo transcurrido con la app cerrada
  const away = clamp((Date.now() - save.t) / 1000, 0, OFFLINE_CAP);
  if (save.hatched && away > 60) { tickStats(away); if (save.sleeping && save.st.energy >= 99) save.sleeping = false; }
  lastReal = Date.now();
  await applyLook();
  pet.sc = STAGE[stageOf(save.lv)].scale;
  shop = createShop({ THREE, M, scene, R, cv, cam, house, player, pet, PN, PA, save, toast, updHud, S, buzz, applyLook, buildTray, leave: leaveShop, foodMesh, FL, VIEW, foam, lights: { hemi, sun, lamp }, setMode: m => { mode = m; } });
  $('#loading').hidden = true;
  setupUI();
  if (!save.hatched) startEgg();
  else { enterHome(); if (away > 600) toast(`Gambi te ha echado de menos (${Math.round(away / 3600 * 10) / 10 || '<1'} h)`); }
  requestAnimationFrame(loop);
  if (Q.get('view') === 'shop') shop.open(Q.get('tab') || 'food');
  if (Q.get('mini')) startMini(Q.get('mini'));
  if (Q.has('shot')) testShot();
}

async function applyLook(eq = save.eq) {
  const ch = CHARS.find(c => c.id === eq.chars) || CHARS[0];
  player.setSkin((SKINS.find(s => s.id === eq.skins) || SKINS[0]).p);
  player.hatId = eq.hats;
  house.applyTheme(eq.themes);
  house.setFurniture(Object.assign({}, save.furn, eq.furnPreview || {}), save.name || 'Gambi');
  await player.use(ch.model);
  shadowsOn();
}
function shadowsOn() {
  player.root.traverse(o => { if (o.isMesh && o !== shadow) o.castShadow = true; });
  for (const r of Object.values(house.rooms)) r.traverse(o => { if (o.isMesh) { o.castShadow = !o.material.transparent; o.receiveShadow = true; } });
  house.shared.traverse(o => { if (o.isMesh) o.receiveShadow = true; });
}

/* ---------- huevo ---------- */
function makeEgg() {
  const g = new THREE.Group(), cr = { n: 0 };
  const c = document.createElement('canvas'); c.width = c.height = 512; const x = c.getContext('2d');
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
  const draw = () => {
    const gr = x.createLinearGradient(0, 0, 0, 512); gr.addColorStop(0, '#fff6e6'); gr.addColorStop(1, '#ffd9b0'); x.fillStyle = gr; x.fillRect(0, 0, 512, 512);
    let s = 7; const r = () => (s = (s * 16807) % 2147483647) / 2147483647;
    for (let i = 0; i < 46; i++) { x.fillStyle = ['#ff9ab8', '#7fd6ff', '#ffd24a', '#b79cff'][i % 4]; x.globalAlpha = .75; x.beginPath(); x.ellipse(r() * 512, r() * 512, 10 + r() * 22, 8 + r() * 14, r() * 3, 0, 7); x.fill(); }
    x.globalAlpha = 1; x.strokeStyle = '#7a4a2a'; x.lineWidth = 7; x.lineJoin = 'round';
    for (let k = 0; k < cr.n; k++) { let px = 40 + k * 55, py = 200 + (k % 3) * 40; x.beginPath(); x.moveTo(px, py); for (let j = 0; j < 7; j++) { px += 14 + r() * 18; py += (j % 2 ? 1 : -1) * (18 + r() * 26); x.lineTo(px, py); } x.stroke(); }
    tex.needsUpdate = true;
  };
  draw();
  const mesh = new THREE.Mesh(new THREE.SphereGeometry(.6, 40, 30), new THREE.MeshStandardMaterial({ map: tex, roughness: .35 }));
  mesh.scale.set(1, 1.32, 1); mesh.position.y = .8; g.add(mesh);
  const sh = M.blob(1.3, 1.3); g.add(sh);
  return { group: g, mesh, cracks: n => { cr.n = n; draw(); }, taps: 0 };
}
function startEgg() {
  mode = 'egg'; eggM.taps = 0; eggM.cracks(0); eggM.group.visible = true; player.root.visible = false;
  house.setRoom('salon'); for (const s of ['#hud', '#nav', '#tray']) $(s).hidden = true;
  $('#egg').hidden = false; $('#eggSub').textContent = 'Tócalo para que nazca';
  SND.ac(); SND.setMusic(true);
}
function tapEgg() {
  if (eggM.taps >= 8) return;
  eggM.taps++; eggM.wob = .5; S.crack(); buzz('MEDIUM'); eggM.cracks(Math.floor(eggM.taps * .8));
  PA.burst(0, .8 + rnd(0, .6), .4, 6, new THREE.Color(0xffe6b0), 1.4, .12, .5);
  $('#eggSub').textContent = eggM.taps < 8 ? `${8 - eggM.taps} toques más…` : '¡Ya sale!';
  if (eggM.taps >= 8) setTimeout(hatch, 500);
}
function hatch() {
  S.hatch(); buzz('HEAVY');
  PA.burst(0, .9, .3, 70, new THREE.Color(0xffe27a), 3.4, .2, 1, 3); PN.burst(0, .9, .3, 40, new THREE.Color(0xfff2d0), 3, .18, .9, 4);
  eggM.group.visible = false; $('#egg').hidden = true;
  player.root.visible = true; pet.sc = 0; pet.x = 0; pet.z = .4; hop(5);
  $('#nameIn').value = NAMES[Math.floor(Math.random() * NAMES.length)]; $('#nameDlg').hidden = false;
}

/* ---------- la casa ---------- */
function enterHome() {
  mode = 'home';
  for (const s of ['#hud', '#nav']) $(s).hidden = false;
  player.root.visible = true; eggM.group.visible = false;
  goRoom(room, true); updHud(true); SND.setMusic(true);
}
function goRoom(id, first) {
  if (save.sleeping && id !== 'dormitorio') wake();
  room = id; house.setRoom(id); pet.act = null; foamSet(0);
  $$('#nav button').forEach(b => b.classList.toggle('on', b.dataset.room === id));
  buildTray();
  if (!first) { S.tap(); buzz(); }
  const H = { salon: 'Acaríciala, hazle cosquillas o enséñale trucos', cocina: 'Arrastra la comida hasta Gambi (o tócala)', bano: 'Frota a Gambi con el dedo y luego pulsa la ducha', dormitorio: 'Cuando tenga sueño, apaga la luz', juegos: 'Juega para ganar monedas y diversión' };
  hint(save.sick ? `${save.name} está mala: dale medicina en la cocina` : H[id], 3800);
}
function setupUI() {
  $$('#nav button').forEach(b => b.onclick = () => { if (mode === 'home') goRoom(b.dataset.room); });
  $('#shopBtn').onclick = () => { if (mode === 'home') { S.click(); shop.open('food'); } };
  $('#giftBtn').onclick = gift;
  document.addEventListener('pointerdown', e => { if (e.target.closest('button, .it, .tab, .game, .food, .lvl')) SND.tone(900, .045, 'sine', .05, 250); }, true);
  $('#lvlBox').onclick = openProfile; $('#profClose').onclick = () => { $('#profile').hidden = true; S.click(); };
  $('#setBtn').onclick = openSettings; $('#setClose').onclick = closeSettings;
  $('#nameOk').onclick = confirmName;
  $('#nameIn').addEventListener('keydown', e => { if (e.key === 'Enter') confirmName(); });
  for (const [id, k] of [['#optSfx', 'sfx'], ['#optMusic', 'music'], ['#optHaptic', 'haptic'], ['#optHQ', 'hq']]) $(id).onchange = e => { save.opt[k] = e.target.checked; Object.assign(SND.cfg, save.opt); persist(); if (k === 'music') SND.setMusic(true); if (k === 'hq') resize(); };
  $('#tray').addEventListener('pointerdown', trayDown); addEventListener('pointermove', trayMove); addEventListener('pointerup', trayUp); addEventListener('pointercancel', trayUp);
  cv.addEventListener('pointerdown', cvDown); cv.addEventListener('pointermove', cvMove); addEventListener('pointerup', cvUp); addEventListener('pointercancel', cvUp);
  document.addEventListener('visibilitychange', () => { if (document.hidden) { persist(); SND.suspend(true); } else { SND.suspend(false); lastReal = Date.now(); } });
  addEventListener('pagehide', persist);
}
function confirmName() {
  const n = $('#nameIn').value.trim().slice(0, 14); if (!n) { $('#nameIn').focus(); return; }
  save.name = n; save.hatched = true; save.born = Date.now(); save.lv = 1; save.xp = 0; save.st = { food: 75, fun: 75, energy: 90, hyg: 85 }; persist();
  $('#nameDlg').hidden = true; S.happy(); enterHome(); toast(`¡Bienvenido, ${n}!`);
}
function openSettings() {
  $('#optSfx').checked = save.opt.sfx; $('#optMusic').checked = save.opt.music; $('#optHaptic').checked = save.opt.haptic; $('#optHQ').checked = save.opt.hq; $('#renameIn').value = save.name;
  $('#settings').hidden = false; S.click();
}
function closeSettings() { const n = $('#renameIn').value.trim().slice(0, 14); if (n) save.name = n; persist(); $('#settings').hidden = true; updHud(true); }
function leaveShop() { mode = 'home'; house.setRoom(room); applyLook().then(() => { for (const s of ['#hud', '#nav']) $(s).hidden = false; buildTray(); updHud(true); }); }

/* ---------- necesidades, nivel y marcador ---------- */
const NEEDS = ['food', 'fun', 'energy', 'hyg'];
function addStat(k, v) { save.st[k] = clamp(save.st[k] + v, 0, 100); }
function gainXp(n) {
  if (save.lv >= MAXLV) return; save.xp += n;
  while (save.lv < MAXLV && save.xp >= xpNeed(save.lv)) {
    save.xp -= xpNeed(save.lv); const old = stageOf(save.lv); save.lv++;
    const reward = 40 + save.lv * 8; save.coins += reward; S.levelup(); buzz('HEAVY');
    PA.burst(pet.x, 1, pet.z, 50, new THREE.Color().setHSL(Math.random(), .9, .65), 3, .18, 1.1, 3);
    toast(stageOf(save.lv) > old ? `¡${save.name} ha crecido! · Nivel ${save.lv}` : `¡Nivel ${save.lv}! +${reward} monedas`);
    if (stageOf(save.lv) > old) { pet.grow = 1; hop(6); }
  }
  updHud(); persist();
}
function updHud(force) {
  $('#hCoins').textContent = save.coins.toLocaleString('es');
  $('#hName').textContent = save.name || 'Gambi';
  $('#hLv').textContent = `Nv ${save.lv} · ${STAGE[stageOf(save.lv)].name}`;
  $('#hXp').style.width = (save.lv >= MAXLV ? 100 : save.xp / xpNeed(save.lv) * 100) + '%';
  $('#giftDot').hidden = save.daily.last === new Date().toISOString().slice(0, 10);
  $('#achDot').hidden = !ACH.some(a => !save.ach[a.id] && a.v(save) >= a.n);
  $('#sickTag').hidden = !save.sick;
  for (const k of NEEDS) { const el = $(`.stat[data-k=${k}]`); el.querySelector('i').style.width = Math.max(4, save.st[k]) + '%'; el.classList.toggle('low', save.st[k] < 25); }
}
function gift() {
  const today = new Date().toISOString().slice(0, 10);
  if (save.daily.last === today) { toast('Vuelve mañana a por otro regalo'); return; }
  const y = new Date(Date.now() - 864e5).toISOString().slice(0, 10);
  save.daily.streak = save.daily.last === y ? save.daily.streak + 1 : 1; save.daily.last = today;
  const amt = Math.round(rnd(60, 120) + Math.min(7, save.daily.streak) * 25);
  save.coins += amt; persist(); S.buy(); buzz('MEDIUM'); PA.burst(pet.x, 1, pet.z + .3, 30, new THREE.Color(0xffd84a), 2.6, .16, .9, 3);
  toast(`+${amt} monedas · racha de ${save.daily.streak} día${save.daily.streak > 1 ? 's' : ''}`); updHud();
}

/* ---------- bandeja de cada habitación ---------- */
const GAME_ART = {};
function buildTray() {
  const t = $('#tray'); t.innerHTML = ''; t.classList.remove('center'); t.hidden = true;
  if (mode !== 'home') return;
  if (room === 'salon') {
    const acts = [['dance', 'music', 'Bailar'], ['flip', 'star', 'Voltereta'], ['tickle', 'fun', 'Cosquillas'], ['talk', 'talk', 'Hablar'], ['bubbles', 'bubble', 'Pompas']];
    t.innerHTML = acts.map(([id, ic, nm]) => `<button class="glass act" data-act="${id}">${ICON[ic] || ''}${nm}${id === 'flip' && save.lv < 3 ? '<small>Nv 3</small>' : ''}</button>`).join('');
    t.querySelectorAll('[data-act]').forEach(b => b.onclick = () => doAct(b.dataset.act));
  } else if (room === 'cocina') {
    const list = FOODS.filter(f => f.free || (save.inv[f.id] || 0) > 0);
    t.innerHTML = list.map(f => `<div class="glass food" data-id="${f.id}"><span class="th ph" data-th="food:${f.id}"></span><b>${f.name}</b>${f.free ? '' : `<span class="n">×${save.inv[f.id]}</span>`}</div>`).join('') + `<div class="glass food more" data-more="1"><span data-i="plus"></span>Más comida</div>`;
    t.querySelector('[data-more] span').innerHTML = ICON.plus;
    for (const f of list) shop.thumb('food', f).then(url => { const el = url && t.querySelector(`[data-th="food:${f.id}"]`); if (el) { el.style.backgroundImage = `url(${url})`; el.classList.remove('ph'); } });
  } else if (room === 'bano') {
    t.classList.add('center'); t.innerHTML = `<button class="glass act big hot" id="showerBtn">${ICON.shower}Ducha</button>`;
    $('#showerBtn').onclick = shower;
  } else if (room === 'dormitorio') {
    t.classList.add('center'); t.innerHTML = `<button class="glass act big hot" id="sleepBtn">${save.sleeping ? ICON.sun + 'Despertar' : ICON.moon + 'Dormir'}</button>`;
    $('#sleepBtn').onclick = () => save.sleeping ? wake() : sleep();
  } else if (room === 'juegos') {
    t.innerHTML = MINIGAMES.map(g => `<div class="glass game" data-game="${g.id}"><span class="th" data-th="game:${g.id}"></span><b>${g.name}</b><small>${g.desc}</small>${save.best[g.id] ? `<span class="rec">Récord ${save.best[g.id]}</span>` : ''}</div>`).join('');
    for (const g of MINIGAMES) shop.thumb('game', g).then(url => { const el = url && t.querySelector(`[data-th="game:${g.id}"]`); if (el) el.style.backgroundImage = `url(${url})`; });
    t.querySelectorAll('[data-game]').forEach(el => el.onclick = () => startMini(el.dataset.game));
  }
  t.hidden = !t.innerHTML;
}

/* ---------- comer ---------- */
let drag = null;
function trayDown(e) {
  const el = e.target.closest('.food'); if (!el) return; SND.ac();
  if (el.dataset.more) { S.click(); shop.open('food'); return; }
  drag = { id: el.dataset.id, x0: e.clientX, y0: e.clientY, active: false, el, pid: e.pointerId };
}
function trayMove(e) {
  if (!drag || e.pointerId !== drag.pid) return;
  const dx = e.clientX - drag.x0, dy = e.clientY - drag.y0;
  if (!drag.active && dy < -16 && Math.abs(dy) > Math.abs(dx)) {
    drag.active = true; const d = $('#dragItem'); d.hidden = false; d.style.backgroundImage = drag.el.querySelector('.th').style.backgroundImage; buzz();
  }
  if (drag.active) { const d = $('#dragItem'); d.style.left = e.clientX + 'px'; d.style.top = e.clientY + 'px'; }
}
function trayUp(e) {
  if (!drag || e.pointerId !== drag.pid) return;
  const d = drag; drag = null; $('#dragItem').hidden = true;
  if (d.active) { const p = petScreen(); if (Math.hypot(e.clientX - p.x, e.clientY - p.y) < 150 * (.6 + .4 * pet.sc)) feed(d.id); }
  else if (Math.hypot(e.clientX - d.x0, e.clientY - d.y0) < 10) feed(d.id);
}
function feed(id) {
  if (pet.act || save.sleeping || mode !== 'home') return;
  const f = FOODS.find(x => x.id === id); if (!f) return;
  if (!f.free && !(save.inv[id] > 0)) { toast('No te queda'); return; }
  if (f.med && !save.sick) { toast(`${save.name} no está mala`); S.no(); return; }
  if (!f.med && save.st.food >= 96 && !(f.fun || f.energy || f.hyg)) { pet.act = { type: 'no', t: 0 }; S.no(); toast(`${save.name} está llena`); buzz('MEDIUM'); return; }
  if (!f.free) save.inv[id]--;
  const mesh = foodMesh(id); mesh.scale.setScalar(.75 + pet.sc * .5); scene.add(mesh);
  pet.act = { type: 'eat', t: 0, id, f, mesh, bites: 0 };
  persist(); buildTray();
}
function finishEat(a) {
  const f = a.f, gain = { food: f.food || 0, fun: f.fun || 0, energy: f.energy || 0, hyg: f.hyg || 0 };
  const lab = { food: 'Comida', fun: 'Diversión', energy: 'Energía', hyg: 'Limpieza' };
  let i = 0; for (const k of NEEDS) if (gain[k]) { addStat(k, gain[k]); FL.add(`+${gain[k]}`, pet.x + (i++ - 1) * .35, 1.05 * pet.sc + .5, pet.z + .3, { color: { food: '#ffc04a', fun: '#ff8ab8', energy: '#ffe94d', hyg: '#6fdcff' }[k], size: .36, life: 1.3 }); }
  if (f.med) { save.sick = false; save.sickT = 0; save.stats.cured++; say('¡Puaj! Pero ya me encuentro mejor'); }
  save.stats.fed++; scene.remove(a.mesh); hop(4); pet.hearts = 3; S.happy(); buzz('MEDIUM');
  gainXp(5 + Math.round((gain.food + gain.fun + gain.energy + gain.hyg) / 14)); persist(); updHud();
}

/* ---------- bañar ---------- */
function makeFoam() {
  const g = new THREE.Group(), m = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: .3 });
  for (let i = 0; i < 46; i++) { const s = new THREE.Mesh(new THREE.SphereGeometry(.05 + Math.random() * .05, 10, 8), m); s.position.set(rnd(-.17, .17), rnd(.1, .5), rnd(-.65, .6)); g.add(s); }
  g.visible = false; return g;
}
function foamSet(v) { pet.foam = v; const n = Math.round(v * foam.children.length); foam.children.forEach((c, i) => { c.visible = i < n; }); foam.visible = n > 0; }
function scrub(dt) {
  if (room !== 'bano' || mode !== 'home' || pet.act) return;
  foamSet(Math.min(1, pet.foam + dt * .4)); addStat('hyg', 10 * dt);
  pet.scrubSfx -= dt; if (pet.scrubSfx <= 0) { pet.scrubSfx = .16; S.scrub(); buzz('LIGHT'); }
  PA.emit(pet.x + rnd(-.5, .5), .35 + rnd(0, .6) * pet.sc, pet.z + rnd(-.3, .3), rnd(-.3, .3), rnd(.3, .9), 0, new THREE.Color(0xffffff), .15, .9, -.2, .6);
  pet.wiggle = .5;
}
function shower() {
  if (pet.act || mode !== 'home') return;
  pet.act = { type: 'shower', t: 0 }; S.splash();
}
function finishShower() {
  const clean = pet.foam > .3; addStat('hyg', clean ? 100 : 6); addStat('fun', clean ? 8 : 0); foamSet(0);
  if (clean) { save.stats.bathed++; gainXp(10); pet.hearts = 4; hop(4.5); S.happy(); FL.add('¡Limpio!', pet.x, 1.3, pet.z + .2, { color: '#8fe6ff', size: .6, font: '700 54px Fredoka, sans-serif' }); }
  else toast('Primero frótalo con espuma');
  persist(); updHud();
}

/* ---------- dormir ---------- */
function sleep() {
  if (save.sleeping || mode !== 'home') return;
  if (save.st.energy > 92) { toast(`${save.name} no tiene sueño`); S.no(); return; }
  save.sleeping = true; S.sleep(); buzz('LIGHT'); persist(); buildTray(); hint('Dulces sueños…', 2500);
}
function wake() {
  if (!save.sleeping) return; save.sleeping = false; S.happy(); persist();
  if (mode === 'home') buildTray();
  if (save.st.energy >= 98) { gainXp(6); FL.add('¡Descansada!', pet.x, 1.2, pet.z + .3, { color: '#ffe94d', size: .6, font: '700 54px Fredoka, sans-serif' }); }
}

/* ---------- interacción con el lienzo ---------- */
const ptr = { down: false, x: 0, y: 0, x0: 0, y0: 0, t0: 0, moved: 0, onPet: false };
function petScreen() { _v.set(pet.x, pet.y + .38 * pet.sc, pet.z).project(cam); return { x: (_v.x * .5 + .5) * innerWidth, y: (-_v.y * .5 + .5) * innerHeight }; }
const nearPet = (x, y, k = 1) => { const p = petScreen(); return Math.hypot(x - p.x, y - p.y) < 130 * (.6 + .4 * pet.sc) * k; };
function cvDown(e) {
  SND.ac();
  if (mode === 'egg') { tapEgg(); return; }
  if (mode === 'mini') { mini && mini.pointer && mini.pointer('down', e.clientX, e.clientY); ptr.down = true; return; }
  if (mode !== 'home') return;
  Object.assign(ptr, { down: true, x: e.clientX, y: e.clientY, x0: e.clientX, y0: e.clientY, t0: performance.now(), moved: 0, onPet: nearPet(e.clientX, e.clientY, 1.15) });
}
function cvMove(e) {
  if (mode === 'mini') { mini && mini.pointer && mini.pointer('move', e.clientX, e.clientY); return; }
  if (!ptr.down || mode !== 'home') return;
  const d = Math.hypot(e.clientX - ptr.x, e.clientY - ptr.y); ptr.moved += d; ptr.x = e.clientX; ptr.y = e.clientY;
  if (nearPet(e.clientX, e.clientY, 1.15) && ptr.moved > 12 && d > 0) {
    if (room === 'bano') scrub(Math.min(.05, d / 900 + .012));
    else if (!save.sleeping) caress(d);
  }
}
function cvUp(e) {
  if (mode === 'mini') { mini && mini.pointer && mini.pointer('up', e.clientX, e.clientY); ptr.down = false; return; }
  if (!ptr.down) return; ptr.down = false;
  if (mode !== 'home' || ptr.moved > 14 || performance.now() - ptr.t0 > 500) return;
  for (const h of (house.hot[room] || [])) {
    _v.setFromMatrixPosition(h.obj.matrixWorld); _v.y += .4; _v.project(cam);
    if (Math.hypot(e.clientX - (_v.x * .5 + .5) * innerWidth, e.clientY - (-_v.y * .5 + .5) * innerHeight) < h.r) { hotspot(h.id); return; }
  }
  if (popBubble(e.clientX, e.clientY)) return;
  if (nearPet(e.clientX, e.clientY) && !pet.act) poke();
}
function hotspot(id) {
  if (id === 'ball') kickBall();
  else if (id === 'lamp') save.sleeping ? wake() : sleep();
  else if (id === 'arcade') startMini(MINIGAMES[Math.floor(Math.random() * MINIGAMES.length)].id);
  else if (id === 'fridge') toast('Arrastra la comida hacia ' + save.name);
}
function poke() {
  if (save.sleeping) { wake(); return; }
  hop(4.2); pet.hearts = Math.max(pet.hearts, 1); pet.wiggle = .8; S.happy(); buzz('LIGHT');
  if (pet.cool <= 0) { addStat('fun', 1.5); pet.cool = .8; gainXp(1); }
}
function caress(d) {
  pet.bond += d; pet.wiggle = .6;
  if (pet.bond > 70) { pet.bond = 0; addStat('fun', 2.2); pet.hearts = 1; S.tap(); save.stats.pets++; if (save.stats.pets % 6 === 0) gainXp(1); }
}
const ballS = { t: 0, x0: 0 };
function kickBall() {
  if (ballS.t > 0) return; ballS.t = 1; ballS.x0 = house.ball.position.x; S.pop(); buzz('LIGHT'); hop(4); addStat('fun', 2); gainXp(1);
}


/* ---------- acciones del salón ---------- */
const TALK = {
  hungry: ['Tengo un hambre que me comería un krill entero', '¿Hay algo de comer?', 'Mi barriga hace ruidos raros'],
  bored: ['Me aburroooo', '¿Jugamos a algo?', 'Vamos a la sala de juegos, porfa'],
  tired: ['Estoy reventada…', 'Necesito una siesta', 'Se me cierran los ojitos'],
  dirty: ['Huelo un poco a marisco…', 'Necesito un baño', 'Tengo arena hasta en las antenas'],
  sick: ['No me encuentro bien…', 'Creo que estoy malita', 'Necesito medicina'],
  happy: ['¡Te quiero mucho!', '¡Qué buen día hace!', '¿Sabías que las gambas oímos con las antenas? Bueno, igual no.', '¡Soy la gamba más feliz del mar!', 'Hoy me siento guapísima', '¿Me haces cosquillas?', '¡Mira qué antenas tan largas tengo!', 'Ojalá fuera domingo todos los días', 'Si fuera un langostino sería más elegante, pero me gusto así'],
};
function phrase() {
  const st = save.st, pick = a => a[Math.floor(Math.random() * a.length)];
  if (save.sick) return pick(TALK.sick);
  const low = [['food', 'hungry'], ['energy', 'tired'], ['hyg', 'dirty'], ['fun', 'bored']].filter(([k]) => st[k] < 30).sort((a, b) => st[a[0]] - st[b[0]]);
  return low.length && Math.random() < .8 ? pick(TALK[low[0][1]]) : pick(TALK.happy);
}
let sayT = 0, chatT = 30;
function say(txt, ms = 2800) {
  const b = $('#talk'); b.textContent = txt; b.hidden = false; b.classList.remove('pop'); void b.offsetWidth; b.classList.add('pop'); sayT = ms / 1000;
  for (let i = 0; i < Math.min(6, 2 + txt.length / 8); i++) SND.tone(500 + Math.random() * 500, .07, 'triangle', .07, Math.random() < .5 ? 200 : -150, i * .09);
}
function doAct(id) {
  if (mode !== 'home' || pet.act) return;
  if (save.sleeping) { wake(); return; }
  if (id === 'talk') { say(phrase()); save.stats.talks++; hop(2.5); addStat('fun', 1); gainXp(1); persist(); return; }
  if (id === 'bubbles') { spawnBubbles(); return; }
  if (id === 'flip' && save.lv < 3) { toast('La voltereta se aprende en el nivel 3'); S.no(); return; }
  if (save.sick) { say('Estoy malita… mejor luego'); S.sad(); return; }
  if (save.st.energy < 12) { say('Estoy demasiado cansada'); S.sad(); return; }
  pet.act = { type: id, t: 0 }; S.click(); buzz();
  if (id === 'dance') { const n = [0, 4, 7, 4, 0, 4, 7, 12, 9, 7, 5, 4, 2, 4, 7, 12]; n.forEach((v, i) => { SND.tone(440 * Math.pow(2, v / 12), .2, 'triangle', .1, 0, i * .25); if (i % 2 === 0) SND.tone(110 * Math.pow(2, [0, 0, 5, 7][(i / 4) | 0] / 12), .2, 'sine', .14, 0, i * .25); }); }
}
function finishAct(a) {
  const R2 = { dance: [7, 4, 3], flip: [5, 3, 3], tickle: [6, 2, 2] }[a.type];
  addStat('fun', R2[0]); addStat('energy', -R2[1]); gainXp(R2[2]); pet.hearts = 3;
  if (a.type !== 'tickle') save.stats.tricks++;
  if (Math.random() < .35) say(a.type === 'tickle' ? '¡Jijiji, para, para!' : a.type === 'dance' ? '¡Soy una estrella!' : '¡Tachán!');
  persist(); updHud();
}
// pompas de jabón que flotan por el salón; se revientan tocándolas
const bubbles = [];
function spawnBubbles() {
  if (bubbles.length > 4) return;
  S.pop(); buzz();
  for (let i = 0; i < 7; i++) {
    const r = rnd(.12, .22), m = new THREE.Mesh(new THREE.SphereGeometry(r, 18, 14), new THREE.MeshStandardMaterial({ color: new THREE.Color().setHSL(rnd(.45, .95), .8, .75), transparent: true, opacity: .45, roughness: .05, emissive: 0x335577, emissiveIntensity: .2 }));
    m.position.set(rnd(-1.4, 1.4), rnd(.3, .8), rnd(-.4, 1)); scene.add(m);
    bubbles.push({ m, r, vy: rnd(.15, .35), ph: rnd(0, 6), life: rnd(9, 14) });
  }
  hint('Toca las pompas para explotarlas', 2500);
}
function updateBubbles(dt) {
  for (const b of bubbles) {
    b.life -= dt; b.ph += dt; b.m.position.y += b.vy * dt; b.m.position.x += Math.sin(b.ph * 1.3) * .2 * dt;
    if (room !== 'salon' || mode !== 'home') b.life = 0;
    // la gamba persigue la pompa más baja
    if (b.life <= 0 || b.m.position.y > 3.5) { scene.remove(b.m); b.dead = true; }
  }
  for (let i = bubbles.length - 1; i >= 0; i--) if (bubbles[i].dead) bubbles.splice(i, 1);
  if (bubbles.length && !pet.act && !save.sleeping) { const low = bubbles.reduce((a, b) => b.m.position.y < a.m.position.y ? b : a); pet.tx = clamp(low.m.position.x, -1.2, 1.2); pet.tz = clamp(low.m.position.z, -.2, 1); if (pet.wait > .5) pet.wait = .5; }
}
function popBubble(x, y) {
  for (const b of bubbles) {
    _v.copy(b.m.position).project(cam); const sx = (_v.x * .5 + .5) * innerWidth, sy = (-_v.y * .5 + .5) * innerHeight;
    if (Math.hypot(x - sx, y - sy) < 60) {
      b.dead = true; b.life = 0; scene.remove(b.m); S.pop(); buzz('LIGHT'); PA.burst(b.m.position.x, b.m.position.y, b.m.position.z, 10, new THREE.Color(0xd6f4ff), 1.6, .1, .5, 1);
      addStat('fun', 2); hop(3.5); if (Math.random() < .25) { save.coins += 2; FL.add('+2', b.m.position.x, b.m.position.y, b.m.position.z + .2, { color: '#ffe14d', size: .4 }); } gainXp(1);
      return true;
    }
  }
  return false;
}

/* ---------- perfil y logros ---------- */
function openProfile() {
  if (mode !== 'home') return; S.click();
  const days = save.born ? Math.max(0, Math.floor((Date.now() - save.born) / 864e5)) : 0;
  $('#pName').textContent = save.name; $('#pInfo').textContent = `Nivel ${save.lv} · ${STAGE[stageOf(save.lv)].name} · ${days === 0 ? 'nació hoy' : days === 1 ? '1 día' : days + ' días'}`;
  const st = save.stats;
  $('#pStats').innerHTML = [['Comidas', st.fed], ['Baños', st.bathed], ['Caricias', st.pets], ['Partidas', st.played], ['Trucos', st.tricks], ['Charlas', st.talks]].map(([k, v]) => `<div><b>${v}</b><small>${k}</small></div>`).join('');
  $('#pBest').innerHTML = MINIGAMES.map(g => `<div><small>${g.name}</small><b>${save.best[g.id] || 0}</b></div>`).join('');
  renderAch(); $('#profile').hidden = false;
}
function renderAch() {
  const box = $('#pAch');
  box.innerHTML = ACH.map(a => { const v = Math.min(a.n, a.v(save)), done = v >= a.n, got = save.ach[a.id];
    return `<div class="ach ${got ? 'got' : done ? 'ready' : ''}"><div class="at"><b>${a.name}</b><small>${a.desc}</small><span class="ab"><i style="width:${v / a.n * 100}%"></i></span></div>${got ? `<span class="ok">${ICON.check}</span>` : done ? `<button class="btn buy" data-a="${a.id}"><span class="coin"></span>${a.r}</button>` : `<span class="rw"><span class="coin"></span>${a.r}</span>`}</div>`; }).join('');
  box.querySelectorAll('[data-a]').forEach(b => b.onclick = () => { const a = ACH.find(x => x.id === b.dataset.a); save.ach[a.id] = true; save.coins += a.r; persist(); S.levelup(); buzz('MEDIUM'); toast(`¡Logro «${a.name}»! +${a.r} monedas`); renderAch(); updHud(); });
}

/* ---------- mascota: movimiento y animación ---------- */
function updatePet(dt) {
  const sp = mode === 'shop' ? { fixed: [0, 0, .5] } : (house.SPOTS[room] || house.SPOTS.salon), a = pet.act;
  pet.cool -= dt; pet.wiggle = Math.max(0, pet.wiggle - dt * 2);
  const wantSc = mode === 'shop' ? 1 : STAGE[stageOf(save.lv)].scale;
  pet.sc = lerp(pet.sc, wantSc, Math.min(1, dt * (pet.grow ? 2 : 4))); if (pet.grow && Math.abs(pet.sc - wantSc) < .01) pet.grow = 0;
  let tx = pet.tx, tz = pet.tz, ty = 0, face = null, moving = false;
  if (save.sleeping && sp.sleep) { [tx, ty, tz] = sp.sleep; face = Math.PI / 2; }
  else if (save.sleeping) { tx = 0; tz = .5; face = FACE; }
  else if (sp.fixed) { [tx, ty, tz] = sp.fixed; face = mode === 'shop' ? FACE + Math.sin(T * .7) * .8 : FACE; }
  else {
    ty = 0; pet.wait -= dt;
    if (pet.wait <= 0 && !a) {
      if (Math.hypot(pet.tx - pet.x, pet.tz - pet.z) < .12) { pet.tx = rnd(sp.x[0], sp.x[1]); pet.tz = rnd(sp.z[0], sp.z[1]); pet.wait = rnd(0.2, .6); if (Math.random() < .3) { hop(3.6); } }
      tx = pet.tx; tz = pet.tz;
    } else { tx = pet.tx; tz = pet.tz; }
  }
  const dx = tx - pet.x, dz = tz - pet.z, dist = Math.hypot(dx, dz);
  const walk = !a && !save.sleeping && dist > .08 && (sp.fixed ? true : pet.wait <= 0);
  if (walk) {
    const spd = sp.fixed ? 1.6 : .55 + pet.sc * .2;
    const step = Math.min(dist, spd * dt); pet.x += dx / dist * step; pet.z += dz / dist * step; moving = true; pet.speed = spd;
    if (!sp.fixed) { const want = Math.atan2(-dx, -dz); pet.yaw += angDiff(want, pet.yaw) * Math.min(1, dt * 7); }
    else pet.yaw += angDiff(Math.atan2(-dx, -dz), pet.yaw) * Math.min(1, dt * 7);
    if (dist < .09 && !sp.fixed) pet.wait = rnd(1.4, 3.8);
  } else {
    if (sp.fixed || save.sleeping) { pet.x += dx * Math.min(1, dt * 4); pet.z += dz * Math.min(1, dt * 4); }
    const tgt = face !== null ? face : pet.yaw; pet.yaw += angDiff(tgt, pet.yaw) * Math.min(1, dt * (save.sleeping ? 3 : 5)); pet.speed = 0;
    if (!sp.fixed && !save.sleeping && !a && pet.wait > 0) pet.yaw += angDiff(FACE, pet.yaw) * Math.min(1, dt * .8);
  }
  // saltitos
  pet.hopV -= 14 * dt; pet.hopY = Math.max(0, pet.hopY + pet.hopV * dt); if (pet.hopY === 0 && pet.hopV < 0) pet.hopV = 0;
  pet.y = lerp(pet.y, ty, Math.min(1, dt * 6));
  // acciones
  let pose = moving ? 'run' : 'idle', squash = 1, headBob = 0, turn = 0;
  if (a && a.type === 'dance') pet.speed = 0;
  if (a) {
    a.t += dt;
    if (a.type === 'eat') {
      const h = heading(), mouth = _v.set(pet.x, 0, pet.z).addScaledVector(h, .62 * pet.sc + .08); mouth.y = pet.y + .3 + pet.sc * .1;
      a.mesh.position.set(mouth.x, mouth.y + Math.sin(a.t * 12) * .012 - a.bites * .05, mouth.z); a.mesh.rotation.y += dt * .8;
      headBob = Math.max(0, Math.sin(a.t * 13)) * .14;
      const bt = [.45, .95, 1.45]; if (a.bites < 3 && a.t > bt[a.bites]) { a.bites++; a.mesh.scale.multiplyScalar(.6); SND.noiseHit(.07, .16, 500); SND.tone(190 + a.bites * 40, .08, 'square', .05, -60); PN.burst(a.mesh.position.x, a.mesh.position.y, a.mesh.position.z, 6, new THREE.Color(0xffe0a0), .9, .08, .5, 5); }
      if (a.t > 1.9) { finishEat(a); pet.act = null; }
    } else if (a.type === 'dance') {
      // 1) pasitos de lado balanceándose, 2) giro sobre sí misma, 3) meneo de cabeza, 4) pose final
      const t = a.t; a.ox = 0; a.roll = 0; a.pitch = 0; a.legs = true;
      if (t < 1.3) { a.ox = Math.sin(t * Math.PI * 2.4) * .32; a.roll = Math.sin(t * Math.PI * 4.8) * .22; squash = 1 + Math.abs(Math.sin(t * Math.PI * 4.8)) * -.08; turn = Math.sin(t * Math.PI * 2.4) * .35; }
      else if (t < 2.3) { pet.yaw += dt * Math.PI * 2; squash = .94; a.roll = .15; }
      else if (t < 3.4) { a.pitch = Math.sin(t * 16) * .22; a.roll = Math.sin(t * 8) * .12; turn = Math.sin(t * 4) * .5; }
      else { const k = Math.min(1, (t - 3.4) / .25); a.pitch = -.55 * k; a.legs = false; squash = 1 + .06 * k; if (!a.sparkle) { a.sparkle = true; PA.burst(pet.x, .9 * pet.sc, pet.z, 26, new THREE.Color(0xffe27a), 2.2, .14, .8, 2); } }
      if (Math.floor(t * 3) !== Math.floor((t - dt) * 3)) FL.add('♪', pet.x + rnd(-.5, .5), pet.y + .9 * pet.sc, pet.z + .3, { color: ['#ffe14d', '#7fd6ff', '#ff8ab8'][Math.floor(rnd(0, 3))], size: .4, life: 1.2, drift: rnd(-.25, .25) });
      if (t > 4) { finishAct(a); pet.act = null; }
    } else if (a.type === 'flip') {
      const t = a.t; if (t < .05) hop(6.5);
      a.rx = t > .05 && t < .85 ? -((t - .05) / .8) * Math.PI * 2 : 0;
      if (t > .85 && !a.landed) { a.landed = true; PA.burst(pet.x, .1, pet.z, 18, new THREE.Color(0xfff2a0), 2, .14, .6, 3); S.happy(); }
      if (t > 1.2) { finishAct(a); pet.act = null; }
    } else if (a.type === 'tickle') {
      const t = a.t; pet.wiggle = 1; turn = Math.sin(t * 25) * .15;
      if (Math.floor(t * 5) !== Math.floor((t - dt) * 5)) SND.tone(700 + Math.random() * 400, .08, 'triangle', .08, 300);
      if (t > 1.8) { finishAct(a); pet.act = null; }
    } else if (a.type === 'no') { turn = Math.sin(a.t * 18) * .4 * Math.max(0, 1 - a.t / 0.7); if (a.t > .75) pet.act = null; }
    else if (a.type === 'shower') {
      const t = a.t; headBob = Math.sin(t * 9) * .05;
      for (let i = 0; i < 3; i++) PN.emit(pet.x + rnd(-.55, .55), 2.5, pet.z + rnd(-.35, .35), 0, -rnd(6, 8), 0, new THREE.Color(0x8fe1ff), .07, .45, 0);
      PA.emit(pet.x + rnd(-.5, .5), .5 + rnd(0, .4), pet.z + rnd(-.3, .3), rnd(-1, 1), rnd(.5, 2), rnd(-.5, .5), new THREE.Color(0xd6f4ff), .08, .5, 4);
      if (Math.random() < .3) foamSet(Math.max(0, pet.foam - dt * 1.2 * 3));
      if (t > 2.2) { finishShower(); pet.act = null; }
    }
  }
  // hearts / floaters
  if (pet.hearts > 0) { pet.hearts -= dt * 2.4; if (Math.random() < dt * 9) FL.add('♥', pet.x + rnd(-.3, .3), pet.y + .7 * pet.sc + .3, pet.z + .3, { color: '#ff6f9a', size: .34, life: 1.1, drift: rnd(-.15, .15) }); }
  // aplicar
  const R_ = player.root;
  const dnc = a && a.type === 'dance';
  R_.position.set(pet.x + (dnc && a.ox || 0), pet.y + pet.hopY, pet.z); R_.rotation.y = pet.yaw + turn; R_.scale.setScalar(Math.max(.01, pet.sc));
  pet.ph += dt * (moving ? 5 + pet.speed * 5 : 2);
  const md = mood(), sleeping = save.sleeping;
  if (dnc && a.legs) pet.ph += dt * 14;
  player.pose(pet.ph, moving || (dnc && a.legs) ? 'run' : 'idle', T, dt, 4);
  player.tilt.position.y = moving ? Math.abs(Math.sin(pet.ph)) * .03 : 0;
  const breathe = sleeping ? Math.sin(T * 1.6) * .03 : Math.sin(T * 2.2) * .012;
  const droop = md === 0 && !sleeping ? .1 : 0;
  player.tilt.scale.set(1 + pet.wiggle * .04 * Math.sin(T * 30), (1 + breathe) * (1 - droop * .4) - pet.wiggle * .03, 1);
  const sickDroop = save.sick && !sleeping ? .12 : 0;
  player.tilt.rotation.set(headBob - droop * .5 - sickDroop + (a && a.rx || 0) + (dnc && a.pitch || 0), 0, pet.wiggle * .1 * Math.sin(T * 24) + (dnc && a.roll || 0));
  if (squash !== 1) player.tilt.scale.y *= squash;
  // dormida en la cama: boca arriba, con las patitas moviéndose despacio
  const onBack = sleeping && room === 'dormitorio' && mode === 'home' && player.cur;
  pet.roll = lerp(pet.roll || 0, onBack ? 1 : 0, Math.min(1, dt * 4));
  if (pet.roll > .01) {
    player.tilt.rotation.z = Math.PI * pet.roll; player.tilt.position.y = (player.cur.h || .5) * pet.roll * .92;
    if (onBack) player.pose(T * 1.6, 'slide', T, dt, 1);
  }
  if (player.hat) player.hat.visible = pet.roll < .5;
  const hb = player.cur && player.cur.bones && player.cur.bones.Head; if (hb && (droop || headBob)) hb.rotation.x += droop * 1.2 + headBob;
  // sueño y avisos
  if (sleeping) { pet.sleepZ -= dt; if (pet.sleepZ <= 0) { pet.sleepZ = 1.2; FL.add('Z', pet.x - .2, pet.y + .95, pet.z, { color: '#cfe3ff', size: .4, life: 2, vy: .4, drift: .12 }); if (Math.random() < .5) PA.emit(pet.x - .55 * pet.sc, pet.y + .35, pet.z, 0, .25, 0, new THREE.Color(0xbfe9ff), .22, 1.6, -.05, 1.2); } }
  if (save.sick && !sleeping) { pet.sickT = (pet.sickT || 0) - dt; if (pet.sickT <= 0) { pet.sickT = 6; FL.add('🤒', pet.x, pet.y + 1.05 * pet.sc + .3, pet.z + .2, { size: .5, life: 2, font: '70px "Apple Color Emoji","Noto Color Emoji",sans-serif' }); } }
  warnT -= dt;
  if (warnT <= 0 && !sleeping && !a) { warnT = 22; const k = NEEDS.find(n => save.st[n] < 25); if (k) { FL.add({ food: '🍤', fun: '🎈', energy: '💤', hyg: '🫧' }[k], pet.x, pet.y + 1.05 * pet.sc + .4, pet.z + .2, { size: .55, life: 2.2, font: '70px "Apple Color Emoji","Noto Color Emoji",sans-serif' }); S.sad(); } }
}
function hop(v) { if (pet.hopY < .02 && pet.hopV <= 0) pet.hopV = v; }
const angDiff = (a, b) => { let d = (a - b) % (Math.PI * 2); if (d > Math.PI) d -= Math.PI * 2; if (d < -Math.PI) d += Math.PI * 2; return d; };

/* ---------- minijuegos ---------- */
async function startMini(id) {
  if (mode !== 'home' || pet.act) return;
  const { createMini } = await import('./juegos.js');
  if (save.sleeping) wake();
  mode = 'mini'; S.click();
  for (const s of ['#hud', '#nav', '#tray', '#hint', '#talk']) $(s).hidden = true; sayT = 0;
  for (const b of bubbles) b.life = 0;
  house.setRoom(null); foamSet(0);
  mini = createMini({ THREE, M, scene, cam, cv, player, pet, PN, PA, FL, S, SND, buzz, save, foodMesh, FOODS, setHouse: v => { house.shared.visible = v; house.decoGroup.visible = v; }, hint, toast, camTo, end: endMini, rnd, clamp, VIEW, stage: () => STAGE[stageOf(save.lv)].scale, onPetReady: null });
  mini.start(id);
}
function endMini(r) {
  // r = { id, score, coins, xp, fun }
  const isRec = r.score > (save.best[r.id] || 0); if (isRec) save.best[r.id] = r.score;
  save.coins += r.coins; addStat('fun', r.fun); addStat('energy', -r.fun * .25); save.stats.played++;
  $('#meTitle').textContent = r.title || '¡Fin!'; $('#meRec').hidden = !isRec; $('#meScore').textContent = r.score; $('#meCoins').textContent = '+' + r.coins; $('#meXp').textContent = '+' + r.xp; $('#meBest').textContent = save.best[r.id];
  $('#miniHud').hidden = true; $('#miniEnd').hidden = false; S.levelup();
  $('#meAgain').onclick = () => { $('#miniEnd').hidden = true; mini.start(r.id); };
  $('#meExit').onclick = exitMini;
  gainXp(r.xp); persist();
}
function exitMini() {
  $('#miniEnd').hidden = true; $('#miniHud').hidden = true; if (mini) mini.dispose(); mini = null;
  mode = 'home'; for (const s of ['#hud', '#nav']) $(s).hidden = false;
  player.root.visible = true; pet.x = 0; pet.z = .5; goRoom('juegos', true); updHud(true);
}
$('#mQuit').onclick = () => { if (mini) { mini.abort(); exitMini(); } };

/* ---------- cámara, luces y bucle ---------- */
const camPos = new THREE.Vector3(0, 1.3, 3.8), camLook = new THREE.Vector3(0, .5, 0);
function camTo(pos, look, k = 6) { camGoal.pos.copy(pos); camGoal.look.copy(look); camGoal.k = k; }
const camGoal = { pos: new THREE.Vector3(0, 1.3, 3.8), look: new THREE.Vector3(0, .5, 0), k: 4 };
function frame(dt) {
  T += dt; M.SKIN.t.value = T;
  const real = (Date.now() - lastReal) / 1000; lastReal = Date.now();
  if (mode === 'home' || mode === 'shop') {
    if (save.hatched) {
      tickStats(Math.min(real, OFFLINE_CAP));
      if (save.sleeping && save.st.energy >= 99.5) { wake(); toast(`${save.name} se ha despertado descansada`); }
    }
    saveT += dt; if (saveT > 6) { saveT = 0; persist(); }
    hudT += dt; if (hudT > .3) { hudT = 0; updHud(); }
    updatePet(dt);
    updateBubbles(dt);
    house.update(dt, T);
    if (sayT > 0) { sayT -= dt; const p = petScreen(), b = $('#talk'), hw = b.offsetWidth / 2 + 10; b.style.left = clamp(p.x, hw, innerWidth - hw) + 'px'; b.style.top = Math.max(b.offsetHeight + 150, p.y - 95 * (.6 + .4 * pet.sc)) + 'px'; if (sayT <= 0) b.hidden = true; }
    if (mode === 'home' && !save.sleeping && !pet.act) { chatT -= dt; if (chatT <= 0) { chatT = rnd(35, 70); say(phrase()); } }
    if (room === 'salon' && ballS.t > 0) { ballS.t -= dt * 1.4; const p = 1 - Math.max(0, ballS.t); house.ball.position.y = .3 + Math.abs(Math.sin(p * Math.PI * 3)) * .9 * (1 - p); house.ball.position.x = ballS.x0 + Math.sin(p * Math.PI) * .6; house.ball.rotation.z -= dt * 6; if (ballS.t <= 0) house.ball.position.x = ballS.x0; }
  } else if (mode === 'egg') {
    eggM.wob = Math.max(0, (eggM.wob || 0) - dt * 1.6);
    eggM.mesh.rotation.z = Math.sin(T * 40) * eggM.wob * .25; eggM.mesh.position.y = .8 + Math.abs(Math.sin(T * 2)) * .03 + eggM.wob * .05;
  }
  if (mode === 'mini' && mini) mini.update(dt);
  // la casa se oscurece al dormir
  const nt = save.sleeping && mode === 'home' ? 1 : 0; nightK = lerp(nightK, nt, Math.min(1, dt * 2.2));
  if (Math.abs(nightK - house.night) > .004) house.setNight(nightK);
  hemi.intensity = lerp(1.65, .4, nightK); sun.intensity = lerp(2.1, .22, nightK);
  if (mode === 'home' && nightK < .5 && Math.random() < dt * 5) PN.emit(rnd(-2, 2), rnd(.4, 2.8), rnd(-1.6, 1), rnd(-.05, .05), rnd(-.03, .05), rnd(-.03, .03), new THREE.Color(0xfff0c8), rnd(.03, .055), rnd(4, 7), 0);   // motitas de polvo en la luz
  lamp.intensity = nightK * 4; lamp.position.copy(house.bedLampPos());
  // cámara
  if (mode === 'home' || mode === 'egg') {
    const k = mode === 'egg' ? 0 : 0;
    camGoal.pos.set(0, 1.25, 3.8); camGoal.look.set(0, .5 + k, 0); camGoal.k = 4;
    if (mode === 'egg') { camGoal.pos.set(0, 1.4, 3.4); camGoal.look.set(0, .75, 0); }
    if (mode === 'home' && save.sleeping && room === 'dormitorio') { camGoal.pos.set(.1, 2.1, 1.6); camGoal.look.set(-.45, .95, -1.45); camGoal.k = 2; }
    cam.setViewOffset(innerWidth, innerHeight, 0, VIEW.shift * innerHeight, innerWidth, innerHeight);
  } else if (mode === 'shop') shop.camera(dt, camGoal);
  else if (mode === 'mini') { if (cam.view && cam.view.enabled) cam.clearViewOffset(); }
  camPos.lerp(camGoal.pos, Math.min(1, dt * camGoal.k)); camLook.lerp(camGoal.look, Math.min(1, dt * camGoal.k));
  cam.position.copy(camPos); cam.lookAt(camLook);
  PN.update(dt); PA.update(dt); FL.update(dt);
}
function loop() {
  requestAnimationFrame(loop);
  const dt = Math.min(1 / 30, clock.getDelta());
  frame(dt); R.render(scene, cam);
}

/* ---------- pruebas (solo con parámetros en la URL) ---------- */
function testShot() {
  document.head.insertAdjacentHTML('beforeend', '<style>*{animation:none!important;transition:none!important}' + (Q.has('noui') ? '#hud,#nav,#tray,.panel,.screen,#hint{display:none!important}' : '') + '</style>');
  const wait = +(Q.get('shot') || 1);
  setTimeout(async () => {
    if (Q.has('act')) { const a = Q.get('act'); if (a === 'eat') feed(Q.get('give') || 'pizza'); if (a === 'shower') { foamSet(1); shower(); } if (a === 'scrub') { foamSet(+(Q.get('foam') || .8)); } if (a === 'sleep') sleep(); if (['dance', 'flip', 'tickle', 'talk', 'bubbles'].includes(a)) doAct(a); if (a === 'profile') openProfile(); }
    if (Q.has('thumbtest')) { const u = await shop.thumb('food', FOODS[4]); document.title = 'thumb ' + (u ? u.length : u); const im0 = new Image(); im0.src = u; im0.style.cssText = 'position:fixed;left:0;top:0;z-index:98;width:320px'; document.body.appendChild(im0); }
    for (let i = 0; i < (+(Q.get('frames')) || 90); i++) frame(1 / 60);
    if (mode === 'mini' && mini && mini.test) mini.test(Q);
    for (let i = 0; i < (+(Q.get('frames2')) || 0); i++) frame(1 / 60);
    R.render(scene, cam);
    const im = $('#shotImg'); im.src = cv.toDataURL('image/png'); im.style.display = 'block';
    document.title = 'LISTO ' + mode + ' ' + room;
    const info = document.createElement('div'); info.style.cssText = 'position:fixed;left:0;bottom:0;z-index:99;background:#fff;color:#000;font:11px monospace;padding:2px 4px'; info.textContent = document.title + ' ' + JSON.stringify(save.st, (k, v) => typeof v === 'number' ? Math.round(v) : v); document.body.appendChild(info);
  }, wait * 1000);
}
boot().catch(e => { $('#loadTxt').textContent = 'Error al cargar: ' + e.message; console.error(e); });
