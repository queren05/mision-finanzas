/* =====================================================================
   Hojas (formularios) y acciones
   ===================================================================== */
function openSheet(o) {
  UI.sheetLive = o.live || null;
  $('#sheetTitle').textContent = o.title || '';
  const b = $('#sheetBody'); b.innerHTML = o.html;
  $('#sheetWrap').hidden = false; document.documentElement.style.overflow = 'hidden';
  $('.sheet').scrollTop = 0;
  if (o.onMount) o.onMount(b);
}
function closeSheet() { $('#sheetWrap').hidden = true; $('#sheetBody').innerHTML = ''; UI.sheetLive = null; document.documentElement.style.overflow = ''; }
const sheetOpen = () => !$('#sheetWrap').hidden;
function ferr(msg) { const e = $('#fErr'); if (e) e.textContent = msg; return false; }
let toastT;
function toast(msg, act) {
  const t = $('#toast'); if (!t) return; t.innerHTML = '';
  const sp = document.createElement('span'); sp.textContent = msg; t.appendChild(sp);
  if (act) { const b = document.createElement('button'); b.className = 'toast-btn'; b.textContent = act.label; b.onclick = () => { t.classList.remove('show'); act.fn(); }; t.appendChild(b); }
  t.classList.toggle('has-act', !!act); t.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('show'), act ? 5000 : 2600);
}

const accSelect = (id, sel, o = {}) => `<div class="sel"><select id="${id}">${o.none ? `<option value="">${esc(o.none)}</option>` : ''}${S.accounts.filter(a => !a.archived || a.id === sel).sort((a, b) => (a.order ?? 0) - (b.order ?? 0)).map(a => `<option value="${a.id}" ${a.id === sel ? 'selected' : ''}>${esc(a.name)} · ${a.currency}</option>`).join('')}</select></div>`;
const ccySelect = (id, sel) => { const all = [...new Set([sel, ...COMMON_CCY, ...Object.keys(fxRates()).sort()])].filter(Boolean); return `<div class="sel"><select id="${id}">${all.map(c => `<option value="${c}" ${c === sel ? 'selected' : ''}>${c}${CCY_NAMES[c] ? ' · ' + CCY_NAMES[c] : ''}</option>`).join('')}</select></div>`; };
const swatchesHtml = sel => `<div class="field"><span>Color</span><div class="swatches" id="sw">${PALETTE.map(c => `<button type="button" data-c="${c}" style="--c:${c}" aria-label="Color ${c}" aria-pressed="${c === sel}"></button>`).join('')}</div></div>`;
function bindSwatches(root, cb) { root.querySelectorAll('#sw button').forEach(b => b.addEventListener('click', () => { root.querySelectorAll('#sw button').forEach(x => x.setAttribute('aria-pressed', 'false')); b.setAttribute('aria-pressed', 'true'); cb(b.dataset.c); })); }
const EMOJI = {
  cat: ['🛒', '🍽️', '☕', '🍺', '🚇', '⛽', '🚗', '🏠', '💡', '📱', '📺', '🎮', '🛍️', '👕', '💊', '🏋️', '🎁', '✈️', '🏖️', '📚', '🐾', '👶', '💇', '🚬', '🎬', '🎵', '🏦', '📦', '💼', '🧾', '🏷️', '📈', '📲', '➕', '💰', '🪙'],
  acc: ['🏦', '🐷', '💶', '💵', '💷', '💳', '🪙', '📊', '💼', '🏧', '🔒', '🌍'],
  goal: ['🎯', '🛟', '✈️', '🗾', '🏠', '🚗', '💍', '🎓', '💻', '📱', '🏖️', '🎮', '🐷', '🚀', '🏔️', '🎸'],
};
const emojiHtml = (sel, set) => `<div class="field"><span>Icono</span><div class="emojis" id="em">${EMOJI[set].map(e => `<button type="button" aria-pressed="${e === sel}">${e}</button>`).join('')}</div><input type="text" id="emIn" value="${esc(sel)}" maxlength="8" placeholder="O escribe cualquier emoji" style="max-width:220px"></div>`;
function bindEmoji(root, cb) {
  root.querySelectorAll('#em button').forEach(b => b.addEventListener('click', () => { root.querySelectorAll('#em button').forEach(x => x.setAttribute('aria-pressed', 'false')); b.setAttribute('aria-pressed', 'true'); root.querySelector('#emIn').value = b.textContent; cb(b.textContent); }));
  root.querySelector('#emIn').addEventListener('input', e => { root.querySelectorAll('#em button').forEach(x => x.setAttribute('aria-pressed', String(x.textContent === e.target.value))); cb(e.target.value.trim()); });
}
const deleteBtn = (action, id, label = 'Eliminar') => `<button type="button" class="btn danger block" data-action="${action}" data-id="${id}" data-confirm="¿Seguro? Toca otra vez">${label}</button>`;

/* ---------- movimientos ---------- */
function catGridHtml(kind, sel) {
  return catTree(kind).map(c => `<button type="button" class="catbtn ${c.parentId ? 'sub' : ''}" data-id="${c.id}" aria-pressed="${c.id === sel}"><span class="e">${esc(c.icon)}</span><span class="t">${esc(c.name)}</span></button>`).join('');
}
function openTxForm(tx, preset = {}) {
  const accs = activeAccounts();
  if (!accs.length) { toast('Primero crea una cuenta'); return openAccountForm(); }
  if (tx && tx.type === 'adjust') return openAdjustTx(tx);
  const isEdit = !!tx;
  const last = accById(S.lastAcc);
  const t = tx ? JSON.parse(JSON.stringify(tx)) : { type: preset.type || 'expense', amount: preset.amount || '', accountId: preset.accountId || (last && !last.archived ? last.id : accs[0].id), toAccountId: preset.toAccountId || '', categoryId: preset.categoryId || '', date: preset.date || today(), note: preset.note || '', tags: preset.tags || [], splits: preset.splits, excl: preset.excl };
  let type = t.type, cat = t.categoryId, toEdited = !!(tx && tx.toAmount != null && tx.toAmount !== tx.amount);
  let splits = Array.isArray(t.splits) && t.splits.length ? t.splits.map(p => ({ categoryId: p.categoryId, amount: p.amount })) : null;
  const html = `<form class="form" id="f" autocomplete="off" novalidate>
    ${isEdit ? '' : `<input class="inp" type="text" id="tQuick" placeholder="Escribe rápido: «12,50 mercadona» o «+1680 nómina»" autocomplete="off" aria-label="Apunte rápido">`}
    <div class="seg" id="tType">${['expense', 'income', 'transfer'].map(k => `<button type="button" data-k="${k}" aria-pressed="${type === k}">${TYPE_L[k]}</button>`).join('')}</div>
    <div class="amount-wrap"><input class="amount-input" id="tAmt" inputmode="decimal" placeholder="0,00" value="${t.amount !== '' ? inputNum(t.amount) : ''}" aria-label="Importe"><span class="amount-ccy" id="tCcy"></span></div>
    <div class="row2"><label class="field"><span id="tAccL">Cuenta</span>${accSelect('tAcc', t.accountId)}</label><label class="field"><span>Fecha</span><input type="date" id="tDate" value="${t.date}"></label></div>
    <div id="tToW" class="stack"><label class="field"><span>Hacia la cuenta</span>${accSelect('tTo', t.toAccountId || '', { none: 'Elige la cuenta de destino…' })}</label>
      <label class="field" id="tToAmtW"><span>Importe que llega (<span id="tToCcy"></span>)</span><input type="text" inputmode="decimal" id="tToAmt" value="${t.toAmount != null ? inputNum(t.toAmount) : ''}"></label></div>
    <div id="tCatW" class="field"><div class="hstack"><span class="lbl">Categoría</span><span class="spacer"></span><button type="button" class="link small" id="tSplitBtn">Dividir</button><button type="button" class="link small" data-action="cat-new-inline" style="margin-left:14px">+ Nueva</button></div><div class="catgrid" id="tCats"></div>
      <div id="tSplitW" class="stack" hidden><div id="tSplits" class="stack"></div><div class="hstack"><button type="button" class="btn sm" id="tSplitAdd">+ Otra parte</button><span class="spacer"></span><span class="small" id="tSplitLeft"></span></div><button type="button" class="link small" id="tSplitOff" style="align-self:flex-start">Quitar división</button></div></div>
    <label class="field"><span>Concepto</span><input type="text" id="tNote" value="${esc(t.note)}" placeholder="Ej.: Mercadona, cena con Ana…" list="noteList"><datalist id="noteList">${[...new Set(sortTx(S.txs).slice(0, 400).map(x => x.note).filter(Boolean))].slice(0, 60).map(n => `<option value="${esc(n)}"></option>`).join('')}</datalist></label>
    <div class="${isEdit ? '' : 'row2'}"><label class="field"><span>Etiquetas</span><input type="text" id="tTags" value="${esc((t.tags || []).join(', '))}" placeholder="viaje, trabajo…"></label>
    ${isEdit ? '' : `<label class="field"><span>Repetir</span><div class="sel"><select id="tRep"><option value="">No se repite</option><option value="weekly">Cada semana</option><option value="monthly">Cada mes</option><option value="yearly">Cada año</option></select></div></label>`}</div>
    <label class="check" id="tExclW"><input type="checkbox" id="tExcl" ${t.excl ? 'checked' : ''}><span>No contar en estadísticas ni presupuestos (reembolsos, gastos de empresa…)</span></label>
    <div class="err" id="fErr" role="alert"></div>
    <button class="btn primary block" type="submit">${isEdit ? 'Guardar cambios' : 'Añadir'}</button>
    ${isEdit ? `<div class="row3"><button type="button" class="btn sm" data-action="tx-dup" data-id="${tx.id}">Duplicar hoy</button><button type="button" class="btn sm" id="tAsTpl">Plantilla</button>${deleteBtn('tx-del', tx.id)}</div>${tx.recId ? '<p class="note">Este movimiento lo creó un recurrente. Editarlo no cambia los próximos.</p>' : ''}` : `<button type="button" class="btn ghost sm" id="tAsTpl">Guardar también como plantilla</button>`}
  </form>`;
  openSheet({
    title: isEdit ? 'Editar movimiento' : 'Nuevo movimiento', html, onMount(root) {
      const kindOf = () => type === 'income' ? 'income' : 'expense';
      const sync = () => {
        const acc = accById($('#tAcc').value); $('#tCcy').textContent = acc ? acc.currency : '';
        $('#tToW').hidden = type !== 'transfer'; $('#tCatW').hidden = type === 'transfer'; $('#tExclW').hidden = type === 'transfer';
        $('#tAccL').textContent = type === 'transfer' ? 'Desde la cuenta' : 'Cuenta';
        const to = accById($('#tTo').value); const diff = !!(to && acc && to.currency !== acc.currency);
        $('#tToAmtW').hidden = !diff; if (to) $('#tToCcy').textContent = to.currency;
        if (diff && !toEdited) { const a = Math.abs(parseMoney($('#tAmt').value)); $('#tToAmt').value = a > 0 ? inputNum(Math.round(conv(a, acc.currency, to.currency) * 100) / 100) : ''; }
        drawSplitLeft();
      };
      const drawCats = () => { const list = catTree(kindOf()); if (!list.some(c => c.id === cat)) cat = ''; $('#tCats').innerHTML = catGridHtml(kindOf(), cat); };
      const catOpts = sel => catTree(kindOf()).map(c => `<option value="${c.id}" ${c.id === sel ? 'selected' : ''}>${c.parentId ? '· ' : ''}${esc(c.icon)} ${esc(c.name)}</option>`).join('');
      const drawSplits = () => {
        const on = !!splits; $('#tSplitW').hidden = !on; $('#tCats').hidden = on; $('#tSplitBtn').hidden = on;
        if (!on) return;
        $('#tSplits').innerHTML = splits.map((p, i) => `<div class="toolbar"><div class="sel" style="flex:1;min-width:0"><select data-si="${i}" data-k="c">${catOpts(p.categoryId)}</select></div><input class="inp num" style="width:96px" inputmode="decimal" data-si="${i}" data-k="a" value="${p.amount !== '' ? inputNum(p.amount) : ''}" placeholder="0,00">${splits.length > 2 ? `<button type="button" class="icon-btn" data-sdel="${i}" aria-label="Quitar">✕</button>` : ''}</div>`).join('');
        drawSplitLeft();
      };
      const drawSplitLeft = () => { if (!splits) return; const tot = Math.abs(parseMoney($('#tAmt').value)) || 0; const used = sum(splits, p => parseMoney(p.amount) || 0); const left = Math.round((tot - used) * 100) / 100; $('#tSplitLeft').innerHTML = left === 0 ? '<span class="pos">Cuadra ✓</span>' : `${left > 0 ? 'Falta' : 'Sobra'} <b class="num">${fmt(Math.abs(left), accById($('#tAcc').value)?.currency)}</b>`; };
      $('#tSplitBtn').addEventListener('click', () => { const tot = Math.abs(parseMoney($('#tAmt').value)) || 0; splits = [{ categoryId: cat || catTree(kindOf())[0].id, amount: tot || '' }, { categoryId: catTree(kindOf())[1]?.id || catTree(kindOf())[0].id, amount: '' }]; drawSplits(); });
      $('#tSplitOff').addEventListener('click', () => { if (splits && splits[0]) cat = splits[0].categoryId; splits = null; drawCats(); drawSplits(); });
      $('#tSplitAdd').addEventListener('click', () => { splits.push({ categoryId: catTree(kindOf())[0].id, amount: '' }); drawSplits(); });
      $('#tSplits').addEventListener('input', e => { const el = e.target.closest('[data-si]'); if (!el) return; const p = splits[+el.dataset.si]; if (el.dataset.k === 'c') p.categoryId = el.value; else p.amount = el.value; drawSplitLeft(); });
      $('#tSplits').addEventListener('change', e => { const el = e.target.closest('select[data-si]'); if (el) splits[+el.dataset.si].categoryId = el.value; });
      $('#tSplits').addEventListener('click', e => { const b = e.target.closest('[data-sdel]'); if (b) { splits.splice(+b.dataset.sdel, 1); drawSplits(); } });
      root._redrawCats = (newId) => { if (newId) cat = newId; drawCats(); };
      root._type = () => type;
      $('#tCats').addEventListener('click', e => { const b = e.target.closest('.catbtn'); if (!b) return; cat = b.dataset.id; $$('.catbtn', root).forEach(x => x.setAttribute('aria-pressed', String(x.dataset.id === cat))); });
      $('#tType').addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; type = b.dataset.k; splits = null; $$('#tType button').forEach(x => x.setAttribute('aria-pressed', String(x.dataset.k === type))); drawCats(); drawSplits(); sync(); });
      $('#tAcc').addEventListener('change', sync); $('#tTo').addEventListener('change', () => { toEdited = false; sync(); });
      $('#tAmt').addEventListener('input', sync); $('#tToAmt').addEventListener('input', () => { toEdited = true; });
      // concepto conocido → propone la categoría que usaste la última vez
      $('#tNote').addEventListener('change', () => { if (cat || splits || isEdit) return; const n = $('#tNote').value.trim().toLowerCase(); if (!n) return; const prev = sortTx(S.txs).find(x => x.type === type && (x.note || '').toLowerCase() === n && x.categoryId); const g = prev ? catById(prev.categoryId) : guessCat(n, kindOf()); if (g && g.kind === kindOf()) { cat = g.id; drawCats(); } });
      const q = $('#tQuick'); if (q) q.addEventListener('input', () => { const r = parseQuick(q.value); if (!r) return; if (r.type !== type) { type = r.type; $$('#tType button').forEach(x => x.setAttribute('aria-pressed', String(x.dataset.k === type))); } if (r.amount) $('#tAmt').value = inputNum(r.amount); $('#tNote').value = r.note || ''; if (r.accountId) $('#tAcc').value = r.accountId; if (r.date) $('#tDate').value = r.date; cat = r.categoryId || ''; drawCats(); sync(); });
      const tplBtn = $('#tAsTpl'); if (tplBtn) tplBtn.addEventListener('click', () => { const a = Math.abs(parseMoney($('#tAmt').value)); const name = $('#tNote').value.trim() || (catById(cat) || {}).name || 'Plantilla'; S.templates.push({ id: 't_' + uid(), name, icon: (catById(cat) || {}).icon || '⭐', tpl: { type, amount: a > 0 ? Math.round(a * 100) / 100 : 0, accountId: $('#tAcc').value, toAccountId: $('#tTo').value || '', categoryId: cat || '', note: $('#tNote').value.trim(), tags: $('#tTags').value.split(',').map(x => x.trim()).filter(Boolean) } }); save(); toast('Plantilla guardada: ' + name); tplBtn.disabled = true; });
      drawCats(); drawSplits(); sync();
      if (!isEdit) (preset.amount ? $('#tNote') : $('#tAmt')).focus();
      $('#f').addEventListener('submit', e => {
        e.preventDefault();
        const amount = Math.abs(parseMoney($('#tAmt').value)); if (!(amount > 0)) return ferr('Escribe un importe mayor que 0.');
        const accountId = $('#tAcc').value; const date = $('#tDate').value || today();
        const o = { id: tx ? tx.id : uid(), type, amount: Math.round(amount * 100) / 100, accountId, date, note: $('#tNote').value.trim(), tags: $('#tTags').value.split(',').map(s => s.trim().replace(/^#/, '')).filter(Boolean) };
        if (tx && tx.recId) o.recId = tx.recId; if (tx && tx.imp) o.imp = tx.imp; if (tx && tx.src) o.src = tx.src; if (!tx && preset.src) o.src = preset.src;
        if (type === 'transfer') {
          const to = $('#tTo').value; if (!to) return ferr('Elige la cuenta de destino.'); if (to === accountId) return ferr('Origen y destino no pueden ser la misma cuenta.');
          const A = accById(accountId), B = accById(to); o.toAccountId = to;
          const ta = Math.abs(parseMoney($('#tToAmt').value));
          o.toAmount = A.currency !== B.currency ? Math.round((ta > 0 ? ta : conv(amount, A.currency, B.currency)) * 100) / 100 : o.amount;
        } else {
          if ($('#tExcl').checked) o.excl = true;
          if (splits) {
            const parts = splits.map(p => ({ categoryId: p.categoryId, amount: Math.round((Math.abs(parseMoney(p.amount)) || 0) * 100) / 100 })).filter(p => p.amount > 0);
            const diff = Math.round((o.amount - sum(parts, p => p.amount)) * 100) / 100;
            if (parts.length < 2) return ferr('Una división necesita al menos dos partes con importe.');
            if (Math.abs(diff) >= 0.01) return ferr(`Las partes no suman el total: ${diff > 0 ? 'faltan' : 'sobran'} ${fmt(Math.abs(diff), accById(accountId).currency)}.`);
            o.splits = parts; o.categoryId = parts[0].categoryId;
          } else o.categoryId = cat || otherCat(type).id;
        }
        if (tx) { const i = S.txs.findIndex(x => x.id === tx.id); S.txs[i] = o; } else S.txs.push(o);
        const rep = $('#tRep') && $('#tRep').value;
        if (rep) {
          const tpl = Object.assign({}, o); delete tpl.id; delete tpl.date; delete tpl.imp; delete tpl.src;
          const day = parseYmd(date).getDate(); const rid = 'r_' + uid();
          S.recurring.push({ id: rid, name: o.note || (type === 'transfer' ? 'Transferencia' : catById(o.categoryId).name), tpl, freq: rep, interval: 1, day, next: nextDate(date, rep, 1, day), end: '', active: true });
          o.recId = rid; runRecurring(); scheduleNotifs();
        }
        S.lastAcc = accountId; save(); closeSheet(); render(); haptic();
        toast(tx ? 'Cambios guardados' : type === 'expense' ? 'Gasto apuntado' : type === 'income' ? 'Ingreso apuntado' : 'Transferencia apuntada', tx ? null : { label: 'Deshacer', fn: () => { S.txs = S.txs.filter(x => x.id !== o.id); save(); render(); toast('Deshecho'); } });
        if (o.type === 'expense') budgetAlert(o);
      });
    }
  });
}
function openAdjustTx(tx) {
  const acc = accById(tx.accountId);
  openSheet({
    title: 'Ajuste de saldo', html: `<form class="form" id="f"><p class="note" style="margin:0">Un ajuste cuadra el saldo con tu banco sin contar como gasto ni ingreso.</p>
    <label class="field"><span>Diferencia (${acc ? acc.currency : ''})</span><input type="text" inputmode="decimal" id="aAmt" value="${inputNum(tx.amount)}"></label>
    <label class="field"><span>Fecha</span><input type="date" id="aDate" value="${tx.date}"></label>
    <label class="field"><span>Nota</span><input type="text" id="aNote" value="${esc(tx.note)}"></label>
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">Guardar</button>${deleteBtn('tx-del', tx.id)}</form>`,
    onMount() { $('#f').addEventListener('submit', e => { e.preventDefault(); const v = parseMoney($('#aAmt').value); if (!isFinite(v) || v === 0) return ferr('Escribe una diferencia distinta de 0 (con signo menos si baja).'); Object.assign(tx, { amount: Math.round(v * 100) / 100, date: $('#aDate').value || tx.date, note: $('#aNote').value.trim() }); save(); closeSheet(); render(); toast('Ajuste guardado'); }); }
  });
}

/* ---------- cuentas ---------- */
function openAccountForm(a) {
  const isEdit = !!a;
  const x = a ? Object.assign({}, a) : { name: '', type: 'corriente', currency: S.settings.base, initial: '', color: PALETTE[S.accounts.length % PALETTE.length], icon: '', includeInTotal: true, archived: false };
  let color = x.color, icon = x.icon || ACC_ICONS[x.type];
  const cur = isEdit ? (balances()[a.id] || 0) : 0;
  const nTx = isEdit ? S.txs.filter(t => t.accountId === a.id || t.toAccountId === a.id).length : 0;
  openSheet({
    title: isEdit ? 'Editar cuenta' : 'Nueva cuenta', html: `<form class="form" id="f" autocomplete="off">
    <label class="field"><span>Nombre</span><input type="text" id="aName" value="${esc(x.name)}" placeholder="Ej.: Cuenta nómina, Revolut, Binance…" maxlength="40"></label>
    <div class="row2"><label class="field"><span>Tipo</span><div class="sel"><select id="aType">${Object.entries(ACC_TYPES).map(([k, l]) => `<option value="${k}" ${k === x.type ? 'selected' : ''}>${l}</option>`).join('')}</select></div></label>
    <label class="field"><span>Moneda</span>${ccySelect('aCcy', x.currency)}</label></div>
    ${isEdit ? `<label class="field"><span>Saldo inicial</span><input type="text" inputmode="decimal" id="aInit" value="${inputNum(x.initial || 0)}"></label>
      <p class="note" style="margin:-6px 0 0">Saldo actual: <b class="num">${fmt(cur, x.currency)}</b>. Si no cuadra con tu banco, usa «Ajustar saldo» en la ficha de la cuenta.</p>`
        : `<label class="field"><span id="aInitL">¿Cuánto tienes hoy en esta cuenta?</span><input type="text" inputmode="decimal" id="aInit" placeholder="0,00"></label>`}
    <p class="note" id="aDebtNote" style="margin:-6px 0 0" hidden>Escribe lo que te queda por pagar (en positivo). Cada cuota que le transfieras reduce la deuda.</p>
    <label class="field" id="aLimW"><span>Límite de crédito (opcional)</span><input type="text" inputmode="decimal" id="aLim" value="${x.limit ? inputNum(x.limit) : ''}" placeholder="Ej.: 1500"></label>
    <label class="field"><span>Nombre de la tarjeta en Wallet / Apple Pay (para Atajos)</span><input type="text" id="aCard" value="${esc(x.cardAlias || '')}" placeholder="Ej.: Visa BBVA, Revolut, Tarjeta Metal"></label>
    <label class="field"><span>Nota (opcional)</span><input type="text" id="aNote" value="${esc(x.note || '')}" placeholder="IBAN abreviado, condiciones, TAE…" maxlength="80"></label>
    ${emojiHtml(icon, 'acc')}
    ${swatchesHtml(color)}
    <label class="check"><input type="checkbox" id="aInc" ${x.includeInTotal !== false ? 'checked' : ''}><span>Sumar al patrimonio total</span></label>
    ${isEdit ? `<label class="check"><input type="checkbox" id="aArch" ${x.archived ? 'checked' : ''}><span>Archivar (se oculta pero conserva su historial)</span></label>` : ''}
    <div class="err" id="fErr"></div>
    <button class="btn primary block" type="submit">${isEdit ? 'Guardar cambios' : 'Crear cuenta'}</button>
    ${isEdit ? deleteBtn('acc-del', a.id, nTx ? `Eliminar cuenta y sus ${nTx} movimientos` : 'Eliminar cuenta') : ''}
  </form>`, onMount(root) {
      bindSwatches(root, c => color = c); bindEmoji(root, e => icon = e);
      const tsync = () => { const ty = $('#aType').value; $('#aLimW').hidden = ty !== 'tarjeta'; $('#aDebtNote').hidden = ty !== 'deuda'; const l = $('#aInitL'); if (l) l.textContent = ty === 'deuda' ? '¿Cuánto debes hoy?' : ty === 'activo' ? '¿Cuánto vale hoy?' : ty === 'tarjeta' ? '¿Cuánto llevas gastado con ella? (en negativo)' : '¿Cuánto tienes hoy en esta cuenta?'; };
      $('#aType').addEventListener('change', e => { tsync(); if (!icon || Object.values(ACC_ICONS).includes(icon)) { icon = ACC_ICONS[e.target.value]; $('#emIn').value = icon; $$('#em button', root).forEach(b => b.setAttribute('aria-pressed', String(b.textContent === icon))); } }); tsync();
      if (!isEdit) $('#aName').focus();
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const name = $('#aName').value.trim(); if (!name) return ferr('Ponle un nombre a la cuenta.');
        let init = parseMoney($('#aInit').value); if (!isEdit && $('#aType').value === 'deuda' && init > 0) init = -init;
        const lim = parseMoney($('#aLim').value);
        const o = { name, type: $('#aType').value, currency: $('#aCcy').value, initial: isFinite(init) ? Math.round(init * 100) / 100 : 0, color, icon: icon || ACC_ICONS[$('#aType').value], includeInTotal: $('#aInc').checked, cardAlias: $('#aCard').value.trim(), note: $('#aNote').value.trim(), limit: lim > 0 ? lim : 0 };
        if (isEdit) { Object.assign(a, o, { archived: $('#aArch').checked }); }
        else { const acc = Object.assign({ id: 'a_' + uid(), archived: false, order: S.accounts.length ? Math.max(...S.accounts.map(z => z.order ?? 0)) + 1 : 0 }, o); S.accounts.push(acc); S.lastAcc = acc.id; }
        save(); closeSheet(); render(); toast(isEdit ? 'Cuenta guardada' : 'Cuenta creada');
      });
    }
  });
}
function deleteAccount(id) {
  S.txs = S.txs.filter(t => t.accountId !== id && t.toAccountId !== id);
  S.recurring = S.recurring.filter(r => r.tpl.accountId !== id && r.tpl.toAccountId !== id);
  S.assets.forEach(a => { if (a.accountId === id) a.accountId = ''; a.ops.forEach(o => { if (o.cashAccountId === id) o.cashAccountId = ''; }); });
  S.groups.forEach(g => g.items = g.items.filter(it => !(it.t === 'account' && it.id === id)));
  S.goals.forEach(g => { if (g.source && g.source.t === 'account' && g.source.id === id) { g.manual = goalCurrent(g, portfolio()); g.source = { t: 'manual' }; } });
  S.accounts = S.accounts.filter(a => a.id !== id);
}
function openAccount(id) {
  const a = accById(id); if (!a) return;
  const draw = () => {
    const P = UI.P || portfolio(); const bal = balances()[id] || 0; const b = P.byAcc(id);
    const MR = FR(curMk()); let inn = 0, out = 0;
    for (const t of S.txs) { if (t.date < MR.from || t.date > MR.to) continue; if (t.accountId === id) { if (t.type === 'income' || (t.type === 'adjust' && t.amount > 0)) inn += Math.abs(t.amount); else out += Math.abs(t.amount); } if (t.type === 'transfer' && t.toAccountId === id) inn += (t.toAmount ?? t.amount); }
    const hold = P.assets.filter(r => r.x.accountId === id);
    const recent = sortTx(S.txs.filter(t => t.accountId === id || t.toAccountId === id)).slice(0, 5);
    return `<div class="stack">
      <div class="hero" style="padding:0"><div class="eyebrow">${esc(ACC_TYPES[a.type] || '')} · ${a.currency}</div><div class="hero-num amt" style="font-size:40px">${fmt(bal, a.currency)}</div>
      <div class="hero-sub">${a.currency !== S.settings.base ? `<span class="chip">≈&nbsp;<span class="amt">${fmt(conv(bal, a.currency))}</span></span>` : ''}${b.inv ? `<span class="chip acc">+&nbsp;<span class="amt">${fmt(b.inv)}</span>&nbsp;en inversiones</span>` : ''}${a.includeInTotal === false ? '<span class="chip">Fuera del patrimonio</span>' : ''}</div></div>
      ${a.type === 'tarjeta' && a.limit ? `<div class="card stack"><div class="hstack"><span class="small muted">Crédito disponible</span><span class="spacer"></span><b class="num amt">${fmt(a.limit + Math.min(0, bal), a.currency)}</b></div><div class="bar" style="--c:var(--${-bal / a.limit > .8 ? 'neg' : -bal / a.limit > .5 ? 'warn' : 'pos'})"><i style="width:${clamp(-bal / a.limit * 100, 0, 100).toFixed(1)}%"></i></div><span class="note">Usado ${fmt(Math.max(0, -bal), a.currency)} de ${fmt(a.limit, a.currency)}</span></div>` : ''}
      ${a.note ? `<p class="note" style="margin:0">${esc(a.note)}</p>` : ''}
      <div class="kpis"><div class="kpi"><div class="k-l">Entradas este mes</div><div class="k-v pos amt">${fmt(inn, a.currency)}</div></div><div class="kpi"><div class="k-l">Salidas este mes</div><div class="k-v amt">${fmt(out, a.currency)}</div></div></div>
      <div class="row3"><button class="btn sm" data-action="acc-adjust" data-id="${id}">Ajustar saldo</button><button class="btn sm" data-action="acc-transfer" data-id="${id}">Transferir</button><button class="btn sm" data-action="acc-edit" data-id="${id}">Editar</button></div>
      ${hold.length ? `<div class="sec-h"><h2>Inversiones en esta cuenta</h2></div><div class="list">${hold.map(assetRow).join('')}</div>` : ''}
      ${recent.length ? `<div class="sec-h"><h2>Últimos movimientos</h2><button class="link" data-action="acc-txs" data-id="${id}">Ver todos</button></div><div class="list">${recent.map(t => txRow(t, id)).join('')}</div>` : '<p class="note">Sin movimientos todavía.</p>'}
    </div>`;
  };
  openSheet({ title: `${a.icon || ''} ${a.name}`, html: `<div id="accLive">${draw()}</div>`, live: () => { const el = $('#accLive'); if (el) el.innerHTML = draw(); } });
}
function openAdjust(id) {
  const a = accById(id); const cur = balances()[id] || 0;
  openSheet({
    title: 'Ajustar saldo', html: `<form class="form" id="f"><p class="note" style="margin:0">Escribe el saldo que ves ahora en tu banco. La diferencia se apunta como ajuste y no cuenta como gasto ni ingreso.</p>
    <div class="amount-wrap"><input class="amount-input" id="aReal" inputmode="decimal" value="${inputNum(Math.round(cur * 100) / 100)}" aria-label="Saldo real"><span class="amount-ccy">${a.currency}</span></div>
    <p class="note" id="aDiff" style="margin:0;text-align:center"></p>
    <label class="check"><input type="checkbox" id="aAsTx"><span>Apuntar la diferencia como gasto o ingreso (cuenta en estadísticas)</span></label>
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">Ajustar</button></form>`,
    onMount() {
      const upd = () => { const v = parseMoney($('#aReal').value); $('#aDiff').innerHTML = isFinite(v) ? `Saldo en la app ${fmt(cur, a.currency)} · diferencia <b class="${pcls(v - cur)}">${fmt(v - cur, a.currency, { sign: true })}</b>` : ''; };
      $('#aReal').addEventListener('input', upd); upd(); $('#aReal').focus(); $('#aReal').select();
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const v = parseMoney($('#aReal').value); if (!isFinite(v)) return ferr('Escribe un número.');
        const d = Math.round((v - cur) * 100) / 100; if (!d) { closeSheet(); return toast('El saldo ya cuadra'); }
        if ($('#aAsTx').checked) S.txs.push({ id: uid(), type: d > 0 ? 'income' : 'expense', amount: Math.abs(d), accountId: id, categoryId: otherCat(d > 0 ? 'income' : 'expense').id, date: today(), note: 'Diferencia de saldo', tags: [] });
        else S.txs.push({ id: uid(), type: 'adjust', amount: d, accountId: id, date: today(), note: 'Ajuste de saldo', tags: [] });
        save(); closeSheet(); render(); toast('Saldo ajustado');
      });
    }
  });
}

/* ---------- objetivos ---------- */
function goalSourceOptions(sel) {
  const s = sel || { t: 'manual' }; const k = s.t + ':' + (s.id || s.v || '');
  const o = [['manual:', 'Lo voy sumando a mano'], ['nw:', 'Mi patrimonio total']];
  S.groups.forEach(g => o.push(['group:' + g.id, 'Bloque: ' + g.name]));
  activeAccounts().forEach(a => o.push(['account:' + a.id, 'Cuenta: ' + a.name]));
  o.push(['kind:crypto', 'Toda mi cripto'], ['kind:stock', 'Todas mis acciones']);
  return o.map(([v, l]) => `<option value="${esc(v)}" ${v === k ? 'selected' : ''}>${esc(l)}</option>`).join('');
}
function openGoalForm(g) {
  const isEdit = !!g;
  const x = g ? Object.assign({}, g) : { name: '', icon: '🎯', color: PALETTE[(S.goals.length + 2) % PALETTE.length], target: '', ccy: S.settings.base, deadline: '', source: { t: 'manual' }, manual: 0 };
  let color = x.color, icon = x.icon;
  openSheet({
    title: isEdit ? 'Editar objetivo' : 'Nuevo objetivo', html: `<form class="form" id="f" autocomplete="off">
    <label class="field"><span>¿Qué quieres conseguir?</span><input type="text" id="gName" value="${esc(x.name)}" placeholder="Ej.: Colchón de 6 meses, viaje a Japón…" maxlength="50"></label>
    <div class="row2"><label class="field"><span>Cantidad objetivo</span><input type="text" inputmode="decimal" id="gTarget" value="${x.target ? inputNum(x.target) : ''}" placeholder="0"></label><label class="field"><span>Moneda</span>${ccySelect('gCcy', x.ccy || S.settings.base)}</label></div>
    <label class="field"><span>Fecha límite (opcional)</span><input type="date" id="gDate" value="${x.deadline || ''}"></label>
    <label class="field"><span>¿Cómo se mide lo que llevas?</span><div class="sel"><select id="gSrc">${goalSourceOptions(x.source)}</select></div></label>
    <label class="field" id="gManW"><span>Lo que llevas ahorrado</span><input type="text" inputmode="decimal" id="gMan" value="${inputNum(x.manual || 0)}"></label>
    ${emojiHtml(icon, 'goal')}${swatchesHtml(color)}
    <div class="err" id="fErr"></div>
    <button class="btn primary block" type="submit">${isEdit ? 'Guardar' : 'Crear objetivo'}</button>${isEdit ? deleteBtn('goal-del', g.id) : ''}</form>`,
    onMount(root) {
      bindSwatches(root, c => color = c); bindEmoji(root, e => icon = e);
      const s = () => { $('#gManW').hidden = $('#gSrc').value !== 'manual:'; }; $('#gSrc').addEventListener('change', s); s();
      if (!isEdit) $('#gName').focus();
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const name = $('#gName').value.trim(); const target = parseMoney($('#gTarget').value);
        if (!name) return ferr('Ponle un nombre.'); if (!(target > 0)) return ferr('La cantidad objetivo tiene que ser mayor que 0.');
        const [t, v] = $('#gSrc').value.split(':'); const source = t === 'group' || t === 'account' ? { t, id: v } : t === 'kind' ? { t, v } : { t };
        const o = { name, target: Math.round(target * 100) / 100, ccy: $('#gCcy').value, deadline: $('#gDate').value, source, icon: icon || '🎯', color, manual: Math.round((parseMoney($('#gMan').value) || 0) * 100) / 100 };
        if (isEdit) Object.assign(g, o); else S.goals.push(Object.assign({ id: 'o_' + uid() }, o));
        save(); closeSheet(); render(); toast(isEdit ? 'Objetivo guardado' : 'Objetivo creado');
      });
    }
  });
}
function openGoal(id) {
  const g = goalById(id); if (!g) return;
  const draw = () => {
    const P = UI.P || portfolio(); const i = goalInfo(g, P);
    const flow3 = (() => { let s = 0; for (let k = 1; k <= 3; k++) { const m = addMonths(monthKey(today()), -k); s += flows(m + '-01', monthEnd(m)).net; } return s / 3; })();
    const eta = !i.done && flow3 > 0 ? Math.ceil(i.left / flow3) : null;
    return `<div class="stack">
      <div class="goal-top">${ico(esc(g.icon || '🎯'), g.color)}<div class="row-m"><div class="row-t">${esc(g.name)}</div><div class="row-s">${goalSrcLabel(g)}</div></div></div>
      <div class="hero-num amt" style="font-size:38px;color:${g.color}">${fmt(i.cur)}</div>
      <div class="bar" style="--c:${g.color};height:10px"><i style="width:${i.pct.toFixed(1)}%"></i></div>
      <dl class="kv"><dt>Objetivo</dt><dd class="num amt">${fmt(i.target)}</dd><dt>Progreso</dt><dd class="num">${fmtPct(i.pct, false)}</dd><dt>Te falta</dt><dd class="num amt">${fmt(i.left)}</dd>
      ${g.deadline ? `<dt>Fecha límite</dt><dd>${shortDate(g.deadline)}</dd><dt>Necesitas apartar</dt><dd class="num amt">${i.done ? '—' : i.months > 0 ? fmt(i.perMonth) + ' al mes' : 'Fecha superada'}</dd>` : ''}
      ${eta ? `<dt>A tu ritmo de ahorro actual</dt><dd>${eta} ${eta === 1 ? 'mes' : 'meses'}</dd>` : ''}</dl>
      ${(g.source || {}).t === 'manual' ? `<form class="toolbar" id="gAddF"><input class="inp" id="gAdd" inputmode="decimal" placeholder="Importe" aria-label="Aportación"><button class="btn" type="submit">Sumar</button><button class="btn ghost" type="button" data-action="goal-sub" data-id="${g.id}">Restar</button></form>` : ''}
      <button class="btn block" data-action="goal-edit" data-id="${g.id}">Editar objetivo</button></div>`;
  };
  const mount = () => { const f = $('#gAddF'); if (f) f.addEventListener('submit', e => { e.preventDefault(); const v = parseMoney($('#gAdd').value); if (!(v > 0)) return; g.manual = Math.round(((Number(g.manual) || 0) + v) * 100) / 100; save(); render(); $('#goalLive').innerHTML = draw(); mount(); toast('Aportación sumada'); }); };
  openSheet({ title: 'Objetivo', html: `<div id="goalLive">${draw()}</div>`, onMount: mount, live: () => { if (document.activeElement && document.activeElement.id === 'gAdd') return; const el = $('#goalLive'); if (el) { el.innerHTML = draw(); mount(); } } });
}

/* ---------- bloques ---------- */
function openGroupForm(g) {
  const isEdit = !!g; const x = g ? JSON.parse(JSON.stringify(g)) : { name: '', color: PALETTE[S.groups.length % PALETTE.length], items: [] };
  let color = x.color;
  const has = (t, k) => x.items.some(it => it.t === t && (it.id || it.v || '') === (k || ''));
  const box = (t, k, label, sub) => `<label class="check"><input type="checkbox" data-t="${t}" data-k="${esc(k || '')}" ${has(t, k) ? 'checked' : ''}><span>${label}${sub ? `<br><span class="small muted">${sub}</span>` : ''}</span></label>`;
  const types = [...new Set(S.accounts.map(a => a.type))];
  openSheet({
    title: isEdit ? 'Editar bloque' : 'Nuevo bloque', html: `<form class="form" id="f" autocomplete="off">
    <label class="field"><span>Nombre</span><input type="text" id="bName" value="${esc(x.name)}" placeholder="Ej.: Todo en Binance, Dinero en dólares…" maxlength="36"></label>
    ${swatchesHtml(color)}
    <div class="field"><span>Qué suma este bloque</span><div class="card" style="padding:4px 12px">
      ${box('all', '', 'Todo el patrimonio')}${box('cash', '', 'Todas las cuentas', 'Solo el dinero, sin inversiones')}${box('kind', 'crypto', 'Toda la cripto')}${box('kind', 'stock', 'Todas las acciones y ETF')}
    </div></div>
    ${types.length ? `<div class="field"><span>Por tipo de cuenta</span><div class="card" style="padding:4px 12px">${types.map(t => box('atype', t, ACC_TYPES[t])).join('')}</div></div>` : ''}
    ${S.accounts.length ? `<div class="field"><span>Cuentas concretas (incluye sus inversiones)</span><div class="card" style="padding:4px 12px">${S.accounts.map(a => box('account', a.id, `${esc(a.icon || '')} ${esc(a.name)}`, a.currency)).join('')}</div></div>` : ''}
    ${S.assets.length ? `<div class="field"><span>Inversiones concretas</span><div class="card" style="padding:4px 12px">${S.assets.map(a => box('asset', a.id, `${esc(a.symbol)} · ${esc(a.name || '')}`)).join('')}</div></div>` : ''}
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">${isEdit ? 'Guardar' : 'Crear bloque'}</button>${isEdit ? deleteBtn('group-del', g.id) : ''}</form>`,
    onMount(root) {
      bindSwatches(root, c => color = c); if (!isEdit) $('#bName').focus();
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const name = $('#bName').value.trim(); if (!name) return ferr('Ponle un nombre al bloque.');
        const items = $$('input[data-t]:checked', root).map(c => { const t = c.dataset.t, k = c.dataset.k; return t === 'account' || t === 'asset' ? { t, id: k } : t === 'kind' || t === 'atype' ? { t, v: k } : { t }; });
        if (!items.length) return ferr('Marca al menos una cosa que sumar.');
        if (isEdit) Object.assign(g, { name, color, items }); else S.groups.push({ id: 'g_' + uid(), name, color, items });
        save(); closeSheet(); render(); toast(isEdit ? 'Bloque guardado' : 'Bloque creado');
      });
    }
  });
}
function openGroup(id) {
  const g = groupById(id); if (!g) return;
  const draw = () => {
    const P = UI.P || portfolio(); const v = groupValue(g, P);
    const accs = P.accounts.filter(r => v.acc.has(r.a.id)), ast = P.assets.filter(r => v.ast.has(r.x.id));
    return `<div class="stack"><div class="eyebrow">${esc(groupItemsLabel(g))}</div><div class="hero-num amt" style="font-size:40px;color:${g.color}">${fmt(v.value)}</div>
      <div class="hero-sub"><span class="chip"><span class="amt">${fmt(v.cash, null, { compact: true })}</span>&nbsp;en cuentas</span>${v.inv ? `<span class="chip"><span class="amt">${fmt(v.inv, null, { compact: true })}</span>&nbsp;invertido</span><span class="chip ${pcls(v.pnl)}"><span class="amt">${fmt(v.pnl, null, { sign: true })}</span>&nbsp;rentabilidad</span>` : ''}</div>
      ${accs.length ? `<div class="list">${accs.map(r => `<div class="row">${ico(esc(r.a.icon || ''), r.a.color)}<div class="row-m"><div class="row-t">${esc(r.a.name)}</div><div class="row-s">${r.a.currency}</div></div><span class="num amt">${fmt(r.base)}</span></div>`).join('')}</div>` : ''}
      ${ast.length ? `<div class="list">${ast.map(assetRow).join('')}</div>` : ''}
      <button class="btn block" data-action="group-edit" data-id="${g.id}">Editar bloque</button></div>`;
  };
  openSheet({ title: g.name, html: `<div id="grpLive">${draw()}</div>`, live: () => { const el = $('#grpLive'); if (el) el.innerHTML = draw(); } });
}

/* ---------- categorías ---------- */
function openCatForm(c, kind, onDone, asSub) {
  const isEdit = !!c; const x = c ? Object.assign({}, c) : { name: '', kind: kind || 'expense', icon: '📦', color: PALETTE[S.categories.length % PALETTE.length], budget: 0, keywords: '', parentId: '' };
  let color = x.color, icon = x.icon, k = x.kind;
  const n = isEdit ? S.txs.filter(t => t.categoryId === c.id).length : 0;
  openSheet({
    title: isEdit ? 'Editar categoría' : 'Nueva categoría', html: `<form class="form" id="f" autocomplete="off">
    ${isEdit ? '' : `<div class="seg" id="cKind"><button type="button" data-k="expense" aria-pressed="${k === 'expense'}">Gasto</button><button type="button" data-k="income" aria-pressed="${k === 'income'}">Ingreso</button></div>`}
    <label class="field"><span>Nombre</span><input type="text" id="cName" value="${esc(x.name)}" maxlength="30" placeholder="Ej.: Café, Mascota, Criptominería…"></label>
    <label class="field" id="cParW"><span>Dentro de (subcategoría)</span><div class="sel"><select id="cPar"></select></div></label>
    ${emojiHtml(icon, 'cat')}${swatchesHtml(color)}
    <label class="field" id="cBudW"><span>Presupuesto mensual (${S.settings.base}, opcional)</span><input type="text" inputmode="decimal" id="cBud" value="${x.budget ? inputNum(x.budget) : ''}" placeholder="Sin límite"></label>
    <label class="check" id="cRollW"><input type="checkbox" id="cRoll" ${x.rollover ? 'checked' : ''}><span>Pasar al siguiente periodo lo que sobre o falte del presupuesto</span></label>
    <label class="field"><span>Palabras clave (importar y Atajos, separadas por comas)</span><textarea id="cKw" rows="2" placeholder="mercadona, lidl, carrefour">${esc(x.keywords || '')}</textarea></label>
    ${isEdit ? `<label class="check"><input type="checkbox" id="cHid" ${x.hidden ? 'checked' : ''}><span>Ocultar al apuntar (conserva su historial)</span></label>` : ''}
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">${isEdit ? 'Guardar' : 'Crear categoría'}</button>
    ${isEdit ? deleteBtn('cat-del', c.id, n ? `Eliminar (sus ${n} movimientos pasan a «${esc(otherCat(c.kind).id === c.id ? 'Sin categoría' : otherCat(c.kind).name)}»)` : 'Eliminar categoría') : ''}</form>`,
    onMount(root) {
      bindSwatches(root, v => color = v); bindEmoji(root, v => icon = v);
      const drawPar = () => { const hasKids = isEdit && S.categories.some(z => z.parentId === c.id); $('#cParW').hidden = hasKids; $('#cPar').innerHTML = `<option value="">Ninguna (categoría principal)</option>` + S.categories.filter(z => z.kind === k && !z.parentId && (!isEdit || z.id !== c.id)).map(z => `<option value="${z.id}" ${z.id === (x.parentId || '') ? 'selected' : ''}>${esc(z.icon)} ${esc(z.name)}</option>`).join(''); if (asSub && !x.parentId && !isEdit) { const first = S.categories.find(z => z.kind === k && !z.parentId); if (first) $('#cPar').value = first.id; } };
      const s = () => { $('#cBudW').hidden = k !== 'expense'; $('#cRollW').hidden = k !== 'expense'; drawPar(); };
      const kb = $('#cKind'); if (kb) kb.addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; k = b.dataset.k; $$('#cKind button').forEach(z => z.setAttribute('aria-pressed', String(z.dataset.k === k))); s(); });
      s(); if (!isEdit) $('#cName').focus();
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const name = $('#cName').value.trim(); if (!name) return ferr('Ponle un nombre.');
        const bud = parseMoney($('#cBud').value);
        const o = { name, icon: icon || '📦', color, budget: k === 'expense' && bud > 0 ? Math.round(bud * 100) / 100 : 0, keywords: $('#cKw').value.trim(), parentId: $('#cParW').hidden ? (x.parentId || '') : $('#cPar').value, rollover: $('#cRoll').checked };
        if ($('#cHid')) o.hidden = $('#cHid').checked;
        let id;
        if (isEdit) { Object.assign(c, o); id = c.id; } else { id = 'c_' + uid(); S.categories.push(Object.assign({ id, kind: k }, o)); }
        save();
        if (onDone) { onDone(id); return; }
        closeSheet(); render(); toast(isEdit ? 'Categoría guardada' : 'Categoría creada');
      });
    }
  });
}

/* ---------- recurrentes ---------- */
function openRecForm(r) {
  const accs = activeAccounts(); if (!accs.length) { toast('Primero crea una cuenta'); return openAccountForm(); }
  const isEdit = !!r;
  const x = r ? JSON.parse(JSON.stringify(r)) : { name: '', tpl: { type: 'expense', amount: '', accountId: accs[0].id, categoryId: '', note: '', tags: [] }, freq: 'monthly', interval: 1, day: new Date().getDate(), next: today(), end: '', active: true };
  let type = x.tpl.type, cat = x.tpl.categoryId;
  openSheet({
    title: isEdit ? 'Editar recurrente' : 'Nuevo recurrente', html: `<form class="form" id="f" autocomplete="off">
    <div class="seg" id="rType">${['expense', 'income', 'transfer'].map(k => `<button type="button" data-k="${k}" aria-pressed="${type === k}">${TYPE_L[k]}</button>`).join('')}</div>
    <label class="field"><span>Nombre</span><input type="text" id="rName" value="${esc(x.name || x.tpl.note)}" placeholder="Ej.: Nómina, Alquiler, Spotify…"></label>
    <div class="row2"><label class="field"><span>Importe</span><input type="text" inputmode="decimal" id="rAmt" value="${x.tpl.amount !== '' ? inputNum(x.tpl.amount) : ''}" placeholder="0,00"></label><label class="field"><span id="rAccL">Cuenta</span>${accSelect('rAcc', x.tpl.accountId)}</label></div>
    <label class="field" id="rToW"><span>Hacia la cuenta</span>${accSelect('rTo', x.tpl.toAccountId || '', { none: 'Elige cuenta…' })}</label>
    <div id="rCatW" class="field"><span class="lbl">Categoría</span><div class="catgrid" id="rCats"></div></div>
    <div class="row2"><label class="field"><span>Frecuencia</span><div class="sel"><select id="rFreq">${Object.entries(FREQ_L).map(([k, l]) => `<option value="${k}" ${k === x.freq ? 'selected' : ''}>${l}</option>`).join('')}</select></div></label><label class="field"><span>Cada cuántos</span><input type="text" inputmode="numeric" id="rInt" value="${x.interval || 1}"></label></div>
    <div class="row2"><label class="field"><span>Próxima vez</span><input type="date" id="rNext" value="${x.next}"></label><label class="field"><span>Termina (opcional)</span><input type="date" id="rEnd" value="${x.end || ''}"></label></div>
    <label class="check"><input type="checkbox" id="rAct" ${x.active ? 'checked' : ''}><span>Activo</span></label>
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">${isEdit ? 'Guardar' : 'Crear recurrente'}</button>${isEdit ? deleteBtn('rec-del', r.id) : ''}
    <p class="note">Si la próxima fecha ya pasó, se apuntan los que falten al guardar.</p></form>`,
    onMount(root) {
      const draw = () => { const kind = type === 'income' ? 'income' : 'expense'; const list = S.categories.filter(c => c.kind === kind); if (!list.some(c => c.id === cat)) cat = ''; $('#rCats').innerHTML = list.map(c => `<button type="button" class="catbtn" data-id="${c.id}" aria-pressed="${c.id === cat}"><span class="e">${esc(c.icon)}</span><span class="t">${esc(c.name)}</span></button>`).join(''); $('#rToW').hidden = type !== 'transfer'; $('#rCatW').hidden = type === 'transfer'; $('#rAccL').textContent = type === 'transfer' ? 'Desde' : 'Cuenta'; };
      $('#rCats').addEventListener('click', e => { const b = e.target.closest('.catbtn'); if (!b) return; cat = b.dataset.id; $$('.catbtn', root).forEach(z => z.setAttribute('aria-pressed', String(z.dataset.id === cat))); });
      $('#rType').addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; type = b.dataset.k; $$('#rType button').forEach(z => z.setAttribute('aria-pressed', String(z.dataset.k === type))); draw(); });
      draw();
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const amount = Math.abs(parseMoney($('#rAmt').value)); if (!(amount > 0)) return ferr('Escribe un importe.');
        const name = $('#rName').value.trim(); const accountId = $('#rAcc').value; const next = $('#rNext').value; if (!next) return ferr('Elige la próxima fecha.');
        const tpl = { type, amount: Math.round(amount * 100) / 100, accountId, note: name, tags: [] };
        if (type === 'transfer') { const to = $('#rTo').value; if (!to || to === accountId) return ferr('Elige una cuenta de destino distinta.'); tpl.toAccountId = to; const A = accById(accountId), B = accById(to); tpl.toAmount = A.currency === B.currency ? tpl.amount : Math.round(conv(tpl.amount, A.currency, B.currency) * 100) / 100; }
        else tpl.categoryId = cat || otherCat(type).id;
        const o = { name: name || (type === 'transfer' ? 'Transferencia' : catById(tpl.categoryId).name), tpl, freq: $('#rFreq').value, interval: Math.max(1, parseInt($('#rInt').value) || 1), day: parseYmd(next).getDate(), next, end: $('#rEnd').value, active: $('#rAct').checked };
        if (isEdit) Object.assign(r, o); else S.recurring.push(Object.assign({ id: 'r_' + uid() }, o));
        runRecurring(); save(); closeSheet(); render(); toast(isEdit ? 'Recurrente guardado' : 'Recurrente creado');
      });
    }
  });
}

/* ---------- inversiones ---------- */
function openAssetNew(kind, watch) {
  const isC = kind === 'crypto';
  const canSearch = isC || yahooOK() || S.settings.finnhubKey;
  openSheet({
    title: watch ? (isC ? 'Seguir una criptomoneda' : 'Seguir una acción o ETF') : isC ? 'Añadir criptomoneda' : 'Añadir acción o ETF', html: `<div class="form">
    ${canSearch ? `<input class="inp" type="search" id="aQ" placeholder="${isC ? 'Busca: bitcoin, ETH, solana…' : 'Busca: Apple, Inditex, SAN.MC, VWCE…'}" autocomplete="off" aria-label="Buscar">
      <div class="results" id="aRes"><div class="empty small">${isC ? 'Escribe para buscar entre miles de criptomonedas.' : 'Escribe el nombre o el ticker.'}</div></div>`
        : `<div class="card stack"><b>Sin buscador de acciones</b><span class="note">Configura una fuente de precios para buscar y actualizar solas. Mientras, puedes añadirla a mano con precio manual.</span><button class="btn sm" data-go="more/prices">Configurar fuente de precios</button></div>`}
    <button class="btn block" id="aManual">Añadir a mano (ticker propio)</button></div>`,
    onMount() {
      $('#aManual').addEventListener('click', () => openAssetDetails({ kind, symbol: '', name: '', provider: isC ? 'auto' : 'manual', watch }, true));
      const q = $('#aQ'); if (!q) return; q.focus();
      let t, seq = 0;
      q.addEventListener('input', () => {
        clearTimeout(t); const v = q.value.trim(); if (v.length < 2) return;
        t = setTimeout(async () => {
          const my = ++seq; $('#aRes').innerHTML = '<div class="empty small">Buscando…</div>';
          try {
            const res = isC ? await searchCrypto(v) : await searchStocks(v); if (my !== seq) return;
            UI._res = res;
            $('#aRes').innerHTML = res.length ? res.map((r, i) => `<button class="row" data-pick="${i}">${ico(esc(r.symbol.split('.')[0].slice(0, 4)), PALETTE[i % PALETTE.length], 'txt')}<div class="row-m"><div class="row-t">${esc(r.name)}</div><div class="row-s">${esc(r.symbol)} · ${esc(r.sub || '')}</div></div></button>`).join('') : '<div class="empty small">Sin resultados. Prueba con el ticker o añádela a mano.</div>';
          } catch (e) { if (my === seq) $('#aRes').innerHTML = `<div class="empty small">No se pudo buscar (${esc(e.message)}). Puedes añadirla a mano.</div>`; }
        }, 380);
      });
      $('#aRes').addEventListener('click', e => { const b = e.target.closest('[data-pick]'); if (!b) return; const r = UI._res[+b.dataset.pick]; if (watch) { addWatch(kind, r); return; } openAssetDetails(Object.assign({ kind, provider: 'auto' }, r), false); });
    }
  });
}
function openAssetDetails(p, manual) {
  const isC = p.kind === 'crypto'; const base = S.settings.base;
  const accs = activeAccounts(); const defAcc = accs.find(a => a.type === (isC ? 'exchange' : 'broker'));
  openSheet({
    title: isC ? 'Nueva cripto' : 'Nueva acción o ETF', html: `<form class="form" id="f" autocomplete="off">
    ${manual ? `<div class="row2"><label class="field"><span>Ticker</span><input type="text" id="dSym" placeholder="${isC ? 'BTC' : 'SAN.MC'}" style="text-transform:uppercase"></label><label class="field"><span>Nombre</span><input type="text" id="dName" placeholder="${isC ? 'Bitcoin' : 'Banco Santander'}"></label></div>`
        : `<div class="goal-top">${ico(esc(String(p.symbol).split('.')[0].slice(0, 4)), PALETTE[5], 'txt')}<div class="row-m"><div class="row-t">${esc(p.name)}</div><div class="row-s">${esc(p.symbol)}${p.sub ? ' · ' + esc(p.sub) : ''}</div></div></div>`}
    ${!isC ? `<div class="row2"><label class="field"><span>Cotiza en</span>${ccySelect('dQccy', p.quoteCcy || (String(p.symbol).match(/\.(MC|DE|PA|AS|MI|BR|LS|F|VI)$/) ? 'EUR' : String(p.symbol).endsWith('.L') ? 'GBP' : 'USD'))}</label><label class="field"><span>Fuente del precio</span><div class="sel"><select id="dProv"><option value="auto">Automática</option><option value="yahoo">Yahoo (proxy)</option><option value="finnhub">Finnhub</option><option value="manual" ${p.provider === 'manual' ? 'selected' : ''}>Manual</option></select></div></label></div>` : ''}
    <label class="field"><span>¿Dónde la tienes? (opcional)</span>${accSelect('dAcc', defAcc ? defAcc.id : '', { none: 'Sin cuenta asignada' })}</label>
    <div class="eyebrow" style="margin-top:4px">Tu compra</div>
    <div class="row2"><label class="field"><span>Cantidad</span><input type="text" inputmode="decimal" id="dQty" placeholder="${isC ? '0,015' : '10'}"></label><label class="field"><span>Fecha</span><input type="date" id="dDate" value="${today()}"></label></div>
    <div class="row2"><label class="field"><span>Precio por unidad</span><input type="text" inputmode="decimal" id="dPx" placeholder="0,00"></label><label class="field"><span>Moneda del precio</span>${ccySelect('dCcy', base)}</label></div>
    <label class="field"><span>Comisión (opcional)</span><input type="text" inputmode="decimal" id="dFee" placeholder="0,00"></label>
    <p class="note" id="dHint" style="margin:0"></p>
    <label class="check"><input type="checkbox" id="dCash"><span>Restar lo pagado del saldo de esa cuenta</span></label>
    <label class="field" id="dManW" hidden><span>Precio actual (manual)</span><input type="text" inputmode="decimal" id="dMan" placeholder="Se usa si no hay fuente de precios"></label>
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">Añadir a la cartera</button></form>`,
    onMount() {
      const upd = () => { const prov = $('#dProv') ? $('#dProv').value : 'auto'; const fake = { kind: p.kind, symbol: ($('#dSym') ? $('#dSym').value : p.symbol).toUpperCase(), provider: prov, cgId: p.cgId }; $('#dManW').hidden = resolveProvider(fake) !== 'manual'; $('#dCash').closest('label').hidden = !$('#dAcc').value; };
      ['#dProv', '#dAcc', '#dSym'].forEach(s => { const el = $(s); if (el) el.addEventListener('input', upd); if (el) el.addEventListener('change', upd); }); upd();
      (async () => {
        try {
          if (isC && p.cgId) { const j = await fetchJSON(`https://api.coingecko.com/api/v3/simple/price?ids=${p.cgId}&vs_currencies=${base.toLowerCase()},usd`); const d = j[p.cgId]; const v = d && (d[base.toLowerCase()] || (d.usd && conv(d.usd, 'USD', base))); if (v && !$('#dPx').value) { $('#dPx').value = inputNum(Math.round(v * (v < 1 ? 1e6 : 100)) / (v < 1 ? 1e6 : 100)); $('#dHint').textContent = `Precio actual: ${fmtPrice(v, base)}. Cámbialo por el que pagaste.`; } }
          else if (!isC && S.settings.yahooProxy && p.symbol) { const j = await fetchJSON(proxyUrl('symbols=' + encodeURIComponent(p.symbol))); const q = (j.quotes || [])[0]; if (q && q.price > 0) { const [px, c] = normCcy(q.price, q.currency); $('#dQccy').value = c; if (!$('#dPx').value) { $('#dPx').value = inputNum(Math.round(px * 100) / 100); $('#dCcy').value = c; $('#dHint').textContent = `Precio actual: ${fmtPrice(px, c)}. Cámbialo por el que pagaste.`; } } }
        } catch (e) { }
      })();
      $('#f').addEventListener('submit', e => {
        e.preventDefault();
        const symbol = (manual ? $('#dSym').value : p.symbol).trim().toUpperCase(); if (!symbol) return ferr('Escribe el ticker.');
        const qty = parseQty($('#dQty').value);
        if (p.watch && !(qty > 0)) { addWatch(p.kind, { symbol, name: manual ? ($('#dName').value.trim() || symbol) : p.name, cgId: p.cgId, quoteCcy: $('#dQccy') ? $('#dQccy').value : 'USD', provider: $('#dProv') ? $('#dProv').value : 'auto' }); return; }
        if (!(qty > 0)) return ferr('Escribe cuántas tienes.');
        const price = parseMoney($('#dPx').value); if (!(price >= 0) || !isFinite(price)) return ferr('Escribe el precio por unidad (puede ser 0 si fue un regalo).');
        const fee = parseMoney($('#dFee').value) || 0; const accId = $('#dAcc').value;
        const a = { id: 's_' + uid(), kind: p.kind, symbol, name: manual ? ($('#dName').value.trim() || symbol) : p.name, cgId: isC ? (p.cgId || CG_IDS[symbol] || '') : '', provider: isC ? 'auto' : $('#dProv').value, quoteCcy: isC ? 'USD' : $('#dQccy').value, accountId: accId, archived: false, ops: [] };
        const man = parseMoney($('#dMan').value); if (man > 0) { a.manualPrice = man; a.manualAt = Date.now(); if (isC) a.quoteCcy = base; }
        if (isC && !a.cgId && man > 0) a.provider = 'auto';
        a.ops.push({ id: uid(), side: price === 0 ? 'reward' : 'buy', qty, price, fee: Math.abs(fee), ccy: $('#dCcy').value, date: $('#dDate').value || today(), cashAccountId: accId && $('#dCash').checked ? accId : '' });
        const ex = S.assets.find(z => z.kind === a.kind && z.symbol === symbol && z.accountId === accId && !z.archived);
        if (ex) { ex.ops.push(a.ops[0]); toast(`Compra añadida a tu ${symbol}`); } else { S.assets.push(a); toast(`${symbol} añadida a tu cartera`); }
        save(); closeSheet(); if (UI.route !== 'inv') go('inv', { reset: true }); else render(); restartFeeds();
      });
    }
  });
}
function opLabel(o) { return { buy: 'Compra', sell: 'Venta', reward: 'Recompensa / staking', out: 'Salida / comisión' }[o.side] || o.side; }
function openAsset(id) {
  const a = assetById(id); if (!a) return;
  const draw = () => {
    const P = UI.P || portfolio(); const r = P.assets.find(z => z.x.id === id) || { h: holding(a), value: 0, pnl: 0, pnlPct: null, pr: priceOf(a) };
    const pr = r.pr; const tk = (PX.ticks[id] || []).map(t => t[1]);
    const share = P.assetsTotal > 0 ? r.value / P.assetsTotal * 100 : 0; const prov = resolveProvider(a);
    const ops = a.ops.slice().sort((x, y) => x.date < y.date ? 1 : -1);
    return `<div class="stack">
      <div class="hstack">${ico(assetTag(a), assetColor(a), 'txt')}<div class="row-m"><div class="row-t">${esc(a.symbol)}</div><div class="row-s">${a.kind === 'crypto' ? 'Criptomoneda' : 'Acción / ETF'}${a.accountId && accById(a.accountId) ? ' · ' + esc(accById(a.accountId).name) : ''}</div></div></div>
      <div class="hero-num" style="font-size:36px">${pr ? fmtPrice(pr.p, pr.ccy) : 'Sin precio'}</div>
      <div class="hero-sub">${pr && pr.ch != null && pr.src !== 'manual' ? `<span class="chip ${pcls(pr.ch)}">${fmtPct(pr.ch)} ${a.kind === 'crypto' ? '24 h' : 'hoy'}</span>` : ''}${pr && pr.ccy !== S.settings.base ? `<span class="chip">${fmtPrice(conv(pr.p, pr.ccy), S.settings.base)}</span>` : ''}<span class="chip">${pr ? (pr.src === 'manual' ? 'Precio manual' : `${PROV_L[pr.src] || pr.src} · ${ago(pr.t)}`) : PROV_L[prov]}</span></div>
      <div class="seg" id="histSeg">${Object.keys(RANGES).map(k => `<button type="button" data-rg="${k}" aria-pressed="${UI.histRange === k}">${k}</button>`).join('')}</div>
      <div id="histBox" class="card" style="padding:10px 8px 4px">${HIST[id + UI.histRange] ? histHtml(a, HIST[id + UI.histRange].pts) : '<div class="empty small">Cargando gráfico…</div>'}</div>
      ${tk.length > 2 ? `<div class="note">En directo desde que abriste la app:</div>${spark(tk, 40)}` : ''}
      ${a.watch ? '' : `<dl class="kv"><dt>Tienes</dt><dd class="num amt">${fmtQty(r.h.qty)} ${esc(a.symbol)}</dd><dt>Valor</dt><dd class="num amt">${fmt(r.value)}</dd><dt>Precio medio de compra</dt><dd class="num">${r.h.qty ? fmtPrice(r.h.avg, S.settings.base) : '—'}</dd><dt>Coste (lo que pusiste)</dt><dd class="num amt">${fmt(r.h.cost)}</dd>
      <dt>Rentabilidad</dt><dd class="num amt ${pcls(r.pnl)}">${fmt(r.pnl, null, { sign: true })} · ${fmtPct(r.pnlPct)}</dd>${r.h.realized ? `<dt>Ganancia realizada</dt><dd class="num amt ${pcls(r.h.realized)}">${fmt(r.h.realized, null, { sign: true })}</dd>` : ''}<dt>Peso en tu cartera</dt><dd class="num">${fmtPct(share, false)}</dd>${r.h.fees ? `<dt>Comisiones pagadas</dt><dd class="num amt">${fmt(r.h.fees)}</dd>` : ''}</dl>`}
      ${a.watch ? `<button class="btn primary block" data-action="op-new" data-id="${id}" data-side="buy">La he comprado: añadir compra</button>` : `<div class="row2"><button class="btn primary" data-action="op-new" data-id="${id}" data-side="buy">Comprar más</button><button class="btn" data-action="op-new" data-id="${id}" data-side="sell">Vender</button></div>`}
      <div class="sec-h"><h2>Operaciones</h2><button class="link" data-action="op-new" data-id="${id}" data-side="reward">+ Otra</button></div>
      <div class="list">${ops.map(o => `<button class="row" data-action="op-edit" data-id="${id}" data-op="${o.id}"><div class="row-m"><div class="row-t">${opLabel(o)}</div><div class="row-s">${shortDate(o.date)}${o.cashAccountId && accById(o.cashAccountId) ? ' · ' + esc(accById(o.cashAccountId).name) : ''}</div></div><div class="row-r"><span class="num amt">${o.side === 'sell' || o.side === 'out' ? '−' : '+'}${fmtQty(o.qty)}</span><span class="row-s">${o.price ? '@ ' + fmtPrice(o.price, o.ccy) : ''}${o.fee ? ` · com. ${fmt(o.fee, o.ccy)}` : ''}</span></div></button>`).join('') || '<div class="empty small">Sin operaciones</div>'}</div>
      <button class="btn block" data-action="asset-edit" data-id="${id}">Editar activo</button></div>`;
  };
  const loadHist = async () => {
    const rg = UI.histRange; const box = () => $('#histBox');
    try { const pts = await priceHistory(a, rg); if (box() && UI.histRange === rg) { box().innerHTML = histHtml(a, pts); bindScrub(); } }
    catch (e) { if (box()) box().innerHTML = `<div class="empty small">No hay gráfico: ${esc(e.message)}</div>`; }
  };
  const bindSeg = () => { const sg = $('#histSeg'); if (sg) sg.onclick = e => { const b = e.target.closest('[data-rg]'); if (!b) return; UI.histRange = b.dataset.rg; $$('#histSeg button').forEach(x => x.setAttribute('aria-pressed', String(x.dataset.rg === UI.histRange))); $('#histBox').innerHTML = '<div class="empty small">Cargando gráfico…</div>'; loadHist(); }; bindScrub(); };
  openSheet({ title: a.name || a.symbol, html: `<div id="astLive">${draw()}</div>`, onMount: () => { bindSeg(); loadHist(); }, live: () => { const el = $('#astLive'); if (el && !UI.scrubbing) { el.innerHTML = draw(); bindSeg(); } } });
}
function openOpForm(assetId, op, side) {
  const a = assetById(assetId); const isEdit = !!op; const base = S.settings.base;
  const pr = priceOf(a);
  const x = op ? Object.assign({}, op) : { side: side || 'buy', qty: '', price: pr && side !== 'reward' ? Math.round(conv(pr.p, pr.ccy, base) * (pr.p < 1 ? 1e6 : 100)) / (pr.p < 1 ? 1e6 : 100) : '', fee: '', ccy: base, date: today(), cashAccountId: '' };
  let sd = x.side; const h = holding(a);
  openSheet({
    title: `${isEdit ? 'Editar' : 'Nueva'} operación · ${a.symbol}`, html: `<form class="form" id="f" autocomplete="off">
    <div class="seg" id="oSide">${[['buy', 'Compra'], ['sell', 'Venta'], ['reward', 'Recompensa'], ['out', 'Salida']].map(([k, l]) => `<button type="button" data-k="${k}" aria-pressed="${sd === k}">${l}</button>`).join('')}</div>
    <div class="row2"><label class="field"><span>Cantidad</span><input type="text" inputmode="decimal" id="oQty" value="${x.qty !== '' ? inputNum(x.qty) : ''}" placeholder="0"></label><label class="field"><span>Fecha</span><input type="date" id="oDate" value="${x.date}"></label></div>
    <p class="note" style="margin:-4px 0 0">Tienes ${fmtQty(h.qty)} ${esc(a.symbol)}. <button type="button" class="link small" id="oAll">Usar todo</button></p>
    <div class="row2" id="oPxW"><label class="field"><span>Precio por unidad</span><input type="text" inputmode="decimal" id="oPx" value="${x.price !== '' ? inputNum(x.price) : ''}"></label><label class="field"><span>Moneda</span>${ccySelect('oCcy', x.ccy || base)}</label></div>
    <label class="field" id="oFeeW"><span>Comisión</span><input type="text" inputmode="decimal" id="oFee" value="${x.fee ? inputNum(x.fee) : ''}" placeholder="0,00"></label>
    <label class="field" id="oCashW"><span id="oCashL">Cuenta del dinero</span>${accSelect('oCash', x.cashAccountId || '', { none: 'No mover dinero de ninguna cuenta' })}</label>
    <p class="note" id="oHint" style="margin:0"></p>
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">${isEdit ? 'Guardar' : 'Añadir operación'}</button>${isEdit ? `<button type="button" class="btn danger block" data-action="op-del" data-id="${assetId}" data-op="${op.id}" data-confirm="¿Seguro? Toca otra vez">Eliminar operación</button>` : ''}</form>`,
    onMount() {
      const s = () => {
        $('#oPxW').hidden = sd === 'reward' || sd === 'out'; $('#oFeeW').hidden = sd === 'reward'; $('#oCashW').hidden = sd === 'reward' || sd === 'out';
        $('#oCashL').textContent = sd === 'sell' ? 'Ingresar lo cobrado en' : 'Pagado desde';
        $('#oHint').textContent = sd === 'reward' ? 'Recompensas, staking, airdrops o regalos: suman cantidad sin coste.' : sd === 'out' ? 'Envíos a otra wallet, comisiones de red o pérdidas: restan cantidad sin contar como venta.' : '';
      };
      $('#oSide').addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; sd = b.dataset.k; $$('#oSide button').forEach(z => z.setAttribute('aria-pressed', String(z.dataset.k === sd))); s(); });
      $('#oAll').addEventListener('click', () => { $('#oQty').value = inputNum(h.qty + (isEdit && (op.side === 'sell' || op.side === 'out') ? Number(op.qty) : 0)); });
      s();
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const qty = parseQty($('#oQty').value); if (!(qty > 0)) return ferr('Escribe la cantidad.');
        const price = sd === 'reward' || sd === 'out' ? 0 : parseMoney($('#oPx').value); if (!(price >= 0) || !isFinite(price)) return ferr('Escribe el precio por unidad.');
        if ((sd === 'sell' || sd === 'out') && qty > h.qty + (isEdit && (op.side === 'sell' || op.side === 'out') ? Number(op.qty) : 0) + 1e-9) return ferr(`No puedes ${sd === 'sell' ? 'vender' : 'sacar'} más de lo que tienes (${fmtQty(h.qty)}).`);
        const o = { id: op ? op.id : uid(), side: sd, qty, price, fee: sd === 'reward' ? 0 : Math.abs(parseMoney($('#oFee').value) || 0), ccy: $('#oCcy').value, date: $('#oDate').value || today(), cashAccountId: sd === 'buy' || sd === 'sell' ? $('#oCash').value : '' };
        if (isEdit) { const i = a.ops.findIndex(z => z.id === op.id); a.ops[i] = o; } else a.ops.push(o);
        if (a.watch && (sd === 'buy' || sd === 'reward')) a.watch = false;
        save(); closeSheet(); render(); openAsset(assetId); toast('Operación guardada');
      });
    }
  });
}
function openAssetEdit(id) {
  const a = assetById(id); let color = assetColor(a); const isC = a.kind === 'crypto';
  openSheet({
    title: 'Editar ' + a.symbol, html: `<form class="form" id="f" autocomplete="off">
    <div class="row2"><label class="field"><span>Ticker</span><input type="text" id="eSym" value="${esc(a.symbol)}"></label><label class="field"><span>Nombre</span><input type="text" id="eName" value="${esc(a.name || '')}"></label></div>
    <label class="field"><span>Cuenta donde está</span>${accSelect('eAcc', a.accountId || '', { none: 'Sin cuenta asignada' })}</label>
    ${isC ? `<div class="row2"><label class="field"><span>Fuente del precio</span><div class="sel"><select id="eProv"><option value="auto" ${a.provider !== 'coingecko' && a.provider !== 'manual' ? 'selected' : ''}>Binance + CoinGecko</option><option value="coingecko" ${a.provider === 'coingecko' ? 'selected' : ''}>Solo CoinGecko</option><option value="manual" ${a.provider === 'manual' ? 'selected' : ''}>Manual</option></select></div></label><label class="field"><span>ID en CoinGecko</span><input type="text" id="eCg" value="${esc(a.cgId || '')}" placeholder="bitcoin"></label></div>`
        : `<div class="row2"><label class="field"><span>Fuente del precio</span><div class="sel"><select id="eProv">${[['auto', 'Automática'], ['yahoo', 'Yahoo (proxy)'], ['finnhub', 'Finnhub'], ['manual', 'Manual']].map(([k, l]) => `<option value="${k}" ${(a.provider || 'auto') === k ? 'selected' : ''}>${l}</option>`).join('')}</select></div></label><label class="field"><span>Cotiza en</span>${ccySelect('eQ', a.quoteCcy || 'USD')}</label></div>`}
    <div class="row2"><label class="field"><span>Precio manual</span><input type="text" inputmode="decimal" id="eMan" value="${a.manualPrice ? inputNum(a.manualPrice) : ''}" placeholder="Opcional"></label>${isC ? `<label class="field"><span>Moneda del precio manual</span>${ccySelect('eQ', a.manualPrice ? (a.quoteCcy || 'USD') : S.settings.base)}</label>` : '<div></div>'}</div>
    ${swatchesHtml(color)}
    <label class="check"><input type="checkbox" id="eArch" ${a.archived ? 'checked' : ''}><span>Archivar (deja de contar y se oculta)</span></label>
    <div class="err" id="fErr"></div><button class="btn primary block" type="submit">Guardar</button>${deleteBtn('asset-del', id, 'Eliminar activo y sus operaciones')}</form>`,
    onMount(root) {
      bindSwatches(root, c => color = c);
      $('#f').addEventListener('submit', e => {
        e.preventDefault(); const sym = $('#eSym').value.trim().toUpperCase(); if (!sym) return ferr('El ticker no puede estar vacío.');
        const man = parseMoney($('#eMan').value);
        Object.assign(a, { symbol: sym, name: $('#eName').value.trim() || sym, accountId: $('#eAcc').value, provider: $('#eProv').value, color, archived: $('#eArch').checked, quoteCcy: $('#eQ').value });
        if (isC) { a.cgId = $('#eCg').value.trim(); if (!(man > 0)) a.quoteCcy = 'USD'; }
        if (man > 0) { if (man !== a.manualPrice) a.manualAt = Date.now(); a.manualPrice = man; } else { delete a.manualPrice; }
        delete S.cache.prices[a.id]; save(); closeSheet(); render(); restartFeeds(); toast('Activo guardado');
      });
    }
  });
}

/* ---------- estado de precios ---------- */
function openPriceStatus() {
  const draw = () => {
    const st = PX.st; const ln = (name, s, detail) => `<div class="row"><div class="row-m"><div class="row-t">${name}</div><div class="row-s">${detail}</div></div><span class="chip ${s === 'ok' || s === 'live' ? 'pos' : s === 'error' ? 'neg' : ''}">${{ ok: 'OK', live: 'En directo', error: 'Error', loading: 'Cargando', connecting: 'Conectando', off: 'Apagado', idle: 'Sin uso' }[s] || s}</span></div>`;
    const errs = Object.values(st.err);
    return `<div class="stack"><div class="list">
      ${ln('Binance (cripto, tick a tick)', st.binance, S.settings.binance ? 'WebSocket público, sin clave' : 'Desactivado en Fuentes de precios')}
      ${ln('CoinGecko (cripto, cada minuto)', st.cg, 'Cubre cualquier moneda y el cambio en 24 h')}
      ${ln('Acciones', S.settings.yahooProxy ? st.yahoo : S.settings.finnhubKey ? st.finnhub : 'idle', S.settings.yahooProxy ? 'Yahoo Finance vía tu proxy' : S.settings.finnhubKey ? 'Finnhub' : 'Sin fuente: precio manual')}
      ${ln('Divisas', st.fx, S.cache.fx ? `${esc(S.cache.fx.src)} · ${ago(S.cache.fx.t)}` : 'Tipos aproximados')}
    </div>
    ${errs.length ? `<div class="card err">${errs.map(esc).join('<br>')}</div>` : ''}
    <p class="note" style="margin:0">Último precio recibido: ${ago(st.last)}.</p>
    <div class="row2"><button class="btn" data-action="reconnect">Reconectar</button><button class="btn" data-go="more/prices">Configurar</button></div></div>`;
  };
  openSheet({ title: 'Precios en tiempo real', html: `<div id="psLive">${draw()}</div>`, live: () => { const el = $('#psLive'); if (el) el.innerHTML = draw(); } });
}

/* ---------- archivos ---------- */
function download(name, text, type) {
  const blob = new Blob([text], { type }); const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = name; document.body.appendChild(a); a.click();
  setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 3000);
}
function exportJson() { const o = Object.assign({}, S, { cache: { fx: S.cache.fx, prices: {} }, exportedAt: new Date().toISOString(), app: 'mision-finanzas' }); return JSON.stringify(o, null, 1); }
function exportCsv() {
  const q = v => { const s = String(v ?? ''); return /[;"\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
  const n = v => String(Math.round(v * 100) / 100).replace('.', ',');
  const lines = [['Fecha', 'Tipo', 'Importe', 'Moneda', 'Cuenta', 'Cuenta destino', 'Importe destino', 'Categoría', 'Concepto', 'Etiquetas'].join(';')];
  for (const t of sortTx(S.txs)) { const a = accById(t.accountId), b = accById(t.toAccountId), c = catById(t.categoryId); lines.push([t.date, TYPE_L[t.type], n(t.type === 'expense' ? -t.amount : t.amount), a?.currency, a?.name, b?.name || '', t.toAmount != null ? n(t.toAmount) : '', c?.name || '', t.note, (t.tags || []).join(', ')].map(q).join(';')); }
  return '﻿' + lines.join('\r\n');
}
function pickFile(accept, cb) { const f = $('#fileIn'); f.value = ''; f.accept = accept; f.onchange = () => { if (f.files[0]) cb(f.files[0]); }; f.click(); }

/* ---------- acciones ---------- */
function arm(el) {
  // Primer toque: el botón pasa a rojo con «Pulsa otra vez para confirmar» y una barra de cuenta atrás.
  // El texto largo de data-confirm ya no se mete en el botón (no cabía): se muestra como aviso.
  const html = el.innerHTML; el.classList.add('armed');
  const lbl = el.offsetWidth < 150 ? '¿Seguro?' : el.offsetWidth < 230 ? 'Pulsa para confirmar' : 'Pulsa otra vez para confirmar';
  el.innerHTML = `<span class="arm-t">${svg('trash')}${lbl}</span><i class="arm-bar"></i>`;
  try { const H = window.Capacitor && Capacitor.Plugins && Capacitor.Plugins.Haptics; if (H) H.impact({ style: 'MEDIUM' }); } catch (e) { }
  clearTimeout(el._t); el._t = setTimeout(() => { el.classList.remove('armed'); el.innerHTML = html; }, 3500);
}
function confirmSheet(title, text, btn, fn, danger = true) {
  openSheet({ title, html: `<div class="stack"><p style="margin:0">${text}</p><button class="btn ${danger ? 'danger' : 'primary'} block" id="cOk">${btn}</button><button class="btn block" data-action="close-sheet">Cancelar</button></div>`, onMount() { $('#cOk').addEventListener('click', fn); } });
}
const ACT = {
  back: () => back(),
  'close-sheet': () => closeSheet(),
  privacy: () => { S.settings.privacy = !S.settings.privacy; save(); chrome(); },
  'toggle-theme': () => { const o = ['auto', 'dark', 'light']; S.settings.theme = o[(o.indexOf(S.settings.theme) + 1) % 3]; applyTheme(); save(); chrome(); toast('Tema ' + { auto: 'automático', dark: 'oscuro', light: 'claro' }[S.settings.theme]); if (UI.route === 'more/settings') render(); },
  theme: el => { S.settings.theme = el.dataset.k; applyTheme(); save(); render(); },
  'price-status': () => openPriceStatus(),
  reconnect: () => { PX.bTry = 0; PX.fTry = 0; PX.st.err = {}; restartFeeds(); refreshFx(true); toast('Reconectando…'); },
  'start-fresh': () => confirmSheet('Empezar con tus datos', 'Se borran los datos de ejemplo y empiezas de cero con las categorías por defecto. Luego te pediremos tu primera cuenta.', 'Borrar ejemplo y empezar', () => { const keep = S.settings; S = blankState(); S.settings = Object.assign(S.settings, { theme: keep.theme, base: keep.base, finnhubKey: keep.finnhubKey, yahooProxy: keep.yahooProxy, binance: keep.binance, refreshSec: keep.refreshSec }); saveNow(); closeSheet(); go('home', { reset: true }); restartFeeds(); openAccountForm(); }, false),
  'load-demo': () => { const load = () => { const keep = S.settings; S = demoState(); S.settings = Object.assign(S.settings, { theme: keep.theme, finnhubKey: keep.finnhubKey, yahooProxy: keep.yahooProxy }); saveNow(); closeSheet(); go('home', { reset: true }); restartFeeds(); toast('Datos de ejemplo cargados'); }; if (!S.demo && (S.txs.length || S.accounts.length)) confirmSheet('Cargar datos de ejemplo', 'Esto sustituye TODOS tus datos actuales. Haz antes una copia de seguridad si quieres conservarlos.', 'Sustituir por el ejemplo', load); else load(); },
  wipe: () => { S = blankState(); saveNow(); go('home', { reset: true }); restartFeeds(); toast('Datos borrados'); },
  'add-tx': () => openTxForm(null, UI.route === 'txs' && UI.txF.acc !== 'all' ? { accountId: UI.txF.acc } : {}),
  'tx-edit': el => { const t = S.txs.find(x => x.id === el.dataset.id); if (t) openTxForm(t); },
  'tx-del': el => { S.txs = S.txs.filter(x => x.id !== el.dataset.id); save(); closeSheet(); render(); toast('Movimiento eliminado'); },
  'tx-dup': el => { const t = S.txs.find(x => x.id === el.dataset.id); if (!t) return; const c = Object.assign({}, t, { id: uid(), date: today() }); delete c.recId; delete c.imp; S.txs.push(c); save(); closeSheet(); render(); toast('Duplicado con fecha de hoy'); },
  'tx-more': () => { UI.txLimit += 300; $('#txList').innerHTML = txListHtml(); },
  txm: el => { UI.txF.month = addMonths(UI.txF.month, +el.dataset.d); UI.txLimit = 300; render(); },
  'txm-all': () => { UI.txF.month = UI.txF.month === 'all' ? monthKey(today()) : 'all'; render(); },
  period: el => { S.settings.period = el.dataset.k; save(); render(); },
  'cat-txs': el => { if (!el.dataset.id) return; closeSheet(); go('txs', { reset: true, cat: el.dataset.id, month: el.dataset.month }); },
  invf: el => { UI.invF = el.dataset.k; render(); },
  stm: el => { UI.statsMonth = addMonths(UI.statsMonth, +el.dataset.d); render(); },
  catkind: el => { UI.catKind = el.dataset.k; render(); },
  'acc-new': () => openAccountForm(),
  'acc-open': el => openAccount(el.dataset.id),
  'acc-edit': el => openAccountForm(accById(el.dataset.id)),
  'acc-del': el => { deleteAccount(el.dataset.id); save(); closeSheet(); render(); toast('Cuenta eliminada'); },
  'acc-adjust': el => openAdjust(el.dataset.id),
  'acc-transfer': el => openTxForm(null, { type: 'transfer', accountId: el.dataset.id }),
  'acc-txs': el => { closeSheet(); go('txs', { reset: true, acc: el.dataset.id }); },
  'acc-move': el => { const list = activeAccounts(); const i = list.findIndex(a => a.id === el.dataset.id); const j = i + +el.dataset.d; if (j < 0 || j >= list.length) return; [list[i], list[j]] = [list[j], list[i]]; list.forEach((a, k) => a.order = k); save(); render(); },
  'goal-new': () => openGoalForm(),
  'goal-open': el => openGoal(el.dataset.id),
  'goal-edit': el => openGoalForm(goalById(el.dataset.id)),
  'goal-del': el => { S.goals = S.goals.filter(g => g.id !== el.dataset.id); save(); closeSheet(); render(); toast('Objetivo eliminado'); },
  'goal-sub': el => { const g = goalById(el.dataset.id); const v = parseMoney($('#gAdd').value); if (!(v > 0)) return; g.manual = Math.max(0, Math.round(((Number(g.manual) || 0) - v) * 100) / 100); save(); render(); openGoal(g.id); toast('Cantidad restada'); },
  'group-new': () => openGroupForm(),
  'group-open': el => openGroup(el.dataset.id),
  'group-edit': el => openGroupForm(groupById(el.dataset.id)),
  'group-del': el => { S.groups = S.groups.filter(g => g.id !== el.dataset.id); S.goals.forEach(g => { if (g.source && g.source.t === 'group' && g.source.id === el.dataset.id) g.source = { t: 'nw' }; }); save(); closeSheet(); render(); toast('Bloque eliminado'); },
  'group-move': el => { const i = S.groups.findIndex(g => g.id === el.dataset.id); const j = i + +el.dataset.d; if (j < 0 || j >= S.groups.length) return; [S.groups[i], S.groups[j]] = [S.groups[j], S.groups[i]]; save(); render(); },
  'home-move': el => { const h = S.settings.home; const i = +el.dataset.i, j = i + +el.dataset.d; if (j < 0 || j >= h.length) return; [h[i], h[j]] = [h[j], h[i]]; save(); render(); },
  'cat-new': el => openCatForm(null, el.dataset.k),
  'cat-new-inline': () => {
    const root = $('#sheetBody'); const kind = root._type && root._type() === 'income' ? 'income' : 'expense';
    const keep = { type: kind, amount: Math.abs(parseMoney($('#tAmt').value)) || '', accountId: $('#tAcc').value, date: $('#tDate').value, note: $('#tNote').value, tags: $('#tTags').value.split(',').map(s => s.trim()).filter(Boolean) };
    openCatForm(null, kind, id => { closeSheet(); render(); openTxForm(null, Object.assign(keep, { categoryId: id })); toast('Categoría creada'); });
  },
  'cat-edit': el => openCatForm(catById(el.dataset.id)),
  'cat-del': el => { const c = catById(el.dataset.id); const same = S.categories.filter(x => x.kind === c.kind); if (same.length <= 1) { toast('Necesitas al menos una categoría de este tipo'); return; } S.categories = S.categories.filter(x => x.id !== c.id); const o = otherCat(c.kind); S.txs.forEach(t => { if (t.categoryId === c.id) t.categoryId = o.id; }); S.recurring.forEach(r => { if (r.tpl.categoryId === c.id) r.tpl.categoryId = o.id; }); save(); closeSheet(); render(); toast('Categoría eliminada'); },
  'rec-new': () => openRecForm(),
  'rec-edit': el => openRecForm(S.recurring.find(r => r.id === el.dataset.id)),
  'rec-del': el => { S.recurring = S.recurring.filter(r => r.id !== el.dataset.id); save(); closeSheet(); render(); toast('Recurrente eliminado (los movimientos ya creados se quedan)'); },
  'asset-new': el => openAssetNew(el.dataset.kind),
  'asset-open': el => openAsset(el.dataset.id),
  'asset-edit': el => openAssetEdit(el.dataset.id),
  'asset-del': el => { S.assets = S.assets.filter(a => a.id !== el.dataset.id); delete S.cache.prices[el.dataset.id]; S.groups.forEach(g => g.items = g.items.filter(it => !(it.t === 'asset' && it.id === el.dataset.id))); save(); closeSheet(); render(); restartFeeds(); toast('Activo eliminado'); },
  'op-new': el => openOpForm(el.dataset.id, null, el.dataset.side),
  'op-edit': el => { const a = assetById(el.dataset.id); openOpForm(a.id, a.ops.find(o => o.id === el.dataset.op)); },
  'op-del': el => { const a = assetById(el.dataset.id); a.ops = a.ops.filter(o => o.id !== el.dataset.op); save(); closeSheet(); render(); openAsset(a.id); toast('Operación eliminada'); },
  'fav-add': () => { const c = $('#favAdd').value; if (c && !S.settings.favCcy.includes(c)) { S.settings.favCcy.push(c); save(); if (!isFiat(c)) { pollCrypto(); PX.bKey = ''; connectBinance(); } render(); } },
  'fav-del': el => { S.settings.favCcy = S.settings.favCcy.filter(c => c !== el.dataset.c); save(); render(); },
  'cv-swap': () => { const f = $('#cvFrom').value; $('#cvFrom').value = $('#cvTo').value; $('#cvTo').value = f; updateConv(); },
  'fx-refresh': () => { refreshFx(true).then(() => { toast(PX.st.fx === 'ok' ? 'Tipos de cambio actualizados' : 'No se pudieron actualizar'); render(); }); },
  'proxy-test': async () => { const el = $('#proxyRes'); S.settings.yahooProxy = $('#prProxy').value.trim(); save(); if (!S.settings.yahooProxy) { el.textContent = 'Pega primero la URL.'; return; } el.textContent = 'Probando…'; try { el.textContent = '✓ ' + await testProxy(); el.className = 'small pos'; restartFeeds(); } catch (e) { el.textContent = 'No funciona: ' + e.message; el.className = 'small neg'; } },
  'export-json': () => { download(`mision-finanzas-${today()}.json`, exportJson(), 'application/json'); toast('Copia descargada'); },
  'export-csv': () => { download(`movimientos-${today()}.csv`, exportCsv(), 'text/csv;charset=utf-8'); toast('CSV descargado'); },
  'copy-json': async () => { try { await navigator.clipboard.writeText(exportJson()); toast('Copiado al portapapeles'); } catch (e) { toast('No se pudo copiar en este navegador'); } },
  'import-json': () => pickFile('.json,application/json', async f => { try { const o = JSON.parse(await f.text()); if (!o || !Array.isArray(o.accounts) || !Array.isArray(o.txs)) throw new Error('no parece una copia de Caudal'); confirmSheet('Restaurar copia', `El archivo tiene ${o.accounts.length} cuentas y ${o.txs.length} movimientos. Sustituirá todo lo que hay ahora en este dispositivo.`, 'Restaurar', () => { S = migrate(o); saveNow(); closeSheet(); applyTheme(); go('home', { reset: true }); restartFeeds(); toast('Copia restaurada'); }); } catch (e) { toast('Archivo no válido: ' + e.message); } }),
  'imp-file': () => pickFile('.csv,.txt,.xlsx,.xls,.ods,text/csv', startImport),
  'imp-reset': () => { UI.imp = null; render(); },
  'imp-go': () => doImport(),
};
document.addEventListener('click', e => {
  const tab = e.target.closest('[data-tab]'); if (tab) { closeSheet(); go(tab.dataset.tab, { reset: true }); return; }
  const g = e.target.closest('[data-go]'); if (g) { e.preventDefault(); if (sheetOpen()) closeSheet(); go(g.dataset.go); return; }
  const el = e.target.closest('[data-action]'); if (!el || el.disabled) return;
  if (el.dataset.confirm && !el.classList.contains('armed')) { e.preventDefault(); arm(el); return; }
  const fn = ACT[el.dataset.action]; if (fn) { e.preventDefault(); fn(el, e); }
});
document.addEventListener('keydown', e => { if (e.key === 'Escape' && sheetOpen()) closeSheet(); });

/* ---------- tema e inicio ---------- */
function applyTheme() {
  const th = S.settings.theme;
  if (th === 'auto') document.documentElement.removeAttribute('data-theme'); else document.documentElement.setAttribute('data-theme', th);
  requestAnimationFrame(() => { const bg = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim(); const m = $('meta[name="theme-color"]'); if (m && bg) m.setAttribute('content', bg); });
}
try { matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => S && applyTheme()); } catch (e) { }

function init() {
  S = load();
  if (!S) { S = demoState(); saveNow(); }
  else if (S.seeded === 2) { splitTrEtf(S); saveNow(); }
  applyTheme(); runRecurring();
  UI.txF.month = curMk(); UI.statsMonth = curMk();
  UI.route = TITLES[S.settings.startTab] ? S.settings.startTab : 'home';
  const h = location.hash.slice(1).replace('-', '/'); if (TITLES[h]) UI.route = h;
  if (S.settings.pinHash) { LOCK.on = true; LOCK.mode = 'unlock'; lockUI(); }
  render(); startPrices(); initLinks(); scheduleNotifs();
  if (NATIVE) document.documentElement.classList.add('native');
  if (Sync.on()) Sync.run();
  setTimeout(() => { recordSnapshot(portfolio()); saveNow(); }, 20000);
  window.addEventListener('scroll', () => $('#top').classList.toggle('scrolled', scrollY > 4), { passive: true });
  window.addEventListener('pagehide', () => { if (S) saveNow(); });
  if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) navigator.serviceWorker.register('sw.js').catch(() => { });
  if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => { });
}

