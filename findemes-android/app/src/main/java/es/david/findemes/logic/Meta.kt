package es.david.findemes.logic

import es.david.findemes.model.Content
import es.david.findemes.model.PigKind
import es.david.findemes.model.PigLevel
import es.david.findemes.model.Rarity
import es.david.findemes.support.Fmt
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import es.david.findemes.support.rnd
import kotlin.random.Random

// MARK: - Encargos (misiones): siempre hay tres, y al cobrar uno sale otro

enum class QuestKind(val text: String, val icon: String) {
    romper("Rompe % {huchas}", "hammer.fill"),
    ganar("Gana %", "eurosign.circle.fill"),
    combo("Haz un combo de %", "flame.fill"),
    doradas("Rompe % {huchas} dorad{as}", "star.circle.fill"),
    criticos("Da % golpes críticos", "burst.fill"),
    diaRico("Gana % en un solo día", "sun.max.fill"),
    mejoras("Compra % mejoras del corcho", "pin.fill"),
    facturas("Paga % facturas", "doc.text.fill"),
    frenesi("Entra % veces en frenesí", "bolt.fill");

    val money: Boolean get() = this == ganar || this == diaRico
}

data class Quest(
    val id: String = UUID.randomUUID().toString(),
    val kind: QuestKind,
    val target: Double,
    val progress: Double = 0.0,
    /** premio: tantas huchas de las de ahora */
    val reward: Double,
    val xp: Double,
) {
    val done: Boolean get() = progress >= target

    fun toJson() = JSONObject().apply {
        put("id", id); put("kind", kind.name); put("target", target); put("progress", progress); put("reward", reward); put("xp", xp)
    }

    companion object {
        fun from(o: JSONObject?): Quest? {
            if (o == null) return null
            val k = QuestKind.entries.firstOrNull { it.name == o.optString("kind") } ?: return null
            return Quest(o.optString("id", UUID.randomUUID().toString()), k, o.optDouble("target", 1.0), o.optDouble("progress", 0.0), o.optDouble("reward", 50.0), o.optDouble("xp", 40.0))
        }
    }
}

// MARK: - Logros: cada uno da +1 % de dinero para siempre

enum class AchMetric {
    broken, earned, bills, bankruptcies, days, golden, kings, chests, crits, combo, frenzies, level, coins, skins, hammers, quests, bestDay, pigLevel, spins, jackpots, scratches, parts
}

class AchDef(val id: String, val name: String, val metric: AchMetric, val target: Double) {
    val desc: String
        get() {
            val n = Fmt.num(target)
            val vez = if (target == 1.0) "vez" else "veces"
            return when (metric) {
                AchMetric.broken -> "Rompe $n {huchas}"
                AchMetric.earned -> "Gana ${Fmt.money(target)} en total"
                AchMetric.bills -> "Paga $n facturas"
                AchMetric.bankruptcies -> "Declárate en bancarrota $n $vez"
                AchMetric.days -> "Juega $n días"
                AchMetric.golden -> "Rompe $n {huchas} dorad{as}"
                AchMetric.kings -> "Derrota al Rey {Hucha} $n $vez"
                AchMetric.chests -> "Abre $n sobres"
                AchMetric.crits -> "Da $n golpes críticos"
                AchMetric.combo -> "Haz un combo de $n"
                AchMetric.frenzies -> "Entra $n $vez en frenesí"
                AchMetric.level -> "Llega al nivel $n"
                AchMetric.coins -> "Junta $n monedas del álbum"
                AchMetric.skins -> "Ten $n animales"
                AchMetric.hammers -> "Ten $n martillos a la vez"
                AchMetric.quests -> "Cumple $n encargos"
                AchMetric.bestDay -> "Gana ${Fmt.money(target)} en un día"
                AchMetric.pigLevel -> "Sube {las} {huchas} al nivel $n"
                AchMetric.spins -> "Tira $n veces en la tragaperras"
                AchMetric.jackpots -> "Saca tres coronas en la tragaperras"
                AchMetric.scratches -> "Rasca $n rascas"
                AchMetric.parts -> "Sube $n niveles las mejoras del martillo en una partida"
            }
        }
}

class DailyPrize(val name: String, val chest: Rarity?, val pigs: Double, val legacy: Double)

object Meta {
    val achievements: List<AchDef> by lazy {
        fun tiers(m: AchMetric, key: String, list: List<Pair<Double, String>>) = list.map { AchDef("$key-${it.first.toLong()}", it.second, m, it.first) }
        tiers(AchMetric.broken, "rotas", listOf(10.0 to "Primer estropicio", 100.0 to "Manitas", 1_000.0 to "Demoledor", 10_000.0 to "Terror de {las} {huchas}", 100_000.0 to "Plaga porcina", 1_000_000.0 to "El fin de {las} {huchas}")) +
            tiers(AchMetric.earned, "ganado", listOf(1_000.0 to "Primeros ahorros", 100_000.0 to "Colchón", 10_000_000.0 to "Patrimonio", 1e9 to "Fortuna", 1e12 to "Imperio", 1e15 to "Más que el Estado")) +
            tiers(AchMetric.bestDay, "dia", listOf(500.0 to "Buen día", 50_000.0 to "Día redondo", 5e6 to "Día histórico", 5e9 to "El día del siglo")) +
            tiers(AchMetric.bills, "facturas", listOf(1.0 to "Al corriente", 12.0 to "Un año sin deudas", 50.0 to "Pagador ejemplar", 200.0 to "Cliente favorito", 1_000.0 to "Socio de honor")) +
            tiers(AchMetric.bankruptcies, "quiebra", listOf(1.0 to "Borrón y cuenta nueva", 5.0 to "Experto en empezar", 20.0 to "Fénix", 100.0 to "Inmortal")) +
            tiers(AchMetric.days, "dias", listOf(7.0 to "Una semana", 30.0 to "Un mes entero", 100.0 to "Constancia", 365.0 to "Un año de martillazos", 1_000.0 to "Leyenda del barrio")) +
            tiers(AchMetric.golden, "doradas", listOf(1.0 to "¡Brilla!", 25.0 to "Buscador de oro", 250.0 to "Fiebre del oro", 2_500.0 to "Rey Midas")) +
            tiers(AchMetric.kings, "rey", listOf(1.0 to "Regicida", 10.0 to "Cazarreyes", 100.0 to "Sin corona")) +
            tiers(AchMetric.chests, "sobres", listOf(1.0 to "Correo", 50.0 to "Coleccionista de sobres", 500.0 to "Cartero")) +
            tiers(AchMetric.crits, "criticos", listOf(100.0 to "Buen ojo", 1_000.0 to "Puntería", 10_000.0 to "Francotirador")) +
            tiers(AchMetric.combo, "combo", listOf(10.0 to "En racha", 25.0 to "Imparable", 50.0 to "Máquina", 100.0 to "Huracán")) +
            tiers(AchMetric.frenzies, "frenesi", listOf(1.0 to "¡Frenesí!", 25.0 to "Adicto al frenesí", 250.0 to "Puro nervio")) +
            tiers(AchMetric.level, "nivel", listOf(5.0 to "Aprendiz", 10.0 to "Ahorrador", 25.0 to "Inversor", 50.0 to "Magnate", 100.0 to "Leyenda")) +
            tiers(AchMetric.coins, "album", listOf(5.0 to "Numismático", 12.0 to "Medio álbum", 24.0 to "Álbum completo")) +
            tiers(AchMetric.skins, "personajes", listOf(3.0 to "Granjero", 6.0 to "Toda la granja")) +
            tiers(AchMetric.hammers, "martillos", listOf(3.0 to "Caja de herramientas", 6.0 to "Ferretería propia", 8.0 to "Todos los martillos")) +
            tiers(AchMetric.pigLevel, "huchas", listOf(10.0 to "Criador", 25.0 to "Granja de {huchas}", 45.0 to "{Huchas} robótic{as}", 60.0 to "Hasta el espacio", 80.0 to "Más allá", 100.0 to "{Huchas} millonari{as}", 150.0 to "Infinito")) +
            tiers(AchMetric.hammers, "martillos2", listOf(10.0 to "Coleccionista de martillos", 12.0 to "La chancla de oro", 16.0 to "Un yunque con un palo")) +
            tiers(AchMetric.spins, "tragaperras", listOf(1.0 to "Una monedita", 30.0 to "Cliente de la feria", 150.0 to "Feriante")) +
            tiers(AchMetric.jackpots, "bote", listOf(1.0 to "¡Bote!")) +
            tiers(AchMetric.scratches, "rascas", listOf(1.0 to "Rasca, rasca", 30.0 to "Uña de oro", 200.0 to "Lotero")) +
            tiers(AchMetric.parts, "taller", listOf(10.0 to "Bricolaje", 60.0 to "Manitas de Paco", 180.0 to "Martillo tuneado")) +
            tiers(AchMetric.coins, "album2", listOf(36.0 to "Álbum ampliado")) +
            tiers(AchMetric.hammers, "martillos3", listOf(19.0 to "Sartenazo", 22.0 to "El juez ha hablado")) +
            tiers(AchMetric.pigLevel, "huchas2", listOf(180.0 to "En las nubes", 220.0 to "Agujero negro")) +
            tiers(AchMetric.quests, "encargos", listOf(5.0 to "Recadero", 50.0 to "Eficiente", 250.0 to "Indispensable", 1_000.0 to "Hombre para todo"))
    }

    val titles = listOf(1 to "Becario", 3 to "Mileurista", 6 to "Autónomo", 10 to "Ahorrador", 15 to "Inversor", 20 to "Tiburón", 30 to "Magnate", 40 to "Banquero", 60 to "Lobo de Wall Street", 80 to "Dueño de Hacienda")
    fun title(level: Int): String = titles.lastOrNull { it.first <= level }?.second ?: "Becario"
    fun xpNeeded(level: Int): Double = rnd(60 * 1.2.pow(level - 1))

    /** premios del calendario de 7 días */
    val daily = listOf(
        DailyPrize("Dinero", null, 40.0, 0.0), DailyPrize("Sobre", Rarity.comun, 0.0, 0.0), DailyPrize("Dinero", null, 120.0, 0.0), DailyPrize("Sobre raro", Rarity.rara, 0.0, 0.0),
        DailyPrize("Mucho dinero", null, 300.0, 0.0), DailyPrize("Sobre épico", Rarity.epica, 0.0, 0.0), DailyPrize("¡Sobre legendario!", Rarity.legendaria, 0.0, 0.0),
    )

    fun dayKey(millis: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = millis }
        return String.format(java.util.Locale.US, "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
    }
}

/** lo que se desbloquea poco a poco (para no abrumar al principio) */
enum class Feature { mejoras, martillos, encargos, logros, monedas, bar }

fun Game.unlocked(f: Feature): Boolean {
    val st = s.stats
    val veteran = st.bankruptcies > 0 || s.legacy > 0
    return when (f) {
        Feature.mejoras, Feature.encargos -> st.days >= 1 || veteran
        Feature.martillos -> st.billsPaid >= 1 || veteran
        Feature.logros -> st.days >= 2 || veteran
        Feature.monedas -> st.chests > 0 || s.coins.isNotEmpty() || s.pendingChests.isNotEmpty() || veteran
        Feature.bar -> st.days >= 3 || veteran
    }
}

/** lo que vale una hucha normal ahora mismo (para que los premios crezcan contigo) */
val Game.pigWorth: Double get() = Content.pigValue(s.tier) * stats.loot

// MARK: nivel

val Game.xpNeeded: Double get() = Meta.xpNeeded(s.level)

fun Game.addXP(v: Double) {
    if (v <= 0) return
    s.xp += rnd(v)
    var ups = 0
    while (s.xp >= Meta.xpNeeded(s.level)) {
        s.xp -= Meta.xpNeeded(s.level)
        s.level += 1
        ups += 1
        // cada nivel trae un sobre; los múltiplos de 5 y de 10, mejores
        s.pendingChests = s.pendingChests + (if (s.level % 10 == 0) Rarity.legendaria else if (s.level % 5 == 0) Rarity.epica else Rarity.comun)
    }
    if (ups > 0) {
        recompute()
        levelUp = s.level
    }
}

// MARK: nivel de las huchas

val Game.pigNeeded: Double get() = PigLevel.needed(s.tier)

fun Game.addPigXP(v: Double) {
    s.pigXP += v * stats.pigXP
    val fresh = mutableListOf<PigKind>()
    while (s.pigXP >= PigLevel.needed(s.tier)) {
        s.pigXP -= PigLevel.needed(s.tier)
        s.tier += 1
        // solo se celebra la primera vez que sale cada una
        if (s.tier > s.bestTier) {
            fresh += PigKind.entries.filter { it.minTier == s.tier && (!it.special || it == PigKind.rey) }
            s.bestTier = s.tier
        }
    }
    if (fresh.isNotEmpty()) newKinds = newKinds + fresh
}

// MARK: encargos

fun Game.refillQuests() {
    if (!unlocked(Feature.encargos)) return
    while (s.quests.size < 3) {
        val used = s.quests.map { it.kind }.toSet()
        val pool = QuestKind.entries.filter { it !in used }.toMutableList()
        if (s.level < 3) pool.removeAll { it == QuestKind.frenesi || it == QuestKind.doradas }
        if (s.billIndex >= Content.bills.size - 1) pool.removeAll { it == QuestKind.facturas }
        val k = pool.randomOrNull() ?: break
        s.quests = s.quests + makeQuest(k)
    }
}

private fun Game.makeQuest(k: QuestKind): Quest {
    val L = s.level.toDouble()
    val w = pigWorth
    val target = when (k) {
        QuestKind.romper -> rnd(50 * (1 + L * 0.18))
        QuestKind.ganar -> rnd(w * 150 * (1 + L * 0.05))
        QuestKind.combo -> rnd(min(80.0, 10 + L * 1.5))
        QuestKind.doradas -> max(1.0, rnd(L / 6))
        QuestKind.criticos -> rnd(12 + L * 2.5)
        QuestKind.diaRico -> rnd(w * 70)
        QuestKind.mejoras -> max(2.0, rnd(2 + L / 8))
        QuestKind.facturas -> max(1.0, min(3.0, rnd(L / 10)))
        QuestKind.frenesi -> max(1.0, rnd(L / 12))
    }
    return Quest(kind = k, target = max(1.0, target), reward = Random.nextDouble(50.0, 90.0), xp = rnd(40 + L * 10))
}

fun Game.progressQuests(k: QuestKind, add: Double = 0.0, best: Double? = null) {
    s.quests = s.quests.map { q ->
        if (q.kind != k || q.done) q
        else {
            val p = if (best != null) max(q.progress, best) else q.progress + add
            q.copy(progress = min(p, q.target))
        }
    }
}

fun Game.questReward(q: Quest): Double = rnd(q.reward * pigWorth)

fun Game.claim(q: Quest) {
    val i = s.quests.indexOfFirst { it.id == q.id }
    if (i < 0 || !s.quests[i].done) return
    val cash = questReward(q)
    s.cash += cash
    s.stats.earned += cash
    s.stats.missions += 1
    s.quests = s.quests.filterIndexed { idx, _ -> idx != i }
    Sound.fanfare()
    addXP(q.xp)
    refillQuests()
    save()
}

// MARK: logros

fun Game.metric(m: AchMetric): Double {
    val st = s.stats
    return when (m) {
        AchMetric.broken -> st.broken
        AchMetric.earned -> st.earned
        AchMetric.bills -> st.billsPaid
        AchMetric.bankruptcies -> st.bankruptcies
        AchMetric.days -> st.days
        AchMetric.golden -> st.golden
        AchMetric.kings -> st.kings
        AchMetric.chests -> st.chests
        AchMetric.crits -> st.crits
        AchMetric.combo -> st.bestCombo
        AchMetric.frenzies -> st.frenzies
        AchMetric.level -> s.level.toDouble()
        AchMetric.coins -> Content.coins.count { (s.coins[it.id] ?: 0) > 0 }.toDouble()
        AchMetric.skins -> Content.skins.count { hasSkin(it) }.toDouble()
        AchMetric.hammers -> s.hammersOwned.size.toDouble()
        AchMetric.quests -> st.missions
        AchMetric.bestDay -> st.bestDay
        AchMetric.pigLevel -> s.bestTier.toDouble()
        AchMetric.spins -> st.spins
        AchMetric.jackpots -> st.jackpots
        AchMetric.scratches -> st.scratches
        AchMetric.parts -> Content.parts.sumOf { partLevel(it) }.toDouble()
    }
}

val Game.achievementsReady: Int
    get() = Meta.achievements.count { it.id !in s.achievements && metric(it.metric) >= it.target }

fun Game.claim(a: AchDef) {
    if (a.id in s.achievements || metric(a.metric) < a.target) return
    s.achievements = s.achievements + a.id
    Sound.fanfare()
    recompute()
    addXP(30 + s.achievements.size * 5.0)
    save()
}

// MARK: premio diario

val Game.dailyReady: Boolean get() = s.tutorial >= 9 && s.stats.days >= 1 && s.lastDaily != Meta.dayKey(System.currentTimeMillis())

/** qué casilla del calendario toca hoy (0…6) */
val Game.dailyIndex: Int
    get() {
        val yesterday = Meta.dayKey(System.currentTimeMillis() - 86_400_000)
        return if (s.lastDaily == yesterday) s.streak % 7 else 0
    }

fun Game.claimDaily() {
    if (!dailyReady) return
    val r = Meta.daily[dailyIndex]
    if (r.pigs > 0) { val c = rnd(r.pigs * pigWorth); s.cash += c; s.stats.earned += c }
    r.chest?.let { s.pendingChests = s.pendingChests + it }
    val yesterday = Meta.dayKey(System.currentTimeMillis() - 86_400_000)
    s.streak = if (s.lastDaily == yesterday) s.streak + 1 else 1
    s.lastDaily = Meta.dayKey(System.currentTimeMillis())
    Sound.fanfare()
    save()
}
