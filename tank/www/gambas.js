// Las gambas de la pecera: modelo clonado y teñido por especie, paseos por la arena, nadar, comer y animación de patas.
import * as THREE from './lib/three.module.min.js';
import * as SkeletonUtils from './lib/SkeletonUtils.js';

export const TANK = { x: 1.48, z: .62, floor: .2, top: 3.05 };   // límites por donde se mueven
export const sandY = (x, z) => TANK.floor + .05 * Math.sin(x * 2.1 + 1) * Math.cos(z * 3) + .04 * (z + .6);
const rnd = (a, b) => a + Math.random() * (b - a);
const baseName = n => n.replace(/_\d+$/, '').replace(/\.\d+$/, '');
const NOT_SKIN = /outline|eye/i;
let restGamba = null;
// la textura de la gamba es color carne: se pasa a gris y se tiñe, para que los colores salgan vivos
const TINTED = {};
function tintedMap(tex, tint) {
  const key = tex.uuid + tint; if (TINTED[key]) return TINTED[key];
  const img = tex.image, c = document.createElement('canvas'); c.width = img.width; c.height = img.height; const x = c.getContext('2d'); x.drawImage(img, 0, 0);
  const d = x.getImageData(0, 0, c.width, c.height), p = d.data, col = new THREE.Color(tint), r = col.r * 255, g = col.g * 255, b = col.b * 255;
  for (let i = 0; i < p.length; i += 4) { const l = Math.min(1.25, (p[i] * .3 + p[i + 1] * .55 + p[i + 2] * .15) / 200); p[i] = Math.min(255, r * l); p[i + 1] = Math.min(255, g * l); p[i + 2] = Math.min(255, b * l); }
  x.putImageData(d, 0, 0);
  const t = new THREE.CanvasTexture(c); t.colorSpace = tex.colorSpace; t.flipY = tex.flipY; t.wrapS = tex.wrapS; t.wrapT = tex.wrapT; t.channel = tex.channel;
  return (TINTED[key] = t);
}

export class ShrimpActor {
  constructor(src, sp, { lvl = 1, baby = 0, uid } = {}) {
    this.sp = sp; this.lvl = lvl; this.uid = uid; this.grow = baby ? .35 : 1; this.baby = baby;
    const g = src[sp.model];
    const sc = sp.model === 'langostino' ? g.scene.clone(true) : SkeletonUtils.clone(g.scene);
    if (!restGamba) { restGamba = {}; src.gamba.scene.traverse(o => { if (o.isBone) restGamba[baseName(o.name)] = [o.position.clone(), o.quaternion.clone(), o.scale.clone()]; }); }
    this.bones = {}; this.mats = [];
    sc.traverse(o => {
      if (o.isBone) { const n = baseName(o.name); if (sp.model === 'chaqueta' && restGamba[n]) { o.position.copy(restGamba[n][0]); o.quaternion.copy(restGamba[n][1]); o.scale.copy(restGamba[n][2]); } this.bones[n] = o; }
      if (o.isMesh) {
        o.frustumCulled = false; o.castShadow = true;
        if (NOT_SKIN.test(o.material.name || '') || NOT_SKIN.test(o.name || '')) return;
        const m = o.material = o.material.clone(); if (m.map && sp.tint !== 0xffffff) { m.map = tintedMap(m.map, sp.tint); m.color.set(0xffffff); } else m.color.set(sp.tint);
        if (sp.fx === 'ghost') { m.transparent = true; m.opacity = .42; m.depthWrite = false; if (m.emissive) { m.emissive.set(0x6ac8ff); m.emissiveIntensity = .35; } }
        if (sp.fx === 'gold' && m.emissive) { m.metalness = .55; m.roughness = .25; m.emissive.set(0x8a5a00); m.emissiveIntensity = .45; }
        this.mats.push(m);
      }
    });
    this.rest = {}; for (const [n, b] of Object.entries(this.bones)) this.rest[n] = b.rotation.clone();
    // tamaño: largo L, cabeza hacia -z
    sc.updateMatrixWorld(true);
    const b = new THREE.Box3().setFromObject(sc, true), L = sp.model === 'langostino' ? .84 : .74, k = L / (b.max.z - b.min.z);
    this.holder = new THREE.Group(); this.holder.add(sc); sc.position.set(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2);
    this.holder.scale.setScalar(k); this.holder.rotation.y = Math.PI;
    this.pitchG = new THREE.Group(); this.pitchG.add(this.holder);
    this.root = new THREE.Group(); this.root.add(this.pitchG);
    this.h = (b.max.y - b.min.y) * k; this.L = L;
    const x = rnd(-1.2, 1.2), z = rnd(-.4, .4);
    this.pos = new THREE.Vector3(x, baby ? sandY(x, z) : 2.6, z); this.vel = new THREE.Vector3(); this.yaw = rnd(0, 6.28);
    this.mode = baby ? 'walk' : 'swim'; this.target = this.pos.clone(); this.newTarget(); this.wait = 0; this.ph = rnd(0, 6); this.fedT = 0; this.flick = 0; this.hop = 0;
    this.coinT = rnd(1, 4);
  }
  get scale() { return this.grow; }
  newTarget(mode) {
    this.mode = mode || (Math.random() < .3 ? 'swim' : 'walk');
    const x = rnd(-TANK.x, TANK.x), z = rnd(-TANK.z, TANK.z);
    this.target.set(x, this.mode === 'swim' ? rnd(.8, TANK.top - .2) : sandY(x, z), z);
  }
  update(dt, t, food) {
    if (this.grow < 1) this.grow = Math.min(1, this.grow + dt / 90);
    this.fedT = Math.max(0, this.fedT - dt);
    // buscar comida
    if (food.length && this.fedT < 100 && this.mode !== 'eat') { let best = null, bd = 3.6; for (const f of food) { const d = f.pos.distanceTo(this.pos); if (d < bd && !f.taken) { bd = d; best = f; } } if (best) { this.mode = 'eat'; this.food = best; } }
    let sp = .22, tgt = this.target;
    if (this.mode === 'eat') {
      if (!this.food || this.food.gone) { this.mode = 'walk'; this.newTarget('walk'); }
      else { tgt = this.food.pos; sp = .55; if (this.pos.distanceTo(tgt) < .1) { this.food.gone = true; this.fedT = 90; this.hop = .3; this.onEat && this.onEat(this); this.newTarget('walk'); } }
    }
    if (this.mode === 'swim') sp = .45 + this.flick;
    if (this.wait > 0) { this.wait -= dt; sp = 0; }
    const d = tgt.distanceTo(this.pos);
    if (d < .06 && this.mode !== 'eat' && this.wait <= 0) { this.wait = rnd(.8, 4); this.newTarget(this.mode === 'swim' && Math.random() < .6 ? 'walk' : undefined); }
    // impulsos con la cola al nadar
    this.flick = Math.max(0, this.flick - dt * 1.4); if ((this.mode === 'swim' || this.mode === 'eat') && Math.random() < dt * .8) this.flick = .5;
    const want = d > .001 && sp > 0 ? tgt.clone().sub(this.pos).normalize().multiplyScalar(sp * Math.min(1, d * 3)) : new THREE.Vector3();
    this.vel.lerp(want, Math.min(1, dt * 2.5));
    this.pos.addScaledVector(this.vel, dt);
    const floor = sandY(this.pos.x, this.pos.z);
    if (this.mode === 'walk' && this.pos.y > floor + .02) this.pos.y = Math.max(floor, this.pos.y - dt * .5);   // bajar posándose
    this.pos.y = THREE.MathUtils.clamp(this.pos.y, floor, TANK.top);
    this.pos.x = THREE.MathUtils.clamp(this.pos.x, -TANK.x, TANK.x); this.pos.z = THREE.MathUtils.clamp(this.pos.z, -TANK.z, TANK.z);
    const hs = Math.hypot(this.vel.x, this.vel.z);
    if (hs > .03) { const a = Math.atan2(-this.vel.x, -this.vel.z); let dd = a - this.yaw; dd = Math.atan2(Math.sin(dd), Math.cos(dd)); this.yaw += dd * Math.min(1, dt * 4); }
    const onFloor = this.pos.y < floor + .03;
    const pitch = onFloor ? 0 : THREE.MathUtils.clamp(Math.atan2(this.vel.y, hs + .05), -.7, .7);
    this.pitchG.rotation.x = THREE.MathUtils.lerp(this.pitchG.rotation.x, pitch, Math.min(1, dt * 3));
    this.hop = Math.max(0, this.hop - dt);
    this.root.position.set(this.pos.x, this.pos.y + Math.sin(this.hop / .3 * Math.PI) * .12, this.pos.z);
    this.root.rotation.y = this.yaw; this.root.scale.setScalar(this.grow * (this.evo || 1) * (1 + this.hop * .6));
    // animación
    const speed = this.vel.length();
    this.ph += dt * (onFloor ? speed * 40 : 14 + this.flick * 30);
    this.pose(t, onFloor ? Math.min(1, speed * 5) : .3, !onFloor);
    if (this.sp.fx === 'rainbow') for (const m of this.mats) m.color.setHSL((t * .15 + this.uid * .17) % 1, .8, .62);
  }
  pose(t, run, swim) {
    const B = this.bones, R = this.rest, set = (n, ax, v) => { const b = B[n]; if (b) b.rotation[ax] = R[n][ax] + v; };
    if (!B.Head && !B.Tail_1) { this.holder.rotation.z = Math.sin(this.ph * .5) * .05 * (run + .3); return; }   // langostino sin huesos
    const ph = this.ph;
    for (const [pos, off] of [['Front', 0], ['Center', 2.1], ['Back', 4.2]]) for (const [side, so] of [['L', 0], ['R', Math.PI]]) {
      set(`Leg_${pos}_Top${side}`, 'x', (swim ? .35 : run * .7) * Math.sin(ph + off + so) + (swim ? .5 : 0));
      set(`Leg_${pos}_Middle${side}`, 'x', (swim ? .25 : run * .4) * Math.sin(ph + off + so + 1.2));
    }
    for (let i = 1; i <= 5; i++) set(`Tail_${i}`, 'x', (swim ? .05 + this.flick * .5 * Math.sin(t * 25) : .06) + Math.sin(ph * .3 - i * .7) * (.05 + (swim ? .06 : 0)));
    for (let i = 1; i <= 15; i++) for (const s of ['L', 'R']) set(`Feelers_${i}${s}`, 'x', Math.sin(t * 3 + i * .45 + (s === 'L' ? 0 : 1)) * .07);
    set('Head', 'x', Math.sin(t * 1.5) * .04);
  }
  hitTest(ray) { const c = this.root.position.clone(); c.y += .1 * this.grow; const r = .3 * this.grow; return ray.distanceSqToPoint(c) < r * r ? ray.origin.distanceTo(c) : null; }
}
