// Modelos 3D de la comida (formas simples). Origen en la base; miden unos 0,4 de alto.
import * as THREE from './lib/three.module.min.js';
import { canvasTex } from './modelos.js';
const mat = (c, o = {}) => new THREE.MeshStandardMaterial(Object.assign({ color: c, roughness: .55 }, o));
const glow = (c, i = .6) => mat(c, { emissive: c, emissiveIntensity: i, roughness: .4 });
function mk(g) {
  return (geo, material, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, sx = 1, sy = 1, sz = 1) => {
    const m = new THREE.Mesh(geo, material); m.position.set(x, y, z); m.rotation.set(rx, ry, rz); m.scale.set(sx, sy, sz); g.add(m); return m;
  };
}
const SPH = (r = 1, w = 20, h = 14) => new THREE.SphereGeometry(r, w, h);
// Modelos del Food Kit de Kenney (CC0): se cargan al arrancar y se usan en lugar de las formas simples
const KIT = {}, KB = {};
export const FOOD_KIT = ['alga', 'krill', 'sushi', 'pizza', 'helado', 'tarta', 'piruleta', 'sopa', 'cafe', 'donut', 'fritas', 'taco', 'tortitas', 'sandia', 'cupcake', 'perrito', 'fresa'];
const FOOD_SIZE = { pizza: .62, tarta: .6, sandia: .5, sopa: .55, alga: .55, tortitas: .55, perrito: .62, taco: .55, piruleta: .55, helado: .55, cafe: .55, fritas: .5, fresa: .32, sushi: .45 };
export function setFoodKit(map) { Object.assign(KIT, map); }
export function foodMesh(id) {
  if (KIT[id]) {
    const src = KIT[id].scene;
    if (!KB[id]) { src.updateMatrixWorld(true); KB[id] = new THREE.Box3().setFromObject(src); }
    const b = KB[id], s2 = b.getSize(new THREE.Vector3()), k = (FOOD_SIZE[id] || .45) / Math.max(s2.x, s2.y, s2.z);
    const o = src.clone(true); o.position.set(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2);
    const g = new THREE.Group(), w = new THREE.Group(); w.add(o); w.scale.setScalar(k); g.add(w);
    return g;
  }
  const g = new THREE.Group(), add = mk(g);
  switch (id) {
    case 'plancton': {
      const cols = [0x5ff0ff, 0xff8ae8, 0xfff27a, 0x9bff8a, 0x7ab8ff];
      [[0, .2, 0, .13], [-.15, .12, .05, .09], [.14, .14, -.04, .1], [.04, .34, .03, .08], [-.05, .05, .13, .07], [.12, .3, .1, .06]].forEach(([x, y, z, r], i) => add(SPH(r), glow(cols[i % 5], .8), x, y, z));
      break;
    }
    case 'alga': {
      for (let k = 0; k < 4; k++) {
        const pts = []; for (let i = 0; i <= 12; i++) pts.push(new THREE.Vector3(Math.sin(i * .7 + k) * .06 + (k - 1.5) * .07, i * .035, Math.cos(i * .6 + k) * .04));
        add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 24, .022, 6), mat([0x3fbf5a, 0x2f9a48, 0x5fd66f, 0x37a852][k], { roughness: .5 }));
      }
      break;
    }
    case 'krill': {   // hamburguesa
      add(new THREE.SphereGeometry(.24, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), mat(0xd9943a), 0, .18, 0, 0, 0, 0, 1, .75, 1);
      add(new THREE.CylinderGeometry(.22, .22, .05, 24), mat(0xc07a2a), 0, .04, 0);
      add(new THREE.CylinderGeometry(.23, .23, .06, 24), mat(0x6b3a1e), 0, .1, 0);
      add(new THREE.CylinderGeometry(.25, .25, .025, 24), mat(0x4fc45a), 0, .14, 0);
      add(new THREE.BoxGeometry(.4, .02, .4), mat(0xffc93a), 0, .165, 0, 0, Math.PI / 4, 0);
      for (let i = 0; i < 7; i++) add(SPH(.012, 6, 4), mat(0xfff3c4), Math.cos(i) * .1, .34, Math.sin(i) * .1 + .0, 0, 0, 0, 1.5, .7, 1);
      break;
    }
    case 'sushi': {
      add(new THREE.CapsuleGeometry(.11, .3, 6, 12), mat(0xfaf6ea), 0, .12, 0, 0, 0, Math.PI / 2);
      add(new THREE.CapsuleGeometry(.1, .36, 6, 12), mat(0xff7b6b), 0, .23, 0, 0, 0, Math.PI / 2, 1, .42, 1.15);
      add(new THREE.BoxGeometry(.06, .17, .3), mat(0x1c2a24), 0, .15, 0);
      break;
    }
    case 'pizza': {   // porción triangular tumbada, con la corteza hacia delante (+z)
      const tri = k => { const sh = new THREE.Shape(); sh.moveTo(0, 0); sh.lineTo(-.27 * k, .56 * k); sh.quadraticCurveTo(0, .66 * k, .27 * k, .56 * k); sh.closePath(); return sh; };
      const ex = (k, d) => { const geo = new THREE.ExtrudeGeometry(tri(k), { depth: d, bevelEnabled: true, bevelSize: .012, bevelThickness: .01, bevelSegments: 2, curveSegments: 10 }); geo.rotateX(Math.PI / 2); return geo; };
      add(ex(1, .04), mat(0xe2a044), 0, .05, -.28);
      add(ex(.9, .015), mat(0xf7c95a), 0, .066, -.26);
      const crust = add(new THREE.CapsuleGeometry(.04, .5, 6, 12), mat(0xc77f2c), 0, .045, .33); crust.rotation.z = Math.PI / 2;
      [[0, .08], [-.09, .2], [.1, .22], [0, .36], [-.07, .44], [.08, .46]].forEach(([x, z], i) => add(new THREE.CylinderGeometry(.045, .045, .014, 14), mat(0xc72d2d), x, .085, z - .28 + .28 - .0 - .02));
      g.children.forEach(c => { c.position.z -= .0; });
      g.position.set(0, 0, -.05);
      break;
    }
    case 'helado': {
      add(new THREE.ConeGeometry(.12, .3, 14), mat(0xd9a15a, { roughness: .8 }), 0, .15, 0, Math.PI);
      add(SPH(.14), mat(0xff9ec8), 0, .36, 0); add(SPH(.12), mat(0xfff0f7), 0, .49, 0);
      add(SPH(.035, 10, 8), mat(0xd7262e), 0, .62, 0);
      break;
    }
    case 'tarta': {   // porción de tarta: bizcocho, crema y fresa
      const w = new THREE.Group(); w.rotation.y = -.5; w.scale.set(.9, 1, .9); g.add(w);
      const part = (geo, material, y) => { const m = new THREE.Mesh(geo, material); m.position.y = y; w.add(m); return m; };
      part(new THREE.CylinderGeometry(.43, .43, .05, 24, 1, false, 0, 1.15), mat(0xb5652a), .025);
      part(new THREE.CylinderGeometry(.425, .425, .07, 24, 1, false, 0, 1.15), mat(0xfff0d6), .085);
      part(new THREE.CylinderGeometry(.43, .43, .05, 24, 1, false, 0, 1.15), mat(0xb5652a), .145);
      part(new THREE.CylinderGeometry(.435, .435, .07, 24, 1, false, 0, 1.15), mat(0xfff0d6), .205);
      part(new THREE.CylinderGeometry(.44, .44, .035, 24, 1, false, 0, 1.15), mat(0xff80b5), .2575 + .0);
      const c = new THREE.Mesh(new THREE.SphereGeometry(.05, 12, 10), mat(0xd7262e)); c.position.set(Math.sin(.575) * .3, .32, Math.cos(.575) * .3); w.add(c);
      const l = new THREE.Mesh(new THREE.ConeGeometry(.02, .05, 6), mat(0x3fae5a)); l.position.set(c.position.x, .375, c.position.z); w.add(l);
      [.15, .55, .95].forEach(a2 => { const d = new THREE.Mesh(new THREE.SphereGeometry(.025, 8, 6), mat(0xffffff)); d.position.set(Math.sin(a2) * .4, .275, Math.cos(a2) * .4); w.add(d); });
      g.position.set(-.12, 0, -.05);
      break;
    }
    case 'piruleta': {
      add(new THREE.CylinderGeometry(.018, .018, .4, 8), mat(0xffffff), 0, .2, 0);
      const t = canvasTex(128, 128, (c, w) => { for (let i = 0; i < 12; i++) { c.fillStyle = i % 2 ? '#ff4d8d' : '#ffe14d'; c.beginPath(); c.moveTo(w / 2, w / 2); c.arc(w / 2, w / 2, w / 2, i * Math.PI / 6, (i + 1) * Math.PI / 6); c.fill(); } }, false);
      add(new THREE.CylinderGeometry(.17, .17, .04, 28), new THREE.MeshStandardMaterial({ map: t, roughness: .3 }), 0, .5, 0, Math.PI / 2);
      break;
    }
    case 'sopa': {
      const prof = [[0, 0], [.1, 0], [.2, .05], [.26, .16], [.27, .2]].map(([x, y]) => new THREE.Vector2(x, y));
      const bowl = add(new THREE.LatheGeometry(prof, 24), mat(0xf4f7ff, { side: THREE.DoubleSide }), 0, 0, 0);
      add(new THREE.TorusGeometry(.268, .012, 8, 28), mat(0x4f8aff), 0, .2, 0, Math.PI / 2);
      add(new THREE.CylinderGeometry(.245, .245, .01, 24), mat(0xff9a3a, { roughness: .3 }), 0, .17, 0);
      [[-.07, .03], [.06, -.06], [.08, .08], [-.1, -.08]].forEach(([x, z], i) => add(SPH(.04, 8, 6), mat([0x5fd66f, 0xffe27a, 0xff6a6a, 0xfff0d0][i]), x, .19, z));
      break;
    }
    case 'vitamina': {
      add(new THREE.CylinderGeometry(.16, .16, .36, 18), mat(0x9fe8ff, { transparent: true, opacity: .45, roughness: .1 }), 0, .2, 0);
      add(new THREE.CylinderGeometry(.14, .16, .07, 18), mat(0x4fe37a), 0, .41, 0);
      [0xff5a7a, 0xffd24a, 0x5ab8ff, 0xb45aff, 0x5fe37a, 0xff9a3a].forEach((c, i) => add(SPH(.05, 8, 6), glow(c, .4), Math.cos(i * 1.1) * .07, .08 + (i % 3) * .09, Math.sin(i * 1.1) * .07));
      break;
    }
    case 'medicina': {   // jarabe con cuchara
      add(new THREE.CylinderGeometry(.12, .13, .3, 20), mat(0x8a3a1c, { transparent: true, opacity: .85, roughness: .15 }), 0, .15, 0);
      add(new THREE.CylinderGeometry(.06, .08, .07, 16), mat(0x8a3a1c, { transparent: true, opacity: .85 }), 0, .33, 0);
      add(new THREE.CylinderGeometry(.07, .07, .07, 16), mat(0xffffff), 0, .4, 0);
      add(new THREE.BoxGeometry(.2, .12, .01), mat(0xffffff), 0, .16, .125);
      add(new THREE.BoxGeometry(.03, .08, .012), mat(0xe32b2b), 0, .16, .13); add(new THREE.BoxGeometry(.08, .03, .012), mat(0xe32b2b), 0, .16, .13);
      break;
    }
    case 'cafe': {   // batido con pajita
      const prof = [[0, 0], [.12, 0], [.16, .36], [0, .36]].map(([x, y]) => new THREE.Vector2(x, y));
      add(new THREE.LatheGeometry(prof, 20), mat(0xff9ec8, { transparent: true, opacity: .9, roughness: .2 }));
      add(SPH(.15, 18, 10), mat(0xfff6f0), 0, .38, 0, 0, 0, 0, 1, .55, 1);
      add(new THREE.CylinderGeometry(.015, .015, .35, 8), mat(0x4fb2ff), .05, .5, 0, 0, 0, -.25);
      add(SPH(.03, 10, 8), mat(0xd7262e), -.04, .46, .03);
      break;
    }
    default: add(SPH(.15), glow(0xffffff, .5), 0, .15, 0);
  }
  return g;
}
