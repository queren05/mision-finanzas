import SwiftUI

/// Colores de la app: uno por cada familia de métricas y tres para los estados.
enum Palette {
    static let sleep = Color(red: 0.45, green: 0.42, blue: 1.00)      // índigo
    static let recovery = Color(red: 0.22, green: 0.85, blue: 0.58)   // verde
    static let effort = Color(red: 1.00, green: 0.58, blue: 0.22)     // naranja
    static let nutrition = Color(red: 1.00, green: 0.40, blue: 0.62)  // rosa
    static let heart = Color(red: 1.00, green: 0.32, blue: 0.38)
    static let breath = Color(red: 0.35, green: 0.78, blue: 1.00)
    static let body = Color(red: 0.70, green: 0.62, blue: 1.00)

    static let good = adaptive(dark: (0.25, 0.86, 0.55), light: (0.05, 0.58, 0.32))
    static let normal = adaptive(dark: (0.56, 0.72, 0.98), light: (0.20, 0.42, 0.85))
    static let attention = adaptive(dark: (1.00, 0.70, 0.22), light: (0.80, 0.45, 0.00))

    /// Más oscuro en modo claro para que el texto se lea bien.
    static func adaptive(dark: (Double, Double, Double), light: (Double, Double, Double)) -> Color {
        Color(UIColor { t in
            let c = t.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

/// Estado general del día; decide el color del fondo.
enum Mood: String, Equatable {
    case recovered, steady, easy, night, neutral

    var key: String { rawValue }

    /// Nueve colores de la malla (3 × 3), de arriba abajo.
    func mesh(_ scheme: ColorScheme) -> [Color] {
        let dark = scheme == .dark
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
            if dark { return Color(red: r, green: g, blue: b) }
            // En claro: el mismo tono, a todo color y mezclado con blanco (pastel, nunca gris).
            let m = max(r, g, b, 0.01)
            return Color(red: 0.55 + 0.45 * r / m, green: 0.55 + 0.45 * g / m, blue: 0.55 + 0.45 * b / m)
        }
        let base = dark ? Color(red: 0.03, green: 0.04, blue: 0.07) : Color(red: 0.96, green: 0.97, blue: 0.98)
        switch self {
        case .recovered:
            return [c(0.04, 0.32, 0.30), c(0.05, 0.42, 0.34), c(0.03, 0.22, 0.28),
                    c(0.03, 0.16, 0.18), c(0.06, 0.26, 0.22), c(0.04, 0.12, 0.20),
                    base, base, base]
        case .steady:
            return [c(0.06, 0.20, 0.36), c(0.05, 0.30, 0.38), c(0.10, 0.16, 0.34),
                    c(0.04, 0.12, 0.22), c(0.05, 0.18, 0.24), c(0.06, 0.10, 0.20),
                    base, base, base]
        case .easy:
            return [c(0.40, 0.22, 0.04), c(0.46, 0.30, 0.06), c(0.34, 0.14, 0.08),
                    c(0.22, 0.12, 0.05), c(0.26, 0.16, 0.06), c(0.18, 0.08, 0.08),
                    base, base, base]
        case .night:
            return [c(0.20, 0.10, 0.42), c(0.28, 0.14, 0.48), c(0.12, 0.08, 0.34),
                    c(0.10, 0.06, 0.24), c(0.16, 0.08, 0.30), c(0.08, 0.05, 0.20),
                    base, base, base]
        case .neutral:
            return [c(0.10, 0.14, 0.22), c(0.12, 0.18, 0.26), c(0.08, 0.10, 0.20),
                    c(0.06, 0.08, 0.14), c(0.08, 0.10, 0.16), c(0.05, 0.06, 0.12),
                    base, base, base]
        }
    }
}

/// Fondo: casi negro (o papel muy claro) con un resplandor arriba del color del día. Sobrio, como las apps de salud serias.
struct MoodBackground: View {
    var mood: Mood
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = mood.mesh(scheme)
        let dark = scheme == .dark
        ZStack {
            Ink.canvas
            // Dos luces suaves en la parte de arriba: el color del estado del día.
            RadialGradient(colors: [colors[1].opacity(dark ? 0.95 : 0.9), .clear], center: UnitPoint(x: 0.2, y: -0.05), startRadius: 0, endRadius: 460)
            RadialGradient(colors: [colors[2].opacity(dark ? 0.8 : 0.7), .clear], center: UnitPoint(x: 0.95, y: 0.02), startRadius: 0, endRadius: 380)
            LinearGradient(colors: [.clear, Ink.canvas], startPoint: UnitPoint(x: 0.5, y: 0.18), endPoint: UnitPoint(x: 0.5, y: 0.55))
        }
        .animation(.easeInOut(duration: 1.2), value: mood)
        .ignoresSafeArea()
    }
}

/// Colores de base (fondo, superficies, líneas) que cambian con el modo claro u oscuro.
enum Ink {
    static let canvas = Palette.adaptive(dark: (0.035, 0.04, 0.055), light: (0.955, 0.955, 0.965))
    static let surface = Palette.adaptive(dark: (0.085, 0.09, 0.11), light: (1, 1, 1))
    static let surfaceHigh = Palette.adaptive(dark: (0.12, 0.125, 0.15), light: (0.985, 0.985, 0.99))
    static let track = Palette.adaptive(dark: (0.19, 0.2, 0.23), light: (0.88, 0.885, 0.9))
    static let hairline = Palette.adaptive(dark: (1, 1, 1), light: (0, 0, 0))
}

// MARK: - Tarjetas y botones

extension View {
    /// Tarjeta sólida con un filo de luz arriba. Esquinas de 26 pt.
    @ViewBuilder
    func card(padding: CGFloat = 20, radius: CGFloat = 26, tint: Color? = nil) -> some View {
        modifier(CardModifier(padding: padding, radius: radius, tint: tint))
    }

    /// Botón principal: cristal en iOS 26, relleno en versiones anteriores.
    @ViewBuilder
    func primaryButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func secondaryButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// La barra de pestañas se encoge al bajar (iOS 26).
    @ViewBuilder
    func minimizingTabBar() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// Entrada suave de las tarjetas al hacer scroll.
    func scrollFade() -> some View {
        scrollTransition(.animated(.smooth)) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.4)
                .scaleEffect(phase.isIdentity ? 1 : 0.97)
        }
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var tint: Color?
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = scheme == .dark
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    shape.fill(LinearGradient(colors: [Ink.surfaceHigh, Ink.surface], startPoint: .top, endPoint: .bottom))
                    if let tint {
                        shape.fill(RadialGradient(colors: [tint.opacity(dark ? 0.22 : 0.12), .clear], center: .topLeading, startRadius: 0, endRadius: 320))
                    }
                }
                .shadow(color: .black.opacity(dark ? 0 : 0.06), radius: 14, y: 6)
            }
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [Ink.hairline.opacity(dark ? 0.13 : 0.07), Ink.hairline.opacity(dark ? 0.03 : 0.04)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
    }
}

/// Espaciados de la app (múltiplos de 4).
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Launch {
    static let args = ProcessInfo.processInfo.arguments
    static var demo: Bool { args.contains("-demo") }
    static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

// MARK: - Transición de zoom (iOS 18+)

extension View {
    @ViewBuilder
    func zoomSource<ID: Hashable>(_ id: ID, _ ns: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: ns)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination<ID: Hashable>(_ id: ID, _ ns: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: ns))
        } else {
            self
        }
    }
}
