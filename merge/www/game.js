// Shrimp Merge: estilo «juego de la sandía». Física 2D de círculos dentro de una pecera; dos iguales que se tocan
// se funden en el siguiente bicho. Render en 3D (esferas con carita) con three.js.
import * as THREE from './lib/three.module.min.js';
import { Particles } from './particulas.js';
import * as SND from './sonido.js';

const Q = new URLSearchParams(location.search);
const $ = s => document.querySelector(s);
const rnd = (a, b) => a + Math.random() * (b - a), clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const S = SND.S, buzz = SND.buzz;

/* ---------- guardado ---------- */
const K = 'merge.';
const save = { best: 0, opt: { sfx: true, music: true, haptic: true }, game: null };
try { save.best = JSON.parse(localStorage.getItem(K + 'best')) || 0; save.opt = Object.assign(save.opt, JSON.parse(localStorage.getItem(K + 'opt')) || {}); save.game = JSON.parse(localStorage.getItem(K + 'game')); } catch (e) { }
const persist = () => { try { localStorage.setItem(K + 'best', JSON.stringify(save.best)); localStorage.setItem(K + 'opt', JSON.stringify(save.opt)); } catch (e) { } };
Object.assign(SND.cfg, save.opt);

/* ---------- bichos ---------- */
const TIERS = [
  { name: 'Plancton', r: .32, c: '#7ff0e0' }, { name: 'Burbuja', r: .42, c: '#a8dcff' }, { name: 'Pececito', r: .54, c: '#ffd23f' },
  { name: 'Gamba', r: .66, c: '#ff9a6a' }, { name: 'Cangrejo', r: .80, c: '#ff4f3f' }, { name: 'Estrella', r: .94, c: '#ffab3a' },
  { name: 'Pulpo', r: 1.08, c: '#c46ae6' }, { name: 'Medusa', r: 1.24, c: '#ff8ad6' }, { name: 'Tortuga', r: 1.42, c: '#5fcf6f' },
  { name: 'Delfín', r: 1.62, c: '#5aa6ff' }, { name: 'Ballena', r: 1.85, c: '#3b5fd6' },
];
const PTS = [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66];
// Dibuja la carita y los rasgos de cada bicho (en un lienzo cuadrado, el círculo ocupa todo el ancho)
function drawFace(x, t, s, withBody) {
  const T0 = TIERS[t], cx = s / 2, cy = s / 2, R = s / 2;
  x.save();
  if (withBody) { const g = x.createRadialGradient(cx - R * .3, cy - R * .35, R * .1, cx, cy, R); g.addColorStop(0, '#ffffff'); g.addColorStop(.18, T0.c); g.addColorStop(1, shade(T0.c, .6)); x.fillStyle = g; x.beginPath(); x.arc(cx, cy, R * .98, 0, 7); x.fill(); }
  const ink = '#2a1830';
  x.fillStyle = 'rgba(255,255,255,.35)';
  switch (t) {
    case 1: x.beginPath(); x.ellipse(cx - R * .35, cy - R * .4, R * .2, R * .12, -.6, 0, 7); x.fill(); break;
    case 2: x.fillStyle = shade(T0.c, .75); x.beginPath(); x.moveTo(cx + R * .55, cy); x.lineTo(cx + R * .95, cy - R * .35); x.lineTo(cx + R * .95, cy + R * .35); x.fill(); break;
    case 3: x.strokeStyle = shade(T0.c, .7); x.lineWidth = s * .025; for (let i = 0; i < 3; i++) { x.beginPath(); x.arc(cx + R * .2, cy, R * (.45 + i * .17), -.9, .9); x.stroke(); } x.strokeStyle = ink; x.lineWidth = s * .012; x.beginPath(); x.moveTo(cx - R * .35, cy - R * .5); x.quadraticCurveTo(cx - R * .6, cy - R * 1, cx - R * .1, cy - R * .95); x.stroke(); break;
    case 4: x.fillStyle = shade(T0.c, .8); for (const sx of [-1, 1]) { x.beginPath(); x.arc(cx + sx * R * .62, cy - R * .62, R * .26, 0, 7); x.fill(); x.fillStyle = shade(T0.c, .55); x.beginPath(); x.moveTo(cx + sx * R * .62, cy - R * .62); x.lineTo(cx + sx * R * .9, cy - R * .85); x.lineTo(cx + sx * R * .82, cy - R * .5); x.fill(); x.fillStyle = shade(T0.c, .8); } break;
    case 5: x.fillStyle = shade(T0.c, .82); for (let i = 0; i < 5; i++) { const a = i / 5 * Math.PI * 2 - Math.PI / 2; x.beginPath(); x.arc(cx + Math.cos(a) * R * .72, cy + Math.sin(a) * R * .72, R * .1, 0, 7); x.fill(); } break;
    case 6: x.fillStyle = shade(T0.c, .75); for (let i = 0; i < 6; i++) { x.beginPath(); x.arc(cx - R * .6 + i * R * .24, cy + R * .78, R * .09, 0, 7); x.fill(); } break;
    case 7: x.fillStyle = 'rgba(255,255,255,.4)'; for (let i = 0; i < 7; i++) { x.beginPath(); x.arc(cx - R * .72 + i * R * .24, cy + R * .55, R * .12, 0, Math.PI); x.fill(); } break;
    case 8: x.strokeStyle = shade(T0.c, .6); x.lineWidth = s * .02; for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; x.beginPath(); x.moveTo(cx + Math.cos(a) * R * .3, cy - R * .25 + Math.sin(a) * R * .3); x.lineTo(cx + Math.cos(a) * R * .75, cy - R * .25 + Math.sin(a) * R * .75); x.stroke(); } x.beginPath(); x.arc(cx, cy - R * .25, R * .3, 0, 7); x.stroke(); break;
    case 9: x.fillStyle = shade(T0.c, .7); x.beginPath(); x.moveTo(cx - R * .1, cy - R * .6); x.lineTo(cx + R * .2, cy - R * 1); x.lineTo(cx + R * .3, cy - R * .55); x.fill(); x.fillStyle = 'rgba(255,255,255,.45)'; x.beginPath(); x.ellipse(cx, cy + R * .45, R * .6, R * .28, 0, 0, 7); x.fill(); break;
    case 10: x.fillStyle = 'rgba(255,255,255,.4)'; x.beginPath(); x.ellipse(cx, cy + R * .45, R * .7, R * .32, 0, 0, 7); x.fill(); x.fillStyle = '#bfe9ff'; for (const [dx, dy, rr] of [[0, -1.02, .1], [-.12, -1.12, .07], [.12, -1.12, .07]]) { x.beginPath(); x.arc(cx + dx * R, cy + dy * R + R * .1, rr * R, 0, 7); x.fill(); } break;
  }
  // ojos
  const ey = cy - R * .08, ex = R * .3, er = R * (t === 0 ? .2 : .16);
  for (const sx of [-1, 1]) { x.fillStyle = '#fff'; x.beginPath(); x.ellipse(cx + sx * ex, ey, er, er * 1.15, 0, 0, 7); x.fill(); x.fillStyle = ink; x.beginPath(); x.arc(cx + sx * ex + er * .15, ey + er * .15, er * .58, 0, 7); x.fill(); x.fillStyle = '#fff'; x.beginPath(); x.arc(cx + sx * ex + er * .35, ey - er * .2, er * .22, 0, 7); x.fill(); }
  x.fillStyle = 'rgba(255,90,140,.45)'; for (const sx of [-1, 1]) { x.beginPath(); x.ellipse(cx + sx * R * .52, cy + R * .18, R * .14, R * .08, 0, 0, 7); x.fill(); }
  x.strokeStyle = ink; x.lineWidth = s * .02; x.lineCap = 'round'; x.beginPath(); x.arc(cx, cy + R * .12, R * .14, .2, Math.PI - .2); x.stroke();
  x.restore();
}
function shade(hex, f) { const c = new THREE.Color(hex).multiplyScalar(f); return '#' + c.getHexString(); }
const faceTex = TIERS.map((_, t) => { const c = document.createElement('canvas'); c.width = c.height = 256; drawFace(c.getContext('2d'), t, 256, false); const tx = new THREE.CanvasTexture(c); tx.colorSpace = THREE.SRGBColorSpace; return tx; });
const iconUrl = TIERS.map((_, t) => { const c = document.createElement('canvas'); c.width = c.height = 120; drawFace(c.getContext('2d'), t, 120, true); return c; });

/* ---------- escena ---------- */
const cv = $('#cv');
const R = new THREE.WebGLRenderer({ canvas: cv, antialias: true, preserveDrawingBuffer: Q.has('shot') });
const scene = new THREE.Scene();
scene.background = (() => { const c = document.createElement('canvas'); c.width = 4; c.height = 256; const x = c.getContext('2d'), g = x.createLinearGradient(0, 0, 0, 256); g.addColorStop(0, '#2a8ad6'); g.addColorStop(1, '#0b2a5a'); x.fillStyle = g; x.fillRect(0, 0, 4, 256); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; })();
scene.add(new THREE.HemisphereLight(0xeaf6ff, 0x30507a, 1.6));
const dl = new THREE.DirectionalLight(0xffffff, 1.6); dl.position.set(-3, 8, 10); scene.add(dl);
const W = 6.2, H = 8.7, LINE = 7.5;
const cam = new THREE.PerspectiveCamera(30, 1, .1, 200);
function resize() {
  const w = innerWidth, h = innerHeight, a = w / h; R.setPixelRatio(Math.min(devicePixelRatio || 1, 2)); R.setSize(w, h, false); cam.aspect = a; cam.updateProjectionMatrix();
  const tv = Math.tan(THREE.MathUtils.degToRad(cam.fov) / 2), th = tv * a, d = Math.max((W / 2 + .5) / th, (H / 2 + 2.6) / tv);
  cam.position.set(0, H / 2 + .4, d); cam.lookAt(0, H / 2 + .4, 0);
  if (PA) PA.setPixelRatio(R.getPixelRatio());
}
addEventListener('resize', resize);
let PA = null;
// pecera: fondo, arena, algas y cristal
const jar = new THREE.Group(); scene.add(jar);
const back = new THREE.Mesh(new THREE.PlaneGeometry(W + .4, H + .6), new THREE.MeshStandardMaterial({ color: 0x3f9fe0, roughness: .9 })); back.position.set(0, H / 2, -1.2); jar.add(back);
const sand = new THREE.Mesh(new THREE.BoxGeometry(W + .4, .6, 2.6), new THREE.MeshStandardMaterial({ color: 0xf2d99a, roughness: 1 })); sand.position.set(0, -.3, 0); jar.add(sand);
for (let i = 0; i < 7; i++) { const h = rnd(1, 2.6), weed = new THREE.Mesh(new THREE.ConeGeometry(.12, h, 5), new THREE.MeshStandardMaterial({ color: [0x3fbf5a, 0x2f9a48, 0x5fd66f][i % 3], flatShading: true })); weed.position.set(-W / 2 + .3 + i * (W - .6) / 6, h / 2, -1.05); weed.userData.ph = rnd(0, 6); jar.add(weed); }
for (let i = 0; i < 5; i++) { const rock = new THREE.Mesh(new THREE.IcosahedronGeometry(rnd(.2, .45), 0), new THREE.MeshStandardMaterial({ color: 0x8a8378, flatShading: true })); rock.position.set(rnd(-W / 2 + .3, W / 2 - .3), .05, -1); jar.add(rock); }
const glassM = new THREE.MeshStandardMaterial({ color: 0xcfefff, transparent: true, opacity: .22, roughness: .05 });
for (const sx of [-1, 1]) { const wall = new THREE.Mesh(new THREE.BoxGeometry(.18, H + .4, 2.6), glassM); wall.position.set(sx * (W / 2 + .09), H / 2, 0); jar.add(wall); const rim = new THREE.Mesh(new THREE.BoxGeometry(.24, .2, 2.7), new THREE.MeshStandardMaterial({ color: 0xffffff })); rim.position.set(sx * (W / 2 + .09), H + .2, 0); jar.add(rim); }
// línea de peligro y guía de caída
const lineM = new THREE.MeshBasicMaterial({ color: 0xff4d6d, transparent: true, opacity: .35 });
const dangerLine = new THREE.Mesh(new THREE.PlaneGeometry(W, .05), lineM); dangerLine.position.set(0, LINE, 1.25); jar.add(dangerLine);
const guide = new THREE.Mesh(new THREE.PlaneGeometry(.04, LINE), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: .35 })); jar.add(guide);

/* ---------- cuerpos ---------- */
const sphGeo = new THREE.SphereGeometry(1, 40, 28), discGeo = new THREE.CircleGeometry(1, 40);
const bodyMat = TIERS.map(t => new THREE.MeshStandardMaterial({ color: t.c, roughness: .35, metalness: 0, transparent: t.name === 'Burbuja', opacity: t.name === 'Burbuja' ? .8 : 1 }));
const faceMat = faceTex.map(tx => new THREE.MeshBasicMaterial({ map: tx, transparent: true, depthWrite: false }));
function makeMesh(t) {
  const g = new THREE.Group(), r = TIERS[t].r;
  const b = new THREE.Mesh(sphGeo, bodyMat[t]); b.scale.set(r, r, r * .85); g.add(b);
  const f = new THREE.Mesh(discGeo, faceMat[t]); f.scale.setScalar(r * .92); f.position.z = r * .86; g.add(f);
  scene.add(g); return g;
}
let bodies = [], G = null, mode = 'start', T = 0;
function addBody(t, x, y, vx = 0, vy = 0) { const b = { t, r: TIERS[t].r, x, y, vx, vy, a: 0, w: 0, m: makeMesh(t), born: T, pop: 0 }; bodies.push(b); return b; }
function removeBody(b) { scene.remove(b.m); b.dead = true; }
const pickTier = () => { const r = Math.random(); return r < .3 ? 0 : r < .55 ? 1 : r < .75 ? 2 : r < .9 ? 3 : 4; };

/* ---------- partida ---------- */
function newGame() {
  for (const b of bodies) scene.remove(b.m); bodies = [];
  G = { score: 0, cur: pickTier(), next: pickTier(), x: 0, cool: 0, over: false, overT: 0, top: 0, combo: 0, comboT: 0, paused: false };
  if (ghost) scene.remove(ghost); ghost = makeMesh(G.cur);
  mode = 'run'; $('#start').hidden = true; $('#over').hidden = true; $('#paused').hidden = true; updHud(); SND.setMusic(true);
}
let ghost = null;
function drop() {
  if (!G || G.over || G.cool > 0 || G.paused) return;
  const r = TIERS[G.cur].r, x = clamp(G.x, -W / 2 + r, W / 2 - r);
  addBody(G.cur, x, LINE + .55 + r * .3, 0, -2);
  SND.tone(400 + G.cur * 40, .08, 'triangle', .1, -120); buzz('LIGHT');
  G.cur = G.next; G.next = pickTier(); G.cool = .5;
  scene.remove(ghost); ghost = makeMesh(G.cur); updHud(); saveGame();
}
function merge(a, b) {
  const t = a.t;
  removeBody(a); removeBody(b);
  const x = (a.x + b.x) / 2, y = (a.y + b.y) / 2, c = new THREE.Color(TIERS[t].c);
  PA.burst(x, y, 1, 14 + t * 3, c, 2 + t * .3, .16 + t * .02, .6, 2);
  G.combo = G.comboT > 0 ? G.combo + 1 : 1; G.comboT = .8;
  if (t === TIERS.length - 1) { G.score += 200; bonus('¡DOBLE BALLENA! +200'); S.levelup && S.levelup(); buzz('HEAVY'); return; }
  const n = addBody(t + 1, x, y, (a.vx + b.vx) / 2, Math.max(a.vy, b.vy) + 1.5); n.pop = 1;
  const pts = PTS[t + 1] * (G.combo > 1 ? G.combo : 1); G.score += pts;
  if (t + 1 > G.top) { G.top = t + 1; if (t + 1 >= 5) bonus(`¡${TIERS[t + 1].name.toUpperCase()}!`); }
  else if (G.combo > 2) bonus(`¡COMBO ×${G.combo}!`);
  SND.tone(330 * Math.pow(1.12, t), .14, 'sine', .14, 260); SND.tone(660 * Math.pow(1.12, t), .1, 'triangle', .06, 0, .05); buzz(t > 5 ? 'MEDIUM' : 'LIGHT');
}
function bonus(s) { const b = $('#bonus'); b.textContent = s; b.classList.remove('on'); void b.offsetWidth; b.classList.add('on'); }

/* ---------- física ---------- */
function physics(dt) {
  const steps = 6, h = dt / steps, GR = 22;
  for (let s = 0; s < steps; s++) {
    for (const b of bodies) { if (b.dead) continue; b.vy -= GR * h; b.x += b.vx * h; b.y += b.vy * h; b.vx *= .999; }
    for (let it = 0; it < 3; it++) {
      for (let i = 0; i < bodies.length; i++) {
        const a = bodies[i]; if (a.dead) continue;
        // paredes y suelo
        if (a.x - a.r < -W / 2) { a.x = -W / 2 + a.r; if (a.vx < 0) a.vx *= -.2; }
        if (a.x + a.r > W / 2) { a.x = W / 2 - a.r; if (a.vx > 0) a.vx *= -.2; }
        if (a.y - a.r < 0) { a.y = a.r; if (a.vy < 0) a.vy *= -.15; a.vx *= .97; a.w = -a.vx / a.r; }
        for (let j = i + 1; j < bodies.length; j++) {
          const b = bodies[j]; if (b.dead) continue;
          const dx = b.x - a.x, dy = b.y - a.y, d2 = dx * dx + dy * dy, rr = a.r + b.r;
          if (d2 >= rr * rr || d2 === 0) continue;
          if (a.t === b.t && !G.over) { merge(a, b); break; }
          const d = Math.sqrt(d2), nx = dx / d, ny = dy / d, pen = rr - d, ma = a.r * a.r, mb = b.r * b.r, tm = ma + mb;
          a.x -= nx * pen * mb / tm; a.y -= ny * pen * mb / tm; b.x += nx * pen * ma / tm; b.y += ny * pen * ma / tm;
          const rv = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
          if (rv < 0) { const j2 = -(1 + .1) * rv / (1 / ma + 1 / mb); a.vx -= j2 * nx / ma; a.vy -= j2 * ny / ma; b.vx += j2 * nx / mb; b.vy += j2 * ny / mb; }
          // rozamiento: hace rodar
          const tx = -ny, ty = nx, tv = (b.vx - a.vx) * tx + (b.vy - a.vy) * ty;
          a.vx += tx * tv * .02; a.vy += ty * tv * .02; b.vx -= tx * tv * .02; b.vy -= ty * tv * .02;
          a.w += tv / a.r * .05; b.w -= tv / b.r * .05;
        }
      }
    }
    bodies = bodies.filter(b => !b.dead);
  }
}
function step(dt) {
  if (G.paused) return;
  G.cool = Math.max(0, G.cool - dt); G.comboT -= dt;
  physics(dt);
  // desbordar: algún bicho asentado por encima de la línea durante 2 s
  const above = bodies.some(b => T - b.born > 1.2 && b.y + b.r > LINE && Math.abs(b.vy) < 1.5);
  G.overT = above ? G.overT + dt : Math.max(0, G.overT - dt * 2);
  lineM.opacity = above ? .35 + Math.abs(Math.sin(T * 8)) * .5 : .3;
  if (G.overT > 2 && !G.over) gameOver();
  updHud();
}
function gameOver() {
  G.over = true; S.bad && S.bad(); buzz('HEAVY'); SND.setMusic(false);
  const rec = G.score > save.best; if (rec) save.best = G.score; persist(); try { localStorage.removeItem(K + 'game'); } catch (e) { }
  setTimeout(() => { $('#oScore').textContent = G.score; $('#oBest').textContent = save.best; $('#oTop').textContent = TIERS[G.top].name; $('#oRec').hidden = !rec; $('#over').hidden = false; mode = 'over'; }, 900);
}
function saveGame() { try { localStorage.setItem(K + 'game', JSON.stringify({ score: G.score, cur: G.cur, next: G.next, top: G.top, b: bodies.map(b => [b.t, +b.x.toFixed(2), +b.y.toFixed(2)]) })); } catch (e) { } }
function loadGame(g) {
  newGame(); G.score = g.score; G.cur = g.cur; G.next = g.next; G.top = g.top || 0;
  for (const [t, x, y] of g.b) addBody(t, x, y).born = -10;
  scene.remove(ghost); ghost = makeMesh(G.cur); updHud();
}

/* ---------- interfaz ---------- */
function updHud() {
  $('#score').textContent = G ? G.score : 0; $('#best').textContent = Math.max(save.best, G ? G.score : 0);
  const nc = $('#nextCv'), x = nc.getContext('2d'); x.clearRect(0, 0, 120, 120); if (G) x.drawImage(iconUrl[G.next], 0, 0);
}
const chain = $('#chain');
TIERS.forEach((t, i) => { const c = document.createElement('canvas'); c.width = c.height = 60; c.getContext('2d').drawImage(iconUrl[i], 0, 0, 60, 60); c.title = t.name; chain.appendChild(c); });
function toCol(clientX) { const v = new THREE.Vector3((clientX / innerWidth) * 2 - 1, 0, .5).unproject(cam), dir = v.sub(cam.position).normalize(), d = -cam.position.z / dir.z; return cam.position.x + dir.x * d; }
let dragging = false;
cv.addEventListener('pointerdown', e => { if (mode !== 'run') return; SND.ac(); dragging = true; G.x = toCol(e.clientX); });
addEventListener('pointermove', e => { if (mode === 'run' && dragging) G.x = toCol(e.clientX); });
addEventListener('pointerup', e => { if (mode === 'run' && dragging) { dragging = false; G.x = toCol(e.clientX); drop(); } });
$('#startBtn').onclick = () => { SND.ac(); save.game && save.game.b && save.game.b.length ? loadGame(save.game) : newGame(); };
$('#again').onclick = () => newGame();
$('#menuBtn').onclick = () => { if (mode === 'run' && !G.over) { G.paused = true; $('#optSfx').checked = save.opt.sfx; $('#optMusic').checked = save.opt.music; $('#paused').hidden = false; } };
$('#resume').onclick = () => { G.paused = false; $('#paused').hidden = true; };
$('#restart').onclick = () => { try { localStorage.removeItem(K + 'game'); } catch (e) { } newGame(); };
$('#optSfx').onchange = e => { save.opt.sfx = e.target.checked; Object.assign(SND.cfg, save.opt); persist(); };
$('#optMusic').onchange = e => { save.opt.music = e.target.checked; Object.assign(SND.cfg, save.opt); persist(); SND.setMusic(true); };
document.addEventListener('visibilitychange', () => { if (document.hidden) { if (G && !G.over) saveGame(); SND.suspend(true); } else SND.suspend(false); });

/* ---------- bucle ---------- */
const clock = new THREE.Clock();
function frame(dt) {
  T += dt;
  if (mode === 'run' && G && !(Q.has('icon'))) step(dt);
  for (const b of bodies) {
    b.a += b.w * dt; b.w *= .98; b.pop = Math.max(0, b.pop - dt * 4);
    b.m.position.set(b.x, b.y, 0); b.m.rotation.z = b.a; b.m.scale.setScalar(1 + Math.sin(b.pop * Math.PI) * .2);
  }
  if (ghost && G) {
    const r = TIERS[G.cur].r, x = clamp(G.x, -W / 2 + r, W / 2 - r);
    ghost.position.set(x, LINE + .55 + r * .3 + Math.sin(T * 3) * .05, 0); ghost.visible = G.cool <= 0 && !G.over;
    guide.position.set(x, LINE / 2, 1.2); guide.visible = ghost.visible;
  }
  for (const o of jar.children) if (o.userData.ph !== undefined) o.rotation.z = Math.sin(T * 1.3 + o.userData.ph) * .12;
  if (Math.random() < dt * 4) PA.emit(rnd(-W / 2, W / 2), 0, -.8, 0, rnd(.6, 1.2), 0, new THREE.Color(0xd6f4ff), rnd(.06, .12), rnd(4, 7), 0);
  PA.update(dt);
}
function loop() { requestAnimationFrame(loop); const dt = Math.min(1 / 30, clock.getDelta()); frame(dt); R.render(scene, cam); }
function boot() {
  PA = new Particles(scene, 300, true, R.getPixelRatio());
  resize(); updHud(); requestAnimationFrame(loop);
  if (save.game && save.game.b && save.game.b.length) $('#startBtn').textContent = 'CONTINUAR';
  if (Q.has('shot')) testShot();
}
function testShot() {
  document.head.insertAdjacentHTML('beforeend', '<style>*{animation:none!important;transition:none!important}' + (Q.has('noui') ? '#top,#chain,.screen{display:none!important}' : '') + '</style>');
  setTimeout(() => {
    if (Q.has('play')) { newGame(); const n = +Q.get('drops') || 0; for (let i = 0; i < n; i++) { G.x = rnd(-2.6, 2.6); G.cool = 0; drop(); for (let k = 0; k < 40; k++) frame(1 / 60); } }
    if (Q.has('icon')) { newGame(); ghost.visible = false; [[10, 0, 1.9], [7, -2.2, 1.2], [3, 2.15, .7], [0, 1.2, 3.0], [5, 2.1, 1.9]].forEach(([t, x, y]) => addBody(t, x, y).born = -10); jar.children.forEach(o => { if (o === dangerLine || o === guide) o.visible = false; }); cam.position.set(0, 2.4, 13); cam.lookAt(0, 2.2, 0); G.over = true; }
    if (Q.has('all')) { newGame(); TIERS.forEach((t, i) => addBody(i, -2.6 + (i % 4) * 1.7, 1 + Math.floor(i / 4) * 2.6).born = -10); }
    for (let i = 0; i < (+Q.get('frames') || 60); i++) frame(1 / 60);
    R.render(scene, cam);
    const im = $('#shotImg'); im.src = cv.toDataURL('image/png'); im.style.cssText = 'display:block;position:fixed;inset:0;width:100%;height:100%;z-index:4;pointer-events:none';
    document.title = 'LISTO ' + mode + (G ? ` score=${G.score} n=${bodies.length} top=${G.top}` : '');
    const d = document.createElement('div'); d.style.cssText = 'position:fixed;left:0;bottom:0;z-index:99;background:#fff;color:#000;font:11px monospace'; d.textContent = document.title; document.body.appendChild(d);
  }, (+Q.get('shot') || 1) * 1000);
}
boot();
