import SwiftUI

@main
struct SupernovaApp: App {
    @Environment(\.scenePhase) private var phase
    @State private var game = GameEngine.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(game)
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("-demo") { Demo.fill(game) }
                    game.resume()
                }
                .onChange(of: phase) { _, p in
                    switch p {
                    case .active: game.resume()
                    case .background: game.pause()
                    default: break
                    }
                }
        }
    }
}

/// partida avanzada para las capturas del simulador
enum Demo {
    @MainActor
    static func fill(_ game: GameEngine) {
        var s = GameState()
        s.energy = 4.7e13
        s.dark = 3_400
        s.owned = [212, 180, 160, 150, 130, 110, 100, 85, 60, 42, 25, 9, 0, 0, 0, 0]
        s.upgrades = Set(Content.upgrades.prefix(70).map(\.id))
        s.research = ["fotones": 14, "pulso": 9, "condensador": 6, "eficiencia": 3]
        s.singularities = 37
        s.singEver = 64
        s.talents = ["chispa", "memoria", "fusion", "halcon", "hiperfusion"]
        s.stats.earnedAll = 9e14; s.stats.earnedLayer = 8e14; s.stats.earnedRun = 3e14
        s.stats.taps = 18_400; s.stats.bigBangs = 3; s.stats.stars = 41; s.stats.missions = 23; s.stats.upgrades = 160; s.stats.bought = 2_400
        s.stats.singAll = 64; s.stats.bestCombo = 1.9
        s.achievements = Set(Content.achievements.prefix(48).map(\.id))
        s.lastSeen = Date()
        game.s = s
        game.refillMissions()
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-offline") { game.s.lastSeen = Date().addingTimeInterval(-3 * 3600 - 1260) }
    }
}
