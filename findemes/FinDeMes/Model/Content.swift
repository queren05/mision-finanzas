import SwiftUI

// Todo el contenido son datos: para añadir martillos, huchas, facturas, mejoras, joyas o monedas
// basta con ampliar estas listas.

// MARK: - Martillos

enum HammerStyle { case chancla, toy, claw, mallet, mace, jack, sledge, thunder }

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
    case normal, gorda, ruedas, cristal, acorazada, bomba, dorada, rey

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
        }
    }
    var hp: Double {
        switch self { case .normal: 1; case .gorda: 3; case .ruedas: 0.8; case .cristal: 0.3; case .acorazada: 4; case .bomba: 1.2; case .dorada: 1.5; case .rey: 40 }
    }
    var value: Double {
        switch self { case .normal: 1; case .gorda: 3.5; case .ruedas: 2; case .cristal: 0.8; case .acorazada: 5; case .bomba: 1.5; case .dorada: 12; case .rey: 60 }
    }
    var size: Double {
        switch self { case .normal: 62; case .gorda: 84; case .ruedas: 54; case .cristal: 56; case .acorazada: 70; case .bomba: 60; case .dorada: 64; case .rey: 128 }
    }
    var speed: Double {
        switch self { case .normal: 14; case .gorda: 7; case .ruedas: 85; case .cristal: 10; case .acorazada: 9; case .bomba: 18; case .dorada: 26; case .rey: 12 }
    }
    /// a partir de qué nivel de huchas aparece (sube al pagar facturas)
    var minTier: Int {
        switch self { case .normal: 0; case .gorda: 1; case .ruedas: 2; case .cristal: 3; case .acorazada: 4; case .bomba: 5; case .dorada: 0; case .rey: 8 }
    }
    var weight: Double {
        switch self { case .normal: 100; case .gorda: 20; case .ruedas: 12; case .cristal: 10; case .acorazada: 10; case .bomba: 8; case .dorada: 0; case .rey: 0 }
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
        }
    }
    var dark: Color {
        switch self {
        case .normal, .gorda, .rey: Ink.pinkDark
        case .ruedas: Color(hex: "#5e98c6")
        case .cristal: Color(hex: "#93c6d8")
        case .acorazada: Color(hex: "#8a847d")
        case .bomba: Color(hex: "#2c2833")
        case .dorada: Color(hex: "#c98d1d")
        }
    }
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

    func cost(_ level: Int) -> Double { (baseCost * pow(growth, Double(level))).rounded() }
}

// MARK: - Joyas (puntos de herencia: se quedan tras la bancarrota)

enum RingEffect { case loot, damage, crit, stamina, golden, startCash, extraDays, radius, chest, legacy, bills }

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
        HammerDef(id: 1, name: "Martillo de juguete", line: "Pita al golpear.", cost: 120, damage: 7, speed: 1.4, radius: 40, style: .toy, head: "#e8483a", handle: "#f2b632"),
        HammerDef(id: 2, name: "Martillo de carpintero", line: "Clavos aparte.", cost: 900, damage: 15, speed: 1.5, radius: 44, style: .claw, head: "#7b8086", handle: "#9a6438"),
        HammerDef(id: 3, name: "Mazo de goma", line: "Rebota que da gusto.", cost: 6_000, damage: 32, speed: 1.75, radius: 58, style: .mallet, head: "#2f2b2b", handle: "#c9a26b"),
        HammerDef(id: 4, name: "Maza medieval", line: "De un mercadillo.", cost: 45_000, damage: 75, speed: 1.6, radius: 64, style: .mace, head: "#8d8f94", handle: "#6e4126"),
        HammerDef(id: 5, name: "Martillo neumático", line: "Los vecinos encantados.", cost: 320_000, damage: 140, speed: 3.4, radius: 46, style: .jack, head: "#f2b632", handle: "#3a3a3a"),
        HammerDef(id: 6, name: "Mazo de demolición", line: "Para tabiques y huchas.", cost: 2.6e6, damage: 450, speed: 1.5, radius: 86, style: .sledge, head: "#5a5f66", handle: "#b47a48"),
        HammerDef(id: 7, name: "Martillo del trueno", line: "Prestado. No preguntes.", cost: 2.4e7, damage: 1_300, speed: 2.1, radius: 100, style: .thunder, head: "#c9ccd2", handle: "#7a4a2a"),
    ]

    static let bills: [BillDef] = [
        BillDef(id: 0, company: "NETFLIZ S.L.", concept: "Suscripción mensual", amount: 15, days: 3),
        BillDef(id: 1, company: "MOVISTAAR", concept: "Tarifa del móvil", amount: 40, days: 3),
        BillDef(id: 2, company: "FIBRA YA", concept: "Internet de casa", amount: 95, days: 3),
        BillDef(id: 3, company: "CANAL DE AGUAS", concept: "Consumo bimestral", amount: 200, days: 3),
        BillDef(id: 4, company: "IBERDROGA", concept: "Luz (otra vez más cara)", amount: 420, days: 3),
        BillDef(id: 5, company: "GYM FIT 24H", concept: "Gimnasio al que no vas", amount: 850, days: 3),
        BillDef(id: 6, company: "COMUNIDAD DE VECINOS", concept: "Derrama del ascensor", amount: 1_700, days: 3),
        BillDef(id: 7, company: "SEGUROS MAPHRE", concept: "Seguro del coche", amount: 3_500, days: 4),
        BillDef(id: 8, company: "ITV EXPRESS", concept: "Inspección + multa", amount: 7_200, days: 4),
        BillDef(id: 9, company: "INMOBILIARIA LOS TIBURONES", concept: "Alquiler del piso", amount: 15_000, days: 4),
        BillDef(id: 10, company: "UNIVERSIDAD PRIVADA", concept: "Matrícula del máster", amount: 32_000, days: 4),
        BillDef(id: 11, company: "AGENCIA TRIBUTARIA", concept: "Declaración de la renta", amount: 80_000, days: 5),
    ]
    /// cada año seguido sin declararte en bancarrota, las facturas se multiplican por esto
    static let yearGrowth = 7.0

    static func pigHP(_ tier: Int) -> Double { 8 * pow(1.3, Double(tier)) }
    static func pigValue(_ tier: Int) -> Double { 2 * pow(1.36, Double(tier)) }

    static let skills: [SkillDef] = [
        // centro: daño
        SkillDef(id: "golpe", name: "Primer golpe", desc: "+% de daño", effect: .damageFlat, per: 2, maxLevel: 5, baseCost: 10, growth: 1.7, parent: nil, col: 3, row: 0, icon: "hammer.fill"),
        SkillDef(id: "muneca", name: "Muñeca fuerte", desc: "+%\u{2009}% de daño", effect: .damagePct, per: 15, maxLevel: 10, baseCost: 40, growth: 1.55, parent: "golpe", col: 3, row: 1, icon: "hand.raised.fill"),
        SkillDef(id: "certero", name: "Golpe certero", desc: "+%\u{2009}% de crítico", effect: .crit, per: 4, maxLevel: 5, baseCost: 150, growth: 1.8, parent: "muneca", col: 3, row: 2, icon: "scope"),
        SkillDef(id: "rompe", name: "Rompehuchas", desc: "Críticos +%\u{2009}%", effect: .critDamage, per: 50, maxLevel: 5, baseCost: 600, growth: 1.9, parent: "certero", col: 3, row: 3, icon: "burst.fill"),
        SkillDef(id: "bruta", name: "Fuerza bruta", desc: "+%\u{2009}% de daño", effect: .damagePct, per: 25, maxLevel: 10, baseCost: 3_000, growth: 1.6, parent: "rompe", col: 3, row: 4, icon: "figure.strengthtraining.traditional"),
        SkillDef(id: "primero", name: "Primer impacto", desc: "+%\u{2009}% al primer golpe", effect: .firstHit, per: 100, maxLevel: 5, baseCost: 15_000, growth: 1.9, parent: "bruta", col: 3, row: 5, icon: "1.circle.fill"),
        SkillDef(id: "abrelatas", name: "Abrelatas", desc: "Atraviesa el +%\u{2009}% de la coraza", effect: .pierce, per: 15, maxLevel: 4, baseCost: 60_000, growth: 2.2, parent: "primero", col: 3, row: 6, icon: "shield.slash.fill"),
        SkillDef(id: "maestro", name: "Golpe maestro", desc: "+%\u{2009}% de daño", effect: .damagePct, per: 50, maxLevel: 10, baseCost: 400_000, growth: 1.7, parent: "abrelatas", col: 3, row: 7, icon: "star.fill"),
        SkillDef(id: "furia", name: "Furia", desc: "+%\u{2009}% de crítico", effect: .crit, per: 5, maxLevel: 5, baseCost: 3e6, growth: 2, parent: "maestro", col: 3, row: 8, icon: "flame.fill"),
        // izquierda: aguante
        SkillDef(id: "desayuno", name: "Desayuno fuerte", desc: "+% de aguante", effect: .stamina, per: 5, maxLevel: 10, baseCost: 25, growth: 1.5, parent: "golpe", col: 2, row: 1, icon: "cup.and.saucer.fill"),
        SkillDef(id: "gimnasio", name: "Ir al gimnasio", desc: "+% de aguante", effect: .stamina, per: 8, maxLevel: 10, baseCost: 300, growth: 1.55, parent: "desayuno", col: 1, row: 2, icon: "dumbbell.fill"),
        SkillDef(id: "segundo", name: "Segundo aire", desc: "%\u{2009}% de recuperar 1 al romper", effect: .killStamina, per: 10, maxLevel: 5, baseCost: 1_200, growth: 1.8, parent: "gimnasio", col: 1, row: 3, icon: "wind"),
        SkillDef(id: "respira", name: "Respirar hondo", desc: "%\u{2009}% de golpes gratis", effect: .drainSave, per: 6, maxLevel: 5, baseCost: 5_000, growth: 1.9, parent: "segundo", col: 0, row: 4, icon: "lungs.fill"),
        SkillDef(id: "cafe", name: "Café doble", desc: "+% de aguante", effect: .stamina, per: 15, maxLevel: 10, baseCost: 30_000, growth: 1.6, parent: "segundo", col: 1, row: 5, icon: "mug.fill"),
        SkillDef(id: "cristalero", name: "Cristalero", desc: "Las de cristal dan +% de aguante", effect: .glass, per: 1, maxLevel: 3, baseCost: 80_000, growth: 2.5, parent: "cafe", col: 0, row: 6, icon: "drop.fill"),
        SkillDef(id: "maraton", name: "Maratón", desc: "+% de aguante", effect: .stamina, per: 30, maxLevel: 10, baseCost: 700_000, growth: 1.7, parent: "cafe", col: 1, row: 7, icon: "figure.run"),
        // izquierda-centro: botín
        SkillDef(id: "sofa", name: "Rebuscar en el sofá", desc: "+%\u{2009}% de dinero", effect: .lootPct, per: 20, maxLevel: 10, baseCost: 80, growth: 1.55, parent: "desayuno", col: 2, row: 2, icon: "sofa.fill"),
        SkillDef(id: "ojo", name: "Ojo para el oro", desc: "+%\u{2009}% de huchas doradas", effect: .golden, per: 1, maxLevel: 5, baseCost: 2_000, growth: 2, parent: "sofa", col: 2, row: 4, icon: "eye.fill"),
        SkillDef(id: "midas", name: "Toque de Midas", desc: "+%\u{2009}% de dinero", effect: .lootPct, per: 40, maxLevel: 10, baseCost: 50_000, growth: 1.65, parent: "ojo", col: 2, row: 6, icon: "sparkles"),
        SkillDef(id: "bote", name: "El bote", desc: "%\u{2009}% de que una hucha dé ×20", effect: .jackpot, per: 0.5, maxLevel: 4, baseCost: 2e6, growth: 2.2, parent: "midas", col: 2, row: 8, icon: "dollarsign.circle.fill"),
        // derecha: huchas
        SkillDef(id: "mas", name: "Más huchas", desc: "+% huchas al empezar", effect: .startPigs, per: 1, maxLevel: 6, baseCost: 30, growth: 1.8, parent: "golpe", col: 4, row: 1, icon: "plus.circle.fill"),
        SkillDef(id: "repartidor", name: "El repartidor", desc: "Salen un %\u{2009}% más rápido", effect: .spawnPct, per: 12, maxLevel: 10, baseCost: 250, growth: 1.6, parent: "mas", col: 5, row: 2, icon: "shippingbox.fill"),
        SkillDef(id: "mesa", name: "Mesa más grande", desc: "+% huchas a la vez", effect: .maxPigs, per: 2, maxLevel: 6, baseCost: 1_000, growth: 1.9, parent: "repartidor", col: 5, row: 3, icon: "rectangle.expand.vertical"),
        SkillDef(id: "gordas", name: "Huchas gordas", desc: "+%\u{2009}% de huchas gordas", effect: .fat, per: 5, maxLevel: 4, baseCost: 4_000, growth: 2, parent: "mesa", col: 6, row: 4, icon: "circle.fill"),
        SkillDef(id: "fabrica", name: "Fábrica de huchas", desc: "Salen un %\u{2009}% más rápido", effect: .spawnPct, per: 15, maxLevel: 10, baseCost: 25_000, growth: 1.65, parent: "mesa", col: 5, row: 5, icon: "building.2.fill"),
        SkillDef(id: "bombas", name: "Pólvora", desc: "Explosiones +%\u{2009}%", effect: .bomb, per: 50, maxLevel: 4, baseCost: 90_000, growth: 2.2, parent: "fabrica", col: 6, row: 6, icon: "flame.circle.fill"),
        SkillDef(id: "corte", name: "La corte del rey", desc: "+%\u{2009}% de que venga el Rey", effect: .king, per: 10, maxLevel: 5, baseCost: 1e6, growth: 2, parent: "fabrica", col: 5, row: 7, icon: "crown.fill"),
        // centro-derecha: alcance y velocidad
        SkillDef(id: "brazo", name: "Brazo largo", desc: "+%\u{2009}% de alcance", effect: .radiusPct, per: 10, maxLevel: 6, baseCost: 120, growth: 1.75, parent: "mas", col: 4, row: 2, icon: "arrow.up.left.and.arrow.down.right"),
        SkillDef(id: "reflejos", name: "Reflejos", desc: "+%\u{2009}% de velocidad", effect: .speedPct, per: 8, maxLevel: 10, baseCost: 500, growth: 1.6, parent: "brazo", col: 4, row: 3, icon: "bolt.fill"),
        SkillDef(id: "onda", name: "Onda expansiva", desc: "Las de al lado reciben un %\u{2009}%", effect: .collateral, per: 10, maxLevel: 5, baseCost: 3_500, growth: 1.9, parent: "reflejos", col: 4, row: 4, icon: "dot.radiowaves.left.and.right"),
        SkillDef(id: "sobres", name: "Sobres sorpresa", desc: "+%\u{2009}% de sobres", effect: .chest, per: 1, maxLevel: 5, baseCost: 40_000, growth: 2, parent: "onda", col: 4, row: 6, icon: "envelope.fill"),
        SkillDef(id: "huracan", name: "Huracán", desc: "+%\u{2009}% de velocidad", effect: .speedPct, per: 15, maxLevel: 5, baseCost: 2.5e6, growth: 2, parent: "sobres", col: 4, row: 8, icon: "tornado"),
    ]

    static let rings: [RingDef] = [
        RingDef(id: "abuela", name: "Anillo de la abuela", desc: "+%\u{2009}% de dinero", effect: .loot, per: 25, maxLevel: 25, baseCost: 5, growth: 1.45, color: "#d9a441", bracelet: false),
        RingDef(id: "oro", name: "Anillo de oro", desc: "+%\u{2009}% de daño", effect: .damage, per: 20, maxLevel: 25, baseCost: 5, growth: 1.45, color: "#f2b632", bracelet: false),
        RingDef(id: "rubi", name: "Anillo de rubí", desc: "+%\u{2009}% de crítico", effect: .crit, per: 3, maxLevel: 10, baseCost: 15, growth: 1.7, color: "#c8323c", bracelet: false),
        RingDef(id: "sello", name: "Anillo de sello", desc: "Empiezas con más dinero", effect: .startCash, per: 1, maxLevel: 10, baseCost: 25, growth: 2, color: "#a07a3c", bracelet: false),
        RingDef(id: "alianza", name: "Alianza", desc: "+%\u{2009}% de puntos de herencia", effect: .legacy, per: 10, maxLevel: 10, baseCost: 50, growth: 2, color: "#e6c86e", bracelet: false),
        RingDef(id: "rey", name: "Anillo del rey", desc: "Facturas un %\u{2009}% más baratas", effect: .bills, per: 5, maxLevel: 6, baseCost: 200, growth: 2.5, color: "#8a5cc2", bracelet: false),
        RingDef(id: "cuero", name: "Pulsera de cuero", desc: "+% de aguante", effect: .stamina, per: 5, maxLevel: 25, baseCost: 8, growth: 1.45, color: "#8a5a36", bracelet: true),
        RingDef(id: "trebol", name: "Pulsera del trébol", desc: "+%\u{2009}% de huchas doradas", effect: .golden, per: 1, maxLevel: 10, baseCost: 20, growth: 1.8, color: "#3d8b4f", bracelet: true),
        RingDef(id: "pinchos", name: "Pulsera de pinchos", desc: "+%\u{2009}% de alcance", effect: .radius, per: 8, maxLevel: 10, baseCost: 30, growth: 1.7, color: "#4a4552", bracelet: true),
        RingDef(id: "gemelos", name: "Pulsera de la suerte", desc: "+%\u{2009}% de sobres y mejores", effect: .chest, per: 1, maxLevel: 5, baseCost: 40, growth: 2, color: "#3f74b0", bracelet: true),
        RingDef(id: "reloj", name: "Reloj de bolsillo", desc: "+% días para cada factura", effect: .extraDays, per: 1, maxLevel: 3, baseCost: 60, growth: 4, color: "#b9b3ad", bracelet: true),
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
    ]
}
