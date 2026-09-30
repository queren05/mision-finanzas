/* =====================================================================
   Vistas
   ===================================================================== */
const ICONS = {
  bank: '<path d="M3 10h18M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20.5h18M12 3l9 5H3z"/>',
  target: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1" fill="currentColor"/>',
  grid: '<rect x="3.5" y="3.5" width="7" height="7" rx="2"/><rect x="13.5" y="3.5" width="7" height="7" rx="2"/><rect x="3.5" y="13.5" width="7" height="7" rx="2"/><rect x="13.5" y="13.5" width="7" height="7" rx="2"/>',
  sliders: '<path d="M4 6h9M19 6h1M4 12h3M13 12h7M4 18h11M21 18h-1"/><circle cx="16" cy="6" r="2.2"/><circle cx="10" cy="12" r="2.2"/><circle cx="18" cy="18" r="2.2"/>',
  tag: '<path d="M3.5 12.5V4.5a1 1 0 0 1 1-1h8l8 8a1.4 1.4 0 0 1 0 2l-7 7a1.4 1.4 0 0 1-2 0z"/><circle cx="8" cy="8" r="1.4"/>',
  gauge: '<path d="M4 18a8 8 0 1 1 16 0"/><path d="M12 18l4-6"/>',
  repeat: '<path d="M17 2.5l3 3-3 3"/><path d="M4 11.5v-2a4 4 0 0 1 4-4h12"/><path d="M7 21.5l-3-3 3-3"/><path d="M20 12.5v2a4 4 0 0 1-4 4H4"/>',
  coins: '<circle cx="9" cy="9" r="6"/><path d="M15.4 9.3a6 6 0 1 1-6.1 6.1"/>',
  download: '<path d="M12 3.5v11M7.5 10l4.5 4.5 4.5-4.5"/><path d="M4 16.5v3.5h16v-3.5"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
  pulse: '<path d="M3 12h4l3-7 4 14 3-7h4"/>',
  gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12 18.5v3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M2.5 12h3M18.5 12h3M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/>',
  phone: '<rect x="6" y="2.5" width="12" height="19" rx="3"/><path d="M10.5 18.5h3"/>',
  chev: '<path d="M9 6l6 6-6 6"/>', chevL: '<path d="M15 6l-6 6 6 6"/>',
  up: '<path d="M6 15l6-6 6 6"/>', down: '<path d="M6 9l6 6 6-6"/>',
  eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
  eyeOff: '<path d="M4 4l16 16"/><path d="M10.6 5.7A10 10 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a17 17 0 0 1-2.9 3.7M6.6 6.9C4 8.6 2.5 12 2.5 12S6 18.5 12 18.5c1.6 0 3-.4 4.2-1"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6l1.4 1.4M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4L6 18M18 6l1.4-1.4"/>',
  moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
  auto: '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5v17a8.5 8.5 0 0 0 0-17z" fill="currentColor"/>',
  swap: '<path d="M7 4L3.5 7.5 7 11"/><path d="M3.5 7.5H17"/><path d="M17 13l3.5 3.5L17 20"/><path d="M20.5 16.5H7"/>',
  refresh: '<path d="M20 11a8 8 0 1 0-2.3 5.7"/><path d="M20 4.5V11h-6.5"/>',
  bolt: '<path d="M13 2.5L4.5 13.5H12l-1 8 8.5-11H12z"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
  palette: '<path d="M12 3.5a8.5 8.5 0 1 0 0 17c1.2 0 1.8-.8 1.8-1.7 0-1.3-1-1.6-1-2.6 0-.9.7-1.5 1.7-1.5h2a3.5 3.5 0 0 0 3.5-3.5C20 7 16.4 3.5 12 3.5z"/><circle cx="7.5" cy="11" r="1.2" fill="currentColor"/><circle cx="10" cy="7.5" r="1.2" fill="currentColor"/><circle cx="14.5" cy="7.5" r="1.2" fill="currentColor"/>',
  star: '<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
};
const svg = (k, cls = '') => `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[k] || ''}</svg>`;

const UI = {
  route: 'home', stack: [],
  txF: { month: monthKey(today()), q: '', type: 'all', acc: 'all', cat: 'all' }, txLimit: 300, txView: 'list', calDay: null,
  invF: 'all', statsMonth: monthKey(today()), statsMode: 'month', statsYear: new Date().getFullYear(), catKind: 'expense', imp: null, P: null, sheetLive: null,
};
const TITLES = {
  home: 'Resumen', txs: 'Movimientos', inv: 'Inversiones', stats: 'Análisis', more: 'Más',
  'more/accounts': 'Cuentas', 'more/goals': 'Objetivos', 'more/groups': 'Bloques del resumen', 'more/home': 'Personalizar el resumen',
  'more/categories': 'Categorías', 'more/budgets': 'Presupuestos', 'more/recurring': 'Recurrentes', 'more/fx': 'Divisas',
  'more/import': 'Importar del banco', 'more/bank': 'Conectar el banco', 'more/backup': 'Copia de seguridad',
  'more/prices': 'Fuentes de precios', 'more/settings': 'Ajustes', 'more/install': 'Instalar en el iPhone',
  'more/look': 'Apariencia', 'more/shortcuts': 'Atajos de iPhone', 'more/security': 'Seguridad', 'more/templates': 'Plantillas',
};
const VIEWS = {}, AFTER = {}, HOME = {};

function go(r, opts = {}) {
  const [main] = r.split('/');
  if (opts.reset || !r.includes('/')) UI.stack = [];
  else if (UI.route !== r) UI.stack.push(UI.route);
  UI.route = r;
  if (main === 'txs' && opts.acc) { UI.txF = { month: 'all', q: '', type: 'all', acc: opts.acc, cat: 'all' }; }
  if (main === 'txs' && opts.cat) { UI.txF = { month: opts.month || curMk(), q: '', type: 'all', acc: 'all', cat: opts.cat }; }
  try { history.replaceState(null, '', '#' + r.replace('/', '-')); } catch (e) { }
  render(true);
}
function back() { const r = UI.stack.pop() || UI.route.split('/')[0]; UI.route = r; try { history.replaceState(null, '', '#' + r.replace('/', '-')); } catch (e) { } render(true); }

function render(scrollTop) {
  const P = portfolio(); UI.P = P;
  const r = UI.route; const [main, sub] = r.split('/');
  $$('.tab').forEach(t => t.setAttribute('aria-current', t.dataset.tab === main ? 'page' : 'false'));
  $('#backBtn').hidden = !sub; $('#top').classList.toggle('sub', !!sub);
  $('#viewTitle').textContent = TITLES[r] || 'Caudal';
  $('#fab').hidden = !['home', 'txs', 'stats'].includes(r);
  $('#demoBanner').hidden = !S.demo;
  const v = $('#view');
  v.innerHTML = (VIEWS[r] || VIEWS.home)(P);
  if (AFTER[r]) AFTER[r]();
  for (const id in PX.flash) PX.flash[id].shown = true;
  if (scrollTop) window.scrollTo(0, 0);
  chrome();
}
function chrome() {
  document.body.classList.toggle('privacy', !!S.settings.privacy);
  $('#privacyBtn').innerHTML = svg(S.settings.privacy ? 'eyeOff' : 'eye');
  $('#privacyBtn').setAttribute('aria-label', S.settings.privacy ? 'Mostrar importes' : 'Ocultar importes');
  const th = S.settings.theme; $('#themeBtn').innerHTML = svg(th === 'dark' ? 'moon' : th === 'light' ? 'sun' : 'auto');
  $('#themeBtn').setAttribute('aria-label', 'Tema: ' + (th === 'dark' ? 'oscuro' : th === 'light' ? 'claro' : 'automático'));
  updateLive();
}
let liveT = null;
function scheduleLive(now) {
  if (now) { clearTimeout(liveT); liveT = null; renderLive(); return; }
  if (liveT) return; liveT = setTimeout(() => { liveT = null; renderLive(); }, 900);
}
function renderLive() {
  if (!S) return;
  updateLive();
  UI.P = portfolio();
  if (UI.sheetLive) { try { UI.sheetLive(); } catch (e) { console.warn(e); } }
  const r = UI.route;
  if (r === 'more/fx') { const d = $('#fxDyn'); if (d) d.innerHTML = fxDyn(UI.P); updateConv(); return; }
  if (!['home', 'inv', 'more/accounts', 'more/goals', 'more/groups'].includes(r)) return;
  const ae = document.activeElement;
  if (ae && $('#view').contains(ae) && /INPUT|SELECT|TEXTAREA/.test(ae.tagName)) return;
  render(false);
}

/* ---------- piezas compartidas ---------- */
const ico = (content, color, cls = '') => `<span class="ico ${cls}" style="--c:${color || 'var(--accent)'}">${content}</span>`;
function sortTx(list) { return list.map((t, i) => [t, i]).sort((a, b) => a[0].date < b[0].date ? 1 : a[0].date > b[0].date ? -1 : b[1] - a[1]).map(x => x[0]); }
function catOf(t) { return catById(t.categoryId) || { name: 'Sin categoría', icon: '•', color: '#a9b3c2' }; }
function txRow(t, ctxAcc) {
  const acc = accById(t.accountId); const cur = acc ? acc.currency : S.settings.base;
  let icon, color, title, sub, val, cls = '', vccy = cur;
  if (t.type === 'transfer') {
    const to = accById(t.toAccountId);
    icon = svg('swap'); color = 'var(--muted)'; title = t.note || 'Transferencia';
    sub = `${acc ? esc(acc.name) : '¿?'} → ${to ? esc(to.name) : '¿?'}`;
    if (ctxAcc && ctxAcc === t.toAccountId) { val = fmt(t.toAmount ?? t.amount, to ? to.currency : cur, { sign: true }); cls = 'pos'; }
    else if (ctxAcc && ctxAcc === t.accountId) val = fmt(-t.amount, cur, { sign: true });
    else { val = fmt(t.amount, cur); cls = 'muted'; }
  } else if (t.type === 'adjust') {
    icon = '±'; color = 'var(--muted)'; title = t.note || 'Ajuste de saldo'; sub = acc ? esc(acc.name) : '';
    val = fmt(t.amount, cur, { sign: true }); cls = pcls(t.amount);
  } else {
    const c = catOf(t); icon = esc(c.icon); color = c.color;
    title = esc(t.note || c.name);
    if (t.splits && t.splits.length) { icon = '⋔'; color = 'var(--accent)'; if (!t.note) title = 'Dividido en ' + t.splits.length; }
    sub = [t.splits && t.splits.length ? t.splits.map(p => esc((catById(p.categoryId) || {}).name || '')).join(' + ') : (t.note ? esc(c.name) : ''), acc ? esc(acc.name) : '', (t.tags || []).map(x => '#' + esc(x)).join(' '), t.recId ? 'recurrente' : '', t.excl ? 'fuera de estadísticas' : '', t.src === 'atajo' ? 'Atajos' : ''].filter(Boolean).join(' · ');
    if (t.type === 'income') { val = fmt(t.amount, cur, { sign: true }); cls = 'pos'; } else val = fmt(-t.amount, cur, { sign: true });
  }
  const baseEq = cur !== S.settings.base && t.type !== 'transfer' ? `<span class="row-s amt">${fmt(conv(t.amount, cur))}</span>` : '';
  return `<button class="row" data-action="tx-edit" data-id="${t.id}">${ico(icon, color)}<div class="row-m"><div class="row-t">${title}</div><div class="row-s">${sub}</div></div><div class="row-r"><span class="num amt ${cls}">${val}</span>${baseEq}</div></button>`;
}
function linkRow(route, icon, title, sub, color) {
  return `<button class="row" data-go="${route}">${ico(svg(icon), color || 'var(--accent)')}<div class="row-m"><div class="row-t">${title}</div>${sub ? `<div class="row-s">${sub}</div>` : ''}</div>${svg('chev', 'chev')}</button>`;
}
function emptyCard(title, text, btns = '') { return `<div class="card empty"><b>${title}</b><span>${text}</span>${btns}</div>`; }
const assetColor = a => a.color || PALETTE[[...String(a.symbol)].reduce((h, c) => h + c.charCodeAt(0), 0) % PALETTE.length];
const assetTag = a => esc(String(a.symbol).split(/[.\-]/)[0].slice(0, 4));

/* =============================== RESUMEN =============================== */
VIEWS.home = P => {
  if (!S.accounts.length && !S.assets.length) {
    return `<section class="hero"><div class="eyebrow">Patrimonio total</div><div class="hero-num">${fmt(0)}</div></section>
    ${emptyCard('Empieza por tus cuentas', 'Añade tu cuenta principal con el saldo que tienes hoy. Después tus ahorros, el efectivo, tu exchange de cripto o tu bróker.', `<button class="btn primary" data-action="acc-new">Añadir cuenta</button><button class="link" data-action="load-demo">Ver la app con datos de ejemplo</button>`)}`;
  }
  const body = S.settings.home.filter(h => h.on).map(h => HOME[h.k] ? HOME[h.k](P) : '').join('');
  return heroHtml(P) + body + `<div class="hstack" style="justify-content:center"><button class="link" data-go="more/home">Personalizar el resumen</button></div>`;
};
function greeting() { const h = new Date().getHours(); return h < 6 ? 'Buenas noches' : h < 13 ? 'Buenos días' : h < 21 ? 'Buenas tardes' : 'Buenas noches'; }
function heroHtml(P) {
  const ser = nwSeries(30);
  const d30 = ser.kind === 'snap' && ser.vals.length >= 2 ? P.nw - ser.vals[0] : null;
  return `<section class="hero">
    <div class="eyebrow">${S.settings.name ? esc(greeting() + ', ' + S.settings.name) + ' · ' : ''}Patrimonio total</div>
    <div class="hero-num amt">${fmt(P.nw)}</div>
    <div class="hero-sub">
      ${P.assets.some(r => r.pr && r.pr.src !== 'manual') ? `<span class="chip ${pcls(P.dayChg)}"><span class="amt">${fmt(P.dayChg, null, { sign: true })}</span>&nbsp;hoy</span>` : ''}
      ${d30 != null ? `<span class="chip ${pcls(d30)}"><span class="amt">${fmt(d30, null, { sign: true })}</span>&nbsp;en 30 días</span>` : ''}
      <span class="chip"><span class="amt">${fmt(P.cashTotal, null, { compact: true })}</span>&nbsp;en cuentas</span>
      ${P.assets.length ? `<span class="chip"><span class="amt">${fmt(P.assetsTotal, null, { compact: true })}</span>&nbsp;invertido</span>` : ''}
    </div>
    ${spark(ser.vals)}
    <div class="note">${ser.kind === 'snap' ? 'Tu patrimonio en los últimos 30 días.' : 'Saldo de tus cuentas en los últimos 30 días. El patrimonio completo se guarda cada día que abres la app.'}</div>
  </section>`;
}
HOME.period = P => {
  const p = S.settings.period || 'month'; const R = periodRange(p);
  const cur = flows(R.from, R.to > today() ? today() : R.to); const prev = flows(R.prevFrom, R.prevTo);
  const dExp = prev.exp > 0 ? (cur.exp - prev.exp) / prev.exp * 100 : null;
  const top = Object.entries(cur.byParent).sort((a, b) => b[1] - a[1]).slice(0, 5); const mx = top.length ? top[0][1] : 1;
  const prevNote = v => v > 0 ? `<span class="amt">${fmt(v)}</span> ${R.prevLabel}` : '&nbsp;';
  return `<section>
    <div class="sec-h"><h2>Resumen ${R.label}</h2><button class="link" data-go="stats">Análisis</button></div>${p === 'month' && (S.settings.monthStart || 1) > 1 ? `<div class="note" style="margin-top:-6px">${finLabel(curMk())}</div>` : ''}
    <div class="seg" role="group" aria-label="Periodo">${[['day', 'Hoy'], ['week', 'Semana'], ['month', 'Mes'], ['year', 'Año']].map(([k, l]) => `<button data-action="period" data-k="${k}" aria-pressed="${p === k}">${l}</button>`).join('')}</div>
    <div class="kpis">
      <div class="kpi"><div class="k-l"><span class="dot" style="--c:var(--pos)"></span>Ganado</div><div class="k-v pos amt">${fmt(cur.inc)}</div><div class="k-s">${prevNote(prev.inc)}</div></div>
      <div class="kpi"><div class="k-l"><span class="dot" style="--c:var(--neg)"></span>Gastado</div><div class="k-v amt">${fmt(cur.exp)}</div><div class="k-s">${dExp != null ? `<span class="${dExp > 0 ? 'neg' : 'pos'}">${fmtPct(dExp)}</span> vs ${R.prevLabel}` : prevNote(prev.exp)}</div></div>
      <div class="kpi"><div class="k-l">Balance</div><div class="k-v ${pcls(cur.net)} amt">${fmt(cur.net, null, { sign: true })}</div><div class="k-s">${cur.rate != null ? `Ahorras el ${fmtPct(cur.rate, false)}` : 'Sin ingresos en el periodo'}</div></div>
      <div class="kpi"><div class="k-l">Gasto medio al día</div><div class="k-v amt">${fmt(cur.exp / Math.max(1, R.days))}</div><div class="k-s">${cur.list.length} movimiento${cur.list.length === 1 ? '' : 's'}</div></div>
    </div>
    ${top.length ? `<div class="card stack"><div class="eyebrow">En qué se ha ido</div>${top.map(([cid, v]) => { const c = catById(cid) || { name: 'Sin categoría', icon: '•', color: '#a9b3c2' }; return `<button class="catline" data-action="cat-txs" data-id="${cid}">${ico(esc(c.icon), c.color, 'sm')}<div class="row-m"><div class="hstack"><span class="row-t">${esc(c.name)}</span><span class="spacer"></span><span class="num amt">${fmt(v)}</span></div><div class="bar"><i style="width:${(v / mx * 100).toFixed(1)}%;--c:${c.color}"></i></div></div></button>`; }).join('')}</div>` : ''}
  </section>`;
};
function goalSrcLabel(g) {
  const s = g.source || { t: 'manual' };
  if (s.t === 'nw') return 'Patrimonio total';
  if (s.t === 'group') return 'Bloque: ' + esc(groupById(s.id)?.name || '¿?');
  if (s.t === 'account') return 'Cuenta: ' + esc(accById(s.id)?.name || '¿?');
  if (s.t === 'kind') return s.v === 'crypto' ? 'Toda tu cripto' : 'Todas tus acciones';
  return 'Aportaciones manuales';
}
function goalCard(g, P) {
  const i = goalInfo(g, P);
  const right = i.done ? '' : i.perMonth != null ? (i.months > 0 ? `<span class="amt">${fmt(i.perMonth)}</span>/mes durante ${i.months} ${i.months === 1 ? 'mes' : 'meses'}` : 'Fecha superada') : (g.deadline ? shortDate(g.deadline) : 'Sin fecha límite');
  return `<button class="card goal" data-action="goal-open" data-id="${g.id}" style="text-align:left;color:var(--fg)">
    <div class="goal-top">${ico(esc(g.icon || '🎯'), g.color)}<div class="row-m"><div class="row-t">${esc(g.name)}</div><div class="row-s">${goalSrcLabel(g)}</div></div>
    <div class="row-r"><span class="num amt">${fmt(i.cur)}</span><span class="row-s">de <span class="amt">${fmt(i.target)}</span></span></div></div>
    <div class="bar" style="--c:${g.color}"><i style="width:${i.pct.toFixed(1)}%"></i></div>
    <div class="goal-meta"><span>${i.done ? '<b class="pos">¡Conseguido!</b>' : `${Math.floor(i.pct)} % · faltan <span class="amt">${fmt(i.left)}</span>`}</span><span>${right}</span></div>
  </button>`;
}
HOME.goals = P => {
  const gs = S.goals.filter(g => !g.archived);
  if (!gs.length) return `<section><div class="sec-h"><h2>Objetivos</h2></div>${emptyCard('Ponte un objetivo', 'Un colchón, un viaje, una cifra de patrimonio… Verás cuánto llevas y cuánto necesitas apartar cada mes.', '<button class="btn primary" data-action="goal-new">Crear objetivo</button>')}</section>`;
  return `<section><div class="sec-h"><h2>Objetivos</h2><button class="link" data-go="more/goals">Todos</button></div><div class="stack">${gs.slice(0, 4).map(g => goalCard(g, P)).join('')}</div></section>`;
};
function groupCard(g, P) {
  const v = groupValue(g, P); const share = P.nw > 0 ? clamp(v.value / P.nw * 100, 0, 100) : 0;
  return `<button class="gcard" data-action="group-open" data-id="${g.id}"><span class="g-n"><span class="dot" style="--c:${g.color}"></span>${esc(g.name)}</span><span class="g-v amt">${fmt(v.value)}</span><div class="bar"><i style="width:${share.toFixed(1)}%;--c:${g.color}"></i></div><span class="row-s">${Math.round(share)} % del total${v.inv && Math.abs(v.pnl) > 0.005 ? ` · <span class="${pcls(v.pnl)} amt">${fmt(v.pnl, null, { sign: true, compact: true })}</span>` : ''}</span></button>`;
}
HOME.groups = P => `<section><div class="sec-h"><h2>Tus bloques</h2><button class="link" data-go="more/groups">Personalizar</button></div>
  <div class="groups">${S.groups.map(g => groupCard(g, P)).join('')}<button class="gcard add" data-action="group-new">+ Nuevo bloque</button></div></section>`;
function allocHtml(rows, total) {
  const top = rows.slice().sort((a, b) => b.v - a.v).filter(r => r.v > 0); if (!top.length || !(total > 0)) return '';
  return `<div class="alloc">${top.map(r => `<i style="width:${(r.v / total * 100).toFixed(2)}%;--c:${r.c}" title="${esc(r.l)}"></i>`).join('')}</div>
  <div class="legend">${top.map(r => `<span><span class="dot" style="--c:${r.c}"></span>${esc(r.l)} ${Math.round(r.v / total * 100)} %</span>`).join('')}</div>`;
}
HOME.invest = P => {
  if (!P.assets.length) return `<section><div class="sec-h"><h2>Inversiones</h2></div>${emptyCard('Aún no tienes inversiones', 'Añade tu cripto o tus acciones y verás su valor en tiempo real y lo que ganas o pierdes.', '<div class="hstack" style="justify-content:center"><button class="btn sm" data-action="asset-new" data-kind="crypto">Añadir cripto</button><button class="btn sm" data-action="asset-new" data-kind="stock">Añadir acción o ETF</button></div>')}</section>`;
  const pnlPct = P.cost > 0 ? P.pnl / P.cost * 100 : null;
  const ranked = P.assets.filter(r => r.pnlPct != null && r.priced && r.h.qty > 0).sort((a, b) => b.pnlPct - a.pnlPct);
  const best = ranked[0], worst = ranked.length > 1 ? ranked[ranked.length - 1] : null;
  const cr = sum(P.assets.filter(r => r.x.kind === 'crypto'), r => r.value), st = sum(P.assets.filter(r => r.x.kind === 'stock'), r => r.value);
  const mini = (r, lbl) => `<button class="row" data-action="asset-open" data-id="${r.x.id}">${ico(assetTag(r.x), assetColor(r.x), 'txt')}<div class="row-m"><div class="row-t">${esc(r.x.name || r.x.symbol)}</div><div class="row-s">${lbl}</div></div><div class="row-r"><span class="chip ${pcls(r.pnl)}">${fmtPct(r.pnlPct)}</span><span class="row-s amt ${pcls(r.pnl)}">${fmt(r.pnl, null, { sign: true })}</span></div></button>`;
  return `<section><div class="sec-h"><h2>Rendimiento de inversiones</h2><button class="link" data-go="inv">Cartera</button></div>
    <div class="kpis">
      <div class="kpi"><div class="k-l">Valor actual</div><div class="k-v amt">${fmt(P.assetsTotal)}</div><div class="k-s">Has puesto <span class="amt">${fmt(P.cost)}</span></div></div>
      <div class="kpi"><div class="k-l">Rentabilidad</div><div class="k-v ${pcls(P.pnl)} amt">${fmt(P.pnl, null, { sign: true })}</div><div class="k-s ${pcls(P.pnl)}">${fmtPct(pnlPct)}</div></div>
      <div class="kpi"><div class="k-l">Hoy</div><div class="k-v ${pcls(P.dayChg)} amt">${fmt(P.dayChg, null, { sign: true })}</div><div class="k-s">${P.assetsTotal - P.dayChg > 0 ? fmtPct(P.dayChg / (P.assetsTotal - P.dayChg) * 100) : '&nbsp;'}</div></div>
      <div class="kpi"><div class="k-l">Ganancia realizada</div><div class="k-v ${pcls(P.realized)} amt">${fmt(P.realized, null, { sign: true })}</div><div class="k-s">de lo que ya vendiste</div></div>
    </div>
    ${allocHtml([{ l: 'Cripto', v: cr, c: PALETTE[5] }, { l: 'Acciones y ETF', v: st, c: PALETTE[6] }], cr + st)}
    ${best ? `<div class="list">${mini(best, 'La que mejor va')}${worst ? mini(worst, 'La que peor va') : ''}</div>` : ''}
  </section>`;
};
function accRow(a, P) {
  const r = P.accounts.find(x => x.a.id === a.id) || { bal: 0, base: 0 }; const b = P.byAcc(a.id);
  const subs = [ACC_TYPES[a.type] || '', b.inv ? `<span class="amt">${fmt(b.inv, null, { compact: true })}</span> en inversiones` : '', a.includeInTotal === false ? 'fuera del total' : ''].filter(Boolean).join(' · ');
  return `<button class="row" data-action="acc-open" data-id="${a.id}">${ico(esc(a.icon || ACC_ICONS[a.type] || '🏦'), a.color)}<div class="row-m"><div class="row-t">${esc(a.name)}</div><div class="row-s">${subs}</div></div>
    <div class="row-r"><span class="num amt ${r.bal < -0.004 ? 'neg' : ''}">${fmt(r.bal, a.currency)}</span>${a.currency !== S.settings.base ? `<span class="row-s amt">≈ ${fmt(r.base)}</span>` : ''}${b.inv ? `<span class="row-s">total <span class="amt">${fmt(b.cash + b.inv, null, { compact: true })}</span></span>` : ''}</div></button>`;
}
HOME.accounts = P => {
  const list = activeAccounts(); if (!list.length) return '';
  return `<section><div class="sec-h"><h2>Cuentas</h2><button class="link" data-go="more/accounts">Gestionar</button></div><div class="list">${list.map(a => accRow(a, P)).join('')}</div></section>`;
};
function budgetRows(mk) {
  const R = FR(mk); const isCur = mk === curMk();
  const span = (parseYmd(R.to) - parseYmd(R.from)) / 864e5 + 1;
  const dayPct = isCur ? ((parseYmd(today()) - parseYmd(R.from)) / 864e5 + 1) / span * 100 : 100;
  const row = (id, icon, color, name, spent, avail, action) => {
    const pct = avail > 0 ? spent / avail * 100 : 100;
    const st = pct >= 100 ? 'neg' : pct > dayPct + 8 ? 'warn' : 'pos';
    const left = avail - spent;
    return `<button class="row" ${action} style="align-items:flex-start">${icon ? ico(esc(icon), color, 'sm') : ico(svg('gauge'), 'var(--accent)', 'sm')}<div class="row-m stack" style="gap:6px"><div class="hstack"><span class="row-t">${esc(name)}</span><span class="spacer"></span><span class="num small"><span class="amt">${fmt(spent)}</span> <span class="muted">/ <span class="amt">${fmt(avail, null, { dec: 0 })}</span></span></span></div>
      <div class="bar budget" style="--c:var(--${st})"><i style="width:${clamp(pct, 0, 100).toFixed(1)}%"></i>${isCur ? `<b style="left:${dayPct.toFixed(1)}%" title="Hoy"></b>` : ''}</div>
      <div class="row-s ${st === 'pos' ? '' : st}">${left >= 0 ? `Te quedan <span class="amt">${fmt(left)}</span>${isCur && dayPct < 100 ? ` · <span class="amt">${fmt(left / Math.max(1, Math.ceil(span * (1 - dayPct / 100))))}</span>/día` : ''}` : `Te has pasado <span class="amt">${fmt(-left)}</span>`}</div></div></button>`;
  };
  let html = '';
  const tot = Number(S.settings.budgetTotal) || 0;
  if (tot > 0) html += row('', '', '', 'Todo el gasto', flows(R.from, R.to).exp, tot, 'data-go="stats"');
  const bs = S.categories.filter(c => c.kind === 'expense' && c.budget > 0 && !c.hidden).map(c => { const avail = budgetAvail(c, mk); const spent = catSpend(c.id, R.from, R.to); return { c, spent, avail, pct: avail > 0 ? spent / avail : 9 }; }).sort((a, b) => b.pct - a.pct);
  html += bs.map(({ c, spent, avail }) => row(c.id, c.icon, c.color, c.name + (c.rollover && avail !== c.budget ? ` (${avail > c.budget ? '+' : '−'}${fmt(Math.abs(avail - c.budget), null, { dec: 0 })} arrastrado)` : ''), spent, avail, `data-action="cat-txs" data-id="${c.id}" data-month="${mk}"`)).join('');
  return html;
}
HOME.budgets = P => {
  const rows = budgetRows(curMk());
  if (!rows) return `<section><div class="sec-h"><h2>Presupuestos</h2></div>${emptyCard('Pon límites a tus gastos', 'Decide cuánto quieres gastar al mes en total o por categoría y mira cómo vas.', '<button class="btn sm" data-go="more/budgets">Crear presupuestos</button>')}</section>`;
  return `<section><div class="sec-h"><h2>Presupuestos</h2><button class="link" data-go="more/budgets">Editar</button></div><div class="list">${rows}</div><div class="note">La marca vertical indica en qué punto del periodo estás.</div></section>`;
};
function recRow(r) {
  const t = r.tpl;
  if (t.type === 'invest') {
    const a = assetById(t.assetId), acc = accById(t.accountId);
    return `<button class="row" data-action="asset-open" data-id="${t.assetId}">${ico(svg('repeat'), a && a.color)}<div class="row-m"><div class="row-t">${esc(r.name || 'Plan de inversión')}</div><div class="row-s">${r.active ? dayLabel(r.next) : 'En pausa'} · ${FREQ_L[r.freq]} · compra de ${esc(a ? a.name : '?')}</div></div><div class="row-r"><span class="num amt">${fmt(t.amount, acc?.currency)}</span></div></button>`;
  } const acc = accById(t.accountId); const c = t.type === 'transfer' ? null : catById(t.categoryId);
  const icon = t.type === 'transfer' ? svg('swap') : esc(c ? c.icon : '•');
  const v = t.type === 'income' ? fmt(t.amount, acc?.currency, { sign: true }) : t.type === 'expense' ? fmt(-t.amount, acc?.currency, { sign: true }) : fmt(t.amount, acc?.currency);
  return `<button class="row" data-action="rec-edit" data-id="${r.id}">${ico(icon, c ? c.color : 'var(--muted)')}<div class="row-m"><div class="row-t">${esc(r.name || t.note || (c ? c.name : 'Recurrente'))}</div><div class="row-s">${r.active ? dayLabel(r.next) : 'En pausa'} · ${FREQ_L[r.freq]}${(r.interval || 1) > 1 ? ` (x${r.interval})` : ''}</div></div><div class="row-r"><span class="num amt ${t.type === 'income' ? 'pos' : ''}">${v}</span></div></button>`;
}
HOME.upcoming = P => {
  const lim = addDays(today(), 14);
  const ups = S.recurring.filter(r => r.active && r.next && r.next <= lim).sort((a, b) => a.next < b.next ? -1 : 1);
  if (!ups.length) return '';
  const out = sum(ups.filter(r => r.tpl.type === 'expense'), r => conv(r.tpl.amount, accById(r.tpl.accountId)?.currency));
  return `<section><div class="sec-h"><h2>Próximos cargos</h2><span class="small muted">14 días · <span class="amt">${fmt(out)}</span></span></div><div class="list">${ups.slice(0, 6).map(recRow).join('')}</div></section>`;
};
const fmtRate = x => nf('rate', { maximumSignificantDigits: 6 }).format(x);
HOME.fx = P => {
  const base = S.settings.base; const favs = S.settings.favCcy.filter(c => c !== base && canConv(c));
  if (!favs.length) return '';
  return `<section><div class="sec-h"><h2>En otras monedas</h2><button class="link" data-go="more/fx">Divisas</button></div>
  <div class="kpis">${favs.map((c, i) => `<div class="kpi ${favs.length % 2 && i === favs.length - 1 ? 'wide' : ''}"><div class="k-l">${esc(CCY_NAMES[c] || c)}</div><div class="k-v amt">${fmt(conv(P.nw, base, c), c)}</div><div class="k-s">1 ${base} = ${fmtRate(conv(1, base, c))} ${c}</div></div>`).join('')}</div></section>`;
};
HOME.recent = P => {
  const list = sortTx(S.txs).slice(0, S.settings.recentCount || 6);
  if (!list.length) return `<section><div class="sec-h"><h2>Últimos movimientos</h2></div>${emptyCard('Sin movimientos todavía', 'Apunta tu primer gasto o ingreso con el botón +.')}</section>`;
  return `<section><div class="sec-h"><h2>Últimos movimientos</h2><button class="link" data-go="txs">Ver todos</button></div><div class="list">${list.map(t => txRow(t)).join('')}</div></section>`;
};

HOME.today = P => {
  const t = today(); const f = flows(t, t); const R = periodRange('month');
  const m = flows(R.from, t); const avg = m.exp / Math.max(1, R.days);
  const tot = Number(S.settings.budgetTotal) || 0;
  const span = (parseYmd(R.to) - parseYmd(R.from)) / 864e5 + 1;
  const safe = tot > 0 ? (tot - m.exp + f.exp) / Math.max(1, span - R.days + 1) : null;
  return `<section><div class="sec-h"><h2>Hoy</h2><span class="small muted">${dayLabel(t) === 'Hoy' ? cap(WEEKDAYS[new Date().getDay()]) + ', ' + shortDate(t) : ''}</span></div>
  <div class="kpis"><div class="kpi"><div class="k-l">Gastado hoy</div><div class="k-v amt">${fmt(f.exp)}</div><div class="k-s">${f.exp > avg && avg > 0 ? `<span class="warn">Por encima</span> de tu media (<span class="amt">${fmt(avg)}</span>)` : `Tu media diaria: <span class="amt">${fmt(avg)}</span>`}</div></div>
  <div class="kpi"><div class="k-l">${safe != null ? 'Puedes gastar hoy' : 'Ganado hoy'}</div><div class="k-v amt ${safe != null ? (safe - f.exp < 0 ? 'neg' : 'pos') : 'pos'}">${safe != null ? fmt(Math.max(0, safe - f.exp)) : fmt(f.inc)}</div><div class="k-s">${safe != null ? 'para cumplir tu presupuesto' : f.list.length + ' movimiento' + (f.list.length === 1 ? '' : 's')}</div></div></div></section>`;
};
HOME.quick = P => {
  const ts = S.templates || [];
  return `<section><div class="sec-h"><h2>Accesos rápidos</h2><button class="link" data-go="more/templates">Editar</button></div>
  <div class="chips-row">${ts.map(t => { const c = catById(t.tpl.categoryId); const a = accById(t.tpl.accountId); return `<button class="qchip" data-action="tpl-use" data-id="${t.id}"><span class="e">${esc(t.icon || (c ? c.icon : '•'))}</span><span class="t">${esc(t.name)}</span><span class="num small amt">${t.tpl.amount ? fmt(t.tpl.amount, a ? a.currency : null) : 'Importe…'}</span></button>`; }).join('')}<button class="qchip add" data-action="tpl-new">+ Plantilla</button></div>
  <div class="note">Un toque y queda apuntado. Si la plantilla no tiene importe, te lo pide.</div></section>`;
};
HOME.networth = P => {
  const cash = sum(P.accounts.filter(r => r.inTotal && !['deuda', 'activo'].includes(r.a.type) && r.base >= 0), r => r.base);
  const neg = sum(P.accounts.filter(r => r.inTotal && r.a.type !== 'deuda' && r.a.type !== 'activo' && r.base < 0), r => r.base);
  const cr = sum(P.assets.filter(r => r.inTotal && r.x.kind === 'crypto'), r => r.value), st = sum(P.assets.filter(r => r.inTotal && r.x.kind === 'stock'), r => r.value);
  const prop = P.property, debt = sum(P.accounts.filter(r => r.inTotal && r.a.type === 'deuda'), r => r.base) + neg;
  const assets = cash + cr + st + prop;
  const rows = [['Dinero en cuentas', cash, PALETTE[1]], ['Cripto', cr, PALETTE[5]], ['Acciones y ETF', st, PALETTE[6]], ['Bienes', prop, PALETTE[3]]].filter(r => r[1] > 0.004);
  return `<section><div class="sec-h"><h2>Desglose del patrimonio</h2></div><div class="card stack">
    ${allocHtml(rows.map(([l, v, c]) => ({ l, v, c })), assets)}
    <dl class="kv">${rows.map(([l, v, c]) => `<dt><span class="dot" style="--c:${c}"></span> ${l}</dt><dd class="num amt">${fmt(v)}</dd>`).join('')}
    <dt><b>Lo que tienes</b></dt><dd class="num amt"><b>${fmt(assets)}</b></dd>
    ${debt < -0.004 ? `<dt>Lo que debes</dt><dd class="num amt neg">${fmt(debt)}</dd>` : ''}
    <dt><b>Patrimonio neto</b></dt><dd class="num amt"><b>${fmt(P.nw)}</b></dd></dl>
    ${debt < -0.004 && assets > 0 ? `<div class="note">Endeudamiento: ${fmtPct(-debt / assets * 100, false)} de lo que tienes.</div>` : ''}</div></section>`;
};
function watchRow(w) {
  const a = w.x, pr = w.pr; const fl = PX.flash[a.id]; const fc = fl && !fl.shown && Date.now() - fl.t < 2000 ? 'flash-' + fl.d : '';
  return `<button class="row ${fc}" data-action="asset-open" data-id="${a.id}">${ico(assetTag(a), assetColor(a), 'txt')}<div class="row-m"><div class="row-t">${esc(a.name || a.symbol)}</div><div class="row-s">${esc(a.symbol)}${pr && pr.src === 'manual' ? ' · manual' : ''}</div></div><div class="row-r"><span class="num">${pr ? fmtPrice(pr.p, pr.ccy) : '—'}</span>${pr && pr.ch != null && pr.src !== 'manual' ? `<span class="chip ${pcls(pr.ch)}">${fmtPct(pr.ch)}</span>` : ''}</div></button>`;
}
HOME.watch = P => {
  if (!P.watch.length) return '';
  return `<section><div class="sec-h"><h2>Seguimiento</h2><button class="link" data-go="inv">Mercados</button></div><div class="list">${P.watch.map(watchRow).join('')}</div></section>`;
};

/* =============================== MOVIMIENTOS =============================== */
function catIdsOf(id) { return new Set([id, ...S.categories.filter(c => c.parentId === id).map(c => c.id)]); }
function txFiltered(noMonth) {
  const f = UI.txF; const q = f.q.trim().toLowerCase();
  const R = f.month !== 'all' ? FR(f.month) : null; const cats = f.cat !== 'all' ? catIdsOf(f.cat) : null;
  let qAmt = null; if (/^[<>]?\s*\d/.test(q)) qAmt = q;
  return S.txs.filter(t => {
    if (R && !noMonth && (t.date < R.from || t.date > R.to)) return false;
    if (f.type === 'excl') { if (!t.excl) return false; } else if (f.type !== 'all' && t.type !== f.type) return false;
    if (f.acc !== 'all' && t.accountId !== f.acc && t.toAccountId !== f.acc) return false;
    if (cats && !txParts(t).some(p => cats.has(p.categoryId))) return false;
    if (q) {
      if (qAmt && /^[<>]/.test(qAmt)) { const n = parseMoney(qAmt.slice(1)); if (!isFinite(n)) return true; return qAmt[0] === '>' ? t.amount > n : t.amount < n; }
      const c = catById(t.categoryId);
      const hay = [t.note, c && c.name, (t.tags || []).map(x => '#' + x).join(' '), String(t.amount).replace('.', ','), String(t.amount), accById(t.accountId)?.name, accById(t.toAccountId)?.name].join(' ').toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  });
}
function txSummary(list) {
  let inc = 0, exp = 0;
  for (const t of list) { if (t.excl) continue; const a = accById(t.accountId); if (!a) continue; if (t.type === 'income') inc += conv(t.amount, a.currency); if (t.type === 'expense') exp += conv(t.amount, a.currency); }
  return `<div class="row3" style="margin-bottom:6px">
    <div class="kpi"><div class="k-l">Ingresos</div><div class="k-v pos amt" style="font-size:16px">${fmt(inc)}</div></div>
    <div class="kpi"><div class="k-l">Gastos</div><div class="k-v amt" style="font-size:16px">${fmt(exp)}</div></div>
    <div class="kpi"><div class="k-l">Neto</div><div class="k-v ${pcls(inc - exp)} amt" style="font-size:16px">${fmt(inc - exp, null, { sign: true })}</div></div></div>`;
}
function txListHtml() {
  const list = sortTx(txFiltered()); const ctx = UI.txF.acc !== 'all' ? UI.txF.acc : null;
  if (!list.length) return emptyCard('No hay movimientos', UI.txF.q || UI.txF.type !== 'all' || UI.txF.acc !== 'all' || UI.txF.cat !== 'all' ? 'Prueba a quitar algún filtro.' : 'Este periodo aún no tiene movimientos. Añade uno con el botón +.');
  const days = new Map();
  for (const t of list.slice(0, UI.txLimit)) { if (!days.has(t.date)) days.set(t.date, []); days.get(t.date).push(t); }
  let html = txSummary(list);
  for (const [d, ts] of days) {
    const dn = sum(ts, t => { const a = accById(t.accountId); if (!a || t.excl) return 0; return t.type === 'income' ? conv(t.amount, a.currency) : t.type === 'expense' ? -conv(t.amount, a.currency) : 0; });
    html += `<div class="day-h"><span>${dayLabel(d)}</span><span class="num amt ${pcls(dn)}">${dn ? fmt(dn, null, { sign: true }) : ''}</span></div><div class="list">${ts.map(t => txRow(t, ctx)).join('')}</div>`;
  }
  if (list.length > UI.txLimit) html += `<button class="btn block" data-action="tx-more" style="margin-top:12px">Mostrar más (${list.length - UI.txLimit})</button>`;
  html += `<div class="note" style="margin-top:10px">${list.length} movimiento${list.length === 1 ? '' : 's'}. Busca por texto, #etiqueta o importe (&gt;50, &lt;10).</div>`;
  return html;
}
// Calendario del periodo con el gasto de cada día
function calHtml() {
  const f = UI.txF; const mk = f.month === 'all' ? curMk() : f.month; const R = FR(mk);
  const ctxList = txFiltered(true).filter(t => t.date >= R.from && t.date <= R.to);
  const per = {}; let mx = 0;
  for (const t of ctxList) { if (t.type !== 'expense' || t.excl) continue; const a = accById(t.accountId); if (!a) continue; per[t.date] = (per[t.date] || 0) + conv(t.amount, a.currency); }
  const inc = {}; for (const t of ctxList) { if (t.type !== 'income' || t.excl) continue; const a = accById(t.accountId); if (a) inc[t.date] = (inc[t.date] || 0) + conv(t.amount, a.currency); }
  for (const v of Object.values(per)) mx = Math.max(mx, v);
  const ws = S.settings.weekStart ?? 1; const first = parseYmd(R.from); const lead = (first.getDay() - ws + 7) % 7;
  const names = ['D', 'L', 'M', 'X', 'J', 'V', 'S']; const hdr = Array.from({ length: 7 }, (_, i) => names[(i + ws) % 7]);
  let cells = ''; for (let i = 0; i < lead; i++) cells += '<span></span>';
  const tdy = today();
  for (let d = R.from; d <= R.to; d = addDays(d, 1)) {
    const v = per[d] || 0; const k = mx > 0 ? v / mx : 0;
    cells += `<button class="cday ${d === tdy ? 'is-today' : ''} ${d === UI.calDay ? 'is-sel' : ''} ${d > tdy ? 'future' : ''}" data-action="calday" data-d="${d}" style="--k:${(k * 55).toFixed(0)}%"><b>${Number(d.slice(8))}</b>${v ? `<span class="amt">${axisFmt(v)}</span>` : ''}${inc[d] ? '<i class="inc-dot"></i>' : ''}</button>`;
  }
  const sel = UI.calDay && UI.calDay >= R.from && UI.calDay <= R.to ? UI.calDay : null;
  const dayList = sel ? sortTx(ctxList.filter(t => t.date === sel)) : [];
  return `${txSummary(ctxList)}<div class="card"><div class="cal">${hdr.map(h => `<span class="cal-h">${h}</span>`).join('')}${cells}</div>
    <div class="legend" style="margin-top:10px"><span><span class="dot" style="--c:var(--neg)"></span>más intenso = más gasto</span><span><span class="dot" style="--c:var(--pos)"></span>día con ingresos</span></div></div>
    ${sel ? `<div class="day-h"><span>${dayLabel(sel)}</span><span class="num amt">${per[sel] ? fmt(-per[sel], null, { sign: true }) : ''}</span></div>${dayList.length ? `<div class="list">${dayList.map(t => txRow(t)).join('')}</div>` : '<p class="note">Sin movimientos este día.</p>'}` : '<p class="note">Toca un día para ver sus movimientos.</p>'}`;
}
const txBody = () => UI.txView === 'cal' ? calHtml() : txListHtml();
VIEWS.txs = P => {
  const f = UI.txF;
  if (UI.txView === 'cal' && f.month === 'all') f.month = curMk();
  const accOpts = `<option value="all">Todas las cuentas</option>` + S.accounts.map(a => `<option value="${a.id}" ${f.acc === a.id ? 'selected' : ''}>${esc(a.name)}</option>`).join('');
  const catOpts = `<option value="all">Todas las categorías</option>` + ['expense', 'income'].map(k => `<optgroup label="${k === 'expense' ? 'Gastos' : 'Ingresos'}">${catTree(k).map(c => `<option value="${c.id}" ${f.cat === c.id ? 'selected' : ''}>${c.parentId ? '   ' : ''}${esc(c.icon)} ${esc(c.name)}</option>`).join('')}</optgroup>`).join('');
  const typeOpts = [['all', 'Todo'], ['expense', 'Gastos'], ['income', 'Ingresos'], ['transfer', 'Transferencias'], ['adjust', 'Ajustes'], ['excl', 'Fuera de estadísticas']].map(([k, l]) => `<option value="${k}" ${f.type === k ? 'selected' : ''}>${l}</option>`).join('');
  return `<section>
    <div class="seg" role="group" aria-label="Vista"><button data-action="txview" data-k="list" aria-pressed="${UI.txView !== 'cal'}">Lista</button><button data-action="txview" data-k="cal" aria-pressed="${UI.txView === 'cal'}">Calendario</button></div>
    <div class="month-nav">
      <button class="icon-btn" data-action="txm" data-d="-1" aria-label="Periodo anterior" ${f.month === 'all' ? 'disabled' : ''}>${svg('chevL')}</button>
      <b>${f.month === 'all' ? 'Todo el historial' : finLabel(f.month)}</b>
      <button class="icon-btn" data-action="txm" data-d="1" aria-label="Periodo siguiente" ${f.month === 'all' ? 'disabled' : ''}>${svg('chev')}</button>
    </div>
    <div class="toolbar"><input class="inp" type="search" id="txQ" placeholder="Buscar concepto, #etiqueta, importe…" value="${esc(f.q)}" autocomplete="off">${UI.txView !== 'cal' ? `<button class="btn sm" data-action="txm-all">${f.month === 'all' ? 'Por meses' : 'Todo'}</button>` : ''}</div>
    <div class="filters"><div class="sel"><select id="txFType" aria-label="Tipo">${typeOpts}</select></div><div class="sel"><select id="txFAcc" aria-label="Cuenta">${accOpts}</select></div><div class="sel"><select id="txFCat" aria-label="Categoría">${catOpts}</select></div></div>
  </section><div id="txList">${txBody()}</div>`;
};
AFTER.txs = () => {
  let t; $('#txQ').addEventListener('input', e => { clearTimeout(t); t = setTimeout(() => { UI.txF.q = e.target.value; $('#txList').innerHTML = txBody(); }, 160); });
  const bind = (id, k) => $(id).addEventListener('change', e => { UI.txF[k] = e.target.value; UI.txLimit = 300; $('#txList').innerHTML = txBody(); });
  bind('#txFType', 'type'); bind('#txFAcc', 'acc'); bind('#txFCat', 'cat');
};
// Categorías en orden: cada padre seguido de sus hijas
function catTree(kind, withHidden) {
  const list = S.categories.filter(c => c.kind === kind && (withHidden || !c.hidden));
  const out = []; for (const c of list.filter(c => !c.parentId || !catById(c.parentId))) { out.push(c); out.push(...list.filter(x => x.parentId === c.id)); }
  return out;
}

/* =============================== INVERSIONES =============================== */
function assetRow(r) {
  const a = r.x; const fl = PX.flash[a.id]; const fc = fl && !fl.shown && Date.now() - fl.t < 2000 ? 'flash-' + fl.d : '';
  const pr = r.pr;
  const px = pr ? `${fmtPrice(pr.p, pr.ccy)}${pr.src === 'manual' ? ' · manual' : ''}` : 'sin precio';
  return `<button class="row ${fc}" data-action="asset-open" data-id="${a.id}">${ico(assetTag(a), assetColor(a), 'txt')}
    <div class="row-m"><div class="row-t">${esc(a.name || a.symbol)}</div><div class="row-s"><span class="amt">${fmtQty(r.h.qty)}</span> ${esc(a.symbol)} · ${px}</div></div>
    <div class="row-r"><span class="num amt">${fmt(r.value)}</span><span class="chip ${pcls(r.pnl)}">${r.pnlPct != null ? fmtPct(r.pnlPct) : 'sin coste'}</span>${pr && pr.ch != null && pr.src !== 'manual' ? `<span class="row-s ${pcls(pr.ch)}">${fmtPct(pr.ch)} ${a.kind === 'crypto' ? '24 h' : 'hoy'}</span>` : ''}</div></button>`;
}
function sourcesNote() {
  const hasStock = S.assets.some(a => a.kind === 'stock' && !a.archived);
  const noStockSrc = hasStock && !yahooOK() && !S.settings.finnhubKey;
  return noStockSrc ? `<div class="card stack"><b>Las acciones van con precio manual</b><span class="note">Para que se actualicen solas, configura una fuente de precios (tarda 5 minutos y es gratis).</span><button class="btn sm" data-go="more/prices">Configurar precios de acciones</button></div>` : '';
}
VIEWS.inv = P => {
  const f = UI.invF; const rows = P.assets.filter(r => f === 'all' || r.x.kind === f).sort((a, b) => b.value - a.value);
  const tot = sum(rows, r => r.value), cost = sum(rows, r => r.h.cost), pnl = tot - cost, day = sum(rows, r => r.dayChg);
  const seg = `<div class="seg" role="group" aria-label="Filtrar">${[['all', 'Todo'], ['crypto', 'Cripto'], ['stock', 'Acciones']].map(([k, l]) => `<button data-action="invf" data-k="${k}" aria-pressed="${f === k}">${l}</button>`).join('')}</div>`;
  if (!P.assets.length && !P.watch.length) return `${seg}${emptyCard('Tu cartera está vacía', 'Añade una criptomoneda o una acción con lo que compraste. El valor se actualiza en tiempo real.', '<div class="hstack" style="justify-content:center"><button class="btn primary" data-action="asset-new" data-kind="crypto">Añadir cripto</button><button class="btn" data-action="asset-new" data-kind="stock">Añadir acción o ETF</button></div>')}`;
  const palette = rows.filter(r => r.value > 0).map(r => ({ l: r.x.symbol, v: r.value, c: assetColor(r.x) }));
  return `<section class="hero"><div class="eyebrow">${f === 'crypto' ? 'Cripto' : f === 'stock' ? 'Acciones y ETF' : 'Toda la cartera'}</div>
      <div class="hero-num amt">${fmt(tot)}</div>
      <div class="hero-sub"><span class="chip ${pcls(pnl)}"><span class="amt">${fmt(pnl, null, { sign: true })}</span>&nbsp;·&nbsp;${fmtPct(cost > 0 ? pnl / cost * 100 : null)}</span><span class="chip ${pcls(day)}"><span class="amt">${fmt(day, null, { sign: true })}</span>&nbsp;hoy</span><span class="chip">Invertido&nbsp;<span class="amt">${fmt(cost, null, { compact: true })}</span></span></div>
    </section>
    ${seg}
    ${palette.length > 1 ? `<section>${allocHtml(palette, tot)}</section>` : ''}
    <section><div class="list">${rows.map(assetRow).join('') || '<div class="empty">Nada en esta categoría.</div>'}</div>
    <div class="row2"><button class="btn" data-action="asset-new" data-kind="crypto">${svg('plus')}Cripto</button><button class="btn" data-action="asset-new" data-kind="stock">${svg('plus')}Acción o ETF</button></div></section>
    ${P.watch.length ? `<section><div class="sec-h"><h2>Seguimiento</h2><span class="small muted">sin tenerlas</span></div><div class="list">${P.watch.filter(w => f === 'all' || w.x.kind === f).map(watchRow).join('')}</div></section>` : ''}
    <div class="row2"><button class="btn sm ghost" data-action="watch-new" data-kind="crypto">+ Seguir una cripto</button><button class="btn sm ghost" data-action="watch-new" data-kind="stock">+ Seguir una acción</button></div>
    ${sourcesNote()}
    <p class="note">Cripto: Binance en directo y CoinGecko. Acciones: ${NATIVE ? 'Yahoo Finance (directo desde la app)' : S.settings.yahooProxy ? 'Yahoo Finance a través de tu proxy' : S.settings.finnhubKey ? 'Finnhub (EE. UU.)' : 'precio manual'}. La rentabilidad usa el precio medio de compra; lo comprado en otra moneda se convierte al cambio actual.</p>`;
};

/* =============================== ANÁLISIS =============================== */
function statsRange() {
  if (UI.statsMode === 'year') { const y = UI.statsYear; const R = { from: `${y}-01-01`, to: `${y}-12-31` }; return { R, P: { from: `${y - 1}-01-01`, to: `${y - 1}-12-31` }, label: String(y), prevWord: 'año anterior', days: y === new Date().getFullYear() ? Math.round((new Date() - new Date(y, 0, 1)) / 864e5) + 1 : (y % 4 ? 365 : 366) }; }
  const mk = UI.statsMonth; const R = FR(mk); const isCur = mk === curMk();
  return { R, P: FR(addMonths(mk, -1)), label: finLabel(mk), prevWord: 'periodo anterior', days: isCur ? Math.round((parseYmd(today()) - parseYmd(R.from)) / 864e5) + 1 : Math.round((parseYmd(R.to) - parseYmd(R.from)) / 864e5) + 1 };
}
function hbars(rows, fmtv) {
  const mx = Math.max(1, ...rows.map(r => r.v));
  return `<div class="stack" style="gap:8px">${rows.map(r => `<div class="catline" style="cursor:default"><span class="small" style="width:74px;flex:none;color:var(--muted)">${esc(r.l)}</span><div class="row-m"><div class="bar" style="height:8px"><i style="width:${(r.v / mx * 100).toFixed(1)}%;--c:${r.c || 'var(--accent)'}"></i></div></div><span class="num small amt" style="width:78px;text-align:right">${fmtv(r.v)}</span></div>`).join('')}</div>`;
}
VIEWS.stats = P => {
  const { R, P: PR, label, prevWord, days } = statsRange();
  const cur = flows(R.from, R.to); const prev = flows(PR.from, PR.to);
  const cats = Object.entries(cur.byParent).sort((a, b) => b[1] - a[1]);
  const segs = cats.slice(0, 8).map(([cid, v]) => { const c = catById(cid) || { name: 'Sin categoría', color: '#a9b3c2', icon: '•' }; return { v, color: c.color, c, cid }; });
  const rest = sum(cats.slice(8), x => x[1]); if (rest > 0) segs.push({ v: rest, color: '#a9b3c2', c: { name: 'Resto', icon: '…', color: '#a9b3c2' }, cid: '' });
  const pvByParent = prev.byParent;
  const months = [];
  if (UI.statsMode === 'year') { for (let m = 1; m <= 12; m++) { const mk = `${UI.statsYear}-${pad(m)}`; const fl = flows(mk + '-01', monthEnd(mk)); months.push({ label: MONTHS_S[m - 1].slice(0, 3), inc: fl.inc, exp: fl.exp }); } }
  else for (let i = 11; i >= 0; i--) { const m = addMonths(UI.statsMonth, -i); const Rm = FR(m); const fl = flows(Rm.from, Rm.to); months.push({ label: finShort(m), inc: fl.inc, exp: fl.exp, mk: m }); }
  const withData = months.filter(m => m.inc || m.exp);
  const avgExp = withData.length ? sum(withData, m => m.exp) / withData.length : 0;
  const avgInc = withData.length ? sum(withData, m => m.inc) / withData.length : 0;
  const cash = cashHistory(12, UI.statsMode === 'year' ? mkOf(`${UI.statsYear}-12-15`) : UI.statsMonth);
  const snaps = S.snapshots.slice(-365).map(s => ({ label: shortDate(s.d), v: conv(s.v, s.c || S.settings.base) }));
  const big = cur.list.filter(t => t.type === 'expense').map(t => [t, conv(t.amount, accById(t.accountId)?.currency)]).sort((a, b) => b[1] - a[1]).slice(0, 5);
  const tagTotals = {}; for (const t of cur.list) if (t.type === 'expense') for (const g of t.tags || []) tagTotals[g] = (tagTotals[g] || 0) + conv(t.amount, accById(t.accountId)?.currency);
  const tags = Object.entries(tagTotals).sort((a, b) => b[1] - a[1]).slice(0, 8);
  const ws = S.settings.weekStart ?? 1; const wd = Array(7).fill(0); for (const t of cur.list) if (t.type === 'expense') wd[(parseYmd(t.date).getDay() - ws + 7) % 7] += conv(t.amount, accById(t.accountId)?.currency);
  const wdNames = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  const merch = {}; for (const t of cur.list) if (t.type === 'expense' && t.note) { const k = t.note.trim().toLowerCase(); const e = merch[k] || (merch[k] = { l: t.note.trim(), v: 0, n: 0 }); e.v += conv(t.amount, accById(t.accountId)?.currency); e.n++; }
  const topMerch = Object.values(merch).sort((a, b) => b.v - a.v).slice(0, 6);
  const incs = Object.entries(cur.incCat).sort((a, b) => b[1] - a[1]);
  const accSp = {}; for (const t of cur.list) if (t.type === 'expense') { const a = accById(t.accountId); if (a) accSp[a.id] = (accSp[a.id] || 0) + conv(t.amount, a.currency); }
  const dPct = (a, b) => b ? (a - b) / b * 100 : null;
  return `<section>
    <div class="seg" role="group" aria-label="Periodo"><button data-action="statsmode" data-k="month" aria-pressed="${UI.statsMode !== 'year'}">Mes</button><button data-action="statsmode" data-k="year" aria-pressed="${UI.statsMode === 'year'}">Año</button></div>
    <div class="month-nav"><button class="icon-btn" data-action="stm" data-d="-1" aria-label="Anterior">${svg('chevL')}</button><b>${label}</b><button class="icon-btn" data-action="stm" data-d="1" aria-label="Siguiente">${svg('chev')}</button></div>
    <div class="kpis">
      <div class="kpi"><div class="k-l"><span class="dot" style="--c:var(--pos)"></span>Ingresos</div><div class="k-v pos amt">${fmt(cur.inc)}</div><div class="k-s">${prev.inc ? `${fmtPct(dPct(cur.inc, prev.inc))} vs ${prevWord}` : '&nbsp;'}</div></div>
      <div class="kpi"><div class="k-l"><span class="dot" style="--c:var(--neg)"></span>Gastos</div><div class="k-v amt">${fmt(cur.exp)}</div><div class="k-s">${prev.exp ? `<span class="${cur.exp > prev.exp ? 'neg' : 'pos'}">${fmtPct(dPct(cur.exp, prev.exp))}</span> vs ${prevWord}` : '&nbsp;'}</div></div>
      <div class="kpi"><div class="k-l">Ahorro</div><div class="k-v ${pcls(cur.net)} amt">${fmt(cur.net, null, { sign: true })}</div><div class="k-s">${cur.rate != null ? `Tasa de ahorro ${fmtPct(cur.rate, false)}` : '&nbsp;'}</div></div>
      <div class="kpi"><div class="k-l">Gasto medio al día</div><div class="k-v amt">${fmt(cur.exp / Math.max(1, days))}</div><div class="k-s">Media mensual <span class="amt">${fmt(avgExp, null, { dec: 0 })}</span></div></div>
    </div>
  </section>
  <section><div class="sec-h"><h2>Gastos por categoría</h2><span class="small muted">toca para ver su evolución</span></div>
    ${segs.length ? `<div class="card"><div class="donut-wrap">${donut(segs, fmt(cur.exp, null, { dec: 0 }), 'gastado')}
      <div class="stack" style="gap:8px;min-width:0">${segs.map(sg => { const pv = sg.cid ? (pvByParent[sg.cid] || 0) : 0; const d = pv ? (sg.v - pv) / pv * 100 : null; return `<button class="catline" data-action="cat-open" data-id="${sg.cid}"><span class="dot" style="--c:${sg.color}"></span><div class="row-m"><div class="hstack" style="flex-wrap:nowrap"><span class="row-t small">${esc(sg.c.icon)} ${esc(sg.c.name)}</span><span class="spacer"></span><span class="num small amt">${fmt(sg.v, null, { dec: 0 })}</span></div><div class="row-s">${Math.round(sg.v / cur.exp * 100)} %${d != null ? ` · <span class="${d > 0 ? 'neg' : 'pos'}">${fmtPct(d)}</span>` : ''}</div></div></button>`; }).join('')}</div></div></div>` : emptyCard('Sin gastos en este periodo', 'Cuando apuntes gastos verás aquí el reparto por categoría.')}
  </section>
  <section><div class="sec-h"><h2>Ingresos y gastos</h2><span class="legend"><span><span class="dot" style="--c:var(--pos)"></span>Ingresos</span><span><span class="dot" style="--c:var(--neg)"></span>Gastos</span></span></div>
    <div class="card">${barsChart(months)}</div><div class="note">Media: ingresas <span class="amt">${fmt(avgInc, null, { dec: 0 })}</span> y gastas <span class="amt">${fmt(avgExp, null, { dec: 0 })}</span> al mes.</div></section>
  ${incs.length ? `<section><div class="sec-h"><h2>De dónde vienen tus ingresos</h2></div><div class="card">${hbars(incs.map(([cid, v]) => { const c = catById(cid) || { name: 'Otros', icon: '•', color: PALETTE[2] }; return { l: c.icon + ' ' + c.name, v, c: c.color }; }), v => fmt(v, null, { dec: 0 }))}</div></section>` : ''}
  ${cur.exp ? `<section><div class="sec-h"><h2>Qué días gastas más</h2></div><div class="card">${hbars(wd.map((v, i) => ({ l: wdNames[(i + ws) % 7], v, c: 'var(--neg)' })), v => fmt(v, null, { dec: 0 }))}</div></section>` : ''}
  ${topMerch.length ? `<section><div class="sec-h"><h2>Dónde más gastas</h2><span class="small muted">por concepto</span></div><div class="list">${topMerch.map(m => `<div class="row"><div class="row-m"><div class="row-t">${esc(m.l)}</div><div class="row-s">${m.n} ${m.n === 1 ? 'vez' : 'veces'} · media <span class="amt">${fmt(m.v / m.n)}</span></div></div><span class="num amt">${fmt(m.v)}</span></div>`).join('')}</div></section>` : ''}
  ${Object.keys(accSp).length > 1 ? `<section><div class="sec-h"><h2>Gasto por cuenta</h2></div><div class="card">${hbars(Object.entries(accSp).sort((a, b) => b[1] - a[1]).map(([id, v]) => ({ l: accById(id).name, v, c: accById(id).color })), v => fmt(v, null, { dec: 0 }))}</div></section>` : ''}
  <section><div class="sec-h"><h2>Dinero en cuentas</h2><span class="small muted">final de cada periodo</span></div><div class="card">${lineChart(cash.map(c => ({ label: finShort(c.mk), v: c.v })), { aria: 'Saldo de tus cuentas al final de cada periodo' })}</div>
    <div class="note">Cuentas, bienes y deudas (sin inversiones), calculado con tus movimientos.</div></section>
  ${snaps.length >= 2 ? `<section><div class="sec-h"><h2>Patrimonio total</h2><span class="small muted">${snaps.length} días registrados</span></div><div class="card">${lineChart(snaps, { aria: 'Evolución del patrimonio' })}</div></section>` : ''}
  ${big.length ? `<section><div class="sec-h"><h2>Mayores gastos</h2></div><div class="list">${big.map(([t]) => txRow(t)).join('')}</div></section>` : ''}
  ${tags.length ? `<section><div class="sec-h"><h2>Por etiquetas</h2></div><div class="list">${tags.map(([g, v]) => `<button class="row" data-action="tag-txs" data-tag="${esc(g)}"><span class="row-m row-t">#${esc(g)}</span><span class="num amt">${fmt(v)}</span></button>`).join('')}</div></section>` : ''}
  ${UI.statsMode !== 'year' && (S.categories.some(c => c.budget > 0) || S.settings.budgetTotal > 0) ? `<section><div class="sec-h"><h2>Presupuestos</h2></div><div class="list">${budgetRows(UI.statsMonth)}</div></section>` : ''}`;
};

/* =============================== MÁS =============================== */
VIEWS.more = P => {
  const nb = S.categories.filter(c => c.budget > 0).length + (S.settings.budgetTotal > 0 ? 1 : 0);
  return `<section><div class="list">
    ${linkRow('more/accounts', 'bank', 'Cuentas', `${S.accounts.length} cuenta${S.accounts.length === 1 ? '' : 's'} · saldos, tarjetas, préstamos, bienes`)}
    ${linkRow('more/goals', 'target', 'Objetivos', `${S.goals.length} objetivo${S.goals.length === 1 ? '' : 's'}`)}
    ${linkRow('more/groups', 'grid', 'Bloques del resumen', 'Agrupa cuentas e inversiones a tu manera')}
    ${linkRow('more/home', 'sliders', 'Personalizar el resumen', 'Qué secciones ves y en qué orden')}
  </div></section>
  <section><div class="list">
    ${linkRow('more/categories', 'tag', 'Categorías', `${S.categories.length} categorías y subcategorías`, PALETTE[3])}
    ${linkRow('more/budgets', 'gauge', 'Presupuestos', nb ? `${nb} activo${nb === 1 ? '' : 's'}` : 'Límites por periodo, total o por categoría', PALETTE[3])}
    ${linkRow('more/recurring', 'repeat', 'Recurrentes', 'Nómina, alquiler, suscripciones…', PALETTE[3])}
    ${linkRow('more/templates', 'star', 'Plantillas', `${(S.templates || []).length} accesos rápidos`, PALETTE[3])}
    ${linkRow('more/fx', 'coins', 'Divisas', 'Tu dinero por moneda y conversor', PALETTE[3])}
  </div></section>
  <section><div class="list">
    ${linkRow('more/shortcuts', 'bolt', 'Atajos de iPhone', 'Apunta gastos al pagar con Apple Pay', PALETTE[1])}
    ${linkRow('more/import', 'download', 'Importar del banco', 'Extracto en CSV o Excel', PALETTE[1])}
    ${linkRow('more/bank', 'link', 'Conectar el banco', 'Qué se puede hacer y cómo', PALETTE[1])}
    ${linkRow('more/sync', 'repeat', 'Sincronización', typeof Sync !== 'undefined' && Sync.on() ? 'Activa · ' + esc(Sync.c.email || '') : 'Varios dispositivos con los mismos datos', PALETTE[1])}
    ${linkRow('more/backup', 'shield', 'Copia de seguridad', 'Exportar, restaurar, pasar a otro dispositivo', PALETTE[1])}
  </div></section>
  <section><div class="list">
    ${linkRow('more/look', 'palette', 'Apariencia', 'Tema, color, tamaño de letra, céntimos', PALETTE[2])}
    ${linkRow('more/settings', 'gear', 'Ajustes', 'Moneda, inicio de mes y semana, avisos', PALETTE[2])}
    ${linkRow('more/security', 'lock', 'Seguridad', S.settings.pinHash ? 'PIN activado' : 'Bloqueo con PIN', PALETTE[2])}
    ${linkRow('more/prices', 'pulse', 'Fuentes de precios', 'Cripto, acciones y divisas en tiempo real', PALETTE[2])}
    ${NATIVE ? '' : linkRow('more/install', 'phone', 'Instalar en el iPhone', 'Úsala como una app desde la pantalla de inicio', PALETTE[2])}
  </div></section>
  <p class="note">Tus datos se guardan en este dispositivo. Lo único que sale a internet son las consultas de precios y, si la activas, la sincronización con tu propio Supabase.</p>`;
};
VIEWS['more/accounts'] = P => {
  const list = S.accounts.slice().sort((a, b) => (a.archived - b.archived) || (a.order ?? 0) - (b.order ?? 0));
  const act = list.filter(a => !a.archived), arch = list.filter(a => a.archived);
  const row = (a, i, n) => `<div class="row">${!a.archived ? `<div class="reorder"><button data-action="acc-move" data-id="${a.id}" data-d="-1" aria-label="Subir" ${i === 0 ? 'disabled' : ''}>${svg('up')}</button><button data-action="acc-move" data-id="${a.id}" data-d="1" aria-label="Bajar" ${i === n - 1 ? 'disabled' : ''}>${svg('down')}</button></div>` : ''}${accRow(a, P).replace('<button class="row"', '<button class="row" style="border:0;padding:0;min-height:0"')}</div>`;
  return `<section><div class="kpis"><div class="kpi"><div class="k-l">Total en cuentas</div><div class="k-v amt">${fmt(P.cashTotal)}</div></div><div class="kpi"><div class="k-l">Con inversiones</div><div class="k-v amt">${fmt(P.nw)}</div></div></div></section>
  <section>${act.length ? `<div class="list">${act.map((a, i) => row(a, i, act.length)).join('')}</div>` : emptyCard('Sin cuentas', 'Crea tu primera cuenta para empezar.')}
  <button class="btn primary block" data-action="acc-new">${svg('plus')}Nueva cuenta</button></section>
  ${arch.length ? `<section><div class="sec-h"><h2>Archivadas</h2></div><div class="list">${arch.map((a, i) => row(a, i, arch.length)).join('')}</div></section>` : ''}
  <p class="note">Toca una cuenta para ver su detalle, ajustar el saldo o editarla. Las de tipo exchange o bróker suman también las inversiones que les asignes.</p>`;
};
VIEWS['more/goals'] = P => {
  const gs = S.goals;
  return `<section>${gs.length ? `<div class="stack">${gs.map(g => goalCard(g, P)).join('')}</div>` : emptyCard('Sin objetivos', 'Crea uno y enlázalo a una cuenta, a un bloque, a tu patrimonio o ve sumando aportaciones a mano.')}
  <button class="btn primary block" data-action="goal-new">${svg('plus')}Nuevo objetivo</button></section>
  <p class="note">Si pones fecha límite verás cuánto tienes que apartar cada mes para llegar.</p>`;
};
VIEWS['more/groups'] = P => {
  return `<section>${S.groups.length ? `<div class="list">${S.groups.map((g, i) => { const v = groupValue(g, P); return `<div class="row"><div class="reorder"><button data-action="group-move" data-id="${g.id}" data-d="-1" aria-label="Subir" ${i === 0 ? 'disabled' : ''}>${svg('up')}</button><button data-action="group-move" data-id="${g.id}" data-d="1" aria-label="Bajar" ${i === S.groups.length - 1 ? 'disabled' : ''}>${svg('down')}</button></div><button class="row" style="border:0;padding:0;min-height:0" data-action="group-edit" data-id="${g.id}"><span class="dot" style="--c:${g.color};width:12px;height:12px"></span><div class="row-m"><div class="row-t">${esc(g.name)}</div><div class="row-s">${esc(groupItemsLabel(g))}</div></div><span class="num amt">${fmt(v.value)}</span></button></div>`; }).join('')}</div>` : emptyCard('Sin bloques', 'Un bloque es una tarjeta del resumen con la suma de lo que elijas: una cuenta, varias, toda tu cripto, un tipo de cuenta…')}
  <button class="btn primary block" data-action="group-new">${svg('plus')}Nuevo bloque</button></section>
  <p class="note">Ejemplos: «Cuenta principal», «Todo lo que tengo en Binance», «Dinero en dólares», «Ahorro + efectivo». Ordénalos con las flechas.</p>`;
};
VIEWS['more/home'] = () => {
  const hs = S.settings.home;
  return `<section><div class="list">${hs.map((h, i) => `<div class="row"><div class="reorder"><button data-action="home-move" data-i="${i}" data-d="-1" aria-label="Subir" ${i === 0 ? 'disabled' : ''}>${svg('up')}</button><button data-action="home-move" data-i="${i}" data-d="1" aria-label="Bajar" ${i === hs.length - 1 ? 'disabled' : ''}>${svg('down')}</button></div><label class="check" style="flex:1;padding:0"><input type="checkbox" data-home="${i}" ${h.on ? 'checked' : ''}><span>${HOME_SECTIONS[h.k]}</span></label></div>`).join('')}</div></section>
  <p class="note">El patrimonio total siempre aparece arriba del todo.</p>`;
};
AFTER['more/home'] = () => $$('[data-home]').forEach(c => c.addEventListener('change', () => { S.settings.home[+c.dataset.home].on = c.checked; save(); }));

VIEWS['more/categories'] = () => {
  const k = UI.catKind; const list = catTree(k, true);
  return `<div class="seg" role="group">${[['expense', 'Gastos'], ['income', 'Ingresos']].map(([x, l]) => `<button data-action="catkind" data-k="${x}" aria-pressed="${k === x}">${l}</button>`).join('')}</div>
  <section><div class="list">${list.map(c => { const n = S.txs.filter(t => txParts(t).some(p => p.categoryId === c.id)).length; const sib = S.categories.filter(x => x.kind === k && (x.parentId || '') === (c.parentId || '')); const i = sib.indexOf(c);
    return `<div class="row" style="${c.parentId ? 'padding-left:34px' : ''}${c.hidden ? ';opacity:.55' : ''}"><div class="reorder"><button data-action="cat-move" data-id="${c.id}" data-d="-1" aria-label="Subir" ${i === 0 ? 'disabled' : ''}>${svg('up')}</button><button data-action="cat-move" data-id="${c.id}" data-d="1" aria-label="Bajar" ${i === sib.length - 1 ? 'disabled' : ''}>${svg('down')}</button></div>
    <button class="row" style="border:0;padding:0;min-height:0" data-action="cat-edit" data-id="${c.id}">${ico(esc(c.icon), c.color, c.parentId ? 'sm' : '')}<div class="row-m"><div class="row-t">${esc(c.name)}${c.hidden ? ' · oculta' : ''}</div><div class="row-s">${n} movimiento${n === 1 ? '' : 's'}${c.budget > 0 ? ` · <span class="amt">${fmt(c.budget, null, { dec: 0 })}</span>/mes` : ''}${c.keywords ? ' · reglas' : ''}</div></div>${svg('chev', 'chev')}</button></div>`; }).join('')}</div>
  <div class="row2"><button class="btn primary" data-action="cat-new" data-k="${k}">${svg('plus')}Categoría</button><button class="btn" data-action="cat-new" data-k="${k}" data-sub="1">${svg('plus')}Subcategoría</button></div></section>
  <p class="note">Las subcategorías suman en su categoría principal en el análisis y en los presupuestos. Las palabras clave clasifican solas lo que importes o apuntes desde Atajos.</p>`;
};
VIEWS['more/budgets'] = () => {
  const mk = curMk(); const R = FR(mk);
  const list = catTree('expense');
  const avg3 = c => { let s = 0; for (let i = 1; i <= 3; i++) { const r = FR(addMonths(mk, -i)); s += catSpend(c.id, r.from, r.to); } return s / 3; };
  const avgAll = (() => { let s = 0; for (let i = 1; i <= 3; i++) { const r = FR(addMonths(mk, -i)); s += flows(r.from, r.to).exp; } return s / 3; })();
  return `<section class="card form"><b>Presupuesto total del periodo</b>
    <div class="toolbar"><input class="inp num" inputmode="decimal" id="budTotal" value="${S.settings.budgetTotal ? inputNum(S.settings.budgetTotal) : ''}" placeholder="Sin límite" aria-label="Presupuesto total"><span class="muted">${S.settings.base}</span></div>
    <p class="note" style="margin:0">Todo lo que gastes cuenta aquí. Media de los últimos 3 periodos: <span class="amt">${fmt(avgAll, null, { dec: 0 })}</span>. Con él, el resumen te dice cuánto puedes gastar cada día.</p>
    <label class="check"><input type="checkbox" id="budAlerts" ${S.settings.budgetAlerts ? 'checked' : ''}><span>Avisarme al llegar al 80 % y al 100 % de un presupuesto</span></label></section>
  <section><div class="sec-h"><h2>Por categoría</h2><span class="small muted">${finLabel(mk)}</span></div>
  <div class="list">${list.map(c => `<div class="row" style="flex-wrap:wrap;${c.parentId ? 'padding-left:30px' : ''}">${ico(esc(c.icon), c.color, 'sm')}<div class="row-m"><div class="row-t">${esc(c.name)}</div><div class="row-s">Media <span class="amt">${fmt(avg3(c), null, { dec: 0 })}</span> · ahora <span class="amt">${fmt(catSpend(c.id, R.from, R.to), null, { dec: 0 })}</span></div></div><input class="inp num" style="width:100px;min-height:40px;text-align:right" inputmode="decimal" data-budget="${c.id}" value="${c.budget ? inputNum(c.budget) : ''}" placeholder="—" aria-label="Presupuesto de ${esc(c.name)}">
    <label class="check small" style="width:100%;padding:4px 0 0 50px"><input type="checkbox" data-roll="${c.id}" ${c.rollover ? 'checked' : ''} style="width:18px;height:18px"><span>Pasar lo que sobre (o falte) al siguiente periodo</span></label></div>`).join('')}</div></section>
  <p class="note">Importes en ${S.settings.base} por periodo. Vacío = sin presupuesto. El presupuesto de una categoría principal incluye sus subcategorías.</p>`;
};
AFTER['more/budgets'] = () => {
  $$('[data-budget]').forEach(i => i.addEventListener('change', () => { const c = catById(i.dataset.budget); const v = parseMoney(i.value); c.budget = v > 0 ? Math.round(v * 100) / 100 : 0; save(); toast('Presupuesto guardado'); }));
  $$('[data-roll]').forEach(i => i.addEventListener('change', () => { catById(i.dataset.roll).rollover = i.checked; save(); }));
  $('#budTotal').addEventListener('change', e => { const v = parseMoney(e.target.value); S.settings.budgetTotal = v > 0 ? Math.round(v * 100) / 100 : 0; save(); toast('Presupuesto total guardado'); });
  $('#budAlerts').addEventListener('change', e => { S.settings.budgetAlerts = e.target.checked; save(); });
};
VIEWS['more/recurring'] = () => {
  const act = S.recurring.filter(r => r.active).sort((a, b) => a.next < b.next ? -1 : 1), off = S.recurring.filter(r => !r.active);
  const monthly = sum(act, r => { const v = conv(r.tpl.amount, accById(r.tpl.accountId)?.currency) * (r.tpl.type === 'income' ? 1 : r.tpl.type === 'expense' ? -1 : 0); const f = r.freq === 'daily' ? 30.4 : r.freq === 'weekly' ? 4.35 : r.freq === 'yearly' ? 1 / 12 : 1; return v * f / (r.interval || 1); });
  const subs = sum(act.filter(r => r.tpl.type === 'expense'), r => { const v = conv(r.tpl.amount, accById(r.tpl.accountId)?.currency); const f = r.freq === 'daily' ? 30.4 : r.freq === 'weekly' ? 4.35 : r.freq === 'yearly' ? 1 / 12 : 1; return v * f / (r.interval || 1); });
  return `<section><div class="kpis"><div class="kpi"><div class="k-l">Gastos fijos al mes</div><div class="k-v amt">${fmt(subs)}</div><div class="k-s"><span class="amt">${fmt(subs * 12, null, { dec: 0 })}</span> al año</div></div><div class="kpi"><div class="k-l">Balance fijo mensual</div><div class="k-v ${pcls(monthly)} amt">${fmt(monthly, null, { sign: true })}</div><div class="k-s">ingresos − gastos fijos</div></div></div></section>
  <section>${act.length ? `<div class="list">${act.map(recRow).join('')}</div>` : emptyCard('Sin recurrentes', 'Añade la nómina, el alquiler o tus suscripciones y se apuntarán solos cada vez que toque.')}
  <button class="btn primary block" data-action="rec-new">${svg('plus')}Nuevo recurrente</button></section>
  ${off.length ? `<section><div class="sec-h"><h2>En pausa</h2></div><div class="list">${off.map(recRow).join('')}</div></section>` : ''}
  <p class="note">Los recurrentes se apuntan automáticamente al abrir la app el día que tocan (o después, si no la abriste).</p>`;
};

/* ---------- divisas ---------- */
function exposure(P) {
  const m = {};
  const add = (code, native, base, kind) => { const e = m[code] || (m[code] = { code, native: 0, base: 0, kind }); e.native += native; e.base += base; };
  for (const r of P.accounts) if (r.inTotal) add(r.a.currency, r.bal, r.base, 'fiat');
  for (const r of P.assets) {
    if (!r.inTotal) continue;
    if (r.x.kind === 'crypto') add(r.x.symbol, r.h.qty, r.value, 'crypto');
    else { const c = (r.pr && r.pr.ccy) || r.x.quoteCcy || S.settings.base; add(c, conv(r.value, S.settings.base, c), r.value, 'fiat'); }
  }
  return Object.values(m).filter(e => Math.abs(e.base) > 0.004).sort((a, b) => b.base - a.base);
}
function fxDyn(P) {
  const base = S.settings.base; const ex = exposure(P); const tot = sum(ex, e => Math.max(0, e.base));
  const favs = S.settings.favCcy.filter(c => c !== base);
  const fx = S.cache.fx;
  return `<section><div class="sec-h"><h2>Tu dinero por moneda</h2></div>
    ${ex.length ? `<div class="list">${ex.map(e => `<div class="row">${ico(esc(e.code), e.kind === 'crypto' ? PALETTE[5] : PALETTE[1], 'txt')}<div class="row-m"><div class="row-t">${esc(CCY_NAMES[e.code] || e.code)}</div><div class="row-s">${tot > 0 ? Math.round(Math.max(0, e.base) / tot * 100) : 0} % de tu patrimonio</div></div><div class="row-r"><span class="num amt">${fmt(e.native, e.code)}</span>${e.code !== base ? `<span class="row-s amt">≈ ${fmt(e.base)}</span>` : ''}</div></div>`).join('')}</div>
    ${allocHtml(ex.map((e, i) => ({ l: e.code, v: Math.max(0, e.base), c: PALETTE[i % PALETTE.length] })), tot)}` : emptyCard('Sin datos', 'Añade cuentas o inversiones.')}
    <div class="note">Las acciones cuentan en la moneda en la que cotizan (una acción de EE. UU. es exposición al dólar).</div></section>
  <section><div class="sec-h"><h2>Tu patrimonio en…</h2></div>
    <div class="list">${favs.map(c => `<div class="row">${ico(esc(c), isFiat(c) ? PALETTE[1] : PALETTE[5], 'txt')}<div class="row-m"><div class="row-t">${esc(CCY_NAMES[c] || c)}</div><div class="row-s">${canConv(c) ? `1 ${base} = ${fmtRate(conv(1, base, c))} ${c}` : 'Sin cotización todavía'}</div></div><span class="num amt">${canConv(c) ? fmt(conv(P.nw, base, c), c) : '—'}</span><button class="icon-btn" data-action="fav-del" data-c="${esc(c)}" aria-label="Quitar ${esc(c)}"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M7 7l10 10M17 7L7 17"/></svg></button></div>`).join('')}</div>
  </section>
  <section><div class="sec-h"><h2>Tipos de cambio</h2><button class="link" data-action="fx-refresh">Actualizar</button></div>
    <div class="tbl-wrap"><table><thead><tr><th>Moneda</th><th class="r">1 ${base} =</th><th class="r">1 unidad =</th></tr></thead><tbody>
    ${COMMON_CCY.filter(c => c !== base && canConv(c)).map(c => `<tr><td><b>${c}</b> <span class="muted">${esc(CCY_NAMES[c] || '')}</span></td><td class="r num">${fmtRate(conv(1, base, c))}</td><td class="r num">${fmt(conv(1, c, base), base, { dec: 4 })}</td></tr>`).join('')}
    </tbody></table></div>
    <div class="note">${fx ? `Fuente: ${esc(fx.src)} · descargado ${ago(fx.t)}. <a href="https://www.exchangerate-api.com" target="_blank" rel="noopener">Rates By Exchange Rate API</a>` : 'Usando tipos aproximados hasta conectar con internet.'}</div>
  </section>`;
}
VIEWS['more/fx'] = P => {
  const base = S.settings.base; const all = [...new Set([...COMMON_CCY, ...Object.keys(fxRates()).sort()])];
  const opts = sel => all.map(c => `<option value="${c}" ${c === sel ? 'selected' : ''}>${c}${CCY_NAMES[c] ? ' · ' + CCY_NAMES[c] : ''}</option>`).join('');
  const cryptoOpts = Object.keys(CG_IDS).filter(c => !STABLES.has(c));
  return `<section><div class="sec-h"><h2>Conversor</h2></div>
    <div class="card form">
      <input class="inp num" id="cvAmt" inputmode="decimal" value="100" aria-label="Importe" style="font-size:22px">
      <div class="row2" style="align-items:center"><div class="sel"><select id="cvFrom" aria-label="De">${opts(base)}${cryptoOpts.map(c => `<option value="${c}">${c} · cripto</option>`).join('')}</select></div><div class="sel"><select id="cvTo" aria-label="A">${opts(base === 'USD' ? 'EUR' : 'USD')}${cryptoOpts.map(c => `<option value="${c}">${c} · cripto</option>`).join('')}</select></div></div>
      <div class="hstack"><div class="num amt" id="cvOut" style="font-size:24px;font-weight:600;color:var(--accent)"></div><span class="spacer"></span><button class="btn sm" data-action="cv-swap" aria-label="Intercambiar">${svg('swap')}</button></div>
    </div></section>
  <div id="fxDyn">${fxDyn(P)}</div>
  <section><div class="sec-h"><h2>Añadir moneda a «Tu patrimonio en…»</h2></div>
    <div class="toolbar"><div class="sel" style="flex:1"><select id="favAdd">${all.filter(c => !S.settings.favCcy.includes(c)).map(c => `<option value="${c}">${c}${CCY_NAMES[c] ? ' · ' + CCY_NAMES[c] : ''}</option>`).join('')}${cryptoOpts.filter(c => !S.settings.favCcy.includes(c)).map(c => `<option value="${c}">${c} · cripto</option>`).join('')}</select></div><button class="btn" data-action="fav-add">Añadir</button></div>
  </section>`;
};
function updateConv() {
  const a = $('#cvAmt'); if (!a) return; const n = parseMoney(a.value); const f = $('#cvFrom').value, t = $('#cvTo').value;
  if (!(canConv(f) && canConv(t))) { $('#cvOut').textContent = 'Sin cotización para ' + (!canConv(f) ? f : t) + ' todavía'; return; }
  $('#cvOut').textContent = isNaN(n) ? '—' : fmt(conv(n, f, t), t);
}
AFTER['more/fx'] = () => { ['#cvAmt', '#cvFrom', '#cvTo'].forEach(s => $(s).addEventListener('input', updateConv)); ['#cvFrom', '#cvTo'].forEach(s => $(s).addEventListener('change', () => { const c = [$('#cvFrom').value, $('#cvTo').value].find(x => !isFiat(x)); if (c) { if (!S.settings.favCcy.includes(c)) { S.settings.favCcy.push(c); save(); } pollCrypto(); connectBinance(); } updateConv(); })); updateConv(); };

/* ---------- conectar banco ---------- */
VIEWS['more/bank'] = () => `
  <section class="card stack"><b>Lo que funciona hoy: importar el extracto</b>
    <p class="note" style="margin:0">Casi todos los bancos (Santander, BBVA, CaixaBank, ING, Sabadell, Openbank, Revolut…) dejan descargar los movimientos en Excel o CSV desde la web. Importarlos aquí tarda un minuto: detecta columnas, evita duplicados y clasifica por palabras clave.</p>
    <button class="btn primary" data-go="more/import">Importar un extracto</button></section>
  <section class="card stack"><b>Conexión automática (open banking)</b>
    <p class="note" style="margin:0">La conexión directa con el banco se hace con la directiva PSD2 a través de un agregador autorizado. Para uso personal y gratuito, la opción viva es <b>Enable Banking</b>: permite enlazar tus propias cuentas en modo restringido sin contrato. GoCardless Bank Account Data (antes Nordigen) no admite registros nuevos.</p>
    <p class="note" style="margin:0">Necesita un pequeño servidor (por ejemplo una Edge Function de Supabase) porque las peticiones van firmadas con una clave privada que no puede estar en la web. El consentimiento caduca cada 90 días y hay que renovarlo.</p>
    <a class="btn" href="https://enablebanking.com/docs/api/linked-accounts/" target="_blank" rel="noopener">Ver cómo funciona Enable Banking</a></section>
  <p class="note">Por seguridad, esta web nunca te pedirá la contraseña de tu banco.</p>`;

/* ---------- ajustes, precios, instalar, copia ---------- */
VIEWS['more/settings'] = () => {
  const st = S.settings; const all = [...new Set([...COMMON_CCY, ...Object.keys(fxRates()).sort()])].filter(isFiat);
  return `<section class="card form">
    <label class="field"><span>Moneda principal</span><div class="sel"><select id="stBase">${all.map(c => `<option value="${c}" ${c === st.base ? 'selected' : ''}>${c}${CCY_NAMES[c] ? ' · ' + CCY_NAMES[c] : ''}</option>`).join('')}</select></div></label>
    <label class="field"><span>El mes empieza el día</span><div class="sel"><select id="stMonth">${Array.from({ length: 28 }, (_, i) => i + 1).map(d => `<option value="${d}" ${d === (st.monthStart || 1) ? 'selected' : ''}>${d === 1 ? '1 (mes natural)' : d}</option>`).join('')}</select></div></label>
    <p class="note" style="margin:-6px 0 0">Si cobras a final de mes, pon el día de la nómina: presupuestos, análisis y movimientos irán de nómina a nómina.</p>
    <label class="field"><span>La semana empieza el</span><div class="sel"><select id="stWeek"><option value="1" ${st.weekStart === 1 ? 'selected' : ''}>Lunes</option><option value="0" ${st.weekStart === 0 ? 'selected' : ''}>Domingo</option><option value="6" ${st.weekStart === 6 ? 'selected' : ''}>Sábado</option></select></div></label>
    <label class="check"><input type="checkbox" id="stPriv" ${st.privacy ? 'checked' : ''}><span>Ocultar importes al abrir (se muestran tocando el ojo)</span></label>
  </section>
  ${NATIVE ? `<section class="card form"><b>Avisos en el iPhone</b>
    <label class="check"><input type="checkbox" id="stNotif" ${st.notifyRecurring ? 'checked' : ''}><span>Avisarme el día antes de cada cargo recurrente</span></label>
    <label class="field"><span>Hora del aviso</span><div class="sel"><select id="stHour">${[7, 8, 9, 10, 12, 18, 20, 21].map(h => `<option value="${h}" ${h === st.notifyHour ? 'selected' : ''}>${h}:00</option>`).join('')}</select></div></label>
    <button class="btn sm" data-action="notif-test">Enviar un aviso de prueba</button></section>` : ''}
  <section><div class="sec-h"><h2>Tus datos</h2></div><div class="list">
    ${linkRow('more/backup', 'shield', 'Copia de seguridad', 'Exportar o restaurar')}
    <button class="row" data-action="load-demo">${ico(svg('refresh'), 'var(--muted)')}<div class="row-m"><div class="row-t">Cargar datos de ejemplo</div><div class="row-s">Sustituye lo que tengas ahora</div></div></button>
  </div>
  <button class="btn danger block" data-action="wipe" data-confirm="Toca otra vez para borrarlo TODO">Borrar todos los datos</button></section>
  <p class="note">Caudal · versión 2.1 · ${NATIVE ? 'app de iPhone' : 'web'}.</p>`;
};
AFTER['more/settings'] = () => {
  $('#stBase').addEventListener('change', e => { S.settings.base = e.target.value; nfCache.clear(); save(); toast('Moneda principal: ' + e.target.value); render(); });
  $('#stMonth').addEventListener('change', e => { S.settings.monthStart = +e.target.value; UI.txF.month = curMk(); UI.statsMonth = curMk(); save(); toast('Guardado'); });
  $('#stWeek').addEventListener('change', e => { S.settings.weekStart = +e.target.value; save(); });
  $('#stPriv').addEventListener('change', e => { S.settings.privacy = e.target.checked; save(); chrome(); });
  const n = $('#stNotif'); if (n) { n.addEventListener('change', e => { S.settings.notifyRecurring = e.target.checked; save(); scheduleNotifs(true); }); $('#stHour').addEventListener('change', e => { S.settings.notifyHour = +e.target.value; save(); scheduleNotifs(true); }); }
};
const ACCENTS = {
  malva: ['Malva', '#e4b3cb', '#9b4873'], azul: ['Azul', '#8fb4ff', '#2f5fb8'], verde: ['Verde', '#6fd49b', '#1b7a47'], ambar: ['Ámbar', '#f0c46a', '#8a5d00'],
  coral: ['Coral', '#ff9f7a', '#b44a22'], lila: ['Lila', '#b39cff', '#5b3fc4'], turquesa: ['Turquesa', '#62cfd0', '#0e7475'], rojo: ['Rojo', '#ff8686', '#b52f2f'], mono: ['Blanco y negro', '#f2edf4', '#1c1620'],
};
VIEWS['more/look'] = () => {
  const st = S.settings;
  return `<section class="card form">
    <div class="field"><span>Tema</span><div class="seg">${[['auto', 'Auto'], ['light', 'Claro'], ['dark', 'Oscuro'], ['black', 'Negro']].map(([k, l]) => `<button data-action="theme" data-k="${k}" aria-pressed="${st.theme === k}">${l}</button>`).join('')}</div></div>
    <p class="note" style="margin:-6px 0 0">«Negro» es negro puro: gasta menos batería en pantallas OLED como la del iPhone.</p>
    <label class="check"><input type="checkbox" id="lkGlass" ${st.glass !== false ? 'checked' : ''}><span>Liquid Glass (cristal translúcido, barra flotante)</span></label>
    <div class="field"><span>Color de acento</span><div class="swatches">${Object.entries(ACCENTS).map(([k, [l, d, li]]) => `<button type="button" data-action="accent" data-k="${k}" style="--c:${d};box-shadow:inset 0 0 0 2px var(--surface),inset 0 0 0 16px ${li}" aria-label="${l}" aria-pressed="${st.accent === k}"></button>`).join('')}<label class="custom-color" aria-label="Color personalizado"><input type="color" id="lkCustom" value="${esc(st.customAccent || '#e4b3cb')}"><span>${st.accent === 'custom' ? '✓ ' : ''}Otro</span></label></div></div>
    <div class="field"><span>Tamaño de letra</span><div class="seg">${[['s', 'Pequeño'], ['m', 'Normal'], ['l', 'Grande'], ['xl', 'Enorme']].map(([k, l]) => `<button data-action="textsize" data-k="${k}" aria-pressed="${st.textSize === k}">${l}</button>`).join('')}</div></div>
    <label class="check"><input type="checkbox" id="lkCents" ${st.hideCents ? 'checked' : ''}><span>Ocultar los céntimos (1.234 € en vez de 1.234,56 €)</span></label>
  </section>
  <section class="card form">
    <label class="field"><span>Tu nombre (para saludarte)</span><input type="text" id="lkName" value="${esc(st.name || '')}" placeholder="Opcional" maxlength="24"></label>
    <label class="field"><span>Pantalla al abrir</span><div class="sel"><select id="lkStart">${[['home', 'Resumen'], ['txs', 'Movimientos'], ['inv', 'Inversiones'], ['stats', 'Análisis']].map(([k, l]) => `<option value="${k}" ${st.startTab === k ? 'selected' : ''}>${l}</option>`).join('')}</select></div></label>
    <label class="field"><span>Movimientos recientes en el resumen</span><div class="sel"><select id="lkRecent">${[3, 6, 10, 15].map(n => `<option value="${n}" ${n === (st.recentCount || 6) ? 'selected' : ''}>${n}</option>`).join('')}</select></div></label>
  </section>
  <section><div class="list">${linkRow('more/home', 'sliders', 'Secciones del resumen', 'Activa, oculta y ordena')}${linkRow('more/groups', 'grid', 'Bloques del resumen', 'Tus propias sumas de cuentas e inversiones')}</div></section>`;
};
AFTER['more/look'] = () => {
  $('#lkCustom').addEventListener('change', e => { S.settings.customAccent = e.target.value; S.settings.accent = 'custom'; applyLook(); save(); render(); });
  $('#lkGlass').addEventListener('change', e => { S.settings.glass = e.target.checked; applyLook(); save(); });
  $('#lkCents').addEventListener('change', e => { S.settings.hideCents = e.target.checked; nfCache.clear(); save(); });
  $('#lkName').addEventListener('change', e => { S.settings.name = e.target.value.trim(); save(); });
  $('#lkStart').addEventListener('change', e => { S.settings.startTab = e.target.value; save(); });
  $('#lkRecent').addEventListener('change', e => { S.settings.recentCount = +e.target.value; save(); });
};
VIEWS['more/security'] = () => {
  const st = S.settings;
  return `<section class="card form"><b>Bloqueo con PIN</b>
    <p class="note" style="margin:0">Pide un PIN de 4 dígitos al abrir la app y al volver a ella. El PIN se guarda cifrado (hash), nunca en claro.</p>
    ${st.pinHash ? `<label class="field"><span>Bloquear al salir de la app</span><div class="sel"><select id="scLock">${[[0, 'Al momento'], [1, 'Tras 1 minuto'], [5, 'Tras 5 minutos'], [15, 'Tras 15 minutos'], [60, 'Tras 1 hora']].map(([v, l]) => `<option value="${v}" ${v === (st.lockAfter || 0) ? 'selected' : ''}>${l}</option>`).join('')}</select></div></label>
      <div class="row2"><button class="btn" data-action="pin-set">Cambiar PIN</button><button class="btn danger" data-action="pin-off" data-confirm="Toca otra vez para quitarlo">Quitar PIN</button></div>
      <button class="btn ghost sm" data-action="lock-now">Bloquear ahora</button>`
      : `<button class="btn primary" data-action="pin-set">Activar PIN</button>`}
  </section>
  <section class="card stack"><b>Ocultar importes</b><p class="note" style="margin:0">El icono del ojo, arriba, difumina todas las cifras. En Ajustes puedes hacer que la app se abra siempre así.</p></section>`;
};
AFTER['more/security'] = () => { const l = $('#scLock'); if (l) l.addEventListener('change', e => { S.settings.lockAfter = +e.target.value; save(); }); };
VIEWS['more/templates'] = () => {
  const ts = S.templates || [];
  return `<section>${ts.length ? `<div class="list">${ts.map((t, i) => { const c = catById(t.tpl.categoryId), a = accById(t.tpl.accountId); return `<div class="row"><div class="reorder"><button data-action="tpl-move" data-id="${t.id}" data-d="-1" aria-label="Subir" ${i === 0 ? 'disabled' : ''}>${svg('up')}</button><button data-action="tpl-move" data-id="${t.id}" data-d="1" aria-label="Bajar" ${i === ts.length - 1 ? 'disabled' : ''}>${svg('down')}</button></div><button class="row" style="border:0;padding:0;min-height:0" data-action="tpl-edit" data-id="${t.id}">${ico(esc(t.icon || (c ? c.icon : '•')), c ? c.color : 'var(--accent)')}<div class="row-m"><div class="row-t">${esc(t.name)}</div><div class="row-s">${TYPE_L[t.tpl.type]} · ${a ? esc(a.name) : ''}${c ? ' · ' + esc(c.name) : ''}</div></div><span class="num amt">${t.tpl.amount ? fmt(t.tpl.amount, a ? a.currency : null) : 'pide importe'}</span></button></div>`; }).join('')}</div>` : emptyCard('Sin plantillas', 'Guarda tus gastos de siempre (café, menú, gasolina, metro) y apúntalos con un toque desde el resumen o desde Atajos.')}
  <button class="btn primary block" data-action="tpl-new">${svg('plus')}Nueva plantilla</button></section>
  <p class="note">También puedes crear una plantilla desde cualquier movimiento con «Guardar como plantilla».</p>`;
};
VIEWS['more/prices'] = () => {
  const st = S.settings;
  const stat = (s, e) => s === 'ok' || s === 'live' ? '<span class="chip pos">Funciona</span>' : s === 'error' ? `<span class="chip neg">Error</span>` : s === 'loading' || s === 'connecting' ? '<span class="chip">Conectando</span>' : '<span class="chip">Sin uso</span>';
  return `<section class="card stack"><div class="hstack"><b>Criptomonedas</b><span class="spacer"></span>${stat(PX.st.binance === 'live' ? 'live' : PX.st.cg)}</div>
    <p class="note" style="margin:0">Binance manda cada cambio de precio al instante; CoinGecko cubre cualquier moneda cada minuto. No hace falta configurar nada.</p>
    <label class="check"><input type="checkbox" id="prBin" ${st.binance ? 'checked' : ''}><span>Precio en directo desde Binance</span></label></section>
  <section class="card form"><div class="hstack"><b>Acciones y ETF</b><span class="spacer"></span>${stat(st.yahooProxy ? PX.st.yahoo : st.finnhubKey ? PX.st.finnhub : 'idle')}</div>
    <p class="note" style="margin:0"><b>Opción A · Yahoo Finance (recomendada):</b> cubre cualquier bolsa (Madrid, Xetra, Nasdaq…), ETF y fondos cotizados. Como Yahoo no deja consultarse desde una web, necesita un proxy: una Edge Function de Supabase que va incluida en la descarga (<code>supabase/functions/quotes</code>). Pega aquí su URL.</p>
    <label class="field"><span>URL del proxy</span><input type="url" id="prProxy" value="${esc(st.yahooProxy)}" placeholder="https://xxxx.supabase.co/functions/v1/quotes" autocomplete="off"></label>
    <div class="hstack"><button class="btn sm" data-action="proxy-test">Probar proxy</button><span class="small muted" id="proxyRes"></span></div>
    <p class="note" style="margin:0"><b>Opción B · Finnhub:</b> clave gratuita en finnhub.io, precios de EE. UU. en directo por WebSocket. No cubre bolsas europeas en el plan gratis.</p>
    <label class="field"><span>Clave de Finnhub</span><input type="password" id="prFh" value="${esc(st.finnhubKey)}" placeholder="Pega tu API key" autocomplete="off"></label>
    <a class="small" href="https://finnhub.io/register" target="_blank" rel="noopener">Conseguir una clave gratis en Finnhub</a>
    ${PX.st.err.yahoo || PX.st.err.finnhub ? `<div class="err">${esc(PX.st.err.yahoo || PX.st.err.finnhub)}</div>` : ''}
  </section>
  <section class="card form"><b>Frecuencia de actualización</b>
    <div class="sel"><select id="prRef">${[15, 30, 60, 120, 300].map(s => `<option value="${s}" ${st.refreshSec === s ? 'selected' : ''}>Cada ${s < 60 ? s + ' segundos' : s / 60 + (s === 60 ? ' minuto' : ' minutos')}</option>`).join('')}</select></div>
    <p class="note" style="margin:0">Afecta a las acciones. La cripto por Binance va siempre al instante y CoinGecko como mínimo cada minuto.</p></section>
  <section class="card stack"><b>Divisas</b><p class="note" style="margin:0">ExchangeRate-API, con el Banco Central Europeo (Frankfurter) de respaldo. Se actualiza cada hora.</p><button class="btn sm" data-action="fx-refresh">Actualizar ahora</button></section>`;
};
AFTER['more/prices'] = () => {
  $('#prBin').addEventListener('change', e => { S.settings.binance = e.target.checked; save(); restartFeeds(); });
  $('#prProxy').addEventListener('change', e => { S.settings.yahooProxy = e.target.value.trim(); save(); restartFeeds(); });
  $('#prFh').addEventListener('change', e => { S.settings.finnhubKey = e.target.value.trim(); save(); restartFeeds(); });
  $('#prRef').addEventListener('change', e => { S.settings.refreshSec = +e.target.value; save(); startPrices(); });
};
VIEWS['more/install'] = () => `
  <section class="card stack"><b>En el iPhone (Safari)</b><ol class="steps">
    <li>Abre la web en <b>Safari</b> (no desde otra app).</li>
    <li>Toca el botón <b>Compartir</b> (el cuadrado con la flecha hacia arriba).</li>
    <li>Baja y elige <b>Añadir a pantalla de inicio</b>.</li>
    <li>Pulsa <b>Añadir</b>. Tendrás el icono de Caudal como una app más, a pantalla completa.</li></ol></section>
  <section class="card stack"><b>Cosas a saber</b>
    <p class="note" style="margin:0">Los datos de la app instalada viven dentro de ella. Si antes la usabas en Safari, pásalos con Copia de seguridad → Exportar y luego Restaurar dentro de la app.</p>
    <p class="note" style="margin:0">Haz una copia de seguridad de vez en cuando: si borras la app o los datos de Safari, se pierden.</p></section>`;
VIEWS['more/backup'] = () => `
  <section class="card stack"><b>Exportar</b><p class="note" style="margin:0">Descarga un archivo con todo: cuentas, movimientos, inversiones, objetivos y ajustes.</p>
    <div class="row2"><button class="btn primary" data-action="export-json">Copia completa (.json)</button><button class="btn" data-action="export-csv">Movimientos (.csv)</button></div>
    <button class="btn ghost sm" data-action="copy-json">Copiar la copia al portapapeles</button></section>
  <section class="card stack"><b>Restaurar</b><p class="note" style="margin:0">Carga un archivo .json exportado antes. Sustituye todos los datos de este dispositivo.</p>
    <button class="btn" data-action="import-json">Elegir archivo…</button></section>
  <p class="note">${S.txs.length} movimientos · ${S.accounts.length} cuentas · ${S.assets.length} inversiones · ${S.snapshots.length} días de historial.</p>`;
