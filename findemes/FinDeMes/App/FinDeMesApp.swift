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
                    if p == .active { Music.shared.resume(); game.wake() }
                }
        }
    }
}

struct RootView: View {
    @Environment(Game.self) private var game
    /// sin partida, ticket ni avisos encima
    private var calm: Bool { !game.inRun && game.report == nil && game.event == nil && game.s.seenIntro }

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
            if let f = game.finale {
                FinaleView(level: f).transition(.opacity).zIndex(9)
            }
            if calm && game.finale == nil, let a = game.away {
                AwayView(prize: a).transition(.opacity).zIndex(8)
            } else if calm && game.finale == nil, let k = game.milestoneShow {
                MilestoneView(k: k).id(k).transition(.opacity).zIndex(8)
            } else if calm, let k = game.newKinds.first {
                NewKindView(kind: k).id(k).transition(.opacity).zIndex(8)
            } else if calm, let l = game.levelUp {
                LevelUpView(level: l).transition(.opacity).zIndex(8)
            } else if calm && game.dailyReady {
                DailyView().transition(.opacity).zIndex(8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.inRun)
        .onChange(of: calm) { _, c in if c { game.checkMilestone() } }
        .onChange(of: game.s.cash) { _, _ in if calm { game.checkMilestone() } }
        .onAppear { if calm { game.checkMilestone() } }
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
        s.milestone = 9
        s.seenDoors = Set(Door.allCases.map(\.rawValue))
        s.cash = 2_340
        s.day = 9
        s.billIndex = 6
        s.billDue = 10
        s.tier = 6
        s.paidThisCycle = 1_620
        s.hammer = 2
        s.hammersOwned = [0, 1, 2]
        s.skills = ["golpe": 4, "muneca": 5, "certero": 2, "desayuno": 9, "sofa": 5, "mas": 3, "brazo": 3, "repartidor": 4, "reflejos": 2, "mesa": 1]
        s.legacy = 86
        s.rings = ["cartera": 3, "chancla": 2, "cuero": 4]
        s.coins = ["peseta": 2, "duro": 1, "yen": 1, "reala8": 1, "doblon": 1]
        s.stats.bankruptcies = 2; s.stats.billsPaid = 30; s.stats.broken = 1_830; s.stats.days = 41
        s.skinsOwned = ["cerdo", "vaca"]
        s.tutorial = 9; s.level = 12; s.xp = 410; s.tier = 13; s.pigXP = 260
        s.lastDaily = args.contains("-daily") ? "" : Game.dayKey(Date())
        s.streak = 3
        s.achievements = ["rotas-10", "rotas-100", "rotas-1000", "ganado-1000", "facturas-1", "facturas-12", "dias-7", "dias-30", "doradas-1", "combo-10"]
        s.brokenByKind = ["normal": 1420, "gorda": 260, "ruedas": 90, "cristal": 51, "acorazada": 38, "bomba": 12, "dorada": 9]
        s.stats.bestCombo = 22; s.stats.missions = 14; s.stats.chests = 6
        s.quests = [Quest(kind: .romper, target: 160, progress: 160, reward: 70, xp: 160), Quest(kind: .combo, target: 28, progress: 22, reward: 60, xp: 160), Quest(kind: .ganar, target: 9_000, progress: 3_100, reward: 80, xp: 160)]
        if args.contains("-sobres") { s.pendingChests = [.comun, .rara, .epica] }
        if args.contains("-inspeccion") { s.billIndex = 4; s.billDue = 11 }
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
        if args.contains("-nivel") { game.levelUp = 13 }
        if args.contains("-nueva") { game.newKinds = [.bomba] }
        if args.contains("-intro") { game.s.seenIntro = false }
        if args.contains("-final") { game.finale = 0 }
        if args.contains("-fuera") { game.away = AwayPrize(minutes: 95, cash: 18_400, cows: 2_350) }
        if args.contains("-hito") { game.milestoneShow = 2 }
        if args.contains("-hipoteca") { game.s.mortgage = 3.4e17 }
    }
}
