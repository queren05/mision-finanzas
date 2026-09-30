/* =====================================================================
   Extras: Atajos de iPhone (enlaces mision://), apunte rápido, plantillas,
   apariencia, bloqueo con PIN, avisos, gráficos históricos y más acciones
   ===================================================================== */
UI.histRange = '1M';
const escapeRe = s => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const norm = s => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();

/* ---------- reconocer cuenta y categoría a partir de texto ---------- */
function matchAccount(str, isCard) {
  const q = norm(str); if (!q) return null;
  const list = activeAccounts();
  const alias = a => norm(a.cardAlias).split(',').map(x => x.trim()).filter(Boolean);
  return list.find(a => alias(a).includes(q)) || list.find(a => norm(a.name) === q)
    || list.find(a => alias(a).some(x => q.includes(x) || x.includes(q)))
    || list.find(a => q.includes(norm(a.name)) || norm(a.name).includes(q))
    || (isCard ? list.find(a => { const d = q.match(/\d{4}/); return d && (a.cardAlias || '').includes(d[0]); }) : null) || null;
}
function findCat(name, kind) {
  const q = norm(name); if (!q) return null;
  const list = S.categories.filter(c => !kind || c.kind === kind);
  return list.find(c => norm(c.name) === q) || list.find(c => norm(c.name).includes(q) || q.includes(norm(c.name))) || null;
}
function guessCat(text, kind) {
  const q = norm(text); if (!q) return null;
  const list = S.categories.filter(c => c.kind === kind && !c.hidden);
  // primero las subcategorías (más concretas)
  const ordered = [...list.filter(c => c.parentId), ...list.filter(c => !c.parentId)];
  for (const c of ordered) for (const k of norm(c.keywords).split(',').map(x => x.trim()).filter(Boolean)) if (q.includes(k)) return c;
  return ordered.find(c => norm(c.name).length > 2 && q.includes(norm(c.name))) || null;
}
function prevCatFor(note, type) {
  const n = norm(note); if (!n) return null;
  const prev = sortTx(S.txs).find(x => x.type === type && norm(x.note) === n && x.categoryId);
  return prev ? catById(prev.categoryId) : null;
}

// «12,50 mercadona», «+1680 nómina», «3 café efectivo ayer»
function parseQuick(txt) {
  let s = String(txt || '').trim(); if (!s) return null;
  let type = 'expense';
  if (/^\+/.test(s) || /\b(ingreso|cobro|n[oó]mina|me pagan|me han pagado|me devuelven)\b/i.test(s)) type = 'income';
  const m = s.match(/[-+]?\d[\d.,]*/);
  const amount = m ? Math.abs(parseMoney(m[0])) : 0;
  let rest = m ? s.slice(0, m.index) + ' ' + s.slice(m.index + m[0].length) : s;
  rest = rest.replace(/€|\beuros?\b|\beur\b/gi, ' ').replace(/^\s*\+/, ' ');
  let date = null;
  if (/\banteayer\b/i.test(rest)) { date = addDays(today(), -2); rest = rest.replace(/\banteayer\b/i, ' '); }
  else if (/\bayer\b/i.test(rest)) { date = addDays(today(), -1); rest = rest.replace(/\bayer\b/i, ' '); }
  else rest = rest.replace(/\bhoy\b/i, ' ');
  let accountId = null;
  for (const a of activeAccounts()) {
    const names = [a.name, ...String(a.cardAlias || '').split(',')].map(x => x.trim()).filter(x => x.length > 2);
    const hit = names.find(nm => norm(rest).includes(norm(nm)));
    if (hit) { accountId = a.id; rest = rest.replace(new RegExp('\\b(con|en|desde)?\\s*' + escapeRe(hit), 'i'), ' '); break; }
  }
  if (!accountId && /\befectivo\b/i.test(rest)) { const c = activeAccounts().find(a => a.type === 'efectivo'); if (c) { accountId = c.id; rest = rest.replace(/\b(en|con)?\s*efectivo\b/i, ' '); } }
  const note = rest.replace(/\s+/g, ' ').replace(/^(de|en|con)\s+/i, '').trim();
  const c = prevCatFor(note, type) || guessCat(note, type);
  return { type, amount, note: note ? cap(note) : '', accountId, date, categoryId: c ? c.id : '' };
}

/* ---------- enlaces mision:// (Atajos) y #nuevo?… en la web ---------- */
function parseLink(raw) {
  const m = String(raw || '').trim().replace(/^[a-z][\w+.-]*:\/\//i, '').replace(/^#\/?/, '');
  const qi = m.indexOf('?');
  const path = (qi < 0 ? m : m.slice(0, qi)).replace(/^\/+|\/+$/g, '').toLowerCase();
  const q = new URLSearchParams(qi < 0 ? '' : m.slice(qi + 1));
  return { path, q, get: (...k) => { for (const x of k) { const v = q.get(x); if (v != null && String(v).trim() !== '') return String(v).trim(); } return ''; } };
}
const LINK_PATHS = ['nuevo', 'gasto', 'ingreso', 'transferencia', 'add', 'new', 'rapido', 'quick', 'plantilla', 'template', 'abrir', 'open', 'importar'];
// mision://importar?d=<JSON en base64url>: añade cuentas, activos y recurrentes sin tocar lo que ya hay.
// Sirve para cargar datos personales sin meterlos en el código (el repositorio es público).
// Cuentas: se emparejan por nombre (si existe, no se toca su saldo). Activos: por símbolo dentro de su cuenta.
function importPatch(d) {
  const json = new TextDecoder().decode(Uint8Array.from(atob(d.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(d.length / 4) * 4, '=')), c => c.charCodeAt(0)));
  const P = JSON.parse(json); let na = 0, ns = 0, nr = 0;
  const accByName = n => S.accounts.find(a => norm(a.name) === norm(n));
  for (const a of P.accounts || []) {
    if (accByName(a.name)) continue;
    S.accounts.push(Object.assign({ id: 'a_' + uid(), currency: 'EUR', initial: 0, color: PALETTE[S.accounts.length % PALETTE.length], icon: ACC_ICONS[a.type] || ACC_ICONS.otro, includeInTotal: true, archived: false, order: S.accounts.length, cardAlias: '', note: '' }, a)); na++;
  }
  for (const x of P.assets || []) {
    const acc = accByName(x.account); if (!acc) continue;
    if (S.assets.some(a => a.accountId === acc.id && a.symbol === x.symbol)) continue;
    const a = Object.assign({ id: 's_' + uid(), provider: 'auto', quoteCcy: 'EUR', archived: false, color: PALETTE[(S.assets.length + 3) % PALETTE.length] }, x, { accountId: acc.id });
    delete a.account; a.ops = (x.ops || []).map(o => Object.assign({ id: uid(), fee: 0, ccy: 'EUR', date: today() }, o));
    S.assets.push(a); ns++;
  }
  for (const r of P.recurring || []) {
    const acc = accByName(r.account), asset = r.asset && S.assets.find(a => a.symbol === r.asset);
    if (!acc || S.recurring.some(x => x.name === r.name)) continue;
    const tpl = Object.assign({ tags: [] }, r.tpl, { accountId: acc.id }, asset ? { assetId: asset.id } : {});
    S.recurring.push({ id: 'r_' + uid(), name: r.name, tpl, freq: r.freq, interval: r.interval || 1, day: r.day, next: r.next, end: '', active: true }); nr++;
  }
  S.demo = false; saveNow(); go('home', { reset: true }); if (typeof restartFeeds === 'function') restartFeeds();
  toast(na + ns + nr ? `Importado: ${na} cuenta${na === 1 ? '' : 's'}, ${ns} activo${ns === 1 ? '' : 's'}${nr ? `, ${nr} recurrente${nr === 1 ? '' : 's'}` : ''}` : 'Ya lo tenías todo, no se ha cambiado nada');
}
const isAppLink = raw => LINK_PATHS.includes(parseLink(raw).path.split('/')[0]);
function handleLink(raw) {
  if (!S || !raw) return false;
  const L = parseLink(raw); const p = L.path.split('/')[0];
  if (!LINK_PATHS.includes(p)) return false;
  // evita apuntar dos veces el mismo enlace (iOS a veces lo entrega doble al arrancar)
  try { const last = JSON.parse(localStorage.getItem('mision.lastLink') || 'null'); if (last && last.u === raw && Date.now() - last.t < 90000) return true; localStorage.setItem('mision.lastLink', JSON.stringify({ u: raw, t: Date.now() })); } catch (e) { }
  if (p === 'importar') {
    try { importPatch(L.q.get('d') || ''); } catch (e) { console.warn(e); toast('El enlace de importación no es válido'); }
    return true;
  }
  if (p === 'abrir' || p === 'open') {
    const scr = norm(L.get('pantalla', 'screen') || L.path.split('/')[1] || 'resumen');
    const map = { resumen: 'home', inicio: 'home', movimientos: 'txs', inversiones: 'inv', cartera: 'inv', analisis: 'stats', mas: 'more', presupuestos: 'more/budgets', objetivos: 'more/goals', cuentas: 'more/accounts', divisas: 'more/fx' };
    go(map[scr] || 'home', { reset: true }); return true;
  }
  if (p === 'plantilla' || p === 'template') {
    const name = norm(L.get('nombre', 'name', 'id')); const t = (S.templates || []).find(x => norm(x.name) === name || x.id === name) || (S.templates || []).find(x => norm(x.name).includes(name));
    if (!t) { toast('No encuentro la plantilla «' + L.get('nombre', 'name') + '»'); go('more/templates', { reset: true }); return true; }
    const amt = Math.abs(parseMoney(L.get('importe', 'amount')));
    useTemplate(t, amt > 0 ? amt : null); return true;
  }
  let pre;
  if (p === 'rapido' || p === 'quick') {
    const r = parseQuick(L.get('texto', 'text', 't')); if (!r) { go('home', { reset: true }); openTxForm(); return true; }
    pre = { type: r.type, amount: r.amount || '', note: r.note, accountId: r.accountId, categoryId: r.categoryId, date: r.date || today() };
  } else {
    const typeMap = { gasto: 'expense', ingreso: 'income', transferencia: 'transfer', expense: 'expense', income: 'income', transfer: 'transfer' };
    const type = typeMap[norm(L.get('tipo', 'type'))] || typeMap[p] || 'expense';
    const note = L.get('concepto', 'comercio', 'merchant', 'nota', 'note', 'nombre');
    const acc = matchAccount(L.get('cuenta', 'account')) || matchAccount(L.get('tarjeta', 'card', 'pase'), true);
    const catName = L.get('categoria', 'category');
    const cat = (catName && findCat(catName, type === 'income' ? 'income' : 'expense')) || prevCatFor(note, type) || guessCat(note, type === 'income' ? 'income' : 'expense');
    const fr = norm(L.get('fecha', 'date'));
    const date = !fr || fr === 'hoy' ? today() : fr === 'ayer' ? addDays(today(), -1) : (parseDateAny(L.get('fecha', 'date')) || today());
    pre = { type, amount: Math.abs(parseMoney(L.get('importe', 'amount', 'cantidad'))) || '', note: note ? cap(note) : '', accountId: acc ? acc.id : '', categoryId: cat ? cat.id : '', date, tags: L.get('etiquetas', 'tags').split(',').map(x => x.trim()).filter(Boolean) };
    if (type === 'transfer') { const to = matchAccount(L.get('destino', 'to', 'hacia')); if (to) pre.toAccountId = to.id; }
    if (!pre.accountId && (L.get('tarjeta', 'card') || L.get('cuenta', 'account'))) pre.unknownCard = L.get('tarjeta', 'card') || L.get('cuenta', 'account');
  }
  pre.src = 'atajo';
  const confirmQ = L.get('confirmar', 'confirm', 'revisar');
  const confirmIt = /^(1|si|sí|true|yes)$/i.test(confirmQ) || (!/^(0|no|false)$/i.test(confirmQ) && S.settings.shortcutMode === 'confirm') || !(pre.amount > 0) || pre.type === 'transfer' && !pre.toAccountId;
  go('home', { reset: true });
  if (confirmIt || !activeAccounts().length) { openTxForm(null, pre); if (pre.unknownCard) toast(`No sé qué cuenta es «${pre.unknownCard}». Asígnalo en la cuenta (campo «Nombre de la tarjeta»).`); return true; }
  const acc = accById(pre.accountId) || accById(S.lastAcc) || activeAccounts()[0];
  const o = { id: uid(), type: pre.type, amount: Math.round(pre.amount * 100) / 100, accountId: acc.id, date: pre.date, note: pre.note, tags: pre.tags || [], src: 'atajo' };
  if (o.type === 'transfer') { o.toAccountId = pre.toAccountId; const B = accById(o.toAccountId); o.toAmount = B.currency === acc.currency ? o.amount : Math.round(conv(o.amount, acc.currency, B.currency) * 100) / 100; }
  else o.categoryId = pre.categoryId || otherCat(o.type).id;
  S.txs.push(o); save(); render(); haptic();
  const c = catById(o.categoryId);
  toast(`${o.type === 'income' ? 'Ingreso' : 'Gasto'} apuntado: ${fmt(o.amount, acc.currency)}${o.note ? ' · ' + o.note : ''}${c ? ' · ' + c.name : ''}${pre.unknownCard ? ` (tarjeta «${pre.unknownCard}» sin asignar: ${acc.name})` : ''}`, { label: 'Editar', fn: () => openTxForm(S.txs.find(x => x.id === o.id)) });
  if (o.type === 'expense') budgetAlert(o);
  return true;
}
function initLinks() {
  const h = decodeURIComponent(location.hash || '');
  if (h.length > 1 && isAppLink(h)) { handleLink(h); try { history.replaceState(null, '', location.pathname + location.search); } catch (e) { } }
  window.addEventListener('hashchange', () => { const x = decodeURIComponent(location.hash || ''); if (isAppLink(x)) { handleLink(x); try { history.replaceState(null, '', location.pathname + location.search); } catch (e) { } } });
  const App = NATIVE && window.Capacitor.Plugins && window.Capacitor.Plugins.App;
  if (App) {
    App.addListener('appUrlOpen', e => { if (!unlocked()) { pendingLink = e.url; return; } handleLink(e.url); });
    App.getLaunchUrl().then(r => { if (r && r.url) { if (!unlocked()) pendingLink = r.url; else handleLink(r.url); } }).catch(() => { });
  }
}
let pendingLink = null;

/* ---------- avisos de presupuesto ---------- */
function budgetAlert(o) {
  if (!S.settings.budgetAlerts || o.excl) return;
  const mk = mkOf(o.date); const R = FR(mk); const acc = accById(o.accountId);
  const msgs = [];
  const check = (name, avail, spent, add) => { if (!(avail > 0)) return; const before = (spent - add) / avail, after = spent / avail; if (before < 1 && after >= 1) msgs.push(`Has superado el presupuesto de ${name} (${fmt(spent)} de ${fmt(avail, null, { dec: 0 })})`); else if (before < 0.8 && after >= 0.8) msgs.push(`Llevas el ${Math.round(after * 100)} % del presupuesto de ${name}`); };
  const ids = new Set(); for (const p of txParts(o)) { ids.add(p.categoryId); ids.add(parentOf(p.categoryId)); }
  for (const id of ids) { const c = catById(id); if (!c || !(c.budget > 0)) continue; const add = sum(txParts(o).filter(p => p.categoryId === id || parentOf(p.categoryId) === id), p => conv(p.amount, acc.currency)); check(c.name, budgetAvail(c, mk), catSpend(c.id, R.from, R.to), add); }
  if (S.settings.budgetTotal > 0) check('todo el periodo', S.settings.budgetTotal, flows(R.from, R.to).exp, conv(o.amount, acc.currency));
  if (msgs.length) setTimeout(() => { toast(msgs[0]); haptic(true); }, 2800);
}
function haptic(strong) { try { const H = NATIVE && window.Capacitor.Plugins.Haptics; if (H) strong ? H.notification({ type: 'WARNING' }) : H.impact({ style: 'LIGHT' }); } catch (e) { } }

/* ---------- plantillas ---------- */
function useTemplate(t, amountOverride) {
  const amount = amountOverride || t.tpl.amount;
  if (!(amount > 0) || (t.tpl.type === 'transfer' && !t.tpl.toAccountId) || !accById(t.tpl.accountId)) { openTxForm(null, Object.assign({}, t.tpl, { amount: amount || '', date: today(), src: 'plantilla' })); return; }
  const acc = accById(t.tpl.accountId);
  const o = Object.assign({}, t.tpl, { id: uid(), amount, date: today(), tags: [...(t.tpl.tags || [])] });
  if (o.type === 'transfer') { const B = accById(o.toAccountId); o.toAmount = B && B.currency !== acc.currency ? Math.round(conv(amount, acc.currency, B.currency) * 100) / 100 : amount; delete o.categoryId; }
  else { delete o.toAccountId; if (!catById(o.categoryId)) o.categoryId = otherCat(o.type).id; }
  S.txs.push(o); save(); render(); haptic();
  toast(`${t.name}: ${fmt(amount, acc.currency)} apuntado`, { label: 'Deshacer', fn: () => { S.txs = S.txs.filter(x => x.id !== o.id); save(); render(); toast('Deshecho'); } });
  if (o.type === 'expense') budgetAlert(o);
}
function openTplForm(t) {
  const isEdit = !!t; const accs = activeAccounts(); if (!accs.length) { toast('Primero crea una cuenta'); return openAccountForm(); }
  const x = t ? JSON.parse(JSON.stringify(t)) : { name: '', icon: '', tpl: { type: 'expense', amount: '', accountId: S.lastAcc && accById(S.lastAcc) ? S.lastAcc : accs[0].id, categoryId: '', note: '', tags: [] } };
  let type = x.tpl.type, icon = x.icon || '';
  const catOpts = () => catTree(type === 'income' ? 'income' : 'expense').map(c => `<option value="${c.id}" ${c.id === x.tpl.categoryId ? 'selected' : ''}>${c.parentId ? '· ' : ''}${esc(c.icon)} ${esc(c.name)}</option>`).join('');
  openSheet({
    title: isEdit ? 'Editar plantilla' : 'Nueva plantilla', html: `<form class="form" id="f" autocomplete="off">
    <div class="seg" id="pType">${['expense', 'income', 'transfer'].map(k => `<button type="button" data-k="${k}" aria-pressed="${type === k}">${TYPE_L[k]}</button>`).join('')}</div>
    <label class="field"><span>Nombre del botón</span><input type="text" id="pName" value="${esc(x.name)}" placeholder="Ej.: Café, Menú del día, Gasolina" maxlength="24"></label>
    <div class="row2"><label class="field"><span>Importe (vacío = preguntar)</span><input type="text" inputmode="decimal" id="pAmt" value="${x.tpl.amount ? inputNum(x.tpl.amount) : ''}" placeholder="Preguntar"></label><label class="field"><span id="pAccL">Cuenta</span>${accSelect('pAcc', x.tpl.accountId)}</label></div>
    <label class="field" id="pToW"><span>Hacia la cuenta</span>${accSelect('pTo', x.tpl.toAccountId || '', { none: 'Elige cuenta…' })}</label>
    <label class="field" id="pCatW"><span>Categoría</span><div class="sel"><select id="pCat">${catOpts()}</select></div></label>
    <label class="field"><span>Concepto</span><input type="text" id="pNote" value="${esc(x.tpl.note || '')}"></label>
    <label class="field"><span>Etiquetas</span><input type="text" id="pTags" value="${esc((x.tpl.tags || []).join(', '))}"></label>
    ${emojiHtml(icon || '⭐', 'cat')}
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">${isEdit ? 'Guardar' : 'Crear plantilla'}</button>${isEdit ? deleteBtn('tpl-del', t.id) : ''}
    <p class="note">Con Atajos o el botón de acción del iPhone: <code>mision://plantilla?nombre=${esc(encodeURIComponent(x.name || 'Café'))}</code></p></form>`,
    onMount(root) {
      bindEmoji(root, e => icon = e);
      const s = () => { $('#pToW').hidden = type !== 'transfer'; $('#pCatW').hidden = type === 'transfer'; $('#pAccL').textContent = type === 'transfer' ? 'Desde' : 'Cuenta'; };
      $('#pType').addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; type = b.dataset.k; $$('#pType button').forEach(z => z.setAttribute('aria-pressed', String(z.dataset.k === type))); $('#pCat').innerHTML = catOpts(); s(); });
      s(); if (!isEdit) $('#pName').focus();
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const name = $('#pName').value.trim(); if (!name) return ferr('Ponle nombre al botón.');
        const amt = Math.abs(parseMoney($('#pAmt').value));
        const tpl = { type, amount: amt > 0 ? Math.round(amt * 100) / 100 : 0, accountId: $('#pAcc').value, note: $('#pNote').value.trim() || name, tags: $('#pTags').value.split(',').map(z => z.trim()).filter(Boolean) };
        if (type === 'transfer') { tpl.toAccountId = $('#pTo').value; if (!tpl.toAccountId || tpl.toAccountId === tpl.accountId) return ferr('Elige una cuenta de destino distinta.'); } else tpl.categoryId = $('#pCat').value;
        const o = { name, icon: icon || (catById(tpl.categoryId) || {}).icon || '⭐', tpl };
        if (isEdit) Object.assign(t, o); else S.templates.push(Object.assign({ id: 't_' + uid() }, o));
        save(); closeSheet(); render(); toast(isEdit ? 'Plantilla guardada' : 'Plantilla creada');
      });
    }
  });
}

/* ---------- seguimiento de mercados ---------- */
function addWatch(kind, r) {
  const sym = String(r.symbol || '').toUpperCase(); if (!sym) return;
  if (S.assets.some(a => a.kind === kind && a.symbol === sym && a.watch && !a.archived)) { toast(sym + ' ya está en seguimiento'); closeSheet(); return; }
  S.assets.push({ id: 's_' + uid(), kind, symbol: sym, name: r.name || sym, cgId: kind === 'crypto' ? (r.cgId || CG_IDS[sym] || '') : '', provider: r.provider && r.provider !== 'manual' ? 'auto' : (r.provider || 'auto'), quoteCcy: kind === 'crypto' ? 'USD' : (r.quoteCcy || 'USD'), accountId: '', archived: false, watch: true, ops: [] });
  save(); closeSheet(); if (UI.route !== 'inv') go('inv', { reset: true }); else render(); restartFeeds(); toast(sym + ' en seguimiento');
}

/* ---------- gráficos históricos ---------- */
function histHtml(a, pts) {
  if (!pts || pts.length < 2) return '<div class="empty small">Sin datos para este rango.</div>';
  const ccy = a.kind === 'crypto' ? 'USD' : (a.quoteCcy || 'USD');
  const rg = UI.histRange; const intraday = rg === '1D' || rg === '1S';
  const lab = t => { const d = new Date(t); return rg === '1D' ? `${pad(d.getHours())}:${pad(d.getMinutes())}` : rg === '1S' ? `${WEEKDAYS[d.getDay()].slice(0, 3)} ${pad(d.getHours())}h` : `${d.getDate()} ${MONTHS_S[d.getMonth()]}${rg === '5A' || rg === '1A' ? ' ' + String(d.getFullYear()).slice(2) : ''}`; };
  const series = pts.map(([t, v]) => ({ label: lab(t), v, t }));
  const first = series[0].v, last = series[series.length - 1].v; const ch = (last - first) / first * 100;
  UI._hist = { series, ccy, intraday };
  return `<div class="hstack" style="padding:0 6px 6px"><span class="num" id="histVal">${fmtPrice(last, ccy)}</span><span class="spacer"></span><span class="chip ${pcls(ch)}" id="histCh">${fmtPct(ch)} en ${rg}</span></div>${lineChart(series, { scrub: true, aria: 'Precio histórico', cls: ch < 0 ? 'down' : '' })}`;
}
function bindScrub() {
  const svgEl = $('#histBox svg.scrubbable'); if (!svgEl || svgEl._b) return; svgEl._b = 1;
  const pts = JSON.parse(svgEl.dataset.pts || '[]'); const H = UI._hist; if (!pts.length || !H) return;
  const l = svgEl.querySelector('.scrub-l'), c = svgEl.querySelector('.scrub-c');
  const move = e => {
    const r = svgEl.getBoundingClientRect(); const x = (e.clientX - r.left) / r.width * 340;
    let i = 0, best = 1e9; pts.forEach((p, k) => { const d = Math.abs(p[0] - x); if (d < best) { best = d; i = k; } });
    const [px, py] = pts[i]; l.setAttribute('x1', px); l.setAttribute('x2', px); l.setAttribute('visibility', 'visible'); c.setAttribute('cx', px); c.setAttribute('cy', py); c.setAttribute('visibility', 'visible');
    const s = H.series[i]; const first = H.series[0].v;
    $('#histVal').textContent = `${fmtPrice(s.v, H.ccy)} · ${s.label}`; $('#histCh').textContent = fmtPct((s.v - first) / first * 100);
    UI.scrubbing = true;
  };
  const end = () => { l.setAttribute('visibility', 'hidden'); c.setAttribute('visibility', 'hidden'); const s = H.series[H.series.length - 1], f = H.series[0].v; $('#histVal').textContent = fmtPrice(s.v, H.ccy); $('#histCh').textContent = `${fmtPct((s.v - f) / f * 100)} en ${UI.histRange}`; UI.scrubbing = false; };
  svgEl.addEventListener('pointerdown', e => { move(e); try { svgEl.setPointerCapture(e.pointerId); } catch (x) { } });
  svgEl.addEventListener('pointermove', e => { if (e.pointerType === 'mouse' || e.buttons) move(e); });
  svgEl.addEventListener('pointerup', end); svgEl.addEventListener('pointerleave', end); svgEl.addEventListener('pointercancel', end);
}

/* ---------- evolución de una categoría ---------- */
function openCatStats(id) {
  const c = catById(id); if (!c) return;
  const mk = UI.statsMode === 'year' ? curMk() : UI.statsMonth;
  const data = []; for (let i = 11; i >= 0; i--) { const m = addMonths(mk, -i); const R = FR(m); data.push({ label: finShort(m), v: catSpend(id, R.from, R.to), mk: m }); }
  const past = data.slice(0, -1).filter(d => d.v > 0); const avg = past.length ? sum(past, d => d.v) / past.length : 0;
  const R = FR(mk); const cur = data[data.length - 1].v;
  const kids = S.categories.filter(k => k.parentId === id).map(k => ({ k, v: catSpend(k.id, R.from, R.to) })).filter(x => x.v > 0);
  const own = cur - sum(kids, x => x.v);
  const notes = {}; for (const t of S.txs) { if (t.type !== 'expense' || t.date < R.from || t.date > R.to) continue; const a = accById(t.accountId); if (!a) continue; for (const p of txParts(t)) if (catIdsOf(id).has(p.categoryId)) { const k = (t.note || '(sin concepto)').trim(); notes[k] = (notes[k] || 0) + conv(p.amount, a.currency); } }
  const top = Object.entries(notes).sort((a, b) => b[1] - a[1]).slice(0, 5);
  openSheet({
    title: `${c.icon} ${c.name}`, html: `<div class="stack">
    <div class="kpis"><div class="kpi"><div class="k-l">${finLabel(mk)}</div><div class="k-v amt">${fmt(cur)}</div><div class="k-s">${avg ? `<span class="${cur > avg ? 'neg' : 'pos'}">${fmtPct((cur - avg) / avg * 100)}</span> vs tu media` : '&nbsp;'}</div></div>
    <div class="kpi"><div class="k-l">Media mensual</div><div class="k-v amt">${fmt(avg)}</div><div class="k-s">${c.budget ? `Presupuesto <span class="amt">${fmt(c.budget, null, { dec: 0 })}</span>` : '<span class="amt">' + fmt(avg * 12, null, { dec: 0 }) + '</span> al año'}</div></div></div>
    <div class="card">${bars1(data, { color: c.color, avg: avg || null, aria: 'Gasto por periodo en ' + c.name })}</div><p class="note" style="margin:0">La línea discontinua es tu media.</p>
    ${kids.length ? `<div class="sec-h"><h2>Subcategorías</h2></div><div class="list">${kids.map(x => `<div class="row">${ico(esc(x.k.icon), x.k.color, 'sm')}<span class="row-m row-t">${esc(x.k.name)}</span><span class="num amt">${fmt(x.v)}</span></div>`).join('')}${own > 0.004 ? `<div class="row">${ico(esc(c.icon), c.color, 'sm')}<span class="row-m row-t">Sin subcategoría</span><span class="num amt">${fmt(own)}</span></div>` : ''}</div>` : ''}
    ${top.length ? `<div class="sec-h"><h2>Dónde</h2></div><div class="list">${top.map(([n, v]) => `<div class="row"><span class="row-m row-t">${esc(n)}</span><span class="num amt">${fmt(v)}</span></div>`).join('')}</div>` : ''}
    <button class="btn block" data-action="cat-txs" data-id="${id}" data-month="${mk}">Ver movimientos</button></div>`
  });
}

/* ---------- apariencia ---------- */
function hexRgb(h) { const m = String(h).replace('#', '').match(/^([0-9a-f]{6})$/i); if (!m) return [228, 179, 203]; const n = parseInt(m[1], 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; }
const rgba = (h, a) => { const [r, g, b] = hexRgb(h); return `rgba(${r},${g},${b},${a})`; };
const lum = h => { const [r, g, b] = hexRgb(h).map(v => { v /= 255; return v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); }); return .2126 * r + .7152 * g + .0722 * b; };
const mixHex = (h, k, t) => { const a = hexRgb(h), b = hexRgb(k); return '#' + a.map((v, i) => Math.round(v + (b[i] - v) * t).toString(16).padStart(2, '0')).join(''); };
function applyLook() {
  const st = S.settings;
  let dark, light;
  if (st.accent === 'custom') { dark = st.customAccent || '#e4b3cb'; light = lum(dark) > .35 ? mixHex(dark, '#1c1620', .45) : dark; if (lum(dark) < .12) dark = mixHex(dark, '#ffffff', .45); }
  else { const a = ACCENTS[st.accent] || ACCENTS.malva; dark = a[1]; light = a[2]; }
  const ink = h => lum(h) > .4 ? '#140d12' : '#ffffff';
  const z = { s: .92, m: 1, l: 1.1, xl: 1.22 }[st.textSize] || 1;
  document.documentElement.classList.toggle('glass', st.glass !== false);
  let el = $('#lookCss'); if (!el) { el = document.createElement('style'); el.id = 'lookCss'; document.head.appendChild(el); }
  el.textContent = `:root{--accent:${dark};--accent-soft:${rgba(dark, .14)};--accent-ink:${ink(dark)};--z:${z}}
@media (prefers-color-scheme: light){:root:not([data-theme="dark"]):not([data-theme="black"]){--accent:${light};--accent-soft:${rgba(light, .10)};--accent-ink:${ink(light)}}}
:root[data-theme="light"]{--accent:${light};--accent-soft:${rgba(light, .10)};--accent-ink:${ink(light)}}`;
}
applyTheme = function () {
  const th = S.settings.theme;
  if (th === 'auto') document.documentElement.removeAttribute('data-theme'); else document.documentElement.setAttribute('data-theme', th);
  applyLook();
  requestAnimationFrame(() => { const bg = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim(); const m = $('meta[name="theme-color"]'); if (m && bg) m.setAttribute('content', bg); try { const SB = NATIVE && window.Capacitor.Plugins.StatusBar; if (SB) SB.setStyle({ style: lum(bg.startsWith('#') ? bg : '#000000') > .4 ? 'LIGHT' : 'DARK' }); } catch (e) { } });
};

/* ---------- bloqueo con PIN ---------- */
let LOCK = { on: false, mode: 'unlock', buf: '', first: '', hiddenAt: 0 };
const unlocked = () => !LOCK.on;
async function hashPin(pin) {
  const data = new TextEncoder().encode('mision:' + pin);
  try { const h = await crypto.subtle.digest('SHA-256', data); return Array.from(new Uint8Array(h)).map(b => b.toString(16).padStart(2, '0')).join(''); }
  catch (e) { let h = 5381; for (const b of data) h = ((h << 5) + h + b) >>> 0; return 'd' + h.toString(16); }
}
function lockUI() {
  let el = $('#lock');
  if (!el) {
    el = document.createElement('div'); el.id = 'lock'; el.setAttribute('role', 'dialog'); el.setAttribute('aria-modal', 'true');
    el.innerHTML = `<div class="lock-in"><div class="lock-mark" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i></div><h2 id="lockT"></h2><div class="pin-dots" id="lockDots"></div><div class="err" id="lockErr"></div>
      <div class="keypad">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => `<button type="button" data-k="${n}">${n}</button>`).join('')}<button type="button" data-k="x" id="lockCancel">Cancelar</button><button type="button" data-k="0">0</button><button type="button" data-k="del" aria-label="Borrar">⌫</button></div></div>`;
    document.body.appendChild(el);
    el.addEventListener('click', e => { const b = e.target.closest('[data-k]'); if (b) pinKey(b.dataset.k); });
    document.addEventListener('keydown', e => { if (!LOCK.on) return; if (/^\d$/.test(e.key)) pinKey(e.key); else if (e.key === 'Backspace') pinKey('del'); else if (e.key === 'Escape' && LOCK.mode !== 'unlock') pinKey('x'); });
  }
  $('#lockT').textContent = LOCK.mode === 'unlock' ? 'Introduce tu PIN' : LOCK.mode === 'set1' ? 'Elige un PIN de 4 dígitos' : 'Repite el PIN';
  $('#lockDots').innerHTML = [0, 1, 2, 3].map(i => `<i class="${i < LOCK.buf.length ? 'on' : ''}"></i>`).join('');
  $('#lockCancel').style.visibility = LOCK.mode === 'unlock' ? 'hidden' : 'visible';
  el.hidden = !LOCK.on; document.documentElement.classList.toggle('locked', LOCK.on);
}
function lockNow() { if (!S.settings.pinHash) return; LOCK = Object.assign(LOCK, { on: true, mode: 'unlock', buf: '' }); closeSheet(); lockUI(); }
function startSetPin() { LOCK = Object.assign(LOCK, { on: true, mode: 'set1', buf: '', first: '' }); lockUI(); $('#lockErr').textContent = ''; }
async function pinKey(k) {
  const err = $('#lockErr');
  if (k === 'x') { LOCK.on = false; lockUI(); return; }
  if (k === 'del') { LOCK.buf = LOCK.buf.slice(0, -1); lockUI(); return; }
  if (LOCK.buf.length >= 4) return;
  LOCK.buf += k; lockUI(); if (LOCK.buf.length < 4) return;
  const pin = LOCK.buf;
  if (LOCK.mode === 'unlock') {
    if (await hashPin(pin) === S.settings.pinHash) { LOCK.on = false; LOCK.buf = ''; lockUI(); err.textContent = ''; if (pendingLink) { const u = pendingLink; pendingLink = null; handleLink(u); } }
    else { err.textContent = 'PIN incorrecto'; haptic(true); setTimeout(() => { LOCK.buf = ''; lockUI(); }, 350); }
  } else if (LOCK.mode === 'set1') { LOCK.first = pin; LOCK.mode = 'set2'; LOCK.buf = ''; err.textContent = ''; lockUI(); }
  else { if (pin === LOCK.first) { S.settings.pinHash = await hashPin(pin); save(); LOCK.on = false; LOCK.buf = ''; lockUI(); toast('PIN activado'); render(); } else { err.textContent = 'No coinciden. Empieza otra vez.'; LOCK.mode = 'set1'; LOCK.buf = ''; setTimeout(lockUI, 350); } }
}
document.addEventListener('visibilitychange', () => {
  if (!S || !S.settings.pinHash) return;
  if (document.hidden) LOCK.hiddenAt = Date.now();
  else if (!LOCK.on && Date.now() - (LOCK.hiddenAt || Date.now()) >= (S.settings.lockAfter || 0) * 60000) lockNow();
});

/* ---------- avisos locales (solo app de iPhone) ---------- */
async function scheduleNotifs(force) {
  const LN = NATIVE && window.Capacitor.Plugins && window.Capacitor.Plugins.LocalNotifications; if (!LN) return;
  try {
    const pend = await LN.getPending(); const mine = (pend.notifications || []).filter(n => n.id >= 1000 && n.id < 2000);
    if (mine.length) await LN.cancel({ notifications: mine.map(n => ({ id: n.id })) });
    if (!S.settings.notifyRecurring || !S.recurring.some(r => r.active)) return;
    let perm = await LN.checkPermissions();
    if (perm.display !== 'granted') { if (perm.display === 'denied' && !force) return; perm = await LN.requestPermissions(); if (perm.display !== 'granted') { if (force) toast('Activa las notificaciones de Caudal en Ajustes del iPhone'); return; } }
    const out = []; const lim = addDays(today(), 60); let id = 1000;
    for (const r of S.recurring.filter(x => x.active)) {
      let d = r.next, g = 0;
      while (d && d <= lim && g++ < 12) {
        if (r.end && d > r.end) break;
        const at = parseYmd(addDays(d, -1)); at.setHours(S.settings.notifyHour || 9, 0, 0, 0);
        if (at > new Date()) { const acc = accById(r.tpl.accountId); out.push({ id: id++, title: r.tpl.type === 'income' ? 'Mañana entra dinero' : 'Mañana tienes un cargo', body: `${r.name || r.tpl.note || 'Recurrente'}: ${fmt(r.tpl.amount, acc ? acc.currency : null)}${acc ? ' · ' + acc.name : ''}`, schedule: { at } }); }
        d = nextDate(d, r.freq, r.interval || 1, r.day);
      }
    }
    out.sort((a, b) => a.schedule.at - b.schedule.at);
    if (out.length) await LN.schedule({ notifications: out.slice(0, 60) });
  } catch (e) { console.warn('avisos', e); }
}

/* ---------- Atajos de iPhone: pantalla de ayuda y generador ---------- */
VIEWS['more/shortcuts'] = () => {
  const st = S.settings; const scheme = NATIVE ? 'mision://' : `${location.origin}${location.pathname}#`;
  const cards = activeAccounts().filter(a => !['activo', 'deuda'].includes(a.type));
  return `<section class="card form"><b>Cuando llega un enlace de Atajos…</b>
    <div class="seg"><button data-action="sc-mode" data-k="auto" aria-pressed="${st.shortcutMode !== 'confirm'}">Guardar directo</button><button data-action="sc-mode" data-k="confirm" aria-pressed="${st.shortcutMode === 'confirm'}">Revisar antes</button></div>
    <p class="note" style="margin:0">Guardar directo: se apunta solo y sale un aviso con «Editar». Revisar: se abre el formulario ya rellenado. Si falta el importe, siempre se abre.</p></section>
  ${NATIVE ? '' : `<section class="card stack"><b>Importante</b><p class="note" style="margin:0">Los enlaces <code>mision://</code> solo funcionan con la app instalada. En la web puedes usar <code>${esc(scheme)}nuevo?…</code>, pero Safari y la web añadida a inicio no comparten datos.</p></section>`}
  <section class="card stack"><b>Apple Pay → se apunta solo al pagar</b><ol class="steps">
    <li>Abre <b>Atajos</b> → pestaña <b>Automatización</b> → <b>+</b> → <b>Transacción</b>.</li>
    <li>Marca tus tarjetas, deja todas las categorías, elige <b>Ejecutar inmediatamente</b> y desactiva «Notificar al ejecutar». Pulsa <b>Siguiente</b> → <b>Nueva automatización en blanco</b>.</li>
    <li>Añade la acción <b>Codificar URL</b> y pon dentro la variable <b>Comerciante</b> (en inglés, <i>Merchant</i>).</li>
    <li>Añade <b>Abrir URL</b> y escribe el enlace de abajo, sustituyendo cada <b>[…]</b> por la variable del mismo nombre (tócala en la barra de variables).</li>
    <li>Asigna el nombre de cada tarjeta a su cuenta (más abajo) para que el gasto vaya a la cuenta correcta.</li></ol>
    <div class="code-box"><code id="scApple">mision://nuevo?importe=[Importe]&amp;concepto=[URL codificada]&amp;tarjeta=[Tarjeta o pase]</code><button class="btn sm" data-action="sc-copy" data-src="scApple">Copiar</button></div>
    <p class="note" style="margin:0">La categoría se elige sola: primero la que usaste la última vez con ese comercio y, si no, por las palabras clave de tus categorías.</p></section>
  <section class="card stack"><b>Otros atajos útiles</b>
    <div class="kv" style="grid-template-columns:1fr"><div><b class="small">Dictar un gasto con Siri</b><p class="note" style="margin:2px 0 6px">Acción «Solicitar entrada» (texto) → «Codificar URL» → «Abrir URL»:</p><div class="code-box"><code id="scQuick">mision://rapido?texto=[URL codificada]</code><button class="btn sm" data-action="sc-copy" data-src="scQuick">Copiar</button></div><p class="note" style="margin:4px 0 0">Dile «12,50 mercadona», «3 café en efectivo ayer» o «+200 venta wallapop».</p></div>
    <div><b class="small">Botón de acción o widget con una plantilla</b><div class="code-box"><code id="scTpl">mision://plantilla?nombre=${esc(encodeURIComponent((S.templates[0] || { name: 'Café' }).name))}</code><button class="btn sm" data-action="sc-copy" data-src="scTpl">Copiar</button></div></div>
    <div><b class="small">Abrir una pantalla</b><div class="code-box"><code id="scOpen">mision://abrir?pantalla=inversiones</code><button class="btn sm" data-action="sc-copy" data-src="scOpen">Copiar</button></div><p class="note" style="margin:4px 0 0">resumen, movimientos, inversiones, analisis, presupuestos, objetivos, cuentas, divisas.</p></div></div></section>
  <section class="card form"><b>Generador de enlaces</b>
    <div class="row2"><label class="field"><span>Tipo</span><div class="sel"><select id="gType"><option value="gasto">Gasto</option><option value="ingreso">Ingreso</option><option value="transferencia">Transferencia</option></select></div></label><label class="field"><span>Importe</span><input type="text" id="gAmt" inputmode="decimal" placeholder="Vacío = preguntar"></label></div>
    <label class="field"><span>Concepto</span><input type="text" id="gNote" placeholder="Opcional"></label>
    <div class="row2"><label class="field"><span>Cuenta</span><div class="sel"><select id="gAcc"><option value="">La última usada</option>${activeAccounts().map(a => `<option value="${esc(a.name)}">${esc(a.name)}</option>`).join('')}</select></div></label><label class="field"><span>Categoría</span><div class="sel"><select id="gCat"><option value="">Automática</option>${[...catTree('expense'), ...catTree('income')].map(c => `<option value="${esc(c.name)}">${esc(c.icon)} ${esc(c.name)}</option>`).join('')}</select></div></label></div>
    <label class="field" id="gToW" hidden><span>Hacia la cuenta</span><div class="sel"><select id="gTo">${activeAccounts().map(a => `<option value="${esc(a.name)}">${esc(a.name)}</option>`).join('')}</select></div></label>
    <label class="check"><input type="checkbox" id="gConf"><span>Abrir para revisar antes de guardar</span></label>
    <div class="code-box"><code id="gOut"></code><button class="btn sm" data-action="sc-copy" data-src="gOut">Copiar</button></div>
    <button class="btn" data-action="sc-test">Probar este enlace aquí</button></section>
  <section><div class="sec-h"><h2>Nombre de cada tarjeta</h2></div>
    <div class="list">${cards.map(a => `<div class="row">${ico(esc(a.icon || ''), a.color, 'sm')}<div class="row-m"><div class="row-t">${esc(a.name)}</div></div><input class="inp" style="width:52%;min-height:40px" data-alias="${a.id}" value="${esc(a.cardAlias || '')}" placeholder="Nombre en Wallet" aria-label="Nombre de la tarjeta de ${esc(a.name)}"></div>`).join('') || '<div class="empty small">Crea tus cuentas primero.</div>'}</div>
    <p class="note">Escríbelo tal como aparece en la app Cartera (por ejemplo «Visa BBVA» o «Revolut»). Si tienes varias, sepáralas con comas.</p></section>
  <section><div class="sec-h"><h2>Todos los parámetros</h2></div><div class="tbl-wrap"><table><thead><tr><th>Parámetro</th><th>Qué hace</th></tr></thead><tbody>
    ${[['importe', '12,50 · 12.50 · -12,50 € (el signo da igual)'], ['concepto / comercio', 'Texto del movimiento'], ['tipo', 'gasto, ingreso o transferencia'], ['cuenta', 'Nombre de la cuenta'], ['tarjeta', 'Nombre de la tarjeta en Wallet'], ['destino', 'Cuenta de destino (transferencias)'], ['categoria', 'Nombre de la categoría'], ['fecha', 'hoy, ayer, 29/09/2026 o 2026-09-29'], ['etiquetas', 'viaje,trabajo'], ['confirmar', '1 para abrir el formulario, 0 para guardar directo'], ['texto', 'Solo en rapido: frase libre'], ['nombre', 'Solo en plantilla: nombre de la plantilla']].map(([a, b]) => `<tr><td><code>${a}</code></td><td style="white-space:normal">${b}</td></tr>`).join('')}
  </tbody></table></div></section>`;
};
function buildLink() {
  const p = new URLSearchParams(); const t = $('#gType').value;
  if (t !== 'gasto') p.set('tipo', t);
  const a = $('#gAmt').value.trim(); if (a) p.set('importe', a);
  const n = $('#gNote').value.trim(); if (n) p.set('concepto', n);
  const acc = $('#gAcc').value; if (acc) p.set('cuenta', acc);
  if (t === 'transferencia') p.set('destino', $('#gTo').value); else { const c = $('#gCat').value; if (c) p.set('categoria', c); }
  if ($('#gConf').checked) p.set('confirmar', '1');
  return 'mision://nuevo' + (p.toString() ? '?' + p.toString().replace(/\+/g, '%20') : '');
}
AFTER['more/shortcuts'] = () => {
  const upd = () => { $('#gToW').hidden = $('#gType').value !== 'transferencia'; $('#gOut').textContent = buildLink(); };
  ['#gType', '#gAmt', '#gNote', '#gAcc', '#gCat', '#gTo', '#gConf'].forEach(s => { $(s).addEventListener('input', upd); $(s).addEventListener('change', upd); }); upd();
  $$('[data-alias]').forEach(i => i.addEventListener('change', () => { const a = accById(i.dataset.alias); a.cardAlias = i.value.trim(); save(); toast('Guardado'); }));
};
VIEWS['more/install'] = () => `
  <section class="card stack"><b>App de iPhone</b><p class="note" style="margin:0">La app se compila con tu cuenta de desarrollador en GitHub (repositorio privado) y se instala por TestFlight. Los pasos están en el README del proyecto. Con la app funcionan las acciones de cualquier bolsa sin proxy, los avisos y los enlaces de Atajos.</p></section>
  <section class="card stack"><b>Mientras tanto, como web (Safari)</b><ol class="steps">
    <li>Abre la web en <b>Safari</b>.</li><li>Toca <b>Compartir</b> → <b>Añadir a pantalla de inicio</b> → <b>Añadir</b>.</li></ol>
    <p class="note" style="margin:0">Los datos de la web y los de la app son independientes salvo que actives la sincronización. Pásalos con Copia de seguridad.</p></section>`;

/* ---------- acciones nuevas ---------- */
Object.assign(ACT, {
  theme: el => { S.settings.theme = el.dataset.k; applyTheme(); save(); render(); },
  'toggle-theme': () => { const o = ['auto', 'dark', 'black', 'light']; S.settings.theme = o[(o.indexOf(S.settings.theme) + 1) % o.length]; applyTheme(); save(); chrome(); toast('Tema ' + { auto: 'automático', dark: 'oscuro', black: 'negro puro', light: 'claro' }[S.settings.theme]); if (UI.route === 'more/look') render(); },
  accent: el => { S.settings.accent = el.dataset.k; applyLook(); save(); render(); },
  textsize: el => { S.settings.textSize = el.dataset.k; applyLook(); save(); render(); },
  txview: el => { UI.txView = el.dataset.k; if (UI.txView === 'cal' && UI.txF.month === 'all') UI.txF.month = curMk(); render(); },
  calday: el => { UI.calDay = UI.calDay === el.dataset.d ? null : el.dataset.d; $('#txList').innerHTML = txBody(); },
  'txm-all': () => { UI.txF.month = UI.txF.month === 'all' ? curMk() : 'all'; render(); },
  statsmode: el => { UI.statsMode = el.dataset.k; if (UI.statsMode === 'year') UI.statsYear = Number(FR(UI.statsMonth).to.slice(0, 4)); render(); },
  stm: el => { if (UI.statsMode === 'year') UI.statsYear += +el.dataset.d; else UI.statsMonth = addMonths(UI.statsMonth, +el.dataset.d); render(); },
  'cat-open': el => { if (el.dataset.id) openCatStats(el.dataset.id); },
  'tag-txs': el => { UI.txF = { month: 'all', q: '#' + el.dataset.tag, type: 'all', acc: 'all', cat: 'all' }; go('txs', { reset: true }); },
  'cat-new': el => openCatForm(null, el.dataset.k, null, !!el.dataset.sub),
  'cat-move': el => {
    const c = catById(el.dataset.id); const sib = S.categories.filter(x => x.kind === c.kind && (x.parentId || '') === (c.parentId || ''));
    const i = sib.indexOf(c), j = i + +el.dataset.d; if (j < 0 || j >= sib.length) return;
    const a = S.categories.indexOf(sib[i]), b = S.categories.indexOf(sib[j]); [S.categories[a], S.categories[b]] = [S.categories[b], S.categories[a]]; save(); render();
  },
  'cat-del': el => {
    const c = catById(el.dataset.id); const same = S.categories.filter(x => x.kind === c.kind && x.id !== c.id); if (!same.length) { toast('Necesitas al menos una categoría de este tipo'); return; }
    const target = c.parentId && catById(c.parentId) ? catById(c.parentId) : (otherCat(c.kind).id === c.id ? same[0] : otherCat(c.kind));
    S.categories.forEach(x => { if (x.parentId === c.id) x.parentId = ''; });
    S.categories = S.categories.filter(x => x.id !== c.id);
    S.txs.forEach(t => { if (t.categoryId === c.id) t.categoryId = target.id; (t.splits || []).forEach(p => { if (p.categoryId === c.id) p.categoryId = target.id; }); });
    S.recurring.forEach(r => { if (r.tpl.categoryId === c.id) r.tpl.categoryId = target.id; });
    (S.templates || []).forEach(t => { if (t.tpl.categoryId === c.id) t.tpl.categoryId = target.id; });
    save(); closeSheet(); render(); toast(`Categoría eliminada (sus movimientos pasan a ${target.name})`);
  },
  'watch-new': el => openAssetNew(el.dataset.kind, true),
  'tpl-use': el => { const t = S.templates.find(x => x.id === el.dataset.id); if (t) useTemplate(t); },
  'tpl-new': () => openTplForm(),
  'tpl-edit': el => openTplForm(S.templates.find(x => x.id === el.dataset.id)),
  'tpl-del': el => { S.templates = S.templates.filter(x => x.id !== el.dataset.id); save(); closeSheet(); render(); toast('Plantilla eliminada'); },
  'tpl-move': el => { const a = S.templates; const i = a.findIndex(x => x.id === el.dataset.id), j = i + +el.dataset.d; if (j < 0 || j >= a.length) return; [a[i], a[j]] = [a[j], a[i]]; save(); render(); },
  'pin-set': () => startSetPin(),
  'pin-off': () => { S.settings.pinHash = ''; save(); render(); toast('PIN desactivado'); },
  'lock-now': () => lockNow(),
  'notif-test': async () => { const LN = NATIVE && window.Capacitor.Plugins.LocalNotifications; if (!LN) return; try { let p = await LN.checkPermissions(); if (p.display !== 'granted') p = await LN.requestPermissions(); if (p.display !== 'granted') { toast('Activa las notificaciones de Caudal en Ajustes del iPhone'); return; } await LN.schedule({ notifications: [{ id: 1999, title: 'Caudal', body: 'Así te avisaré de tus próximos cargos.', schedule: { at: new Date(Date.now() + 5000) } }] }); toast('Te llegará en 5 segundos (sal de la app para verla)'); } catch (e) { toast('No se pudo programar: ' + e.message); } },
  'sc-mode': el => { S.settings.shortcutMode = el.dataset.k; save(); render(); },
  'sc-copy': async el => { const txt = $('#' + el.dataset.src).textContent; try { await navigator.clipboard.writeText(txt); toast('Copiado'); } catch (e) { const r = document.createRange(); r.selectNodeContents($('#' + el.dataset.src)); const s = getSelection(); s.removeAllRanges(); s.addRange(r); toast('Seleccionado: cópialo'); } },
  'sc-test': () => { const u = buildLink(); try { localStorage.removeItem('mision.lastLink'); } catch (e) { } handleLink(u); },
});
