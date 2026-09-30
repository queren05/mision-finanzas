// Catálogo de la tienda y partida guardada de Gambi (localStorage, prefijo «gambi.»).

// Cada comida sube una o varias necesidades (0–100). La primera (plancton) es gratis e ilimitada.
export const FOODS = [
  { id: 'plancton', name: 'Plancton', price: 0, free: true, food: 14, desc: 'Lo básico de toda gamba. Siempre hay.' },
  { id: 'alga', name: 'Alga fresca', price: 15, food: 24, desc: 'Crujiente y sana.' },
  { id: 'krill', name: 'Burger de krill', price: 45, food: 42, fun: 6, desc: 'Con doble de krill.' },
  { id: 'sushi', name: 'Sushi', price: 55, food: 34, fun: 12, desc: 'Finura oriental.' },
  { id: 'pizza', name: 'Pizza', price: 70, food: 55, fun: 4, desc: 'Sacia muchísimo.' },
  { id: 'helado', name: 'Helado', price: 40, food: 10, fun: 30, desc: 'Sube el ánimo al instante.' },
  { id: 'tarta', name: 'Tarta', price: 80, food: 22, fun: 38, desc: 'Para celebrar cualquier cosa.' },
  { id: 'piruleta', name: 'Piruleta', price: 30, food: 4, fun: 26, desc: 'Dulce y entretenida.' },
  { id: 'sopa', name: 'Sopa caliente', price: 60, food: 40, energy: 12, desc: 'Da energía y calorcito.' },
  { id: 'vitamina', name: 'Súper vitamina', price: 160, food: 25, fun: 25, energy: 25, hyg: 25, desc: 'Un poquito de todo.' },
];

// Especies (modelos de gamba). «model» es el id de PLAYERS en modelos.js.
export const CHARS = [
  { id: 'gambita', name: 'Gambita', price: 0, model: 'gamba', desc: 'La gamba de siempre.' },
  { id: 'langostino', name: 'Langostino', price: 800, model: 'langostino', desc: 'Corre enroscado y a saltitos.' },
  { id: 'chulita', name: 'Gamba Chulita', price: 1800, model: 'chaqueta', desc: 'Con chaqueta de llamas.' },
  { id: 'limpiadora', name: 'Gamba Limpiadora', price: 2500, model: 'mysis', desc: 'Una gamba de verdad, con sus veinte patitas.' },
];

// h: giro de tono (vueltas), s: saturación, v: brillo. Extras: ghost, shine, rainbow.
export const SKINS = [
  { id: 'natural', name: 'Natural', price: 0, p: { h: 0, s: 1, v: 1 } },
  { id: 'cocida', name: 'Cocida', price: 120, p: { h: -.045, s: 1.7, v: .95 } },
  { id: 'chicle', name: 'Chicle', price: 140, p: { h: -.13, s: 1.05, v: 1.1 } },
  { id: 'lima', name: 'Lima', price: 160, p: { h: .22, s: 1.2, v: 1 } },
  { id: 'carbon', name: 'Carbón', price: 180, p: { h: 0, s: .15, v: .42 } },
  { id: 'tropical', name: 'Tropical', price: 200, p: { h: .43, s: 1.15, v: 1 } },
  { id: 'real', name: 'Azul real', price: 240, p: { h: .57, s: 1.25, v: .95 } },
  { id: 'uva', name: 'Uva', price: 280, p: { h: .72, s: 1.2, v: .95 } },
  { id: 'fantasma', name: 'Fantasma', price: 500, p: { h: .47, s: .35, v: 1.3, ghost: 1 } },
  { id: 'dorada', name: 'Dorada', price: 800, p: { h: .085, s: 1.5, v: 1.15, shine: 1 } },
  { id: 'arcoiris', name: 'Arcoíris', price: 1400, p: { h: 0, s: 1.3, v: 1.05, rainbow: 1 } },
];

export const HATS = [
  { id: 'nada', name: 'Sin gorro', price: 0 },
  { id: 'fiesta', name: 'Gorro de fiesta', price: 100 },
  { id: 'gorra', name: 'Gorra', price: 140 },
  { id: 'gafas', name: 'Gafas de sol', price: 180 },
  { id: 'auris', name: 'Auriculares', price: 240 },
  { id: 'chistera', name: 'Chistera', price: 320 },
  { id: 'vikingo', name: 'Casco vikingo', price: 400 },
  { id: 'halo', name: 'Aureola', price: 450 },
  { id: 'corona', name: 'Corona', price: 700 },
  { id: 'tiburon', name: 'Gorro Tiburón', price: 900, desc: 'El disfraz de tiburón más famoso de internet.' },
];

// Temas de la casa: colores y dibujo de las paredes y del suelo
export const THEMES = [
  { id: 'cuqui', name: 'Cuqui', price: 0, wall: ['#ffd9e8', '#ffb7d3'], line: '#ffffff', floor: ['#f3dcb8', '#e3c392'], fpat: 'planks', wpat: 'dots', accent: 0xff7ab0, dark: 0xd9467f, sky: 0x9fd8ff },
  { id: 'submarino', name: 'Submarino', price: 300, wall: ['#2a86c9', '#0f4a8a'], line: '#9fe6ff', floor: ['#ecdcab', '#d8c48a'], fpat: 'sand', wpat: 'waves', accent: 0x35d0ff, dark: 0x0a6db0, sky: 0x1a78c2 },
  { id: 'selva', name: 'Selva', price: 350, wall: ['#86cf78', '#3f9a4c'], line: '#d6f7a8', floor: ['#ad7d50', '#8a5e3a'], fpat: 'planks', wpat: 'leaves', accent: 0x4fe37a, dark: 0x2c8a4a, sky: 0xbdf0ff },
  { id: 'playa', name: 'Playa', price: 400, wall: ['#ffeaa8', '#ffd07a'], line: '#ffffff', floor: ['#f6e5b4', '#ebd194'], fpat: 'sand', wpat: 'stripes', accent: 0xffa62e, dark: 0xd9791a, sky: 0x8fd6ff },
  { id: 'espacio', name: 'Espacio', price: 500, wall: ['#2d2270', '#0d0a30'], line: '#ffffff', floor: ['#43477a', '#2b2e55'], fpat: 'tiles', wpat: 'stars', accent: 0xb45aff, dark: 0x6a2fb8, sky: 0x120c3a },
  { id: 'neon', name: 'Neón', price: 600, wall: ['#1c103c', '#3b1470'], line: '#ff3fb4', floor: ['#22143f', '#311a60'], fpat: 'grid', wpat: 'grid', accent: 0xff3fb4, dark: 0x3ff0ff, sky: 0x1a0d36 },
];

export const MINIGAMES = [
  { id: 'catch', name: 'Lluvia de comida', desc: 'Mueve a Gambi y atrapa la comida. ¡Esquiva los erizos!', icon: 'catch', col: [0x2c8a4a, 0x7cf0a2] },
  { id: 'bubbles', name: 'Pompas', desc: 'Explota las burbujas antes de que se escapen. Las doradas valen más.', icon: 'bubble', col: [0x1a78c2, 0x7fe0ff] },
  { id: 'simon', name: 'Simón marino', desc: 'Repite la melodía de las conchas sin equivocarte.', icon: 'brain', col: [0x6a2fb8, 0xffa8f0] },
];

export const NAMES = ['Gambi', 'Coral', 'Burbuja', 'Mochi', 'Nemo', 'Pinchito', 'Sushi', 'Canelo', 'Perla', 'Mini', 'Tito', 'Nube'];

export const TABS = [
  { id: 'food', name: 'Comida', list: FOODS },
  { id: 'chars', name: 'Especies', list: CHARS },
  { id: 'skins', name: 'Colores', list: SKINS },
  { id: 'hats', name: 'Gorros', list: HATS },
  { id: 'themes', name: 'Casa', list: THEMES },
];

/* ---------- reglas ---------- */
export const xpNeed = lv => 40 + lv * 28;
export const stageOf = lv => lv < 6 ? 0 : lv < 16 ? 1 : 2;           // 0 cría, 1 joven, 2 adulta
export const STAGE = [{ name: 'Cría', scale: .7 }, { name: 'Joven', scale: .9 }, { name: 'Adulta', scale: 1.05 }];
export const MAXLV = 40;
// puntos que se pierden por hora despierta; dormida sube la energía
export const DECAY = { food: 6.5, fun: 8.5, energy: 4.5, hyg: 4 };
export const SLEEP_RATE = 1.5;     // puntos de energía por segundo durmiendo
export const OFFLINE_CAP = 10 * 3600;

/* ---------- guardado ---------- */
const K = 'gambi.';
if (/[?&]reset\b/.test(location.search) && /[?&]shot\b/.test(location.search)) { try { Object.keys(localStorage).filter(k => k.startsWith(K)).forEach(k => localStorage.removeItem(k)); } catch (e) { } }
const get = (k, d) => { try { const v = JSON.parse(localStorage.getItem(K + k)); return v ?? d; } catch (e) { return d; } };
const set = (k, v) => { try { localStorage.setItem(K + k, JSON.stringify(v)); } catch (e) { } };
const DEF = {
  name: '', hatched: false, taps: 0,
  st: { food: 70, fun: 70, energy: 85, hyg: 80 }, t: Date.now(), sleeping: false,
  xp: 0, lv: 1, coins: 150,
  inv: {}, owned: {}, eq: { chars: 'gambita', skins: 'natural', hats: 'nada', themes: 'cuqui' },
  best: { catch: 0, bubbles: 0, simon: 0 }, daily: { last: '', streak: 0 },
  opt: { sfx: true, music: true, haptic: true, hq: true }, stats: { fed: 0, bathed: 0, played: 0, pets: 0 },
};
export const save = {};
for (const k of Object.keys(DEF)) save[k] = get(k, DEF[k]);
for (const k of ['st', 'eq', 'best', 'daily', 'opt', 'stats']) save[k] = Object.assign({}, DEF[k], save[k]);
for (const k of Object.keys(DEF.st)) if (!Number.isFinite(save.st[k])) save.st[k] = DEF.st[k];   // por si un valor guardado se corrompe
for (const k of ['coins', 'xp', 'lv']) if (!Number.isFinite(save[k])) save[k] = DEF[k];
for (const t of TABS) for (const it of t.list) if (!it.price) save.owned[t.id + ':' + it.id] = true;
export function persist() { save.t = Date.now(); for (const k of Object.keys(DEF)) set(k, save[k]); }
export const owns = (tab, id) => !!save.owned[tab + ':' + id];
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

// aplica el paso del tiempo (también el rato que la app ha estado cerrada)
export function tickStats(dtSec, awake = !save.sleeping) {
  const d = Math.max(0, dtSec) / 3600;
  const s = save.st, half = awake ? 1 : .5;
  s.food = clamp(s.food - DECAY.food * d * half, 0, 100);
  s.fun = clamp(s.fun - DECAY.fun * d * half, 0, 100);
  s.hyg = clamp(s.hyg - DECAY.hyg * d * half, 0, 100);
  s.energy = awake ? clamp(s.energy - DECAY.energy * d, 0, 100) : clamp(s.energy + SLEEP_RATE * dtSec, 0, 100);
}
export const mood = () => { const s = save.st, m = Math.min(s.food, s.fun, s.energy, s.hyg); return m < 20 ? 0 : m < 45 ? 1 : 2; };   // 0 mal, 1 regular, 2 bien
