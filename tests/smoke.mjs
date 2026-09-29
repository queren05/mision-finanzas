// Prueba de humo: abre la app con datos de ejemplo, recorre todas las pantallas y formularios
// y falla si hay errores de JavaScript o scroll horizontal.
// Uso:  npm i -D playwright && npx playwright install chromium && node tests/smoke.mjs
import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const url = process.argv[2] || 'file://' + path.resolve(here, '../dist/index.html');
const b = await chromium.launch();
let failed = false;
for (const scheme of ['light', 'dark']) {
  const p = await b.newPage({ viewport: { width: 390, height: 844 }, colorScheme: scheme });
  const errs = [];
  p.on('pageerror', e => errs.push('PAGEERR ' + e.message));
  p.on('console', m => { if (m.type() === 'error' && !/Failed to load resource|net::|ERR_|WebSocket/.test(m.text())) errs.push('CONSOLE ' + m.text()); });
  await p.goto(url); await p.waitForTimeout(800);
  await p.evaluate(() => { localStorage.clear(); S = demoState(); saveNow(); render(); });
  const routes = await p.evaluate(() => Object.keys(TITLES));
  for (const r of routes) { await p.evaluate(r => go(r), r); await p.waitForTimeout(80); }
  await p.evaluate(() => {
    const f = [() => openTxForm(), () => openTxForm(S.txs.find(t => t.splits)), () => openAccountForm(), () => openAccount(S.accounts[0].id),
      () => openAdjust(S.accounts[0].id), () => openGoalForm(), () => openGoal(S.goals[0].id), () => openGroupForm(), () => openGroup(S.groups[0].id),
      () => openCatForm(S.categories[0]), () => openRecForm(S.recurring[0]), () => openTplForm(S.templates[0]), () => openAssetNew('crypto'),
      () => openAsset(S.assets[0].id), () => openOpForm(S.assets[0].id, null, 'sell'), () => openAssetEdit(S.assets[0].id), () => openCatStats(S.categories[0].id), () => openPriceStatus()];
    for (const fn of f) { fn(); closeSheet(); }
  });
  const n0 = await p.evaluate(() => S.txs.length);
  await p.evaluate(() => { localStorage.removeItem('mision.lastLink'); handleLink('mision://nuevo?importe=12,50&concepto=Mercadona'); });
  const added = await p.evaluate(n0 => S.txs.length - n0, n0);
  if (added !== 1) errs.push('El enlace mision://nuevo no apuntó el gasto');
  const q = await p.evaluate(() => parseQuick('3 café en efectivo ayer'));
  if (q.amount !== 3) errs.push('parseQuick falla');
  const ov = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth);
  if (ov > 0) errs.push('Scroll horizontal de ' + ov + 'px');
  console.log(`[${scheme}] ${routes.length} pantallas, ${errs.length ? errs.length + ' errores' : 'OK'}`);
  if (errs.length) { failed = true; console.log(errs.join('\n')); }
  await p.close();
}
await b.close();
process.exit(failed ? 1 : 0);
