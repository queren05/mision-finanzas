import SwiftUI
import UIKit

/// Lo que la app manda al servidor de casa para los widgets de la pantalla de inicio
struct WidgetData: Codable {
    struct Acc: Codable, Hashable { var name: String; var icon: String; var color: String; var value: Double }
    struct Cat: Codable, Hashable { var name: String; var icon: String; var color: String; var total: Double }
    struct Pos: Codable, Hashable { var name: String; var value: Double; var change: Double? }
    struct Mov: Codable, Hashable { var title: String; var icon: String; var amount: Double; var date: String }

    var updated = Date()
    var netWorth = 0.0
    var cash = 0.0
    var invest = 0.0
    var investChange: Double? = nil
    var accounts: [Acc] = []
    var month = ""
    var spent = 0.0
    var earned = 0.0
    var budget = 0.0
    var cats: [Cat] = []
    var positions: [Pos] = []
    var recent: [Mov] = []
    var accent = "#e4b3cb"
    // Añadidos después: opcionales para poder leer los resúmenes antiguos.
    var name: String?
    var mood: String?
    var mascotColor: String?
    var mascotHat: String?
    var perDay: Double?
    var left: Double?
    var daysLeft: Int?

    /// el servidor de casa (solo se llega por Tailscale y solo responde a los aparatos de David)
    static let server = URL(string: "http://100.99.241.98:8790/caudal/widget")!

    /// copia propia (la app y el widget tienen cada uno la suya) por si no hay conexión
    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("widget.json")
    }
    static func cached() -> WidgetData? {
        guard let d = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: d)
    }
    private static func session() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8; c.timeoutIntervalForResource = 12
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }

    /// el widget lo pide al servidor; si no llega, lo último que tenía
    static func fetch() async -> WidgetData? {
        var r = URLRequest(url: server); r.cachePolicy = .reloadIgnoringLocalCacheData
        if let (d, resp) = try? await session().data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
           let w = try? JSONDecoder().decode(WidgetData.self, from: d) {
            try? d.write(to: cacheURL, options: .atomic)
            return w
        }
        return cached()
    }

    /// la app lo manda al servidor
    @discardableResult
    func upload() async -> Bool {
        guard let d = try? JSONEncoder().encode(self) else { return false }
        var r = URLRequest(url: WidgetData.server); r.httpMethod = "PUT"; r.httpBody = d
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let (_, resp) = try? await WidgetData.session().data(for: r) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    static let sample = WidgetData(netWorth: 1832.40, cash: 232.58, invest: 1599.82, investChange: 0.84,
        accounts: [Acc(name: "Revolut", icon: "🏦", color: "#8fb4ff", value: 127.67), Acc(name: "Trade Republic", icon: "🐷", color: "#e4b3cb", value: 100),
                   Acc(name: "Conjunta", icon: "💞", color: "#f59fc4", value: 4.91), Acc(name: "TR · ETF", icon: "📊", color: "#6fd49b", value: 1599.82)],
        month: "Octubre", spent: 517.48, earned: 441.09, budget: 700,
        cats: [Cat(name: "Comida", icon: "🍔", color: "#ff9f7a", total: 160), Cat(name: "Súper", icon: "🛒", color: "#6fd49b", total: 120),
               Cat(name: "Transporte", icon: "⛽️", color: "#7ac8ff", total: 80), Cat(name: "Ocio", icon: "🎮", color: "#b39cff", total: 45)],
        positions: [Pos(name: "MSCI World", value: 1200, change: 0.9), Pos(name: "Bitcoin", value: 399.82, change: -1.2)],
        recent: [Mov(title: "KFC", icon: "🍔", amount: -10.53, date: "2026-10-20"), Mov(title: "Monster", icon: "☕️", amount: -2, date: "2026-10-20")],
        name: "David", mood: "happy", perDay: 14.20, left: 127.80, daysLeft: 9)
}

enum WMoney {
    private static let f: NumberFormatter = {
        let f = NumberFormatter(); f.locale = Locale(identifier: "es_ES"); f.numberStyle = .decimal
        f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }()
    static func eur(_ v: Double) -> String { (f.string(from: NSNumber(value: v)) ?? "0,00") + " €" }
    static func pct(_ v: Double) -> String { (v >= 0 ? "+" : "") + (f.string(from: NSNumber(value: v)) ?? "0") + " %" }
}

extension Color {
    init(wHex: String) {
        let h = wHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0; Scanner(string: h).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
    static let wGreen = Color(wHex: "#6fd49b")
    static let wRed = Color(wHex: "#ff8686")
}

