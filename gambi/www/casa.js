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
    const teddy = new THREE.Group(); const br = mat(0xb5773f); teddy.add(sph(.22, br, 0, .22, 0, 1, 1.1, 1), sph(.16, br, 0, .52, 0), sph(.06, br, -.12, .65, 0), sph(.06, br, .12, .65, 0), sph(.05, mat(0xf0d2a8), 0, .49, .13, 1, .8, 1), sph(.02, mat(0x222222), -.06, .56, .14), sph(.02, mat(0x222222), .06, .56, .14)); teddy.position.set(.2, .86, -.9); teddy.rotation.y = -.4; g.add(teddy);
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
  };
}
