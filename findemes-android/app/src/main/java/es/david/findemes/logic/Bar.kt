package es.david.findemes.logic

import es.david.findemes.model.Content
import es.david.findemes.model.PartDef
import es.david.findemes.model.Rarity
import es.david.findemes.model.ScratchPrize
import es.david.findemes.model.SlotSymbol
import es.david.findemes.support.Fmt
import es.david.findemes.support.rnd
import java.util.Calendar
import kotlin.math.max
import kotlin.math.pow
import kotlin.random.Random

data class SpinResult(val reels: List<SlotSymbol>, val won: Double, val chest: Rarity?)

data class ScratchCard(val cells: List<ScratchPrize?>, val prize: ScratchPrize?)   // null = casilla vacía (una cruz)

// MARK: - Mejoras del martillo

fun Game.partLevel(p: PartDef): Int = s.parts[p.id] ?: 0

/** en huchas del nivel de ahora: así siempre están al alcance */
fun Game.partCost(p: PartDef, l: Int? = null): Double {
    val lv = l ?: partLevel(p)
    return max(1.0, rnd(Content.pigValue(s.tier) * p.base * p.growth.pow(lv)))
}

fun Game.canBuyPart(p: PartDef): Boolean = partLevel(p) < p.maxLevel && s.cash >= partCost(p)

fun Game.buyPart(p: PartDef, quiet: Boolean = false): Boolean {
    if (!canBuyPart(p)) { if (!quiet) Sound.denied(); return false }
    s.cash -= partCost(p)
    s.parts = s.parts + (p.id to partLevel(p) + 1)
    recompute()
    if (!quiet) { Sound.coin(); save() }
    return true
}

/** compra niveles de una mejora hasta que no llegue el dinero */
fun Game.buyPartMax(p: PartDef) {
    var n = 0
    while (n < 200 && buyPart(p, quiet = true)) n += 1
    if (n > 0) { Sound.till(); save() } else Sound.denied()
}

// MARK: - La feria

val todayKey: String
    get() {
        val c = Calendar.getInstance()
        return "${c.get(Calendar.YEAR)}-${c.get(Calendar.MONTH) + 1}-${c.get(Calendar.DAY_OF_MONTH)}"
    }

/** tres tiradas gratis al día; no se apuesta nada */
const val dailySpins = 3
val Game.freeSpins: Int get() = if (s.lastSpin != todayKey) dailySpins else max(0, dailySpins - s.spinsToday)

fun Game.spin(): SpinResult? {
    if (freeSpins <= 0) { Sound.denied(); return null }
    if (s.lastSpin != todayKey) { s.lastSpin = todayKey; s.spinsToday = 0 }
    s.spinsToday += 1
    s.stats.spins += 1
    val reels = List(3) { SlotSymbol.random() }
    // cada premio pequeño vale cinco huchas de las de ahora
    val unit = pigWorth * 5
    var won = 0.0
    var chest: Rarity? = null
    if (reels[0] == reels[1] && reels[1] == reels[2]) {
        won = unit * reels[0].pays
        if (reels[0] == SlotSymbol.corona) { chest = Rarity.legendaria; s.stats.jackpots += 1 }
        else if (reels[0] == SlotSymbol.anillo) chest = Rarity.epica
    } else if (reels.toSet().size == 2) {
        won = unit
    }
    won = rnd(won)
    s.cash += won
    s.stats.earned += won
    chest?.let { s.pendingChests = s.pendingChests + it }
    save()
    return SpinResult(reels, won, chest)
}

/** un rasca gratis al día */
val Game.freeScratch: Boolean get() = s.lastScratch != todayKey

fun Game.buyScratch(): ScratchCard? {
    if (!freeScratch) { Sound.denied(); return null }
    s.lastScratch = todayKey
    s.stats.scratches += 1
    save()
    // primero se decide el premio y luego se rellena la tarjeta
    var r = Random.nextDouble()
    var prize: ScratchPrize? = null
    for (p in ScratchPrize.entries.reversed()) { if (r < p.chance) { prize = p; break }; r -= p.chance }
    val cells = mutableListOf<ScratchPrize?>()
    if (prize != null) cells += listOf(prize, prize, prize)
    // el resto, sin que se repita nada tres veces
    val others = ScratchPrize.entries.filter { it != prize }
    val count = mutableMapOf<ScratchPrize, Int>()
    while (cells.size < 9) {
        if (Random.nextDouble() < 0.2) { cells.add(null); continue }
        val o = others.random()
        if ((count[o] ?: 0) < 2) { count[o] = (count[o] ?: 0) + 1; cells.add(o) }
    }
    return ScratchCard(cells.shuffled(), prize)
}

/** cobra el premio del rasca; devuelve el texto de lo ganado */
fun Game.claimScratch(p: ScratchPrize?): String {
    if (p == null) return ""
    val worth = Content.pigValue(s.tier) * stats.loot
    fun cash(k: Double, fanfare: Boolean = false): String {
        val v = rnd(worth * k); s.cash += v; s.stats.earned += v
        if (fanfare) Sound.fanfare() else Sound.till()
        save(); return Fmt.money(v)
    }
    when (p) {
        ScratchPrize.calderilla -> return cash(120.0)
        ScratchPrize.fajo -> return cash(500.0)
        ScratchPrize.sobreRaro -> s.pendingChests = s.pendingChests + Rarity.rara
        ScratchPrize.sobreEpico -> s.pendingChests = s.pendingChests + Rarity.epica
        ScratchPrize.sobreLegendario -> s.pendingChests = s.pendingChests + Rarity.legendaria
        ScratchPrize.herencia -> return cash(2_500.0, fanfare = true)
    }
    Sound.fanfare()
    save()
    return p.title
}
