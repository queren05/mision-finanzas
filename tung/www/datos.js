// Catálogo de la tienda y partida guardada (localStorage, prefijo «tung3.»).

export const CHARS = [
  { id: 'gambita', name: 'Gambita', icon: '🦐', price: 0, model: 'gamba', desc: 'La gamba original. Pequeña, rápida y con muchas patas.' },
  { id: 'langostino', name: 'Langostino', icon: '🦞', price: 1200, model: 'langostino', desc: 'Recién salido de la plancha. Corre enroscado, a saltitos.' },
  { id: 'chulita', name: 'Gamba Chulita', icon: '🧥', price: 2500, model: 'chaqueta', desc: 'Chaqueta de llamas y barritas de luz. Celebra a lo grande.' },
  { id: 'limpiadora', name: 'Gamba Limpiadora', icon: '🦐', price: 4000, model: 'mysis', desc: 'Una gamba de verdad, realista, con sus veinte patitas corriendo.' },
];

// h: giro de tono (radianes), s: saturación, v: brillo. Extras: ghost, shine, rainbow.
export const SKINS = [
  { id: 'natural', name: 'Natural', price: 0, sw: '#ee9a6d', p: { h: 0, s: 1, v: 1 } },
  { id: 'cocida', name: 'Cocida', price: 300, sw: '#f0442c', p: { h: -.045, s: 1.7, v: .95 } },
  { id: 'chicle', name: 'Chicle', price: 350, sw: '#ff7ac8', p: { h: -.13, s: 1.05, v: 1.1 } },
  { id: 'lima', name: 'Lima', price: 400, sw: '#a6e04a', p: { h: .22, s: 1.2, v: 1 } },
  { id: 'carbon', name: 'Carbón', price: 450, sw: '#3a3a44', p: { h: 0, s: .15, v: .42 } },
  { id: 'tropical', name: 'Tropical', price: 500, sw: '#34d1a8', p: { h: .43, s: 1.15, v: 1 } },
  { id: 'real', name: 'Azul real', price: 600, sw: '#4f7dff', p: { h: .57, s: 1.25, v: .95 } },
  { id: 'uva', name: 'Uva', price: 700, sw: '#9b5cff', p: { h: .72, s: 1.2, v: .95 } },
  { id: 'fantasma', name: 'Fantasma', price: 1200, sw: '#cdeeff', p: { h: .47, s: .35, v: 1.3, ghost: 1 } },
  { id: 'dorada', name: 'Dorada', price: 1800, sw: '#ffd23f', p: { h: .085, s: 1.5, v: 1.15, shine: 1 } },
  { id: 'arcoiris', name: 'Arcoíris', price: 3000, sw: 'conic-gradient(#ff5a5a,#ffd84a,#5ae07a,#4fb2ff,#b45aff,#ff5a5a)', p: { h: 0, s: 1.3, v: 1.05, rainbow: 1 } },
];

export const HATS = [
  { id: 'nada', name: 'Sin gorro', icon: '🚫', price: 0 },
  { id: 'fiesta', name: 'Gorro de fiesta', icon: '🎉', price: 200 },
  { id: 'gorra', name: 'Gorra', icon: '🧢', price: 300 },
  { id: 'gafas', name: 'Gafas de sol', icon: '🕶️', price: 400 },
  { id: 'auris', name: 'Auriculares', icon: '🎧', price: 550 },
  { id: 'chistera', name: 'Chistera', icon: '🎩', price: 700 },
  { id: 'vikingo', name: 'Casco vikingo', icon: '🪖', price: 900 },
  { id: 'halo', name: 'Aureola', icon: '😇', price: 1000 },
  { id: 'corona', name: 'Corona', icon: '👑', price: 1500 },
  { id: 'tiburon', name: 'Gorro Tiburón', icon: '🦈', price: 2000, desc: 'El disfraz de tiburón más famoso de internet.' },
];

export const TRAILS = [
  { id: 'polvo', name: 'Polvo', icon: '💨', price: 0 },
  { id: 'burbujas', name: 'Burbujas', icon: '🫧', price: 300 },
  { id: 'chispas', name: 'Chispas', icon: '✨', price: 450 },
  { id: 'corazones', name: 'Corazones', icon: '💖', price: 700 },
  { id: 'hielo', name: 'Escarcha', icon: '❄️', price: 900 },
  { id: 'fuego', name: 'Fuego', icon: '🔥', price: 1000 },
  { id: 'arcoiris', name: 'Arcoíris', icon: '🌈', price: 2000 },
];

// Potenciadores que salen en la carrera; cada nivel alarga su duración.
export const UPGRADES = [
  { id: 'iman', name: 'Imán', icon: '🧲', base: 7, step: 2.5, desc: 'Atrae las monedas de los tres carriles.' },
  { id: 'escudo', name: 'Escudo', icon: '🛡️', base: 9, step: 3, desc: 'Aguanta un golpe sin tropezar.' },
  { id: 'x2', name: 'Monedas ×2', icon: '💰', base: 8, step: 2.5, desc: 'Cada moneda vale el doble.' },
  { id: 'salto', name: 'Supersalto', icon: '🦘', base: 8, step: 2.5, desc: 'Saltos altísimos para coger las monedas del aire.' },
  { id: 'turbo', name: 'Turbo', icon: '🚀', base: 4, step: 1.3, desc: 'Vas a tope y atraviesas todo lo que pilles.' },
];
export const UPGRADE_COST = [250, 600, 1200, 2500, 5000];

export const MULTS = [
  { id: 'mult', name: 'Multiplicador', icon: '✖️', max: 9, base: 400, k: 1.7, desc: 'Suma +1 al multiplicador de puntos (hasta ×10).' },
  { id: 'valor', name: 'Monedas extra', icon: '🪙', max: 5, base: 500, k: 1.9, desc: '+20 % de monedas al final de cada partida.' },
  { id: 'suerte', name: 'Suerte', icon: '🍀', max: 5, base: 450, k: 1.8, desc: 'Salen potenciadores más a menudo.' },
  { id: 'aguante', name: 'Aguante', icon: '💪', max: 5, base: 400, k: 1.8, desc: 'Te recuperas antes de un tropiezo: Tung tarda más en pillarte.' },
];
export const multCost = (m, lv) => Math.round(m.base * Math.pow(m.k, lv) / 10) * 10;

export const ITEMS = [
  { id: 'vida', name: 'Salvavidas', icon: '❤️‍🩹', price: 600, desc: 'Cuando te pille Tung, sigue corriendo donde lo dejaste.' },
  { id: 'cohete', name: 'Salida cohete', icon: '🚀', price: 350, desc: 'Empieza la partida con un turbo largo.' },
  { id: 'escudoIni', name: 'Escudo inicial', icon: '🛡️', price: 250, desc: 'Empieza la partida con escudo.' },
  { id: 'dobleIni', name: 'Monedas ×2 inicial', icon: '💰', price: 300, desc: 'Empieza con monedas dobles durante 20 s.' },
];

export const MAPS = [
  { id: 'selva', name: 'Selva Sahur', icon: '🌴', price: 0, desc: 'Senderos de tierra, troncos y rocas entre árboles gigantes.' },
  { id: 'ciudad', name: 'Ciudad Tung', icon: '🏙️', price: 1500, desc: 'Calles entre rascacielos, vallas de obra y coches que vienen de frente.' },
];

export const TABS = [
  { id: 'chars', name: '🦐 Personajes', list: CHARS },
  { id: 'skins', name: '🎨 Colores', list: SKINS },
  { id: 'hats', name: '🎩 Gorros', list: HATS },
  { id: 'trails', name: '✨ Estelas', list: TRAILS },
  { id: 'ups', name: '⚡ Mejoras', list: UPGRADES },
  { id: 'mults', name: '✖️ Multiplicadores', list: MULTS },
  { id: 'items', name: '🎒 Objetos', list: ITEMS },
  { id: 'maps', name: '🗺️ Mapas', list: MAPS },
];

/* ---------- guardado ---------- */
const K = 'tung3.';
const get = (k, d) => { try { const v = JSON.parse(localStorage.getItem(K + k)); return v ?? d; } catch (e) { return d; } };
const set = (k, v) => { try { localStorage.setItem(K + k, JSON.stringify(v)); } catch (e) { } };

export const save = {
  bank: get('bank', null),
  best: get('best', 0),
  bestD: get('bestD', 0),
  owned: get('owned', {}),
  eq: get('eq', {}),
  lv: get('lv', {}),
  items: get('items', {}),
  use: get('use', {}),
  opt: get('opt', {}),
  daily: get('daily', { last: '', streak: 0 }),
  stats: get('stats', { runs: 0, coins: 0, dist: 0 }),
};
// Migración desde la versión 2D (tung.bank / tung.best)
if (save.bank === null) {
  let old = 0; try { old = JSON.parse(localStorage.getItem('tung.bank')) || 0; } catch (e) { }
  save.bank = old + 150;   // regalo de bienvenida a la versión 3D
  try { const ob = JSON.parse(localStorage.getItem('tung.best')) || 0; save.bestD = Math.max(save.bestD, ob); } catch (e) { }
}
save.eq = Object.assign({ chars: 'gambita', skins: 'natural', hats: 'nada', trails: 'polvo', maps: 'selva' }, save.eq);
// Personajes retirados (Ebi y Gamba Gafitas): si alguien los había comprado se le devuelven las monedas
{
  const RETIRED = { ebi: 800, gafitas: 1800 }; let refund = 0;
  for (const [id, price] of Object.entries(RETIRED)) { if (save.owned['chars:' + id]) { refund += price; delete save.owned['chars:' + id]; } if (save.eq.chars === id) save.eq.chars = 'gambita'; }
  if (refund) { save.bank += refund; try { localStorage.setItem(K + 'bank', JSON.stringify(save.bank)); localStorage.setItem(K + 'owned', JSON.stringify(save.owned)); localStorage.setItem(K + 'eq', JSON.stringify(save.eq)); } catch (e) { } }
  if (!CHARS.some(c => c.id === save.eq.chars)) save.eq.chars = 'gambita';
}
save.opt = Object.assign({ sfx: true, music: true, haptic: true, hq: true }, save.opt);
for (const t of TABS) for (const it of t.list) if (it.price === 0) save.owned[t.id + ':' + it.id] = true;

export function persist() {
  for (const k of Object.keys(save)) set(k, save[k]);
}
export const owns = (tab, id) => !!save.owned[tab + ':' + id];
export const level = id => save.lv[id] || 0;
export const upDur = u => u.base + u.step * level(u.id);
export const scoreMult = () => 1 + level('mult');
