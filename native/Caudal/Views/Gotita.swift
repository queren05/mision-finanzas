import SwiftUI

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
