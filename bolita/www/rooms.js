/* Habitaciones ilustradas (SVG plano, estilo pastel). viewBox 400x700; el suelo empieza en y=470.
   Se dibujan a pantalla completa detrás de la interfaz de cristal. */
const ROOM_SVG = {
  kitchen: `<rect width="400" height="700" fill="#fff1dd"/>
    <g opacity=".5">${Array.from({ length: 10 }, (_, i) => `<path d="M${i * 44 - 10} 330 v140" stroke="#ffe0bd" stroke-width="2"/>`).join('')}${Array.from({ length: 4 }, (_, i) => `<path d="M0 ${330 + i * 36} h400" stroke="#ffe0bd" stroke-width="2"/>`).join('')}</g>
    <rect x="34" y="120" width="130" height="120" rx="16" fill="#bfe7ff" stroke="#fff" stroke-width="10"/><path d="M99 120 v120 M34 180 h130" stroke="#fff" stroke-width="6"/>
    <circle cx="70" cy="160" r="14" fill="#fff8d6"/><path d="M110 210 q20 -24 44 0" fill="#d9f1ff"/>
    <rect x="236" y="120" width="130" height="16" rx="8" fill="#e8b98a"/><circle cx="262" cy="110" r="14" fill="#ff8f7a"/><rect x="290" y="96" width="22" height="24" rx="5" fill="#ffd56b"/><path d="M322 120 q10 -34 26 0z" fill="#9ed98f"/>
    <rect x="236" y="380" width="164" height="90" rx="10" fill="#f3c998"/><rect x="236" y="372" width="164" height="14" rx="6" fill="#e3b27f"/><circle cx="276" cy="428" r="6" fill="#d19a63"/><circle cx="340" cy="428" r="6" fill="#d19a63"/>
    <rect y="470" width="400" height="230" fill="#f0cfa4"/>${Array.from({ length: 6 }, (_, i) => `<path d="M0 ${500 + i * 36} h400" stroke="#e5bf90" stroke-width="3"/>`).join('')}
    <ellipse cx="200" cy="560" rx="150" ry="34" fill="#ffb4a2" opacity=".55"/>`,
  bath: `<rect width="400" height="700" fill="#e4f5ff"/>
    <g>${Array.from({ length: 9 }, (_, i) => `<path d="M${i * 50} 0 v470" stroke="#d2ecfb" stroke-width="3"/>`).join('')}${Array.from({ length: 10 }, (_, i) => `<path d="M0 ${i * 50} h400" stroke="#d2ecfb" stroke-width="3"/>`).join('')}</g>
    <ellipse cx="300" cy="170" rx="54" ry="70" fill="#cfeaff" stroke="#fff" stroke-width="10"/><path d="M276 140 q20 -20 40 0" stroke="#fff" stroke-width="6" fill="none" opacity=".8"/>
    <rect x="40" y="90" width="60" height="10" rx="5" fill="#fff"/><circle cx="56" cy="80" r="11" fill="#ff9ec7"/><rect x="72" y="64" width="16" height="26" rx="6" fill="#8fd3ff"/>
    <rect y="470" width="400" height="230" fill="#bfe1f5"/>${Array.from({ length: 8 }, (_, i) => Array.from({ length: 5 }, (_, j) => (i + j) % 2 ? `<rect x="${i * 50}" y="${470 + j * 50}" width="50" height="50" fill="#aed6ef"/>` : '').join('')).join('')}
    <path d="M10 400 h200 v40 q0 50 -50 50 h-100 q-50 0 -50 -50 z" fill="#fff" stroke="#bfdcee" stroke-width="4"/><path d="M20 404 h180 v18 h-180z" fill="#9ed6ff"/>
    ${[40, 70, 100, 130, 160, 190].map((x, i) => `<circle cx="${x}" cy="${396 - (i % 2) * 8}" r="${10 + (i % 3) * 3}" fill="#fff" stroke="#d6ecfa" stroke-width="2"/>`).join('')}
    <circle cx="232" cy="398" r="10" fill="#ffd84a"/><path d="M226 390 q6 -10 14 -2" fill="#ffd84a"/>`,
  bed: `<rect width="400" height="700" fill="#ebe3ff"/>
    ${Array.from({ length: 30 }, (_, i) => `<circle cx="${(i * 73) % 400}" cy="${(i * 131) % 460}" r="2" fill="#fff" opacity=".7"/>`).join('')}
    <rect x="40" y="110" width="130" height="130" rx="65" fill="#3c3a7a" stroke="#fff" stroke-width="10"/><circle cx="118" cy="160" r="26" fill="#fff5c4"/><circle cx="132" cy="150" r="24" fill="#3c3a7a"/>
    <circle cx="70" cy="190" r="2.5" fill="#fff"/><circle cx="92" cy="140" r="2" fill="#fff"/><circle cx="140" cy="206" r="2" fill="#fff"/>
    <path d="M290 120 l-40 60 h80 z" fill="#ffd6e8"/><rect x="286" y="180" width="8" height="120" fill="#c9b8ee"/><ellipse cx="290" cy="300" rx="30" ry="8" fill="#c9b8ee"/>
    <rect y="470" width="400" height="230" fill="#d9ccf5"/><ellipse cx="200" cy="570" rx="160" ry="40" fill="#fff" opacity=".45"/>
    <rect x="230" y="380" width="170" height="80" rx="16" fill="#ffb6cf"/><rect x="230" y="360" width="60" height="40" rx="14" fill="#fff"/><rect x="224" y="330" width="14" height="140" rx="7" fill="#b89be6"/>`,
  play: `<rect width="400" height="700" fill="#e7f8e3"/>
    <path d="M0 80 Q100 120 200 80 Q300 120 400 80" fill="none" stroke="#c9b28a" stroke-width="3"/>
    ${[20, 60, 100, 140, 180, 220, 260, 300, 340, 380].map((x, i) => `<path d="M${x - 14} ${84 + Math.sin(i) * 6} l14 26 l14 -26z" fill="${['#ff9e9e', '#ffd56b', '#8fd3ff', '#b69cff', '#9ee59a'][i % 5]}"/>`).join('')}
    <rect x="250" y="170" width="120" height="14" rx="7" fill="#e0b98a"/><rect x="250" y="250" width="120" height="14" rx="7" fill="#e0b98a"/>
    <circle cx="276" cy="154" r="16" fill="#ff8f8f"/><rect x="304" y="136" width="30" height="34" rx="6" fill="#8fd3ff"/><path d="M340 170 l14 -34 l14 34z" fill="#ffd56b"/>
    <rect x="262" y="218" width="26" height="32" rx="6" fill="#b69cff"/><circle cx="318" cy="234" r="16" fill="#9ee59a"/>
    <rect y="470" width="400" height="230" fill="#c8e8b5"/><circle cx="200" cy="580" r="130" fill="#fff" opacity=".35"/>
    <circle cx="60" cy="520" r="26" fill="#ff8f8f"/><path d="M34 520 q26 -14 52 0 M60 494 v52" stroke="#fff" stroke-width="4" fill="none"/>`,
  closet: `<rect width="400" height="700" fill="#ffe8f0"/>
    ${Array.from({ length: 8 }, (_, i) => `<path d="M${i * 56} 0 v470" stroke="#ffd6e4" stroke-width="18"/>`).join('')}
    <rect x="30" y="130" width="160" height="340" rx="14" fill="#f3b8cb"/><path d="M110 140 v320" stroke="#e59bb3" stroke-width="4"/><circle cx="98" cy="300" r="6" fill="#fff"/><circle cx="122" cy="300" r="6" fill="#fff"/>
    <ellipse cx="300" cy="230" rx="60" ry="90" fill="#dff3ff" stroke="#ffd36e" stroke-width="10"/><path d="M270 190 q20 -22 44 -6" stroke="#fff" stroke-width="7" fill="none"/>
    <rect y="470" width="400" height="230" fill="#f5c6d6"/><ellipse cx="200" cy="570" rx="150" ry="38" fill="#fff" opacity=".4"/>`,
};
