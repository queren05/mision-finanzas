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
    struct Shard { var pos: CGPoint; var vel: CGVector; var rot: Double; var spin: Double; var born: Double; var color: Color; var pts: [CGPoint] }
    struct Loot { var pos: CGPoint; var vel: CGVector; var born: Double; var bill: Bool; var rot: Double }
    struct Floater { var text: String; var pos: CGPoint; var born: Double; var color: Color; var size: Double }
    struct Swing { var pos: CGPoint; var born: Double; var radius: Double; var hit: Bool; var crit: Bool }
    struct Blast { var pos: CGPoint; var born: Double; var radius: Double }

    let stats: HitStats
    let tier: Int
    let hammer: HammerDef
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
    private var shake = 0.0
    private var hitStop = 0.0
    private var endAt: Double? = nil
    private var kingDone = false
    private var started = false
    /// para avisar a SwiftUI fuera del dibujado
    var onChange: (() -> Void)? = nil
    var onFinish: ((DayReport) -> Void)? = nil
    private(set) var dirty = false
    var earnedPending = 0.0

    init(stats: HitStats, tier: Int, hammer: HammerDef, day: Int) {
        self.stats = stats
        self.tier = tier
        self.hammer = hammer
        self.stamina = stats.stamina.rounded()
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

    private func spawn(_ forced: PigKind? = nil) {
        let kind = forced ?? pickKind()
        let s = kind.size
        let x = Double.random(in: s * 0.7...max(s * 0.7 + 1, size.width - s * 0.7))
        let y = Double.random(in: top + s * 0.5...max(top + s * 0.5 + 1, size.height - bottom - s * 0.5))
        let a = Double.random(in: 0..<(2 * .pi))
        let hp = Content.pigHP(tier) * kind.hp
        nextId += 1
        pigs.append(Pig(id: nextId, kind: kind, pos: CGPoint(x: x, y: y),
                        vel: CGVector(dx: cos(a) * kind.speed, dy: sin(a) * kind.speed * 0.6),
                        hp: hp, maxHP: hp, value: Content.pigValue(tier) * kind.value, size: s, born: time,
                        facing: cos(a) >= 0 ? 1 : -1, wander: Double.random(in: 0...6)))
        Sound.shared.pop()
    }

    // MARK: - Martillazo

    func tap(_ p: CGPoint) {
        guard !finished, stamina > 0, p.y > top - 30, p.y < size.height - bottom + 30 else { return }
        if time - lastSwing >= cooldown { swing(at: p) } else { pending = p }
    }

    private func swing(at p: CGPoint) {
        lastSwing = time
        pending = nil
        report.swings += 1
        if Double.random(in: 0..<1) >= stats.drainSave { stamina -= 1 }
        else { floaters.append(Floater(text: "¡Gratis!", pos: CGPoint(x: p.x, y: p.y - 40), born: time, color: Ink.green, size: 18)) }
        Sound.shared.swing()

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
        if stamina <= 0 && endAt == nil { endAt = time + 1.4 }
        markDirty()
    }

    /// devuelve true si la hucha se rompe
    private func damage(_ i: Int, base: Double, crit: Bool, at p: CGPoint, quiet: Bool = false) -> Bool {
        var d = base * (crit ? stats.critMult : 1)
        if pigs[i].hp >= pigs[i].maxHP { d *= 1 + stats.firstHit }
        if pigs[i].kind == .acorazada { d *= min(1, 0.4 + stats.pierce) }
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
        var value = pig.value * stats.loot
        var jackpot = false
        if Double.random(in: 0..<1) < stats.jackpot { value *= 20; jackpot = true }
        report.earned += value
        report.broken += 1
        earnedPending += value
        report.best = max(report.best, value)
        hitStop = pig.kind == .rey ? 0.12 : 0.045
        shake = max(shake, pig.kind == .rey ? 16 : 7)
        Sound.shared.smash(big: pig.kind == .rey || pig.kind == .gorda)

        // pedazos de cerámica
        for _ in 0..<(pig.kind == .rey ? 26 : 14) {
            let a = Double.random(in: 0..<(2 * .pi))
            let sp = Double.random(in: 120...420)
            let r = pig.size * Double.random(in: 0.08...0.18)
            let pts = (0..<3).map { k -> CGPoint in
                let b = Double(k) / 3 * 2 * .pi + Double.random(in: -0.4...0.4)
                return CGPoint(x: cos(b) * r, y: sin(b) * r)
            }
            shards.append(Shard(pos: pig.pos, vel: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 220), rot: 0,
                                spin: Double.random(in: -12...12), born: time,
                                color: Bool.random() ? pig.kind.color : pig.kind.dark, pts: pts))
        }
        // monedas y billetes que vuelan al marcador
        let n = min(14, 3 + Int(log10(max(1, value)) * 1.6))
        for k in 0..<n {
            let a = Double.random(in: -.pi...0)
            loot.append(Loot(pos: pig.pos, vel: CGVector(dx: cos(a) * Double.random(in: 80...260), dy: sin(a) * Double.random(in: 160...360)),
                             born: time + Double(k) * 0.015, bill: k % 3 == 2, rot: Double.random(in: 0...6)))
        }
        floaters.append(Floater(text: (jackpot ? "¡BOTE! " : "+") + Fmt.money(value), pos: CGPoint(x: pig.pos.x, y: pig.pos.y - 10),
                                born: time, color: jackpot ? Ink.red : Ink.green, size: jackpot ? 30 : 23))

        switch pig.kind {
        case .dorada:
            report.golden += 1
            if let c = Game.shared.goldenCoinDrop() {
                report.coins.append(c)
                let name = Content.coins.first { $0.id == c }?.name ?? "Moneda"
                floaters.append(Floater(text: "¡\(name)!", pos: CGPoint(x: pig.pos.x, y: pig.pos.y - 46), born: time + 0.15, color: Ink.purple, size: 20))
            }
        case .cristal:
            stamina += stats.glass
            floaters.append(Floater(text: "+\(Int(stats.glass)) aguante", pos: CGPoint(x: pig.pos.x, y: pig.pos.y - 46), born: time + 0.1, color: Ink.blue, size: 18))
        case .bomba:
            explode(at: pig.pos, power: pig.maxHP)
        case .rey:
            report.kings += 1
        default: break
        }
        if Double.random(in: 0..<1) < stats.killStamina {
            stamina += 1
            floaters.append(Floater(text: "+1 aguante", pos: CGPoint(x: pig.pos.x + 30, y: pig.pos.y - 30), born: time + 0.1, color: Ink.blue, size: 16))
        }
        let chestChance = stats.chest * (pig.kind == .dorada ? 6 : (pig.kind == .rey ? 30 : 1))
        if Double.random(in: 0..<1) < chestChance {
            let r = Game.shared.rollChest()
            report.chests.append(r)
            floaters.append(Floater(text: "¡Sobre \(r.name.lowercased())!", pos: CGPoint(x: pig.pos.x, y: pig.pos.y - 70), born: time + 0.2, color: r == .comun ? Ink.soft : r.color, size: 20))
        }
        if endAt != nil && stamina > 0 { endAt = nil }
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
        DispatchQueue.main.async { [weak self] in
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
            for _ in 0..<stats.startPigs { spawn() }
            spawnTimer = stats.spawnEvery
            if tier >= PigKind.rey.minTier && Double.random(in: 0..<1) < 0.25 + stats.king { kingDone = true; spawn(.rey) }
        }
        // parón de impacto: el tiempo casi se detiene un instante al romper
        if hitStop > 0 { hitStop -= dt; dt *= 0.08 }
        time += dt

        if let p = pending, time - lastSwing >= cooldown, stamina > 0 { swing(at: p) }

        // aparecen huchas
        if stamina > 0 {
            spawnTimer -= dt
            if spawnTimer <= 0 {
                spawnTimer = stats.spawnEvery * Double.random(in: 0.7...1.3)
                if pigs.count < stats.maxPigs { spawn() }
            }
        }

        // se mueven
        for i in pigs.indices {
            var p = pigs[i]
            p.wander += dt
            if Int(p.wander * 10) % 23 == 0 && Double.random(in: 0..<1) < 0.04 {
                let a = Double.random(in: 0..<(2 * .pi))
                p.vel = CGVector(dx: cos(a) * p.kind.speed, dy: sin(a) * p.kind.speed * 0.6)
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
        shards.removeAll { time - $0.born > 1.3 }

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
        swings.removeAll { time - $0.born > 0.45 }
        blasts.removeAll { time - $0.born > 0.6 }
        shake *= pow(0.0005, dt)

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
    }

    private func drawDesk(_ ctx: inout GraphicsContext) {
        let w = size.width, h = size.height
        ctx.fill(Path(CGRect(x: -20, y: -20, width: w + 40, height: h + 40)), with: .color(Ink.wood))
        let plank = 74.0
        var y = -20.0
        var k = 0
        while y < h + 20 {
            let shade = k % 2 == 0 ? Ink.woodLight.opacity(0.25) : Ink.woodDark.opacity(0.12)
            ctx.fill(Path(CGRect(x: -20, y: y, width: w + 40, height: plank)), with: .color(shade))
            ctx.fill(Path(CGRect(x: -20, y: y + plank - 3, width: w + 40, height: 3)), with: .color(Ink.woodDark.opacity(0.7)))
            // vetas
            for v in 0..<3 {
                var g = Path()
                let gy = y + 16 + Double(v) * 18
                g.move(to: CGPoint(x: -20, y: gy))
                var x = -20.0
                while x < w + 20 {
                    x += 40
                    g.addLine(to: CGPoint(x: x, y: gy + sin(x * 0.02 + Double(k * 3 + v)) * 4))
                }
                ctx.stroke(g, with: .color(Ink.woodDark.opacity(0.18)), lineWidth: 1.5)
            }
            // juntas
            let off = Double((k * 137) % 260)
            for jx in stride(from: off, to: w + 20, by: 260) {
                ctx.fill(Path(CGRect(x: jx, y: y, width: 3, height: plank - 3)), with: .color(Ink.woodDark.opacity(0.5)))
            }
            y += plank; k += 1
        }
    }

    private func drawPig(_ c: inout GraphicsContext, _ p: Pig) {
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
            let r = CGRect(x: -13, y: -7, width: 26, height: 14)
            ctx.fill(Path(r), with: .color(Ink.money))
            ctx.stroke(Path(r), with: .color(Ink.ink), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8)), with: .color(Ink.ink.opacity(0.35)))
        } else {
            let w = 9 * abs(cos(l.rot)) + 2
            ctx.fill(Path(ellipseIn: CGRect(x: -w, y: -9, width: w * 2, height: 18)), with: .color(Ink.gold))
            ctx.stroke(Path(ellipseIn: CGRect(x: -w, y: -9, width: w * 2, height: 18)), with: .color(Ink.ink), lineWidth: 2)
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
        // el martillo: baja de golpe y se queda un instante
        let swingT = min(1, age / 0.07)
        let angle = -70 * (1 - swingT) + (sw.hit ? 0 : 8)
        ctx.opacity = age > 0.3 ? max(0, 1 - (age - 0.3) / 0.15) : 1
        ctx.translateBy(x: sw.pos.x + 26, y: sw.pos.y + 46)
        ctx.rotate(by: .degrees(angle - 20))
        HammerArt.draw(&ctx, hammer, scale: 1)
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
enum HammerArt {
    /// dibuja con el mango hacia abajo y la cabeza en el origen
    static func draw(_ ctx: inout GraphicsContext, _ h: HammerDef, scale k: Double) {
        let ink = GraphicsContext.Shading.color(Ink.ink)
        let head = Color(hex: h.head), handle = Color(hex: h.handle)
        let lw = 2.5 * k
        func box(_ r: CGRect, _ c: Color, _ radius: Double = 3) {
            let p = Path(roundedRect: r, cornerRadius: radius * k)
            ctx.fill(p, with: .color(c)); ctx.stroke(p, with: ink, lineWidth: lw)
        }
        switch h.style {
        case .chancla:
            let sole = Path(roundedRect: CGRect(x: -15 * k, y: -44 * k, width: 30 * k, height: 70 * k), cornerRadius: 14 * k)
            ctx.fill(sole, with: .color(head)); ctx.stroke(sole, with: ink, lineWidth: lw)
            var strap = Path()
            strap.move(to: CGPoint(x: -14 * k, y: -18 * k))
            strap.addQuadCurve(to: CGPoint(x: 14 * k, y: -18 * k), control: CGPoint(x: 0, y: -40 * k))
            ctx.stroke(strap, with: .color(Ink.paper), style: StrokeStyle(lineWidth: 6 * k, lineCap: .round))
            ctx.stroke(strap, with: ink, style: StrokeStyle(lineWidth: 1.5 * k, lineCap: .round))
        case .toy:
            box(CGRect(x: -4 * k, y: -8 * k, width: 8 * k, height: 50 * k), handle, 4)
            box(CGRect(x: -22 * k, y: -26 * k, width: 44 * k, height: 22 * k), head, 9)
            box(CGRect(x: -26 * k, y: -24 * k, width: 7 * k, height: 18 * k), Ink.gold, 3)
            box(CGRect(x: 19 * k, y: -24 * k, width: 7 * k, height: 18 * k), Ink.gold, 3)
        case .claw:
            box(CGRect(x: -4 * k, y: -6 * k, width: 8 * k, height: 54 * k), handle, 3)
            box(CGRect(x: -6 * k, y: -26 * k, width: 28 * k, height: 18 * k), head, 3)
            var claw = Path()
            claw.move(to: CGPoint(x: -6 * k, y: -24 * k))
            claw.addQuadCurve(to: CGPoint(x: -26 * k, y: -8 * k), control: CGPoint(x: -24 * k, y: -26 * k))
            claw.addLine(to: CGPoint(x: -20 * k, y: -6 * k))
            claw.addQuadCurve(to: CGPoint(x: -6 * k, y: -12 * k), control: CGPoint(x: -14 * k, y: -16 * k))
            claw.closeSubpath()
            ctx.fill(claw, with: .color(head)); ctx.stroke(claw, with: ink, lineWidth: lw)
        case .mallet:
            box(CGRect(x: -4 * k, y: -6 * k, width: 8 * k, height: 56 * k), handle, 3)
            box(CGRect(x: -24 * k, y: -30 * k, width: 48 * k, height: 26 * k), head, 7)
        case .mace:
            box(CGRect(x: -4 * k, y: -6 * k, width: 8 * k, height: 58 * k), handle, 3)
            let ball = Path(ellipseIn: CGRect(x: -18 * k, y: -38 * k, width: 36 * k, height: 36 * k))
            for a in stride(from: 0.0, to: 2 * .pi, by: .pi / 4) {
                var spike = Path()
                spike.move(to: CGPoint(x: cos(a - 0.25) * 16 * k, y: -20 * k + sin(a - 0.25) * 16 * k))
                spike.addLine(to: CGPoint(x: cos(a) * 26 * k, y: -20 * k + sin(a) * 26 * k))
                spike.addLine(to: CGPoint(x: cos(a + 0.25) * 16 * k, y: -20 * k + sin(a + 0.25) * 16 * k))
                ctx.fill(spike, with: .color(Color(hex: "#d7d9dd"))); ctx.stroke(spike, with: ink, lineWidth: 1.8 * k)
            }
            ctx.fill(ball, with: .color(head)); ctx.stroke(ball, with: ink, lineWidth: lw)
        case .jack:
            box(CGRect(x: -16 * k, y: -34 * k, width: 32 * k, height: 40 * k), head, 6)
            box(CGRect(x: -26 * k, y: -30 * k, width: 52 * k, height: 8 * k), handle, 4)
            box(CGRect(x: -3 * k, y: 6 * k, width: 6 * k, height: 30 * k), Color(hex: "#9aa0a6"), 2)
        case .sledge:
            box(CGRect(x: -4 * k, y: -6 * k, width: 8 * k, height: 64 * k), handle, 3)
            box(CGRect(x: -30 * k, y: -32 * k, width: 60 * k, height: 28 * k), head, 4)
            box(CGRect(x: -30 * k, y: -32 * k, width: 10 * k, height: 28 * k), Color(hex: "#3a3f45"), 3)
            box(CGRect(x: 20 * k, y: -32 * k, width: 10 * k, height: 28 * k), Color(hex: "#3a3f45"), 3)
        case .thunder:
            box(CGRect(x: -4 * k, y: -6 * k, width: 8 * k, height: 50 * k), handle, 3)
            box(CGRect(x: -26 * k, y: -34 * k, width: 52 * k, height: 30 * k), head, 5)
            var bolt = Path()
            bolt.addLines([CGPoint(x: 2 * k, y: -32 * k), CGPoint(x: -6 * k, y: -18 * k), CGPoint(x: 1 * k, y: -18 * k), CGPoint(x: -4 * k, y: -6 * k), CGPoint(x: 8 * k, y: -22 * k), CGPoint(x: 1 * k, y: -22 * k)])
            bolt.closeSubpath()
            ctx.fill(bolt, with: .color(Ink.gold)); ctx.stroke(bolt, with: ink, lineWidth: 1.5 * k)
        }
    }
}
