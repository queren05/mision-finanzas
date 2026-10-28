import Foundation

struct SpinResult: Equatable {
    let reels: [SlotSymbol]
    let won: Double
    let chest: Rarity?
}

struct ScratchCard: Equatable {
    let cells: [ScratchPrize?]   // nil = casilla vacía (una cruz)
    let prize: ScratchPrize?
}

@MainActor
extension Game {
    // MARK: - Mejoras del martillo

    func partLevel(_ p: PartDef) -> Int { s.parts[p.id] ?? 0 }

    /// en huchas del nivel de ahora: así siempre están al alcance
    func partCost(_ p: PartDef, _ l: Int? = nil) -> Double {
        let l = l ?? partLevel(p)
        return max(1, (Content.pigValue(s.tier) * p.base * pow(p.growth, Double(l))).rounded())
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

    /// compra niveles de una mejora hasta que no llegue el dinero
    func buyPartMax(_ p: PartDef) {
        var n = 0
        while n < 200, buyPart(p, quiet: true) { n += 1 }
        if n > 0 { Sound.shared.till(); save() } else { Sound.shared.denied() }
    }

    // MARK: - La feria

    var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    /// tres tiradas gratis al día; no se apuesta nada
    static let dailySpins = 3
    var freeSpins: Int { s.lastSpin != todayKey ? Game.dailySpins : max(0, Game.dailySpins - s.spinsToday) }

    func spin() -> SpinResult? {
        guard freeSpins > 0 else { Sound.shared.denied(); return nil }
        if s.lastSpin != todayKey { s.lastSpin = todayKey; s.spinsToday = 0 }
        s.spinsToday += 1
        s.stats.spins += 1
        let reels = (0..<3).map { _ in SlotSymbol.random() }
        // cada premio pequeño vale cinco huchas de las de ahora
        let unit = pigWorth * 5
        var won = 0.0
        var chest: Rarity? = nil
        if reels[0] == reels[1] && reels[1] == reels[2] {
            won = unit * reels[0].pays
            if reels[0] == .corona { chest = .legendaria; s.stats.jackpots += 1 }
            else if reels[0] == .anillo { chest = .epica }
        } else if Set(reels).count == 2 {
            won = unit
        }
        won = won.rounded()
        s.cash += won
        s.stats.earned += won
        if let chest { s.pendingChests.append(chest) }
        save()
        return SpinResult(reels: reels, won: won, chest: chest)
    }

    /// un rasca gratis al día
    var freeScratch: Bool { s.lastScratch != todayKey }

    func buyScratch() -> ScratchCard? {
        guard freeScratch else { Sound.shared.denied(); return nil }
        s.lastScratch = todayKey
        s.stats.scratches += 1
        save()
        // primero se decide el premio y luego se rellena la tarjeta
        var r = Double.random(in: 0..<1)
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
        let worth = Content.pigValue(s.tier) * stats.loot
        switch p {
        case .calderilla:
            let v = (worth * 120).rounded(); s.cash += v; s.stats.earned += v; Sound.shared.till(); save(); return Fmt.money(v)
        case .fajo:
            let v = (worth * 500).rounded(); s.cash += v; s.stats.earned += v; Sound.shared.till(); save(); return Fmt.money(v)
        case .sobreRaro: s.pendingChests.append(.rara)
        case .sobreEpico: s.pendingChests.append(.epica)
        case .sobreLegendario: s.pendingChests.append(.legendaria)
        case .herencia:
            let v = (worth * 2_500).rounded(); s.cash += v; s.stats.earned += v; Sound.shared.fanfare(); save(); return Fmt.money(v)
        }
        Sound.shared.fanfare()
        save()
        return p.name
    }
}
