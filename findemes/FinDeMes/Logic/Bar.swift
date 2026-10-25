import Foundation

struct SpinResult: Equatable {
    let reels: [SlotSymbol]
    let bet: Double
    let won: Double
    let chest: Rarity?
}

struct ScratchCard: Equatable {
    let cells: [ScratchPrize?]   // nil = casilla vacía (una cruz)
    let prize: ScratchPrize?
}

@MainActor
extension Game {
    // MARK: - Taller

    func partLevel(_ p: PartDef) -> Int { s.parts[p.id] ?? 0 }

    /// en huchas del nivel de ahora: así el taller siempre está al alcance
    func partCost(_ p: PartDef, _ l: Int? = nil) -> Double {
        let l = l ?? partLevel(p)
        let off = 1 - totemValue(.discount) * 0.05
        return max(1, (Content.pigValue(s.tier) * p.base * pow(p.growth, Double(l)) * off).rounded())
    }

    func canBuyPart(_ p: PartDef) -> Bool { partLevel(p) < p.maxLevel && s.cash >= partCost(p) }

    @discardableResult
    func buyPart(_ p: PartDef, quiet: Bool = false) -> Bool {
        guard canBuyPart(p) else { if !quiet { Sound.shared.denied() }; return false }
        s.cash -= partCost(p)
        s.parts[p.id] = partLevel(p) + 1
        recompute()
        if !quiet { Sound.shared.coin(); save() }
        return true
    }

    /// compra niveles de una pieza hasta que no llegue el dinero
    func buyPartMax(_ p: PartDef) {
        var n = 0
        while n < 200, buyPart(p, quiet: true) { n += 1 }
        if n > 0 { Sound.shared.till(); save() } else { Sound.shared.denied() }
    }

    /// compra lo más barato del taller una y otra vez
    func buyAllParts() {
        var n = 0
        while n < 1_000, let p = Content.parts.filter({ canBuyPart($0) }).min(by: { partCost($0) < partCost($1) }) {
            buyPart(p, quiet: true); n += 1
        }
        if n > 0 { Sound.shared.till(); save() } else { Sound.shared.denied() }
    }

    // MARK: - Tótems

    func totemLevel(_ t: TotemDef) -> Int { s.totems[t.id] ?? 0 }
    var activeTotems: [TotemDef] { Content.totems.filter { s.totemsOn.contains($0.id) && totemLevel($0) > 0 } }
    /// nivel del tótem puesto con ese efecto (0 si no está puesto)
    func totemValue(_ e: TotemEffect) -> Double { Double(activeTotems.first { $0.effect == e }.map { totemLevel($0) } ?? 0) }

    /// huecos para tótems: uno, otro en el nivel 15 y otro en el 35
    var totemSlots: Int { 1 + (s.level >= 15 ? 1 : 0) + (s.level >= 35 ? 1 : 0) + Int(familyValue(.totemSlot)) }
    static let totemSlotLevels = [1, 15, 35]

    func buyTotem(_ t: TotemDef) {
        let l = totemLevel(t)
        guard l < TotemDef.maxLevel, s.legacy >= t.cost(l) else { Sound.shared.denied(); return }
        s.legacy -= t.cost(l)
        s.totems[t.id] = l + 1
        // el primero que compras se pone solo si hay hueco
        if l == 0 && s.totemsOn.count < totemSlots { s.totemsOn.append(t.id) }
        recompute()
        Sound.shared.till()
        save()
    }

    func toggleTotem(_ t: TotemDef) {
        guard totemLevel(t) > 0 else { return }
        if let i = s.totemsOn.firstIndex(of: t.id) {
            s.totemsOn.remove(at: i)
        } else {
            guard s.totemsOn.count < totemSlots else { Sound.shared.denied(); return }
            s.totemsOn.append(t.id)
        }
        Sound.shared.click()
        recompute()
        save()
    }

    // MARK: - Mascotas

    func petLevel(_ p: PetDef) -> Int { s.pets[p.id] ?? 0 }

    func buyPet(_ p: PetDef) {
        let l = petLevel(p)
        guard l < PetDef.maxLevel, s.legacy >= p.cost(l) else { Sound.shared.denied(); return }
        s.legacy -= p.cost(l)
        s.pets[p.id] = l + 1
        if l == 0 { s.pet = p.id }
        recompute()
        Sound.shared.till()
        save()
    }

    func pickPet(_ p: PetDef) {
        guard petLevel(p) > 0 else { return }
        s.pet = s.pet == p.id ? "" : p.id
        Sound.shared.click()
        recompute()
        save()
    }

    // MARK: - El bar

    var casinoBoost: Double { 1 + totemValue(.casino) * 0.03 }

    func spin(bet: Double) -> SpinResult? {
        let bet = min(s.cash, bet.rounded())
        guard bet >= 1 else { Sound.shared.denied(); return nil }
        s.cash -= bet
        s.stats.spins += 1
        let reels = (0..<3).map { _ in SlotSymbol.random() }
        var won = 0.0
        var chest: Rarity? = nil
        if reels[0] == reels[1] && reels[1] == reels[2] {
            won = bet * reels[0].pays
            if reels[0] == .corona { chest = .legendaria; s.stats.jackpots += 1 }
            else if reels[0] == .anillo { chest = .epica }
        } else if Set(reels).count == 2 {
            // dos iguales: recuperas lo apostado
            won = bet
        }
        won = (won * casinoBoost).rounded()
        s.cash += won
        if let chest { s.pendingChests.append(chest) }
        if won > bet { s.stats.earned += won - bet }
        save()
        return SpinResult(reels: reels, bet: bet, won: won, chest: chest)
    }

    var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }
    /// rascas gratis de hoy (la tía lotera da más)
    var freeScratches: Int { s.lastScratch != todayKey ? 1 + Int(familyValue(.scratch)) : max(0, 1 + Int(familyValue(.scratch)) - s.scratchesToday) }
    var freeScratch: Bool { freeScratches > 0 }
    /// el rasca de pago vale lo mismo que 60 huchas de las de ahora
    var scratchPrice: Double { max(5, (Content.pigValue(s.tier) * 60).rounded()) }

    func buyScratch() -> ScratchCard? {
        if freeScratch {
            if s.lastScratch != todayKey { s.lastScratch = todayKey; s.scratchesToday = 0 }
            s.scratchesToday += 1
        } else {
            guard s.cash >= scratchPrice else { Sound.shared.denied(); return nil }
            s.cash -= scratchPrice
        }
        s.stats.scratches += 1
        save()
        // primero se decide el premio y luego se rellena la tarjeta
        var r = Double.random(in: 0..<1) / casinoBoost
        var prize: ScratchPrize? = nil
        for p in ScratchPrize.allCases.reversed() { if r < p.chance { prize = p; break }; r -= p.chance }
        var cells: [ScratchPrize?] = []
        if let prize { cells += [prize, prize, prize] }
        // el resto, sin que se repita nada tres veces
        let others = ScratchPrize.allCases.filter { $0 != prize }
        var count: [ScratchPrize: Int] = [:]
        while cells.count < 9 {
            if Double.random(in: 0..<1) < 0.2 { cells.append(nil); continue }
            let o = others.randomElement()!
            if count[o, default: 0] < 2 { count[o, default: 0] += 1; cells.append(o) }
        }
        return ScratchCard(cells: cells.shuffled(), prize: prize)
    }

    /// cobra el premio del rasca; devuelve el texto de lo ganado
    func claimScratch(_ p: ScratchPrize?) -> String {
        guard let p else { return "" }
        let worth = Content.pigValue(s.tier) * stats.loot * casinoBoost
        switch p {
        case .calderilla:
            let v = (worth * 120).rounded(); s.cash += v; s.stats.earned += v; Sound.shared.till(); save(); return Fmt.money(v)
        case .fajo:
            let v = (worth * 500).rounded(); s.cash += v; s.stats.earned += v; Sound.shared.till(); save(); return Fmt.money(v)
        case .sobreRaro: s.pendingChests.append(.rara)
        case .sobreEpico: s.pendingChests.append(.epica)
        case .sobreLegendario: s.pendingChests.append(.legendaria)
        case .herencia:
            let v = Double(5 + s.bestTier / 4); s.legacy += v; Sound.shared.fanfare(); save(); return "+\(Fmt.num(v)) puntos de herencia"
        }
        Sound.shared.fanfare()
        save()
        return p.name
    }
}

// MARK: - Carreras

struct Racer {
    let name: String
    let kind: PigKind
    let chance: Double
    /// lo que paga por lo apostado (la casa se queda un 8 %)
    var pays: Double { (0.92 / chance * 10).rounded() / 10 }
}

struct RaceResult: Equatable {
    let order: [Int]          // quién llega primero, segundo…
    let pick: Int
    let bet: Double
    let won: Double
}

extension Content {
    static let racers: [Racer] = [
        Racer(name: "Leche Rápida", kind: .ruedas, chance: 0.38),
        Racer(name: "La Pinta", kind: .normal, chance: 0.25),
        Racer(name: "Doña Ubre", kind: .gorda, chance: 0.18),
        Racer(name: "Rayo Lechero", kind: .ninja, chance: 0.12),
        Racer(name: "Vaca de Oro", kind: .dorada, chance: 0.07),
    ]
}

@MainActor
extension Game {
    func race(bet: Double, pick: Int) -> RaceResult? {
        let bet = min(s.cash, bet.rounded())
        guard bet >= 1 else { Sound.shared.denied(); return nil }
        s.cash -= bet
        s.races += 1
        // el orden de llegada: cada puesto se sortea entre los que quedan, según su suerte
        var left = Array(Content.racers.indices)
        var order: [Int] = []
        while !left.isEmpty {
            var r = Double.random(in: 0..<left.reduce(0) { $0 + Content.racers[$1].chance })
            var picked = left[left.count - 1]
            for i in left { if r < Content.racers[i].chance { picked = i; break }; r -= Content.racers[i].chance }
            order.append(picked)
            left.removeAll { $0 == picked }
        }
        var won = 0.0
        if order[0] == pick { won = (bet * Content.racers[pick].pays * casinoBoost).rounded() }
        s.cash += won
        if won > bet { s.stats.earned += won - bet }
        save()
        return RaceResult(order: order, pick: pick, bet: bet, won: won)
    }
}
