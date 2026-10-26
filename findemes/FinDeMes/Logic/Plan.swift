import SwiftUI

/// Las puertas de la cocina: cada una junta varias pantallas y aparece cuando toca
enum Door: String, CaseIterable {
    case mejoras, martillo, album, bar, herencia

    var title: String {
        switch self {
        case .mejoras: "Mejoras"
        case .martillo: "Martillo"
        case .album: "Álbum"
        case .bar: "El bar de Manolo"
        case .herencia: "Herencia"
        }
    }
    var icon: String {
        switch self {
        case .mejoras: "leaf.fill"
        case .martillo: "hammer.fill"
        case .album: "book.closed.fill"
        case .bar: "dice.fill"
        case .herencia: "crown.fill"
        }
    }
    var color: Color {
        switch self {
        case .mejoras: Ink.red
        case .martillo: Ink.blue
        case .album: Ink.gold
        case .bar: Ink.red
        case .herencia: Ink.purple
        }
    }
}

/// lo ganado mientras no se jugaba
struct AwayPrize: Identifiable {
    let id = UUID()
    let minutes: Double
    let cash: Double
    let cows: Double
}

/// las hipotecas, una detrás de otra
enum Mortgage {
    static let names = ["La Hipoteca", "El chalet de la playa", "El yate", "El equipo de fútbol", "Comprar el banco"]
    static func name(_ level: Int) -> String { level < names.count ? names[level] : "El banco (\(level - names.count + 2))" }
    /// lo que cuesta: la primera, mil trillones; cada una, diez mil veces la anterior
    static func total(_ level: Int) -> Double { 1e21 * pow(1e4, Double(level)) }
    /// la cifra en palabras: «Mil trillones €», «10 cuatrillones €»
    static func words(_ v: Double) -> String {
        let names = ["", "mil", "millones", "mil millones", "billones", "mil billones", "trillones", "mil trillones",
                     "cuatrillones", "mil cuatrillones", "quintillones", "mil quintillones", "sextillones"]
        let e3 = min(names.count - 1, Int(floor(log10(max(1, v)) / 3)))
        let m = (v / pow(1000, Double(e3))).rounded()
        if m == 1 && names[e3].hasPrefix("mil") { return names[e3].capitalizedFirst + " €" }
        return Fmt.num(m) + " " + names[e3] + " €"
    }
}

@MainActor
extension Game {
    // MARK: puertas (se abren poco a poco)

    func doorOpen(_ d: Door) -> Bool {
        let st = s.stats
        let veteran = st.bankruptcies > 0
        switch d {
        case .mejoras: return st.days >= 1 || veteran
        case .martillo: return st.billsPaid >= 1 || veteran
        case .album: return st.days >= 2 || veteran
        case .bar: return st.days >= 3 || veteran
        case .herencia: return veteran
        }
    }
    func isNew(_ d: Door) -> Bool { doorOpen(d) && !s.seenDoors.contains(d.rawValue) }
    func open(_ d: Door) {
        guard !s.seenDoors.contains(d.rawValue) else { return }
        s.seenDoors.insert(d.rawValue)
        save()
    }

    // MARK: la hipoteca (el final)

    var mortgageTotal: Double { Mortgage.total(s.richLevel) }
    var mortgageName: String { Mortgage.name(s.richLevel) }
    var mortgageShare: Double { min(1, s.mortgage / mortgageTotal) }

    /// abonar dinero a la hipoteca: lo abonado se queda aunque te arruines
    func payMortgage(_ amount: Double) {
        let a = min(amount, s.cash)
        guard a > 0 else { return }
        s.cash -= a
        addToMortgage(a)
        Sound.shared.till()
        save()
    }

    func addToMortgage(_ a: Double) {
        guard a > 0 else { return }
        s.mortgage += a
        if s.mortgage >= mortgageTotal {
            // ¡pagada! la casa es tuya: desde ahora todo da más y llega la siguiente
            finale = s.richLevel
            s.richLevel += 1
            s.mortgage = 0
            recompute()
            Sound.shared.fanfare()
        }
    }

    // MARK: lo ganado mientras no juegas

    /// al abrir la app: si ha pasado un rato, la mascota (o el abuelo) ha seguido rompiendo
    func wake() {
        let now = Date().timeIntervalSince1970
        defer { s.lastPlayed = now }
        guard s.lastPlayed > 0, !inRun, s.lastDayEarned > 0, away == nil else { return }
        let minutes = min(240, (now - s.lastPlayed) / 60)
        guard minutes >= 5 else { return }
        // cada hora fuera vale algo más que un día de los buenos
        let cash = (s.lastDayEarned * 1.2 * minutes / 60).rounded()
        away = AwayPrize(minutes: minutes, cash: cash, cows: max(1, (cash / max(1, pigWorth)).rounded()))
    }

    func collectAway() {
        guard let a = away else { return }
        s.cash += a.cash
        s.stats.earned += a.cash
        away = nil
        Sound.shared.till()
        save()
    }

    // MARK: números grandes

    static let milestoneNames = ["", "MIL €", "MILLÓN", "MIL MILLONES", "BILLÓN", "MIL BILLONES", "TRILLÓN", "MIL TRILLONES",
                                 "CUATRILLÓN", "MIL CUATRILLONES", "QUINTILLÓN"]

    /// celebra la primera vez que se llega a mil, a un millón, a mil millones…
    func checkMilestone() {
        guard s.cash >= 1000 else { return }
        let k = Int(floor(log10(s.cash) / 3))
        guard k > s.milestone else { return }
        s.milestone = k
        milestoneShow = k
        Sound.shared.fanfare()
        save()
    }

    // MARK: la mejor compra (la chincheta dorada)

    /// la mejora que más conviene ahora: la más barata de las que llega el dinero
    func bestSkill(_ defs: [SkillDef]) -> String? {
        defs.filter { canGet($0) }.min { cost($0) < cost($1) }?.id
    }
    var bestPart: String? {
        Content.parts.filter { canBuyPart($0) }.min { partCost($0) < partCost($1) }?.id
    }
    /// el siguiente martillo, si ya llega el dinero
    var bestHammer: Int? {
        Content.hammers.first { !s.hammersOwned.contains($0.id) && s.cash >= hammerCost($0) }?.id
    }
}
