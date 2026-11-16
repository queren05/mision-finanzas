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
    /// retirada: ya no sale para apuntar turnos nuevos, pero su historial se conserva
    var archived: Bool? = nil
}

/// Contrato indefinido: sueldo fijo al mes. El cobro va como ingreso periódico, así sale solo cada mes y cuenta en las previsiones.
struct Job: Codable, Hashable {
    var company: String
    /// yyyy-MM-dd
    var start: String
    var net: Double
    var payDay: Int = 28
    var accountId: String
    var recurringId: String = "r_nomina"
    /// lo que dice la oferta: bruto al año. Sin él solo se conoce el neto
    var grossYear: Double? = nil
    var pays: Int? = nil
    var ssPct: Double? = nil
    var irpfPct: Double? = nil
    /// el neto se ha escrito a mano (ya no se recalcula desde el bruto)
    var netManual: Bool? = nil

    var grossMonth: Double? { grossYear.map { (($0 / Double(pays ?? 12)) * 100).rounded() / 100 } }
    static func netMonth(grossYear: Double, pays: Int, ss: Double, irpf: Double) -> Double {
        ((grossYear / Double(max(1, pays)) * (1 - (ss + irpf) / 100)) * 100).rounded() / 100
    }
    /// retención de IRPF aproximada para un sueldo bruto anual (persona soltera sin hijos); sirve de punto de partida
    static func irpfEstimate(_ gross: Double) -> Double {
        guard gross > 15876 else { return 0 }
        let rn = gross * (1 - 0.065)
        var red = 0.0
        if rn <= 14852 { red = 7302 }
        else if rn <= 17673.52 { red = 7302 - 1.75 * (rn - 14852) }
        else if rn <= 19747.5 { red = 2364.34 - 1.14 * (rn - 17673.52) }
        let base = max(0, rn - 2000 - red)
        func scale(_ b: Double) -> Double {
            let steps: [(Double, Double)] = [(12450, 0.19), (20200, 0.24), (35200, 0.30), (60000, 0.37), (300000, 0.45), (.infinity, 0.47)]
            var t = 0.0, prev = 0.0
            for (top, pct) in steps { if b > prev { t += (min(b, top) - prev) * pct }; prev = top }
            return t
        }
        let quota = min(max(0, scale(base) - scale(5550)), 0.43 * (gross - 15876))
        return (quota / gross * 10000).rounded() / 100
    }

    /// primer día de cobro que no sea anterior a la fecha dada
    static func firstPay(from: String, day: Int) -> String {
        var m = Day.monthStart(from)
        for _ in 0..<3 {
            let days = Day.cal.range(of: .day, in: .month, for: Day.date(m))?.count ?? 28
            let d = String(m.prefix(8)) + String(format: "%02d", min(max(1, day), days))
            if d >= from { return d }
            m = Day.add(m, months: 1)
        }
        return from
    }
    /// «3 meses», «1 año y 2 meses»
    var seniority: String {
        let c = Day.cal.dateComponents([.year, .month], from: Day.date(start), to: Date())
        let y = max(0, c.year ?? 0), mo = max(0, c.month ?? 0)
        if start > Day.today { return "Empiezas el \(Day.header(start))" }
        if y == 0 && mo == 0 { return "Desde el \(Day.header(start))" }
        let ys = y == 0 ? "" : (y == 1 ? "1 año" : "\(y) años")
        let ms = mo == 0 ? "" : (mo == 1 ? "1 mes" : "\(mo) meses")
        return [ys, ms].filter { !$0.isEmpty }.joined(separator: " y ")
    }
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
    /// precio por hora de este turno (si no, el de la empresa)
    var normalRate: Double? = nil
    var nightRate: Double? = nil
}

struct ShiftCalc {
    var normalMin: Int
    var nightMin: Int
    var totalMin: Int { normalMin + nightMin }
    var gross: Double
}

/// lo que lleva ganado el contrato en un mes: cada día suma su parte del sueldo
struct JobMonth {
    var days = 0          // días ya ganados
    var monthDays = 30
    var net = 0.0         // neto ganado hasta hoy
    var gross: Double? = nil
    var dayNet = 0.0
    var dayGross: Double? = nil
    var fullNet = 0.0     // lo que toca cobrar por el mes entero
    var fullGross: Double? = nil
    var paid: Double? = nil
}

struct WorkSummary {
    /// hay sueldo de contrato sin bruto conocido: el bruto total no se puede dar
    var grossUnknown = false
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
        let gross = (Double(normal) / 60 * (s.normalRate ?? c.normalRate) + Double(night) / 60 * (s.nightRate ?? c.nightRate))
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

    func jobMonth(_ month: String) -> JobMonth? {
        guard let j = state.job else { return nil }
        let first = month + "-01"
        let n = Day.cal.range(of: .day, in: .month, for: Day.date(first))?.count ?? 30
        let last = month + String(format: "-%02d", n)
        guard j.start <= last else { return nil }
        func span(_ a: String, _ b: String) -> Int { a > b ? 0 : (Day.cal.dateComponents([.day], from: Day.date(a), to: Day.date(b)).day ?? 0) + 1 }
        func r2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
        let from = max(first, j.start)
        var m = JobMonth()
        m.monthDays = n
        m.days = span(from, min(last, Day.today))
        let due = span(from, last)
        m.dayNet = r2(j.net / Double(n))
        m.net = r2(j.net * Double(m.days) / Double(n))
        m.fullNet = r2(j.net * Double(due) / Double(n))
        if let g = j.grossMonth {
            m.dayGross = r2(g / Double(n)); m.gross = r2(g * Double(m.days) / Double(n)); m.fullGross = r2(g * Double(due) / Double(n))
        }
        m.paid = jobTx(month)?.amount
        return m
    }
    /// la nómina del contrato apuntada en ese mes (a mano o sola el día de cobro)
    func jobTx(_ month: String) -> Tx? {
        guard let j = state.job else { return nil }
        return state.txs.first { $0.recurringId == j.recurringId && $0.type == .income && Day.monthKey($0.date) == month }
    }
    /// turnos del mes más lo ganado con el contrato
    func workSummary(month: String, company: String? = nil) -> WorkSummary {
        var w = summary(shifts(month: month, company: company))
        guard company == nil, let m = jobMonth(month) else { return w }
        if let p = m.paid {
            w.net += p; w.paidNet += p
            if let g = m.fullGross { w.gross += g } else { w.grossUnknown = true }
        } else {
            w.net += m.net; w.pendingNet += m.net
            if let g = m.gross { w.gross += g } else if m.net > 0 { w.grossUnknown = true }
        }
        return w
    }
    /// apunta la nómina del mes con lo cobrado de verdad (o corrige la que ya estaba apuntada)
    func payJob(month: String, amount: Double, accountId: String) {
        guard let j = state.job, amount > 0 else { return }
        if let t = jobTx(month), let i = state.txs.firstIndex(where: { $0.id == t.id }) {
            withAnimation(Motion.layout) { state.txs[i].amount = amount; state.txs[i].accountId = accountId }
            return
        }
        let first = month + "-01"
        let n = Day.cal.range(of: .day, in: .month, for: Day.date(first))?.count ?? 30
        let last = month + String(format: "-%02d", n)
        let ri = state.recurring.firstIndex { $0.id == j.recurringId }
        save(Tx(type: .income, amount: amount, accountId: accountId,
                categoryId: ri.flatMap { state.recurring[$0].categoryId } ?? state.categories.first { $0.id == "i_nomina" }?.id,
                date: min(Day.today, last), time: Day.time(Date()), title: "Nómina · \(j.company)", recurringId: j.recurringId))
        // el cobro automático de ese mes ya no hace falta
        if let ri, state.recurring[ri].next <= last { state.recurring[ri].next = Job.firstPay(from: Day.add(first, months: 1), day: j.payDay) }
    }

    /// empresas en las que se pueden apuntar turnos (las retiradas solo guardan su historial)
    var activeCompanies: [Company] { state.companies.filter { $0.archived != true } }

    func saveJob(_ j: Job) {
        let old = state.recurring.first { $0.id == j.recurringId }
        var r = old ?? Recurring(id: j.recurringId, name: "", type: "income", amount: j.net, accountId: j.accountId, next: Day.today)
        r.name = "Nómina · \(j.company)"; r.type = "income"; r.amount = j.net; r.accountId = j.accountId
        r.freq = .monthly; r.day = j.payDay; r.active = true
        if r.categoryId == nil {
            r.categoryId = state.categories.first { c in
                let n = c.name.lowercased()
                return c.kind == .income && (n.contains("nómina") || n.contains("nomina") || n.contains("sueldo") || n.contains("salario"))
            }?.id
        }
        // si ya estaba programado y no cambia el día, se respeta el próximo cobro (para no cobrar dos veces el mismo mes)
        if old == nil { r.next = Job.firstPay(from: max(j.start, Day.today), day: j.payDay) }
        else if old?.day != j.payDay || (state.job?.start ?? "") != j.start { r.next = Job.firstPay(from: max(j.start, Day.add(Day.today, days: 1)), day: j.payDay) }
        // si la nómina de ese mes ya está apuntada, el siguiente cobro es el del mes que viene
        if state.txs.contains(where: { $0.recurringId == r.id && Day.monthKey($0.date) == Day.monthKey(r.next) }) {
            r.next = Job.firstPay(from: Day.add(Day.monthStart(r.next), months: 1), day: j.payDay)
        }
        withAnimation(Motion.layout) {
            if let i = state.recurring.firstIndex(where: { $0.id == r.id }) { state.recurring[i] = r } else { state.recurring.append(r) }
            state.job = j
        }
    }
    /// quita el contrato y su cobro mensual (los ingresos ya apuntados se quedan)
    func removeJob() {
        guard let j = state.job else { return }
        withAnimation(Motion.layout) { state.recurring.removeAll { $0.id == j.recurringId }; state.job = nil }
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
