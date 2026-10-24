import SwiftUI
import Observation

/// lo que vale cada cosa con el martillo, las mejoras, las joyas y la colección de ahora
struct HitStats {
    var damage = 4.0
    var speed = 1.1
    var radius = 34.0
    var stamina = 25.0
    var killStamina = 0.0     // probabilidad de recuperar 1 al romper
    var drainSave = 0.0       // probabilidad de que un golpe no gaste
    var startPigs = 10
    var spawnEvery = 0.9
    var maxPigs = 18
    var loot = 1.0
    var golden = 0.008
    var crit = 0.05
    var critMult = 2.5
    var collateral = 0.0
    var chest = 0.006
    var chestLuck = 0
    var jackpot = 0.0
    var pierce = 0.0
    var firstHit = 0.0
    var fat = 0.0
    var bomb = 1.0
    var king = 0.0
    var glass = 2.0
}

struct DayReport: Identifiable {
    let id = UUID()
    let day: Int
    var earned = 0.0
    var broken = 0
    var swings = 0
    var crits = 0
    var golden = 0
    var kings = 0
    var chests: [Rarity] = []
    var coins: [String] = []
    var best = 0.0
    var bestCombo = 0
    var frenzies = 0
    var byKind: [String: Int] = [:]
    var xp = 0.0
    var record = false
}

struct ChestPrize: Identifiable {
    let id = UUID()
    let rarity: Rarity
    let cash: Double
    let coin: CoinDef?
    let duplicate: Bool
    let legacy: Double
}

enum GameEvent: Identifiable {
    case collector(legacy: Double)
    case taxes
    case bankrupt(legacy: Double)
    var id: String {
        switch self {
        case .collector: "collector"
        case .taxes: "taxes"
        case .bankrupt: "bankrupt"
        }
    }
}

@Observable
@MainActor
final class Game {
    static let shared = Game()

    var s: SaveState
    var inRun = false
    var report: DayReport? = nil
    var event: GameEvent? = nil
    /// nivel nuevo recién alcanzado (para la celebración)
    var levelUp: Int? = nil
    /// huchas nuevas que acaban de aparecer
    var newKinds: [PigKind] = []
    /// sube cada vez que cambia algo que afecta a las estadísticas
    private(set) var stats = HitStats()

    private init() {
        s = Persistence.load() ?? SaveState()
        applySettings()
        recompute()
        refillQuests()
        startBankIfNeeded()
    }

    func applySettings() {
        Sound.shared.on = s.settings.sound
        Sound.shared.haptics = s.settings.haptics
        Music.shared.on = s.settings.music
    }

    func save() { Persistence.save(s) }

    // MARK: - Estadísticas

    func level(_ k: SkillDef) -> Int { s.skills[k.id] ?? 0 }
    func ringLevel(_ r: RingDef) -> Int { s.rings[r.id] ?? 0 }

    func recompute() {
        let h = Content.hammers[s.hammer]
        var st = HitStats()
        st.damage = h.damage; st.speed = h.speed; st.radius = h.radius
        var dmgPct = 0.0, speedPct = 0.0, radiusPct = 0.0, lootPct = 0.0, spawnPct = 0.0
        for k in Content.skills {
            let l = Double(level(k))
            guard l > 0 else { continue }
            let v = k.per * l
            switch k.effect {
            case .damageFlat: st.damage += v
            case .damagePct: dmgPct += v
            case .speedPct: speedPct += v
            case .radiusPct: radiusPct += v
            case .stamina: st.stamina += v
            case .killStamina: st.killStamina += v / 100
            case .drainSave: st.drainSave += v / 100
            case .startPigs: st.startPigs += Int(v)
            case .spawnPct: spawnPct += v
            case .maxPigs: st.maxPigs += Int(v)
            case .lootPct: lootPct += v
            case .golden: st.golden += v / 100
            case .crit: st.crit += v / 100
            case .critDamage: st.critMult += v / 100
            case .collateral: st.collateral += v / 100
            case .chest: st.chest += v / 100
            case .jackpot: st.jackpot += v / 100
            case .pierce: st.pierce += v / 100
            case .firstHit: st.firstHit += v / 100
            case .fat: st.fat += v / 100
            case .bomb: st.bomb += v / 100
            case .king: st.king += v / 100
            case .glass: st.glass += v
            }
        }
        for r in Content.rings {
            let l = Double(ringLevel(r))
            guard l > 0 else { continue }
            let v = r.per * l
            switch r.effect {
            case .loot: lootPct += v
            case .damage: dmgPct += v
            case .crit: st.crit += v / 100
            case .stamina: st.stamina += v
            case .golden: st.golden += v / 100
            case .radius: radiusPct += v
            case .chest: st.chest += v / 100; st.chestLuck += Int(l)
            case .startCash, .extraDays, .legacy, .bills: break
            }
        }
        // cada moneda de la colección da dinero para siempre
        for c in Content.coins where (s.coins[c.id] ?? 0) > 0 { lootPct += c.rarity.bonus * 100 }
        // cada nivel da +2 % y cada logro +3 % de dinero, para siempre
        lootPct += Double(s.level - 1) * 2 + Double(s.achievements.count) * 3
        st.damage *= 1 + dmgPct / 100
        st.speed *= 1 + speedPct / 100
        st.radius *= 1 + radiusPct / 100
        st.loot = 1 + lootPct / 100
        st.spawnEvery = 0.9 / (1 + spawnPct / 100)
        stats = st
    }

    func ringValue(_ e: RingEffect) -> Double {
        Content.rings.filter { $0.effect == e }.reduce(0) { $0 + $1.per * Double(ringLevel($1)) }
    }

    // MARK: - Facturas

    var bill: BillDef { Content.bills[s.billIndex] }
    func billAmount(_ b: BillDef) -> Double {
        (b.amount * pow(Content.yearGrowth, Double(s.year)) * (1 - ringValue(.bills) / 100)).rounded()
    }
    var billAmount: Double { billAmount(bill) }
    var daysLeft: Int { s.billDue - s.day }      // 0 = hoy es el último día
    var nextBill: BillDef? { s.billIndex + 1 < Content.bills.count ? Content.bills[s.billIndex + 1] : nil }

    func payBill() {
        let a = billAmount
        guard s.cash >= a, !s.awaitingTaxChoice else { Sound.shared.denied(); return }
        s.cash -= a
        s.paidThisCycle += a
        s.stats.billsPaid += 1
        progressQuests(.facturas, add: 1)
        addXP((25 * Double(s.billIndex + 1)).rounded())
        Sound.shared.stamp()
        if s.billIndex == Content.bills.count - 1 {
            s.awaitingTaxChoice = true
            event = .taxes
        } else {
            s.billIndex += 1
            s.billDue = s.day + bill.days - 1 + Int(ringValue(.extraDays))
        }
        save()
    }

    /// tras pagar a Hacienda: otro año (facturas más caras, huchas más ricas)
    func anotherYear() {
        s.awaitingTaxChoice = false
        s.year += 1
        s.billIndex = 0
        s.billDue = s.day + bill.days - 1 + Int(ringValue(.extraDays))
        event = nil
        Sound.shared.till()
        save()
    }

    // MARK: - Bancarrota (prestigio)

    /// 1 punto de herencia por cada 50 € pagados en facturas
    var legacyGain: Double { floor(s.paidThisCycle / 50 * (1 + ringValue(.legacy) / 100)) }
    var startCash: Double {
        let l = ringValue(.startCash)
        return l > 0 ? 50 * pow(4, l - 1) : 0
    }

    func bankruptcy(forced: Bool = false) {
        let g = legacyGain
        s.legacy += g
        s.stats.bankruptcies += 1
        s.cash = 0
        s.day = 1; s.year = 0; s.billIndex = 0; s.paidThisCycle = 0
        s.hammer = 0; s.hammersOwned = [0]; s.skills = [:]
        s.awaitingTaxChoice = false
        recompute()
        s.cash = startCash
        s.billDue = 1 + Content.bills[0].days - 1 + Int(ringValue(.extraDays))
        event = forced ? .collector(legacy: g) : .bankrupt(legacy: g)
        forced ? Sound.shared.sad() : Sound.shared.fanfare()
        save()
    }

    // MARK: - El día

    func startDay() {
        guard !inRun, !s.awaitingTaxChoice else { return }
        recompute()
        inRun = true
        Sound.shared.click()
    }

    func finishDay(_ r: DayReport) {
        inRun = false
        s.stats.days += 1
        s.stats.broken += Double(r.broken); s.stats.swings += Double(r.swings); s.stats.crits += Double(r.crits)
        s.stats.golden += Double(r.golden); s.stats.kings += Double(r.kings)
        var r = r
        r.record = r.earned > s.stats.bestDay && s.stats.days > 1
        s.stats.bestDay = max(s.stats.bestDay, r.earned)
        s.stats.bestCombo = max(s.stats.bestCombo, Double(r.bestCombo))
        s.stats.frenzies += Double(r.frenzies)
        s.pendingChests += r.chests
        for c in r.coins { addCoin(c) }
        s.day += 1
        for (k, n) in r.byKind { s.brokenByKind[k, default: 0] += Double(n) }
        addPigXP(Double(r.broken))
        progressQuests(.romper, add: Double(r.broken))
        progressQuests(.ganar, add: r.earned)
        progressQuests(.combo, best: Double(r.bestCombo))
        progressQuests(.doradas, add: Double(r.golden))
        progressQuests(.criticos, add: Double(r.crits))
        progressQuests(.diaRico, best: r.earned)
        progressQuests(.frenesi, add: Double(r.frenzies))
        if s.tutorial < 9 { s.tutorial = 9 }
        report = r
        addXP(r.xp)
        refillQuests()
        startBankIfNeeded()
        save()
    }

    /// al cerrar el ticket del día: si la factura venció, viene el cobrador
    func afterReport() {
        report = nil
        guard s.day > s.billDue, !s.awaitingTaxChoice else { return }
        // la factura vencía ayer: se paga sola si llega el dinero; si no, viene el cobrador
        if s.cash >= billAmount { autoPaid = bill.company; payBill() }
        else { bankruptcy(forced: true) }
    }
    /// para enseñar el sello cuando una factura se paga sola
    var autoPaid: String? = nil

    /// dinero que entra durante el día (lo llama la mesa)
    func earn(_ v: Double) {
        s.cash += v
        s.stats.earned += v
    }

    // MARK: - Tienda

    func canBuy(_ k: SkillDef) -> Bool {
        let l = level(k)
        guard l < k.maxLevel else { return false }
        if let p = k.parent, (s.skills[p] ?? 0) == 0 { return false }
        return s.cash >= k.cost(l)
    }
    func isVisible(_ k: SkillDef) -> Bool { k.parent == nil || (s.skills[k.parent!] ?? 0) > 0 || level(k) > 0 }

    @discardableResult
    func buy(_ k: SkillDef) -> Bool {
        guard canBuy(k) else { Sound.shared.denied(); return false }
        s.cash -= k.cost(level(k))
        s.skills[k.id] = level(k) + 1
        progressQuests(.mejoras, add: 1)
        recompute()
        Sound.shared.coin()
        save()
        return true
    }

    func buyHammer(_ h: HammerDef) {
        if s.hammersOwned.contains(h.id) { s.hammer = h.id; recompute(); Sound.shared.click(); return }
        guard s.cash >= h.cost else { Sound.shared.denied(); return }
        s.cash -= h.cost
        s.hammersOwned.insert(h.id)
        s.hammer = h.id
        recompute()
        Sound.shared.till()
        save()
    }

    func buyRing(_ r: RingDef) {
        let l = ringLevel(r)
        guard l < r.maxLevel, s.legacy >= r.cost(l) else { Sound.shared.denied(); return }
        s.legacy -= r.cost(l)
        s.rings[r.id] = l + 1
        recompute()
        Sound.shared.till()
        save()
    }

    func pickSkin(_ k: SkinDef) {
        if s.skinsOwned.contains(k.id) { s.skin = k.id; Sound.shared.click(); save(); return }
        guard s.legacy >= k.cost else { Sound.shared.denied(); return }
        s.legacy -= k.cost
        s.skinsOwned.insert(k.id)
        s.skin = k.id
        Sound.shared.till()
        save()
    }

    // MARK: - Sobres y monedas

    func rollChest() -> Rarity {
        let luck = Double(stats.chestLuck)
        let w: [(Rarity, Double)] = [(.comun, 70), (.rara, 22 + luck * 2), (.epica, 7 + luck * 1.5), (.legendaria, 1 + luck * 0.5)]
        var r = Double.random(in: 0..<w.reduce(0) { $0 + $1.1 })
        for (k, x) in w { if r < x { return k }; r -= x }
        return .comun
    }

    private func randomCoin(_ rarities: [Rarity]) -> CoinDef {
        let pool = Content.coins.filter { rarities.contains($0.rarity) }
        return pool.randomElement() ?? Content.coins[0]
    }

    @discardableResult
    private func addCoin(_ id: String) -> (dup: Bool, legacy: Double) {
        guard let c = Content.coins.first(where: { $0.id == id }) else { return (false, 0) }
        let had = (s.coins[id] ?? 0) > 0
        s.coins[id] = (s.coins[id] ?? 0) + 1
        if had { s.legacy += c.rarity.duplicate; return (true, c.rarity.duplicate) }
        recompute()
        return (false, 0)
    }

    /// moneda que suelta una hucha dorada
    func goldenCoinDrop() -> String? {
        guard Double.random(in: 0..<1) < 0.25 else { return nil }
        let roll = Double.random(in: 0..<1)
        let r: [Rarity] = roll < 0.6 ? [.comun] : (roll < 0.9 ? [.rara] : (roll < 0.99 ? [.epica] : [.legendaria]))
        return randomCoin(r).id
    }

    /// abre el primer sobre pendiente
    func openChest() -> ChestPrize? {
        guard !s.pendingChests.isEmpty else { return nil }
        let rarity = s.pendingChests.removeFirst()
        let base = Content.pigValue(s.tier) * stats.loot
        var cash = 0.0
        var coin: CoinDef? = nil
        switch rarity {
        case .comun:
            cash = base * 25
        case .rara:
            cash = base * 80
            if Double.random(in: 0..<1) < 0.35 { coin = randomCoin([.comun, .rara]) }
        case .epica:
            cash = base * 250
            coin = randomCoin(Double.random(in: 0..<1) < 0.7 ? [.rara] : [.epica])
        case .legendaria:
            cash = base * 1_000
            coin = randomCoin(Double.random(in: 0..<1) < 0.7 ? [.epica] : [.legendaria])
        }
        s.cash += cash
        s.stats.earned += cash
        s.stats.chests += 1
        var dup = false, legacy = 0.0
        if let coin { (dup, legacy) = addCoin(coin.id) }
        save()
        return ChestPrize(rarity: rarity, cash: cash, coin: coin, duplicate: dup, legacy: legacy)
    }

    // MARK: - Ajustes

    func erase() {
        Persistence.erase()
        let settings = s.settings
        s = SaveState()
        s.settings = settings
        s.seenIntro = true
        s.tutorial = 9
        inRun = false; report = nil; event = nil
        recompute()
        save()
    }
}

extension String {
    /// cambia solo el primer «%» por el valor
    func filling(_ value: String) -> String {
        guard let r = range(of: "%") else { return self }
        return replacingCharacters(in: r, with: value)
    }
}
