/* =====================================================================
   Gráficos SVG propios (sin librerías, funcionan sin conexión)
   ===================================================================== */
function niceTicks(min, max, n = 3) {
  if (min === max) { const d = Math.abs(min) || 1; min -= d * 0.1; max += d * 0.1; }
  const span = max - min; const raw = span / n; const mag = Math.pow(10, Math.floor(Math.log10(raw)));
  const step = [1, 2, 2.5, 5, 10].map(m => m * mag).find(s => s >= raw) || raw;
  const lo = Math.floor(min / step) * step, hi = Math.ceil(max / step) * step;
  const out = []; for (let v = lo; v <= hi + step / 2; v += step) out.push(Math.round(v / step) * step);
  return out;
}
function axisFmt(v) {
  const a = Math.abs(v);
  if (a >= 1e6) return nf('ax6', { maximumFractionDigits: 1 }).format(v / 1e6) + ' M';
  if (a >= 1e4) return nf('ax3', { maximumFractionDigits: 0 }).format(v / 1e3) + ' k';
  if (a >= 1e3) return nf('ax3b', { maximumFractionDigits: 1 }).format(v / 1e3) + ' k';
  return nf('ax0', { maximumFractionDigits: a < 10 ? 2 : 0 }).format(v);
}

// Línea mínima (sin ejes) para el patrimonio del resumen y los activos
function spark(vals, h = 56) {
  if (!vals || vals.length < 2) return '';
  const w = 300, min = Math.min(...vals), max = Math.max(...vals), span = (max - min) || Math.abs(max) * 0.01 || 1;
  const pts = vals.map((v, i) => [i / (vals.length - 1) * w, (h - 4) - (v - min) / span * (h - 10)]);
  const d = pts.map((p, i) => (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' ');
  return `<svg class="spark" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" aria-hidden="true"><path class="spark-area" d="${d} L${w} ${h} L0 ${h} Z"/><path class="spark-line" d="${d}" vector-effect="non-scaling-stroke"/></svg>`;
}

// Línea con ejes: series = [{label, v}]
function lineChart(series, o = {}) {
  if (!series || series.length < 2) return '';
  const W = 340, H = o.h || 170, L = 44, R = 10, T = 12, B = 22;
  const vals = series.map(s => s.v); const ticks = niceTicks(Math.min(...vals, o.zero ? 0 : Infinity), Math.max(...vals));
  const y0 = ticks[0], y1 = ticks[ticks.length - 1];
  const X = i => L + i / (series.length - 1) * (W - L - R);
  const Y = v => T + (1 - (v - y0) / ((y1 - y0) || 1)) * (H - T - B);
  const d = series.map((s, i) => (i ? 'L' : 'M') + X(i).toFixed(1) + ' ' + Y(s.v).toFixed(1)).join(' ');
  const grid = ticks.map(t => `<line class="grid" x1="${L}" x2="${W - R}" y1="${Y(t).toFixed(1)}" y2="${Y(t).toFixed(1)}"/><text x="${L - 6}" y="${(Y(t) + 3).toFixed(1)}" text-anchor="end">${axisFmt(t)}</text>`).join('');
  const every = Math.ceil(series.length / 6);
  const xl = series.map((s, i) => (i % every === 0 || i === series.length - 1) && (i === series.length - 1 || series.length - 1 - i >= every / 2) ? `<text x="${X(i).toFixed(1)}" y="${H - 6}" text-anchor="middle">${esc(s.label)}</text>` : '').join('');
  const last = series[series.length - 1];
  const sc = o.scrub ? ` data-pts='${JSON.stringify(series.map((p, i) => [+X(i).toFixed(1), +Y(p.v).toFixed(1)]))}' data-top="${T}" data-bot="${H - B}"` : '';
  const scEls = o.scrub ? `<line class="scrub-l" x1="0" x2="0" y1="${T}" y2="${H - B}" visibility="hidden"/><circle class="scrub-c" r="4.5" cx="0" cy="0" visibility="hidden"/>` : '';
  const lnCls = o.cls ? ` ${o.cls}` : '';
  return `<svg class="chart${o.scrub ? ' scrubbable' : ''}" viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(o.aria || 'Gráfico de evolución')}"${sc}>${grid}<path class="ar${lnCls}" d="${d} L${X(series.length - 1).toFixed(1)} ${Y(y0).toFixed(1)} L${L} ${Y(y0).toFixed(1)} Z"/><path class="ln${lnCls}" d="${d}"/><circle class="end" cx="${X(series.length - 1).toFixed(1)}" cy="${Y(last.v).toFixed(1)}" r="4"/>${xl}${scEls}</svg>`;
}

// Barras dobles ingresos / gastos: data = [{label, inc, exp}]
function barsChart(data, o = {}) {
  const W = 340, H = o.h || 180, L = 44, R = 6, T = 10, B = 22;
  const max = Math.max(1, ...data.map(d => Math.max(d.inc, d.exp)));
  const ticks = niceTicks(0, max); const y1 = ticks[ticks.length - 1];
  const Y = v => T + (1 - v / y1) * (H - T - B);
  const gw = (W - L - R) / data.length, bw = Math.max(3, Math.min(12, gw * 0.34));
  const grid = ticks.map(t => `<line class="grid" x1="${L}" x2="${W - R}" y1="${Y(t).toFixed(1)}" y2="${Y(t).toFixed(1)}"/><text x="${L - 6}" y="${(Y(t) + 3).toFixed(1)}" text-anchor="end">${axisFmt(t)}</text>`).join('');
  const bars = data.map((d, i) => {
    const cx = L + gw * i + gw / 2;
    const bi = `<rect class="inc" x="${(cx - bw - 1).toFixed(1)}" y="${Y(d.inc).toFixed(1)}" width="${bw.toFixed(1)}" height="${Math.max(0, Y(0) - Y(d.inc)).toFixed(1)}" rx="2"><title>${esc(d.label)} · ingresos ${fmt(d.inc)}</title></rect>`;
    const be = `<rect class="exp" x="${(cx + 1).toFixed(1)}" y="${Y(d.exp).toFixed(1)}" width="${bw.toFixed(1)}" height="${Math.max(0, Y(0) - Y(d.exp)).toFixed(1)}" rx="2"><title>${esc(d.label)} · gastos ${fmt(d.exp)}</title></rect>`;
    return bi + be + `<text x="${cx.toFixed(1)}" y="${H - 6}" text-anchor="middle">${esc(d.label)}</text>`;
  }).join('');
  return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="Ingresos y gastos por mes">${grid}${bars}</svg>`;
}

// Donut: segs = [{v, color}]
function donut(segs, centerTop, centerSub) {
  const total = sum(segs, s => s.v); const R = 42, C = 2 * Math.PI * R; let off = 0;
  const gap = segs.length > 1 ? 1.2 : 0;
  const arcs = total > 0 ? segs.map(s => { const len = s.v / total * C; const a = `<circle r="${R}" cx="50" cy="50" fill="none" stroke="${s.color}" stroke-width="13" stroke-dasharray="${Math.max(0, len - gap).toFixed(2)} ${(C - Math.max(0, len - gap)).toFixed(2)}" stroke-dashoffset="${(-off).toFixed(2)}"/>`; off += len; return a; }).join('')
    : `<circle r="${R}" cx="50" cy="50" fill="none" stroke="var(--surface-2)" stroke-width="13"/>`;
  return `<div class="donut"><svg viewBox="0 0 100 100" aria-hidden="true">${arcs}</svg><div class="c"><b class="amt">${centerTop}</b><span>${centerSub}</span></div></div>`;
}

// Barras de una serie (evolución de una categoría)
function bars1(data, o = {}) {
  const W = 340, H = o.h || 160, L = 44, R = 6, T = 10, B = 22;
  const ticks = niceTicks(0, Math.max(1, ...data.map(d => d.v))); const y1 = ticks[ticks.length - 1];
  const Y = v => T + (1 - v / y1) * (H - T - B); const gw = (W - L - R) / data.length, bw = Math.max(4, Math.min(16, gw * 0.6));
  const avg = o.avg != null ? `<line class="zero" x1="${L}" x2="${W - R}" y1="${Y(o.avg).toFixed(1)}" y2="${Y(o.avg).toFixed(1)}"/>` : '';
  return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(o.aria || 'Evolución')}">${ticks.map(t => `<line class="grid" x1="${L}" x2="${W - R}" y1="${Y(t).toFixed(1)}" y2="${Y(t).toFixed(1)}"/><text x="${L - 6}" y="${(Y(t) + 3).toFixed(1)}" text-anchor="end">${axisFmt(t)}</text>`).join('')}${data.map((d, i) => { const cx = L + gw * i + gw / 2; return `<rect x="${(cx - bw / 2).toFixed(1)}" y="${Y(d.v).toFixed(1)}" width="${bw.toFixed(1)}" height="${Math.max(0, Y(0) - Y(d.v)).toFixed(1)}" rx="3" fill="${o.color || 'var(--accent)'}" opacity="${i === data.length - 1 ? 1 : .7}"><title>${esc(d.label)} · ${fmt(d.v)}</title></rect><text x="${cx.toFixed(1)}" y="${H - 6}" text-anchor="middle">${esc(d.label)}</text>`; }).join('')}${avg}</svg>`;
}
