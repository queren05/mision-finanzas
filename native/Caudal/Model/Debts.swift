import SwiftUI

/// Cuentas Claras: quién te debe y a quién debes
extension Store {
    func person(_ id: String?) -> Person? { state.people.first { $0.id == id } }

    func debtBalance(_ pid: String) -> Double {
        let v = state.debts.filter { $0.personId == pid }.reduce(0) { $0 + $1.amount }
        return (v * 100).rounded() / 100
    }
    var owedToMe: Double { state.people.map { debtBalance($0.id) }.filter { $0 > 0 }.reduce(0, +) }
    var iOwe: Double { -state.people.map { debtBalance($0.id) }.filter { $0 < 0 }.reduce(0, +) }

    func lastDebt(_ pid: String) -> DebtMove? {
        state.debts.filter { $0.personId == pid }.max { ($0.date, $0.created) < ($1.date, $1.created) }
    }
    /// personas con cuentas pendientes primero (por importe) y luego el resto por nombre
    var peopleSorted: [Person] {
        state.people.sorted {
            let a = abs(debtBalance($0.id)), b = abs(debtBalance($1.id))
            if (a > 0) != (b > 0) { return a > 0 }
            if a != b { return a > b }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    func save(_ p: Person) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if let i = state.people.firstIndex(where: { $0.id == p.id }) { state.people[i] = p } else { state.people.append(p) }
        }
    }
    func deletePerson(_ p: Person) {
        withAnimation { state.debts.removeAll { $0.personId == p.id }; state.people.removeAll { $0.id == p.id } }
    }
    func add(_ moves: [DebtMove]) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { state.debts += moves }
    }
    func deleteDebt(_ m: DebtMove) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { state.debts.removeAll { $0.id == m.id } }
    }
    /// deja la cuenta de esa persona a cero (o apunta un pago parcial)
    func settle(_ pid: String, amount: Double? = nil) {
        let b = debtBalance(pid)
        guard b != 0 else { return }
        let paid = min(abs(b), amount ?? abs(b))
        add([DebtMove(personId: pid, amount: b > 0 ? -paid : paid, kind: b > 0 ? .pay : .ipay, date: Day.today)])
    }

    /// mensaje para recordarle lo que te debe (WhatsApp o compartir)
    func reminder(for p: Person) -> String {
        let b = debtBalance(p.id)
        let items = state.debts.filter { $0.personId == p.id && $0.amount > 0 && $0.kind != .ipay }
            .sorted { $0.date < $1.date }.suffix(8)
            .map { "• \($0.concept.isEmpty ? $0.kind.label : $0.concept) (\(Day.shortLabel($0.date))): \(Money.eur($0.amount))" }
            .joined(separator: "\n")
        return "¡Hola \(p.name)! 👋 Te paso las cuentas: me debes \(Money.eur(b)).\n\(items)\n¿Me lo pasas por Bizum cuando puedas? 🙏"
    }
    func whatsappURL(for p: Person) -> URL? {
        let digits = p.phone.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let ph = p.phone.hasPrefix("+") ? digits : (digits.count == 9 ? "34" + digits : digits)
        let text = reminder(for: p).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "whatsapp://send?phone=\(ph)&text=\(text)")
    }

    /// la copia de la app Cuentas Claras (web): {"people":[…],"moves":[…]}
    func importCuentasClaras(_ text: String) throws -> String {
        guard let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let people = root["people"] as? [[String: Any]] else { throw WebImport.Failure.notBackup }
        var added = 0
        for p in people {
            guard let id = p["id"] as? String, !state.people.contains(where: { $0.id == id }) else { continue }
            var photo: Data? = nil
            if let s = p["photo"] as? String, let comma = s.firstIndex(of: ",") { photo = Data(base64Encoded: String(s[s.index(after: comma)...])) }
            state.people.append(Person(id: id, name: p["name"] as? String ?? "Amigo", emoji: p["emoji"] as? String ?? "😎", color: p["color"] as? String ?? "#b9a4ff",
                                       nick: p["nick"] as? String ?? "", phone: p["phone"] as? String ?? "", photo: photo))
            added += 1
        }
        var moves = 0
        for m in (root["moves"] as? [[String: Any]]) ?? [] {
            guard let id = m["id"] as? String, !state.debts.contains(where: { $0.id == id }), let pid = m["pid"] as? String else { continue }
            let amt = (m["amt"] as? Double) ?? Double(m["amt"] as? Int ?? 0)
            let t = (m["t"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
            state.debts.append(DebtMove(id: id, personId: pid, amount: amt, kind: DebtKind(rawValue: m["kind"] as? String ?? "owe") ?? .owe,
                                        concept: m["concept"] as? String ?? "", date: m["date"] as? String ?? Day.today, created: t,
                                        group: m["group"] as? String, total: m["total"] as? Double))
            moves += 1
        }
        return "Importadas \(added) personas y \(moves) movimientos"
    }
}
