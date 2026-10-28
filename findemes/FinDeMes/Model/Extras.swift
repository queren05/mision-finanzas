import Foundation

// MARK: - Mejoras del martillo (valen para cualquiera y se pierden con la bancarrota)

enum PartEffect { case damage, loot, speed }

struct PartDef: Identifiable {
    let id: String
    let name: String
    let desc: String          // «%» se cambia por el valor por nivel
    let effect: PartEffect
    let per: Double
    let maxLevel: Int
    let base: Double          // en huchas del nivel de ahora
    let growth: Double
    func value(_ l: Int) -> Double { per * Double(l) }
}

// MARK: - La feria: la tragaperras (tiradas gratis, sin apostar) y el rasca

enum SlotSymbol: Int, CaseIterable {
    case cerdo, moneda, billete, chancla, anillo, corona
    var weight: Double { [32, 26, 20, 12, 7, 3][rawValue] }
    /// cuánto paga sacar tres iguales (en premios pequeños: 5 {huchas} cada uno)
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
        case .herencia: "Un maletín de billetes"
        case .sobreLegendario: "¡Sobre legendario!"
        }
    }
    /// probabilidad de que el rasca toque esto (lo que falta hasta 1 es no tocar nada)
    var chance: Double { [0.3, 0.18, 0.12, 0.06, 0.04, 0.015][rawValue] }
}

extension Content {
    /// las tres mejoras del martillo (valen para cualquiera y se pierden con la bancarrota)
    static let parts: [PartDef] = [
        PartDef(id: "contrapeso", name: "Contrapeso de plomo", desc: "+%\u{2009}% de daño", effect: .damage, per: 10, maxLevel: 100, base: 30, growth: 1.42),
        PartDef(id: "iman", name: "Imán de nevera", desc: "+%\u{2009}% de dinero", effect: .loot, per: 10, maxLevel: 100, base: 40, growth: 1.42),
        PartDef(id: "mango", name: "Mango de goma", desc: "+%\u{2009}% de velocidad", effect: .speed, per: 5, maxLevel: 40, base: 35, growth: 1.3),
    ]
}
