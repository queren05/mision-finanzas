import SwiftUI

/// Las ramas del árbol: cada mejora va en la rama de lo que hace y se compran en orden, de la más barata a la más cara.
enum Branch: Int, CaseIterable {
    case dano, dinero, aguante, rebano, frenesi

    var name: String {
        switch self {
        case .dano: "Daño"
        case .dinero: "Dinero"
        case .aguante: "Aguante"
        case .rebano: "{Huchas}"
        case .frenesi: "Frenesí"
        }
    }
    var color: Color {
        switch self {
        case .dano: Ink.red
        case .dinero: Ink.gold
        case .aguante: Ink.blue
        case .rebano: Ink.green
        case .frenesi: Ink.purple
        }
    }
    var icon: String {
        switch self {
        case .dano: "burst.fill"
        case .dinero: "eurosign.circle.fill"
        case .aguante: "heart.fill"
        case .rebano: "square.grid.3x3.fill"
        case .frenesi: "bolt.fill"
        }
    }

    static func of(_ e: SkillEffect) -> Branch {
        switch e {
        case .damageFlat, .damagePct, .crit, .critDamage, .pierce: .dano
        case .lootPct, .golden, .goldenValue, .jackpot, .chest: .dinero
        case .stamina, .killStamina, .drainSave, .glass: .aguante
        case .startPigs, .spawnPct, .maxPigs, .fat, .pigXPMul, .bomb, .king: .rebano
        case .speedPct, .radiusPct, .collateral, .frenzyEarly, .frenzyTime, .frenzyMoney, .comboCap, .comboTime: .frenesi
        }
    }
}

struct SkillTree {
    let root: SkillDef
    let branches: [[SkillDef]]
    /// de quién cuelga cada mejora (la anterior de su rama; la primera, del tronco)
    let parent: [String: String]

    init(_ defs: [SkillDef]) {
        let root = defs[0]
        self.root = root
        var b = Array(repeating: [SkillDef](), count: Branch.allCases.count)
        for k in defs where k.id != root.id { b[Branch.of(k.effect).rawValue].append(k) }
        for i in b.indices {
            let list = b[i]
            let order = list.indices.sorted { x, y in
                list[x].baseCost != list[y].baseCost ? list[x].baseCost < list[y].baseCost : x < y
            }
            b[i] = order.map { list[$0] }
        }
        branches = b
        var p: [String: String] = [:]
        for list in b {
            for (i, k) in list.enumerated() { p[k.id] = i == 0 ? root.id : list[i - 1].id }
        }
        parent = p
    }

    static let main = SkillTree(Content.skills)
}
