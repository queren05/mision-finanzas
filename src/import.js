/* =====================================================================
   Importar extractos del banco (CSV / Excel)
   ===================================================================== */
function parseCSV(text) {
  text = String(text).replace(/^﻿/, '');
  const sample = text.split(/\r?\n/).slice(0, 15).join('\n');
  let delim = ';', best = -1;
  for (const c of [';', ',', '\t', '|']) { const n = sample.split(c).length - 1; if (n > best) { best = n; delim = c; } }
  const rows = []; let row = [], cell = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) { if (ch === '"') { if (text[i + 1] === '"') { cell += '"'; i++; } else q = false; } else cell += ch; }
    else if (ch === '"') q = true;
    else if (ch === delim) { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') { if (ch === '\r' && text[i + 1] === '\n') i++; row.push(cell); rows.push(row); row = []; cell = ''; }
    else cell += ch;
  }
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  return rows.filter(r => r.some(c => String(c).trim() !== ''));
}
function parseDateAny(v) {
  if (v == null || v === '') return null;
  if (v instanceof Date && !isNaN(v)) return ymd(new Date(v.getTime() + 12 * 3600e3));
  const s = String(v).trim(); let m;
  const ok = (y, mo, d) => (mo >= 1 && mo <= 12 && d >= 1 && d <= 31 && y > 1970 && y < 2100) ? `${y}-${pad(mo)}-${pad(d)}` : null;
  if ((m = s.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})/))) return ok(+m[1], +m[2], +m[3]);
  if ((m = s.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})/))) { let y = +m[3]; if (y < 100) y += 2000; return ok(y, +m[2], +m[1]); }
  if (/^\d{5}(\.\d+)?$/.test(s)) { const d = new Date(Math.round((+s - 25569) * 864e5)); return ok(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate()); }
  return null;
}
function loadScript(src) {
  return new Promise((res, rej) => { const s = document.createElement('script'); s.src = src; s.onload = res; s.onerror = () => rej(new Error('No se pudo cargar el lector de Excel (¿sin conexión?)')); document.head.appendChild(s); });
}
async function readSheetFile(file) {
  const name = file.name.toLowerCase();
  if (/\.(xlsx|xls|ods)$/.test(name)) {
    if (!window.XLSX) await loadScript('https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js');
    const wb = XLSX.read(await file.arrayBuffer(), { type: 'array', cellDates: true });
    const ws = wb.Sheets[wb.SheetNames[0]];
    return XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, defval: '' }).filter(r => r.some(c => String(c).trim() !== ''));
  }
  let text = await file.text();
  if (text.includes('�')) { try { text = new TextDecoder('windows-1252').decode(await file.arrayBuffer()); } catch (e) { } }
  return parseCSV(text);
}
function guessImport(rows) {
  let hdr = 0;
  for (let i = 0; i < Math.min(25, rows.length); i++) {
    const r = rows[i].map(c => String(c).toLowerCase());
    if (r.filter(c => c.trim()).length >= 3 && r.some(c => /fecha|date|f\.\s?valor|f\.\s?oper/.test(c))) { hdr = i; break; }
  }
  const h = (rows[hdr] || []).map(c => String(c).toLowerCase().trim());
  const find = re => h.findIndex(c => re.test(c));
  let date = find(/fecha.*oper|f\.?\s?oper|^fecha$|date|fecha/);
  let desc = find(/concepto|descrip|detalle|movimiento|description|comercio|beneficiario|referencia/);
  let amount = find(/importe|amount|cantidad|valor(?!.*fecha)/);
  const debit = find(/cargo|debe|gasto|debit|salida/), credit = find(/abono|haber|ingreso|credit|entrada/);
  if (date < 0) date = 0; if (desc < 0) desc = Math.min(1, h.length - 1);
  const mode = amount < 0 && debit >= 0 && credit >= 0 ? 'split' : 'single';
  if (amount < 0) amount = Math.min(2, h.length - 1);
  return { hdr, date, desc, amount, debit: Math.max(0, debit), credit: Math.max(0, credit), mode };
}
function importItems() {
  const im = UI.imp; if (!im) return [];
  const acc = accById(im.acc); if (!acc) return [];
  const existing = new Set();
  for (const t of S.txs) {
    if (t.accountId !== acc.id || (t.type !== 'expense' && t.type !== 'income')) continue;
    const sgn = t.type === 'income' ? t.amount : -t.amount;
    existing.add(`${t.date}|${sgn.toFixed(2)}`);
  }
  const rules = S.categories.map(c => ({ c, kws: String(c.keywords || '').toLowerCase().split(',').map(s => s.trim()).filter(Boolean) })).filter(r => r.kws.length);
  const out = [];
  for (let i = im.hdr + 1; i < im.rows.length; i++) {
    const r = im.rows[i]; const date = parseDateAny(r[im.date]);
    let a = im.mode === 'split' ? (Math.abs(parseMoney(r[im.credit])) || 0) - (Math.abs(parseMoney(r[im.debit])) || 0) : parseMoney(r[im.amount]);
    if (im.invert) a = -a;
    const desc = String(r[im.desc] ?? '').replace(/\s+/g, ' ').trim();
    if (!date || !isFinite(a) || Math.abs(a) < 0.005) { out.push({ bad: true, row: i + 1 }); continue; }
    const kind = a > 0 ? 'income' : 'expense'; const low = desc.toLowerCase();
    const hit = rules.find(x => x.c.kind === kind && x.kws.some(k => low.includes(k)));
    const dup = existing.has(`${date}|${a.toFixed(2)}`);
    out.push({ date, amount: Math.round(Math.abs(a) * 100) / 100, kind, desc, cat: hit ? hit.c : otherCat(kind), dup });
  }
  return out;
}
VIEWS['more/import'] = () => {
  const im = UI.imp;
  if (!im) return `<section class="card stack"><b>1 · Descarga el extracto de tu banco</b><p class="note" style="margin:0">En la web del banco: Cuenta → Movimientos → Descargar / Exportar. Elige Excel o CSV y el rango de fechas que quieras.</p></section>
    <section class="card stack"><b>2 · Súbelo aquí</b><p class="note" style="margin:0">Se lee solo en tu dispositivo. Nada se envía a ningún servidor.</p>
      <button class="btn primary" data-action="imp-file">Elegir archivo (.csv, .xlsx, .xls)</button><div class="err" id="impErr"></div></section>
    <p class="note">Consejo: añade palabras clave a tus categorías (Más → Categorías) para que los movimientos se clasifiquen solos, por ejemplo «mercadona, lidl» en Supermercado.</p>`;
  const cols = (im.rows[im.hdr] || []).map((c, i) => ({ i, l: String(c).trim() || `Columna ${i + 1}` }));
  const colSel = (id, v) => `<div class="sel"><select id="${id}">${cols.map(c => `<option value="${c.i}" ${c.i === v ? 'selected' : ''}>${esc(c.l)}</option>`).join('')}</select></div>`;
  return `<section class="card form">
    <div class="hstack"><b style="min-width:0;overflow:hidden;text-overflow:ellipsis">${esc(im.name)}</b><span class="spacer"></span><button class="link" data-action="imp-reset">Cambiar archivo</button></div>
    <label class="field"><span>Cuenta donde se apuntan</span>${accSelect('imAcc', im.acc)}</label>
    <label class="field"><span>Fila con los nombres de columna</span><div class="sel"><select id="imHdr">${im.rows.slice(0, 30).map((r, i) => `<option value="${i}" ${i === im.hdr ? 'selected' : ''}>Fila ${i + 1}: ${esc(r.slice(0, 4).join(' | ').slice(0, 60))}</option>`).join('')}</select></div></label>
    <div class="row2"><label class="field"><span>Fecha</span>${colSel('imDate', im.date)}</label><label class="field"><span>Concepto</span>${colSel('imDesc', im.desc)}</label></div>
    <div class="field"><span>Importe</span><div class="seg" id="imMode"><button type="button" data-k="single" aria-pressed="${im.mode === 'single'}">Una columna con signo</button><button type="button" data-k="split" aria-pressed="${im.mode === 'split'}">Cargo y abono</button></div></div>
    ${im.mode === 'single' ? `<label class="field"><span>Columna del importe</span>${colSel('imAmt', im.amount)}</label>` : `<div class="row2"><label class="field"><span>Cargos (gastos)</span>${colSel('imDeb', im.debit)}</label><label class="field"><span>Abonos (ingresos)</span>${colSel('imCre', im.credit)}</label></div>`}
    <label class="check"><input type="checkbox" id="imInv" ${im.invert ? 'checked' : ''}><span>Invertir signos (si los gastos te salen como ingresos)</span></label>
    <label class="check"><input type="checkbox" id="imDup" ${im.skipDup ? 'checked' : ''}><span>Saltar los que ya tengo (misma fecha e importe)</span></label>
  </section><section id="impPrev">${impPreview()}</section>`;
};
function impPreview() {
  const items = importItems(); const good = items.filter(x => !x.bad); const dups = good.filter(x => x.dup); const bad = items.filter(x => x.bad);
  const toImport = good.filter(x => !(UI.imp.skipDup && x.dup));
  const inc = sum(toImport.filter(x => x.kind === 'income'), x => x.amount), exp = sum(toImport.filter(x => x.kind === 'expense'), x => x.amount);
  const ccy = accById(UI.imp.acc)?.currency;
  return `<div class="kpis"><div class="kpi"><div class="k-l">Se van a importar</div><div class="k-v">${toImport.length}</div><div class="k-s">${dups.length} duplicados · ${bad.length} filas ignoradas</div></div><div class="kpi"><div class="k-l">Ingresos / gastos</div><div class="k-v small amt"><span class="pos">${fmt(inc, ccy, { dec: 0 })}</span> / ${fmt(exp, ccy, { dec: 0 })}</div><div class="k-s">${toImport.length ? `${shortDate(toImport.map(x => x.date).sort()[0])} – ${shortDate(toImport.map(x => x.date).sort().pop())}` : '&nbsp;'}</div></div></div>
  ${good.length ? `<div class="tbl-wrap" style="margin-top:10px"><table><thead><tr><th>Fecha</th><th>Concepto</th><th class="r">Importe</th><th>Categoría</th></tr></thead><tbody>${good.slice(0, 12).map(x => `<tr style="${x.dup && UI.imp.skipDup ? 'opacity:.45' : ''}"><td>${shortDate(x.date)}</td><td style="max-width:180px;overflow:hidden;text-overflow:ellipsis">${esc(x.desc)}</td><td class="r num ${x.kind === 'income' ? 'pos' : ''}">${fmt(x.kind === 'income' ? x.amount : -x.amount, ccy, { sign: true })}</td><td>${esc(x.cat.icon)} ${esc(x.cat.name)}${x.dup ? ' · <span class="warn">duplicado</span>' : ''}</td></tr>`).join('')}</tbody></table></div>
  <p class="note">Vista previa de las primeras ${Math.min(12, good.length)} filas. Si las fechas o importes no cuadran, cambia las columnas de arriba.</p>` : emptyCard('No encuentro movimientos', 'Revisa la fila de cabeceras y las columnas de fecha e importe.')}
  <button class="btn primary block" data-action="imp-go" ${toImport.length ? '' : 'disabled'} style="margin-top:12px">Importar ${toImport.length} movimiento${toImport.length === 1 ? '' : 's'}</button>`;
}
AFTER['more/import'] = () => {
  const im = UI.imp; if (!im) return;
  const upd = () => { $('#impPrev').innerHTML = impPreview(); };
  $('#imAcc').addEventListener('change', e => { im.acc = e.target.value; upd(); });
  $('#imHdr').addEventListener('change', e => { im.hdr = +e.target.value; Object.assign(im, guessImportFromHdr(im.rows, im.hdr)); render(); });
  const bind = (id, k) => { const el = $(id); if (el) el.addEventListener('change', e => { im[k] = +e.target.value; upd(); }); };
  bind('#imDate', 'date'); bind('#imDesc', 'desc'); bind('#imAmt', 'amount'); bind('#imDeb', 'debit'); bind('#imCre', 'credit');
  $('#imInv').addEventListener('change', e => { im.invert = e.target.checked; upd(); });
  $('#imDup').addEventListener('change', e => { im.skipDup = e.target.checked; upd(); });
  $('#imMode').addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; im.mode = b.dataset.k; render(); });
};
function guessImportFromHdr(rows, hdr) { const g = guessImport(rows.slice(hdr)); return { date: g.date, desc: g.desc, amount: g.amount, debit: g.debit, credit: g.credit, mode: g.mode }; }
async function startImport(file) {
  try {
    const rows = await readSheetFile(file);
    if (!rows.length) throw new Error('El archivo está vacío.');
    const g = guessImport(rows);
    const acc = activeAccounts()[0];
    if (!acc) { toast('Crea primero la cuenta a la que pertenece el extracto'); return openAccountForm(); }
    UI.imp = Object.assign({ name: file.name, rows, acc: acc.id, invert: false, skipDup: true }, g);
    render();
  } catch (e) { const el = $('#impErr'); if (el) el.textContent = 'No he podido leer el archivo: ' + e.message; else toast(e.message); }
}
function doImport() {
  const im = UI.imp; const items = importItems().filter(x => !x.bad && !(im.skipDup && x.dup));
  for (const x of items) S.txs.push({ id: uid(), type: x.kind, amount: x.amount, accountId: im.acc, categoryId: x.cat.id, date: x.date, note: x.desc.slice(0, 120), tags: [], imp: 1 });
  save(); UI.imp = null; toast(`${items.length} movimientos importados`);
  UI.txF = { month: 'all', q: '', type: 'all', acc: im.acc, cat: 'all' }; go('txs', { reset: true });
}
