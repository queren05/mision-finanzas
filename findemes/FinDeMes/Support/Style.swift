import SwiftUI

// MARK: - Colores: papel, tinta y madera

enum Ink {
    static let paper = Color(hex: "#f6eedb")
    static let paperDark = Color(hex: "#e7d8b4")
    static let ink = Color(hex: "#2a2018")
    static let soft = Color(hex: "#6b5a48")
    static let wood = Color(hex: "#9a6438")
    static let woodDark = Color(hex: "#6e4126")
    static let woodLight = Color(hex: "#b47a48")
    static let red = Color(hex: "#d2462e")
    static let green = Color(hex: "#3d8b4f")
    static let money = Color(hex: "#5ba566")
    static let pink = Color(hex: "#f5a7b8")
    static let pinkDark = Color(hex: "#de7f98")
    static let gold = Color(hex: "#f2b632")
    static let blue = Color(hex: "#3f74b0")
    static let purple = Color(hex: "#8a5cc2")
    static let kitchen = Color(hex: "#e9c97a")
    static let tile = Color(hex: "#f1dfa9")
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

// MARK: - Letras: Lilita One para títulos y cifras, Courier Prime para las facturas

extension Font {
    static func chunky(_ size: CGFloat) -> Font { .custom("LilitaOne", size: size) }
    static func typewriter(_ size: CGFloat, bold: Bool = false) -> Font { .custom(bold ? "CourierPrime-Bold" : "CourierPrime-Regular", size: size) }
}

// MARK: - Números

enum Fmt {
    private static let suffixes = ["", " mil", " M", " mil M", " B", " mil B", " T", " mil T", " Cu", " mil Cu", " Qi"]

    /// dinero: 1.234 € · 12,5 mil € · 3,2 M €
    static func money(_ v: Double) -> String { num(v) + " €" }

    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_ES"); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()

    static func num(_ v: Double) -> String {
        guard v.isFinite else { return "∞" }
        let a = abs(v)
        if a < 10_000 {
            if a < 100 && a.rounded(.down) != a { return dec(v, 1) }
            return grouped.string(from: NSNumber(value: v.rounded(.down))) ?? String(Int(v))
        }
        let e3 = Int(floor(log10(a) / 3))
        guard e3 < suffixes.count else {
            let e = Int(floor(log10(a)))
            return dec(v / pow(10, Double(e)), 2) + "e" + String(e)
        }
        let m = v / pow(10, Double(e3 * 3))
        return dec(m, m < 10 ? 2 : (m < 100 ? 1 : 0)) + suffixes[e3]
    }

    static func dec(_ v: Double, _ d: Int) -> String {
        String(format: "%.\(d)f", v).replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Piezas de estilo: papel, bordes gordos y sombras duras (sin desenfoques ni brillos)

struct PaperCard: ViewModifier {
    var color: Color = Ink.paper
    var tilt: Double = 0
    var shadow: CGFloat = 5
    func body(content: Self.Content) -> some View {
        content
            .background(color)
            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2.5))
            .background(Rectangle().fill(Ink.ink).offset(x: shadow * 0.6, y: shadow))
            .rotationEffect(.degrees(tilt))
    }
}

extension View {
    func paper(_ color: Color = Ink.paper, tilt: Double = 0, shadow: CGFloat = 5) -> some View {
        modifier(PaperCard(color: color, tilt: tilt, shadow: shadow))
    }
    func outlined(_ radius: CGFloat = 12, color: Color, line: CGFloat = 2.5, shadow: CGFloat = 4) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(color))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Ink.ink, lineWidth: line))
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Ink.ink).offset(y: shadow))
    }
}

/// botón gordo que se hunde de verdad al pulsarlo (la sombra desaparece)
struct ChunkyButton: ButtonStyle {
    var color: Color = Ink.gold
    var text: Color = Ink.ink
    var size: CGFloat = 20
    var radius: CGFloat = 14
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        configuration.label
            .font(.chunky(size))
            .foregroundStyle(enabled ? text : Ink.soft)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(enabled ? color : Ink.paperDark))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Ink.ink, lineWidth: 3))
            .offset(y: down ? 5 : 0)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Ink.ink).offset(y: 5))
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: down)
    }
}

/// sello de goma (PAGADO, VENCIDA…)
struct Stamp: View {
    var text: String
    var color: Color = Ink.red
    var body: some View {
        Text(text)
            .font(.typewriter(18, bold: true))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(-12))
            .opacity(0.88)
    }
}

/// fondo de la cocina: azulejos
struct KitchenBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Ink.tile))
            let s: CGFloat = 46
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = row % 2 == 0 ? 0 : -s / 2
                while x < size.width {
                    let r = CGRect(x: x + 2, y: y + 2, width: s - 4, height: s - 4)
                    ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(Ink.kitchen.opacity(0.35)))
                    x += s
                }
                y += s; row += 1
            }
        }
        .ignoresSafeArea()
    }
}

/// barra de vida / aguante con borde de tinta
struct InkBar: View {
    var value: Double
    var color: Color
    var height: CGFloat = 14
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.paperDark)
                Capsule().fill(color).frame(width: max(0, g.size.width * min(1, max(0, value))))
                Capsule().strokeBorder(Ink.ink, lineWidth: 2.5)
            }
        }
        .frame(height: height)
    }
}
