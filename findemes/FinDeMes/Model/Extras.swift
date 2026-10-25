import Foundation

// MARK: - El taller de Paco: piezas para el martillo (valen para cualquiera y se pierden con la bancarrota)

enum PartEffect { case damage, loot, speed, spawn, maxPigs, startPigs, crit, critDamage, frenzy, stamina, golden, radius, chest, frenzyMoney, pierce }

struct PartDef: Identifiable {
    let id: String
    let name: String
    let desc: String          // «%» se cambia por el valor por nivel
    let effect: PartEffect
    let per: Double
    let maxLevel: Int
    let base: Double          // en huchas del nivel de ahora
    let growth: Double
    /// el daño y el dinero se multiplican nivel a nivel (×1,12 cada uno)
    var compound: Bool { effect == .damage || effect == .loot }
    func value(_ l: Int) -> Double { compound ? pow(1 + per / 100, Double(l)) : per * Double(l) }
}

// MARK: - Tótems: se compran con puntos de herencia y se quedan para siempre; solo cuentan los que tienes puestos

enum TotemEffect { case pigs, owl, money, damage, speed, luck, stamina, frenzy, dragon, casino, pigXP, discount, startPigs, combo, pet, legacy }

struct TotemDef: Identifiable {
    let id: String
    let name: String
    let effect: TotemEffect
    let base: Double
    static let maxLevel = 10
    func cost(_ l: Int) -> Double { (base * pow(2, Double(l))).rounded() }

    /// lo que hace en el nivel l
    func desc(_ l: Int) -> String {
        let n = Double(max(1, l))
        switch effect {
        case .pigs: return "+\(Int(5 * n)) huchas a la vez y salen un \(Int(10 * n)) % más rápido"
        case .owl: return "+\(Int(2 * n)) % de crítico y críticos +\(Int(25 * n)) %"
        case .money: return "+\(Int(50 * n)) % de dinero"
        case .damage: return "+\(Int(50 * n)) % de daño"
        case .speed: return "+\(Int(8 * n)) % de velocidad"
        case .luck: return "+\(Fmt.dec(0.5 * n, 1)) % de huchas doradas y +\(Fmt.dec(0.3 * n, 1)) % de sobres"
        case .stamina: return "+\(Int(10 * n)) de aguante y \(Int(2 * n)) % de golpes gratis"
        case .frenzy: return "El frenesí dura +\(Int(n)) s y da +\(Int(25 * n)) % de dinero"
        case .dragon: return "+\(Int(60 * n)) % de dinero y de daño, pero −30 % de aguante"
        case .casino: return "Premios del bar +\(Int(3 * n)) %"
        case .pigXP: return "Las huchas suben de nivel un \(Int(12 * n)) % más rápido"
        case .discount: return "El taller un \(Int(5 * n)) % más barato"
        case .startPigs: return "+\(Int(8 * n)) huchas al empezar el día"
        case .combo: return "El frenesí sale con \(Int(2 * n)) de combo menos"
        case .pet: return "Tu mascota hace un \(Int(40 * n)) % más de daño"
        case .legacy: return "+\(Int(15 * n)) % de puntos de herencia"
        }
    }
}

// MARK: - El bar: la tragaperras y el rasca

enum SlotSymbol: Int, CaseIterable {
    case cerdo, moneda, billete, chancla, anillo, corona
    var weight: Double { [32, 26, 20, 12, 7, 3][rawValue] }
    /// cuánto paga sacar tres iguales (por la apuesta)
    var pays: Double { [3, 6, 12, 30, 100, 400][rawValue] }
    var image: String { ["", "c_loot", "billete", "m_chancla", "j_oro", "j_rey"][rawValue] }
    static func random() -> SlotSymbol {
        var r = Double.random(in: 0..<allCases.reduce(0) { $0 + $1.weight })
        for s in allCases { if r < s.weight { return s }; r -= s.weight }
        return .cerdo
    }
}

enum ScratchPrize: Int, CaseIterable {
    case calderilla, fajo, sobreRaro, sobreEpico, herencia, sobreLegendario
    var name: String {
        switch self {
        case .calderilla: "Calderilla"
        case .fajo: "Un fajo de billetes"
        case .sobreRaro: "Sobre raro"
        case .sobreEpico: "Sobre épico"
        case .herencia: "Puntos de herencia"
        case .sobreLegendario: "¡Sobre legendario!"
        }
    }
    /// probabilidad de que el rasca toque esto (lo que falta hasta 1 es no tocar nada)
    var chance: Double { [0.26, 0.14, 0.09, 0.04, 0.025, 0.008][rawValue] }
}

extension Content {
    static let parts: [PartDef] = [
        PartDef(id: "contrapeso", name: "Contrapeso de plomo", desc: "×% de daño", effect: .damage, per: 12, maxLevel: 120, base: 30, growth: 1.22),
        PartDef(id: "iman", name: "Imán de nevera", desc: "×% de dinero", effect: .loot, per: 12, maxLevel: 120, base: 40, growth: 1.22),
        PartDef(id: "mango", name: "Mango de goma", desc: "+%\u{2009}% de velocidad", effect: .speed, per: 5, maxLevel: 40, base: 35, growth: 1.3),
        PartDef(id: "silbato", name: "Silbato", desc: "Salen un %\u{2009}% más rápido", effect: .spawn, per: 8, maxLevel: 50, base: 35, growth: 1.28),
        PartDef(id: "cajon", name: "Cajón de fruta", desc: "+% huchas a la vez", effect: .maxPigs, per: 3, maxLevel: 50, base: 60, growth: 1.3),
        PartDef(id: "muelle", name: "Muelle", desc: "+% huchas al empezar", effect: .startPigs, per: 2, maxLevel: 40, base: 50, growth: 1.3),
        PartDef(id: "pila", name: "Pila de petaca", desc: "+% de aguante", effect: .stamina, per: 3, maxLevel: 60, base: 40, growth: 1.27),
        PartDef(id: "lupa", name: "Lupa", desc: "+%\u{2009}% de crítico", effect: .crit, per: 1, maxLevel: 30, base: 100, growth: 1.38),
        PartDef(id: "punta", name: "Punta de acero", desc: "Críticos +%\u{2009}%", effect: .critDamage, per: 15, maxLevel: 40, base: 120, growth: 1.33),
        PartDef(id: "cinta", name: "Cinta americana", desc: "El frenesí dura +% s", effect: .frenzy, per: 0.4, maxLevel: 25, base: 250, growth: 1.42),
        PartDef(id: "guantes", name: "Guantes de boxeo", desc: "+%\u{2009}% de alcance", effect: .radius, per: 4, maxLevel: 30, base: 80, growth: 1.32),
        PartDef(id: "brujula", name: "Brújula", desc: "+%\u{2009}% de sobres", effect: .chest, per: 0.15, maxLevel: 20, base: 200, growth: 1.42),
        PartDef(id: "temporizador", name: "Reloj de cocina", desc: "En frenesí, +%\u{2009}% de dinero", effect: .frenzyMoney, per: 10, maxLevel: 30, base: 180, growth: 1.38),
        PartDef(id: "lija", name: "Lija gorda", desc: "Atraviesa el +%\u{2009}% de las corazas", effect: .pierce, per: 3, maxLevel: 20, base: 150, growth: 1.4),
        PartDef(id: "herradura", name: "Herradura", desc: "+%\u{2009}% de huchas doradas", effect: .golden, per: 0.2, maxLevel: 20, base: 300, growth: 1.45),
    ]

    static let totems: [TotemDef] = [
        TotemDef(id: "cerdo", name: "Tótem del cerdo", effect: .pigs, base: 20),
        TotemDef(id: "urraca", name: "Tótem de la urraca", effect: .money, base: 25),
        TotemDef(id: "toro", name: "Tótem del toro", effect: .damage, base: 25),
        TotemDef(id: "buho", name: "Tótem del búho", effect: .owl, base: 30),
        TotemDef(id: "liebre", name: "Tótem de la liebre", effect: .speed, base: 25),
        TotemDef(id: "oso", name: "Tótem del oso", effect: .stamina, base: 20),
        TotemDef(id: "gato", name: "Tótem del gato negro", effect: .luck, base: 35),
        TotemDef(id: "tortuga", name: "Tótem de la tortuga", effect: .frenzy, base: 40),
        TotemDef(id: "elefante", name: "Tótem del elefante", effect: .pigXP, base: 50),
        TotemDef(id: "zorro", name: "Tótem del zorro", effect: .discount, base: 30),
        TotemDef(id: "rana", name: "Tótem de la rana", effect: .casino, base: 15),
        TotemDef(id: "pulpo", name: "Tótem del pulpo", effect: .startPigs, base: 30),
        TotemDef(id: "lobo", name: "Tótem del lobo", effect: .combo, base: 40),
        TotemDef(id: "ballena", name: "Tótem de la ballena", effect: .pet, base: 60),
        TotemDef(id: "fenix", name: "Tótem del fénix", effect: .legacy, base: 80),
        TotemDef(id: "dragon", name: "Tótem del dragón", effect: .dragon, base: 150),
    ]
}

// MARK: - Mascotas: van por la mesa rompiendo huchas solas

enum PetSkill { case none, chests, money, richest, triple, octopus, fire, fast }

struct PetDef: Identifiable {
    let id: String
    let name: String
    let line: String
    let skill: PetSkill
    let every: Double        // segundos entre golpes
    let damage: Double       // parte del daño de tu martillo
    let speed: Double        // puntos por segundo
    let base: Double         // puntos de herencia
    static let maxLevel = 10
    func cost(_ l: Int) -> Double { (base * pow(1.8, Double(l))).rounded() }
    func dmg(_ l: Int) -> Double { damage * (1 + 0.6 * Double(max(0, l - 1))) }
    func interval(_ l: Int) -> Double { every * pow(0.94, Double(max(0, l - 1))) }
    var skillText: String {
        switch skill {
        case .none: "Saca críticos como tú"
        case .chests: "Encuentra sobres al romper"
        case .money: "Las que rompe valen el doble"
        case .richest: "Siempre va a por la hucha más valiosa"
        case .triple: "Picotea tres huchas a la vez"
        case .octopus: "Golpea a todas las que tiene alrededor"
        case .fire: "Escupe fuego: explota al golpear"
        case .fast: "Rapidísimo, aunque pega flojo"
        }
    }
}

extension Content {
    static let pets: [PetDef] = [
        PetDef(id: "gato", name: "Michi", line: "Tira las huchas de la mesa por gusto.", skill: .none, every: 1.6, damage: 0.8, speed: 230, base: 25),
        PetDef(id: "perro", name: "Toby", line: "Buen chico. Muerde huchas.", skill: .chests, every: 1.3, damage: 0.55, speed: 300, base: 40),
        PetDef(id: "hamster", name: "Bolita", line: "No para quieto.", skill: .fast, every: 0.55, damage: 0.28, speed: 380, base: 50),
        PetDef(id: "loro", name: "Paquito", line: "Repite «¡dinero, dinero!».", skill: .money, every: 2.0, damage: 0.6, speed: 260, base: 60),
        PetDef(id: "mapache", name: "Ladronzuelo", line: "Tiene buen ojo para lo caro.", skill: .richest, every: 1.8, damage: 0.9, speed: 250, base: 80),
        PetDef(id: "cuervo", name: "Edgar", line: "Le gustan las cosas brillantes.", skill: .triple, every: 1.7, damage: 0.6, speed: 320, base: 140),
        PetDef(id: "pulpo", name: "Ocho", line: "Ocho brazos, ocho huchas.", skill: .octopus, every: 2.4, damage: 0.7, speed: 180, base: 220),
        PetDef(id: "dragon", name: "Chispa", line: "Un dragón pequeñito. De momento.", skill: .fire, every: 3.0, damage: 1.5, speed: 210, base: 400),
    ]
}
