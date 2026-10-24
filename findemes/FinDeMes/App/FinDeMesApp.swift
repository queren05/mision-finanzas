import SwiftUI

@main
struct FinDeMesApp: App {
    @Environment(\.scenePhase) private var phase
    @State private var game = Game.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(game)
                .onAppear { Demo.apply(game); Music.shared.resume() }
                .onChange(of: phase) { _, p in
                    if p == .background { game.save(); Sound.shared.stop(); Music.shared.pause() }
                    if p == .active { Music.shared.resume() }
                }
        }
    }
}

struct RootView: View {
    @Environment(Game.self) private var game

    var body: some View {
        ZStack {
            if game.inRun {
                DeskView(game: game)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
            } else {
                HomeView()
                    .transition(.opacity)
            }
            if let r = game.report {
                ReportView(report: r).transition(.opacity).zIndex(5)
            }
            if let e = game.event {
                EventView(event: e).transition(.opacity).zIndex(6)
            }
            if !game.s.seenIntro && !game.inRun {
                IntroView().transition(.opacity).zIndex(7)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.inRun)
        .preferredColorScheme(.light)
        .statusBarHidden(game.inRun)
    }
}

/// partidas de ejemplo para las capturas del simulador
enum Demo {
    @MainActor
    static func apply(_ game: Game) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-demo") else { return }
        var s = SaveState()
        s.seenIntro = true
        s.cash = 2_340
        s.day = 9
        s.billIndex = 6
        s.billDue = 10
        s.tier = 6
        s.paidThisCycle = 1_620
        s.hammer = 2
        s.hammersOwned = [0, 1, 2]
        s.skills = ["golpe": 4, "muneca": 5, "certero": 2, "desayuno": 6, "gimnasio": 3, "sofa": 5, "mas": 3, "brazo": 3, "repartidor": 4, "reflejos": 2, "mesa": 1]
        s.legacy = 86
        s.rings = ["abuela": 3, "oro": 2, "cuero": 4]
        s.coins = ["peseta": 2, "duro": 1, "yen": 1, "reala8": 1, "doblon": 1]
        s.stats.bankruptcies = 2; s.stats.billsPaid = 30; s.stats.broken = 1_830; s.stats.days = 41
        s.skinsOwned = ["cerdo", "gamba", "dibujo", "chaqueta", "vaca"]
        if let i = args.firstIndex(of: "-skin"), i + 1 < args.count { s.skin = args[i + 1] }
        game.s = s
        game.recompute()
        if args.contains("-play") { game.startDay() }
        if args.contains("-report") {
            var r = DayReport(day: 8)
            r.earned = 1_284; r.broken = 37; r.swings = 52; r.crits = 6; r.golden = 1; r.best = 212
            r.chests = [.rara, .comun]
            game.s.pendingChests = r.chests
            game.report = r
        }
        if args.contains("-collector") { game.event = .collector(legacy: 32) }
    }
}
