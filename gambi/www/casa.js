// La casa de Gambi: habitaciones 3D hechas con formas simples y temas de decoración.
import * as THREE from './lib/three.module.min.js';
import { RoundedBoxGeometry } from './lib/RoundedBoxGeometry.js';
import { canvasTex, noise } from './modelos.js';
import { THEMES } from './datos.js';

const rnd = (a, b) => a + Math.random() * (b - a);
const WALL_Z = -2.7;
export const ROOMS = ['salon', 'cocina', 'bano', 'dormitorio', 'juegos'];

/* ---------- texturas de paredes y suelos ---------- */
function wallTexture(t) {
  return canvasTex(512, 512, (c, w, h) => {
    const g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, t.wall[0]); g.addColorStop(1, t.wall[1]); c.fillStyle = g; c.fillRect(0, 0, w, h);
    c.strokeStyle = t.line; c.fillStyle = t.line;
    switch (t.wpat) {
      case 'dots': c.globalAlpha = .4; for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) { c.beginPath(); c.arc(x * 64 + (y % 2 ? 32 : 0) + 16, y * 64 + 32, 9, 0, 7); c.fill(); } break;
      case 'stripes': c.globalAlpha = .3; for (let x = 0; x < 8; x++) c.fillRect(x * 64 + 16, 0, 32, h); break;
      case 'waves': c.globalAlpha = .4; c.lineWidth = 5; for (let y = 0; y < 9; y++) { c.beginPath(); for (let x = 0; x <= w; x += 8) c.lineTo(x, y * 64 + 20 + Math.sin(x / w * Math.PI * 4 + y) * 12); c.stroke(); } break;
      case 'leaves': c.globalAlpha = .35; for (let i = 0; i < 26; i++) { const x = rnd(0, w), y = rnd(0, h), a = rnd(0, 3); for (const dx of [-w, 0, w]) for (const dy of [-h, 0, h]) { c.save(); c.translate(x + dx, y + dy); c.rotate(a); c.beginPath(); c.ellipse(0, 0, 34, 14, 0, 0, 7); c.fill(); c.restore(); } } break;
      case 'stars': for (let i = 0; i < 60; i++) { const x = rnd(0, w), y = rnd(0, h), r = rnd(1, 4); c.globalAlpha = rnd(.4, 1); c.beginPath(); c.arc(x, y, r, 0, 7); c.fill(); if (r > 3) { c.fillRect(x - 9, y - .8, 18, 1.6); c.fillRect(x - .8, y - 9, 1.6, 18); } } break;
      case 'grid': c.globalAlpha = .75; c.lineWidth = 3; c.shadowColor = t.line; c.shadowBlur = 10; for (let i = 0; i <= 8; i++) { c.beginPath(); c.moveTo(i * 64, 0); c.lineTo(i * 64, h); c.moveTo(0, i * 64); c.lineTo(w, i * 64); c.stroke(); } break;
    }
  });
}
function floorTexture(t) {
  return canvasTex(512, 512, (c, w, h) => {
    c.fillStyle = t.floor[0]; c.fillRect(0, 0, w, h);
    switch (t.fpat) {
      case 'planks': for (let i = 0; i < 8; i++) { c.fillStyle = i % 2 ? t.floor[1] : t.floor[0]; c.fillRect(0, i * 64, w, 64); c.fillStyle = 'rgba(0,0,0,.18)'; c.fillRect(0, i * 64, w, 3); for (let k = 0; k < 2; k++) c.fillRect(((i * 97 + k * 260) % w), i * 64, 3, 64); } noise(c, w, h, 160, ['rgba(0,0,0,.08)', 'rgba(255,255,255,.08)'], 2, 10, 1); break;
      case 'sand': noise(c, w, h, 900, [t.floor[1], 'rgba(255,255,255,.35)', 'rgba(150,110,50,.25)'], 1, 5, .8); break;
      case 'tiles': for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { c.fillStyle = (x + y) % 2 ? t.floor[1] : t.floor[0]; c.fillRect(x * 128, y * 128, 128, 128); } c.strokeStyle = 'rgba(255,255,255,.18)'; c.lineWidth = 3; for (let i = 0; i <= 4; i++) { c.beginPath(); c.moveTo(i * 128, 0); c.lineTo(i * 128, h); c.moveTo(0, i * 128); c.lineTo(w, i * 128); c.stroke(); } break;
      case 'grid': c.fillStyle = t.floor[1]; c.fillRect(0, 0, w, h); c.strokeStyle = t.line; c.lineWidth = 3; c.shadowColor = t.line; c.shadowBlur = 10; c.globalAlpha = .85; for (let i = 0; i <= 4; i++) { c.beginPath(); c.moveTo(i * 128, 0); c.lineTo(i * 128, h); c.moveTo(0, i * 128); c.lineTo(w, i * 128); c.stroke(); } break;
    }
  });
}
const tileTexture = (a, b) => canvasTex(256, 256, (c, w, h) => { c.fillStyle = b; c.fillRect(0, 0, w, h); c.fillStyle = a; for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { c.beginPath(); c.roundRect ? c.roundRect(x * 64 + 3, y * 64 + 3, 58, 58, 8) : c.rect(x * 64 + 3, y * 64 + 3, 58, 58); c.fill(); } });
function skyTexture(day, night) {
  return canvasTex(256, 256, (c, w, h) => {
    const g = c.createLinearGradient(0, 0, 0, h);
    if (night) { g.addColorStop(0, '#0b1140'); g.addColorStop(1, '#2a2f78'); } else { const k = new THREE.Color(day); g.addColorStop(0, '#' + k.clone().multiplyScalar(.75).getHexString()); g.addColorStop(1, '#' + k.clone().lerp(new THREE.Color(0xffffff), .55).getHexString()); }
    c.fillStyle = g; c.fillRect(0, 0, w, h);
    if (night) { c.fillStyle = '#fff'; for (let i = 0; i < 40; i++) { c.globalAlpha = rnd(.4, 1); c.beginPath(); c.arc(rnd(0, w), rnd(0, h), rnd(.8, 2.2), 0, 7); c.fill(); } c.globalAlpha = 1; c.fillStyle = '#fff6c8'; c.beginPath(); c.arc(w * .68, h * .3, 26, 0, 7); c.fill(); c.fillStyle = '#1e2468'; c.beginPath(); c.arc(w * .68 + 13, h * .3 - 6, 23, 0, 7); c.fill(); }
    else { c.fillStyle = 'rgba(255,255,255,.9)'; for (const [x, y, r] of [[60, 80, 24], [90, 70, 30], [125, 82, 22], [190, 150, 20], [215, 142, 26]]) { c.beginPath(); c.arc(x, y, r, 0, 7); c.fill(); } c.fillStyle = '#ffe47a'; c.beginPath(); c.arc(w * .8, h * .22, 24, 0, 7); c.fill(); }
  }, false);
}

export function buildHouse(scene) {
  const accents = [], darks = [];
  const mat = (c, o = {}) => new THREE.MeshStandardMaterial(Object.assign({ color: c, roughness: .65 }, o));
  const A = (o = {}) => { const m = mat(0xffffff, o); accents.push(m); return m; };
  const D = (o = {}) => { const m = mat(0xffffff, o); darks.push(m); return m; };
  const lit = (c, i = 1) => mat(c, { emissive: c, emissiveIntensity: i, roughness: .4 });
  const put = (m, x, y, z) => { m.position.set(x, y, z); return m; };
  const rb = (w, h, d, r, material, x, y, z) => put(new THREE.Mesh(new RoundedBoxGeometry(w, h, d, 4, Math.min(r, Math.min(w, h, d) / 2 - .002)), material), x, y + h / 2, z);
  const cyl = (rt, rbt, h, material, x, y, z, seg = 28) => put(new THREE.Mesh(new THREE.CylinderGeometry(rt, rbt, h, seg), material), x, y + h / 2, z);
  const sph = (r, material, x, y, z, sx = 1, sy = 1, sz = 1) => { const m = put(new THREE.Mesh(new THREE.SphereGeometry(r, 22, 16), material), x, y, z); m.scale.set(sx, sy, sz); return m; };
  const plane = (w, h, material, x, y, z) => put(new THREE.Mesh(new THREE.PlaneGeometry(w, h), material), x, y, z);
  const white = mat(0xf7f4ee), wood = mat(0xa56b3c), steel = mat(0xc9d2db, { metalness: .4, roughness: .35 });
  const hot = {};   // puntos tocables por habitación: { id, obj, r }
  const anim = [];  // funciones (dt, t) para cosas que se mueven

  /* paredes y suelo compartidos */
  const wallMat = new THREE.MeshStandardMaterial({ roughness: 1 }), floorMat = new THREE.MeshStandardMaterial({ roughness: .95 });
  const wall = plane(16, 12, wallMat, 0, 6, WALL_Z), floor = plane(16, 12, floorMat, 0, 0, 3.2);
  floor.rotation.x = -Math.PI / 2;
  const base = rb(16, .16, .1, .02, D(), 0, 0, WALL_Z + .05);
  const shared = new THREE.Group(); shared.add(wall, floor, base); scene.add(shared);
  const winMat = new THREE.MeshBasicMaterial({ map: null });
  const windowAt = (x, y, w, h, z = WALL_Z + .02) => {
    const g = new THREE.Group();
    g.add(plane(w, h, winMat, x, y, z + .01));
    const f = mat(0xffffff);
    for (const [fw, fh, fx, fy] of [[w + .16, .08, 0, h / 2 + .04], [w + .16, .08, 0, -h / 2 - .04], [.08, h, -w / 2 - .04, 0], [.08, h, w / 2 + .04, 0], [.05, h, 0, 0], [w, .05, 0, 0]]) g.add(put(new THREE.Mesh(new THREE.BoxGeometry(fw, fh, .09), f), x + fx, y + fy, z + .03));
    return g;
  };
  const curtain = (x, y, h, w = .38) => { const g = new THREE.Group(); g.add(rb(w, h, .14, .07, A(), x, y, WALL_Z + .14)); g.add(rb(w * .35, h * .96, .16, .05, D(), x + w * .2, y, WALL_Z + .15)); return g; };
  const frameArt = (x, y, w, h, colors) => {
    const g = new THREE.Group(); g.add(rb(w, h, .07, .03, white, x, y - h / 2, WALL_Z + .05));
    const t = canvasTex(128, 128, (c, ww) => { c.fillStyle = colors[0]; c.fillRect(0, 0, ww, ww); c.fillStyle = colors[1]; c.beginPath(); c.arc(64, 70, 34, 0, 7); c.fill(); c.fillStyle = colors[2]; c.beginPath(); c.arc(86, 46, 14, 0, 7); c.fill(); }, false);
    g.add(plane(w - .14, h - .14, new THREE.MeshBasicMaterial({ map: t }), x, y, WALL_Z + .1)); return g;
  };

  /* ---------- SALÓN ---------- */
  function salon() {
    const g = new THREE.Group();
    g.add(cyl(1.4, 1.4, .03, A(), 0, 0, .35, 48)); g.add(cyl(1.0, 1.0, .035, mat(0xffffff, { transparent: true, opacity: .35 }), 0, 0, .35, 48));
    const sofa = new THREE.Group();   // sofá
    sofa.add(rb(2.3, .48, 1.0, .2, A(), 0, .14, 0), rb(2.3, .8, .3, .15, A(), 0, .14, -.42), rb(.32, .72, 1.0, .15, D(), -1.15, .1, 0), rb(.32, .72, 1.0, .15, D(), 1.15, .1, 0));
    sofa.add(rb(.95, .2, .8, .09, mat(0xffffff, { transparent: false }), -.5, .6, .05), rb(.95, .2, .8, .09, mat(0xfff3d6), .5, .6, .05));
    sofa.add(rb(.45, .42, .18, .08, mat(0xffd36b), -.75, .7, -.18));
    sofa.position.set(-.85, 0, -2.05); g.add(sofa);
    const pot = cyl(.32, .23, .42, mat(0xc46a3a), 1.85, 0, -1.95); g.add(pot);
    const leafM = mat(0x3fae5a, { flatShading: true });
    [[0, .95, 0, .4], [.22, .75, .1, .28], [-.2, .8, -.08, .3], [.05, 1.25, -.04, .24]].forEach(([x, y, z, r]) => g.add(sph(r, leafM, 1.85 + x, y + .2, -1.95 + z, 1, 1.2, 1)));
    g.add(cyl(.03, .035, 1.75, mat(0x3a3d46), 1.0, 0, -2.3, 8), cyl(.44, .28, .42, lit(0xfff0c0, .7), 1.0, 1.6, -2.3), cyl(.22, .22, .03, mat(0x3a3d46), 1.0, 0, -2.3));
    g.add(windowAt(-.05, 2.6, 1.5, 1.4), curtain(-.98, 1.85, 1.75), curtain(.9, 1.85, 1.75));
    g.add(frameArt(-1.85, 3.2, .7, .85, ['#ffd9a0', '#ff8a5c', '#fff']), frameArt(1.8, 3.2, .6, .75, ['#bfe6ff', '#4f9aff', '#ffe27a']));
    const ball = sph(.3, mat(0xffffff), -1.35, .3, .8); const bt = canvasTex(128, 64, (c, w, h) => { for (let i = 0; i < 6; i++) { c.fillStyle = ['#ff5a5a', '#fff', '#4f9aff', '#fff', '#ffd24a', '#fff'][i]; c.fillRect(i * w / 6, 0, w / 6 + 1, h); } }, false);
    ball.material = new THREE.MeshStandardMaterial({ map: bt, roughness: .4 }); g.add(ball); hot.salon = [{ id: 'ball', obj: ball, r: 70 }];
    return g;
  }

  /* ---------- COCINA ---------- */
  function cocina() {
    const g = new THREE.Group();
    const tile = tileTexture('#ffffff', '#c7d3dd'); tile.repeat.set(3, 1);
    g.add(plane(3.0, .8, new THREE.MeshStandardMaterial({ map: tile, roughness: .4 }), -.95, 1.35, WALL_Z + .02));
    g.add(rb(2.9, .92, .85, .07, white, -.95, 0, -2.2));
    for (let i = 0; i < 3; i++) { g.add(rb(.88, .74, .04, .02, mat(0xe9e2d3), -1.95 + i * .95, .08, -1.77)); g.add(rb(.12, .04, .05, .02, steel, -1.6 + i * .95, .6, -1.75)); }
    g.add(rb(3.0, .09, .95, .035, A(), -.95, .92, -2.2));
    g.add(rb(2.3, .78, .5, .06, white, -1.25, 2.1, -2.42)); for (let i = 0; i < 3; i++) g.add(rb(.7, .64, .04, .02, mat(0xe9e2d3), -1.95 + i * .72, 2.17, -2.16));
    for (const x of [-.25, .25]) g.add(cyl(.2, .2, .03, mat(0x2b2d33), -.25 + x, 1.01, -2.05), cyl(.11, .11, .02, mat(0x55585f), -.25 + x, 1.04, -2.05));
    g.add(cyl(.19, .17, .26, steel, -1.7, 1.01, -2.1), cyl(.2, .2, .04, mat(0xd8401f), -1.7, 1.27, -2.1));
    const fr = new THREE.Group();
    fr.add(rb(1.15, 2.3, .9, .12, mat(0xf3f8fc), 0, 0, 0), rb(1.05, .03, .02, .01, mat(0xc5d0da), 0, 1.45, .46), rb(.06, .7, .07, .03, steel, -.43, .62, .48), rb(.06, .4, .07, .03, steel, -.43, 1.7, .48));
    fr.add(rb(.3, .3, .02, .03, A(), .2, 1.85, .46)); fr.position.set(1.55, 0, -2.0); g.add(fr);
    g.add(cyl(.008, .008, 1.2, mat(0x333333), .3, 2.6, -1.4, 6), cyl(.32, .12, .32, lit(0xffe2a0, .8), .3, 2.45, -1.4), cyl(.008, .008, .4, mat(0x333333), .3, 3.8, -1.4, 6));
    g.add(frameArt(1.55, 3.6, .7, .7, ['#c9f0c0', '#ff6a5a', '#fff']));
    hot.cocina = [{ id: 'fridge', obj: fr, r: 90 }];
    return g;
  }

  /* ---------- BAÑO ---------- */
  let duck, waterMesh;
  function bano() {
    const g = new THREE.Group();
    const tile = tileTexture('#cfeefb', '#ffffff'); tile.repeat.set(4, 2);
    g.add(plane(16, 3.2, new THREE.MeshStandardMaterial({ map: tile, roughness: .35 }), 0, 1.6, WALL_Z + .02));
    g.add(rb(16, .08, .14, .03, D(), 0, 3.2, WALL_Z + .07));
    const tub = new THREE.Group();
    tub.add(rb(2.6, .14, 1.7, .05, white, 0, 0, 0), rb(2.6, .72, .22, .1, white, 0, 0, -.74), rb(2.6, .3, .22, .1, white, 0, 0, .74), rb(.22, .6, 1.7, .1, white, -1.19, 0, 0), rb(.22, .6, 1.7, .1, white, 1.19, 0, 0));
    tub.add(rb(2.66, .06, .28, .03, A(), 0, .72, -.74), rb(2.66, .06, .28, .03, A(), 0, .3, .74));
    for (const [x, z] of [[-1.0, -.6], [1.0, -.6], [-1.0, .6], [1.0, .6]]) tub.add(sph(.1, steel, x, -.02, z));
    waterMesh = new THREE.Mesh(new THREE.BoxGeometry(2.2, .04, 1.3), mat(0x6fd2ff, { transparent: true, opacity: .82, roughness: .1, metalness: .1 })); waterMesh.position.set(0, .4, 0); tub.add(waterMesh);
    tub.position.set(0, 0, -.25); g.add(tub);
    const tap = new THREE.Group(); tap.add(cyl(.05, .05, .45, steel, 0, 0, 0, 12), put(new THREE.Mesh(new THREE.CylinderGeometry(.045, .045, .4, 12), steel), 0, .45, .18)); tap.children[1].rotation.x = Math.PI / 2; tap.position.set(.75, .72, -.95); tub.add(tap);
    // ducha
    g.add(cyl(.04, .04, 2.6, steel, 1.55, 0, WALL_Z + .14, 12));
    const head = cyl(.3, .22, .08, steel, 1.1, 2.52, WALL_Z + .6); head.rotation.x = .35; const arm = put(new THREE.Mesh(new THREE.CylinderGeometry(.03, .03, .6, 10), steel), 1.3, 2.6, WALL_Z + .3); arm.rotation.z = Math.PI / 2 - .2; g.add(head, arm);
    // patito
    duck = new THREE.Group(); duck.add(sph(.2, lit(0xffd21f, .25), 0, .17, 0, 1.2, .9, 1), sph(.13, lit(0xffd21f, .25), .16, .34, 0), put(new THREE.Mesh(new THREE.ConeGeometry(.05, .12, 10), mat(0xff8a1f)), .3, .33, 0), sph(.02, mat(0x222222), .22, .4, .07), sph(.02, mat(0x222222), .22, .4, -.07));
    duck.children[2].rotation.z = -Math.PI / 2; duck.position.set(-.8, .44, -.25); g.add(duck);
    anim.push((dt, t) => { duck.position.y = .42 + Math.sin(t * 2) * .02; duck.rotation.y = Math.sin(t * .8) * .4; });
    // toalla y alfombrilla
    g.add(rb(.8, 1.0, .08, .04, white, -1.85, 1.3, WALL_Z + .08), rb(.75, .9, .1, .04, A(), -1.85, 1.0, WALL_Z + .12), cyl(.02, .02, 1.0, steel, -1.85, 1.35, WALL_Z + .05, 8));
    g.add(rb(1.8, .04, .9, .02, A(), 0, 0, 1.25));
    const mir = cyl(.5, .5, .05, mat(0xbfe9ff, { metalness: .6, roughness: .1 }), -.9, 3.4, WALL_Z + .06); mir.rotation.x = Math.PI / 2; g.add(mir);
    const ring = put(new THREE.Mesh(new THREE.TorusGeometry(.52, .05, 10, 40), steel), -.9, 3.9, WALL_Z + .07); g.add(ring);
    return g;
  }

  /* ---------- DORMITORIO ---------- */
  let bedLamp, bedLight = { pos: new THREE.Vector3(1.5, 1.35, -1.8) };
  function dormitorio() {
    const g = new THREE.Group();
    g.add(cyl(1.3, 1.3, .03, A(), 0, 0, .8, 48));
    g.add(rb(2.75, .42, 1.8, .1, wood, -.35, 0, -1.6), rb(2.6, .3, 1.65, .14, mat(0xfbfbff), -.35, .4, -1.6), rb(.22, 1.4, 1.85, .09, wood, -1.72, 0, -1.6));
    g.add(rb(.85, .2, .52, .1, white, -1.25, .68, -1.6), rb(1.65, .2, 1.7, .1, A(), .15, .62, -1.6), rb(1.65, .05, 1.72, .04, D(), .15, .81, -1.6));
    const teddy = new THREE.Group(); const br = mat(0xb5773f); teddy.add(sph(.22, br, 0, .22, 0, 1, 1.1, 1), sph(.16, br, 0, .52, 0), sph(.06, br, -.12, .65, 0), sph(.06, br, .12, .65, 0), sph(.05, mat(0xf0d2a8), 0, .49, .13, 1, .8, 1), sph(.02, mat(0x222222), -.06, .56, .14), sph(.02, mat(0x222222), .06, .56, .14)); teddy.position.set(.75, .82, -2.15); teddy.rotation.y = -.2; g.add(teddy);
    g.add(rb(.78, .75, .62, .07, wood, 1.6, 0, -2.0), rb(.7, .3, .04, .02, mat(0x8a5730), 1.6, .4, -1.68));
    bedLamp = new THREE.Group(); bedLamp.add(cyl(.12, .14, .05, mat(0x3a3d46), 0, 0, 0), cyl(.025, .025, .35, mat(0x3a3d46), 0, .05, 0, 8), cyl(.26, .18, .3, lit(0xffe6a8, .35), 0, .38, 0)); bedLamp.position.set(1.6, .75, -2.0); g.add(bedLamp);
    g.add(sph(.3, lit(0xfff3c2, .6), 1.6, 3.6, WALL_Z + .05, 1, 1, .15));
    g.add(windowAt(-.6, 3.0, 1.4, 1.3), curtain(-1.5, 2.3, 1.65), curtain(.3, 2.3, 1.65));
    g.add(frameArt(-1.75, 3.5, .6, .6, ['#d8c6ff', '#7a5cff', '#ffe27a']));
    hot.dormitorio = [{ id: 'lamp', obj: bedLamp, r: 80 }];
    return g;
  }

  /* ---------- SALA DE JUEGOS ---------- */
  function juegos() {
    const g = new THREE.Group();
    g.add(cyl(1.35, 1.35, .03, D(), 0, 0, .45, 48), cyl(1.0, 1.0, .035, A(), 0, 0, .45, 48));
    const arcade = (x, col) => {
      const a = new THREE.Group(); const body = mat(col);
      a.add(rb(.95, 1.9, .8, .1, body, 0, 0, 0), rb(1.0, .3, .86, .08, A(), 0, 1.7, 0), rb(.95, .18, .7, .06, mat(0x22242b), 0, .86, .28));
      const scr = canvasTex(128, 128, (c, w) => { const g2 = c.createLinearGradient(0, 0, 0, w); g2.addColorStop(0, '#10134a'); g2.addColorStop(1, '#3a1d7a'); c.fillStyle = g2; c.fillRect(0, 0, w, w); c.fillStyle = '#5ff0ff'; for (let i = 0; i < 4; i++) c.fillRect(14 + i * 24, 26 + (i % 2) * 18, 16, 10); c.fillStyle = '#ffe14d'; c.beginPath(); c.arc(64, 94, 14, .3, Math.PI * 2 - .3); c.lineTo(64, 94); c.fill(); }, false);
      const s = plane(.72, .6, new THREE.MeshBasicMaterial({ map: scr }), 0, 1.3, .41); s.rotation.x = -.2; a.add(s);
      a.add(cyl(.02, .02, .14, steel, -.18, .94, .3, 8), sph(.05, mat(0xff3b5c), -.18, 1.1, .3), sph(.04, mat(0x3bff8a), .14, .96, .3), sph(.04, mat(0xffe14d), .26, .96, .3));
      a.position.set(x, 0, -2.2); return a;
    };
    const a1 = arcade(-1.0, 0x7a3bd6), a2 = arcade(.15, 0x2c86d9); g.add(a1, a2);
    const bag = (x, z, c) => sph(.62, mat(c, { roughness: .9 }), x, .32, z, 1.1, .55, 1);
    g.add(bag(1.6, -1.6, 0xff6fa5), bag(1.35, -.7, 0x6fd0ff));
    const blocks = new THREE.Group(); [[0, 0, 0xff5a5a], [.42, 0, 0xffd24a], [.2, .42, 0x4f9aff], [.9, 0, 0x5fe37a]].forEach(([x, y, c], i) => blocks.add(rb(.4, .4, .4, .05, mat(c), x, y, (i % 2) * .05)));
    blocks.position.set(.95, 0, -.35); g.add(blocks);
    const teddy = new THREE.Group(); const br = mat(0xc08a4a); teddy.add(sph(.4, br, 0, .42, 0, 1, 1.1, 1), sph(.3, br, 0, 1.0, 0), sph(.12, br, -.22, 1.28, 0), sph(.12, br, .22, 1.28, 0), sph(.1, mat(0xf0d2a8), 0, .94, .26, 1, .8, 1), sph(.04, mat(0x222222), -.1, 1.06, .27), sph(.04, mat(0x222222), .1, 1.06, .27), sph(.08, mat(0xf0d2a8), -.34, .35, .15), sph(.08, mat(0xf0d2a8), .34, .35, .15));
    teddy.position.set(-2.05, 0, -1.2); teddy.rotation.y = .5; g.add(teddy);
    const balloons = new THREE.Group(); [[-1.7, 4.3, 0xff5a7a], [-1.3, 4.7, 0xffd24a], [-.9, 4.2, 0x4fb2ff], [.9, 4.5, 0x5fe37a], [1.3, 4.1, 0xb45aff], [1.7, 4.6, 0xff9a3a]].forEach(([x, y, c]) => { balloons.add(sph(.3, lit(c, .15), x, y, WALL_Z + .4, 1, 1.2, 1)); balloons.add(cyl(.004, .004, 1.0, mat(0xffffff), x, y - 1.5, WALL_Z + .4, 4)); }); g.add(balloons);
    anim.push((dt, t) => { balloons.position.y = Math.sin(t * 1.1) * .06; });
    hot.juegos = [{ id: 'arcade', obj: a1, r: 95 }, { id: 'arcade', obj: a2, r: 95 }];
    return g;
  }

  const rooms = { salon: salon(), cocina: cocina(), bano: bano(), dormitorio: dormitorio(), juegos: juegos() };
  for (const r of Object.values(rooms)) { r.visible = false; scene.add(r); }
  const decoGroup = new THREE.Group(); scene.add(decoGroup);

  /* decoración especial de cada tema */
  function deco(t) {
    while (decoGroup.children.length) decoGroup.remove(decoGroup.children[0]);
    const add = o => decoGroup.add(o), z = WALL_Z + .05, acc = t.accent;
    switch (t.id) {
      case 'cuqui': for (let i = 0; i < 9; i++) { const x = -3 + i * .75, y = 5.0 - Math.sin(i / 8 * Math.PI) * .5; const m = new THREE.Mesh(new THREE.ConeGeometry(.22, .5, 3), lit([0xff7ab0, 0xffe27a, 0x7fd6ff][i % 3], .2)); m.position.set(x, y - .25, z + .05); m.rotation.z = Math.PI; m.rotation.x = Math.PI / 2 * 0; add(m); } break;
      case 'submarino': for (const [x, y, r] of [[-2.6, 4.2, .4], [-2.1, 5.2, .22], [2.4, 4.6, .34], [2.8, 3.6, .2]]) add(sph(r, mat(0xbfefff, { transparent: true, opacity: .35, roughness: .05 }), x, y, z + .2)); { const st = new THREE.Mesh(new THREE.CircleGeometry(.45, 5), lit(0xff8a5c, .3)); st.position.set(-2.3, 3.3, z + .02); st.rotation.z = .3; add(st); } break;
      case 'selva': for (let i = 0; i < 6; i++) { const x = -3 + i * 1.2; add(cyl(.03, .03, 1.2 + (i % 3) * .5, mat(0x2f8a3a), x, 5.6 - (1.2 + (i % 3) * .5), z + .1, 6)); add(sph(.16, mat(0x4fd66f, { flatShading: true }), x, 5.6 - (1.2 + (i % 3) * .5), z + .1, 1.6, .5, 1)); } break;
      case 'playa': { const sun = cyl(.55, .55, .05, lit(0xffe27a, .5), 2.3, 4.4, z + .02); sun.rotation.x = Math.PI / 2; add(sun); const ring = put(new THREE.Mesh(new THREE.TorusGeometry(.4, .13, 10, 28), lit(0xff5a5a, .2)), -2.3, 4.1, z + .1); add(ring); } break;
      case 'espacio': { add(sph(.6, mat(acc, { roughness: .5 }), 2.4, 4.4, z + .5)); const r = put(new THREE.Mesh(new THREE.TorusGeometry(.95, .05, 8, 40), lit(0xffe27a, .3)), 2.4, 4.4, z + .5); r.rotation.x = 1.25; add(r); add(sph(.22, mat(0xdddddd), -2.4, 4.8, z + .3)); } break;
      case 'neon': { const r = put(new THREE.Mesh(new THREE.TorusGeometry(.6, .05, 10, 40), lit(acc, 1.4)), 2.2, 4.3, z + .05); add(r); const tri = put(new THREE.Mesh(new THREE.TorusGeometry(.5, .05, 3, 3), lit(t.dark, 1.4)), -2.2, 4.3, z + .05); add(tri); } break;
    }
  }


  /* ---------- muebles que se compran en la tienda (cada uno con su sitio en una habitación) ---------- */
  function makeFurniture(id, name = 'GAMBI') {
    const g = new THREE.Group(), A2 = c => mat(c);
    switch (id) {
      case 'pecera': {
        g.add(rb(.75, .62, .55, .05, wood, 0, 0, 0));
        const tank = rb(.72, .55, .46, .04, mat(0x9fe8ff, { transparent: true, opacity: .32, roughness: .05, metalness: .1 }), 0, .62, 0); g.add(tank);
        g.add(rb(.66, .38, .4, .03, mat(0x2aa8e8, { transparent: true, opacity: .55, roughness: .1 }), 0, .64, 0));
        g.add(rb(.66, .05, .4, .02, mat(0xf2d99a), 0, .63, 0));
        const weed = mat(0x3fbf5a); for (const x of [-.22, .2]) g.add(sph(.06, weed, x, .76, -.05, .6, 2, .6));
        const fish = []; for (const [c, r] of [[0xff8a2a, .2], [0xffd84a, .14]]) { const f = new THREE.Group(); const b = sph(.045, lit(c, .2), 0, 0, 0, 1.5, 1, .7); const t = put(new THREE.Mesh(new THREE.ConeGeometry(.035, .06, 3), lit(c, .2)), -.07, 0, 0); t.rotation.z = Math.PI / 2; f.add(b, t); g.add(f); fish.push([f, r]); }
        anim.push((dt, t) => fish.forEach(([f, r], i) => { const a = t * (.8 + i * .3) + i * 2; f.position.set(Math.cos(a) * r, .85 + Math.sin(a * 2) * .04, Math.sin(a) * r * .5); f.rotation.y = -a - Math.PI / 2; }));
        break;
      }
      case 'guitarra': {
        const body = mat(0xd9792a), dark = mat(0x5a3418);
        const gg = new THREE.Group(); g.add(gg); gg.rotation.z = -.22;
        gg.add(sph(.26, body, 0, .3, 0, 1, 1, .32), sph(.2, body, 0, .62, 0, 1, 1, .32), sph(.07, dark, 0, .42, .085, 1, 1, .3));
        gg.add(rb(.07, .8, .05, .02, dark, 0, .7, .02), rb(.12, .16, .05, .02, dark, 0, 1.5, .02));
        break;
      }
      case 'poster': {
        const t = canvasTex(256, 340, (c, w, h) => { const gr = c.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#ff9a5a'); gr.addColorStop(1, '#ff4d8d'); c.fillStyle = gr; c.fillRect(0, 0, w, h);
          c.fillStyle = '#ffd9b0'; c.beginPath(); c.ellipse(130, 170, 70, 46, -.3, 0, 7); c.fill(); c.beginPath(); c.ellipse(190, 120, 34, 26, -.6, 0, 7); c.fill(); c.fillStyle = '#222'; c.beginPath(); c.arc(98, 160, 9, 0, 7); c.fill();
          c.strokeStyle = '#ffd9b0'; c.lineWidth = 4; c.beginPath(); c.moveTo(70, 170); c.quadraticCurveTo(10, 90, 60, 40); c.stroke();
          c.fillStyle = '#fff'; c.font = '700 44px Fredoka, sans-serif'; c.textAlign = 'center'; c.fillText(name, w / 2, 300); }, false);
        g.scale.setScalar(.8); g.add(rb(.84, 1.1, .04, .02, white, 0, -.55, 0)); g.add(plane(.76, 1.02, new THREE.MeshBasicMaterial({ map: t }), 0, 0, .03));
        break;
      }
      case 'reloj': {
        const face = cyl(.32, .32, .05, white, 0, 0, 0, 36); face.rotation.x = Math.PI / 2; g.add(face);
        const ring = put(new THREE.Mesh(new THREE.TorusGeometry(.32, .04, 10, 36), A()), 0, 0, .02); g.add(ring);
        for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; g.add(put(new THREE.Mesh(new THREE.BoxGeometry(.02, i % 3 ? .03 : .06, .01), mat(0x333344)), Math.sin(a) * .25, Math.cos(a) * .25, .035)); g.children[g.children.length - 1].rotation.z = -a; }
        const hand = (l, w, c) => { const p = new THREE.Group(); const m = new THREE.Mesh(new THREE.BoxGeometry(w, l, .012), mat(c)); m.position.y = l / 2; p.add(m); p.position.z = .045; g.add(p); return p; };
        const hh = hand(.15, .03, 0x333344), mh = hand(.22, .02, 0x333344), sh2 = hand(.24, .008, 0xe32b2b);
        anim.push(() => { const d = new Date(), sec = d.getSeconds() + d.getMilliseconds() / 1000, m = d.getMinutes() + sec / 60, h = (d.getHours() % 12) + m / 60; sh2.rotation.z = -sec / 60 * Math.PI * 2; mh.rotation.z = -m / 60 * Math.PI * 2; hh.rotation.z = -h / 12 * Math.PI * 2; });
        break;
      }
      case 'hierbas': {
        [[-.22, 0x3fae5a], [0, 0x6fd06a], [.22, 0x2f8a3a]].forEach(([x, c]) => { g.add(cyl(.09, .07, .14, mat(0xc46a3a), x, 0, 0, 16)); for (let i = 0; i < 5; i++) g.add(sph(.045, mat(c, { flatShading: true }), x + rnd(-.04, .04), .19 + rnd(0, .07), rnd(-.04, .04))); });
        break;
      }
      case 'patitos': {
        [[-.3, .7], [0, .6], [.3, .55]].forEach(([x, k]) => { const d = new THREE.Group(); d.add(sph(.2, lit(0xffd21f, .25), 0, .17, 0, 1.2, .9, 1), sph(.13, lit(0xffd21f, .25), .16, .34, 0), sph(.02, mat(0x222222), .22, .4, .07), sph(.02, mat(0x222222), .22, .4, -.07)); const bk = put(new THREE.Mesh(new THREE.ConeGeometry(.05, .12, 10), mat(0xff8a1f)), .3, .33, 0); bk.rotation.z = -Math.PI / 2; d.add(bk); d.scale.setScalar(k); d.position.x = x; d.rotation.y = -.6 + x; g.add(d); });
        break;
      }
      case 'lava': {
        g.add(cyl(.17, .2, .55, mat(0x5a5f6b), 0, 0, 0, 18));
        g.add(cyl(.11, .17, .9, mat(0xff5aa5, { transparent: true, opacity: .55, roughness: .1, emissive: 0xff2a85, emissiveIntensity: .5 }), 0, .55, 0, 18));
        g.add(cyl(.11, .08, .14, mat(0x5a5f6b), 0, 1.45, 0, 18));
        const blobs = []; for (let i = 0; i < 4; i++) { const b = sph(.06 + i * .01, lit(0xffd84a, .9), 0, .7, 0); g.add(b); blobs.push(b); }
        anim.push((dt, t) => blobs.forEach((b, i) => { b.position.y = .72 + (Math.sin(t * .5 + i * 1.7) * .5 + .5) * .62; b.position.x = Math.sin(t * .7 + i) * .03; b.scale.set(1, 1.2 + Math.sin(t + i) * .3, 1); }));
        break;
      }
      case 'estrellas': {
        const shape = new THREE.Shape(); for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2 + Math.PI / 2, r = i % 2 ? .05 : .12; i ? shape.lineTo(Math.cos(a) * r, Math.sin(a) * r) : shape.moveTo(Math.cos(a) * r, Math.sin(a) * r); }
        const geo = new THREE.ShapeGeometry(shape), m = lit(0xfff3a0, 1.1);
        [[-1.85, 2.9, .9], [-1.3, 3.3, .6], [.9, 3.3, .7], [1.9, 2.7, .8], [.35, 3.5, .5], [-.6, 3.5, .5], [2.05, 3.35, .5]].forEach(([x, y, k]) => { const st = new THREE.Mesh(geo, m); st.position.set(x, y, 0); st.scale.setScalar(k); st.rotation.z = x; g.add(st); });
        anim.push((dt, t) => { m.emissiveIntensity = .8 + night * 1.6 + Math.sin(t * 2) * .2; });
        break;
      }
      case 'trofeos': {
        g.add(rb(1.25, .07, .3, .02, wood, 0, 0, 0));
        const gold = mat(0xffc93a, { metalness: .5, roughness: .3, emissive: 0x4a3000 }), silver = mat(0xd0d8e0, { metalness: .5, roughness: .3 });
        [[-.4, gold, 1], [0, silver, .8], [.4, mat(0xd9894a, { metalness: .4, roughness: .35 }), .7]].forEach(([x, m2, k]) => { const tr = new THREE.Group(); tr.add(cyl(.1, .12, .06, mat(0x3a3d46), 0, 0, 0, 16), cyl(.025, .025, .14, m2, 0, .06, 0, 10)); const cup = new THREE.Mesh(new THREE.CylinderGeometry(.13, .05, .2, 20, 1, true), m2); cup.material.side = THREE.DoubleSide; cup.position.y = .3; tr.add(cup); for (const s2 of [-1, 1]) { const hd = put(new THREE.Mesh(new THREE.TorusGeometry(.05, .012, 8, 16), m2), s2 * .14, .3, 0); hd.rotation.y = Math.PI / 2; tr.add(hd); } tr.scale.setScalar(k); tr.position.set(x, .07, 0); g.add(tr); });
        break;
      }
      case 'neon': {
        const t = canvasTex(512, 160, (c, w, h) => { c.clearRect(0, 0, w, h); c.font = '700 110px Fredoka, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.shadowColor = '#ff3fb4'; c.shadowBlur = 26; c.lineWidth = 9; c.strokeStyle = '#ff3fb4'; c.strokeText(name.toUpperCase().slice(0, 10), w / 2, h / 2 + 6); c.shadowBlur = 8; c.fillStyle = '#ffe6f6'; c.fillText(name.toUpperCase().slice(0, 10), w / 2, h / 2 + 6); }, false);
        g.add(rb(1.9, .7, .04, .05, mat(0x1a1030), 0, -.35, 0));
        g.add(plane(1.8, .56, new THREE.MeshBasicMaterial({ map: t, transparent: true }), 0, 0, .03));
        break;
      }
    }
    return g;
  }
  const FURN_POS = {
    pecera: ['salon', -1.35, 0, -.7, .35], guitarra: ['salon', 1.42, 0, -1.45, -.2], poster: ['salon', 1.38, 2.15, WALL_Z + .03, 0],
    reloj: ['cocina', .66, 2.05, WALL_Z + .04, 0], hierbas: ['cocina', -1.1, 1.01, -2.25, 0],
    patitos: ['bano', .15, .76, -.99, 0], lava: ['dormitorio', 1.5, 0, -1.15, 0], estrellas: ['dormitorio', 0, 0, WALL_Z + .05, 0],
    trofeos: ['juegos', 1.25, 2.5, WALL_Z + .2, 0], neon: ['juegos', -.42, 2.85, WALL_Z + .04, 0],
  };
  const furn = {};
  function setFurniture(on, name) {
    for (const [id, [r, x, y, z, ry]] of Object.entries(FURN_POS)) {
      const want = !!on[id], key = id + (id === 'neon' || id === 'poster' ? ':' + name : '');
      if (furn[id] && (furn[id].key !== key || !want)) { rooms[r].remove(furn[id].g); delete furn[id]; }
      if (want && !furn[id]) { const g = makeFurniture(id, name); g.position.set(x, y, z); g.rotation.y = ry; rooms[r].add(g); furn[id] = { g, key }; }
    }
  }
  // manta del dormitorio (se ve cuando duerme)
  const blanket = new THREE.Group();
  blanket.add(rb(1.2, .1, 1.05, .05, A(), 0, 0, 0), rb(1.22, .05, .25, .03, white, 0, .05, -.42));
  blanket.position.set(.05, .9, -1.45); blanket.visible = false; rooms.dormitorio.add(blanket);


  // rayos de sol que entran por las ventanas (desaparecen de noche)
  const beamTex = canvasTex(64, 256, (c, w, h) => { const g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, 'rgba(255,236,190,.9)'); g.addColorStop(1, 'rgba(255,236,190,0)'); c.fillStyle = g; c.fillRect(0, 0, w, h); const g2 = c.createLinearGradient(0, 0, w, 0); g2.addColorStop(0, 'rgba(0,0,0,1)'); g2.addColorStop(.2, 'rgba(0,0,0,0)'); g2.addColorStop(.8, 'rgba(0,0,0,0)'); g2.addColorStop(1, 'rgba(0,0,0,1)'); c.globalCompositeOperation = 'destination-out'; c.fillStyle = g2; c.fillRect(0, 0, w, h); }, false);
  const beamMat = new THREE.MeshBasicMaterial({ map: beamTex, transparent: true, opacity: .22, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
  const beams = [];
  for (const [r, wx, wy] of [['salon', -.05, 2.6], ['dormitorio', -.6, 3.0]]) {
    for (const k of [-.45, 0, .45]) { const b = new THREE.Mesh(new THREE.PlaneGeometry(.55, 3.6), beamMat); b.position.set(wx + k + .9, wy - 1.35, WALL_Z + 1.35); b.rotation.set(-.62, .35, .28); b.renderOrder = 2; rooms[r].add(b); beams.push(b); }
  }
  const tmpC = new THREE.Color();
  const skyDay = {}, skyNight = skyTexture(0, true);
  let curTheme = null, night = 0, curRoom = 'salon';
  const nightWall = new THREE.Color(0x4a5490), white3 = new THREE.Color(0xffffff);
  function applyTheme(id) {
    const t = THEMES.find(x => x.id === id) || THEMES[0]; curTheme = t;
    if (wallMat.map) { wallMat.map.dispose(); floorMat.map.dispose(); }
    wallMat.map = wallTexture(t); wallMat.map.repeat.set(4, 3); wallMat.needsUpdate = true;
    floorMat.map = floorTexture(t); floorMat.map.repeat.set(8, 6); floorMat.needsUpdate = true;
    for (const m of accents) m.color.set(t.accent);
    for (const m of darks) m.color.set(t.dark);
    skyDay[t.id] = skyDay[t.id] || skyTexture(t.sky, false);
    deco(t); setNight(night);
  }
  function setNight(k) {
    night = k;
    tmpC.lerpColors(white3, nightWall, k); wallMat.color.copy(tmpC); floorMat.color.copy(tmpC); base.material.color.copy(tmpC);
    winMat.map = k > .5 ? skyNight : skyDay[curTheme.id]; winMat.needsUpdate = true;
    if (bedLamp) bedLamp.children[2].material.emissiveIntensity = .35 + k * 1.4;
    beamMat.opacity = .22 * (1 - k); for (const b of beams) b.visible = k < .9;
  }
  function setRoom(id) { curRoom = id; for (const [k, r] of Object.entries(rooms)) r.visible = k === id; }
  const SPOTS = {
    salon: { x: [-.9, .9], z: [-.1, .9] }, cocina: { fixed: [0, 0, .5] }, bano: { fixed: [0, .34, -.2] },
    dormitorio: { fixed: [0, 0, .6], sleep: [-.6, .86, -1.45] }, juegos: { x: [-.8, .8], z: [.1, .9] },
  };
  function update(dt, t) { for (const f of anim) f(dt, t); }
  return {
    rooms, hot, applyTheme, setNight, setRoom, update, SPOTS, get night() { return night; }, get theme() { return curTheme; }, get room() { return curRoom; },
    bedLampPos: () => bedLight.pos, ball: hot.salon[0].obj, water: () => waterMesh, shared, decoGroup,
    makeFurniture, setFurniture, furnSpot: id => { const p = FURN_POS[id]; return p && { room: p[0], x: p[1], y: p[2], z: p[3] }; }, setBlanket: (v, y) => { blanket.visible = v; if (y) blanket.position.y = y; },
  };
}
