import Foundation
import SwiftUI

/// Lo normal en ti para una métrica: mediana de los últimos 30 días y rango = mediana ± desviación.
struct Baseline: Equatable {
    var median: Double
    var spread: Double
    var count: Int

    var low: Double { median - spread }
    var high: Double { median + spread }

    /// Días mínimos para opinar.
    static let minDays = 7

    init?(_ values: [Double], metric: Metric? = nil) {
        guard values.count >= Self.minDays else { return nil }
        let s = values.sorted()
        let mid = s.count / 2
        median = s.count % 2 == 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid]
        let mean = s.reduce(0, +) / Double(s.count)
        let sd = sqrt(s.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(s.count - 1))
        // Un rango nunca más estrecho que el 4 % de la mediana (ni que la precisión del aparato).
        spread = max(sd, abs(median) * 0.04, metric.map(Self.minSpread) ?? 0)
        count = s.count
    }

    private static func minSpread(_ m: Metric) -> Double {
        switch m {
        case .restingHR, .walkingHR, .heartRate: 1.5
        case .respiratoryRate: 0.4
        case .weight: 0.4
        case .vo2max: 0.5
        case .sleep: 15 * 60
        default: 0
        }
    }

    /// Cuántas «desviaciones» se separa un valor de lo normal.
    func z(_ v: Double, expected: Double? = nil) -> Double {
        let ref = expected ?? median
        let band = expected.map { spread * max(0.35, $0 / max(median, 0.0001)) } ?? spread
        return band > 0 ? (v - ref) / band : 0
    }
}

/// Estado de color de cada tarjeta.
enum Status: String {
    case good, normal, attention, learning

    var title: String {
        switch self {
        case .good: "Bien"
        case .normal: "Normal"
        case .attention: "Atención"
        case .learning: "Aprendiendo"
        }
    }

    var color: Color {
        switch self {
        case .good: Palette.good
        case .normal: Palette.normal
        case .attention: Palette.attention
        case .learning: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .good: "arrow.up.heart.fill"
        case .normal: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .learning: "hourglass"
        }
    }

    static func from(z: Double, direction: Metric.Direction) -> Status {
        switch direction {
        case .higher: z > 1 ? .good : z < -1 ? .attention : .normal
        case .lower: z < -1 ? .good : z > 1 ? .attention : .normal
        case .stable: abs(z) > 1.5 ? .attention : .normal
        case .none: .normal
        }
    }
}

extension HealthStore {
    /// Lo normal en ti, con los 30 días anteriores a `day` (sin contar ese día).
    func baseline(_ m: Metric, before day: Date? = nil) -> Baseline? {
        remember("base|\(m.rawValue)|\(day?.timeIntervalSince1970 ?? 0)") { computeBaseline(m, before: day) }
    }

    private func computeBaseline(_ m: Metric, before day: Date?) -> Baseline? {
        let cal = Calendar.current
        let end = cal.startOfDay(for: day ?? today)
        let start = cal.date(byAdding: .day, value: -30, to: end)!
        let vals = (values[m] ?? [:]).filter { $0.key >= start && $0.key < end }.map(\.value)
            // Días sin reloj (muy pocos pasos o energía) estropean la media de lo acumulado.
            .filter { !m.accumulates || $0 > 0 }
        return Baseline(vals, metric: m)
    }

    /// Parte del día que normalmente ya has hecho a esta hora (para comparar lo acumulado hoy de forma justa).
    /// Curva sencilla: casi nada antes de las 7 y todo a las 22, con algo más de peso por la tarde.
    var dayProgress: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let h = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        let x = min(1, max(0, (h - 7) / 15))
        return max(0.05, min(1, x * (0.85 + 0.15 * x)))
    }
}
