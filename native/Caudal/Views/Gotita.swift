import SwiftUI

/// cómo está Gotita
enum Mood { case happy, wow, sleepy, sad, love, wink }

/// complementos que se le pueden poner a Gotita
let mascotHats: [(id: String, name: String)] = [
    ("nada", "Nada"), ("gorro", "Gorro"), ("gafas", "Gafas"), ("lazo", "Lazo"),
    ("corona", "Corona"), ("auriculares", "Cascos"), ("flor", "Flor"),
]

/// Gotita: la mascota de Caudal, una gota de agua con cara. Flota un rato al aparecer y luego solo parpadea.
struct Gotita: View {
    var mood: Mood = .happy
    var size: CGFloat = 96
    var hat: String? = nil
    var color: Color? = nil
    @State private var up = false
    @State private var blink = false

    var body: some View {
        let L = Look.shared
        let tint = color ?? L.mascotColor
        let wear = hat ?? L.s.mascotHat
        let closed = blink
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.3, y: h * 0.95, width: w * 0.4, height: h * 0.04)), with: .color(.black.opacity(0.12)))
            GotitaDraw.drop(ctx, w, h, tint)
            GotitaDraw.face(ctx, w, h, mood, closed)
            GotitaDraw.accessory(ctx, w, h, wear)
        }
        .frame(width: size, height: size)
        .offset(y: up ? -size * 0.03 : size * 0.02)
        .task(id: L.motion) {
            guard L.motion else { up = false; return }
            withAnimation(.easeInOut(duration: 1.3).repeatCount(5, autoreverses: true)) { up = true }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_600_000_000)
                blink = true
                try? await Task.sleep(nanoseconds: 130_000_000)
                blink = false
            }
        }
        .accessibilityLabel("Gotita")
    }
}

private enum GotitaDraw {
    static let ink = Color(red: 0.165, green: 0.125, blue: 0.19)

    static func drop(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
        p.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.62), control1: CGPoint(x: w * 0.62, y: h * 0.22), control2: CGPoint(x: w * 0.88, y: h * 0.42))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.93), control1: CGPoint(x: w * 0.88, y: h * 0.82), control2: CGPoint(x: w * 0.71, y: h * 0.93))
        p.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.62), control1: CGPoint(x: w * 0.29, y: h * 0.93), control2: CGPoint(x: w * 0.12, y: h * 0.82))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.04), control1: CGPoint(x: w * 0.12, y: h * 0.42), control2: CGPoint(x: w * 0.38, y: h * 0.22))
        p.closeSubpath()
        let g = Gradient(colors: [c.mix(.white, 0.35), c, c.mix(.black, 0.12)])
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
            ctx.fill(p, with: .color(Color(hex: "#ff8fa3")))
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.27, y: h * 0.27, width: w * 0.46, height: h * 0.08), cornerRadius: w * 0.04), with: .color(Color(hex: "#ffd1da")))
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
            let c = Color(hex: "#ff6b9a")
            var l = Path()
            l.move(to: CGPoint(x: w * 0.5, y: h * 0.2)); l.addLine(to: CGPoint(x: w * 0.36, y: h * 0.12)); l.addLine(to: CGPoint(x: w * 0.37, y: h * 0.3)); l.closeSubpath()
            var r = Path()
            r.move(to: CGPoint(x: w * 0.5, y: h * 0.2)); r.addLine(to: CGPoint(x: w * 0.64, y: h * 0.12)); r.addLine(to: CGPoint(x: w * 0.63, y: h * 0.3)); r.closeSubpath()
            ctx.fill(l, with: .color(c)); ctx.fill(r, with: .color(c))
            circle(ctx, w * 0.5, h * 0.2, w * 0.035, Color(hex: "#ff3d7f"))
        case "corona":
            var p = Path()
            p.move(to: CGPoint(x: w * 0.34, y: h * 0.24)); p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.1)); p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.17))
            p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.05)); p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.17)); p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.1))
            p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.24)); p.closeSubpath()
            ctx.fill(p, with: .color(Color(hex: "#ffc94d")))
            circle(ctx, w * 0.5, h * 0.17, w * 0.022, Color(hex: "#ff6b6b"))
        case "auriculares":
            let c = Color(hex: "#8fc8ff")
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
                circle(ctx, cx + CGFloat(cos(a)) * w * 0.05, cy + CGFloat(sin(a)) * w * 0.05, w * 0.045, Color(hex: "#ffb3c7"))
            }
            circle(ctx, cx, cy, w * 0.03, Color(hex: "#ffd166"))
        default: break
        }
    }
}

// MARK: - Depósito de agua

/// El depósito: el nivel es lo que te queda del mes (0…1). Se llena al aparecer, salpica al tocarlo y se calma.
struct WaterTank<Content: View>: View {
    var level: Double
    var color: Color
    var mood: Mood? = .happy
    @ViewBuilder var content: () -> Content

    @State private var start = Date()
    @State private var from = 0.0
    @State private var pokeAt = Date()
    @State private var active = true

    var body: some View {
        let L = Look.shared
        let target = max(0, min(1, level))
        TimelineView(.animation(paused: !active || !L.motion)) { tl in
            let now = L.motion ? tl.date : start.addingTimeInterval(20)
            let t = now.timeIntervalSince(start)
            // llenado con rebote
            let k: Double = min(1, t / 2.2)
            let ease: Double = (1 - exp(-4 * k) * cos(6 * k)) / (1 - exp(-4.0) * cos(6.0))
            let fill: Double = from + (target - from) * ease
            let sincePoke = now.timeIntervalSince(pokeAt)
            let energy = max(0.15, 1 - sincePoke / 4.5)
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                let surface = h * (1 - CGFloat(fill))
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, size in
                        let amp: Double = Double(size.height) * (0.035 * energy + 0.008)
                        func wave(_ phase: Double, _ k: Double, _ a: Double) -> Path {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: size.height))
                            var x: CGFloat = 0
                            while x <= size.width + 6 {
                                let y = surface + CGFloat(a * sin(Double(x / size.width) * 2 * Double.pi * k + phase))
                                p.addLine(to: CGPoint(x: x, y: y))
                                x += 6
                            }
                            p.addLine(to: CGPoint(x: size.width, y: size.height))
                            p.closeSubpath()
                            return p
                        }
                        ctx.fill(wave(-t * 2.4 + 1.2, 1.3, amp * 0.8), with: .color(color.mix(.white, 0.25).opacity(0.45)))
                        ctx.fill(wave(t * 3, 1, amp), with: .linearGradient(Gradient(colors: [color.mix(.white, 0.15), color, color.mix(.black, 0.18)]),
                                                                             startPoint: CGPoint(x: 0, y: surface), endPoint: CGPoint(x: 0, y: size.height)))
                        if fill > 0.08 {
                            for (i, b) in [(0.18, 0.7), (0.42, 0.45), (0.77, 0.62), (0.6, 0.85)].enumerated() {
                                let rise = (t * 0.25 + Double(i) * 0.27).truncatingRemainder(dividingBy: 1)
                                let y = size.height - (size.height - surface) * CGFloat((b.1 + rise).truncatingRemainder(dividingBy: 1))
                                let r: CGFloat = i % 2 == 0 ? 3 : 5
                                if y > surface + 6 {
                                    ctx.fill(Path(ellipseIn: CGRect(x: size.width * CGFloat(b.0) - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.35)))
                                }
                            }
                        }
                    }
                    if let mood {
                        let gs: CGFloat = 54
                        let bob = CGFloat(sin(t * 2.6) * 6 * energy)
                        Gotita(mood: mood, size: gs)
                            .position(x: w - 18 - gs / 2, y: min(h - gs / 2, max(gs / 2, surface - gs * 0.72 + bob + gs / 2)))
                    }
                    content()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.soft()
            pokeAt = Date(); active = true
        }
        .onChange(of: level) { _, _ in from = 0; start = Date(); pokeAt = Date(); active = true }
        .task(id: pokeAt) {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            active = false
        }
    }
}

// MARK: - Disponible hoy

struct Allowance {
    var left: Double
    var perDay: Double
    var daysLeft: Int
    var upcoming: Double
    var fromBudget: Bool
    /// presupuesto o ingresos del mes (0: aún no se puede calcular)
    var base: Double
}

extension Store {
    /// presupuesto del mes − lo gastado en las categorías con presupuesto − sus cargos pendientes, repartido entre los días que quedan.
    /// Sin presupuestos: lo ingresado − todo lo gastado − los cargos pendientes.
    func allowance(today: String = Day.today) -> Allowance {
        let r = periodRange(periodStart(for: today))
        let budgeted = state.categories.filter { $0.kind == .expense && $0.budget > 0 }
        let budget = budgeted.reduce(0) { $0 + $1.budget }
        let ids = Set(budgeted.map(\.id))
        let counts: (String?) -> Bool = { budget <= 0 || ids.contains($0 ?? "") }
        let spent = txs(in: r).filter { $0.type == .expense && !$0.excluded && counts($0.categoryId) }.reduce(0) { $0 + $1.amount }
        let toEnd = Day.cal.dateComponents([.day], from: Day.date(today), to: Day.date(r.upperBound)).day ?? 0
        let up = upcoming(days: toEnd).filter { $0.date <= r.upperBound && $0.r.type == "expense" && counts($0.r.categoryId) }.reduce(0) { $0 + $1.r.amount }
        let base = budget > 0 ? budget : earned(in: r)
        let left = base - spent - up
        let days = max(1, toEnd + 1)
        return Allowance(left: left, perDay: left > 0 ? left / Double(days) : 0, daysLeft: days, upcoming: up, fromBudget: budget > 0, base: base)
    }

    /// la cara de Gotita según cómo va el mes
    var mood: Mood {
        let a = allowance()
        if a.base <= 0 { return .sleepy }
        if a.left < 0 { return .sad }
        if a.left / a.base > 0.5 { return .love }
        return .happy
    }
}
