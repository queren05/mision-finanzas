import Foundation

/// Datos de partida: categorías por defecto. Los datos personales (cuentas y movimientos reales) no están en el código:
/// se leen de `seed-personal.json`, que no se sube a git (ver .gitignore) y GitHub Actions lo pone desde un secreto.
enum Seed {
    static let version = 7

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
        s.seed = version
    }
}
