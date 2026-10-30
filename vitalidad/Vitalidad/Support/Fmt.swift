import Foundation

/// Números, horas y duraciones escritos como en España.
enum Fmt {
    static var energyIsKJ: Bool { UserDefaults.standard.string(forKey: "energia") == EnergyUnit.kJ.rawValue }
    static var energyUnit: String { energyIsKJ ? "kJ" : "kcal" }

    /// Pasa kilocalorías a la unidad elegida en Ajustes.
    static func energy(_ kcal: Double) -> Double { energyIsKJ ? kcal * 4.184 : kcal }

    /// 5.200 · 12.345 · 7,5 (siempre con punto de miles, también con 4 cifras).
    static func number(_ v: Double, decimals: Int = 0) -> String {
        // Crear formateadores es caro: se guardan y se reutilizan.
        let f = numberFormatters[decimals] ?? {
            let f = NumberFormatter()
            f.locale = Locale(identifier: "es_ES")
            f.numberStyle = .decimal
            f.minimumFractionDigits = 0
            f.maximumFractionDigits = decimals
            f.usesGroupingSeparator = false
            numberFormatters[decimals] = f
            return f
        }()
        let s = f.string(from: NSNumber(value: v)) ?? "\(v)"
        // El español no agrupa los números de 4 cifras; aquí sí, para que se lean mejor.
        let parts = s.split(separator: ",", maxSplits: 1).map(String.init)
        var int = parts[0]
        let neg = int.hasPrefix("-")
        if neg { int.removeFirst() }
        var out = ""
        for (i, ch) in int.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(".") }
            out.append(ch)
        }
        return (neg ? "-" : "") + String(out.reversed()) + (parts.count > 1 ? "," + parts[1] : "")
    }

    /// 6 h 40 · 45 min
    static func duration(_ seconds: TimeInterval) -> String {
        let m = Int((seconds / 60).rounded())
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", r))"
    }

    /// 23:40
    static func clock(_ d: Date) -> String { day(d, style: "H:mm") }

    /// «lunes 3» · «3 oct»
    static func day(_ d: Date, style: String = "EEEE d") -> String {
        let f = dateFormatters[style] ?? {
            let f = DateFormatter()
            f.locale = Locale(identifier: "es_ES")
            f.dateFormat = style
            dateFormatters[style] = f
            return f
        }()
        return f.string(from: d)
    }

    nonisolated(unsafe) private static var numberFormatters: [Int: NumberFormatter] = [:]
    nonisolated(unsafe) private static var dateFormatters: [String: DateFormatter] = [:]

    /// Valor de una métrica listo para pintar, sin la unidad.
    static func value(_ m: Metric, _ v: Double) -> String {
        switch m {
        case .sleep: duration(v)
        case .activeEnergy, .basalEnergy, .calories: number(energy(v))
        case .hrv, .heartRate, .restingHR, .walkingHR, .steps, .exerciseMinutes, .standHours, .protein, .carbs, .fat: number(v)
        case .respiratoryRate, .vo2max, .weight: number(v, decimals: 1)
        case .water: number(v, decimals: 1)
        }
    }

    /// Valor con su unidad: «58 lpm», «6 h 40», «1.850 kcal».
    static func full(_ m: Metric, _ v: Double) -> String {
        let u = m.unit
        return u.isEmpty ? value(m, v) : "\(value(m, v)) \(u)"
    }
}

extension String {
    /// «viernes, 30 de octubre» → «Viernes, 30 de octubre».
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
