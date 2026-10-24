import Foundation

struct Stats: Codable, Hashable {
    var broken = 0.0
    var swings = 0.0
    var earned = 0.0
    var billsPaid = 0.0
    var days = 0.0
    var bankruptcies = 0.0
    var kings = 0.0
    var golden = 0.0
    var chests = 0.0
    var bestDay = 0.0
    var crits = 0.0

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func v(_ k: CodingKeys) -> Double { (try? c.decodeIfPresent(Double.self, forKey: k)) ?? 0 }
        broken = v(.broken); swings = v(.swings); earned = v(.earned); billsPaid = v(.billsPaid); days = v(.days)
        bankruptcies = v(.bankruptcies); kings = v(.kings); golden = v(.golden); chests = v(.chests); bestDay = v(.bestDay); crits = v(.crits)
    }
}

struct Settings: Codable, Hashable {
    var sound = true
    var haptics = true
    var music = true
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        sound = (try? c.decodeIfPresent(Bool.self, forKey: .sound)) ?? true
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? true
        music = (try? c.decodeIfPresent(Bool.self, forKey: .music)) ?? true
    }
}

/// Todo lo que se guarda
struct SaveState: Codable {
    // la partida de ahora (se pierde en la bancarrota)
    var cash = 0.0
    var day = 1
    var year = 0                  // años seguidos tras pagar a Hacienda
    var billIndex = 0
    var billDue = 3               // último día para pagar la factura de ahora
    var paidThisCycle = 0.0
    var tier = 0                  // nivel de las huchas: sube con cada factura pagada
    var hammer = 0
    var hammersOwned: Set<Int> = [0]
    var skills: [String: Int] = [:]
    var pendingChests: [Rarity] = []
    var awaitingTaxChoice = false
    // lo que se queda para siempre
    var legacy = 0.0
    var rings: [String: Int] = [:]
    var coins: [String: Int] = [:]
    var stats = Stats()
    var settings = Settings()
    var seenIntro = false
    var skin = "cerdo"
    var skinsOwned: Set<String> = ["cerdo", "gamba", "dibujo"]

    init() {}

    enum CodingKeys: String, CodingKey {
        case cash, day, year, billIndex, billDue, paidThisCycle, tier, hammer, hammersOwned, skills, pendingChests, awaitingTaxChoice
        case legacy, rings, coins, stats, settings, seenIntro, skin, skinsOwned
    }
    // tolera partidas de versiones anteriores
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let x = SaveState()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? def }
        cash = v(.cash, x.cash); day = v(.day, x.day); year = v(.year, x.year); billIndex = v(.billIndex, x.billIndex)
        billDue = v(.billDue, x.billDue); paidThisCycle = v(.paidThisCycle, x.paidThisCycle); tier = v(.tier, x.tier)
        hammer = v(.hammer, x.hammer); hammersOwned = v(.hammersOwned, x.hammersOwned); skills = v(.skills, x.skills)
        pendingChests = v(.pendingChests, x.pendingChests); awaitingTaxChoice = v(.awaitingTaxChoice, x.awaitingTaxChoice)
        legacy = v(.legacy, x.legacy); rings = v(.rings, x.rings); coins = v(.coins, x.coins)
        stats = v(.stats, x.stats); settings = v(.settings, x.settings); seenIntro = v(.seenIntro, x.seenIntro)
        skin = v(.skin, x.skin); skinsOwned = v(.skinsOwned, x.skinsOwned).union(x.skinsOwned)
        if !Content.skins.contains(where: { $0.id == skin }) { skin = x.skin }
        if !cash.isFinite { cash = 0 }
        if hammer >= Content.hammers.count { hammer = 0 }
        billIndex = min(billIndex, Content.bills.count - 1)
    }
}

/// guarda en JSON con escritura atómica y deja una copia de la versión anterior
enum Persistence {
    private static var dir: URL {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private static var main: URL { dir.appendingPathComponent("partida.json") }
    private static var backup: URL { dir.appendingPathComponent("partida-copia.json") }

    static func load() -> SaveState? {
        for url in [main, backup] {
            if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(SaveState.self, from: d) { return s }
        }
        return nil
    }
    static func save(_ s: SaveState) {
        guard let d = try? JSONEncoder().encode(s) else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: main.path) { try? fm.removeItem(at: backup); try? fm.copyItem(at: main, to: backup) }
        try? d.write(to: main, options: .atomic)
    }
    static func erase() {
        try? FileManager.default.removeItem(at: main)
        try? FileManager.default.removeItem(at: backup)
    }
}
