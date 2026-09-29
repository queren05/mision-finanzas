'use strict';
/* =====================================================================
   MISIÓN FINANZAS — núcleo: utilidades, estado, cálculos
   Todo se guarda en este dispositivo (localStorage). Haz copias en Más › Copia de seguridad.
   ===================================================================== */

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
const uid = () => Math.random().toString(36).slice(2, 9) + Date.now().toString(36).slice(-4);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pad = n => String(n).padStart(2, '0');
const ymd = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const today = () => ymd(new Date());
const parseYmd = s => { const [y, m, d] = String(s).split('-').map(Number); return new Date(y, (m || 1) - 1, d || 1); };
const monthKey = s => String(s).slice(0, 7);
const addDays = (s, n) => { const d = parseYmd(s); d.setDate(d.getDate() + n); return ymd(d); };
const addMonths = (mk, n) => { const [y, m] = mk.split('-').map(Number); const d = new Date(y, m - 1 + n, 1); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}`; };
const daysInMonth = (y, m0) => new Date(y, m0 + 1, 0).getDate();
const monthEnd = mk => { const [y, m] = mk.split('-').map(Number); return `${mk}-${pad(daysInMonth(y, m - 1))}`; };
const sum = (arr, f = x => x) => arr.reduce((a, x) => a + (Number(f(x)) || 0), 0);
const clamp = (n, a, b) => Math.max(a, Math.min(b, n));

const MONTHS = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
const MONTHS_S = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
const WEEKDAYS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const cap = s => s ? s[0].toUpperCase() + s.slice(1) : s;
const monthLabel = mk => { const [y, m] = mk.split('-').map(Number); return `${cap(MONTHS[m - 1])} ${y}`; };
function dayLabel(s) {
  const t = today();
  if (s === t) return 'Hoy';
  if (s === addDays(t, -1)) return 'Ayer';
  if (s === addDays(t, 1)) return 'Mañana';
  const d = parseYmd(s);
  return `${cap(WEEKDAYS[d.getDay()])}, ${d.getDate()} ${MONTHS_S[d.getMonth()]}${d.getFullYear() !== new Date().getFullYear() ? ' ' + d.getFullYear() : ''}`;
}
const shortDate = s => { if (!s) return ''; const d = parseYmd(s); return `${d.getDate()} ${MONTHS_S[d.getMonth()]}${d.getFullYear() !== new Date().getFullYear() ? ' ' + String(d.getFullYear()).slice(2) : ''}`; };
function ago(ms) {
  if (!ms) return 'nunca';
  const s = Math.round((Date.now() - ms) / 1000);
  if (s < 10) return 'ahora';
  if (s < 60) return `hace ${s} s`;
  const m = Math.round(s / 60); if (m < 60) return `hace ${m} min`;
  const h = Math.round(m / 60); if (h < 48) return `hace ${h} h`;
  return `hace ${Math.round(h / 24)} días`;
}

/* ---------- números ---------- */
// Importes con convención española: "1.234,56", "12,5", "1500". Admite signo y paréntesis.
function parseMoney(v) {
  if (typeof v === 'number') return v;
  let s = String(v ?? '').trim().replace(/[\u2012-\u2015\u2212]/g, '-').replace(/[\s\u00a0\u20ac$\u00a3\u00a5]/g, '').replace(/[A-Za-z]/g, '');
  if (!s) return NaN;
  let neg = false;
  if (/^\(.*\)$/.test(s)) { neg = true; s = s.slice(1, -1); }
  if (s.endsWith('-')) { neg = true; s = s.slice(0, -1); }
  if (s.startsWith('+')) s = s.slice(1);
  if (s.startsWith('-')) { neg = true; s = s.slice(1); }
  const lc = s.lastIndexOf(','), ld = s.lastIndexOf('.');
  if (lc > -1 && ld > -1) s = lc > ld ? s.replace(/\./g, '').replace(',', '.') : s.replace(/,/g, '');
  else if (lc > -1) s = (s.match(/,/g).length > 1) ? s.replace(/,/g, '') : s.replace(',', '.');
  else if (ld > -1 && /^\d{1,3}(\.\d{3})+$/.test(s)) s = s.replace(/\./g, '');
  const n = Number(s);
  if (!isFinite(n)) return NaN;
  return neg ? -n : n;
}
// Cantidades (cripto, acciones): coma o punto como decimal, sin miles.
function parseQty(v) {
  if (typeof v === 'number') return v;
  const s = String(v ?? '').trim().replace(/\s/g, '').replace(',', '.');
  if (!s) return NaN;
  const n = Number(s);
  return isFinite(n) ? n : NaN;
}
const inputNum = n => (n === '' || n == null || isNaN(n)) ? '' : String(Math.round(n * 1e8) / 1e8).replace('.', ',');

let FIAT;
try { FIAT = new Set(Intl.supportedValuesOf('currency')); } catch (e) { FIAT = null; }
const COMMON_CCY = ['EUR', 'USD', 'GBP', 'CHF', 'JPY', 'CNY', 'CAD', 'AUD', 'MXN', 'ARS', 'COP', 'CLP', 'PEN', 'BRL', 'UYU', 'SEK', 'NOK', 'DKK', 'PLN', 'CZK', 'HUF', 'RON', 'BGN', 'TRY', 'MAD', 'AED', 'SAR', 'INR', 'KRW', 'HKD', 'SGD', 'THB', 'ZAR', 'NZD'];
const CCY_NAMES = { EUR: 'Euro', USD: 'Dólar estadounidense', GBP: 'Libra esterlina', CHF: 'Franco suizo', JPY: 'Yen japonés', CNY: 'Yuan chino', CAD: 'Dólar canadiense', AUD: 'Dólar australiano', MXN: 'Peso mexicano', ARS: 'Peso argentino', COP: 'Peso colombiano', CLP: 'Peso chileno', PEN: 'Sol peruano', BRL: 'Real brasileño', UYU: 'Peso uruguayo', SEK: 'Corona sueca', NOK: 'Corona noruega', DKK: 'Corona danesa', PLN: 'Esloti polaco', CZK: 'Corona checa', HUF: 'Forinto húngaro', RON: 'Leu rumano', BGN: 'Lev búlgaro', TRY: 'Lira turca', MAD: 'Dírham marroquí', AED: 'Dírham de EAU', SAR: 'Riyal saudí', INR: 'Rupia india', KRW: 'Won surcoreano', HKD: 'Dólar de Hong Kong', SGD: 'Dólar de Singapur', THB: 'Baht tailandés', ZAR: 'Rand sudafricano', NZD: 'Dólar neozelandés', BTC: 'Bitcoin', ETH: 'Ether' };
const isFiat = c => FIAT ? FIAT.has(c) : COMMON_CCY.includes(c);

const nfCache = new Map();
function nf(key, opts) { let f = nfCache.get(key); if (!f) { try { f = new Intl.NumberFormat('es-ES', opts); } catch (e) { f = new Intl.NumberFormat('es-ES', { maximumFractionDigits: 2 }); } nfCache.set(key, f); } return f; }
function fmt(n, ccy, o = {}) {
  ccy = ccy || S.settings.base;
  if (n == null || isNaN(n)) return '—';
  const dec = o.dec ?? (isFiat(ccy) ? (ccy === 'JPY' || ccy === 'KRW' || ccy === 'CLP' || (S && S.settings.hideCents && !o.cents) ? 0 : 2) : (Math.abs(n) >= 1000 ? 2 : Math.abs(n) >= 1 ? 4 : 8));
  let s;
  if (o.compact && Math.abs(n) >= 10000) s = nf('c' + ccy, { style: isFiat(ccy) ? 'currency' : 'decimal', currency: isFiat(ccy) ? ccy : undefined, notation: 'compact', maximumFractionDigits: 1 }).format(n) + (isFiat(ccy) ? '' : ' ' + ccy);
  else if (isFiat(ccy)) s = nf(ccy + dec, { style: 'currency', currency: ccy, minimumFractionDigits: dec, maximumFractionDigits: dec }).format(n);
  else s = nf('d' + dec, { minimumFractionDigits: 0, maximumFractionDigits: dec }).format(n) + ' ' + ccy;
  if (o.sign && n > 0) s = '+' + s;
  if (o.sign && n < 0 && !s.startsWith('-') && !s.startsWith('−')) s = '−' + s.replace('-', '');
  return s;
}
function fmtPrice(p, ccy) { const a = Math.abs(p); return fmt(p, ccy, { dec: a >= 1000 ? 2 : a >= 1 ? 2 : a >= 0.01 ? 4 : 8 }); }
const fmtQty = n => nf('q', { maximumFractionDigits: 8 }).format(n || 0);
const fmtPct = (n, sign = true) => (n == null || !isFinite(n)) ? '—' : (sign && n > 0 ? '+' : '') + nf('p', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n) + ' %';
const pcls = n => n > 0.00001 ? 'pos' : n < -0.00001 ? 'neg' : '';
const amt = (n, ccy, o = {}) => `<span class="amt num ${o.cls || ''}">${fmt(n, ccy, o)}</span>`;

/* ---------- constantes de dominio ---------- */
const ACC_TYPES = { corriente: 'Cuenta corriente', ahorro: 'Ahorro', efectivo: 'Efectivo', tarjeta: 'Tarjeta de crédito', exchange: 'Exchange / wallet cripto', broker: 'Bróker de bolsa', activo: 'Bien (casa, coche…)', deuda: 'Préstamo o hipoteca', otro: 'Otro' };
const ACC_ICONS = { corriente: '🏦', ahorro: '🐷', efectivo: '💶', tarjeta: '💳', exchange: '🪙', broker: '📊', activo: '🏠', deuda: '📉', otro: '💼' };
const PALETTE = ['#e4b3cb', '#8fb4ff', '#6fd49b', '#f0c46a', '#ff9f7a', '#b39cff', '#62cfd0', '#ff8686', '#c3d36a', '#d9a0f5', '#7ac8ff', '#f59fc4', '#a9b3c2'];
const STABLES = new Set(['USDT', 'USDC', 'DAI', 'FDUSD', 'TUSD', 'BUSD', 'USDE', 'PYUSD', 'EURC', 'EURT']);
const CG_IDS = { BTC: 'bitcoin', ETH: 'ethereum', SOL: 'solana', BNB: 'binancecoin', XRP: 'ripple', ADA: 'cardano', DOGE: 'dogecoin', USDT: 'tether', USDC: 'usd-coin', DOT: 'polkadot', AVAX: 'avalanche-2', LINK: 'chainlink', LTC: 'litecoin', TRX: 'tron', TON: 'the-open-network', SHIB: 'shiba-inu', PEPE: 'pepe', ATOM: 'cosmos', XLM: 'stellar', NEAR: 'near', SUI: 'sui', APT: 'aptos', ARB: 'arbitrum', OP: 'optimism', POL: 'polygon-ecosystem-token', BCH: 'bitcoin-cash', XMR: 'monero', ETC: 'ethereum-classic', HBAR: 'hedera-hashgraph', ICP: 'internet-computer', UNI: 'uniswap', AAVE: 'aave', RNDR: 'render-token', FET: 'fetch-ai', INJ: 'injective-protocol', KAS: 'kaspa', WIF: 'dogwifcoin', BONK: 'bonk' };
const TYPE_L = { expense: 'Gasto', income: 'Ingreso', transfer: 'Transferencia', adjust: 'Ajuste de saldo' };
const FREQ_L = { daily: 'Cada día', weekly: 'Cada semana', monthly: 'Cada mes', yearly: 'Cada año' };
const HOME_SECTIONS = { period: 'Resumen del periodo', today: 'Hoy', quick: 'Accesos rápidos (plantillas)', goals: 'Objetivos', groups: 'Tus bloques', invest: 'Rendimiento de inversiones', networth: 'Desglose del patrimonio', accounts: 'Cuentas', budgets: 'Presupuestos del mes', upcoming: 'Próximos cargos', watch: 'Seguimiento de mercados', fx: 'En otras monedas', recent: 'Últimos movimientos' };
// Tipos de cambio aproximados solo para el primer arranque sin conexión (por 1 USD). Se sustituyen al conectar.
const FALLBACK_FX = { USD: 1, EUR: 0.86, GBP: 0.75, CHF: 0.80, JPY: 148, CNY: 7.1, CAD: 1.38, AUD: 1.52, MXN: 18.6, ARS: 1350, COP: 3900, CLP: 950, PEN: 3.5, BRL: 5.4, SEK: 9.4, NOK: 10.1, DKK: 6.4, PLN: 3.65, CZK: 21, HUF: 340, RON: 4.35, TRY: 41, MAD: 9, INR: 88 };

/* ---------- estado ---------- */
const KEY = 'mision.finanzas.v1';
let S = null;

function defaultCategories() {
  const e = [
    ['Supermercado', '🛒', 'mercadona, lidl, carrefour, supermercados dia, alcampo, aldi, eroski, ahorramas, hipercor, consum, bm supermercados'],
    ['Restaurantes', '🍽️', 'restaurante, glovo, just eat, uber eats, burger king, mcdonald, telepizza, kfc, starbucks, cafeteria'],
    ['Transporte', '🚇', 'metro, renfe, emt, crtm, cabify, uber, bolt, blablacar, alsa'],
    ['Coche y gasolina', '⛽', 'repsol, cepsa, moeve, galp, shell, gasolinera, parking, itv, peaje, bp oil'],
    ['Vivienda', '🏠', 'alquiler, hipoteca, comunidad de propietarios, ibi'],
    ['Facturas', '💡', 'iberdrola, endesa, naturgy, holaluz, canal de isabel, movistar, vodafone, orange, digi, pepephone, masmovil, jazztel, lowi, simyo'],
    ['Suscripciones', '📺', 'netflix, spotify, hbo, disney, amazon prime, youtube premium, apple.com, icloud, chatgpt, anthropic, claude.ai, dazn, xbox game pass, playstation plus'],
    ['Ocio', '🎮', 'steam, playstation, nintendo, cine, ticketmaster, entradas, epic games'],
    ['Compras', '🛍️', 'amazon, aliexpress, shein, temu, zara, primark, el corte ingles, decathlon, mediamarkt, pccomponentes, ikea'],
    ['Salud', '💊', 'farmacia, dentista, clinica, sanitas, adeslas, optica'],
    ['Deporte', '🏋️', 'gimnasio, basic-fit, altafit, mcfit, dreamfit, go fit'],
    ['Regalos', '🎁', ''],
    ['Viajes', '✈️', 'booking, airbnb, ryanair, iberia, vueling, hotel, easyjet'],
    ['Formación', '📚', 'udemy, coursera, platzi, libreria, casa del libro'],
    ['Comisiones', '🏦', 'comision, comisión, mantenimiento cuenta'],
    ['Otros gastos', '📦', ''],
  ];
  const i = [
    ['Nómina', '💼', 'nomina, nómina, salario'],
    ['Extras y freelance', '🧾', ''],
    ['Ventas', '🏷️', 'wallapop, vinted'],
    ['Intereses y dividendos', '📈', 'intereses, dividendo, remuneracion'],
    ['Regalos recibidos', '🎁', ''],
    ['Bizum recibido', '📲', 'bizum de'],
    ['Otros ingresos', '➕', ''],
  ];
  return [
    ...e.map(([name, icon, kw], n) => ({ id: 'c_' + uid(), kind: 'expense', name, icon, color: PALETTE[n % PALETTE.length], budget: 0, keywords: kw })),
    ...i.map(([name, icon, kw], n) => ({ id: 'c_' + uid(), kind: 'income', name, icon, color: PALETTE[(n + 2) % PALETTE.length], budget: 0, keywords: kw })),
  ];
}

function blankState() {
  return {
    v: 1, demo: false, createdAt: today(),
    settings: {
      base: 'EUR', theme: 'auto', privacy: false,
      finnhubKey: '', yahooProxy: '', refreshSec: 30, binance: true,
      favCcy: ['USD', 'GBP', 'CHF', 'BTC'],
      home: Object.keys(HOME_SECTIONS).map(k => ({ k, on: true })),
      period: 'month',
      name: '', accent: 'malva', customAccent: '#e4b3cb', textSize: 'm', hideCents: false,
      weekStart: 1, monthStart: 1, startTab: 'home', recentCount: 6,
      pinHash: '', lockAfter: 0, notifyRecurring: true, notifyHour: 9,
      budgetTotal: 0, budgetAlerts: true, shortcutMode: 'auto',
    },
    accounts: [], categories: defaultCategories(), txs: [], recurring: [], assets: [], groups: [], goals: [], templates: [],
    snapshots: [], cache: { fx: null, prices: {} },
  };
}

function migrate(s) {
  const b = blankState();
  const out = Object.assign(b, s);
  out.settings = Object.assign(blankState().settings, s.settings || {});
  // secciones del resumen: añade las nuevas que falten
  const have = new Set(out.settings.home.map(h => h.k));
  Object.keys(HOME_SECTIONS).forEach(k => { if (!have.has(k)) out.settings.home.push({ k, on: true }); });
  out.settings.home = out.settings.home.filter(h => HOME_SECTIONS[h.k]);
  out.cache = Object.assign({ fx: null, prices: {} }, s.cache || {});
  for (const k of ['accounts', 'categories', 'txs', 'recurring', 'assets', 'groups', 'goals', 'snapshots', 'templates']) if (!Array.isArray(out[k])) out[k] = [];
  out.assets.forEach(a => { a.ops = a.ops || []; });
  return out;
}

function load() {
  try { const raw = localStorage.getItem(KEY); if (raw) return migrate(JSON.parse(raw)); } catch (e) { console.warn(e); }
  return null;
}
let saveT = null;
function save() { clearTimeout(saveT); saveT = setTimeout(saveNow, 120); }
function saveNow() {
  clearTimeout(saveT);
  try { localStorage.setItem(KEY, JSON.stringify(S)); if (typeof Sync !== 'undefined') Sync.schedule(); }
  catch (e) { toast('No se ha podido guardar en este navegador (¿modo privado o almacenamiento lleno?)'); }
}

/* ---------- accesos ---------- */
const accById = id => S.accounts.find(a => a.id === id);
const catById = id => S.categories.find(c => c.id === id);
const assetById = id => S.assets.find(a => a.id === id);
const groupById = id => S.groups.find(g => g.id === id);
const goalById = id => S.goals.find(g => g.id === id);
const activeAccounts = () => S.accounts.filter(a => !a.archived).sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
const otherCat = kind => S.categories.find(c => c.kind === kind && /^otros/i.test(c.name)) || S.categories.find(c => c.kind === kind);

/* ---------- divisas ---------- */
const cryptoUsd = {}; // SYM -> precio en USD (de los feeds de cripto)
function fxRates() { return (S.cache.fx && S.cache.fx.rates) || FALLBACK_FX; }
function rateOf(c) { // unidades de c por 1 USD
  const r = fxRates();
  if (r[c]) return r[c];
  if (cryptoUsd[c]) return 1 / cryptoUsd[c];
  return null;
}
function conv(n, from, to) {
  to = to || S.settings.base;
  if (!n || !from || from === to) return n || 0;
  const rf = rateOf(from), rt = rateOf(to);
  if (!rf || !rt) return n;
  return n / rf * rt;
}
const canConv = c => !!rateOf(c);

/* ---------- inversiones ---------- */
function holding(a) {
  let qty = 0, cost = 0, realized = 0, invested = 0, fees = 0;
  const ops = (a.ops || []).slice().sort((x, y) => x.date < y.date ? -1 : x.date > y.date ? 1 : 0);
  for (const o of ops) {
    const px = conv(Number(o.price) || 0, o.ccy || S.settings.base);
    const fee = conv(Number(o.fee) || 0, o.ccy || S.settings.base);
    const q = Number(o.qty) || 0;
    fees += fee;
    if (o.side === 'buy') { qty += q; cost += q * px + fee; invested += q * px + fee; }
    else if (o.side === 'reward') { qty += q; }
    else if (o.side === 'sell') {
      const avg = qty > 0 ? cost / qty : 0; const s = Math.min(q, qty);
      realized += s * px - fee - s * avg; cost -= s * avg; qty -= s;
    }
    else if (o.side === 'out') { const avg = qty > 0 ? cost / qty : 0; const s = Math.min(q, qty); cost -= s * avg; qty -= s; }
  }
  if (Math.abs(qty) < 1e-12) { qty = 0; cost = 0; }
  return { qty, cost, avg: qty > 0 ? cost / qty : 0, realized, invested, fees };
}

function resolveProvider(a) {
  const st = S.settings;
  if (a.provider === 'manual') return 'manual';
  if (a.kind === 'crypto') {
    if (a.provider === 'coingecko') return (a.cgId || CG_IDS[a.symbol]) ? 'coingecko' : 'manual';
    if (a.cgId || CG_IDS[a.symbol] || st.binance) return 'crypto';
    return 'manual';
  }
  if (a.watch && a.provider === 'manual') return 'manual';
  if (a.provider === 'yahoo') return (st.yahooProxy || NATIVE) ? 'yahoo' : 'manual';
  if (a.provider === 'finnhub') return st.finnhubKey ? 'finnhub' : 'manual';
  if (st.yahooProxy || NATIVE) return 'yahoo';
  if (st.finnhubKey && !String(a.symbol).includes('.')) return 'finnhub';
  return 'manual';
}
const PROV_L = { crypto: 'Binance + CoinGecko', coingecko: 'CoinGecko', yahoo: 'Yahoo Finance', finnhub: 'Finnhub', manual: 'Precio manual', binance: 'Binance en directo' };

function priceOf(a) {
  const prov = resolveProvider(a);
  if (prov !== 'manual') { const l = S.cache.prices[a.id]; if (l && l.p) return l; }
  if (a.manualPrice) return { p: Number(a.manualPrice), ccy: a.quoteCcy || S.settings.base, ch: null, src: 'manual', t: a.manualAt || null };
  const l = S.cache.prices[a.id]; if (l && l.p) return Object.assign({}, l, { stale: true });
  return null;
}

/* ---------- saldos ---------- */
function balances(upto) {
  const m = {};
  for (const a of S.accounts) m[a.id] = Number(a.initial) || 0;
  for (const t of S.txs) {
    if (upto && t.date > upto) continue;
    if (m[t.accountId] != null) {
      if (t.type === 'expense') m[t.accountId] -= t.amount;
      else if (t.type === 'income') m[t.accountId] += t.amount;
      else if (t.type === 'transfer') m[t.accountId] -= t.amount;
      else if (t.type === 'adjust') m[t.accountId] += t.amount;
    }
    if (t.type === 'transfer' && m[t.toAccountId] != null) m[t.toAccountId] += (t.toAmount ?? t.amount);
  }
  for (const as of S.assets) for (const o of as.ops || []) {
    if (!o.cashAccountId || m[o.cashAccountId] == null) continue;
    if (upto && o.date > upto) continue;
    const acc = accById(o.cashAccountId);
    const gross = (Number(o.qty) || 0) * (Number(o.price) || 0), fee = Number(o.fee) || 0;
    const v = o.side === 'buy' ? -(gross + fee) : o.side === 'sell' ? (gross - fee) : 0;
    m[o.cashAccountId] += conv(v, o.ccy || acc.currency, acc.currency);
  }
  return m;
}

// Foto completa del patrimonio en la moneda base. Se calcula una vez por pintado.
function portfolio() {
  const bal = balances();
  const inTotalAcc = a => a && a.includeInTotal !== false && !a.archived;
  const accounts = S.accounts.filter(a => !a.archived).map(a => ({ a, bal: bal[a.id] || 0, base: conv(bal[a.id] || 0, a.currency), inTotal: inTotalAcc(a) }));
  const watch = S.assets.filter(x => !x.archived && x.watch).map(x => ({ x, pr: priceOf(x) }));
  const assets = S.assets.filter(x => !x.archived && !x.watch).map(x => {
    const h = holding(x); const pr = priceOf(x);
    const pBase = pr ? conv(pr.p, pr.ccy) : null;
    const value = pBase != null ? h.qty * pBase : h.cost;
    const dayChg = (pr && pr.ch != null && isFinite(pr.ch) && pr.src !== 'manual') ? value - value / (1 + pr.ch / 100) : 0;
    const pnl = value - h.cost;
    const acc = x.accountId ? accById(x.accountId) : null;
    return { x, h, pr, pBase, value, dayChg, pnl, pnlPct: h.cost > 0 ? pnl / h.cost * 100 : null, priced: pBase != null, inTotal: !acc || inTotalAcc(acc) };
  });
  const cashTotal = sum(accounts.filter(r => r.inTotal), r => r.base);
  const inv = assets.filter(r => r.inTotal);
  const assetsTotal = sum(inv, r => r.value);
  return {
    accounts, assets, watch, cashTotal, assetsTotal, nw: cashTotal + assetsTotal,
    debts: sum(accounts.filter(r => r.inTotal && (r.a.type === 'deuda' || r.base < 0)), r => r.base), property: sum(accounts.filter(r => r.inTotal && r.a.type === 'activo'), r => r.base),
    dayChg: sum(inv, r => r.dayChg), cost: sum(inv, r => r.h.cost), pnl: sum(inv, r => r.pnl), realized: sum(inv, r => r.h.realized),
    byAcc: id => ({ cash: (accounts.find(r => r.a.id === id) || {}).base || 0, inv: sum(assets.filter(r => r.x.accountId === id), r => r.value) }),
  };
}

/* ---------- bloques (grupos) ---------- */
function groupMembers(g, P) {
  const acc = new Set(), ast = new Set();
  for (const it of g.items || []) {
    if (it.t === 'all') { P.accounts.forEach(r => r.inTotal && acc.add(r.a.id)); P.assets.forEach(r => r.inTotal && ast.add(r.x.id)); }
    else if (it.t === 'cash') P.accounts.forEach(r => r.inTotal && acc.add(r.a.id));
    else if (it.t === 'kind') P.assets.forEach(r => r.x.kind === it.v && ast.add(r.x.id));
    else if (it.t === 'atype') P.accounts.forEach(r => r.a.type === it.v && acc.add(r.a.id));
    else if (it.t === 'account') { acc.add(it.id); P.assets.forEach(r => r.x.accountId === it.id && ast.add(r.x.id)); }
    else if (it.t === 'asset') ast.add(it.id);
  }
  return { acc, ast };
}
function groupValue(g, P) {
  const { acc, ast } = groupMembers(g, P);
  const cash = sum(P.accounts.filter(r => acc.has(r.a.id)), r => r.base);
  const inv = P.assets.filter(r => ast.has(r.x.id));
  return { value: cash + sum(inv, r => r.value), cash, inv: sum(inv, r => r.value), pnl: sum(inv, r => r.pnl), day: sum(inv, r => r.dayChg), n: acc.size + ast.size, acc, ast };
}
function groupItemsLabel(g) {
  const parts = (g.items || []).map(it => {
    if (it.t === 'all') return 'Todo';
    if (it.t === 'cash') return 'Todas las cuentas';
    if (it.t === 'kind') return it.v === 'crypto' ? 'Toda la cripto' : 'Todas las acciones';
    if (it.t === 'atype') return ACC_TYPES[it.v];
    if (it.t === 'account') return accById(it.id)?.name;
    if (it.t === 'asset') return assetById(it.id)?.symbol;
  }).filter(Boolean);
  return parts.join(' · ') || 'Vacío';
}

/* ---------- objetivos ---------- */
function goalCurrent(g, P) {
  const s = g.source || { t: 'manual' };
  if (s.t === 'nw') return P.nw;
  if (s.t === 'group') { const gr = groupById(s.id); return gr ? groupValue(gr, P).value : 0; }
  if (s.t === 'account') { const b = P.byAcc(s.id); return b.cash + b.inv; }
  if (s.t === 'kind') return sum(P.assets.filter(r => r.x.kind === s.v), r => r.value);
  return conv(Number(g.manual) || 0, g.ccy || S.settings.base);
}
function goalInfo(g, P) {
  const target = conv(Number(g.target) || 0, g.ccy || S.settings.base);
  const cur = goalCurrent(g, P);
  const pct = target > 0 ? clamp(cur / target * 100, 0, 100) : 0;
  const left = Math.max(0, target - cur);
  let months = null, perMonth = null;
  if (g.deadline) {
    const d = parseYmd(g.deadline), n = new Date();
    months = (d.getFullYear() - n.getFullYear()) * 12 + (d.getMonth() - n.getMonth()) + (d.getDate() >= n.getDate() ? 0 : -1) + 1;
    months = Math.max(0, months);
    perMonth = months > 0 ? left / months : left;
  }
  return { target, cur, pct, left, months, perMonth, done: target > 0 && cur >= target };
}

/* ---------- mes financiero (puede empezar el día que cobras) ---------- */
function FR(mk) {
  const st = Math.min(28, Math.max(1, S.settings.monthStart || 1));
  if (st === 1) return { from: mk + '-01', to: monthEnd(mk) };
  return { from: `${mk}-${pad(st)}`, to: addDays(`${addMonths(mk, 1)}-${pad(st)}`, -1) };
}
function mkOf(date) { const st = S.settings.monthStart || 1; const mk = monthKey(date); return st > 1 && Number(String(date).slice(8, 10)) < st ? addMonths(mk, -1) : mk; }
const curMk = () => mkOf(today());
function finLabel(mk) {
  if ((S.settings.monthStart || 1) === 1) return monthLabel(mk);
  const R = FR(mk); const a = parseYmd(R.from), b = parseYmd(R.to);
  return `${a.getDate()} ${MONTHS_S[a.getMonth()]} – ${b.getDate()} ${MONTHS_S[b.getMonth()]}${b.getFullYear() !== new Date().getFullYear() ? ' ' + b.getFullYear() : ''}`;
}
const finShort = mk => { const R = FR(mk); const d = parseYmd((S.settings.monthStart || 1) > 15 ? R.to : R.from); return MONTHS_S[d.getMonth()].slice(0, 3); };

/* ---------- flujo (ingresos / gastos) ---------- */
function periodRange(p, ref = today()) {
  const d = parseYmd(ref);
  if (p === 'day') return { from: ref, to: ref, prevFrom: addDays(ref, -1), prevTo: addDays(ref, -1), label: 'hoy', prevLabel: 'ayer', days: 1 };
  if (p === 'week') {
    const ws = S.settings.weekStart ?? 1; const wd = (d.getDay() - ws + 7) % 7; const from = addDays(ref, -wd); const to = addDays(from, 6);
    return { from, to, prevFrom: addDays(from, -7), prevTo: addDays(ref, -7), label: 'esta semana', prevLabel: 'la semana pasada', days: wd + 1 };
  }
  if (p === 'year') {
    const y = d.getFullYear();
    return { from: `${y}-01-01`, to: `${y}-12-31`, prevFrom: `${y - 1}-01-01`, prevTo: `${y - 1}-${ref.slice(5)}`, label: `en ${y}`, prevLabel: `a estas alturas de ${y - 1}`, days: Math.round((d - new Date(y, 0, 1)) / 864e5) + 1, prevCmpTo: true };
  }
  const mk = mkOf(ref); const R = FR(mk), PR = FR(addMonths(mk, -1));
  const days = Math.round((parseYmd(ref) - parseYmd(R.from)) / 864e5) + 1;
  const pt = addDays(PR.from, days - 1); const prevTo = pt < PR.to ? pt : PR.to;
  return { from: R.from, to: R.to, prevFrom: PR.from, prevTo, label: (S.settings.monthStart || 1) > 1 ? 'este periodo' : 'este mes', prevLabel: 'a estas alturas del anterior', days };
}
// Reparte un movimiento entre categorías (movimientos divididos)
function txParts(t) {
  if (Array.isArray(t.splits) && t.splits.length) return t.splits.map(p => ({ categoryId: p.categoryId, amount: Number(p.amount) || 0 }));
  return [{ categoryId: t.categoryId, amount: t.amount }];
}
const parentOf = id => { const c = catById(id); return c && c.parentId && catById(c.parentId) ? c.parentId : id; };
function flows(from, to, filter) {
  let inc = 0, exp = 0; const byCat = {}, byParent = {}, incCat = {}; const list = [];
  for (const t of S.txs) {
    if (t.date < from || t.date > to) continue;
    if (t.type !== 'income' && t.type !== 'expense') continue;
    if (t.excl) continue;
    const acc = accById(t.accountId); if (!acc) continue;
    if (filter && !filter(t)) continue;
    for (const p of txParts(t)) {
      const v = conv(p.amount, acc.currency);
      if (t.type === 'income') { inc += v; incCat[p.categoryId] = (incCat[p.categoryId] || 0) + v; }
      else { exp += v; byCat[p.categoryId] = (byCat[p.categoryId] || 0) + v; const pid = parentOf(p.categoryId); byParent[pid] = (byParent[pid] || 0) + v; }
    }
    list.push(t);
  }
  return { inc, exp, net: inc - exp, byCat, byParent, incCat, list, rate: inc > 0 ? (inc - exp) / inc * 100 : null };
}
// Gasto de una categoría (incluye sus subcategorías)
function catSpend(catId, from, to) {
  const ids = new Set([catId, ...S.categories.filter(c => c.parentId === catId).map(c => c.id)]);
  let v = 0;
  for (const t of S.txs) {
    if (t.type !== 'expense' || t.excl || t.date < from || t.date > to) continue;
    const a = accById(t.accountId); if (!a) continue;
    for (const p of txParts(t)) if (ids.has(p.categoryId)) v += conv(p.amount, a.currency);
  }
  return v;
}
// Presupuesto disponible con arrastre del sobrante (hasta 12 periodos atrás)
function budgetAvail(c, mk, depth = 0) {
  const b = Number(c.budget) || 0; if (!b) return 0;
  if (!c.rollover || depth >= 12) return b;
  const pm = addMonths(mk, -1); const R = FR(pm);
  if (S.createdAt && R.to < S.createdAt) return b;
  return b + (budgetAvail(c, pm, depth + 1) - catSpend(c.id, R.from, R.to));
}

/* ---------- recurrentes ---------- */
function nextDate(d, freq, interval = 1, anchor) {
  const x = parseYmd(d);
  if (freq === 'daily') { x.setDate(x.getDate() + interval); return ymd(x); }
  if (freq === 'weekly') { x.setDate(x.getDate() + 7 * interval); return ymd(x); }
  const day = anchor || x.getDate();
  let y = x.getFullYear(), m = x.getMonth();
  if (freq === 'yearly') y += interval; else { m += interval; y += Math.floor(m / 12); m = ((m % 12) + 12) % 12; }
  return `${y}-${pad(m + 1)}-${pad(Math.min(day, daysInMonth(y, m)))}`;
}
function runRecurring() {
  const t = today(); let n = 0;
  for (const r of S.recurring) {
    if (!r.active) continue;
    let guard = 0;
    while (r.next && r.next <= t && guard++ < 500) {
      if (r.end && r.next > r.end) { r.active = false; break; }
      const acc = accById(r.tpl.accountId);
      if (acc) { S.txs.push(Object.assign({}, r.tpl, { id: uid(), date: r.next, recId: r.id })); n++; }
      r.next = nextDate(r.next, r.freq, r.interval || 1, r.day);
    }
  }
  if (n) { save(); setTimeout(() => toast(`${n} movimiento${n > 1 ? 's' : ''} recurrente${n > 1 ? 's' : ''} añadido${n > 1 ? 's' : ''}`), 600); }
}

/* ---------- histórico ---------- */
function cashHistory(months = 12, endMk = curMk()) {
  const out = [];
  for (let i = months - 1; i >= 0; i--) {
    const mk = addMonths(endMk, -i); let end = FR(mk).to; if (end > today()) end = today();
    const b = balances(end);
    const v = sum(S.accounts.filter(a => a.includeInTotal !== false && !a.archived), a => conv(b[a.id] || 0, a.currency));
    out.push({ mk, v });
  }
  return out;
}
function recordSnapshot(P) {
  const d = today(); const v = Math.round(P.nw * 100) / 100; const c = S.settings.base;
  const last = S.snapshots[S.snapshots.length - 1];
  if (last && last.d === d) { last.v = v; last.c = c; } else S.snapshots.push({ d, v, c });
  if (S.snapshots.length > 1500) S.snapshots.splice(0, S.snapshots.length - 1500);
}
function nwSeries(days = 30) {
  const from = addDays(today(), -days);
  const snaps = S.snapshots.filter(s => s.d >= from).map(s => conv(s.v, s.c || S.settings.base));
  if (snaps.length >= 2) return { vals: snaps, kind: 'snap' };
  // sin histórico todavía: saldo en cuentas día a día (exacto) de los últimos días
  const vals = [];
  for (let i = Math.min(days, 30); i >= 0; i -= 2) { const b = balances(addDays(today(), -i)); vals.push(sum(S.accounts.filter(a => a.includeInTotal !== false && !a.archived), a => conv(b[a.id] || 0, a.currency))); }
  return { vals, kind: 'cash' };
}

/* ---------- datos de ejemplo ---------- */
function demoState() {
  const s = blankState(); s.demo = true;
  let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const r = (a, b) => Math.round((a + rnd() * (b - a)) * 100) / 100;
  const acc = (name, type, currency, initial, color) => { const a = { id: 'a_' + uid(), name, type, currency, initial, color, icon: ACC_ICONS[type], includeInTotal: true, archived: false, order: s.accounts.length }; s.accounts.push(a); return a; };
  const main = acc('Cuenta principal', 'corriente', 'EUR', 1320, PALETTE[0]);
  const sav = acc('Ahorro', 'ahorro', 'EUR', 4800, PALETTE[2]);
  const cash = acc('Efectivo', 'efectivo', 'EUR', 420, PALETTE[3]);
  const usd = acc('Revolut en dólares', 'corriente', 'USD', 310, PALETTE[1]);
  const bin = acc('Binance', 'exchange', 'EUR', 35, PALETTE[5]);
  const tr = acc('Bróker', 'broker', 'EUR', 120, PALETTE[6]);
  const C = n => s.categories.find(c => c.name === n).id;
  const tx = (type, amount, a, cat, date, note) => s.txs.push({ id: uid(), type, amount, accountId: a.id, categoryId: cat ? C(cat) : '', date, note: note || '', tags: [] });
  const tr_ = (amount, a, b, date, note) => s.txs.push({ id: uid(), type: 'transfer', amount, toAmount: amount, accountId: a.id, toAccountId: b.id, date, note: note || '', tags: [] });
  const t = today(); const cm = monthKey(t);
  for (let back = 3; back >= 0; back--) {
    const mk = addMonths(cm, -back); const [y, m] = mk.split('-').map(Number); const dim = daysInMonth(y, m - 1);
    const D = d => { const s2 = `${mk}-${pad(Math.min(d, dim))}`; return s2; };
    const ok = d => D(d) <= t;
    if (ok(1)) tx('expense', 650, main, 'Vivienda', D(1), 'Alquiler');
    if (ok(3)) tx('expense', 29.99, main, 'Deporte', D(3), 'Gimnasio');
    if (ok(5)) tx('expense', r(38, 62), main, 'Facturas', D(5), 'Luz');
    if (ok(8)) tx('expense', 15, main, 'Facturas', D(8), 'Móvil y fibra');
    if (ok(12)) tx('expense', 11.99, main, 'Suscripciones', D(12), 'Spotify');
    if (ok(15)) tx('expense', 13.99, main, 'Suscripciones', D(15), 'Netflix');
    if (ok(10)) tr_(100, main, bin, D(10), 'Aportación cripto');
    for (const d of [2, 6, 11, 16, 21, 26]) if (ok(d)) tx('expense', r(22, 78), main, 'Supermercado', D(d), ['Mercadona', 'Lidl', 'Carrefour', 'Mercadona', 'Ahorramás', 'Lidl'][d % 6]);
    for (const d of [4, 13, 19, 25]) if (ok(d)) tx('expense', r(11, 36), d % 2 ? cash : main, 'Restaurantes', D(d), ['Cena con amigos', 'Menú del día', 'Glovo', 'Cañas'][d % 4]);
    for (const d of [7, 22]) if (ok(d)) tx('expense', r(44, 62), main, 'Coche y gasolina', D(d), 'Repsol');
    if (ok(18)) tx('expense', r(18, 55), main, 'Ocio', D(18), 'Steam');
    if (ok(20)) tx('expense', r(25, 90), main, 'Compras', D(20), 'Amazon');
    if (ok(9)) tx('expense', r(6, 18), usd, 'Suscripciones', D(9), 'Suscripción en USD');
    if (ok(27) && back % 2 === 0) tx('income', r(120, 260), main, 'Extras y freelance', D(27), 'Web para un cliente');
    if (ok(28)) tx('income', 1680, main, 'Nómina', D(28), 'Nómina');
    if (ok(29)) tr_(250, main, sav, D(29), 'Ahorro del mes');
  }
  const rec = (tpl, freq, day) => { let next = `${cm}-${pad(Math.min(day, 28))}`; while (next <= t) next = nextDate(next, freq, 1, day); s.recurring.push({ id: 'r_' + uid(), name: tpl.note, tpl, freq, interval: 1, day, next, end: '', active: true }); };
  rec({ type: 'income', amount: 1680, accountId: main.id, categoryId: C('Nómina'), note: 'Nómina', tags: [] }, 'monthly', 28);
  rec({ type: 'expense', amount: 650, accountId: main.id, categoryId: C('Vivienda'), note: 'Alquiler', tags: [] }, 'monthly', 1);
  rec({ type: 'expense', amount: 11.99, accountId: main.id, categoryId: C('Suscripciones'), note: 'Spotify', tags: [] }, 'monthly', 12);
  rec({ type: 'expense', amount: 13.99, accountId: main.id, categoryId: C('Suscripciones'), note: 'Netflix', tags: [] }, 'monthly', 15);
  rec({ type: 'expense', amount: 29.99, accountId: main.id, categoryId: C('Deporte'), note: 'Gimnasio', tags: [] }, 'monthly', 3);
  rec({ type: 'transfer', amount: 250, toAmount: 250, accountId: main.id, toAccountId: sav.id, note: 'Ahorro del mes', tags: [] }, 'monthly', 29);
  // lo generado ya está en el histórico; los recurrentes empiezan en la siguiente fecha
  s.categories.find(c => c.name === 'Supermercado').budget = 300;
  s.categories.find(c => c.name === 'Restaurantes').budget = 120;
  s.categories.find(c => c.name === 'Ocio').budget = 60;
  s.categories.find(c => c.name === 'Compras').budget = 100;
  const d0 = addDays(t, -200), d1 = addDays(t, -120), d2 = addDays(t, -60);
  const asset = (o) => { const a = Object.assign({ id: 's_' + uid(), provider: 'auto', archived: false, ops: [] }, o); s.assets.push(a); return a; };
  asset({ kind: 'crypto', symbol: 'BTC', name: 'Bitcoin', cgId: 'bitcoin', quoteCcy: 'USD', accountId: bin.id, manualPrice: 95000, ops: [{ id: uid(), side: 'buy', qty: 0.012, price: 52000, fee: 3, ccy: 'EUR', date: d0 }, { id: uid(), side: 'buy', qty: 0.006, price: 61000, fee: 2, ccy: 'EUR', date: d2 }] });
  asset({ kind: 'crypto', symbol: 'ETH', name: 'Ethereum', cgId: 'ethereum', quoteCcy: 'USD', accountId: bin.id, manualPrice: 3500, ops: [{ id: uid(), side: 'buy', qty: 0.35, price: 2400, fee: 1.5, ccy: 'EUR', date: d1 }] });
  asset({ kind: 'crypto', symbol: 'SOL', name: 'Solana', cgId: 'solana', quoteCcy: 'USD', accountId: bin.id, manualPrice: 180, ops: [{ id: uid(), side: 'buy', qty: 4, price: 140, fee: 1, ccy: 'EUR', date: d1 }, { id: uid(), side: 'reward', qty: 0.12, price: 0, fee: 0, ccy: 'EUR', date: d2 }] });
  asset({ kind: 'stock', symbol: 'AAPL', name: 'Apple Inc.', quoteCcy: 'USD', accountId: tr.id, manualPrice: 230, ops: [{ id: uid(), side: 'buy', qty: 3, price: 172, fee: 1, ccy: 'EUR', date: d0 }] });
  asset({ kind: 'stock', symbol: 'SAN.MC', name: 'Banco Santander', quoteCcy: 'EUR', accountId: tr.id, manualPrice: 7.5, ops: [{ id: uid(), side: 'buy', qty: 150, price: 5.2, fee: 1, ccy: 'EUR', date: d0 }] });
  asset({ kind: 'stock', symbol: 'VWCE.DE', name: 'Vanguard FTSE All-World (ETF)', quoteCcy: 'EUR', accountId: tr.id, manualPrice: 135, ops: [{ id: uid(), side: 'buy', qty: 10, price: 118, fee: 1, ccy: 'EUR', date: d1 }] });
  const rest = s.categories.find(c => c.name === 'Restaurantes');
  const cafe = { id: 'c_' + uid(), kind: 'expense', name: 'Café', icon: '☕', color: rest.color, budget: 0, keywords: 'cafe, café, starbucks', parentId: rest.id };
  s.categories.splice(s.categories.indexOf(rest) + 1, 0, cafe);
  for (let i = 1; i <= 12; i++) { s.txs.push({ id: uid(), type: 'expense', amount: r(1.3, 3.2), accountId: cash.id, categoryId: cafe.id, date: addDays(t, -i * 3), note: 'Café', tags: [] }); }
  s.txs.push({ id: uid(), type: 'expense', amount: 96.4, accountId: main.id, categoryId: C('Supermercado'), date: addDays(t, -4), note: 'Carrefour (compra + regalo)', tags: [], splits: [{ categoryId: C('Supermercado'), amount: 71.4 }, { categoryId: C('Regalos'), amount: 25 }] });
  const loan = acc('Préstamo del coche', 'deuda', 'EUR', -6400, PALETTE[7]);
  for (let back = 3; back >= 0; back--) { const d = `${addMonths(cm, -back)}-05`; if (d <= t) tr_(215, main, loan, d, 'Cuota préstamo coche'); }
  rec({ type: 'transfer', amount: 215, toAmount: 215, accountId: main.id, toAccountId: loan.id, note: 'Cuota préstamo coche', tags: [] }, 'monthly', 5);
  s.templates = [
    { id: 't_' + uid(), name: 'Café', icon: '☕', tpl: { type: 'expense', amount: 1.6, accountId: cash.id, categoryId: cafe.id, note: 'Café', tags: [] } },
    { id: 't_' + uid(), name: 'Menú del día', icon: '🍽️', tpl: { type: 'expense', amount: 13.5, accountId: main.id, categoryId: C('Restaurantes'), note: 'Menú del día', tags: [] } },
    { id: 't_' + uid(), name: 'Gasolina', icon: '⛽', tpl: { type: 'expense', amount: 50, accountId: main.id, categoryId: C('Coche y gasolina'), note: 'Gasolina', tags: [] } },
    { id: 't_' + uid(), name: 'Metro', icon: '🚇', tpl: { type: 'expense', amount: 1.5, accountId: main.id, categoryId: C('Transporte'), note: 'Metro', tags: [] } },
  ];
  asset({ kind: 'stock', symbol: 'NVDA', name: 'NVIDIA', quoteCcy: 'USD', accountId: '', manualPrice: 180, watch: true, ops: [] });
  asset({ kind: 'crypto', symbol: 'XRP', name: 'XRP', cgId: 'ripple', quoteCcy: 'USD', accountId: '', manualPrice: 2.5, watch: true, ops: [] });
  s.groups = [
    { id: 'g_' + uid(), name: 'Cuenta principal', color: PALETTE[0], items: [{ t: 'account', id: main.id }] },
    { id: 'g_' + uid(), name: 'Todas las cuentas', color: PALETTE[1], items: [{ t: 'cash' }] },
    { id: 'g_' + uid(), name: 'Cripto', color: PALETTE[5], items: [{ t: 'kind', v: 'crypto' }] },
    { id: 'g_' + uid(), name: 'Acciones y ETF', color: PALETTE[6], items: [{ t: 'kind', v: 'stock' }] },
    { id: 'g_' + uid(), name: 'En dólares', color: PALETTE[3], items: [{ t: 'account', id: usd.id }] },
  ];
  s.goals = [
    { id: 'o_' + uid(), name: 'Colchón de emergencia', icon: '🛟', color: PALETTE[2], target: 6000, ccy: 'EUR', deadline: `${Number(t.slice(0, 4)) + 1}-03-31`, source: { t: 'account', id: sav.id } },
    { id: 'o_' + uid(), name: 'Viaje a Japón', icon: '🗾', color: PALETTE[0], target: 2500, ccy: 'EUR', deadline: `${Number(t.slice(0, 4)) + 1}-09-01`, source: { t: 'manual' }, manual: 640 },
    { id: 'o_' + uid(), name: 'Patrimonio de 25.000 €', icon: '🎯', color: PALETTE[5], target: 25000, ccy: 'EUR', deadline: '', source: { t: 'nw' } },
  ];
  return s;
}
