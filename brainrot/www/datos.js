// Progresión de Brainrot Battle: niveles de personaje, cajas, campaña y especiales.
import { CHARS } from './personajes.js';
export { CHARS };

// cartas que hacen falta para subir del nivel n al n+1, y monedas que cuesta
export const CARDS_NEED = [2, 4, 10, 20, 50, 100, 200, 400, 800, 1000, 1500, 2000];
export const MAX_LV = CARDS_NEED.length + 1;
export const upCost = (lvl, rar) => Math.round([20, 50, 150, 400, 1000, 2000, 4000, 8000, 15000, 25000, 40000, 60000][lvl - 1] * [1, 1.5, 2.5, 4][rar]);
export const statAt = (base, lvl) => Math.round(base * Math.pow(1.1, lvl - 1));

// cajas sorpresa: prob = probabilidad de cada rareza (común, raro, épico, legendario)
export const BOXES = [
  { id: 'basica', name: 'Caja de madera', price: 150, cards: 4, prob: [.72, .24, .04, 0], col: '#c8864a' },
  { id: 'plata', name: 'Caja de plata', price: 900, cards: 12, prob: [.5, .34, .14, .02], col: '#c8d4e8' },
  { id: 'oro', name: 'Caja de oro', price: 4000, cards: 35, prob: [.32, .38, .24, .06], col: '#ffc83a', minRar: 2 },
];
export const FREE_BOX_H = 4;

// campaña: 60 niveles; el equipo enemigo sube de nivel poco a poco y cada 10 hay un jefe
export function stageTeam(n) {
  const pool = CHARS.map(c => c.id), lvl = 1 + Math.floor((n - 1) / 3.2), boss = n % 10 === 0;
  const rng = mulberry(n * 977), pick = () => pool[Math.floor(rng() * pool.length)];
  const team = [];
  if (boss) { const legend = CHARS.filter(c => c.rar >= 2); const b = legend[Math.floor(rng() * legend.length)]; team.push({ id: pick(), lvl }, { id: b.id, lvl: lvl + 2, boss: true }, { id: pick(), lvl }); }
  else for (let i = 0; i < 3; i++) { let id; do { id = pick(); } while (team.some(t => t.id === id)); team.push({ id, lvl: lvl + (rng() < Math.min(.6, n / 80) ? 1 : 0) }); }
  // los primeros niveles, más fáciles: solo comunes
  if (n <= 3) team.forEach((t, i) => t.id = ['patapim', 'bana', 'boneca'][(i + n) % 3]);
  return team;
}
export const stageReward = n => 40 + n * 14;
export const STAGE_NAMES = ['Playa de Tralala', 'Selva Bananini', 'Cafetería Cappuccina', 'Cielo de Bombardiro', 'Desierto Lirilì', 'Templo de Sahur'];
function mulberry(a) { return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

// especiales: kind = 'single' (un enemigo) | 'all' (todos) | 'heal' | 'shield'
export const SPECIALS = {
  tung: { kind: 'single', hits: 3, mult: .75 },
  trippi: { kind: 'single', hits: 1, mult: 2.3 },
  croco: { kind: 'all', hits: 1, mult: 1.05 },
  balle: { kind: 'heal', amount: .35 },
  trala: { kind: 'all', hits: 1, mult: .85 },
  lirili: { kind: 'shield', turns: 2 },
  bonbon: { kind: 'all', hits: 1, mult: .6, burn: 3 },
  patapim: { kind: 'single', hits: 1, mult: 1.6, stun: 1 },
  bana: { kind: 'single', hits: 2, mult: 1 },
  boneca: { kind: 'single', hits: 1, mult: 1.9 },
};
