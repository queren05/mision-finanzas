// Personajes «italian brainrot» hechos con piezas simples, sombreado toon y contorno negro.
// Cada constructor devuelve un grupo con la base en y = 0, mirando hacia +z y de ~1,4 m de alto.
import * as THREE from './lib/three.module.min.js';

let GRAD = null;
const toon = c => { if (!GRAD) { GRAD = new THREE.DataTexture(new Uint8Array([110, 185, 255]), 3, 1, THREE.RedFormat); GRAD.minFilter = GRAD.magFilter = THREE.NearestFilter; GRAD.needsUpdate = true; } return new THREE.MeshToonMaterial({ color: c, gradientMap: GRAD }); };
const OUT = new THREE.MeshBasicMaterial({ color: 0x140a1e, side: THREE.BackSide });
const V = (x, y, z) => new THREE.Vector3(x, y, z);

function kit(g) {
  const add = (geo, mat, p = [0, 0, 0], r = [0, 0, 0], s = [1, 1, 1], ol = .025) => {
    const m = new THREE.Mesh(geo, typeof mat === 'number' ? toon(mat) : mat); m.position.set(...p); m.rotation.set(...r); m.scale.set(...s); g.add(m);
    if (ol) { geo.computeBoundingSphere(); const o = new THREE.Mesh(geo, OUT); o.position.copy(m.position); o.rotation.copy(m.rotation); o.scale.copy(m.scale).multiplyScalar(1 + ol / Math.max(.03, geo.boundingSphere.radius * Math.min(...s))); g.add(o); }
    return m;
  };
  const sph = (r, c, p, s = [1, 1, 1], ol) => add(new THREE.SphereGeometry(r, 20, 14), c, p, [0, 0, 0], s, ol);
  const cyl = (rt, rb, h, c, p, r = [0, 0, 0], ol) => add(new THREE.CylinderGeometry(rt, rb, h, 18), c, p, r, [1, 1, 1], ol);
  const cone = (rad, h, c, p, r = [0, 0, 0], seg = 14, ol) => add(new THREE.ConeGeometry(rad, h, seg), c, p, r, [1, 1, 1], ol);
  const box = (w, h, d, c, p, r = [0, 0, 0], ol) => add(new THREE.BoxGeometry(w, h, d), c, p, r, [1, 1, 1], ol);
  const eye = (x, y, z, r = .08, look = [0, 0, 1]) => { sph(r, 0xffffff, [x, y, z], [1, 1.1, .7], .012); sph(r * .55, 0x161018, [x + look[0] * r * .2, y + look[1] * r * .2, z + r * .55], [1, 1, .6], 0); sph(r * .18, 0xffffff, [x + r * .25, y + r * .3, z + r * .8], [1, 1, 1], 0); };
  const tube = (pts, r, c) => add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts.map(p => V(...p))), 24, r, 8), c, [0, 0, 0], [0, 0, 0], [1, 1, 1], .015);
  return { add, sph, cyl, cone, box, eye, tube };
}
const sneaker = (k, x, z, c = 0x2f6fe0) => { k.box(.2, .1, .32, 0xffffff, [x, .05, z + .04]); k.box(.21, .07, .2, c, [x, .1, z]); };

export const BUILD = {
  // Tralalero Tralala: tiburón azul con tres patas y zapatillas
  trala() {
    const g = new THREE.Group(), k = kit(g);
    k.sph(.5, 0x4f8fe0, [0, .95, 0], [.8, .7, 1.5]); k.sph(.42, 0xf2f6ff, [0, .82, .12], [.62, .45, 1.3], 0);
    k.cone(.17, .45, 0x3f7fd0, [0, 1.4, -.15], [-.3, 0, 0]);
    k.cone(.22, .5, 0x3f7fd0, [0, 1.05, -.85], [Math.PI / 2 + .3, 0, 0]); k.cone(.16, .35, 0x3f7fd0, [0, .75, -.8], [Math.PI / 2 - .5, 0, 0]);
    for (const s of [-1, 1]) k.eye(s * .25, 1.08, .52, .08, [s * .3, 0, 1]);
    k.box(.4, .04, .05, 0xffffff, [0, .85, .72], [0, 0, 0], .01); for (let i = 0; i < 5; i++) k.cone(.025, .06, 0xffffff, [-.16 + i * .08, .82, .73], [Math.PI, 0, 0], 4, 0);
    for (const [x, z] of [[-.22, .25], [.22, .25], [0, -.3]]) { k.cyl(.06, .06, .55, 0x3f7fd0, [x, .42, z]); sneaker(k, x, z); }
    return g;
  },
  // Bombardiro Crocodilo: cocodrilo bombardero
  croco() {
    const g = new THREE.Group(), k = kit(g);
    k.cyl(.32, .3, 1.4, 0x6f7a6a, [0, .95, -.1], [Math.PI / 2, 0, 0]);
    k.box(.5, .26, .6, 0x5fae4a, [0, 1.0, .85]); k.box(.42, .12, .55, 0x5fae4a, [0, .85, .88]);
    for (let i = 0; i < 6; i++) for (const s of [-1, 1]) k.cone(.025, .07, 0xffffff, [s * .19, .93, .68 + i * .08], [Math.PI, 0, 0], 4, 0);
    for (const s of [-1, 1]) { k.sph(.11, 0x5fae4a, [s * .15, 1.2, .62]); k.eye(s * .15, 1.24, .7, .07); }
    k.box(2.1, .06, .42, 0x8a9488, [0, .98, -.05]); k.box(.8, .05, .26, 0x8a9488, [0, 1.0, -.75]); k.box(.05, .35, .3, 0x8a9488, [0, 1.2, -.75]);
    for (const s of [-1, 1]) { k.cyl(.07, .07, .3, 0x333a40, [s * .6, .88, .05], [Math.PI / 2, 0, 0]); k.sph(.09, 0x222222, [s * .35, .68, .05], [1, 1, 1.8]); }
    for (const s of [-1, 1]) k.cyl(.04, .04, .7, 0x5fae4a, [s * .18, .35, .2]);
    return g;
  },
  // Ballerina Cappuccina: taza de capuchino con tutú
  balle() {
    const g = new THREE.Group(), k = kit(g);
    for (const s of [-1, 1]) { k.cyl(.035, .035, .62, 0xf2d0b0, [s * .08, .31, 0], [0, 0, s * .1]); k.cone(.05, .1, 0xff8ab8, [s * .1, .03, .04], [-Math.PI / 2, 0, 0]); }
    k.cone(.5, .22, 0xff9ac8, [0, .66, 0], [Math.PI, 0, 0], 22); k.cone(.42, .2, 0xffc2dc, [0, .7, 0], [Math.PI, 0, 0], 22, .015);
    k.cyl(.12, .1, .3, 0xff9ac8, [0, .88, 0]);
    k.cyl(.32, .24, .44, 0xffffff, [0, 1.25, 0]); k.cyl(.3, .3, .05, 0xc9945a, [0, 1.46, 0], [0, 0, 0], 0); k.sph(.24, 0xf6ead8, [0, 1.5, 0], [1, .35, 1], 0);
    k.add(new THREE.TorusGeometry(.12, .035, 8, 16), 0xffffff, [.34, 1.25, 0], [0, 0, 0]);
    for (const s of [-1, 1]) k.eye(s * .11, 1.27, .27, .065);
    for (const s of [-1, 1]) k.tube([[s * .15, .95, 0], [s * .35, 1.1, .05], [s * .3, 1.5, .1]], .025, 0xf2d0b0);
    return g;
  },
  // Brr Brr Patapim: árbol-mono con pies enormes
  patapim() {
    const g = new THREE.Group(), k = kit(g);
    for (const s of [-1, 1]) k.sph(.2, 0xd9a07a, [s * .18, .1, .15], [1, .5, 1.6]);
    k.cyl(.3, .36, 1.0, 0x8a5a32, [0, .65, 0]);
    k.sph(.5, 0x4fa83a, [0, 1.35, 0], [1.1, .8, 1.1]); k.sph(.28, 0x5fbf4a, [.32, 1.5, .15]); k.sph(.3, 0x3f9a32, [-.3, 1.45, -.1]);
    k.sph(.24, 0xe8c09a, [0, .82, .22], [1, .9, .6]);
    for (const s of [-1, 1]) { k.eye(s * .1, .9, .32, .06); k.sph(.08, 0xe8c09a, [s * .34, .9, .05]); }
    k.sph(.05, 0x5a3a22, [0, .78, .38], [1.3, 1, 1], .01);
    for (const s of [-1, 1]) k.tube([[s * .28, .9, 0], [s * .55, .65, .1], [s * .5, .35, .2]], .045, 0x8a5a32);
    return g;
  },
  // Chimpanzini Bananini: chimpancé dentro de un plátano
  bana() {
    const g = new THREE.Group(), k = kit(g);
    k.cyl(.3, .22, .7, 0xffd84a, [0, .35, 0]);
    for (let i = 0; i < 4; i++) { const a = i / 4 * Math.PI * 2; k.add(new THREE.ConeGeometry(.16, .7, 6), 0xffd84a, [Math.sin(a) * .25, .75, Math.cos(a) * .25], [Math.cos(a) * .5, 0, -Math.sin(a) * .5], [1, 1, .35]); }
    k.sph(.32, 0x6a4428, [0, .95, 0]); k.sph(.22, 0x6a4428, [0, 1.28, 0]);
    k.sph(.15, 0xe8c09a, [0, 1.24, .12], [1.2, .9, .8]);
    for (const s of [-1, 1]) { k.sph(.08, 0xe8c09a, [s * .22, 1.32, 0], [1, 1, .5]); k.eye(s * .07, 1.32, .18, .05); }
    k.sph(.06, 0x3a2414, [0, 1.2, .25], [1.4, .8, 1], .01);
    for (const s of [-1, 1]) k.tube([[s * .28, 1.0, 0], [s * .45, 1.15, .1], [s * .4, 1.4, .1]], .05, 0x6a4428);
    return g;
  },
  // Lirilì Larilà: elefante con cuerpo de cactus y sandalias
  lirili() {
    const g = new THREE.Group(), k = kit(g);
    for (const s of [-1, 1]) { k.cyl(.11, .11, .4, 0x4f9a3a, [s * .16, .2, 0]); k.box(.24, .04, .34, 0xb5773f, [s * .16, .02, .04]); }
    k.cyl(.3, .32, .7, 0x5fae4a, [0, .7, 0]);
    for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2, y = .5 + (i % 3) * .2; k.cone(.02, .1, 0xfff2c8, [Math.sin(a) * .32, y, Math.cos(a) * .32], [Math.cos(a) * Math.PI / 2, 0, -Math.sin(a) * Math.PI / 2], 4, 0); }
    k.sph(.36, 0x9aa0aa, [0, 1.3, .05]);
    for (const s of [-1, 1]) k.sph(.24, 0x8a909a, [s * .38, 1.32, -.02], [.35, 1, .9]);
    k.tube([[0, 1.25, .35], [0, 1.0, .5], [0, .85, .45], [0, .8, .55]], .07, 0x9aa0aa);
    for (const s of [-1, 1]) k.eye(s * .14, 1.4, .3, .065);
    return g;
  },
  // Bombombini Gusini: ganso con motores de reacción
  bonbon() {
    const g = new THREE.Group(), k = kit(g);
    for (const s of [-1, 1]) { k.cyl(.03, .03, .35, 0xff9a2a, [s * .14, .18, 0]); k.box(.16, .03, .2, 0xff9a2a, [s * .14, .02, .06]); }
    k.sph(.42, 0xffffff, [0, .65, 0], [1, .85, 1.25]);
    k.cyl(.09, .11, .55, 0xffffff, [0, 1.1, .3], [.35, 0, 0]); k.sph(.17, 0xffffff, [0, 1.38, .4]);
    k.cone(.07, .22, 0xff9a2a, [0, 1.35, .62], [Math.PI / 2, 0, 0]);
    for (const s of [-1, 1]) { k.eye(s * .09, 1.44, .52, .05); k.box(.5, .06, .3, 0xeeeeee, [s * .45, .7, -.05], [0, 0, s * .2]); k.cyl(.09, .07, .38, 0x5a626e, [s * .55, .58, -.05], [Math.PI / 2, 0, 0]); k.cone(.08, .2, 0xff7a2a, [s * .55, .58, -.33], [-Math.PI / 2, 0, 0], 10, 0); }
    return g;
  },
  // Boneca Ambalabu: cabeza de rana sobre un neumático, con piernas
  boneca() {
    const g = new THREE.Group(), k = kit(g);
    for (const s of [-1, 1]) { k.cyl(.06, .06, .45, 0xe8c09a, [s * .14, .22, 0]); k.box(.16, .06, .26, 0x333333, [s * .14, .03, .05]); }
    k.add(new THREE.TorusGeometry(.32, .14, 12, 24), 0x26262c, [0, .72, 0], [0, 0, 0]);
    k.cyl(.2, .2, .1, 0x9aa0aa, [0, .72, 0], [Math.PI / 2, 0, 0], 0);
    k.sph(.36, 0x5fbf4a, [0, 1.22, .02], [1.15, .8, 1]); k.sph(.3, 0xd8f0a0, [0, 1.12, .12], [1.1, .55, 1], 0);
    for (const s of [-1, 1]) { k.sph(.12, 0x5fbf4a, [s * .2, 1.45, .1]); k.eye(s * .2, 1.48, .18, .08); }
    k.add(new THREE.TorusGeometry(.16, .02, 6, 16, Math.PI), 0x2a1a20, [0, 1.12, .34], [0, 0, Math.PI], [1, 1, 1], 0);
    return g;
  },
};

export const CHARS = [
  { id: 'tung', name: 'Tung Tung Tung Sahur', rar: 3, hp: 120, atk: 22, spd: 26, sp: 'Golpe triple', spd2: 'Tres batazos a un enemigo.' },
  { id: 'trippi', name: 'Trippi Troppi', rar: 3, hp: 100, atk: 26, spd: 30, sp: 'Miau gigante', spd2: 'Un mordisco enorme a un enemigo.' },
  { id: 'croco', name: 'Bombardiro Crocodilo', rar: 2, hp: 110, atk: 18, spd: 22, sp: 'Bombardeo', spd2: 'Bombas a todos los enemigos.' },
  { id: 'balle', name: 'Ballerina Cappuccina', rar: 2, hp: 95, atk: 14, spd: 28, sp: 'Pirueta café', spd2: 'Cura a todo el equipo.' },
  { id: 'trala', name: 'Tralalero Tralala', rar: 1, hp: 105, atk: 17, spd: 25, sp: 'Ola', spd2: 'Golpea a todos los enemigos.' },
  { id: 'lirili', name: 'Lirilì Larilà', rar: 1, hp: 130, atk: 13, spd: 18, sp: 'Escudo de pinchos', spd2: 'El equipo recibe la mitad de daño un rato.' },
  { id: 'bonbon', name: 'Bombombini Gusini', rar: 1, hp: 95, atk: 18, spd: 27, sp: 'Misiles', spd2: 'Quema a todos los enemigos.' },
  { id: 'patapim', name: 'Brr Brr Patapim', rar: 0, hp: 120, atk: 15, spd: 20, sp: 'Pisotón', spd2: 'Golpe fuerte que aturde.' },
  { id: 'bana', name: 'Chimpanzini Bananini', rar: 0, hp: 85, atk: 15, spd: 32, sp: 'Plátano doble', spd2: 'Dos golpes rápidos.' },
  { id: 'boneca', name: 'Boneca Ambalabu', rar: 0, hp: 110, atk: 16, spd: 22, sp: 'Rodada', spd2: 'Arrolla a un enemigo.' },
];
export const RAR = [{ name: 'Común', col: '#9aa4b8' }, { name: 'Raro', col: '#4fb2ff' }, { name: 'Épico', col: '#b45aff' }, { name: 'Legendario', col: '#ffb21d' }];
