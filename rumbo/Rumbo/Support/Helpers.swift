import SwiftUI
import UIKit

// MARK: - Fechas (se guardan como texto yyyy-MM-dd, siempre en hora local)

enum Day {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_ES")
        c.firstWeekday = 2
        return c
    }()
    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let hm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let long: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d 'de' MMMM"
        return f
    }()
    private static let longYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d 'de' MMMM 'de' yyyy"
        return f
    }()
    private static let monthName: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "LLLL"
        return f
    }()
    private static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "LLLL yyyy"
        return f
    }()
    private static let short: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM"
        return f
    }()

    static func str(_ d: Date) -> String { iso.string(from: d) }
    static func date(_ s: String) -> Date { iso.date(from: s) ?? Date() }
    static func time(_ d: Date) -> String { hm.string(from: d) }
    static var today: String { str(Date()) }
    static func add(_ s: String, days: Int) -> String { str(cal.date(byAdding: .day, value: days, to: date(s)) ?? date(s)) }
    static func add(_ s: String, months: Int) -> String { str(cal.date(byAdding: .month, value: months, to: date(s)) ?? date(s)) }

    /// "Hoy", "Ayer" o "12 de octubre"
    static func header(_ s: String) -> String {
        if s == today { return "Hoy" }
        if s == add(today, days: -1) { return "Ayer" }
        let d = date(s)
        if cal.component(.year, from: d) != cal.component(.year, from: Date()) { return longYear.string(from: d) }
        return long.string(from: d)
    }
    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE"
        return f
    }()
    static func weekdayName(_ s: String) -> String { weekday.string(from: date(s)) }
    static func shortLabel(_ s: String) -> String { short.string(from: date(s)) }
    static func month(_ s: String) -> String { monthName.string(from: date(s)).capitalized }
    static func monthYearLabel(_ s: String) -> String { monthYear.string(from: date(s)).capitalized }
    /// primer día del mes de la fecha (yyyy-MM-01)
    static func monthStart(_ s: String) -> String { String(s.prefix(7)) + "-01" }
    static func monthKey(_ s: String) -> String { String(s.prefix(7)) }
}

// MARK: - Colores

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 3 {
            let r = (v >> 8) & 0xF, g = (v >> 4) & 0xF, b = v & 0xF
            self.init(red: Double(r * 17) / 255, green: Double(g * 17) / 255, blue: Double(b * 17) / 255)
        } else {
            self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
        }
    }
    static let income = Color(red: 0.29, green: 0.84, blue: 0.56)
    static let expense = Color.primary
    static let negative = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let cardBG = Color(.secondarySystemGroupedBackground)
}

let palette = ["#b39cff", "#e4b3cb", "#8fb4ff", "#6fd49b", "#f0c46a", "#ff9f7a", "#b39cff", "#62cfd0", "#ff8686", "#c3d36a", "#d9a0f5", "#7ac8ff", "#f59fc4", "#a9b3c2"]

// MARK: - Vibraciones

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Botones que se hunden al pulsarlos

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    /// tarjeta redondeada sobre el fondo agrupado
    func card(_ padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// círculo con el emoji de la categoría o la cuenta
struct IconBubble: View {
    var icon: String
    var color: String
    var size: CGFloat = 44
    var body: some View {
        Text(icon)
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(Color(hex: color).opacity(0.22), in: Circle())
            .overlay(Circle().strokeBorder(Color(hex: color).opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Dinero

enum Money {
    private static let f: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()
    static func eur(_ v: Double) -> String { (f.string(from: NSNumber(value: v)) ?? "0,00") + " €" }
    static func num(_ v: Double) -> String { f.string(from: NSNumber(value: v)) ?? "0,00" }
    /// «23,40» o «23.40» → 23.4
    static func parse(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: " ", with: "")
        let n = t.contains(",") ? t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") : t
        return Double(n)
    }
}
