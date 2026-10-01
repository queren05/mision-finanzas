// Tung Tung Run 3D: corredor infinito con three.js. Tres carriles; deslizar izq/der cambia de carril, arriba salta,
// abajo se agacha. Te persigue Tung Tung Tung Sahur: si tropiezas se acerca; si tropiezas otra vez antes de
// despegarte (o chocas de frente), te pilla.
import * as THREE from './lib/three.module.min.js';
import * as M from './modelos.js';
import { CHARS, SKINS, HATS, TRAILS, UPGRADES, UPGRADE_COST, MULTS, multCost, ITEMS, MAPS, TABS, save, persist, owns, level, upDur, scoreMult } from './datos.js';

const Q = new URLSearchParams(location.search);
const $ = s => document.querySelector(s);
const rnd = M.rnd, clamp = (v, a, b) => Math.max(a, Math.min(b, v)), lerp = (a, b, t) => a + (b - a) * t;
const LX = [-1.3, 0, 1.3];

/* ---------- motor ---------- */
const cv = $('#cv');
const R = new THREE.WebGLRenderer({ canvas: cv, antialias: true, powerPreference: 'high-performance', preserveDrawingBuffer: Q.has('shot') });
const scene = new THREE.Scene();
const cam = new THREE.PerspectiveCamera(62, 1, .1, 700);
// Resolución adaptativa: si el móvil no llega a ~40 fps, baja la resolución de dibujo un escalón (2 → 1,6 → 1,3 → 1).
const PR_STEPS = [2, 1.6, 1.3, 1];
let prLevel = 0;
const pixelRatio = () => Math.min(devicePixelRatio || 1, save.opt.hq ? PR_STEPS[prLevel] : Math.min(1.25, PR_STEPS[prLevel]));
function resize() {
  const w = innerWidth, h = innerHeight, pr = pixelRatio();
  if (typeof PN !== 'undefined' && PN) { PN.mat.uniforms.k.value = PA.mat.uniforms.k.value = 300 * pr; }
  R.setPixelRatio(pr);
  R.setSize(w, h, false);
  cam.aspect = w / h;
  // que los tres carriles quepan siempre de ancho: ~4,6 m visibles a la altura del jugador
  const hf = 2 * Math.atan(2.45 / 6.6), vf = 2 * Math.atan(Math.tan(hf / 2) / cam.aspect);
  cam.fov = clamp(THREE.MathUtils.radToDeg(vf), 55, 80);
  cam.updateProjectionMatrix();
}
let emaDt = 1 / 60, slowN = 0, warm = 0;
function adapt(raw) {
  if (Q.has('shot') || raw > .25 || raw <= 0) return;           // pruebas, pausas y cambios de pestaña no cuentan
  if (++warm < 120) return;                                      // los primeros segundos (carga de modelos) tampoco
  emaDt = emaDt * .94 + raw * .06;
  if (emaDt > 1 / 38 && prLevel < PR_STEPS.length - 1) { if (++slowN > 50) { prLevel++; slowN = 0; emaDt = 1 / 50; warm = 60; resize(); } } else slowN = 0;
}
addEventListener('resize', resize);

const hemi = new THREE.HemisphereLight(0xdff2ff, 0x5a6a3a, 1.9); scene.add(hemi);
const sun = new THREE.DirectionalLight(0xfff1d6, 2.3); sun.position.set(-4, 10, 7); scene.add(sun);
scene.fog = new THREE.Fog(0xcfe6f5, 40, 135);

// cielo: degradado + siluetas lejanas (no se curvan ni tienen niebla)
const skyMat = new THREE.ShaderMaterial({
  side: THREE.BackSide, depthWrite: false, fog: false,
  uniforms: { top: { value: new THREE.Color() }, mid: { value: new THREE.Color() }, bot: { value: new THREE.Color() } },
  vertexShader: 'varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
  fragmentShader: `uniform vec3 top; uniform vec3 mid; uniform vec3 bot; varying vec3 vP;
void main(){ float h = vP.y; vec3 c = h > 0.0 ? mix(mid, top, pow(clamp(h*1.6,0.0,1.0), .7)) : mix(mid, bot, clamp(-h*4.0,0.0,1.0)); gl_FragColor = vec4(c,1.0);
#include <colorspace_fragment>
}`,
});
const sky = new THREE.Mesh(new THREE.SphereGeometry(500, 32, 16), skyMat); scene.add(sky);
const far = new THREE.Group(); scene.add(far);   // siluetas del horizonte (van con la cámara)

/* ---------- estado general ---------- */
let A = null;                // modelos cargados
let player, tung, env = {}, curMap = null;
let mode = 'loading';        // loading | menu | shop | run | dying | over
let G = null;                // partida
const clock = new THREE.Clock();
let T = 0;

/* ---------- sonido ---------- */
let AC = null, master = null, musicGain = null;
function ac() { if (!AC) { try { AC = new (window.AudioContext || window.webkitAudioContext)(); master = AC.createGain(); master.gain.value = .9; master.connect(AC.destination); musicGain = AC.createGain(); musicGain.gain.value = .0; musicGain.connect(master); } catch (e) { } } if (AC && AC.state === 'suspended') AC.resume(); return AC; }
// iOS: con el interruptor de silencio activado, Safari apaga el Web Audio. Si la sesión de audio es de tipo «playback»
// (iOS 17+) y además suena en bucle un <audio> silencioso, el juego se oye igual que cualquier otro juego.
// También hay que crear/reanudar el audio dentro de un gesto real (touchend o click; pointerdown no siempre vale).
const SILENT = 'data:audio/wav;base64,UklGRsQPAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YaAPAACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA';
let silentEl = null;
function unlockAudio() {
  try { if (navigator.audioSession && navigator.audioSession.type !== 'playback') navigator.audioSession.type = 'playback'; } catch (e) { }
  if (!silentEl) { silentEl = document.createElement('audio'); silentEl.setAttribute('playsinline', ''); silentEl.setAttribute('x-webkit-airplay', 'deny'); silentEl.loop = true; silentEl.src = SILENT; silentEl.volume = 0.01; }
  if (silentEl.paused) silentEl.play().catch(() => { });
  const a = ac(); if (a && a.state !== 'running') a.resume().catch(() => { });
}
for (const ev of ['touchend', 'click', 'keydown']) document.addEventListener(ev, unlockAudio, { capture: true, passive: true });
function tone(f, d, type = 'sine', v = .2, slide = 0, when = 0, dest) {
  if (!save.opt.sfx && !dest) return; const a = ac(); if (!a) return;
  const o = a.createOscillator(), g = a.createGain(), t = a.currentTime + when;
  o.type = type; o.frequency.setValueAtTime(f, t); if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, f + slide), t + d);
  g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + d); o.connect(g).connect(dest || master); o.start(t); o.stop(t + d + .02);
}
function noiseHit(d = .15, v = .2, hp = 1000, when = 0, dest) {
  const a = ac(); if (!a || (!save.opt.sfx && !dest)) return;
  const b = a.createBuffer(1, a.sampleRate * d, a.sampleRate), ch = b.getChannelData(0); for (let i = 0; i < ch.length; i++) ch[i] = (Math.random() * 2 - 1) * (1 - i / ch.length);
  const s = a.createBufferSource(), f = a.createBiquadFilter(), g = a.createGain(); s.buffer = b; f.type = 'highpass'; f.frequency.value = hp; g.gain.value = v;
  s.connect(f).connect(g).connect(dest || master); s.start(a.currentTime + when);
}
const S = {
  coin: () => { tone(1318, .07, 'square', .045); tone(1976, .12, 'square', .04, 0, .05); },
  jump: () => tone(330, .2, 'sine', .16, 500),
  slide: () => { noiseHit(.22, .12, 1800); tone(200, .18, 'triangle', .08, -90); },
  lane: () => tone(620, .05, 'sine', .05, 120),
  tung: () => [0, .17, .34].forEach(w => { tone(180, .13, 'triangle', .38, -70, w); tone(92, .12, 'sine', .32, 0, w); }),
  hit: () => { noiseHit(.3, .3, 300); tone(110, .35, 'sawtooth', .16, -60); },
  power: () => [0, .07, .14, .21].forEach((w, i) => tone(660 * Math.pow(1.26, i), .12, 'triangle', .1, 0, w)),
  buy: () => [0, .08, .16].forEach((w, i) => tone(880 * Math.pow(1.335, i), .14, 'square', .06, 0, w)),
  shield: () => tone(900, .3, 'sine', .15, -500),
  bonk: () => { tone(160, .25, 'square', .12, -80); noiseHit(.2, .2, 600); },
};
// música: bucle sencillo con bajo, bombo, «tung» de madera y charles
let musicOn = false, nextBeat = 0, beat = 0;
const BASS = [45, 45, 52, 45, 48, 48, 43, 50];
function musicTick() {
  if (!AC || !musicOn) return;
  const spb = 60 / 128 / 2;
  while (nextBeat < AC.currentTime + .25) {
    const w = nextBeat - AC.currentTime, b = beat % 16;
    if (b % 4 === 0) { tone(55, .22, 'sine', .5, -30, w, musicGain); }
    if (b % 2 === 1) noiseHit(.04, .08, 7000, w, musicGain);
    if (b % 8 === 4) noiseHit(.12, .18, 1500, w, musicGain);
    if (b % 2 === 0) { const n = BASS[(beat >> 1) % 8]; tone(440 * Math.pow(2, (n - 69) / 12), .2, 'triangle', .22, 0, w, musicGain); }
    if (b === 10 || b === 13 || b === 14) tone(260, .09, 'triangle', .22, -80, w, musicGain);
    nextBeat += spb; beat++;
  }
}
setInterval(musicTick, 90);
function setMusic(on) { musicOn = on && save.opt.music; if (!ac()) return; musicGain.gain.setTargetAtTime(musicOn ? (mode === 'run' ? .16 : .1) : 0, AC.currentTime, .3); if (musicOn && nextBeat < AC.currentTime) nextBeat = AC.currentTime + .05; }
const Hap = () => window.Capacitor && Capacitor.Plugins && Capacitor.Plugins.Haptics;
const buzz = (s = 'LIGHT') => { if (!save.opt.haptic) return; try { const h = Hap(); if (h) h.impact({ style: s }); } catch (e) { } };

/* ---------- partículas ---------- */
class Particles {
  constructor(n, additive) {
    this.n = n; this.i = 0;
    const g = new THREE.BufferGeometry();
    this.pos = new Float32Array(n * 3); this.col = new Float32Array(n * 3); this.sz = new Float32Array(n); this.al = new Float32Array(n);
    this.vel = new Float32Array(n * 3); this.life = new Float32Array(n); this.max = new Float32Array(n); this.grav = new Float32Array(n); this.s0 = new Float32Array(n); this.grow = new Float32Array(n);
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3)); g.setAttribute('color', new THREE.BufferAttribute(this.col, 3));
    g.setAttribute('size', new THREE.BufferAttribute(this.sz, 1)); g.setAttribute('alpha', new THREE.BufferAttribute(this.al, 1));
    this.mat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending, vertexColors: true,
      uniforms: { k: { value: 300 * R.getPixelRatio() } },
      vertexShader: 'attribute float size; attribute float alpha; varying vec3 vC; varying float vA; uniform float k; void main(){ vC = color; vA = alpha; vec4 mv = modelViewMatrix * vec4(position,1.0); gl_PointSize = size * k / -mv.z; gl_Position = projectionMatrix * mv; }',
      fragmentShader: `varying vec3 vC; varying float vA;
void main(){ vec2 p = gl_PointCoord - .5; float d = length(p); if (d > .5) discard; gl_FragColor = vec4(vC, vA * smoothstep(.5, .15, d));
#include <colorspace_fragment>
}`,
    });
    this.pts = new THREE.Points(g, this.mat); this.pts.frustumCulled = false; scene.add(this.pts);
  }
  emit(x, y, z, vx, vy, vz, color, size, life, grav = 0, grow = 0) {
    const i = this.i = (this.i + 1) % this.n;
    this.pos.set([x, y, z], i * 3); this.vel.set([vx, vy, vz], i * 3); this.col.set([color.r, color.g, color.b], i * 3);
    this.s0[i] = size; this.life[i] = this.max[i] = life; this.grav[i] = grav; this.grow[i] = grow;
  }
  update(dt, dz) {
    for (let i = 0; i < this.n; i++) {
      if (this.life[i] <= 0) { this.al[i] = 0; continue; }
      this.life[i] -= dt; const k = i * 3;
      this.vel[k + 1] -= this.grav[i] * dt;
      this.pos[k] += this.vel[k] * dt; this.pos[k + 1] += this.vel[k + 1] * dt; this.pos[k + 2] += this.vel[k + 2] * dt + dz;
      const f = Math.max(0, this.life[i] / this.max[i]);
      this.al[i] = Math.min(1, f * 1.6); this.sz[i] = this.s0[i] * (1 + this.grow[i] * (1 - f));
    }
    const a = this.pts.geometry.attributes; a.position.needsUpdate = a.color.needsUpdate = a.size.needsUpdate = a.alpha.needsUpdate = true;
  }
}
let PN, PA;
const C = h => new THREE.Color(h);

/* ---------- decorado instanciado que se recicla al pasar ---------- */
class Scatter {
  // Decorado repetido con mallas instanciadas. El grupo avanza entero (una sola transformación por frame) y solo se
  // recalcula y se vuelve a subir a la GPU lo que sale por detrás y pasa delante.
  constructor(protos, count, place, span = 175, zMax = 14) {
    this.group = new THREE.Group(); this.span = span; this.zMax = zMax; this.place = place; this.off = 0;
    this.kinds = protos.map(p => { const b = M.bake(p); b.updateMatrixWorld(true); const subs = []; b.traverse(o => { if (o.isMesh) subs.push({ o, rel: o.matrixWorld.clone() }); }); return { subs, items: [] }; });
    for (let i = 0; i < count; i++) { const kind = i % this.kinds.length, it = { kind, z: zMax - rnd(0, span) }; place(it, true); this.kinds[kind].items.push(it); }
    for (const k of this.kinds) k.meshes = k.subs.map(s => { const im = new THREE.InstancedMesh(s.o.geometry, M.bend(s.o.material), Math.max(1, k.items.length)); im.frustumCulled = false; this.group.add(im); return im; });
    this.tmp = new THREE.Matrix4(); this.m = new THREE.Matrix4(); this.q = new THREE.Quaternion(); this.e = new THREE.Euler(); this.v = new THREE.Vector3(); this.s = new THREE.Vector3();
    this.kinds.forEach(k => { k.items.forEach((it, i) => this.write(k, it, i)); k.meshes.forEach(im => { im.instanceMatrix.needsUpdate = true; }); });
  }
  write(k, it, idx) {
    const { m, q, e, v, s } = this;
    e.set(0, it.ry || 0, 0); q.setFromEuler(e); v.set(it.x, it.y || 0, it.z); s.setScalar(it.s || 1); m.compose(v, q, s);
    k.subs.forEach((sub, j) => k.meshes[j].setMatrixAt(idx, this.tmp.multiplyMatrices(m, sub.rel)));
  }
  update(d) {
    this.off += d; this.group.position.z = this.off;
    for (const k of this.kinds) {
      let dirty = false;
      k.items.forEach((it, idx) => { if (it.z + this.off > this.zMax) { it.z -= this.span; this.place(it, false); this.write(k, it, idx); dirty = true; } });
      if (dirty) for (const im of k.meshes) im.instanceMatrix.needsUpdate = true;
    }
  }
}

/* ---------- carga ---------- */
async function boot() {
  resize();
  A = await M.loadAll({
    gamba: 'models/gamba.glb', chaqueta: 'models/gamba_chaqueta.glb', hood: 'models/gorro_tiburon.glb', tung: 'models/tung.glb',
    tronco: 'models/tronco.glb', monedas: 'models/monedas.glb', arbA: 'models/arboles_a.glb', arbB: 'models/arboles_b.glb', arbC: 'models/arboles_c.glb', ciudad: 'models/ciudad.glb',
  }, p => { $('#loadBar').style.width = Math.round(p * 100) + '%'; });
  $('#loadTxt').textContent = 'Preparando la selva…';
  await new Promise(r => setTimeout(r, 30));
  PN = new Particles(260, false); PA = new Particles(360, true);
  player = new M.Shrimp(A); scene.add(player.root);
  await player.use((CHARS.find(c => c.id === save.eq.chars) || CHARS[0]).model);
  player.shadow = M.blob(1.1, 1.9); scene.add(player.shadow);
  tung = new M.Tung(A.tung); scene.add(tung.root); tung.root.rotation.y = Math.PI;
  tung.shadow = M.blob(1.6, 1.4); scene.add(tung.shadow);
  buildProps();
  buildCoins();
  env.selva = buildSelva(); env.ciudad = buildCiudad();
  applyLook();
  setMap(Q.get('map') || save.eq.maps);
  $('#loading').hidden = true;
  if (Q.has('coins')) save.bank = +Q.get('coins');
  if (Q.get('map')) save.eq.maps = Q.get('map');
  if (Q.get('char')) save.eq.chars = Q.get('char');
  if (Q.get('hat')) save.eq.hats = Q.get('hat');
  if (Q.get('skin')) save.eq.skins = Q.get('skin');
  toMenu();
  if (Q.get('view') === 'shop') openShop(Q.get('tab') || 'chars');
  if (Q.get('view') === 'run' || Q.has('auto')) startRun();
  requestAnimationFrame(loop);
  if (Q.has('shot')) testShot();
}

/* ---------- prototipos de objetos ---------- */
const P = {};
function treeProtos(gltf, parent, filter = () => true, height = [4, 6.5]) {
  const names = M.childrenOf(gltf, parent).filter(filter);
  return names.map(n => { const g = M.pick(gltf, n); if (!g || !g.children.length) return null; const w = M.normalize(g, { height: rnd(...height) }); w.userData.name = n; return w; }).filter(Boolean);
}
function buildProps() {
  // troncos a partir del modelo: largo en x
  const t = A.tronco.scene; t.updateMatrixWorld(true);
  const tg = new THREE.Group(); t.traverse(o => { if (o.isMesh) { const m = new THREE.Mesh(o.geometry.clone().applyMatrix4(o.matrixWorld), M.bend(o.material)); tg.add(m); } });
  const bb = new THREE.Box3().setFromObject(tg), c = bb.getCenter(new THREE.Vector3()), sz = bb.getSize(new THREE.Vector3());
  tg.children.forEach(m => m.geometry.translate(-c.x, -bb.min.y, -c.z));
  P.log = (len, h) => { const g = tg.clone(); g.scale.set(len / sz.x, h / sz.y, (h * 1.1) / sz.z); return g; };
  // árboles
  P.trees = [
    ...treeProtos(A.arbA, 'RootNode', n => !/007/.test(n), [4.5, 7]).slice(0, 6),
    ...treeProtos(A.arbB, 'RootNode', () => true, [4, 6.5]).filter((_, i) => i % 3 === 0).slice(0, 5),
  ];
  P.toon = treeProtos(A.arbC, 'RootNode', n => /^(Tree|FirTree)/.test(n), [3.5, 5.5]).filter((_, i) => i % 3 === 0).slice(0, 4);
  P.stumps = treeProtos(A.arbC, 'RootNode', n => /^Log/.test(n), [.6, .8]);
  P.rocks = [0, 1, 2].map(() => M.bake(M.rock(1)));
  P.cars = [0, 1, 2, 3, 4, 5].map(i => M.bake(M.car(undefined, false)));
  P.bus = M.bake(M.car(0x2f7cff, true));
  P.barrier3 = M.bake(M.barrier(4.0)); P.barrier1 = M.bake(M.barrier(1.2));
  P.over3 = M.bake(M.overhead(3.9, .74));
  P.cone = M.bake(M.cone());
  // barra alta de la selva: tronco sobre dos postes con lianas
  const bar = new THREE.Group(); const beam = P.log(4.8, .42); beam.position.y = .74; bar.add(beam);
  for (const s of [-1, 1]) { const post = P.log(1.2, .34); post.rotation.z = Math.PI / 2; post.position.set(s * 2.35, .6, 0); bar.add(post); }
  const vine = M.bend(M.std(0x2f8a3a, { roughness: .8 }));
  for (let i = 0; i < 7; i++) { const v = new THREE.Mesh(new THREE.CylinderGeometry(.025, .02, rnd(.25, .5), 5), vine); v.position.set(-1.9 + i * .63 + rnd(-.1, .1), .74 - .12, rnd(-.1, .1)); v.geometry.translate(0, -v.geometry.parameters.height / 2, 0); bar.add(v); const lf = new THREE.Mesh(new THREE.IcosahedronGeometry(.07, 0), vine); lf.position.copy(v.position); lf.position.y -= v.geometry.parameters.height; bar.add(lf); }
  P.jungleBar = M.bake(bar);
  // potenciadores: modelo 3D que gira y flota, con un aro de luz en el suelo
  P.orb = {};
  for (const u of UPGRADES) {
    const g = new THREE.Group(), m = M.powerModel(u.id);
    m.scale.setScalar(1.55); g.add(m);
    const ring = new THREE.Mesh(new THREE.RingGeometry(.5, .72, 36), M.bend(new THREE.MeshBasicMaterial({ color: m.userData.col, transparent: true, opacity: .6, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })));
    ring.rotation.x = -Math.PI / 2; ring.position.y = .03; g.add(ring);
    g.userData.col = m.userData.col;
    P.orb[u.id] = g;
  }
}

/* ---------- monedas (instanciadas) ---------- */
let coinIM, coins = [];
function buildCoins() {
  let g = M.pick(A.monedas, 'Coin_17');
  const mesh = g.children[0]; const geo = mesh.geometry.clone(); geo.computeBoundingBox();
  const bb = geo.boundingBox, c = bb.getCenter(new THREE.Vector3()), s = bb.getSize(new THREE.Vector3());
  geo.translate(-c.x, -c.y, -c.z);
  const thin = s.x < s.y && s.x < s.z ? 'x' : s.y < s.z ? 'y' : 'z';
  if (thin === 'x') geo.rotateY(Math.PI / 2); else if (thin === 'y') geo.rotateX(Math.PI / 2);
  geo.computeBoundingBox(); const s2 = geo.boundingBox.getSize(new THREE.Vector3()); const k = .44 / Math.max(s2.x, s2.y); geo.scale(k, k, k);
  const mat = mesh.material.clone(); mat.emissive = new THREE.Color(0x6b4a00); mat.emissiveIntensity = .6; mat.metalness = .6; mat.roughness = .3;
  coinIM = new THREE.InstancedMesh(geo, M.bend(mat), 220); coinIM.frustumCulled = false; coinIM.count = 0; scene.add(coinIM);
}
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _v = new THREE.Vector3(), _s = new THREE.Vector3(1, 1, 1);
function drawCoins() {
  let n = 0; _e.set(0, T * 4, 0); _q.setFromEuler(_e);
  for (const c of coins) { if (!c.alive || c.z < -175) continue; _v.set(c.x, c.y + .45 + Math.sin(T * 5 + c.z) * .05, c.z); _s.setScalar(c.pop ? 1 + c.pop : 1); _m.compose(_v, _q, _s); coinIM.setMatrixAt(n++, _m); if (n >= 220) break; }
  coinIM.count = n; coinIM.instanceMatrix.needsUpdate = true;
}

/* ---------- mapas ---------- */
function groundTex(draw, w = 256, h = 256) { const t = M.canvasTex(w, h, draw); return t; }
function farBand(draw, radius = 420, height = 130, y = 18) {
  const tex = M.canvasTex(2048, 256, draw, false); tex.wrapS = THREE.RepeatWrapping;
  const m = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, height, 48, 1, true), new THREE.MeshBasicMaterial({ map: tex, transparent: true, side: THREE.BackSide, fog: false, depthWrite: false }));
  m.position.y = y; return m;
}
function buildSelva() {
  const E = { id: 'selva', group: new THREE.Group(), far: new THREE.Group(), scroll: [] };
  E.look = { top: 0x3f8fd8, mid: 0xffe0a6, bot: 0x6f8f4a, fog: 0xc9dcc0, fogN: 30, fogF: 125, hemiS: 0xe8f4ff, hemiG: 0x4a5a2a, hemiI: 1.9, sun: 0xffe7bf, sunI: 2.4 };
  // hierba
  const grass = groundTex((c, w, h) => { c.fillStyle = '#5e9a3c'; c.fillRect(0, 0, w, h); M.noise(c, w, h, 900, ['#6fae47', '#4f8a32', '#7cbc52', '#56923a'], 2, 9, .7); M.noise(c, w, h, 40, ['#8fca5c', '#e8e27a'], 1, 3, .9); });
  grass.repeat.set(24, 36);
  const gm = new THREE.Mesh(new THREE.PlaneGeometry(130, 190, 12, 90), M.bend(new THREE.MeshStandardMaterial({ map: grass, roughness: 1 })));
  gm.rotation.x = -Math.PI / 2; gm.position.z = -80; E.group.add(gm); E.scroll.push([grass, 190 / 36]);
  // camino de tierra con piedras
  const path = groundTex((c, w, h) => {
    c.fillStyle = '#b08858'; c.fillRect(0, 0, w, h); M.noise(c, w, h, 700, ['#a07848', '#c29a66', '#98703f', '#b89060'], 2, 10, .6);
    M.noise(c, w, h, 45, ['#8f8a80', '#a8a296', '#7a756c'], 5, 13, .95);
    const g = c.createLinearGradient(0, 0, w, 0); g.addColorStop(0, 'rgba(60,40,20,.55)'); g.addColorStop(.1, 'rgba(60,40,20,0)'); g.addColorStop(.9, 'rgba(60,40,20,0)'); g.addColorStop(1, 'rgba(60,40,20,.55)'); c.fillStyle = g; c.fillRect(0, 0, w, h);
    c.fillStyle = 'rgba(80,55,25,.18)'; for (const x of [w / 3, 2 * w / 3]) c.fillRect(x - 3, 0, 6, h);
  }, 256, 256);
  path.repeat.set(1, 36);
  const pm = new THREE.Mesh(new THREE.PlaneGeometry(4.8, 190, 1, 90), M.bend(new THREE.MeshStandardMaterial({ map: path, roughness: 1 })));
  pm.rotation.x = -Math.PI / 2; pm.position.set(0, .012, -80); E.group.add(pm); E.scroll.push([path, 190 / 36]);
  // bordillos de piedra, árboles, arbustos, flores
  const side = () => Math.random() < .5 ? -1 : 1;
  E.scatters = [
    new Scatter(P.rocks.map(r => { const g = r.clone(); g.scale.setScalar(.45); return g; }), 70, (it) => { it.x = side() * rnd(2.55, 2.9); it.ry = rnd(0, 6); it.s = rnd(.6, 1.2); }),
    new Scatter([...P.trees, ...P.toon], 110, (it) => { it.x = side() * rnd(3.6, 22); it.ry = rnd(0, 6); it.s = rnd(.8, 1.35); }),
    new Scatter([0, 1, 2].map(i => M.bush([0x3f8f3a, 0x2f7a33, 0x5aa03a][i])), 60, (it) => { it.x = side() * rnd(3, 9); it.ry = rnd(0, 6); it.s = rnd(.7, 1.4); }),
    new Scatter([0, 1, 2].map(() => M.flower()), 90, (it) => { it.x = side() * rnd(2.9, 8); it.ry = rnd(0, 6); it.s = rnd(.8, 1.5); }),
  ];
  E.scatters.forEach((s, i) => { if (!Q.has('solo') || +Q.get('solo') === i) E.group.add(s.group); });
  // montañas al fondo
  E.far.add(farBand((c, w, h) => {
    for (const [col, amp, base, fq] of [['#9fc3b0', 60, 150, 3], ['#7fae8e', 45, 185, 5], ['#5f9470', 30, 215, 9]]) {
      c.fillStyle = col; c.beginPath(); c.moveTo(0, h);
      for (let x = 0; x <= w; x += 8) c.lineTo(x, base - amp * (.5 + .5 * Math.sin(x / w * Math.PI * 2 * fq + fq)) * (.7 + .3 * Math.sin(x / w * Math.PI * 2 * fq * 2.3)));
      c.lineTo(w, h); c.fill();
    }
  }));
  E.update = d => { for (const [t, len] of E.scroll) t.offset.y = (t.offset.y + d / len) % 1; E.scatters.forEach(s => s.update(d)); };
  // obstáculos
  E.make = {
    jump3: () => ({ mesh: P.log(4.6, .58), dz: .35 }),
    jump1: () => ({ mesh: P.log(1.3, .5), dz: .3 }),
    slide3: () => ({ mesh: P.jungleBar.clone(), dz: .25 }),
    block: () => { const r = Math.random(); if (r < .65) { const g = P.rocks[Math.floor(rnd(0, P.rocks.length))].clone(); g.scale.set(1.05, rnd(1.1, 1.5), 1); g.rotation.y = rnd(0, 6); return { mesh: g, dz: .55 }; } const s = P.stumps.length ? P.stumps[Math.floor(rnd(0, P.stumps.length))].clone() : P.rocks[0].clone(); s.scale.multiplyScalar(1.6); return { mesh: s, dz: .5 }; },
  };
  scene.add(E.group); far.add(E.far);
  return E;
}
function buildCiudad() {
  const E = { id: 'ciudad', group: new THREE.Group(), far: new THREE.Group(), scroll: [] };
  E.look = { top: 0x2f7fd6, mid: 0xd6ecff, bot: 0x9aa7b3, fog: 0xcfe0ee, fogN: 35, fogF: 140, hemiS: 0xeaf4ff, hemiG: 0x6a6f78, hemiI: 2.1, sun: 0xfff3dc, sunI: 2.4 };
  // asfalto con líneas de carril
  const road = groundTex((c, w, h) => {
    c.fillStyle = '#3d4148'; c.fillRect(0, 0, w, h); M.noise(c, w, h, 900, ['#454a52', '#363a40', '#4c5159'], 1, 4, .6);
    c.fillStyle = '#f4f4f4'; for (const x of [w * 0.04, w * .96]) c.fillRect(x - 3, 0, 6, h);
    c.fillStyle = '#f2f2f2'; for (const x of [w * .3645, w * .6355]) c.fillRect(x - 3, h * .1, 6, h * .45);
  }, 256, 256);
  road.repeat.set(1, 40);
  const rm = new THREE.Mesh(new THREE.PlaneGeometry(5.6, 190, 1, 90), M.bend(new THREE.MeshStandardMaterial({ map: road, roughness: .9 })));
  rm.rotation.x = -Math.PI / 2; rm.position.set(0, .02, -80); E.group.add(rm); E.scroll.push([road, 190 / 40]);
  // bloques de ciudad recortados del «Low Poly City Pack» (103 m cada uno), en bucle
  const chunk = A.ciudad.scene; chunk.traverse(o => { if (o.isMesh) { M.bend(o.material); o.frustumCulled = false; } });
  const LEN = 103.2; E.chunks = [];
  for (let i = 0; i < 3; i++) { const c = i ? chunk.clone() : chunk; c.position.z = 14 - LEN / 2 - i * LEN; if (i % 2) c.scale.x = -1; E.group.add(c); E.chunks.push(c); }
  const base = new THREE.Mesh(new THREE.PlaneGeometry(400, 400, 20, 60), M.bend(new THREE.MeshStandardMaterial({ color: 0xa9b3a0, roughness: 1 }))); base.rotation.x = -Math.PI / 2; base.position.set(0, -.35, -120); E.group.add(base);
  E.scatters = [
    new Scatter([M.lamp()], 16, (it, first) => { it.x = (it.side = it.side || (Math.random() < .5 ? -1 : 1)) * 3.25; it.ry = it.side > 0 ? 0 : Math.PI; }, 176),
    new Scatter([P.cone], 24, (it) => { it.x = (Math.random() < .5 ? -1 : 1) * rnd(3.05, 3.3); it.ry = rnd(0, 6); }),
  ];
  E.scatters.forEach(s => E.group.add(s.group));
  E.far.add(farBand((c, w, h) => {
    for (const [col, hmin, hmax, bw] of [['#b9cde0', 50, 150, 34], ['#9fb6cc', 30, 110, 26]]) {
      c.fillStyle = col; let x = 0;
      while (x < w) { const bh = rnd(hmin, hmax), ww = rnd(bw * .6, bw * 1.4); c.fillRect(x, h - bh - 20, ww, bh + 20); if (Math.random() < .3) c.fillRect(x + ww / 2 - 2, h - bh - 40, 4, 22); x += ww + rnd(0, 6); }
    }
  }, 420, 130, 22));
  E.update = d => {
    for (const [t, len] of E.scroll) t.offset.y = (t.offset.y + d / len) % 1;
    for (const c of E.chunks) { c.position.z += d; if (c.position.z - LEN / 2 > 14) c.position.z -= LEN * 3; }
    E.scatters.forEach(s => s.update(d));
  };
  E.make = {
    jump3: () => ({ mesh: P.barrier3.clone(), dz: .3 }),
    jump1: () => Math.random() < .5 ? { mesh: P.barrier1.clone(), dz: .3 } : { mesh: (() => { const g = new THREE.Group(); for (const x of [-.35, 0, .35]) { const c = P.cone.clone(); c.position.x = x; g.add(c); } return g; })(), dz: .25 },
    slide3: () => ({ mesh: P.over3.clone(), dz: .2 }),
    block: (moving) => { if (!moving && Math.random() < .12) { const b = P.bus.clone(); return { mesh: b, dz: 2.6 }; } const c = P.cars[Math.floor(rnd(0, P.cars.length))].clone(); if (!moving) c.rotation.y = Math.PI; return { mesh: c, dz: 1.25 }; },
  };
  scene.add(E.group); far.add(E.far);
  return E;
}
function applyLook() {
  const L = curMap ? env[curMap].look : env.selva.look;
  skyMat.uniforms.top.value.set(L.top); skyMat.uniforms.mid.value.set(L.mid); skyMat.uniforms.bot.value.set(L.bot);
  scene.fog.color.set(L.fog); scene.fog.near = L.fogN; scene.fog.far = L.fogF;
  hemi.color.set(L.hemiS); hemi.groundColor.set(L.hemiG); hemi.intensity = L.hemiI; sun.color.set(L.sun); sun.intensity = L.sunI;
  R.setClearColor(L.fog);
}
function setMap(id) {
  if (!env[id]) id = 'selva';
  curMap = id;
  for (const [k, E] of Object.entries(env)) { E.group.visible = k === id; E.far.visible = k === id; }
  applyLook();
  $('#mapIco').textContent = MAPS.find(m => m.id === id).icon; $('#mapName').textContent = MAPS.find(m => m.id === id).name.split(' ')[0];
}

/* ---------- aspecto del jugador ---------- */
let look = {};
function applyEquip(p = save.eq) {
  look = Object.assign({}, p);
  const ch = CHARS.find(c => c.id === p.chars) || CHARS[0];
  player.setSkin((SKINS.find(s => s.id === p.skins) || SKINS[0]).p);
  player.hatId = p.hats;
  return player.use(ch.model);
}

/* ---------- estelas ---------- */
const TRAIL_FX = {
  polvo: (x, y, z) => { if ((G && G.y > .05) || Math.random() < .5) return; PN.emit(x + rnd(-.3, .3), .06, z + .7, rnd(-.4, .4), rnd(.3, .8), rnd(.2, .8), C(curMap === 'ciudad' ? 0xb8bcc2 : 0xc9b08a), rnd(.07, .12), rnd(.25, .4), 0, .8); },
  burbujas: (x, y, z) => PN.emit(x + rnd(-.3, .3), y + rnd(.2, .6), z + .8, rnd(-.2, .2), rnd(.6, 1.4), rnd(.3, 1), C(0xbfeaff), rnd(.15, .32), rnd(.7, 1.2), -.4, .3),
  chispas: (x, y, z) => PA.emit(x + rnd(-.25, .25), y + rnd(.2, .6), z + .8, rnd(-1, 1), rnd(0, 2), rnd(0, 1), C(0xffe27a), rnd(.08, .16), rnd(.3, .6), 3),
  corazones: (x, y, z) => PN.emit(x + rnd(-.3, .3), y + rnd(.3, .7), z + .8, rnd(-.3, .3), rnd(.5, 1.2), rnd(.2, .8), C([0xff4d8d, 0xff7ab0, 0xff2e63][Math.floor(rnd(0, 3))]), rnd(.18, .3), rnd(.6, 1), -.3),
  hielo: (x, y, z) => PA.emit(x + rnd(-.3, .3), y + rnd(.1, .6), z + .8, rnd(-.4, .4), rnd(-.2, .6), rnd(.2, 1), C([0xbfefff, 0x7fd6ff, 0xffffff][Math.floor(rnd(0, 3))]), rnd(.1, .2), rnd(.5, .9), .5),
  fuego: (x, y, z) => { PA.emit(x + rnd(-.2, .2), y + rnd(.15, .45), z + .8, rnd(-.3, .3), rnd(1, 2.2), rnd(.3, 1.2), C([0xff5a1a, 0xffa31a, 0xffd23f][Math.floor(rnd(0, 3))]), rnd(.2, .34), rnd(.3, .55), -1, -.6); },
  arcoiris: (x, y, z) => PA.emit(x + rnd(-.15, .15), y + .35 + rnd(-.1, .1), z + .8, 0, 0, rnd(.5, 1), new THREE.Color().setHSL((T * .6) % 1, .9, .6), .26, .7, 0, -.3),
};

/* ---------- partida ---------- */
function newGame() {
  const g = {
    t: 0, lane: 1, prevLane: 1, px: 0, y: 0, vy: 0, slideT: 0, speed: 11, dist: 0, score: 0, coins: 0, obs: [], nextRow: -26, stumble: 0, chase: 12, tungT: 4,
    shake: 0, pw: {}, nextPw: rnd(140, 220) / (1 + level('suerte') * .18), ph: 0, over: false, paused: false, revives: 0, inv: 0, row: 0, airT: 0, flip: 0, bump: 0,
  };
  for (const c of coins) c.alive = false; coins.length = 0;
  for (const o of (G ? G.obs : [])) scene.remove(o.mesh);
  return g;
}
function startRun() {
  if (G) for (const o of G.obs) scene.remove(o.mesh);
  G = newGame();
  applyEquip();
  // objetos de un solo uso elegidos en el menú
  for (const it of ['cohete', 'escudoIni', 'dobleIni']) if (save.use[it] && (save.items[it] || 0) > 0) {
    save.items[it]--; if (it === 'cohete') G.pw.turbo = { t: 7 + upDur(UPGRADES[4]), max: 7 + upDur(UPGRADES[4]) }; if (it === 'escudoIni') G.pw.escudo = { t: 30, max: 30 }; if (it === 'dobleIni') G.pw.x2 = { t: 20, max: 20 };
    if (!save.items[it]) save.use[it] = false;
  }
  persist();
  while (G.nextRow > -160) { spawnRow(G.nextRow); G.nextRow -= rowGap(); }
  mode = 'run';
  for (const s of ['#menu', '#over', '#paused', '#shop']) $(s).hidden = true;
  $('#hud').hidden = false;
  player.root.position.set(0, 0, 0); player.tilt.rotation.set(0, 0, 0); player.tilt.scale.set(1, 1, 1);
  tung.root.rotation.y = Math.PI;
  setMusic(true); ac();
  updHud(true);
}
const rowGap = () => Math.max(11, G.speed * .95) + rnd(0, 7) - Math.min(3, G.t * .02);

// patrones de fila: cada entrada es [tipo, carriles]; siempre queda al menos un carril practicable
function spawnRow(z) {
  const E = env[curMap], d = G.dist + (-z);
  G.row++;
  const L = [0, 1, 2].sort(() => Math.random() - .5);
  const hard = clamp(d / 1500, 0, 1);
  const pats = [
    [3, [['jump3', [0, 1, 2]]]],
    [3, [['slide3', [0, 1, 2]]]],
    [4, [['block', [L[0]]]]],
    [3 + hard * 3, [['block', [L[0]]], ['block', [L[1]]]]],
    [2 + hard * 3, [['block', [L[0]]], ['jump1', [L[1]]]]],
    [2 + hard * 2, [['block', [L[0]]], ['block', [L[1]]], ['jump1', [L[2]]]]],
    [2, [['jump1', [L[0]]], ['jump1', [L[1]]]]],
  ];
  if (curMap === 'ciudad' && d > 250) pats.push([2 + hard * 4, [['car', [L[0]]]]]);
  let tot = pats.reduce((a, p) => a + p[0], 0), r = Math.random() * tot, pat = pats[0];
  for (const p of pats) { if ((r -= p[0]) <= 0) { pat = p; break; } }
  const laneKind = [null, null, null];
  for (const [kind, lanes] of pat[1]) {
    const moving = kind === 'car';
    const b = (kind === 'jump3' || kind === 'slide3') ? E.make[kind]() : E.make[kind === 'car' ? 'block' : kind](moving);
    const x = lanes.length === 3 ? 0 : LX[lanes[0]];
    b.mesh.position.set(x, 0, z);
    scene.add(b.mesh);
    const type = kind.startsWith('jump') ? 'jump' : kind.startsWith('slide') ? 'slide' : 'block';
    G.obs.push({ type, lanes, z, dz: b.dz, mesh: b.mesh, vz: moving ? 7 + hard * 4 : 0, kind });
    for (const l of lanes) laneKind[l] = type;
  }
  // monedas
  const free = [0, 1, 2].filter(l => laneKind[l] !== 'block');
  const cl = free[Math.floor(rnd(0, free.length))];
  const k = laneKind[cl];
  if (G.dist - z > G.nextPw && free.length) {   // potenciador en vez de monedas
    G.nextPw += rnd(260, 420) / (1 + level('suerte') * .18);
    const u = UPGRADES[Math.floor(rnd(0, UPGRADES.length))];
    const o = P.orb[u.id].clone(); o.position.set(LX[cl], k === 'jump' ? 1 : 0, z + (k ? 6 : 0)); scene.add(o);
    G.obs.push({ type: 'pw', id: u.id, lanes: [cl], z: z + (k ? 6 : 0), dz: .5, mesh: o, vz: 0 });
    return;
  }
  if (Math.random() < .85) {
    if (k === 'jump') for (let i = -3; i <= 3; i++) coins.push({ x: LX[cl], y: .35 + 1.05 * (1 - (i / 3.6) ** 2), z: z + i * 1.05, alive: true });
    else if (k === 'slide') for (let i = -3; i <= 3; i++) coins.push({ x: LX[cl], y: 0, z: z + i * 1.1, alive: true });
    else for (let i = 0; i < 6; i++) coins.push({ x: LX[cl], y: 0, z: z + 3 + i * 1.3, alive: true });
  }
}

/* ---------- controles ---------- */
let tx0 = 0, ty0 = 0, tDone = true, tT = 0;
addEventListener('touchstart', e => { if (mode !== 'run') return; tx0 = e.touches[0].clientX; ty0 = e.touches[0].clientY; tDone = false; tT = performance.now(); ac(); }, { passive: true });
addEventListener('touchmove', e => {
  if (tDone || mode !== 'run' || !G || G.paused) return;
  const dx = e.touches[0].clientX - tx0, dy = e.touches[0].clientY - ty0;
  if (Math.max(Math.abs(dx), Math.abs(dy)) < 26) return; tDone = true;
  Math.abs(dx) > Math.abs(dy) ? move(dx > 0 ? 1 : -1) : dy < 0 ? jump() : slide();
}, { passive: true });
addEventListener('keydown', e => { if (mode !== 'run' || !G) return; const f = { ArrowLeft: () => move(-1), ArrowRight: () => move(1), ArrowUp: jump, ArrowDown: slide, ' ': jump, Escape: pause }[e.key]; if (f) { e.preventDefault(); f(); } });
function move(d) { const n = clamp(G.lane + d, 0, 2); if (n !== G.lane) { G.prevLane = G.lane; G.lane = n; S.lane(); buzz(); } else { G.bump = .25 * d; } }
function jump() { if (G.y <= .02) { G.vy = G.pw.salto ? 12.5 : 8.6; G.slideT = 0; S.jump(); buzz(); G.flip = G.pw.salto ? 1 : 0; } }
function slide() { if (G.y > .02) G.vy = -16; G.slideT = .7; S.slide(); buzz(); }

/* ---------- paso de simulación ---------- */
function step(dt) {
  const g = G; g.t += dt;
  const turbo = !!g.pw.turbo;
  const base = Math.min(26, 11 + g.t * .13);
  g.speed = lerp(g.speed, turbo ? base * 1.55 + 4 : g.stumble > 0 ? base * .9 : base, Math.min(1, dt * 3));
  const d = g.speed * dt; g.dist += d; g.score += d * scoreMult() * (turbo ? 1.5 : 1);
  g.ph += dt * (6 + g.speed * .45);
  // lateral, salto, deslizamiento
  g.px = lerp(g.px, LX[g.lane] + g.bump, Math.min(1, dt * 13)); g.bump *= Math.pow(.02, dt);
  g.vy -= (g.pw.salto ? 24 : 27) * dt; g.y = Math.max(0, g.y + g.vy * dt); if (g.y === 0 && g.vy < 0) { if (g.airT > .25) { for (let i = 0; i < 8; i++) PN.emit(g.px + rnd(-.5, .5), .05, rnd(-.6, .6), rnd(-1.5, 1.5), rnd(.3, 1), rnd(-.5, .5), C(curMap === 'ciudad' ? 0x9aa0a8 : 0xc9b08a), .35, .5, 0, 1.2); } g.vy = 0; g.airT = 0; } else if (g.y > 0) g.airT += dt;
  g.slideT = Math.max(0, g.slideT - dt);
  g.stumble = Math.max(0, g.stumble - dt); g.shake = Math.max(0, g.shake - dt); g.inv = Math.max(0, g.inv - dt);
  for (const [k, p] of Object.entries(g.pw)) { p.t -= dt; if (p.t <= 0) delete g.pw[k]; }
  // Tung
  const want = g.stumble > 0 ? 3.3 : 13;
  g.chase = lerp(g.chase, want, Math.min(1, dt * (g.stumble > 0 ? 2.2 : .6)));
  g.tungT -= dt; if (g.tungT <= 0) { g.tungT = g.stumble > 0 ? 1.3 : rnd(7, 12); if (g.stumble > 0 || Math.random() < .55) tungShout(); }
  // mundo
  env[curMap].update(d);
  for (const o of g.obs) { o.z += d + o.vz * dt; o.mesh.position.z = o.z; if (o.fly) { o.fly.t += dt; o.mesh.position.y += o.fly.vy * dt; o.fly.vy -= 20 * dt; o.mesh.position.x += o.fly.vx * dt; o.mesh.rotation.x += o.fly.r * dt; } if (o.type === 'pw') { const m0 = o.mesh.children[0]; m0.rotation.y = T * 2.2; m0.position.y = .12 + Math.sin(T * 3) * .09; } }
  for (const c of coins) {
    c.z += d;
    if (!c.alive) continue;
    if ((g.pw.iman && c.z > -16 && c.z < 1) || c.mag) { c.mag = true; c.x = lerp(c.x, g.px, Math.min(1, dt * 9)); c.y = lerp(c.y, g.y, Math.min(1, dt * 9)); c.z = lerp(c.z, 0, Math.min(1, dt * 7)); }
    if (Math.abs(c.z) < .75 && Math.abs(c.x - g.px) < .75 && Math.abs(c.y - g.y) < 1) {
      c.alive = false; const v = g.pw.x2 ? 2 : 1; g.coins += v; S.coin();
      for (let i = 0; i < 6; i++) PA.emit(c.x, c.y + .5, c.z, rnd(-1.5, 1.5), rnd(0, 2.5), rnd(-1, 1), C(0xffd84a), .16, .35, 4);
    }
  }
  if (coins.length > 400) coins = coins.filter(c => c.alive && c.z < 3);
  g.nextRow += d; while (g.nextRow > -160) { spawnRow(g.nextRow); g.nextRow -= rowGap(); }
  // colisiones
  for (const o of g.obs) {
    if (o.hit || o.z - o.dz > .6 || o.z + o.dz < -.6) continue;
    const inLane = o.lanes.length === 3 || o.lanes.some(l => Math.abs(g.px - LX[l]) < (o.type === 'block' ? .6 : .72));
    if (!inLane) continue;
    if (o.type === 'pw') { o.hit = true; scene.remove(o.mesh); powerUp(o.id); continue; }
    if (turbo || g.inv > 0) { knock(o); continue; }
    if (o.type === 'jump') { if (g.y > .45) continue; stumble(o); continue; }
    if (o.type === 'slide') { if (g.slideT > 0 && g.y < .5) continue; stumble(o); continue; }
    // bloque: si vienes de lado te rebota; de frente te estampas
    const lateral = Math.abs(g.px - LX[g.lane]) > .3 && !o.lanes.includes(g.lane);
    if (lateral) { g.lane = g.prevLane === g.lane ? clamp(g.lane + (g.px < LX[g.lane] ? 1 : -1), 0, 2) : g.prevLane; stumble(o, true); continue; }
    if (g.pw.escudo) { delete g.pw.escudo; S.shield(); knock(o); g.inv = 1; flash(0x4fb2ff); continue; }
    return die('crash');
  }
  // limpiar
  for (const o of g.obs) if (o.z - o.dz > 12 || (o.fly && o.fly.t > 2)) { scene.remove(o.mesh); o.dead = true; }
  g.obs = g.obs.filter(o => !o.dead);
  // estela
  const fx = TRAIL_FX[look.trails] || TRAIL_FX.polvo; if (Math.random() < (look.trails === 'polvo' ? .7 : .9)) fx(g.px, g.y, 0);
  if (turbo) PA.emit(g.px + rnd(-.3, .3), g.y + .3, .9, 0, rnd(0, .5), 4, C(0xb45aff), .3, .3);
  PN.update(dt, d); PA.update(dt, d);
}
function knock(o) { o.hit = true; o.fly = { t: 0, vy: rnd(5, 8), vx: rnd(-3, 3), r: rnd(-8, 8) }; S.bonk(); G.shake = .2; buzz('MEDIUM'); }
function stumble(o, side) {
  o.hit = true; G.log = (G.log || '') + ` T:${o.kind}@${Math.floor(G.dist)}${side ? 's' : ''}`;
  if (G.pw.escudo) { delete G.pw.escudo; S.shield(); knock(o); flash(0x4fb2ff); return; }
  if (G.stumble > 0) return die('caught');
  G.stumble = 3.4 - level('aguante') * .35; G.shake = .35; S.hit(); buzz('HEAVY'); G.tungT = 0; flash(0xff3b3b);
  if (!side && o.type !== 'block') knock(o);
}
function powerUp(id) {
  const u = UPGRADES.find(x => x.id === id), dur = upDur(u);
  G.pw[id] = { t: dur, max: dur }; S.power(); buzz('MEDIUM');
  toast(`${u.icon} ${u.name}`);
  for (let i = 0; i < 24; i++) PA.emit(G.px, G.y + .6, 0, rnd(-3, 3), rnd(0, 4), rnd(-3, 3), C(P.orb[id].userData.col), .22, .6, 3);
}
let flashT = 0, flashCol = new THREE.Color();
function flash(c) { flashT = .25; flashCol.set(c); }
function tungShout() { S.tung(); const t = $('#tungTxt'); t.classList.remove('on'); void t.offsetWidth; t.classList.add('on'); }

/* ---------- muerte y final ---------- */
let dieT = 0, dieWhy = '';
function die(why) {
  if (mode !== 'run') return;
  mode = 'dying'; dieT = 0; dieWhy = why; G.over = true; G.log = (G.log || '') + ` X:${why}@${Math.floor(G.dist)}`;
  S.hit(); buzz('HEAVY'); tungShout(); setMusic(false);
  G.dieX = G.px; G.vy = 0; G.flying = false; G.chase = Math.min(G.chase, why === 'crash' ? 6 : 3.1);
}
function finish() {
  mode = 'over';
  const bonus = 1 + level('valor') * .2, got = Math.round(G.coins * bonus);
  const sc = Math.floor(G.score), d = Math.floor(G.dist), rec = sc > save.best;
  if (rec) save.best = sc; save.bestD = Math.max(save.bestD, d);
  save.bank += got; save.stats.runs++; save.stats.coins += got; save.stats.dist += d; persist();
  $('#oScore').textContent = sc.toLocaleString('es'); $('#oDist').textContent = d + ' m'; $('#oCoins').textContent = got + (bonus > 1 ? ` (+${Math.round((bonus - 1) * 100)}%)` : '');
  $('#oBest').textContent = save.best.toLocaleString('es'); $('#oRec').hidden = !rec;
  const lives = save.items.vida || 0; $('#reviveBtn').hidden = !(lives > 0 && G.revives < 3); $('#reviveN').textContent = lives;
  G.got = got;
  $('#hud').hidden = true; $('#over').hidden = false;
  if (rec) { S.buy(); }
}
function revive() {
  if (!(save.items.vida > 0)) return;
  save.items.vida--; persist();
  save.bank -= G.got; save.stats.runs--; // la partida sigue: las monedas se cuentan al final
  G.revives++; G.over = false; G.stumble = 0; G.chase = 13; G.inv = 3; G.y = 0; G.vy = 0;
  for (const o of G.obs) if (o.z > -30) { scene.remove(o.mesh); o.dead = true; }
  G.obs = G.obs.filter(o => !o.dead);
  player.tilt.rotation.set(0, 0, 0); player.root.position.set(G.px, 0, 0); G.flying = false;
  mode = 'run'; $('#over').hidden = true; $('#hud').hidden = false; setMusic(true); tungShout();
}

/* ---------- cámara y dibujo ---------- */
const camPos = new THREE.Vector3(0, 3, 6.4), camLook = new THREE.Vector3(0, .8, -5), _cp = new THREE.Vector3(), _cl = new THREE.Vector3();
let menuA = 0, shopRot = 0, shopShift = null;
function frame(dt) {
  T += dt; M.SKIN.t.value = T;
  if (mode !== 'shop') { shopShift = null; if (cam.view && cam.view.enabled) cam.clearViewOffset(); }
  const g = G;
  if (mode === 'over') { /* se queda la escena del golpe congelada */ }
  else if (mode === 'run' || mode === 'dying') {
    const x = g.px;
    let m = 'run'; if (g.y > .05) m = 'jump'; if (g.slideT > 0 && g.y < .1) m = 'slide';
    if (mode === 'dying') m = 'dead';
    player.pose(g.ph, m, T, dt, g.speed);
    player.root.position.set(x, g.y, 0);
    const lean = (LX[g.lane] - g.px) * -.35;
    if (mode === 'run') {
      player.tilt.rotation.set(m === 'jump' ? clamp(-g.vy * .03, -.3, .35) + (g.flip ? 0 : 0) : m === 'slide' ? .12 : Math.sin(g.ph * 2) * .04, lean * .6, lean);
      player.tilt.position.y = m === 'run' ? Math.abs(Math.sin(g.ph)) * .07 : 0;
      const sq = m === 'slide' ? .5 : 1; player.tilt.scale.set(1 + (1 - sq) * .3, lerp(player.tilt.scale.y, sq, Math.min(1, dt * 18)), 1 + (1 - sq) * .2);
      if (g.inv > 0) player.root.visible = Math.floor(T * 14) % 2 === 0; else player.root.visible = true;
    }
    // Tung detrás, un poco a la izquierda; cuando está cerca se ve en la parte baja de la pantalla
    const tz = mode === 'dying' ? lerp(tung.root.position.z, 1.25, Math.min(1, dt * 5)) : g.chase;
    const tx = mode === 'dying' ? g.dieX - .9 : x * .55 - (g.chase < 6 ? 1.05 : 0);
    tung.root.position.set(lerp(tung.root.position.x, tx, Math.min(1, dt * 6)), 0, tz);
    tung.root.visible = tz < 10;
    tung.pose(g.ph * .8, mode === 'dying' && dieT > .25 ? 'hit' : 'run', T, dt);
    // cámara
    if (mode === 'run') {
      _cp.set(x * .55, 3.0 + g.y * .3, 6.4); _cl.set(x * .35, .75 + g.y * .4, -5);
      if (g.shake) { _cp.x += rnd(-.12, .12) * g.shake * 4; _cp.y += rnd(-.1, .1) * g.shake * 4; }
      camPos.lerp(_cp, Math.min(1, dt * 8)); camLook.lerp(_cl, Math.min(1, dt * 8));
      M.BEND.x.value = Math.sin(g.dist * .006) * .0012;
    } else {
      dieT += dt;
      _cp.set(g.dieX + 2.6, 1.6, -2.6); _cl.set(g.dieX - .4, 1, .8);
      camPos.lerp(_cp, Math.min(1, dt * 3)); camLook.lerp(_cl, Math.min(1, dt * 3));
      if (dieT > .45) { // golpe: la gamba sale volando
        if (!g.flying) { g.flying = true; g.vy = 7; } g.vy -= 20 * dt; g.y = Math.max(0, g.y + g.vy * dt);
        player.tilt.rotation.z += dt * 9; player.root.position.set(g.dieX + (dieT - .45) * 2.5, g.y, (dieT - .45) * -1.5);
        if (dieT < .5) { for (let i = 0; i < 20; i++) PA.emit(g.dieX, .6, 0, rnd(-3, 3), rnd(0, 4), rnd(-3, 3), C(0xffe27a), .2, .5, 5); S.bonk(); g.shake = .3; }
      }
      PN.update(dt, 0); PA.update(dt, 0);
      if (dieT > 1.7) finish();
    }
    player.shadow.position.set(player.root.position.x, .025, player.root.position.z); player.shadow.scale.setScalar(1 / (1 + g.y * .6));
    tung.shadow.position.set(tung.root.position.x, .025, tung.root.position.z); tung.shadow.visible = tung.root.visible;
    if (mode === 'run') drawCoins(); else coinIM.count = 0;
    updHud();
  } else {
    // menú / tienda / fin: escena quieta con la cámara girando
    menuA += dt * .25;
    player.root.visible = true;
    const idle = mode === 'shop' ? 'cheer' : 'idle';
    player.pose(T * 6, idle, T, dt);
    player.root.position.set(0, 0, 0); player.tilt.position.y = 0; player.tilt.scale.set(1, 1, 1);
    tung.root.visible = mode !== 'shop';
    tung.root.position.set(1.1, 0, 2.6); tung.pose(0, 'idle', T, dt);
    tung.shadow.position.set(1.1, .025, 2.6); tung.shadow.visible = tung.root.visible;
    player.shadow.position.set(0, .025, 0); player.shadow.scale.setScalar(1);
    if (mode === 'shop') {
      shopRot += dt * .6; player.tilt.rotation.set(0, Math.sin(shopRot) * .9 + .3, 0);
      // la gamba se encuadra en el hueco libre entre la cabecera y el panel de la tienda
      const W = innerWidth, H = innerHeight, sheet = $('#shop .sheet'), head = $('#shop .shopHead');
      const hb = head ? head.getBoundingClientRect().bottom + 4 : 80, top = H - (sheet ? sheet.offsetHeight : H * .5);
      const bh = Math.max(120, top - hb), target = H / 2 - (hb + top) / 2;
      shopShift = shopShift === null ? target : lerp(shopShift, target, Math.min(1, dt * 7));
      const tanV = Math.tan(THREE.MathUtils.degToRad(cam.fov) / 2), tanH = tanV * W / H;
      const d = clamp(Math.max(2.7 / (2 * tanH), 1.7 / (2 * tanV * bh / H)), 2.6, 7);
      _cp.set(0, .42 + d * .2, -d * .98); _cl.set(0, .42, 0);
      if (Q.has('cam')) { shopShift = 0; if (Q.get('cam') === 'side') { player.tilt.rotation.set(0, 0, 0); _cp.set(2.6, .7, -.3); _cl.set(0, .45, -.3); } else { player.tilt.rotation.set(0, .5, 0); _cp.set(.4, .9, -2.4); _cl.set(0, .5, 0); } }
      cam.setViewOffset(W, H, 0, shopShift, W, H);
      const fx = look.trails !== 'polvo' && TRAIL_FX[look.trails]; if (fx && Math.random() < .5) fx(0, 0, -.2);
    } else {
      player.tilt.rotation.set(0, Math.sin(T * .7) * .15, 0);
      _cp.set(Math.sin(menuA) * 1.3 - .5, 1.05, -3.6 + Math.cos(menuA) * .3); _cl.set(.3, .95, .8);
    }
    camPos.lerp(_cp, Math.min(1, dt * 3)); camLook.lerp(_cl, Math.min(1, dt * 3));
    M.BEND.x.value = 0;
    PN.update(dt, 0); PA.update(dt, 0);
    coinIM.count = 0;
  }
  cam.position.copy(camPos); cam.lookAt(camLook);
  sky.position.copy(cam.position); far.position.set(cam.position.x, 0, cam.position.z);
  if (flashT > 0) { flashT -= dt; R.setClearColor(flashCol); }
}
function loop() {
  requestAnimationFrame(loop);
  const raw = clock.getDelta(), dt = Math.min(1 / 30, raw); adapt(raw);
  if (mode === 'run' && G && !G.paused) { if (Q.has('auto')) autopilot(); step(dt); }
  if (!(G && G.paused)) frame(dt);
  R.render(scene, cam);
}

/* ---------- HUD ---------- */
let hudCache = {};
function updHud(force) {
  const g = G; if (!g) return;
  const sc = Math.floor(g.score).toLocaleString('es'), co = g.coins, di = Math.floor(g.dist) + ' m', mu = '×' + (scoreMult() * (g.pw.turbo ? 1.5 : 1));
  if (force || hudCache.sc !== sc) $('#hScore').textContent = hudCache.sc = sc;
  if (force || hudCache.co !== co) $('#hCoins b').textContent = hudCache.co = co;
  if (force || hudCache.di !== di) $('#hDist').textContent = hudCache.di = di;
  if (force || hudCache.mu !== mu) $('#hMult').textContent = hudCache.mu = mu;
  const pw = $('#pw'), keys = Object.keys(g.pw).join();
  if (force || hudCache.pw !== keys) { hudCache.pw = keys; pw.innerHTML = Object.keys(g.pw).map(k => `<div class="glass pwi" data-k="${k}">${UPGRADES.find(u => u.id === k).icon}<span class="t"><i></i></span></div>`).join(''); }
  for (const el of pw.children) { const p = g.pw[el.dataset.k]; if (p) el.querySelector('i').style.width = (p.t / p.max * 100) + '%'; }
}
let toastT = 0;
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 1600); }

/* ---------- menú ---------- */
const today = () => new Date().toISOString().slice(0, 10);
function toMenu() {
  mode = 'menu';
  if (G) { for (const o of G.obs) scene.remove(o.mesh); G = null; }
  coins.length = 0;
  applyEquip(); setMap(save.eq.maps);
  for (const s of ['#over', '#paused', '#shop', '#hud', '#settings']) $(s).hidden = true;
  $('#menu').hidden = false;
  $('#mCoins').textContent = save.bank.toLocaleString('es'); $('#mBest').textContent = save.best.toLocaleString('es'); $('#mBestD').textContent = save.bestD + ' m'; $('#mMult').textContent = '×' + scoreMult();
  $('#giftDot').hidden = save.daily.last === today();
  renderBoosts();
  setMusic(true);
}
function renderBoosts() {
  const b = $('#boosts');
  b.innerHTML = ITEMS.filter(i => i.id !== 'vida' && (save.items[i.id] || 0) > 0).map(i => `<button class="boost ${save.use[i.id] ? 'on' : ''}" data-id="${i.id}">${i.icon} ${i.name} <i>×${save.items[i.id]}</i></button>`).join('')
    + ((save.items.vida || 0) > 0 ? `<span class="boost">❤️‍🩹 Salvavidas <i>×${save.items.vida}</i></span>` : '');
  b.querySelectorAll('button').forEach(el => el.onclick = () => { save.use[el.dataset.id] = !save.use[el.dataset.id]; persist(); renderBoosts(); buzz(); });
}
function gift() {
  if (save.daily.last === today()) { toast('Vuelve mañana a por otro regalo 🎁'); return; }
  const y = new Date(Date.now() - 864e5).toISOString().slice(0, 10);
  save.daily.streak = save.daily.last === y ? save.daily.streak + 1 : 1; save.daily.last = today();
  const amt = Math.round(rnd(80, 200) + Math.min(7, save.daily.streak) * 40);
  save.bank += amt; persist(); S.buy(); buzz('MEDIUM');
  toast(`🎁 +${amt} monedas · racha de ${save.daily.streak} día${save.daily.streak > 1 ? 's' : ''}`);
  $('#mCoins').textContent = save.bank.toLocaleString('es'); $('#giftDot').hidden = true;
}

/* ---------- miniaturas de la tienda: cada objeto se renderiza a una imagen pequeña ---------- */
const TW = 320, TH = 240;
const thumbCache = {}, thumbBgs = {};
let thumbQ = Promise.resolve();
const tcam = new THREE.PerspectiveCamera(30, TW / TH, .1, 200), tkey = new THREE.DirectionalLight(0xffffff, 0);
scene.add(tkey);   // siempre en la escena (con intensidad 0): así no cambia el número de luces ni se recompilan los materiales
const shade = (c, f) => (Math.round((c >> 16 & 255) * f) << 16) | (Math.round((c >> 8 & 255) * f) << 8) | Math.round((c & 255) * f);
const rgb = (c, f = 1, a = 1) => `rgba(${Math.min(255, Math.round(((c >> 16) & 255) * f))},${Math.min(255, Math.round(((c >> 8) & 255) * f))},${Math.min(255, Math.round((c & 255) * f))},${a})`;
function thumbBg(top, bot, glow) {
  const k = top + '-' + bot + '-' + glow;
  return thumbBgs[k] || (thumbBgs[k] = M.canvasTex(TW, TH, (c, w, h) => {
    const g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, rgb(top)); g.addColorStop(1, rgb(bot)); c.fillStyle = g; c.fillRect(0, 0, w, h);
    const r = c.createRadialGradient(w / 2, h * .58, 0, w / 2, h * .58, w * .55); r.addColorStop(0, rgb(glow, 1, .75)); r.addColorStop(1, rgb(glow, 1, 0)); c.fillStyle = r; c.fillRect(0, 0, w, h);
    c.fillStyle = 'rgba(0,0,0,.2)'; c.fillRect(0, h * .87, w, h * .13);
  }, false));
}
// Renderiza la escena con la cámara de la miniatura y devuelve la imagen. opts: world (se ve el mapa), hidePlayer.
function capture(bg, place, opts = {}) {
  const always = [PN.pts, PA.pts, coinIM, tung.root, tung.shadow];
  const list = opts.world ? always : always.concat([sky, far, ...Object.values(env).map(E => E.group)]);
  const vis = list.map(o => o.visible), pv = [player.root.visible, player.shadow.visible];
  const prev = { bg: scene.background, fn: scene.fog.near, ff: scene.fog.far, pr: R.getPixelRatio(), sz: R.getSize(new THREE.Vector2()), by: M.BEND.y.value, bx: M.BEND.x.value };
  list.forEach(o => { o.visible = false; });
  player.root.visible = player.shadow.visible = !opts.hidePlayer;
  if (!opts.world) { scene.background = bg; scene.fog.near = 1e5; scene.fog.far = 2e5; }
  M.BEND.y.value = M.BEND.x.value = 0;
  R.setPixelRatio(1); R.setSize(TW, TH, false);
  tcam.fov = 30; place(tcam); tcam.updateProjectionMatrix();
  if (!opts.world) { tkey.intensity = 1.6; tkey.position.copy(tcam.position).add(_v.set(.6, 2.2, 0)); }
  R.render(scene, tcam);
  const url = cv.toDataURL('image/jpeg', .9);
  tkey.intensity = 0;
  list.forEach((o, i) => { o.visible = vis[i]; });
  player.root.visible = pv[0]; player.shadow.visible = pv[1];
  scene.background = prev.bg; scene.fog.near = prev.fn; scene.fog.far = prev.ff; M.BEND.y.value = prev.by; M.BEND.x.value = prev.bx;
  R.setPixelRatio(prev.pr); R.setSize(prev.sz.x, prev.sz.y, false);
  return url;
}
// prueba un aspecto en la gamba y la deja como estaba
function withPlayer(fn) {
  const s = { id: player.curId, hat: player.hatId, skin: player.skin, rot: player.tilt.rotation.clone() };
  try { return fn(); } finally { player.useNow(s.id); player.setHat(s.hat); if (s.skin) player.setSkin(s.skin); player.tilt.rotation.copy(s.rot); }
}
function posePlayer() {
  player.root.position.set(0, 0, 0); player.tilt.position.set(0, 0, 0); player.tilt.scale.set(1, 1, 1); player.tilt.rotation.set(0, 0, 0);
  for (let i = 0; i < 3; i++) player.pose(1.2, 'idle', 1.4 + i * .3, .3);
  player.root.updateMatrixWorld(true); player.shadow.position.set(0, .025, 0); player.shadow.scale.setScalar(1);
}
const shrimpCam = cam => { cam.position.set(1.45, .85, -1.9); cam.lookAt(0, .27, 0); };
const eqModel = () => (CHARS.find(c => c.id === save.eq.chars) || CHARS[0]).model;
const ITEM_MODEL = { vida: 'vida', cohete: 'turbo', escudoIni: 'escudo', dobleIni: 'x2' };

// imágenes dibujadas en 2D (estelas, multiplicadores, «sin gorro»)
function flat(draw, top, bot) {
  const c = document.createElement('canvas'); c.width = TW; c.height = TH; const x = c.getContext('2d');
  const g = x.createLinearGradient(0, 0, 0, TH); g.addColorStop(0, top); g.addColorStop(1, bot); x.fillStyle = g; x.fillRect(0, 0, TW, TH);
  x.textAlign = 'center'; x.textBaseline = 'middle'; draw(x, TW, TH); return c.toDataURL('image/jpeg', .9);
}
function heart(x, cx, cy, s) { x.beginPath(); x.moveTo(cx, cy + s * .9); x.bezierCurveTo(cx - s * 1.6, cy - s * .2, cx - s * .7, cy - s * 1.3, cx, cy - s * .35); x.bezierCurveTo(cx + s * .7, cy - s * 1.3, cx + s * 1.6, cy - s * .2, cx, cy + s * .9); x.fill(); }
const TRAIL_PAL = { polvo: [0xc9b08a, 0x9a835f], burbujas: [0xbfeaff, 0xffffff], chispas: [0xffe27a, 0xfff6c2], corazones: [0xff4d8d, 0xff9ac0], hielo: [0x7fd6ff, 0xe4f8ff], fuego: [0xff5a1a, 0xffd23f], arcoiris: null };
function trailThumb(it) {
  const pal = TRAIL_PAL[it.id]; let seed = it.id.length * 9973 + 7;
  const rng = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  return flat((x, w, h) => {
    for (let i = 0; i < 64; i++) {
      const t = i / 63, px = w * (.08 + .84 * t), py = h * .55 + Math.sin(t * 7) * h * .09 + (rng() - .5) * h * .36, r = 5 + (1 - t) * 17 * (.35 + rng()), a = .35 + .6 * rng();
      x.fillStyle = pal ? rgb(pal[i % 2], 1, a) : `hsla(${t * 330},92%,62%,${a})`; x.shadowColor = x.fillStyle; x.shadowBlur = 14;
      if (it.id === 'corazones') heart(x, px, py, r * .75); else { x.beginPath(); x.arc(px, py, r, 0, 7); x.fill(); }
    }
  }, '#16284a', '#0a1426');
}
function multThumb(it) {
  const big = (x, t, y, size, fill = '#ffd84a') => { x.font = `700 ${size}px "Fredoka",system-ui,sans-serif`; x.lineJoin = 'round'; x.lineWidth = size * .12; x.strokeStyle = 'rgba(60,25,0,.85)'; x.strokeText(t, TW / 2, y); x.fillStyle = fill; x.fillText(t, TW / 2, y); };
  if (it.id === 'mult') return flat(x => { big(x, '×' + scoreMult(), TH * .52, 128); }, '#3b1d7a', '#b03fa0');
  if (it.id === 'valor') return flat((x, w, h) => { for (let k = 0; k < 5; k++) { x.fillStyle = '#b87400'; x.beginPath(); x.ellipse(w / 2, h * .82 - k * 15 + 7, 60, 22, 0, 0, 7); x.fill(); x.fillStyle = k % 2 ? '#ffc21d' : '#ffd84a'; x.beginPath(); x.ellipse(w / 2, h * .82 - k * 15, 60, 22, 0, 0, 7); x.fill(); } big(x, '+' + Math.max(20, level('valor') * 20) + '%', h * .28, 64, '#fff'); }, '#14402a', '#1f8a52');
  if (it.id === 'suerte') return flat((x, w, h) => { x.fillStyle = '#6ff09a'; x.strokeStyle = '#2f8a4a'; x.lineWidth = 3; x.save(); x.translate(w / 2, h * .48); for (let k = 0; k < 4; k++) { x.save(); x.rotate(k * Math.PI / 2); x.translate(0, -36); heart(x, 0, 0, 34); x.restore(); } x.restore(); x.strokeStyle = '#2f8a4a'; x.lineWidth = 7; x.beginPath(); x.moveTo(w / 2, h * .5); x.quadraticCurveTo(w / 2 + 6, h * .75, w / 2 + 30, h * .88); x.stroke(); }, '#0f3d2a', '#1c7a4a');
  return flat((x, w, h) => { x.fillStyle = '#ff5a7a'; heart(x, w / 2, h * .5, 66); x.fillStyle = 'rgba(255,255,255,.35)'; x.beginPath(); x.ellipse(w / 2 - 34, h * .36, 13, 8, -.6, 0, 7); x.fill(); big(x, '+', h * .52, 76, '#fff'); }, '#3d1426', '#a3243f');
}
const noHatThumb = () => flat((x, w, h) => { x.strokeStyle = 'rgba(255,255,255,.75)'; x.lineWidth = 12; x.beginPath(); x.arc(w / 2, h / 2, 54, 0, 7); x.moveTo(w / 2 - 38, h / 2 + 38); x.lineTo(w / 2 + 38, h / 2 - 38); x.stroke(); }, '#2a2244', '#15112a');

async function thumbJob(tab, it) {
  switch (tab) {
    case 'chars': await player.ensure(it.model);
      return withPlayer(() => { player.useNow(it.model); player.setHat('nada'); player.setSkin(SKINS[0].p); posePlayer(); return capture(thumbBg(0x2d2a66, 0x7a3a8c, 0xffb46e), shrimpCam); });
    case 'skins': { const m = eqModel(); await player.ensure(m);
      return withPlayer(() => { player.useNow(m); player.setHat('nada'); player.setSkin(it.p); posePlayer(); return capture(thumbBg(0x0f3b5e, 0x1b8a9a, 0x8affe6), shrimpCam); }); }
    case 'hats': if (it.id === 'nada') return noHatThumb();
      await player.ensure('gamba'); return hatShot('gamba', it.id);
    case 'trails': return trailThumb(it);
    case 'mults': return multThumb(it);
    case 'maps': { const prev = curMap; setMap(it.id);
      try { return withPlayer(() => { player.useNow(eqModel()); posePlayer(); return capture(null, cam => { cam.fov = 58; cam.position.set(0, 2.5, 6.2); cam.lookAt(0, .8, -6); sky.position.copy(cam.position); far.position.set(0, 0, 6.2); }, { world: true }); }); } finally { setMap(prev); } }
    case 'ups': case 'items': {
      const id = tab === 'ups' ? it.id : ITEM_MODEL[it.id], col = M.POWER_COL[id], m = M.powerModel(id);
      m.rotation.y = -.45; scene.add(m);
      try { return capture(thumbBg(shade(col, .28), shade(col, .62), col), cam => { cam.position.set(.8, .92, 2.05); cam.lookAt(0, .5, 0); }, { hidePlayer: true }); } finally { scene.remove(m); }
    }
  }
  return null;
}
// un gorro puesto en una gamba, visto de cerca
function hatShot(model, id) {
  return withPlayer(() => {
    player.useNow(model); player.setSkin(SKINS[0].p); player.setHat(id); posePlayer();
    const b = new THREE.Box3().setFromObject(player.hat), c = b.getCenter(new THREE.Vector3()), s = Math.max(...b.getSize(new THREE.Vector3()).toArray());
    return capture(thumbBg(0x36205e, 0x9a3f8f, 0xffa8d8), cam => { cam.position.copy(c).add(new THREE.Vector3(.85, .42, -1).normalize().multiplyScalar(s * 3.3 + .3)); cam.lookAt(c.x, c.y - s * .22, c.z); });
  });
}
// prueba: cuadrícula con cada gorro en cada gamba (?hatgrid=gafas,fiesta,...)
// prueba: dónde están los ojos de cada modelo respecto a su centro (z negativo = hacia delante en el mundo)
async function eyeCheck() {
  const out = [];
  for (const ch of CHARS) {
    await player.ensure(ch.model); player.useNow(ch.model); posePlayer(); player.root.position.set(0, 0, 0); player.root.rotation.y = 0; player.root.updateMatrixWorld(true);
    const body = new THREE.Box3().setFromObject(player.cur.sc, true), bc = body.getCenter(new THREE.Vector3()), eb = new THREE.Box3(); let n = 0;
    player.cur.sc.traverse(o => { if (o.isMesh && /eye/i.test((o.material.name || '') + o.name)) { eb.expandByObject(o); n++; } });
    const ec = eb.getCenter(new THREE.Vector3());
    out.push(`${ch.model}: ojos(${n}) z=${ec.z.toFixed(2)} centro z=${bc.z.toFixed(2)} largo z=${(body.max.z - body.min.z).toFixed(2)}`);
  }
  document.title = 'LISTO ' + out.join(' | ');
  const d = document.createElement('pre'); d.style.cssText = 'position:fixed;inset:0;z-index:99;background:#fff;color:#000;font:13px monospace;padding:10px;margin:0;white-space:pre-wrap'; d.textContent = out.join('\n'); document.body.appendChild(d);
}
async function hatGrid() {
  const hats = Q.get('hatgrid').split(','), box = document.createElement('div');
  box.style.cssText = 'position:fixed;inset:0;z-index:99;background:#222;display:grid;gap:2px;grid-template-columns:repeat(' + hats.length + ',1fr);align-content:start';
  document.body.appendChild(box);
  for (const ch of CHARS) { await player.ensure(ch.model); for (const h of hats) { const im = new Image(); im.style.cssText = 'width:100%;display:block'; im.src = hatShot(ch.model, h); box.appendChild(im); } }
  document.title = 'LISTO hatgrid';
}
const thumbKey = (tab, it) => tab + ':' + it.id + (tab === 'mults' ? ':' + level(it.id) + ':' + scoreMult() : tab === 'skins' ? ':' + save.eq.chars : '');
function thumb(tab, it) {
  const k = thumbKey(tab, it);
  if (thumbCache[k]) return Promise.resolve(thumbCache[k]);
  return (thumbQ = thumbQ.then(async () => {
    if (thumbCache[k]) return thumbCache[k];
    try { return (thumbCache[k] = await thumbJob(tab, it)); } catch (e) { console.warn('miniatura', k, e); return null; }
  }));
}

/* ---------- tienda ---------- */
let tab = 'chars', selId = null, preview = {};
function openShop(t = 'chars') {
  mode = 'shop'; tab = t; preview = Object.assign({}, save.eq); setMin(Q.has('min'), true);
  $('#menu').hidden = true; $('#over').hidden = true; $('#shop').hidden = false;
  renderTabs(); pickTab(t);
}
function closeShop() { applyEquip(); setMap(save.eq.maps); toMenu(); }
// tirador del panel: plegado solo quedan las pestañas y el botón de comprar, y el personaje se ve grande
function setMin(v, quiet) { $('#sheet').classList.toggle('min', v); $('#grabTxt').textContent = v ? 'Ver tienda' : 'Ver personaje'; if (!quiet) buzz(); }
let grabY = null;
$('#grab').addEventListener('pointerdown', e => { grabY = e.clientY; });
$('#grab').addEventListener('pointerup', e => { if (grabY === null) return; const dy = e.clientY - grabY; grabY = null; setMin(dy > 20 ? true : dy < -20 ? false : !$('#sheet').classList.contains('min')); });
function renderTabs() {
  $('#tabs').innerHTML = TABS.map(t => `<button class="tab ${t.id === tab ? 'on' : ''}" data-t="${t.id}">${t.name}</button>`).join('');
  $('#tabs').querySelectorAll('.tab').forEach(b => b.onclick = () => { pickTab(b.dataset.t); buzz(); });
}
function pickTab(t) {
  tab = t; renderTabs();
  const T0 = TABS.find(x => x.id === t);
  selId = ['chars', 'skins', 'hats', 'trails', 'maps'].includes(t) ? preview[t] || save.eq[t] : T0.list[0].id;
  renderGrid();
  const on = $('#tabs .tab.on'); on && on.scrollIntoView({ inline: 'center', behavior: 'smooth', block: 'nearest' });
}
function renderGrid() {
  const T0 = TABS.find(x => x.id === tab), grid = $('#grid'), st = grid.scrollTop;
  $('#sCoins').textContent = save.bank.toLocaleString('es');
  grid.innerHTML = T0.list.map(it => {
    const url = thumbCache[thumbKey(tab, it)];
    const ic = `<span class="th ${url ? '' : 'ph'}" data-th="${tab}:${it.id}" ${url ? `style="background-image:url(${url})"` : ''}>${url ? '' : (it.icon || '')}</span>`;
    let pr;
    if (tab === 'ups') { const lv = level(it.id); pr = `<span class="lv">${[0, 1, 2, 3, 4].map(i => `<i class="${i < lv ? 'f' : ''}"></i>`).join('')}</span>`; }
    else if (tab === 'mults') { const lv = level(it.id); pr = `<span class="pr own">Nv ${lv}/${it.max}</span>`; }
    else if (tab === 'items') pr = `<span class="pr"><span class="coin"></span>${it.price}</span>`;
    else if (save.eq[tab] === it.id) pr = `<span class="pr eq">EN USO</span>`;
    else if (owns(tab, it.id)) pr = `<span class="pr own">Tuyo</span>`;
    else pr = `<span class="pr"><span class="coin"></span>${it.price.toLocaleString('es')}</span>`;
    const cnt = tab === 'items' && save.items[it.id] ? `<span class="cnt">×${save.items[it.id]}</span>` : '';
    const lock = ['chars', 'skins', 'hats', 'trails', 'maps'].includes(tab) && !owns(tab, it.id) ? 'lock' : '';
    return `<button class="it ${it.id === selId ? 'sel' : ''} ${lock}" data-id="${it.id}">${cnt}${ic}<span class="nm">${it.name}</span>${pr}</button>`;
  }).join('');
  grid.scrollTop = st;
  grid.querySelectorAll('.it').forEach(b => b.onclick = () => { selId = b.dataset.id; buzz(); tryOn(); renderGrid(); });
  // las miniaturas que faltan se van generando una a una y aparecen al estar listas
  const myTab = tab;
  for (const it of T0.list) if (!thumbCache[thumbKey(tab, it)]) thumb(tab, it).then(url => {
    const el = url && tab === myTab && $(`#grid [data-th="${myTab}:${it.id}"]`);
    if (el) { el.style.backgroundImage = `url(${url})`; el.classList.remove('ph'); el.textContent = ''; }
  });
  renderDetail();
}
function tryOn() {
  if (['chars', 'skins', 'hats', 'trails'].includes(tab)) { preview[tab] = selId; applyEquip(Object.assign({}, save.eq, preview)); }
  if (tab === 'maps') { preview.maps = selId; setMap(selId); }
}
function renderDetail() {
  const T0 = TABS.find(x => x.id === tab), it = T0.list.find(x => x.id === selId) || T0.list[0];
  const btn = $('#dBtn'); btn.disabled = false;
  let desc = it.desc || '', label = '', act = null;
  const coin = n => `<span class="coin"></span>${n.toLocaleString('es')}`;
  if (tab === 'ups') {
    const lv = level(it.id); desc = `${it.desc} Dura ${upDur(it).toFixed(1).replace('.0', '')} s${lv < 5 ? ` → ${(upDur(it) + it.step).toFixed(1).replace('.0', '')} s` : ''}.`;
    if (lv >= 5) { label = 'Al máximo'; btn.disabled = true; } else { const c = UPGRADE_COST[lv]; label = `Mejorar ${coin(c)}`; act = () => buy(c, () => { save.lv[it.id] = lv + 1; }); }
  } else if (tab === 'mults') {
    const lv = level(it.id);
    if (lv >= it.max) { label = 'Al máximo'; btn.disabled = true; } else { const c = multCost(it, lv); label = `Mejorar ${coin(c)}`; act = () => buy(c, () => { save.lv[it.id] = lv + 1; }); }
  } else if (tab === 'items') {
    label = `Comprar ${coin(it.price)}`; act = () => buy(it.price, () => { save.items[it.id] = (save.items[it.id] || 0) + 1; if (it.id !== 'vida') save.use[it.id] = true; });
  } else {
    if (!desc && tab === 'skins') desc = 'Cambia el color de tu gamba.';
    if (!desc && tab === 'hats') desc = 'Un complemento para la cabeza.';
    if (!desc && tab === 'trails') desc = 'Lo que va dejando tu gamba al correr.';
    if (save.eq[tab] === it.id) { label = 'En uso'; btn.disabled = true; }
    else if (owns(tab, it.id)) { label = 'Usar'; act = () => { save.eq[tab] = it.id; persist(); S.lane(); } }
    else { label = `Comprar ${coin(it.price)}`; act = () => buy(it.price, () => { save.owned[tab + ':' + it.id] = true; save.eq[tab] = it.id; }); }
  }
  $('#dName').textContent = it.name; $('#dDesc').textContent = desc;
  btn.innerHTML = label; btn.onclick = act ? () => { act(); renderGrid(); } : null;
}
function buy(cost, fn) {
  if (save.bank < cost) { toast(`Te faltan ${(cost - save.bank).toLocaleString('es')} monedas`); buzz('HEAVY'); S.bonk(); return; }
  save.bank -= cost; fn(); persist(); S.buy(); buzz('MEDIUM'); toast('¡Comprado!');
  for (let i = 0; i < 30; i++) PA.emit(rnd(-.5, .5), rnd(.3, 1), rnd(-.5, .5), rnd(-2, 2), rnd(1, 4), rnd(-2, 2), new THREE.Color().setHSL(rnd(0, 1), .9, .6), .18, .8, 5);
}

/* ---------- pausa ---------- */
function pause() { if (mode === 'run' && G && !G.paused) { G.paused = true; $('#paused').hidden = false; setMusic(false); } }
$('#pauseBtn').onclick = pause;
$('#resume').onclick = () => { G.paused = false; $('#paused').hidden = true; clock.getDelta(); setMusic(true); };
$('#quit').onclick = () => { if (G) { G.paused = false; } toMenu(); };
document.addEventListener('visibilitychange', () => { if (document.hidden) { pause(); if (AC) AC.suspend(); } else if (AC && mode !== 'loading') AC.resume(); });

/* ---------- botones ---------- */
$('#playBtn').onclick = () => { ac(); startRun(); };
$('#again').onclick = () => startRun();
$('#overMenu').onclick = toMenu;
$('#overShop').onclick = () => { toMenu(); openShop('ups'); };
$('#reviveBtn').onclick = revive;
$('#shopBtn').onclick = () => { ac(); openShop('chars'); };
$('#mapBtn').onclick = () => { ac(); openShop('maps'); };
$('#shopClose').onclick = closeShop;
$('#gift').onclick = gift;
$('#setBtn').onclick = () => { $('#optSfx').checked = save.opt.sfx; $('#optMusic').checked = save.opt.music; $('#optHaptic').checked = save.opt.haptic; $('#optHQ').checked = save.opt.hq; $('#settings').hidden = false; };
$('#setClose').onclick = () => { $('#settings').hidden = true; };
for (const [id, k] of [['#optSfx', 'sfx'], ['#optMusic', 'music'], ['#optHaptic', 'haptic'], ['#optHQ', 'hq']]) $(id).onchange = e => { save.opt[k] = e.target.checked; persist(); if (k === 'music') setMusic(true); if (k === 'hq') resize(); };

/* ---------- pruebas automáticas (solo con parámetros en la URL) ---------- */
function autopilot() {
  const g = G, look = 6 + g.speed * .55;
  const risk = l => { let r = 0; for (const o of g.obs) if (!o.hit && o.type === 'block' && o.lanes.includes(l) && o.z - o.dz < 1 && o.z + o.dz > -look - o.vz * 1.2) r += 30 + o.z; return r; };
  // esquivar bloques: ir hacia el carril más seguro, paso a paso
  if (risk(g.lane) > 0 && Math.abs(g.px - LX[g.lane]) < .3) {
    const best = [0, 1, 2].sort((a, b) => risk(a) - risk(b) || Math.abs(a - g.lane) - Math.abs(b - g.lane))[0];
    if (best !== g.lane && !(Math.abs(best - g.lane) === 2 && risk(1) > 0 && g.obs.some(o => o.type === 'block' && o.lanes.includes(1) && o.z > -3 && o.z < 1))) move(Math.sign(best - g.lane));
  }
  let ahead = null;
  for (const o of g.obs) if (!o.hit && o.type !== 'pw' && o.type !== 'block' && o.z < 0 && o.z > -9 && o.lanes.some(l => Math.abs(LX[l] - g.px) < .8)) { if (!ahead || o.z > ahead.z) ahead = o; }
  if (!ahead) return;
  const lead = .12 * g.speed + .3;
  if (ahead.type === 'jump' && ahead.z > -lead - .6 && g.y === 0) jump();
  else if (ahead.type === 'slide' && ahead.z > -lead - .6 && g.slideT <= 0) slide();
}
function testShot() {
  if (Q.has('eyes')) return eyeCheck();
  if (Q.has('hatgrid')) return hatGrid();
  const sim = +(Q.get('sim') || 0), wait = +(Q.get('shot') || 1);
  document.head.insertAdjacentHTML('beforeend', '<style>*{animation:none!important;transition:none!important}' + (Q.has('noui') ? '.panel,.screen,#hud{display:none!important}' : '') + '</style>');
  setTimeout(() => {
    if (sim && G) { for (let i = 0; i < sim * 60 && mode === 'run'; i++) { if (Q.has('auto')) autopilot(); step(1 / 60); } for (let i = 0; i < 20; i++) frame(1 / 60); }
    if (Q.has('pwnear') && G) ['iman', 'salto', 'turbo'].forEach((id, i) => { const o = P.orb[id].clone(); o.position.set(LX[i], 0, -6); scene.add(o); G.obs.push({ type: 'pw', id, lanes: [i], z: -6, dz: .5, mesh: o, vz: 0 }); });
    if (Q.has('tungnear') && G) { G.stumble = 3; G.chase = 3.1; tung.root.position.x = G.px - 1.15; }
    if (Q.has('noobs') && G) { G.obs.forEach(o => scene.remove(o.mesh)); G.obs = []; coins.length = 0; }
    for (let i = 0; i < (+(Q.get('skip')) || 0); i++) env[curMap].update(1);
    for (let i = 0; i < (+(Q.get('frames')) || 120); i++) frame(1 / 60);
    R.render(scene, cam); const ri = R.info.render, rinfo = `calls=${ri.calls} tris=${ri.triangles} geo=${R.info.memory.geometries} tex=${R.info.memory.textures} `;
    const im = $('#shotImg'); im.src = cv.toDataURL('image/png'); im.style.display = 'block';
    if (Q.has('bbox')) { const bb = new THREE.Box3().setFromObject(player.cur.sc, true); document.title = `k=${player.cur.k.toFixed(3)} min=${bb.min.toArray().map(v => v.toFixed(2))} max=${bb.max.toArray().map(v => v.toFixed(2))} | `; if (player.hat) { const hb = new THREE.Box3().setFromObject(player.hat); document.title += `hat ${hb.min.toArray().map(v => v.toFixed(2))} ${hb.max.toArray().map(v => v.toFixed(2))} rel ${player.hoodRel.toArray().map(v => v.toFixed(3))} vis ${player.hat.parent && player.hat.parent.parent && player.hat.parent.parent.visible} | `; } }
    document.title = (document.title.startsWith('k=') ? document.title : '') + 'LISTO ' + (G ? `d=${Math.floor(G.dist)} ${mode} c=${G.coins}${G.log || ''}` : mode);
    document.title = rinfo + document.title;
    const info = document.createElement('div'); info.style.cssText = 'position:fixed;left:0;bottom:0;z-index:99;background:#fff;color:#000;font:11px monospace;padding:2px 4px'; info.textContent = document.title; document.body.appendChild(info);
  }, wait * 1000);
}

boot().catch(e => { $('#loadTxt').textContent = 'Error al cargar: ' + e.message; console.error(e); });
