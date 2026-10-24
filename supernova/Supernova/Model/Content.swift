import Foundation

// MARK: - Definiciones del contenido
// Todo el contenido (generadores, mejoras, logros…) son datos: para añadir más basta con
// ampliar las listas o las fórmulas que los generan, sin tocar la lógica del juego.

struct GeneratorDef: Identifiable {
    let id: Int
    let name: String
    let icon: String       // SF Symbol
    let color: String
    let baseCost: Double
    let baseProd: Double
}

/// condiciones para que una mejora aparezca en la tienda
struct Unlock {
    var owned: [(gen: Int, count: Int)] = []
    var earned: Double = 0
}

enum UpgradeEffect {
    case generator(Int, Double)                     // multiplica la producción de un generador
    case tap(Double)                                // multiplica el toque
    case tapShare(Double)                           // cada toque suma este tanto por uno de la energía por segundo
    case global(Double)                             // multiplica toda la producción
    case synergy(from: Int, to: Int, per: Double)   // cada unidad de «from» mejora «to»
    case dark(Double)                               // multiplica la materia oscura
}

struct UpgradeDef: Identifiable {
    let id: String
    let name: String
    let desc: String
    let icon: String
    let color: String
    let cost: Double
    let unlock: Unlock
    let effect: UpgradeEffect
}

enum ResearchEffect { case production, tap, cost, stars, dark, offline, crit }

struct ResearchDef: Identifiable {
    let id: String
    let name: String
    let icon: String
    let baseCost: Double
    let growth: Double
    let maxLevel: Int
    let per: Double
    let effect: ResearchEffect

    func cost(_ level: Int) -> Double { baseCost * pow(growth, Double(level)) }
    func describe(_ level: Int) -> String {
        switch effect {
        case .production: return "+\(Fmt.num(per * 100 * Double(level))) % de producción"
        case .tap: return "+\(Fmt.num(per * 100 * Double(level))) % por toque"
        case .cost: return "Generadores \(Fmt.dec((1 - pow(1 - per, Double(level))) * 100, 0)) % más baratos"
        case .stars: return "+\(Fmt.num(per * 100 * Double(level))) % de estrellas fugaces"
        case .dark: return "+\(Fmt.num(per * 100 * Double(level))) % de materia oscura"
        case .offline: return "+\(Fmt.num(per * Double(level))) h de producción sin conexión"
        case .crit: return "+\(Fmt.num(per * 100 * Double(level))) % de golpe crítico"
        }
    }
}

enum TalentEffect {
    case tap(Double), production(Double), offlineHours(Double), offlineRate(Double), autoTap(Double)
    case startEnergy(Double), starRate(Double), starPower(Double), cost(Double), dark(Double)
    case achievements(Double), missions(Double), autoBuy, keepResearch, singularityBonus(Double), crit(Double)
}

struct TalentDef: Identifiable {
    let id: String
    let name: String
    let desc: String
    let icon: String
    let cost: Double
    let requires: [String]
    let col: Int
    let row: Int
    let effect: TalentEffect
}

enum AchievementKind {
    case earned, taps, owned(Int), totalOwned, rps, bigBangs, stars, upgrades, missions, singularities, combo, universes
}

struct AchievementDef: Identifiable {
    let id: String
    let name: String
    let desc: String
    let icon: String
    let kind: AchievementKind
    let goal: Double
}

enum MissionKind: String, Codable, CaseIterable {
    case taps, buy, earn, stars, upgrades, dark
}

// MARK: - El contenido

enum Content {
    static let growth = 1.15
    /// al llegar a estas cantidades, el generador produce el doble
    static let milestones = [10, 25, 50, 100, 150, 200, 250, 300, 350, 400, 500, 600, 700, 800, 900, 1000]

    static let generators: [GeneratorDef] = {
        let list: [(String, String, String, Double, Double)] = [
            ("Polvo estelar", "sparkle", "#9fe8ff", 15, 0.1),
            ("Asteroide", "circle.hexagongrid.fill", "#c9b8a6", 100, 1),
            ("Cometa", "flame.fill", "#7fd3ff", 1_100, 8),
            ("Luna", "moon.fill", "#e6e6f0", 12_000, 47),
            ("Planeta", "globe.americas.fill", "#5fd38a", 130_000, 260),
            ("Gigante gaseoso", "circle.circle.fill", "#f0a35e", 1.4e6, 1_400),
            ("Estrella", "sun.max.fill", "#ffd36e", 2e7, 7_800),
            ("Púlsar", "dot.radiowaves.left.and.right", "#6ee7ff", 3.3e8, 44_000),
            ("Nebulosa", "cloud.fill", "#ff8ad8", 5.1e9, 260_000),
            ("Cúmulo estelar", "sparkles", "#fff0a8", 7.5e10, 1.6e6),
            ("Galaxia", "hurricane", "#b48cff", 1e12, 1e7),
            ("Agujero negro", "smallcircle.filled.circle", "#ff9a5e", 1.4e13, 6.5e7),
            ("Cuásar", "bolt.fill", "#5ef0ff", 1.7e14, 4.3e8),
            ("Supercúmulo", "atom", "#ff6fa8", 2.1e15, 2.9e9),
            ("Filamento cósmico", "point.3.connected.trianglepath.dotted", "#9dffcf", 2.6e16, 2.1e10),
            ("Multiverso", "infinity", "#ffe27a", 3.1e17, 1.5e11),
        ]
        return list.enumerated().map { i, g in GeneratorDef(id: i, name: g.0, icon: g.1, color: g.2, baseCost: g.3, baseProd: g.4) }
    }()

    // MARK: mejoras (se generan con fórmulas)

    private static let tierNames = ["Calibrado", "Reforzado", "Turbo", "Cuántico", "Dorado", "Plasma", "Antimateria",
                                    "Hiperespacial", "Divino", "Eterno", "Primordial", "Absoluto", "Omega"]
    private static let tierOwned = [1, 5, 25, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500]
    private static let tierCost: [Double] = [10, 50, 500, 5e4, 5e6, 5e8, 5e10, 5e12, 5e14, 5e16, 5e18, 5e20, 5e22]

    static let upgrades: [UpgradeDef] = {
        var u: [UpgradeDef] = []
        // por generador: cada nivel duplica su producción
        for g in generators {
            for t in tierNames.indices {
                u.append(UpgradeDef(id: "g\(g.id)-\(t)", name: "\(g.name) \(tierNames[t].lowercased())",
                                    desc: "\(g.name): producción ×2", icon: g.icon, color: g.color,
                                    cost: g.baseCost * tierCost[t], unlock: Unlock(owned: [(g.id, tierOwned[t])]),
                                    effect: .generator(g.id, 2)))
            }
        }
        // toque
        let tapCosts: [Double] = [100, 500, 1e4, 1e5, 1e7, 1e9, 1e11, 1e13, 1e15, 1e18, 1e21, 1e24, 1e27, 1e30, 1e33, 1e36, 1e40]
        for (k, c) in tapCosts.enumerated() {
            let early = k < 3
            u.append(UpgradeDef(id: "tap\(k)", name: "Pulso \(roman(k + 1))",
                                desc: early ? "Cada toque vale el doble" : "Cada toque suma un 1 % de tu energía por segundo",
                                icon: "hand.tap.fill", color: "#5ed9ff", cost: c, unlock: Unlock(earned: c / 4),
                                effect: early ? .tap(2) : .tapShare(0.01)))
        }
        // producción global
        for k in 0..<30 {
            let c = 1e5 * pow(1e3, Double(k))
            u.append(UpgradeDef(id: "glob\(k)", name: "Expansión \(roman(k + 1))", desc: "Toda la producción +25 %",
                                icon: "arrow.up.right.circle.fill", color: "#ffd36e", cost: c,
                                unlock: Unlock(earned: c / 10), effect: .global(1.25)))
        }
        // sinergias: un generador mejora al de dos niveles más arriba
        for g in generators.dropLast(2) {
            let to = generators[g.id + 2]
            u.append(UpgradeDef(id: "syn\(g.id)", name: "\(g.name) + \(to.name)",
                                desc: "\(to.name) +1 % por cada \(g.name.lowercased()) que tengas",
                                icon: "link", color: "#ff8ad8", cost: to.baseCost * 200,
                                unlock: Unlock(owned: [(g.id, 15), (to.id, 15)]),
                                effect: .synergy(from: g.id, to: to.id, per: 0.01)))
        }
        // materia oscura
        for k in 0..<12 {
            let c = 1e4 * pow(1e4, Double(k))
            u.append(UpgradeDef(id: "dark\(k)", name: "Condensador \(roman(k + 1))", desc: "Materia oscura ×1,5",
                                icon: "aqi.medium", color: "#b17bff", cost: c, unlock: Unlock(earned: c / 5),
                                effect: .dark(1.5)))
        }
        return u
    }()

    /// para calcular rápido: mejoras de cada generador y sinergias que recibe
    static let upgradesByGen: [[UpgradeDef]] = generators.map { g in
        upgrades.filter { if case .generator(let i, _) = $0.effect { return i == g.id }; return false }
    }
    static let synergiesTo: [[UpgradeDef]] = generators.map { g in
        upgrades.filter { if case .synergy(_, let to, _) = $0.effect { return to == g.id }; return false }
    }

    // MARK: investigación (se paga con materia oscura)

    static let research: [ResearchDef] = [
        ResearchDef(id: "fotones", name: "Fotones", icon: "light.max", baseCost: 10, growth: 1.5, maxLevel: 300, per: 0.10, effect: .production),
        ResearchDef(id: "pulso", name: "Pulso", icon: "hand.tap.fill", baseCost: 5, growth: 1.45, maxLevel: 300, per: 0.25, effect: .tap),
        ResearchDef(id: "eficiencia", name: "Eficiencia", icon: "gearshape.2.fill", baseCost: 25, growth: 1.7, maxLevel: 40, per: 0.02, effect: .cost),
        ResearchDef(id: "radar", name: "Radar", icon: "scope", baseCost: 40, growth: 1.8, maxLevel: 25, per: 0.08, effect: .stars),
        ResearchDef(id: "condensador", name: "Condensador", icon: "aqi.medium", baseCost: 15, growth: 1.55, maxLevel: 300, per: 0.10, effect: .dark),
        ResearchDef(id: "cronos", name: "Cronos", icon: "hourglass", baseCost: 60, growth: 2, maxLevel: 22, per: 1, effect: .offline),
        ResearchDef(id: "precision", name: "Precisión", icon: "target", baseCost: 50, growth: 1.9, maxLevel: 20, per: 0.01, effect: .crit),
    ]

    // MARK: constelaciones (árbol de talentos, se paga con singularidades)

    static let talents: [TalentDef] = [
        TalentDef(id: "chispa", name: "Chispa", desc: "Toque ×3", icon: "hand.tap.fill", cost: 1, requires: [], col: 2, row: 0, effect: .tap(3)),
        TalentDef(id: "memoria", name: "Memoria estelar", desc: "+4 h de producción sin conexión", icon: "moon.zzz.fill", cost: 3, requires: ["chispa"], col: 1, row: 1, effect: .offlineHours(4)),
        TalentDef(id: "fusion", name: "Fusión", desc: "Producción ×2", icon: "flame.fill", cost: 5, requires: ["chispa"], col: 2, row: 1, effect: .production(2)),
        TalentDef(id: "halcon", name: "Ojo de halcón", desc: "Estrellas fugaces un 50 % más a menudo", icon: "eye.fill", cost: 5, requires: ["chispa"], col: 3, row: 1, effect: .starRate(1.5)),
        TalentDef(id: "paciencia", name: "Paciencia cósmica", desc: "Sin conexión produces un 25 % más", icon: "tortoise.fill", cost: 10, requires: ["memoria"], col: 0, row: 2, effect: .offlineRate(0.25)),
        TalentDef(id: "herencia", name: "Herencia", desc: "Empiezas cada Big Bang con 1 M de energía", icon: "gift.fill", cost: 15, requires: ["memoria"], col: 1, row: 2, effect: .startEnergy(1e6)),
        TalentDef(id: "hiperfusion", name: "Hiperfusión", desc: "Producción ×3", icon: "flame.circle.fill", cost: 25, requires: ["fusion"], col: 2, row: 2, effect: .production(3)),
        TalentDef(id: "fortuna", name: "Fortuna", desc: "Estrellas fugaces el doble de potentes", icon: "star.circle.fill", cost: 20, requires: ["halcon"], col: 3, row: 2, effect: .starPower(2)),
        TalentDef(id: "critico", name: "Golpe crítico", desc: "+5 % de probabilidad de crítico", icon: "burst.fill", cost: 15, requires: ["halcon"], col: 4, row: 2, effect: .crit(0.05)),
        TalentDef(id: "autopulso", name: "Autopulso", desc: "5 toques automáticos por segundo", icon: "repeat.circle.fill", cost: 40, requires: ["paciencia"], col: 0, row: 3, effect: .autoTap(5)),
        TalentDef(id: "ingenieria", name: "Ingeniería", desc: "Generadores un 10 % más baratos", icon: "wrench.and.screwdriver.fill", cost: 50, requires: ["herencia"], col: 1, row: 3, effect: .cost(0.9)),
        TalentDef(id: "exotica", name: "Materia exótica", desc: "Materia oscura ×2", icon: "aqi.high", cost: 60, requires: ["hiperfusion"], col: 2, row: 3, effect: .dark(2)),
        TalentDef(id: "coleccionista", name: "Coleccionista", desc: "Cada logro da un 2 % en vez de un 1 %", icon: "trophy.fill", cost: 80, requires: ["fortuna"], col: 3, row: 3, effect: .achievements(2)),
        TalentDef(id: "frenesi", name: "Frenesí", desc: "Toque ×5", icon: "hands.and.sparkles.fill", cost: 60, requires: ["critico"], col: 4, row: 3, effect: .tap(5)),
        TalentDef(id: "autoconstructor", name: "Autoconstructor", desc: "Compra solo el generador más barato", icon: "cpu.fill", cost: 150, requires: ["autopulso"], col: 0, row: 4, effect: .autoBuy),
        TalentDef(id: "archivo", name: "Archivo eterno", desc: "La investigación no se pierde en el Big Bang", icon: "books.vertical.fill", cost: 200, requires: ["ingenieria"], col: 1, row: 4, effect: .keepResearch),
        TalentDef(id: "supernova", name: "Supernova", desc: "Producción ×5", icon: "sun.max.trianglebadge.exclamationmark.fill", cost: 300, requires: ["exotica"], col: 2, row: 4, effect: .production(5)),
        TalentDef(id: "colmena", name: "Mente colmena", desc: "Misiones con el triple de premio", icon: "brain.head.profile", cost: 250, requires: ["coleccionista"], col: 3, row: 4, effect: .missions(3)),
        TalentDef(id: "eternidad", name: "Eternidad", desc: "+20 h de producción sin conexión", icon: "infinity.circle.fill", cost: 300, requires: ["frenesi"], col: 4, row: 4, effect: .offlineHours(20)),
        TalentDef(id: "horizonte", name: "Horizonte de sucesos", desc: "Cada singularidad da un 4 % en vez de un 2 %", icon: "circle.dashed.inset.filled", cost: 1_000, requires: ["archivo"], col: 1, row: 5, effect: .singularityBonus(0.02)),
        TalentDef(id: "hipernova", name: "Hipernova", desc: "Producción ×10", icon: "sparkles", cost: 2_000, requires: ["supernova"], col: 2, row: 5, effect: .production(10)),
        TalentDef(id: "riqueza", name: "Riqueza cósmica", desc: "Empiezas cada Big Bang con 1 T de energía", icon: "crown.fill", cost: 1_500, requires: ["colmena"], col: 3, row: 5, effect: .startEnergy(1e12)),
        TalentDef(id: "crunch", name: "Big Crunch", desc: "Producción ×25", icon: "atom", cost: 10_000, requires: ["hipernova", "horizonte", "riqueza"], col: 2, row: 6, effect: .production(25)),
    ]

    // MARK: logros (se generan)

    static let achievements: [AchievementDef] = {
        var a: [AchievementDef] = []
        for k in 0..<22 {
            let g = 100 * pow(1000, Double(k))
            a.append(AchievementDef(id: "earn\(k)", name: "Energía \(roman(k + 1))", desc: "Genera \(Fmt.num(g)) de energía en total", icon: "bolt.fill", kind: .earned, goal: g))
        }
        for (k, g) in [100.0, 1_000, 5_000, 25_000, 100_000, 500_000, 1e6].enumerated() {
            a.append(AchievementDef(id: "taps\(k)", name: "Dedos de acero \(roman(k + 1))", desc: "Toca \(Fmt.num(g)) veces", icon: "hand.tap.fill", kind: .taps, goal: g))
        }
        for g in generators {
            for (k, n) in [1.0, 50, 100, 200, 300, 500].enumerated() {
                a.append(AchievementDef(id: "own\(g.id)-\(k)", name: "\(g.name) \(roman(k + 1))", desc: "Ten \(Int(n)) × \(g.name.lowercased())", icon: g.icon, kind: .owned(g.id), goal: n))
            }
        }
        for (k, n) in [100.0, 500, 1_000, 2_500, 5_000, 10_000].enumerated() {
            a.append(AchievementDef(id: "total\(k)", name: "Constructor \(roman(k + 1))", desc: "Ten \(Fmt.num(n)) generadores a la vez", icon: "square.stack.3d.up.fill", kind: .totalOwned, goal: n))
        }
        for k in 0..<16 {
            let g = 10 * pow(1000, Double(k))
            a.append(AchievementDef(id: "rps\(k)", name: "Flujo \(roman(k + 1))", desc: "Produce \(Fmt.num(g)) por segundo", icon: "speedometer", kind: .rps, goal: g))
        }
        for (k, n) in [1.0, 5, 10, 25, 50, 100, 250].enumerated() {
            a.append(AchievementDef(id: "bb\(k)", name: "Big Bang \(roman(k + 1))", desc: "Haz \(Int(n)) Big Bang", icon: "burst.fill", kind: .bigBangs, goal: n))
        }
        for (k, n) in [1.0, 10, 50, 150, 500, 1_000].enumerated() {
            a.append(AchievementDef(id: "star\(k)", name: "Cazaestrellas \(roman(k + 1))", desc: "Atrapa \(Int(n)) estrellas fugaces", icon: "star.fill", kind: .stars, goal: n))
        }
        for (k, n) in [10.0, 50, 100, 200, 300, 400].enumerated() {
            a.append(AchievementDef(id: "upg\(k)", name: "Inventor \(roman(k + 1))", desc: "Compra \(Int(n)) mejoras", icon: "wand.and.stars", kind: .upgrades, goal: n))
        }
        for (k, n) in [5.0, 25, 100, 250, 1_000].enumerated() {
            a.append(AchievementDef(id: "mis\(k)", name: "Explorador \(roman(k + 1))", desc: "Completa \(Int(n)) misiones", icon: "flag.checkered", kind: .missions, goal: n))
        }
        for (k, n) in [1.0, 100, 10_000, 1e6, 1e8].enumerated() {
            a.append(AchievementDef(id: "sing\(k)", name: "Singular \(roman(k + 1))", desc: "Consigue \(Fmt.num(n)) singularidades", icon: "circle.dashed.inset.filled", kind: .singularities, goal: n))
        }
        for (k, n) in [1.5, 1.8, 2.0].enumerated() {
            a.append(AchievementDef(id: "combo\(k)", name: "Combo \(roman(k + 1))", desc: "Llega a un combo ×\(Fmt.dec(n, 1))", icon: "flame", kind: .combo, goal: n))
        }
        for (k, n) in [1.0, 3, 10].enumerated() {
            a.append(AchievementDef(id: "uni\(k)", name: "Multiverso \(roman(k + 1))", desc: "Crea \(Int(n)) universos", icon: "infinity", kind: .universes, goal: n))
        }
        return a
    }()

    static func roman(_ n: Int) -> String {
        let map: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, s = ""
        for (v, r) in map { while n >= v { s += r; n -= v } }
        return s
    }
}
