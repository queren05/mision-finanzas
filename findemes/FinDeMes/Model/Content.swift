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
        case .normal: "Hucha"
        case .gorda: "Hucha gorda"
        case .ruedas: "Hucha con ruedas"
        case .cristal: "Hucha de cristal"
        case .acorazada: "Hucha acorazada"
        case .bomba: "Hucha bomba"
        case .dorada: "Hucha dorada"
        case .rey: "Rey Cerdito"
        case .gigante: "Hucha gigante"
        case .fantasma: "Hucha fantasma"
        case .madre: "Mamá hucha"
        case .diamante: "Hucha de diamante"
        case .arcoiris: "Hucha arcoíris"
        case .robot: "Hucha robot"
        case .lava: "Hucha de lava"
        case .cosmica: "Hucha cósmica"
        case .hielo: "Hucha de hielo"
        case .suerte: "Hucha de la suerte"
        case .zombi: "Hucha zombi"
        case .millonaria: "Hucha millonaria"
        case .ninja: "Hucha ninja"
        case .payaso: "Hucha payaso"
        case .pirata: "Hucha pirata"
        case .vampiro: "Hucha vampiro"
        case .titan: "Hucha titán"
        case .momia: "Hucha momia"
        case .alien: "Hucha alienígena"
        case .nube: "Hucha nube"
        case .reina: "Reina Cerdita"
        case .fenix: "Hucha fénix"
        case .agujero: "Hucha agujero negro"
        }
    }
    var line: String {
        switch self {
        case .normal: "La de toda la vida."
        case .gorda: "Aguanta más y suelta más."
        case .ruedas: "Corre que se las pela."
        case .cristal: "Frágil. Te devuelve aguante."
        case .acorazada: "Lleva coraza: cuesta hacerle daño."
        case .bomba: "Al romperla, explota y rompe las de al lado."
        case .dorada: "Rara. Puede soltar monedas del álbum."
        case .rey: "El jefe. Muchísima vida y un botín enorme."
        case .gigante: "Del tamaño de una lavadora."
        case .fantasma: "Desaparece y aparece donde quiere."
        case .madre: "Al romperla salen tres huchitas."
        case .diamante: "Durísima. Vale una fortuna."
        case .arcoiris: "Casi siempre suelta un sobre."
        case .robot: "Blindada y rápida. Odia los martillos."
        case .lava: "Explota como diez bombas."
        case .cosmica: "Viene del espacio con un tesoro dentro."
        case .hielo: "Congelada y durísima. Lenta como un lunes."
        case .suerte: "Al romperla, te da un punto de herencia."
        case .zombi: "La rompes y vuelve a levantarse."
        case .millonaria: "Rarísima. Vale mil huchas."
        case .ninja: "No la ves venir. Ni irse."
        case .payaso: "Al romperla salen cinco huchitas de colores."
        case .pirata: "Siempre lleva un sobre escondido."
        case .vampiro: "Al romperla te devuelve 3 de aguante."
        case .titan: "Enorme. Al romperla tiembla toda la mesa."
        case .momia: "Lleva tres mil años ahorrando."
        case .alien: "Al romperla se lleva a tres huchas en su nave."
        case .nube: "Al romperla llueven huchas doradas."
        case .reina: "La mujer del Rey. Suelta sobres buenos."
        case .fenix: "Renace de sus cenizas una vez."
        case .agujero: "Al romperla se traga todo lo que tiene cerca."
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
    static func needed(_ level: Int) -> Double { (100 * pow(1.09, Double(level))).rounded() }
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
    // se multiplican nivel a nivel
    case damageMul, lootMul, bothMul, pigXPMul
    case petDamage, goldenValue, chestValue, comboCap, comboTime
    // solo en el árbol familiar
    case keepTier, startHammer, keepParts, totemSlot, legacyPct, autoBuy, scratch
}

struct SkillDef: Identifiable {
    let id: String
    let name: String
    let desc: String          // «%» se cambia por el valor por nivel
    let effect: SkillEffect
    let per: Double
    let maxLevel: Int
    let baseCost: Double
    let growth: Double
    let parent: String?
    let col: Int
    let row: Int
    let icon: String
    /// del árbol familiar: se paga con puntos de herencia y no se pierde nunca
    var family = false

    func cost(_ level: Int) -> Double {
        family ? (baseCost * pow(growth, Double(level))).rounded() : (baseCost * 2.5 * pow(growth + 0.1, Double(level))).rounded()
    }
    var compound: Bool { effect == .damageMul || effect == .lootMul || effect == .bothMul || effect == .pigXPMul }
    /// lo que da en el nivel l, ya escrito
    func text(_ l: Int) -> String {
        if compound { let v = pow(1 + per / 100, Double(l)); return desc.filling(v < 100 ? Fmt.dec(v, 2) : Fmt.num(v)) }
        return desc.filling(Fmt.num(per * Double(l)))
    }
    var perText: String { compound ? desc.filling(Fmt.dec(1 + per / 100, 2)) : desc.filling(Fmt.num(per)) }
}

// MARK: - Joyas (puntos de herencia: se quedan tras la bancarrota)

enum RingEffect { case loot, damage, crit, stamina, golden, startCash, extraDays, radius, chest, legacy, bills, speed, critDamage, startPigs, maxPigs, spawn, frenzy, xp, pigXP, bankHours, quests }

struct RingDef: Identifiable {
    let id: String
    let name: String
    let desc: String
    let effect: RingEffect
    let per: Double
    let maxLevel: Int
    let baseCost: Double
    let growth: Double
    let color: String
    let bracelet: Bool
    func cost(_ level: Int) -> Double { (baseCost * pow(growth, Double(level))).rounded() }
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
        switch self { case .comun: 0.03; case .rara: 0.06; case .epica: 0.12; case .legendaria: 0.30 }
    }
    /// puntos de herencia por una moneda repetida
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
        HammerDef(id: 6, name: "Mazo de demolición", line: "Para tabiques y huchas.", cost: 9.1e+06, damage: 450, speed: 1.5, radius: 86, style: .sledge, head: "#5a5f66", handle: "#b47a48"),
        HammerDef(id: 7, name: "Martillo del trueno", line: "Prestado. No preguntes.", cost: 8.4e+07, damage: 1_300, speed: 2.1, radius: 100, style: .thunder, head: "#c9ccd2", handle: "#7a4a2a"),
        HammerDef(id: 8, name: "Martillo del trueno dorado", line: "Ahora sí es suyo.", cost: 1.2e9, damage: 4_500, speed: 2.3, radius: 110, style: .thunderGold, head: "#f2b632", handle: "#7a1f2a"),
        HammerDef(id: 9, name: "Mazo de diamante", line: "Raya hasta el cristal blindado.", cost: 1.5e10, damage: 16_000, speed: 1.9, radius: 130, style: .diamond, head: "#9fe8ff", handle: "#3a3f45"),
        HammerDef(id: 10, name: "Cetro cósmico", line: "Lo encontraste en un meteorito.", cost: 2e11, damage: 60_000, speed: 2.8, radius: 140, style: .cosmic, head: "#8a5cc2", handle: "#2b1f4a"),
        HammerDef(id: 11, name: "La chancla de oro", line: "La de la abuela. Casi la definitiva.", cost: 3e12, damage: 260_000, speed: 3.2, radius: 160, style: .goldFlop, head: "#f2b632", handle: "#c8323c"),
        HammerDef(id: 12, name: "Martillo de fuego", line: "Funde la cerámica al tocarla.", cost: 4e13, damage: 1.1e6, speed: 3.4, radius: 170, style: .fire, head: "#c8323c", handle: "#3a2a20"),
        HammerDef(id: 13, name: "Mazo de hielo eterno", line: "Las huchas se quedan heladas.", cost: 6e14, damage: 4.5e6, speed: 3.6, radius: 185, style: .ice, head: "#9fe8ff", handle: "#e6f6ff"),
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
        BillDef(id: 0, company: "NETFLIZ S.L.", concept: "Suscripción mensual", amount: 15, days: 3),
        BillDef(id: 1, company: "MOVISTAAR", concept: "Tarifa del móvil", amount: 30, days: 3),
        BillDef(id: 2, company: "FIBRA YA", concept: "Internet de casa", amount: 55, days: 3),
        BillDef(id: 3, company: "CANAL DE AGUAS", concept: "Consumo bimestral", amount: 100, days: 3),
        BillDef(id: 4, company: "VETERINARIO EL GATO FELIZ", concept: "Vacunas del gato", amount: 180, days: 3),
        BillDef(id: 5, company: "IBERDROGA", concept: "Luz (otra vez más cara)", amount: 320, days: 3),
        BillDef(id: 6, company: "GYM FIT 24H", concept: "Gimnasio al que no vas", amount: 560, days: 3),
        BillDef(id: 7, company: "DGT", concept: "Multa por exceso de velocidad", amount: 1_000, days: 3),
        BillDef(id: 8, company: "COMUNIDAD DE VECINOS", concept: "Derrama del ascensor", amount: 1_800, days: 3),
        BillDef(id: 9, company: "CLÍNICA SONRISAS", concept: "Empaste y limpieza", amount: 3_200, days: 4),
        BillDef(id: 10, company: "SEGUROS MAPHRE", concept: "Seguro del coche", amount: 5_600, days: 4),
        BillDef(id: 11, company: "ITV EXPRESS", concept: "Inspección + multa", amount: 10_000, days: 4),
        BillDef(id: 12, company: "BODA DE TU PRIMO", concept: "Regalo, traje y viaje", amount: 18_000, days: 4),
        BillDef(id: 13, company: "INMOBILIARIA LOS TIBURONES", concept: "Alquiler del piso", amount: 32_000, days: 4),
        BillDef(id: 14, company: "REFORMAS PACO", concept: "El baño nuevo", amount: 56_000, days: 4),
        BillDef(id: 15, company: "UNIVERSIDAD PRIVADA", concept: "Matrícula del máster", amount: 100_000, days: 5),
        BillDef(id: 16, company: "CONCESIONARIO AUTOCAR", concept: "Coche nuevo (el viejo murió)", amount: 180_000, days: 5),
        BillDef(id: 17, company: "AGENCIA TRIBUTARIA", concept: "Declaración de la renta", amount: 320_000, days: 5),
    ]
    /// cada año seguido sin declararte en bancarrota, las facturas se multiplican por esto
    static let yearGrowth = 20.0

    static func pigHP(_ tier: Int) -> Double { 8 * pow(1.36, Double(tier)) }
    static func pigValue(_ tier: Int) -> Double { 0.9 * pow(1.32, Double(tier)) }

    static let skills: [SkillDef] = [
        // centro: daño
        SkillDef(id: "golpe", name: "Primer golpe", desc: "+% de daño", effect: .damageFlat, per: 2, maxLevel: 5, baseCost: 10, growth: 1.7, parent: nil, col: 3, row: 0, icon: "hammer.fill"),
        SkillDef(id: "muneca", name: "Muñeca fuerte", desc: "+%\u{2009}% de daño", effect: .damagePct, per: 15, maxLevel: 30, baseCost: 40, growth: 1.55, parent: "golpe", col: 3, row: 1, icon: "hand.raised.fill"),
        SkillDef(id: "certero", name: "Golpe certero", desc: "+%\u{2009}% de crítico", effect: .crit, per: 4, maxLevel: 5, baseCost: 150, growth: 1.8, parent: "muneca", col: 3, row: 2, icon: "scope"),
        SkillDef(id: "rompe", name: "Rompehuchas", desc: "Críticos +%\u{2009}%", effect: .critDamage, per: 50, maxLevel: 5, baseCost: 600, growth: 1.9, parent: "certero", col: 3, row: 3, icon: "burst.fill"),
        SkillDef(id: "bruta", name: "Fuerza bruta", desc: "+%\u{2009}% de daño", effect: .damagePct, per: 25, maxLevel: 30, baseCost: 3_000, growth: 1.6, parent: "rompe", col: 3, row: 4, icon: "figure.strengthtraining.traditional"),
        SkillDef(id: "primero", name: "Primer impacto", desc: "+%\u{2009}% al primer golpe", effect: .firstHit, per: 100, maxLevel: 5, baseCost: 15_000, growth: 1.9, parent: "bruta", col: 3, row: 5, icon: "1.circle.fill"),
        SkillDef(id: "abrelatas", name: "Abrelatas", desc: "Atraviesa el +%\u{2009}% de la coraza", effect: .pierce, per: 15, maxLevel: 4, baseCost: 60_000, growth: 2.2, parent: "primero", col: 3, row: 6, icon: "shield.slash.fill"),
        SkillDef(id: "maestro", name: "Golpe maestro", desc: "+%\u{2009}% de daño", effect: .damagePct, per: 50, maxLevel: 40, baseCost: 400_000, growth: 1.7, parent: "abrelatas", col: 3, row: 7, icon: "star.fill"),
        SkillDef(id: "furia", name: "Furia", desc: "+%\u{2009}% de crítico", effect: .crit, per: 5, maxLevel: 5, baseCost: 3e6, growth: 2, parent: "maestro", col: 3, row: 8, icon: "flame.fill"),
        // izquierda: aguante
        SkillDef(id: "desayuno", name: "Desayuno fuerte", desc: "+% de aguante", effect: .stamina, per: 5, maxLevel: 20, baseCost: 25, growth: 1.5, parent: "golpe", col: 2, row: 1, icon: "cup.and.saucer.fill"),
        SkillDef(id: "gimnasio", name: "Ir al gimnasio", desc: "+% de aguante", effect: .stamina, per: 8, maxLevel: 20, baseCost: 300, growth: 1.55, parent: "desayuno", col: 1, row: 2, icon: "dumbbell.fill"),
        SkillDef(id: "segundo", name: "Segundo aire", desc: "%\u{2009}% de recuperar 1 al romper", effect: .killStamina, per: 6, maxLevel: 5, baseCost: 1_200, growth: 1.8, parent: "gimnasio", col: 1, row: 3, icon: "wind"),
        SkillDef(id: "respira", name: "Respirar hondo", desc: "%\u{2009}% de golpes gratis", effect: .drainSave, per: 4, maxLevel: 5, baseCost: 5_000, growth: 1.9, parent: "segundo", col: 0, row: 4, icon: "lungs.fill"),
        SkillDef(id: "cafe", name: "Café doble", desc: "+% de aguante", effect: .stamina, per: 5, maxLevel: 20, baseCost: 30_000, growth: 1.6, parent: "segundo", col: 1, row: 5, icon: "mug.fill"),
        SkillDef(id: "cristalero", name: "Cristalero", desc: "Las de cristal dan +% de aguante", effect: .glass, per: 1, maxLevel: 3, baseCost: 80_000, growth: 2.5, parent: "cafe", col: 0, row: 6, icon: "drop.fill"),
        SkillDef(id: "maraton", name: "Maratón", desc: "+% de aguante", effect: .stamina, per: 9, maxLevel: 25, baseCost: 700_000, growth: 1.7, parent: "cafe", col: 1, row: 7, icon: "figure.run"),
        // izquierda-centro: botín
        SkillDef(id: "sofa", name: "Rebuscar en el sofá", desc: "+%\u{2009}% de dinero", effect: .lootPct, per: 20, maxLevel: 30, baseCost: 80, growth: 1.55, parent: "desayuno", col: 2, row: 2, icon: "sofa.fill"),
        SkillDef(id: "ojo", name: "Ojo para el oro", desc: "+%\u{2009}% de huchas doradas", effect: .golden, per: 1, maxLevel: 5, baseCost: 2_000, growth: 2, parent: "sofa", col: 2, row: 4, icon: "eye.fill"),
        SkillDef(id: "midas", name: "Toque de Midas", desc: "+%\u{2009}% de dinero", effect: .lootPct, per: 40, maxLevel: 40, baseCost: 50_000, growth: 1.65, parent: "ojo", col: 2, row: 6, icon: "sparkles"),
        SkillDef(id: "bote", name: "El bote", desc: "%\u{2009}% de que una hucha dé ×20", effect: .jackpot, per: 0.5, maxLevel: 4, baseCost: 2e6, growth: 2.2, parent: "midas", col: 2, row: 8, icon: "dollarsign.circle.fill"),
        // derecha: huchas
        SkillDef(id: "mas", name: "Más huchas", desc: "+% huchas al empezar", effect: .startPigs, per: 3, maxLevel: 15, baseCost: 30, growth: 1.8, parent: "golpe", col: 4, row: 1, icon: "plus.circle.fill"),
        SkillDef(id: "repartidor", name: "El repartidor", desc: "Salen un %\u{2009}% más rápido", effect: .spawnPct, per: 12, maxLevel: 25, baseCost: 250, growth: 1.6, parent: "mas", col: 5, row: 2, icon: "shippingbox.fill"),
        SkillDef(id: "mesa", name: "Mesa más grande", desc: "+% huchas a la vez", effect: .maxPigs, per: 4, maxLevel: 20, baseCost: 1_000, growth: 1.9, parent: "repartidor", col: 5, row: 3, icon: "rectangle.expand.vertical"),
        SkillDef(id: "gordas", name: "Huchas gordas", desc: "+%\u{2009}% de huchas gordas", effect: .fat, per: 5, maxLevel: 4, baseCost: 4_000, growth: 2, parent: "mesa", col: 6, row: 4, icon: "circle.fill"),
        SkillDef(id: "fabrica", name: "Fábrica de huchas", desc: "Salen un %\u{2009}% más rápido", effect: .spawnPct, per: 15, maxLevel: 35, baseCost: 25_000, growth: 1.65, parent: "mesa", col: 5, row: 5, icon: "building.2.fill"),
        SkillDef(id: "bombas", name: "Pólvora", desc: "Explosiones +%\u{2009}%", effect: .bomb, per: 50, maxLevel: 4, baseCost: 90_000, growth: 2.2, parent: "fabrica", col: 6, row: 6, icon: "flame.circle.fill"),
        SkillDef(id: "corte", name: "La corte del rey", desc: "+%\u{2009}% de que venga el Rey", effect: .king, per: 10, maxLevel: 5, baseCost: 1e6, growth: 2, parent: "fabrica", col: 5, row: 7, icon: "crown.fill"),
        // centro-derecha: alcance y velocidad
        SkillDef(id: "brazo", name: "Brazo largo", desc: "+%\u{2009}% de alcance", effect: .radiusPct, per: 10, maxLevel: 6, baseCost: 120, growth: 1.75, parent: "mas", col: 4, row: 2, icon: "arrow.up.left.and.arrow.down.right"),
        SkillDef(id: "reflejos", name: "Reflejos", desc: "+%\u{2009}% de velocidad", effect: .speedPct, per: 8, maxLevel: 25, baseCost: 500, growth: 1.6, parent: "brazo", col: 4, row: 3, icon: "bolt.fill"),
        SkillDef(id: "onda", name: "Onda expansiva", desc: "Las de al lado reciben un %\u{2009}%", effect: .collateral, per: 10, maxLevel: 5, baseCost: 3_500, growth: 1.9, parent: "reflejos", col: 4, row: 4, icon: "dot.radiowaves.left.and.right"),
        SkillDef(id: "sobres", name: "Sobres sorpresa", desc: "+%\u{2009}% de sobres", effect: .chest, per: 1, maxLevel: 5, baseCost: 40_000, growth: 2, parent: "onda", col: 4, row: 6, icon: "envelope.fill"),
        SkillDef(id: "huracan", name: "Huracán", desc: "+%\u{2009}% de velocidad", effect: .speedPct, per: 15, maxLevel: 5, baseCost: 2.5e6, growth: 2, parent: "sobres", col: 4, row: 8, icon: "tornado"),
        // la parte de abajo del corcho: para cuando ya lo tienes todo
        SkillDef(id: "almacen", name: "Almacén de huchas", desc: "+% huchas a la vez", effect: .maxPigs, per: 4, maxLevel: 25, baseCost: 5e7, growth: 1.55, parent: "corte", col: 5, row: 9, icon: "shippingbox.circle.fill"),
        SkillDef(id: "alud", name: "Avalancha", desc: "+% huchas al empezar", effect: .startPigs, per: 5, maxLevel: 15, baseCost: 2e8, growth: 1.6, parent: "almacen", col: 6, row: 9, icon: "square.stack.3d.down.forward.fill"),
        SkillDef(id: "cinta", name: "Cinta transportadora", desc: "Salen un %\u{2009}% más rápido", effect: .spawnPct, per: 25, maxLevel: 30, baseCost: 6e8, growth: 1.55, parent: "alud", col: 6, row: 10, icon: "arrow.right.to.line.circle.fill"),
        SkillDef(id: "horapunta", name: "Hora punta", desc: "Frenesí con % huchas menos de combo", effect: .frenzyEarly, per: 2, maxLevel: 8, baseCost: 8e7, growth: 1.8, parent: "huracan", col: 4, row: 10, icon: "timer"),
        SkillDef(id: "fiesta", name: "Fiesta", desc: "El frenesí dura +% s", effect: .frenzyTime, per: 1, maxLevel: 12, baseCost: 3e8, growth: 1.75, parent: "horapunta", col: 4, row: 11, icon: "party.popper.fill"),
        SkillDef(id: "locura", name: "Locura", desc: "En frenesí, +%\u{2009}% de dinero", effect: .frenzyMoney, per: 50, maxLevel: 25, baseCost: 1e9, growth: 1.6, parent: "fiesta", col: 5, row: 11, icon: "sparkles"),
        SkillDef(id: "martillazo", name: "Martillazo", desc: "+%\u{2009}% de daño", effect: .damagePct, per: 100, maxLevel: 50, baseCost: 4e7, growth: 1.5, parent: "furia", col: 3, row: 10, icon: "hammer.circle.fill"),
        SkillDef(id: "tesoro", name: "El tesoro", desc: "+%\u{2009}% de dinero", effect: .lootPct, per: 100, maxLevel: 50, baseCost: 6e7, growth: 1.5, parent: "bote", col: 2, row: 10, icon: "crown.fill"),
        SkillDef(id: "hormigon", name: "Pulmones de hormigón", desc: "+% de aguante", effect: .stamina, per: 15, maxLevel: 20, baseCost: 3e7, growth: 1.6, parent: "maraton", col: 1, row: 9, icon: "figure.strengthtraining.functional"),
        // filas nuevas: lo más caro del corcho
        SkillDef(id: "demoledor", name: "Demoledor", desc: "×% de daño", effect: .damageMul, per: 10, maxLevel: 60, baseCost: 1e10, growth: 1.45, parent: "martillazo", col: 3, row: 12, icon: "hammer.circle"),
        SkillDef(id: "banquero", name: "Amigo banquero", desc: "×% de dinero", effect: .lootMul, per: 10, maxLevel: 60, baseCost: 1.5e10, growth: 1.45, parent: "tesoro", col: 2, row: 12, icon: "banknote.fill"),
        SkillDef(id: "cartero", name: "El cartero", desc: "Los sobres dan +%\u{2009}% de dinero", effect: .chestValue, per: 50, maxLevel: 20, baseCost: 2e10, growth: 1.6, parent: "hormigon", col: 1, row: 12, icon: "envelope.open.fill"),
        SkillDef(id: "manada", name: "Manada", desc: "+% huchas a la vez", effect: .maxPigs, per: 15, maxLevel: 30, baseCost: 5e9, growth: 1.5, parent: "cinta", col: 6, row: 12, icon: "square.grid.3x3.fill"),
        SkillDef(id: "criadero", name: "Criadero", desc: "Salen un %\u{2009}% más rápido", effect: .spawnPct, per: 40, maxLevel: 30, baseCost: 2e10, growth: 1.5, parent: "manada", col: 6, row: 13, icon: "arrow.triangle.2.circlepath"),
        SkillDef(id: "mascotero", name: "Chuches para la mascota", desc: "Tu mascota hace +%\u{2009}% de daño", effect: .petDamage, per: 40, maxLevel: 25, baseCost: 8e9, growth: 1.55, parent: "locura", col: 5, row: 13, icon: "pawprint.fill"),
        SkillDef(id: "comboloco", name: "Combo loco", desc: "El combo llega +% más alto", effect: .comboCap, per: 10, maxLevel: 10, baseCost: 3e10, growth: 2, parent: "fiesta", col: 4, row: 13, icon: "flame"),
        SkillDef(id: "pegamento", name: "Combo pegajoso", desc: "El combo aguanta +% s", effect: .comboTime, per: 0.15, maxLevel: 8, baseCost: 6e10, growth: 2, parent: "comboloco", col: 4, row: 14, icon: "timer"),
        SkillDef(id: "orfebre", name: "Orfebre", desc: "Las doradas valen +%\u{2009}%", effect: .goldenValue, per: 50, maxLevel: 20, baseCost: 4e10, growth: 1.6, parent: "banquero", col: 2, row: 14, icon: "seal.fill"),
        SkillDef(id: "brutal", name: "Golpe brutal", desc: "Críticos +%\u{2009}%", effect: .critDamage, per: 100, maxLevel: 30, baseCost: 5e10, growth: 1.55, parent: "demoledor", col: 3, row: 14, icon: "bolt.circle.fill"),
        SkillDef(id: "granja", name: "Granja de huchas", desc: "Las huchas suben de nivel ×%", effect: .pigXPMul, per: 10, maxLevel: 30, baseCost: 1e11, growth: 1.7, parent: "mascotero", col: 5, row: 15, icon: "leaf.fill"),
        SkillDef(id: "sismo", name: "Sismo", desc: "Las de al lado reciben un +%\u{2009}%", effect: .collateral, per: 10, maxLevel: 10, baseCost: 2e11, growth: 1.9, parent: "brutal", col: 3, row: 15, icon: "waveform.path"),
        SkillDef(id: "dinamita", name: "Dinamita", desc: "Explosiones +%\u{2009}%", effect: .bomb, per: 100, maxLevel: 10, baseCost: 2e11, growth: 1.9, parent: "criadero", col: 6, row: 14, icon: "burst.fill"),
        SkillDef(id: "multitud", name: "Multitud", desc: "+% huchas a la vez", effect: .maxPigs, per: 25, maxLevel: 20, baseCost: 1e13, growth: 1.6, parent: "dinamita", col: 6, row: 15, icon: "person.3.fill"),
        SkillDef(id: "eterno", name: "Frenesí eterno", desc: "El frenesí dura +% s", effect: .frenzyTime, per: 1, maxLevel: 15, baseCost: 5e12, growth: 1.7, parent: "pegamento", col: 4, row: 15, icon: "hourglass"),
        SkillDef(id: "lluvia", name: "Lluvia de oro", desc: "+%\u{2009}% de huchas doradas", effect: .golden, per: 0.5, maxLevel: 10, baseCost: 1e11, growth: 1.8, parent: "orfebre", col: 2, row: 15, icon: "cloud.rain.fill"),
        SkillDef(id: "omega", name: "El martillazo final", desc: "×% de daño", effect: .damageMul, per: 25, maxLevel: 50, baseCost: 1e14, growth: 1.5, parent: "sismo", col: 3, row: 16, icon: "sparkle"),
        SkillDef(id: "fortuna", name: "La gran fortuna", desc: "×% de dinero", effect: .lootMul, per: 25, maxLevel: 50, baseCost: 1e14, growth: 1.5, parent: "lluvia", col: 2, row: 16, icon: "crown"),
    ]

    /// el árbol familiar: se paga con puntos de herencia y se queda para siempre
    static let family: [SkillDef] = [
        SkillDef(id: "f_abuelo", name: "Abuelo Paco", desc: "×% de dinero", effect: .lootMul, per: 25, maxLevel: 60, baseCost: 5, growth: 1.3, parent: nil, col: 3, row: 0, icon: "figure.walk", family: true),
        SkillDef(id: "f_abuela", name: "Abuela Carmen", desc: "×% de daño", effect: .damageMul, per: 25, maxLevel: 60, baseCost: 5, growth: 1.3, parent: "f_abuelo", col: 2, row: 1, icon: "figure.stand.dress", family: true),
        SkillDef(id: "f_tio", name: "Tío Fermín", desc: "+% huchas a la vez", effect: .maxPigs, per: 12, maxLevel: 25, baseCost: 10, growth: 1.45, parent: "f_abuelo", col: 4, row: 1, icon: "figure.wave", family: true),
        SkillDef(id: "f_rosi", name: "Tía Rosi", desc: "Críticos +%\u{2009}%", effect: .critDamage, per: 40, maxLevel: 30, baseCost: 8, growth: 1.35, parent: "f_abuela", col: 1, row: 2, icon: "figure.dance", family: true),
        SkillDef(id: "f_bisabuela", name: "La bisabuela", desc: "Empiezas con las huchas al %\u{2009}% de tu récord", effect: .keepTier, per: 5, maxLevel: 10, baseCost: 30, growth: 1.9, parent: "f_abuela", col: 3, row: 2, icon: "brain.head.profile", family: true),
        SkillDef(id: "f_jonatan", name: "Primo Jonatan", desc: "+% huchas al empezar", effect: .startPigs, per: 10, maxLevel: 25, baseCost: 10, growth: 1.4, parent: "f_tio", col: 4, row: 2, icon: "figure.run", family: true),
        SkillDef(id: "f_vane", name: "Prima Vane", desc: "Salen un %\u{2009}% más rápido", effect: .spawnPct, per: 20, maxLevel: 25, baseCost: 12, growth: 1.4, parent: "f_tio", col: 5, row: 2, icon: "figure.socialdance", family: true),
        SkillDef(id: "f_tomas", name: "Abuelo Tomás", desc: "+%\u{2009}% de velocidad", effect: .speedPct, per: 5, maxLevel: 20, baseCost: 15, growth: 1.45, parent: "f_rosi", col: 1, row: 3, icon: "figure.walk.motion", family: true),
        SkillDef(id: "f_gemelos", name: "Los gemelos", desc: "Las huchas suben de nivel ×%", effect: .pigXPMul, per: 20, maxLevel: 50, baseCost: 10, growth: 1.38, parent: "f_bisabuela", col: 3, row: 3, icon: "person.2.fill", family: true),
        SkillDef(id: "f_sobrino", name: "El sobrino", desc: "Tu mascota hace +%\u{2009}% de daño", effect: .petDamage, per: 30, maxLevel: 25, baseCost: 20, growth: 1.45, parent: "f_vane", col: 5, row: 3, icon: "pawprint.fill", family: true),
        SkillDef(id: "f_herrero", name: "Bisabuelo herrero", desc: "Empiezas con los % primeros martillos", effect: .startHammer, per: 1, maxLevel: 12, baseCost: 40, growth: 1.8, parent: "f_tomas", col: 1, row: 4, icon: "hammer.fill", family: true),
        SkillDef(id: "f_cunado", name: "Cuñado contable", desc: "Al acabar el día compra solo lo más barato del corcho y el taller", effect: .autoBuy, per: 1, maxLevel: 1, baseCost: 150, growth: 1, parent: "f_gemelos", col: 3, row: 4, icon: "list.clipboard.fill", family: true),
        SkillDef(id: "f_lotera", name: "Tía lotera", desc: "+% rascas gratis al día", effect: .scratch, per: 1, maxLevel: 2, baseCost: 80, growth: 4, parent: "f_sobrino", col: 5, row: 4, icon: "ticket.fill", family: true),
        SkillDef(id: "f_mecanico", name: "Tío mecánico", desc: "Guardas el %\u{2009}% del taller en la bancarrota", effect: .keepParts, per: 5, maxLevel: 10, baseCost: 60, growth: 1.9, parent: "f_herrero", col: 1, row: 5, icon: "wrench.and.screwdriver.fill", family: true),
        SkillDef(id: "f_padrino", name: "El padrino", desc: "+% huecos para tótems", effect: .totemSlot, per: 1, maxLevel: 2, baseCost: 300, growth: 6, parent: "f_cunado", col: 3, row: 5, icon: "theatermasks.fill", family: true),
        SkillDef(id: "f_notario", name: "El notario", desc: "+%\u{2009}% de puntos de herencia", effect: .legacyPct, per: 10, maxLevel: 30, baseCost: 50, growth: 1.5, parent: "f_lotera", col: 5, row: 5, icon: "signature", family: true),
        SkillDef(id: "f_oro", name: "La abuela del oro", desc: "Las doradas valen +%\u{2009}%", effect: .goldenValue, per: 50, maxLevel: 20, baseCost: 40, growth: 1.5, parent: "f_mecanico", col: 1, row: 6, icon: "seal.fill", family: true),
        SkillDef(id: "f_tatara", name: "El tatarabuelo", desc: "×% de dinero y de daño", effect: .bothMul, per: 50, maxLevel: 30, baseCost: 500, growth: 1.6, parent: "f_padrino", col: 3, row: 6, icon: "crown.fill", family: true),
        SkillDef(id: "f_fiesta", name: "Tío fiestero", desc: "Frenesí con % huchas menos de combo", effect: .frenzyEarly, per: 2, maxLevel: 10, baseCost: 40, growth: 1.6, parent: "f_notario", col: 5, row: 6, icon: "party.popper.fill", family: true),
    ]

    static let rings: [RingDef] = [
        RingDef(id: "abuela", name: "Anillo de la abuela", desc: "+%\u{2009}% de dinero", effect: .loot, per: 25, maxLevel: 60, baseCost: 5, growth: 1.45, color: "#d9a441", bracelet: false),
        RingDef(id: "oro", name: "Anillo de oro", desc: "+%\u{2009}% de daño", effect: .damage, per: 20, maxLevel: 60, baseCost: 5, growth: 1.45, color: "#f2b632", bracelet: false),
        RingDef(id: "rubi", name: "Anillo de rubí", desc: "+%\u{2009}% de crítico", effect: .crit, per: 3, maxLevel: 20, baseCost: 15, growth: 1.7, color: "#c8323c", bracelet: false),
        RingDef(id: "sello", name: "Anillo de sello", desc: "Empiezas con más dinero", effect: .startCash, per: 1, maxLevel: 20, baseCost: 25, growth: 2, color: "#a07a3c", bracelet: false),
        RingDef(id: "alianza", name: "Alianza", desc: "+%\u{2009}% de puntos de herencia", effect: .legacy, per: 10, maxLevel: 25, baseCost: 50, growth: 2, color: "#e6c86e", bracelet: false),
        RingDef(id: "rey", name: "Anillo del rey", desc: "Facturas un %\u{2009}% más baratas", effect: .bills, per: 5, maxLevel: 6, baseCost: 200, growth: 2.5, color: "#8a5cc2", bracelet: false),
        RingDef(id: "cuero", name: "Pulsera de cuero", desc: "+% de aguante", effect: .stamina, per: 5, maxLevel: 50, baseCost: 8, growth: 1.45, color: "#8a5a36", bracelet: true),
        RingDef(id: "trebol", name: "Pulsera del trébol", desc: "+%\u{2009}% de huchas doradas", effect: .golden, per: 1, maxLevel: 20, baseCost: 20, growth: 1.8, color: "#3d8b4f", bracelet: true),
        RingDef(id: "pinchos", name: "Pulsera de pinchos", desc: "+%\u{2009}% de alcance", effect: .radius, per: 8, maxLevel: 20, baseCost: 30, growth: 1.7, color: "#4a4552", bracelet: true),
        RingDef(id: "gemelos", name: "Pulsera de la suerte", desc: "+%\u{2009}% de sobres y mejores", effect: .chest, per: 1, maxLevel: 5, baseCost: 40, growth: 2, color: "#3f74b0", bracelet: true),
        RingDef(id: "reloj", name: "Reloj de bolsillo", desc: "+% días para cada factura", effect: .extraDays, per: 1, maxLevel: 3, baseCost: 60, growth: 4, color: "#b9b3ad", bracelet: true),
        RingDef(id: "esmeralda", name: "Anillo de esmeralda", desc: "+%\u{2009}% de velocidad", effect: .speed, per: 4, maxLevel: 20, baseCost: 40, growth: 1.6, color: "#2fae5a", bracelet: false),
        RingDef(id: "zafiro", name: "Anillo de zafiro", desc: "Críticos +%\u{2009}%", effect: .critDamage, per: 20, maxLevel: 20, baseCost: 45, growth: 1.6, color: "#2f5fd0", bracelet: false),
        RingDef(id: "collar", name: "Collar de perlas", desc: "+% huchas al empezar", effect: .startPigs, per: 2, maxLevel: 20, baseCost: 60, growth: 1.7, color: "#f4efe6", bracelet: true),
        RingDef(id: "broche", name: "Broche de flor", desc: "+% huchas a la vez", effect: .maxPigs, per: 2, maxLevel: 30, baseCost: 70, growth: 1.65, color: "#e8483a", bracelet: true),
        RingDef(id: "tobillera", name: "Tobillera", desc: "Salen un %\u{2009}% más rápido", effect: .spawn, per: 8, maxLevel: 40, baseCost: 55, growth: 1.6, color: "#f2b632", bracelet: true),
        RingDef(id: "relojoro", name: "Reloj de oro", desc: "El frenesí dura +% s", effect: .frenzy, per: 0.5, maxLevel: 20, baseCost: 90, growth: 1.8, color: "#f2b632", bracelet: true),
        RingDef(id: "gargantilla", name: "Gargantilla", desc: "+%\u{2009}% de experiencia", effect: .xp, per: 10, maxLevel: 20, baseCost: 50, growth: 1.6, color: "#c8323c", bracelet: true),
        RingDef(id: "diadema", name: "Diadema", desc: "Las huchas suben de nivel un %\u{2009}% más rápido", effect: .pigXP, per: 8, maxLevel: 15, baseCost: 120, growth: 1.75, color: "#8a5cc2", bracelet: true),
        RingDef(id: "llavero", name: "Llavero de casa", desc: "En la hucha de casa caben +% h más", effect: .bankHours, per: 1, maxLevel: 12, baseCost: 35, growth: 1.7, color: "#d9a441", bracelet: true),
        RingDef(id: "compromiso", name: "Anillo de compromiso", desc: "Encargos +%\u{2009}% de premio", effect: .quests, per: 20, maxLevel: 15, baseCost: 80, growth: 1.7, color: "#e6e8ec", bracelet: false),
        RingDef(id: "amatista", name: "Anillo de amatista", desc: "Críticos +%\u{2009}%", effect: .critDamage, per: 30, maxLevel: 25, baseCost: 120, growth: 1.6, color: "#8a5cc2", bracelet: false),
        RingDef(id: "perla", name: "Anillo de perla", desc: "+%\u{2009}% de dinero", effect: .loot, per: 80, maxLevel: 50, baseCost: 800, growth: 1.5, color: "#f4efe6", bracelet: false),
        RingDef(id: "obsidiana", name: "Anillo de obsidiana", desc: "+%\u{2009}% de daño", effect: .damage, per: 80, maxLevel: 50, baseCost: 800, growth: 1.5, color: "#1d1a17", bracelet: false),
        RingDef(id: "topacio", name: "Anillo de topacio", desc: "Salen un %\u{2009}% más rápido", effect: .spawn, per: 10, maxLevel: 30, baseCost: 150, growth: 1.6, color: "#f0a020", bracelet: false),
        RingDef(id: "ambar", name: "Colgante de ámbar", desc: "+%\u{2009}% de experiencia", effect: .xp, per: 15, maxLevel: 20, baseCost: 200, growth: 1.6, color: "#e8962a", bracelet: true),
        RingDef(id: "luna", name: "Colgante de la luna", desc: "Las huchas suben de nivel un %\u{2009}% más rápido", effect: .pigXP, per: 10, maxLevel: 15, baseCost: 300, growth: 1.75, color: "#e6e8ec", bracelet: true),
        RingDef(id: "diamantes", name: "Anillo de diamantes", desc: "+%\u{2009}% de dinero", effect: .loot, per: 60, maxLevel: 50, baseCost: 500, growth: 1.5, color: "#f4fbff", bracelet: false),
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
        CoinDef(id: "reycerdito", name: "Moneda del Rey Cerdito", line: "Acuñada en su honor", rarity: .legendaria, metal: "#f5a7b8", mark: "♛"),
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
        CoinDef(id: "huchaoro", name: "La hucha de oro", line: "La madre de todas", rarity: .legendaria, metal: "#f2b632", mark: "♥"),
    ]
}

// MARK: - Personajes (modelos 3D renderizados a imagen)

struct SkinDef: Identifiable {
    let id: String
    let name: String
    let cost: Double          // puntos de herencia (0 = gratis)
    let w: Double, h: Double  // tamaño de la imagen
    let head: CGPoint         // dónde va la corona o la mecha (en píxeles de la imagen)
    let shards: [String]      // colores de los pedazos al romperse
    var drawn: Bool { id == "dibujo" }
}

extension Content {
    static let skins: [SkinDef] = [
        SkinDef(id: "cerdo", name: "Cerdito", cost: 0, w: 296, h: 211, head: CGPoint(x: 176, y: 39), shards: ["#f4b8c4", "#e48aa0"]),
        SkinDef(id: "gamba", name: "Gamba", cost: 0, w: 341, h: 239, head: CGPoint(x: 215, y: 120), shards: ["#f6b98a", "#e58a5a"]),
        SkinDef(id: "chaqueta", name: "Gamba con chaqueta", cost: 10, w: 301, h: 230, head: CGPoint(x: 210, y: 95), shards: ["#f6b98a", "#4d8fc7"]),
        SkinDef(id: "gafas", name: "Gamba con gafas", cost: 10, w: 319, h: 180, head: CGPoint(x: 215, y: 85), shards: ["#f3b48f", "#a7d36a"]),
        SkinDef(id: "langostino", name: "Langostino", cost: 25, w: 344, h: 249, head: CGPoint(x: 225, y: 75), shards: ["#f7a64a", "#e8603c"]),
        SkinDef(id: "langosta", name: "Langosta", cost: 40, w: 316, h: 144, head: CGPoint(x: 205, y: 60), shards: ["#ef3b2c", "#b8261b"]),
        SkinDef(id: "vaca", name: "Vaca", cost: 20, w: 300, h: 226, head: CGPoint(x: 178, y: 46), shards: ["#ffffff", "#3a3a3a"]),
        SkinDef(id: "carlino", name: "Carlino", cost: 20, w: 274, h: 251, head: CGPoint(x: 232, y: 35), shards: ["#f3e6c4", "#6b4a3a"]),
        SkinDef(id: "llama", name: "Llama", cost: 30, w: 264, h: 307, head: CGPoint(x: 208, y: 12), shards: ["#a77b5a", "#ffffff"]),
        SkinDef(id: "caballo", name: "Caballo", cost: 35, w: 294, h: 235, head: CGPoint(x: 258, y: 12), shards: ["#a0673e", "#3a2a20"]),
        SkinDef(id: "cebra", name: "Cebra", cost: 45, w: 292, h: 238, head: CGPoint(x: 260, y: 10), shards: ["#ffffff", "#1d1a17"]),
        SkinDef(id: "mysis", name: "Gamba transparente", cost: 30, w: 336, h: 173, head: CGPoint(x: 250, y: 40), shards: ["#e8e4dc", "#bdb6a8"]),
        SkinDef(id: "ebi", name: "Gamba blanca", cost: 20, w: 328, h: 180, head: CGPoint(x: 200, y: 90), shards: ["#fff6ec", "#f0c9a8"]),
        SkinDef(id: "dibujo", name: "Hucha de dibujo", cost: 0, w: 1, h: 1, head: .zero, shards: []),
    ]
    static func skin(_ id: String) -> SkinDef { skins.first { $0.id == id } ?? skins[0] }
    /// de momento todo son vacas: los personajes siguen aquí (y lo comprado se guarda) por si vuelven
    static let onlyCows = true
    static func playing(_ id: String) -> SkinDef { onlyCows ? skin("vaca") : skin(id) }
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
