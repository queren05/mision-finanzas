// Carga de modelos 3D, personajes (gamba y Tung con esqueleto propio) y objetos del escenario.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import { mergeGeometries } from './lib/BufferGeometryUtils.js';

/* ---------- mundo curvo: el suelo «cae» a lo lejos (estilo Subway Surfers) ---------- */
export const BEND = { y: { value: 0 }, x: { value: 0 } };
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

/* ---------- fundir objetos en pocas mallas (menos llamadas de dibujo) ----------
   Junta todas las piezas de un grupo que solo tienen color (sin textura) en una única malla con color por vértice.
   Las piezas con textura o transparencia se quedan aparte. El grupo debe estar ya colocado (sin padres). */
const BAKED = { front: null, double: null };
const f32 = (a, n) => { const r = new Float32Array(a.count * n); for (let i = 0; i < a.count; i++) { r[i * n] = a.getX(i); r[i * n + 1] = a.getY(i); r[i * n + 2] = a.getZ(i); } return new THREE.BufferAttribute(r, n); };
export function bake(root) {
  BAKED.front = BAKED.front || bend(new THREE.MeshStandardMaterial({ vertexColors: true, roughness: .75 }));
  BAKED.double = BAKED.double || bend(new THREE.MeshStandardMaterial({ vertexColors: true, roughness: .75, side: THREE.DoubleSide }));
  root.updateMatrixWorld(true);
  const out = new THREE.Group(), parts = { front: [], double: [] }, c = new THREE.Color();
  root.traverse(o => {
    if (!o.isMesh) return;
    const mats = Array.isArray(o.material) ? o.material : [o.material], m0 = mats[0];
    if (o.isSkinnedMesh || o.isInstancedMesh || mats.length > 1 || m0.map || m0.transparent || m0.vertexColors) {
      const k = new THREE.Mesh(o.geometry.clone().applyMatrix4(o.matrixWorld), mats.length > 1 ? o.material.map(bend) : bend(o.material)); k.frustumCulled = o.frustumCulled; out.add(k); return;
    }
    let g = o.geometry.clone().applyMatrix4(o.matrixWorld); if (g.index) g = g.toNonIndexed();
    const pos = f32(g.attributes.position, 3), ng = new THREE.BufferGeometry(); ng.setAttribute('position', pos);
    if (g.attributes.normal) ng.setAttribute('normal', f32(g.attributes.normal, 3)); else ng.computeVertexNormals();
    c.copy(m0.color); if (m0.emissive && m0.emissiveIntensity) { c.r = Math.min(1, c.r + m0.emissive.r * m0.emissiveIntensity * .6); c.g = Math.min(1, c.g + m0.emissive.g * m0.emissiveIntensity * .6); c.b = Math.min(1, c.b + m0.emissive.b * m0.emissiveIntensity * .6); }
    if (m0.isMeshBasicMaterial) c.multiplyScalar(1.2);
    const col = new Float32Array(pos.count * 3); for (let i = 0; i < pos.count; i++) { col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b; }
    ng.setAttribute('color', new THREE.BufferAttribute(col, 3));
    parts[m0.side === THREE.DoubleSide ? 'double' : 'front'].push(ng);
  });
  for (const k of ['front', 'double']) if (parts[k].length) out.add(new THREE.Mesh(mergeGeometries(parts[k]), BAKED[k]));
  return out;
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
// Los gorros usan sombreado «toon» y un contorno negro, igual que el dibujo de las gambas.
let TOON_G = null;
const toon = (c, o = {}) => {
  if (!TOON_G) { TOON_G = new THREE.DataTexture(new Uint8Array([125, 190, 255]), 3, 1, THREE.RedFormat); TOON_G.minFilter = TOON_G.magFilter = THREE.NearestFilter; TOON_G.needsUpdate = true; }
  return new THREE.MeshToonMaterial(Object.assign({ color: c, gradientMap: TOON_G }, o));
};
const OUTLINE = new THREE.MeshBasicMaterial({ color: 0x150b1f, side: THREE.BackSide });
function hatMesh(id, gltfs) {
  const g = new THREE.Group();
  // piv: todo el gorro se puede inclinar junto; ol: grosor del contorno (0 = sin contorno)
  let piv = g;
  const add = (geo, mat, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, ol = .0042) => {
    const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.rotation.set(rx, ry, rz); piv.add(m);
    if (ol) { geo.computeBoundingSphere(); const o = new THREE.Mesh(geo, OUTLINE); o.position.copy(m.position); o.rotation.copy(m.rotation); o.scale.setScalar(1 + ol / Math.max(.012, geo.boundingSphere.radius)); piv.add(o); }
    return m;
  };
  const tilt = (rx, rz = 0) => { piv = new THREE.Group(); piv.rotation.set(rx, 0, rz); g.add(piv); };
  switch (id) {
    case 'fiesta': {
      tilt(-.22);
      add(new THREE.ConeGeometry(.046, .14, 28), toon(0xff4fa3), 0, .06, 0);
      for (let i = 0; i < 3; i++) add(new THREE.TorusGeometry(.037 - i * .0115, .0045, 8, 28), toon([0xffe14d, 0x4fd1ff, 0x7cf07c][i]), 0, .02 + i * .032, 0, Math.PI / 2, 0, 0, 0);
      add(new THREE.SphereGeometry(.017, 14, 10), toon(0xffe14d), 0, .135, 0);
      break;
    }
    case 'gorra': {
      tilt(-.1);
      const red = toon(0xe8302e);
      add(new THREE.SphereGeometry(.056, 28, 14, 0, Math.PI * 2, 0, Math.PI / 2), red, 0, -.004, 0).scale.set(1, .9, 1.05);
      add(new THREE.CylinderGeometry(.066, .066, .011, 28, 1, false, -Math.PI / 2, Math.PI), toon(0xc2221f), 0, -.004, .034, .14, 0, 0).scale.set(1, 1, 1.55);
      add(new THREE.SphereGeometry(.009, 10, 8), toon(0xffffff), 0, .046, 0);
      add(new THREE.TorusGeometry(.055, .004, 6, 28), toon(0xffffff), 0, .004, 0, Math.PI / 2, 0, 0, 0);
      break;
    }
    case 'gafas': {   // lentes redondas pegadas a los dos lados de la cabeza, a la altura del ojo; las patillas van hacia atrás (+z)
      const lens = new THREE.MeshStandardMaterial({ color: 0x0c0f1c, roughness: .12, metalness: .5 }), frame = toon(0x1c1c24);
      for (const s of [-1, 1]) {
        add(new THREE.CylinderGeometry(.03, .03, .012, 24), lens, s * .043, -.055, .05, 0, 0, Math.PI / 2, .0035);
        add(new THREE.TorusGeometry(.03, .0055, 8, 24), frame, s * .049, -.055, .05, 0, Math.PI / 2, 0, 0);
        add(new THREE.SphereGeometry(.007, 8, 6), toon(0xffffff), s * .052, -.045, .06, 0, 0, 0, 0);
      }
      add(new THREE.TorusGeometry(.044, .0045, 8, 24, Math.PI), frame, 0, -.055, .05, 0, 0, 0, .002);
      break;
    }
    case 'auris': {
      tilt(0);
      add(new THREE.TorusGeometry(.052, .0075, 10, 32, Math.PI), toon(0x26262e), 0, -.022, 0, 0, 0, 0, .003);
      for (const s of [-1, 1]) {
        add(new THREE.CylinderGeometry(.025, .025, .02, 24), toon(0x31e0c4), s * .055, -.028, 0, 0, 0, Math.PI / 2);
        add(new THREE.CylinderGeometry(.016, .016, .006, 20), toon(0xffffff), s * .066, -.028, 0, 0, 0, Math.PI / 2, 0);
      }
      break;
    }
    case 'chistera': {
      tilt(-.05, .06);
      const black = toon(0x22222b);
      add(new THREE.CylinderGeometry(.078, .078, .009, 36), black, 0, .0, 0);
      add(new THREE.CylinderGeometry(.046, .047, .095, 32), black, 0, .052, 0);
      add(new THREE.CylinderGeometry(.0475, .0475, .02, 32), toon(0xd12d3a), 0, .02, 0, 0, 0, 0, 0);
      add(new THREE.CylinderGeometry(.04, .04, .004, 24), toon(0x3a3a46), 0, .1, 0, 0, 0, 0, 0);
      break;
    }
    case 'vikingo': {
      tilt(0);
      add(new THREE.SphereGeometry(.057, 28, 14, 0, Math.PI * 2, 0, Math.PI / 2), toon(0xb9c2cc), 0, -.004, 0).scale.set(1, .9, 1.05);
      add(new THREE.TorusGeometry(.057, .008, 8, 32), toon(0x8a5a2b), 0, -.002, 0, Math.PI / 2, 0, 0);
      add(new THREE.BoxGeometry(.012, .05, .012), toon(0x8a5a2b), 0, .03, .02, -.15, 0, 0, .003);
      for (const s of [-1, 1]) {
        add(new THREE.ConeGeometry(.017, .075, 14), toon(0xf6ecd2), s * .064, .04, 0, 0, 0, -s * .75);
        add(new THREE.SphereGeometry(.014, 10, 8), toon(0xf6ecd2), s * .054, .004, 0, 0, 0, 0, 0);
      }
      break;
    }
    case 'halo': {
      const m = add(new THREE.TorusGeometry(.05, .009, 10, 40), new THREE.MeshBasicMaterial({ color: 0xfff1a6 }), 0, .07, 0, Math.PI / 2, 0, 0, .0035);
      m.userData.spin = 1; break;
    }
    case 'corona': {
      tilt(-.08);
      const gold = toon(0xffc93a, { emissive: 0x3a2400 });
      add(new THREE.CylinderGeometry(.05, .053, .03, 32, 1, true), Object.assign(gold.clone(), { side: THREE.DoubleSide }), 0, .012, 0, 0, 0, 0, 0);
      add(new THREE.TorusGeometry(.052, .005, 8, 32), gold, 0, .0, 0, Math.PI / 2, 0, 0);
      for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; add(new THREE.ConeGeometry(.0115, .036, 8), gold, Math.sin(a) * .051, .04, Math.cos(a) * .051, 0, 0, 0, .002); add(new THREE.SphereGeometry(.0075, 10, 8), toon([0xff3355, 0x3fa9ff, 0x4fe37a][i % 3]), Math.sin(a) * .054, .012, Math.cos(a) * .054, 0, 0, 0, 0); }
      break;
    }
    case 'lazo': {
      tilt(0, .35);
      const pink = toon(0xff5aa5);
      for (const sx of [-1, 1]) { const m = add(new THREE.ConeGeometry(.032, .06, 4), pink, sx * .03, .022, 0, 0, 0, sx * Math.PI / 2); m.scale.set(1, 1, .45); }
      add(new THREE.SphereGeometry(.014, 12, 10), toon(0xff2f86), 0, .022, 0);
      break;
    }
    case 'flor': {
      tilt(0, -.3);
      for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; const p = add(new THREE.SphereGeometry(.02, 12, 8), toon(0xffffff), Math.cos(a) * .024, .02, Math.sin(a) * .024, 0, 0, 0, .002); p.scale.set(1, .45, 1); }
      add(new THREE.SphereGeometry(.014, 12, 8), toon(0xffd02a), 0, .026, 0);
      break;
    }
    case 'cocinero': {
      tilt(-.06);
      const w = toon(0xffffff);
      add(new THREE.CylinderGeometry(.05, .05, .045, 28), w, 0, .02, 0);
      for (const [x, z] of [[0, 0], [-.026, .012], [.026, .012], [0, -.022], [.0, .028]]) add(new THREE.SphereGeometry(.036, 14, 10), w, x, .07, z, 0, 0, 0, .0025);
      break;
    }
    case 'reno': {
      const br = toon(0x8a5a2b);
      for (const s of [-1, 1]) {
        add(new THREE.CylinderGeometry(.006, .008, .08, 8), br, s * .035, .035, 0, 0, 0, -s * .35, .002);
        add(new THREE.CylinderGeometry(.005, .006, .04, 8), br, s * .055, .07, .0, 0, 0, -s * 1.1, .002);
        add(new THREE.CylinderGeometry(.005, .006, .035, 8), br, s * .038, .085, -.01, .4, 0, s * .2, .002);
      }
      break;
    }
    case 'santa': {
      tilt(-.12, .1);
      add(new THREE.ConeGeometry(.05, .11, 28), toon(0xe32b2b), 0, .055, 0).rotation.z = -.35;
      add(new THREE.TorusGeometry(.048, .012, 10, 28), toon(0xffffff), 0, .002, 0, Math.PI / 2, 0, 0, .002);
      add(new THREE.SphereGeometry(.016, 12, 10), toon(0xffffff), .035, .1, 0);
      break;
    }
    case 'bruja': {
      tilt(-.1, .12);
      const pu = toon(0x3d2470);
      add(new THREE.CylinderGeometry(.085, .085, .008, 36), pu, 0, .0, 0);
      const c = add(new THREE.ConeGeometry(.045, .14, 28), pu, 0, .07, 0); c.rotation.z = -.25;
      add(new THREE.CylinderGeometry(.047, .047, .014, 28), toon(0xb45aff), 0, .012, 0, 0, 0, 0, 0);
      add(new THREE.BoxGeometry(.016, .012, .006), toon(0xffd84a), 0, .012, .047, 0, 0, 0, 0);
      break;
    }
    case 'mexicano': {
      tilt(-.05);
      const y = toon(0xf2c75a), r = toon(0xe23c3c);
      add(new THREE.CylinderGeometry(.11, .11, .007, 40), y, 0, .0, 0);
      add(new THREE.TorusGeometry(.108, .007, 8, 40), y, 0, .006, 0, Math.PI / 2, 0, 0, .002);
      add(new THREE.ConeGeometry(.04, .07, 28), y, 0, .04, 0);
      add(new THREE.CylinderGeometry(.034, .037, .012, 28), r, 0, .016, 0, 0, 0, 0, 0);
      for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; add(new THREE.SphereGeometry(.006, 8, 6), toon([0x4fe37a, 0xe23c3c][i % 2]), Math.sin(a) * .1, .006, Math.cos(a) * .1, 0, 0, 0, 0); }
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
// rig: 'chumbud' (esqueleto con patas, antenas y cola), 'clip' (animación incluida), 'static' (sin huesos)
// len: largo en metros; hat: [altura, avance] del punto donde va el gorro (metros, con la cabeza hacia -z)
export const PLAYERS = {
  gamba: { file: 'models/char/gamba.glb', rig: 'chumbud', len: 1.45 },
  chaqueta: { file: 'models/char/gamba_chaqueta.glb', rig: 'chumbud', len: 1.45, cheer: true },
  langostino: { file: 'models/char/langostino.glb', rig: 'static', len: 1.25, hat: [.52, -.2] },
  mysis: { file: 'models/char/gamba_mysis.glb', rig: 'clip', len: 1.7, walk: 'walk1', idle: 'idle1', hat: [.42, -.52] },
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
        if (!NOT_SKIN.test(m.name || '') && !NOT_SKIN.test(o.name || '')) { skinPatch(m); bodies.push(m); m.userData.op0 = m.opacity; m.userData.tr0 = m.transparent; m.forceSinglePass = true; }
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
    const M = { cfg, wrap, holder, sc, bones, rest, restAll, bodies, k, h: (b.max.y - b.min.y) * k };
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
  async use(id) { await this.ensure(id); this.useNow(id); }
  useNow(id) {   // síncrono: el modelo tiene que estar ya cargado
    const M = this.models[id];
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

export { std, rnd };
