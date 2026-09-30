// Carga de modelos 3D, personajes (gamba y Tung con esqueleto propio) y objetos del escenario.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import { mergeGeometries } from './lib/BufferGeometryUtils.js';

/* ---------- mundo curvo: el suelo «cae» a lo lejos (estilo Subway Surfers) ---------- */
export const BEND = { y: { value: 0.0017 }, x: { value: 0 } };
const PROJ = `vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
float bz_ = min( 0.0, mvPosition.z + 3.0 );
mvPosition.y -= bz_ * bz_ * uBendY;
mvPosition.x += bz_ * bz_ * uBendX;
gl_Position = projectionMatrix * mvPosition;`;
export function bend(m) {
  if (!m || m.userData.bent) return m;
  m.userData.bent = true;
  const prev = m.onBeforeCompile;
  m.onBeforeCompile = (sh, r) => {
    if (prev) prev.call(m, sh, r);
    sh.uniforms.uBendY = BEND.y; sh.uniforms.uBendX = BEND.x;
    sh.vertexShader = 'uniform float uBendY;\nuniform float uBendX;\n' + sh.vertexShader.replace('#include <project_vertex>', PROJ);
  };
  const key = m.customProgramCacheKey ? m.customProgramCacheKey.bind(m) : () => '';
  m.customProgramCacheKey = () => key() + '|bend' + (m.userData.skinKey || '');
  return m;
}
export function bendAll(obj) { obj.traverse(o => { if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach(bend); }); return obj; }

/* ---------- carga ---------- */
const loader = new GLTFLoader();
export async function loadAll(files, onProgress) {
  const out = {}; let done = 0;
  await Promise.all(Object.entries(files).map(([k, url]) => new Promise((ok, ko) => loader.load(url, g => { out[k] = g; onProgress(++done / Object.keys(files).length); ok(); }, undefined, ko))));
  return out;
}
const baseName = n => n.replace(/_\d+$/, '');

// Centra un objeto: base en y=0, centrado en x/z, y lo escala a una altura (o longitud) dada.
export function normalize(obj, { height, length, axis = 'y' } = {}) {
  const w = new THREE.Group(); w.add(obj);
  obj.updateMatrixWorld(true);
  const b = new THREE.Box3().setFromObject(obj), s = b.getSize(new THREE.Vector3()), c = b.getCenter(new THREE.Vector3());
  obj.position.sub(new THREE.Vector3(c.x, b.min.y, c.z));
  let k = 1;
  if (height) k = height / s.y; else if (length) k = length / s[axis];
  w.scale.setScalar(k);
  w.userData.size = s.clone().multiplyScalar(k);
  return w;
}

// Clona solo los nodos con ese nombre (sin sanear) de un GLB, horneando la transformación.
export function pick(gltf, name) {
  gltf.scene.updateMatrixWorld(true);
  let node = null;
  gltf.scene.traverse(o => { if (!node && (o.name === name || baseName(o.name) === name)) node = o; });
  if (!node) return null;
  const g = new THREE.Group();
  node.traverse(o => {
    if (!o.isMesh) return;
    const m = new THREE.Mesh(o.geometry.clone().applyMatrix4(o.matrixWorld), o.material);
    g.add(m);
  });
  return g;
}
export function childrenOf(gltf, parentName) {
  let p = null; gltf.scene.traverse(o => { if (!p && o.name === parentName) p = o; });
  return p ? p.children.map(c => c.name) : [];
}

/* ---------- tono de la piel de la gamba ---------- */
export const SKIN = { h: { value: 0 }, s: { value: 1 }, v: { value: 1 }, glow: { value: 0 }, rain: { value: 0 }, shine: { value: 0 }, t: { value: 0 } };
const SKIN_GLSL = `uniform float uH; uniform float uS; uniform float uV; uniform float uGlow; uniform float uRain; uniform float uShine; uniform float uT;
vec3 rgb2hsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y); float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x); }
vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y); }
vec3 hueRot(vec3 c, float a) { vec3 h = rgb2hsv(c); h.x = fract(h.x + a); return hsv2rgb(h); }
`;
function skinPatch(m) {
  m.userData.skinKey = 'skin';
  m.onBeforeCompile = sh => {
    Object.assign(sh.uniforms, { uH: SKIN.h, uS: SKIN.s, uV: SKIN.v, uGlow: SKIN.glow, uRain: SKIN.rain, uShine: SKIN.shine, uT: SKIN.t });
    sh.fragmentShader = SKIN_GLSL + sh.fragmentShader.replace('#include <map_fragment>', `#include <map_fragment>
      { vec3 c = diffuseColor.rgb;
        float a = uH + uRain * (uT * .35 + gl_FragCoord.y * 0.002);
        c = hueRot(c, a);
        float g = dot(c, vec3(0.299, 0.587, 0.114));
        c = mix(vec3(g), c, uS) * uV;
        c += uShine * 0.35 * pow(max(0.0, sin(gl_FragCoord.x * 0.02 + gl_FragCoord.y * 0.015 - uT * 4.0)), 8.0);
        c += uGlow * vec3(0.25, 0.45, 0.6);
        diffuseColor.rgb = clamp(c, 0.0, 1.0); }`);
  };
}

/* ---------- gorros (se construyen en el espacio original de la gamba: la cabeza mide ~0,1) ---------- */
const std = (c, o = {}) => new THREE.MeshStandardMaterial(Object.assign({ color: c, roughness: .55, metalness: 0 }, o));
function hatMesh(id, gltfs) {
  const g = new THREE.Group();
  const add = (geo, mat, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0) => { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.rotation.set(rx, ry, rz); g.add(m); return m; };
  switch (id) {
    case 'fiesta': {
      add(new THREE.ConeGeometry(.045, .12, 24), std(0xff4fa3), 0, .06, 0);
      add(new THREE.SphereGeometry(.014, 12, 8), std(0xffe14d), 0, .125, 0);
      for (let i = 0; i < 3; i++) add(new THREE.TorusGeometry(.036 - i * .011, .005, 6, 24), std([0xffe14d, 0x4fd1ff, 0x7cf07c][i]), 0, .018 + i * .03, 0, Math.PI / 2);
      break;
    }
    case 'gorra': {
      add(new THREE.SphereGeometry(.058, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), std(0xe8302e), 0, 0, 0);
      add(new THREE.CylinderGeometry(.06, .06, .008, 24, 1, false, -Math.PI / 2, Math.PI), std(0xe8302e), 0, .002, .03).scale.set(1, 1, 1.25);
      add(new THREE.SphereGeometry(.009, 8, 6), std(0xffffff), 0, .058, 0);
      break;
    }
    case 'gafas': {
      const lens = std(0x111318, { roughness: .1, metalness: .6 }), frame = std(0x222222);
      for (const s of [-1, 1]) add(new THREE.CylinderGeometry(.024, .024, .008, 20), lens, s * .03, -.035, .062, Math.PI / 2);
      add(new THREE.BoxGeometry(.02, .006, .006), frame, 0, -.03, .064);
      for (const s of [-1, 1]) add(new THREE.BoxGeometry(.005, .006, .07), frame, s * .055, -.032, .03);
      break;
    }
    case 'auris': {
      add(new THREE.TorusGeometry(.062, .008, 8, 32, Math.PI), std(0x1c1c22), 0, -.02, 0);
      for (const s of [-1, 1]) add(new THREE.CylinderGeometry(.026, .026, .022, 20), std(0x31e0c4), s * .064, -.03, 0, 0, 0, Math.PI / 2);
      break;
    }
    case 'chistera': {
      const black = std(0x16161c, { roughness: .4 });
      add(new THREE.CylinderGeometry(.075, .075, .008, 32), black, 0, .004, 0);
      add(new THREE.CylinderGeometry(.045, .045, .09, 32), black, 0, .05, 0);
      add(new THREE.CylinderGeometry(.0455, .0455, .016, 32), std(0xd12d3a), 0, .018, 0);
      break;
    }
    case 'vikingo': {
      add(new THREE.SphereGeometry(.058, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), std(0x9aa3ad, { metalness: .7, roughness: .3 }));
      add(new THREE.TorusGeometry(.057, .007, 8, 32), std(0x8a5a2b), 0, .004, 0, Math.PI / 2);
      for (const s of [-1, 1]) { const h = add(new THREE.ConeGeometry(.016, .07, 12), std(0xf3ead6), s * .06, .045, 0, 0, 0, -s * .9); h.scale.set(1, 1, 1); }
      break;
    }
    case 'halo': {
      const m = add(new THREE.TorusGeometry(.05, .008, 10, 40), new THREE.MeshBasicMaterial({ color: 0xfff1a6 }), 0, .06, 0, Math.PI / 2);
      m.userData.spin = 1; break;
    }
    case 'corona': {
      const gold = std(0xffc93a, { metalness: .8, roughness: .25, emissive: 0x3a2400 });
      add(new THREE.CylinderGeometry(.05, .052, .028, 32, 1, true), gold, 0, .014, 0).material.side = THREE.DoubleSide;
      for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; add(new THREE.ConeGeometry(.012, .03, 8), gold, Math.sin(a) * .05, .042, Math.cos(a) * .05); add(new THREE.SphereGeometry(.007, 8, 6), std([0xff3355, 0x3fa9ff, 0x4fe37a][i % 3], { roughness: .2 }), Math.sin(a) * .052, .016, Math.cos(a) * .052); }
      break;
    }
    case 'tiburon': {
      const s = gltfs.hood.scene.clone(true);
      // Ajustado a mano: el disfraz rodea la cabeza y la cara asoma por la boca.
      s.rotation.y = -Math.PI / 2; s.scale.setScalar(.6);
      g.add(s); g.userData.raw = true; break;
    }
  }
  return g;
}

/* ---------- las gambas jugables ---------- */
// rig: 'chumbud' (esqueleto con patas, antenas y cola), 'ebi' (esqueleto propio), 'clip' (animación incluida), 'static' (sin huesos)
// len: largo en metros; hat: [altura, avance] del punto donde va el gorro (metros, con la cabeza hacia -z)
export const PLAYERS = {
  gamba: { file: 'models/gamba.glb', rig: 'chumbud', len: 1.45 },
  chaqueta: { file: 'models/gamba_chaqueta.glb', rig: 'chumbud', len: 1.45, cheer: true },
  gafas: { file: 'models/gamba_gafas.glb', rig: 'static', len: 1.5, hat: [.4, -.46] },
  ebi: { file: 'models/gamba_ebi.glb', rig: 'ebi', len: 1.45, hat: [.38, -.46] },
  langostino: { file: 'models/langostino.glb', rig: 'static', len: 1.25, hat: [.52, -.2] },
  mysis: { file: 'models/gamba_mysis.glb', rig: 'clip', len: 1.7, walk: 'walk1', idle: 'idle1', hat: [.5, -.62] },
};
const NOT_SKIN = /outline|eye|glass|heart/i;
export class Shrimp {
  constructor(gltfs) {
    this.root = new THREE.Group();          // posición en el mundo (x, y)
    this.tilt = new THREE.Group();          // inclinaciones y aplastado
    this.root.add(this.tilt);
    this.models = {}; this.gltfs = gltfs; this.hatId = 'nada'; this.skin = null;
    this.hoodRel = new THREE.Vector3(0, -.03, .06);
  }
  // carga (si hace falta) y prepara un modelo; devuelve una promesa
  async ensure(id) {
    if (this.models[id]) return this.models[id];
    const cfg = PLAYERS[id] || PLAYERS.gamba;
    if (!this.gltfs[id]) this.gltfs[id] = await new Promise((ok, ko) => loader.load(cfg.file, ok, undefined, ko));
    if (cfg.cheer && this.gltfs.gamba) {
      // la de la chaqueta viene guardada en plena celebración (de pie): se le copia la postura de la gamba normal
      const ref = {}; this.gltfs.gamba.scene.traverse(o => { if (o.isBone) ref[o.name] = o; });
      this.gltfs[id].scene.traverse(o => { const r = o.isBone && ref[o.name]; if (r && !r.userData.posed) { o.position.copy(r.userData.p0 || r.position); o.quaternion.copy(r.userData.q0 || r.quaternion); o.scale.copy(r.scale); } });
    }
    if (id === 'gamba') this.gltfs.gamba.scene.traverse(o => { if (o.isBone) { o.userData.p0 = o.position.clone(); o.userData.q0 = o.quaternion.clone(); } });
    return (this.models[id] = this.#prep(this.gltfs[id], cfg));
  }
  #prep(gltf, cfg) {
    const sc = gltf.scene;
    const bones = {}, bodies = [];
    sc.traverse(o => {
      if (o.isBone) bones[baseName(o.name)] = o;
      if (o.isMesh) {
        o.frustumCulled = false;
        const m = o.material;
        if (!NOT_SKIN.test(m.name || '') && !NOT_SKIN.test(o.name || '')) { skinPatch(m); bodies.push(m); m.userData.op0 = m.opacity; m.userData.tr0 = m.transparent; }
        bend(m);
      }
    });
    let clipMixer = null, walk, idle;
    if (cfg.rig === 'clip') {   // se mide ya con la postura animada: la de reposo está desplazada
      clipMixer = new THREE.AnimationMixer(sc);
      const find = n => gltf.animations.find(a => a.name.split('|').pop() === n);
      walk = clipMixer.clipAction(find(cfg.walk)); idle = clipMixer.clipAction(find(cfg.idle));
      walk.play(); idle.play(); idle.weight = 0; clipMixer.update(.01);
    }
    sc.updateMatrixWorld(true);
    const b = new THREE.Box3().setFromObject(sc, true);
    const L = cfg.len, k = L / (b.max.z - b.min.z);
    const wrap = new THREE.Group(), holder = new THREE.Group(); holder.add(sc); wrap.add(holder);
    sc.position.set(-(b.min.x + b.max.x) / 2, -b.min.y + .01, -(b.min.z + b.max.z) / 2);
    holder.scale.setScalar(k); holder.rotation.y = Math.PI;   // la cabeza mira hacia -z (hacia delante)
    this.tilt.add(wrap);
    const rest = {}, restAll = [];
    for (const [n, bn] of Object.entries(bones)) rest[n] = bn.rotation.clone();
    sc.traverse(o => { if (o.isBone) restAll.push([o, o.position.clone(), o.quaternion.clone()]); });
    const M = { cfg, wrap, holder, sc, bones, rest, restAll, bodies, k };
    if (cfg.rig === 'chumbud') {
      // el gorro sigue al hueso de la cabeza
      const head = bones.Head, anchor = new THREE.Object3D(), rawAnchor = new THREE.Object3D();
      head.add(anchor); head.add(rawAnchor);
      const hp = new THREE.Vector3(); head.getWorldPosition(hp);
      const ap = sc.worldToLocal(hp.clone()).add(new THREE.Vector3(0, .07, .06));
      const inv = new THREE.Matrix4().copy(head.matrixWorld).invert().multiply(sc.matrixWorld);
      new THREE.Matrix4().multiplyMatrices(inv, new THREE.Matrix4().makeTranslation(ap.x, ap.y, ap.z)).decompose(anchor.position, anchor.quaternion, anchor.scale);
      new THREE.Matrix4().multiplyMatrices(inv, new THREE.Matrix4().makeTranslation(0, .06, .18)).decompose(rawAnchor.position, rawAnchor.quaternion, rawAnchor.scale);
      this.hoodRel.set(0, .06 - ap.y, .18 - ap.z);
      Object.assign(M, { anchor, rawAnchor });
      const clip = (this.gltfs.chaqueta || gltf).animations[0];
      if (clip) { M.mixer = new THREE.AnimationMixer(sc); M.cheer = M.mixer.clipAction(clip); }
    } else {
      // gorro en un punto fijo sobre la cabeza, en las mismas unidades que la gamba original (0,58 de largo)
      const base = new THREE.Group(); base.position.set(0, cfg.hat[0], cfg.hat[1]); base.scale.setScalar(1.45 / .58); base.rotation.y = Math.PI;
      const rawAnchor = new THREE.Group(); base.add(rawAnchor);
      wrap.add(base); Object.assign(M, { anchor: base, rawAnchor });
      if (cfg.rig === 'clip') Object.assign(M, { mixer: clipMixer, walk, idle });
    }
    if (this.skin) this.#skinModel(M, this.skin);
    return M;
  }
  async use(id) {
    const M = await this.ensure(id);
    for (const m of Object.values(this.models)) m.wrap.visible = m === M;
    this.cur = M; this.curId = id;
    this.setHat(this.hatId);
  }
  setHat(id) {
    this.hatId = id;
    for (const m of Object.values(this.models)) for (const a of [m.anchor, m.rawAnchor]) for (const c of [...a.children]) if (c.userData.isHat) a.remove(c);
    this.hat = null;
    if (id === 'nada' || !this.cur) return;
    const h = hatMesh(id, this.gltfs); bendAll(h); h.userData.isHat = true;
    if (h.userData.raw) { (this.cur.rawAnchor).add(h); if (this.cur.cfg.rig !== 'chumbud') h.position.copy(this.hoodRel); }
    else this.cur.anchor.add(h);
    this.hat = h;
  }
  #skinModel(m, p) { for (const b of m.bodies) { b.transparent = p.ghost ? true : b.userData.tr0; b.opacity = p.ghost ? .6 : b.userData.op0; b.depthWrite = !p.ghost; b.needsUpdate = true; } }
  setSkin(p) {
    this.skin = p;
    SKIN.h.value = p.h; SKIN.s.value = p.s; SKIN.v.value = p.v;
    SKIN.glow.value = p.ghost ? 1 : 0; SKIN.rain.value = p.rainbow ? 1 : 0; SKIN.shine.value = p.shine ? 1 : 0;
    for (const m of Object.values(this.models)) this.#skinModel(m, p);
  }
  // animación: ph = fase de la zancada, mode = 'run' | 'idle' | 'jump' | 'slide' | 'dead' | 'cheer'; speed en m/s
  pose(ph, mode, t, dt, speed = 12) {
    const C = this.cur; if (!C) return;
    const { bones: B, rest: R, cfg } = C;
    const set = (n, ax, v) => { const b = B[n]; if (b) b.rotation[ax] = R[n][ax] + v; };
    const run = mode === 'run' ? 1 : mode === 'slide' ? .4 : mode === 'jump' ? .15 : mode === 'idle' || mode === 'cheer' ? .12 : 0;
    const sp = mode === 'idle' || mode === 'cheer' ? t * 3 : ph;
    C.holder.rotation.z = 0; C.holder.position.y = 0;
    if (cfg.rig === 'chumbud') {
      if (mode === 'cheer' && C.cheer) { C.cheer.play(); C.mixer.update(dt); this.cheering = true; }
      else {
        if (this.cheering) { this.cheering = false; for (const m of Object.values(this.models)) { if (m.cheer) m.cheer.stop(); for (const [b, p, q] of m.restAll) { b.position.copy(p); b.quaternion.copy(q); } } }
        for (const [pos, off] of [['Front', 0], ['Center', 2.1], ['Back', 4.2]]) for (const [side, so] of [['L', 0], ['R', Math.PI]]) {
          set(`Leg_${pos}_Top${side}`, 'x', run * .75 * Math.sin(sp + off + so) + (mode === 'jump' ? .6 : 0));
          set(`Leg_${pos}_Middle${side}`, 'x', run * .45 * Math.sin(sp + off + so + 1.2));
        }
        for (let i = 1; i <= 5; i++) set(`Tail_${i}`, 'x', (mode === 'slide' ? -.12 : .06) + Math.sin((mode === 'idle' ? t * 2 : ph * .5) - i * .7) * (.05 + run * .05));
        for (let i = 1; i <= 15; i++) for (const s of ['L', 'R']) set(`Feelers_${i}${s}`, 'x', Math.sin(t * 5 + i * .45 + (s === 'L' ? 0 : 1)) * .05 * (1 + run));
        set('Head', 'x', mode === 'idle' ? Math.sin(t * 2) * .05 : 0);
      }
    } else if (cfg.rig === 'ebi') {
      for (const [pos, off] of [['front', 0], ['mid', 2.1], ['back', 4.2]]) for (const [side, so] of [['l', 0], ['r', Math.PI]])
        set(`${pos}_${side}`, 'x', run * .7 * Math.sin(sp + off + so) + (mode === 'jump' ? .5 : 0));
      set('tail', 'x', (mode === 'slide' ? -.1 : 0) + Math.sin(mode === 'idle' ? t * 2 : ph * .5) * (.06 + run * .06));
      for (let i = 2; i <= 4; i++) set(`Joint_${i}`, 'x', Math.sin((mode === 'idle' ? t * 2 : ph * .5) - i * .7) * (.05 + run * .05));
      for (let i = 1; i <= 9; i++) for (const s of ['l', 'r']) set(`a_${s}_${i}`, 'x', Math.sin(t * 5 + i * .5 + (s === 'l' ? 0 : 1)) * .04 * (1 + run));
      set('head', 'x', mode === 'idle' || mode === 'cheer' ? Math.sin(t * 2) * .06 : 0);
    } else if (cfg.rig === 'clip') {
      const moving = mode === 'run' || mode === 'slide';
      C.walk.weight = lerpN(C.walk.weight, moving ? 1 : 0, Math.min(1, dt * 6)); C.idle.weight = 1 - C.walk.weight;
      C.walk.timeScale = moving ? Math.max(1, speed / 7) : 1;
      C.mixer.update(dt);
      if (C.gy === undefined) { // la primera vez: apoyar en el suelo la postura animada
        C.wrap.updateMatrixWorld(true); const bb = new THREE.Box3().setFromObject(C.sc, true), w = new THREE.Vector3(); C.wrap.getWorldPosition(w);
        C.gy = -(bb.min.y - w.y) / Math.max(.01, C.wrap.getWorldScale(new THREE.Vector3()).y);
      }
      C.holder.position.y = C.gy;
    } else {
      // sin huesos: saltitos y meneo de todo el cuerpo
      C.holder.rotation.z = Math.sin(sp) * .06 * (run + .2);
      C.holder.position.y = Math.abs(Math.sin(sp)) * .1 * run;
      if (mode === 'cheer' || mode === 'idle') C.holder.position.y = Math.abs(Math.sin(t * 3)) * .05;
    }
    if (this.hat && this.hat.children[0] && this.hat.children[0].userData.spin) this.hat.children[0].rotation.z += dt * 2;
  }
}
const lerpN = (a, b, t) => a + (b - a) * t;

/* ---------- Tung Tung Tung Sahur con esqueleto hecho a mano ---------- */
export class Tung {
  constructor(gltf) {
    const sc = gltf.scene; sc.updateMatrixWorld(true);
    const parts = []; sc.traverse(o => { if (o.isMesh) parts.push(o); });
    const isHead = o => { for (let p = o; p; p = p.parent) if (/Head/i.test(p.name)) return true; return false; };
    const geos = parts.map(m => { const g = m.geometry.clone().applyMatrix4(m.matrixWorld); for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(k)) g.deleteAttribute(k); g.userData.head = isHead(m); return g; });
    const box = new THREE.Box3(); geos.forEach(g => { g.computeBoundingBox(); box.union(g.boundingBox); });
    const H = box.max.y - box.min.y, cx = (box.min.x + box.max.x) / 2;
    geos.forEach(g => g.translate(-cx, -box.min.y, 0));
    const f = v => v * H;
    // huesos: 0 raíz, 1 cadera, 2 pierna izq, 3 pierna der, 4 espalda, 5 brazo izq (+x), 6 brazo der (-x), 7 cabeza
    const mk = (x, y, z) => { const b = new THREE.Bone(); b.position.set(x, y, z); return b; };
    const root = mk(0, 0, 0), hips = mk(0, f(.3), 0), legL = mk(.09, 0, 0), legR = mk(-.09, 0, 0), spine = mk(0, f(.25), 0), armL = mk(.23, f(.05), 0), armR = mk(-.23, f(.05), 0), head = mk(0, f(.1), 0);
    root.add(hips); hips.add(legL, legR, spine); spine.add(armL, armR, head);
    const bones = [root, hips, legL, legR, spine, armL, armR, head];
    for (const g of geos) {
      const p = g.attributes.position, n = p.count, si = new Uint16Array(n * 4), sw = new Float32Array(n * 4);
      for (let i = 0; i < n; i++) {
        const x = p.getX(i), y = p.getY(i) / H, ax = Math.abs(x);
        let a = 4, b = 4, t = 0;
        if (g.userData.head) { a = 7; }
        else if (y < .28) { a = x >= 0 ? 2 : 3; }
        else if (y < .34) { a = x >= 0 ? 2 : 3; b = 1; t = (y - .28) / .06; }
        else if (ax > .2 && y > .52 && y < .68) { a = 4; b = x >= 0 ? 5 : 6; t = Math.min(1, (ax - .2) / .07); }
        si[i * 4] = a; si[i * 4 + 1] = b; sw[i * 4] = 1 - t; sw[i * 4 + 1] = t;
      }
      g.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(si, 4));
      g.setAttribute('skinWeight', new THREE.Float32BufferAttribute(sw, 4));
    }
    let geo; try { geo = mergeGeometries(geos); } catch (e) { geo = null; }
    const mat = parts[0].material; mat.side = THREE.FrontSide; bend(mat);
    const mesh = new THREE.SkinnedMesh(geo || geos[0], mat);
    mesh.add(root); mesh.frustumCulled = false;
    const skel = new THREE.Skeleton(bones);
    mesh.updateMatrixWorld(true);
    mesh.bind(skel);
    this.extra = [];
    if (!geo) for (const g of geos.slice(1)) { const m2 = new THREE.SkinnedMesh(g, mat); m2.bind(skel, mesh.matrixWorld); m2.frustumCulled = false; this.extra.push(m2); }
    // el bate
    const prof = [[0, 0], [.03, 0], [.034, .02], [.022, .06], [.024, .32], [.05, .62], [.068, .85], [.062, .92], [0, .94]].map(([r, y]) => new THREE.Vector2(r, y));
    const bat = new THREE.Mesh(new THREE.LatheGeometry(prof, 16), bend(std(0xd9a86c, { roughness: .6 })));
    bat.scale.setScalar(1.25);
    const batPivot = new THREE.Group(); batPivot.position.set(-.62, 0, 0); batPivot.add(bat);
    bat.rotation.set(0, 0, 0); bat.position.set(0, -.08, 0);
    armR.add(batPivot);
    this.body = new THREE.Group(); this.body.add(mesh, ...this.extra);
    this.root = new THREE.Group(); this.root.add(this.body);
    this.body.scale.setScalar(2.35 / H);
    this.B = { root, hips, legL, legR, spine, armL, armR, head, batPivot };
    this.H = H; this.swing = 0;
  }
  // mode: 'run' | 'idle' | 'hit'
  pose(ph, mode, t, dt) {
    const B = this.B, run = mode === 'run' ? 1 : mode === 'hit' ? .3 : 0;
    B.legL.rotation.x = .75 * run * Math.sin(ph); B.legR.rotation.x = -.75 * run * Math.sin(ph);
    B.root.position.y = run * Math.abs(Math.sin(ph)) * .06 + (mode === 'idle' ? Math.sin(t * 2) * .01 : 0);
    B.spine.rotation.y = .12 * run * Math.sin(ph); B.spine.rotation.x = run * .08;
    B.head.rotation.x = mode === 'idle' ? Math.sin(t * 1.6) * .06 : .06 * Math.sin(ph * 2);
    B.head.rotation.z = mode === 'idle' ? Math.sin(t * 1.1) * .08 : 0;
    // brazo libre (izquierdo): abajo y balanceando
    B.armL.rotation.set(-.7 * run * Math.sin(ph) + (mode === 'idle' ? Math.sin(t * 2) * .1 : 0), 0, -1.2);
    // brazo del bate (derecho): en alto y hacia delante; al golpear baja de golpe
    this.swing = mode === 'hit' ? Math.min(1, this.swing + dt * 4) : Math.max(0, this.swing - dt * 3);
    const s = this.swing, e = s < .35 ? -s / .35 * .5 : -.5 + (s - .35) / .65 * 2.4;
    B.armR.rotation.set(.1 * run * Math.sin(ph) + e * .6, .9, -.55 + (mode === 'idle' ? Math.sin(t * 2.4) * .12 : 0) + e * .9);
    B.batPivot.rotation.set(0, 0, .5 + e * .3);
  }
}

/* ---------- texturas hechas con canvas ---------- */
export function canvasTex(w, h, draw, repeat = true) {
  const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}
const rnd = (a, b) => a + Math.random() * (b - a);
export function noise(ctx, w, h, n, colors, rmin, rmax, alpha = 1) {
  for (let i = 0; i < n; i++) {
    ctx.globalAlpha = alpha * rnd(.3, 1); ctx.fillStyle = colors[i % colors.length];
    const x = rnd(0, w), y = rnd(0, h), r = rnd(rmin, rmax);
    for (const dx of [-w, 0, w]) for (const dy of [-h, 0, h]) { ctx.beginPath(); ctx.ellipse(x + dx, y + dy, r, r * rnd(.5, 1), rnd(0, 3), 0, 7); ctx.fill(); }
  }
  ctx.globalAlpha = 1;
}
export const blobTex = canvasTex(64, 64, (c, w) => { const g = c.createRadialGradient(32, 32, 0, 32, 32, 32); g.addColorStop(0, 'rgba(0,0,0,.55)'); g.addColorStop(1, 'rgba(0,0,0,0)'); c.fillStyle = g; c.fillRect(0, 0, w, w); }, false);
export function blob(w, d) { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, d), bend(new THREE.MeshBasicMaterial({ map: blobTex, transparent: true, depthWrite: false }))); m.rotation.x = -Math.PI / 2; m.position.y = .02; m.renderOrder = 1; return m; }

/* ---------- objetos del escenario (procedurales) ---------- */
export function rock(size = 1) {
  const g = new THREE.IcosahedronGeometry(.62, 1), p = g.attributes.position, v = new THREE.Vector3();
  const seed = Math.random() * 10;
  for (let i = 0; i < p.count; i++) { v.fromBufferAttribute(p, i); const k = 1 + .22 * Math.sin(v.x * 5 + seed) * Math.cos(v.z * 4 + seed * 2) + .06 * Math.sin(v.y * 9 + seed * 3); v.multiplyScalar(k); v.y = Math.max(v.y, -.25); p.setXYZ(i, v.x, v.y * 1.05, v.z); }
  g.computeVertexNormals();
  const m = new THREE.Mesh(g.toNonIndexed(), bend(std(new THREE.Color().setHSL(rnd(.06, .1), .12, rnd(.42, .52)), { flatShading: true, roughness: .9 })));
  m.geometry.computeVertexNormals();
  const w = new THREE.Group(); w.add(m); m.position.y = .25 * size; w.scale.setScalar(size); return w;
}
const stripeTex = (a, b, n = 6) => canvasTex(256, 64, (c, w, h) => { c.fillStyle = a; c.fillRect(0, 0, w, h); c.fillStyle = b; for (let i = -1; i < n + 1; i++) { c.beginPath(); c.moveTo(i * w / n, h); c.lineTo(i * w / n + h, 0); c.lineTo(i * w / n + h + w / n / 2, 0); c.lineTo(i * w / n + w / n / 2, h); c.fill(); } }, false);
let _stripe, _warn;
export function barrier(width) {       // valla de obra (hay que saltarla)
  _stripe = _stripe || stripeTex('#ffffff', '#e8262c');
  const g = new THREE.Group();
  const board = new THREE.Mesh(new THREE.BoxGeometry(width, .26, .08), bend(new THREE.MeshStandardMaterial({ map: _stripe, roughness: .5 })));
  board.position.y = .42; g.add(board);
  const leg = bend(std(0x2b2f36));
  for (const s of [-1, 1]) { const l = new THREE.Mesh(new THREE.BoxGeometry(.07, .5, .5), leg); l.position.set(s * (width / 2 - .12), .25, 0); g.add(l); }
  const lamp = bend(new THREE.MeshBasicMaterial({ color: 0xffb020 }));
  for (const s of [-1, 1]) { const b = new THREE.Mesh(new THREE.SphereGeometry(.06, 10, 8), lamp); b.position.set(s * (width / 2 - .12), .6, 0); g.add(b); }
  return g;
}
export function overhead(width, h = .72) {   // barra alta (hay que agacharse)
  _warn = _warn || stripeTex('#ffcf1a', '#1b1b1b', 8);
  const g = new THREE.Group();
  const beam = new THREE.Mesh(new THREE.BoxGeometry(width + .6, .3, .22), bend(new THREE.MeshStandardMaterial({ map: _warn, roughness: .5 })));
  beam.position.y = h + .15; g.add(beam);
  const post = bend(std(0x59616b, { metalness: .5, roughness: .4 }));
  for (const s of [-1, 1]) { const p = new THREE.Mesh(new THREE.BoxGeometry(.14, h + .3, .14), post); p.position.set(s * (width / 2 + .22), (h + .3) / 2, 0); g.add(p); }
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(1, .36), bend(new THREE.MeshBasicMaterial({ map: canvasTex(256, 92, (c, w, hh) => { c.fillStyle = '#ffcf1a'; c.fillRect(0, 0, w, hh); c.fillStyle = '#1b1b1b'; c.font = 'bold 48px Fredoka, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('¡AGÁCHATE!', w / 2, hh / 2 + 3); }, false) })));
  sign.position.set(0, h + .15, .12); g.add(sign);
  return g;
}
const CAR_COLORS = [0xffc21d, 0xe8302e, 0x2f7cff, 0xf4f4f4, 0x2fbf71, 0xff7a1a, 0x8a4dff];
export function car(color = CAR_COLORS[Math.floor(Math.random() * CAR_COLORS.length)], bus = false) {
  const g = new THREE.Group(), L = bus ? 5.2 : 2.5, W = bus ? 1.2 : 1.12;
  const paint = bend(std(color, { roughness: .35, metalness: .15 })), glass = bend(std(0x1d2a3a, { roughness: .1, metalness: .4 })), black = bend(std(0x16171a, { roughness: .8 }));
  const body = new THREE.Mesh(new THREE.BoxGeometry(W, bus ? .9 : .5, L), paint); body.position.y = bus ? .72 : .45; g.add(body);
  if (bus) {
    const win = new THREE.Mesh(new THREE.BoxGeometry(W + .02, .42, L - .5), glass); win.position.y = 1.2; g.add(win);
    const roof = new THREE.Mesh(new THREE.BoxGeometry(W, .12, L), paint); roof.position.y = 1.47; g.add(roof);
  } else {
    const cab = new THREE.Mesh(new THREE.BoxGeometry(W * .88, .4, L * .5), glass); cab.position.set(0, .88, .05); g.add(cab);
    const roof = new THREE.Mesh(new THREE.BoxGeometry(W * .9, .07, L * .46), paint); roof.position.set(0, 1.1, .05); g.add(roof);
    if (color === 0xffc21d) { const t = new THREE.Mesh(new THREE.BoxGeometry(.34, .12, .16), bend(std(0xffffff))); t.position.set(0, 1.2, .05); g.add(t); }
  }
  const wg = new THREE.CylinderGeometry(.24, .24, .18, 16);
  for (const z of bus ? [-L / 2 + .8, L / 2 - .8] : [-L / 2 + .5, L / 2 - .5]) for (const s of [-1, 1]) { const w = new THREE.Mesh(wg, black); w.rotation.z = Math.PI / 2; w.position.set(s * W / 2, .24, z); g.add(w); }
  const lightF = bend(new THREE.MeshBasicMaterial({ color: 0xfff6c8 })), lightB = bend(new THREE.MeshBasicMaterial({ color: 0xff2a2a }));
  for (const s of [-1, 1]) { const a = new THREE.Mesh(new THREE.BoxGeometry(.22, .1, .04), lightF); a.position.set(s * W * .33, bus ? .7 : .5, L / 2 + .01); g.add(a); const b = new THREE.Mesh(new THREE.BoxGeometry(.22, .1, .04), lightB); b.position.set(s * W * .33, bus ? .7 : .5, -L / 2 - .01); g.add(b); }
  g.userData.len = L; return g;
}
export function lamp() {
  const g = new THREE.Group(), m = bend(std(0x3b4350, { metalness: .6, roughness: .4 }));
  const p = new THREE.Mesh(new THREE.CylinderGeometry(.05, .07, 3.2, 8), m); p.position.y = 1.6; g.add(p);
  const a = new THREE.Mesh(new THREE.BoxGeometry(.6, .06, .08), m); a.position.set(-.28, 3.18, 0); g.add(a);
  const l = new THREE.Mesh(new THREE.BoxGeometry(.3, .08, .18), bend(new THREE.MeshBasicMaterial({ color: 0xfff1b8 }))); l.position.set(-.52, 3.12, 0); g.add(l);
  return g;
}
export function cone() {
  const g = new THREE.Group();
  const c = new THREE.Mesh(new THREE.ConeGeometry(.16, .5, 16), bend(new THREE.MeshStandardMaterial({ map: stripeTex('#ff6a00', '#ffffff', 3), roughness: .5 }))); c.position.y = .27; g.add(c);
  const b = new THREE.Mesh(new THREE.BoxGeometry(.38, .04, .38), bend(std(0xff6a00))); b.position.y = .02; g.add(b);
  return g;
}
export function bush(color = 0x3f8f3a) {
  const g = new THREE.Group(), m = bend(std(color, { flatShading: true, roughness: .9 }));
  for (let i = 0; i < 3; i++) { const s = new THREE.Mesh(new THREE.IcosahedronGeometry(rnd(.35, .55), 0), m); s.position.set(rnd(-.4, .4), rnd(.25, .4), rnd(-.3, .3)); g.add(s); }
  return g;
}
export function flower() {
  const g = new THREE.Group(), c = [0xff5a7a, 0xffd84a, 0xffffff, 0xb45aff, 0xff9d2a][Math.floor(Math.random() * 5)];
  const st = new THREE.Mesh(new THREE.CylinderGeometry(.015, .015, .3, 4), bend(std(0x2f7a2a))); st.position.y = .15; g.add(st);
  const f = new THREE.Mesh(new THREE.IcosahedronGeometry(.07, 0), bend(std(c, { flatShading: true }))); f.position.y = .32; g.add(f);
  return g;
}
export { std, rnd };
