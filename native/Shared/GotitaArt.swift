import SwiftUI

/// cómo está Gotita (se manda al widget por su nombre)
enum Mood: String { case happy, wow, sleepy, sad, love, wink }

/// Gotita quieta, para los widgets (en la app está `Gotita`, que flota y parpadea)
struct GotitaStill: View {
    var mood: Mood = .happy
    var size: CGFloat = 48
    var hat = "nada"
    var color = Color(wHex: "#8fc8ff")

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.3, y: h * 0.95, width: w * 0.4, height: h * 0.04)), with: .color(.black.opacity(0.15)))
            GotitaDraw.drop(ctx, w, h, color)
            GotitaDraw.face(ctx, w, h, mood, false)
            GotitaDraw.accessory(ctx, w, h, hat)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum GotitaDraw {

    /// mezcla de dos colores (0 = el primero, 1 = el segundo)
    static func blend(_ a: Color, _ b: Color, _ t: CGFloat) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(a).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(b).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t)
    }
    static let ink = Color(red: 0.165, green: 0.125, blue: 0.19)

    static func drop(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
        p.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.62), control1: CGPoint(x: w * 0.62, y: h * 0.22), control2: CGPoint(x: w * 0.88, y: h * 0.42))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.93), control1: CGPoint(x: w * 0.88, y: h * 0.82), control2: CGPoint(x: w * 0.71, y: h * 0.93))
        p.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.62), control1: CGPoint(x: w * 0.29, y: h * 0.93), control2: CGPoint(x: w * 0.12, y: h * 0.82))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.04), control1: CGPoint(x: w * 0.12, y: h * 0.42), control2: CGPoint(x: w * 0.38, y: h * 0.22))
        p.closeSubpath()
        let g = Gradient(colors: [blend(c, .white, 0.35), c, blend(c, .black, 0.12)])
        ctx.fill(p, with: .linearGradient(g, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.25, y: h * 0.48, width: w * 0.1, height: h * 0.17)), with: .color(.white.opacity(0.55)))
        circle(ctx, w * 0.31, h * 0.7, w * 0.03, .white.opacity(0.55))
    }

    static func circle(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(c))
    }

    static func face(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, _ mood: Mood, _ blink: Bool) {
        let eyeY = h * 0.6, lx = w * 0.4, rx = w * 0.6, er = w * 0.045
        let st = StrokeStyle(lineWidth: w * 0.028, lineCap: .round)
        let cheek = Color(red: 1, green: 0.5, blue: 0.63).opacity(0.45)
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.25, y: h * 0.66, width: w * 0.1, height: h * 0.05)), with: .color(cheek))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.65, y: h * 0.66, width: w * 0.1, height: h * 0.05)), with: .color(cheek))

        func closedEye(_ x: CGFloat, happy: Bool) {
            var p = Path()
            p.move(to: CGPoint(x: x - er, y: eyeY))
            p.addQuadCurve(to: CGPoint(x: x + er, y: eyeY), control: CGPoint(x: x, y: happy ? eyeY - er * 1.6 : eyeY + er * 1.2))
            ctx.stroke(p, with: .color(ink), style: st)
        }
        func openEye(_ x: CGFloat, _ r: CGFloat) {
            circle(ctx, x, eyeY, r, ink)
            circle(ctx, x - r * 0.3, eyeY - r * 0.35, r * 0.38, .white)
        }
        func heart(_ x: CGFloat) {
            let s = er * 1.3
            var p = Path()
            p.move(to: CGPoint(x: x, y: eyeY + s * 0.8))
            p.addCurve(to: CGPoint(x: x, y: eyeY - s * 0.3), control1: CGPoint(x: x - s * 1.6, y: eyeY - s * 0.2), control2: CGPoint(x: x - s * 0.6, y: eyeY - s * 1.3))
            p.addCurve(to: CGPoint(x: x, y: eyeY + s * 0.8), control1: CGPoint(x: x + s * 0.6, y: eyeY - s * 1.3), control2: CGPoint(x: x + s * 1.6, y: eyeY - s * 0.2))
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(red: 1, green: 0.31, blue: 0.48)))
        }

        if mood == .love { heart(lx); heart(rx) }
        else if blink || mood == .sleepy { closedEye(lx, happy: mood != .sleepy); closedEye(rx, happy: mood != .sleepy) }
        else if mood == .wink { closedEye(lx, happy: true); openEye(rx, er) }
        else if mood == .wow { openEye(lx, er * 1.2); openEye(rx, er * 1.2) }
        else { openEye(lx, er); openEye(rx, er) }

        let my = h * 0.72
        var m = Path()
        switch mood {
        case .wow:
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.465, y: my - h * 0.01, width: w * 0.07, height: h * 0.06)), with: .color(ink))
        case .sad:
            m.move(to: CGPoint(x: w * 0.45, y: my + h * 0.02))
            m.addQuadCurve(to: CGPoint(x: w * 0.55, y: my + h * 0.02), control: CGPoint(x: w * 0.5, y: my - h * 0.025))
        case .sleepy:
            m.move(to: CGPoint(x: w * 0.47, y: my))
            m.addLine(to: CGPoint(x: w * 0.53, y: my))
        default:
            m.move(to: CGPoint(x: w * 0.44, y: my - h * 0.005))
            m.addQuadCurve(to: CGPoint(x: w * 0.56, y: my - h * 0.005), control: CGPoint(x: w * 0.5, y: my + h * 0.05))
        }
        ctx.stroke(m, with: .color(ink), style: st)
        if mood == .sleepy {
            var z = Path()
            z.move(to: CGPoint(x: w * 0.76, y: h * 0.3)); z.addLine(to: CGPoint(x: w * 0.84, y: h * 0.3))
            z.addLine(to: CGPoint(x: w * 0.76, y: h * 0.38)); z.addLine(to: CGPoint(x: w * 0.84, y: h * 0.38))
            ctx.stroke(z, with: .color(ink.opacity(0.6)), style: StrokeStyle(lineWidth: w * 0.02, lineCap: .round, lineJoin: .round))
        }
    }

    static func accessory(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, _ hat: String) {
        switch hat {
        case "gorro":
            var p = Path()
            p.move(to: CGPoint(x: w * 0.3, y: h * 0.3))
            p.addCurve(to: CGPoint(x: w * 0.7, y: h * 0.3), control1: CGPoint(x: w * 0.32, y: h * 0.02), control2: CGPoint(x: w * 0.68, y: h * 0.02))
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(wHex: "#ff8fa3")))
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.27, y: h * 0.27, width: w * 0.46, height: h * 0.08), cornerRadius: w * 0.04), with: .color(Color(wHex: "#ffd1da")))
            circle(ctx, w * 0.5, h * 0.06, w * 0.06, .white)
        case "gafas":
            let st = StrokeStyle(lineWidth: w * 0.022)
            for x: CGFloat in [0.4, 0.6] {
                circle(ctx, w * x, h * 0.6, w * 0.07, .white.opacity(0.25))
                ctx.stroke(Path(ellipseIn: CGRect(x: w * x - w * 0.085, y: h * 0.6 - w * 0.085, width: w * 0.17, height: w * 0.17)), with: .color(ink), style: st)
            }
            var b = Path()
            b.move(to: CGPoint(x: w * 0.485, y: h * 0.6)); b.addLine(to: CGPoint(x: w * 0.515, y: h * 0.6))
            ctx.stroke(b, with: .color(ink), style: st)
        case "lazo":
            let c = Color(wHex: "#ff6b9a")
            var l = Path()
            l.move(to: CGPoint(x: w * 0.5, y: h * 0.2)); l.addLine(to: CGPoint(x: w * 0.36, y: h * 0.12)); l.addLine(to: CGPoint(x: w * 0.37, y: h * 0.3)); l.closeSubpath()
            var r = Path()
            r.move(to: CGPoint(x: w * 0.5, y: h * 0.2)); r.addLine(to: CGPoint(x: w * 0.64, y: h * 0.12)); r.addLine(to: CGPoint(x: w * 0.63, y: h * 0.3)); r.closeSubpath()
            ctx.fill(l, with: .color(c)); ctx.fill(r, with: .color(c))
            circle(ctx, w * 0.5, h * 0.2, w * 0.035, Color(wHex: "#ff3d7f"))
        case "corona":
            var p = Path()
            p.move(to: CGPoint(x: w * 0.34, y: h * 0.24)); p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.1)); p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.17))
            p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.05)); p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.17)); p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.1))
            p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.24)); p.closeSubpath()
            ctx.fill(p, with: .color(Color(wHex: "#ffc94d")))
            circle(ctx, w * 0.5, h * 0.17, w * 0.022, Color(wHex: "#ff6b6b"))
        case "auriculares":
            let c = Color(wHex: "#8fc8ff")
            var a = Path()
            for i in 0...28 {
                let ang = (200.0 + 140.0 * Double(i) / 28) * Double.pi / 180
                let pt = CGPoint(x: w * 0.5 + w * 0.32 * CGFloat(cos(ang)), y: h * 0.52 + h * 0.3 * CGFloat(sin(ang)))
                if i == 0 { a.move(to: pt) } else { a.addLine(to: pt) }
            }
            ctx.stroke(a, with: .color(c), style: StrokeStyle(lineWidth: w * 0.04, lineCap: .round))
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.11, y: h * 0.48, width: w * 0.1, height: h * 0.18), cornerRadius: w * 0.05), with: .color(c))
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.79, y: h * 0.48, width: w * 0.1, height: h * 0.18), cornerRadius: w * 0.05), with: .color(c))
        case "flor":
            let cx = w * 0.68, cy = h * 0.36
            for i in 0..<5 {
                let a = Double(i) * 72 * Double.pi / 180
                circle(ctx, cx + CGFloat(cos(a)) * w * 0.05, cy + CGFloat(sin(a)) * w * 0.05, w * 0.045, Color(wHex: "#ffb3c7"))
            }
            circle(ctx, cx, cy, w * 0.03, Color(wHex: "#ffd166"))
        default: break
        }
    }
}
