package es.david.findemes.logic

import androidx.compose.ui.graphics.Color
import es.david.findemes.model.Content
import es.david.findemes.model.SkillDef
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.L10n
import es.david.findemes.support.Lang
import es.david.findemes.support.tf
import es.david.findemes.support.capitalizedFirst
import es.david.findemes.support.rnd
import java.util.UUID
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/** Las puertas de la cocina: cada una junta varias pantallas y aparece cuando toca */
enum class Door(val title: String, val icon: String, val color: Color) {
    mejoras("Mejoras", "leaf.fill", Ink.red),
    martillo("Martillo", "hammer.fill", Ink.blue),
    album("Álbum", "book.closed.fill", Ink.gold),
    bar("La feria", "ticket.fill", Ink.red),
    herencia("Herencia", "crown.fill", Ink.purple),
}

/** lo que trae cada factura a la mesa mientras está pegada en la nevera */
enum class BillTwist(val title: String, val icon: String) {
    none("", ""),
    prisa("Salen más rápido", "hare.fill"),
    frenesi("Frenesí antes", "bolt.fill"),
    gordas("Más {huchas} gord{as}", "circle.fill"),
    doradas("Doradas ×2", "star.fill"),
    cansado("−25 % aguante · +50 % dinero", "bed.double.fill"),
    rey("Viene el Rey {Hucha}", "crown.fill");

    companion object {
        /** cada empresa trae lo suyo */
        fun of(bill: Int): BillTwist {
            val list = listOf(none, prisa, frenesi, gordas, rey, doradas, cansado, prisa, rey, gordas, gordas, frenesi, doradas, cansado, prisa, rey, prisa, none)
            return if (bill < list.size) list[bill] else none
        }
    }
}

/** lo ganado mientras no se jugaba */
class AwayPrize(val minutes: Double, val cash: Double, val cows: Double) { val id = UUID.randomUUID().toString() }

/** las hipotecas, una detrás de otra */
object Mortgage {
    val names = listOf("La Hipoteca", "El chalet de la playa", "El yate", "El equipo de fútbol", "Comprar el banco")
    fun name(level: Int): String = if (level < names.size) names[level] else tf("El banco (%1)", level - names.size + 2)
    /** lo que cuesta: la primera, mil trillones; cada una, diez mil veces la anterior */
    fun total(level: Int): Double = 1e21 * 1e4.pow(level)
    /** la cifra en palabras: «Mil trillones €», «10 cuatrillones €» */
    fun words(v: Double): String {
        val e3 = floor(log10(max(1.0, v)) / 3).toInt()
        when (L10n.lang) {
            Lang.es -> {
                val names = listOf("", "mil", "millones", "mil millones", "billones", "mil billones", "trillones", "mil trillones",
                    "cuatrillones", "mil cuatrillones", "quintillones", "mil quintillones", "sextillones")
                val k = min(names.size - 1, e3)
                val m = rnd(v / 1000.0.pow(k))
                if (m == 1.0 && names[k].startsWith("mil")) return names[k].capitalizedFirst + " €"
                return Fmt.num(m) + " " + names[k] + " €"
            }
            Lang.en -> {
                val names = listOf("", "thousand", "million", "billion", "trillion", "quadrillion", "quintillion", "sextillion",
                    "septillion", "octillion", "nonillion", "decillion", "undecillion")
                val k = min(names.size - 1, e3)
                return "$" + Fmt.num(rnd(v / 1000.0.pow(k))) + " " + names[k]
            }
            Lang.pt -> {
                val one = listOf("", "mil", "milhão", "bilhão", "trilhão", "quatrilhão", "quintilhão", "sextilhão",
                    "septilhão", "octilhão", "nonilhão", "decilhão", "undecilhão")
                val many = listOf("", "mil", "milhões", "bilhões", "trilhões", "quatrilhões", "quintilhões", "sextilhões",
                    "septilhões", "octilhões", "nonilhões", "decilhões", "undecilhões")
                val k = min(one.size - 1, e3)
                val m = rnd(v / 1000.0.pow(k))
                return "R$ " + Fmt.num(m) + " " + (if (m == 1.0) one[k] else many[k])
            }
        }
    }
}

// MARK: facturas: cada una trae algo y cada cinco, inspección de Hacienda

/** la quinta, la décima… (menos la última del año, que ya es Hacienda) */
fun Game.isInspection(id: Int): Boolean = (s.year * Content.bills.size + id) % 5 == 4 && id < Content.bills.size - 1
val Game.inspection: Boolean get() = isInspection(s.billIndex)
val Game.twist: BillTwist get() = if (inspection) BillTwist.none else BillTwist.of(s.billIndex)

// MARK: puertas (se abren poco a poco)

fun Game.doorOpen(d: Door): Boolean {
    val st = s.stats
    val veteran = st.bankruptcies > 0
    return when (d) {
        Door.mejoras -> st.days >= 1 || veteran
        Door.martillo -> st.billsPaid >= 1 || veteran
        Door.album -> st.days >= 2 || veteran
        Door.bar -> st.days >= 3 || veteran
        Door.herencia -> veteran
    }
}
fun Game.isNew(d: Door): Boolean = doorOpen(d) && d.name !in s.seenDoors
fun Game.open(d: Door) {
    if (d.name in s.seenDoors) return
    s.seenDoors = s.seenDoors + d.name
    save()
}

// MARK: la hipoteca (el final)

val Game.mortgageTotal: Double get() = Mortgage.total(s.richLevel)
val Game.mortgageName: String get() = Mortgage.name(s.richLevel)
val Game.mortgageShare: Double get() = min(1.0, s.mortgage / mortgageTotal)

/** abonar dinero a la hipoteca: lo abonado se queda aunque te arruines */
fun Game.payMortgage(amount: Double) {
    val a = min(amount, s.cash)
    if (a <= 0) return
    s.cash -= a
    addToMortgage(a)
    Sound.till()
    save()
}

fun Game.addToMortgage(a: Double) {
    if (a <= 0) return
    s.mortgage += a
    if (s.mortgage >= mortgageTotal) {
        // ¡pagada! la casa es tuya: desde ahora todo da más y llega la siguiente
        finale = s.richLevel
        s.richLevel += 1
        s.mortgage = 0.0
        recompute()
        Sound.fanfare()
    }
}

// MARK: lo ganado mientras no juegas

/** al abrir la app: si ha pasado un rato, el abuelo ha seguido rompiendo */
fun Game.wake() {
    val now = System.currentTimeMillis() / 1000.0
    try {
        if (s.lastPlayed <= 0 || inRun || s.lastDayEarned <= 0 || away != null) return
        val minutes = min(240.0, (now - s.lastPlayed) / 60)
        if (minutes < 5) return
        // cada hora fuera vale algo más que un día de los buenos
        val cash = rnd(s.lastDayEarned * 1.2 * minutes / 60)
        away = AwayPrize(minutes, cash, max(1.0, rnd(cash / max(1.0, pigWorth))))
    } finally {
        s.lastPlayed = now
    }
}

fun Game.collectAway(double: Boolean = false) {
    val a = away ?: return
    val v = if (double) a.cash * 2 else a.cash
    s.cash += v
    s.stats.earned += v
    away = null
    Sound.till()
    save()
}

// MARK: números grandes

/** el número grande celebrado, en el idioma de ahora */
fun milestoneName(k: Int): String {
    val list = when (L10n.lang) {
        Lang.es -> milestoneNames
        Lang.en -> listOf("", "$1,000", "MILLION", "BILLION", "TRILLION", "QUADRILLION", "QUINTILLION", "SEXTILLION", "SEPTILLION", "OCTILLION", "NONILLION")
        Lang.pt -> listOf("", "R$ 1.000", "MILHÃO", "BILHÃO", "TRILHÃO", "QUATRILHÃO", "QUINTILHÃO", "SEXTILHÃO", "SEPTILHÃO", "OCTILHÃO", "NONILHÃO")
    }
    return if (k < list.size) list[k] else "1e${k * 3}"
}

val milestoneNames = listOf("", "MIL €", "MILLÓN", "MIL MILLONES", "BILLÓN", "MIL BILLONES", "TRILLÓN", "MIL TRILLONES",
    "CUATRILLÓN", "MIL CUATRILLONES", "QUINTILLÓN")

/** celebra la primera vez que se llega a mil, a un millón, a mil millones… */
fun Game.checkMilestone() {
    if (s.cash < 1000) return
    val k = floor(log10(s.cash) / 3).toInt()
    if (k <= s.milestone) return
    s.milestone = k
    milestoneShow = k
    Sound.fanfare()
    save()
}

// MARK: la mejor compra (la chincheta dorada)

/** la mejora que más conviene ahora: la más barata de las que llega el dinero */
fun Game.bestSkill(defs: List<SkillDef>): String? = defs.filter { canGet(it) }.minByOrNull { cost(it) }?.id
val Game.bestPart: String? get() = Content.parts.filter { canBuyPart(it) }.minByOrNull { partCost(it) }?.id
/** el siguiente martillo, si ya llega el dinero */
val Game.bestHammer: Int? get() = Content.hammers.firstOrNull { it.id !in s.hammersOwned && s.cash >= hammerCost(it) }?.id
