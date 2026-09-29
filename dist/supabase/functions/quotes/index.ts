// Proxy de cotizaciones de Yahoo Finance para Misión Finanzas.
// Yahoo no permite consultarse desde el navegador (CORS), así que esta función hace de puente.
//
// Despliegue (desde la carpeta que contiene /supabase):
//   supabase functions deploy quotes --no-verify-jwt
// URL resultante:  https://<tu-proyecto>.supabase.co/functions/v1/quotes
//
// Uso:
//   ?symbols=AAPL,SAN.MC,VWCE.DE   -> { quotes: [{ symbol, price, prevClose, currency, name, marketState, time }] }
//   ?search=inditex                -> { results: [{ symbol, name, exchange, type }] }

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};
const UA = { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36" };
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json", "Cache-Control": "max-age=10" } });

async function quote(symbol: string) {
  try {
    const r = await fetch(`https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=1d`, { headers: UA });
    const j = await r.json();
    const m = j?.chart?.result?.[0]?.meta;
    if (!m || typeof m.regularMarketPrice !== "number") return { symbol, error: "sin datos" };
    return {
      symbol,
      price: m.regularMarketPrice,
      prevClose: m.chartPreviousClose ?? m.previousClose ?? null,
      currency: m.currency ?? null,
      name: m.longName ?? m.shortName ?? symbol,
      marketState: m.marketState ?? null,
      time: m.regularMarketTime ?? null,
    };
  } catch (_e) {
    return { symbol, error: "fallo al consultar" };
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const url = new URL(req.url);

  const chart = url.searchParams.get("chart");
  if (chart) {
    const range = url.searchParams.get("range") ?? "1mo", interval = url.searchParams.get("interval") ?? "1d";
    try {
      const r = await fetch(`https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(chart)}?range=${range}&interval=${interval}`, { headers: UA });
      const j = await r.json();
      return json({ result: j?.chart?.result?.[0] ?? null });
    } catch (_e) { return json({ result: null, error: "fallo al consultar" }, 502); }
  }

  const q = url.searchParams.get("search");
  if (q) {
    try {
      const r = await fetch(`https://query1.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(q)}&quotesCount=12&newsCount=0`, { headers: UA });
      const j = await r.json();
      const results = (j.quotes ?? [])
        .filter((x: any) => x.symbol && x.quoteType !== "OPTION")
        .map((x: any) => ({ symbol: x.symbol, name: x.longname ?? x.shortname ?? x.symbol, exchange: x.exchDisp ?? x.exchange, type: x.typeDisp ?? x.quoteType }));
      return json({ results });
    } catch (_e) {
      return json({ results: [], error: "fallo en la búsqueda" }, 502);
    }
  }

  const symbols = (url.searchParams.get("symbols") ?? "").split(",").map((s) => s.trim()).filter(Boolean).slice(0, 50);
  if (!symbols.length) return json({ error: "Usa ?symbols=AAPL,SAN.MC o ?search=texto" }, 400);
  const quotes = await Promise.all(symbols.map(quote));
  return json({ quotes });
});
