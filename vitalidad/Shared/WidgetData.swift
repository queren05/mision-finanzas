import SwiftUI

/// Lo que la app manda al servidor de casa para los widgets (como en Caudal: el certificado de KSign no deja compartir datos directamente).
struct WidgetData: Codable {
    struct Item: Codable, Hashable {
        var id: String
        var title: String
        var symbol: String
        var value: String
        var unit: String
        var status: String   // good · normal · attention · learning
        var color: String    // #rrggbb
    }

    var updated = Date()
    var recovery: Int?
    var sleep: Int?
    var effort: Int?
    var summary = ""
    var mood = "neutral"
    var slept: String?
    var items: [Item] = []

    static let server = URL(string: "http://100.99.241.98:8790/vitalidad/widget")!

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("vitalidad-widget.json")
    }

    static func cached() -> WidgetData? {
        guard let d = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: d)
    }

    private static func session() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.timeoutIntervalForResource = 12
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }

    /// El widget lo pide al servidor; si no llega, usa lo último que tenía.
    static func fetch() async -> WidgetData? {
        var r = URLRequest(url: server)
        r.cachePolicy = .reloadIgnoringLocalCacheData
        if let (d, resp) = try? await session().data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
           let w = try? JSONDecoder().decode(WidgetData.self, from: d) {
            try? d.write(to: cacheURL, options: .atomic)
            return w
        }
        return cached()
    }

    /// La app lo manda al servidor.
    @discardableResult
    func upload() async -> Bool {
        guard let d = try? JSONEncoder().encode(self) else { return false }
        var r = URLRequest(url: WidgetData.server)
        r.httpMethod = "PUT"
        r.httpBody = d
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let (_, resp) = try? await WidgetData.session().data(for: r) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    static let sample = WidgetData(
        recovery: 72, sleep: 81, effort: 43,
        summary: "Dormiste 7 h 30, lo normal para ti. Estás recuperado: buen día para apretar si te apetece.",
        mood: "recovered", slept: "7 h 30",
        items: [
            Item(id: "steps", title: "Pasos", symbol: "figure.walk", value: "6.412", unit: "pasos", status: "good", color: "#ff943a"),
            Item(id: "restingHR", title: "Pulso en reposo", symbol: "heart.fill", value: "56", unit: "lpm", status: "good", color: "#ff5261"),
            Item(id: "hrv", title: "Variabilidad", symbol: "waveform.path.ecg", value: "58", unit: "ms", status: "normal", color: "#38d994"),
            Item(id: "calories", title: "Calorías", symbol: "fork.knife", value: "1.540", unit: "kcal", status: "normal", color: "#ff669e"),
        ])
}

// MARK: - Colores y piezas compartidas

extension Color {
    init(wHex: String) {
        let h = wHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }

    var wHex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }
}

enum WTone {
    static let recovery = Color(red: 0.22, green: 0.85, blue: 0.58)
    static let sleep = Color(red: 0.45, green: 0.42, blue: 1.00)
    static let effort = Color(red: 1.00, green: 0.58, blue: 0.22)

    static func status(_ s: String) -> Color {
        switch s {
        case "good": Color(red: 0.25, green: 0.86, blue: 0.55)
        case "attention": Color(red: 1.00, green: 0.70, blue: 0.22)
        case "normal": Color(red: 0.56, green: 0.72, blue: 0.98)
        default: .gray
        }
    }

    /// Fondo del widget según cómo va el día.
    static func background(_ mood: String) -> LinearGradient {
        let top: Color = switch mood {
        case "recovered": Color(red: 0.04, green: 0.30, blue: 0.27)
        case "steady": Color(red: 0.05, green: 0.20, blue: 0.33)
        case "easy": Color(red: 0.36, green: 0.20, blue: 0.04)
        case "night": Color(red: 0.20, green: 0.10, blue: 0.40)
        default: Color(red: 0.10, green: 0.14, blue: 0.22)
        }
        return LinearGradient(colors: [top, Color(red: 0.03, green: 0.04, blue: 0.07)], startPoint: .top, endPoint: .bottom)
    }
}

/// Anillo pequeño con número dentro.
struct WRing: View {
    var value: Int?
    var color: Color
    var line: CGFloat = 6
    var font: Font = .system(size: 17, weight: .bold, design: .rounded)

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: line)
            Circle()
                .trim(from: 0, to: Double(value ?? 0) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(value.map(String.init) ?? "–").font(font).minimumScaleFactor(0.6)
        }
        .padding(line / 2)
    }
}
