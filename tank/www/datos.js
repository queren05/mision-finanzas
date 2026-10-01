// Datos de Shrimp Tank: especies, mejoras y decoración. Las monedas son por segundo.
// tint: color que multiplica la textura de la gamba; fx: 'ghost' | 'gold' | 'rainbow'
export const SPECIES = [
  { id: 'comun', name: 'Gamba común', model: 'gamba', price: 15, rate: 1, tint: 0xffffff, desc: 'La de toda la vida.' },
  { id: 'cereza', name: 'Gamba cereza', model: 'gamba', price: 250, rate: 7, tint: 0xff4a4a, desc: 'Roja como una cereza.' },
  { id: 'azul', name: 'Gamba azul', model: 'gamba', price: 2500, rate: 40, tint: 0x7ac0ff, desc: 'Del color del mar profundo.' },
  { id: 'amarilla', name: 'Gamba limón', model: 'gamba', price: 25000, rate: 220, tint: 0xffe04a, desc: 'Brilla como el sol.' },
  { id: 'chaqueta', name: 'Gamba chaqueta', model: 'chaqueta', price: 220000, rate: 1200, tint: 0xffffff, desc: 'Con su chupa de cuero.' },
  { id: 'tigre', name: 'Gamba tigre', model: 'gamba', price: 2e6, rate: 6500, tint: 0xff8a2a, desc: 'Naranja y salvaje.' },
  { id: 'langostino', name: 'Langostino', model: 'langostino', price: 2e7, rate: 36000, tint: 0xffffff, desc: 'El jefe de la pecera.' },
  { id: 'fantasma', name: 'Gamba fantasma', model: 'gamba', price: 2e8, rate: 2e5, tint: 0xd8f4ff, fx: 'ghost', desc: 'Casi transparente.' },
  { id: 'dorada', name: 'Gamba dorada', model: 'gamba', price: 2.5e9, rate: 1.2e6, tint: 0xffc83a, fx: 'gold', desc: 'Vale su peso en oro.' },
  { id: 'arcoiris', name: 'Gamba arcoíris', model: 'gamba', price: 4e10, rate: 8e6, tint: 0xffffff, fx: 'rainbow', desc: 'Cambia de color sin parar.' },
];
export const speciesPrice = (sp, owned) => Math.round(sp.price * Math.pow(1.32, owned));
// nivel de una gamba: producción y precio de subirla
export const shrimpRate = (sp, lvl) => sp.rate * (1 + (lvl - 1) * .4) * Math.pow(2, Math.floor(lvl / 10));
export const levelCost = (sp, lvl) => Math.round(sp.price * .45 * Math.pow(1.19, lvl - 1) + 5);

export const UPGRADES = [
  { id: 'filtro', name: 'Filtro', desc: '+20 % de monedas por nivel', max: 15, base: 400, k: 2.4 },
  { id: 'luz', name: 'Luces LED', desc: '+15 % de monedas por nivel', max: 15, base: 1500, k: 2.6 },
  { id: 'capacidad', name: 'Pecera más grande', desc: '+2 huecos para gambas', max: 12, base: 120, k: 2.2 },
  { id: 'comedero', name: 'Comedero automático', desc: 'Echa comida solo cada cierto tiempo', max: 5, base: 3000, k: 4 },
  { id: 'toque', name: 'Toque mágico', desc: 'Tocar una gamba da más monedas', max: 15, base: 200, k: 2.3 },
  { id: 'bomba', name: 'Bomba de aire', desc: '+2 h de ganancias mientras no juegas', max: 5, base: 5000, k: 3.5 },
];
export const upCost = (u, lvl) => Math.round(u.base * Math.pow(u.k, lvl));

// decoración: cada pieza se compra una vez y da un % extra
export const DECOR = [
  { id: 'algas', name: 'Algas', price: 60, bonus: .05, kind: 'algas' },
  { id: 'rocas', name: 'Rocas', price: 600, bonus: .08, kind: 'rocks-sand-a', at: [-.95, -.35], s: .14, ry: .4 },
  { id: 'coral', name: 'Coral', price: 5000, bonus: .10, kind: 'coral' },
  { id: 'barril', name: 'Barril', price: 30000, bonus: .12, kind: 'barrel', at: [1.05, -.4], s: .2, ry: .3, tilt: 1.3 },
  { id: 'cofre', name: 'Cofre del tesoro', price: 150000, bonus: .15, kind: 'chest', at: [-.25, .25], s: .22, ry: -.3 },
  { id: 'canon', name: 'Cañón hundido', price: 900000, bonus: .18, kind: 'cannon', at: [.75, .3], s: .2, ry: -2.3 },
  { id: 'botella', name: 'Botella con mensaje', price: 6e6, bonus: .20, kind: 'bottle-large', at: [-1.2, .3], s: .35, ry: .5, tilt: 1.45 },
  { id: 'torre', name: 'Torre del castillo', price: 4e7, bonus: .25, kind: 'tower-complete-small', at: [1.2, -.45], s: .13, ry: .6 },
  { id: 'barca', name: 'Barca hundida', price: 3e8, bonus: .30, kind: 'boat-row-small', at: [.15, -.5], s: .26, ry: .2, tilt: .35 },
  { id: 'barco', name: 'Barco pirata hundido', price: 3e9, bonus: .45, kind: 'ship-wreck', at: [-.85, -.45], s: .11, ry: .8 },
  { id: 'fantasma', name: 'Barco fantasma', price: 5e10, bonus: .70, kind: 'ship-ghost', at: [.6, -.52], s: .09, ry: -.6 },
];

const UNITS = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx'];
export function fmt(n) {
  if (n < 1000) return n < 10 && n % 1 ? n.toFixed(1).replace('.', ',') : String(Math.floor(n));
  let u = 0; while (n >= 1000 && u < UNITS.length - 1) { n /= 1000; u++; }
  return (n < 10 ? n.toFixed(2) : n < 100 ? n.toFixed(1) : Math.floor(n).toString()).replace('.', ',') + UNITS[u];
}
export function fmtTime(s) { s = Math.floor(s); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? `${h} h ${m} min` : m ? `${m} min` : `${s} s`; }
