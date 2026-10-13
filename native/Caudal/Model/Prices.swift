import Foundation

/// Cotizaciones de Yahoo Finance (acciones, ETF y cripto en EUR: BTC-EUR, ETH-EUR…). Desde la app nativa no hace falta proxy.
enum Prices {
    struct Chart {
        var points: [(date: Date, close: Double)]
        var quote: Quote
    }

    static func chart(_ symbol: String, range: String = "1mo", interval: String = "1d") async throws -> Chart {
        let s = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var req = URLRequest(url: URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(s)?range=\(range)&interval=\(interval)")!)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = root["chart"] as? [String: Any],
              let res = (chart["result"] as? [[String: Any]])?.first,
              let meta = res["meta"] as? [String: Any],
              let price = meta["regularMarketPrice"] as? Double else { throw URLError(.badServerResponse) }
        let prev = (meta["chartPreviousClose"] as? Double) ?? (meta["previousClose"] as? Double) ?? price
        let ccy = (meta["currency"] as? String) ?? "EUR"
        var pts: [(Date, Double)] = []
        if let ts = res["timestamp"] as? [Double],
           let q = ((res["indicators"] as? [String: Any])?["quote"] as? [[String: Any]])?.first,
           let closes = q["close"] as? [Any] {
            for (i, t) in ts.enumerated() where i < closes.count {
                if let c = closes[i] as? Double { pts.append((Date(timeIntervalSince1970: t), c)) }
            }
        }
        // el cambio del día: contra el cierre anterior (en gráficos de varios días, el penúltimo cierre)
        var dayPrev = prev
        if range != "1d", pts.count >= 2 { dayPrev = pts[pts.count - 2].1 }
        return Chart(points: pts.map { (date: $0.0, close: $0.1) }, quote: Quote(price: price, previousClose: dayPrev, currency: ccy, updated: Date()))
    }

    /// actualiza todas las cotizaciones de la cartera
    @MainActor
    static func refresh(_ store: Store) async {
        store.refreshing = true
        defer { store.refreshing = false }
        let symbols = Set(store.state.assets.filter { !$0.archived }.map(\.ySymbol))
        await withTaskGroup(of: (String, Quote?).self) { g in
            for s in symbols {
                g.addTask { (s, try? await chart(s, range: "5d").quote) }
            }
            for await (s, q) in g {
                if let q { store.state.quotes[s] = q }
            }
        }
    }
}
