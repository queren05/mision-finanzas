import SwiftUI

/// La mesa durante un día: huchas, martillazos, pedazos y monedas.
/// Es una clase normal (no observable) que se actualiza y se dibuja en cada fotograma desde un Canvas.
@MainActor
final class Desk {
    struct Pig {
        var id: Int
        var kind: PigKind
        var pos: CGPoint
        var vel: CGVector
        var hp: Double
        var maxHP: Double
        var value: Double
        var size: Double
        var born: Double
        var hitAt = -10.0
        var cracks: [[CGPoint]] = []
        var pupil = CGVector.zero
        var pupilVel = CGVector.zero
        var facing: Double = 1
        var wander = 0.0
        var dead = false
    }
    struct Shard { var pos: CGPoint; var vel: CGVector; var rot: Double; var spin: Double; var born: Double; var color: Color; var pts: [CGPoint]; var id = 0 }
    struct Loot { var pos: CGPoint; var vel: CGVector; var born: Double; var bill: Bool; var rot: Double; var id = 0 }
    struct Floater { var text: String; var pos: CGPoint; var born: Double; var color: Color; var size: Double; var id = 0 }
    struct Swing { var pos: CGPoint; var born: Double; var radius: Double; var hit: Bool; var crit: Bool }
    struct Blast { var pos: CGPoint; var born: Double; var radius: Double }

    let stats: HitStats
    let tier: Int
    let hammer: HammerDef
    let skin: SkinDef
    var pigs: [Pig] = []
    var shards: [Shard] = []
    var loot: [Loot] = []
    var floaters: [Floater] = []
    var swings: [Swing] = []
    var blasts: [Blast] = []
    var stamina: Double
    var time = 0.0
    var report: DayReport
    var finished = false
    var size = CGSize(width: 390, height: 700)
    /// zona de juego (sin el marcador de arriba ni la barra de abajo)
    var top: Double = 120
    var bottom: Double = 130

    private var lastDate: Date? = nil
    private var lastSwing = -10.0
    private var pending: CGPoint? = nil
    private var spawnTimer = 0.0
    private var nextId = 0
    private(set) var shake = 0.0
    private var hitStop = 0.0
    private var endAt: Double? = nil
    private var kingDone = false
    private var started = false
    /// para avisar a SwiftUI fuera del dibujado
    var onChange: (() -> Void)? = nil
    var onFinish: ((DayReport) -> Void)? = nil
    private(set) var dirty = false
    var earnedPending = 0.0
    /// combo: huchas rotas seguidas sin parar más de un momento
    private(set) var combo = 0
    private(set) var comboAt = -10.0
    private(set) var frenzyUntil = -10.0
    var frenzy: Bool { time < frenzyUntil }
    var comboMult: Double { 1 + Double(min(combo, 50)) * 0.04 }
    /// combo que hace falta para el primer frenesí del día
    var frenzyBase: Int { max(8, Desk.frenzyAt - stats.frenzyEarly) }
    var frenzyGain: Double { 2 + stats.frenzyMoney }
    static let comboWindow = 1.7
    static let frenzyAt = 25
    /// primera partida: enseña dónde tocar
    var tutorial = false
    private(set) var firstBreakAt: Double? = nil
    /// golpe de ahora: cuántas rompe (para no repetir sonidos ni parones)
    private var swingKills = 0
    private var swingEarned = 0.0
    private var swingPos = CGPoint.zero
    private var lastPop = -10.0
    private var nextPart = 0
    /// aguante que se puede recuperar en un día (para que las partidas terminen)
    private var regainLeft = 0.0
    private var nextFrenzy = Desk.frenzyAt
    /// imágenes ya preparadas para este fotograma
    private var frameImgs: [String: GraphicsContext.ResolvedImage] = [:]

    init(stats: HitStats, tier: Int, hammer: HammerDef, day: Int, skin: SkinDef = Content.skins[0]) {
        self.skin = skin
        self.stats = stats
        self.tier = tier
        self.hammer = hammer
        self.stamina = stats.stamina.rounded()
        self.regainLeft = (stats.stamina * 0.4).rounded()
        self.nextFrenzy = max(8, Desk.frenzyAt - stats.frenzyEarly)
        self.report = DayReport(day: day)
    }

    var cooldown: Double { 1 / stats.speed }
    var cooldownProgress: Double { min(1, (time - lastSwing) / cooldown) }

    // MARK: - Huchas

    private func pickKind() -> PigKind {
        if Double.random(in: 0..<1) < stats.golden { return .dorada }
        let pool = PigKind.allCases.filter { $0.weight > 0 && tier >= $0.minTier }
        var weights = pool.map { $0 == .gorda ? $0.weight * (1 + stats.fat * 10) : $0.weight }
        let total = weights.reduce(0, +)
        var r = Double.random(in: 0..<total)
        for (i, k) in pool.enumerated() { if r < weights[i] { return k }; r -= weights[i] }
        weights.removeAll()
        return .normal
    }

    private func spawn(_ forced: PigKind? = nil, at: CGPoint? = nil, scale: Double = 1) {
        let kind = forced ?? pickKind()
        let s = kind.size * 0.85 * scale
        var x = Double.random(in: s * 0.7...max(s * 0.7 + 1, size.width - s * 0.7))
        var y = Double.random(in: top + s * 0.5...max(top + s * 0.5 + 1, size.height - bottom - s * 0.5))
        if let at { x = at.x + Double.random(in: -30...30); y = at.y + Double.random(in: -20...20) }
        let a = Double.random(in: 0..<(2 * .pi))
        let hp = Content.pigHP(tier) * kind.hp
        nextId += 1
        pigs.append(Pig(id: nextId, kind: kind, pos: CGPoint(x: x, y: y),
                        vel: CGVector(dx: cos(a) * kind.speed, dy: sin(a) * kind.speed * 0.6),
                        hp: hp * scale, maxHP: hp * scale, value: Content.pigValue(tier) * kind.value * scale, size: s, born: time,
                        facing: cos(a) >= 0 ? 1 : -1, wander: Double.random(in: 0...6)))
        if time - lastPop > 0.15 && !frenzy { lastPop = time; Sound.shared.pop() }
    }

    // MARK: - Martillazo

    func tap(_ p: CGPoint) {
        guard !finished, stamina > 0 || frenzy, p.y > top - 30, p.y < size.height - bottom + 30 else { return }
        if time - lastSwing >= cooldown { swing(at: p) } else { pending = p }
    }

    private func swing(at p: CGPoint) {
        lastSwing = time
        pending = nil
        report.swings += 1
        if frenzy {
            // en frenesí los golpes no gastan
        } else if Double.random(in: 0..<1) >= stats.drainSave { stamina -= 1 }
        else { floaters.append(Floater(text: "¡Gratis!", pos: CGPoint(x: p.x, y: p.y - 40), born: time, color: Ink.green, size: 18)) }
        Sound.shared.swing()

        swingKills = 0
        swingEarned = 0
        swingPos = p
        let crit = Double.random(in: 0..<1) < stats.crit
        var hitAny = false
        let r = stats.radius
        var killed: [Int] = []
        for i in pigs.indices where !pigs[i].dead {
            let d = hypot(pigs[i].pos.x - p.x, pigs[i].pos.y - p.y)
            if d < r + pigs[i].size * 0.45 {
                hitAny = true
                if damage(i, base: stats.damage, crit: crit, at: p) { killed.append(i) }
            } else if stats.collateral > 0 && d < r * 2.2 + pigs[i].size * 0.45 {
                if damage(i, base: stats.damage * stats.collateral, crit: false, at: p, quiet: true) { killed.append(i) }
            }
        }
        swings.append(Swing(pos: p, born: time, radius: r, hit: hitAny, crit: crit))
        if hitAny {
            Sound.shared.hit(crit: crit)
            shake = max(shake, crit ? 9 : 4)
            if crit { report.crits += 1 }
        } else {
            Sound.shared.miss()
            shake = max(shake, 2)
        }
        for i in killed { breakPig(i) }
        pigs.removeAll { $0.dead }
        if swingKills > 0 {
            // un solo sonido, un solo parón y un solo número por golpe, aunque rompa veinte
            Sound.shared.smash(big: swingKills >= 4)
            if !frenzy { hitStop = max(hitStop, swingKills >= 6 ? 0.06 : 0.035) }
            shake = max(shake, min(16, 5 + Double(swingKills)))
            if swingKills >= 3 {
                floaters.append(Floater(text: "×\(swingKills)  +" + Fmt.money(swingEarned), pos: CGPoint(x: p.x, y: p.y - 70), born: time, color: Ink.gold, size: min(40, 26 + Double(swingKills))))
            }
            if Double.random(in: 0..<1) < stats.killStamina { regain(1, at: p) }
        }
        if stamina <= 0 && endAt == nil && !frenzy { endAt = time + 1.4 }
        markDirty()
    }

    /// devuelve true si la hucha se rompe
    private func damage(_ i: Int, base: Double, crit: Bool, at p: CGPoint, quiet: Bool = false) -> Bool {
        var d = base * (crit ? stats.critMult : 1)
        if pigs[i].hp >= pigs[i].maxHP { d *= 1 + stats.firstHit }
        if pigs[i].kind == .acorazada || pigs[i].kind == .robot { d *= min(1, 0.4 + stats.pierce) }
        pigs[i].hp -= d
        pigs[i].hitAt = time
        // los ojos dan un respingo
        pigs[i].pupilVel = CGVector(dx: Double.random(in: -60...60), dy: Double.random(in: -60...60))
        addCrack(i, from: p)
        if !quiet {
            floaters.append(Floater(text: (crit ? "¡ZAS! " : "") + "-" + Fmt.num(d.rounded(.up)),
                                    pos: CGPoint(x: pigs[i].pos.x + Double.random(in: -10...10), y: pigs[i].pos.y - pigs[i].size * 0.55),
                                    born: time, color: crit ? Ink.red : Ink.ink, size: crit ? 24 : 17))
        }
        return pigs[i].hp <= 0
    }

    private func addCrack(_ i: Int, from p: CGPoint) {
        guard pigs[i].cracks.count < 9 else { return }
        let s = pigs[i].size
        // punto de impacto en coordenadas de la hucha (normalizadas al tamaño)
        var sx = (p.x - pigs[i].pos.x) / s
        let sy = (p.y - pigs[i].pos.y) / s
        if pigs[i].facing < 0 { sx = -sx }
        var pt = CGPoint(x: max(-0.4, min(0.4, sx)), y: max(-0.3, min(0.3, sy)))
        var line = [pt]
        var ang = Double.random(in: 0..<(2 * .pi))
        for _ in 0..<Int.random(in: 3...5) {
            ang += Double.random(in: -0.9...0.9)
            pt = CGPoint(x: pt.x + cos(ang) * 0.1, y: pt.y + sin(ang) * 0.08)
            pt.x = max(-0.5, min(0.5, pt.x)); pt.y = max(-0.36, min(0.36, pt.y))
            line.append(pt)
        }
        pigs[i].cracks.append(line)
    }

    private func breakPig(_ i: Int) {
        guard !pigs[i].dead else { return }
        pigs[i].dead = true
        let pig = pigs[i]
        report.byKind[pig.kind.rawValue, default: 0] += 1
        combo += 1
        comboAt = time
        report.bestCombo = max(report.bestCombo, combo)
        if firstBreakAt == nil { firstBreakAt = time }
        if combo >= nextFrenzy && !frenzy {
            nextFrenzy = combo + frenzyBase + 12 * (report.frenzies + 1)
            frenzyUntil = time + 6 + stats.frenzyExtra
            report.frenzies += 1
            shake = max(shake, 12)
            Sound.shared.fanfare()
            floaters.append(Floater(text: "¡FRENESÍ!", pos: CGPoint(x: size.width / 2, y: top + 120), born: time, color: Ink.gold, size: 46))
        }
        report.xp += pig.kind == .rey ? 120 : (pig.kind == .dorada ? 12 : (pig.kind == .normal ? 1 : 2))
        var value = pig.value * stats.loot * comboMult * (frenzy ? frenzyGain : 1)
        var jackpot = false
        if Double.random(in: 0..<1) < stats.jackpot { value *= 20; jackpot = true }
        report.earned += value
        report.broken += 1
        earnedPending += value
        report.best = max(report.best, value)
        swingKills += 1
        swingEarned += value
        if pig.kind == .rey { hitStop = 0.12; shake = 16; Sound.shared.smash(big: true) }

        // pedazos de cerámica (menos cuantos más haya ya volando)
        let budget = shards.count > 140 ? 2 : (shards.count > 70 ? 5 : 10)
        for _ in 0..<(pig.kind == .rey ? 26 : budget) {
            let a = Double.random(in: 0..<(2 * .pi))
            let sp = Double.random(in: 120...420)
            let r = pig.size * Double.random(in: 0.08...0.18)
            let pts = (0..<3).map { k -> CGPoint in
                let b = Double(k) / 3 * 2 * .pi + Double.random(in: -0.4...0.4)
                return CGPoint(x: cos(b) * r, y: sin(b) * r)
            }
            shards.append(Shard(pos: pig.pos, vel: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 220), rot: 0,
                                spin: Double.random(in: -12...12), born: time,
                                color: shardColor(pig.kind), pts: pts))
        }
        // monedas y billetes que vuelan al marcador
        let n = loot.count > 60 ? 1 : (loot.count > 30 ? 2 : min(10, 3 + Int(log10(max(1, value)) * 1.4)))
        for k in 0..<n {
            let a = Double.random(in: -.pi...0)
            loot.append(Loot(pos: pig.pos, vel: CGVector(dx: cos(a) * Double.random(in: 80...260), dy: sin(a) * Double.random(in: 160...360)),
                             born: time + Double(k) * 0.015, bill: k % 3 == 2, rot: Double.random(in: 0...6)))
        }
        if floaters.count < 10 || jackpot {
            floaters.append(Floater(text: (jackpot ? "¡BOTE! " : "+") + Fmt.money(value), pos: CGPoint(x: pig.pos.x, y: pig.pos.y - 10),
                                    born: time, color: jackpot ? Ink.red : Ink.green, size: jackpot ? 30 : 23))
        }

        switch pig.kind {
        case .dorada:
            report.golden += 1
            if let c = Game.shared.goldenCoinDrop() {
                report.coins.append(c)
                let name = Content.coins.first { $0.id == c }?.name ?? "Moneda"
                floaters.append(Floater(text: "¡\(name)!", pos: CGPoint(x: pig.pos.x, y: pig.pos.y - 46), born: time + 0.15, color: Ink.purple, size: 20))
            }
        case .cristal:
            regain(stats.glass, at: pig.pos)
        case .bomba:
            explode(at: pig.pos, power: pig.maxHP)
        case .rey:
            report.kings += 1
        case .madre:
            for _ in 0..<3 { spawn(.normal, at: pig.pos, scale: 0.6) }
        case .lava:
            explode(at: pig.pos, power: pig.maxHP * 4)
        case .cosmica:
            if let c = Game.shared.goldenCoinDrop() { report.coins.append(c) }
        case .suerte:
            report.legacy += 1
            if floaters.count < 16 { floaters.append(Floater(text: "+1 herencia", pos: CGPoint(x: pig.pos.x, y: pig.pos.y - 46), born: time + 0.1, color: Ink.purple, size: 18)) }
        case .zombi:
            // vuelve a levantarse una vez, más pequeña
            if pig.size > PigKind.zombi.size * 0.8 { spawn(.zombi, at: pig.pos, scale: 0.7) }
        default: break
        }
        let chestChance = pig.kind == .arcoiris ? 0.7 : pig.kind == .cosmica ? 0.5 : stats.chest * (pig.kind == .dorada ? 6 : (pig.kind == .rey ? 30 : 1))
        if Double.random(in: 0..<1) < chestChance {
            let r = Game.shared.rollChest()
            report.chests.append(r)
            floaters.append(Floater(text: "¡Sobre \(r.name.lowercased())!", pos: CGPoint(x: pig.pos.x, y: pig.pos.y - 70), born: time + 0.2, color: r == .comun ? Ink.soft : r.color, size: 20))
        }
        if endAt != nil && stamina > 0 { endAt = nil }
    }

    private func shardColor(_ k: PigKind) -> Color {
        if skin.drawn || k.look != "normal" || skin.shards.isEmpty { return Bool.random() ? k.color : k.dark }
        return Color(hex: skin.shards.randomElement()!)
    }

    /// recuperar aguante, con tope por día
    private func regain(_ v: Double, at p: CGPoint) {
        // nunca por encima del aguante máximo
        let g = min(v, regainLeft, (stats.stamina - stamina).rounded(.down))
        guard g >= 1 else { return }
        regainLeft -= g
        stamina += g
        if floaters.count < 14 {
            floaters.append(Floater(text: "+\(Int(g)) aguante", pos: CGPoint(x: p.x + 20, y: p.y - 40), born: time + 0.1, color: Ink.blue, size: 17))
        }
    }

    private func explode(at p: CGPoint, power: Double) {
        blasts.append(Blast(pos: p, born: time, radius: 140))
        Sound.shared.boom()
        shake = max(shake, 14)
        var killed: [Int] = []
        for i in pigs.indices where !pigs[i].dead && hypot(pigs[i].pos.x - p.x, pigs[i].pos.y - p.y) < 140 {
            pigs[i].hp -= power * 1.5 * stats.bomb
            pigs[i].hitAt = time
            addCrack(i, from: p)
            if pigs[i].hp <= 0 { killed.append(i) }
        }
        for i in killed { breakPig(i) }
    }

    private func markDirty() {
        guard !dirty else { return }
        dirty = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.dirty = false
            self.onChange?()
        }
    }

    // MARK: - Bucle

    func frame(_ date: Date, size: CGSize) {
        self.size = size
        let raw = lastDate.map { date.timeIntervalSince($0) } ?? 0
        lastDate = date
        var dt = min(max(raw, 0), 1.0 / 20)
        if !started {
            started = true
            if ProcessInfo.processInfo.arguments.contains("-zoo") {
                for k in PigKind.allCases { spawn(k) }
            } else {
                for _ in 0..<stats.startPigs { spawn() }
            }
            spawnTimer = stats.spawnEvery
            if tier >= PigKind.rey.minTier && Double.random(in: 0..<1) < 0.25 + stats.king { kingDone = true; spawn(.rey) }
        }
        // parón de impacto: el tiempo casi se detiene un instante al romper
        if hitStop > 0 { hitStop -= dt; dt *= 0.08 }
        time += dt

        if let p = pending, time - lastSwing >= cooldown, stamina > 0 || frenzy { swing(at: p) }

        // aparecen huchas
        if stamina > 0 || frenzy {
            spawnTimer -= dt * (frenzy ? 4 : 1)
            if spawnTimer <= 0 {
                spawnTimer = stats.spawnEvery * Double.random(in: 0.7...1.3)
                if pigs.count < min(220, stats.maxPigs + (frenzy ? max(10, stats.maxPigs / 2) : 0)) { spawn() }
            }
        }
        if combo > 0 && time - comboAt > Desk.comboWindow && !frenzy { combo = 0; nextFrenzy = frenzyBase + 12 * report.frenzies }

        // se mueven
        for i in pigs.indices {
            var p = pigs[i]
            p.wander += dt
            if Int(p.wander * 10) % 23 == 0 && Double.random(in: 0..<1) < 0.04 {
                let a = Double.random(in: 0..<(2 * .pi))
                p.vel = CGVector(dx: cos(a) * p.kind.speed, dy: sin(a) * p.kind.speed * 0.6)
            }
            if p.kind == .fantasma && Double.random(in: 0..<1) < dt * 0.35 {
                p.pos = CGPoint(x: Double.random(in: p.size...max(p.size + 1, size.width - p.size)),
                                y: Double.random(in: top + p.size * 0.5...max(top + p.size * 0.5 + 1, size.height - bottom - p.size * 0.5)))
                p.born = time - 0.05
            }
            let slow = time - p.hitAt < 0.3 ? 0.2 : 1
            p.pos.x += p.vel.dx * dt * slow
            p.pos.y += p.vel.dy * dt * slow
            let mx = p.size * 0.6, my = p.size * 0.45
            if p.pos.x < mx { p.pos.x = mx; p.vel.dx = abs(p.vel.dx) }
            if p.pos.x > size.width - mx { p.pos.x = size.width - mx; p.vel.dx = -abs(p.vel.dx) }
            if p.pos.y < top + my { p.pos.y = top + my; p.vel.dy = abs(p.vel.dy) }
            if p.pos.y > size.height - bottom - my { p.pos.y = size.height - bottom - my; p.vel.dy = -abs(p.vel.dy) }
            if abs(p.vel.dx) > 2 { p.facing = p.vel.dx > 0 ? 1 : -1 }
            // ojos locos: un muelle que vuelve al centro con algo de temblor
            let k = 120.0, damp = 7.0
            p.pupilVel.dx += (-p.pupil.dx * k - p.pupilVel.dx * damp) * dt + Double.random(in: -30...30) * dt
            p.pupilVel.dy += (-p.pupil.dy * k - p.pupilVel.dy * damp) * dt + Double.random(in: -30...30) * dt
            p.pupil.dx += p.pupilVel.dx * dt; p.pupil.dy += p.pupilVel.dy * dt
            let m = hypot(p.pupil.dx, p.pupil.dy)
            if m > 1 { p.pupil.dx /= m; p.pupil.dy /= m }
            pigs[i] = p
        }

        for i in shards.indices {
            shards[i].vel.dy += 1100 * dt
            shards[i].pos.x += shards[i].vel.dx * dt
            shards[i].pos.y += shards[i].vel.dy * dt
            shards[i].rot += shards[i].spin * dt
        }
        shards.removeAll { time - $0.born > 1.1 }
        if shards.count > 180 { shards.removeFirst(shards.count - 180) }

        // monedas: saltan y luego vuelan hacia el contador de dinero
        let target = CGPoint(x: 70, y: 40)
        var arrived = 0
        for i in loot.indices {
            let age = time - loot[i].born
            if age < 0 { continue }
            if age < 0.35 {
                loot[i].vel.dy += 900 * dt
                loot[i].pos.x += loot[i].vel.dx * dt
                loot[i].pos.y += loot[i].vel.dy * dt
            } else {
                let k = min(1, (age - 0.35) * 3.2)
                loot[i].pos.x += (target.x - loot[i].pos.x) * k * 0.35
                loot[i].pos.y += (target.y - loot[i].pos.y) * k * 0.35
            }
            loot[i].rot += dt * 8
            if hypot(loot[i].pos.x - target.x, loot[i].pos.y - target.y) < 18 && age > 0.4 { loot[i].born = -100; arrived += 1 }
        }
        if arrived > 0 { Sound.shared.coin() }
        loot.removeAll { $0.born == -100 || time - $0.born > 2.5 }
        floaters.removeAll { time - $0.born > 1.1 }
        if floaters.count > 18 { floaters.removeFirst(floaters.count - 18) }
        swings.removeAll { time - $0.born > 0.45 }
        blasts.removeAll { time - $0.born > 0.6 }
        shake *= pow(0.0005, dt)

        // cada pedazo, moneda y número lleva su número para que no salten de dibujo
        for i in shards.indices where shards[i].id == 0 { nextPart += 1; shards[i].id = nextPart }
        for i in loot.indices where loot[i].id == 0 { nextPart += 1; loot[i].id = nextPart }
        for i in floaters.indices where floaters[i].id == 0 { nextPart += 1; floaters[i].id = nextPart }
        if stamina <= 0 && endAt == nil && !frenzy && !finished { endAt = time + 1.0 }
        if earnedPending > 0 { markDirty() }
        if let e = endAt, time >= e, !finished {
            finished = true
            let r = report
            DispatchQueue.main.async { [weak self] in self?.onFinish?(r) }
        }
    }

    /// terminar el día antes de tiempo
    func quit() {
        guard !finished else { return }
        stamina = 0
        endAt = time + 0.2
    }

    // MARK: - Dibujo

    func draw(_ ctx: inout GraphicsContext) {
        frameImgs.removeAll(keepingCapacity: true)
        let sx = Double.random(in: -shake...shake), sy = Double.random(in: -shake...shake)
        ctx.translateBy(x: sx, y: sy)
        drawDesk(&ctx)
        for b in blasts {
            let age = (time - b.born) / 0.6
            let r = b.radius * (0.3 + age * 0.9)
            ctx.fill(Path(ellipseIn: CGRect(x: b.pos.x - r, y: b.pos.y - r, width: r * 2, height: r * 2)), with: .color(Ink.gold.opacity(0.5 * (1 - age))))
            ctx.stroke(Path(ellipseIn: CGRect(x: b.pos.x - r, y: b.pos.y - r, width: r * 2, height: r * 2)), with: .color(Ink.ink.opacity(1 - age)), lineWidth: 4)
        }
        for p in pigs.sorted(by: { $0.pos.y < $1.pos.y }) { drawPig(&ctx, p) }
        for s in shards { drawShard(&ctx, s) }
        for sw in swings { drawSwing(&ctx, sw) }
        for l in loot where time >= l.born { drawLoot(&ctx, l) }
        for f in floaters where time >= f.born { drawFloater(&ctx, f) }
        drawCombo(&ctx)
        if tutorial { drawTutorial(&ctx) }
    }

    /// texto gordo con borde de tinta
    private func inkText(_ ctx: inout GraphicsContext, _ s: String, _ size: Double, _ color: Color, at p: CGPoint) {
        let t = ctx.resolve(Text(s).font(.chunky(size)).foregroundColor(Ink.ink))
        for (dx, dy) in [(-2.5, 0.0), (2.5, 0), (0, -2.5), (0, 2.5), (2, 3.5), (-2, 2.5)] { ctx.draw(t, at: CGPoint(x: p.x + dx, y: p.y + dy)) }
        ctx.draw(Text(s).font(.chunky(size)).foregroundColor(color), at: p)
    }

    private func drawCombo(_ c: inout GraphicsContext) {
        var ctx = c
        if frenzy {
            let left = (frenzyUntil - time) / 6
            let pulse = 0.12 + 0.06 * sin(time * 12)
            ctx.fill(Path(CGRect(x: -20, y: -20, width: size.width + 40, height: size.height + 40)), with: .color(Ink.gold.opacity(pulse)))
            let w = size.width * 0.6
            let r = CGRect(x: (size.width - w) / 2, y: top + 44, width: w, height: 12)
            ctx.fill(Path(roundedRect: r, cornerRadius: 6), with: .color(Ink.paper))
            ctx.fill(Path(roundedRect: CGRect(x: r.minX, y: r.minY, width: w * max(0, left), height: 12), cornerRadius: 6), with: .color(Ink.red))
            ctx.stroke(Path(roundedRect: r, cornerRadius: 6), with: .color(Ink.ink), lineWidth: 2.5)
        }
        guard combo >= 3 else { return }
        let since = time - comboAt
        let pop = 1 + 0.35 * exp(-since * 10)
        let y = top + 22
        let color: Color = combo >= 25 ? Ink.red : (combo >= 10 ? Ink.gold : Ink.paper)
        var t = ctx
        t.translateBy(x: size.width / 2, y: y)
        t.scaleBy(x: pop, y: pop)
        inkText(&t, "COMBO ×\(combo)", 26, color, at: CGPoint(x: 0, y: 0))
        inkText(&ctx, "dinero ×" + Fmt.dec(comboMult * (frenzy ? 2 : 1), 2), 15, Ink.paper, at: CGPoint(x: size.width / 2, y: y + 24))
        if !frenzy {
            let k = max(0, 1 - since / Desk.comboWindow)
            let w = 90.0
            let r = CGRect(x: size.width / 2 - w / 2, y: y + 36, width: w * k, height: 5)
            ctx.fill(Path(roundedRect: r, cornerRadius: 2.5), with: .color(Ink.paper.opacity(0.9)))
        }
    }

    /// la primera vez: un dedo señala dónde hay más huchas juntas
    private func drawTutorial(_ c: inout GraphicsContext) {
        var ctx = c
        if report.swings == 0, let p = bestCluster() {
            let k = 0.5 + 0.5 * sin(time * 5)
            let r = 46 + 10 * k
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(Ink.paper), style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
            inkText(&ctx, "¡Toca aquí!", 28, Ink.paper, at: CGPoint(x: p.x, y: p.y - r - 24))
            ctx.draw(Text("👆").font(.system(size: 44)), at: CGPoint(x: p.x + 14, y: p.y + 40 - 8 * k))
        } else if let f = firstBreakAt, time - f < 4 {
            inkText(&ctx, "Junta varias en cada golpe", 22, Ink.paper, at: CGPoint(x: size.width / 2, y: size.height - bottom - 70))
            inkText(&ctx, "Cada golpe gasta aguante ↓", 22, Ink.gold, at: CGPoint(x: size.width / 2, y: size.height - bottom - 36))
        }
    }

    func bestCluster() -> CGPoint? {
        var best: CGPoint? = nil
        var n = 0
        for p in pigs {
            let c = pigs.filter { hypot($0.pos.x - p.pos.x, $0.pos.y - p.pos.y) < stats.radius + 50 }.count
            if c > n { n = c; best = p.pos }
        }
        return best
    }

    private func drawDesk(_ ctx: inout GraphicsContext) {
        let w = size.width, h = size.height
        if let img = ItemArt.image("mesa", ext: "jpg") {
            // la imagen de la mesa ocupa toda la pantalla (sin deformarse)
            let k = max((w + 40) / 1179, (h + 40) / 2556)
            ctx.draw(img, in: CGRect(x: (w - 1179 * k) / 2, y: (h - 2556 * k) / 2, width: 1179 * k, height: 2556 * k))
            return
        }
        ctx.fill(Path(CGRect(x: -20, y: -20, width: w + 40, height: h + 40)), with: .color(Ink.wood))
    }

    private func drawPig(_ c: inout GraphicsContext, _ p: Pig) {
        if !skin.drawn, let img = resolved(&c, p.kind.look) {
            drawModel(&c, p, img)
            return
        }
        var ctx = c
        let s = p.size
        let age = time - p.born
        // aparece con un pequeño bote
        let pop = age < 0.3 ? max(0.01, 1 + 0.25 * sin(age / 0.3 * .pi) - (1 - age / 0.3) * (1 - age / 0.3) * 0.9) : 1
        // se aplasta al recibir el golpe
        let h = time - p.hitAt
        let sq = h < 0.35 ? exp(-h * 12) * cos(h * 40) * 0.22 : 0
        // sombra (no gira con la hucha)
        ctx.fill(Path(ellipseIn: CGRect(x: p.pos.x - s * 0.5 * pop, y: p.pos.y + s * 0.34, width: s * pop, height: s * 0.2 * pop)), with: .color(.black.opacity(0.22)))
        ctx.translateBy(x: p.pos.x, y: p.pos.y + s * 0.4)
        ctx.scaleBy(x: p.facing * pop * (1 + sq), y: pop * (1 - sq))
        ctx.translateBy(x: 0, y: -s * 0.4)
        let line = max(2.2, s * 0.045)
        let ink = GraphicsContext.Shading.color(Ink.ink)
        let body = p.kind.color, dark = p.kind.dark
        let bob = sin(time * (p.kind == .ruedas ? 30 : 10) + Double(p.id)) * s * 0.012

        // patas o ruedas
        if p.kind == .ruedas {
            for lx in [-0.3, 0.3] {
                let r = CGRect(x: s * lx - s * 0.11, y: s * 0.24, width: s * 0.22, height: s * 0.22)
                ctx.fill(Path(ellipseIn: r), with: .color(Ink.ink))
                ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.06, dy: s * 0.06)), with: .color(.gray))
            }
        } else {
            for (k, lx) in [-0.36, -0.14, 0.14, 0.36].enumerated() {
                let step = (p.kind.speed > 0 ? sin(time * 12 + Double(k) * 1.6) * s * 0.02 : 0)
                let r = CGRect(x: s * lx - s * 0.07, y: s * 0.24 + step, width: s * 0.14, height: s * 0.18)
                ctx.fill(Path(roundedRect: r, cornerRadius: s * 0.04), with: .color(dark))
                ctx.stroke(Path(roundedRect: r, cornerRadius: s * 0.04), with: ink, lineWidth: line * 0.8)
            }
        }
        // cola en espiral
        var tail = Path()
        tail.move(to: CGPoint(x: -s * 0.54, y: -s * 0.02 + bob))
        tail.addCurve(to: CGPoint(x: -s * 0.66, y: -s * 0.1), control1: CGPoint(x: -s * 0.66, y: s * 0.06), control2: CGPoint(x: -s * 0.72, y: -s * 0.04))
        tail.addCurve(to: CGPoint(x: -s * 0.6, y: -s * 0.14), control1: CGPoint(x: -s * 0.62, y: -s * 0.16), control2: CGPoint(x: -s * 0.58, y: -s * 0.14))
        ctx.stroke(tail, with: ink, style: StrokeStyle(lineWidth: line * 0.9, lineCap: .round))
        // cuerpo
        let bodyRect = CGRect(x: -s * 0.56, y: -s * 0.4 + bob, width: s * 1.12, height: s * 0.74)
        let shape = Path(ellipseIn: bodyRect)
        ctx.fill(shape, with: .color(body.opacity(p.kind == .cristal ? 0.8 : 1)))
        // brillo
        ctx.fill(Path(ellipseIn: CGRect(x: -s * 0.36, y: -s * 0.32 + bob, width: s * 0.36, height: s * 0.12)), with: .color(.white.opacity(p.kind == .cristal ? 0.7 : 0.35)))
        if p.kind == .dorada {
            let t = (time * 0.8 + Double(p.id)).truncatingRemainder(dividingBy: 2)
            var shine = Path()
            let x0 = -s * 0.6 + t * s * 0.7
            shine.move(to: CGPoint(x: x0, y: -s * 0.4)); shine.addLine(to: CGPoint(x: x0 + s * 0.12, y: -s * 0.4))
            shine.addLine(to: CGPoint(x: x0 - s * 0.05, y: s * 0.34)); shine.addLine(to: CGPoint(x: x0 - s * 0.17, y: s * 0.34))
            var clip = ctx
            clip.clip(to: shape)
            clip.fill(shine, with: .color(.white.opacity(0.55)))
        }
        if p.kind == .cristal {
            for k in 0..<3 {
                var l = Path()
                l.move(to: CGPoint(x: -s * 0.2 + Double(k) * s * 0.18, y: -s * 0.1 + bob))
                l.addLine(to: CGPoint(x: -s * 0.12 + Double(k) * s * 0.18, y: s * 0.18 + bob))
                ctx.stroke(l, with: .color(.white.opacity(0.8)), lineWidth: line * 0.6)
            }
        }
        // grietas
        var clip = ctx
        clip.clip(to: shape)
        for crack in p.cracks {
            var path = Path()
            for (k, pt) in crack.enumerated() {
                let q = CGPoint(x: pt.x * s, y: pt.y * s + bob)
                if k == 0 { path.move(to: q) } else { path.addLine(to: q) }
            }
            clip.stroke(path, with: ink, style: StrokeStyle(lineWidth: line * 0.75, lineCap: .round, lineJoin: .round))
        }
        ctx.stroke(shape, with: ink, lineWidth: line)
        // ranura para las monedas
        let slot = CGRect(x: -s * 0.16, y: -s * 0.43 + bob, width: s * 0.3, height: s * 0.07)
        ctx.fill(Path(roundedRect: slot, cornerRadius: s * 0.035), with: .color(Ink.ink))
        // oreja
        var ear = Path()
        ear.move(to: CGPoint(x: s * 0.08, y: -s * 0.33 + bob))
        ear.addLine(to: CGPoint(x: s * 0.2, y: -s * 0.56 + bob))
        ear.addLine(to: CGPoint(x: s * 0.3, y: -s * 0.3 + bob))
        ear.closeSubpath()
        ctx.fill(ear, with: .color(dark))
        ctx.stroke(ear, with: ink, style: StrokeStyle(lineWidth: line * 0.9, lineJoin: .round))
        // hocico
        let snout = CGRect(x: s * 0.42, y: -s * 0.1 + bob, width: s * 0.2, height: s * 0.24)
        ctx.fill(Path(ellipseIn: snout), with: .color(dark))
        ctx.stroke(Path(ellipseIn: snout), with: ink, lineWidth: line * 0.9)
        for ny in [-0.04, 0.05] {
            ctx.fill(Path(ellipseIn: CGRect(x: s * 0.5, y: s * ny - s * 0.02 + bob + s * 0.01, width: s * 0.045, height: s * 0.06)), with: ink)
        }
        // ojos saltones
        for (k, e) in [(0.18, -0.16, 0.11), (0.32, -0.19, 0.095)].enumerated() {
            let r = s * e.2
            let c0 = CGPoint(x: s * e.0, y: s * e.1 + bob)
            ctx.fill(Path(ellipseIn: CGRect(x: c0.x - r, y: c0.y - r, width: r * 2, height: r * 2)), with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: c0.x - r, y: c0.y - r, width: r * 2, height: r * 2)), with: ink, lineWidth: line * 0.75)
            let pr = r * 0.5
            let off = r * 0.45
            let px = c0.x + p.pupil.dx * off + (k == 0 ? 0 : 1)
            let py = c0.y + p.pupil.dy * off + r * 0.15
            ctx.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: ink)
        }
        // extras de cada tipo
        switch p.kind {
        case .acorazada:
            var helmet = Path()
            helmet.addArc(center: CGPoint(x: 0, y: -s * 0.16 + bob), radius: s * 0.46, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            helmet.closeSubpath()
            ctx.fill(helmet, with: .color(Color(hex: "#8f9399")))
            ctx.stroke(helmet, with: ink, lineWidth: line)
            for rx in [-0.25, 0, 0.25] {
                ctx.fill(Path(ellipseIn: CGRect(x: s * rx - s * 0.025, y: -s * 0.43 + bob, width: s * 0.05, height: s * 0.05)), with: ink)
            }
        case .bomba:
            var fuse = Path()
            fuse.move(to: CGPoint(x: -s * 0.05, y: -s * 0.4 + bob))
            fuse.addQuadCurve(to: CGPoint(x: -s * 0.2, y: -s * 0.62 + bob), control: CGPoint(x: s * 0.05, y: -s * 0.58 + bob))
            ctx.stroke(fuse, with: .color(Color(hex: "#c9a26b")), style: StrokeStyle(lineWidth: line * 1.2, lineCap: .round))
            let fl = s * (0.07 + 0.03 * sin(time * 30))
            ctx.fill(Path(ellipseIn: CGRect(x: -s * 0.2 - fl, y: -s * 0.62 + bob - fl, width: fl * 2, height: fl * 2)), with: .color(Ink.gold))
            ctx.fill(Path(ellipseIn: CGRect(x: -s * 0.2 - fl * 0.5, y: -s * 0.62 + bob - fl * 0.5, width: fl, height: fl)), with: .color(Ink.red))
        case .rey:
            var crown = Path()
            let cy = -s * 0.44 + bob
            crown.move(to: CGPoint(x: -s * 0.2, y: cy))
            for (k, x) in [-0.2, -0.13, -0.06, 0.01, 0.08, 0.15, 0.22].enumerated() {
                crown.addLine(to: CGPoint(x: s * x, y: cy - (k % 2 == 1 ? s * 0.18 : s * 0.05)))
            }
            crown.addLine(to: CGPoint(x: s * 0.22, y: cy))
            crown.closeSubpath()
            ctx.fill(crown, with: .color(Ink.gold))
            ctx.stroke(crown, with: ink, style: StrokeStyle(lineWidth: line * 0.8, lineJoin: .round))
        default: break
        }
        // vida
        if p.hp < p.maxHP {
            var bar = c
            let w = max(50, s * 0.8)
            let r = CGRect(x: p.pos.x - w / 2, y: p.pos.y - s * 0.66, width: w, height: 9)
            bar.fill(Path(roundedRect: r, cornerRadius: 4.5), with: .color(Ink.paper))
            bar.fill(Path(roundedRect: CGRect(x: r.minX, y: r.minY, width: w * max(0, p.hp / p.maxHP), height: 9), cornerRadius: 4.5), with: .color(Ink.red))
            bar.stroke(Path(roundedRect: r, cornerRadius: 4.5), with: ink, lineWidth: 2)
        }
    }

    private func item(_ c: inout GraphicsContext, _ name: String) -> GraphicsContext.ResolvedImage? {
        if let r = frameImgs["i:" + name] { return r }
        guard let img = ItemArt.image(name) else { return nil }
        let r = c.resolve(img)
        frameImgs["i:" + name] = r
        return r
    }

    private func resolved(_ c: inout GraphicsContext, _ look: String) -> GraphicsContext.ResolvedImage? {
        if let r = frameImgs[look] { return r }
        guard let img = SkinArt.image(skin.id, look) else { return nil }
        let r = c.resolve(img)
        frameImgs[look] = r
        return r
    }

    /// personaje 3D (imagen renderizada) que va dando saltitos por la mesa
    private func drawModel(_ c: inout GraphicsContext, _ p: Pig, _ img: GraphicsContext.ResolvedImage) {
        var ctx = c
        let s = p.size
        let age = time - p.born
        let pop = age < 0.3 ? max(0.01, 1 + 0.25 * sin(age / 0.3 * .pi) - (1 - age / 0.3) * (1 - age / 0.3) * 0.9) : 1
        let h = time - p.hitAt
        let sq = h < 0.35 ? exp(-h * 12) * cos(h * 40) * 0.22 : 0
        var dw = s * 1.5
        var dh = dw * skin.h / skin.w
        if dh > s * 1.35 { dh = s * 1.35; dw = dh * skin.w / skin.h }
        let wheels = p.kind == .ruedas
        let moving = hypot(p.vel.dx, p.vel.dy) > 2 && h > 0.3
        let ph = time * (p.kind == .bomba ? 11 : 8.5) + Double(p.id) * 1.7
        let up = abs(sin(ph))
        let hop = (wheels || !moving) ? 0 : up * s * 0.14
        let land = (!wheels && moving) ? max(0, 0.22 - up) * 0.4 : 0
        let breathe = moving ? 0 : sin(time * 3 + Double(p.id)) * 0.025
        let tilt = wheels ? -0.05 : (moving ? cos(ph) * 0.08 : 0)
        let feet = p.pos.y + s * 0.42
        // sombra: se encoge cuando salta
        let sw = dw * 0.62 * pop * (1 - hop / s * 1.6)
        ctx.fill(Path(ellipseIn: CGRect(x: p.pos.x - sw / 2, y: feet - sw * 0.1 + (wheels ? s * 0.12 : 0), width: sw, height: sw * 0.22)), with: .color(.black.opacity(0.22)))
        ctx.translateBy(x: p.pos.x, y: feet - hop)
        ctx.rotate(by: .radians(tilt * p.facing))
        ctx.scaleBy(x: p.facing * pop * (1 + sq + land), y: pop * (1 - sq - land + breathe))
        let ink = GraphicsContext.Shading.color(Ink.ink)
        let line = max(2.2, s * 0.045)
        // monopatín
        if wheels {
            let bw = dw * 0.86
            let wy = s * 0.02
            for wx in [-bw * 0.32, bw * 0.32] {
                let r = CGRect(x: wx - s * 0.06, y: wy + s * 0.03, width: s * 0.12, height: s * 0.12)
                ctx.fill(Path(ellipseIn: r), with: .color(Ink.ink))
                ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.03, dy: s * 0.03)), with: .color(.gray))
            }
            let board = Path(roundedRect: CGRect(x: -bw / 2, y: wy - s * 0.02, width: bw, height: s * 0.07), cornerRadius: s * 0.035)
            ctx.fill(board, with: .color(Color(hex: "#d9573b")))
            ctx.stroke(board, with: ink, lineWidth: line * 0.8)
        }
        let rect = CGRect(x: -dw / 2, y: -dh + (wheels ? s * 0.0 : s * 0.02), width: dw, height: dh)
        var ic = ctx
        switch p.kind {
        case .fantasma: ic.opacity = 0.45 + 0.15 * sin(time * 4 + Double(p.id))
        case .arcoiris: ic.addFilter(.hueRotation(.degrees(time * 160 + Double(p.id) * 40))); ic.addFilter(.saturation(1.6))
        case .diamante: ic.addFilter(.saturation(1.8)); ic.addFilter(.brightness(0.08))
        default: break
        }
        ic.draw(img, in: rect)
        // destello blanco al recibir el golpe (sin filtros, que son lentos)
        if h < 0.08 {
            var fl = ctx
            fl.blendMode = .plusLighter
            fl.opacity = 0.45
            fl.draw(img, in: rect)
        }
        // grietas (cortas, dentro del cuerpo) y brillo de la dorada
        if !p.cracks.isEmpty || p.kind == .dorada {
            var cl = ctx
            if p.kind == .dorada { cl.clipToLayer { l in l.draw(img, in: rect) } }
            for crack in p.cracks {
                var path = Path()
                for (k, pt) in crack.enumerated() {
                    let q = CGPoint(x: pt.x * s * 0.9, y: pt.y * s * 0.75 - s * 0.42)
                    if k == 0 { path.move(to: q) } else { path.addLine(to: q) }
                }
                cl.stroke(path, with: ink, style: StrokeStyle(lineWidth: line * 0.75, lineCap: .round, lineJoin: .round))
            }
            if p.kind == .dorada {
                let t = (time * 0.8 + Double(p.id)).truncatingRemainder(dividingBy: 2)
                var shine = Path()
                let x0 = -dw * 0.6 + t * dw * 0.8
                shine.move(to: CGPoint(x: x0, y: -dh)); shine.addLine(to: CGPoint(x: x0 + dw * 0.1, y: -dh))
                shine.addLine(to: CGPoint(x: x0 - dw * 0.08, y: 0)); shine.addLine(to: CGPoint(x: x0 - dw * 0.18, y: 0))
                cl.fill(shine, with: .color(.white.opacity(0.5)))
            }
        }
        // corona del rey o mecha de la bomba sobre la cabeza
        let hx = rect.minX + skin.head.x / skin.w * dw
        let hy = rect.minY + skin.head.y / skin.h * dh
        switch p.kind {
        case .rey:
            let cw = s * 0.42
            var crown = Path()
            let cy = hy + s * 0.04
            crown.move(to: CGPoint(x: hx - cw / 2, y: cy))
            for k in 0..<7 {
                let x = hx - cw / 2 + Double(k) * cw / 6
                crown.addLine(to: CGPoint(x: x, y: cy - (k % 2 == 1 ? s * 0.06 : s * 0.2)))
            }
            crown.addLine(to: CGPoint(x: hx + cw / 2, y: cy))
            crown.closeSubpath()
            ctx.fill(crown, with: .color(Ink.gold))
            ctx.stroke(crown, with: ink, style: StrokeStyle(lineWidth: line * 0.8, lineJoin: .round))
            for k in [1, 3, 5] {
                let x = hx - cw / 2 + Double(k) * cw / 6
                ctx.fill(Path(ellipseIn: CGRect(x: x - s * 0.02, y: cy - s * 0.1, width: s * 0.04, height: s * 0.04)), with: .color(Ink.red))
            }
        case .bomba:
            var fuse = Path()
            fuse.move(to: CGPoint(x: hx, y: hy + s * 0.04))
            fuse.addQuadCurve(to: CGPoint(x: hx - s * 0.14, y: hy - s * 0.2), control: CGPoint(x: hx + s * 0.1, y: hy - s * 0.16))
            ctx.stroke(fuse, with: .color(Ink.ink), style: StrokeStyle(lineWidth: line * 1.7, lineCap: .round))
            ctx.stroke(fuse, with: .color(Color(hex: "#c9a26b")), style: StrokeStyle(lineWidth: line * 1.0, lineCap: .round))
            let fl = s * (0.07 + 0.03 * sin(time * 30))
            let fp = CGPoint(x: hx - s * 0.14, y: hy - s * 0.2)
            ctx.fill(Path(ellipseIn: CGRect(x: fp.x - fl, y: fp.y - fl, width: fl * 2, height: fl * 2)), with: .color(Ink.gold))
            ctx.fill(Path(ellipseIn: CGRect(x: fp.x - fl * 0.5, y: fp.y - fl * 0.5, width: fl, height: fl)), with: .color(Ink.red))
        default: break
        }
        // vida
        if p.hp < p.maxHP {
            var bar = c
            let w = max(50, s * 0.8)
            let r = CGRect(x: p.pos.x - w / 2, y: feet - hop - dh * pop - 16, width: w, height: 9)
            bar.fill(Path(roundedRect: r, cornerRadius: 4.5), with: .color(Ink.paper))
            bar.fill(Path(roundedRect: CGRect(x: r.minX, y: r.minY, width: w * max(0, p.hp / p.maxHP), height: 9), cornerRadius: 4.5), with: .color(Ink.red))
            bar.stroke(Path(roundedRect: r, cornerRadius: 4.5), with: ink, lineWidth: 2)
        }
    }

    private func drawShard(_ c: inout GraphicsContext, _ s: Shard) {
        let age = time - s.born
        var ctx = c
        ctx.opacity = max(0, 1 - max(0, age - 0.8) * 2)
        ctx.translateBy(x: s.pos.x, y: s.pos.y)
        ctx.rotate(by: .radians(s.rot))
        var p = Path()
        p.addLines(s.pts); p.closeSubpath()
        ctx.fill(p, with: .color(s.color))
        ctx.stroke(p, with: .color(Ink.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
    }

    private func drawLoot(_ c: inout GraphicsContext, _ l: Loot) {
        var ctx = c
        ctx.translateBy(x: l.pos.x, y: l.pos.y)
        if l.bill {
            ctx.rotate(by: .radians(sin(l.rot) * 0.6))
            if let img = item(&c, "billete") { ctx.draw(img, in: CGRect(x: -17, y: -9, width: 34, height: 18)) }
        } else {
            ctx.scaleBy(x: max(0.15, abs(cos(l.rot))), y: 1)
            if let img = item(&c, "c_loot") { ctx.draw(img, in: CGRect(x: -11, y: -11, width: 22, height: 22)) }
        }
    }

    private func drawSwing(_ c: inout GraphicsContext, _ sw: Swing) {
        let age = time - sw.born
        var ctx = c
        // polvo del golpe
        if sw.hit || age < 0.25 {
            let k = min(1, age / 0.3)
            let r = sw.radius * (0.6 + 0.5 * k)
            var ring = ctx
            ring.opacity = 1 - k
            ring.stroke(Path(ellipseIn: CGRect(x: sw.pos.x - r, y: sw.pos.y - r * 0.6, width: r * 2, height: r * 1.2)),
                        with: .color(sw.crit ? Ink.red : Ink.paper), style: StrokeStyle(lineWidth: sw.crit ? 5 : 3, dash: [6, 7]))
            if sw.hit {
                for a in stride(from: 0.0, to: 2 * .pi, by: .pi / 4) {
                    var l = Path()
                    l.move(to: CGPoint(x: sw.pos.x + cos(a) * r * 0.5, y: sw.pos.y + sin(a) * r * 0.35))
                    l.addLine(to: CGPoint(x: sw.pos.x + cos(a) * r * 0.85, y: sw.pos.y + sin(a) * r * 0.55))
                    ring.stroke(l, with: .color(Ink.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
        }
        // el martillo: gira desde el mango y la cabeza cae justo donde has tocado
        let hh = 92.0
        let v = HammerArt.handle(hammer, height: hh)
        let final = -0.45
        let swingT = min(1, age / 0.07)
        let ang = final + (1 - swingT) * 1.25 + (sw.hit ? 0 : 0.12)
        // el final del mango se queda quieto
        let pivot = CGPoint(x: sw.pos.x + v.dx * cos(final) - v.dy * sin(final), y: sw.pos.y + v.dx * sin(final) + v.dy * cos(final))
        ctx.opacity = age > 0.3 ? max(0, 1 - (age - 0.3) / 0.15) : 1
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: .radians(ang))
        ctx.translateBy(x: -v.dx, y: -v.dy)
        HammerArt.draw(&ctx, hammer, height: hh)
    }

    private func drawFloater(_ c: inout GraphicsContext, _ f: Floater) {
        let age = time - f.born
        var ctx = c
        ctx.opacity = min(1, (1.1 - age) * 3)
        let y = f.pos.y - 70 * age + 30 * age * age
        let pop = age < 0.12 ? 0.6 + age / 0.12 * 0.5 : (age < 0.2 ? 1.1 - (age - 0.12) / 0.08 * 0.1 : 1)
        ctx.translateBy(x: f.pos.x, y: y)
        ctx.scaleBy(x: pop, y: pop)
        let t = Text(f.text).font(.chunky(f.size))
        // contorno de tinta para que se lea sobre cualquier cosa
        for (dx, dy) in [(-2.0, 0.0), (2, 0), (0, -2), (0, 2), (2, 3)] {
            ctx.draw(t.foregroundColor(Ink.ink), at: CGPoint(x: dx, y: dy))
        }
        ctx.draw(t.foregroundColor(f.color == Ink.ink ? Ink.paper : f.color), at: .zero)
    }
}

/// dibujo de cada martillo (se usa en la mesa y en la tienda)
/// los martillos son modelos 3D renderizados a imagen (Items/m_*.png)
@MainActor
enum HammerArt {
    /// ancho, alto y centro de la cabeza (en píxeles de la imagen)
    static let meta: [HammerStyle: (file: String, w: Double, h: Double, ax: Double, ay: Double)] = [
        .chancla: ("m_chancla", 179, 328, 81, 151),
        .toy: ("m_toy", 238, 341, 119, 78),
        .claw: ("m_claw", 246, 342, 152, 45),
        .mallet: ("m_mallet", 208, 340, 104, 76),
        .mace: ("m_mace", 158, 324, 79, 82),
        .jack: ("m_jack", 252, 336, 126, 135),
        .sledge: ("m_sledge", 222, 348, 111, 68),
        .thunder: ("m_thunder", 250, 349, 125, 87),
        .thunderGold: ("m_trueno_oro", 292, 357, 146, 98),
        .diamond: ("m_diamante", 228, 350, 114, 71),
        .cosmic: ("m_cosmico", 186, 320, 93, 93),
        .goldFlop: ("m_chancla_oro", 179, 328, 81, 151),
        .fire: ("m_fuego", 174, 327, 87, 93),
        .ice: ("m_hielo", 192, 345, 96, 72),
        .viking: ("m_vikingo", 140, 319, 81, 81),
        .anvil: ("m_yunque", 244, 348, 126, 74),
    ]
    static func image(_ h: HammerDef) -> Image? { ItemArt.image(meta[h.style]!.file) }

    /// dibuja el martillo con el mango hacia abajo; la cabeza queda en el origen
    static func draw(_ ctx: inout GraphicsContext, _ h: HammerDef, height: Double) {
        guard let img = image(h), let m = meta[h.style] else { return }
        let k = height / m.h
        ctx.draw(img, in: CGRect(x: -m.ax * k, y: -m.ay * k, width: m.w * k, height: m.h * k))
    }
    /// vector de la cabeza al final del mango (en puntos)
    static func handle(_ h: HammerDef, height: Double) -> CGVector {
        let m = meta[h.style]!
        let k = height / m.h
        return CGVector(dx: (m.w / 2 - m.ax) * k, dy: (m.h - m.ay) * k)
    }
}

/// imágenes de objetos (martillos, joyas, monedas), cargadas una vez
@MainActor
enum ItemArt {
    private static var cache: [String: Image] = [:]
    private static var ui: [String: UIImage] = [:]
    static func uiImage(_ name: String, ext: String = "png") -> UIImage? {
        if let i = ui[name] { return i }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext), let img = UIImage(contentsOfFile: url.path) else { return nil }
        ui[name] = img
        return img
    }
    static func image(_ name: String, ext: String = "png") -> Image? {
        if let i = cache[name] { return i }
        guard let u = uiImage(name, ext: ext) else { return nil }
        let i = Image(uiImage: u)
        cache[name] = i
        return i
    }
}

/// las imágenes de los personajes, cargadas una vez
@MainActor
enum SkinArt {
    private static var cache: [String: Image] = [:]
    private static var ui: [String: UIImage] = [:]
    static func uiImage(_ skin: String, _ look: String = "normal") -> UIImage? {
        let key = skin + "_" + look
        if let i = ui[key] { return i }
        guard let url = Bundle.main.url(forResource: key, withExtension: "png"), let img = UIImage(contentsOfFile: url.path) else { return nil }
        ui[key] = img
        return img
    }
    static func image(_ skin: String, _ look: String) -> Image? {
        let key = skin + "_" + look
        if let i = cache[key] { return i }
        guard let u = uiImage(skin, look) else { return nil }
        let i = Image(uiImage: u)
        cache[key] = i
        return i
    }
}
