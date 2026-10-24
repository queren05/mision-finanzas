import SwiftUI

/// Un día rompiendo huchas
struct DeskView: View {
    @Environment(Game.self) private var game
    @State private var desk: Desk
    @State private var stamina: Double
    @State private var cash: Double
    @State private var cooldownTick = 0
    @State private var askQuit = false

    init(game: Game) {
        let d = Desk(stats: game.stats, tier: game.s.tier, hammer: Content.hammers[game.s.hammer], day: game.s.day)
        _desk = State(initialValue: d)
        _stamina = State(initialValue: d.stamina)
        _cash = State(initialValue: game.s.cash)
    }

    var body: some View {
        ZStack(alignment: .top) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    MainActor.assumeIsolated {
                        desk.frame(tl.date, size: size)
                        desk.draw(&ctx)
                    }
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(coordinateSpace: .global).onEnded { v in desk.tap(v.location) }
            )

            VStack(spacing: 0) {
                hud
                Spacer()
                bottomBar
            }
            .allowsHitTesting(true)
        }
        .onAppear {
            desk.top = 130
            desk.bottom = 120
            desk.onChange = { [weak desk] in
                guard let desk else { return }
                if desk.earnedPending > 0 { game.earn(desk.earnedPending); desk.earnedPending = 0 }
                cash = game.s.cash
                stamina = desk.stamina
            }
            desk.onFinish = { r in
                if desk.earnedPending > 0 { game.earn(desk.earnedPending); desk.earnedPending = 0 }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { game.finishDay(r) }
            }
        }
        .confirmationDialog("¿Terminar el día ya?", isPresented: $askQuit, titleVisibility: .visible) {
            Button("Terminar el día", role: .destructive) { desk.quit() }
            Button("Seguir rompiendo", role: .cancel) {}
        } message: { Text("Te quedan \(Int(stamina)) de aguante sin usar.") }
    }

    private var hud: some View {
        HStack(alignment: .top, spacing: 10) {
            // la cartera
            HStack(spacing: 8) {
                Image(systemName: "eurosign.circle.fill").font(.system(size: 24, weight: .black)).foregroundStyle(Ink.gold)
                    .background(Circle().fill(Ink.ink).padding(1))
                Text(Fmt.money(cash))
                    .font(.chunky(26)).foregroundStyle(Ink.ink)
                    .contentTransition(.numericText(value: cash))
                    .animation(.snappy, value: cash)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .outlined(16, color: Ink.paper)
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text("DÍA \(game.s.day)").font(.chunky(22)).foregroundStyle(Ink.paper)
                    .shadow(color: Ink.ink, radius: 0, x: 2, y: 2)
                let left = game.daysLeft
                Text("Factura: \(Fmt.money(game.billAmount))")
                    .font(.typewriter(13, bold: true)).foregroundStyle(Ink.ink)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(left == 0 ? Ink.red.opacity(0.85) : Ink.paper)
                    .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
                Text(left == 0 ? "¡VENCE HOY!" : "vence en \(left) día\(left == 1 ? "" : "s")")
                    .font(.typewriter(11, bold: true)).foregroundStyle(left == 0 ? Ink.red : Ink.paper)
                    .shadow(color: Ink.ink, radius: 0, x: 1, y: 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("AGUANTE").font(.chunky(16)).foregroundStyle(Ink.ink)
                    Spacer()
                    Text("\(Int(max(0, stamina))) / \(Int(game.stats.stamina))").font(.chunky(16)).foregroundStyle(Ink.ink).monospacedDigit()
                }
                InkBar(value: stamina / max(1, game.stats.stamina), color: stamina / max(1, game.stats.stamina) < 0.25 ? Ink.red : Ink.green, height: 16)
            }
            .padding(10)
            .outlined(16, color: Ink.paper)

            Button { Sound.shared.click(); askQuit = true } label: {
                Image(systemName: "moon.zzz.fill").font(.system(size: 20, weight: .black))
            }
            .buttonStyle(ChunkyButton(color: Ink.paper, size: 18))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}
