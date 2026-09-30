// Sonido sintetizado (sin archivos): efectos y una musiquilla tranquila.
export const cfg = { sfx: true, music: true, haptic: true };
let AC = null, master = null, musicGain = null;
export function ac() {
  if (!AC) {
    try {
      AC = new (window.AudioContext || window.webkitAudioContext)();
      master = AC.createGain(); master.gain.value = .9; master.connect(AC.destination);
      musicGain = AC.createGain(); musicGain.gain.value = 0; musicGain.connect(master);
    } catch (e) { }
  }
  if (AC && AC.state === 'suspended') AC.resume();
  return AC;
}
export function tone(f, d, type = 'sine', v = .2, slide = 0, when = 0, dest) {
  if (!dest && !cfg.sfx) return; const a = ac(); if (!a) return;
  const o = a.createOscillator(), g = a.createGain(), t = a.currentTime + when;
  o.type = type; o.frequency.setValueAtTime(f, t); if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, f + slide), t + d);
  g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + d); o.connect(g).connect(dest || master); o.start(t); o.stop(t + d + .02);
}
export function noiseHit(d = .15, v = .2, hp = 1000, when = 0, dest) {
  if (!dest && !cfg.sfx) return; const a = ac(); if (!a) return;
  const b = a.createBuffer(1, Math.max(1, a.sampleRate * d), a.sampleRate), ch = b.getChannelData(0);
  for (let i = 0; i < ch.length; i++) ch[i] = (Math.random() * 2 - 1) * (1 - i / ch.length);
  const s = a.createBufferSource(), f = a.createBiquadFilter(), g = a.createGain(); s.buffer = b; f.type = 'highpass'; f.frequency.value = hp; g.gain.value = v;
  s.connect(f).connect(g).connect(dest || master); s.start(a.currentTime + when);
}
const N = n => 440 * Math.pow(2, (n - 69) / 12);
export const S = {
  tap: () => tone(700, .05, 'sine', .07, 120),
  click: () => { tone(520, .05, 'triangle', .08); tone(780, .06, 'triangle', .06, 0, .04); },
  coin: () => { tone(1318, .07, 'square', .04); tone(1976, .12, 'square', .035, 0, .06); },
  pop: () => { tone(480 + Math.random() * 300, .09, 'sine', .14, 500); noiseHit(.05, .06, 3000); },
  eat: () => { for (let i = 0; i < 3; i++) { noiseHit(.07, .16, 500, i * .16); tone(200 + i * 40, .08, 'square', .05, -60, i * .16); } },
  splash: () => { noiseHit(.35, .12, 800); tone(300, .25, 'sine', .07, 500); },
  scrub: () => noiseHit(.06, .05, 2500),
  happy: () => [0, .09, .18].forEach((w, i) => tone(N(72 + i * 4), .14, 'triangle', .12, 0, w)),
  sad: () => { tone(300, .35, 'sine', .1, -120); },
  no: () => { tone(220, .12, 'square', .07, -40); tone(200, .14, 'square', .07, -40, .14); },
  levelup: () => [0, .1, .2, .3, .42].forEach((w, i) => tone(N(65 + [0, 4, 7, 12, 16][i]), .2, 'triangle', .13, 0, w)),
  buy: () => [0, .08, .16].forEach((w, i) => tone(880 * Math.pow(1.335, i), .14, 'square', .05, 0, w)),
  err: () => { tone(160, .2, 'sawtooth', .09, -50); },
  sleep: () => [0, .25, .5].forEach((w, i) => tone(N(72 - i * 3), .4, 'sine', .07, 0, w)),
  crack: () => { noiseHit(.12, .22, 700); tone(180, .1, 'square', .08, -60); },
  hatch: () => [0, .08, .16, .24, .32].forEach((w, i) => tone(N(67 + i * 3), .16, 'triangle', .13, 0, w)),
  good: () => tone(988, .09, 'triangle', .1, 400),
  bad: () => { tone(130, .3, 'sawtooth', .13, -60); noiseHit(.2, .15, 400); },
  pad: i => tone(N([60, 64, 67, 72][i]), .3, 'triangle', .16),
  tick: () => tone(880, .04, 'square', .03),
};
export const buzz = (style = 'LIGHT') => { if (!cfg.haptic) return; try { const h = window.Capacitor && Capacitor.Plugins && Capacitor.Plugins.Haptics; if (h) h.impact({ style }); } catch (e) { } };

// música: acordes suaves y una melodía pentatónica con notas al azar
let musicOn = false, nextBeat = 0, beat = 0;
const CH = [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 55, 59]], PENT = [69, 72, 74, 76, 79, 81];
function musicTick() {
  if (!AC || !musicOn) return;
  const spb = 60 / 76;
  while (nextBeat < AC.currentTime + .3) {
    const w = nextBeat - AC.currentTime, bar = Math.floor(beat / 4) % 4, b = beat % 4;
    if (b === 0) CH[bar].forEach((n, i) => tone(N(n), spb * 3.8, 'sine', .07, 0, w + i * .02, musicGain));
    if (b === 0 || b === 2) tone(N(CH[bar][0] - 12), spb * 1.6, 'triangle', .1, 0, w, musicGain);
    if (Math.random() < .55) tone(N(PENT[Math.floor(Math.random() * PENT.length)]), spb * 1.2, 'sine', .055, 0, w + (Math.random() < .5 ? 0 : spb / 2), musicGain);
    nextBeat += spb; beat++;
  }
}
setInterval(musicTick, 120);
export function setMusic(on) {
  musicOn = on && cfg.music; const a = ac(); if (!a) return;
  musicGain.gain.setTargetAtTime(musicOn ? .55 : 0, a.currentTime, .4);
  if (musicOn && nextBeat < a.currentTime) nextBeat = a.currentTime + .05;
}
export function suspend(v) { if (AC) v ? AC.suspend() : AC.resume(); }
