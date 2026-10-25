import SwiftUI
import Observation
import UserNotifications

@Observable
final class Store {
    var s: CState { didSet { scheduleSave() } }
    var lastDeleted: LogEntry? = nil
    /// copia del servidor esperando a que digas si la recuperas
    var pendingRestore: CState? = nil
    var lastBackup: Date? = ServerCopy.last
    let datos = Datos.shared

    @ObservationIgnored private var saveTask: Task<Void, Never>? = nil
    @ObservationIgnored private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("micorsa.json")

    init() {
        if let d = try? Data(contentsOf: url), let st = try? JSONDecoder().decode(CState.self, from: d) { s = st } else { s = CState() }
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
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: url, options: .atomic) }
        scheduleNotifications()
    }
    func exportData() -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? e.encode(s)) ?? Data()
    }

    func pieza(_ id: String) -> Pieza? { datos.PIEZAS.first { $0.id == id } }

    // MARK: fechas

    static func addYears(_ d: String, _ y: Double) -> String {
        let months = Int((y * 12).rounded())
        return Day.add(d, months: months)
    }
    static func daysTo(_ d: String) -> Int {
        Day.cal.dateComponents([.day], from: Day.cal.startOfDay(for: Date()), to: Day.date(d)).day ?? 0
    }

    // MARK: estado de una pieza (igual que la versión web)

    func status(_ p: Pieza) -> PartInfo {
        let d = s.parts[p.id] ?? PartState()
        guard let use = p.use, use.km != nil || use.y != nil else { return PartInfo(st: .watch, txt: "Sin intervalo: se cambia cuando falla") }
        let never = d.never == true
        if d.unknown == true || (!never && d.km == nil && (d.date ?? "").isEmpty) {
            return PartInfo(st: .unk, txt: "No se sabe cuándo se cambió: revísalo")
        }
        let baseKm: Int? = never ? 0 : d.km
        let baseDate: String? = never ? s.matric : ((d.date ?? "").isEmpty ? nil : d.date)
        var dueKm: Int? = nil, dueDate: String? = nil
        var fk = 0.0, fd = 0.0
        if let uk = use.km, let b = baseKm { dueKm = b + uk; fk = Double(s.km - b) / Double(uk) }
        if let uy = use.y, let bd = baseDate {
            dueDate = Store.addYears(bd, uy)
            fd = Date().timeIntervalSince(Day.date(bd)) / (uy * 365.25 * 86400)
        }
        if use.km != nil && baseKm == nil && !(use.y != nil && baseDate != nil) { return PartInfo(st: .unk, txt: "Falta el kilometraje del último cambio") }
        let pct = max(use.km != nil && baseKm != nil ? fk : 0, use.y != nil && baseDate != nil ? fd : 0)
        let leftKm = dueKm.map { $0 - s.km }
        let leftD = dueDate.map { Store.daysTo($0) }
        var parts: [String] = []
        if let l = leftKm { parts.append(l < 0 ? "pasado \(Money.km(-l))" : l == 0 ? "toca justo ahora" : "quedan \(Money.km(l))") }
        if let l = leftD, let dd = dueDate { parts.append(l <= 0 ? "caducó \(Day.shortLabel(dd))" : "hasta \(Day.monthYearLabel(dd).lowercased())") }
        let st: PartStatus = pct >= 1 ? .bad : (pct >= 0.85 || (leftKm.map { $0 < 2000 } ?? false) || (leftD.map { $0 < 45 } ?? false)) ? .soon : .ok
        return PartInfo(st: st, pct: min(1, max(0, pct)), dueKm: dueKm, dueDate: dueDate, txt: parts.joined(separator: " · "))
    }

    var sorted: [(p: Pieza, i: PartInfo)] {
        datos.PIEZAS.map { (p: $0, i: status($0)) }.sorted {
            $0.i.st.order != $1.i.st.order ? $0.i.st.order < $1.i.st.order : $0.i.pct > $1.i.pct
        }
    }

    func nextItv() -> String? {
        let m = s.matric
        guard !m.isEmpty else { return nil }
        let age: (Double) -> String = { Store.addYears(m, $0) }
        var d: String
        if !s.itv.isEmpty {
            let yearsAtItv = Day.date(s.itv).timeIntervalSince(Day.date(m)) / 31_557_600
            d = Store.addYears(s.itv, yearsAtItv >= 10 ? 1 : 2)
        } else { d = age(4) }
        var n = 0
        while Store.daysTo(d) < -400 && n < 50 { d = Store.addYears(d, 2); n += 1 }
        let t10 = age(10)
        if d > t10 && (s.itv.isEmpty || s.itv < t10) { d = min(t10, d) }
        return d
    }

    var kmPerMonth: Int? {
        guard let a = s.kmLog.first, let b = s.kmLog.last, s.kmLog.count >= 2 else { return nil }
        let days = Day.date(b.d).timeIntervalSince(Day.date(a.d)) / 86400
        return days > 20 ? Int(Double(b.km - a.km) / days * 30.4) : nil
    }

    var health: Double {
        let c = sorted.map(\.i.st).filter { $0 != .watch }
        return c.isEmpty ? 0 : Double(c.filter { $0 == .ok }.count) / Double(c.count)
    }

    // MARK: cambios

    func setKm(_ km: Int, date: String = Day.today) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            s.km = km
            s.kmLog.removeAll { $0.d == date }
            s.kmLog.append(KmPoint(d: date, km: km))
            s.kmLog.sort { $0.d < $1.d }
        }
    }

    func save(_ l: LogEntry) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            if let i = s.logs.firstIndex(where: { $0.id == l.id }) { s.logs[i] = l } else { s.logs.append(l) }
            if !l.part.isEmpty {
                let cur = s.parts[l.part]
                if cur?.km == nil || l.km >= (cur?.km ?? 0) || cur?.unknown == true || cur?.never == true { s.parts[l.part] = PartState(km: l.km, date: l.date) }
            }
        }
        if l.km > s.km { setKm(l.km, date: l.date) }
    }
    func delete(_ l: LogEntry) {
        withAnimation(.spring) { s.logs.removeAll { $0.id == l.id }; lastDeleted = l }
    }
    func undoDelete() {
        guard let l = lastDeleted else { return }
        withAnimation(.spring) { s.logs.append(l); lastDeleted = nil }
    }
    /// cambio rápido de hoy (deslizando en una pieza)
    func changedToday(_ p: Pieza) {
        save(LogEntry(part: p.id, date: Day.today, km: s.km, note: "Apuntado deslizando"))
    }

    // MARK: importar

    /// código de facturas/km (base64 de un JSON con logs y km) o la copia JSON de la web
    func importText(_ text: String) throws -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("{"), let d = t.data(using: .utf8) {
            let st = try JSONDecoder().decode(CState.self, from: d)
            withAnimation { s = st; s.done = true }
            return "Copia restaurada: \(st.logs.count) cambios registrados"
        }
        var b = t.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let data = Data(base64Encoded: b), let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "corsa", code: 1, userInfo: [NSLocalizedDescriptionKey: "El código no es válido"])
        }
        var n = 0
        for l in (root["logs"] as? [[String: Any]]) ?? [] {
            guard let ld = try? JSONSerialization.data(withJSONObject: l), let e = try? JSONDecoder().decode(LogEntry.self, from: ld) else { continue }
            if s.logs.contains(where: { $0.id == e.id }) { continue }
            s.logs.append(e); n += 1
            let extra = (l["parts"] as? [String]) ?? []
            for part in ([e.part] + extra).filter({ !$0.isEmpty }) {
                let cur = s.parts[part]
                if cur?.unknown == true || cur?.never == true || cur?.km == nil || e.km >= (cur?.km ?? 0) { s.parts[part] = PartState(km: e.km, date: e.date) }
            }
        }
        if let km = (root["km"] as? Int) ?? (root["km"] as? Double).map({ Int($0) }), km > s.km { setKm(km, date: root["d"] as? String ?? Day.today) }
        return n > 0 ? "Importado: \(n) registro\(n == 1 ? "" : "s")" : "Ya estaba todo importado"
    }

    // MARK: avisos

    func scheduleNotifications() {
        let c = UNUserNotificationCenter.current()
        c.removeAllPendingNotificationRequests()
        func at(_ date: String, hour: Int = 10) -> DateComponents {
            var comps = Day.cal.dateComponents([.year, .month, .day], from: Day.date(date)); comps.hour = hour; return comps
        }
        func add(_ id: String, _ title: String, _ body: String, _ comps: DateComponents) {
            let n = UNMutableNotificationContent(); n.title = title; n.body = body; n.sound = .default
            c.add(UNNotificationRequest(identifier: id, content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
        if let itv = nextItv() {
            let pre = Day.add(itv, days: -30)
            if pre > Day.today { add("itv", "ITV en un mes 📋", "Pide cita para la ITV del Corsa.", at(pre)) }
        }
        // si pasa un mes sin actualizar los km
        let last = s.kmLog.last?.d ?? Day.today
        let remind = max(Day.add(last, days: 30), Day.add(Day.today, days: 1))
        add("km", "¿Cuántos km tiene el Corsa? 🚗", "Actualízalos para que los avisos de mantenimiento sean exactos.", at(remind, hour: 19))
        // piezas que caducan por fecha
        for (p, i) in sorted where i.st != .bad {
            if let d = i.dueDate, d > Day.today { add("p-" + p.id, "\(p.ic) Toca: \(p.n)", "Según el mantenimiento recomendado, ya toca revisarlo o cambiarlo.", at(d)) }
        }
    }
}
