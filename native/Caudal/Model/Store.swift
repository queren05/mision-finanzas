import SwiftUI
import Observation

struct NWPoint: Identifiable { var date: Date; var value: Double; var id: Date { date } }
struct CatTotal: Identifiable { var cat: Category; var total: Double; var id: String { cat.id } }
struct Upcoming: Identifiable { var r: Recurring; var date: String; var id: String { r.id + date } }

/// Todo el estado de la app, guardado en un JSON en Documentos.
@Observable
final class Store {
    var state: AppState {
        didSet { scheduleSave() }
    }
    var hideAmounts = false
    /// último movimiento borrado (para deshacer)
    var lastDeleted: Tx? = nil
    var refreshing = false

    @ObservationIgnored private var saveTask: Task<Void, Never>? = nil
    @ObservationIgnored private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("caudal.json")
    }()

    init() {
        if let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(AppState.self, from: data) {
            state = s
        } else {
            state = Seed.david()
        }
        if state.seed < Seed.version && state.seed >= 3 { Seed.migrate(&state) }
        hideAmounts = state.settings.hideAmountsOnLaunch
        runRecurring()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !Task.isCancelled else { return }
            self.saveNow()
        }
    }
    func saveNow() {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(state) { try? data.write(to: url, options: .atomic) }
    }
    func exportData() -> Data {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(state)) ?? Data()
    }

    // MARK: búsquedas

    var accounts: [Account] { state.accounts.filter { !$0.archived }.sorted { $0.order < $1.order } }
    func account(_ id: String?) -> Account? { state.accounts.first { $0.id == id } }
    func category(_ id: String?) -> Category? { state.categories.first { $0.id == id } }
    func asset(_ id: String?) -> Asset? { state.assets.first { $0.id == id } }
    func categories(_ kind: CatKind) -> [Category] { state.categories.filter { $0.kind == kind && !$0.hidden } }

    // MARK: saldos

    /// efecto de un movimiento en una cuenta
    func effect(_ t: Tx, on accId: String) -> Double {
        switch t.type {
        case .expense: return t.accountId == accId ? -t.amount : 0
        case .income: return t.accountId == accId ? t.amount : 0
        case .adjust: return t.accountId == accId ? t.amount : 0
        case .transfer:
            var v = 0.0
            if t.accountId == accId { v -= t.amount }
            if t.toAccountId == accId { v += t.amount }
            return v
        }
    }

    func balance(_ a: Account, upTo date: String? = nil) -> Double {
        var b = a.initial
        for t in state.txs where t.accountId == a.id || t.toAccountId == a.id {
            if let d = date, t.date > d { continue }
            b += effect(t, on: a.id)
        }
        for asset in state.assets {
            for op in asset.ops where op.cashAccountId == a.id {
                if let d = date, op.date > d { continue }
                switch op.side {
                case .buy: b -= op.qty * op.price + op.fee
                case .sell: b += op.qty * op.price - op.fee
                case .reward: break
                }
            }
        }
        return b
    }

    /// valor de la cuenta con sus inversiones
    func value(_ a: Account) -> Double {
        balance(a) + state.assets.filter { $0.accountId == a.id && !$0.archived }.reduce(0) { $0 + assetValue($1) }
    }

    var netWorth: Double {
        accounts.filter { $0.includeInTotal }.reduce(0) { $0 + value($1) }
    }
    var cashTotal: Double { accounts.filter { $0.includeInTotal }.reduce(0) { $0 + balance($1) } }

    /// patrimonio de los últimos días (cuentas con su historia + inversiones al valor de hoy)
    func netWorthSeries(days: Int = 30) -> [NWPoint] {
        let invest = state.assets.filter { !$0.archived }.reduce(0) { $0 + assetValue($1) }
        var out: [NWPoint] = []
        for k in stride(from: days, through: 0, by: -1) {
            let d = Day.add(Day.today, days: -k)
            let cash = accounts.filter { $0.includeInTotal }.reduce(0) { $0 + balance($1, upTo: d) }
            out.append(NWPoint(date: Day.date(d), value: cash + invest))
        }
        return out
    }

    // MARK: inversiones

    func price(_ a: Asset) -> Double { state.quotes[a.ySymbol]?.price ?? a.manualPrice }
    func dayChange(_ a: Asset) -> Double? {
        guard let q = state.quotes[a.ySymbol], q.previousClose > 0 else { return nil }
        return (q.price / q.previousClose - 1) * 100
    }
    func position(_ a: Asset) -> (qty: Double, cost: Double, realized: Double) {
        var qty = 0.0, cost = 0.0, realized = 0.0
        for op in a.ops.sorted(by: { $0.date < $1.date }) {
            switch op.side {
            case .buy: qty += op.qty; cost += op.qty * op.price + op.fee
            case .reward: qty += op.qty
            case .sell:
                let avg = qty > 0 ? cost / qty : 0
                let q = min(op.qty, qty)
                realized += q * (op.price - avg) - op.fee
                cost -= q * avg; qty -= q
            }
        }
        return (qty, cost, realized)
    }
    func assetValue(_ a: Asset) -> Double { position(a).qty * price(a) }
    var investValue: Double { state.assets.filter { !$0.archived }.reduce(0) { $0 + assetValue($1) } }
    var investCost: Double { state.assets.filter { !$0.archived }.reduce(0) { $0 + position($1).cost } }

    // MARK: periodos (mes financiero)

    /// inicio del mes que contiene la fecha (respetando el día de inicio)
    func periodStart(for d: String) -> String {
        let ms = max(1, min(28, state.settings.monthStart))
        let day = Int(d.suffix(2)) ?? 1
        var base = Day.monthStart(d)
        if day < ms { base = Day.add(base, months: -1) }
        return String(base.prefix(8)) + String(format: "%02d", ms)
    }
    func periodRange(_ start: String) -> ClosedRange<String> {
        start...Day.add(Day.add(start, months: 1), days: -1)
    }
    func txs(in r: ClosedRange<String>) -> [Tx] { state.txs.filter { r.contains($0.date) } }

    func spent(in r: ClosedRange<String>) -> Double {
        txs(in: r).filter { $0.type == .expense && !$0.excluded }.reduce(0) { $0 + $1.amount }
    }
    func earned(in r: ClosedRange<String>) -> Double {
        txs(in: r).filter { $0.type == .income && !$0.excluded }.reduce(0) { $0 + $1.amount }
    }
    func byCategory(in r: ClosedRange<String>, kind: TxType = .expense) -> [CatTotal] {
        var m: [String: Double] = [:]
        for t in txs(in: r) where t.type == kind && !t.excluded { m[t.categoryId ?? "", default: 0] += t.amount }
        return m.compactMap { (k, v) in
            let c = category(k) ?? Category(id: "none", kind: kind == .income ? .income : .expense, name: "Sin categoría", icon: "❔")
            return CatTotal(cat: c, total: v)
        }.sorted { $0.total > $1.total }
    }

    // MARK: cambios

    func save(_ t: Tx) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            if let i = state.txs.firstIndex(where: { $0.id == t.id }) { state.txs[i] = t } else { state.txs.append(t) }
        }
    }
    func delete(_ t: Tx) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state.txs.removeAll { $0.id == t.id }
            lastDeleted = t
        }
    }
    func undoDelete() {
        guard let t = lastDeleted else { return }
        withAnimation(.spring) { state.txs.append(t); lastDeleted = nil }
    }
    func duplicate(_ t: Tx) {
        var c = t; c.id = UUID().uuidString; c.date = Day.today; c.time = Day.time(Date())
        save(c)
    }
    func save(_ a: Account) {
        if let i = state.accounts.firstIndex(where: { $0.id == a.id }) { state.accounts[i] = a } else {
            var n = a; n.order = (state.accounts.map(\.order).max() ?? -1) + 1; state.accounts.append(n)
        }
    }
    func deleteAccount(_ a: Account) {
        state.txs.removeAll { $0.accountId == a.id || $0.toAccountId == a.id }
        state.accounts.removeAll { $0.id == a.id }
    }
    /// apunta un ajuste para que el saldo de la cuenta sea el indicado
    func adjust(_ a: Account, to target: Double) {
        let diff = target - balance(a)
        guard abs(diff) >= 0.005 else { return }
        save(Tx(type: .adjust, amount: (diff * 100).rounded() / 100, accountId: a.id, date: Day.today, time: Day.time(Date()), title: "Ajuste de saldo"))
    }
    func save(_ c: Category) {
        if let i = state.categories.firstIndex(where: { $0.id == c.id }) { state.categories[i] = c } else { state.categories.append(c) }
    }
    func deleteCategory(_ c: Category) {
        for i in state.txs.indices where state.txs[i].categoryId == c.id { state.txs[i].categoryId = nil }
        state.categories.removeAll { $0.id == c.id }
    }
    func save(_ r: Recurring) {
        if let i = state.recurring.firstIndex(where: { $0.id == r.id }) { state.recurring[i] = r } else { state.recurring.append(r) }
        runRecurring()
    }
    /// lo ahorrado para un objetivo
    func saved(_ g: Goal) -> Double {
        if let id = g.accountId, let a = account(id) { return value(a) }
        return g.saved
    }
    func save(_ g: Goal) {
        if let i = state.goals.firstIndex(where: { $0.id == g.id }) { state.goals[i] = g } else { state.goals.append(g) }
    }
    func save(_ a: Asset) {
        if let i = state.assets.firstIndex(where: { $0.id == a.id }) { state.assets[i] = a } else { state.assets.append(a) }
    }

    /// la categoría que encaja con el concepto (por sus palabras clave)
    func guessCategory(_ text: String, kind: CatKind) -> Category? {
        let t = text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        guard t.count >= 3 else { return nil }
        for c in categories(kind) {
            for k in c.keywords.split(separator: ",") {
                let kw = k.trimmingCharacters(in: .whitespaces).lowercased().folding(options: .diacriticInsensitive, locale: nil)
                if kw.count >= 2 && t.contains(kw) { return c }
            }
        }
        return nil
    }
    /// conceptos usados antes (para autocompletar), del más reciente al más antiguo
    var knownTitles: [String] {
        var seen = Set<String>(); var out: [String] = []
        for t in state.txs.sorted(by: { $0.sortKey > $1.sortKey }) where !t.title.isEmpty && seen.insert(t.title).inserted { out.append(t.title) }
        return out
    }

    // MARK: recurrentes

    func nextDate(_ r: Recurring, after d: String) -> String {
        switch r.freq {
        case .weekly: return Day.add(d, days: 7)
        case .yearly: return Day.add(d, months: 12)
        case .monthly:
            let n = Day.add(Day.monthStart(d), months: 1)
            let days = Day.cal.range(of: .day, in: .month, for: Day.date(n))?.count ?? 28
            return String(n.prefix(8)) + String(format: "%02d", min(r.day, days))
        }
    }

    /// apunta los cargos pendientes hasta hoy
    func runRecurring() {
        let today = Day.today
        for i in state.recurring.indices {
            var r = state.recurring[i]
            guard r.active else { continue }
            var guardN = 0
            while r.next <= today && guardN < 60 {
                guardN += 1
                if r.type == "invest", let aid = r.assetId, let ai = state.assets.firstIndex(where: { $0.id == aid }) {
                    let p = price(state.assets[ai])
                    if p > 0 { state.assets[ai].ops.append(AssetOp(side: .buy, qty: r.amount / p, price: p, date: r.next, cashAccountId: r.accountId)) }
                } else {
                    let type = TxType(rawValue: r.type) ?? .expense
                    state.txs.append(Tx(type: type, amount: r.amount, accountId: r.accountId, toAccountId: r.toAccountId, categoryId: r.categoryId, date: r.next, time: "08:00", title: r.name, recurringId: r.id))
                }
                r.next = nextDate(r, after: r.next)
            }
            state.recurring[i] = r
        }
    }

    /// cargos de los próximos días
    func upcoming(days: Int = 14) -> [Upcoming] {
        let end = Day.add(Day.today, days: days)
        var out: [Upcoming] = []
        for r in state.recurring where r.active {
            var d = r.next; var n = 0
            while d <= end && n < 10 { out.append(Upcoming(r: r, date: d)); d = nextDate(r, after: d); n += 1 }
        }
        return out.sorted { $0.date < $1.date }
    }

    // MARK: datos

    func resetToSeed() { withAnimation { state = Seed.david() } }
    func eraseAll() {
        withAnimation {
            var s = AppState(); s.categories = Seed.categories(); s.seed = Seed.version; state = s
        }
    }

    /// copia de seguridad: la de esta app o la de la versión web (Misión Finanzas / Caudal 2)
    func importBackup(_ data: Data) throws -> String {
        if let s = try? JSONDecoder().decode(AppState.self, from: data) {
            withAnimation { state = s }
            return "Copia restaurada: \(s.txs.count) movimientos"
        }
        let s = try WebImport.convert(data)
        withAnimation { state = s }
        runRecurring()
        return "Importado de la versión web: \(s.accounts.count) cuentas y \(s.txs.count) movimientos"
    }
}
