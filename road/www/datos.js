// Catálogo y partida guardada de Shrimp Road (localStorage, prefijo «road.»).
export const CHARS = [
  { id: 'gambita', name: 'Gambita', price: 0, model: 'gamba', desc: 'La de siempre.' },
  { id: 'chulita', name: 'Gamba Chulita', price: 400, model: 'chaqueta', desc: 'Con su chaqueta de llamas.' },
  { id: 'langostino', name: 'Langostino', price: 700, model: 'langostino', desc: 'Salta enroscado.' },
  { id: 'limpiadora', name: 'Gamba Limpiadora', price: 1500, model: 'mysis', desc: 'Realista, con todas sus patitas.' },
];
export const HATS = [
  { id: 'nada', name: 'Sin gorro', price: 0 },
  { id: 'lazo', name: 'Lazo', price: 60 }, { id: 'flor', name: 'Flor', price: 70 }, { id: 'fiesta', name: 'Gorro de fiesta', price: 80 },
  { id: 'gorra', name: 'Gorra', price: 100 }, { id: 'gafas', name: 'Gafas de sol', price: 120 }, { id: 'auris', name: 'Auriculares', price: 150 },
  { id: 'cocinero', name: 'Cocinero', price: 180 }, { id: 'reno', name: 'Cuernos de reno', price: 200 }, { id: 'santa', name: 'Papá Noel', price: 220 },
  { id: 'chistera', name: 'Chistera', price: 250 }, { id: 'vikingo', name: 'Vikingo', price: 300 }, { id: 'bruja', name: 'Bruja', price: 320 },
  { id: 'mexicano', name: 'Sombrero mexicano', price: 350 }, { id: 'halo', name: 'Aureola', price: 400 }, { id: 'corona', name: 'Corona', price: 500 },
  { id: 'tiburon', name: 'Gorro Tiburón', price: 800 },
];
export const TABS = [{ id: 'chars', name: 'Personajes', list: CHARS }, { id: 'hats', name: 'Gorros', list: HATS }];

const K = 'road.';
const get = (k, d) => { try { const v = JSON.parse(localStorage.getItem(K + k)); return v ?? d; } catch (e) { return d; } };
const set = (k, v) => { try { localStorage.setItem(K + k, JSON.stringify(v)); } catch (e) { } };
const DEF = { coins: 0, best: 0, owned: {}, eq: { chars: 'gambita', hats: 'nada' }, opt: { sfx: true, music: true, haptic: true }, daily: { last: '', streak: 0 }, games: 0 };
export const save = {};
for (const k of Object.keys(DEF)) save[k] = get(k, DEF[k]);
for (const k of ['eq', 'opt', 'daily']) save[k] = Object.assign({}, DEF[k], save[k]);
for (const t of TABS) for (const it of t.list) if (!it.price) save.owned[t.id + ':' + it.id] = true;
export function persist() { for (const k of Object.keys(DEF)) set(k, save[k]); }
export const owns = (tab, id) => !!save.owned[tab + ':' + id];
