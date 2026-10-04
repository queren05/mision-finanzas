// Armas: dmg por bala, rate = disparos por segundo, mag/res = cargador y reserva, rel = segundos de recarga,
// auto = automática, spread = dispersión (rad) sin apuntar, pel = perdigones, proj = proyectil (no hitscan).
// rmodel: modelo realista (Sketchfab, CC-BY) que se usa en el modo realista; rflip: girarlo 180° si apunta al revés.
// pap: versión mejorada en el Pack-a-Punch. wall: precio en la pared (null = solo en la caja).
export const GUNS = {
  m1911: { rmodel: 'w/gun_m1911', name: 'M1911', model: 'g/Pistol_1', len: .3, dmg: 40, rate: 4.5, mag: 8, res: 80, rel: 1.4, auto: false, spread: .02, pel: 1, wall: null, pitch: 1.3,
    pap: { name: 'Mustang & Sally', dmg: 900, mag: 12, res: 60, rate: 4, proj: 'nade', splash: 2.2, col: 0xff3a3a } },
  olympia: { rmodel: 'w/gun_olympia', name: 'Olympia', model: 'g/Shotgun_SawedOff', len: .55, dmg: 45, rate: 1.4, mag: 2, res: 38, rel: 2.4, auto: false, spread: .09, pel: 8, wall: 500, pitch: .6,
    pap: { name: 'Hades', dmg: 120, mag: 4, res: 76 } },
  m14: { rmodel: 'w/gun_m14', name: 'M14', model: 'g/AssaultRifle_4', len: .85, dmg: 110, rate: 4, mag: 8, res: 92, rel: 1.6, auto: false, spread: .01, pel: 1, wall: 500, pitch: .9,
    pap: { name: 'Mnesia', dmg: 250, mag: 15, res: 150, auto: true, rate: 6 } },
  mp40: { rmodel: 'w/gun_mp40', name: 'MP40', model: 'g/SubmachineGun_3', len: .55, dmg: 45, rate: 9, mag: 32, res: 192, rel: 2.2, auto: true, spread: .035, pel: 1, wall: 1000, pitch: 1.05,
    pap: { name: 'The Afterburner', dmg: 110, mag: 64, res: 384 } },
  ak74u: { rmodel: 'w/gun_ak74u', name: 'AK-74u', model: 'g/AssaultRifle_1', len: .6, dmg: 55, rate: 11, mag: 20, res: 160, rel: 2.0, auto: true, spread: .04, pel: 1, wall: 1200, pitch: 1.1,
    pap: { name: 'AK-74fu2', dmg: 130, mag: 40, res: 280 } },
  m16: { rmodel: 'w/gun_m16', name: 'M16', model: 'g/AssaultRifle2_2', len: .85, dmg: 70, rate: 7, mag: 30, res: 120, rel: 2.0, auto: true, spread: .025, pel: 1, wall: 1200, pitch: .95,
    pap: { name: 'Skullcrusher', dmg: 160, mag: 30, res: 240 } },
  rpk: { rmodel: 'w/gun_rpk2', name: 'RPK', model: 'g/AssaultRifle_3', len: .85, dmg: 70, rate: 10, mag: 100, res: 400, rel: 3.6, auto: true, spread: .05, pel: 1, wall: null, pitch: .8,
    pap: { name: 'R115 Resonator', dmg: 160, mag: 125, res: 500 } },
  galil: { rmodel: 'w/gun_galil', name: 'Galil', model: 'g/AssaultRifle2_1', len: .85, dmg: 75, rate: 11, mag: 35, res: 315, rel: 2.6, auto: true, spread: .03, pel: 1, wall: null, pitch: .9,
    pap: { name: 'Lamentation', dmg: 170, mag: 50, res: 400 } },
  raygun: { name: 'Ray Gun', model: 'blaster-l', len: .5, dmg: 1000, rate: 3, mag: 20, res: 160, rel: 2.4, auto: false, spread: .005, pel: 1, wall: null, pitch: 1.6, proj: 'ray', splash: 1.6, col: 0x3aff5a,
    pap: { name: "Porter's X2 Ray Gun", dmg: 2000, mag: 40, res: 200, col: 0xff3a3a } },
  python: { rmodel: 'w/gun_python', rflip: true, name: 'Python', model: 'g/Revolver_1', len: .36, dmg: 180, rate: 2.2, mag: 6, res: 42, rel: 2.8, auto: false, spread: .012, pel: 1, wall: 1000, pitch: .7,
    pap: { name: 'Cobra', dmg: 600, mag: 12, res: 84 } },
  stakeout: { rmodel: 'w/gun_stakeout', name: 'Stakeout', model: 'g/Shotgun_2', len: .95, dmg: 60, rate: 1.3, mag: 6, res: 48, rel: 3, auto: false, spread: .08, pel: 8, wall: null, pitch: .55,
    pap: { name: 'Raid', dmg: 150, mag: 8, res: 64 } },
  mp5k: { rmodel: 'w/gun_mp5k', name: 'MP5K', model: 'g/SubmachineGun_5', len: .48, dmg: 50, rate: 12, mag: 30, res: 210, rel: 2, auto: true, spread: .035, pel: 1, wall: null, pitch: 1.1,
    pap: { name: 'MP115 Kollider', dmg: 120, mag: 40, res: 320 } },
  l96: { rmodel: 'w/gun_l96', name: 'L96A1', model: 'g/SniperRifle_2', len: 1.1, dmg: 900, rate: .9, mag: 5, res: 40, rel: 3.2, auto: false, spread: .002, pel: 1, wall: null, pitch: .6, scope: true,
    pap: { name: 'Destructor', dmg: 3000, mag: 8, res: 60 } },
  commando: { rmodel: 'w/gun_commando', name: 'Commando', model: 'g/AssaultRifle2_3', len: .75, dmg: 85, rate: 11, mag: 30, res: 240, rel: 2.2, auto: true, spread: .025, pel: 1, wall: null, pitch: 1,
    pap: { name: 'Predator', dmg: 190, mag: 40, res: 360 } },
  spas: { rmodel: 'w/gun_spas', name: 'SPAS-12', model: 'g/Shotgun_1', len: .95, dmg: 70, rate: 2.5, mag: 8, res: 56, rel: 3, auto: false, spread: .085, pel: 8, wall: null, pitch: .5,
    pap: { name: 'SPAZ-24', dmg: 170, mag: 24, res: 96 } },
  gambas: { name: 'Lanzagambas', model: 'blaster-a', len: .6, dmg: 3000, rate: 1.2, mag: 6, res: 30, rel: 2.6, auto: false, spread: .005, pel: 1, wall: null, pitch: 2, proj: 'shrimp', splash: 3.2, col: 0xff8a5a,
    pap: { name: 'Gamba Atómica', dmg: 8000, mag: 10, res: 60, splash: 4.5 } },
};
export const BOX_POOL = ['raygun', 'raygun', 'rpk', 'galil', 'ak74u', 'm16', 'mp40', 'olympia', 'm14', 'gambas', 'python', 'stakeout', 'mp5k', 'l96', 'commando', 'commando', 'spas', 'galil', 'rpk'];
export const PERKS = {
  revive: { name: 'Quick Revive', cost: 500, col: 0x4fb2ff, desc: 'Te levanta solo una vez si caes', power: false },
  jugg: { name: 'Juggernog', cost: 2500, col: 0xe8302e, desc: 'Aguantas muchos más golpes' },
  speed: { name: 'Speed Cola', cost: 3000, col: 0x3fd65a, desc: 'Recargas el doble de rápido' },
  dtap: { name: 'Double Tap', cost: 2000, col: 0xffc21d, desc: 'Disparas más rápido y con más daño' },
  stamin: { name: 'Stamin-Up', cost: 2000, col: 0xff8a2a, desc: 'Corres más rápido' },
  mule: { name: 'Mule Kick', cost: 4000, col: 0x3a9a4a, desc: 'Puedes llevar un tercer arma' },
};
export const POWERUPS = ['ammo', 'insta', 'double', 'nuke', 'carpenter'];
export const PU_NAME = { ammo: 'MUNICIÓN MÁXIMA', insta: 'MUERTE INSTANTÁNEA', double: 'DOBLES PUNTOS', nuke: 'NUCLEAR', carpenter: 'CARPINTERO' };
