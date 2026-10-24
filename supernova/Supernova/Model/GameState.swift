import Foundation

struct Buff: Codable, Hashable {
    enum Kind: String, Codable { case frenzy, tapFrenzy }
    var kind: Kind
    var mult: Double
    var until: Date
}

struct Mission: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var kind: MissionKind
    var goal: Double
    /// valor del contador cuando empezó
    var start: Double
}

struct Stats: Codable, Hashable {
    var earnedRun = 0.0        // desde el último Big Bang
    var earnedLayer = 0.0      // desde el último Multiverso (da las singularidades)
    var earnedAll = 0.0
    var taps = 0.0
    var bought = 0.0
    var stars = 0.0
    var upgrades = 0.0
    var missions = 0.0
    var bigBangs = 0.0
    var universes = 0.0
    var darkAll = 0.0
    var singAll = 0.0
    var bestCombo = 1.0
    var playSeconds = 0.0
    var bestRps = 0.0

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func v(_ k: CodingKeys) -> Double { (try? c.decodeIfPresent(Double.self, forKey: k)) ?? 0 }
        earnedRun = v(.earnedRun); earnedLayer = v(.earnedLayer); earnedAll = v(.earnedAll); taps = v(.taps)
        bought = v(.bought); stars = v(.stars); upgrades = v(.upgrades); missions = v(.missions)
        bigBangs = v(.bigBangs); universes = v(.universes); darkAll = v(.darkAll); singAll = v(.singAll)
        bestCombo = max(1, v(.bestCombo)); playSeconds = v(.playSeconds); bestRps = v(.bestRps)
    }
}

struct GameSettings: Codable, Hashable {
    var sound = true
    var haptics = true
    var scientific = false
    /// 1, 10, 100 o 0 (= el máximo posible)
    var buyAmount = 1

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        sound = (try? c.decodeIfPresent(Bool.self, forKey: .sound)) ?? true
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? true
        scientific = (try? c.decodeIfPresent(Bool.self, forKey: .scientific)) ?? false
        buyAmount = (try? c.decodeIfPresent(Int.self, forKey: .buyAmount)) ?? 1
    }
}

/// Todo lo que se guarda de la partida
struct GameState: Codable {
    var energy = 0.0
    var dark = 0.0                 // materia oscura
    var singularities = 0.0        // sin gastar
    var singEver = 0.0             // ganadas en esta capa: dan el bonus aunque se gasten
    var universes = 0.0            // segunda capa de prestigio
    var owned: [Int] = Array(repeating: 0, count: Content.generators.count)
    var upgrades: Set<String> = []
    var research: [String: Int] = [:]
    var talents: Set<String> = []
    var achievements: Set<String> = []
    var missions: [Mission] = []
    var buffs: [Buff] = []
    var stats = Stats()
    var settings = GameSettings()
    var lastSeen = Date()
    var created = Date()

    init() {}

    enum CodingKeys: String, CodingKey {
        case energy, dark, singularities, singEver, universes, owned, upgrades, research, talents, achievements, missions, buffs, stats, settings, lastSeen, created
    }
    // tolera partidas guardadas por versiones anteriores (campos nuevos o que faltan)
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let x = GameState()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? def }
        energy = v(.energy, x.energy); dark = v(.dark, x.dark); singularities = v(.singularities, x.singularities)
        singEver = v(.singEver, x.singEver); universes = v(.universes, x.universes)
        owned = v(.owned, x.owned); upgrades = v(.upgrades, x.upgrades); research = v(.research, x.research)
        talents = v(.talents, x.talents); achievements = v(.achievements, x.achievements); missions = v(.missions, x.missions)
        buffs = v(.buffs, x.buffs); stats = v(.stats, x.stats); settings = v(.settings, x.settings)
        lastSeen = v(.lastSeen, x.lastSeen); created = v(.created, x.created)
        // si hay generadores nuevos, se añaden a cero
        if owned.count < Content.generators.count { owned += Array(repeating: 0, count: Content.generators.count - owned.count) }
        if !energy.isFinite { energy = 0 }
    }
}
