// Tienda de Gambi y miniaturas renderizadas en 3D de cada objeto.
import { FOODS, CHARS, SKINS, HATS, THEMES, TABS, MINIGAMES, owns, persist } from './datos.js';

export function createShop(ctx) {
  const { THREE, M, scene, R, cv, cam, house, player, pet, PN, PA, save, toast, updHud, S, buzz, applyLook, buildTray, leave, foodMesh, FL, VIEW } = ctx;
  const $ = s => document.querySelector(s);
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v)), lerp = (a, b, t) => a + (b - a) * t;
  const _v = new THREE.Vector3();

  /* ---------- miniaturas ---------- */
  const TW = 320, TH = 240, cache = {}, bgs = {};
  let queue = Promise.resolve();
  const tcam = new THREE.PerspectiveCamera(30, TW / TH, .1, 100), tkey = new THREE.DirectionalLight(0xffffff, 0);
  scene.add(tkey);   // siempre en la escena (intensidad 0) para no cambiar el número de luces
  const shade = (c, f) => (Math.round((c >> 16 & 255) * f) << 16) | (Math.round((c >> 8 & 255) * f) << 8) | Math.round((c & 255) * f);
  const rgb = (c, f = 1, a = 1) => `rgba(${Math.min(255, Math.round(((c >> 16) & 255) * f))},${Math.min(255, Math.round(((c >> 8) & 255) * f))},${Math.min(255, Math.round((c & 255) * f))},${a})`;
  function bgTex(top, bot, glow) {
    const k = top + '-' + bot + '-' + glow;
    return bgs[k] || (bgs[k] = M.canvasTex(TW, TH, (c, w, h) => {
      const g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, rgb(top)); g.addColorStop(1, rgb(bot)); c.fillStyle = g; c.fillRect(0, 0, w, h);
      const r = c.createRadialGradient(w / 2, h * .58, 0, w / 2, h * .58, w * .55); r.addColorStop(0, rgb(glow, 1, .75)); r.addColorStop(1, rgb(glow, 1, 0)); c.fillStyle = r; c.fillRect(0, 0, w, h);
      c.fillStyle = 'rgba(0,0,0,.2)'; c.fillRect(0, h * .87, w, h * .13);
    }, false));
  }
  function capture(bg, place, opts = {}) {
    const L = ctx.lights, hide = [house.shared, house.decoGroup, ...Object.values(house.rooms), PN.pts, PA.pts, ...FL.list.map(f => f.s)];
    const vis = hide.map(o => o.visible), pv = [player.root.visible, player.root.position.clone(), player.root.rotation.y, player.root.scale.x];
    const tl = { p: player.tilt.position.clone(), r: player.tilt.rotation.clone(), s: player.tilt.scale.clone() };
    const prev = { bg: scene.background, pr: R.getPixelRatio(), sz: R.getSize(new THREE.Vector2()), hi: L.hemi.intensity, si: L.sun.intensity, li: L.lamp.intensity, foam: ctx.foam.visible };
    hide.forEach(o => { o.visible = false; });
    player.root.visible = !opts.hidePlayer; player.root.position.set(0, 0, 0); player.root.rotation.y = 0; player.root.scale.setScalar(1); ctx.foam.visible = false;
    scene.background = bg; L.hemi.intensity = 1.7; L.sun.intensity = 1.2; L.lamp.intensity = 0;
    R.setPixelRatio(1); R.setSize(TW, TH, false);
    tcam.fov = 30; place(tcam); tcam.updateProjectionMatrix();
    tkey.intensity = 1.5; tkey.position.copy(tcam.position).add(_v.set(.6, 2.2, 0));
    R.render(scene, tcam);
    const url = cv.toDataURL('image/jpeg', .9);
    tkey.intensity = 0; if (opts.after) opts.after();
    hide.forEach((o, i) => { o.visible = vis[i]; });
    player.root.visible = pv[0]; player.root.position.copy(pv[1]); player.root.rotation.y = pv[2]; player.root.scale.setScalar(pv[3]);
    player.tilt.position.copy(tl.p); player.tilt.rotation.copy(tl.r); player.tilt.scale.copy(tl.s); ctx.foam.visible = prev.foam;
    scene.background = prev.bg; L.hemi.intensity = prev.hi; L.sun.intensity = prev.si; L.lamp.intensity = prev.li;
    R.setPixelRatio(prev.pr); R.setSize(prev.sz.x, prev.sz.y, false);
    return url;
  }
  function withPlayer(fn) {
    const s = { id: player.curId, hat: player.hatId, skin: player.skin };
    try { return fn(); } finally { player.useNow(s.id); player.setHat(s.hat); if (s.skin) player.setSkin(s.skin); }
  }
  function posePlayer() {
    player.tilt.position.set(0, 0, 0); player.tilt.scale.set(1, 1, 1); player.tilt.rotation.set(0, 0, 0);
    for (let i = 0; i < 3; i++) player.pose(1.2, 'idle', 1.4 + i * .3, .3);
    player.root.updateMatrixWorld(true);
  }
  const petCam = cam => { cam.position.set(1.45, .85, -1.9); cam.lookAt(0, .27, 0); };
  function flat(draw) {
    const c = document.createElement('canvas'); c.width = TW; c.height = TH; const x = c.getContext('2d');
    x.textAlign = 'center'; x.textBaseline = 'middle'; draw(x, TW, TH); return c.toDataURL('image/jpeg', .9);
  }
  const hexs = c => '#' + c.toString(16).padStart(6, '0');
  function themeThumb(t) {
    return flat((x, w, h) => {
      const g = x.createLinearGradient(0, 0, 0, h * .66); g.addColorStop(0, t.wall[0]); g.addColorStop(1, t.wall[1]); x.fillStyle = g; x.fillRect(0, 0, w, h * .66);
      x.fillStyle = t.line; x.globalAlpha = .4;
      for (let i = 0; i < 28; i++) { const px = (i % 7) * 50 + 20 + (Math.floor(i / 7) % 2) * 22, py = Math.floor(i / 7) * 36 + 18; if (t.wpat === 'stripes') x.fillRect(px - 10, 0, 18, h * .66); else if (t.wpat === 'waves') { x.fillRect(px - 16, py, 30, 4); } else if (t.wpat === 'grid') { x.fillRect(px, 0, 2, h * .66); } else { x.beginPath(); x.arc(px, py, t.wpat === 'stars' ? 2 : 6, 0, 7); x.fill(); } }
      x.globalAlpha = 1;
      const f = x.createLinearGradient(0, h * .66, 0, h); f.addColorStop(0, t.floor[0]); f.addColorStop(1, t.floor[1]); x.fillStyle = f; x.fillRect(0, h * .66, w, h * .34);
      x.fillStyle = hexs(t.accent); x.beginPath(); x.roundRect ? x.roundRect(28, h * .44, 130, 52, 14) : x.rect(28, h * .44, 130, 52); x.fill();
      x.fillStyle = hexs(t.dark); x.beginPath(); x.roundRect ? x.roundRect(20, h * .5, 26, 46, 10) : x.rect(20, h * .5, 26, 46); x.fill(); x.beginPath(); x.roundRect ? x.roundRect(140, h * .5, 26, 46, 10) : x.rect(140, h * .5, 26, 46); x.fill();
      x.fillStyle = 'rgba(255,255,255,.9)'; x.fillRect(214, h * .14, 70, 58); x.fillStyle = hexs(t.sky); x.fillRect(219, h * .14 + 5, 60, 48);
      x.fillStyle = hexs(t.accent); x.beginPath(); x.ellipse(w * .72, h * .86, 70, 14, 0, 0, 7); x.fill();
    });
  }
  function gameThumb(g) {
    return flat((x, w, h) => {
      const gr = x.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, rgb(g.col[0])); gr.addColorStop(1, rgb(g.col[1])); x.fillStyle = gr; x.fillRect(0, 0, w, h);
      x.globalAlpha = .9;
      if (g.id === 'catch') { const cols = ['#ffb04a', '#ff7ab0', '#fff27a', '#9bff8a', '#5ff0ff']; for (let i = 0; i < 9; i++) { x.fillStyle = cols[i % 5]; x.beginPath(); x.arc(28 + i * 33, 28 + (i * 47) % 120, 13, 0, 7); x.fill(); } x.fillStyle = '#20222b'; x.beginPath(); x.arc(240, 170, 24, 0, 7); x.fill(); x.fillStyle = 'rgba(255,255,255,.95)'; x.beginPath(); x.ellipse(w / 2, 212, 54, 12, 0, 0, 7); x.fill(); }
      else if (g.id === 'bubbles') { for (let i = 0; i < 11; i++) { const r = 14 + (i * 13) % 30, bx = 30 + (i * 59) % 270, by = 40 + (i * 83) % 170; x.strokeStyle = 'rgba(255,255,255,.9)'; x.fillStyle = 'rgba(255,255,255,.22)'; x.lineWidth = 4; x.beginPath(); x.arc(bx, by, r, 0, 7); x.fill(); x.stroke(); x.fillStyle = 'rgba(255,255,255,.8)'; x.beginPath(); x.arc(bx - r * .35, by - r * .35, r * .18, 0, 7); x.fill(); } }
      else { const cs = ['#ff5a5a', '#ffd24a', '#5fe37a', '#4f9aff']; for (let i = 0; i < 4; i++) { x.fillStyle = cs[i]; x.beginPath(); x.arc(w / 2 + (i % 2 ? 62 : -62), h / 2 + (i > 1 ? 52 : -44), 46, 0, 7); x.fill(); } }
      x.globalAlpha = 1;
    });
  }
  async function job(kind, it) {
    switch (kind) {
      case 'food': return capture(bgTex(0x3a2468, 0x7a3c8c, 0xffb46e), cam => { const m = foodMesh(it.id); m.name = 'tmpfood'; scene.add(m); cam.position.set(.55, .68, 1.4); cam.lookAt(0, .24, 0); }, { hidePlayer: true, after: () => { const m = scene.getObjectByName('tmpfood'); if (m) scene.remove(m); } });
      case 'chars': await player.ensure(it.model);
        return withPlayer(() => { player.useNow(it.model); player.setHat('nada'); player.setSkin(SKINS[0].p); posePlayer(); return capture(bgTex(0x2d2a66, 0x7a3a8c, 0xffb46e), petCam); });
      case 'skins': await player.ensure('gamba');
        return withPlayer(() => { player.useNow('gamba'); player.setHat('nada'); player.setSkin(it.p); posePlayer(); return capture(bgTex(0x0f3b5e, 0x1b8a9a, 0x8affe6), petCam); });
      case 'hats': if (it.id === 'nada') return flat((x, w, h) => { x.fillStyle = '#2a2244'; x.fillRect(0, 0, w, h); x.strokeStyle = 'rgba(255,255,255,.75)'; x.lineWidth = 12; x.beginPath(); x.arc(w / 2, h / 2, 54, 0, 7); x.moveTo(w / 2 - 38, h / 2 + 38); x.lineTo(w / 2 + 38, h / 2 - 38); x.stroke(); });
        await player.ensure('gamba');
        return withPlayer(() => {
          player.useNow('gamba'); player.setSkin(SKINS[0].p); player.setHat(it.id); posePlayer();
          const b = new THREE.Box3().setFromObject(player.hat), c = b.getCenter(new THREE.Vector3()), s = Math.max(...b.getSize(new THREE.Vector3()).toArray());
          return capture(bgTex(0x36205e, 0x9a3f8f, 0xffa8d8), cam => { cam.position.copy(c).add(new THREE.Vector3(.85, .42, -1).normalize().multiplyScalar(s * 3.3 + .3)); cam.lookAt(c.x, c.y - s * .22, c.z); });
        });
      case 'themes': return themeThumb(it);
      case 'game': return gameThumb(it);
    }
    return null;
  }
  const keyOf = (kind, it) => kind + ':' + it.id;
  function thumb(kind, it) {
    const k = keyOf(kind, it);
    if (cache[k]) return Promise.resolve(cache[k]);
    return (queue = queue.then(async () => {
      if (cache[k]) return cache[k];
      try { return (cache[k] = await job(kind, it)); } catch (e) { console.warn('miniatura', k, e); return null; }
    }));
  }

  /* ---------- tienda ---------- */
  let tab = 'food', selId = null, preview = {}, shift = null, isOpen = false;
  const SHOWN = ['chars', 'skins', 'hats', 'themes'];
  function open(t = 'food') {
    if (isOpen) return; isOpen = true; ctx.setMode('shop'); tab = t; preview = {}; shift = null;
    for (const s of ['#hud', '#nav', '#tray', '#hint']) $(s).hidden = true;
    $('#shop').hidden = false; setMin(false, true); house.setRoom('salon'); renderTabs(); pick(t);
    if (!save.hatched) return;
  }
  function close() {
    if (!isOpen) return; isOpen = false; $('#shop').hidden = true;
    if (cam.view && cam.view.enabled) cam.clearViewOffset();
    persist(); leave();
  }
  $('#shopClose').onclick = () => { S.click(); close(); };
  function setMin(v, quiet) { $('#sheet').classList.toggle('min', v); $('#grabTxt').textContent = v ? 'Ver tienda' : 'Ver a ' + (save.name || 'Gambi'); if (!quiet) buzz(); }
  let grabY = null;
  $('#grab').addEventListener('pointerdown', e => { grabY = e.clientY; });
  $('#grab').addEventListener('pointerup', e => { if (grabY === null) return; const dy = e.clientY - grabY; grabY = null; setMin(dy > 20 ? true : dy < -20 ? false : !$('#sheet').classList.contains('min')); });
  function renderTabs() {
    $('#tabs').innerHTML = TABS.map(t => `<button class="tab ${t.id === tab ? 'on' : ''}" data-t="${t.id}">${t.name}</button>`).join('');
    $('#tabs').querySelectorAll('.tab').forEach(b => b.onclick = () => { pick(b.dataset.t); buzz(); });
  }
  function pick(t) {
    tab = t; renderTabs();
    const T0 = TABS.find(x => x.id === t);
    selId = SHOWN.includes(t) ? preview[t] || save.eq[t] : T0.list[0].id;
    $('#grid').scrollTop = 0; renderGrid();
    const on = $('#tabs .tab.on'); on && on.scrollIntoView({ inline: 'center', behavior: 'smooth', block: 'nearest' });
  }
  const kindOf = t => ({ food: 'food', chars: 'chars', skins: 'skins', hats: 'hats', themes: 'themes' }[t]);
  function renderGrid() {
    const T0 = TABS.find(x => x.id === tab), grid = $('#grid'), st = grid.scrollTop, kind = kindOf(tab);
    $('#sCoins').textContent = save.coins.toLocaleString('es');
    grid.innerHTML = T0.list.map(it => {
      const url = cache[keyOf(kind, it)];
      const ic = `<span class="th ${url ? '' : 'ph'}" data-th="${kind}:${it.id}" ${url ? `style="background-image:url(${url})"` : ''}></span>`;
      let pr;
      if (tab === 'food') pr = it.free ? `<span class="pr own">Gratis</span>` : `<span class="pr"><span class="coin"></span>${it.price}</span>`;
      else if (save.eq[tab] === it.id) pr = `<span class="pr eq">EN USO</span>`;
      else if (owns(tab, it.id)) pr = `<span class="pr own">Tuyo</span>`;
      else pr = `<span class="pr"><span class="coin"></span>${it.price.toLocaleString('es')}</span>`;
      const cnt = tab === 'food' && save.inv[it.id] ? `<span class="cnt">×${save.inv[it.id]}</span>` : '';
      const lock = SHOWN.includes(tab) && !owns(tab, it.id) ? 'lock' : '';
      return `<button class="it ${it.id === selId ? 'sel' : ''} ${lock}" data-id="${it.id}">${cnt}${ic}<span class="nm">${it.name}</span>${pr}</button>`;
    }).join('');
    grid.scrollTop = st;
    grid.querySelectorAll('.it').forEach(b => b.onclick = () => { selId = b.dataset.id; buzz(); tryOn(); renderGrid(); });
    const myTab = tab;
    for (const it of T0.list) if (!cache[keyOf(kind, it)]) thumb(kind, it).then(url => {
      const el = url && tab === myTab && $(`#grid [data-th="${kind}:${it.id}"]`);
      if (el) { el.style.backgroundImage = `url(${url})`; el.classList.remove('ph'); }
    });
    renderDetail();
  }
  function tryOn() {
    if (SHOWN.includes(tab)) { preview[tab] = selId; applyLook(Object.assign({}, save.eq, preview)); }
  }
  function renderDetail() {
    const T0 = TABS.find(x => x.id === tab), it = T0.list.find(x => x.id === selId) || T0.list[0], btn = $('#dBtn');
    btn.disabled = false; let label = '', act = null;
    const coin = n => `<span class="coin"></span>${n.toLocaleString('es')}`;
    if (tab === 'food') {
      if (it.free) { label = 'Gratis'; btn.disabled = true; }
      else { label = `Comprar ${coin(it.price)}`; act = () => buy(it.price, () => { save.inv[it.id] = (save.inv[it.id] || 0) + 1; }); }
    } else if (save.eq[tab] === it.id) { label = 'En uso'; btn.disabled = true; }
    else if (owns(tab, it.id)) { label = 'Usar'; act = () => { save.eq[tab] = it.id; persist(); S.click(); }; }
    else { label = `Comprar ${coin(it.price)}`; act = () => buy(it.price, () => { save.owned[tab + ':' + it.id] = true; save.eq[tab] = it.id; }); }
    const extra = tab === 'food' ? [it.food && `Comida +${it.food}`, it.fun && `Diversión +${it.fun}`, it.energy && `Energía +${it.energy}`, it.hyg && `Limpieza +${it.hyg}`].filter(Boolean).join(' · ') : '';
    $('#dName').textContent = it.name; $('#dDesc').textContent = [it.desc, extra].filter(Boolean).join(' — ');
    btn.innerHTML = label; btn.onclick = act ? () => { act(); renderGrid(); } : null;
  }
  function buy(cost, fn) {
    if (save.coins < cost) { toast(`Te faltan ${(cost - save.coins).toLocaleString('es')} monedas`); buzz('HEAVY'); S.err(); return; }
    save.coins -= cost; fn(); persist(); S.buy(); buzz('MEDIUM'); toast('¡Comprado!'); updHud();
    for (let i = 0; i < 30; i++) PA.emit(Math.random() * 1.2 - .6, .4 + Math.random() * .8, pet.z + .3, Math.random() * 4 - 2, 1 + Math.random() * 3, Math.random() * 2 - 1, new THREE.Color().setHSL(Math.random(), .9, .6), .16, .8, 5);
  }
  // encuadra a Gambi en el hueco libre entre la cabecera y el panel
  function camera(dt, goal) {
    const W = innerWidth, H = innerHeight, sheet = $('#sheet'), head = $('#shop .shopHead');
    const hb = head ? head.getBoundingClientRect().bottom + 6 : 80, top = H - (sheet ? sheet.offsetHeight : H * .5);
    const bh = Math.max(110, top - hb), target = H / 2 - (hb + top) / 2;
    shift = shift === null ? target : lerp(shift, target, Math.min(1, dt * 7));
    const tanV = Math.tan(THREE.MathUtils.degToRad(cam.fov) / 2), tanH = tanV * W / H;
    const d = clamp(Math.max(2.5 / (2 * tanH), 1.45 / (2 * tanV * bh / H)), 2.4, 8);
    goal.pos.set(0, .4 + d * .2, pet.z + d * .98); goal.look.set(0, .4, pet.z); goal.k = 5;
    cam.setViewOffset(W, H, 0, shift, W, H);
  }
  return { open, close, camera, thumb, get isOpen() { return isOpen; } };
}
