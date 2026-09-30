/* Sprites de las criaturas: se recortan de criaturas.jpg (la lámina que David creó con Gemini) y se les
   quita el fondo de papel al arrancar: relleno desde los bordes del recorte por los píxeles claros y poco
   saturados, con borde suavizado. SPRITES[id] = dataURL PNG transparente (listo tras loadSprites()).
   BOX = [x, y, ancho, alto] en la lámina de 1024×559. */
const BOX = {
  'hoja:1': [52, 22, 180, 150], 'hoja:2': [34, 176, 196, 172], 'hoja:3': [10, 342, 228, 214],
  'rayo:1': [284, 34, 180, 160], 'rayo:2': [288, 190, 192, 160], 'rayo:3': [280, 340, 214, 216],
  'agua:1': [540, 44, 196, 132], 'agua:2': [548, 180, 184, 170], 'agua:3': [530, 340, 212, 216],
  'fuego:1': [794, 22, 172, 156], 'fuego:2': [798, 176, 182, 168], 'fuego:3': [764, 342, 224, 214],
};
const SPRITES = {};
function loadSprites(src = 'criaturas.jpg') {
  return new Promise((ok, ko) => {
    const img = new Image();
    img.onload = () => {
      for (const [id, [bx, by, bw, bh]] of Object.entries(BOX)) {
        const c = document.createElement('canvas'); c.width = bw; c.height = bh;
        const g = c.getContext('2d'); g.drawImage(img, bx, by, bw, bh, 0, 0, bw, bh);
        const d = g.getImageData(0, 0, bw, bh), p = d.data, seen = new Uint8Array(bw * bh), q = [];
        const bg = i => { const r = p[i * 4], gg = p[i * 4 + 1], b = p[i * 4 + 2]; return Math.min(r, gg, b) > 214 && Math.max(r, gg, b) - Math.min(r, gg, b) < 26; };
        for (let x = 0; x < bw; x++) q.push(x, (bh - 1) * bw + x);
        for (let y = 0; y < bh; y++) q.push(y * bw, y * bw + bw - 1);
        while (q.length) { const i = q.pop(); if (seen[i]) continue; seen[i] = 1; if (!bg(i)) continue; p[i * 4 + 3] = 0; const x = i % bw, y = (i / bw) | 0;
          if (x > 0) q.push(i - 1); if (x < bw - 1) q.push(i + 1); if (y > 0) q.push(i - bw); if (y < bh - 1) q.push(i + bw); }
        // quita trocitos sueltos que tocan el borde del recorte (restos del texto o de la criatura vecina)
        const lab = new Int32Array(bw * bh), sizes = [0], edge = [false];
        for (let s = 0; s < bw * bh; s++) { if (!p[s * 4 + 3] || lab[s]) continue; const id = sizes.length; let n = 0, e = false; const st = [s]; lab[s] = id;
          while (st.length) { const i = st.pop(); n++; const x = i % bw, y = (i / bw) | 0; if (x === 0 || y === 0 || x === bw - 1 || y === bh - 1) e = true;
            for (const j of [x > 0 ? i - 1 : -1, x < bw - 1 ? i + 1 : -1, y > 0 ? i - bw : -1, y < bh - 1 ? i + bw : -1]) if (j >= 0 && p[j * 4 + 3] && !lab[j]) { lab[j] = id; st.push(j); } }
          sizes.push(n); edge.push(e); }
        const big = Math.max(...sizes);
        for (let i = 0; i < bw * bh; i++) { const l = lab[i]; if (l && ((edge[l] && sizes[l] < big * .06) || sizes[l] < 6)) p[i * 4 + 3] = 0; }
        // borde suave: píxeles claros pegados al fondo quitado → semitransparentes
        for (let y = 1; y < bh - 1; y++) for (let x = 1; x < bw - 1; x++) { const i = y * bw + x; if (!p[i * 4 + 3]) continue;
          const n = (!p[(i - 1) * 4 + 3]) + (!p[(i + 1) * 4 + 3]) + (!p[(i - bw) * 4 + 3]) + (!p[(i + bw) * 4 + 3]);
          if (n && Math.min(p[i * 4], p[i * 4 + 1], p[i * 4 + 2]) > 190) p[i * 4 + 3] = 120; }
        g.putImageData(d, 0, 0);
        SPRITES[id] = c.toDataURL('image/png');
      }
      ok();
    };
    img.onerror = ko; img.src = src;
  });
}
