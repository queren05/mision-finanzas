import Foundation

/// Convierte la copia de seguridad JSON de la versión web (Misión Finanzas / Caudal 2.x) al formato de la app nativa.
enum WebImport {
    enum Failure: LocalizedError {
        case notBackup
        var errorDescription: String? { "El archivo no es una copia de seguridad de Caudal." }
    }

    static func convert(_ data: Data) throws -> AppState {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accs = root["accounts"] as? [[String: Any]] else { throw Failure.notBackup }
        func s(_ d: [String: Any], _ k: String, _ def: String = "") -> String { (d[k] as? String) ?? def }
        func n(_ d: [String: Any], _ k: String) -> Double { (d[k] as? Double) ?? Double(d[k] as? Int ?? 0) }
        func b(_ d: [String: Any], _ k: String, _ def: Bool) -> Bool { (d[k] as? Bool) ?? def }

        var st = AppState()
        st.seed = Seed.version
        for (i, a) in accs.enumerated() {
            let type = AccountType(rawValue: s(a, "type", "corriente")) ?? .otro
            st.accounts.append(Account(id: s(a, "id", UUID().uuidString), name: s(a, "name", "Cuenta"), type: type, currency: s(a, "currency", "EUR"),
                                       initial: n(a, "initial"), color: s(a, "color", palette[i % palette.count]), icon: s(a, "icon", type.icon),
                                       includeInTotal: b(a, "includeInTotal", true), archived: b(a, "archived", false), order: (a["order"] as? Int) ?? i, note: s(a, "note")))
        }
        for c in (root["categories"] as? [[String: Any]]) ?? [] {
            st.categories.append(Category(id: s(c, "id", UUID().uuidString), kind: s(c, "kind") == "income" ? .income : .expense, name: s(c, "name", "Categoría"),
                                          icon: s(c, "icon", "📦"), color: s(c, "color", "#a9b3c2"), budget: n(c, "budget"), keywords: s(c, "keywords"), hidden: b(c, "hidden", false)))
        }
        if st.categories.isEmpty { st.categories = Seed.categories() }
        for t in (root["txs"] as? [[String: Any]]) ?? [] {
            guard let type = TxType(rawValue: s(t, "type", "expense")) else { continue }
            let tags = ((t["tags"] as? [String]) ?? []).map { "#" + $0 }.joined(separator: " ")
            st.txs.append(Tx(id: s(t, "id", UUID().uuidString), type: type, amount: n(t, "amount"), accountId: s(t, "accountId"),
                             toAccountId: t["toAccountId"] as? String, categoryId: t["categoryId"] as? String, date: s(t, "date", Day.today),
                             time: "12:00", title: s(t, "note"), note: tags, excluded: b(t, "excl", false), recurringId: t["recId"] as? String))
        }
        for r in (root["recurring"] as? [[String: Any]]) ?? [] {
            let tpl = (r["tpl"] as? [String: Any]) ?? [:]
            let freq: Freq = s(r, "freq") == "weekly" ? .weekly : (s(r, "freq") == "yearly" ? .yearly : .monthly)
            st.recurring.append(Recurring(id: s(r, "id", UUID().uuidString), name: s(r, "name", "Recurrente"), type: s(tpl, "type", "expense"),
                                          amount: n(tpl, "amount"), accountId: s(tpl, "accountId"), toAccountId: tpl["toAccountId"] as? String,
                                          categoryId: tpl["categoryId"] as? String, assetId: tpl["assetId"] as? String, freq: freq,
                                          day: (r["day"] as? Int) ?? 1, next: s(r, "next", Day.today), active: b(r, "active", true)))
        }
        for a in (root["assets"] as? [[String: Any]]) ?? [] {
            if b(a, "watch", false) { continue }
            let kind = s(a, "kind", "stock")
            let sym = s(a, "symbol", "?")
            var y = s(a, "ySymbol")
            if y.isEmpty { y = kind == "crypto" ? sym.uppercased() + "-EUR" : sym }
            var asset = Asset(id: s(a, "id", UUID().uuidString), kind: kind, symbol: sym, ySymbol: y, name: s(a, "name", sym), isin: s(a, "isin"),
                              accountId: a["accountId"] as? String, manualPrice: n(a, "manualPrice"), color: s(a, "color", "#6fd49b"), archived: b(a, "archived", false))
            for o in (a["ops"] as? [[String: Any]]) ?? [] {
                let side: OpSide = s(o, "side") == "sell" ? .sell : (s(o, "side") == "reward" ? .reward : .buy)
                if s(o, "side") == "out" { continue }
                asset.ops.append(AssetOp(id: s(o, "id", UUID().uuidString), side: side, qty: n(o, "qty"), price: n(o, "price"), fee: n(o, "fee"),
                                         date: s(o, "date", Day.today), cashAccountId: o["cashAccountId"] as? String))
            }
            st.assets.append(asset)
        }
        for g in (root["goals"] as? [[String: Any]]) ?? [] {
            st.goals.append(Goal(id: s(g, "id", UUID().uuidString), name: s(g, "name", "Objetivo"), icon: s(g, "icon", "🎯"), color: s(g, "color", "#f0c46a"),
                                 target: n(g, "target"), saved: n(g, "manual"), deadline: s(g, "deadline"),
                                 accountId: (g["source"] as? [String: Any]).flatMap { s($0, "t") == "account" ? $0["id"] as? String : nil }))
        }
        if let set = root["settings"] as? [String: Any] {
            let name = s(set, "name")
            if !name.isEmpty { st.settings.name = name }
            st.settings.monthStart = (set["monthStart"] as? Int) ?? 1
        }
        return st
    }
}
