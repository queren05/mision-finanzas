// Datos de Shrimp Tank: especies, evoluciones, mejoras, decoración y temporadas. Las monedas son por segundo.
// La progresión está pensada para semanas: cada especie cuesta ~20-40 veces más que la anterior.
// tint: color de la gamba; fx: 'ghost' | 'gold' | 'rainbow'
export const SPECIES = [
  { id: 'comun', name: 'Gamba común', model: 'gamba', price: 50, rate: 1, tint: 0xffffff, desc: 'La de toda la vida.' },
  { id: 'cereza', name: 'Gamba cereza', model: 'gamba', price: 1500, rate: 9, tint: 0xff4a4a, desc: 'Roja como una cereza.' },
  { id: 'azul', name: 'Gamba azul', model: 'gamba', price: 3e4, rate: 70, tint: 0x7ac0ff, desc: 'Del color del mar profundo.' },
  { id: 'amarilla', name: 'Gamba limón', model: 'gamba', price: 6e5, rate: 480, tint: 0xffe04a, desc: 'Brilla como el sol.' },
  { id: 'chaqueta', name: 'Gamba chaqueta', model: 'chaqueta', price: 1.2e7, rate: 3500, tint: 0xffffff, desc: 'Con su chupa de cuero.' },
  { id: 'tigre', name: 'Gamba tigre', model: 'gamba', price: 2.5e8, rate: 26000, tint: 0xff8a2a, desc: 'Naranja y salvaje.' },
  { id: 'langostino', name: 'Langostino', model: 'langostino', price: 5e9, rate: 2e5, tint: 0xffffff, desc: 'El jefe de la pecera.' },
  { id: 'fantasma', name: 'Gamba fantasma', model: 'gamba', price: 1e11, rate: 1.5e6, tint: 0xd8f4ff, fx: 'ghost', desc: 'Casi transparente.' },
  { id: 'dorada', name: 'Gamba dorada', model: 'gamba', price: 2.5e12, rate: 1.2e7, tint: 0xffc83a, fx: 'gold', desc: 'Vale su peso en oro.' },
  { id: 'arcoiris', name: 'Gamba arcoíris', model: 'gamba', price: 7e13, rate: 1e8, tint: 0xffffff, fx: 'rainbow', desc: 'Cambia de color sin parar.' },
];
export const speciesPrice = (sp, owned) => Math.round(sp.price * Math.pow(1.55, owned));

// evoluciones: cada etapa tiene un nivel máximo; para seguir subiendo hay que evolucionar
export const EVO = [
  { name: 'Cría', cap: 10, mult: 1, size: 1, cost: 0 },
  { name: 'Joven', cap: 25, mult: 4, size: 1.12, cost: 8 },
  { name: 'Adulta', cap: 50, mult: 16, size: 1.25, cost: 60 },
  { name: 'Reina', cap: 100, mult: 64, size: 1.4, cost: 500 },
];
export const shrimpRate = (sp, lvl, st = 0) => sp.rate * (1 + (lvl - 1) * .3) * EVO[st].mult;
export const levelCost = (sp, lvl, st = 0) => Math.round(sp.price * .35 * Math.pow(1.21, lvl - 1) * (1 + st * .6) + 5);
export const evoCost = (sp, st) => Math.round(sp.price * EVO[st].cost);   // coste para llegar a la etapa st
export const sellValue = (sp, lvl, st = 0) => Math.round(sp.price * .3 * Math.pow(EVO[st].mult, .55) * (1 + lvl * .04));

export const UPGRADES = [
  { id: 'filtro', name: 'Filtro', desc: '+15 % de monedas por nivel', max: 20, base: 2000, k: 2.7 },
  { id: 'luz', name: 'Luces LED', desc: '+10 % de monedas por nivel', max: 20, base: 8000, k: 2.9 },
  { id: 'capacidad', name: 'Pecera más grande', desc: '+1 hueco para gambas', max: 17, base: 300, k: 2.6 },
  { id: 'comedero', name: 'Comedero automático', desc: 'Echa comida solo cada cierto tiempo', max: 5, base: 4e4, k: 5 },
  { id: 'toque', name: 'Toque mágico', desc: 'Tocar una gamba da más monedas', max: 20, base: 500, k: 2.5 },
  { id: 'bomba', name: 'Bomba de aire', desc: '+1 h de ganancias mientras no juegas', max: 10, base: 2e4, k: 3.2 },
];
export const upCost = (u, lvl) => Math.round(u.base * Math.pow(u.k, lvl));

// decoración: cada pieza se compra una vez y da un % extra
export const DECOR = [
  { id: 'algas', name: 'Algas', price: 600, bonus: .05, kind: 'algas' },
  { id: 'rocas', name: 'Rocas', price: 6000, bonus: .08, kind: 'rocks-sand-a', at: [-.95, -.35], s: .14, ry: .4 },
  { id: 'coral', name: 'Coral', price: 5e4, bonus: .10, kind: 'coral' },
  { id: 'barril', name: 'Barril', price: 4e5, bonus: .12, kind: 'barrel', at: [1.05, -.4], s: .2, ry: .3, tilt: 1.3 },
  { id: 'cofre', name: 'Cofre del tesoro', price: 3e6, bonus: .15, kind: 'chest', at: [-.25, .25], s: .22, ry: -.3 },
  { id: 'canon', name: 'Cañón hundido', price: 2e7, bonus: .18, kind: 'cannon', at: [.75, .3], s: .2, ry: -2.3 },
  { id: 'botella', name: 'Botella con mensaje', price: 1.5e8, bonus: .20, kind: 'bottle-large', at: [-1.2, .3], s: .35, ry: .5, tilt: 1.45 },
  { id: 'torre', name: 'Torre del castillo', price: 1e9, bonus: .25, kind: 'tower-complete-small', at: [1.2, -.45], s: .13, ry: .6 },
  { id: 'barca', name: 'Barca hundida', price: 1e10, bonus: .30, kind: 'boat-row-small', at: [.15, -.5], s: .26, ry: .2, tilt: .35 },
  { id: 'barco', name: 'Barco pirata hundido', price: 1.5e11, bonus: .45, kind: 'ship-wreck', at: [-.85, -.45], s: .11, ry: .8 },
  { id: 'fantasma', name: 'Barco fantasma', price: 3e12, bonus: .70, kind: 'ship-ghost', at: [.6, -.52], s: .09, ry: -.6 },
];

// temporadas: empezar de cero a cambio de perlas, que suben las monedas para siempre
export const pearlsFor = total => Math.floor(Math.sqrt(total / 5e6));
export const pearlBonus = .12;

const UNITS = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx'];
export function fmt(n) {
  if (n < 1000) return n < 10 && n % 1 ? n.toFixed(1).replace('.', ',') : String(Math.floor(n));
  let u = 0; while (n >= 1000 && u < UNITS.length - 1) { n /= 1000; u++; }
  return (n < 10 ? n.toFixed(2) : n < 100 ? n.toFixed(1) : Math.floor(n).toString()).replace('.', ',') + UNITS[u];
}
export function fmtTime(s) { s = Math.floor(s); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? `${h} h ${m} min` : m ? `${m} min` : `${s} s`; }
