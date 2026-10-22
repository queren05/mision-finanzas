import SwiftUI
import UIKit
import AVFoundation

/// El aspecto elegido en Personalizar, a mano desde cualquier vista (lo actualiza la tienda al cambiar los ajustes).
@Observable
final class Look {
    static let shared = Look()
    var s = Settings()

    var cornerScale: CGFloat {
        switch s.corners { case "suaves": 0.6; case "muy": 1.35; default: 1 }
    }
    var space: CGFloat { s.density == "compacta" ? 0.78 : 1 }
    var motion: Bool { !s.reducedMotion }
    /// fondo de siempre (sin dibujos ni negro puro)
    var plainBackdrop: Bool { s.background == "liso" && !s.amoled }
    var scheme: ColorScheme? {
        switch s.theme { case "light": .light; case "system": nil; default: .dark }
    }
    var fontDesign: Font.Design? {
        switch s.font { case "burbuja": .rounded; case "elegante": .serif; case "maquina": .monospaced; default: nil }
    }
    var typeSize: DynamicTypeSize? {
        switch s.textSize { case "pequena": .small; case "grande": .xLarge; default: nil }
    }
    var accent: Color { Color(hex: s.accent) }
    var mascotColor: Color { Color(hex: s.mascotColor.isEmpty ? s.accent : s.mascotColor) }

    /// vuelve al estilo de siempre (sin tocar nombre, color, bloqueo ni el día de inicio del mes)
    static func reset(_ s: inout Settings) {
        let d = Settings()
        s.theme = d.theme; s.amoled = d.amoled; s.font = d.font; s.textSize = d.textSize
        s.cardStyle = d.cardStyle; s.corners = d.corners; s.density = d.density; s.background = d.background
        s.hideCents = d.hideCents; s.haptics = d.haptics; s.sounds = d.sounds; s.ripple = d.ripple
        s.reducedMotion = d.reducedMotion; s.tabs = d.tabs; s.mascot = d.mascot; s.mascotHat = d.mascotHat
        s.mascotColor = d.mascotColor; s.appIcon = d.appIcon
    }
}

extension Color {
    /// fondo de las pantallas (negro puro con AMOLED en modo oscuro)
    static var appBG: Color {
        guard Look.shared.s.amoled else { return Color(.systemGroupedBackground) }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .systemGroupedBackground })
    }
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }
    /// mezcla con otro color (0 = este, 1 = el otro)
    func mix(_ other: Color, _ t: CGFloat) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t)
    }
}

// MARK: - Tarjetas

struct CardBackground: ViewModifier {
    var padding: CGFloat
    var style: String? = nil
    func body(content: Content) -> some View {
        let L = Look.shared
        let shape = RoundedRectangle(cornerRadius: 22 * L.cornerScale, style: .continuous)
        content
            .padding(padding * L.space)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                switch style ?? L.s.cardStyle {
                case "cristal":
                    shape.fill(.ultraThinMaterial).overlay(shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                case "contorno":
                    shape.strokeBorder(Color.primary.opacity(0.16), lineWidth: 1.2)
                default:
                    shape.fill(Color.cardBG)
                }
            }
    }
}

// MARK: - Fondos

struct AppBackground: View {
    /// para las muestras de Personalizar
    var style: String? = nil
    var body: some View {
        let L = Look.shared
        ZStack {
            Color.appBG
            switch style ?? L.s.background {
            case "agua": WavesBackdrop(color: L.accent)
            case "brillo":
                ZStack {
                    RadialGradient(colors: [L.accent.opacity(0.32), .clear], center: .topLeading, startRadius: 0, endRadius: 460)
                    RadialGradient(colors: [L.accent.mix(.blue, 0.4).opacity(0.18), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 420)
                }
            case "puntos":
                Canvas { ctx, size in
                    let step: CGFloat = 22
                    var y: CGFloat = 8
                    while y < size.height {
                        var x: CGFloat = 8
                        while x < size.width {
                            ctx.fill(Path(ellipseIn: CGRect(x: x - 1.3, y: y - 1.3, width: 2.6, height: 2.6)), with: .color(L.accent.opacity(0.22)))
                            x += step
                        }
                        y += step
                    }
                }
            default: EmptyView()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// olas suaves al fondo de la pantalla; se mueven unos segundos y se calman
struct WavesBackdrop: View {
    var color: Color
    @State private var start = Date()
    @State private var calm = false
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: calm || !Look.shared.motion)) { tl in
            let t = calm ? 10 : tl.date.timeIntervalSince(start)
            Canvas { ctx, size in
                let h = size.height, w = size.width
                for (i, layer) in [(0.80, 0.10, 1.0), (0.86, 0.14, 1.4), (0.92, 0.2, 0.8)].enumerated() {
                    let base: CGFloat = h * CGFloat(layer.0)
                    let amp: CGFloat = h * 0.018
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: h))
                    var x: CGFloat = 0
                    while x <= w + 8 {
                        let phase: Double = Double(x / w) * 2 * Double.pi * layer.2 + t * (0.5 + Double(i) * 0.25) + Double(i)
                        let y: CGFloat = base + amp * CGFloat(sin(phase))
                        p.addLine(to: CGPoint(x: x, y: y))
                        x += 8
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(color.opacity(layer.1)))
                }
                ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.5)),
                         with: .linearGradient(Gradient(colors: [color.opacity(0.10), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.5)))
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            calm = true
        }
    }
}

extension View {
    /// fondo de las pantallas con scroll
    func appBackground() -> some View { background(AppBackground()) }
    /// fondo de las listas (si es el de siempre, no cambia nada)
    func appList() -> some View { modifier(AppListBackground()) }
}

struct AppListBackground: ViewModifier {
    func body(content: Content) -> some View {
        let plain = Look.shared.plainBackdrop
        content
            .scrollContentBackground(plain ? .automatic : .hidden)
            .background { if !plain { AppBackground() } }
    }
}

// MARK: - Onda al tocar

struct RippleRing: View {
    var pressed: Bool
    @State private var p: CGFloat = 1
    var body: some View {
        GeometryReader { g in
            let r = hypot(g.size.width, g.size.height)
            let c = Look.shared.accent
            ZStack {
                Circle().fill(c.opacity(0.18 * (1 - p))).frame(width: r * p, height: r * p)
                Circle().stroke(c.opacity(0.45 * (1 - p)), lineWidth: 2).frame(width: r * p * 0.7, height: r * p * 0.7)
                Circle().stroke(c.opacity(0.3 * (1 - p)), lineWidth: 1.5).frame(width: r * p * 0.4, height: r * p * 0.4)
            }
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
        .allowsHitTesting(false)
        .onChange(of: pressed) { _, v in
            guard v else { return }
            p = 0
            withAnimation(.easeOut(duration: 0.65)) { p = 1 }
        }
    }
}

// MARK: - Sonidos

enum Sound {
    private static var players: [String: AVAudioPlayer] = [:]
    /// plop (apuntar), pop (borrar), chime (logros)
    static func play(_ name: String) {
        guard Look.shared.s.sounds else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        if players[name] == nil, let u = Bundle.main.url(forResource: name, withExtension: "wav") {
            players[name] = try? AVAudioPlayer(contentsOf: u)
            players[name]?.volume = 0.6
        }
        players[name]?.currentTime = 0
        players[name]?.play()
    }
}

// MARK: - Icono de la app

enum AppIcons {
    static let all: [(id: String, name: String)] = [
        ("", "Original"), ("Menta", "Menta"), ("Cielo", "Cielo"), ("Lavanda", "Lavanda"),
        ("Melocoton", "Melocotón"), ("Oro", "Oro"), ("Claro", "Claro"), ("Gotita", "Gotita"),
    ]
    static func set(_ id: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(id.isEmpty ? nil : "AppIcon-" + id) { _ in }
    }
}
