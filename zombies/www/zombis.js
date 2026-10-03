// Zombis: navegación por el mapa (campo de flujo sobre la rejilla), entrada por ventanas, ataques y muerte.
import * as THREE from './lib/three.module.min.js';
import * as SkeletonUtils from './lib/SkeletonUtils.js';
import { GW, GH, idx, cellAt, walkable, WINDOWS, WIN, FLOOR, DOOR } from './mapa.js';

export const ZH = 1.3;                // altura de un zombi (un poco más que la gamba de pie)
const R = .3;                         // radio de colisión
/* ---------- campo de flujo hacia el jugador ---------- */
export let dist = new Int16Array(1);
let lastCell = -1;
const N8 = [[1, 0, 10], [-1, 0, 10], [0, 1, 10], [0, -1, 10], [1, 1, 14], [1, -1, 14], [-1, 1, 14], [-1, -1, 14]];
export function flow(px, pz, force = false) {
  if (dist.length !== GW * GH) { dist = new Int16Array(GW * GH); lastCell = -1; }
  const cx = Math.floor(px), cz = Math.floor(pz), c = idx(cx, cz);
  if (c === lastCell && !force) return; lastCell = c;
  dist.fill(32000); if (!walkable(cx, cz)) return;
  // Dijkstra simple con cola de cubos (los costes son 10 y 14)
  const buckets = [[c]]; dist[c] = 0;
  for (let d = 0; d < buckets.length; d++) {
    const b = buckets[d]; if (!b) continue;
    for (const i of b) {
      if (dist[i] !== d) continue; const x = i % GW, z = (i - x) / GW;
      for (const [dx, dz, cost] of N8) {
        const nx = x + dx, nz = z + dz; if (!walkable(nx, nz)) continue;
        if (dx && dz && (!walkable(x + dx, z) || !walkable(x, z + dz))) continue;   // no cortar esquinas
        const ni = idx(nx, nz), nd = d + cost; if (nd < dist[ni]) { dist[ni] = nd; (buckets[nd] || (buckets[nd] = [])).push(ni); }
      }
    }
  }
}
export const resetFlow = () => lastCell = -1;
// ¿se ve el punto b desde a sin muros por medio? (para ir en línea recta)
export function clearLine(ax, az, bx, bz) {
  const d = Math.hypot(bx - ax, bz - az), n = Math.ceil(d / .25);
  for (let i = 1; i < n; i++) { const t = i / n, x = ax + (bx - ax) * t, z = az + (bz - az) * t; if (!walkable(Math.floor(x), Math.floor(z))) return false; }
  return true;
}
// empuja un círculo fuera de las casillas que no se pueden pisar
export function collide(p, r, ok = walkable) {
  const cx = Math.floor(p.x), cz = Math.floor(p.z);
  for (let z = cz - 1; z <= cz + 1; z++) for (let x = cx - 1; x <= cx + 1; x++) {
    if (ok(x, z)) continue;
    const nx = Math.max(x, Math.min(x + 1, p.x)), nz = Math.max(z, Math.min(z + 1, p.z)), dx = p.x - nx, dz = p.z - nz, d2 = dx * dx + dz * dz;
    if (d2 < r * r) {
      if (d2 > 1e-8) { const d = Math.sqrt(d2), k = (r - d) / d; p.x += dx * k; p.z += dz * k; }
      else { // el centro está dentro de la casilla: sacarlo por el lado más cercano
        const ex = [p.x - x, x + 1 - p.x, p.z - z, z + 1 - p.z], m = Math.min(...ex), i = ex.indexOf(m);
        if (i === 0) p.x = x - r; else if (i === 1) p.x = x + 1 + r; else if (i === 2) p.z = z - r; else p.z = z + 1 + r;
      }
    }
  }
}

/* ---------- el zombi ---------- */
// modelos de zombi: Kenney (bloques), zombi realista (bachosoftdesign) y corredor (Quaternius)
const id = n => n;
export const KENNEY = { h: .83, skinned: false, eyes: true, head: /^head$/, walkSpeed: 1.1, runSpeed: 3.2, clips: Object.fromEntries(['walk', 'sprint', 'attack-melee-right', 'attack-melee-left', 'die', 'idle', 'crouch', 'interact-right'].map(n => [n, id(n)])) };
export const REAL = { skinned: true, eyes: false, head: /Head$/, walkSpeed: .9, runSpeed: 2.2, clips: { walk: ['Armature|Walk', 'Armature|Walk2'], sprint: 'Armature|Walk2', 'attack-melee-right': 'Armature|Attack', 'attack-melee-left': 'Armature|Headbutt', die: ['Armature|Die', 'Armature|Die2'], idle: 'Armature|Idle', crouch: 'Armature|Idle', 'interact-right': 'Armature|Attack' } };
export const RUNNER = { skinned: true, eyes: false, head: /^Head$/, walkSpeed: 1, runSpeed: 3.4, clips: { walk: 'Zombie|ZombieWalk', sprint: 'Zombie|ZombieRun', 'attack-melee-right': 'Zombie|ZombieBite', 'attack-melee-left': 'Zombie|ZombieBite', die: null, idle: 'Zombie|ZombieIdle', crouch: 'Zombie|ZombieCrawl', 'interact-right': 'Zombie|ZombieBite' } };
// marchas medidas sobre las animaciones (recorrido del pie respecto a la cadera): el zombi avanza justo lo que cubre su animación, así los pies no patinan
KENNEY.gaits = [{ clip: 'walk', v: 1.1, lo: .8, hi: 1.5 }, { clip: 'sprint', v: 3.2, lo: .8, hi: 1.4 }];
REAL.gaits = [{ clip: 'Armature|Walk', v: .35, lo: .85, hi: 1.6 }, { clip: 'Armature|Walk2', v: .55, lo: .85, hi: 1.8 }, { clip: 'Armature|Running_Crawl', v: 1.27, lo: .7, hi: 1.4, crawl: true }];
RUNNER.gaits = [{ clip: 'Zombie|ZombieWalk', v: .38, lo: .85, hi: 2.2 }, { clip: 'Zombie|ZombieRun', v: 2.09, lo: .55, hi: 1.5 }];
function pickGait(def, s) {
  let best = null, bd = 1e9;
  for (const g of def.gaits) { const lo = g.v * g.lo, hi = g.v * g.hi, d = (s < lo ? lo - s : s > hi ? s - hi : 0) + Math.random() * .05; if (d < bd) { bd = d; best = g; } }
  return best;
}
const angDiff = (a, b) => Math.atan2(Math.sin(a - b), Math.cos(a - b));
// zombi de ciudad (Rikindle3D, CC0): texturas PBR; solo lo usamos en las marchas lentas porque su clip de correr viene vacío
export const CITY = { skinned: true, eyes: false, pbr: true, head: /Head$/, clips: { walk: 'Shamble', sprint: 'Walk', 'attack-melee-right': 'Attack', 'attack-melee-left': 'Attack2', die: ['Death'], idle: ['Idle', 'Idle2'], crouch: 'Idle2', 'interact-right': 'Attack3' },
  gaits: [{ clip: 'Walk', v: .35, lo: .9, hi: 1.5 }, { clip: 'Shamble', v: .64, lo: .85, hi: 1.8 }] };
// instante (en segundos del clip) en que la mano llega al máximo y en que termina el golpe, medidos sobre cada animación
KENNEY.atk = { 'attack-melee-right': { hit: .42, end: .9 }, 'attack-melee-left': { hit: .42, end: .9 } };
REAL.atk = { 'attack-melee-right': { hit: 1.0, end: 1.45 }, 'attack-melee-left': { hit: .5, end: 1.0 } };
RUNNER.atk = { 'attack-melee-right': { hit: 1.0, end: 1.6 }, 'attack-melee-left': { hit: 1.0, end: 1.6 } };
CITY.atk = { 'attack-melee-right': { hit: 1.0, end: 1.35 }, 'attack-melee-left': { hit: 1.5, end: 1.95 } };
const ATK_RATE = 1.5;   // los golpes de estas animaciones son lentos: se aceleran para que el zombi no avise tanto
const eyeTex = (() => { const c = document.createElement('canvas'); c.width = c.height = 32; const x = c.getContext('2d'), g = x.createRadialGradient(16, 16, 0, 16, 16, 16); g.addColorStop(0, '#fff'); g.addColorStop(.25, '#ffd040'); g.addColorStop(1, 'rgba(255,120,0,0)'); x.fillStyle = g; x.fillRect(0, 0, 32, 32); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; })();
const EYE_MAT = [new THREE.SpriteMaterial({ map: eyeTex, color: 0xffb030, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }), new THREE.SpriteMaterial({ map: eyeTex, color: 0x60c8ff, blending: THREE.AdditiveBlending, depthWrite: false, fog: false })];
const _v = new THREE.Vector3(), _s = new THREE.Vector3();
export class Zombie {
  constructor(game, gltf, opt) {
    this.g = game; this.kind = opt.kind || 'zombie';
    // def: cómo es el modelo (alto original, si tiene esqueleto y qué animación es cada cosa)
    const def = this.def = opt.def || KENNEY;
    const o = def.skinned ? SkeletonUtils.clone(gltf.scene) : gltf.scene.clone(true); o.traverse(m => { if (m.isMesh) { m.castShadow = true; m.frustumCulled = false; } });
    if (!def.h) { gltf.scene.updateMatrixWorld(true); def.h = new THREE.Box3().setFromObject(gltf.scene).getSize(new THREE.Vector3()).y; }
    this.hs = ZH * (opt.scale || 1) / 1.85;   // escala respecto a un zombi de 1,85 m (para las zonas de impacto)
    this.k = ZH / def.h * (opt.scale || 1);
    o.scale.setScalar(this.k); this.root = new THREE.Group(); this.root.add(o); this.model = o; game.scene.add(this.root);
    o.traverse(m => { if (!this.head && def.head.test(m.name)) this.head = m; });
    // cada zombi con un tono algo distinto
    const tintC = def.pbr ? new THREE.Color().setScalar(.75 + Math.random() * .25) : def.skinned ? new THREE.Color().setHSL(.3, .1 + Math.random() * .15, .7 + Math.random() * .3) : new THREE.Color().setHSL(.25 + (Math.random() - .5) * .18, .25 + Math.random() * .3, .55 + Math.random() * .3);
    o.traverse(m => { if (m.isMesh) { m.material = m.material.clone(); m.material.color.multiply(tintC); } });
    if (this.head && def.eyes) for (const sx of [-1, 1]) { const e = new THREE.Sprite(EYE_MAT[opt.kind === 'skel' ? 1 : 0]); e.position.set(sx * .045, .085, .118); e.scale.setScalar(.06); this.head.add(e); }
    this.mixer = new THREE.AnimationMixer(o);
    const clip = n => { const list = [].concat(n || []); const pick = list[Math.floor(Math.random() * list.length)]; return gltf.animations.find(a => a.name === pick); };
    this.act = {}; for (const n of ['walk', 'sprint', 'attack-melee-right', 'attack-melee-left', 'die', 'idle', 'crouch', 'interact-right']) { const c = clip(def.clips[n]); if (c) this.act[n] = this.mixer.clipAction(c); }
    for (const n of ['attack-melee-right', 'attack-melee-left', 'die', 'interact-right']) if (this.act[n]) { this.act[n].setLoop(THREE.LoopOnce); this.act[n].clampWhenFinished = true; }
    this.cur = null;
    const gait = pickGait(def, opt.speed), sc = opt.scale || 1, gclip = gltf.animations.find(a => a.name === gait.clip);
    this.act.gait = this.mixer.clipAction(gclip); this.gait = gait; this.hy = gait.crawl ? .42 : 1;
    this.cv = gait.v * sc;                                                    // m/s que recorre un ciclo de la animación
    this.gts = THREE.MathUtils.clamp(opt.speed / gait.v / sc * (.94 + Math.random() * .12), gait.lo, gait.hi);   // velocidad de reproducción
    this.hp = opt.hp; this.maxHp = opt.hp; this.speed = this.cv * this.gts; this.run = 'gait'; this.turnRate = 2.6 + this.speed * .9;
    this.pos = new THREE.Vector3(); this.vel = new THREE.Vector3(); this.yaw = 0; this.atkCd = 0; this.atkT = -1; this.groanT = Math.random() * 4 + 1;
    this.state = 'approach'; this.t = 0; this.dead = false; this.win = null; this.boardT = 0; this.stuck = 0;
    this.play(this.run);
  }
  play(n, fade = .2) {
    const a = this.act[n]; if (!a || this.cur === a) return;
    a.reset().play(); if (this.cur) this.cur.crossFadeTo(a, fade, false); this.cur = a;
    a.timeScale = n === 'gait' ? this.gts : 1;
  }
  // aparece fuera de una ventana y va hacia ella
  spawnAtWindow(w) {
    this.win = w; this.state = 'approach';
    const ox = w.out[0] - w.inn[0], oz = w.out[1] - w.inn[1];   // hacia fuera
    const lat = (Math.random() - .5) * 3;
    this.pos.set(w.out[0] + .5 + ox * 2 + (ox ? 0 : lat), 0, w.out[1] + .5 + oz * 2 + (oz ? 0 : lat));
    this.outward = [ox / 2 || 0, oz / 2 || 0];
  }
  // sale de la tierra (cementerio)
  spawnGround(x, z) { this.state = 'rise'; this.pos.set(x, -ZH, z); this.t = 0; this.play('idle'); this.g.fx.burst(x, .1, z, 22, new THREE.Color(0x4a3a2a), 2.2, .22, .9, 7); }
  hit(ray, maxT) {   // devuelve { t, head } o null
    if (this.dead || this.state === 'rise' && this.pos.y < -1) return null;
    const p = this.pos, k = this.hs, y0 = p.y;   // las medidas de abajo son para un zombi de 1,85 m
    let best = null;
    const hy = this.hy, test = (y, r, head) => { _s.set(p.x, y0 + y * k * hy, p.z); const t = raySphere(ray, _s, r * k * (hy < 1 ? 1.25 : 1)); if (t !== null && t < maxT && (!best || t < best.t)) best = { t, head }; };
    test(1.58, .24, true); test(1.18, .3, false); test(.82, .3, false); test(.42, .26, false);
    return best;
  }
  update(dt, P) {
    this.mixer.update(dt); this.t += dt;
    if (this.dead) { this.deadT += dt; if (this.fall) this.model.rotation.x = -Math.min(1, this.deadT * 2.5) * Math.PI / 2 * .95; if (this.deadT > 2.2) this.root.position.y -= dt * .8; this.root.position.x = this.pos.x; this.root.position.z = this.pos.z; return this.deadT < 3.6; }
    const g = this.g;
    if ((this.groanT -= dt) < 0) { this.groanT = 3 + Math.random() * 6; if (this.pos.distanceTo(P.pos) < 14) g.groan(this); }
    let tx = null, tz = null, sp = this.speed;
    if (this.state === 'rise') {
      this.pos.y = Math.min(0, -ZH + this.t * 1.1); if (this.pos.y >= 0) { this.state = 'chase'; this.play(this.run); }
      if (Math.random() < .3) g.fx.emit(this.pos.x + (Math.random() - .5) * .6, .05, this.pos.z + (Math.random() - .5) * .6, (Math.random() - .5), 1.5, (Math.random() - .5), new THREE.Color(0x4a3a2a), .16, .6, 5);
      this.face(P.pos.x - this.pos.x, P.pos.z - this.pos.z, dt * 3);
    } else if (this.state === 'approach') {
      const w = this.win, busy = w.user && w.user !== this;
      tx = w.out[0] + .5 + (busy ? this.outward[0] * 2.4 : 0); tz = w.out[1] + .5 + (busy ? this.outward[1] * 2.4 : 0);
      if (Math.hypot(tx - this.pos.x, tz - this.pos.z) < .15) { if (!busy) { w.user = this; this.state = 'tear'; this.boardT = .6; this.play('idle'); } else { tx = tz = null; this.play('idle'); } }
      else if (busy && this.cur === this.act.idle) this.play(this.run);
      if (!busy && this.cur === this.act.idle && this.state === 'approach') this.play(this.run);
    } else if (this.state === 'tear') {
      const w = this.win; this.face(w.inn[0] - w.out[0], w.inn[1] - w.out[1], dt * 8);
      if (w.boards > 0) {
        if ((this.boardT -= dt) < 0) { this.boardT = 1.25 * (this.kind === 'skel' ? .5 : 1); this.startAttack(); g.tearBoard(w, this); }
      } else { this.state = 'climb'; this.t = 0; this.from = this.pos.clone(); this.play('crouch', .1); }
      // si el jugador está justo al otro lado, le pega a través de la ventana
      if (P.pos.distanceTo(_v.set(w.inn[0] + .5, 0, w.inn[1] + .5)) < 1 && w.boards === 0) this.state = 'climb';
    } else if (this.state === 'climb') {
      const w = this.win, k = Math.min(1, this.t / .9);
      this.pos.set(THREE.MathUtils.lerp(this.from.x, w.inn[0] + .5, k), Math.sin(k * Math.PI) * .55, THREE.MathUtils.lerp(this.from.z, w.inn[1] + .5, k));
      if (k >= 1) { this.pos.y = 0; this.state = 'chase'; w.user = null; this.win = null; this.play(this.run); }
      if (w.boards > 0 && k < .4) { this.state = 'tear'; this.pos.copy(this.from); this.pos.y = 0; }
    } else if (this.state === 'chase') {
      const dx = P.pos.x - this.pos.x, dz = P.pos.z - this.pos.z, d = Math.hypot(dx, dz);
      if (d < 6 && clearLine(this.pos.x, this.pos.z, P.pos.x, P.pos.z)) { tx = P.pos.x; tz = P.pos.z; }
      else {
        const cx = Math.floor(this.pos.x), cz = Math.floor(this.pos.z); let bi = -1, bd = dist[idx(cx, cz)];
        if (cellAt(cx, cz) !== FLOOR && cellAt(cx, cz) !== DOOR) bd = 32000;
        for (const [ddx, ddz] of N8) { const nx = cx + ddx, nz = cz + ddz; if (!walkable(nx, nz)) continue; if (ddx && ddz && (!walkable(cx + ddx, cz) || !walkable(cx, cz + ddz))) continue; const v = dist[idx(nx, nz)]; if (v < bd) { bd = v; bi = idx(nx, nz); } }
        if (bi >= 0) { tx = bi % GW + .5; tz = Math.floor(bi / GW) + .5; }
        else { tx = P.pos.x; tz = P.pos.z; }
      }
      // atacar
      if (this.atkT >= 0) {
        this.atkT += dt; sp = 0;
        if (this.atkT > this.atkHit && !this.atkDone) { this.atkDone = true; if (d < 1.35 && P.alive && Math.abs(P.pos.y - this.pos.y) < 1.2) g.hurtPlayer(this); }
        if (this.atkT > this.atkEnd) { this.atkT = -1; this.play(this.run, .15); }
        this.face(dx, dz, dt * 6);
      } else if (d < 1.0 && P.alive && (this.atkCd -= dt) < 0) { this.atkCd = this.kind === 'skel' ? .7 : 1.0; this.atkT = 0; this.atkDone = false; this.startAttack(); }
      else if (d < .8) sp = 0;
    }
    // moverse hacia el objetivo: primero gira (con velocidad limitada) y solo avanza en la dirección en la que mira, nunca de lado
    const slow = this.slowT > 0 ? .4 : 1; this.slowT = Math.max(0, (this.slowT || 0) - dt);
    if (tx !== null && sp > 0) {
      const dx = tx - this.pos.x, dz = tz - this.pos.z, want = Math.atan2(dx, dz), diff = angDiff(want, this.yaw);
      const step = this.turnRate * dt; this.yaw += Math.max(-step, Math.min(step, diff));
      const al = Math.max(0, Math.cos(angDiff(want, this.yaw))), f = al > .7 ? 1 : al * al * 1.4;   // si aún está girando, casi no avanza
      const v = sp * slow * f, k = Math.min(1, dt * 7);
      this.vel.x += (Math.sin(this.yaw) * v - this.vel.x) * k; this.vel.z += (Math.cos(this.yaw) * v - this.vel.z) * k;
    } else { this.vel.multiplyScalar(Math.max(0, 1 - dt * 10)); }
    if (this.state !== 'climb' && this.state !== 'rise') {
      this.pos.x += this.vel.x * dt; this.pos.z += this.vel.z * dt;
      if (this.state === 'chase') collide(this.pos, R);
    }
    // la animación sigue a la velocidad real: más lento si se frena o gira, quieto (idle) si no se mueve
    const spd = Math.hypot(this.vel.x, this.vel.z);
    if (this.cur === this.act.gait) {
      if (this.state === 'chase' && spd < this.cv * .12 && this.act.idle) this.play('idle', .25);
      else this.cur.timeScale = Math.max(.25, spd / this.cv);
    } else if (this.state === 'chase' && this.cur === this.act.idle && spd > this.cv * .3) this.play('gait', .25);
    this.root.position.copy(this.pos); this.root.rotation.y = this.yaw;
    return true;
  }
  startAttack() {
    const n = Math.random() < .5 ? 'attack-melee-right' : 'attack-melee-left', a = this.def.atk[n], r = this.def.skinned ? ATK_RATE : 1;
    this.play(n, .1); this.cur.reset().play(); this.cur.timeScale = r; this.atkHit = a.hit / r; this.atkEnd = a.end / r;
  }
  face(dx, dz, k) { if (Math.abs(dx) + Math.abs(dz) < 1e-4) return; const a = Math.atan2(dx, dz); let d = a - this.yaw; d = Math.atan2(Math.sin(d), Math.cos(d)); this.yaw += d * Math.min(1, k); }
  damage(n, head, from) {
    this.hp -= n; this.slowT = .12;
    if (this.hp <= 0 && !this.dead) { this.die(head); return true; }
    return false;
  }
  die(head) {
    this.dead = true; this.deadT = 0;
    if (this.act.die) this.play('die', .08); else { this.cur && this.cur.stop(); this.fall = true; }   // sin animación de muerte: cae de espaldas
    if (head && this.head) { if (this.def.skinned) this.head.scale.setScalar(.001); else this.head.visible = false; }
    if (this.win && this.win.user === this) this.win.user = null;
  }
  dispose() { this.g.scene.remove(this.root); this.mixer.stopAllAction(); }
}
function raySphere(ray, c, r) {
  const ox = ray.origin.x - c.x, oy = ray.origin.y - c.y, oz = ray.origin.z - c.z, d = ray.direction;
  const b = ox * d.x + oy * d.y + oz * d.z, cc = ox * ox + oy * oy + oz * oz - r * r, h = b * b - cc;
  if (h < 0) return null; const t = -b - Math.sqrt(h); return t > 0 ? t : null;
}
// separa a los zombis que se apelotonan
export function separate(zs) {
  for (let i = 0; i < zs.length; i++) { const a = zs[i]; if (a.dead || a.state === 'climb' || a.state === 'rise') continue;
    for (let j = i + 1; j < zs.length; j++) { const b = zs[j]; if (b.dead || b.state === 'climb' || b.state === 'rise') continue;
      const dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z, d2 = dx * dx + dz * dz, m = .62;
      if (d2 < m * m && d2 > 1e-6) { const d = Math.sqrt(d2), k = (m - d) / d * .5; a.pos.x -= dx * k; a.pos.z -= dz * k; b.pos.x += dx * k; b.pos.z += dz * k; }
    }
  }
}
// casillas del cementerio donde salen de la tierra
// número de zombis y vida por ronda (parecido al Black Ops en solitario)
export function roundCount(r) { return r <= 5 ? [6, 8, 13, 18, 24][r - 1] : Math.floor(24 + (r - 5) * 3.2 + Math.max(0, r - 15) * 2); }
export function roundHp(r) { return r < 10 ? 150 + 100 * (r - 1) : Math.floor(950 * Math.pow(1.1, r - 9)); }
// velocidades (m/s) pensadas para las marchas medidas: arrastrado .35-.55, paso rápido hasta ~1, reptando 1-1.7, trote y carrera 1.2-3.1
export function roundSpeed(r) {
  const x = Math.random(), u = (a, b) => a + Math.random() * (b - a);
  if (r <= 2) return x < .7 ? u(.4, .65) : u(.65, .95);
  if (r <= 4) return x < .45 ? u(.5, .95) : x < .85 ? u(.95, 1.5) : u(1.5, 2.1);
  if (r <= 7) return x < .2 ? u(.6, .95) : x < .55 ? u(1, 1.7) : u(1.9, 2.5);
  return x < .1 ? u(.8, 1) : x < .35 ? u(1.2, 1.7) : u(2.2, 3.1);
}
export { WINDOWS, WIN };
