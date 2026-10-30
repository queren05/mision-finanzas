import SwiftUI

/// Anillo que se rellena con un muelle. `progress` va de 0 a 1.
struct Ring: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 12
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(shown, 1)))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.65), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(shown, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.45), radius: lineWidth * 0.5)
        }
        .padding(lineWidth / 2)
        .onAppear { animate(to: progress, delay: 0.15) }
        .onChange(of: progress) { _, p in animate(to: p, delay: 0) }
    }

    private func animate(to p: Double, delay: Double) {
        if reduceMotion { shown = p; return }
        withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(delay)) { shown = p }
    }
}

/// Icono redondo con el color de la métrica.
struct MetricGlyph: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: Circle())
    }
}

/// Aparición escalonada: cada elemento entra un poco después del anterior.
struct Stagger: ViewModifier {
    var index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.86).delay(Double(index) * 0.06)) { shown = true }
            }
    }
}

extension View {
    func stagger(_ index: Int) -> some View { modifier(Stagger(index: index)) }
}

/// Números grandes que también crecen con el tamaño de letra del sistema (con tope para que quepan).
struct BigFont: ViewModifier {
    var size: CGFloat
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.font(.system(size: size * min(scale, 1.5), weight: .bold, design: .rounded))
    }
}

extension View {
    func bigFont(_ size: CGFloat) -> some View { modifier(BigFont(size: size)) }
}
