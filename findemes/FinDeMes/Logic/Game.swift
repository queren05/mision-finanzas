import SwiftUI
import Observation

/// lo que vale cada cosa con el martillo, las mejoras, las joyas y la colección de ahora
struct HitStats {
    var damage = 4.0
    var speed = 1.1
    var radius = 34.0
    var stamina = 40.0
    var killStamina = 0.0     // probabilidad de recuperar 1 al romper
    var drainSave = 0.0       // probabilidad de que un golpe no gaste
    var startPigs = 20
    var spawnEvery = 0.6
    var maxPigs = 30
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
    var frenzyExtra = 0.0
    var frenzyEarly = 0
    var frenzyMoney = 0.0
    var goldenValue = 1.0
    var chestValue = 1.0
    var comboCap = 50
    var comboTime = 0.0
    var pigXP = 1.0
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
    var legacy = 0.0
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
        Animal.use(Content.skin(s.skin))
        recompute()
        wake()
        refillQuests()
    }

    func applySettings() {
        Sound.shared.on = s.settings.sound
        Sound.shared.haptics = s.settings.haptics
        Music.shared.on = s.settings.music
    }

    func save() {
        s.lastPlayed = Date().timeIntervalSince1970
        Persistence.save(s)
    }

    // MARK: - Estadísticas

    func level(_ k: SkillDef) -> Int { s.skills[k.id] ?? 0 }
    func ringLevel(_ r: RingDef) -> Int { s.rings[r.id] ?? 0 }

    func recompute() {
        let h = Content.hammers[s.hammer]
        var st = HitStats()
        st.damage = h.damage; st.speed = h.speed; st.radius = h.radius
        var dmgPct = 0.0, speedPct = 0.0, radiusPct = 0.0, lootPct = 0.0, spawnPct = 0.0
        var dmgMul = 1.0, lootMul = 1.0
        for k in Content.skills {
            let l = Double(level(k))
            guard l > 0 else { continue }
            let v = k.value(Int(l))
            let m = v
            switch k.effect {
            case .pigXPMul: st.pigXP *= m
            case .goldenValue: st.goldenValue += v / 100
            case .chestValue: st.chestValue += v / 100
            case .firstHit: st.firstHit += v / 100
            case .comboCap: st.comboCap += Int(v)
            case .comboTime: st.comboTime += v
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
            case .fat: st.fat += v / 100
            case .bomb: st.bomb += v / 100
            case .king: st.king += v / 100
            case .glass: st.glass += v
            case .frenzyEarly: st.frenzyEarly += Int(v)
            case .frenzyTime: st.frenzyExtra += v
            case .frenzyMoney: st.frenzyMoney += v / 100
            }
        }
        for r in Content.rings {
            let l = Double(ringLevel(r))
            guard l > 0 else { continue }
            let v = r.per * l
            switch r.effect {
            case .lootMul: lootMul *= r.value(Int(l))
            case .damageMul: dmgMul *= r.value(Int(l))
            case .crit: st.crit += v / 100
            case .stamina: st.stamina += v
            case .golden: st.golden += v / 100
            case .chest: st.chest += v / 100; st.chestLuck += Int(l)
            case .startCash, .extraDays, .legacy, .bills, .keepTier, .startHammer, .autoBuy: break
            }
        }
        // las mejoras del martillo
        for p in Content.parts {
            let l = min(partLevel(p), p.maxLevel)
            guard l > 0 else { continue }
            let v = p.value(l)
            switch p.effect {
            case .damage: dmgPct += v
            case .loot: lootPct += v
            case .speed: speedPct += v
            }
        }
        // cada moneda de la colección da dinero para siempre
        for c in Content.coins where (s.coins[c.id] ?? 0) > 0 { lootPct += c.rarity.bonus * 100 }
        // cada nivel y cada logro dan +1 % de dinero, para siempre
        lootPct += Double(s.level - 1) + Double(s.achievements.count)
        st.damage *= (1 + dmgPct / 100) * dmgMul
        st.stamina = st.stamina.rounded()
        st.speed *= 1 + speedPct / 100
        st.radius *= 1 + radiusPct / 100
        // cada hipoteca pagada multiplica el dinero para siempre
        st.loot = (1 + lootPct / 100) * lootMul * Double(1 + s.richLevel)
        // cuanto más rápido salen, menos se nota cada mejora (si no, la mesa se desborda y el dinero se dispara)
        st.spawnEvery = 0.6 / (1 + spawnPct / 100).squareRoot()
        // la habilidad del martillo en la mano
        switch h.style {
        case .chancla: st.crit += 0.10
        case .toy: st.speed *= 1.25
        case .claw: st.pierce += 0.4
        case .mace: st.critMult += 1
        case .jack: st.drainSave += 0.25
        case .sledge: st.collateral += 0.35
        case .thunderGold: st.loot *= 2
        case .diamond: st.crit += 0.15; st.critMult += 2
        case .cosmic: st.frenzyEarly += 10
        case .goldFlop: st.loot *= 1.5; st.chest *= 2
        case .viking: st.crit += 0.25; st.critMult += 1.5
        case .plunger: st.maxPigs += 25; st.startPigs += 10
        case .swatter: st.speed *= 1.4
        case .pan: st.crit += 0.3; st.chest *= 3
        case .bat: st.radius *= 1.4; st.collateral += 0.6
        case .choco: st.loot *= 3
        default: break
        }
        // lo que trae la factura de ahora
        switch twist {
        case .none: break
        case .prisa: st.spawnEvery *= 0.7
        case .frenesi: st.frenzyEarly += 6
        case .gordas: st.fat += 0.3
        case .doradas: st.golden *= 2
        case .cansado: st.stamina = (st.stamina * 0.75).rounded(); st.loot *= 1.5
        case .rey: st.king += 0.75
        }
        stats = st
    }

    func ringValue(_ e: RingEffect) -> Double {
        Content.rings.filter { $0.effect == e }.reduce(0) { $0 + $1.per * Double(ringLevel($1)) }
    }

    // MARK: - Facturas

    var bill: BillDef { Content.bills[s.billIndex] }
    /// en vacas: la factura vale según lo que valía una vaca cuando llegó (la de ahora y las siguientes, según lo de ahora)
    func billAmount(_ b: BillDef) -> Double {
        let tier = b.id == s.billIndex ? s.billTier : s.tier
        let units = Content.billUnits(s.year * Content.bills.count + b.id) * (isInspection(b.id) ? 2 : 1)
        return max(1, (units * Content.pigValue(tier) / Content.pigValue(0) * (1 - ringValue(.bills) / 100)).rounded())
    }
    /// días que hay para pagar la factura de ahora (la inspección da uno más)
    var billDays: Int { bill.days + Int(ringValue(.extraDays)) + (inspection ? 1 : 0) }

    /// precios en vacas del nivel de ahora (el corcho y los martillos)
    func cost(_ k: SkillDef) -> Double {
        max(1, (k.cost(level(k)) * Content.pigValue(s.tier)).rounded())
    }
    func hammerCost(_ h: HammerDef) -> Double { (Content.hammerUnits(h.id) * Content.pigValue(s.tier)).rounded() }
    var billAmount: Double { billAmount(bill) }
    var daysLeft: Int { s.billDue - s.day }      // 0 = hoy es el último día
    var nextBill: BillDef? { s.billIndex + 1 < Content.bills.count ? Content.bills[s.billIndex + 1] : nil }

    func payBill() {
        let a = billAmount
        guard s.cash >= a, !s.awaitingTaxChoice else { Sound.shared.denied(); return }
        s.cash -= a
        // la inspección de Hacienda, si se paga, trae un sobre legendario
        if inspection { s.pendingChests.append(.legendaria) }
        s.paidThisCycle += a
        s.billsThisRun += 1
        s.stats.billsPaid += 1
        progressQuests(.facturas, add: 1)
        addXP((25 * Double(s.billIndex + 1)).rounded())
        Sound.shared.stamp()
        if s.billIndex == Content.bills.count - 1 {
            s.awaitingTaxChoice = true
            event = .taxes
        } else {
            s.billIndex += 1
            s.billTier = s.tier
            s.billDue = s.day + billDays - 1
        }
        save()
    }

    /// tras pagar a Hacienda: otro año (facturas más caras, huchas más ricas)
    func anotherYear() {
        s.awaitingTaxChoice = false
        s.year += 1
        s.billIndex = 0
        s.billTier = s.tier
        s.billDue = s.day + billDays - 1
        event = nil
        Sound.shared.till()
        save()
    }

    // MARK: - Bancarrota (prestigio)

    /// puntos de herencia: según el nivel de las huchas y las facturas pagadas en esta partida
    var legacyGain: Double {
        // crece mucho con cada factura pagada: llegar más lejos compensa de verdad
        let base = 8 * pow(1.12, Double(s.billsThisRun))
        return floor(base * (1 + ringValue(.legacy) / 100))
    }
    var startCash: Double {
        let l = ringValue(.startCash)
        return l > 0 ? 50 * pow(4, l - 1) : 0
    }

    func bankruptcy(forced: Bool = false) {
        let g = legacyGain
        // lo que quedaba en la cartera se lo lleva el banco: va a la hipoteca
        mortgageAdded = max(0, s.cash)
        addToMortgage(mortgageAdded)
        s.legacy += g
        s.stats.bankruptcies += 1
        s.cash = 0
        // cada partida las huchas vuelven a empezar (el huchario recuerda las descubiertas)
        s.day = 1; s.year = 0; s.billIndex = 0; s.paidThisCycle = 0; s.billsThisRun = 0; s.pigXP = 0
        // los recuerdos del abuelo ayudan a empezar: nivel de las huchas y martillos
        s.tier = Int(Double(s.bestTier) * ringValue(.keepTier) / 100)
        let hammers = min(Content.hammers.count - 1, Int(ringValue(.startHammer)))
        s.hammer = hammers; s.hammersOwned = Set(0...hammers); s.skills = [:]; s.parts = [:]
        s.awaitingTaxChoice = false
        recompute()
        s.cash = startCash
        s.billTier = s.tier
        s.billDue = billDays
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
        if ringValue(.autoBuy) > 0 && s.autoBuy { autoBuyAll() }
        report = r
        s.lastDayEarned = r.earned
        addXP(r.xp)
        refillQuests()
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
    /// la hipoteca recién pagada (nivel), lo ganado sin jugar, el número grande recién alcanzado
    /// y lo que fue a la hipoteca con la última bancarrota
    var finale: Int? = nil
    var away: AwayPrize? = nil
    var milestoneShow: Int? = nil
    var mortgageAdded = 0.0

    /// dinero que entra durante el día (lo llama la mesa)
    func earn(_ v: Double) {
        s.cash += v
        s.stats.earned += v
    }

    // MARK: - Tienda

    func canBuy(_ k: SkillDef) -> Bool {
        let l = level(k)
        guard l < k.maxLevel else { return false }
        if let p = SkillTree.main.parent[k.id], (s.skills[p] ?? 0) == 0 { return false }
        return s.cash >= cost(k)
    }
    func isVisible(_ k: SkillDef) -> Bool {
        guard let p = SkillTree.main.parent[k.id] else { return true }
        return (s.skills[p] ?? 0) > 0 || level(k) > 0
    }

    @discardableResult
    func buy(_ k: SkillDef, quiet: Bool = false) -> Bool {
        guard canBuy(k) else { if !quiet { Sound.shared.denied() }; return false }
        s.cash -= cost(k)
        s.skills[k.id] = level(k) + 1
        progressQuests(.mejoras, add: 1)
        recompute()
        // comprando muchas de golpe, se guarda y suena una sola vez al final
        if !quiet { Sound.shared.coin(); save() }
        return true
    }

    /// el cuñado contable: guarda para la factura si vence ya y gasta el resto en lo más barato
    func autoBuyAll() {
        let reserve = daysLeft <= 1 ? billAmount : 0
        var n = 0
        while n < 2_000 {
            let skill = Content.skills.filter { canBuy($0) }.min { cost($0) < cost($1) }
            let part = Content.parts.filter { canBuyPart($0) }.min { partCost($0) < partCost($1) }
            let sc = skill.map { cost($0) } ?? .infinity
            let pc = part.map { partCost($0) } ?? .infinity
            guard min(sc, pc) <= s.cash - reserve else { break }
            if sc <= pc, let k = skill { buy(k, quiet: true) } else if let p = part { buyPart(p, quiet: true) }
            n += 1
        }
    }

    func canGet(_ k: SkillDef) -> Bool { canBuy(k) }
    @discardableResult
    func get(_ k: SkillDef, quiet: Bool = false) -> Bool { buy(k, quiet: quiet) }
    func missing(_ k: SkillDef) -> Double { max(0, cost(k) - s.cash) }

    func buyHammer(_ h: HammerDef) {
        if s.hammersOwned.contains(h.id) { s.hammer = h.id; recompute(); Sound.shared.click(); return }
        guard s.cash >= hammerCost(h) else { Sound.shared.denied(); return }
        s.cash -= hammerCost(h)
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
        // los martillos del bisabuelo llegan al momento
        if r.effect == .startHammer { s.hammersOwned.formUnion(0...min(Content.hammers.count - 1, Int(ringValue(.startHammer)))) }
        recompute()
        Sound.shared.till()
        save()
    }

    /// los animales se ganan pagando facturas
    func hasSkin(_ k: SkinDef) -> Bool { s.skinsOwned.contains(k.id) || s.stats.billsPaid >= k.bills }
    func pickSkin(_ k: SkinDef) {
        guard hasSkin(k) else { Sound.shared.denied(); return }
        s.skinsOwned.insert(k.id); s.skin = k.id; Animal.use(k); Sound.shared.click(); save()
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
    private func addCoin(_ id: String, refresh: Bool = true) -> (dup: Bool, legacy: Double) {
        guard let c = Content.coins.first(where: { $0.id == id }) else { return (false, 0) }
        let had = (s.coins[id] ?? 0) > 0
        s.coins[id] = (s.coins[id] ?? 0) + 1
        // las repetidas se cambian por dinero (los puntos de herencia solo llegan con la bancarrota)
        if had {
            let v = (Content.pigValue(s.tier) * stats.loot * c.rarity.duplicate * 50).rounded()
            s.cash += v; s.stats.earned += v
            return (true, v)
        }
        if refresh { recompute() }
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
        let p = prize(rarity, refresh: true)
        save()
        return p
    }

    /// abre todos de una: se reparte en una copia y se guarda una sola vez (antes daba un tirón)
    func openAllChests() -> [ChestPrize] {
        let list = s.pendingChests
        guard !list.isEmpty else { return [] }
        s.pendingChests = []
        let out = list.map { prize($0, refresh: false) }
        recompute()
        save()
        return out
    }

    private func prize(_ rarity: Rarity, refresh: Bool) -> ChestPrize {
        let base = Content.pigValue(s.tier) * stats.loot * stats.chestValue
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
        if let coin { (dup, legacy) = addCoin(coin.id, refresh: refresh) }
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
