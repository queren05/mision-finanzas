import SwiftUI
import Observation

struct ShootingStar: Identifiable, Equatable {
    let id = UUID()
    let born: Date
    let y: Double          // 0…1 de la altura
    let fromLeft: Bool
    let life: Double = 9
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: String
}

struct OfflineReport: Identifiable {
    let id = UUID()
    let away: Double
    let counted: Double
    let energy: Double
    let dark: Double
}

/// modificadores que salen de talentos e investigación (se recalculan en cada tic)
struct Mods {
    var tap = 1.0, production = 1.0
    var offlineHours = 2.0, offlineRate = 0.5
    var autoTap = 0.0, startEnergy = 0.0
    var starRate = 1.0, starPower = 1.0
    var cost = 1.0, dark = 1.0
    var achievementPct = 0.01, missions = 1.0
    var autoBuy = false, keepResearch = false
    var singularityPct = 0.02, crit = 0.04
}

/// El corazón del juego: estado, economía, bucle de juego y guardado.
@Observable
@MainActor
final class GameEngine {
    static let shared = GameEngine()

    var s: GameState
    private(set) var rps = 0.0          // energía por segundo (con todo)
    private(set) var tapValue = 1.0     // energía por toque (sin combo ni crítico)
    private(set) var darkRate = 0.0
    private(set) var mods = Mods()
    private(set) var combo = 1.0
    var star: ShootingStar? = nil
    var toasts: [Toast] = []
    var offline: OfflineReport? = nil

    @ObservationIgnored private var loop: Task<Void, Never>? = nil
    @ObservationIgnored private var lastTick = Date()
    @ObservationIgnored private var lastSave = Date()
    @ObservationIgnored private var recentTaps: [Date] = []
    @ObservationIgnored private var nextStar = Date().addingTimeInterval(45)
    @ObservationIgnored private var autoTapAcc = 0.0
    @ObservationIgnored private var autoBuyAcc = 0.0
    @ObservationIgnored private var checkAcc = 0.0

    private init() {
        s = Persistence.load() ?? GameState()
        applySettings()
        recompute()
        refillMissions()
    }

    func applySettings() {
        Feedback.shared.sound = s.settings.sound
        Feedback.shared.haptics = s.settings.haptics
        Fmt.scientific = s.settings.scientific
    }

    // MARK: - Ciclo de vida

    /// al abrir o volver a la app: calcula lo ganado sin conexión y arranca el bucle
    func resume() {
        applyOffline()
        start()
    }

    /// al salir: para el bucle (no gasta batería en segundo plano) y guarda
    func pause() {
        loop?.cancel(); loop = nil
        s.lastSeen = Date()
        save()
        Feedback.shared.stopAudio()
    }

    private func start() {
        guard loop == nil else { return }
        lastTick = Date()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)   // 10 tics por segundo; la animación va aparte a 60 fps
                self?.tick()
            }
        }
    }

    func save() {
        s.lastSeen = Date()
        Persistence.save(s)
        lastSave = Date()
    }

    private func applyOffline() {
        let now = Date()
        let away = now.timeIntervalSince(s.lastSeen)
        s.lastSeen = now
        lastTick = now
        s.buffs.removeAll { $0.until < now }
        recompute()
        guard away > 60 else { return }
        let counted = min(away, mods.offlineHours * 3600)
        let e = rps * counted * mods.offlineRate
        let d = darkRate * counted * mods.offlineRate
        guard e > 0 || d > 0 else { return }
        gain(e)
        s.dark += d; s.stats.darkAll += d
        offline = OfflineReport(away: away, counted: counted, energy: e, dark: d)
        nextStar = now.addingTimeInterval(20)
    }

    // MARK: - Bucle

    private func tick() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastTick), 0), 1)
        lastTick = now
        if s.buffs.contains(where: { $0.until < now }) { s.buffs.removeAll { $0.until < now } }
        recompute()

        gain(rps * dt)
        let d = darkRate * dt
        s.dark += d; s.stats.darkAll += d
        s.stats.playSeconds += dt
        s.stats.bestRps = max(s.stats.bestRps, rps)

        // el combo baja si dejas de tocar
        recentTaps.removeAll { now.timeIntervalSince($0) > 1.2 }
        let c = 1 + min(Double(recentTaps.count), 25) * 0.04
        if abs(c - combo) > 0.001 { combo = c }

        if mods.autoTap > 0 {
            autoTapAcc += mods.autoTap * dt
            if autoTapAcc >= 1 {
                let n = floor(autoTapAcc); autoTapAcc -= n
                gain(tapValue * n); s.stats.taps += n
            }
        }
        if mods.autoBuy {
            autoBuyAcc += dt
            if autoBuyAcc >= 2 { autoBuyAcc = 0; autoBuyCheapest() }
        }

        // estrellas fugaces
        if let st = star, now.timeIntervalSince(st.born) > st.life { star = nil; scheduleStar() }
        if star == nil && now >= nextStar {
            star = ShootingStar(born: now, y: Double.random(in: 0.12...0.42), fromLeft: Bool.random())
        }

        checkAcc += dt
        if checkAcc >= 0.5 { checkAcc = 0; checkAchievements() }
        if now.timeIntervalSince(lastSave) > 15 { save() }
    }

    private func gain(_ x: Double) {
        guard x > 0, x.isFinite else { return }
        s.energy += x
        s.stats.earnedRun += x; s.stats.earnedLayer += x; s.stats.earnedAll += x
    }

    // MARK: - Economía

    func level(_ r: ResearchDef) -> Int { s.research[r.id] ?? 0 }

    private func computeMods() -> Mods {
        var m = Mods()
        for t in Content.talents where s.talents.contains(t.id) {
            switch t.effect {
            case .tap(let x): m.tap *= x
            case .production(let x): m.production *= x
            case .offlineHours(let x): m.offlineHours += x
            case .offlineRate(let x): m.offlineRate += x
            case .autoTap(let x): m.autoTap += x
            case .startEnergy(let x): m.startEnergy = max(m.startEnergy, x)
            case .starRate(let x): m.starRate *= x
            case .starPower(let x): m.starPower *= x
            case .cost(let x): m.cost *= x
            case .dark(let x): m.dark *= x
            case .achievements(let x): m.achievementPct = 0.01 * x
            case .missions(let x): m.missions *= x
            case .autoBuy: m.autoBuy = true
            case .keepResearch: m.keepResearch = true
            case .singularityBonus(let x): m.singularityPct += x
            case .crit(let x): m.crit += x
            }
        }
        for r in Content.research {
            let l = Double(level(r))
            guard l > 0 else { continue }
            switch r.effect {
            case .production: m.production *= 1 + r.per * l
            case .tap: m.tap *= 1 + r.per * l
            case .cost: m.cost *= pow(1 - r.per, l)
            case .stars: m.starRate *= 1 + r.per * l
            case .dark: m.dark *= 1 + r.per * l
            case .offline: m.offlineHours += r.per * l
            case .crit: m.crit += r.per * l
            }
        }
        return m
    }

    func generatorMult(_ i: Int) -> Double {
        let n = s.owned[i]
        var m = pow(2, Double(Content.milestones.filter { n >= $0 }.count))
        for u in Content.upgradesByGen[i] where s.upgrades.contains(u.id) {
            if case .generator(_, let x) = u.effect { m *= x }
        }
        var syn = 0.0
        for u in Content.synergiesTo[i] where s.upgrades.contains(u.id) {
            if case .synergy(let from, _, let per) = u.effect { syn += per * Double(s.owned[from]) }
        }
        return m * (1 + syn)
    }

    /// multiplicador de toda la producción
    var globalMult: Double {
        var g = mods.production
        for u in Content.upgrades where s.upgrades.contains(u.id) { if case .global(let x) = u.effect { g *= x } }
        g *= 1 + Double(s.achievements.count) * mods.achievementPct
        g *= 1 + s.singEver * mods.singularityPct
        g *= pow(3, s.universes)
        for b in s.buffs where b.kind == .frenzy { g *= b.mult }
        return g
    }

    func generatorRate(_ i: Int) -> Double {
        Double(s.owned[i]) * Content.generators[i].baseProd * generatorMult(i)
    }

    private func recompute() {
        mods = computeMods()
        let g = globalMult
        var total = 0.0
        for i in Content.generators.indices where s.owned[i] > 0 { total += generatorRate(i) }
        rps = total * g

        var tapMult = mods.tap, share = 0.0, darkMult = mods.dark
        for u in Content.upgrades where s.upgrades.contains(u.id) {
            switch u.effect {
            case .tap(let x): tapMult *= x
            case .tapShare(let x): share += x
            case .dark(let x): darkMult *= x
            default: break
            }
        }
        var t = tapMult + rps * share
        for b in s.buffs where b.kind == .tapFrenzy { t *= b.mult }
        tapValue = t
        let totalOwned = Double(s.owned.reduce(0, +))
        darkRate = totalOwned > 0 ? 0.05 * sqrt(totalOwned) * darkMult * pow(1.5, s.universes) : 0
    }

    var totalOwned: Int { s.owned.reduce(0, +) }
    var critChance: Double { min(0.5, mods.crit) }

    func cost(_ i: Int, _ n: Int) -> Double {
        let g = Content.growth
        let base = Content.generators[i].baseCost * pow(g, Double(s.owned[i])) * mods.cost
        return base * (pow(g, Double(n)) - 1) / (g - 1)
    }

    func maxAffordable(_ i: Int) -> Int {
        let g = Content.growth
        let base = Content.generators[i].baseCost * pow(g, Double(s.owned[i])) * mods.cost
        let n = floor(log(s.energy * (g - 1) / base + 1) / log(g))
        return n.isFinite ? max(0, Int(n)) : 0
    }

    /// cuántos se comprarían con el selector actual (x1, x10, x100, máx.)
    func buyCount(_ i: Int) -> Int {
        s.settings.buyAmount == 0 ? max(1, maxAffordable(i)) : s.settings.buyAmount
    }

    /// el siguiente generador sin descubrir aparece cuando ya casi te lo puedes permitir
    func isRevealed(_ i: Int) -> Bool {
        i == 0 || s.owned[i] > 0 || s.owned[i - 1] > 0 || s.stats.earnedRun >= Content.generators[i].baseCost * 0.4
    }

    // MARK: - Acciones

    /// toque en la estrella: devuelve lo ganado y si ha sido crítico
    func tap() -> (value: Double, crit: Bool) {
        let now = Date()
        recentTaps.append(now)
        recentTaps.removeAll { now.timeIntervalSince($0) > 1.2 }
        combo = 1 + min(Double(recentTaps.count), 25) * 0.04
        s.stats.bestCombo = max(s.stats.bestCombo, combo)
        let crit = Double.random(in: 0..<1) < critChance
        let v = tapValue * combo * (crit ? 10 : 1)
        gain(v)
        s.stats.taps += 1
        Feedback.shared.tap(combo: combo, crit: crit)
        return (v, crit)
    }

    @discardableResult
    func buy(_ i: Int) -> Bool {
        let n = buyCount(i)
        let c = cost(i, n)
        guard n > 0, s.energy >= c else { Feedback.shared.denied(); return false }
        let before = Content.milestones.filter { s.owned[i] >= $0 }.count
        s.energy -= c
        s.owned[i] += n
        s.stats.bought += Double(n)
        recompute()
        Feedback.shared.buy()
        let after = Content.milestones.filter { s.owned[i] >= $0 }.count
        if after > before {
            toast("¡\(Content.generators[i].name) ×2!", "Has llegado a \(s.owned[i])", Content.generators[i].icon, Content.generators[i].color)
        }
        return true
    }

    private func autoBuyCheapest() {
        let candidates = Content.generators.indices.filter { isRevealed($0) }
        guard let i = candidates.min(by: { cost($0, 1) < cost($1, 1) }), s.energy >= cost(i, 1) else { return }
        s.energy -= cost(i, 1); s.owned[i] += 1; s.stats.bought += 1
        recompute()
    }

    func isUnlocked(_ u: UpgradeDef) -> Bool {
        s.stats.earnedRun >= u.unlock.earned && u.unlock.owned.allSatisfy { s.owned[$0.gen] >= $0.count }
    }

    /// mejoras a la venta, de la más barata a la más cara
    var availableUpgrades: [UpgradeDef] {
        Content.upgrades.filter { !s.upgrades.contains($0.id) && isUnlocked($0) }.sorted { $0.cost < $1.cost }
    }

    @discardableResult
    func buyUpgrade(_ u: UpgradeDef) -> Bool {
        guard !s.upgrades.contains(u.id), s.energy >= u.cost else { Feedback.shared.denied(); return false }
        s.energy -= u.cost
        s.upgrades.insert(u.id)
        s.stats.upgrades += 1
        recompute()
        Feedback.shared.upgrade()
        return true
    }

    func buyAllUpgrades() {
        var n = 0
        for u in availableUpgrades where s.energy >= u.cost {
            s.energy -= u.cost; s.upgrades.insert(u.id); s.stats.upgrades += 1; n += 1
        }
        if n > 0 { recompute(); Feedback.shared.upgrade(); toast("\(n) mejoras compradas", "La producción sube", "wand.and.stars", "#ffd36e") }
        else { Feedback.shared.denied() }
    }

    @discardableResult
    func buyResearch(_ r: ResearchDef) -> Bool {
        let l = level(r)
        let c = r.cost(l)
        guard l < r.maxLevel, s.dark >= c else { Feedback.shared.denied(); return false }
        s.dark -= c
        s.research[r.id] = l + 1
        recompute()
        Feedback.shared.upgrade()
        return true
    }

    // MARK: - Estrellas fugaces

    private func scheduleStar() {
        nextStar = Date().addingTimeInterval(Double.random(in: 60...150) / mods.starRate)
    }

    /// atrapar la estrella: premio al azar
    func catchStar() {
        guard star != nil else { return }
        star = nil
        scheduleStar()
        s.stats.stars += 1
        Feedback.shared.star()
        let p = mods.starPower
        let roll = Double.random(in: 0..<1)
        let now = Date()
        if roll < 0.45 {
            s.buffs.append(Buff(kind: .frenzy, mult: 7, until: now.addingTimeInterval(30 * p)))
            toast("¡Lluvia de estrellas!", "Producción ×7 durante \(Int(30 * p)) s", "sparkles", "#ffd36e")
        } else if roll < 0.8 {
            let v = max(min(s.energy * 0.15, rps * 900), 25) * p
            gain(v)
            toast("¡Polvo de estrellas!", "+\(Fmt.num(v)) de energía", "star.fill", "#ffd36e")
        } else if roll < 0.95 {
            s.buffs.append(Buff(kind: .tapFrenzy, mult: 77, until: now.addingTimeInterval(13 * p)))
            toast("¡Pulso cósmico!", "Toque ×77 durante \(Int(13 * p)) s. ¡Toca sin parar!", "hand.tap.fill", "#5ed9ff")
        } else {
            let d = (darkRate * 600 + 10) * p
            s.dark += d; s.stats.darkAll += d
            toast("¡Materia oscura!", "+\(Fmt.num(d))", "aqi.high", "#b17bff")
        }
        recompute()
    }

    // MARK: - Big Bang (primera capa de prestigio)

    /// singularidades que darías ahora
    var singularityGain: Double {
        let total = floor(cbrt(s.stats.earnedLayer / 1e9) * (1 + 0.5 * s.universes))
        return max(0, total - s.singEver)
    }

    /// energía que falta para la próxima singularidad
    var nextSingularityAt: Double {
        let k = 1 + 0.5 * s.universes
        let target = (s.singEver + singularityGain + 1) / k
        return max(0, pow(target, 3) * 1e9 - s.stats.earnedLayer)
    }

    func bigBang() {
        let g = singularityGain
        guard g >= 1 else { Feedback.shared.denied(); return }
        s.singularities += g; s.singEver += g; s.stats.singAll += g
        s.stats.bigBangs += 1
        resetRun()
        Feedback.shared.bigBang()
        toast("¡Big Bang!", "+\(Fmt.num(g)) singularidades", "burst.fill", "#ff7ad9")
        save()
    }

    private func resetRun() {
        s.energy = mods.startEnergy
        s.dark = 0
        s.owned = Array(repeating: 0, count: Content.generators.count)
        s.upgrades = []
        if !mods.keepResearch { s.research = [:] }
        s.buffs = []
        s.stats.earnedRun = 0
        star = nil
        recompute()
    }

    func canBuyTalent(_ t: TalentDef) -> Bool {
        !s.talents.contains(t.id) && t.requires.allSatisfy { s.talents.contains($0) } && s.singularities >= t.cost
    }
    func isTalentReachable(_ t: TalentDef) -> Bool { t.requires.allSatisfy { s.talents.contains($0) } }

    @discardableResult
    func buyTalent(_ t: TalentDef) -> Bool {
        guard canBuyTalent(t) else { Feedback.shared.denied(); return false }
        s.singularities -= t.cost
        s.talents.insert(t.id)
        recompute()
        Feedback.shared.achievement()
        toast(t.name, t.desc, t.icon, "#ff7ad9")
        save()
        return true
    }

    // MARK: - Multiverso (segunda capa)

    var universeGain: Double { max(0, floor(sqrt(s.stats.singAll / 1e4)) - s.stats.universes) }

    func multiverse() {
        let g = universeGain
        guard g >= 1 else { Feedback.shared.denied(); return }
        s.universes += g; s.stats.universes += g
        s.singularities = 0; s.singEver = 0; s.talents = []
        s.stats.earnedLayer = 0
        s.research = [:]
        recompute()
        resetRun()
        Feedback.shared.bigBang()
        toast("¡Nuevo universo!", "Producción ×3 por cada universo", "infinity", "#ffd36e")
        save()
    }

    // MARK: - Logros

    func progress(_ a: AchievementDef) -> Double {
        let v: Double
        switch a.kind {
        case .earned: v = s.stats.earnedAll
        case .taps: v = s.stats.taps
        case .owned(let i): v = Double(s.owned[i])
        case .totalOwned: v = Double(totalOwned)
        case .rps: v = s.stats.bestRps
        case .bigBangs: v = s.stats.bigBangs
        case .stars: v = s.stats.stars
        case .upgrades: v = s.stats.upgrades
        case .missions: v = s.stats.missions
        case .singularities: v = s.stats.singAll
        case .combo: v = s.stats.bestCombo
        case .universes: v = s.stats.universes
        }
        return min(1, v / a.goal)
    }

    private func checkAchievements() {
        for a in Content.achievements where !s.achievements.contains(a.id) && progress(a) >= 1 {
            s.achievements.insert(a.id)
            toast("Logro: \(a.name)", a.desc, a.icon, "#6ff0a8")
            Feedback.shared.achievement()
        }
    }

    // MARK: - Misiones

    func counter(_ k: MissionKind) -> Double {
        switch k {
        case .taps: return s.stats.taps
        case .buy: return s.stats.bought
        case .earn: return s.stats.earnedAll
        case .stars: return s.stats.stars
        case .upgrades: return s.stats.upgrades
        case .dark: return s.stats.darkAll
        }
    }

    func missionProgress(_ m: Mission) -> Double { min(1, max(0, counter(m.kind) - m.start) / m.goal) }

    func missionText(_ m: Mission) -> String {
        switch m.kind {
        case .taps: return "Toca la estrella \(Fmt.num(m.goal)) veces"
        case .buy: return "Compra \(Fmt.num(m.goal)) generadores"
        case .earn: return "Genera \(Fmt.num(m.goal)) de energía"
        case .stars: return m.goal == 1 ? "Atrapa una estrella fugaz" : "Atrapa \(Fmt.num(m.goal)) estrellas fugaces"
        case .upgrades: return "Compra \(Fmt.num(m.goal)) mejoras"
        case .dark: return "Reúne \(Fmt.num(m.goal)) de materia oscura"
        }
    }

    func missionIcon(_ k: MissionKind) -> String {
        switch k {
        case .taps: return "hand.tap.fill"
        case .buy: return "cart.fill"
        case .earn: return "bolt.fill"
        case .stars: return "star.fill"
        case .upgrades: return "wand.and.stars"
        case .dark: return "aqi.medium"
        }
    }

    var missionRewardEnergy: Double { max(rps * 300, 150) * mods.missions }
    var missionRewardDark: Double { max(darkRate * 180, 3) * mods.missions }

    private func newMission(excluding: Set<MissionKind>) -> Mission {
        var kinds = MissionKind.allCases.filter { !excluding.contains($0) }
        if darkRate <= 0 { kinds.removeAll { $0 == .dark } }
        if availableUpgrades.isEmpty && s.stats.upgrades < 1 { kinds.removeAll { $0 == .upgrades } }
        let k = kinds.randomElement() ?? .taps
        let level = 1 + s.stats.missions * 0.05
        let goal: Double
        switch k {
        case .taps: goal = (Double(Int.random(in: 6...20)) * 10 * level).rounded()
        case .buy: goal = (Double(Int.random(in: 5...20)) * level).rounded()
        case .earn: goal = max(500, rps * Double.random(in: 120...480))
        case .stars: goal = 1
        case .upgrades: goal = Double(Int.random(in: 1...3))
        case .dark: goal = max(5, darkRate * Double.random(in: 120...400)).rounded()
        }
        return Mission(kind: k, goal: goal, start: counter(k))
    }

    func refillMissions() {
        while s.missions.count < 3 {
            s.missions.append(newMission(excluding: Set(s.missions.map(\.kind))))
        }
    }

    func claim(_ m: Mission) {
        guard missionProgress(m) >= 1, let i = s.missions.firstIndex(of: m) else { return }
        let e = missionRewardEnergy, d = missionRewardDark
        gain(e); s.dark += d; s.stats.darkAll += d
        s.stats.missions += 1
        s.missions.remove(at: i)
        s.missions.insert(newMission(excluding: Set(s.missions.map(\.kind))), at: i)
        Feedback.shared.achievement()
        toast("¡Misión cumplida!", "+\(Fmt.num(e)) energía · +\(Fmt.num(d)) materia oscura", "flag.checkered", "#6ff0a8")
    }

    // MARK: - Avisos

    func toast(_ title: String, _ subtitle: String, _ icon: String, _ color: String) {
        let t = Toast(title: title, subtitle: subtitle, icon: icon, color: color)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            toasts.append(t)
            if toasts.count > 3 { toasts.removeFirst() }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation(.easeOut(duration: 0.3)) { self?.toasts.removeAll { $0.id == t.id } }
        }
    }

    // MARK: - Ajustes

    func eraseGame() {
        Persistence.erase()
        let settings = s.settings
        s = GameState()
        s.settings = settings
        star = nil; offline = nil
        recompute()
        refillMissions()
        save()
    }
}
