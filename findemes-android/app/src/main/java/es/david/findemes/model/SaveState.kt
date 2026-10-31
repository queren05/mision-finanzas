package es.david.findemes.model

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import es.david.findemes.logic.Meta
import es.david.findemes.logic.Quest
import es.david.findemes.logic.QuestKind
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min

// Todo lo guardado es estado de Compose: las pantallas se redibujan solas al cambiar algo.
// El JSON usa las mismas claves que la versión de iPhone.

class Stats {
    var broken by mutableDoubleStateOf(0.0)
    var swings by mutableDoubleStateOf(0.0)
    var earned by mutableDoubleStateOf(0.0)
    var billsPaid by mutableDoubleStateOf(0.0)
    var days by mutableDoubleStateOf(0.0)
    var bankruptcies by mutableDoubleStateOf(0.0)
    var kings by mutableDoubleStateOf(0.0)
    var golden by mutableDoubleStateOf(0.0)
    var chests by mutableDoubleStateOf(0.0)
    var bestDay by mutableDoubleStateOf(0.0)
    var crits by mutableDoubleStateOf(0.0)
    var bestCombo by mutableDoubleStateOf(0.0)
    var frenzies by mutableDoubleStateOf(0.0)
    var missions by mutableDoubleStateOf(0.0)
    var spins by mutableDoubleStateOf(0.0)
    var jackpots by mutableDoubleStateOf(0.0)
    var scratches by mutableDoubleStateOf(0.0)

    fun toJson() = JSONObject().apply {
        put("broken", broken); put("swings", swings); put("earned", earned); put("billsPaid", billsPaid); put("days", days)
        put("bankruptcies", bankruptcies); put("kings", kings); put("golden", golden); put("chests", chests); put("bestDay", bestDay)
        put("crits", crits); put("bestCombo", bestCombo); put("frenzies", frenzies); put("missions", missions)
        put("spins", spins); put("jackpots", jackpots); put("scratches", scratches)
    }

    companion object {
        fun from(o: JSONObject?): Stats = Stats().apply {
            if (o == null) return@apply
            fun v(k: String) = o.optDouble(k, 0.0).let { if (it.isNaN()) 0.0 else it }
            broken = v("broken"); swings = v("swings"); earned = v("earned"); billsPaid = v("billsPaid"); days = v("days")
            bankruptcies = v("bankruptcies"); kings = v("kings"); golden = v("golden"); chests = v("chests"); bestDay = v("bestDay")
            crits = v("crits"); bestCombo = v("bestCombo"); frenzies = v("frenzies"); missions = v("missions")
            spins = v("spins"); jackpots = v("jackpots"); scratches = v("scratches")
        }
    }
}

class Settings {
    var sound by mutableStateOf(true)
    var haptics by mutableStateOf(true)
    var music by mutableStateOf(true)
    /** "auto" (el del teléfono), "es", "en" o "pt" */
    var lang by mutableStateOf("auto")
    /** avisos al teléfono (dinero lleno y premio diario) */
    var reminders by mutableStateOf(true)
    /** ya se pidió el permiso de avisos una vez */
    var askedReminders = false

    fun toJson() = JSONObject().apply { put("sound", sound); put("haptics", haptics); put("music", music); put("lang", lang); put("reminders", reminders); put("askedReminders", askedReminders) }

    companion object {
        fun from(o: JSONObject?): Settings = Settings().apply {
            if (o == null) return@apply
            sound = o.optBoolean("sound", true); haptics = o.optBoolean("haptics", true); music = o.optBoolean("music", true)
            lang = o.optString("lang", "auto")
            reminders = o.optBoolean("reminders", true); askedReminders = o.optBoolean("askedReminders", false)
        }
    }
}

/** Todo lo que se guarda */
class SaveState {
    // la partida de ahora (se pierde en la bancarrota)
    var cash by mutableDoubleStateOf(0.0)
    var day by mutableIntStateOf(1)
    var year by mutableIntStateOf(0)                  // años seguidos tras pagar a Hacienda
    var billIndex by mutableIntStateOf(0)
    var billDue by mutableIntStateOf(3)               // último día para pagar la factura de ahora
    var paidThisCycle by mutableDoubleStateOf(0.0)
    var tier by mutableIntStateOf(0)                  // nivel de las huchas
    var hammer by mutableIntStateOf(0)
    var hammersOwned by mutableStateOf(setOf(0))
    var skills by mutableStateOf(mapOf<String, Int>())
    var pendingChests by mutableStateOf(listOf<Rarity>())
    var awaitingTaxChoice by mutableStateOf(false)
    // lo que se queda para siempre
    var legacy by mutableDoubleStateOf(0.0)
    var rings by mutableStateOf(mapOf<String, Int>())
    var coins by mutableStateOf(mapOf<String, Int>())
    var stats by mutableStateOf(Stats())
    var settings by mutableStateOf(Settings())
    var seenIntro by mutableStateOf(false)
    var skin by mutableStateOf("vaca")
    var skinsOwned by mutableStateOf(setOf("vaca", "cerdo"))
    // lo que engancha: nivel, encargos, logros, y premio diario
    var level by mutableIntStateOf(1)
    var xp by mutableDoubleStateOf(0.0)
    var quests by mutableStateOf(listOf<Quest>())
    var achievements by mutableStateOf(setOf<String>())
    var streak by mutableIntStateOf(0)
    var lastDaily by mutableStateOf("")
    var tutorial by mutableIntStateOf(0)
    /** el nivel de las huchas es `tier`; esto es lo que lleva hacia el siguiente */
    var pigXP by mutableDoubleStateOf(0.0)
    /** el nivel más alto que han llegado a tener las huchas (el huchario lo recuerda siempre) */
    var bestTier by mutableIntStateOf(0)
    /** piezas del taller (se pierden con la bancarrota, como los martillos) */
    var parts by mutableStateOf(mapOf<String, Int>())
    /** último día en que se rascó el rasca gratis */
    var lastScratch by mutableStateOf("")
    var brokenByKind by mutableStateOf(mapOf<String, Double>())
    /** facturas pagadas en esta partida */
    var billsThisRun by mutableIntStateOf(0)
    /** nivel de las vacas cuando llegó la factura de ahora (lo que vale) */
    var billTier by mutableIntStateOf(0)
    var autoBuy by mutableStateOf(true)
    /** tiradas gratis de la tragaperras: el día y cuántas van */
    var lastSpin by mutableStateOf("")
    var spinsToday by mutableIntStateOf(0)
    /** puertas de la cocina que ya has abierto (las nuevas llevan el sello «NUEVO») */
    var seenDoors by mutableStateOf(setOf<String>())
    /** lo abonado a la hipoteca de ahora (se queda aunque te arruines) y las ya pagadas */
    var mortgage by mutableDoubleStateOf(0.0)
    var richLevel by mutableIntStateOf(0)
    /** cuándo se jugó por última vez y lo que se ganó el último día (para lo ganado sin jugar) */
    var lastPlayed by mutableDoubleStateOf(0.0)
    var lastDayEarned by mutableDoubleStateOf(0.0)
    /** el último número grande celebrado (1 = mil, 2 = millón, 3 = mil millones…) */
    var milestone by mutableIntStateOf(0)
    /** premios por anuncio: el día y cuántos de cada uno se han cobrado hoy */
    var adDay by mutableStateOf("")
    var adUses by mutableStateOf(mapOf<String, Int>())
    /** los sobres del paquete de inicio ya se dieron */
    var starterClaimed by mutableStateOf(false)

    fun toJson(): JSONObject = JSONObject().apply {
        put("cash", cash); put("day", day); put("year", year); put("billIndex", billIndex); put("billDue", billDue)
        put("paidThisCycle", paidThisCycle); put("tier", tier); put("hammer", hammer); put("hammersOwned", JSONArray(hammersOwned.toList()))
        put("skills", JSONObject(skills)); put("pendingChests", JSONArray(pendingChests.map { it.name })); put("awaitingTaxChoice", awaitingTaxChoice)
        put("legacy", legacy); put("rings", JSONObject(rings)); put("coins", JSONObject(coins))
        put("stats", stats.toJson()); put("settings", settings.toJson()); put("seenIntro", seenIntro)
        put("skin", skin); put("skinsOwned", JSONArray(skinsOwned.toList()))
        put("level", level); put("xp", xp); put("quests", JSONArray(quests.map { it.toJson() }))
        put("achievements", JSONArray(achievements.toList())); put("streak", streak); put("lastDaily", lastDaily)
        put("tutorial", tutorial); put("pigXP", pigXP); put("brokenByKind", JSONObject(brokenByKind))
        put("bestTier", bestTier); put("parts", JSONObject(parts)); put("lastScratch", lastScratch)
        put("billsThisRun", billsThisRun); put("autoBuy", autoBuy); put("billTier", billTier)
        put("lastSpin", lastSpin); put("spinsToday", spinsToday)
        put("seenDoors", JSONArray(seenDoors.toList())); put("mortgage", mortgage); put("richLevel", richLevel)
        put("lastPlayed", lastPlayed); put("lastDayEarned", lastDayEarned); put("milestone", milestone)
        put("adDay", adDay); put("adUses", JSONObject(adUses)); put("starterClaimed", starterClaimed)
    }

    companion object {
        /** tolera partidas a medias o de otras versiones: lo que falta se queda como al empezar */
        fun from(o: JSONObject): SaveState {
            val s = SaveState()
            fun d(k: String, def: Double) = if (o.has(k)) o.optDouble(k, def).let { if (it.isNaN()) def else it } else def
            fun i(k: String, def: Int) = if (o.has(k)) o.optInt(k, def) else def
            fun b(k: String, def: Boolean) = if (o.has(k)) o.optBoolean(k, def) else def
            fun str(k: String, def: String) = if (o.has(k)) o.optString(k, def) else def
            fun intMap(k: String): Map<String, Int> = o.optJSONObject(k)?.let { m -> m.keys().asSequence().associateWith { m.optInt(it) } } ?: emptyMap()
            fun strSet(k: String): Set<String>? = o.optJSONArray(k)?.let { a -> (0 until a.length()).map { a.optString(it) }.toSet() }

            s.cash = d("cash", 0.0); s.day = i("day", 1); s.year = i("year", 0); s.billIndex = i("billIndex", 0)
            s.billDue = i("billDue", 3); s.paidThisCycle = d("paidThisCycle", 0.0); s.tier = i("tier", 0)
            s.hammer = i("hammer", 0)
            o.optJSONArray("hammersOwned")?.let { a -> s.hammersOwned = (0 until a.length()).map { a.optInt(it) }.toSet() + 0 }
            s.skills = intMap("skills")
            o.optJSONArray("pendingChests")?.let { a ->
                s.pendingChests = (0 until a.length()).mapNotNull { idx -> Rarity.entries.firstOrNull { it.name == a.optString(idx) } }
            }
            s.awaitingTaxChoice = b("awaitingTaxChoice", false)
            s.legacy = d("legacy", 0.0); s.rings = intMap("rings"); s.coins = intMap("coins")
            s.stats = Stats.from(o.optJSONObject("stats")); s.settings = Settings.from(o.optJSONObject("settings"))
            s.seenIntro = b("seenIntro", false)
            s.skin = str("skin", "vaca"); s.skinsOwned = (strSet("skinsOwned") ?: emptySet()) + setOf("vaca", "cerdo")
            if (Content.skins.none { it.id == s.skin }) s.skin = "vaca"
            s.level = max(1, i("level", 1)); s.xp = d("xp", 0.0)
            o.optJSONArray("quests")?.let { a -> s.quests = (0 until a.length()).mapNotNull { Quest.from(a.optJSONObject(it)) } }
            s.achievements = strSet("achievements") ?: emptySet()
            s.streak = i("streak", 0); s.lastDaily = str("lastDaily", "")
            // las partidas de antes ya saben jugar
            s.tutorial = i("tutorial", if (s.seenIntro) 9 else 0)
            s.pigXP = d("pigXP", 0.0)
            s.brokenByKind = o.optJSONObject("brokenByKind")?.let { m -> m.keys().asSequence().associateWith { m.optDouble(it, 0.0) } } ?: emptyMap()
            s.bestTier = max(i("bestTier", 0), s.tier)
            s.parts = intMap("parts").filterKeys { k -> Content.parts.any { it.id == k } }
            s.lastScratch = str("lastScratch", "")
            s.billsThisRun = i("billsThisRun", s.billIndex + s.year * Content.bills.size)
            s.autoBuy = b("autoBuy", true); s.lastSpin = str("lastSpin", ""); s.spinsToday = i("spinsToday", 0)
            s.billTier = i("billTier", s.tier)
            // los logros que ya no existen se quitan
            val ids = Meta.achievements.map { it.id }.toSet()
            s.achievements = s.achievements.filter { it in ids }.toSet()
            // quien ya jugaba conoce todas las puertas y sus números grandes
            s.seenDoors = strSet("seenDoors") ?: if (s.seenIntro) setOf("mejoras", "martillo", "album", "bar", "herencia") else emptySet()
            s.mortgage = d("mortgage", 0.0); s.richLevel = i("richLevel", 0)
            s.lastPlayed = d("lastPlayed", 0.0); s.lastDayEarned = d("lastDayEarned", 0.0)
            s.milestone = i("milestone", max(0, floor(log10(max(1.0, max(s.cash, s.stats.bestDay))) / 3).toInt()))
            s.adDay = str("adDay", ""); s.adUses = intMap("adUses"); s.starterClaimed = b("starterClaimed", false)
            if (!s.cash.isFinite()) s.cash = 0.0
            if (s.hammer >= Content.hammers.size) s.hammer = 0
            s.billIndex = min(s.billIndex, Content.bills.size - 1)
            return s
        }
    }
}

/** guarda en JSON con escritura atómica y deja una copia de la versión anterior */
object Persistence {
    private lateinit var dir: File
    fun init(context: Context) { dir = context.filesDir }
    private val main get() = File(dir, "partida.json")
    private val backup get() = File(dir, "partida-copia.json")

    fun load(): SaveState? {
        for (f in listOf(main, backup)) {
            try {
                if (f.exists()) return SaveState.from(JSONObject(f.readText()))
            } catch (_: Exception) { }
        }
        return null
    }
    fun save(s: SaveState) {
        val text = try { s.toJson().toString() } catch (_: Exception) { return }
        try {
            if (main.exists()) main.copyTo(backup, overwrite = true)
            val tmp = File(dir, "partida.tmp")
            tmp.writeText(text)
            tmp.renameTo(main)
        } catch (_: Exception) { }
    }
    fun erase() { main.delete(); backup.delete() }
}
