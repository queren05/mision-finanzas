// Entrada unificada: mando (Gamepad API, mapeo estándar), teclado + ratón y controles táctiles.
// Cada fotograma el juego lee `I` (estado ya combinado) y llama a poll().
export const I = {
  mx: 0, my: 0,            // movimiento (-1..1), y positivo = hacia delante
  lx: 0, ly: 0,            // giro de cámara acumulado este fotograma (radianes)
  fire: false, aim: false, sprint: false,
  pressed: new Set(),      // acciones pulsadas este fotograma: reload, swap, use, knife, nade, jump, pause
  held: new Set(),         // acciones mantenidas: use
  device: 'touch',         // último dispositivo usado: 'touch' | 'kb' | 'pad'
  padKind: 'xbox',         // 'xbox' | 'ps'
  stickLook: false,        // el giro viene de un stick (para la ayuda al apuntar)
};
export const opts = { sens: 1, invertY: false, assist: true };
const listeners = new Set();
export const onDevice = f => listeners.add(f);
function setDevice(d) { if (I.device !== d) { I.device = d; listeners.forEach(f => f(d)); } }

/* ---------- mando ---------- */
// botones del mapeo estándar
const B = { A: 0, B: 1, X: 2, Y: 3, LB: 4, RB: 5, LT: 6, RT: 7, BACK: 8, START: 9, L3: 10, R3: 11, UP: 12, DOWN: 13, LEFT: 14, RIGHT: 15 };
let prevPad = [];
let padIndex = -1;
window.addEventListener('gamepadconnected', e => { padIndex = e.gamepad.index; detectKind(e.gamepad); setDevice('pad'); });
window.addEventListener('gamepaddisconnected', e => { if (e.gamepad.index === padIndex) padIndex = -1; });
function detectKind(g) { I.padKind = /054c|playstation|dualshock|dualsense|wireless controller(?!.*xbox)/i.test(g.id) && !/xbox/i.test(g.id) ? 'ps' : 'xbox'; }
export function pad() {
  const ps = navigator.getGamepads ? navigator.getGamepads() : [];
  if (padIndex >= 0 && ps[padIndex]) return ps[padIndex];
  for (const g of ps) if (g && g.connected) { padIndex = g.index; detectKind(g); return g; }
  return null;
}
export const padConnected = () => !!pad();
const dz = (x, y, d = .16) => { const m = Math.hypot(x, y); if (m < d) return [0, 0]; const k = Math.min(1, (m - d) / (1 - d)) / m; return [x * k, y * k]; };
export function rumble(strong = .5, weak = .5, ms = 120) {
  const g = pad(); const a = g && (g.vibrationActuator || (g.hapticActuators && g.hapticActuators[0]));
  try { if (a && a.playEffect) a.playEffect('dual-rumble', { duration: ms, strongMagnitude: strong, weakMagnitude: weak }); else if (a && a.pulse) a.pulse(strong, ms); } catch (e) { }
}
export const glyph = {
  xbox: { A: 'A', B: 'B', X: 'X', Y: 'Y', RT: 'RT', LT: 'LT', RB: 'RB', LB: 'LB', R3: 'R3', START: '☰' },
  ps: { A: '✕', B: '○', X: '□', Y: '△', RT: 'R2', LT: 'L2', RB: 'R1', LB: 'L1', R3: 'R3', START: 'OPTIONS' },
};
// texto del botón para una acción, según el dispositivo actual
export function key(action) {
  if (I.device === 'pad') { const g = glyph[I.padKind]; return { use: g.X, reload: g.X, swap: g.Y, knife: g.R3, nade: g.RB, jump: g.A, fire: g.RT, aim: g.LT, pause: g.START }[action]; }
  if (I.device === 'kb') return { use: 'F', reload: 'R', swap: 'Q', knife: 'V', nade: 'G', jump: 'Espacio', fire: 'Clic', aim: 'Clic dcho', pause: 'Esc' }[action];
  return null;
}

/* ---------- teclado y ratón ---------- */
const keys = new Set(); let mouseDX = 0, mouseDY = 0, mouseL = false, mouseR = false; const kbPress = new Set();
const KEYMAP = { KeyR: 'reload', KeyQ: 'swap', Digit1: 'swap', Digit2: 'swap', KeyF: 'use', KeyE: 'use', KeyV: 'knife', KeyG: 'nade', Space: 'jump', Escape: 'pause', KeyP: 'pause' };
addEventListener('keydown', e => { if (e.repeat) return; keys.add(e.code); setDevice('kb'); const a = KEYMAP[e.code]; if (a) kbPress.add(a); if (menuActive()) menuKey(e); });
addEventListener('keyup', e => keys.delete(e.code));
addEventListener('mousemove', e => { if (document.pointerLockElement) { mouseDX += e.movementX; mouseDY += e.movementY; } });
addEventListener('mousedown', e => { if (!document.pointerLockElement) return; setDevice('kb'); if (e.button === 0) mouseL = true; if (e.button === 2) mouseR = true; });
addEventListener('mouseup', e => { if (e.button === 0) mouseL = false; if (e.button === 2) mouseR = false; });
addEventListener('contextmenu', e => e.preventDefault());
export function lockPointer(el) { if (I.device === 'kb' && el.requestPointerLock && !matchMedia('(pointer: coarse)').matches) try { el.requestPointerLock(); } catch (e) { } }
export function unlockPointer() { if (document.pointerLockElement) document.exitPointerLock(); }

/* ---------- táctil ---------- */
// zona izquierda: joystick flotante; zona derecha: arrastrar para mirar. Botones con data-act.
const T = { moveId: null, mx0: 0, my0: 0, mvx: 0, mvy: 0, lookId: null, lx: 0, ly: 0, ldx: 0, ldy: 0, fire: false, aim: false, press: new Set(), held: new Set(), fireId: null };
export function bindTouch(root, stickEl, knobEl) {
  const R = 60;
  root.addEventListener('touchstart', e => {
    setDevice('touch');
    for (const t of e.changedTouches) {
      const btn = t.target.closest && t.target.closest('[data-act]');
      if (btn) {
        const a = btn.dataset.act; btn.classList.add('on');
        if (a === 'fire') { T.fire = true; T.fireId = t.identifier; if (T.lookId === null) { T.lookId = t.identifier; T.lx = t.clientX; T.ly = t.clientY; } }   // disparar y apuntar con el mismo dedo
        else if (a === 'aim') T.aim = !T.aim;
        else { T.press.add(a); T.held.add(a); btn.dataset.tid = t.identifier; }
        continue;
      }
      if (t.clientX < innerWidth * .45 && T.moveId === null) { T.moveId = t.identifier; T.mx0 = t.clientX; T.my0 = t.clientY; T.mvx = T.mvy = 0; stickEl.style.left = t.clientX + 'px'; stickEl.style.top = t.clientY + 'px'; stickEl.classList.add('on'); knobEl.style.transform = ''; }
      else if (T.lookId === null) { T.lookId = t.identifier; T.lx = t.clientX; T.ly = t.clientY; }
    }
    e.preventDefault();
  }, { passive: false });
  root.addEventListener('touchmove', e => {
    for (const t of e.changedTouches) {
      if (t.identifier === T.moveId) { let dx = t.clientX - T.mx0, dy = t.clientY - T.my0; const m = Math.hypot(dx, dy); if (m > R) { dx *= R / m; dy *= R / m; } T.mvx = dx / R; T.mvy = -dy / R; knobEl.style.transform = `translate(${dx}px,${dy}px)`; }
      if (t.identifier === T.lookId) { T.ldx += t.clientX - T.lx; T.ldy += t.clientY - T.ly; T.lx = t.clientX; T.ly = t.clientY; }
    }
    e.preventDefault();
  }, { passive: false });
  const end = e => {
    for (const t of e.changedTouches) {
      if (t.identifier === T.moveId) { T.moveId = null; T.mvx = T.mvy = 0; stickEl.classList.remove('on'); knobEl.style.transform = ''; }
      if (t.identifier === T.lookId) T.lookId = null;
      if (t.identifier === T.fireId) { T.fire = false; T.fireId = null; }
      root.querySelectorAll('[data-act]').forEach(b => { if (b.dataset.act === 'fire' ? !T.fire : (b.dataset.tid == t.identifier)) { b.classList.remove('on'); if (b.dataset.tid == t.identifier) { T.held.delete(b.dataset.act); delete b.dataset.tid; } } });
    }
  };
  root.addEventListener('touchend', end); root.addEventListener('touchcancel', end);
}
export function resetTouch() { T.fire = false; T.aim = false; T.held.clear(); T.press.clear(); T.moveId = T.lookId = T.fireId = null; T.mvx = T.mvy = 0; }
export const touchAim = v => { if (v !== undefined) T.aim = v; return T.aim; };

/* ---------- lectura por fotograma ---------- */
export function poll(dt, inGame) {
  I.pressed.clear(); I.held.clear(); I.lx = I.ly = 0; I.mx = I.my = 0; I.fire = I.aim = I.sprint = false; I.stickLook = false;
  // mando
  const g = pad();
  if (g) {
    const btn = i => g.buttons[i] && (g.buttons[i].pressed || g.buttons[i].value > .35);
    const was = i => prevPad[i];
    const edge = i => btn(i) && !was(i);
    const [mx, my] = dz(g.axes[0] || 0, g.axes[1] || 0), [rx, ry] = dz(g.axes[2] || 0, g.axes[3] || 0, .12);
    let any = mx || my || rx || ry;
    for (let i = 0; i < g.buttons.length; i++) if (btn(i)) any = true;
    if (any) setDevice('pad');
    if (I.device === 'pad') {
      I.mx = mx; I.my = -my;
      const m = Math.hypot(rx, ry), curve = m > 0 ? Math.pow(m, 1.8) / m : 0;   // curva de respuesta: precisión cerca del centro
      const turn = 3.4 * opts.sens * dt;
      I.lx = -rx * curve * turn; I.ly = (opts.invertY ? 1 : -1) * ry * curve * turn * .75;
      I.stickLook = m > 0;
      I.fire = btn(B.RT); I.aim = btn(B.LT); I.sprint = btn(B.L3) || (Math.hypot(mx, my) > .95 && sprintLatch);
      if (edge(B.L3)) sprintLatch = true; if (Math.hypot(mx, my) < .5) sprintLatch = false;
      if (edge(B.X)) { I.pressed.add('reload'); I.pressed.add('use'); }
      if (btn(B.X)) I.held.add('use');
      if (edge(B.Y)) I.pressed.add('swap');
      if (edge(B.R3) || edge(B.B)) I.pressed.add('knife');
      if (edge(B.RB) || edge(B.LB)) I.pressed.add('nade');
      if (edge(B.A)) I.pressed.add('jump');
      if (edge(B.START) || edge(B.BACK)) I.pressed.add('pause');
      if (menuActive()) menuPad(g, btn, edge, my, mx);
    }
    prevPad = g.buttons.map((_, i) => btn(i));
  }
  // teclado y ratón
  if (I.device === 'kb') {
    I.mx = (keys.has('KeyD') ? 1 : 0) - (keys.has('KeyA') ? 1 : 0); I.my = (keys.has('KeyW') ? 1 : 0) - (keys.has('KeyS') ? 1 : 0);
    const k = .0024 * opts.sens; I.lx = -mouseDX * k; I.ly = -mouseDY * k * (opts.invertY ? -1 : 1);
    I.fire = mouseL; I.aim = mouseR; I.sprint = keys.has('ShiftLeft');
    if (keys.has('KeyF') || keys.has('KeyE')) I.held.add('use');
  }
  mouseDX = mouseDY = 0;
  for (const a of kbPress) I.pressed.add(a); kbPress.clear();
  // táctil
  if (I.device === 'touch') {
    I.mx = T.mvx; I.my = T.mvy; I.sprint = Math.hypot(T.mvx, T.mvy) > .97 && T.mvy > .6;
    const k = .0052 * opts.sens; I.lx = -T.ldx * k; I.ly = -T.ldy * k * (opts.invertY ? -1 : 1) * .8;
    I.fire = T.fire; I.aim = T.aim;
    for (const a of T.held) I.held.add(a);
  }
  T.ldx = T.ldy = 0;
  for (const a of T.press) I.pressed.add(a); T.press.clear();
}
let sprintLatch = false;

/* ---------- navegación de menús con mando / teclado ---------- */
// Los elementos navegables llevan la clase .nav; el foco se mueve al más cercano en la dirección pulsada.
let menuRoot = null, navRepeat = 0, lastDir = '';
export function setMenu(root) { menuRoot = root; if (root && (I.device === 'pad' || I.device === 'kb')) focusFirst(); else if (!root) clearFocus(); }
const menuActive = () => menuRoot && !menuRoot.hidden;
const navEls = () => [...menuRoot.querySelectorAll('.nav')].filter(e => e.offsetParent !== null && !e.disabled);
function clearFocus() { document.querySelectorAll('.focus').forEach(e => e.classList.remove('focus')); }
function focusEl(el) { clearFocus(); if (el) { el.classList.add('focus'); el.scrollIntoView && el.scrollIntoView({ block: 'nearest', inline: 'nearest' }); } }
export function focusFirst() { const els = navEls(); const pref = els.find(e => e.classList.contains('primary')) || els[0]; focusEl(pref); }
function cur() { const c = menuRoot.querySelector('.nav.focus'); return c && c.offsetParent !== null ? c : null; }
function move(dir) {
  const els = navEls(); if (!els.length) return; const c = cur(); if (!c) return focusFirst();
  const r = c.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
  let best = null, bd = 1e9;
  for (const e of els) {
    if (e === c) continue; const q = e.getBoundingClientRect(), x = q.left + q.width / 2 - cx, y = q.top + q.height / 2 - cy;
    const along = dir === 'up' ? -y : dir === 'down' ? y : dir === 'left' ? -x : x, side = dir === 'up' || dir === 'down' ? Math.abs(x) : Math.abs(y);
    if (along <= 4) continue; const d = along + side * 2.2; if (d < bd) { bd = d; best = e; }
  }
  if (best) { focusEl(best); navSound && navSound(); }
}
function activate() { const c = cur(); if (c) { c.click(); } }
function back() { const b = menuRoot.querySelector('[data-back]'); if (b && b.offsetParent !== null) b.click(); }
function slide(d) { let c = cur(); if (c && c.type !== 'range') c = c.querySelector('input[type=range]'); if (c && c.type === 'range') { c.value = +c.value + d * (+c.step || 1); c.dispatchEvent(new Event('input', { bubbles: true })); return true; } return false; }
let navSound = null; export const setNavSound = f => navSound = f;
function menuPad(g, btn, edge, my, mx) {
  const dir = btn(B.UP) || my < -.5 ? 'up' : btn(B.DOWN) || my > .5 ? 'down' : btn(B.LEFT) || mx < -.5 ? 'left' : btn(B.RIGHT) || mx > .5 ? 'right' : '';
  const now = performance.now();
  if (dir && (dir !== lastDir || now > navRepeat)) { if (!((dir === 'left' || dir === 'right') && slide(dir === 'left' ? -1 : 1))) move(dir); navRepeat = now + (dir !== lastDir ? 380 : 140); }
  lastDir = dir;
  if (edge(B.A)) activate();
  if (edge(B.B)) back();
}
function menuKey(e) {
  const m = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' }[e.code];
  if (m) { if (!cur()) focusFirst(); else if (!((m === 'left' || m === 'right') && slide(m === 'left' ? -1 : 1))) move(m); e.preventDefault(); }
  if (e.code === 'Enter' && cur()) { activate(); e.preventDefault(); }
  if (e.code === 'Escape' || e.code === 'Backspace') back();
}
onDevice(d => { if (menuActive() && (d === 'pad' || d === 'kb') && !cur()) focusFirst(); if (d === 'touch') clearFocus(); });
