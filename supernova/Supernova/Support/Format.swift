import SwiftUI

/// Números grandes legibles: 1,23 M · 45,6 Qa · 7,89e312
enum Fmt {
    private static let suffixes = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
                                   "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg",
                                   "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg", "Tg"]
    static var scientific = false

    static func num(_ v: Double) -> String {
        guard v.isFinite else { return "∞" }
        let a = abs(v)
        if a < 1000 {
            if a < 100 && a.rounded(.down) != a { return dec(v, 1) }
            return String(Int(v.rounded(.down)))
        }
        let e3 = Int(floor(log10(a) / 3))
        if !scientific && e3 < suffixes.count {
            let m = v / pow(10, Double(e3 * 3))
            return dec(m, m < 10 ? 2 : (m < 100 ? 1 : 0)) + " " + suffixes[e3]
        }
        let e = Int(floor(log10(a)))
        return dec(v / pow(10, Double(e)), 2) + "e" + String(e)
    }

    static func dec(_ v: Double, _ d: Int) -> String {
        String(format: "%.\(d)f", v).replacingOccurrences(of: ".", with: ",")
    }

    static func pct(_ v: Double) -> String { num(v * 100) + " %" }

    static func time(_ s: Double) -> String {
        let t = Int(max(0, s))
        let d = t / 86400, h = t % 86400 / 3600, m = t % 3600 / 60, sec = t % 60
        if d > 0 { return "\(d) d \(h) h" }
        if h > 0 { return "\(h) h \(m) min" }
        if m > 0 { return "\(m) min \(sec) s" }
        return "\(sec) s"
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB, red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255, opacity: 1)
    }
}

/// Paleta del juego
enum Palette {
    static let energy = Color(hex: "#5ed9ff")
    static let dark = Color(hex: "#b17bff")
    static let singularity = Color(hex: "#ff7ad9")
    static let universe = Color(hex: "#ffd36e")
    static let gold = Color(hex: "#ffc94d")
    static let good = Color(hex: "#6ff0a8")
    static let bgTop = Color(hex: "#06041a")
    static let bgBottom = Color(hex: "#1a0b3d")
    static let panel = Color.white.opacity(0.06)
}
