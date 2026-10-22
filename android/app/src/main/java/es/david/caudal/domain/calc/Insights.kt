package es.david.caudal.domain.calc

import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import kotlin.math.abs


/** cuánto puedes gastar al día hasta que acabe el mes */
data class Allowance(
    /** lo que queda para gastar hasta fin de mes (ya descontados los cargos que faltan) */
    val left: Double,
    val perDay: Double,
    /** días que quedan, hoy incluido */
    val daysLeft: Int,
    /** cargos recurrentes que aún faltan este mes */
    val upcoming: Double,
    /** sale del presupuesto (true) o de lo ingresado (false) */
    val fromBudget: Boolean,
    /** presupuesto o ingresos del mes de los que sale (0: aún no se puede calcular) */
    val base: Double = 0.0,
)

/** un aviso amable: «gastas un 23 % menos en Restaurantes» */
data class Insight(val category: Category, val now: Double, val before: Double) {
    val pct: Double get() = if (before > 0) (now / before - 1) * 100 else 100.0
}

/** Funciones nuevas del inicio (Android). Funciones puras, con pruebas. */
object Insights {
    /**
     * Disponible: presupuesto del mes − lo gastado en las categorías con presupuesto − sus recurrentes pendientes,
     * repartido entre los días que quedan. Sin presupuestos: lo ingresado − todo lo gastado − recurrentes pendientes.
     */
    fun allowance(l: Ledger, today: String = Day.today): Allowance {
        val start = l.periodStart(today)
        val r = l.periodRange(start)
        val budget = l.totalBudget
        val budgeted = l.data.categories.filter { it.budget > 0 }.map { it.id }.toSet()
        val counts: (String?) -> Boolean = { budget <= 0 || it in budgeted }
        val spent = l.txs(r).filter { it.type == TxType.EXPENSE && !it.excluded && counts(it.categoryId) }.sumOf { Money.fromCents(it.amount) }
        val upcoming = l.upcoming(Day.daysBetween(today, r.end).toInt(), today)
            .filter { it.date <= r.end && it.r.type == "expense" && counts(it.r.categoryId) }
            .sumOf { Money.fromCents(it.r.amount) }
        val base = if (budget > 0) budget else l.earned(r)
        val left = base - spent - upcoming
        val daysLeft = (Day.daysBetween(today, r.end) + 1).toInt().coerceAtLeast(1)
        return Allowance(left, if (left > 0) left / daysLeft else 0.0, daysLeft, upcoming, budget > 0, base)
    }

    /** previsión del gasto a fin de mes al ritmo de ahora (null al principio, con pocos datos) */
    fun forecast(l: Ledger, today: String = Day.today): Double? {
        val start = l.periodStart(today)
        val r = l.periodRange(start)
        val elapsed = (Day.daysBetween(start, today) + 1).toInt()
        if (elapsed < 3) return null
        val total = (Day.daysBetween(start, r.end) + 1).toInt()
        return l.spent(DateRange(start, today)) / elapsed * total
    }

    /** días seguidos apuntando algo (hasta hoy, o hasta ayer si hoy aún no) */
    fun streak(txs: List<Tx>, today: String = Day.today): Int {
        val days = txs.filter { it.type != TxType.ADJUST && it.recurringId == null }.map { it.date }.toHashSet()
        var d = if (today in days) today else Day.addDays(today, -1)
        var n = 0
        while (d in days) { n++; d = Day.addDays(d, -1) }
        return n
    }

    /**
     * Las categorías que más han cambiado frente al mes pasado a estas alturas (lo mismo que hace iPhone con el total).
     * Solo cuenta cambios de al menos 15 € y 15 %.
     */
    fun categoryChanges(l: Ledger, today: String = Day.today, max: Int = 3): List<Insight> {
        val start = l.periodStart(today)
        val elapsed = Day.daysBetween(start, today).toInt()
        val prevStart = Day.addMonths(start, -1)
        val now = l.byCategory(DateRange(start, today)).associateBy { it.cat.id }
        val before = l.byCategory(DateRange(prevStart, minOf(l.periodRange(prevStart).end, Day.addDays(prevStart, elapsed)))).associateBy { it.cat.id }
        return (now.keys + before.keys).mapNotNull { id ->
            val cat = (now[id] ?: before[id])!!.cat
            if (cat.id == Ledger.NO_CATEGORY) return@mapNotNull null
            val a = now[id]?.total ?: 0.0
            val b = before[id]?.total ?: 0.0
            if (abs(a - b) < 15 || (b > 0 && abs(a / b - 1) < 0.15)) null else Insight(cat, a, b)
        }.sortedByDescending { abs(it.now - it.before) }.take(max)
    }

    /** gastado cada día de un rango (para el calendario de colores) */
    fun spentByDay(l: Ledger, r: DateRange): Map<String, Double> =
        l.txs(r).filter { it.type == TxType.EXPENSE && !it.excluded }.groupBy { it.date }.mapValues { (_, v) -> v.sumOf { Money.fromCents(it.amount) } }

    /** humor de Gotita según cómo va el mes */
    fun mood(l: Ledger, today: String = Day.today): MonthMood {
        val r = l.periodRange(l.periodStart(today))
        val budget = l.totalBudget
        val spent = l.spent(r)
        if (l.data.txs.isEmpty()) return MonthMood.EMPTY
        if (budget > 0) {
            val elapsedPart = (Day.daysBetween(r.start, today) + 1).toDouble() / (Day.daysBetween(r.start, r.end) + 1)
            val used = spent / budget
            return when {
                used > 1 -> MonthMood.OVER
                used > elapsedPart * 1.15 -> MonthMood.CAREFUL
                else -> MonthMood.GREAT
            }
        }
        val cmp = l.monthComparison(today) ?: return MonthMood.OK
        return if (cmp <= -5) MonthMood.GREAT else if (cmp >= 15) MonthMood.CAREFUL else MonthMood.OK
    }

    /** gastos frecuentes (para apuntar a un toque): mismo concepto, categoría e importe repetidos */
    data class Frequent(val title: String, val categoryId: String?, val accountId: String, val amount: Long, val times: Int)

    fun frequent(txs: List<Tx>, today: String = Day.today, max: Int = 6): List<Frequent> {
        val since = Day.addDays(today, -90)
        return txs.asSequence()
            .filter { it.type == TxType.EXPENSE && it.title.isNotBlank() && it.date >= since && it.recurringId == null }
            .groupBy { Triple(it.title.trim().lowercase(), it.categoryId, it.amount) }
            .filter { it.value.size >= 2 }
            .map { (_, v) -> val t = v.maxBy { it.sortKey }; Frequent(t.title.trim(), t.categoryId, t.accountId, t.amount, v.size) }
            .sortedWith(compareByDescending<Frequent> { it.times }.thenBy { it.title })
            .take(max)
    }

}

enum class MonthMood { EMPTY, GREAT, OK, CAREFUL, OVER }
