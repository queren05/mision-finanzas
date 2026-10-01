// Minijuegos de Gambi: lluvia de comida, pompas y Simón marino. Usan la misma escena 3D con otra cámara.
export function createMini(ctx) {
  const { THREE, scene, cam, player, pet, PN, PA, FL, S, buzz, foodMesh, FOODS, save, rnd, clamp, camTo } = ctx;
  const $ = s => document.querySelector(s);
  const V = (x, y, z) => new THREE.Vector3(x, y, z);
  const col = h => new THREE.Color(h);
  const ray = new THREE.Raycaster(), _v = new THREE.Vector3(), _p = new THREE.Plane();
  let G = null, T = 0, objs = [], msgT = 0, ph = 0, yaw = 0, px = 0, pz = .3, ptX = 0, aborted = false;

  const toScreen = p => { cam.updateMatrixWorld(); _v.copy(p).project(cam); return { x: (_v.x * .5 + .5) * innerWidth, y: (-_v.y * .5 + .5) * innerHeight }; };
  // punto del mundo bajo el dedo, sobre el plano z = zz
  function worldAt(cx, cy, zz) {
    cam.updateMatrixWorld(); ray.setFromCamera({ x: cx / innerWidth * 2 - 1, y: -(cy / innerHeight) * 2 + 1 }, cam);
    _p.set(V(0, 0, 1), -zz); const out = V(); return ray.ray.intersectPlane(_p, out) ? out : null;
  }
  const add = o => { scene.add(o); objs.push(o); return o; };
  const drop = o => { scene.remove(o); objs = objs.filter(x => x !== o); };
  function msg(t) { const m = $('#miniMsg'); m.textContent = t; m.hidden = false; m.style.animation = 'none'; void m.offsetWidth; m.style.animation = ''; clearTimeout(msgT); msgT = setTimeout(() => { m.hidden = true; }, 1000); }
  const hud = (score, info) => { $('#mScore').textContent = score; $('#mInfo').textContent = info; };
  function petPose(dt, moving, hop = 0) {
    const sc = ctx.stage(); ph += dt * (moving ? 12 : 3);
    player.root.visible = true; player.root.position.set(px, hop, pz); player.root.rotation.y = yaw; player.root.scale.setScalar(sc);
    player.tilt.position.set(0, moving ? Math.abs(Math.sin(ph)) * .03 : 0, 0); player.tilt.rotation.set(0, 0, 0); player.tilt.scale.set(1, 1, 1);
    player.pose(ph, moving ? 'run' : 'idle', T, dt, 6);
  }
  function finish(r) { if (!G || G.over) return; G.over = true; setTimeout(() => { if (!aborted) ctx.end(r); }, 700); }

  /* ============ 1. LLUVIA DE COMIDA ============ */
  function urchin() {
    const g = new THREE.Group(), m = new THREE.MeshStandardMaterial({ color: 0x2b2f52, roughness: .5 });
    g.add(new THREE.Mesh(new THREE.SphereGeometry(.17, 14, 10), m));
    for (let i = 0; i < 16; i++) { const c = new THREE.Mesh(new THREE.ConeGeometry(.035, .22, 6), new THREE.MeshStandardMaterial({ color: 0x55609a })); const d = _v.set(Math.random() - .5, Math.random() - .5, Math.random() - .5).normalize(); c.position.copy(d).multiplyScalar(.22); c.quaternion.setFromUnitVectors(V(0, 1, 0), d); g.add(c); }
    const e = new THREE.MeshBasicMaterial({ color: 0xff4d6d }); [-.06, .06].forEach(x => { const s = new THREE.Mesh(new THREE.SphereGeometry(.03, 8, 6), e); s.position.set(x, .03, .16); g.add(s); });
    return g;
  }
  function startCatch() {
    G = { id: 'catch', score: 0, lives: 3, time: 45, spawn: .5, items: [], combo: 0, t: 0, over: false, best: 0 };
    px = 0; pz = .3; ptX = 0; yaw = -Math.PI / 2;
    camTo(V(0, 2.4, 5.6), V(0, 2.1, 0), 9);
    hud(0, '♥♥♥ 45 s'); msg('¡Atrapa la comida!');
  }
  function updateCatch(dt) {
    const g = G; g.t += dt;
    if (!g.over) {
      g.time -= dt; g.spawn -= dt;
      if (g.spawn <= 0) {
        g.spawn = Math.max(.3, .7 - g.t * .008);
        const r = Math.random(), bad = r < .2 + Math.min(.14, g.t * .003), gold = !bad && r > .93;
        let mesh, val = 1, kind = 'good';
        if (bad) { mesh = urchin(); kind = 'bad'; }
        else if (gold) { mesh = new THREE.Mesh(new THREE.CylinderGeometry(.22, .22, .06, 24), new THREE.MeshStandardMaterial({ color: 0xffc21d, emissive: 0xffa800, emissiveIntensity: .6, roughness: .3 })); mesh.rotation.x = Math.PI / 2; val = 6; kind = 'gold'; }
        else { const f = FOODS[Math.floor(rnd(0, FOODS.length))]; mesh = foodMesh(f.id); mesh.scale.setScalar(.85); val = 1 + (f.food > 35 ? 1 : 0); }
        const holder = new THREE.Group(); holder.add(mesh); holder.position.set(rnd(-1.6, 1.6), 5.4, .3 + rnd(-.1, .1)); add(holder);
        g.items.push({ m: holder, vy: -(2.6 + Math.min(3, g.t * .05) + rnd(0, 1.3)), kind, val, spin: rnd(-3, 3) });
      }
      for (const it of g.items) {
        it.m.position.y += it.vy * dt; it.m.rotation.y += it.spin * dt; if (it.kind === 'gold') it.m.children[0].rotation.z += dt * 5;
        const dx = Math.abs(it.m.position.x - px), y = it.m.position.y;
        if (y < .85 && y > 0 && dx < .42 + ctx.stage() * .3) {
          it.dead = true;
          if (it.kind === 'bad') { g.lives--; g.combo = 0; S.bad(); buzz('HEAVY'); PA.burst(px, .6, pz, 18, col(0xff4d6d), 2.4, .16, .6); FL.add('¡Ay!', px, 1.4, pz + .3, { color: '#ff8a9a', size: .7, font: '700 54px Fredoka, sans-serif' }); }
          else { g.combo++; const bonus = g.combo % 6 === 0 ? 3 : 0; g.score += it.val + bonus; S.good(); buzz('LIGHT'); PA.burst(it.m.position.x, y, .3, 10, col(it.kind === 'gold' ? 0xffd84a : 0xfff2a0), 1.8, .12, .5); FL.add(`+${it.val + bonus}`, px, 1.3, pz + .3, { color: it.kind === 'gold' ? '#ffe14d' : '#ffffff', size: .5, life: .9 }); if (bonus) msg('¡Combo!'); }
        } else if (y < -.3) { it.dead = true; if (it.kind !== 'bad') g.combo = 0; }
      }
      g.items = g.items.filter(it => { if (it.dead) drop(it.m); return !it.dead; });
      if (g.lives <= 0) finish({ id: 'catch', score: g.score, coins: Math.round(g.score * 1.4), xp: 6 + Math.round(g.score * .6), fun: Math.min(45, 8 + g.score * .8), title: '¡Ay, los erizos!' });
      else if (g.time <= 0) finish({ id: 'catch', score: g.score, coins: Math.round(g.score * 1.4), xp: 8 + Math.round(g.score * .6), fun: Math.min(45, 10 + g.score * .8), title: '¡Tiempo!' });
      hud(g.score, '♥'.repeat(Math.max(0, g.lives)) + ' ' + Math.max(0, Math.ceil(g.time)) + ' s');
    }
    const nx = clamp(ptX, -1.6, 1.6), d = nx - px, mv = Math.abs(d) > .05;
    px += d * Math.min(1, dt * 9); if (mv) yaw += ((d > 0 ? -Math.PI / 2 : Math.PI / 2) - yaw) * Math.min(1, dt * 12);
    petPose(dt, mv);
  }

  /* ============ 2. POMPAS ============ */
  function startBubbles() {
    G = { id: 'bubbles', score: 0, time: 40, spawn: .3, bubbles: [], combo: 0, t: 0, over: false };
    px = 0; pz = .3; yaw = 2.5;
    camTo(V(0, 2.2, 5.4), V(0, 2.2, 0), 9);
    hud(0, '40 s'); msg('¡Explota las pompas!');
  }
  function makeBubble(kind, r) {
    const c = kind === 'gold' ? 0xffd84a : kind === 'bad' ? 0x2b2f52 : new THREE.Color().setHSL(rnd(.45, .98), .95, .58).getHex();
    const g = new THREE.Group();
    g.add(new THREE.Mesh(new THREE.SphereGeometry(r, 24, 18), new THREE.MeshStandardMaterial({ color: c, transparent: true, opacity: kind === 'bad' ? .9 : .68, roughness: .08, emissive: c, emissiveIntensity: kind === 'gold' ? .8 : .5 })));
    const hl = new THREE.Mesh(new THREE.SphereGeometry(r * .22, 10, 8), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: .85 })); hl.position.set(-r * .4, r * .42, r * .7); g.add(hl);
    if (kind === 'bad') for (let i = 0; i < 12; i++) { const s = new THREE.Mesh(new THREE.ConeGeometry(r * .13, r * .5, 6), new THREE.MeshStandardMaterial({ color: 0x7a84c4 })); const d = _v.set(Math.random() - .5, Math.random() - .5, Math.random() * .5).normalize(); s.position.copy(d).multiplyScalar(r * 1.05); s.quaternion.setFromUnitVectors(V(0, 1, 0), d); g.add(s); }
    return { g, c };
  }
  function updateBubbles(dt) {
    const g = G; g.t += dt;
    if (!g.over) {
      g.time -= dt; g.spawn -= dt;
      if (g.spawn <= 0) {
        g.spawn = Math.max(.22, .5 - g.t * .005);
        const q = Math.random(), kind = q < .09 ? 'bad' : q > .93 ? 'gold' : 'good', r = kind === 'gold' ? .3 : rnd(.2, .46);
        const b = makeBubble(kind, r); b.g.position.set(rnd(-1.5, 1.5), -1.6, rnd(-.2, .4)); add(b.g);
        g.bubbles.push({ m: b.g, r, kind, c: b.c, vy: rnd(1.1, 2.1) + g.t * .01, ph: rnd(0, 6), ax: rnd(.2, .6), x0: b.g.position.x });
      }
      for (const b of g.bubbles) {
        b.m.position.y += b.vy * dt; b.ph += dt * 2; b.m.position.x = b.x0 + Math.sin(b.ph) * b.ax; b.m.scale.setScalar(1 + Math.sin(b.ph * 2) * .04);
        if (b.m.position.y > 6.6) { b.dead = true; if (b.kind === 'good') g.combo = 0; }
      }
      g.bubbles = g.bubbles.filter(b => { if (b.dead) drop(b.m); return !b.dead; });
      if (g.time <= 0) finish({ id: 'bubbles', score: g.score, coins: Math.round(g.score * .9), xp: 8 + Math.round(g.score * .4), fun: Math.min(45, 10 + g.score * .5), title: '¡Tiempo!' });
      hud(g.score, Math.max(0, Math.ceil(g.time)) + ' s');
    }
    petPose(dt, false, Math.max(0, Math.sin(T * 6)) * (g.combo > 3 ? .12 : 0));
  }
  function tapBubble(x, y) {
    const g = G; if (!g || g.over) return;
    let best = null, bd = 1e9;
    for (const b of g.bubbles) {
      const c = toScreen(b.m.position), e = toScreen(_v.copy(b.m.position).add(V(b.r, 0, 0))), rad = Math.hypot(e.x - c.x, e.y - c.y) + 26, d = Math.hypot(x - c.x, y - c.y);
      if (d < rad && d < bd) { bd = d; best = b; }
    }
    if (!best) { g.combo = 0; return; }
    best.dead = true; const p = best.m.position;
    PA.burst(p.x, p.y, p.z, 14, col(best.c), 2.2, .14, .55); PN.burst(p.x, p.y, p.z, 6, col(0xffffff), 1.6, .1, .4, 2);
    if (best.kind === 'bad') { g.score = Math.max(0, g.score - 5); g.combo = 0; S.bad(); buzz('HEAVY'); FL.add('-5', p.x, p.y, p.z + .3, { color: '#ff8a9a', size: .6 }); }
    else if (best.kind === 'gold') { g.score += 8; g.time += 2; S.coin(); buzz('MEDIUM'); FL.add('+8', p.x, p.y, p.z + .3, { color: '#ffe14d', size: .6 }); msg('¡+2 s!'); g.combo++; }
    else { const base = best.r < .3 ? 3 : best.r < .38 ? 2 : 1, mult = 1 + Math.floor(g.combo / 6); g.score += base * mult; g.combo++; S.pop(); buzz('LIGHT'); FL.add(`+${base * mult}`, p.x, p.y, p.z + .3, { color: '#ffffff', size: .45, life: .8 }); if (g.combo % 6 === 0) msg(`Combo ×${1 + g.combo / 6}`); }
    g.bubbles = g.bubbles.filter(b => { if (b.dead) drop(b.m); return !b.dead; });
  }

  /* ============ 3. SIMÓN MARINO ============ */
  const PADC = [0xff5a5a, 0xffd24a, 0x5fe37a, 0x4f9aff], PADP = [[-.95, -.3], [.95, -.3], [-.95, 1.3], [.95, 1.3]];
  function startSimon() {
    G = { id: 'simon', score: 0, seq: [], phase: 'wait', idx: 0, timer: .8, pads: [], over: false, t: 0, idle: 0, lit: -1, litT: 0 };
    for (let i = 0; i < 4; i++) {
      const m = new THREE.MeshStandardMaterial({ color: PADC[i], emissive: PADC[i], emissiveIntensity: .12, roughness: .4 });
      const pad = new THREE.Mesh(new THREE.CylinderGeometry(.62, .68, .16, 32), m); pad.position.set(PADP[i][0], .08, PADP[i][1]); add(pad);
      const ring = new THREE.Mesh(new THREE.TorusGeometry(.6, .035, 8, 32), new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: .3 })); ring.rotation.x = Math.PI / 2; ring.position.set(PADP[i][0], .17, PADP[i][1]); add(ring);
      G.pads.push({ m: pad, mat: m });
    }
    px = 0; pz = .5; yaw = 2.5;
    camTo(V(0, 4.3, 4.6), V(0, 0, .5), 9);
    G.seq.push(Math.floor(Math.random() * 4));
    hud('Ronda 1', 'Mira…');
  }
  function light(i, d = .45) { const p = G.pads[i]; G.lit = i; G.litT = d; p.mat.emissiveIntensity = 1.1; S.pad(i); buzz('LIGHT'); PA.burst(PADP[i][0], .3, PADP[i][1], 8, col(PADC[i]), 1.4, .12, .5); }
  function updateSimon(dt) {
    const g = G; g.t += dt;
    if (g.litT > 0) { g.litT -= dt; if (g.litT <= 0) { g.pads[g.lit].mat.emissiveIntensity = .12; g.lit = -1; } }
    if (!g.over) {
      if (g.phase === 'wait') { g.timer -= dt; if (g.timer <= 0) { g.phase = 'show'; g.idx = 0; g.timer = .3; hud('Ronda ' + g.seq.length, 'Mira…'); } }
      else if (g.phase === 'show') {
        g.timer -= dt;
        if (g.timer <= 0) { if (g.idx < g.seq.length) { light(g.seq[g.idx]); g.idx++; g.timer = Math.max(.35, .75 - g.seq.length * .03); } else { g.phase = 'input'; g.idx = 0; g.idle = 0; hud('Ronda ' + g.seq.length, '¡Tu turno!'); } }
      } else if (g.phase === 'input') { g.idle += dt; if (g.idle > 9) simonFail(); }
    }
    // Gambi salta al pad que se ilumina
    const tp = g.lit >= 0 ? PADP[g.lit] : [0, .5], d = Math.hypot(tp[0] - px, tp[1] - pz);
    px += (tp[0] - px) * Math.min(1, dt * 7); pz += (tp[1] - pz) * Math.min(1, dt * 7);
    if (d > .05) yaw += (Math.atan2(-(tp[0] - px), -(tp[1] - pz)) - yaw) * Math.min(1, dt * 10);
    petPose(dt, d > .12, g.lit >= 0 ? Math.abs(Math.sin(T * 10)) * .1 : 0);
  }
  function simonFail() {
    const g = G; if (g.over) return; S.bad(); buzz('HEAVY'); const sc = g.seq.length - 1;
    finish({ id: 'simon', score: sc, coins: sc * 6, xp: 6 + sc * 3, fun: Math.min(45, 8 + sc * 3), title: sc > 0 ? '¡Qué memoria!' : '¡Casi!' });
  }
  function tapSimon(x, y) {
    const g = G; if (!g || g.over || g.phase !== 'input') return;
    let best = -1, bd = 1e9;
    g.pads.forEach((p, i) => { const s = toScreen(p.m.position), d = Math.hypot(x - s.x, y - s.y); if (d < bd) { bd = d; best = i; } });
    if (best < 0 || bd > 130) return;
    light(best, .3); g.idle = 0;
    if (g.seq[g.idx] !== best) { simonFail(); return; }
    g.idx++;
    if (g.idx >= g.seq.length) { g.phase = 'wait'; g.timer = .9; g.score = g.seq.length; g.seq.push(Math.floor(Math.random() * 4)); S.levelup(); msg(`¡Ronda ${g.seq.length - 1}!`); PA.burst(0, 1, .5, 20, col(0xffe27a), 2.4, .16, .8, 3); hud('Ronda ' + g.seq.length, '¡Bien!'); }
  }


  /* ============ 4. NADO (tipo Flappy) ============ */
  function coral(h, c) {
    const g = new THREE.Group(), m = new THREE.MeshStandardMaterial({ color: c, roughness: .6, flatShading: true });
    const n = Math.max(1, Math.round(h / .45));
    for (let i = 0; i < n; i++) { const s2 = new THREE.Mesh(new THREE.IcosahedronGeometry(.36 + Math.random() * .08, 0), m); s2.position.set(rnd(-.05, .05), (i + .5) * h / n, rnd(-.05, .05)); s2.scale.set(1, h / n / .62, 1); g.add(s2); }
    return g;
  }
  function startSwim() {
    G = { id: 'swim', score: 0, pipes: [], spawn: 0, vy: 0, y: 2.1, over: false, t: 0, started: false, speed: 2.1 };
    px = -1.1; pz = 0; yaw = -Math.PI / 2;
    camTo(V(0, 2.2, 6.6), V(0, 2.2, 0), 9); ctx.setHouse(false);
    const sand = new THREE.Mesh(new THREE.BoxGeometry(14, .3, 3), new THREE.MeshStandardMaterial({ color: 0xf2d99a, roughness: 1 })); sand.position.set(0, -.15, 0); add(sand);
    const c2 = document.createElement('canvas'); c2.width = 4; c2.height = 256; const x2 = c2.getContext('2d'), gr = x2.createLinearGradient(0, 0, 0, 256); gr.addColorStop(0, '#6fe0ff'); gr.addColorStop(1, '#0b4f96'); x2.fillStyle = gr; x2.fillRect(0, 0, 4, 256); const tx = new THREE.CanvasTexture(c2); tx.colorSpace = THREE.SRGBColorSpace;
    const bg = new THREE.Mesh(new THREE.PlaneGeometry(30, 14), new THREE.MeshBasicMaterial({ map: tx })); bg.position.set(0, 3, -3); add(bg);
    hud(0, 'Toca para nadar'); msg('¡Toca para nadar!');
  }
  function updateSwim(dt) {
    const g = G; g.t += dt;
    if (g.started && !g.over) {
      g.vy -= 10.5 * dt; g.y += g.vy * dt; g.speed = Math.min(3.4, 2.1 + g.t * .025);
      g.spawn -= dt;
      if (g.spawn <= 0) {
        g.spawn = 2.05 / (g.speed / 2.1);
        const gap = Math.max(1.55, 2.1 - g.t * .008), c = rnd(1.05 + gap / 2, 4.1 - gap / 2), col = [0xff7a8a, 0xffa84a, 0xb45aff, 0x4fe3a0][Math.floor(rnd(0, 4))];
        const lo = coral(c - gap / 2, col), hi = coral(5.5 - (c + gap / 2), col); hi.position.y = c + gap / 2;
        const grp = new THREE.Group(); grp.add(lo, hi); grp.position.x = 3.2; add(grp);
        g.pipes.push({ m: grp, c, gap, passed: false });
      }
      for (const p2 of g.pipes) {
        p2.m.position.x -= g.speed * dt;
        const dx = Math.abs(p2.m.position.x - px);
        if (dx < .36 + .3 * ctx.stage() && (g.y < p2.c - p2.gap / 2 + .12 || g.y + .32 > p2.c + p2.gap / 2)) swimDie();
        if (!p2.passed && p2.m.position.x < px) { p2.passed = true; g.score++; S.good(); buzz('LIGHT'); }
        if (p2.m.position.x < -4) { drop(p2.m); p2.dead = true; }
      }
      g.pipes = g.pipes.filter(p2 => !p2.dead);
      if (g.y < .05 || g.y > 4.6) swimDie();
      if (Math.random() < .3) PN.emit(px - .4, g.y + .2, pz, -1, rnd(.2, .6), 0, col(0xd6f4ff), .08, .6, -1);
      hud(g.score, 'Nado');
    } else if (!g.started) g.y = 2.1 + Math.sin(g.t * 3) * .12;
    else g.y = Math.max(.05, g.y - dt * 2);
    petPose(dt, true, g.y);
    player.tilt.rotation.x = clamp(g.vy * .07, -.6, .5);
  }
  function swimDie() {
    const g = G; if (g.over) return; S.bad(); buzz('HEAVY'); PA.burst(px, g.y + .2, pz, 20, col(0xffffff), 2, .12, .6);
    finish({ id: 'swim', score: g.score, coins: g.score * 4, xp: 6 + g.score * 2, fun: Math.min(45, 10 + g.score * 2), title: g.score > 9 ? '¡Qué buceadora!' : '¡Choque!' });
  }
  function tapSwim() { const g = G; if (!g || g.over) return; g.started = true; g.vy = 4.3; S.pop(); }

  /* ============ 5. PAREJAS ============ */
  const SYM = [['#ff5a7a', 'heart'], ['#5fd6ff', 'drop'], ['#ffd84a', 'star'], ['#7cf0b0', 'leaf'], ['#b45aff', 'moon'], ['#ff9a3a', 'fish']];
  function symTex(i) {
    const [c, kind] = SYM[i];
    return ctxTex(c, kind);
  }
  function ctxTex(c, kind) {
    const cv2 = document.createElement('canvas'); cv2.width = 160; cv2.height = 208; const x = cv2.getContext('2d');
    x.fillStyle = '#fff6e8'; x.fillRect(0, 0, 160, 208); x.strokeStyle = c; x.lineWidth = 8; x.strokeRect(8, 8, 144, 192);
    x.fillStyle = c; x.translate(80, 104);
    if (kind === 'heart') { x.beginPath(); x.moveTo(0, 36); x.bezierCurveTo(-60, -4, -30, -50, 0, -18); x.bezierCurveTo(30, -50, 60, -4, 0, 36); x.fill(); }
    else if (kind === 'drop') { x.beginPath(); x.moveTo(0, -46); x.bezierCurveTo(30, -6, 36, 18, 0, 38); x.bezierCurveTo(-36, 18, -30, -6, 0, -46); x.fill(); }
    else if (kind === 'star') { x.beginPath(); for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2 - Math.PI / 2, r = i % 2 ? 20 : 46; x.lineTo(Math.cos(a) * r, Math.sin(a) * r); } x.fill(); }
    else if (kind === 'leaf') { x.beginPath(); x.ellipse(0, 0, 24, 44, .5, 0, 7); x.fill(); }
    else if (kind === 'moon') { x.beginPath(); x.arc(0, 0, 40, 0, 7); x.fill(); x.globalCompositeOperation = 'destination-out'; x.beginPath(); x.arc(18, -10, 34, 0, 7); x.fill(); }
    else { x.beginPath(); x.ellipse(-6, 0, 34, 20, 0, 0, 7); x.fill(); x.beginPath(); x.moveTo(24, 0); x.lineTo(46, -20); x.lineTo(46, 20); x.fill(); x.fillStyle = '#fff'; x.beginPath(); x.arc(-22, -4, 5, 0, 7); x.fill(); }
    const t = new THREE.CanvasTexture(cv2); t.colorSpace = THREE.SRGBColorSpace; return t;
  }
  let backTex = null;
  function startMemory() {
    G = { id: 'memory', score: 0, cards: [], open: [], found: 0, moves: 0, time: 75, over: false, t: 0, lock: 0 };
    px = 0; pz = -2.05; yaw = Math.PI * .95;
    camTo(V(0, 6.6, 3.6), V(0, 0, .45), 9);
    if (!backTex) { const c2 = document.createElement('canvas'); c2.width = 160; c2.height = 208; const x = c2.getContext('2d'); const gr = x.createLinearGradient(0, 0, 160, 208); gr.addColorStop(0, '#6a2fb8'); gr.addColorStop(1, '#ff6fa5'); x.fillStyle = gr; x.fillRect(0, 0, 160, 208); x.fillStyle = 'rgba(255,255,255,.25)'; for (let i = 0; i < 30; i++) { x.beginPath(); x.arc((i * 37) % 160, (i * 53) % 208, 8, 0, 7); x.fill(); } x.strokeStyle = '#fff'; x.lineWidth = 8; x.strokeRect(8, 8, 144, 192); backTex = new THREE.CanvasTexture(c2); backTex.colorSpace = THREE.SRGBColorSpace; }
    const ids = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5].sort(() => Math.random() - .5), side = new THREE.MeshStandardMaterial({ color: 0xffffff }), backM = new THREE.MeshStandardMaterial({ map: backTex, roughness: .5 });
    ids.forEach((id, i) => {
      const face = new THREE.MeshStandardMaterial({ map: symTex(id), roughness: .5 });
      const m = new THREE.Mesh(new THREE.BoxGeometry(.82, .05, 1.07), [side, side, backM, face, side, side]);
      const g2 = new THREE.Group(); g2.add(m); g2.position.set(-1.5 + (i % 4) * 1.0, .05, -.95 + Math.floor(i / 4) * 1.25); add(g2);
      G.cards.push({ g: g2, id, up: false, rot: 0, done: false });
    });
    hud('0 parejas', '75 s'); msg('¡Encuentra las parejas!');
  }
  function updateMemory(dt) {
    const g = G; g.t += dt;
    for (const c of g.cards) { const want = c.up || c.done ? Math.PI : 0; c.rot += (want - c.rot) * Math.min(1, dt * 12); c.g.rotation.z = c.rot; c.g.position.y = .05 + Math.sin(c.rot) * .35; }
    if (!g.over) {
      g.time -= dt;
      if (g.lock > 0) { g.lock -= dt; if (g.lock <= 0) { for (const c of g.open) c.up = false; g.open = []; } }
      if (g.time <= 0) memEnd(false);
      hud(`${g.found} pareja${g.found === 1 ? '' : 's'}`, Math.max(0, Math.ceil(g.time)) + ' s');
    }
    petPose(dt, false, g.hop || 0); g.hop = Math.max(0, (g.hop || 0) - dt * 1.5);
  }
  function tapMemory(x, y) {
    const g = G; if (!g || g.over || g.lock > 0) return;
    let best = null, bd = 1e9;
    for (const c of g.cards) { if (c.up || c.done) continue; const sp = toScreen(c.g.position), d = Math.hypot(x - sp.x, y - sp.y); if (d < bd) { bd = d; best = c; } }
    if (!best || bd > 70) return;
    best.up = true; g.open.push(best); S.tap(); buzz('LIGHT');
    if (g.open.length === 2) {
      g.moves++;
      const [a, b] = g.open;
      if (a.id === b.id) { a.done = b.done = true; g.open = []; g.found++; S.good(); g.hop = .5; PA.burst(a.g.position.x, .4, a.g.position.z, 12, col(0xffe27a), 1.6, .12, .6); PA.burst(b.g.position.x, .4, b.g.position.z, 12, col(0xffe27a), 1.6, .12, .6); if (g.found === 6) memEnd(true); }
      else { g.lock = .85; S.no(); }
    }
  }
  function memEnd(win) {
    const g = G; if (g.over) return;
    const sc = g.found * 10 + (win ? Math.ceil(g.time) + Math.max(0, 20 - g.moves) * 2 : 0);
    finish({ id: 'memory', score: sc, coins: Math.round(sc * .7), xp: 6 + Math.round(sc * .3), fun: Math.min(45, 10 + g.found * 5), title: win ? '¡Todas las parejas!' : '¡Se acabó el tiempo!' });
  }

  /* ============ 6. CAZA-CANGREJOS ============ */
  function crabMesh(gold) {
    const g = new THREE.Group(), c = gold ? 0xffc21d : 0xe8402e, m = new THREE.MeshStandardMaterial({ color: c, roughness: .45, emissive: gold ? 0x8a5a00 : 0x000000, emissiveIntensity: .4 });
    const body = new THREE.Mesh(new THREE.SphereGeometry(.3, 18, 12), m); body.scale.set(1.25, .7, 1); g.add(body);
    for (const s2 of [-1, 1]) {
      const cl = new THREE.Mesh(new THREE.SphereGeometry(.13, 12, 10), m); cl.position.set(s2 * .45, .14, .12); cl.scale.set(1, .8, .7); g.add(cl);
      const st = new THREE.Mesh(new THREE.CylinderGeometry(.025, .025, .18, 8), m); st.position.set(s2 * .1, .27, .12); g.add(st);
      const e = new THREE.Mesh(new THREE.SphereGeometry(.065, 12, 10), new THREE.MeshStandardMaterial({ color: 0xffffff })); e.position.set(s2 * .1, .38, .14); g.add(e);
      const pu = new THREE.Mesh(new THREE.SphereGeometry(.032, 8, 6), new THREE.MeshBasicMaterial({ color: 0x111111 })); pu.position.set(s2 * .1, .39, .2); g.add(pu);
      for (let k = 0; k < 3; k++) { const l = new THREE.Mesh(new THREE.CylinderGeometry(.02, .02, .25, 6), m); l.position.set(s2 * (.3 + k * .02), -.1, -.08 + k * .1); l.rotation.z = s2 * 1.1; g.add(l); }
    }
    return g;
  }
  function jellyMesh() {
    const g = new THREE.Group(), m = new THREE.MeshStandardMaterial({ color: 0xff8ad8, transparent: true, opacity: .75, roughness: .2, emissive: 0xff3fb4, emissiveIntensity: .35 });
    const b = new THREE.Mesh(new THREE.SphereGeometry(.3, 18, 12, 0, Math.PI * 2, 0, Math.PI / 2), m); b.position.y = .1; g.add(b);
    for (let k = 0; k < 6; k++) { const a = k / 6 * Math.PI * 2, t2 = new THREE.Mesh(new THREE.CylinderGeometry(.02, .01, .4, 6), m); t2.position.set(Math.cos(a) * .18, -.1, Math.sin(a) * .18); g.add(t2); }
    for (const s2 of [-1, 1]) { const e = new THREE.Mesh(new THREE.SphereGeometry(.035, 8, 6), new THREE.MeshBasicMaterial({ color: 0x2a1f4d })); e.position.set(s2 * .09, .22, .24); g.add(e); }
    return g;
  }
  const HOLES = [[-1.3, -.2], [0, -.2], [1.3, -.2], [-1.3, 1.05], [0, 1.05], [1.3, 1.05]];
  function startCrabs() {
    G = { id: 'crabs', score: 0, time: 40, over: false, t: 0, spawn: .6, moles: [] };
    px = 0; pz = -1.7; yaw = Math.PI * .95;
    camTo(V(0, 4.8, 5.4), V(0, 0, .45), 9);
    const sand = new THREE.Mesh(new THREE.BoxGeometry(5, .2, 3.4), new THREE.MeshStandardMaterial({ color: 0xf2d99a, roughness: 1 })); sand.position.set(0, -.1, .45); add(sand);
    for (const [hx, hz] of HOLES) { const h = new THREE.Mesh(new THREE.CircleGeometry(.42, 28), new THREE.MeshBasicMaterial({ color: 0x5a3a1a })); h.rotation.x = -Math.PI / 2; h.position.set(hx, .01, hz); add(h); const r2 = new THREE.Mesh(new THREE.TorusGeometry(.43, .06, 8, 28), new THREE.MeshStandardMaterial({ color: 0xd9b870 })); r2.rotation.x = Math.PI / 2; r2.position.set(hx, .02, hz); add(r2); }
    hud(0, '40 s'); msg('¡Toca los cangrejos!');
  }
  function updateCrabs(dt) {
    const g = G; g.t += dt;
    if (!g.over) {
      g.time -= dt; g.spawn -= dt;
      if (g.spawn <= 0) {
        g.spawn = Math.max(.32, .8 - g.t * .012);
        const free = HOLES.map((h, i) => i).filter(i => !g.moles.some(m2 => m2.hole === i));
        if (free.length) {
          const hole = free[Math.floor(rnd(0, free.length))], q = Math.random(), kind = q < .18 ? 'jelly' : q > .92 ? 'gold' : 'crab';
          const m2 = kind === 'jelly' ? jellyMesh() : crabMesh(kind === 'gold'); m2.position.set(HOLES[hole][0], -.5, HOLES[hole][1]); add(m2);
          g.moles.push({ m: m2, hole, kind, t: 0, up: Math.max(.6, 1.3 - g.t * .015), hit: false });
        }
      }
      for (const m2 of g.moles) {
        m2.t += dt; const k = m2.hit ? Math.max(0, 1 - (m2.t - m2.hitT) * 5) : m2.t < .15 ? m2.t / .15 : m2.t > m2.up ? Math.max(0, 1 - (m2.t - m2.up) / .15) : 1;
        m2.m.position.y = -.5 + k * .62; m2.m.rotation.y = Math.sin(m2.t * 8) * .15;
        if ((m2.hit && k <= 0) || (!m2.hit && m2.t > m2.up + .16)) { drop(m2.m); m2.dead = true; }
      }
      g.moles = g.moles.filter(m2 => !m2.dead);
      if (g.time <= 0) finish({ id: 'crabs', score: g.score, coins: Math.round(g.score * 1.5), xp: 6 + Math.round(g.score * .6), fun: Math.min(45, 10 + g.score), title: '¡Tiempo!' });
      hud(g.score, Math.max(0, Math.ceil(g.time)) + ' s');
    }
    petPose(dt, false, g.hop || 0); g.hop = Math.max(0, (g.hop || 0) - dt * 1.4);
  }
  function tapCrabs(x, y) {
    const g = G; if (!g || g.over) return;
    let best = null, bd = 1e9;
    for (const m2 of g.moles) { if (m2.hit) continue; const sp = toScreen(_v.set(m2.m.position.x, .15, m2.m.position.z)), d = Math.hypot(x - sp.x, y - sp.y); if (d < bd) { bd = d; best = m2; } }
    if (!best || bd > 85 || best.m.position.y < -.3) return;
    best.hit = true; best.hitT = best.t; const p2 = best.m.position;
    if (best.kind === 'jelly') { g.score = Math.max(0, g.score - 3); S.bad(); buzz('HEAVY'); FL.add('-3', p2.x, .8, p2.z + .3, { color: '#ff8ad8', size: .6 }); }
    else { const v = best.kind === 'gold' ? 5 : 1; g.score += v; g.hop = .4; S.bonk ? S.bonk() : S.good(); SND_hit(); buzz('MEDIUM'); PA.burst(p2.x, .4, p2.z, 12, col(best.kind === 'gold' ? 0xffd84a : 0xffffff), 1.8, .12, .5); FL.add('+' + v, p2.x, .9, p2.z + .3, { color: best.kind === 'gold' ? '#ffe14d' : '#ffffff', size: .55 }); }
  }
  function SND_hit() { ctx.SND && ctx.SND.noiseHit ? ctx.SND.noiseHit(.08, .2, 700) : S.good(); }


  /* ============ 7. CARRETERA (coche por las colinas, tipo Pou) ============ */
  // Física 2D sencilla: dos ruedas unidas por una barra (Verlet), gravedad y un suelo hecho de senos.
  // A la derecha de la pantalla, acelerar; a la izquierda, frenar / marcha atrás. En el aire, acelerar levanta el morro.
  const hgt = x => { if (x < 6) return 0; const k = .55 + Math.min(1.5, (x - 6) / 260); const e = Math.min(1, (x - 6) / 10); return e * k * (1.25 * Math.sin(x * .16) + .7 * Math.sin(x * .37 + 1) + .3 * Math.sin(x * .83 + 2)); };
  const slope = x => (hgt(x + .05) - hgt(x - .05)) / .1;
  const WR = .32, CL = 1.5;
  function terrainChunk(x0, x1) {
    const n = Math.ceil((x1 - x0) / .25), pos = [], col = [], idx = [], grass = new THREE.Color(0x5fbf4a), grass2 = new THREE.Color(0x4aa63a), dirt = new THREE.Color(0xa86d3e), deep = new THREE.Color(0x6b4426);
    for (let i = 0; i <= n; i++) {
      const x = x0 + i * (x1 - x0) / n, y = hgt(x);
      // capas: césped arriba (frente y tapa), tierra hacia abajo
      pos.push(x, y, .9, x, y - .22, .9, x, y - 8, .9, x, y, -.9, x, y - .02, .9);
      const g = i % 2 ? grass : grass2;
      col.push(g.r, g.g, g.b, dirt.r, dirt.g, dirt.b, deep.r, deep.g, deep.b, g.r, g.g, g.b, g.r, g.g, g.b);
      if (i < n) { const a = i * 5, b = a + 5; idx.push(a, b + 1, b, a, a + 1, b + 1, a + 1, b + 2, b + 1, a + 1, a + 2, b + 2, a + 3, b + 3, b + 4, a + 3, b + 4, a + 4); }
    }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3)); g.setIndex(idx); g.computeVertexNormals();
    const m = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: .95, side: THREE.DoubleSide }));
    const grp = new THREE.Group(); grp.add(m);
    // flores y piedras en el borde de atrás
    for (let x = x0 + 1; x < x1; x += rnd(1.2, 3)) { const r = Math.random(); const o = r < .5 ? new THREE.Mesh(new THREE.IcosahedronGeometry(rnd(.12, .25), 0), new THREE.MeshStandardMaterial({ color: 0x9a9488, flatShading: true })) : new THREE.Mesh(new THREE.SphereGeometry(.08, 8, 6), new THREE.MeshStandardMaterial({ color: [0xff5a7a, 0xffd84a, 0xffffff, 0xb45aff][Math.floor(rnd(0, 4))] })); o.position.set(x, hgt(x) + .05, -.55); grp.add(o); }
    return grp;
  }
  function makeCar() {
    const g = new THREE.Group(), red = new THREE.MeshStandardMaterial({ color: 0xff4d4d, roughness: .35 }), dark = new THREE.MeshStandardMaterial({ color: 0x24262e, roughness: .7 }), white = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: .4 });
    const body = new THREE.Mesh(new THREE.BoxGeometry(1.9, .36, .9), red); body.position.y = .42; g.add(body);
    const nose = new THREE.Mesh(new THREE.BoxGeometry(.5, .24, .86), red); nose.position.set(.92, .5, 0); nose.rotation.z = -.35; g.add(nose);
    const seat = new THREE.Mesh(new THREE.BoxGeometry(.14, .42, .7), dark); seat.position.set(-.86, .76, 0); g.add(seat);
    const bar = new THREE.Mesh(new THREE.TorusGeometry(.5, .045, 8, 20, Math.PI), white); bar.position.set(-.25, .6, 0); g.add(bar);
    const lamp = new THREE.Mesh(new THREE.BoxGeometry(.06, .12, .2), new THREE.MeshBasicMaterial({ color: 0xfff3b0 })); lamp.position.set(1.05, .5, .3); g.add(lamp);
    const wheels = [];
    for (const x of [-CL / 2, CL / 2]) for (const z of [.48, -.48]) {
      const w = new THREE.Group(), tyre = new THREE.Mesh(new THREE.CylinderGeometry(WR, WR, .2, 20), dark); tyre.rotation.x = Math.PI / 2; w.add(tyre);
      const hub = new THREE.Mesh(new THREE.CylinderGeometry(WR * .5, WR * .5, .22, 10), new THREE.MeshStandardMaterial({ color: 0xffd84a, roughness: .3 })); hub.rotation.x = Math.PI / 2; w.add(hub);
      const spoke = new THREE.Mesh(new THREE.BoxGeometry(WR * 1.6, .06, .23), white); w.add(spoke);
      w.position.set(x, 0, z); g.add(w); wheels.push(w);
    }
    g.userData.wheels = wheels; return g;
  }
  function startDrive() {
    const P = (x, y) => ({ x, y, px: x, py: y });
    G = { id: 'drive', score: 0, over: false, t: 0, fuel: 100, coins: 0, r: P(0, WR + .02), f: P(CL, WR + .02), gas: 0, chunks: [], chunkX: -20, items: [], nextCoin: 8, nextFuel: 90, stopT: 0, ground: false, best: 0, spin: 0 };
    ctx.setHouse(false);
    const c2 = document.createElement('canvas'); c2.width = 4; c2.height = 256; const x2 = c2.getContext('2d'), gr = x2.createLinearGradient(0, 0, 0, 256); gr.addColorStop(0, '#5fc8ff'); gr.addColorStop(.7, '#cdefff'); gr.addColorStop(1, '#fff6d8'); x2.fillStyle = gr; x2.fillRect(0, 0, 4, 256);
    const tx = new THREE.CanvasTexture(c2); tx.colorSpace = THREE.SRGBColorSpace;
    G.sky = add(new THREE.Mesh(new THREE.PlaneGeometry(80, 40), new THREE.MeshBasicMaterial({ map: tx, depthWrite: false }))); G.sky.position.z = -14;
    G.hills = [];
    for (let i = 0; i < 2; i++) { const h = new THREE.Mesh(new THREE.ConeGeometry(rnd(5, 8), rnd(4, 7), 5), new THREE.MeshBasicMaterial({ color: i ? 0x9fd88a : 0x7fc46a })); add(h); G.hills.push({ m: h, k: .3 + i * .2, off: i * 23 }); }
    G.car = add(makeCar());
    for (let i = 0; i < 3; i++) addChunk();
    $('#pedals').hidden = false;
    hud('0 m', 'Gasolina 100%'); msg('¡A conducir!');
  }
  function addChunk() {
    const g = G, c = terrainChunk(g.chunkX, g.chunkX + 40); add(c); g.chunks.push({ m: c, x1: g.chunkX + 40 }); g.chunkX += 40;
    while (g.nextCoin < g.chunkX) {   // filas de monedas sobre el suelo
      const n = Math.floor(rnd(4, 8)); for (let i = 0; i < n; i++) { const x = g.nextCoin + i * .7, m = new THREE.Mesh(new THREE.CylinderGeometry(.2, .2, .05, 18), new THREE.MeshStandardMaterial({ color: 0xffc21d, emissive: 0x8a5a00, emissiveIntensity: .5, roughness: .3, metalness: .3 })); m.rotation.x = Math.PI / 2; m.position.set(x, hgt(x) + .75, 0); add(m); g.items.push({ m, x, kind: 'coin' }); }
      g.nextCoin += rnd(10, 22);
    }
    while (g.nextFuel < g.chunkX) {
      const x = g.nextFuel, m = new THREE.Group(), red = new THREE.MeshStandardMaterial({ color: 0xe8302e, roughness: .4 });
      m.add(new THREE.Mesh(new THREE.BoxGeometry(.4, .5, .25), red)); const cap = new THREE.Mesh(new THREE.CylinderGeometry(.05, .05, .12, 10), new THREE.MeshStandardMaterial({ color: 0xffd84a })); cap.position.set(.12, .3, 0); m.add(cap);
      const lab = new THREE.Mesh(new THREE.BoxGeometry(.26, .14, .26), new THREE.MeshStandardMaterial({ color: 0xffffff })); m.add(lab);
      m.position.set(x, hgt(x) + .45, 0); add(m); g.items.push({ m, x, kind: 'fuel' }); g.nextFuel += rnd(110, 170);
    }
  }
  function wheelGround(p, dt, drive) {
    const gy = hgt(p.x), d = p.y - WR - gy;
    if (d > .02) return false;
    const sl = slope(p.x), nl = Math.hypot(1, sl), nx = -sl / nl, ny = 1 / nl, pen = -d;
    if (pen > 0) { p.x += nx * pen * Math.abs(ny); p.y += ny * pen; }
    // quitar la velocidad que va hacia el suelo y aplicar tracción a lo largo de la cuesta
    let vx = p.x - p.px, vy = p.y - p.py; const vn = vx * nx + vy * ny; if (vn < 0) { vx -= vn * nx * 1.3; vy -= vn * ny * 1.3; }
    const tx = ny, ty = -nx; let vt = vx * tx + vy * ty;
    vt += drive * dt * dt; vt *= .997; vt = clamp(vt, -5 * dt, 10.5 * dt);
    const vnn = vx * nx + vy * ny; vx = tx * vt + nx * vnn; vy = ty * vt + ny * vnn;
    p.px = p.x - vx; p.py = p.y - vy; return true;
  }
  function updateDrive(dt) {
    const g = G; g.t += dt;
    const steps = 4, h = dt / steps, wantGas = g.over ? 0 : g.gas;
    let grounded = false;
    for (let k = 0; k < steps; k++) {
      for (const p2 of [g.r, g.f]) { const vx = (p2.x - p2.px) * .999, vy = (p2.y - p2.py) * .999; p2.px = p2.x; p2.py = p2.y; p2.x += vx; p2.y += vy - 15 * h * h; }
      for (let it = 0; it < 3; it++) { const dx = g.f.x - g.r.x, dy = g.f.y - g.r.y, dd = Math.hypot(dx, dy) || 1, diff = (dd - CL) / dd * .5; g.r.x += dx * diff; g.r.y += dy * diff; g.f.x -= dx * diff; g.f.y -= dy * diff; }
      const fuelOk = g.fuel > 0, drive = fuelOk ? (wantGas > 0 ? 9 : wantGas < 0 ? -7 : 0) : 0;
      const gr1 = wheelGround(g.r, h, drive), gr2 = wheelGround(g.f, h, drive * .6);
      grounded = grounded || gr1 || gr2;
      if (!gr1 && !gr2 && wantGas && fuelOk) {   // en el aire: acelerar levanta el morro, frenar lo baja
        const ang = (wantGas > 0 ? 1.6 : -1.6) * h, cx = (g.r.x + g.f.x) / 2, cy = (g.r.y + g.f.y) / 2;
        for (const p2 of [g.r, g.f]) { const rx = p2.x - cx, ry = p2.y - cy, c = Math.cos(ang), s2 = Math.sin(ang); p2.x = cx + rx * c - ry * s2; p2.y = cy + rx * s2 + ry * c; }
      }
    }
    g.ground = grounded;
    const cx = (g.r.x + g.f.x) / 2, cy = (g.r.y + g.f.y) / 2, ang = Math.atan2(g.f.y - g.r.y, g.f.x - g.r.x);
    const vx = ((g.r.x - g.r.px) + (g.f.x - g.f.px)) / 2 / (dt / steps);
    if (!g.over) {
      g.fuel = Math.max(0, g.fuel - dt * (wantGas ? 6.5 : 1.6));
      g.score = Math.max(g.score, Math.floor(cx));
      // cabeza contra el suelo = vuelco
      const hx = cx - Math.sin(ang) * .95, hy = cy + Math.cos(ang) * .95;
      if (hy < hgt(hx) + .05) driveEnd('¡Vuelco!');
      if (g.fuel <= 0) { g.stopT = Math.abs(vx) < .4 ? g.stopT + dt : 0; if (g.stopT > 1.5) driveEnd('¡Sin gasolina!'); }
      for (const it of g.items) {
        if (it.got) continue;
        if (it.kind === 'coin') it.m.rotation.z += dt * 4;
        if (Math.abs(it.x - cx) < .9 && Math.abs(it.m.position.y - (cy + .4)) < 1.1) {
          it.got = true; drop(it.m);
          if (it.kind === 'coin') { g.coins++; S.coin(); PA.burst(it.m.position.x, it.m.position.y, 0, 6, col(0xffd84a), 1.4, .1, .4); }
          else { g.fuel = 100; S.good(); buzz('MEDIUM'); msg('¡Gasolina!'); }
        }
      }
      g.items = g.items.filter(it => !it.got && it.x > cx - 30);
      hud(g.score + ' m', g.coins + ' monedas');
      const fb = $('#fuelBar i'); if (fb) { fb.style.width = g.fuel + '%'; fb.style.background = g.fuel < 25 ? '#ff4d6d' : ''; }
    }
    // generar suelo por delante y quitar el de detrás
    while (g.chunkX < cx + 60) addChunk();
    while (g.chunks.length && g.chunks[0].x1 < cx - 30) drop(g.chunks.shift().m);
    // coche, ruedas y gamba
    g.car.position.set(cx, cy - WR, 0); g.car.rotation.z = ang;
    g.spin -= (vx * (dt / steps) / WR) * steps; for (const w of g.car.userData.wheels) w.rotation.z = g.spin;
    const sc = Math.min(.82, ctx.stage() * .85);
    player.root.visible = true; player.root.scale.setScalar(sc);
    _v.set(-.3, .58, 0).applyAxisAngle(V(0, 0, 1), ang).add(g.car.position); player.root.position.copy(_v);
    player.root.quaternion.setFromEuler(new THREE.Euler(0, 0, ang)).multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(0, -Math.PI / 2, 0)));
    player.tilt.position.set(0, 0, 0); player.tilt.rotation.set(-.5 + Math.sin(T * 9) * (Math.abs(vx) > 1 ? .04 : 0), 0, 0); player.tilt.scale.set(1, 1, 1);
    player.pose(T * 3, 'idle', T, dt, 2);
    if (wantGas > 0 && grounded && g.fuel > 0 && Math.random() < .5) PN.emit(g.r.x - .3, g.r.y - .2, .4, -rnd(.5, 1.5), rnd(.3, 1), 0, col(0xc9b08a), .25, .6, 0, 1.2);
    // cámara y fondo
    const look = V(cx + 2.4, cy + .9, 0), zoom = 9.5 + Math.min(3, Math.abs(vx) * .25);
    camTo(V(look.x, look.y + 1.6, zoom), look, 9);
    g.sky.position.set(cx, cy + 4, -14);
    for (const hh of g.hills) hh.m.position.set(cx - ((cx * hh.k + hh.off) % 46) + 23, cy - 1 + hh.m.geometry.parameters.height / 2 - 2, -10 + hh.k * 3);
    // pedales
    const pd = $('#pedals'); if (pd) { pd.querySelector('.gas').classList.toggle('on', wantGas > 0); pd.querySelector('.brake').classList.toggle('on', wantGas < 0); }
  }
  function driveEnd(title) {
    const g = G; if (g.over) return; S.bad(); buzz('HEAVY');
    const sc = g.score;
    finish({ id: 'drive', score: sc, coins: g.coins + Math.floor(sc / 8), xp: 6 + Math.floor(sc / 10), fun: Math.min(45, 10 + sc / 8), title });
  }

  /* ============ interfaz común ============ */
  const GAMES = { catch: [startCatch, updateCatch], bubbles: [startBubbles, updateBubbles], simon: [startSimon, updateSimon], swim: [startSwim, updateSwim], memory: [startMemory, updateMemory], crabs: [startCrabs, updateCrabs], drive: [startDrive, updateDrive] };
  function clear() { for (const o of objs) scene.remove(o); objs = []; if (G) G.items = G.bubbles = G.pads = G.pipes = G.cards = G.moles = G.chunks = []; }
  return {
    start(id) {
      clear(); ctx.setHouse(true); $('#pedals').hidden = true; aborted = false; T = 0; $('#miniEnd').hidden = true; $('#miniHud').hidden = false; $('#miniMsg').hidden = true;
      pet.act = null; GAMES[id][0](); this.id = id;
    },
    update(dt) { T += dt; if (G) GAMES[G.id][1](dt); },
    pointer(type, x, y) {
      if (!G) return;
      if (G.id === 'catch') { if (type !== 'up') { const w = worldAt(x, y, pz); if (w) ptX = w.x; } }
      else if (G.id === 'bubbles') { if (type === 'down') tapBubble(x, y); }
      else if (G.id === 'simon') { if (type === 'down') tapSimon(x, y); }
      else if (G.id === 'swim') { if (type === 'down') tapSwim(); }
      else if (G.id === 'memory') { if (type === 'down') tapMemory(x, y); }
      else if (G.id === 'crabs') { if (type === 'down') tapCrabs(x, y); }
      else if (G.id === 'drive') { if (type === 'down' || (type === 'move' && G.gas)) G.gas = x > innerWidth / 2 ? 1 : -1; else if (type === 'up') G.gas = 0; }
    },
    abort() { aborted = true; if (G) G.over = true; },
    dispose() { clear(); ctx.setHouse(true); G = null; $('#pedals').hidden = true; $('#miniMsg').hidden = true; player.tilt.position.set(0, 0, 0); player.tilt.rotation.set(0, 0, 0); player.tilt.scale.set(1, 1, 1); },
    // pruebas: ?mini=simon&act=... — adelanta el juego para sacar capturas
    test(Q) {
      const steps = +(Q.get('steps') || 0);
      const log = []; for (let i = 0; i < steps; i++) { if (G.id === 'drive' && i % 15 === 0) log.push(`${i}:x${((G.r.x + G.f.x) / 2).toFixed(1)} y${((G.r.y + G.f.y) / 2).toFixed(1)} g${G.ground ? 1 : 0} h${hgt((G.r.x + G.f.x) / 2).toFixed(1)}`); this.update(1 / 30); if (G.id === 'catch' && i % 5 === 0) this.pointer('move', innerWidth * (.5 + Math.sin(i / 20) * .3), innerHeight * .6); if (G.id === 'drive') G.gas = G.ground ? 1 : 0; if (G.id === 'swim' && (!G.started || (G.y < 1.9 && G.vy < 0))) tapSwim(); if (G.id === 'memory' && i % 20 === 5 && G.found < 3) { const c = G.cards.find(c2 => !c2.up && !c2.done); if (c) { const sp = toScreen(c.g.position); tapMemory(sp.x, sp.y); } } }
      if (log.length) { const d = document.createElement('pre'); d.style.cssText = 'position:fixed;left:0;top:80px;z-index:99;background:#fffc;color:#000;font:10px monospace;margin:0;white-space:pre-wrap;width:390px'; d.textContent = log.join(' '); document.body.appendChild(d); }
    },
  };
}
