import Foundation

/// Datos de partida: categorías por defecto. Los datos personales (cuentas y movimientos reales) no están en el código:
/// se leen de `seed-personal.json`, que no se sube a git (ver .gitignore) y GitHub Actions lo pone desde un secreto.
enum Seed {
    static let version = 14

    static func categories() -> [Category] {
        let e: [(String, String, String, String)] = [
            ("c_super", "Supermercado", "🛒", "mercadona, lidl, carrefour, dia, alcampo, aldi, eroski, ahorramas, hipercor, consum, alimentacion, mini super"),
            ("c_rest", "Restaurantes", "🍽️", "restaurante, taberna, bar, sushi, glovo, just eat, uber eats, burger king, mcdonald, telepizza, kfc"),
            ("c_snack", "Cafés y snacks", "☕", "arbitrade, alliance vending, vending, starbucks, cafeteria"),
            ("c_transp", "Transporte", "🚇", "metro, renfe, emt, crtm, cabify, uber, bolt, blablacar, alsa"),
            ("c_coche", "Coche y gasolina", "⛽", "easypark, e. s, e.s, estacion de servicio, repsol, cepsa, moeve, galp, shell, gasolinera, parking, itv, peaje"),
            ("c_casa", "Vivienda", "🏠", "alquiler, hipoteca, comunidad, ibi"),
            ("c_fact", "Facturas", "💡", "iberdrola, endesa, naturgy, movistar, vodafone, orange, digi, pepephone"),
            ("c_subs", "Suscripciones", "📺", "netflix, spotify, hbo, disney, amazon prime, youtube premium, icloud, chatgpt"),
            ("c_ocio", "Ocio", "🎮", "steam, playstation, nintendo, cine, groupon, parque, snzy, entradas"),
            ("c_compras", "Compras", "🛍️", "amazon, aliexpress, shein, temu, zara, primark, toys r us, decathlon, mediamarkt, ikea"),
            ("c_tabaco", "Tabaco", "🚬", "estanco"),
            ("c_salud", "Salud", "💊", "farmacia, dentista, clinica, optica"),
            ("c_deporte", "Deporte", "🏋️", "vivagym, gimnasio, basic-fit, altafit"),
            ("c_amigos", "Amigos y Bizum", "👥", "bizum a"),
            ("c_pareja", "Pareja", "❤️", "miamor"),
            ("c_regalos", "Regalos", "🎁", ""),
            ("c_viajes", "Viajes", "✈️", "booking, airbnb, ryanair, iberia, vueling, hotel"),
            ("c_formacion", "Formación", "📚", "udemy, coursera, google play console, libreria"),
            ("c_comisiones", "Comisiones", "🏦", "comision, comisión, mantenimiento cuenta"),
            ("c_otros", "Otros gastos", "📦", ""),
        ]
        let i: [(String, String, String, String)] = [
            ("i_nomina", "Nómina", "💼", "nomina, nómina, salario"),
            ("i_bizum", "Bizum recibido", "📲", "bizum de"),
            ("i_reemb", "Reembolsos", "↩️", "refund, reembolso, devolucion"),
            ("i_familia", "Familia", "👨‍👩‍👦", "mama, papa"),
            ("i_pareja", "Pareja", "❤️", "miamor"),
            ("i_int", "Intereses y dividendos", "📈", "intereses, dividendo"),
            ("i_ventas", "Ventas", "🏷️", "wallapop, vinted"),
            ("i_otros", "Otros ingresos", "➕", ""),
        ]
        var out: [Category] = []
        let budgets: [String: Double] = ["c_rest": 100, "c_coche": 200, "c_ocio": 100, "c_compras": 100]   // los de la app antigua
        for (n, c) in e.enumerated() { out.append(Category(id: c.0, kind: .expense, name: c.1, icon: c.2, color: palette[n % palette.count], budget: budgets[c.0] ?? 0, keywords: c.3)) }
        for (n, c) in i.enumerated() { out.append(Category(id: c.0, kind: .income, name: c.1, icon: c.2, color: palette[(n + 2) % palette.count], keywords: c.3)) }
        return out
    }

    /// datos de partida: los personales si la app los lleva dentro; si no, vacía con las categorías por defecto
    static func david() -> AppState {
        if let url = Bundle.main.url(forResource: "seed-personal", withExtension: "json"),
           let data = try? Data(contentsOf: url), var s = try? JSONDecoder().decode(AppState.self, from: data) {
            s.seed = version
            return s
        }
        var s = AppState()
        s.seed = version
        s.categories = categories()
        return s
    }

    /// pone al día los datos guardados con versiones anteriores de los datos de partida sin tocar lo apuntado
    static func migrate(_ s: inout AppState) {
        for c in categories() where !s.categories.contains(where: { $0.id == c.id }) { s.categories.append(c) }
        if s.seed < 7 {
            let order = ["a_revolut": 0, "a_tr": 1, "a_conjunta": 2, "a_etf": 3]
            for i in s.accounts.indices { if let o = order[s.accounts[i].id] { s.accounts[i].order = o } else if s.accounts[i].order < 4 { s.accounts[i].order += 4 } }
        }
        if s.seed < 10 {
            // Nov 2026: el plan mensual pasa de 100 € al MSCI ACWI a 50 € al MSCI ACWI y 50 € al S&P 500.
            if let i = s.recurring.firstIndex(where: { $0.id == "r_plan" }) {
                s.recurring[i].amount = 50
                if s.assets.contains(where: { $0.id == "s_sp500" }) && !s.recurring.contains(where: { $0.id == "r_plan_sp500" }) {
                    var sp = s.recurring[i]
                    sp.id = "r_plan_sp500"
                    sp.name = "Plan S&P 500"
                    sp.assetId = "s_sp500"
                    s.recurring.insert(sp, at: i + 1)
                }
            }
        }
        if s.seed < 11 {
            // Nov 2026: se retiran las empresas de trabajo por horas (su historial de turnos se conserva)
            for i in s.companies.indices { s.companies[i].archived = true }
        }
        if s.seed < 12 {
            // Nov 2026: la empresa «Altius» pasa a llamarse «UPS» (si ya hay una «UPS», sus turnos van a ella)
            if let a = s.companies.firstIndex(where: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == "altius" }) {
                if let u = s.companies.first(where: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == "ups" }) {
                    let from = s.companies[a].id
                    for i in s.shifts.indices where s.shifts[i].companyId == from { s.shifts[i].companyId = u.id }
                } else { s.companies[a].name = "UPS" }
            }
            // el contrato ya no tiene día de cobro: la nómina se apunta a mano cuando llega
            if let j = s.job { s.recurring.removeAll { $0.id == j.recurringId } }
        }
        if s.seed < 13 {
            // Nov 2026: octubre de 2026 queda como cobrado sin apuntar ingreso (la nómina ya estaba metida a mano)
            for i in s.shifts.indices where Day.monthKey(s.shifts[i].date) == "2026-10" && s.shifts[i].status == .pendiente {
                s.shifts[i].status = .pagado; s.shifts[i].paidDate = Day.today
            }
            if var j = s.job, j.start <= "2026-10-31" {
                j.paidMonths = Array(Set((j.paidMonths ?? []) + ["2026-10"])).sorted(); s.job = j
            }
        }
        if s.seed < 14 {
            // 23-nov-2026: gastos de Revolut que faltaban (20 y 21 de noviembre)
            let faltan: [Tx] = [
                Tx(id: "m14_estanco", amount: 7.10, accountId: "a_revolut", categoryId: "c_tabaco", date: "2026-11-20", time: "19:11", title: "Estanco"),
                Tx(id: "m14_alim1", amount: 3.70, accountId: "a_revolut", categoryId: "c_super", date: "2026-11-20", time: "19:26", title: "Alimentación"),
                Tx(id: "m14_alim2", amount: 2, accountId: "a_revolut", categoryId: "c_super", date: "2026-11-20", time: "21:12", title: "Alimentación"),
                Tx(id: "m14_kfc", amount: 20.65, accountId: "a_revolut", categoryId: "c_rest", date: "2026-11-20", time: "22:46", title: "KFC"),
                Tx(id: "m14_monda", amount: 6.75, accountId: "a_revolut", categoryId: "c_super", date: "2026-11-21", time: "21:46", title: "Monda"),
            ]
            for t in faltan where !s.txs.contains(where: { $0.id == t.id || ($0.date == t.date && $0.accountId == t.accountId && abs($0.amount - t.amount) < 0.001 && $0.type == .expense) }) {
                s.txs.append(t)
            }
        }
        s.seed = version
    }
}
