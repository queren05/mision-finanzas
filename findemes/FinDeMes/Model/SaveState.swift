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
    var bestCombo = 0.0
    var frenzies = 0.0
    var missions = 0.0
    var spins = 0.0
    var jackpots = 0.0
    var scratches = 0.0

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func v(_ k: CodingKeys) -> Double { (try? c.decodeIfPresent(Double.self, forKey: k)) ?? 0 }
        broken = v(.broken); swings = v(.swings); earned = v(.earned); billsPaid = v(.billsPaid); days = v(.days)
        bankruptcies = v(.bankruptcies); kings = v(.kings); golden = v(.golden); chests = v(.chests); bestDay = v(.bestDay); crits = v(.crits)
        bestCombo = v(.bestCombo); frenzies = v(.frenzies); missions = v(.missions)
        spins = v(.spins); jackpots = v(.jackpots); scratches = v(.scratches)
    }
}

struct Settings: Codable, Hashable {
    var sound = true
    var haptics = true
    var music = true
    /// cómo se ve el árbol de mejoras (TreeStyle)
    var treeStyle = 0
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        sound = (try? c.decodeIfPresent(Bool.self, forKey: .sound)) ?? true
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? true
        music = (try? c.decodeIfPresent(Bool.self, forKey: .music)) ?? true
        treeStyle = (try? c.decodeIfPresent(Int.self, forKey: .treeStyle)) ?? 0
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
    var skin = "vaca"
    var skinsOwned: Set<String> = ["vaca", "cerdo"]
    // lo que engancha: nivel, encargos, logros, y premio diario
    var level = 1
    var xp = 0.0
    var quests: [Quest] = []
    var achievements: Set<String> = []
    var streak = 0
    var lastDaily = ""
    var tutorial = 0
    /// el nivel de las huchas es `tier`; esto es lo que lleva hacia el siguiente
    var pigXP = 0.0
    /// el nivel más alto que han llegado a tener las huchas (el huchario lo recuerda siempre)
    var bestTier = 0
    /// piezas del taller (se pierden con la bancarrota, como los martillos)
    var parts: [String: Int] = [:]
    /// tótems comprados (nivel) y los que están puestos
    var totems: [String: Int] = [:]
    var totemsOn: [String] = []
    /// último día en que se rascó el rasca gratis
    var lastScratch = ""
    /// mascotas compradas (nivel) y la que te acompaña
    var pets: [String: Int] = [:]
    var pet = ""
    var brokenByKind: [String: Double] = [:]
    /// árbol familiar (para siempre) y facturas pagadas en esta partida
    var family: [String: Int] = [:]
    var billsThisRun = 0
    /// nivel de las vacas cuando llegó la factura de ahora (lo que vale)
    var billTier = 0
    var scratchesToday = 0
    var autoBuy = true
    /// apuestas de la carrera de cerdos
    var races = 0.0
    /// puertas de la cocina que ya has abierto (las nuevas llevan el sello «NUEVO»)
    var seenDoors: Set<String> = []
    /// lo abonado a la hipoteca de ahora (se queda aunque te arruines) y las ya pagadas
    var mortgage = 0.0
    var richLevel = 0
    /// cuándo se jugó por última vez y lo que se ganó el último día (para lo ganado sin jugar)
    var lastPlayed = 0.0
    var lastDayEarned = 0.0
    /// el último número grande celebrado (1 = mil, 2 = millón, 3 = mil millones…)
    var milestone = 0

    init() {}

    enum CodingKeys: String, CodingKey {
        case cash, day, year, billIndex, billDue, paidThisCycle, tier, hammer, hammersOwned, skills, pendingChests, awaitingTaxChoice
        case legacy, rings, coins, stats, settings, seenIntro, skin, skinsOwned
        case level, xp, quests, achievements, streak, lastDaily, tutorial, pigXP, brokenByKind, bestTier, parts, totems, totemsOn, lastScratch, pets, pet
        case family, billsThisRun, scratchesToday, autoBuy, races, billTier
        case seenDoors, mortgage, richLevel, lastPlayed, lastDayEarned, milestone
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
        level = max(1, v(.level, 1)); xp = v(.xp, 0.0); quests = v(.quests, [Quest]()); achievements = v(.achievements, Set<String>())
        streak = v(.streak, 0); lastDaily = v(.lastDaily, "")
        // las partidas de antes ya saben jugar
        tutorial = v(.tutorial, seenIntro ? 9 : 0)
        pigXP = v(.pigXP, 0.0); brokenByKind = v(.brokenByKind, [String: Double]())
        bestTier = max(v(.bestTier, 0), tier)
        parts = v(.parts, [String: Int]()); totems = v(.totems, [String: Int]())
        totemsOn = v(.totemsOn, [String]()).filter { totems[$0] != nil }; lastScratch = v(.lastScratch, "")
        pets = v(.pets, [String: Int]()); pet = v(.pet, "")
        family = v(.family, [String: Int]()); billsThisRun = v(.billsThisRun, billIndex + year * Content.bills.count)
        scratchesToday = v(.scratchesToday, 0); autoBuy = v(.autoBuy, true); races = v(.races, 0.0)
        billTier = v(.billTier, tier)
        // quien ya jugaba conoce todas las puertas y sus números grandes
        seenDoors = v(.seenDoors, seenIntro ? Set(["mejoras", "martillo", "album", "bar", "herencia"]) : Set<String>())
        mortgage = v(.mortgage, 0.0); richLevel = v(.richLevel, 0)
        lastPlayed = v(.lastPlayed, 0.0); lastDayEarned = v(.lastDayEarned, 0.0)
        milestone = v(.milestone, max(0, Int(floor(log10(max(1, max(cash, stats.bestDay))) / 3))))
        // el llavero de la hucha de casa ya no existe: se devuelven sus puntos
        if let l = rings["llavero"] {
            for i in 0..<l { legacy += (35 * pow(1.7, Double(i))).rounded() }
            rings["llavero"] = nil
        }
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
