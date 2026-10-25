import SwiftUI

// MARK: - Encargos (misiones): siempre hay tres, y al cobrar uno sale otro

enum QuestKind: String, Codable, CaseIterable {
    case romper, ganar, combo, doradas, criticos, diaRico, mejoras, facturas, frenesi

    var text: String {
        switch self {
        case .romper: "Rompe % {huchas}"
        case .ganar: "Gana %"
        case .combo: "Haz un combo de %"
        case .doradas: "Rompe % {huchas} dorad{as}"
        case .criticos: "Da % golpes críticos"
        case .diaRico: "Gana % en un solo día"
        case .mejoras: "Compra % mejoras del corcho"
        case .facturas: "Paga % facturas"
        case .frenesi: "Entra % veces en frenesí"
        }
    }
    var icon: String {
        switch self {
        case .romper: "hammer.fill"
        case .ganar: "eurosign.circle.fill"
        case .combo: "flame.fill"
        case .doradas: "star.circle.fill"
        case .criticos: "burst.fill"
        case .diaRico: "sun.max.fill"
        case .mejoras: "pin.fill"
        case .facturas: "doc.text.fill"
        case .frenesi: "bolt.fill"
        }
    }
    var money: Bool { self == .ganar || self == .diaRico }
}

struct Quest: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var kind: QuestKind
    var target: Double
    var progress: Double = 0
    /// premio: tantas huchas de las de ahora
    var reward: Double
    var xp: Double
    var done: Bool { progress >= target }
}

// MARK: - Logros: cada uno da +3 % de dinero para siempre

enum AchMetric {
    case broken, earned, bills, bankruptcies, days, golden, kings, chests, crits, combo, frenzies, level, coins, skins, hammers, quests, bestDay, pigLevel, spins, jackpots, scratches, totems, parts, pets, family, races
}

struct AchDef: Identifiable {
    let id: String
    let name: String
    let metric: AchMetric
    let target: Double
    var desc: String {
        let n = Fmt.num(target)
        switch metric {
        case .broken: return "Rompe \(n) {huchas}"
        case .earned: return "Gana \(Fmt.money(target)) en total"
        case .bills: return "Paga \(n) facturas"
        case .bankruptcies: return "Declárate en bancarrota \(n) \(target == 1 ? "vez" : "veces")"
        case .days: return "Juega \(n) días"
        case .golden: return "Rompe \(n) {huchas} dorad{as}"
        case .kings: return "Derrota al Rey Cerdito \(n) \(target == 1 ? "vez" : "veces")"
        case .chests: return "Abre \(n) sobres"
        case .crits: return "Da \(n) golpes críticos"
        case .combo: return "Haz un combo de \(n)"
        case .frenzies: return "Entra \(n) \(target == 1 ? "vez" : "veces") en frenesí"
        case .level: return "Llega al nivel \(n)"
        case .coins: return "Junta \(n) monedas del álbum"
        case .skins: return "Ten \(n) personajes"
        case .hammers: return "Ten \(n) martillos a la vez"
        case .quests: return "Cumple \(n) encargos"
        case .bestDay: return "Gana \(Fmt.money(target)) en un día"
        case .pigLevel: return "Sube {las} {huchas} al nivel \(n)"
        case .spins: return "Juega \(n) veces a la tragaperras"
        case .jackpots: return "Saca tres coronas en la tragaperras"
        case .scratches: return "Rasca \(n) rascas"
        case .totems: return "Ten \(n) tótems"
        case .parts: return "Sube \(n) niveles en el taller en una partida"
        case .pets: return "Ten \(n) \(target == 1 ? "mascota" : "mascotas")"
        case .family: return "Sube \(n) niveles del árbol familiar"
        case .races: return "Apuesta en \(n) carreras"
        }
    }
}

enum Meta {
    static let achievements: [AchDef] = {
        func tiers(_ m: AchMetric, _ key: String, _ list: [(Double, String)]) -> [AchDef] {
            list.map { AchDef(id: "\(key)-\(Int($0.0))", name: $0.1, metric: m, target: $0.0) }
        }
        return tiers(.broken, "rotas", [(10, "Primer estropicio"), (100, "Manitas"), (1_000, "Demoledor"), (10_000, "Terror de {las} {huchas}"), (100_000, "Plaga porcina"), (1_000_000, "El fin de {las} {huchas}")])
            + tiers(.earned, "ganado", [(1_000, "Primeros ahorros"), (100_000, "Colchón"), (10_000_000, "Patrimonio"), (1e9, "Fortuna"), (1e12, "Imperio"), (1e15, "Más que el Estado")])
            + tiers(.bestDay, "dia", [(500, "Buen día"), (50_000, "Día redondo"), (5e6, "Día histórico"), (5e9, "El día del siglo")])
            + tiers(.bills, "facturas", [(1, "Al corriente"), (12, "Un año sin deudas"), (50, "Pagador ejemplar"), (200, "Cliente favorito"), (1_000, "Socio de honor")])
            + tiers(.bankruptcies, "quiebra", [(1, "Borrón y cuenta nueva"), (5, "Experto en empezar"), (20, "Fénix"), (100, "Inmortal")])
            + tiers(.days, "dias", [(7, "Una semana"), (30, "Un mes entero"), (100, "Constancia"), (365, "Un año de martillazos"), (1_000, "Leyenda del barrio")])
            + tiers(.golden, "doradas", [(1, "¡Brilla!"), (25, "Buscador de oro"), (250, "Fiebre del oro"), (2_500, "Rey Midas")])
            + tiers(.kings, "rey", [(1, "Regicida"), (10, "Cazarreyes"), (100, "Sin corona")])
            + tiers(.chests, "sobres", [(1, "Correo"), (50, "Coleccionista de sobres"), (500, "Cartero")])
            + tiers(.crits, "criticos", [(100, "Buen ojo"), (1_000, "Puntería"), (10_000, "Francotirador")])
            + tiers(.combo, "combo", [(10, "En racha"), (25, "Imparable"), (50, "Máquina"), (100, "Huracán")])
            + tiers(.frenzies, "frenesi", [(1, "¡Frenesí!"), (25, "Adicto al frenesí"), (250, "Puro nervio")])
            + tiers(.level, "nivel", [(5, "Aprendiz"), (10, "Ahorrador"), (25, "Inversor"), (50, "Magnate"), (100, "Leyenda")])
            + tiers(.coins, "album", [(5, "Numismático"), (12, "Medio álbum"), (24, "Álbum completo")])
            + tiers(.skins, "personajes", [(4, "Disfraces"), (7, "Zoológico"), (10, "Todos")])
            + tiers(.hammers, "martillos", [(3, "Caja de herramientas"), (6, "Ferretería propia"), (8, "Todos los martillos")])
            + tiers(.pigLevel, "huchas", [(10, "Criador"), (25, "Granja de {huchas}"), (45, "{Huchas} robótic{as}"), (60, "Hasta el espacio"), (80, "Más allá"), (100, "{Huchas} millonari{as}"), (150, "Infinito")])
            + tiers(.hammers, "martillos2", [(10, "Coleccionista de martillos"), (12, "La chancla de oro"), (16, "Un yunque con un palo")])
            + tiers(.skins, "personajes2", [(13, "Arca de Noé")])
            + tiers(.spins, "tragaperras", [(1, "Una monedita"), (50, "Cliente del bar"), (500, "Ludópata")])
            + tiers(.jackpots, "bote", [(1, "¡Bote!")])
            + tiers(.scratches, "rascas", [(1, "Rasca, rasca"), (30, "Uña de oro"), (200, "Lotero")])
            + tiers(.totems, "totems", [(1, "Chamán"), (6, "Bosque de tótems"), (12, "Todos los tótems")])
            + tiers(.parts, "taller", [(10, "Bricolaje"), (100, "Manitas de Paco"), (500, "Martillo tuneado")])
            + tiers(.pets, "mascotas", [(1, "Compañía"), (4, "Zoo en casa"), (8, "Arca de las mascotas")])
            + tiers(.coins, "album2", [(36, "Álbum ampliado")])
            + tiers(.hammers, "martillos3", [(19, "Sartenazo"), (22, "El juez ha hablado")])
            + tiers(.pigLevel, "huchas2", [(180, "En las nubes"), (220, "Agujero negro")])
            + tiers(.totems, "totems2", [(16, "Bosque sagrado")])
            + tiers(.family, "familia", [(1, "Buena familia"), (25, "Familia numerosa"), (100, "Clan"), (300, "Dinastía")])
            + tiers(.races, "carreras", [(1, "Al hipódromo"), (25, "Apostador"), (200, "Rey del hipódromo")])
            + tiers(.pets, "mascotas2", [(12, "Todas las mascotas")])
            + tiers(.quests, "encargos", [(5, "Recadero"), (50, "Eficiente"), (250, "Indispensable"), (1_000, "Hombre para todo")])
    }()

    static let titles: [(Int, String)] = [(1, "Becario"), (3, "Mileurista"), (6, "Autónomo"), (10, "Ahorrador"), (15, "Inversor"), (20, "Tiburón"), (30, "Magnate"), (40, "Banquero"), (60, "Lobo de Wall Street"), (80, "Dueño de Hacienda")]
    static func title(_ level: Int) -> String { titles.last { $0.0 <= level }?.1 ?? "Becario" }
    static func xpNeeded(_ level: Int) -> Double { (60 * pow(1.2, Double(level - 1))).rounded() }

    /// premios del calendario de 7 días
    static let daily: [(name: String, chest: Rarity?, pigs: Double, legacy: Double)] = [
        ("Dinero", nil, 40, 0), ("Sobre", .comun, 0, 0), ("Dinero", nil, 120, 0), ("Sobre raro", .rara, 0, 0),
        ("Mucho dinero", nil, 300, 0), ("Sobre épico", .epica, 0, 0), ("¡Sobre legendario!", .legendaria, 0, 0),
    ]
}

/// lo que se desbloquea poco a poco (para no abrumar al principio)
enum Feature {
    case mejoras, martillos, encargos, logros, joyero, monedas, personajes, taller, totems, bar, mascotas, familia

    var hint: String {
        switch self {
        case .mejoras: "Termina tu primer día"
        case .martillos: "Paga tu primera factura"
        case .encargos: "Termina tu primer día"
        case .logros: "Juega 2 días"
        case .joyero, .personajes: "Arruínate una vez"
        case .monedas: "Abre tu primer sobre"
        case .taller: "Paga tu primera factura"
        case .totems: "Arruínate una vez"
        case .bar: "Juega 3 días"
        case .mascotas: "Arruínate una vez"
        case .familia: "Arruínate una vez"
        }
    }
}

@MainActor
extension Game {
    func unlocked(_ f: Feature) -> Bool {
        let st = s.stats
        let veteran = st.bankruptcies > 0 || s.legacy > 0
        switch f {
        case .mejoras, .encargos: return st.days >= 1 || veteran
        case .martillos: return st.billsPaid >= 1 || veteran
        case .logros: return st.days >= 2 || veteran
        case .joyero, .personajes: return veteran
        case .monedas: return st.chests > 0 || !s.coins.isEmpty || veteran
        case .taller: return st.billsPaid >= 1 || veteran
        case .totems: return veteran
        case .bar: return st.days >= 3 || veteran
        case .mascotas, .familia: return veteran
        }
    }

    /// lo que vale una hucha normal ahora mismo (para que los premios crezcan contigo)
    var pigWorth: Double { Content.pigValue(s.tier) * stats.loot }

    // MARK: nivel

    var xpNeeded: Double { Meta.xpNeeded(s.level) }

    func addXP(_ v: Double) {
        guard v > 0 else { return }
        s.xp += (v * (1 + ringValue(.xp) / 100)).rounded()
        var ups = 0
        while s.xp >= Meta.xpNeeded(s.level) {
            s.xp -= Meta.xpNeeded(s.level)
            s.level += 1
            ups += 1
            // cada nivel trae un sobre; los múltiplos de 5 y de 10, mejores
            s.pendingChests.append(s.level % 10 == 0 ? .legendaria : (s.level % 5 == 0 ? .epica : .comun))
        }
        if ups > 0 {
            recompute()
            levelUp = s.level
        }
    }

    // MARK: nivel de las huchas

    var pigNeeded: Double { PigLevel.needed(s.tier) }

    func addPigXP(_ v: Double) {
        s.pigXP += v * (1 + ringValue(.pigXP) / 100 + totemValue(.pigXP) * 0.12) * stats.pigXP
        var fresh: [PigKind] = []
        while s.pigXP >= PigLevel.needed(s.tier) {
            s.pigXP -= PigLevel.needed(s.tier)
            s.tier += 1
            // solo se celebra la primera vez que sale cada una
            if s.tier > s.bestTier {
                fresh += PigKind.allCases.filter { $0.minTier == s.tier && (!$0.special || $0 == .rey) }
                s.bestTier = s.tier
            }
        }
        if !fresh.isEmpty { newKinds += fresh }
    }

    // MARK: encargos

    func refillQuests() {
        guard unlocked(.encargos) else { return }
        while s.quests.count < 3 {
            let used = Set(s.quests.map(\.kind))
            var pool = QuestKind.allCases.filter { !used.contains($0) }
            if s.level < 3 { pool.removeAll { $0 == .frenesi || $0 == .doradas } }
            if s.billIndex >= Content.bills.count - 1 { pool.removeAll { $0 == .facturas } }
            guard let k = pool.randomElement() else { break }
            s.quests.append(makeQuest(k))
        }
    }

    private func makeQuest(_ k: QuestKind) -> Quest {
        let L = Double(s.level)
        let w = pigWorth
        let target: Double
        switch k {
        case .romper: target = (50 * (1 + L * 0.18)).rounded()
        case .ganar: target = (w * 150 * (1 + L * 0.05)).rounded()
        case .combo: target = min(80, 10 + L * 1.5).rounded()
        case .doradas: target = max(1, (L / 6).rounded())
        case .criticos: target = (12 + L * 2.5).rounded()
        case .diaRico: target = (w * 70).rounded()
        case .mejoras: target = max(2, (2 + L / 8).rounded())
        case .facturas: target = max(1, min(3, (L / 10).rounded()))
        case .frenesi: target = max(1, (L / 12).rounded())
        }
        return Quest(kind: k, target: max(1, target), reward: Double.random(in: 50...90), xp: (40 + L * 10).rounded())
    }

    func progressQuests(_ k: QuestKind, add: Double = 0, best: Double? = nil) {
        for i in s.quests.indices where s.quests[i].kind == k && !s.quests[i].done {
            if let b = best { s.quests[i].progress = max(s.quests[i].progress, b) } else { s.quests[i].progress += add }
            s.quests[i].progress = min(s.quests[i].progress, s.quests[i].target)
        }
    }

    func questReward(_ q: Quest) -> Double { (q.reward * pigWorth * (1 + ringValue(.quests) / 100)).rounded() }

    func claim(_ q: Quest) {
        guard let i = s.quests.firstIndex(where: { $0.id == q.id }), s.quests[i].done else { return }
        let cash = questReward(q)
        s.cash += cash
        s.stats.earned += cash
        s.stats.missions += 1
        s.quests.remove(at: i)
        Sound.shared.fanfare()
        addXP(q.xp)
        refillQuests()
        save()
    }

    // MARK: logros

    func metric(_ m: AchMetric) -> Double {
        let st = s.stats
        switch m {
        case .broken: return st.broken
        case .earned: return st.earned
        case .bills: return st.billsPaid
        case .bankruptcies: return st.bankruptcies
        case .days: return st.days
        case .golden: return st.golden
        case .kings: return st.kings
        case .chests: return st.chests
        case .crits: return st.crits
        case .combo: return st.bestCombo
        case .frenzies: return st.frenzies
        case .level: return Double(s.level)
        case .coins: return Double(Content.coins.filter { (s.coins[$0.id] ?? 0) > 0 }.count)
        case .skins: return Double(s.skinsOwned.subtracting(["dibujo"]).count)
        case .hammers: return Double(s.hammersOwned.count)
        case .quests: return st.missions
        case .bestDay: return st.bestDay
        case .pigLevel: return Double(s.bestTier)
        case .spins: return st.spins
        case .jackpots: return st.jackpots
        case .scratches: return st.scratches
        case .totems: return Double(s.totems.count)
        case .parts: return Double(s.parts.values.reduce(0, +))
        case .pets: return Double(s.pets.count)
        case .family: return Double(s.family.values.reduce(0, +))
        case .races: return s.races
        }
    }

    var achievementsReady: Int {
        Meta.achievements.filter { !s.achievements.contains($0.id) && metric($0.metric) >= $0.target }.count
    }

    func claim(_ a: AchDef) {
        guard !s.achievements.contains(a.id), metric(a.metric) >= a.target else { return }
        s.achievements.insert(a.id)
        Sound.shared.fanfare()
        recompute()
        addXP(30 + Double(s.achievements.count) * 5)
        save()
    }

    // MARK: premio diario

    static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var dailyReady: Bool { s.tutorial >= 9 && s.stats.days >= 1 && s.lastDaily != Game.dayKey(Date()) }

    /// qué casilla del calendario toca hoy (0…6)
    var dailyIndex: Int {
        let yesterday = Game.dayKey(Date().addingTimeInterval(-86_400))
        let keep = s.lastDaily == yesterday
        return keep ? s.streak % 7 : 0
    }

    func claimDaily() {
        guard dailyReady else { return }
        let i = dailyIndex
        let r = Meta.daily[i]
        if r.pigs > 0 { let c = (r.pigs * pigWorth).rounded(); s.cash += c; s.stats.earned += c }
        if let ch = r.chest { s.pendingChests.append(ch) }
        let yesterday = Game.dayKey(Date().addingTimeInterval(-86_400))
        s.streak = s.lastDaily == yesterday ? s.streak + 1 : 1
        s.lastDaily = Game.dayKey(Date())
        Sound.shared.fanfare()
        save()
    }
}
