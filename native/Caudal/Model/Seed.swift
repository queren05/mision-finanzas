import Foundation

/// Datos de partida: categorías por defecto y las cuentas y movimientos reales de David (Revolut y Trade Republic, octubre de 2026).
enum Seed {
    static let version = 3

    static func categories() -> [Category] {
        let e: [(String, String, String, String)] = [
            ("c_super", "Supermercado", "🛒", "mercadona, lidl, carrefour, dia, alcampo, aldi, eroski, ahorramas, hipercor, consum, alimentacion, mini super"),
            ("c_rest", "Restaurantes", "🍽️", "restaurante, taberna, bar, sushi, glovo, just eat, uber eats, burger king, mcdonald, telepizza, kfc"),
            ("c_snack", "Cafés y snacks", "☕", "arbitrade, alliance vending, vending, starbucks, cafeteria"),
            ("c_transp", "Transporte", "🚇", "metro, renfe, emt, crtm, cabify, uber, bolt, blablacar, alsa"),
            ("c_coche", "Coche y gasolina", "⛽", "e. s, e.s, estacion de servicio, repsol, cepsa, moeve, galp, shell, gasolinera, parking, itv, peaje"),
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
            ("c_otros", "Otros gastos", "📦", ""),
        ]
        let i: [(String, String, String, String)] = [
            ("i_nomina", "Nómina", "💼", "nomina, nómina, salario"),
            ("i_bizum", "Bizum recibido", "📲", "bizum de"),
            ("i_reemb", "Reembolsos", "↩️", "refund, reembolso, devolucion"),
            ("i_familia", "Familia", "👨‍👩‍👦", "mama, papa"),
            ("i_int", "Intereses y dividendos", "📈", "intereses, dividendo"),
            ("i_ventas", "Ventas", "🏷️", "wallapop, vinted"),
            ("i_otros", "Otros ingresos", "➕", ""),
        ]
        var out: [Category] = []
        for (n, c) in e.enumerated() { out.append(Category(id: c.0, kind: .expense, name: c.1, icon: c.2, color: palette[n % palette.count], keywords: c.3)) }
        for (n, c) in i.enumerated() { out.append(Category(id: c.0, kind: .income, name: c.1, icon: c.2, color: palette[(n + 2) % palette.count], keywords: c.3)) }
        return out
    }

    static func david() -> AppState {
        var s = AppState()
        s.seed = version
        s.categories = categories()
        let rev = Account(id: "a_revolut", name: "Revolut", type: .corriente, initial: 115.10, color: "#8fb4ff", icon: "🏦", order: 0)
        let conj = Account(id: "a_conjunta", name: "Conjunta", type: .ahorro, initial: 0, color: "#f59fc4", icon: "💞", order: 1, note: "Bolsillo conjunto de Revolut")
        let tr = Account(id: "a_tr", name: "Trade Republic", type: .ahorro, initial: 500, color: "#e4b3cb", icon: "🐷", order: 2, note: "Efectivo remunerado")
        let etf = Account(id: "a_etf", name: "TR · ETF", type: .broker, initial: 0, color: "#6fd49b", icon: "📊", order: 3)
        s.accounts = [rev, conj, tr, etf]

        // fondos de Trade Republic (precio de TR del 30/09; luego se actualiza en vivo con Yahoo)
        var sp = Asset(id: "s_sp500", symbol: "S&P 500", ySymbol: "500.PA", name: "S&P 500 EUR (Acc)", isin: "LU1681048804", accountId: etf.id, manualPrice: 135.265, color: "#f0c46a")
        let spQty = 310.56 / 135.265
        sp.ops = [AssetOp(side: .buy, qty: spQty, price: (310.56 / 1.0318) / spQty, date: "2026-09-30")]
        var acwi = Asset(id: "s_acwi", symbol: "MSCI ACWI", ySymbol: "IUSQ.DE", name: "MSCI ACWI USD (Acc)", isin: "IE00B6R52259", accountId: etf.id, manualPrice: 108.46, color: "#62cfd0")
        let acQty = 101.74 / 108.46
        acwi.ops = [AssetOp(side: .buy, qty: acQty, price: 100 / acQty, date: "2026-09-30"),
                    AssetOp(side: .buy, qty: 100 / 108.46, price: 108.46, date: "2026-10-02", cashAccountId: tr.id)]   // plan del día 2
        s.assets = [sp, acwi]

        // recurrentes: plan de inversión y el gimnasio
        s.recurring = [
            Recurring(id: "r_plan", name: "Plan MSCI ACWI", type: "invest", amount: 100, accountId: tr.id, assetId: acwi.id, freq: .monthly, day: 2, next: "2026-11-02"),
            Recurring(id: "r_gym", name: "VivaGym", type: "expense", amount: 29.90, accountId: rev.id, categoryId: "c_deporte", freq: .monthly, day: 5, next: "2026-11-05"),
        ]

        func g(_ date: String, _ time: String, _ title: String, _ amount: Double, _ cat: String, _ note: String = "") -> Tx {
            Tx(type: .expense, amount: amount, accountId: rev.id, categoryId: cat, date: date, time: time, title: title, note: note)
        }
        func i(_ date: String, _ time: String, _ title: String, _ amount: Double, _ cat: String, _ note: String = "") -> Tx {
            Tx(type: .income, amount: amount, accountId: rev.id, categoryId: cat, date: date, time: time, title: title, note: note)
        }
        func t(_ date: String, _ time: String, _ from: String, _ to: String, _ amount: Double, _ title: String) -> Tx {
            Tx(type: .transfer, amount: amount, accountId: from, toAccountId: to, date: date, time: time, title: title)
        }
        s.txs = [
            // 1 y 2 de octubre: lo que no sale en las capturas va como ajuste para cuadrar el saldo real
            Tx(type: .adjust, amount: -58.53, accountId: rev.id, date: "2026-10-02", time: "23:59", title: "Movimientos del 1 y 2 de octubre", note: "Sin detallar: cuadra el saldo de Revolut"),
            g("2026-10-02", "22:25", "Alfonso", 3, "c_amigos", "Bizum"),
            // 3 de octubre
            g("2026-10-03", "14:28", "Miamor", 17.29, "c_super", "Mercadona"),
            g("2026-10-03", "11:10", "E. S. San Fernando", 23.76, "c_coche"),
            g("2026-10-03", "11:09", "Estanco", 5.40, "c_tabaco"),
            // 4 de octubre
            g("2026-10-04", "22:12", "Sushi Mood", 28.20, "c_rest"),
            g("2026-10-04", "21:06", "Miamor", 5.23, "c_pareja", "Pene action"),
            t("2026-10-04", "21:03", rev.id, conj.id, 10, "Personal → Conjunta"),
            t("2026-10-04", "21:00", tr.id, rev.id, 100.82, "Trade Republic → Revolut"),
            // 5 de octubre
            g("2026-10-05", "19:59", "Alimentación", 2, "c_super"),
            g("2026-10-05", "14:18", "Snzy", 20, "c_ocio"),
            t("2026-10-05", "14:18", tr.id, rev.id, 100, "Trade Republic → Revolut"),
            g("2026-10-05", "14:07", "Alvaro", 8.50, "c_amigos", "Bizum"),
            g("2026-10-05", "14:06", "Jorlo", 18.50, "c_amigos", "Bizum"),
            g("2026-10-05", "07:15", "VivaGym", 29.90, "c_deporte", "Recibo VivaGym"),
            // 6 de octubre
            i("2026-10-06", "19:17", "Jorlo", 11.11, "i_bizum", "Vicios varios"),
            i("2026-10-06", "19:17", "Daria", 9.25, "i_bizum", "Bizum de Daria"),
            g("2026-10-06", "18:34", "Alcampo", 35.10, "c_super"),
            i("2026-10-06", "15:36", "Devolución de Snzy", 20, "i_reemb", "Provisional refund for Snzy claim"),
            // 9 de octubre
            g("2026-10-09", "21:22", "E. S. San Fernando", 19, "c_coche"),
            i("2026-10-09", "18:36", "Miamor", 9.20, "i_reemb", "Para Parque Corredor Pos"),
            g("2026-10-09", "18:35", "Parque Corredor", 18.40, "c_ocio", "Factura dividida"),
            i("2026-10-09", "18:17", "Miamor", 1.90, "i_reemb", "Para Alimentación Jinling Han"),
            g("2026-10-09", "17:58", "Alimentación Jinling Han", 3.80, "c_super", "Factura dividida"),
            i("2026-10-09", "17:58", "Miamor", 7.67, "i_reemb", "Para Groupon"),
            g("2026-10-09", "17:57", "Estanco", 14.15, "c_tabaco"),
            g("2026-10-09", "16:57", "Groupon", 15.33, "c_ocio", "Factura dividida"),
            // 10 de octubre
            g("2026-10-10", "11:45", "Mini Super", 10, "c_super"),
            // 12 de octubre
            g("2026-10-12", "20:06", "Arbitrade", 1.50, "c_snack", "Máquina de vending"),
            g("2026-10-12", "20:05", "Arbitrade", 0.95, "c_snack", "Máquina de vending"),
            i("2026-10-12", "14:40", "Mamá", 50, "i_familia"),
            g("2026-10-12", "14:23", "Miamor", 6, "c_rest", "Para Bar Don Lorenzo"),
            g("2026-10-12", "13:09", "Toys R Us", 3.99, "c_compras"),
            g("2026-10-12", "12:48", "E. S. San Fernando", 29.30, "c_coche"),
            t("2026-10-12", "12:30", tr.id, rev.id, 100, "Trade Republic → Revolut"),
            g("2026-10-12", "11:54", "Taberna de Irene", 9.55, "c_rest"),
            // Trade Republic: el efectivo disponible es de 100,00 € (con los intereses cobrados)
            Tx(type: .adjust, amount: 0.82, accountId: tr.id, date: "2026-10-13", time: "01:38", title: "Intereses de Trade Republic", note: "Cuadra el efectivo disponible (100,00 €)"),
        ]
        return s
    }
}
