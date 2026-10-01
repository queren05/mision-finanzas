// Escenarios, vehículos, mejoras y misiones de Shrimp Hill Climb.
// La dificultad sube con la distancia: D(x) va de 0 (salida) a 1 (muy lejos).
const ease = x => x < 8 ? 0 : Math.min(1, (x - 8) / 14);
const D = (x, L = 2600) => Math.min(1, Math.max(0, x) / L);
const mod = (x, m) => ((x % m) + m) % m;
const bump = (x, m, at, w, h) => { const c = mod(x, m); return c > at && c < at + w ? Math.sin((c - at) / w * Math.PI) * h : 0; };
const crater = (x, m, w, h) => { const c = mod(x, m); return c < w ? -Math.sin(c / w * Math.PI) * h : 0; };

// grip: agarre del suelo · g: gravedad · air: giro en el aire · drag: freno del agua
// hazard: 'gap' (vacío) | 'lava' | null · pit(x): ¿hay agujero/lava aquí?
export const STAGES = [
  { id: 'campo', name: 'Campo', price: 0, g: 14, grip: 1, air: 1, fuel: 1, info: 'Colinas verdes. Para empezar.',
    sky: ['#4fb8ff', '#cdeeff', '#fff6d8'], top: [0x5fbf4a, 0x4aa63a], dirt: 0xa86d3e, deep: 0x6b4426, far: [0x8fd07a, 0x7fc46a], deco: 'campo',
    hgt: x => ease(x) * (.5 + 2 * D(x)) * (1.3 * Math.sin(x * .15) + .75 * Math.sin(x * .36 + 1) + .3 * Math.sin(x * .83 + 2)) + ease(x) * D(x, 1500) * bump(x, 31, 20, 1.6, .45) },
  { id: 'desierto', name: 'Desierto', price: 1500, g: 14, grip: .78, air: 1, fuel: 1.1, info: 'Dunas largas. La arena resbala.',
    sky: ['#ffb24a', '#ffe0a0', '#fff2d0'], top: [0xf0c878, 0xe8bc68], dirt: 0xd8a050, deep: 0xa86d2e, far: [0xe8b060, 0xd89a4a], deco: 'desierto',
    hgt: x => ease(x) * (.8 + 2.6 * D(x)) * (1.4 * Math.sin(x * .07) + .6 * Math.sin(x * .19 + 1)) + .08 * Math.sin(x * 2.1) * ease(x) },
  { id: 'bosque', name: 'Bosque', price: 4000, g: 14, grip: .95, air: 1, fuel: 1, info: 'Cuestas empinadas y raíces que te hacen botar.',
    sky: ['#3a8ad0', '#9ad0e8', '#d8f0e0'], top: [0x3a8a3a, 0x2f7a32], dirt: 0x6a4a2a, deep: 0x3a2814, far: [0x2a6a3a, 0x1f5a30], deco: 'bosque',
    hgt: x => ease(x) * (.7 + 2.5 * D(x)) * (1.2 * Math.sin(x * .18) + .8 * Math.sin(x * .41 + 2) + .35 * Math.sin(x * .97)) + ease(x) * (bump(x, 23, 10, .9, .25 + .2 * D(x)) + bump(x, 37, 5, 1.1, .3)) },
  { id: 'playa', name: 'Playa', price: 8000, g: 14, grip: .82, air: 1.1, fuel: 1, info: 'Rampas de madera para saltar muy lejos.',
    sky: ['#38b8ff', '#a8ecff', '#fff8e0'], top: [0xf6dca0, 0xeed090], dirt: 0xe0bc78, deep: 0xb8904a, far: [0x2ab0d8, 0x1a98c8], deco: 'playa',
    hgt: x => { const base = ease(x) * (.35 + 1.3 * D(x)) * (Math.sin(x * .12) + .4 * Math.sin(x * .33)); const c = mod(x, 58), H = 1 + 1.3 * D(x); if (x > 40 && c > 40 && c < 48) return base + (c - 40) / 8 * H; if (x > 40 && c >= 48 && c < 49.2) return base + H * (1 - (c - 48) / 1.2); return base; } },
  { id: 'artico', name: 'Ártico', price: 14000, g: 14, grip: .5, air: 1, fuel: 1.15, info: 'Hielo: casi no hay agarre. Frena con cuidado.',
    sky: ['#7ab8e8', '#d8f0ff', '#ffffff'], top: [0xf4faff, 0xe0f0ff], dirt: 0xb8d8f0, deep: 0x7aa8d0, far: [0xd0e8ff, 0xb8d8f8], deco: 'artico',
    hgt: x => ease(x) * (.55 + 2.3 * D(x)) * (1.5 * Math.sin(x * .11) + .7 * Math.sin(x * .29 + 1) + .2 * Math.sin(x * 1.1)) },
  { id: 'fondo', name: 'Fondo del mar', price: 22000, g: 7.5, grip: .85, air: 1.3, drag: .35, fuel: 1, info: 'Bajo el agua todo flota y va despacio. ¡Territorio gamba!',
    sky: ['#0a3a6a', '#1a6aa8', '#2a8ac8'], top: [0xe8d8a8, 0xd8c890], dirt: 0xb8a070, deep: 0x7a6a48, far: [0x1a5a88, 0x145080], deco: 'fondo',
    hgt: x => ease(x) * (.8 + 2.4 * D(x)) * (1.3 * Math.sin(x * .1) + .8 * Math.sin(x * .27 + 2) + .25 * Math.sin(x * .8)) },
  { id: 'volcan', name: 'Volcán', price: 35000, g: 15, grip: 1, air: 1, fuel: 1.1, hazard: 'lava', info: 'Pozos de lava: si caes dentro, te quemas.',
    sky: ['#2a0a0a', '#7a2010', '#ff6a2a'], top: [0x3a3030, 0x2e2626], dirt: 0x4a3a34, deep: 0x1a1210, far: [0x2a1a18, 0x1f1412], deco: 'volcan',
    pit: x => { if (x < 45) return false; const c = mod(x, 47); return c > 30 && c < 30 + 2.2 + 3.5 * D(x); },
    hgt(x) { const b = ease(x) * (.8 + 1.6 * D(x)) * (1.2 * Math.sin(x * .13) + .6 * Math.sin(x * .31 + 1)); if (this.pit(x)) { const c = mod(x, 47) - 30, w = 2.2 + 3.5 * D(x); return b - 3.2 * Math.min(1, Math.min(c, w - c) / .35); } return b; } },
  { id: 'ciudad', name: 'Ciudad', price: 55000, g: 14, grip: 1.05, air: 1, fuel: 1, hazard: 'gap', info: 'Rampas y huecos sobre el vacío. Hay que ir rápido.',
    sky: ['#ff8aa8', '#ffc8a0', '#fff0d0'], top: [0x5a5a64, 0x52525c], dirt: 0x8a8a94, deep: 0x4a4a54, far: [0x6a5a7a, 0x5a4a6a], deco: 'ciudad',
    pit: x => { if (x < 50) return false; const c = mod(x, 72); return c > 57 && c < 57 + 2.8 + 4.5 * D(x); },
    hgt(x) { const base = ease(x) * (.3 + .9 * D(x)) * (Math.sin(x * .09) + .5 * Math.sin(x * .23)); if (this.pit(x)) return -40; const c = mod(x, 72), H = 1.1 + .9 * D(x); if (x > 50 && c > 50 && c <= 57) return base + Math.pow((c - 50) / 7, 1.4) * H; return base; } },
  { id: 'marte', name: 'Marte', price: 85000, g: 9, grip: .9, air: 1.2, fuel: 1.1, info: 'Gravedad baja y cráteres por todas partes.',
    sky: ['#3a1a20', '#a8503a', '#e8986a'], top: [0xc8603a, 0xb85434], dirt: 0x9a4a2e, deep: 0x5a2a1a, far: [0x8a3a28, 0x7a3020], deco: 'marte',
    hgt: x => ease(x) * ((.7 + 2.4 * D(x)) * (1.5 * Math.sin(x * .09) + .8 * Math.sin(x * .23 + 2) + .3 * Math.sin(x * .7)) + (x > 20 ? crater(x, 29, 6, .7 + .5 * D(x)) : 0)) },
  { id: 'luna', name: 'Luna', price: 130000, g: 6, grip: .85, air: 1.4, fuel: 1.2, info: 'Poca gravedad: saltos enormes. ¡Cuidado con volcar!',
    sky: ['#05060f', '#0d1030', '#1a1d40'], top: [0xb9bcc6, 0xa8abb6], dirt: 0x8a8d98, deep: 0x4a4d58, far: [0x3a3d4a, 0x2e313c], deco: 'luna',
    hgt: x => ease(x) * ((.7 + 2 * D(x)) * (1.8 * Math.sin(x * .085) + .9 * Math.sin(x * .22 + 2) + .25 * Math.sin(x * .9)) + (x > 20 ? crater(x, 37, 5, .55 + .4 * D(x)) : 0)) },
];

// drive: 'rwd' tracción trasera · 'fwd' delantera · '4x4'
// engine: empuje · vmax: velocidad máx. (m/s) · mu: agarre de las ruedas · air: giro en el aire · k/c: suspensión · tank: litros · cons: consumo · up: precio base de las mejoras
export const CARS = [
  { id: 'abuelo', name: 'Coche del abuelo', file: 'sedan', price: 0, up: 60, wb: 1.75, engine: 12, vmax: 8.5, mu: .8, air: 2.2, k: 105, c: 9, tank: 50, cons: 1, drive: 'rwd', desc: 'Viejo, lento y con poca gasolina. Algo es algo.' },
  { id: 'kart', name: 'Kart', file: 'kart', price: 1200, up: 110, wb: 1.4, engine: 16, vmax: 12, mu: .85, air: 4.5, k: 125, c: 9, tank: 42, cons: .85, drive: 'rwd', desc: 'Ligero y ágil, pero el depósito es diminuto.' },
  { id: 'furgo', name: 'Furgoneta', file: 'van', price: 2500, up: 170, wb: 1.9, engine: 14.5, vmax: 10, mu: .88, air: 2, k: 115, c: 12, tank: 85, cons: 1.1, drive: 'rwd', desc: 'Pesada y lenta, pero llega lejos.' },
  { id: 'taxi', name: 'Taxi', file: 'taxi', price: 4000, up: 240, wb: 1.75, engine: 17, vmax: 13, mu: .92, air: 3.2, k: 125, c: 12, tank: 65, cons: 1, drive: 'rwd', desc: 'Equilibrado. ¡Al aeropuerto!' },
  { id: 'todoterreno', name: 'Todoterreno', file: 'suv', price: 7000, up: 380, wb: 1.75, engine: 18, vmax: 12.5, mu: 1.05, air: 3.2, k: 100, c: 13, tank: 72, cons: 1.05, drive: '4x4', desc: '4x4: sube cuestas que otros no pueden.' },
  { id: 'reparto', name: 'Reparto', file: 'delivery', price: 9500, up: 450, wb: 1.9, engine: 17, vmax: 11.5, mu: .98, air: 2.6, k: 115, c: 13, tank: 115, cons: 1.15, drive: 'rwd', desc: 'Depósito enorme para viajes largos.' },
  { id: 'deportivo', name: 'Deportivo', file: 'hatchback-sports', price: 13000, up: 600, wb: 1.75, engine: 23, vmax: 17, mu: .98, air: 3.8, k: 140, c: 12, tank: 62, cons: 1.2, drive: 'fwd', desc: 'Tracción delantera: rápido y no se encabrita.' },
  { id: 'tractor', name: 'Tractor', file: 'tractor', price: 17000, up: 720, wb: 1.6, engine: 25, vmax: 9, mu: 1.35, air: 2.8, k: 135, c: 15, tank: 80, cons: 1, drive: 'rwd', desc: 'Lento, pero trepa por donde sea.' },
  { id: 'ambulancia', name: 'Ambulancia', file: 'ambulance', price: 23000, up: 900, wb: 1.95, engine: 21, vmax: 14, mu: 1.02, air: 2.8, k: 120, c: 14, tank: 95, cons: 1.1, drive: 'rwd', desc: 'Grande y estable. ¡Nunu nunu!' },
  { id: 'policia', name: 'Policía', file: 'police', price: 31000, up: 1200, wb: 1.75, engine: 26, vmax: 18, mu: 1.05, air: 3.8, k: 140, c: 13, tank: 75, cons: 1.15, drive: 'rwd', desc: 'Potente y con mucho nervio.' },
  { id: 'bomberos', name: 'Bomberos', file: 'firetruck', price: 45000, up: 1600, wb: 2.1, engine: 29, vmax: 13, mu: 1.12, air: 2.1, k: 140, c: 16, tank: 150, cons: 1.4, drive: '4x4', desc: 'Un monstruo 4x4 con un depósito gigante.' },
  { id: 'muscle', name: 'Muscle car', file: 'sedan-sports', price: 62000, up: 2000, wb: 1.75, engine: 32, vmax: 21, mu: 1, air: 4.2, k: 150, c: 13, tank: 80, cons: 1.3, drive: 'rwd', desc: 'Puro músculo. Ojo con los caballitos.' },
  { id: 'excavadora', name: 'Excavadora', file: 'tractor-shovel', price: 82000, up: 2500, wb: 1.7, engine: 33, vmax: 9.5, mu: 1.5, air: 2.4, k: 130, c: 16, tank: 120, cons: 1.2, drive: '4x4', desc: 'El rey de las cuestas imposibles.' },
  { id: 'lujo', name: 'SUV de lujo', file: 'suv-luxury', price: 110000, up: 3200, wb: 1.8, engine: 31, vmax: 18, mu: 1.2, air: 4, k: 115, c: 14, tank: 110, cons: 1.15, drive: '4x4', desc: 'Rápido, cómodo y 4x4.' },
  { id: 'formula', name: 'Fórmula', file: 'race', price: 165000, up: 4500, wb: 1.7, engine: 41, vmax: 26, mu: 1.22, air: 4.5, k: 165, c: 14, tank: 70, cons: 1.3, drive: 'rwd', desc: 'Un cohete con ruedas. Solo para expertos.' },
  { id: 'futuro', name: 'Futurista', file: 'race-future', price: 300000, up: 7000, wb: 1.75, engine: 45, vmax: 30, mu: 1.3, air: 6.5, k: 170, c: 15, tank: 100, cons: 1.1, drive: '4x4', desc: 'Del año 3000. Lo mejor de lo mejor.' },
];
export const UPG = [{ id: 'motor', name: 'Motor' }, { id: 'agarre', name: 'Ruedas' }, { id: 'susp', name: 'Suspensión' }, { id: 'tanque', name: 'Depósito' }];
export const MAXLV = 10;
export const upCost = (car, lv) => Math.round(car.up * Math.pow(1.5, lv) / 10) * 10;

// puntos de control: 250, 600, 1050, 1600… con premio creciente
export const checkpoint = k => 250 * k + 50 * k * (k - 1);
export const cpBonus = k => 150 * k * k;

// misiones: siempre hay 3; al cumplir una sale otra más difícil
export const MISSION_TYPES = [
  { t: 'dist', make: (n, st) => ({ goal: Math.round((180 + n * 70) / 10) * 10, stage: st, text: g => `Llega a ${g} m en ${st.name}` }) },
  { t: 'flips', make: n => ({ goal: 1 + Math.floor(n / 3), text: g => `Haz ${g} volteret${g > 1 ? 'as' : 'a'} en una carrera` }) },
  { t: 'air', make: n => ({ goal: +(1.5 + n * .25).toFixed(1), text: g => `Vuela ${String(g).replace('.', ',')} s seguidos en un salto` }) },
  { t: 'coins', make: n => ({ goal: Math.round((150 + n * 120) / 10) * 10, text: g => `Consigue ${g} monedas en una carrera` }) },
  { t: 'fuel', make: n => ({ goal: 1 + Math.floor(n / 2), text: g => `Coge ${g} bidón${g > 1 ? 'es' : ''} de gasolina en una carrera` }) },
  { t: 'total', make: n => ({ goal: Math.round((800 + n * 500) / 100) * 100, text: g => `Recorre ${g} m en total` }) },
];
export const missionReward = n => 120 + n * 90;
