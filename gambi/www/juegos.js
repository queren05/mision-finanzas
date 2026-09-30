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

  /* ============ interfaz común ============ */
  const GAMES = { catch: [startCatch, updateCatch], bubbles: [startBubbles, updateBubbles], simon: [startSimon, updateSimon] };
  function clear() { for (const o of objs) scene.remove(o); objs = []; if (G) G.items = G.bubbles = G.pads = []; }
  return {
    start(id) {
      clear(); aborted = false; T = 0; $('#miniEnd').hidden = true; $('#miniHud').hidden = false; $('#miniMsg').hidden = true;
      pet.act = null; GAMES[id][0](); this.id = id;
    },
    update(dt) { T += dt; if (G) GAMES[G.id][1](dt); },
    pointer(type, x, y) {
      if (!G) return;
      if (G.id === 'catch') { if (type !== 'up') { const w = worldAt(x, y, pz); if (w) ptX = w.x; } }
      else if (G.id === 'bubbles') { if (type === 'down') tapBubble(x, y); }
      else if (G.id === 'simon') { if (type === 'down') tapSimon(x, y); }
    },
    abort() { aborted = true; if (G) G.over = true; },
    dispose() { clear(); G = null; $('#miniMsg').hidden = true; player.tilt.position.set(0, 0, 0); player.tilt.rotation.set(0, 0, 0); player.tilt.scale.set(1, 1, 1); },
    // pruebas: ?mini=simon&act=... — adelanta el juego para sacar capturas
    test(Q) {
      const steps = +(Q.get('steps') || 0);
      for (let i = 0; i < steps; i++) { this.update(1 / 30); if (G.id === 'catch' && i % 5 === 0) this.pointer('move', innerWidth * (.5 + Math.sin(i / 20) * .3), innerHeight * .6); }
    },
  };
}
