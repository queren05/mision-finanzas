package es.david.findemes.logic

import androidx.compose.ui.graphics.Color
import es.david.findemes.model.Content
import es.david.findemes.model.HammerDef
import es.david.findemes.model.HammerStyle
import es.david.findemes.model.PigKind
import es.david.findemes.model.Rarity
import es.david.findemes.model.SkinDef
import es.david.findemes.model.lightning
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.hex
import es.david.findemes.support.rnd
import es.david.findemes.ui.Hat
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

class P(var x: Double, var y: Double) { fun copy() = P(x, y) }
class V(var dx: Double, var dy: Double)

private fun rand(a: Double, b: Double) = if (b <= a) a else Random.nextDouble(a, b)
private fun chance() = Random.nextDouble()

/** La mesa durante un día: huchas, martillazos, pedazos y monedas.
 *  Es una clase normal que se actualiza en cada fotograma; DeskScene la dibuja. */
class Desk(val stats: HitStats, val tier: Int, val hammer: HammerDef, day: Int, val skin: SkinDef = Content.skins[0]) {
    class Pig(
        val id: Int,
        val kind: PigKind,
        val pos: P,
        var vel: V,
        var hp: Double,
        val maxHP: Double,
        val value: Double,
        val size: Double,
        var born: Double,
        var facing: Double = 1.0,
        var wander: Double = 0.0,
    ) {
        var hitAt = -10.0
        val cracks = mutableListOf<List<P>>()
        val pupil = V(0.0, 0.0)
        val pupilVel = V(0.0, 0.0)
        var burnUntil = -10.0
        var frozenUntil = -10.0
        var dead = false
    }
    class Shard(val pos: P, val vel: V, var rot: Double, val spin: Double, val born: Double, val color: Color, val pts: List<P>, var id: Int = 0, val look: String = "")
    class Loot(val pos: P, val vel: V, var born: Double, val bill: Boolean, var rot: Double, var id: Int = 0)
    class Floater(val text: String, val pos: P, val born: Double, val color: Color, val size: Double, var id: Int = 0)
    class Swing(val pos: P, val born: Double, val radius: Double, val hit: Boolean, val crit: Boolean)
    class Blast(val pos: P, val born: Double, val radius: Double)

    val pigs = ArrayList<Pig>()
    val shards = ArrayList<Shard>()
    val loot = ArrayList<Loot>()
    val floaters = ArrayList<Floater>()
    val swings = ArrayList<Swing>()
    val blasts = ArrayList<Blast>()
    var stamina: Double = rnd(stats.stamina)
    var time = 0.0
    var report = DayReport(day)
    var finished = false
    var width = 390.0
    var height = 700.0
    /** zona de juego (sin el marcador de arriba ni la barra de abajo) */
    var top = 120.0
    var bottom = 130.0

    private var lastNanos = 0L
    var lastSwing = -10.0
        private set
    private var pending: P? = null
    private var spawnTimer = 0.0
    private var nextId = 0
    var shake = 0.0
        private set
    private var hitStop = 0.0
    private var endAt: Double? = null
    private var kingDone = false
    private var started = false
    /** para avisar a las pantallas fuera del dibujado (cada 0,1 s como mucho) */
    var onChange: (() -> Unit)? = null
    var onFinish: ((DayReport) -> Unit)? = null
    private var dirtyAt: Long? = null
    var earnedPending = 0.0
    /** combo: huchas rotas seguidas sin parar más de un momento */
    var combo = 0
        private set
    var comboAt = -10.0
        private set
    var frenzyUntil = -10.0
        private set
    val frenzy: Boolean get() = time < frenzyUntil
    val comboMult: Double get() = 1 + min(combo, stats.comboCap) * 0.04
    /** combo que hace falta para el primer frenesí del día */
    val frenzyBase: Int get() = max(8, FRENZY_AT - stats.frenzyEarly)
    /** el frenesí da más dinero con las mejoras, pero cada vez se nota menos (como mucho ×10) */
    val frenzyGain: Double get() = 2 + 8 * stats.frenzyMoney / (stats.frenzyMoney + 8)
    /** y dura más, hasta 18 s */
    val frenzyLength: Double get() = 6 + 12 * stats.frenzyExtra / (stats.frenzyExtra + 12)

    /** primera partida: enseña dónde tocar */
    var tutorial = false
    var firstBreakAt: Double? = null
        private set
    /** golpe de ahora: cuántas rompe (para no repetir sonidos ni parones) */
    private var swingKills = 0
    private var swingEarned = 0.0
    private var lastPop = -10.0
    private var nextPart = 0
    /** sucesos al azar durante el día */
    enum class Happening { lluvia, horaFeliz, terremoto, invasion, rebajas, desfile, visita, estampida }
    var happening: Happening? = null
        private set
    private var happeningUntil = -10.0
    val happeningUntilLeft: Double get() = happeningUntil - time
    private var nextHappening = rand(10.0, 22.0)
    /** aguante que se puede recuperar en un día (para que las partidas terminen) */
    private var regainLeft = rnd(stats.stamina * 0.4)
    private var nextFrenzy = max(8, FRENZY_AT - stats.frenzyEarly)
    /** para las capturas: todas a la vez */
    var zoo = false
    var parade = false

    companion object {
        const val COMBO_WINDOW = 1.7
        const val FRENZY_AT = 25
        const val MAX_ON_DESK = 600
        /** gritos según las huchas rotas de un golpe */
        val shouts = listOf(
            Shout(10, "¡DESTROZO!", Ink.paper, 38.0), Shout(25, "¡MASACRE!", Ink.gold, 44.0), Shout(60, "¡CATACLISMO!", Ink.red, 50.0), Shout(150, "¡APOCALIPSIS!", Ink.purple, 46.0),
        )
        /** premios por huchas rotas en el día */
        val milestones = listOf(50 to Rarity.comun, 150 to Rarity.comun, 400 to Rarity.rara, 1_000 to Rarity.rara, 2_500 to Rarity.epica, 6_000 to Rarity.epica, 15_000 to Rarity.legendaria, 40_000 to Rarity.legendaria)
    }
    class Shout(val n: Int, val text: String, val color: Color, val size: Double)

    val cooldown: Double get() = 1 / stats.speed
    val cooldownProgress: Double get() = min(1.0, (time - lastSwing) / cooldown)

    // MARK: - Huchas

    private fun pickKind(): PigKind {
        if (chance() < stats.golden) return PigKind.dorada
        if (happening == Happening.lluvia && chance() < 0.45) return PigKind.dorada
        val pool = PigKind.entries.filter { it.weight > 0 && tier >= it.minTier }
        val weights = pool.map { if (it == PigKind.gorda) it.weight * (1 + stats.fat * 10) else it.weight }
        var r = Random.nextDouble() * weights.sum()
        for ((i, k) in pool.withIndex()) { if (r < weights[i]) return k; r -= weights[i] }
        return PigKind.normal
    }

    private fun spawn(forced: PigKind? = null, at: P? = null, scale: Double = 1.0) {
        val kind = forced ?: pickKind()
        val s = kind.size * 0.85 * scale * crowd
        var x = rand(s * 0.7, max(s * 0.7 + 1, width - s * 0.7))
        var y = rand(top + s * 0.5, max(top + s * 0.5 + 1, height - bottom - s * 0.5))
        if (at != null) { x = at.x + rand(-30.0, 30.0); y = at.y + rand(-20.0, 20.0) }
        val a = Random.nextDouble() * 2 * PI
        val hp = Content.pigHP(tier) * kind.hp
        nextId += 1
        pigs.add(Pig(nextId, kind, P(x, y), V(cos(a) * kind.speed, sin(a) * kind.speed * 0.6),
            hp * scale, hp * scale, Content.pigValue(tier) * kind.value * scale, s, time,
            if (cos(a) >= 0) 1.0 else -1.0, rand(0.0, 6.0)))
        if (time - lastPop > 0.15 && !frenzy) { lastPop = time; Sound.pop() }
    }

    // MARK: - Martillazo

    /** dónde está el dedo mientras se mantiene pulsado */
    var holding: P? = null
    /** con muchas huchas en la mesa se ven más pequeñas, para que quepan */
    val crowd: Double get() = max(0.42, min(1.0, sqrt(45.0 / max(45, stats.maxPigs))))

    fun tap(p: P) {
        if (finished || !(stamina > 0 || frenzy) || p.y <= top - 30 || p.y >= height - bottom + 30) return
        if (time - lastSwing >= cooldown) swing(p) else pending = p
    }

    private fun swing(p: P) {
        lastSwing = time
        pending = null
        report.swings += 1
        if (frenzy) {
            // en frenesí los golpes no gastan
        } else if (chance() >= stats.drainSave) stamina -= 1
        else floaters.add(Floater("¡Gratis!", P(p.x, p.y - 40), time, Ink.green, 18.0))
        Sound.swing()

        swingKills = 0
        swingEarned = 0.0
        val crit = chance() < stats.crit
        var hitAny = false
        val r = stats.radius
        val killed = mutableListOf<Int>()
        for (i in pigs.indices) {
            if (pigs[i].dead) continue
            val d = hypot(pigs[i].pos.x - p.x, pigs[i].pos.y - p.y)
            if (d < r + pigs[i].size * 0.45) {
                hitAny = true
                if (damage(i, stats.damage, crit, p)) killed.add(i)
            } else if (stats.collateral > 0 && d < r * 2.2 + pigs[i].size * 0.45) {
                if (damage(i, stats.damage * stats.collateral, false, p, quiet = true)) killed.add(i)
            }
        }
        swings.add(Swing(p, time, r, hitAny, crit))
        if (hitAny) {
            Sound.hit(crit)
            shake = max(shake, if (crit) 9.0 else 4.0)
            if (crit) report.crits += 1
        } else {
            Sound.miss()
            shake = max(shake, 2.0)
        }
        // habilidades del martillo
        if (hitAny) {
            if (hammer.style == HammerStyle.mallet && chance() < 0.25) {
                for (i in pigs.indices) {
                    if (pigs[i].dead || i in killed || hypot(pigs[i].pos.x - p.x, pigs[i].pos.y - p.y) >= r + pigs[i].size * 0.45) continue
                    if (damage(i, stats.damage, false, p, quiet = true)) killed.add(i)
                }
                floaters.add(Floater("¡REBOTE!", P(p.x, p.y - 40), time, Ink.paper, 20.0))
            }
            if (hammer.style.lightning && chance() < 0.3) {
                val targets = pigs.indices.filter { !pigs[it].dead && it !in killed }.shuffled().take(3)
                for (i in targets) {
                    blasts.add(Blast(pigs[i].pos.copy(), time, 50.0))
                    if (damage(i, stats.damage * 2, false, pigs[i].pos.copy(), quiet = true)) killed.add(i)
                }
                if (targets.isNotEmpty()) { Sound.boom(); floaters.add(Floater("¡RAYO!", P(p.x, p.y - 60), time, Ink.gold, 24.0)) }
            }
        }
        if (hammer.style == HammerStyle.anvil) {
            for (i in pigs.indices) {
                if (pigs[i].dead || i in killed) continue
                pigs[i].hp -= stats.damage * 0.12
                if (pigs[i].hp <= 0) killed.add(i)
            }
            shake = max(shake, 6.0)
        }
        for (i in killed) if (!pigs[i].dead) breakPig(i)
        pigs.removeAll { it.dead }
        if (swingKills > 0) {
            // un solo sonido, un solo parón y un solo número por golpe, aunque rompa veinte
            Sound.smash(swingKills >= 4, combo)
            if (!frenzy) hitStop = max(hitStop, if (swingKills >= 6) 0.06 else 0.035)
            shake = max(shake, min(16.0, 5.0 + swingKills))
            if (swingKills >= 3) {
                floaters.add(Floater("×$swingKills  +" + Fmt.money(swingEarned), P(p.x, p.y - 70), time, Ink.gold, min(40.0, 26.0 + swingKills)))
            }
            // cuantas más de un golpe, más grande el grito
            shouts.lastOrNull { swingKills >= it.n }?.let { shout ->
                floaters.add(Floater(shout.text, P(width / 2, top + 180), time, shout.color, shout.size))
                shake = max(shake, 18.0)
                hitStop = max(hitStop, 0.09)
                Sound.boom()
            }
            if (chance() < stats.killStamina) regain(1.0, p)
        }
        if (stamina <= 0 && endAt == null && !frenzy) endAt = time + 1.4
        markDirty()
    }

    /** devuelve true si la hucha se rompe */
    private fun damage(i: Int, base: Double, crit: Boolean, p: P, quiet: Boolean = false): Boolean {
        val pig = pigs[i]
        var d = base * (if (crit) stats.critMult else 1.0)
        if (pig.hp >= pig.maxHP) d *= 1 + stats.firstHit
        if (pig.kind == PigKind.acorazada || pig.kind == PigKind.robot) d *= min(1.0, 0.4 + stats.pierce)
        if (time < pig.frozenUntil) d *= 1.3
        if (hammer.style == HammerStyle.gavel && chance() < 0.08) d = max(d, pig.hp)
        pig.hp -= d
        pig.hitAt = time
        if (hammer.style == HammerStyle.fire) pig.burnUntil = time + 3
        if (hammer.style == HammerStyle.ice) pig.frozenUntil = time + 3
        // los ojos dan un respingo
        pig.pupilVel.dx = rand(-60.0, 60.0); pig.pupilVel.dy = rand(-60.0, 60.0)
        addCrack(i, p)
        if (!quiet) {
            floaters.add(Floater((if (crit) "¡ZAS! " else "") + "-" + Fmt.num(ceil(d)),
                P(pig.pos.x + rand(-10.0, 10.0), pig.pos.y - pig.size * 0.55),
                time, if (crit) Ink.red else Ink.ink, if (crit) 24.0 else 17.0))
        }
        return pig.hp <= 0
    }

    private fun addCrack(i: Int, p: P) {
        val pig = pigs[i]
        if (pig.cracks.size >= 9) return
        val s = pig.size
        // punto de impacto en coordenadas de la hucha (normalizadas al tamaño)
        var sx = (p.x - pig.pos.x) / s
        val sy = (p.y - pig.pos.y) / s
        if (pig.facing < 0) sx = -sx
        var pt = P(max(-0.4, min(0.4, sx)), max(-0.3, min(0.3, sy)))
        val line = mutableListOf(pt)
        var ang = Random.nextDouble() * 2 * PI
        repeat(Random.nextInt(3, 6)) {
            ang += rand(-0.9, 0.9)
            pt = P(max(-0.5, min(0.5, pt.x + cos(ang) * 0.1)), max(-0.36, min(0.36, pt.y + sin(ang) * 0.08)))
            line.add(pt)
        }
        pig.cracks.add(line)
    }

    private fun breakPig(i: Int) {
        val pig = pigs[i]
        if (pig.dead) return
        pig.dead = true
        report.byKind[pig.kind.name] = (report.byKind[pig.kind.name] ?: 0) + 1
        combo += 1
        if (combo in listOf(10, 25, 50, 100, 200) && floaters.size < 30) {
            floaters.add(Floater("COMBO ×$combo", P(width / 2, top + 60), time, Ink.gold, 30 + min(combo, 100) / 8.0))
        }
        milestones.firstOrNull { it.first == report.broken + 1 }?.let { m ->
            report.chests.add(m.second)
            floaters.add(Floater("¡${m.first} {HUCHAS}! Sobre ${m.second.title.lowercase()}", P(width / 2, top + 230), time, if (m.second == Rarity.comun) Ink.paper else m.second.color, 26.0))
            Sound.fanfare()
        }
        comboAt = time
        report.bestCombo = max(report.bestCombo, combo)
        if (firstBreakAt == null) firstBreakAt = time
        if (combo >= nextFrenzy && !frenzy) {
            // cada frenesí del día cuesta bastante más combo que el anterior
            nextFrenzy = combo + frenzyBase + 15 * (report.frenzies + 1) * (report.frenzies + 1)
            frenzyUntil = time + frenzyLength
            report.frenzies += 1
            shake = max(shake, 12.0)
            Sound.fanfare()
            floaters.add(Floater("¡FRENESÍ!", P(width / 2, top + 120), time, Ink.gold, 46.0))
        }
        report.xp += if (pig.kind == PigKind.rey) 120.0 else if (pig.kind == PigKind.dorada) 12.0 else if (pig.kind == PigKind.normal) 1.0 else 2.0
        var value = pig.value * (if (pig.kind == PigKind.dorada) stats.goldenValue else 1.0) * stats.loot * comboMult * (if (frenzy) frenzyGain else 1.0) *
            (if (happening == Happening.horaFeliz) 3.0 else if (happening == Happening.estampida) 2.0 else 1.0)
        var jackpot = false
        if (chance() < stats.jackpot) { value *= 20; jackpot = true }
        report.earned += value
        report.broken += 1
        earnedPending += value
        report.best = max(report.best, value)
        swingKills += 1
        swingEarned += value
        if (pig.kind == PigKind.rey) { hitStop = 0.12; shake = 16.0; Sound.smash(true) }

        // pedazos de cerámica (menos cuantos más haya ya volando)
        val budget = if (shards.size > 170) 0 else if (shards.size > 140) 2 else if (shards.size > 70) 5 else 10
        repeat(if (pig.kind == PigKind.rey) 26 else budget) {
            val a = Random.nextDouble() * 2 * PI
            val sp = rand(120.0, 420.0)
            val r = pig.size * rand(0.08, 0.18)
            val pts = (0 until 3).map { k ->
                val b = k / 3.0 * 2 * PI + rand(-0.4, 0.4)
                P(cos(b) * r, sin(b) * r)
            }
            shards.add(Shard(pig.pos.copy(), V(cos(a) * sp, sin(a) * sp - 220), 0.0, rand(-12.0, 12.0), time,
                shardColor(pig.kind), pts, look = if (skin.drawn) "" else pig.kind.look))
        }
        // monedas y billetes que vuelan al marcador
        val n = if (loot.size > 120) 0 else if (loot.size > 60) 1 else if (loot.size > 30) 2 else min(10, 3 + (log10(max(1.0, value)) * 1.4).toInt())
        for (k in 0 until n) {
            val a = rand(-PI, 0.0)
            loot.add(Loot(pig.pos.copy(), V(cos(a) * rand(80.0, 260.0), sin(a) * rand(160.0, 360.0)), time + k * 0.015, k % 3 == 2, rand(0.0, 6.0)))
        }
        if (floaters.size < 10 || jackpot) {
            floaters.add(Floater((if (jackpot) "¡BOTE! " else "+") + Fmt.money(value), P(pig.pos.x, pig.pos.y - 10),
                time, if (jackpot) Ink.red else Ink.green, if (jackpot) 30.0 else 23.0))
        }

        when (pig.kind) {
            PigKind.dorada -> {
                report.golden += 1
                Game.shared.goldenCoinDrop()?.let { c ->
                    report.coins.add(c)
                    val name = Content.coins.firstOrNull { it.id == c }?.name ?: "Moneda"
                    floaters.add(Floater("¡$name!", P(pig.pos.x, pig.pos.y - 46), time + 0.15, Ink.purple, 20.0))
                }
            }
            PigKind.cristal -> regain(stats.glass, pig.pos)
            PigKind.bomba -> explode(pig.pos.copy(), pig.maxHP)
            PigKind.rey -> report.kings += 1
            PigKind.madre -> repeat(3) { spawn(PigKind.normal, pig.pos, 0.6) }
            PigKind.lava -> explode(pig.pos.copy(), pig.maxHP * 4)
            PigKind.cosmica -> Game.shared.goldenCoinDrop()?.let { report.coins.add(it) }
            PigKind.suerte -> {
                report.chests.add(Rarity.rara)
                if (floaters.size < 16) floaters.add(Floater("¡Sobre raro!", P(pig.pos.x, pig.pos.y - 46), time + 0.1, Ink.purple, 18.0))
            }
            // vuelve a levantarse una vez, más pequeña
            PigKind.zombi -> if (pig.size > PigKind.zombi.size * 0.8 * crowd) spawn(PigKind.zombi, pig.pos, 0.7)
            PigKind.payaso -> repeat(5) { spawn(listOf(PigKind.normal, PigKind.gorda, PigKind.ruedas, PigKind.cristal).random(), pig.pos, 0.55) }
            PigKind.vampiro -> regain(3.0, pig.pos)
            PigKind.titan -> {
                explode(pig.pos.copy(), pig.maxHP * 0.5)
                shake = max(shake, 14.0)
            }
            PigKind.alien -> {
                val taken = pigs.indices.filter { !pigs[it].dead && pigs[it].kind != PigKind.rey && pigs[it].kind != PigKind.reina }.shuffled().take(3)
                for (j in taken) { blasts.add(Blast(pigs[j].pos.copy(), time, 40.0)); breakPig(j) }
                if (taken.isNotEmpty() && floaters.size < 16) floaters.add(Floater("¡ABDUCIDAS!", P(pig.pos.x, pig.pos.y - 50), time, hex("#8fe36a"), 20.0))
            }
            PigKind.nube -> repeat(3) { spawn(PigKind.dorada, pig.pos, 0.8) }
            PigKind.fenix -> if (pig.size > PigKind.fenix.size * 0.85 * 0.95 * crowd) {
                spawn(PigKind.fenix, pig.pos, 0.9)
                if (floaters.size < 16) floaters.add(Floater("¡RENACE!", P(pig.pos.x, pig.pos.y - 50), time, Ink.red, 20.0))
            }
            PigKind.agujero -> {
                blasts.add(Blast(pig.pos.copy(), time, 220.0))
                val sucked = pigs.indices.filter { j -> !pigs[j].dead && hypot(pigs[j].pos.x - pig.pos.x, pigs[j].pos.y - pig.pos.y) < 220 && pigs[j].kind != PigKind.rey && pigs[j].kind != PigKind.reina }
                for (j in sucked) breakPig(j)
                shake = max(shake, 18.0)
                Sound.boom()
            }
            else -> {}
        }
        val chestChance = if (pig.kind == PigKind.pirata || pig.kind == PigKind.reina) 1.0 else if (pig.kind == PigKind.arcoiris) 0.7 else if (pig.kind == PigKind.cosmica) 0.5
            else stats.chest * (if (pig.kind == PigKind.dorada) 6.0 else if (pig.kind == PigKind.rey) 30.0 else 1.0)
        if (chance() < chestChance) {
            val r = Game.shared.rollChest()
            report.chests.add(r)
            floaters.add(Floater("¡Sobre ${r.title.lowercase()}!", P(pig.pos.x, pig.pos.y - 70), time + 0.2, if (r == Rarity.comun) Ink.soft else r.color, 20.0))
        }
        if (endAt != null && stamina > 0) endAt = null
    }

    private fun shardColor(k: PigKind): Color {
        if (skin.drawn || k.look != "normal" || skin.shards.isEmpty()) return if (Random.nextBoolean()) k.color else k.dark
        return hex(skin.shards.random())
    }

    private fun startHappening() {
        val h = Happening.entries.random()
        val mid = P(width / 2, top + 150)
        Sound.fanfare()
        when (h) {
            Happening.lluvia -> {
                happening = h; happeningUntil = time + 7
                floaters.add(Floater("¡LLUVIA DE ORO!", mid, time, Ink.gold, 40.0))
            }
            Happening.horaFeliz -> {
                happening = h; happeningUntil = time + 8
                floaters.add(Floater("¡HORA FELIZ! ×3", mid, time, Ink.green, 40.0))
            }
            Happening.terremoto -> {
                shake = 22.0
                floaters.add(Floater("¡TERREMOTO!", mid, time, Ink.red, 40.0))
                val killed = mutableListOf<Int>()
                for (i in pigs.indices) {
                    val p = pigs[i]
                    if (p.dead) continue
                    p.hp -= p.maxHP * 0.45
                    p.hitAt = time
                    addCrack(i, p.pos.copy())
                    if (p.hp <= 0) killed.add(i)
                }
                swingKills = 0; swingEarned = 0.0
                for (i in killed) breakPig(i)
                pigs.removeAll { it.dead }
            }
            Happening.invasion -> {
                floaters.add(Floater("¡INVASIÓN DE {HUCHAS}!", mid, time, Ink.pink, 36.0))
                repeat(min(30, max(10, stats.maxPigs / 3))) { spawn() }
            }
            Happening.rebajas -> {
                floaters.add(Floater("¡REBAJAS! +aguante", mid, time, Ink.blue, 36.0))
                stamina = min(stats.stamina, stamina + rnd(stats.stamina * 0.15))
            }
            Happening.desfile -> {
                floaters.add(Floater("¡DESFILE DORADO!", mid, time, Ink.gold, 38.0))
                repeat(8) { spawn(PigKind.dorada) }
            }
            Happening.visita -> {
                floaters.add(Floater("¡VISITA REAL!", mid, time, Ink.purple, 40.0))
                spawn(if (tier >= PigKind.reina.minTier && Random.nextBoolean()) PigKind.reina else PigKind.rey)
            }
            Happening.estampida -> {
                happening = h; happeningUntil = time + 8
                floaters.add(Floater("¡ESTAMPIDA! ×2", mid, time, Ink.red, 40.0))
            }
        }
    }

    /** recuperar aguante, con tope por día */
    private fun regain(v: Double, p: P) {
        // nunca por encima del aguante máximo
        val g = minOf(v, regainLeft, floor(stats.stamina - stamina))
        if (g < 1) return
        regainLeft -= g
        stamina += g
        if (floaters.size < 14) floaters.add(Floater("+${g.toInt()} aguante", P(p.x + 20, p.y - 40), time + 0.1, Ink.blue, 17.0))
    }

    private fun explode(p: P, power: Double) {
        blasts.add(Blast(p, time, 140.0))
        Sound.boom()
        shake = max(shake, 14.0)
        val killed = mutableListOf<Int>()
        for (i in pigs.indices) {
            val q = pigs[i]
            if (q.dead || hypot(q.pos.x - p.x, q.pos.y - p.y) >= 140) continue
            q.hp -= power * 1.5 * stats.bomb
            q.hitAt = time
            addCrack(i, p)
            if (q.hp <= 0) killed.add(i)
        }
        for (i in killed) breakPig(i)
    }

    private fun markDirty() {
        if (dirtyAt == null) dirtyAt = System.nanoTime()
    }

    // MARK: - Bucle

    fun frame(nanos: Long, w: Double, h: Double) {
        width = w; height = h
        val raw = if (lastNanos == 0L) 0.0 else (nanos - lastNanos) / 1e9
        lastNanos = nanos
        var dt = min(max(raw, 0.0), 1.0 / 20)
        if (!started) {
            started = true
            if (zoo) {
                for (k in PigKind.entries) spawn(k)
            } else {
                repeat(min(MAX_ON_DESK, stats.startPigs)) { spawn() }
                if (parade) for (k in PigKind.entries) if (Hat.spec(k) != null) spawn(k)
            }
            spawnTimer = stats.spawnEvery
            if (tier >= PigKind.rey.minTier && chance() < 0.25 + stats.king) { kingDone = true; spawn(PigKind.rey) }
        }
        // parón de impacto: el tiempo casi se detiene un instante al romper
        if (hitStop > 0) { hitStop -= dt; dt *= 0.08 }
        time += dt

        // el aguante se va gastando solo (menos en frenesí); empieza a contar con el primer golpe
        if (!frenzy && !finished && !tutorial && report.swings > 0 && stamina > 0) {
            val before = stamina.toInt()
            stamina = max(0.0, stamina - max(0.4, stats.stamina / 45) * dt)
            if (stamina.toInt() != before) markDirty()
        }
        pending?.let { p -> if (time - lastSwing >= cooldown && (stamina > 0 || frenzy)) swing(p) }
        // con el dedo puesto se sigue golpeando donde esté
        holding?.let { hd ->
            if (pending == null && !finished && time - lastSwing >= cooldown && (stamina > 0 || frenzy) && hd.y > top - 30 && hd.y < height - bottom + 30) swing(hd.copy())
        }

        // aparecen huchas
        if (stamina > 0 || frenzy) {
            spawnTimer -= dt * (if (frenzy) 4 else 1)
            if (spawnTimer <= 0) {
                spawnTimer = stats.spawnEvery * rand(0.7, 1.3)
                if (pigs.size < min(MAX_ON_DESK, stats.maxPigs + (if (frenzy) max(10, stats.maxPigs / 2) else 0))) spawn()
            }
        }
        // sucesos: lluvia de oro, hora feliz, terremoto, invasión y rebajas de aguante
        if (happening != null && time > happeningUntil) happening = null
        if (time >= nextHappening && (stamina > 0 || frenzy) && !finished) {
            nextHappening = time + rand(16.0, 30.0)
            startHappening()
        }
        if (combo > 0 && time - comboAt > COMBO_WINDOW + stats.comboTime && !frenzy) { combo = 0; nextFrenzy = frenzyBase + 15 * report.frenzies * report.frenzies }

        // se mueven
        val burned = mutableListOf<Int>()
        for (p in pigs) {
            p.wander += dt
            if ((p.wander * 10).toInt() % 23 == 0 && chance() < 0.04) {
                val a = Random.nextDouble() * 2 * PI
                p.vel = V(cos(a) * p.kind.speed, sin(a) * p.kind.speed * 0.6)
            }
            if (p.kind == PigKind.fantasma && chance() < dt * 0.35) {
                p.pos.x = rand(p.size, max(p.size + 1, width - p.size))
                p.pos.y = rand(top + p.size * 0.5, max(top + p.size * 0.5 + 1, height - bottom - p.size * 0.5))
                p.born = time - 0.05
            }
            val slow = if (time < p.frozenUntil) 0.0 else if (time - p.hitAt < 0.3) 0.2 else 1.0
            if (time < p.burnUntil && !p.dead) {
                p.hp -= p.maxHP * 0.12 * dt
                if (p.hp <= 0) burned.add(p.id)
            }
            p.pos.x += p.vel.dx * dt * slow
            p.pos.y += p.vel.dy * dt * slow
            val mx = p.size * 0.6; val my = p.size * 0.45
            if (p.pos.x < mx) { p.pos.x = mx; p.vel.dx = abs(p.vel.dx) }
            if (p.pos.x > width - mx) { p.pos.x = width - mx; p.vel.dx = -abs(p.vel.dx) }
            if (p.pos.y < top + my) { p.pos.y = top + my; p.vel.dy = abs(p.vel.dy) }
            if (p.pos.y > height - bottom - my) { p.pos.y = height - bottom - my; p.vel.dy = -abs(p.vel.dy) }
            if (abs(p.vel.dx) > 2) p.facing = if (p.vel.dx > 0) 1.0 else -1.0
            // ojos locos: un muelle que vuelve al centro con algo de temblor
            val k = 120.0; val damp = 7.0
            p.pupilVel.dx += (-p.pupil.dx * k - p.pupilVel.dx * damp) * dt + rand(-30.0, 30.0) * dt
            p.pupilVel.dy += (-p.pupil.dy * k - p.pupilVel.dy * damp) * dt + rand(-30.0, 30.0) * dt
            p.pupil.dx += p.pupilVel.dx * dt; p.pupil.dy += p.pupilVel.dy * dt
            val m = hypot(p.pupil.dx, p.pupil.dy)
            if (m > 1) { p.pupil.dx /= m; p.pupil.dy /= m }
        }

        if (burned.isNotEmpty()) {
            swingKills = 0; swingEarned = 0.0
            for (id in burned) { val i = pigs.indexOfFirst { it.id == id && !it.dead }; if (i >= 0) breakPig(i) }
            pigs.removeAll { it.dead }
        }
        for (s in shards) {
            s.vel.dy += 1100 * dt
            s.pos.x += s.vel.dx * dt
            s.pos.y += s.vel.dy * dt
            s.rot += s.spin * dt
        }
        shards.removeAll { time - it.born > 1.1 }
        if (shards.size > 180) shards.subList(0, shards.size - 180).clear()

        // monedas: saltan y luego vuelan hacia el contador de dinero
        val tx = 70.0; val ty = 40.0
        var arrived = 0
        for (l in loot) {
            val age = time - l.born
            if (age < 0) continue
            if (age < 0.35) {
                l.vel.dy += 900 * dt
                l.pos.x += l.vel.dx * dt
                l.pos.y += l.vel.dy * dt
            } else {
                val k = min(1.0, (age - 0.35) * 3.2)
                l.pos.x += (tx - l.pos.x) * k * 0.35
                l.pos.y += (ty - l.pos.y) * k * 0.35
            }
            l.rot += dt * 8
            if (hypot(l.pos.x - tx, l.pos.y - ty) < 18 && age > 0.4) { l.born = -100.0; arrived += 1 }
        }
        if (arrived > 0) Sound.coin()
        loot.removeAll { it.born == -100.0 || time - it.born > 2.5 }
        floaters.removeAll { time - it.born > 1.1 }
        if (floaters.size > 18) floaters.subList(0, floaters.size - 18).clear()
        swings.removeAll { time - it.born > 0.45 }
        blasts.removeAll { time - it.born > 0.6 }
        shake *= 0.0005.pow(dt)

        // cada pedazo, moneda y número lleva su número para que no salten de dibujo
        for (s in shards) if (s.id == 0) { nextPart += 1; s.id = nextPart }
        for (l in loot) if (l.id == 0) { nextPart += 1; l.id = nextPart }
        for (f in floaters) if (f.id == 0) { nextPart += 1; f.id = nextPart }
        if (stamina <= 0 && endAt == null && !frenzy && !finished) endAt = time + 1.0
        if (earnedPending > 0) markDirty()
        // avisa como mucho cada 0,1 s
        dirtyAt?.let { if (System.nanoTime() - it >= 100_000_000L) { dirtyAt = null; onChange?.invoke() } }
        endAt?.let { e ->
            if (time >= e && !finished) {
                finished = true
                onChange?.invoke()
                onFinish?.invoke(report)
            }
        }
    }

    /** terminar el día antes de tiempo */
    fun quit() {
        if (finished) return
        stamina = 0.0
        endAt = time + 0.2
    }

    fun bestCluster(): P? {
        var best: P? = null
        var n = 0
        for (p in pigs) {
            val c = pigs.count { hypot(it.pos.x - p.pos.x, it.pos.y - p.pos.y) < stats.radius + 50 }
            if (c > n) { n = c; best = p.pos }
        }
        return best
    }
}
