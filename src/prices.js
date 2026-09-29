/* =====================================================================
   Precios en tiempo real
   · Cripto: WebSocket de Binance (tick a tick) + CoinGecko (cada minuto, cubre cualquier moneda)
   · Acciones/ETF: tu proxy de Yahoo Finance (cualquier bolsa) o Finnhub (EE. UU., con WebSocket)
   · Divisas: open.er-api.com (respaldo: Frankfurter/BCE)
   ===================================================================== */
const PX = {
  st: { fx: 'idle', cg: 'idle', binance: 'off', yahoo: 'idle', finnhub: 'idle', fws: 'off', last: 0, err: {} },
  ticks: {}, flash: {}, dirty: false,
  bws: null, bKey: '', bTry: 0, fws: null, fKey: '', fTry: 0,
  timers: {},
};
const cryptoT = {}; // SYM -> último tick de Binance
// Dentro de la app de iPhone las peticiones van por HTTP nativo (sin CORS): Yahoo funciona sin proxy.
const NATIVE = !!(window.Capacitor && typeof Capacitor.isNativePlatform === 'function' && Capacitor.isNativePlatform());
const yahooOK = () => NATIVE || !!S.settings.yahooProxy;
async function yahooChart(sym, range = '1d', interval = '1d') {
  const u = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(sym)}?range=${range}&interval=${interval}&includePrePost=false`;
  const j = await fetchJSON(u, 15000);
  const r = j && j.chart && j.chart.result && j.chart.result[0]; if (!r) throw new Error('sin datos');
  return r;
}
async function yahooQuotes(syms) {
  if (S.settings.yahooProxy) { const j = await fetchJSON(proxyUrl('symbols=' + encodeURIComponent(syms.join(','))), 15000); return j.quotes || []; }
  return Promise.all(syms.map(async sym => {
    try { const m = (await yahooChart(sym)).meta; return { symbol: sym, price: m.regularMarketPrice, prevClose: m.chartPreviousClose ?? m.previousClose, currency: m.currency, name: m.longName || m.shortName, marketState: m.marketState }; }
    catch (e) { return { symbol: sym, error: true }; }
  }));
}
// Histórico de precios para los gráficos de cada activo (en la moneda de cotización)
const HIST = {};
const RANGES = { '1D': { d: 1, y: ['1d', '5m'] }, '1S': { d: 7, y: ['5d', '30m'] }, '1M': { d: 30, y: ['1mo', '1d'] }, '3M': { d: 90, y: ['3mo', '1d'] }, '1A': { d: 365, y: ['1y', '1wk'] }, '5A': { d: 1825, y: ['5y', '1mo'] } };
async function priceHistory(a, rg) {
  const key = a.id + rg; const c = HIST[key]; if (c && Date.now() - c.t < 5 * 60 * 1000) return c.pts;
  let pts = [];
  if (a.kind === 'crypto') {
    const id = a.cgId || CG_IDS[a.symbol]; if (!id) throw new Error('Sin ID de CoinGecko');
    const j = await fetchJSON(`https://api.coingecko.com/api/v3/coins/${id}/market_chart?vs_currency=usd&days=${RANGES[rg].d}`, 15000);
    pts = (j.prices || []).map(([t, p]) => [t, p]);
  } else {
    if (!yahooOK()) throw new Error('Configura una fuente de acciones');
    const [range, interval] = RANGES[rg].y;
    const r = S.settings.yahooProxy ? await fetchJSON(proxyUrl(`chart=${encodeURIComponent(a.ySymbol || a.symbol)}&range=${range}&interval=${interval}`), 15000).then(j => j.result) : await yahooChart(a.ySymbol || a.symbol, range, interval);
    const ts = r.timestamp || [], cl = (r.indicators && r.indicators.quote && r.indicators.quote[0] && r.indicators.quote[0].close) || [];
    const div = /^(GBp|GBX|ZAc|ILA)$/.test((r.meta && r.meta.currency) || '') ? 100 : 1;
    pts = ts.map((t, i) => [t * 1000, cl[i] / div]).filter(x => x[1] > 0);
  }
  if (pts.length > 240) { const step = pts.length / 240; pts = Array.from({ length: 240 }, (_, i) => pts[Math.floor(i * step)]).concat([pts[pts.length - 1]]); }
  HIST[key] = { t: Date.now(), pts }; return pts;
}

async function fetchJSON(url, ms = 12000, opts = {}) {
  const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await fetch(url, Object.assign({ signal: ctl.signal, cache: 'no-store' }, opts));
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return await r.json();
  } finally { clearTimeout(t); }
}

function setPrice(id, p, ccy, ch, src, extra) {
  if (!(p > 0)) return;
  const prev = S.cache.prices[id];
  const o = Object.assign({}, prev || {}, extra || {}, { p, ccy, src, t: Date.now() });
  if (ch != null && isFinite(ch)) o.ch = ch; else if (o.pc > 0) o.ch = (p - o.pc) / o.pc * 100;
  S.cache.prices[id] = o;
  if (prev && prev.p && prev.p !== p) PX.flash[id] = { d: p > prev.p ? 'up' : 'down', t: Date.now() };
  const tk = PX.ticks[id] || (PX.ticks[id] = []);
  const last = tk[tk.length - 1];
  if (!last || Date.now() - last[0] > 1500) { tk.push([Date.now(), p]); if (tk.length > 400) tk.shift(); } else last[1] = p;
  PX.st.last = Date.now(); PX.dirty = true;
  scheduleLive();
}

/* ---------- divisas ---------- */
async function refreshFx(force) {
  const c = S.cache.fx;
  if (!force && c && Date.now() - c.t < 55 * 60 * 1000) { PX.st.fx = 'ok'; return; }
  PX.st.fx = 'loading';
  try {
    const j = await fetchJSON('https://open.er-api.com/v6/latest/USD');
    if (j.result !== 'success' || !j.rates) throw new Error('respuesta no válida');
    S.cache.fx = { rates: j.rates, t: Date.now(), upd: (j.time_last_update_unix || 0) * 1000, src: 'ExchangeRate-API' };
  } catch (e) {
    try {
      const j = await fetchJSON('https://api.frankfurter.dev/v1/latest?base=USD');
      if (!j.rates || typeof j.rates !== 'object') throw new Error('sin datos');
      S.cache.fx = { rates: Object.assign({ USD: 1 }, j.rates), t: Date.now(), upd: j.date ? parseYmd(j.date).getTime() : Date.now(), src: 'Frankfurter (BCE)' };
    } catch (e2) { PX.st.fx = 'error'; PX.st.err.fx = 'No se pudieron descargar los tipos de cambio'; return; }
  }
  PX.st.fx = 'ok'; delete PX.st.err.fx; save(); scheduleLive(true);
}

/* ---------- cripto ---------- */
function cryptoTargets() {
  const map = new Map(); // SYM -> {cg, ids:[]}
  for (const a of S.assets) {
    if (a.kind !== 'crypto' || a.archived) continue;
    const prov = resolveProvider(a); if (prov === 'manual') continue;
    const sym = String(a.symbol).toUpperCase();
    const e = map.get(sym) || { cg: a.cgId || CG_IDS[sym] || null, ids: [], ws: prov === 'crypto' && !STABLES.has(sym) };
    e.ids.push(a.id); if (!e.cg && (a.cgId || CG_IDS[sym])) e.cg = a.cgId || CG_IDS[sym];
    if (prov === 'crypto' && !STABLES.has(sym)) e.ws = true;
    map.set(sym, e);
  }
  for (const c of S.settings.favCcy) if (!isFiat(c) && !map.has(c)) map.set(c, { cg: CG_IDS[c] || null, ids: [], ws: !STABLES.has(c) });
  return map;
}
async function pollCrypto() {
  const tg = cryptoTargets(); const ids = [...new Set([...tg.values()].map(e => e.cg).filter(Boolean))];
  if (!ids.length) { PX.st.cg = 'idle'; return; }
  PX.st.cg = 'loading';
  try {
    const j = await fetchJSON(`https://api.coingecko.com/api/v3/simple/price?ids=${ids.join(',')}&vs_currencies=usd&include_24hr_change=true`);
    for (const [sym, e] of tg) {
      const d = e.cg && j[e.cg]; if (!d || !d.usd) continue;
      const liveWs = PX.st.binance === 'live' && e.ws && cryptoT[sym] && Date.now() - cryptoT[sym] < 30000;
      if (!liveWs) cryptoUsd[sym] = d.usd;
      for (const id of e.ids) {
        const cur = S.cache.prices[id];
        const fresh = cur && cur.src === 'binance' && Date.now() - cur.t < 30000;
        if (!fresh) setPrice(id, d.usd, 'USD', d.usd_24h_change, 'coingecko');
      }
    }
    PX.st.cg = 'ok'; delete PX.st.err.cg; scheduleLive();
  } catch (e) { PX.st.cg = 'error'; PX.st.err.cg = 'CoinGecko no responde (límite de peticiones o sin conexión)'; }
}
function connectBinance() {
  const tg = cryptoTargets();
  const streams = S.settings.binance ? [...tg].filter(([, e]) => e.ws).map(([s]) => s.toLowerCase() + 'usdt@miniTicker').sort() : [];
  const key = streams.join('/');
  if (key === PX.bKey && PX.bws && PX.bws.readyState <= 1) return;
  PX.bKey = key;
  if (PX.bws) { const old = PX.bws; PX.bws = null; try { old.close(); } catch (e) { } }
  clearTimeout(PX.timers.b);
  if (!key || document.hidden) { PX.st.binance = 'off'; updateLive(); return; }
  const host = PX.bTry % 2 ? 'wss://data-stream.binance.vision' : 'wss://stream.binance.com:9443';
  let ws;
  try { ws = new WebSocket(`${host}/stream?streams=${key}`); } catch (e) { PX.st.binance = 'error'; return; }
  PX.bws = ws; PX.st.binance = 'connecting'; updateLive();
  ws.onopen = () => { if (PX.bws !== ws) return; PX.st.binance = 'live'; PX.bTry = 0; delete PX.st.err.binance; updateLive(); };
  ws.onmessage = ev => {
    let m; try { m = JSON.parse(ev.data); } catch (e) { return; }
    const d = m && m.data; if (!d || !d.s) return;
    const sym = d.s.replace(/USDT$/, ''); const c = +d.c, o = +d.o; if (!(c > 0)) return;
    cryptoUsd[sym] = c; cryptoT[sym] = Date.now();
    const e = tg.get(sym); if (!e) return;
    for (const id of e.ids) setPrice(id, c, 'USD', o ? (c - o) / o * 100 : null, 'binance');
    if (!e.ids.length) scheduleLive();
  };
  ws.onclose = () => {
    if (PX.bws !== ws) return;
    PX.bws = null; PX.st.binance = 'off'; PX.bTry++; PX.st.err.binance = 'Conexión con Binance cerrada, reintentando…'; updateLive();
    PX.timers.b = setTimeout(() => { PX.bKey = ''; connectBinance(); }, Math.min(30000, 1500 * PX.bTry));
  };
  ws.onerror = () => { };
}

/* ---------- acciones ---------- */
function proxyUrl(params) {
  const base = String(S.settings.yahooProxy || '').trim(); if (!base) return '';
  return base + (base.includes('?') ? '&' : '?') + params;
}
function normCcy(p, ccy) {
  if (ccy === 'GBp' || ccy === 'GBX') return [p / 100, 'GBP'];
  if (ccy === 'ZAc') return [p / 100, 'ZAR'];
  if (ccy === 'ILA') return [p / 100, 'ILS'];
  return [p, ccy];
}
async function pollYahoo() {
  const list = S.assets.filter(a => a.kind === 'stock' && !a.archived && resolveProvider(a) === 'yahoo');
  if (!list.length) { PX.st.yahoo = 'idle'; return; }
  PX.st.yahoo = 'loading';
  const syms = [...new Set(list.map(a => a.ySymbol || a.symbol))];
  try {
    for (let i = 0; i < syms.length; i += 25) {
      const quotes = await yahooQuotes(syms.slice(i, i + 25));
      for (const q of quotes) {
        if (!(q.price > 0)) continue;
        let [p, ccy] = normCcy(q.price, q.currency || '');
        let [pc] = normCcy(q.prevClose || 0, q.currency || '');
        for (const a of list) if ((a.ySymbol || a.symbol) === q.symbol) {
          if (!ccy) ccy = a.quoteCcy || 'USD';
          if (a.quoteCcy !== ccy) { a.quoteCcy = ccy; save(); }
          setPrice(a.id, p, ccy, pc > 0 ? (p - pc) / pc * 100 : null, 'yahoo', { pc, mkt: q.marketState || '' });
        }
      }
    }
    PX.st.yahoo = 'ok'; delete PX.st.err.yahoo;
  } catch (e) { PX.st.yahoo = 'error'; PX.st.err.yahoo = (S.settings.yahooProxy ? 'Tu proxy de Yahoo no responde: ' : 'Yahoo Finance no responde: ') + e.message; }
}
async function pollFinnhub() {
  const list = S.assets.filter(a => a.kind === 'stock' && !a.archived && resolveProvider(a) === 'finnhub');
  if (!list.length) { PX.st.finnhub = 'idle'; return; }
  PX.st.finnhub = 'loading'; const k = encodeURIComponent(S.settings.finnhubKey.trim());
  let ok = 0;
  for (const a of list) {
    try {
      const j = await fetchJSON(`https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(a.symbol)}&token=${k}`);
      if (j && j.c > 0) { setPrice(a.id, j.c, a.quoteCcy || 'USD', j.dp, 'finnhub', { pc: j.pc }); ok++; }
    } catch (e) { PX.st.err.finnhub = 'Finnhub: ' + e.message + ' (revisa la clave; el plan gratis solo cubre EE. UU.)'; }
  }
  PX.st.finnhub = ok ? 'ok' : 'error'; if (ok) delete PX.st.err.finnhub;
}
function connectFinnhub() {
  const list = S.assets.filter(a => a.kind === 'stock' && !a.archived && resolveProvider(a) === 'finnhub');
  const syms = [...new Set(list.map(a => a.symbol))].sort(); const key = S.settings.finnhubKey ? syms.join(',') : '';
  if (key === PX.fKey && PX.fws && PX.fws.readyState <= 1) return;
  PX.fKey = key;
  if (PX.fws) { const o = PX.fws; PX.fws = null; try { o.close(); } catch (e) { } }
  clearTimeout(PX.timers.f);
  if (!key || document.hidden) { PX.st.fws = 'off'; return; }
  let ws; try { ws = new WebSocket('wss://ws.finnhub.io?token=' + encodeURIComponent(S.settings.finnhubKey.trim())); } catch (e) { return; }
  PX.fws = ws; PX.st.fws = 'connecting';
  ws.onopen = () => { PX.st.fws = 'live'; PX.fTry = 0; syms.forEach(s => ws.send(JSON.stringify({ type: 'subscribe', symbol: s }))); updateLive(); };
  ws.onmessage = ev => {
    let m; try { m = JSON.parse(ev.data); } catch (e) { return; }
    if (m.type !== 'trade' || !Array.isArray(m.data)) return;
    const last = {}; for (const d of m.data) last[d.s] = d.p;
    for (const [s, p] of Object.entries(last)) for (const a of list) if (a.symbol === s) setPrice(a.id, p, a.quoteCcy || 'USD', null, 'finnhub');
  };
  ws.onclose = () => { if (PX.fws !== ws) return; PX.fws = null; PX.st.fws = 'off'; PX.fTry++; updateLive(); PX.timers.f = setTimeout(() => { PX.fKey = ''; connectFinnhub(); }, Math.min(60000, 3000 * PX.fTry)); };
  ws.onerror = () => { };
}

/* ---------- búsquedas ---------- */
async function searchCrypto(q) {
  const j = await fetchJSON('https://api.coingecko.com/api/v3/search?query=' + encodeURIComponent(q));
  return (j.coins || []).slice(0, 12).map(c => ({ symbol: String(c.symbol).toUpperCase(), name: c.name, cgId: c.id, sub: c.market_cap_rank ? `#${c.market_cap_rank} por capitalización` : 'CoinGecko' }));
}
async function searchStocks(q) {
  if (S.settings.yahooProxy) {
    const j = await fetchJSON(proxyUrl('search=' + encodeURIComponent(q)), 15000);
    return (j.results || []).slice(0, 12).map(r => ({ symbol: r.symbol, name: r.name, sub: [r.exchange, r.type].filter(Boolean).join(' · '), provider: 'yahoo' }));
  }
  if (NATIVE) {
    const j = await fetchJSON(`https://query1.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(q)}&quotesCount=12&newsCount=0`, 15000);
    return (j.quotes || []).filter(x => x.symbol && x.quoteType !== 'OPTION').slice(0, 12).map(x => ({ symbol: x.symbol, name: x.longname || x.shortname || x.symbol, sub: [x.exchDisp || x.exchange, x.typeDisp || x.quoteType].filter(Boolean).join(' · '), provider: 'yahoo' }));
  }
  if (S.settings.finnhubKey) {
    const j = await fetchJSON(`https://finnhub.io/api/v1/search?q=${encodeURIComponent(q)}&token=${encodeURIComponent(S.settings.finnhubKey.trim())}`);
    return (j.result || []).filter(r => !r.symbol.includes('.')).slice(0, 12).map(r => ({ symbol: r.symbol, name: r.description, sub: r.type || 'Finnhub', provider: 'finnhub', quoteCcy: 'USD' }));
  }
  return [];
}
async function testProxy() {
  const j = await fetchJSON(proxyUrl('symbols=AAPL,SAN.MC'), 15000);
  const q = (j.quotes || []).filter(x => x.price > 0);
  if (!q.length) throw new Error('el proxy responde pero sin precios');
  return q.map(x => `${x.symbol} ${fmtPrice(x.price, normCcy(x.price, x.currency)[1] || 'USD')}`).join(' · ');
}

/* ---------- ciclo ---------- */
function startPrices() {
  refreshFx(); pollCrypto(); pollYahoo(); pollFinnhub(); connectBinance(); connectFinnhub();
  clearInterval(PX.timers.c); clearInterval(PX.timers.s); clearInterval(PX.timers.x); clearInterval(PX.timers.save);
  PX.timers.c = setInterval(() => { if (!document.hidden) pollCrypto(); }, Math.max(60, S.settings.refreshSec) * 1000);
  PX.timers.s = setInterval(() => { if (!document.hidden) { pollYahoo(); pollFinnhub(); } }, Math.max(15, S.settings.refreshSec) * 1000);
  PX.timers.x = setInterval(() => { if (!document.hidden) refreshFx(); }, 10 * 60 * 1000);
  PX.timers.save = setInterval(() => { if (PX.dirty) { PX.dirty = false; recordSnapshot(portfolio()); saveNow(); } }, 20000);
}
function restartFeeds() { PX.bKey = ''; PX.fKey = ''; connectBinance(); connectFinnhub(); pollCrypto(); pollYahoo(); pollFinnhub(); }
document.addEventListener('visibilitychange', () => {
  if (!S) return;
  if (document.hidden) { if (PX.dirty) { PX.dirty = false; recordSnapshot(portfolio()); saveNow(); } connectBinance(); connectFinnhub(); }
  else { runRecurring(); refreshFx(); restartFeeds(); render(); }
});

function liveState() {
  const hasCrypto = S.assets.some(a => a.kind === 'crypto' && !a.archived);
  const hasStock = S.assets.some(a => a.kind === 'stock' && !a.archived);
  if (PX.st.binance === 'live' || PX.st.fws === 'live') return { cls: 'on', txt: 'En directo' };
  if (PX.st.last && Date.now() - PX.st.last < 3 * 60 * 1000) return { cls: 'on', txt: 'Actualizado' };
  if (Object.keys(PX.st.err).length) return { cls: 'warn', txt: 'Revisar' };
  if (!hasCrypto && !hasStock) return { cls: '', txt: 'Precios' };
  return { cls: '', txt: 'Conectando' };
}
function updateLive() {
  const b = $('#liveBtn'); if (!b) return; const l = liveState();
  b.className = 'live ' + l.cls; $('#liveTxt').textContent = l.txt;
}
