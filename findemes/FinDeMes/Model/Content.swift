import SwiftUI

// Todo el contenido son datos: para añadir martillos, huchas, facturas, mejoras, joyas o monedas
// basta con ampliar estas listas.

// MARK: - Martillos

enum HammerStyle { case chancla, toy, claw, mallet, mace, jack, sledge, thunder, thunderGold, diamond, cosmic, goldFlop, fire, ice, viking, anvil, plunger, swatter, pan, bat, choco, gavel }

struct HammerDef: Identifiable {
    let id: Int
    let name: String
    let line: String
    let cost: Double
    let damage: Double
    let speed: Double      // golpes por segundo
    let radius: Double     // alcance en puntos
    let style: HammerStyle
    let head: String
    let handle: String
}

// MARK: - Huchas

enum PigKind: String, Codable, CaseIterable {
    case normal, gorda, ruedas, cristal, acorazada, bomba, dorada, rey, gigante, fantasma, madre, diamante, arcoiris, robot, lava, cosmica, hielo, suerte, zombi, millonaria, ninja, payaso, pirata, vampiro, titan, momia, alien, nube, reina, fenix, agujero

    var name: String {
        switch self {
        case .normal: "{Hucha}"
        case .gorda: "{Hucha} gord{a}"
        case .ruedas: "{Hucha} con ruedas"
        case .cristal: "{Hucha} de cristal"
        case .acorazada: "{Hucha} acorazad{a}"
        case .bomba: "{Hucha} bomba"
        case .dorada: "{Hucha} dorad{a}"
        case .rey: "Rey {Hucha}"
        case .gigante: "{Hucha} gigante"
        case .fantasma: "{Hucha} fantasma"
        case .madre: "Mamá {hucha}"
        case .diamante: "{Hucha} de diamante"
        case .arcoiris: "{Hucha} arcoíris"
        case .robot: "{Hucha} robot"
        case .lava: "{Hucha} de lava"
        case .cosmica: "{Hucha} cósmic{a}"
        case .hielo: "{Hucha} de hielo"
        case .suerte: "{Hucha} de la suerte"
        case .zombi: "{Hucha} zombi"
        case .millonaria: "{Hucha} millonari{a}"
        case .ninja: "{Hucha} ninja"
        case .payaso: "{Hucha} payaso"
        case .pirata: "{Hucha} pirata"
        case .vampiro: "{Hucha} vampiro"
        case .titan: "{Hucha} titán"
        case .momia: "{Hucha} momia"
        case .alien: "{Hucha} alienígena"
        case .nube: "{Hucha} nube"
        case .reina: "Reina {Hucha}"
        case .fenix: "{Hucha} fénix"
        case .agujero: "{Hucha} agujero negro"
        }
    }
    var line: String {
        switch self {
        case .normal: "{La} de toda la vida."
        case .gorda: "Aguanta más y suelta más."
        case .ruedas: "Corre que se las pela."
        case .cristal: "Frágil. Te devuelve aguante."
        case .acorazada: "Lleva coraza: cuesta hacerle daño."
        case .bomba: "Al romper{lo}, explota y rompe {las} de al lado."
        case .dorada: "Rar{a}. Puede soltar monedas del álbum."
        case .rey: "El jefe. Muchísima vida y un botín enorme."
        case .gigante: "Del tamaño de una lavadora."
        case .fantasma: "Desaparece y aparece donde quiere."
        case .madre: "Al romper{lo} salen tres {huchas} pequeñ{as}."
        case .diamante: "Durísim{a}. Vale una fortuna."
        case .arcoiris: "Casi siempre suelta un sobre."
        case .robot: "Blindad{a} y rápid{a}. Odia los martillos."
        case .lava: "Explota como diez bombas."
        case .cosmica: "Viene del espacio con un tesoro dentro."
        case .hielo: "Congelad{a} y durísim{a}. Lenta como un lunes."
        case .suerte: "Al romper{lo}, suelta un sobre raro."
        case .zombi: "{Lo} rompes y vuelve a levantarse."
        case .millonaria: "Rarísim{a}. Vale mil {huchas}."
        case .ninja: "No {lo} ves venir. Ni irse."
        case .payaso: "Al romper{lo} salen cinco {huchas} pequeñ{as} de colores."
        case .pirata: "Siempre lleva un sobre escondido."
        case .vampiro: "Al romper{lo} te devuelve 3 de aguante."
        case .titan: "Enorme. Al romper{lo} tiembla toda la mesa."
        case .momia: "Lleva tres mil años ahorrando."
        case .alien: "Al romper{lo} se lleva a tres {huchas} en su nave."
        case .nube: "Al romper{lo} llueven {huchas} dorad{as}."
        case .reina: "La reina de todas. Suelta sobres buenos."
        case .fenix: "Renace de sus cenizas una vez."
        case .agujero: "Al romper{lo} se traga todo lo que tiene cerca."
        }
    }
    var hp: Double {
        switch self {
        case .normal: 1; case .gorda: 3; case .ruedas: 0.8; case .cristal: 0.3; case .acorazada: 4; case .bomba: 1.2; case .dorada: 1.5; case .rey: 40
        case .gigante: 14; case .fantasma: 1.5; case .madre: 5; case .diamante: 12; case .arcoiris: 3
        case .robot: 9; case .lava: 6; case .cosmica: 30
        case .hielo: 25; case .suerte: 6; case .zombi: 10; case .millonaria: 60
        case .ninja: 6; case .payaso: 12; case .pirata: 20; case .vampiro: 18; case .titan: 120
        case .momia: 40; case .alien: 25; case .nube: 15; case .reina: 150; case .fenix: 30; case .agujero: 80
        }
    }
    var value: Double {
        switch self {
        case .normal: 1; case .gorda: 3.5; case .ruedas: 2; case .cristal: 0.8; case .acorazada: 5; case .bomba: 1.5; case .dorada: 12; case .rey: 60
        case .gigante: 22; case .fantasma: 6; case .madre: 6; case .diamante: 45; case .arcoiris: 10
        case .robot: 18; case .lava: 14; case .cosmica: 150
        case .hielo: 40; case .suerte: 30; case .zombi: 35; case .millonaria: 1_000
        case .ninja: 45; case .payaso: 30; case .pirata: 90; case .vampiro: 70; case .titan: 500
        case .momia: 120; case .alien: 160; case .nube: 140; case .reina: 800; case .fenix: 200; case .agujero: 600
        }
    }
    var size: Double {
        switch self {
        case .normal: 62; case .gorda: 84; case .ruedas: 54; case .cristal: 56; case .acorazada: 70; case .bomba: 60; case .dorada: 64; case .rey: 128
        case .gigante: 150; case .fantasma: 64; case .madre: 92; case .diamante: 70; case .arcoiris: 66
        case .robot: 72; case .lava: 74; case .cosmica: 96
        case .hielo: 88; case .suerte: 64; case .zombi: 70; case .millonaria: 110
        case .ninja: 58; case .payaso: 80; case .pirata: 76; case .vampiro: 72; case .titan: 175
        case .momia: 80; case .alien: 68; case .nube: 92; case .reina: 140; case .fenix: 76; case .agujero: 100
        }
    }
    var speed: Double {
        switch self {
        case .normal: 14; case .gorda: 7; case .ruedas: 85; case .cristal: 10; case .acorazada: 9; case .bomba: 18; case .dorada: 26; case .rey: 12
        case .gigante: 5; case .fantasma: 20; case .madre: 8; case .diamante: 16; case .arcoiris: 30
        case .robot: 45; case .lava: 12; case .cosmica: 22
        case .hielo: 4; case .suerte: 28; case .zombi: 10; case .millonaria: 18
        case .ninja: 140; case .payaso: 22; case .pirata: 20; case .vampiro: 34; case .titan: 4
        case .momia: 6; case .alien: 50; case .nube: 60; case .reina: 8; case .fenix: 30; case .agujero: 3
        }
    }
    /// a partir de qué nivel de las huchas aparece (el nivel sube rompiéndolas)
    var minTier: Int {
        switch self {
        case .normal: 0; case .dorada: 0; case .gorda: 2; case .ruedas: 4; case .cristal: 6; case .acorazada: 9; case .bomba: 12
        case .rey: 15; case .gigante: 19; case .fantasma: 23; case .madre: 27; case .diamante: 32; case .arcoiris: 38
        case .robot: 45; case .lava: 52; case .cosmica: 60
        case .hielo: 68; case .suerte: 75; case .zombi: 82; case .millonaria: 100
        case .ninja: 90; case .payaso: 96; case .pirata: 108; case .vampiro: 120; case .titan: 135
        case .momia: 150; case .alien: 165; case .nube: 180; case .reina: 190; case .fenix: 205; case .agujero: 220
        }
    }
    var weight: Double {
        switch self {
        case .normal: 100; case .gorda: 20; case .ruedas: 12; case .cristal: 10; case .acorazada: 10; case .bomba: 8; case .dorada: 0; case .rey: 0
        case .gigante: 3; case .fantasma: 7; case .madre: 5; case .diamante: 2; case .arcoiris: 2
        case .robot: 6; case .lava: 4; case .cosmica: 1.5
        case .hielo: 5; case .suerte: 2; case .zombi: 5; case .millonaria: 0.6
        case .ninja: 6; case .payaso: 4; case .pirata: 3; case .vampiro: 4; case .titan: 1.2
        case .momia: 4; case .alien: 3; case .nube: 3; case .reina: 0.8; case .fenix: 2; case .agujero: 1
        }
    }
    var color: Color {
        switch self {
        case .normal: Ink.pink
        case .gorda: Color(hex: "#ee93a8")
        case .ruedas: Color(hex: "#8fc3ea")
        case .cristal: Color(hex: "#cdeaf4")
        case .acorazada: Color(hex: "#b9b3ad")
        case .bomba: Color(hex: "#4a4552")
        case .dorada: Ink.gold
        case .rey: Color(hex: "#f08aa3")
        case .gigante: Color(hex: "#f2a0b4")
        case .fantasma: Color(hex: "#eef2f6")
        case .madre: Color(hex: "#f7b6c6")
        case .diamante: Color(hex: "#9fe8ff")
        case .arcoiris: Color(hex: "#b48ef0")
        case .robot: Color(hex: "#8fa3b8")
        case .lava: Color(hex: "#f0642a")
        case .cosmica: Color(hex: "#6a4bc4")
        case .hielo: Color(hex: "#c9f1ff")
        case .suerte: Color(hex: "#5fd36a")
        case .zombi: Color(hex: "#93b07a")
        case .millonaria: Ink.gold
        case .ninja: Color(hex: "#3a3540")
        case .payaso: Color(hex: "#ffd23a")
        case .pirata: Color(hex: "#c9965e")
        case .vampiro: Color(hex: "#8a1f2a")
        case .titan: Color(hex: "#9aa1a9")
        case .momia: Color(hex: "#e7d8b4")
        case .alien: Color(hex: "#8fe36a")
        case .nube: Color(hex: "#f4f8ff")
        case .reina: Color(hex: "#f5a7b8")
        case .fenix: Color(hex: "#f0642a")
        case .agujero: Color(hex: "#2a2440")
        }
    }
    var dark: Color {
        switch self {
        case .normal, .gorda, .rey, .gigante, .madre: Ink.pinkDark
        case .ruedas: Color(hex: "#5e98c6")
        case .cristal: Color(hex: "#93c6d8")
        case .acorazada: Color(hex: "#8a847d")
        case .bomba: Color(hex: "#2c2833")
        case .dorada: Color(hex: "#c98d1d")
        case .fantasma: Color(hex: "#c4ccd6")
        case .diamante: Color(hex: "#4fb8d8")
        case .arcoiris: Color(hex: "#f2b632")
        case .robot: Color(hex: "#5b6b7c")
        case .lava: Color(hex: "#a52a12")
        case .cosmica: Color(hex: "#f2b632")
        case .hielo: Color(hex: "#7cc8e8")
        case .suerte: Color(hex: "#2f8f3a")
        case .zombi: Color(hex: "#5a6b4a")
        case .millonaria: Color(hex: "#c98d1d")
        case .ninja: Color(hex: "#1d1a17")
        case .payaso: Color(hex: "#e8483a")
        case .pirata: Color(hex: "#6e4126")
        case .vampiro: Color(hex: "#4a0f18")
        case .titan: Color(hex: "#5a5f66")
        case .momia: Color(hex: "#b9a77e")
        case .alien: Color(hex: "#3d8b4f")
        case .nube: Color(hex: "#b8c8e0")
        case .reina: Ink.pinkDark
        case .fenix: Color(hex: "#f2b632")
        case .agujero: Color(hex: "#8a5cc2")
        }
    }
    /// las que salen al azar (la dorada y el rey salen aparte)
    var special: Bool { self == .dorada || self == .rey }
}

/// el nivel de las huchas: sube muy poco a poco con cada hucha rota
enum PigLevel {
    static func needed(_ level: Int) -> Double { (90 * pow(1.12, Double(level))).rounded() }
}

// MARK: - Facturas

struct BillDef: Identifiable {
    let id: Int
    let company: String
    let concept: String
    let amount: Double
    let days: Int
}

// MARK: - Árbol de mejoras

enum SkillEffect {
    case damageFlat, damagePct, speedPct, radiusPct, stamina, killStamina, drainSave, startPigs, spawnPct, maxPigs
    case lootPct, golden, crit, critDamage, collateral, chest, jackpot, pierce, firstHit, fat, bomb, king, glass
    case frenzyEarly, frenzyTime, frenzyMoney
    case pigXPMul, goldenValue, chestValue, comboCap, comboTime
}

/// un tramo de una mejora: cuánto da cada nivel y lo que cuesta
struct SkillStep {
    let per: Double
    let levels: Int
    let baseCost: Double
    let growth: Double
    /// en vacas: el juego lo multiplica por lo que vale una vaca ahora (Game.cost)
    func cost(_ k: Int) -> Double { pow(baseCost, 0.6) * 2.5 * pow(growth + 0.1, Double(k)) }
}

/// Cada mejora hace una sola cosa. Las que tienen varios tramos dan más por nivel según suben
/// (+15 %, luego +25 %, +50 %…), y cada tramo dura hasta que el siguiente sale más a cuenta.
struct SkillDef: Identifiable {
    let id: String
    let name: String
    let desc: String          // «%» se cambia por el valor
    let effect: SkillEffect
    let icon: String
    let steps: [SkillStep]

    /// tramos: (por nivel, niveles, precio base, crecimiento)
    init(id: String, name: String, desc: String, effect: SkillEffect, icon: String, _ raw: (Double, Int, Double, Double)...) {
        self.id = id; self.name = name; self.desc = desc; self.effect = effect; self.icon = icon
        var list: [SkillStep] = []
        for (i, r) in raw.enumerated() {
            var n = r.1
            if i + 1 < raw.count {
                let next = SkillStep(per: raw[i + 1].0, levels: 0, baseCost: raw[i + 1].2, growth: raw[i + 1].3)
                let step = SkillStep(per: r.0, levels: 0, baseCost: r.2, growth: r.3)
                var k = 0
                while k < n && step.cost(k) < next.cost(0) { k += 1 }
                n = max(3, k)
            }
            list.append(SkillStep(per: r.0, levels: n, baseCost: r.2, growth: r.3))
        }
        steps = list
    }

    var maxLevel: Int { steps.reduce(0) { $0 + $1.levels } }
    var baseCost: Double { steps[0].baseCost }
    var compound: Bool { effect == .pigXPMul }

    /// el tramo del nivel l (el que se compra al subir desde l) y el nivel dentro de él
    private func step(_ l: Int) -> (SkillStep, Int) {
        var k = l
        for s in steps { if k < s.levels { return (s, k) }; k -= s.levels }
        return (steps[steps.count - 1], steps[steps.count - 1].levels)
    }
    func cost(_ l: Int) -> Double { let (s, k) = step(l); return s.cost(k) }

    /// lo que da en el nivel l
    func value(_ l: Int) -> Double {
        var left = l
        var v = compound ? 1.0 : 0.0
        for s in steps {
            let n = min(left, s.levels)
            if compound { v *= pow(1 + s.per / 100, Double(n)) } else { v += s.per * Double(n) }
            left -= n
        }
        return v
    }
    /// lo que da en el nivel l, ya escrito
    func text(_ l: Int) -> String {
        let v = value(l)
        return desc.filling(compound ? (v < 100 ? Fmt.dec(v, 2) : Fmt.num(v)) : Fmt.num(v))
    }
    /// lo que da el siguiente nivel
    func perText(_ l: Int) -> String {
        let per = step(min(l, maxLevel - 1)).0.per
        return desc.filling(compound ? Fmt.dec(1 + per / 100, 2) : Fmt.num(per))
    }
}

// MARK: - Herencia: los recuerdos del abuelo (puntos de herencia: se quedan tras la bancarrota)

enum RingEffect { case crit, stamina, golden, startCash, extraDays, chest, legacy, bills, lootMul, damageMul, keepTier, startHammer, autoBuy }

struct RingDef: Identifiable {
    let id: String
    let name: String
    let desc: String
    let effect: RingEffect
    let per: Double
    let maxLevel: Int
    let baseCost: Double
    let growth: Double
    /// imagen del objeto; si no hay, el icono
    var art: String = ""
    var icon: String = "sparkles"
    var image: String { art.isEmpty ? "j_" + id : art }
    /// los que multiplican nivel a nivel (×1,25, ×1,56…)
    var compound: Bool { effect == .lootMul || effect == .damageMul }
    func cost(_ level: Int) -> Double { (baseCost * pow(growth, Double(level))).rounded() }
    func value(_ l: Int) -> Double { compound ? pow(1 + per / 100, Double(l)) : per * Double(l) }
    var perText: String { compound ? desc.filling(Fmt.dec(1 + per / 100, 2)) : desc.filling(Fmt.num(per)) }
}

// MARK: - Colección de monedas y sobres sorpresa

enum Rarity: String, Codable, CaseIterable {
    case comun, rara, epica, legendaria
    var name: String {
        switch self { case .comun: "Común"; case .rara: "Rara"; case .epica: "Épica"; case .legendaria: "Legendaria" }
    }
    var color: Color {
        switch self { case .comun: Color(hex: "#c9b48a"); case .rara: Ink.blue; case .epica: Ink.purple; case .legendaria: Ink.gold }
    }
    /// bonus permanente de dinero por tener la moneda
    var bonus: Double {
        switch self { case .comun: 0.01; case .rara: 0.02; case .epica: 0.05; case .legendaria: 0.12 }
    }
    /// lo que vale una moneda repetida (en huchas ×50)
    var duplicate: Double {
        switch self { case .comun: 1; case .rara: 4; case .epica: 15; case .legendaria: 60 }
    }
}

struct CoinDef: Identifiable {
    let id: String
    let name: String
    let line: String
    let rarity: Rarity
    let metal: String
    let mark: String
}

// MARK: - El contenido

enum Content {
    static let hammers: [HammerDef] = [
        HammerDef(id: 0, name: "La chancla", line: "La de tu madre. Nunca falla.", cost: 0, damage: 4, speed: 1.1, radius: 34, style: .chancla, head: "#3f74b0", handle: "#2a2018"),
        HammerDef(id: 1, name: "Martillo de juguete", line: "Pita al golpear.", cost: 420, damage: 7, speed: 1.4, radius: 40, style: .toy, head: "#e8483a", handle: "#f2b632"),
        HammerDef(id: 2, name: "Martillo de carpintero", line: "Clavos aparte.", cost: 3150, damage: 15, speed: 1.5, radius: 44, style: .claw, head: "#7b8086", handle: "#9a6438"),
        HammerDef(id: 3, name: "Mazo de goma", line: "Rebota que da gusto.", cost: 21000, damage: 32, speed: 1.75, radius: 58, style: .mallet, head: "#2f2b2b", handle: "#c9a26b"),
        HammerDef(id: 4, name: "Maza medieval", line: "De un mercadillo.", cost: 157500, damage: 75, speed: 1.6, radius: 64, style: .mace, head: "#8d8f94", handle: "#6e4126"),
        HammerDef(id: 5, name: "Martillo neumático", line: "Los vecinos encantados.", cost: 1.12e+06, damage: 140, speed: 3.4, radius: 46, style: .jack, head: "#f2b632", handle: "#3a3a3a"),
        HammerDef(id: 6, name: "Mazo de demolición", line: "Para tabiques y {huchas}.", cost: 9.1e+06, damage: 450, speed: 1.5, radius: 86, style: .sledge, head: "#5a5f66", handle: "#b47a48"),
        HammerDef(id: 7, name: "Martillo del trueno", line: "Prestado. No preguntes.", cost: 8.4e+07, damage: 1_300, speed: 2.1, radius: 100, style: .thunder, head: "#c9ccd2", handle: "#7a4a2a"),
        HammerDef(id: 8, name: "Martillo del trueno dorado", line: "Ahora sí es suyo.", cost: 1.2e9, damage: 4_500, speed: 2.3, radius: 110, style: .thunderGold, head: "#f2b632", handle: "#7a1f2a"),
        HammerDef(id: 9, name: "Mazo de diamante", line: "Raya hasta el cristal blindado.", cost: 1.5e10, damage: 16_000, speed: 1.9, radius: 130, style: .diamond, head: "#9fe8ff", handle: "#3a3f45"),
        HammerDef(id: 10, name: "Cetro cósmico", line: "Lo encontraste en un meteorito.", cost: 2e11, damage: 60_000, speed: 2.8, radius: 140, style: .cosmic, head: "#8a5cc2", handle: "#2b1f4a"),
        HammerDef(id: 11, name: "La chancla de oro", line: "La de la abuela. Casi la definitiva.", cost: 3e12, damage: 260_000, speed: 3.2, radius: 160, style: .goldFlop, head: "#f2b632", handle: "#c8323c"),
        HammerDef(id: 12, name: "Martillo de fuego", line: "Funde la cerámica al tocarla.", cost: 4e13, damage: 1.1e6, speed: 3.4, radius: 170, style: .fire, head: "#c8323c", handle: "#3a2a20"),
        HammerDef(id: 13, name: "Mazo de hielo eterno", line: "{Las} {huchas} se quedan helad{as}.", cost: 6e14, damage: 4.5e6, speed: 3.6, radius: 185, style: .ice, head: "#9fe8ff", handle: "#e6f6ff"),
        HammerDef(id: 14, name: "Hacha vikinga", line: "No es un martillo. Da igual.", cost: 9e15, damage: 2e7, speed: 4.0, radius: 200, style: .viking, head: "#c9ccd2", handle: "#8a5a36"),
        HammerDef(id: 15, name: "Un yunque con un palo", line: "El final. Literalmente.", cost: 1.5e17, damage: 1e8, speed: 4.5, radius: 230, style: .anvil, head: "#5a5f66", handle: "#b07a4a"),
        HammerDef(id: 16, name: "Desatascador industrial", line: "Del fontanero del quinto.", cost: 2.2e18, damage: 4e8, speed: 4.0, radius: 220, style: .plunger, head: "#c8323c", handle: "#c9965e"),
        HammerDef(id: 17, name: "Matamoscas eléctrico", line: "Chisporrotea. Mucho.", cost: 3.4e19, damage: 1.4e9, speed: 5.5, radius: 190, style: .swatter, head: "#f2b632", handle: "#3a3a3a"),
        HammerDef(id: 18, name: "La sartén de la abuela", line: "Más peligrosa que la chancla.", cost: 5e20, damage: 6e9, speed: 3.8, radius: 240, style: .pan, head: "#2a2a30", handle: "#2a2420"),
        HammerDef(id: 19, name: "Bate de béisbol", line: "¡Home run!", cost: 7.5e21, damage: 2.4e10, speed: 4.2, radius: 250, style: .bat, head: "#d9b27c", handle: "#1d1a17"),
        HammerDef(id: 20, name: "Mazo de chocolate", line: "Se derrite de tanto dinero.", cost: 1.1e23, damage: 9e10, speed: 4.4, radius: 250, style: .choco, head: "#6b3a1f", handle: "#f4efe6"),
        HammerDef(id: 21, name: "El mazo del juez", line: "Culpables. Todas.", cost: 1.7e24, damage: 4e11, speed: 5.0, radius: 270, style: .gavel, head: "#8a5a36", handle: "#7a4a2a"),
    ]

    static let bills: [BillDef] = [
        BillDef(id: 0, company: "NETFLIZ S.L.", concept: "Suscripción mensual", amount: 60, days: 3),
        BillDef(id: 1, company: "MOVISTAAR", concept: "Tarifa del móvil", amount: 125, days: 3),
        BillDef(id: 2, company: "FIBRA YA", concept: "Internet de casa", amount: 260, days: 3),
        BillDef(id: 3, company: "CANAL DE AGUAS", concept: "Consumo bimestral", amount: 550, days: 3),
        BillDef(id: 4, company: "VETERINARIO EL GATO FELIZ", concept: "Vacunas del gato", amount: 1_150, days: 3),
        BillDef(id: 5, company: "IBERDROGA", concept: "Luz (otra vez más cara)", amount: 2_450, days: 3),
        BillDef(id: 6, company: "GYM FIT 24H", concept: "Gimnasio al que no vas", amount: 5_100, days: 3),
        BillDef(id: 7, company: "DGT", concept: "Multa por exceso de velocidad", amount: 10_800, days: 3),
        BillDef(id: 8, company: "COMUNIDAD DE VECINOS", concept: "Derrama del ascensor", amount: 22_700, days: 3),
        BillDef(id: 9, company: "CLÍNICA SONRISAS", concept: "Empaste y limpieza", amount: 47_700, days: 4),
        BillDef(id: 10, company: "SEGUROS MAPHRE", concept: "Seguro del coche", amount: 100_000, days: 4),
        BillDef(id: 11, company: "ITV EXPRESS", concept: "Inspección + multa", amount: 210_000, days: 4),
        BillDef(id: 12, company: "BODA DE TU PRIMO", concept: "Regalo, traje y viaje", amount: 440_000, days: 4),
        BillDef(id: 13, company: "INMOBILIARIA LOS TIBURONES", concept: "Alquiler del piso", amount: 925_000, days: 4),
        BillDef(id: 14, company: "REFORMAS PACO", concept: "El baño nuevo", amount: 1_950_000, days: 4),
        BillDef(id: 15, company: "UNIVERSIDAD PRIVADA", concept: "Matrícula del máster", amount: 4_100_000, days: 5),
        BillDef(id: 16, company: "CONCESIONARIO AUTOCAR", concept: "Coche nuevo (el viejo murió)", amount: 8_600_000, days: 5),
        BillDef(id: 17, company: "AGENCIA TRIBUTARIA", concept: "Declaración de la renta", amount: 18_000_000, days: 5),
    ]
    /// lo que cuesta la factura número n (contando todos los años), en vacas del nivel de cuando llega:
    /// suben poco al principio y luego cada una vale el triple que la anterior
    static func billUnits(_ n: Int) -> Double { 40 * pow(1.4, Double(min(n, 10))) * pow(1.6, Double(max(0, n - 10))) }
    /// los martillos también se pagan en vacas
    static func hammerUnits(_ id: Int) -> Double { id == 0 ? 0 : 1_000 * pow(4, Double(id - 1)) }

    static func pigHP(_ tier: Int) -> Double { 8 * pow(1.3, Double(tier)) }
    static func pigValue(_ tier: Int) -> Double { 0.9 * pow(1.12, Double(tier)) }

    /// el árbol de mejoras: el tronco y cinco ramas de seis, cada una hace una sola cosa
    static let skills: [SkillDef] = [
        SkillDef(id: "golpe", name: "Primer golpe", desc: "+% de daño", effect: .damageFlat, icon: "hammer.fill", (2, 5, 10, 1.7)),
        // daño
        SkillDef(id: "muneca", name: "Muñeca fuerte", desc: "+%\u{2009}% de daño", effect: .damagePct, icon: "hand.raised.fill",
                 (15, 30, 40, 1.55), (25, 30, 3_000, 1.6), (50, 40, 4e5, 1.7), (100, 50, 4e7, 1.5), (200, 60, 1e10, 1.45), (600, 50, 1e14, 1.5)),
        SkillDef(id: "certero", name: "Golpe certero", desc: "+%\u{2009}% de crítico", effect: .crit, icon: "scope", (4, 5, 150, 1.8), (5, 5, 3e6, 2)),
        SkillDef(id: "rompe", name: "Rompe{huchas}", desc: "Críticos +%\u{2009}%", effect: .critDamage, icon: "burst.fill", (50, 5, 600, 1.9), (100, 30, 5e10, 1.55)),
        SkillDef(id: "onda", name: "Onda expansiva", desc: "Las de al lado reciben un %\u{2009}%", effect: .collateral, icon: "dot.radiowaves.left.and.right", (10, 5, 3_500, 1.9), (10, 10, 2e11, 1.9)),
        SkillDef(id: "primero", name: "Primer impacto", desc: "+%\u{2009}% al primer golpe", effect: .firstHit, icon: "1.circle.fill", (100, 5, 15_000, 1.9)),
        SkillDef(id: "abrelatas", name: "Abrelatas", desc: "Atraviesa el +%\u{2009}% de la coraza", effect: .pierce, icon: "shield.slash.fill", (15, 4, 60_000, 2.2)),
        // dinero
        SkillDef(id: "sofa", name: "Rebuscar en el sofá", desc: "+%\u{2009}% de dinero", effect: .lootPct, icon: "sofa.fill",
                 (20, 30, 80, 1.55), (40, 40, 5e4, 1.65), (100, 50, 6e7, 1.5), (200, 60, 1.5e10, 1.45), (600, 50, 1e14, 1.5)),
        SkillDef(id: "ojo", name: "Ojo para el oro", desc: "+%\u{2009}% de {huchas} dorad{as}", effect: .golden, icon: "eye.fill", (1, 5, 2_000, 2), (0.5, 10, 1e11, 1.8)),
        SkillDef(id: "sobres", name: "Sobres sorpresa", desc: "+%\u{2009}% de sobres", effect: .chest, icon: "envelope.fill", (1, 5, 40_000, 2)),
        SkillDef(id: "bote", name: "El bote", desc: "%\u{2009}% de que {una} {hucha} dé ×20", effect: .jackpot, icon: "dollarsign.circle.fill", (0.5, 4, 2e6, 2.2)),
        SkillDef(id: "cartero", name: "El cartero", desc: "Los sobres dan +%\u{2009}% de dinero", effect: .chestValue, icon: "envelope.open.fill", (50, 20, 2e10, 1.6)),
        SkillDef(id: "orfebre", name: "Orfebre", desc: "Las doradas valen +%\u{2009}%", effect: .goldenValue, icon: "seal.fill", (50, 20, 4e10, 1.6)),
        // aguante y cuerpo
        SkillDef(id: "desayuno", name: "Desayuno fuerte", desc: "+% de aguante", effect: .stamina, icon: "cup.and.saucer.fill",
                 (5, 20, 25, 1.5), (8, 20, 300, 1.55), (9, 25, 7e5, 1.7), (15, 20, 3e7, 1.6), (20, 25, 5e10, 1.6)),
        SkillDef(id: "brazo", name: "Brazo largo", desc: "+%\u{2009}% de alcance", effect: .radiusPct, icon: "arrow.up.left.and.arrow.down.right", (10, 6, 120, 1.75)),
        SkillDef(id: "reflejos", name: "Reflejos", desc: "+%\u{2009}% de velocidad", effect: .speedPct, icon: "bolt.fill", (8, 25, 500, 1.6), (15, 5, 2.5e6, 2)),
        SkillDef(id: "segundo", name: "Segundo aire", desc: "%\u{2009}% de recuperar 1 al romper", effect: .killStamina, icon: "wind", (6, 5, 1_200, 1.8)),
        SkillDef(id: "respira", name: "Respirar hondo", desc: "%\u{2009}% de golpes gratis", effect: .drainSave, icon: "lungs.fill", (4, 5, 5_000, 1.9), (3, 5, 1e13, 2)),
        SkillDef(id: "cristalero", name: "Cristalero", desc: "Las de cristal dan +% de aguante", effect: .glass, icon: "drop.fill", (1, 3, 80_000, 2.5)),
        // huchas
        SkillDef(id: "mas", name: "Más {huchas}", desc: "+% {huchas} al empezar", effect: .startPigs, icon: "plus.circle.fill", (3, 15, 30, 1.8), (5, 15, 2e8, 1.6)),
        SkillDef(id: "repartidor", name: "El repartidor", desc: "Salen un %\u{2009}% más rápido", effect: .spawnPct, icon: "shippingbox.fill",
                 (12, 25, 250, 1.6), (15, 35, 25_000, 1.65), (25, 30, 6e8, 1.55), (40, 30, 2e10, 1.5)),
        SkillDef(id: "mesa", name: "Mesa más grande", desc: "+% {huchas} a la vez", effect: .maxPigs, icon: "rectangle.expand.vertical",
                 (4, 20, 1_000, 1.9), (4, 25, 5e7, 1.55), (15, 30, 5e9, 1.5), (25, 20, 1e13, 1.6)),
        SkillDef(id: "gordas", name: "{Huchas} gord{as}", desc: "+%\u{2009}% de {huchas} gord{as}", effect: .fat, icon: "circle.fill", (5, 4, 4_000, 2)),
        SkillDef(id: "corte", name: "La corte del rey", desc: "+%\u{2009}% de que venga el Rey", effect: .king, icon: "crown.fill", (10, 5, 1e6, 2)),
        SkillDef(id: "granja", name: "Granja de {huchas}", desc: "{Las} {huchas} suben de nivel ×%", effect: .pigXPMul, icon: "leaf.fill", (8, 30, 1e11, 1.7)),
        // frenesí
        SkillDef(id: "bombas", name: "Pólvora", desc: "Explosiones +%\u{2009}%", effect: .bomb, icon: "flame.circle.fill", (50, 4, 90_000, 2.2), (100, 10, 2e11, 1.9)),
        SkillDef(id: "horapunta", name: "Hora punta", desc: "Frenesí con % {huchas} menos de combo", effect: .frenzyEarly, icon: "timer", (2, 8, 8e7, 1.8)),
        SkillDef(id: "fiesta", name: "Fiesta", desc: "El frenesí dura +% s", effect: .frenzyTime, icon: "party.popper.fill", (1, 12, 3e8, 1.75), (1, 15, 5e12, 1.7)),
        SkillDef(id: "locura", name: "Locura", desc: "En frenesí, +%\u{2009}% de dinero", effect: .frenzyMoney, icon: "sparkles", (50, 25, 1e9, 1.6)),
        SkillDef(id: "comboloco", name: "Combo loco", desc: "El combo llega +% más alto", effect: .comboCap, icon: "flame", (10, 10, 3e10, 2)),
        SkillDef(id: "pegamento", name: "Combo pegajoso", desc: "El combo aguanta +% s", effect: .comboTime, icon: "hourglass", (0.15, 8, 6e10, 2)),
    ]

    static let rings: [RingDef] = [
        RingDef(id: "cartera", name: "La cartera del abuelo", desc: "×% de dinero", effect: .lootMul, per: 25, maxLevel: 60, baseCost: 5, growth: 1.3, art: "billete"),
        RingDef(id: "chancla", name: "La chancla de la abuela", desc: "×% de daño", effect: .damageMul, per: 25, maxLevel: 60, baseCost: 5, growth: 1.3, art: "m_chancla"),
        RingDef(id: "cuero", name: "Pulsera de cuero", desc: "+% de aguante", effect: .stamina, per: 5, maxLevel: 50, baseCost: 8, growth: 1.45),
        RingDef(id: "rubi", name: "Anillo de rubí", desc: "+%\u{2009}% de crítico", effect: .crit, per: 3, maxLevel: 20, baseCost: 15, growth: 1.7),
        RingDef(id: "trebol", name: "Pulsera del trébol", desc: "+%\u{2009}% de {huchas} dorad{as}", effect: .golden, per: 1, maxLevel: 20, baseCost: 20, growth: 1.8),
        RingDef(id: "sello", name: "Anillo de sello", desc: "Empiezas con más dinero", effect: .startCash, per: 1, maxLevel: 20, baseCost: 25, growth: 2),
        RingDef(id: "foto", name: "La foto de la bisabuela", desc: "Empiezas con {las} {huchas} al %\u{2009}% de tu récord", effect: .keepTier, per: 5, maxLevel: 10, baseCost: 30, growth: 1.9, icon: "photo.fill"),
        RingDef(id: "gemelos", name: "Pulsera de la suerte", desc: "+%\u{2009}% de sobres y mejores", effect: .chest, per: 1, maxLevel: 5, baseCost: 40, growth: 2),
        RingDef(id: "martillo", name: "El martillo del bisabuelo", desc: "Empiezas con los % primeros martillos", effect: .startHammer, per: 1, maxLevel: 12, baseCost: 40, growth: 1.8, icon: "hammer.fill"),
        RingDef(id: "alianza", name: "Alianza", desc: "+%\u{2009}% de puntos de herencia", effect: .legacy, per: 10, maxLevel: 25, baseCost: 50, growth: 2),
        RingDef(id: "reloj", name: "Reloj de bolsillo", desc: "+% días para cada factura", effect: .extraDays, per: 1, maxLevel: 3, baseCost: 60, growth: 4),
        RingDef(id: "libreta", name: "La libreta del cuñado", desc: "Al acabar el día compra solo lo más barato", effect: .autoBuy, per: 1, maxLevel: 1, baseCost: 150, growth: 1, icon: "list.clipboard.fill"),
        RingDef(id: "rey", name: "Anillo del rey", desc: "Facturas un %\u{2009}% más baratas", effect: .bills, per: 5, maxLevel: 6, baseCost: 200, growth: 2.5),
    ]

    static let coins: [CoinDef] = [
        CoinDef(id: "peseta", name: "Peseta", line: "España, 1980", rarity: .comun, metal: "#c9a24a", mark: "1"),
        CoinDef(id: "duro", name: "Duro", line: "Cinco pesetas", rarity: .comun, metal: "#c9a24a", mark: "5"),
        CoinDef(id: "perrachica", name: "Perra chica", line: "Cinco céntimos", rarity: .comun, metal: "#a5703a", mark: "5c"),
        CoinDef(id: "perragorda", name: "Perra gorda", line: "Diez céntimos", rarity: .comun, metal: "#a5703a", mark: "10c"),
        CoinDef(id: "centimo", name: "Céntimo", line: "El que nadie quiere", rarity: .comun, metal: "#b0673a", mark: "1c"),
        CoinDef(id: "doseuros", name: "2 euros", line: "Bimetálica", rarity: .comun, metal: "#c2c4c8", mark: "2€"),
        CoinDef(id: "penique", name: "Penique", line: "Reino Unido", rarity: .comun, metal: "#a5703a", mark: "p"),
        CoinDef(id: "dime", name: "Dime", line: "Estados Unidos", rarity: .comun, metal: "#c2c4c8", mark: "10"),
        CoinDef(id: "yen", name: "Yen", line: "Japón, con agujero", rarity: .comun, metal: "#d8dadd", mark: "¥"),
        CoinDef(id: "ochavo", name: "Ochavo", line: "Siglo XVIII", rarity: .comun, metal: "#8a5a36", mark: "8"),
        CoinDef(id: "reala8", name: "Real de a ocho", line: "El dólar de su época", rarity: .rara, metal: "#c2c4c8", mark: "8R"),
        CoinDef(id: "escudo", name: "Escudo", line: "Portugal", rarity: .rara, metal: "#c9a24a", mark: "E"),
        CoinDef(id: "florin", name: "Florín", line: "Florencia", rarity: .rara, metal: "#e0b84a", mark: "F"),
        CoinDef(id: "dracma", name: "Dracma", line: "Atenas, con lechuza", rarity: .rara, metal: "#c2c4c8", mark: "Δ"),
        CoinDef(id: "lira", name: "Lira", line: "Italia, 1970", rarity: .rara, metal: "#c2c4c8", mark: "L"),
        CoinDef(id: "rublo", name: "Rublo", line: "Rusia zarista", rarity: .rara, metal: "#c2c4c8", mark: "₽"),
        CoinDef(id: "doblon", name: "Doblón", line: "Oro de las Indias", rarity: .epica, metal: "#f2b632", mark: "D"),
        CoinDef(id: "sestercio", name: "Sestercio", line: "Roma imperial", rarity: .epica, metal: "#b0873a", mark: "S"),
        CoinDef(id: "ducado", name: "Ducado", line: "Venecia", rarity: .epica, metal: "#f2b632", mark: "Du"),
        CoinDef(id: "maravedi", name: "Maravedí de oro", line: "Castilla", rarity: .epica, metal: "#f2b632", mark: "M"),
        CoinDef(id: "reycerdito", name: "Moneda del Rey", line: "Acuñada en su honor", rarity: .legendaria, metal: "#f5a7b8", mark: "♛"),
        CoinDef(id: "galeon", name: "Doblón del galeón", line: "Del fondo del mar", rarity: .legendaria, metal: "#f2b632", mark: "⚓"),
        CoinDef(id: "chocolate", name: "Moneda de chocolate", line: "Sigue envuelta", rarity: .legendaria, metal: "#7a4a2a", mark: "C"),
        CoinDef(id: "primera", name: "La primera peseta", line: "1868. Única.", rarity: .legendaria, metal: "#e0b84a", mark: "I"),
        CoinDef(id: "kopek", name: "Kópek", line: "Rusia, céntimo de rublo", rarity: .comun, metal: "#a5703a", mark: "k"),
        CoinDef(id: "won", name: "Won", line: "Corea, con agujero", rarity: .comun, metal: "#c2c4c8", mark: "₩"),
        CoinDef(id: "peso", name: "Peso", line: "México", rarity: .comun, metal: "#c9a24a", mark: "$"),
        CoinDef(id: "thaler", name: "Tálero", line: "Bohemia, 1520", rarity: .rara, metal: "#d0d2d6", mark: "T"),
        CoinDef(id: "denario", name: "Denario", line: "Roma, plata", rarity: .rara, metal: "#b9bcc2", mark: "X"),
        CoinDef(id: "cruzado", name: "Cruzado", line: "Portugal, oro", rarity: .rara, metal: "#e0b84a", mark: "✚"),
        CoinDef(id: "aureo", name: "Áureo", line: "Roma, oro puro", rarity: .epica, metal: "#f2b632", mark: "A"),
        CoinDef(id: "solidus", name: "Sólido", line: "Bizancio", rarity: .epica, metal: "#e8c040", mark: "S"),
        CoinDef(id: "ryo", name: "Ryō", line: "Japón, de los samuráis", rarity: .epica, metal: "#f2c94a", mark: "両"),
        CoinDef(id: "lunar", name: "Moneda lunar", line: "Cayó de la Luna", rarity: .legendaria, metal: "#e6e8ec", mark: "☾"),
        CoinDef(id: "maldito", name: "Doblón maldito", line: "Del capitán Cerdobarba", rarity: .legendaria, metal: "#4a4552", mark: "☠"),
        CoinDef(id: "huchaoro", name: "La {hucha} de oro", line: "La madre de todas", rarity: .legendaria, metal: "#f2b632", mark: "♥"),
    ]
}

// MARK: - Personajes (modelos 3D renderizados a imagen)

struct SkinDef: Identifiable {
    let id: String
    let name: String
    let bills: Double         // facturas pagadas (en total) para tenerlo
    let w: Double, h: Double  // tamaño de la imagen
    let head: CGPoint         // dónde va la corona o la mecha (en píxeles de la imagen)
    let shards: [String]      // colores de los pedazos al romperse
    var singular = "hucha", plural = "huchas", female = true
    var drawn: Bool { id == "dibujo" }
}

extension Content {
    /// los animales de granja (las gambas y la hucha de dibujo se quitaron; sus imágenes siguen en Skins/)
    static let skins: [SkinDef] = [
        SkinDef(id: "vaca", name: "Vaca", bills: 0, w: 300, h: 226, head: CGPoint(x: 178, y: 46), shards: ["#ffffff", "#3a3a3a"], singular: "vaca", plural: "vacas", female: true),
        SkinDef(id: "cerdo", name: "Cerdito", bills: 0, w: 296, h: 211, head: CGPoint(x: 176, y: 39), shards: ["#f4b8c4", "#e48aa0"], singular: "cerdo", plural: "cerdos", female: false),
        SkinDef(id: "carlino", name: "Carlino", bills: 5, w: 274, h: 251, head: CGPoint(x: 232, y: 35), shards: ["#f3e6c4", "#6b4a3a"], singular: "carlino", plural: "carlinos", female: false),
        SkinDef(id: "llama", name: "Llama", bills: 15, w: 264, h: 307, head: CGPoint(x: 208, y: 12), shards: ["#a77b5a", "#ffffff"], singular: "llama", plural: "llamas", female: true),
        SkinDef(id: "caballo", name: "Caballo", bills: 30, w: 294, h: 235, head: CGPoint(x: 258, y: 12), shards: ["#a0673e", "#3a2a20"], singular: "caballo", plural: "caballos", female: false),
        SkinDef(id: "cebra", name: "Cebra", bills: 60, w: 292, h: 238, head: CGPoint(x: 260, y: 10), shards: ["#ffffff", "#1d1a17"], singular: "cebra", plural: "cebras", female: true),
    ]
    static func skin(_ id: String) -> SkinDef { skins.first { $0.id == id } ?? skins[0] }
    static func playing(_ id: String) -> SkinDef { skin(id) }
}

extension PigKind {
    /// qué versión del personaje se usa para cada tipo de hucha
    var look: String {
        switch self {
        case .dorada: "oro"
        case .cristal: "cristal"
        case .acorazada: "hierro"
        case .bomba: "bomba"
        case .diamante: "cristal"
        case .robot: "hierro"
        case .hielo: "cristal"
        case .millonaria: "oro"
        case .titan: "hierro"
        case .momia: "normal"
        case .agujero: "bomba"
        default: "normal"
        }
    }
}

extension Rarity {
    var order: Int { Rarity.allCases.firstIndex(of: self) ?? 0 }
}
