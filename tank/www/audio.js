// Sonido sintetizado para Shrimp Zombies (sin archivos). Incluye el desbloqueo de audio de iOS.
export const cfg = { sfx: true, music: true };
let AC = null, master = null, musicBus = null;
export function ac() {
  if (!AC) { try { AC = new (window.AudioContext || window.webkitAudioContext)(); master = AC.createGain(); master.gain.value = .9; master.connect(AC.destination); musicBus = AC.createGain(); musicBus.gain.value = 0; musicBus.connect(master); } catch (e) { } }
  if (AC && AC.state === 'suspended') AC.resume();
  return AC;
}
const SILENT = 'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQQAAACAgICA';
let silentEl = null;
function unlock() {
  try { if (navigator.audioSession && navigator.audioSession.type !== 'playback') navigator.audioSession.type = 'playback'; } catch (e) { }
  if (!silentEl) { silentEl = document.createElement('audio'); silentEl.setAttribute('playsinline', ''); silentEl.loop = true; silentEl.src = SILENT; silentEl.volume = .01; }
  if (silentEl.paused) silentEl.play().catch(() => { });
  const a = ac(); if (a && a.state !== 'running') a.resume().catch(() => { });
}
for (const ev of ['touchend', 'click', 'keydown']) document.addEventListener(ev, unlock, { capture: true, passive: true });
window.addEventListener('gamepadconnected', unlock);

export function tone(f, d, type = 'sine', v = .2, slide = 0, when = 0, bus) {
  if (!bus && !cfg.sfx) return; const a = ac(); if (!a) return;
  const o = a.createOscillator(), g = a.createGain(), t = a.currentTime + when;
  o.type = type; o.frequency.setValueAtTime(f, t); if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(20, f + slide), t + d);
  g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + d); o.connect(g).connect(bus || master); o.start(t); o.stop(t + d + .02);
}
let noiseBuf = null;
export function noise(d = .15, v = .2, f = 1000, type = 'highpass', when = 0, bus, q = 1) {
  if (!bus && !cfg.sfx) return; const a = ac(); if (!a) return;
  if (!noiseBuf) { noiseBuf = a.createBuffer(1, a.sampleRate, a.sampleRate); const ch = noiseBuf.getChannelData(0); for (let i = 0; i < ch.length; i++) ch[i] = Math.random() * 2 - 1; }
  const s = a.createBufferSource(), fl = a.createBiquadFilter(), g = a.createGain(), t = a.currentTime + when;
  s.buffer = noiseBuf; fl.type = type; fl.frequency.value = f; fl.Q.value = q; g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + d);
  s.connect(fl).connect(g).connect(bus || master); s.start(t, Math.random() * .5); s.stop(t + d + .02);
}
const N = n => 440 * Math.pow(2, (n - 69) / 12);
export const S = {
  shot: (p = 1, big = false) => { noise(big ? .35 : .16, big ? .5 : .32, 600 * p, 'lowpass'); noise(.05, .25, 3000, 'highpass'); tone(110 * p, big ? .2 : .1, 'sine', .3, -60); },
  ray: () => { tone(1400, .25, 'sawtooth', .07, -1100); tone(700, .25, 'square', .05, -500); },
  boom: () => { noise(.8, .6, 300, 'lowpass'); tone(60, .6, 'sine', .5, -30); },
  dry: () => tone(1800, .03, 'square', .05),
  reload: () => { noise(.05, .18, 2500, 'bandpass', 0, null, 3); noise(.05, .18, 1800, 'bandpass', .35, null, 3); tone(400, .04, 'square', .05, 0, .5); },
  hit: () => { noise(.06, .2, 900, 'bandpass', 0, null, 2); },
  hitmark: () => tone(2200, .04, 'square', .04),
  head: () => { tone(1800, .05, 'square', .05); noise(.08, .2, 600, 'bandpass', 0, null, 2); },
  knife: () => { noise(.12, .25, 3500, 'highpass'); tone(300, .08, 'sawtooth', .06, -150); },
  hurt: () => { noise(.25, .35, 400, 'lowpass'); tone(90, .25, 'sawtooth', .15, -40); },
  groan: (p = 1) => { const a = ac(); if (!a || !cfg.sfx) return; const o = a.createOscillator(), l = a.createOscillator(), lg = a.createGain(), g = a.createGain(), f = a.createBiquadFilter(), t = a.currentTime, d = 1 + Math.random(); o.type = 'sawtooth'; o.frequency.value = (70 + Math.random() * 60) * p; l.frequency.value = 5 + Math.random() * 4; lg.gain.value = 15; l.connect(lg).connect(o.frequency); f.type = 'bandpass'; f.frequency.value = 500; f.Q.value = 3; g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(.06, t + .2); g.gain.exponentialRampToValueAtTime(.001, t + d); o.connect(f).connect(g).connect(master); o.start(t); l.start(t); o.stop(t + d); l.stop(t + d); },
  board: () => { noise(.18, .3, 700, 'bandpass', 0, null, 2); tone(150, .1, 'square', .06, -60); },
  build: () => { noise(.06, .25, 1200, 'bandpass', 0, null, 4); tone(500, .05, 'square', .05); },
  buy: () => [0, .07, .14].forEach((w, i) => tone(N(72 + [0, 4, 7][i]), .12, 'square', .06, 0, w)),
  no: () => { tone(160, .2, 'square', .08); tone(150, .2, 'square', .08, 0, .2); },
  door: () => { noise(.6, .4, 400, 'lowpass'); tone(90, .4, 'sawtooth', .08, -30); },
  power: () => { [0, .3, .6].forEach((w, i) => tone(N(36 + i * 7), 1.2, 'sawtooth', .07, 0, w)); noise(1.2, .2, 200, 'lowpass', 0); },
  perk: () => [0, .1, .2, .3, .45, .6].forEach((w, i) => tone(N([67, 71, 74, 79, 74, 83][i]), .16, 'triangle', .1, 0, w)),
  drink: () => { noise(.3, .12, 800, 'bandpass', 0, null, 2); tone(300, .2, 'sine', .08, 400, .3); tone(200, .3, 'sine', .1, -50, .7); },
  boxSpin: () => tone(N(84 + Math.floor(Math.random() * 8)), .1, 'triangle', .05),
  boxOpen: () => [0, .12, .24, .36].forEach((w, i) => tone(N([72, 76, 79, 84][i]), .25, 'sine', .08, 0, w)),
  pap: () => { [0, .2, .4, .6, .8, 1].forEach((w, i) => tone(N([48, 55, 60, 63, 67, 72][i]), .4, 'sawtooth', .06, 0, w)); noise(1.2, .2, 300, 'lowpass', .2); },
  powerup: () => [0, .08, .16, .24].forEach((w, i) => tone(N(79 + i * 3), .18, 'triangle', .1, 0, w)),
  puSpeak: () => { tone(120, .6, 'sawtooth', .08, -30); },
  roundEnd: () => { [0, .5, 1, 1.5].forEach((w, i) => { tone(N([50, 53, 57, 50][i]), 1.1, 'sawtooth', .07, 0, w); tone(N([38, 41, 45, 38][i]), 1.1, 'triangle', .1, 0, w); }); },
  roundStart: () => { [0, .4, .8].forEach((w, i) => { tone(N([45, 48, 52][i]), .9, 'sawtooth', .07, 0, w); tone(N(33), .9, 'triangle', .12, 0, w); }); noise(2, .1, 200, 'lowpass', 0); },
  down: () => { tone(200, 1.5, 'sawtooth', .1, -150); },
  pts: () => tone(1500, .03, 'sine', .03),
};
// ambiente: zumbido grave y viento
let ambOn = false, ambNodes = null;
export function ambient(on) {
  const a = ac(); if (!a) return; ambOn = on && cfg.music;
  if (ambOn && !ambNodes) {
    const o = a.createOscillator(), o2 = a.createOscillator(), f = a.createBiquadFilter(), g = a.createGain(); o.type = 'sawtooth'; o.frequency.value = 55; o2.type = 'sawtooth'; o2.frequency.value = 55.6; f.type = 'lowpass'; f.frequency.value = 180; g.gain.value = 0; o.connect(f); o2.connect(f); f.connect(g).connect(master); o.start(); o2.start(); ambNodes = { o, o2, g };
  }
  if (ambNodes) ambNodes.g.gain.setTargetAtTime(ambOn ? .05 : 0, a.currentTime, 1);
}
setInterval(() => { if (ambOn && Math.random() < .3) noise(3, .04, 400, 'bandpass', 0, null, .7); }, 2500);
export function suspend(v) { if (AC) v ? AC.suspend() : AC.resume(); }
