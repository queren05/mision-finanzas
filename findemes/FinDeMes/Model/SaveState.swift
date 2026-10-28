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
    /// último día en que se rascó el rasca gratis
    var lastScratch = ""
    var brokenByKind: [String: Double] = [:]
    /// facturas pagadas en esta partida
    var billsThisRun = 0
    /// nivel de las vacas cuando llegó la factura de ahora (lo que vale)
    var billTier = 0
    var autoBuy = true
    /// tiradas gratis de la tragaperras: el día y cuántas van
    var lastSpin = ""
    var spinsToday = 0
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
        case level, xp, quests, achievements, streak, lastDaily, tutorial, pigXP, brokenByKind, bestTier, parts, lastScratch
        case billsThisRun, autoBuy, billTier, lastSpin, spinsToday
        // de versiones anteriores: solo se leen para devolver los puntos
        case totems, pets, family
        case seenDoors, mortgage, richLevel, lastPlayed, lastDayEarned, milestone
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(cash, forKey: .cash); try c.encode(day, forKey: .day); try c.encode(year, forKey: .year)
        try c.encode(billIndex, forKey: .billIndex); try c.encode(billDue, forKey: .billDue); try c.encode(paidThisCycle, forKey: .paidThisCycle)
        try c.encode(tier, forKey: .tier); try c.encode(hammer, forKey: .hammer); try c.encode(hammersOwned, forKey: .hammersOwned)
        try c.encode(skills, forKey: .skills); try c.encode(pendingChests, forKey: .pendingChests); try c.encode(awaitingTaxChoice, forKey: .awaitingTaxChoice)
        try c.encode(legacy, forKey: .legacy); try c.encode(rings, forKey: .rings); try c.encode(coins, forKey: .coins)
        try c.encode(stats, forKey: .stats); try c.encode(settings, forKey: .settings); try c.encode(seenIntro, forKey: .seenIntro)
        try c.encode(skin, forKey: .skin); try c.encode(skinsOwned, forKey: .skinsOwned)
        try c.encode(level, forKey: .level); try c.encode(xp, forKey: .xp); try c.encode(quests, forKey: .quests)
        try c.encode(achievements, forKey: .achievements); try c.encode(streak, forKey: .streak); try c.encode(lastDaily, forKey: .lastDaily)
        try c.encode(tutorial, forKey: .tutorial); try c.encode(pigXP, forKey: .pigXP); try c.encode(brokenByKind, forKey: .brokenByKind)
        try c.encode(bestTier, forKey: .bestTier); try c.encode(parts, forKey: .parts); try c.encode(lastScratch, forKey: .lastScratch)
        try c.encode(billsThisRun, forKey: .billsThisRun); try c.encode(autoBuy, forKey: .autoBuy); try c.encode(billTier, forKey: .billTier)
        try c.encode(lastSpin, forKey: .lastSpin); try c.encode(spinsToday, forKey: .spinsToday)
        try c.encode(seenDoors, forKey: .seenDoors); try c.encode(mortgage, forKey: .mortgage); try c.encode(richLevel, forKey: .richLevel)
        try c.encode(lastPlayed, forKey: .lastPlayed); try c.encode(lastDayEarned, forKey: .lastDayEarned); try c.encode(milestone, forKey: .milestone)
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
        parts = v(.parts, [String: Int]()).filter { k, _ in Content.parts.contains { $0.id == k } }
        lastScratch = v(.lastScratch, "")
        billsThisRun = v(.billsThisRun, billIndex + year * Content.bills.count)
        autoBuy = v(.autoBuy, true); lastSpin = v(.lastSpin, ""); spinsToday = v(.spinsToday, 0)
        billTier = v(.billTier, tier)
        Migration.v22(&self, totems: v(.totems, [String: Int]()), pets: v(.pets, [String: Int]()), family: v(.family, [String: Int]()))
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

/// la 2.2 quitó la familia, los tótems, las mascotas y las joyas repetidas: lo útil pasa a la herencia y el resto se devuelve en puntos
enum Migration {
    /// (base, crecimiento) de lo que ya no existe: lo gastado se devuelve entero
    private static let oldRings: [String: (Double, Double)] = [
        "pinchos": (30, 1.7), "gargantilla": (50, 1.6), "amatista": (120, 1.6), "perla": (800, 1.5), "obsidiana": (800, 1.5),
        "topacio": (150, 1.6), "ambar": (200, 1.6), "luna": (300, 1.75), "diamantes": (500, 1.5),
        // los que hacían lo mismo que otro (2.2, segunda vuelta)
        "abuela": (5, 1.45), "oro": (5, 1.45), "esmeralda": (40, 1.6), "zafiro": (45, 1.6), "tobillera": (55, 1.6),
        "collar": (60, 1.7), "broche": (70, 1.65), "compromiso": (80, 1.7), "relojoro": (90, 1.8), "diadema": (120, 1.75),
    ]
    private static let oldTotems: [String: Double] = [
        "cerdo": 20, "urraca": 25, "toro": 25, "buho": 30, "liebre": 25, "oso": 20, "gato": 35, "tortuga": 40,
        "elefante": 50, "zorro": 30, "rana": 15, "pulpo": 30, "lobo": 40, "ballena": 60, "fenix": 80, "dragon": 150,
    ]
    private static let oldPets: [String: Double] = [
        "gato": 25, "perro": 40, "hamster": 50, "loro": 60, "mapache": 80, "cuervo": 140, "pulpo": 220, "dragon": 400,
        "pinguino": 600, "abeja": 900, "tortuga": 1_300, "unicornio": 2_000,
    ]
    private static let oldFamily: [String: (Double, Double)] = [
        "f_tio": (10, 1.45), "f_rosi": (8, 1.35), "f_jonatan": (10, 1.4), "f_vane": (12, 1.4), "f_tomas": (15, 1.45),
        "f_gemelos": (10, 1.38), "f_sobrino": (20, 1.45), "f_lotera": (80, 4), "f_mecanico": (60, 1.9), "f_padrino": (300, 6),
        "f_notario": (50, 1.5), "f_oro": (40, 1.5), "f_tatara": (500, 1.6), "f_fiesta": (40, 1.6),
    ]
    /// los de la familia que siguen, ahora como recuerdos del abuelo (mismo precio)
    private static let moved = ["f_abuelo": "cartera", "f_abuela": "chancla", "f_bisabuela": "foto", "f_herrero": "martillo", "f_cunado": "libreta"]

    private static func spent(_ levels: Int, _ cost: (Int) -> Double) -> Double { (0..<max(0, levels)).reduce(0) { $0 + cost($1) } }

    static func v22(_ s: inout SaveState, totems: [String: Int], pets: [String: Int], family: [String: Int]) {
        var back = 0.0
        for (id, (b, g)) in oldRings { if let l = s.rings[id] { back += spent(l) { (b * pow(g, Double($0))).rounded() }; s.rings[id] = nil } }
        for (id, l) in totems { if let b = oldTotems[id] { back += spent(l) { (b * pow(2, Double($0))).rounded() } } }
        for (id, l) in pets { if let b = oldPets[id] { back += spent(l) { (b * pow(1.8, Double($0))).rounded() } } }
        for (id, l) in family {
            if let to = moved[id] { s.rings[to] = max(s.rings[to] ?? 0, l) }
            else if let (b, g) = oldFamily[id] { back += spent(l) { (b * pow(g, Double($0))).rounded() } }
        }
        s.legacy += back
        // los logros que ya no existen se quitan
        let ids = Set(Meta.achievements.map(\.id))
        s.achievements = s.achievements.filter { ids.contains($0) }
    }
}
