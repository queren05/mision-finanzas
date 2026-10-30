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
enum Mood: Equatable {
    case recovered, steady, easy, night, neutral

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

/// Fondo vivo: una malla de color que respira despacio (iOS 18+) o un degradado en iOS 17.
struct MoodBackground: View {
    var mood: Mood
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = mood.mesh(scheme)
        Group {
            if #available(iOS 18.0, *) {
                // Quieta: una malla que se mueve obliga al cristal de todas las tarjetas a redibujarse en cada fotograma.
                MeshGradient(width: 3, height: 3, points: Self.points(2.2), colors: colors)
                    .drawingGroup()
            } else {
                ZStack {
                    LinearGradient(colors: [colors[1], colors[4], colors[7]], startPoint: .top, endPoint: .bottom)
                    RadialGradient(colors: [colors[0].opacity(0.8), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
                    RadialGradient(colors: [colors[2].opacity(0.7), .clear], center: .topTrailing, startRadius: 0, endRadius: 380)
                }
            }
        }
        .animation(.easeInOut(duration: 1.2), value: mood)
        .ignoresSafeArea()
    }

    static func points(_ t: Double) -> [SIMD2<Float>] {
        func w(_ speed: Double, _ phase: Double, _ amp: Double) -> Float { Float(sin(t * speed + phase) * amp) }
        return [
            [0, 0], [0.5 + w(0.21, 0, 0.12), 0], [1, 0],
            [0, 0.42 + w(0.17, 1, 0.08)], [0.5 + w(0.23, 2, 0.14), 0.45 + w(0.19, 3, 0.1)], [1, 0.40 + w(0.15, 4, 0.08)],
            [0, 1], [0.5, 1], [1, 1],
        ]
    }
}

// MARK: - Tarjetas y botones de cristal

extension View {
    /// Tarjeta con cristal líquido (iOS 26) o material translúcido (iOS 17-18). Esquinas de 24 pt.
    @ViewBuilder
    func card(padding: CGFloat = 20, radius: CGFloat = 24, tint: Color? = nil) -> some View {
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
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let inner = content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
        if reduceTransparency {
            inner.background(Color(.secondarySystemBackground), in: shape)
        } else if #available(iOS 26.0, *) {
            let glass: Glass = tint.map { Glass.regular.tint($0.opacity(0.18)) } ?? Glass.regular
            inner.glassEffect(glass, in: shape)
        } else {
            inner
                .background(.ultraThinMaterial, in: shape)
                .background((tint ?? .clear).opacity(0.10), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(scheme == .dark ? 0.08 : 0.4), lineWidth: 0.5))
        }
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
