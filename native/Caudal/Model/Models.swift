import Foundation

// MARK: - Modelo de datos (se guarda como JSON en Documentos)

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case corriente, ahorro, efectivo, tarjeta, exchange, broker, activo, deuda, otro
    var id: String { rawValue }
    var label: String {
        switch self {
        case .corriente: "Cuenta corriente"
        case .ahorro: "Ahorro"
        case .efectivo: "Efectivo"
        case .tarjeta: "Tarjeta de crédito"
        case .exchange: "Exchange cripto"
        case .broker: "Bróker"
        case .activo: "Bien (casa, coche…)"
        case .deuda: "Préstamo o hipoteca"
        case .otro: "Otro"
        }
    }
    var icon: String {
        switch self {
        case .corriente: "🏦"
        case .ahorro: "🐷"
        case .efectivo: "💶"
        case .tarjeta: "💳"
        case .exchange: "🪙"
        case .broker: "📊"
        case .activo: "🏠"
        case .deuda: "📉"
        case .otro: "💼"
        }
    }
}

struct Account: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var type: AccountType = .corriente
    var currency: String = "EUR"
    var initial: Double = 0
    var color: String = "#8fb4ff"
    var icon: String = "🏦"
    var includeInTotal: Bool = true
    var archived: Bool = false
    var order: Int = 0
    var note: String = ""
}

enum CatKind: String, Codable, CaseIterable, Identifiable {
    case expense, income
    var id: String { rawValue }
    var label: String { self == .expense ? "Gasto" : "Ingreso" }
}

struct Category: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var kind: CatKind = .expense
    var name: String
    var icon: String = "📦"
    var color: String = "#a9b3c2"
    var budget: Double = 0
    var keywords: String = ""
    var hidden: Bool = false
}

enum TxType: String, Codable, CaseIterable, Identifiable {
    case expense, income, transfer, adjust
    var id: String { rawValue }
    var label: String {
        switch self {
        case .expense: "Gasto"
        case .income: "Ingreso"
        case .transfer: "Transferencia"
        case .adjust: "Ajuste de saldo"
        }
    }
}

struct Tx: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var type: TxType = .expense
    /// Siempre positivo, salvo en los ajustes (llevan signo).
    var amount: Double
    var accountId: String
    var toAccountId: String? = nil
    var categoryId: String? = nil
    /// yyyy-MM-dd
    var date: String
    /// HH:mm
    var time: String = "12:00"
    var title: String = ""
    var note: String = ""
    var excluded: Bool = false
    var recurringId: String? = nil

    var sortKey: String { date + " " + time }
}

enum Freq: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weekly: "Cada semana"
        case .monthly: "Cada mes"
        case .yearly: "Cada año"
        }
    }
}

struct Recurring: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// expense / income / transfer / invest (compra de un activo con el dinero de la cuenta)
    var type: String = "expense"
    var amount: Double
    var accountId: String
    var toAccountId: String? = nil
    var categoryId: String? = nil
    var assetId: String? = nil
    var freq: Freq = .monthly
    var day: Int = 1
    /// próxima fecha yyyy-MM-dd
    var next: String
    var active: Bool = true
}

enum OpSide: String, Codable, CaseIterable, Identifiable {
    case buy, sell, reward
    var id: String { rawValue }
    var label: String {
        switch self {
        case .buy: "Compra"
        case .sell: "Venta"
        case .reward: "Recompensa"
        }
    }
}

struct AssetOp: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var side: OpSide = .buy
    var qty: Double
    var price: Double
    var fee: Double = 0
    var date: String
    /// cuenta de la que sale (o a la que entra) el dinero
    var cashAccountId: String? = nil
}

struct Asset: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    /// "stock" o "crypto"
    var kind: String = "stock"
    var symbol: String
    /// símbolo de Yahoo Finance (p. ej. IUSQ.DE, BTC-EUR)
    var ySymbol: String
    var name: String
    var isin: String = ""
    var accountId: String? = nil
    var manualPrice: Double = 0
    var color: String = "#6fd49b"
    var archived: Bool = false
    var ops: [AssetOp] = []
}

struct Goal: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var icon: String = "🎯"
    var color: String = "#f0c46a"
    var target: Double
    var saved: Double = 0
    /// yyyy-MM-dd o vacío
    var deadline: String = ""
    /// si está puesto, lo ahorrado es el valor de esa cuenta (si no, las aportaciones a mano)
    var accountId: String? = nil
}

struct Settings: Codable, Hashable {
    var name: String = "David"
    var accent: String = "#e4b3cb"
    var hideAmountsOnLaunch: Bool = false
    var faceID: Bool = false
    var monthStart: Int = 1
}

struct Quote: Codable, Hashable {
    var price: Double
    var previousClose: Double
    var currency: String
    var updated: Date
}

struct Snapshot: Codable, Hashable {
    var d: String
    var v: Double
}

// MARK: - Cuentas Claras (deudas con amigos)

struct Person: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var emoji: String = "😎"
    var color: String = "#b9a4ff"
    var nick: String = ""
    var phone: String = ""
    var photo: Data? = nil
}

enum DebtKind: String, Codable, CaseIterable, Identifiable {
    case owe, debt, split, theypaid, pay, ipay
    var id: String { rawValue }
    var label: String {
        switch self {
        case .owe: "Te debe"
        case .debt: "Le debes"
        case .split: "Gasto a medias"
        case .theypaid: "Pagó por ti"
        case .pay: "Te ha pagado"
        case .ipay: "Le has pagado"
        }
    }
}

/// amount > 0: esa persona te debe; amount < 0: tú le debes
struct DebtMove: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var personId: String
    var amount: Double
    var kind: DebtKind
    var concept: String = ""
    var date: String
    var created: Date = Date()
    var group: String? = nil
    var total: Double? = nil
}

struct AppState: Codable {
    var version: Int = 3
    var seed: Int = 0
    var accounts: [Account] = []
    var categories: [Category] = []
    var txs: [Tx] = []
    var recurring: [Recurring] = []
    var assets: [Asset] = []
    var goals: [Goal] = []
    var settings = Settings()
    var quotes: [String: Quote] = [:]
    var snapshots: [Snapshot] = []
    var people: [Person] = []
    var debts: [DebtMove] = []
    var companies: [Company] = []
    var shifts: [Shift] = []

    init() {}

    // lee también los datos guardados por versiones anteriores (a las que les faltan campos nuevos)
    enum CodingKeys: String, CodingKey { case version, seed, accounts, categories, txs, recurring, assets, goals, settings, quotes, snapshots, people, debts, companies, shifts }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 3
        seed = try c.decodeIfPresent(Int.self, forKey: .seed) ?? 0
        accounts = try c.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        categories = try c.decodeIfPresent([Category].self, forKey: .categories) ?? []
        txs = try c.decodeIfPresent([Tx].self, forKey: .txs) ?? []
        recurring = try c.decodeIfPresent([Recurring].self, forKey: .recurring) ?? []
        assets = try c.decodeIfPresent([Asset].self, forKey: .assets) ?? []
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        quotes = try c.decodeIfPresent([String: Quote].self, forKey: .quotes) ?? [:]
        snapshots = try c.decodeIfPresent([Snapshot].self, forKey: .snapshots) ?? []
        people = try c.decodeIfPresent([Person].self, forKey: .people) ?? []
        debts = try c.decodeIfPresent([DebtMove].self, forKey: .debts) ?? []
        companies = try c.decodeIfPresent([Company].self, forKey: .companies) ?? []
        shifts = try c.decodeIfPresent([Shift].self, forKey: .shifts) ?? []
    }
}
