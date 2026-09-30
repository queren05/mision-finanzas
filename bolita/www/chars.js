/* Chibimon — 4 líneas elementales × 3 fases (evolucionan al nivel 16 y al 36). Dibujo original en estilo chibi
   pastel: trazo marrón algo tembloroso, cabezas grandes, ojitos de punto.
   charSvg(id, e) → <svg> completo. id = 'linea:fase' (p. ej. 'hoja:2'). e = { eyes, mouth, look, dirt, acc, shadow, sweat, tear }.
   Cada forma define: c (colores), F (posición de cara y complementos) y d(c) → capas {back, body, front}. */
const O = '#6b4a3a';
const SW = 'stroke="#6b4a3a" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round"';
const sw = w => `stroke="#6b4a3a" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;
const LOAF = (c, w = 64, top = 74) => `<path d="M${100 - w} 150 C${100 - w} ${top + 10} ${100 - w * .6} ${top} 100 ${top} C${100 + w * .6} ${top} ${100 + w} ${top + 10} ${100 + w} 150 C${100 + w} 176 ${100 + w * .7} 182 100 182 C${100 - w * .7} 182 ${100 - w} 176 ${100 - w} 150 Z" fill="${c}" ${SW}/>`;
const PAWS = c => `<path d="M72 178 q8 -10 16 0" fill="${c}" ${SW}/><path d="M112 178 q8 -10 16 0" fill="${c}" ${SW}/>`;
// cabeza + cuerpo para fases 2 y 3 (más "de pie")
const HEAD = (c, cy = 84, rx = 50, ry = 44) => `<ellipse cx="100" cy="${cy}" rx="${rx}" ry="${ry}" fill="${c}" ${SW}/>`;
const TORSO = (c, cy = 150, rx = 34, ry = 30) => `<ellipse cx="100" cy="${cy}" rx="${rx}" ry="${ry}" fill="${c}" ${SW}/>`;
const LEGS = c => `<ellipse cx="82" cy="180" rx="12" ry="8" fill="${c}" ${SW}/><ellipse cx="118" cy="180" rx="12" ry="8" fill="${c}" ${SW}/>`;
const ARMS = c => `<ellipse cx="68" cy="146" rx="8" ry="13" fill="${c}" ${SW} transform="rotate(25 68 146)"/><ellipse cx="132" cy="146" rx="8" ry="13" fill="${c}" ${SW} transform="rotate(-25 132 146)"/>`;
const VEST = (col, trim) => `<path d="M72 132 Q100 150 128 132 L132 168 Q100 178 68 168 Z" fill="${col}" ${SW}/><path d="M100 144 V174" stroke="${trim}" stroke-width="3"/><path d="M76 136 Q100 152 124 136" fill="none" stroke="${trim}" stroke-width="3"/>`;
const BOLT = (x, y, s = 1, col = '#f7c948') => `<path transform="translate(${x} ${y}) scale(${s})" d="M0 -12 L-6 1 H0 L-3 12 L7 -3 H1 L4 -12 Z" fill="${col}" ${sw(2)}/>`;
const FLAME = (x, y, s = 1, r = 0) => `<g transform="translate(${x} ${y}) rotate(${r}) scale(${s})"><path d="M0 -26 Q16 -8 10 6 Q6 14 0 14 Q-6 14 -10 6 Q-16 -8 0 -26Z" fill="#ff7a45" ${sw(2.6)}/><path d="M0 -10 Q7 -2 4 6 Q0 10 -4 6 Q-7 -2 0 -10Z" fill="#ffd166"/></g>`;
const LOTUS = (x, y, s = 1) => `<g transform="translate(${x} ${y}) scale(${s})"><path d="M0 4 Q-12 -2 -10 -12 Q-2 -8 0 4Z M0 4 Q12 -2 10 -12 Q2 -8 0 4Z" fill="#ffb3cc" ${sw(2)}/><path d="M0 4 Q-5 -8 0 -16 Q5 -8 0 4Z" fill="#ffd0e0" ${sw(2)}/></g>`;

const LINES = {
  hoja: { n: 'Planta', e: '🌿', egg: ['#cfe8b8', '#8fc47a'], food: 'carrot' },
  rayo: { n: 'Rayo', e: '⚡', egg: ['#fff6df', '#f2c14e'], food: 'banana' },
  agua: { n: 'Agua', e: '💧', egg: ['#d3f1ec', '#6cc3b8'], food: 'sushi' },
  fuego: { n: 'Fuego', e: '🔥', egg: ['#ffe0cc', '#e8604c'], food: 'pizza' },
};
const CHARS = {
  // ---------- PLANTA: ciervo ----------
  'hoja:1': { n: 'Lotín', t: 'Cervatillo de loto', d: 'Tímido y dulce. Usa una hoja de loto de paraguas.', c: '#a8cf8a',
    F: { ex: 24, ey: 124, my: 136, cx: 42, cy: 138, top: 60, neck: 160, cheek: '#ffb0a0' },
    d: c => ({ back: `<g transform="rotate(-14 100 58)"><ellipse cx="100" cy="58" rx="54" ry="16" fill="#8cc275" ${SW}/><path d="M100 58 L60 52 M100 58 L78 68 M100 58 L128 68 M100 58 L142 52" stroke="#6ea85c" stroke-width="2.5"/></g><path d="M100 72 V58" ${sw(3)}/>`,
      body: LOAF(c.c, 62, 80) + PAWS(c.c) + `<circle cx="64" cy="118" r="4" fill="#e6f2cf"/><circle cx="140" cy="122" r="5" fill="#e6f2cf"/><circle cx="150" cy="142" r="3.5" fill="#e6f2cf"/>`,
      front: `<path d="M44 108 Q28 92 36 84 Q48 92 54 104Z" fill="${c.c}" ${SW}/><path d="M156 108 Q172 92 164 84 Q152 92 146 104Z" fill="${c.c}" ${SW}/>` }) },
  'hoja:2': { n: 'Floriervo', t: 'Ciervo del lago', d: 'Sereno y protector. Le crecen flores en la cornamenta.', c: '#98c27a',
    F: { ex: 22, ey: 88, my: 100, cx: 38, cy: 100, top: 40, neck: 128, cheek: '#ffb0a0', muzzle: '#e3eecb' },
    d: c => ({ back: `<path d="M74 52 L62 24 M66 36 L52 30 M126 52 L138 24 M134 36 L148 30" ${sw(5)} stroke="#a47a52"/>${LOTUS(60, 22, .8)}${LOTUS(140, 22, .8)}`,
      body: TORSO(c.c) + VEST('#3f8f6a', '#e9c46a') + ARMS(c.c) + LEGS(c.c),
      front: HEAD(c.c) + `<path d="M50 70 Q32 56 40 50 Q52 58 58 66Z" fill="${c.c}" ${SW}/><path d="M150 70 Q168 56 160 50 Q148 58 142 66Z" fill="${c.c}" ${SW}/>` }) },
  'hoja:3': { n: 'Bosquerón', t: 'Señor del bosque', d: 'Majestuosa y sabia. Donde pisa, florece.', c: '#8fb872',
    F: { ex: 21, ey: 94, my: 106, cx: 36, cy: 106, top: 50, neck: 134, cheek: '#ffb0a0', muzzle: '#e3eecb' },
    d: c => ({ back: `<path d="M76 58 L58 20 M66 40 L44 32 M62 30 L50 12 M124 58 L142 20 M134 40 L156 32 M138 30 L150 12" ${sw(6)} stroke="#9a714b"/>
        ${[[50, 12], [44, 32], [70, 22], [150, 12], [156, 32], [130, 22]].map(([x, y]) => LOTUS(x, y, .7)).join('')}
        <path d="M58 150 Q30 176 60 190 H140 Q170 176 142 150Z" fill="#3f8f6a" ${SW}/>`,
      body: TORSO(c.c, 154, 36, 30) + `<path d="M66 134 Q100 158 134 134 L138 176 Q100 188 62 176 Z" fill="#2f7d61" ${SW}/><path d="M66 134 Q100 158 134 134" fill="none" stroke="#e9c46a" stroke-width="4"/><path d="M100 150 V184" stroke="#e9c46a" stroke-width="3"/>` + ARMS(c.c),
      front: HEAD(c.c, 90, 46, 42) + `<path d="M56 76 Q38 62 46 56 Q58 64 64 72Z" fill="${c.c}" ${SW}/><path d="M144 76 Q162 62 154 56 Q142 64 136 72Z" fill="${c.c}" ${SW}/><circle cx="100" cy="60" r="5" fill="#e9c46a" ${sw(2)}/>` }) },
  // ---------- RAYO: zorro ----------
  'rayo:1': { n: 'Chispín', t: 'Zorrito chispa', d: 'Travieso y rapidísimo. Su cola suelta chispitas.', c: '#fff8ee',
    F: { ex: 24, ey: 124, my: 136, cx: 42, cy: 138, top: 62, neck: 160, cheek: '#ffb49a' },
    d: c => ({ back: `<path d="M150 166 Q192 160 186 118 Q182 98 164 106 Q180 118 168 136 Q158 148 146 150Z" fill="${c.c}" ${SW}/><path d="M178 116 q-8 8 -2 16 q6 -6 12 0" fill="none" stroke="#f2c14e" stroke-width="3"/>`,
      body: LOAF(c.c, 62, 80) + PAWS(c.c) + `<path d="M92 92 L100 104 L108 92" fill="none" stroke="#f2c14e" stroke-width="3"/>`,
      front: `<path d="M50 104 L48 52 L84 84Z" fill="${c.c}" ${SW}/><path d="M56 94 L55 66 L74 84Z" fill="#f7d98a"/><path d="M150 104 L152 52 L116 84Z" fill="${c.c}" ${SW}/><path d="M144 94 L145 66 L126 84Z" fill="#f7d98a"/>` }) },
  'rayo:2': { n: 'Zorrayo', t: 'Zorro del trueno', d: 'Orgulloso y leal. Dos colas cargadas de energía.', c: '#fff8ee',
    F: { ex: 22, ey: 88, my: 100, cx: 38, cy: 100, top: 36, neck: 128, cheek: '#ffb49a' },
    d: c => ({ back: [[-20, 160], [18, 150]].map(([r, x]) => `<g transform="rotate(${r} ${x} 150)"><path d="M${x - 8} 160 Q${x + 36} 150 ${x + 26} 104 Q${x + 18} 88 ${x + 6} 100 Q${x + 18} 118 ${x + 4} 138Z" fill="${c.c}" ${SW}/></g>`).join('') + BOLT(40, 60, 1.1) + BOLT(166, 48, .9),
      body: TORSO(c.c) + VEST('#3d4f7a', '#f2c14e') + ARMS(c.c) + LEGS(c.c),
      front: `<path d="M58 72 L52 22 L88 54Z" fill="${c.c}" ${SW}/><path d="M63 62 L60 36 L79 54Z" fill="#f7d98a"/><path d="M142 72 L148 22 L112 54Z" fill="${c.c}" ${SW}/><path d="M137 62 L140 36 L121 54Z" fill="#f7d98a"/>` + HEAD(c.c) + `<path d="M92 56 L100 66 L108 56" fill="none" stroke="#f2c14e" stroke-width="3"/>` }) },
  'rayo:3': { n: 'Tronarca', t: 'Señor de la tormenta', d: 'Imponente y justo. Nueve colas, nueve relámpagos.', c: '#fffaf2',
    F: { ex: 21, ey: 92, my: 104, cx: 36, cy: 104, top: 40, neck: 132, cheek: '#ffb49a' },
    d: c => ({ back: [-88, -66, -44, 44, 66, 88, -110, 110].map(r => `<g transform="rotate(${r} 100 160)"><path d="M90 160 Q80 100 100 70 Q120 100 110 160Z" fill="${c.c}" ${SW}/><path d="M100 78 Q108 92 100 106" fill="none" stroke="#f2c14e" stroke-width="3"/></g>`).join('')
        + `<path d="M60 136 Q34 186 56 194 H144 Q166 186 140 136Z" fill="#34406b" ${SW}/>${BOLT(62, 176, .8)}${BOLT(138, 172, .8)}`,
      body: TORSO(c.c, 154) + `<path d="M68 134 Q100 150 132 134 L136 174 Q100 184 64 174 Z" fill="#3d4f7a" ${SW}/><path d="M68 134 Q100 150 132 134" fill="none" stroke="#f2c14e" stroke-width="4"/>` + ARMS(c.c),
      front: `<path d="M62 74 L54 24 L90 56Z" fill="${c.c}" ${SW}/><path d="M138 74 L146 24 L110 56Z" fill="${c.c}" ${SW}/>` + HEAD(c.c, 88, 46, 42) + `<path d="M88 58 L100 72 L112 58" fill="none" stroke="#f2c14e" stroke-width="3.5"/><path d="M100 50 l-6 -12 h12z" fill="#f2c14e" ${sw(2)}/>` }) },
  // ---------- AGUA: tortuga → dragón ----------
  'agua:1': { n: 'Tortuguín', t: 'Tortuga de ola', d: 'Tranquila y risueña. Lleva el mar dibujado en el caparazón.', c: '#8fd6cb',
    F: { ex: 24, ey: 124, my: 136, cx: 42, cy: 138, top: 72, neck: 160, cheek: '#ff9fb0' },
    d: c => ({ back: `<ellipse cx="100" cy="130" rx="78" ry="56" fill="#4fa99c" ${SW}/><path d="M40 120 q16 -20 34 -4 q-14 4 -8 16 M126 104 q20 -12 32 6 q-14 0 -12 14" fill="none" stroke="#9fe0d6" stroke-width="3.5"/>
        <ellipse cx="34" cy="168" rx="16" ry="9" fill="${c.c}" ${SW} transform="rotate(-25 34 168)"/><ellipse cx="166" cy="168" rx="16" ry="9" fill="${c.c}" ${SW} transform="rotate(25 166 168)"/>`,
      body: LOAF(c.c, 50, 88) + PAWS(c.c), front: '' }) },
  'agua:2': { n: 'Salpicón', t: 'Guardián de las olas', d: 'Valiente y juguetón. Lleva una ola por bufanda.', c: '#7fcfc3',
    F: { ex: 22, ey: 88, my: 100, cx: 38, cy: 100, top: 34, neck: 124, cheek: '#ff9fb0' },
    d: c => ({ back: `<path d="M130 170 Q182 176 180 136 Q168 150 136 154Z" fill="${c.c}" ${SW}/><path d="M62 150 Q20 150 30 112 Q44 128 64 128Z" fill="#9fe0d6" ${SW}/>`,
      body: TORSO(c.c) + `<ellipse cx="100" cy="156" rx="20" ry="18" fill="#dff5f0"/>` + ARMS(c.c) + LEGS(c.c),
      front: HEAD(c.c) + `<path d="M76 44 Q88 22 100 40 Q112 20 124 44" fill="#9fe0d6" ${SW}/>` + `<path d="M58 118 Q100 140 142 118 Q150 126 140 134 Q100 150 60 134 Q50 126 58 118Z" fill="#8fd3ff" ${SW}/><path d="M140 128 q16 4 20 -12 q-10 4 -14 -2" fill="#8fd3ff" ${SW}/>` }) },
  'agua:3': { n: 'Dracomar', t: 'Dragón de los mares', d: 'Sabio y poderoso. Guarda una perla de luna.', c: '#72c6ba',
    F: { ex: 21, ey: 84, my: 98, cx: 36, cy: 98, top: 30, neck: 124, cheek: '#ff9fb0' },
    d: c => ({ back: `<path d="M150 180 Q196 160 180 120 Q170 96 150 110 Q170 124 156 146 Q140 166 110 170Z" fill="${c.c}" ${SW}/><path d="M168 108 L186 96 L178 114Z" fill="#9fe0d6" ${SW}/>
        <path d="M60 120 Q20 110 22 76 Q40 100 62 98Z" fill="#9fe0d6" ${SW}/><path d="M140 120 Q180 110 178 76 Q160 100 138 98Z" fill="#9fe0d6" ${SW}/>`,
      body: TORSO(c.c, 150, 36, 32) + `<path d="M84 128 Q100 180 116 128" fill="#dff5f0"/><path d="M88 138 h24 M86 150 h28 M88 162 h24" stroke="#b9e6de" stroke-width="2.5"/>` + ARMS(c.c) + LEGS(c.c) + `<circle cx="134" cy="166" r="9" fill="#fff" ${sw(2.5)}/><circle cx="131" cy="163" r="3" fill="#e8f7ff"/>`,
      front: HEAD(c.c, 82, 50, 42) + `<path d="M70 44 L78 18 L88 40 L100 12 L112 40 L122 18 L130 44" fill="#9fe0d6" ${SW}/><path d="M60 98 Q40 104 34 120 M140 98 Q160 104 166 120" fill="none" ${sw(2.6)}/>` }) },
  // ---------- FUEGO: pollito → fénix ----------
  'fuego:1': { n: 'Chamusquín', t: 'Pájaro de brasa', d: 'Alegre y comilón. Su cresta se aviva cuando está contento.', c: '#f27a5e',
    F: { ex: 24, ey: 118, my: 134, cx: 44, cy: 132, top: 60, neck: 160, cheek: '#ffd0a0', beak: true },
    d: c => ({ back: FLAME(100, 72, 1.1) + FLAME(84, 78, .7, -20) + FLAME(116, 78, .7, 20),
      body: LOAF(c.c, 62, 76) + PAWS('#ffb36b') + `<ellipse cx="100" cy="160" rx="30" ry="18" fill="#ffc98a"/>` + `<path d="M38 142 q-14 -2 -10 -18 q10 4 16 14" fill="${c.c}" ${SW}/><path d="M162 142 q14 -2 10 -18 q-10 4 -16 14" fill="${c.c}" ${SW}/>`,
      front: '' }) },
  'fuego:2': { n: 'Llamarín', t: 'Halcón de fuego', d: 'Decidido y noble. Viste un chaleco de brasas.', c: '#e8604c',
    F: { ex: 22, ey: 86, my: 102, cx: 38, cy: 98, top: 36, neck: 126, cheek: '#ffd0a0', beak: true },
    d: c => ({ back: FLAME(100, 40, 1.3) + FLAME(78, 46, .9, -25) + FLAME(122, 46, .9, 25) + FLAME(156, 150, 1, 60) + `<path d="M64 130 Q26 120 30 96 Q46 112 66 114Z" fill="${c.c}" ${SW}/><path d="M136 130 Q174 120 170 96 Q154 112 134 114Z" fill="${c.c}" ${SW}/>`,
      body: TORSO(c.c) + VEST('#fff1dc', '#e8604c') + LEGS('#ffb36b'),
      front: HEAD(c.c) }) },
  'fuego:3': { n: 'Fénixol', t: 'Grifo de fuego', d: 'Radiante e incansable. Renace más fuerte cada día.', c: '#e25640',
    F: { ex: 21, ey: 90, my: 106, cx: 36, cy: 102, top: 40, neck: 130, cheek: '#ffd0a0', beak: true },
    d: c => ({ back: `<path d="M70 130 Q10 120 8 60 Q30 86 44 82 Q34 60 40 40 Q58 70 70 70 Q66 52 76 38 Q84 80 86 110Z" fill="#ff7a45" ${SW}/><path d="M130 130 Q190 120 192 60 Q170 86 156 82 Q166 60 160 40 Q142 70 130 70 Q134 52 124 38 Q116 80 114 110Z" fill="#ff7a45" ${SW}/>
        <path d="M60 110 Q30 96 30 72 Q48 92 64 96Z M140 110 Q170 96 170 72 Q152 92 136 96Z" fill="#ffd166"/>` + FLAME(100, 44, 1.5) + FLAME(74, 50, 1, -30) + FLAME(126, 50, 1, 30),
      body: TORSO(c.c, 152) + `<path d="M70 132 Q100 148 130 132 L128 150 Q100 162 72 150Z" fill="#3aa57a" ${SW}/><circle cx="100" cy="148" r="6" fill="#e9c46a" ${sw(2)}/>` + LEGS('#ffb36b'),
      front: HEAD(c.c, 88, 46, 42) }) },
};
const STAGE_LV = [1, 16, 36];
const formOf = (line, lvl) => `${line}:${lvl >= STAGE_LV[2] ? 3 : lvl >= STAGE_LV[1] ? 2 : 1}`;

function faceSvg(ch, e) {
  const F = ch.F, [lx, ly] = e.look || [0, 0], L = 100 - F.ex, R = 100 + F.ex, y = F.ey, ox = lx * 3, oy = ly * 2.5;
  let eyes;
  switch (e.eyes) {
    case 'happy': eyes = [L, R].map(x => `<path d="M${x - 6} ${y + 2} Q${x} ${y - 6} ${x + 6} ${y + 2}" fill="none" ${SW}/>`).join(''); break;
    case 'sleep': eyes = [L, R].map(x => `<path d="M${x - 6} ${y - 1} Q${x} ${y + 5} ${x + 6} ${y - 1}" fill="none" ${SW}/>`).join(''); break;
    case 'x': eyes = `<path d="M${L - 5} ${y - 5} L${L + 4} ${y} L${L - 5} ${y + 5}" fill="none" ${SW}/><path d="M${R + 5} ${y - 5} L${R - 4} ${y} L${R + 5} ${y + 5}" fill="none" ${SW}/>`; break;
    case 'tired': eyes = [L, R].map(x => `<path d="M${x - 6} ${y} H${x + 6}" ${SW}/><path d="M${x - 4} ${y + 1} Q${x} ${y + 6} ${x + 4} ${y + 1}" fill="${O}"/>`).join(''); break;
    case 'blink': eyes = [L, R].map(x => `<path d="M${x - 5} ${y} H${x + 5}" ${SW}/>`).join(''); break;
    case 'sparkle': eyes = [L, R].map(x => `<circle cx="${x + ox}" cy="${y + oy}" r="7" fill="${O}"/><circle cx="${x + ox + 2}" cy="${y + oy - 2.5}" r="2.4" fill="#fff"/><circle cx="${x + ox - 2}" cy="${y + oy + 2.5}" r="1.2" fill="#fff"/>`).join(''); break;
    default: eyes = [L, R].map(x => `<ellipse cx="${x + ox}" cy="${y + oy}" rx="4.8" ry="5.6" fill="${O}"/><circle cx="${x + ox + 1.6}" cy="${y + oy - 2}" r="1.7" fill="#fff"/>`).join('');
  }
  const mx = 100 + lx * 2, my = F.my + ly * 2;
  let M;
  if (F.beak && !['open', 'laugh', 'chew'].includes(e.mouth)) M = `<path d="M${mx - 10} ${my - 5} Q${mx} ${my - 10} ${mx + 10} ${my - 5} Q${mx} ${my + 6} ${mx - 10} ${my - 5}Z" fill="#ffb347" ${SW}/>`;
  else M = {
    cat: `<path d="M${mx - 7} ${my} Q${mx - 3.5} ${my + 4} ${mx} ${my} Q${mx + 3.5} ${my + 4} ${mx + 7} ${my}" fill="none" ${SW}/>`,
    smile: `<path d="M${mx - 6} ${my} Q${mx} ${my + 6} ${mx + 6} ${my}" fill="none" ${SW}/>`,
    open: `<path d="M${mx - 8} ${my - 2} Q${mx} ${my + 14} ${mx + 8} ${my - 2} Z" fill="#9b4a4a" ${SW}/><path d="M${mx - 4} ${my + 6} Q${mx} ${my + 3} ${mx + 4} ${my + 6} Q${mx} ${my + 9} ${mx - 4} ${my + 6}Z" fill="#ff9aa8"/>`,
    laugh: `<path d="M${mx - 10} ${my - 3} Q${mx} ${my + 16} ${mx + 10} ${my - 3} Z" fill="#9b4a4a" ${SW}/><path d="M${mx - 5} ${my + 7} Q${mx} ${my + 3} ${mx + 5} ${my + 7} Q${mx} ${my + 11} ${mx - 5} ${my + 7}Z" fill="#ff9aa8"/>`,
    chew: `<path d="M${mx - 6} ${my + 1} Q${mx - 3} ${my - 3} ${mx} ${my + 1} Q${mx + 3} ${my - 3} ${mx + 6} ${my + 1}" fill="none" ${SW}/>`,
    o: `<ellipse cx="${mx}" cy="${my + 2}" rx="3.6" ry="4.4" fill="#9b4a4a" ${sw(2.4)}/>`,
    flat: `<path d="M${mx - 5} ${my + 2} H${mx + 5}" ${SW}/>`,
    sad: `<path d="M${mx - 6} ${my + 4} Q${mx} ${my - 1} ${mx + 6} ${my + 4}" fill="none" ${SW}/>`,
    wavy: `<path d="M${mx - 7} ${my + 2} Q${mx - 3.5} ${my - 2} ${mx} ${my + 2} Q${mx + 3.5} ${my + 6} ${mx + 7} ${my + 2}" fill="none" ${SW}/>`,
    tiny: `<circle cx="${mx}" cy="${my + 1}" r="1.8" fill="${O}"/>`,
    grr: `<path d="M${mx - 6} ${my + 4} Q${mx} ${my - 2} ${mx + 6} ${my + 4}" fill="none" ${SW}/>`,
  }[e.mouth || 'cat'] || '';
  const muzzle = F.muzzle ? `<ellipse cx="100" cy="${F.my - 3}" rx="16" ry="11" fill="${F.muzzle}"/><ellipse cx="100" cy="${F.my - 8}" rx="4.6" ry="3.2" fill="${O}"/>` : '';
  const blush = e.eyes === 'tired' ? '' : `<ellipse cx="${100 - F.cx}" cy="${F.cy}" rx="8" ry="5" fill="${F.cheek}" opacity=".75"/><ellipse cx="${100 + F.cx}" cy="${F.cy}" rx="8" ry="5" fill="${F.cheek}" opacity=".75"/>`;
  const sweat = e.sweat ? `<path d="M${R + 24} ${y - 22} q6 9 0 13 q-6 -4 0 -13z" fill="#a7dcff" ${sw(2)}/>` : '';
  const tear = e.tear ? `<path d="M${L - 3} ${y + 8} q-3 6 0 9 q3 -3 0 -9z" fill="#a7dcff"/>` : '';
  return muzzle + blush + eyes + M + sweat + tear;
}
function accSvg(ch, id) {
  const F = ch.F, t = F.top, n = F.neck, ey = F.ey, ex = F.ex;
  switch (id) {
    case 'party': return `<g transform="translate(100 ${t + 4})"><path d="M-16 8 L0 -36 L16 8 Z" fill="#ff9fc9" ${SW}/><path d="M-10 -6 L10 -6 M-5 -20 L5 -20" stroke="#fff08a" stroke-width="4"/><circle cy="-38" r="6" fill="#fff08a" ${SW}/></g>`;
    case 'bow': return `<g transform="translate(${100 + 30} ${t + 8}) rotate(16)"><path d="M0 0 L-18 -11 Q-22 0 -18 11 Z M0 0 L18 -11 Q22 0 18 11 Z" fill="#ff8fb3" ${SW}/><circle r="5.5" fill="#ffadc8" ${SW}/></g>`;
    case 'flower': return `<g transform="translate(${100 + 30} ${t + 8})">${[0, 72, 144, 216, 288].map(a => `<ellipse rx="6" ry="9" transform="rotate(${a}) translate(0 -8)" fill="#ffd6e7" ${sw(2.6)}/>`).join('')}<circle r="5" fill="#ffd05a" ${sw(2.6)}/></g>`;
    case 'crown': return `<g transform="translate(100 ${t - 2})"><path d="M-22 8 L-22 -10 L-11 0 L0 -15 L11 0 L22 -10 L22 8 Z" fill="#ffd95a" ${SW}/><circle cy="1" r="3.4" fill="#ff7a95"/></g>`;
    case 'cap': return `<g transform="translate(100 ${t + 10})"><path d="M-34 8 Q-34 -22 0 -22 Q34 -22 34 8 Z" fill="#ff8f80" ${SW}/><path d="M-2 8 L48 11 Q50 19 41 19 L-2 16 Z" fill="#f07464" ${SW}/></g>`;
    case 'round': return `<g fill="rgba(255,255,255,.3)" ${SW}><circle cx="${100 - ex}" cy="${ey}" r="12"/><circle cx="${100 + ex}" cy="${ey}" r="12"/><path d="M${100 - ex + 12} ${ey} Q100 ${ey - 5} ${100 + ex - 12} ${ey}" fill="none"/></g>`;
    case 'sun': return `<g ${SW}><rect x="${100 - ex - 14}" y="${ey - 9}" width="28" height="18" rx="7" fill="#3b2c34"/><rect x="${100 + ex - 14}" y="${ey - 9}" width="28" height="18" rx="7" fill="#3b2c34"/><path d="M${100 - ex + 14} ${ey - 2} H${100 + ex - 14}" fill="none"/></g>`;
    case 'bowtie': return `<g transform="translate(100 ${n})"><path d="M0 0 L-16 -10 Q-20 0 -16 10 Z M0 0 L16 -10 Q20 0 16 10 Z" fill="#ff8a8a" ${SW}/><circle r="4.5" fill="#ffa3a3" ${sw(2.6)}/></g>`;
    case 'scarf': return `<g><path d="M52 ${n - 8} Q100 ${n + 10} 148 ${n - 8} L149 ${n + 4} Q100 ${n + 22} 51 ${n + 4} Z" fill="#8fc4ff" ${SW}/><path d="M118 ${n + 8} L124 ${n + 26} L112 ${n + 28} L108 ${n + 10} Z" fill="#7ab3f2" ${SW}/></g>`;
    case 'medal': return `<g transform="translate(100 ${n})"><path d="M-10 -10 L0 6 L10 -10" fill="none" stroke="#8aa0ff" stroke-width="5"/><circle cy="12" r="8" fill="#ffd05a" ${sw(2.6)}/></g>`;
    default: return '';
  }
}
function charSvg(id, e = {}) {
  const ch = CHARS[id] || CHARS['hoja:1'], L = ch.d(ch);
  const dirt = e.dirt ? [[66, 160, 5], [138, 110, 4], [132, 166, 6], [58, 126, 3.5], [110, 172, 4]].slice(0, e.dirt).map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="#a98357" opacity=".5"/>`).join('') : '';
  const A = e.acc || {};
  return `<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" width="100%" height="100%"><defs><filter id="hand" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency=".035" numOctaves="2" seed="3"/><feDisplacementMap in="SourceGraphic" scale="2.4"/></filter></defs>
    ${e.shadow !== false ? '<ellipse cx="100" cy="188" rx="60" ry="6" fill="rgba(107,74,58,.16)"/>' : ''}
    <g filter="url(#hand)">${L.back}${L.body}${accSvg(ch, A.neck)}${L.front}${dirt}</g>${faceSvg(ch, e)}${accSvg(ch, A.face)}${accSvg(ch, A.head)}</svg>`;
}
// Huevo (para eclosionar): cracks 0–3
function eggSvg(line, cracks = 0) {
  const [a, b] = LINES[line].egg;
  const cr = ['', 'M92 70 l8 10 l-6 8 l10 8', 'M92 70 l8 10 l-6 8 l10 8 M120 110 l-10 6 l6 10 l-10 6', 'M92 70 l8 10 l-6 8 l10 8 M120 110 l-10 6 l6 10 l-10 6 M70 120 l12 4 l-4 12 l12 6'][cracks];
  return `<svg viewBox="0 0 200 200" width="100%" height="100%"><ellipse cx="100" cy="186" rx="50" ry="6" fill="rgba(107,74,58,.16)"/>
    <path d="M100 28 C142 28 160 96 160 128 C160 164 134 184 100 184 C66 184 40 164 40 128 C40 96 58 28 100 28Z" fill="${a}" ${SW}/>
    <path d="M44 118 q14 -10 28 0 q14 10 28 0 q14 -10 28 0 q14 10 28 0" fill="none" stroke="${b}" stroke-width="6"/>
    <circle cx="80" cy="80" r="8" fill="${b}"/><circle cx="124" cy="68" r="6" fill="${b}"/><circle cx="118" cy="150" r="9" fill="${b}"/><circle cx="70" cy="150" r="5" fill="${b}"/>
    <ellipse cx="78" cy="62" rx="10" ry="16" fill="#fff" opacity=".5" transform="rotate(-20 78 62)"/>
    ${cr ? `<path d="${cr}" fill="none" ${sw(3)}/>` : ''}</svg>`;
}
