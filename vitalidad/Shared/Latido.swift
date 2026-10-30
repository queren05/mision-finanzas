import SwiftUI

/// Latido: la mascota de Vitalidad, un corazón con cara que pone gesto según cómo estás.
enum LatidoMood: String, Codable {
    case love, happy, calm, tired, sleepy

    /// La cara según la recuperación (y de noche, dormido).
    static func from(recovery: Int?, night: Bool) -> LatidoMood {
        if night { return .sleepy }
        guard let r = recovery else { return .calm }
        return r >= 80 ? .love : r >= 60 ? .happy : r >= 40 ? .calm : .tired
    }
}

struct Latido: View {
    var mood: LatidoMood = .happy
    var size: CGFloat = 60
    var color = Color(red: 1.0, green: 0.42, blue: 0.5)

    var body: some View {
        Canvas { ctx, sz in
            LatidoDraw.draw(ctx, sz.width, sz.height, mood, color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum LatidoDraw {
    static let ink = Color(red: 0.2, green: 0.1, blue: 0.16)

    static func blend(_ a: Color, _ b: Color, _ t: CGFloat) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(a).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(b).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t)
    }

    static func heart(_ w: CGFloat, _ h: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.9))
        p.addCurve(to: CGPoint(x: w * 0.07, y: h * 0.4), control1: CGPoint(x: w * 0.28, y: h * 0.76), control2: CGPoint(x: w * 0.07, y: h * 0.6))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.24), control1: CGPoint(x: w * 0.07, y: h * 0.12), control2: CGPoint(x: w * 0.4, y: h * 0.08))
        p.addCurve(to: CGPoint(x: w * 0.93, y: h * 0.4), control1: CGPoint(x: w * 0.6, y: h * 0.08), control2: CGPoint(x: w * 0.93, y: h * 0.12))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.9), control1: CGPoint(x: w * 0.93, y: h * 0.6), control2: CGPoint(x: w * 0.72, y: h * 0.76))
        p.closeSubpath()
        return p
    }

    static func dot(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(c))
    }

    static func draw(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, _ mood: LatidoMood, _ c: Color) {
        // sombra, cuerpo y brillo
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.3, y: h * 0.93, width: w * 0.4, height: h * 0.04)), with: .color(.black.opacity(0.15)))
        let g = Gradient(colors: [blend(c, .white, 0.3), c, blend(c, .black, 0.15)])
        ctx.fill(heart(w, h), with: .linearGradient(g, startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.26, width: w * 0.12, height: h * 0.09)), with: .color(.white.opacity(0.55)))

        let eyeY = h * 0.5, lx = w * 0.38, rx = w * 0.62, er = w * 0.045
        let st = StrokeStyle(lineWidth: w * 0.03, lineCap: .round)
        let cheek = Color(red: 1, green: 0.75, blue: 0.8).opacity(0.7)
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.22, y: h * 0.56, width: w * 0.11, height: h * 0.05)), with: .color(cheek))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.67, y: h * 0.56, width: w * 0.11, height: h * 0.05)), with: .color(cheek))

        func arc(_ x: CGFloat, up: Bool) {
            var p = Path()
            p.move(to: CGPoint(x: x - er, y: eyeY))
            p.addQuadCurve(to: CGPoint(x: x + er, y: eyeY), control: CGPoint(x: x, y: up ? eyeY - er * 1.6 : eyeY + er * 1.2))
            ctx.stroke(p, with: .color(ink), style: st)
        }
        func open(_ x: CGFloat) {
            dot(ctx, x, eyeY, er, ink)
            dot(ctx, x - er * 0.3, eyeY - er * 0.35, er * 0.4, .white)
        }
        func tired(_ x: CGFloat) {
            dot(ctx, x, eyeY + er * 0.2, er * 0.85, ink)
            // párpado caído
            ctx.fill(Path(CGRect(x: x - er * 1.2, y: eyeY - er * 1.2, width: er * 2.4, height: er * 1.2)), with: .color(c))
            var p = Path()
            p.move(to: CGPoint(x: x - er * 1.1, y: eyeY))
            p.addLine(to: CGPoint(x: x + er * 1.1, y: eyeY))
            ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: w * 0.022, lineCap: .round))
        }
        func little(_ x: CGFloat) {
            let s = er * 1.25
            var p = Path()
            p.move(to: CGPoint(x: x, y: eyeY + s * 0.8))
            p.addCurve(to: CGPoint(x: x, y: eyeY - s * 0.3), control1: CGPoint(x: x - s * 1.6, y: eyeY - s * 0.2), control2: CGPoint(x: x - s * 0.6, y: eyeY - s * 1.3))
            p.addCurve(to: CGPoint(x: x, y: eyeY + s * 0.8), control1: CGPoint(x: x + s * 0.6, y: eyeY - s * 1.3), control2: CGPoint(x: x + s * 1.6, y: eyeY - s * 0.2))
            ctx.fill(p, with: .color(Color(red: 0.75, green: 0.05, blue: 0.25)))
        }

        switch mood {
        case .love: little(lx); little(rx)
        case .happy: arc(lx, up: true); arc(rx, up: true)
        case .calm: open(lx); open(rx)
        case .tired: tired(lx); tired(rx)
        case .sleepy: arc(lx, up: false); arc(rx, up: false)
        }

        let my = h * 0.62
        var m = Path()
        switch mood {
        case .love, .happy:
            m.move(to: CGPoint(x: w * 0.43, y: my - h * 0.01))
            m.addQuadCurve(to: CGPoint(x: w * 0.57, y: my - h * 0.01), control: CGPoint(x: w * 0.5, y: my + h * 0.07))
        case .calm:
            m.move(to: CGPoint(x: w * 0.45, y: my))
            m.addQuadCurve(to: CGPoint(x: w * 0.55, y: my), control: CGPoint(x: w * 0.5, y: my + h * 0.035))
        case .tired:
            m.move(to: CGPoint(x: w * 0.45, y: my + h * 0.015))
            m.addQuadCurve(to: CGPoint(x: w * 0.55, y: my + h * 0.015), control: CGPoint(x: w * 0.5, y: my - h * 0.02))
        case .sleepy:
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.475, y: my - h * 0.015, width: w * 0.05, height: h * 0.045)), with: .color(ink))
        }
        ctx.stroke(m, with: .color(ink), style: st)

        if mood == .sleepy {
            for (x, y, s) in [(0.78, 0.2, 0.07), (0.88, 0.08, 0.05)] as [(CGFloat, CGFloat, CGFloat)] {
                var z = Path()
                z.move(to: CGPoint(x: w * x, y: h * y)); z.addLine(to: CGPoint(x: w * (x + s), y: h * y))
                z.addLine(to: CGPoint(x: w * x, y: h * (y + s))); z.addLine(to: CGPoint(x: w * (x + s), y: h * (y + s)))
                ctx.stroke(z, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: w * 0.022, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
