/* Habitaciones ilustradas (SVG, viewBox 400x700; el suelo empieza en y≈470). Cada una tiene degradados,
   luz de ventana, sombras y muebles. SLOTS = huecos donde aparece la decoración comprada:
   techo, pared, estante, sueloI, sueloD → [x, y, tamaño]. */
const RDEFS = `<defs>
  <linearGradient id="skyD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7cc8ff"/><stop offset="1" stop-color="#d8f0ff"/></linearGradient>
  <linearGradient id="skyN" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2b2a6e"/><stop offset="1" stop-color="#6a5bb8"/></linearGradient>
  <radialGradient id="sunGlow" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#fff6c8" stop-opacity=".9"/><stop offset="1" stop-color="#fff6c8" stop-opacity="0"/></radialGradient>
  <linearGradient id="beam" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
  <linearGradient id="floorShade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity=".12"/><stop offset=".25" stop-color="#000" stop-opacity="0"/></linearGradient>
  <radialGradient id="vign" cx=".5" cy=".45" r=".75"><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#3a1d3a" stop-opacity=".22"/></radialGradient>
</defs>`;
const wall = (a, b) => `<linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient><rect width="400" height="480" fill="url(#w)"/>`;
const floor = (a, b) => `<linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient><rect y="470" width="400" height="230" fill="url(#f)"/><rect y="470" width="400" height="230" fill="url(#floorShade)"/><rect y="462" width="400" height="12" fill="${b}" opacity=".9"/><rect y="462" width="400" height="3" fill="#fff" opacity=".35"/>`;
const windowDay = (x, y, w, h) => `<g><rect x="${x - 8}" y="${y - 8}" width="${w + 16}" height="${h + 16}" rx="20" fill="#fff" opacity=".95"/><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="14" fill="url(#skyD)"/>
  <circle cx="${x + w * .28}" cy="${y + h * .32}" r="40" fill="url(#sunGlow)"/><circle cx="${x + w * .28}" cy="${y + h * .32}" r="15" fill="#fff4b0"/>
  <path d="M${x + w * .45} ${y + h * .7} q14 -18 30 -4 q12 -12 24 2 q10 0 10 10 h-72 q-4 -8 8 -8z" fill="#fff"/><path d="M${x} ${y + h * .85} q${w * .3} -22 ${w * .55} -6 q${w * .25} -16 ${w * .45} 0 v${h * .15} h-${w}z" fill="#9fdc8a"/>
  <path d="M${x + w / 2} ${y} v${h} M${x} ${y + h / 2} h${w}" stroke="#fff" stroke-width="7"/>
  <path d="M${x + w} ${y + h} L${x + w + 170} 700 L${x + w + 40} 700 L${x - 20} ${y + h}Z" fill="url(#beam)" opacity=".7"/></g>`;
const curtain = (x, y, h, c) => `<path d="M${x} ${y} q18 ${h / 2} -6 ${h} h26 q10 -${h / 2} 8 -${h}z" fill="${c}" opacity=".9"/>`;
const shelf = (x, y, w) => `<rect x="${x}" y="${y}" width="${w}" height="12" rx="6" fill="#d9a877"/><rect x="${x}" y="${y + 9}" width="${w}" height="5" rx="2.5" fill="#000" opacity=".12"/>`;
const rug = (cx, cy, rx, ry, a, b) => `<ellipse cx="${cx}" cy="${cy + 6}" rx="${rx}" ry="${ry}" fill="#000" opacity=".08"/><ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${a}"/><ellipse cx="${cx}" cy="${cy}" rx="${rx - 16}" ry="${ry - 8}" fill="none" stroke="${b}" stroke-width="6" stroke-dasharray="2 10" stroke-linecap="round"/>`;
const ROOM_SVG = {
  kitchen: RDEFS + wall('#ffe9d2', '#ffd9b8') +
    `<g opacity=".55">${Array.from({ length: 9 }, (_, i) => `<rect x="${i * 46 - 6}" y="300" width="42" height="42" rx="6" fill="${i % 2 ? '#fff6ea' : '#ffe8d0'}"/><rect x="${i * 46 + 17}" y="346" width="42" height="42" rx="6" fill="${i % 2 ? '#ffe8d0' : '#fff6ea'}"/><rect x="${i * 46 - 6}" y="392" width="42" height="42" rx="6" fill="${i % 2 ? '#fff6ea' : '#ffe8d0'}"/>`).join('')}</g>` +
    windowDay(40, 110, 140, 130) + curtain(24, 96, 170, '#ff9eb8') + curtain(178, 96, 170, '#ff9eb8') + shelf(236, 150, 150) +
    `<rect x="248" y="118" width="26" height="32" rx="6" fill="#ffd56b"/><rect x="286" y="106" width="22" height="44" rx="6" fill="#8fd3ff"/><circle cx="336" cy="134" r="16" fill="#ff8f7a"/><path d="M360 150 q8 -34 22 0z" fill="#7fd07a"/>
    <rect x="228" y="360" width="172" height="110" rx="12" fill="#f5c28e"/><rect x="220" y="350" width="186" height="18" rx="8" fill="#fff0de"/><rect x="244" y="384" width="66" height="66" rx="8" fill="#eab07a"/><rect x="320" y="384" width="66" height="66" rx="8" fill="#eab07a"/><circle cx="300" cy="418" r="5" fill="#fff"/><circle cx="332" cy="418" r="5" fill="#fff"/>
    <path d="M300 342 q10 -24 26 0z" fill="#fff" opacity=".9"/><rect x="290" y="338" width="46" height="12" rx="6" fill="#6c7a89"/>` +
    floor('#f4c794', '#e2a66d') + `<g opacity=".25">${Array.from({ length: 6 }, (_, i) => `<path d="M0 ${500 + i * 36} h400" stroke="#b77c47" stroke-width="3"/>`).join('')}</g>` + rug(200, 580, 150, 38, '#ff9eb8', '#fff') + `<rect width="400" height="700" fill="url(#vign)"/>`,
  bath: RDEFS + wall('#dff4ff', '#c4e8ff') +
    `<g opacity=".7">${Array.from({ length: 9 }, (_, i) => Array.from({ length: 10 }, (_, j) => `<rect x="${i * 46 + 2}" y="${j * 48 + 2}" width="42" height="44" rx="8" fill="${(i + j) % 3 ? '#eaf8ff' : '#d3efff'}"/>`).join('')).join('')}</g>
    <ellipse cx="300" cy="190" rx="62" ry="80" fill="#fff"/><ellipse cx="300" cy="190" rx="52" ry="70" fill="#bfe6ff"/><path d="M272 150 q24 -24 50 -6" stroke="#fff" stroke-width="8" fill="none" stroke-linecap="round" opacity=".85"/>` +
    shelf(30, 128, 110) + `<circle cx="52" cy="112" r="14" fill="#ff9ec7"/><rect x="74" y="92" width="20" height="36" rx="7" fill="#8fd3ff"/><rect x="102" y="100" width="20" height="28" rx="7" fill="#b69cff"/>` +
    floor('#aedcf5', '#8cc6ea') + `<g opacity=".5">${Array.from({ length: 9 }, (_, i) => Array.from({ length: 5 }, (_, j) => (i + j) % 2 ? `<rect x="${i * 46}" y="${474 + j * 46}" width="46" height="46" fill="#c6e8fb"/>` : '').join('')).join('')}</g>
    <path d="M6 390 h212 v44 q0 56 -56 56 h-100 q-56 0 -56 -56z" fill="#fff"/><path d="M6 390 h212 v10 h-212z" fill="#e6f4fb"/><path d="M18 400 h188 v20 q-94 14 -188 0z" fill="#7cc6ff"/>
    ${[36, 66, 96, 126, 156, 186].map((x, i) => `<circle cx="${x}" cy="${392 - (i % 2) * 10}" r="${11 + (i % 3) * 4}" fill="#fff"/><circle cx="${x - 4}" cy="${388 - (i % 2) * 10}" r="3" fill="#dff4ff"/>`).join('')}
    <circle cx="238" cy="404" r="12" fill="#ffd84a"/><path d="M232 396 q6 -12 16 -2" fill="#ffd84a"/><circle cx="242" cy="400" r="2" fill="#333"/>
    <rect x="18" y="300" width="8" height="90" fill="#c9d6e0"/><path d="M22 300 q40 -10 50 20" stroke="#c9d6e0" stroke-width="8" fill="none"/><circle cx="72" cy="326" r="12" fill="#c9d6e0"/>` + rug(300, 600, 80, 26, '#ffc7de', '#fff') + `<rect width="400" height="700" fill="url(#vign)"/>`,
  bed: RDEFS + wall('#e6dcff', '#cfc0ff') +
    `<g opacity=".35">${Array.from({ length: 40 }, (_, i) => `<path d="M${(i * 53) % 400} ${(i * 97) % 450} l3 7 7 3 -7 3 -3 7 -3 -7 -7 -3 7 -3z" fill="#fff"/>`).join('')}</g>
    <g><rect x="32" y="102" width="146" height="146" rx="73" fill="#fff" opacity=".95"/><rect x="40" y="110" width="130" height="130" rx="65" fill="url(#skyN)"/><circle cx="120" cy="158" r="28" fill="#fff5c4"/><circle cx="136" cy="148" r="26" fill="#3c3a88"/>
    ${[[70, 190], [92, 136], [146, 206], [66, 150], [150, 120]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.2" fill="#fff"/>`).join('')}</g>` + curtain(22, 92, 190, '#a98cff') + curtain(180, 92, 190, '#a98cff') +
    `<path d="M300 118 l-46 64 h92 z" fill="#ffd6e8"/><path d="M300 118 l-46 64 h92 z" fill="url(#sunGlow)" opacity=".5"/><rect x="296" y="182" width="8" height="120" fill="#b49ae8"/><ellipse cx="300" cy="302" rx="32" ry="8" fill="#b49ae8"/>
    <ellipse cx="300" cy="190" rx="70" ry="30" fill="#fff6c8" opacity=".25"/>
    <rect x="214" y="330" width="16" height="140" rx="8" fill="#9a7fe0"/><rect x="226" y="372" width="174" height="92" rx="18" fill="#ffb6d2"/><rect x="226" y="372" width="174" height="26" rx="13" fill="#ffd0e2"/><rect x="236" y="346" width="70" height="40" rx="16" fill="#fff"/>
    <path d="M250 404 q20 10 40 0 q20 -10 40 0 q20 10 40 0" stroke="#fff" stroke-width="5" fill="none" opacity=".7"/>` +
    floor('#cbb8f5', '#b19ce8') + rug(170, 590, 150, 40, '#fff', '#c9b6ff') + `<rect width="400" height="700" fill="url(#vign)"/>`,
  play: RDEFS + wall('#e2f8dc', '#c6eebc') +
    `<path d="M0 70 Q100 110 200 70 Q300 110 400 70" fill="none" stroke="#c9a77a" stroke-width="3"/>
    ${[20, 60, 100, 140, 180, 220, 260, 300, 340, 380].map((x, i) => `<path d="M${x - 15} ${76 + Math.sin(i) * 6} l15 28 l15 -28z" fill="${['#ff7aa2', '#ffc93c', '#4db8ff', '#9b7bff', '#3fd0a4'][i % 5]}"/>`).join('')}` +
    windowDay(30, 140, 130, 120) + shelf(238, 170, 140) + shelf(238, 260, 140) +
    `<circle cx="262" cy="152" r="16" fill="#ff7a8a"/><rect x="290" y="130" width="32" height="40" rx="8" fill="#4db8ff"/><path d="M336 170 l16 -38 l16 38z" fill="#ffc93c"/>
    <rect x="252" y="222" width="28" height="38" rx="7" fill="#9b7bff"/><circle cx="312" cy="242" r="18" fill="#3fd0a4"/><rect x="340" y="230" width="30" height="30" rx="6" fill="#ff9ec7"/><text x="355" y="252" font-size="18" text-anchor="middle" fill="#fff" font-weight="900">A</text>` +
    floor('#bfe6a8', '#9fd489') + `<circle cx="200" cy="590" r="140" fill="#fff" opacity=".28"/><circle cx="200" cy="590" r="110" fill="none" stroke="#fff" stroke-width="6" stroke-dasharray="4 14" stroke-linecap="round" opacity=".7"/>
    <g transform="translate(360 520)"><circle r="24" fill="#ff7a8a"/><path d="M-24 0 q24 -14 48 0 M0 -24 v48" stroke="#fff" stroke-width="4" fill="none"/></g><rect width="400" height="700" fill="url(#vign)"/>`,
  closet: RDEFS + wall('#ffe3ef', '#ffcfe2') +
    `${Array.from({ length: 8 }, (_, i) => `<rect x="${i * 56 + 20}" y="0" width="16" height="470" fill="#fff" opacity=".35"/>`).join('')}
    <rect x="26" y="126" width="168" height="344" rx="16" fill="#f7a8c6"/><rect x="36" y="136" width="72" height="326" rx="10" fill="#fbbfd6"/><rect x="112" y="136" width="72" height="326" rx="10" fill="#fbbfd6"/><circle cx="100" cy="300" r="6" fill="#fff"/><circle cx="120" cy="300" r="6" fill="#fff"/>
    <rect x="18" y="116" width="184" height="16" rx="8" fill="#e98fb4"/>
    <ellipse cx="300" cy="228" rx="64" ry="94" fill="#ffd36e"/><ellipse cx="300" cy="228" rx="54" ry="84" fill="#dff3ff"/><path d="M270 180 q22 -24 48 -8" stroke="#fff" stroke-width="8" fill="none" stroke-linecap="round"/>
    ${[[250, 140], [352, 160], [360, 300], [244, 316]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="5" fill="#fff" opacity=".9"/>`).join('')}` +
    floor('#f7c1d6', '#eea3c1') + rug(260, 590, 130, 36, '#fff', '#ffb0cf') + `<rect width="400" height="700" fill="url(#vign)"/>`,
};
// Posiciones visibles en un iPhone (la escena recorta ~40 unidades por lado y la bandeja tapa y>500)
const SLOTS = {
  kitchen: { techo: [200, 190, 50], pared: [300, 260, 62], estante: [312, 128, 40], sueloI: [78, 440, 78], sueloD: [322, 450, 70] },
  bath: { techo: [190, 190, 50], pared: [200, 250, 56], estante: [120, 90, 36], sueloI: [80, 330, 60], sueloD: [322, 450, 70] },
  bed: { techo: [200, 190, 50], pared: [200, 270, 56], estante: [300, 250, 40], sueloI: [80, 440, 78], sueloD: [322, 330, 60] },
  play: { techo: [200, 190, 50], pared: [100, 330, 60], estante: [296, 208, 40], sueloI: [78, 440, 78], sueloD: [322, 450, 70] },
  closet: { techo: [200, 190, 50], pared: [300, 380, 58], estante: [110, 100, 38], sueloI: [78, 440, 78], sueloD: [322, 450, 70] },
};

// Fondos pintados (ilustraciones de Gemini). Si una habitación tiene imagen aquí, sustituye al dibujo SVG.
// p. ej. kitchen: 'rooms/cocina.jpg' (vertical, 1080x1920 o similar).
const ROOM_IMG = {};
