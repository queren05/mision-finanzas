import Foundation

/// gastos que deja Claude en el servidor de casa (`/caudal/entrada`): al abrir la app se apuntan solos
struct EntradaTx: Codable {
    var id: String
    var type: TxType?
    var amount: Double
    var accountId: String?
    var toAccountId: String?
    var categoryId: String?
    var date: String
    var time: String?
    var title: String?
    var note: String?
}

extension Store {
    private static let hechas = "entrada-hechas"

    /// trae la entrada del servidor y apunta lo que no esté ya (cada id solo una vez, aunque luego lo borres)
    @MainActor
    func mergeServerInbox() async {
        guard let d = try? await Store.server.entrada(), let lista = try? JSONDecoder().decode([EntradaTx].self, from: d), !lista.isEmpty else { return }
        var hechas = Set(UserDefaults.standard.stringArray(forKey: Store.hechas) ?? [])
        var n = 0
        for e in lista where !hechas.contains(e.id) {
            hechas.insert(e.id)
            let tipo = e.type ?? .expense
            let cuenta = e.accountId.flatMap { id in state.accounts.first { $0.id == id }?.id } ?? accounts.first { $0.type == .corriente }?.id ?? accounts.first?.id
            guard let cuenta else { continue }
            let ya = state.txs.contains { $0.id == e.id || ($0.date == e.date && $0.accountId == cuenta && $0.type == tipo && abs($0.amount - e.amount) < 0.005) }
            if ya { continue }
            let titulo = e.title ?? ""
            let cat = e.categoryId.flatMap { id in state.categories.first { $0.id == id }?.id }
                ?? (tipo == .transfer ? nil : guessCategory(titulo, kind: tipo == .income ? .income : .expense)?.id)
            save(Tx(id: e.id, type: tipo, amount: (e.amount * 100).rounded() / 100, accountId: cuenta, toAccountId: e.toAccountId, categoryId: cat,
                    date: e.date, time: e.time ?? "12:00", title: titulo, note: e.note ?? ""))
            n += 1
        }
        UserDefaults.standard.set(Array(hechas), forKey: Store.hechas)
        if n > 0 {
            saveNow()
            Haptic.success()
            _ = await backup(force: true)
        }
    }
}

extension ServerCopy {
    func entrada() async throws -> Data? {
        guard let u = URL(string: "http://100.99.241.98:8790/\(app)/entrada") else { return nil }
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        let (d, r) = try await URLSession(configuration: c).data(from: u)
        return (r as? HTTPURLResponse)?.statusCode == 200 ? d : nil
    }
}
