import SwiftUI

// MARK: - Fondo: cielo con estrellas que titilan y nebulosas que se mueven despacio

struct SpaceBackground: View {
    var active: Bool
    // fijas (static): si no, cambiarían cada vez que se redibuja la vista
    private static let stars: [(x: Double, y: Double, r: Double, speed: Double, phase: Double)] = (0..<140).map { _ in
        (Double.random(in: 0...1), Double.random(in: 0...1), Double.random(in: 0.4...1.6), Double.random(in: 0.5...2.2), Double.random(in: 0...6.28))
    }

    var body: some View {
        // a 20 fps basta para el fondo: gasta poca batería
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !active)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                // nebulosas
                let blobs: [(Color, Double, Double, Double)] = [(Palette.dark, 0.2, 0.25, 0.9), (Palette.singularity, 0.85, 0.6, 0.7), (Palette.energy, 0.5, 0.95, 0.8)]
                for (k, b) in blobs.enumerated() {
                    let cx = size.width * (b.1 + 0.06 * sin(t * 0.05 + Double(k)))
                    let cy = size.height * (b.2 + 0.04 * cos(t * 0.04 + Double(k) * 2))
                    let r = size.width * b.3
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(colors: [b.0.opacity(0.22), .clear]), center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r))
                }
                for s in Self.stars {
                    let a = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
                    let rect = CGRect(x: s.x * size.width, y: s.y * size.height, width: s.r, height: s.r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a)))
                }
            }
        }
        .background(LinearGradient(colors: [Palette.bgTop, Palette.bgBottom], startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Panel de cristal

struct GlassCard: ViewModifier {
    var radius: CGFloat = 20
    var tint: Color = .white
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(tint.opacity(0.05), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(
                LinearGradient(colors: [tint.opacity(0.35), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}

extension View {
    func glass(_ radius: CGFloat = 20, tint: Color = .white) -> some View { modifier(GlassCard(radius: radius, tint: tint)) }
}

/// botón que se hunde al pulsarlo
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// icono de color en un cuadrado brillante
struct IconTile: View {
    var icon: String
    var color: Color
    var size: CGFloat = 44
    var dim = false
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(dim ? Color.white.opacity(0.25) : .white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(dim ? 0.15 : 0.95), color.opacity(dim ? 0.05 : 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: dim ? .clear : color.opacity(0.55), radius: 8)
    }
}

/// barra de progreso con brillo
struct GlowBar: View {
    var value: Double
    var color: Color
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule().fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, g.size.width * min(1, max(0, value))))
                    .shadow(color: color.opacity(0.7), radius: 4)
            }
        }
        .frame(height: height)
    }
}

/// cifra de una moneda con su icono
struct CurrencyChip: View {
    var icon: String
    var value: Double
    var color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(color)
            Text(Fmt.num(value)).font(.system(.subheadline, design: .rounded).weight(.bold)).monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .glass(14, tint: color)
    }
}

// MARK: - Avisos que bajan desde arriba

struct ToastStack: View {
    @Environment(GameEngine.self) private var game
    var body: some View {
        VStack(spacing: 8) {
            ForEach(game.toasts) { t in
                HStack(spacing: 12) {
                    IconTile(icon: t.icon, color: Color(hex: t.color), size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.title).font(.subheadline.weight(.bold))
                        Text(t.subtitle).font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .glass(18, tint: Color(hex: t.color))
                .shadow(color: Color(hex: t.color).opacity(0.35), radius: 16)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
        .allowsHitTesting(false)
    }
}
