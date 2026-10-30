package es.david.findemes.logic

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import es.david.findemes.model.BillDef
import es.david.findemes.model.CoinDef
import es.david.findemes.model.Content
import es.david.findemes.model.HammerDef
import es.david.findemes.model.HammerStyle
import es.david.findemes.model.PartEffect
import es.david.findemes.model.PigKind
import es.david.findemes.model.Persistence
import es.david.findemes.model.Rarity
import es.david.findemes.model.RingDef
import es.david.findemes.model.RingEffect
import es.david.findemes.model.SaveState
import es.david.findemes.model.SkillDef
import es.david.findemes.model.SkillEffect
import es.david.findemes.model.SkillTree
import es.david.findemes.model.SkinDef
import es.david.findemes.money.Money
import es.david.findemes.money.Reward
import es.david.findemes.money.Shop
import es.david.findemes.support.Animal
import es.david.findemes.support.rnd
import java.util.UUID
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt
import kotlin.random.Random

/** lo que vale cada cosa con el martillo, las mejoras, las joyas y la colección de ahora */
class HitStats {
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

class DayReport(val day: Int) {
    val id = UUID.randomUUID().toString()
    var earned = 0.0
    var broken = 0
    var swings = 0
    var crits = 0
    var golden = 0
    var kings = 0
    var chests = mutableListOf<Rarity>()
    var coins = mutableListOf<String>()
    var best = 0.0
    var bestCombo = 0
    var frenzies = 0
    var byKind = mutableMapOf<String, Int>()
    var xp = 0.0
    var record = false
    var legacy = 0.0
}

class ChestPrize(val rarity: Rarity, val cash: Double, val coin: CoinDef?, val duplicate: Boolean, val legacy: Double) {
    val id = UUID.randomUUID().toString()
}

sealed class GameEvent(val id: String) {
    class Collector(val legacy: Double) : GameEvent("collector")
    /** llama el cobrador: si quieres, te da un día más */
    object Warning : GameEvent("warning")
    object Taxes : GameEvent("taxes")
    class Bankrupt(val legacy: Double) : GameEvent("bankrupt")
}

class Game private constructor() {
    companion object {
        val shared by lazy { Game() }
    }

    var s by mutableStateOf(Persistence.load() ?: SaveState())
    var inRun by mutableStateOf(false)
    var report by mutableStateOf<DayReport?>(null)
    var event by mutableStateOf<GameEvent?>(null)
    /** nivel nuevo recién alcanzado (para la celebración) */
    var levelUp by mutableStateOf<Int?>(null)
    /** huchas nuevas que acaban de aparecer */
    var newKinds by mutableStateOf(listOf<PigKind>())
    /** cambia cada vez que cambia algo que afecta a las estadísticas */
    var stats by mutableStateOf(HitStats())
        private set
    /** para enseñar el sello cuando una factura se paga sola */
    var autoPaid by mutableStateOf<String?>(null)
    /** la hipoteca recién pagada (nivel), lo ganado sin jugar, el número grande recién alcanzado
     *  y lo que fue a la hipoteca con la última bancarrota */
    var finale by mutableStateOf<Int?>(null)
    var away by mutableStateOf<AwayPrize?>(null)
    var milestoneShow by mutableStateOf<Int?>(null)
    var mortgageAdded by mutableDoubleStateOf(0.0)

    init {
        applySettings()
        Animal.use(Content.skin(s.skin))
        recompute()
        wake()
        refillQuests()
    }

    fun applySettings() {
        Sound.on = s.settings.sound
        Sound.haptics = s.settings.haptics
        Music.on = s.settings.music
    }

    fun save() {
        s.lastPlayed = System.currentTimeMillis() / 1000.0
        Persistence.save(s)
    }

    // MARK: - Estadísticas

    fun level(k: SkillDef): Int = s.skills[k.id] ?: 0
    fun ringLevel(r: RingDef): Int = s.rings[r.id] ?: 0

    fun recompute() {
        val h = Content.hammers[s.hammer]
        val st = HitStats()
        st.damage = h.damage; st.speed = h.speed; st.radius = h.radius
        var dmgPct = 0.0; var speedPct = 0.0; var radiusPct = 0.0; var lootPct = 0.0; var spawnPct = 0.0
        var dmgMul = 1.0; var lootMul = 1.0
        for (k in Content.skills) {
            val l = level(k)
            if (l <= 0) continue
            val v = k.value(l)
            when (k.effect) {
                SkillEffect.pigXPMul -> st.pigXP *= v
                SkillEffect.goldenValue -> st.goldenValue += v / 100
                SkillEffect.chestValue -> st.chestValue += v / 100
                SkillEffect.firstHit -> st.firstHit += v / 100
                SkillEffect.comboCap -> st.comboCap += v.toInt()
                SkillEffect.comboTime -> st.comboTime += v
                SkillEffect.damageFlat -> st.damage += v
                SkillEffect.damagePct -> dmgPct += v
                SkillEffect.speedPct -> speedPct += v
                SkillEffect.radiusPct -> radiusPct += v
                SkillEffect.stamina -> st.stamina += v
                SkillEffect.killStamina -> st.killStamina += v / 100
                SkillEffect.drainSave -> st.drainSave += v / 100
                SkillEffect.startPigs -> st.startPigs += v.toInt()
                SkillEffect.spawnPct -> spawnPct += v
                SkillEffect.maxPigs -> st.maxPigs += v.toInt()
                SkillEffect.lootPct -> lootPct += v
                SkillEffect.golden -> st.golden += v / 100
                SkillEffect.crit -> st.crit += v / 100
                SkillEffect.critDamage -> st.critMult += v / 100
                SkillEffect.collateral -> st.collateral += v / 100
                SkillEffect.chest -> st.chest += v / 100
                SkillEffect.jackpot -> st.jackpot += v / 100
                SkillEffect.pierce -> st.pierce += v / 100
                SkillEffect.fat -> st.fat += v / 100
                SkillEffect.bomb -> st.bomb += v / 100
                SkillEffect.king -> st.king += v / 100
                SkillEffect.glass -> st.glass += v
                SkillEffect.frenzyEarly -> st.frenzyEarly += v.toInt()
                SkillEffect.frenzyTime -> st.frenzyExtra += v
                SkillEffect.frenzyMoney -> st.frenzyMoney += v / 100
            }
        }
        for (r in Content.rings) {
            val l = ringLevel(r)
            if (l <= 0) continue
            val v = r.per * l
            when (r.effect) {
                RingEffect.lootMul -> lootMul *= r.value(l)
                RingEffect.damageMul -> dmgMul *= r.value(l)
                RingEffect.crit -> st.crit += v / 100
                RingEffect.stamina -> st.stamina += v
                RingEffect.golden -> st.golden += v / 100
                RingEffect.chest -> { st.chest += v / 100; st.chestLuck += l }
                RingEffect.startCash, RingEffect.extraDays, RingEffect.legacy, RingEffect.bills, RingEffect.keepTier, RingEffect.startHammer, RingEffect.autoBuy -> {}
            }
        }
        // las mejoras del martillo
        for (p in Content.parts) {
            val l = min(partLevel(p), p.maxLevel)
            if (l <= 0) continue
            val v = p.value(l)
            when (p.effect) {
                PartEffect.damage -> dmgPct += v
                PartEffect.loot -> lootPct += v
                PartEffect.speed -> speedPct += v
            }
        }
        // cada moneda de la colección da dinero para siempre
        for (c in Content.coins) if ((s.coins[c.id] ?: 0) > 0) lootPct += c.rarity.bonus * 100
        // cada nivel y cada logro dan +1 % de dinero, para siempre
        lootPct += (s.level - 1).toDouble() + s.achievements.size
        st.damage *= (1 + dmgPct / 100) * dmgMul
        st.stamina = rnd(st.stamina)
        st.speed *= 1 + speedPct / 100
        st.radius *= 1 + radiusPct / 100
        // cada hipoteca pagada multiplica el dinero para siempre
        st.loot = (1 + lootPct / 100) * lootMul * (1 + s.richLevel)
        // cuanto más rápido salen, menos se nota cada mejora (si no, la mesa se desborda y el dinero se dispara)
        st.spawnEvery = 0.6 / sqrt(1 + spawnPct / 100)
        // la habilidad del martillo en la mano
        when (h.style) {
            HammerStyle.chancla -> st.crit += 0.10
            HammerStyle.toy -> st.speed *= 1.25
            HammerStyle.claw -> st.pierce += 0.4
            HammerStyle.mace -> st.critMult += 1
            HammerStyle.jack -> st.drainSave += 0.25
            HammerStyle.sledge -> st.collateral += 0.35
            HammerStyle.thunderGold -> st.loot *= 2
            HammerStyle.diamond -> { st.crit += 0.15; st.critMult += 2 }
            HammerStyle.cosmic -> st.frenzyEarly += 10
            HammerStyle.goldFlop -> { st.loot *= 1.5; st.chest *= 2 }
            HammerStyle.viking -> { st.crit += 0.25; st.critMult += 1.5 }
            HammerStyle.plunger -> { st.maxPigs += 25; st.startPigs += 10 }
            HammerStyle.swatter -> st.speed *= 1.4
            HammerStyle.pan -> { st.crit += 0.3; st.chest *= 3 }
            HammerStyle.bat -> { st.radius *= 1.4; st.collateral += 0.6 }
            HammerStyle.choco -> st.loot *= 3
            else -> {}
        }
        // lo que trae la factura de ahora
        when (twist) {
            BillTwist.none -> {}
            BillTwist.prisa -> st.spawnEvery *= 0.7
            BillTwist.frenesi -> st.frenzyEarly += 6
            BillTwist.gordas -> st.fat += 0.3
            BillTwist.doradas -> st.golden *= 2
            BillTwist.cansado -> { st.stamina = rnd(st.stamina * 0.75); st.loot *= 1.5 }
            BillTwist.rey -> st.king += 0.75
        }
        stats = st
    }

    fun ringValue(e: RingEffect): Double = Content.rings.filter { it.effect == e }.sumOf { it.per * ringLevel(it) }

    // MARK: - Facturas

    val bill: BillDef get() = Content.bills[s.billIndex]
    /** en vacas: la factura vale según lo que valía una vaca cuando llegó (la de ahora y las siguientes, según lo de ahora) */
    fun billAmount(b: BillDef): Double {
        val tier = if (b.id == s.billIndex) s.billTier else s.tier
        val units = Content.billUnits(s.year * Content.bills.size + b.id) * (if (isInspection(b.id)) 2 else 1)
        return max(1.0, rnd(units * Content.pigValue(tier) / Content.pigValue(0) * (1 - ringValue(RingEffect.bills) / 100)))
    }
    /** días que hay para pagar la factura de ahora (la inspección da uno más) */
    val billDays: Int get() = bill.days + ringValue(RingEffect.extraDays).toInt() + (if (inspection) 1 else 0)

    /** precios en vacas del nivel de ahora (el corcho y los martillos) */
    fun cost(k: SkillDef): Double = max(1.0, rnd(k.cost(level(k)) * Content.pigValue(s.tier)))
    fun hammerCost(h: HammerDef): Double = rnd(Content.hammerUnits(h.id) * Content.pigValue(s.tier))
    val billAmount: Double get() = billAmount(bill)
    val daysLeft: Int get() = s.billDue - s.day      // 0 = hoy es el último día
    val nextBill: BillDef? get() = if (s.billIndex + 1 < Content.bills.size) Content.bills[s.billIndex + 1] else null

    fun payBill() {
        val a = billAmount
        if (s.cash < a || s.awaitingTaxChoice) { Sound.denied(); return }
        s.cash -= a
        // la inspección de Hacienda, si se paga, trae un sobre legendario
        if (inspection) s.pendingChests = s.pendingChests + Rarity.legendaria
        s.paidThisCycle += a
        s.billsThisRun += 1
        s.stats.billsPaid += 1
        progressQuests(QuestKind.facturas, add = 1.0)
        addXP(rnd(25.0 * (s.billIndex + 1)))
        Sound.stamp()
        if (s.billIndex == Content.bills.size - 1) {
            s.awaitingTaxChoice = true
            event = GameEvent.Taxes
        } else {
            s.billIndex += 1
            s.billTier = s.tier
            s.billDue = s.day + billDays - 1
        }
        save()
    }

    /** tras pagar a Hacienda: otro año (facturas más caras, huchas más ricas) */
    fun anotherYear() {
        s.awaitingTaxChoice = false
        s.year += 1
        s.billIndex = 0
        s.billTier = s.tier
        s.billDue = s.day + billDays - 1
        event = null
        Sound.till()
        save()
    }

    // MARK: - Bancarrota (prestigio)

    /** puntos de herencia: según las facturas pagadas en esta partida */
    val legacyGain: Double
        get() {
            // crece mucho con cada factura pagada: llegar más lejos compensa de verdad
            val base = 8 * 1.12.pow(s.billsThisRun)
            return floor(base * (1 + ringValue(RingEffect.legacy) / 100))
        }
    val startCash: Double
        get() {
            val l = ringValue(RingEffect.startCash)
            return if (l > 0) 50 * 4.0.pow(l - 1) else 0.0
        }

    fun bankruptcy(forced: Boolean = false) {
        val g = legacyGain
        // lo que quedaba en la cartera se lo lleva el banco: va a la hipoteca
        mortgageAdded = max(0.0, s.cash)
        addToMortgage(mortgageAdded)
        s.legacy += g
        s.stats.bankruptcies += 1
        s.cash = 0.0
        // cada partida las huchas vuelven a empezar (el huchario recuerda las descubiertas)
        s.day = 1; s.year = 0; s.billIndex = 0; s.paidThisCycle = 0.0; s.billsThisRun = 0; s.pigXP = 0.0
        // los recuerdos del abuelo ayudan a empezar: nivel de las huchas y martillos
        s.tier = (s.bestTier * ringValue(RingEffect.keepTier) / 100).toInt()
        val hammers = min(Content.hammers.size - 1, ringValue(RingEffect.startHammer).toInt())
        s.hammer = hammers; s.hammersOwned = (0..hammers).toSet(); s.skills = emptyMap(); s.parts = emptyMap()
        s.awaitingTaxChoice = false
        recompute()
        s.cash = startCash
        s.billTier = s.tier
        s.billDue = billDays
        event = if (forced) GameEvent.Collector(g) else GameEvent.Bankrupt(g)
        if (forced) Sound.sad() else Sound.fanfare()
        save()
    }

    // MARK: - El día

    fun startDay() {
        if (inRun || s.awaitingTaxChoice) return
        // la factura venció y se cerró el juego antes de decidir: primero, el cobrador
        if (s.day > s.billDue) { afterReport(); return }
        recompute()
        inRun = true
        Sound.click()
    }

    fun finishDay(r: DayReport) {
        inRun = false
        s.stats.days += 1
        s.stats.broken += r.broken; s.stats.swings += r.swings; s.stats.crits += r.crits
        s.stats.golden += r.golden; s.stats.kings += r.kings
        r.record = r.earned > s.stats.bestDay && s.stats.days > 1
        s.stats.bestDay = max(s.stats.bestDay, r.earned)
        s.stats.bestCombo = max(s.stats.bestCombo, r.bestCombo.toDouble())
        s.stats.frenzies += r.frenzies
        s.pendingChests = s.pendingChests + r.chests
        for (c in r.coins) addCoin(c)
        s.day += 1
        val by = s.brokenByKind.toMutableMap()
        for ((k, n) in r.byKind) by[k] = (by[k] ?: 0.0) + n
        s.brokenByKind = by
        addPigXP(r.broken.toDouble())
        progressQuests(QuestKind.romper, add = r.broken.toDouble())
        progressQuests(QuestKind.ganar, add = r.earned)
        progressQuests(QuestKind.combo, best = r.bestCombo.toDouble())
        progressQuests(QuestKind.doradas, add = r.golden.toDouble())
        progressQuests(QuestKind.criticos, add = r.crits.toDouble())
        progressQuests(QuestKind.diaRico, best = r.earned)
        progressQuests(QuestKind.frenesi, add = r.frenzies.toDouble())
        if (s.tutorial < 9) s.tutorial = 9
        if (ringValue(RingEffect.autoBuy) > 0 && s.autoBuy) autoBuyAll()
        report = r
        s.lastDayEarned = r.earned
        addXP(r.xp)
        refillQuests()
        save()
    }

    /** al cerrar el ticket del día: si la factura venció, viene el cobrador */
    fun afterReport() {
        report = null
        if (s.day <= s.billDue || s.awaitingTaxChoice) return
        // la factura vencía ayer: se paga sola si llega el dinero; si no, viene el cobrador
        if (s.cash >= billAmount) { autoPaid = bill.company; payBill() }
        else if (Money.canUse(Reward.prorroga)) event = GameEvent.Warning
        else bankruptcy(forced = true)
    }

    /** dinero que entra durante el día (lo llama la mesa) */
    fun earn(v: Double) {
        s.cash += v
        s.stats.earned += v
    }

    // MARK: - Tienda

    fun canBuy(k: SkillDef): Boolean {
        val l = level(k)
        if (l >= k.maxLevel) return false
        val p = SkillTree.main.parent[k.id]
        if (p != null && (s.skills[p] ?: 0) == 0) return false
        return s.cash >= cost(k)
    }
    fun isVisible(k: SkillDef): Boolean {
        val p = SkillTree.main.parent[k.id] ?: return true
        return (s.skills[p] ?: 0) > 0 || level(k) > 0
    }

    fun buy(k: SkillDef, quiet: Boolean = false): Boolean {
        if (!canBuy(k)) { if (!quiet) Sound.denied(); return false }
        s.cash -= cost(k)
        s.skills = s.skills + (k.id to level(k) + 1)
        progressQuests(QuestKind.mejoras, add = 1.0)
        recompute()
        // comprando muchas de golpe, se guarda y suena una sola vez al final
        if (!quiet) { Sound.coin(); save() }
        return true
    }

    /** el cuñado contable: guarda para la factura si vence ya y gasta el resto en lo más barato */
    fun autoBuyAll() {
        val reserve = if (daysLeft <= 1) billAmount else 0.0
        var n = 0
        while (n < 2_000) {
            val skill = Content.skills.filter { canBuy(it) }.minByOrNull { cost(it) }
            val part = Content.parts.filter { canBuyPart(it) }.minByOrNull { partCost(it) }
            val sc = skill?.let { cost(it) } ?: Double.POSITIVE_INFINITY
            val pc = part?.let { partCost(it) } ?: Double.POSITIVE_INFINITY
            if (min(sc, pc) > s.cash - reserve) break
            if (sc <= pc && skill != null) buy(skill, quiet = true) else if (part != null) buyPart(part, quiet = true)
            n += 1
        }
    }

    fun canGet(k: SkillDef): Boolean = canBuy(k)
    fun get(k: SkillDef, quiet: Boolean = false): Boolean = buy(k, quiet)
    fun missing(k: SkillDef): Double = max(0.0, cost(k) - s.cash)

    fun buyHammer(h: HammerDef) {
        if (h.id in s.hammersOwned) { s.hammer = h.id; recompute(); Sound.click(); return }
        if (s.cash < hammerCost(h)) { Sound.denied(); return }
        s.cash -= hammerCost(h)
        s.hammersOwned = s.hammersOwned + h.id
        s.hammer = h.id
        recompute()
        Sound.till()
        save()
    }

    fun buyRing(r: RingDef) {
        val l = ringLevel(r)
        if (l >= r.maxLevel || s.legacy < r.cost(l)) { Sound.denied(); return }
        s.legacy -= r.cost(l)
        s.rings = s.rings + (r.id to l + 1)
        // los martillos del bisabuelo llegan al momento
        if (r.effect == RingEffect.startHammer) s.hammersOwned = s.hammersOwned + (0..min(Content.hammers.size - 1, ringValue(RingEffect.startHammer).toInt()))
        recompute()
        Sound.till()
        save()
    }

    /** los animales se ganan pagando facturas */
    fun hasSkin(k: SkinDef): Boolean = k.id in s.skinsOwned || (k.product?.let { Shop.owns(it) } ?: (s.stats.billsPaid >= k.bills))

    /** el cobrador da un día más para pagar */
    fun reprieve() {
        s.billDue = s.day
        event = null
        Sound.till()
        save()
    }
    fun pickSkin(k: SkinDef) {
        if (!hasSkin(k)) { Sound.denied(); return }
        s.skinsOwned = s.skinsOwned + k.id; s.skin = k.id; Animal.use(k); Sound.click(); save()
    }

    // MARK: - Sobres y monedas

    fun rollChest(): Rarity {
        val luck = stats.chestLuck.toDouble()
        val w = listOf(Rarity.comun to 70.0, Rarity.rara to 22 + luck * 2, Rarity.epica to 7 + luck * 1.5, Rarity.legendaria to 1 + luck * 0.5)
        var r = Random.nextDouble() * w.sumOf { it.second }
        for ((k, x) in w) { if (r < x) return k; r -= x }
        return Rarity.comun
    }

    private fun randomCoin(rarities: List<Rarity>): CoinDef {
        val pool = Content.coins.filter { it.rarity in rarities }
        return pool.randomOrNull() ?: Content.coins[0]
    }

    private fun addCoin(id: String, refresh: Boolean = true): Pair<Boolean, Double> {
        val c = Content.coins.firstOrNull { it.id == id } ?: return false to 0.0
        val had = (s.coins[id] ?: 0) > 0
        s.coins = s.coins + (id to (s.coins[id] ?: 0) + 1)
        // las repetidas se cambian por dinero (los puntos de herencia solo llegan con la bancarrota)
        if (had) {
            val v = rnd(Content.pigValue(s.tier) * stats.loot * c.rarity.duplicate * 50)
            s.cash += v; s.stats.earned += v
            return true to v
        }
        if (refresh) recompute()
        return false to 0.0
    }

    /** moneda que suelta una hucha dorada */
    fun goldenCoinDrop(): String? {
        if (Random.nextDouble() >= 0.25) return null
        val roll = Random.nextDouble()
        val r = if (roll < 0.6) listOf(Rarity.comun) else if (roll < 0.9) listOf(Rarity.rara) else if (roll < 0.99) listOf(Rarity.epica) else listOf(Rarity.legendaria)
        return randomCoin(r).id
    }

    /** abre el primer sobre pendiente */
    fun openChest(): ChestPrize? {
        if (s.pendingChests.isEmpty()) return null
        val rarity = s.pendingChests.first()
        s.pendingChests = s.pendingChests.drop(1)
        val p = prize(rarity, refresh = true)
        save()
        return p
    }

    /** abre todos de una: se reparte y se guarda una sola vez */
    fun openAllChests(): List<ChestPrize> {
        val list = s.pendingChests
        if (list.isEmpty()) return emptyList()
        s.pendingChests = emptyList()
        val out = list.map { prize(it, refresh = false) }
        recompute()
        save()
        return out
    }

    private fun prize(rarity: Rarity, refresh: Boolean): ChestPrize {
        val base = Content.pigValue(s.tier) * stats.loot * stats.chestValue
        var cash = 0.0
        var coin: CoinDef? = null
        when (rarity) {
            Rarity.comun -> cash = base * 25
            Rarity.rara -> {
                cash = base * 80
                if (Random.nextDouble() < 0.35) coin = randomCoin(listOf(Rarity.comun, Rarity.rara))
            }
            Rarity.epica -> {
                cash = base * 250
                coin = randomCoin(if (Random.nextDouble() < 0.7) listOf(Rarity.rara) else listOf(Rarity.epica))
            }
            Rarity.legendaria -> {
                cash = base * 1_000
                coin = randomCoin(if (Random.nextDouble() < 0.7) listOf(Rarity.epica) else listOf(Rarity.legendaria))
            }
        }
        s.cash += cash
        s.stats.earned += cash
        s.stats.chests += 1
        var dup = false; var legacy = 0.0
        if (coin != null) { val r = addCoin(coin.id, refresh); dup = r.first; legacy = r.second }
        return ChestPrize(rarity, cash, coin, dup, legacy)
    }

    // MARK: - Ajustes

    fun erase() {
        Persistence.erase()
        val settings = s.settings
        s = SaveState()
        s.settings = settings
        s.seenIntro = true
        s.tutorial = 9
        inRun = false; report = null; event = null
        recompute()
        save()
    }
}
