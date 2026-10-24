import SwiftUI

// MARK: - Ticket del día y sobres sorpresa

struct ReportView: View {
    @Environment(Game.self) private var game
    let report: DayReport
    @State private var shown = 0
    @State private var prize: ChestPrize? = nil
    @State private var opening = false
    @State private var shakeKey = 0

    private var lines: [(String, String)] {
        var l: [(String, String)] = [
            ("HUCHAS ROTAS", "\(report.broken)"),
            ("MARTILLAZOS", "\(report.swings)"),
            ("CRÍTICOS", "\(report.crits)"),
        ]
        if report.golden > 0 { l.append(("HUCHAS DORADAS", "\(report.golden)")) }
        if report.kings > 0 { l.append(("REY CERDITO", "\(report.kings)")) }
        if !report.coins.isEmpty { l.append(("MONEDAS RARAS", "\(report.coins.count)")) }
        if report.best > 0 { l.append(("MEJOR HUCHA", Fmt.money(report.best))) }
        return l
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    ticket
                    if !game.s.pendingChests.isEmpty || prize != nil { chests }
                    Button {
                        Sound.shared.click()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { game.afterReport() }
                    } label: { Text(game.s.pendingChests.isEmpty ? "A LA COCINA" : "Abrir los sobres luego").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 22))
                    .opacity(shown >= lines.count ? 1 : 0)
                }
                .padding(20).padding(.top, 30)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            // las líneas del ticket salen una a una, como en la caja
            for i in 0..<lines.count {
                try? await Task.sleep(nanoseconds: 140_000_000)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { shown = i + 1 }
                Sound.shared.click()
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            Sound.shared.till()
        }
    }

    private var ticket: some View {
        VStack(spacing: 6) {
            Text("SUPERMERCADO DE HUCHAS").font(.typewriter(13, bold: true))
            Text("TICKET DEL DÍA \(report.day)").font(.typewriter(16, bold: true))
            dashed
            ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                HStack {
                    Text(l.0).font(.typewriter(14))
                    Spacer()
                    Text(l.1).font(.typewriter(14, bold: true))
                }
                .opacity(i < shown ? 1 : 0)
                .offset(y: i < shown ? 0 : 8)
            }
            dashed
            HStack(alignment: .lastTextBaseline) {
                Text("TOTAL").font(.typewriter(18, bold: true))
                Spacer()
                Text(Fmt.money(report.earned)).font(.chunky(32))
            }
            .opacity(shown >= lines.count ? 1 : 0)
            .scaleEffect(shown >= lines.count ? 1 : 0.7)
            dashed
            Text("En la cartera: \(Fmt.money(game.s.cash))").font(.typewriter(13, bold: true))
            let left = game.s.billDue - game.s.day
            Text(left < 0 ? "¡LA FACTURA HA VENCIDO!" : (left == 0 ? "La factura vence HOY" : "La factura vence en \(left) día\(left == 1 ? "" : "s")"))
                .font(.typewriter(13, bold: true)).foregroundStyle(left <= 0 ? Ink.red : Ink.ink)
            // dientes de sierra del papel
            ZigZag().fill(Color(hex: "#fffdf6")).frame(height: 10).offset(y: 14)
        }
        .foregroundStyle(Ink.ink)
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
        .background(Color(hex: "#fffdf6"))
        .rotationEffect(.degrees(-0.8))
    }

    private var dashed: some View {
        Text(String(repeating: "- ", count: 22)).font(.typewriter(12)).foregroundStyle(Ink.soft).lineLimit(1)
    }

    // MARK: sobres

    private var chests: some View {
        VStack(spacing: 12) {
            Text(game.s.pendingChests.isEmpty ? "¡SOBRES ABIERTOS!" : "\(game.s.pendingChests.count) SOBRE\(game.s.pendingChests.count == 1 ? "" : "S") SORPRESA")
                .font(.chunky(24)).foregroundStyle(Ink.paper).shadow(color: Ink.ink, radius: 0, x: 2, y: 2)
            if let p = prize {
                VStack(spacing: 8) {
                    Text(p.rarity.name.uppercased()).font(.chunky(18)).foregroundStyle(p.rarity == .comun ? Ink.ink : p.rarity.color)
                    Text("+" + Fmt.money(p.cash)).font(.chunky(34)).foregroundStyle(Ink.green)
                    if let c = p.coin {
                        HStack(spacing: 10) {
                            CoinArt(def: c, found: true).frame(width: 54, height: 54)
                            VStack(alignment: .leading) {
                                Text(c.name).font(.chunky(18))
                                Text(p.duplicate ? "Repetida: +\(Fmt.num(p.legacy)) puntos de herencia" : "¡Nueva para el álbum!").font(.typewriter(12, bold: true)).foregroundStyle(p.duplicate ? Ink.soft : Ink.purple)
                            }
                        }
                    }
                }
                .foregroundStyle(Ink.ink)
                .padding(16)
                .frame(maxWidth: .infinity)
                .paper(Ink.paper)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
                .id(p.id)
            }
            if let next = game.s.pendingChests.first {
                Button { open() } label: {
                    EnvelopeArt(rarity: next).frame(width: 150, height: 104)
                        .keyframeAnimator(initialValue: 0.0, trigger: shakeKey) { v, a in v.rotationEffect(.degrees(a)) } keyframes: { _ in
                            CubicKeyframe(-9, duration: 0.06); CubicKeyframe(9, duration: 0.07); CubicKeyframe(-6, duration: 0.07); CubicKeyframe(0, duration: 0.08)
                        }
                }
                .buttonStyle(.plain)
                .disabled(opening)
                Text("Toca para abrir").font(.typewriter(13, bold: true)).foregroundStyle(Ink.paper)
            }
        }
    }

    private func open() {
        opening = true
        shakeKey += 1
        Sound.shared.click()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            let p = game.openChest()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { prize = p }
            if let p { p.rarity == .comun ? Sound.shared.till() : Sound.shared.fanfare() }
            opening = false
        }
    }
}

struct ZigZag: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        var x = r.minX
        var up = false
        while x < r.maxX {
            x += 8
            p.addLine(to: CGPoint(x: min(x, r.maxX), y: up ? r.minY : r.maxY))
            up.toggle()
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

struct EnvelopeArt: View {
    let rarity: Rarity
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(x: 4, y: 4, width: size.width - 10, height: size.height - 10)
            let ink = GraphicsContext.Shading.color(Ink.ink)
            ctx.fill(Path(r.offsetBy(dx: 4, dy: 5)), with: ink)
            ctx.fill(Path(r), with: .color(rarity == .comun ? Ink.paper : rarity.color))
            ctx.stroke(Path(r), with: ink, lineWidth: 3)
            var flap = Path()
            flap.move(to: CGPoint(x: r.minX, y: r.minY))
            flap.addLine(to: CGPoint(x: r.midX, y: r.midY + 6))
            flap.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            ctx.stroke(flap, with: ink, lineWidth: 3)
            let seal = CGRect(x: r.midX - 14, y: r.midY - 8, width: 28, height: 28)
            ctx.fill(Path(ellipseIn: seal), with: .color(Ink.red))
            ctx.stroke(Path(ellipseIn: seal), with: ink, lineWidth: 2.5)
            ctx.draw(Text("€").font(.chunky(16)).foregroundColor(Ink.paper), at: CGPoint(x: seal.midX, y: seal.midY))
        }
    }
}

// MARK: - El cobrador, Hacienda y la bancarrota

struct EventView: View {
    @Environment(Game.self) private var game
    let event: GameEvent
    @State private var stamped = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                switch event {
                case .collector(let legacy):
                    Text("¡EL COBRADOR!").font(.chunky(36)).foregroundStyle(Ink.red)
                    Text("No pagaste a \(Content.bills[min(game.s.billIndex, Content.bills.count - 1)].company.lowercased()) a tiempo. Se lo han llevado todo: el dinero, los martillos y las mejoras.")
                        .font(.typewriter(15)).multilineTextAlignment(.center)
                    legacyLine(legacy)
                    Text("Las joyas y las monedas siguen siendo tuyas. Gástate los puntos en el joyero y vuelve más fuerte.")
                        .font(.typewriter(13)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
                    Button { close() } label: { Text("Empezar de nuevo").frame(maxWidth: .infinity) }
                        .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
                case .taxes:
                    Text("¡HACIENDA PAGADA!").font(.chunky(32)).foregroundStyle(Ink.green)
                    Text("Has sobrevivido a un año entero de facturas. Ahora puedes declararte en bancarrota y cobrar tus puntos de herencia, o aguantar otro año con facturas \(Int(Content.yearGrowth)) veces más caras (y huchas más ricas).")
                        .font(.typewriter(14)).multilineTextAlignment(.center)
                    legacyLine(game.legacyGain)
                    Button { game.bankruptcy() } label: { Text("Bancarrota (+\(Fmt.num(game.legacyGain)) puntos)").frame(maxWidth: .infinity) }
                        .buttonStyle(ChunkyButton(color: Ink.gold, size: 19))
                    Button { game.anotherYear() } label: { Text("Otro año más").frame(maxWidth: .infinity) }
                        .buttonStyle(ChunkyButton(color: Ink.paper, size: 19))
                case .bankrupt(let legacy):
                    Text("BANCARROTA").font(.chunky(36)).foregroundStyle(Ink.ink)
                    Text("Vuelves a empezar con la chancla, pero con más experiencia.").font(.typewriter(15)).multilineTextAlignment(.center)
                    legacyLine(legacy)
                    Button { close() } label: { Text("Al joyero y a por otra").frame(maxWidth: .infinity) }
                        .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
                }
            }
            .foregroundStyle(Ink.ink)
            .padding(22)
            .paper(tilt: -0.8)
            .overlay(alignment: .topTrailing) {
                if case .collector = event {
                    Stamp(text: "EMBARGADO").scaleEffect(stamped ? 1.3 : 3).opacity(stamped ? 1 : 0).offset(x: -10, y: -14)
                }
            }
            .padding(22)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.3)) { stamped = true }
            if case .collector = event { Task { try? await Task.sleep(nanoseconds: 350_000_000); Sound.shared.stamp() } }
        }
    }

    private func legacyLine(_ v: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(Ink.purple)
            Text("+\(Fmt.num(v)) puntos de herencia").font(.chunky(22))
        }
        .padding(.vertical, 6).padding(.horizontal, 12)
        .outlined(12, color: Color(hex: "#f2d58a"), shadow: 3)
    }

    private func close() {
        Sound.shared.click()
        withAnimation { game.event = nil }
    }
}

// MARK: - Primera vez

struct IntroView: View {
    @Environment(Game.self) private var game
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                PigIcon(size: 90)
                Text("FIN DE MES").font(.chunky(38)).foregroundStyle(Ink.red)
                Text("Las facturas no se pagan solas. Rompe huchas a martillazos, paga antes de que venzan y no dejes que venga el cobrador.")
                    .font(.typewriter(15)).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Cada martillazo gasta aguante", systemImage: "hammer.fill")
                    Label("Golpea donde haya más huchas juntas", systemImage: "scope")
                    Label("Gasta en el corcho y en la ferretería", systemImage: "pin.fill")
                }
                .font(.typewriter(13, bold: true))
                Button {
                    Sound.shared.click()
                    withAnimation { game.s.seenIntro = true }
                    game.save()
                } label: { Text("¡Vamos!").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 22))
            }
            .foregroundStyle(Ink.ink)
            .padding(22)
            .paper(tilt: 0.6)
            .padding(24)
        }
    }
}
