// Partículas (puntos suaves) y sprites de texto flotante.
import * as THREE from './lib/three.module.min.js';
const rnd = (a, b) => a + Math.random() * (b - a);
export class Particles {
  constructor(scene, n, additive, pixelRatio = 1) {
    this.n = n; this.i = 0;
    const g = new THREE.BufferGeometry();
    this.pos = new Float32Array(n * 3); this.col = new Float32Array(n * 3); this.sz = new Float32Array(n); this.al = new Float32Array(n);
    this.vel = new Float32Array(n * 3); this.life = new Float32Array(n); this.max = new Float32Array(n); this.grav = new Float32Array(n); this.s0 = new Float32Array(n); this.grow = new Float32Array(n);
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3)); g.setAttribute('color', new THREE.BufferAttribute(this.col, 3));
    g.setAttribute('size', new THREE.BufferAttribute(this.sz, 1)); g.setAttribute('alpha', new THREE.BufferAttribute(this.al, 1));
    this.mat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending, vertexColors: true,
      uniforms: { k: { value: 300 * pixelRatio } },
      vertexShader: 'attribute float size; attribute float alpha; varying vec3 vC; varying float vA; uniform float k; void main(){ vC = color; vA = alpha; vec4 mv = modelViewMatrix * vec4(position,1.0); gl_PointSize = size * k / -mv.z; gl_Position = projectionMatrix * mv; }',
      fragmentShader: `varying vec3 vC; varying float vA;
void main(){ vec2 p = gl_PointCoord - .5; float d = length(p); if (d > .5) discard; gl_FragColor = vec4(vC, vA * smoothstep(.5, .15, d));
#include <colorspace_fragment>
}`,
    });
    this.pts = new THREE.Points(g, this.mat); this.pts.frustumCulled = false; scene.add(this.pts);
  }
  setPixelRatio(pr) { this.mat.uniforms.k.value = 300 * pr; }
  emit(x, y, z, vx, vy, vz, color, size, life, grav = 0, grow = 0) {
    const i = this.i = (this.i + 1) % this.n;
    this.pos.set([x, y, z], i * 3); this.vel.set([vx, vy, vz], i * 3); this.col.set([color.r, color.g, color.b], i * 3);
    this.s0[i] = size; this.life[i] = this.max[i] = life; this.grav[i] = grav; this.grow[i] = grow;
  }
  burst(x, y, z, n, color, speed = 2, size = .14, life = .7, grav = 4) {
    for (let k = 0; k < n; k++) this.emit(x, y, z, rnd(-speed, speed), rnd(0, speed * 1.4), rnd(-speed, speed), color, size * rnd(.7, 1.3), life * rnd(.7, 1.2), grav);
  }
  update(dt) {
    for (let i = 0; i < this.n; i++) {
      if (this.life[i] <= 0) { this.al[i] = 0; continue; }
      this.life[i] -= dt; const k = i * 3;
      this.vel[k + 1] -= this.grav[i] * dt;
      this.pos[k] += this.vel[k] * dt; this.pos[k + 1] += this.vel[k + 1] * dt; this.pos[k + 2] += this.vel[k + 2] * dt;
      const f = Math.max(0, this.life[i] / this.max[i]);
      this.al[i] = Math.min(1, f * 1.6); this.sz[i] = this.s0[i] * (1 + this.grow[i] * (1 - f));
    }
    const a = this.pts.geometry.attributes; a.position.needsUpdate = a.color.needsUpdate = a.size.needsUpdate = a.alpha.needsUpdate = true;
  }
}

// texto o emoji flotante que sube y se desvanece (Z de dormir, corazones, «+5»…)
export class Floaters {
  constructor(scene) { this.scene = scene; this.list = []; this.cache = {}; }
  tex(text, color, font) {
    const k = text + color + font;
    if (this.cache[k]) return this.cache[k];
    const c = document.createElement('canvas'); c.width = c.height = 128; const x = c.getContext('2d');
    x.font = font; x.textAlign = 'center'; x.textBaseline = 'middle'; x.lineWidth = 12; x.lineJoin = 'round'; x.strokeStyle = 'rgba(40,20,70,.85)'; x.strokeText(text, 64, 68); x.fillStyle = color; x.fillText(text, 64, 68);
    const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return (this.cache[k] = t);
  }
  add(text, x, y, z, { color = '#fff', size = .42, life = 1.4, vy = .55, drift = 0, font = '700 84px Fredoka, system-ui, sans-serif' } = {}) {
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.tex(text, color, font), transparent: true, depthWrite: false, fog: false }));
    s.position.set(x, y, z); s.scale.setScalar(size); this.scene.add(s);
    this.list.push({ s, life, max: life, vy, drift, size });
  }
  update(dt) {
    for (const f of this.list) {
      f.life -= dt; f.s.position.y += f.vy * dt; f.s.position.x += f.drift * dt;
      const k = f.life / f.max; f.s.material.opacity = Math.min(1, k * 2.4); f.s.scale.setScalar(f.size * (1.25 - .25 * k));
    }
    this.list = this.list.filter(f => { if (f.life > 0) return true; this.scene.remove(f.s); f.s.material.dispose(); return false; });
  }
}
