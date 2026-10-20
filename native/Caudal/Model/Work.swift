import SwiftUI

// MARK: - Horas trabajadas (ETT y otras empresas)

struct Company: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var color: String = "#7ac8ff"
    var normalRate: Double = 13.59
    var nightRate: Double = 16.07
    /// tramo nocturno (minutos desde las 00:00): por defecto de 22:00 a 06:00
    var nightStart: Int = 22 * 60
    var nightEnd: Int = 6 * 60
    /// retenciones estimadas para pasar de bruto a neto
    var ssPct: Double = 6.5
    var irpfPct: Double = 2
    var accountId: String? = nil
}

enum PayStatus: String, Codable, CaseIterable, Identifiable {
    case pendiente, pagado
    var id: String { rawValue }
    var label: String { self == .pagado ? "Pagado" : "Pendiente" }
}

struct Shift: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var companyId: String
    /// yyyy-MM-dd (día en que empieza el turno)
    var date: String
    /// minutos desde las 00:00
    var start: Int
    var end: Int
    var breakMin: Int = 0
    var note: String = ""
    var status: PayStatus = .pendiente
    var paidDate: String = ""
}

struct ShiftCalc {
    var normalMin: Int
    var nightMin: Int
    var totalMin: Int { normalMin + nightMin }
    var gross: Double
}

struct WorkSummary {
    var normalMin = 0
    var nightMin = 0
    var gross = 0.0
    var net = 0.0
    var paidNet = 0.0
    var pendingNet = 0.0
    var days = 0
    var totalMin: Int { normalMin + nightMin }
}

enum Hours {
    /// «16:00»
    static func hm(_ m: Int) -> String { String(format: "%02d:%02d", (m / 60) % 24, m % 60) }
    /// «7 h 30 min» / «7 h»
    static func dur(_ m: Int) -> String {
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) h" : (h == 0 ? "\(r) min" : "\(h) h \(r) min")
    }
    /// 7,5
    static func dec(_ m: Int) -> String { Money.num(Double(m) / 60).replacingOccurrences(of: ",00", with: "") }

    /// reparte el turno en minutos normales y nocturnos (el turno puede pasar de medianoche)
    static func calc(_ s: Shift, _ c: Company) -> ShiftCalc {
        let a = s.start
        var b = s.end
        if b <= a { b += 1440 }
        // tramos nocturnos en minutos absolutos (día anterior, el del turno y el siguiente)
        var night = 0
        for k in -1...1 {
            let ns = c.nightStart + 1440 * k
            let ne = c.nightEnd > c.nightStart ? c.nightEnd + 1440 * k : c.nightEnd + 1440 * (k + 1)
            night += max(0, min(b, ne) - max(a, ns))
        }
        var normal = (b - a) - night
        // el descanso se quita primero de las horas normales
        var br = max(0, s.breakMin)
        let fromNormal = min(br, normal); normal -= fromNormal; br -= fromNormal
        night = max(0, night - br)
        let gross = (Double(normal) / 60 * c.normalRate + Double(night) / 60 * c.nightRate)
        return ShiftCalc(normalMin: normal, nightMin: night, gross: (gross * 100).rounded() / 100)
    }

    static func net(_ gross: Double, _ c: Company) -> Double {
        ((gross * (1 - (c.ssPct + c.irpfPct) / 100)) * 100).rounded() / 100
    }
}

extension Store {
    func company(_ id: String?) -> Company? { state.companies.first { $0.id == id } }

    func calc(_ s: Shift) -> ShiftCalc {
        guard let c = company(s.companyId) else { return ShiftCalc(normalMin: 0, nightMin: 0, gross: 0) }
        return Hours.calc(s, c)
    }

    func shifts(month: String, company: String? = nil) -> [Shift] {
        state.shifts.filter { Day.monthKey($0.date) == month && (company == nil || $0.companyId == company) }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.start > $1.start }
    }

    func summary(_ list: [Shift]) -> WorkSummary {
        var w = WorkSummary()
        w.days = Set(list.map(\.date)).count
        for s in list {
            guard let c = company(s.companyId) else { continue }
            let r = Hours.calc(s, c)
            let n = Hours.net(r.gross, c)
            w.normalMin += r.normalMin; w.nightMin += r.nightMin
            w.gross += r.gross; w.net += n
            if s.status == .pagado { w.paidNet += n } else { w.pendingNet += n }
        }
        return w
    }

    func save(_ c: Company) {
        withAnimation(.spring) {
            if let i = state.companies.firstIndex(where: { $0.id == c.id }) { state.companies[i] = c } else { state.companies.append(c) }
        }
    }
    func deleteCompany(_ c: Company) {
        withAnimation { state.shifts.removeAll { $0.companyId == c.id }; state.companies.removeAll { $0.id == c.id } }
    }
    func save(_ s: Shift) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            if let i = state.shifts.firstIndex(where: { $0.id == s.id }) { state.shifts[i] = s } else { state.shifts.append(s) }
        }
    }
    func deleteShift(_ s: Shift) {
        withAnimation(.spring) { state.shifts.removeAll { $0.id == s.id } }
    }
    func setPaid(_ ids: [String], _ paid: Bool) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            for i in state.shifts.indices where ids.contains(state.shifts[i].id) {
                state.shifts[i].status = paid ? .pagado : .pendiente
                state.shifts[i].paidDate = paid ? Day.today : ""
            }
        }
    }
    /// marca como pagado lo pendiente de una empresa en un mes y, si se quiere, lo apunta como ingreso
    func payMonth(company c: Company, month: String, amount: Double, accountId: String?) {
        let pend = shifts(month: month, company: c.id).filter { $0.status == .pendiente }
        setPaid(pend.map(\.id), true)
        if let acc = accountId, amount > 0 {
            save(Tx(type: .income, amount: amount, accountId: acc, categoryId: state.categories.first { $0.id == "i_nomina" }?.id,
                    date: Day.today, time: Day.time(Date()), title: "Nómina \(c.name)", note: "Horas de \(Day.monthYearLabel(month + "-01").lowercased())"))
        }
    }
}
