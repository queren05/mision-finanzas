package es.david.caudal.domain.calc

import es.david.caudal.core.Day
import es.david.caudal.domain.model.Freq
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import java.time.temporal.ChronoUnit
import kotlin.math.abs
import kotlin.math.roundToLong

/** una suscripción encontrada en los movimientos */
data class SubscriptionGuess(
    val title: String,
    /** importe típico (el último) en céntimos */
    val amount: Long,
    val freq: Freq,
    val accountId: String,
    val categoryId: String?,
    /** fecha del último cargo */
    val last: String,
    /** próximo cargo esperado */
    val next: String,
    val count: Int,
) {
    /** para convertirla en recurrente con un toque */
    fun toRecurring(): Recurring = Recurring(
        name = title, type = "expense", amount = amount, accountId = accountId, categoryId = categoryId,
        freq = freq, day = Day.date(next).dayOfMonth, next = next,
    )
}

/**
 * Detección de suscripciones y pagos periódicos: gastos con el mismo concepto, importe parecido (±10 %)
 * y una cadencia semanal, mensual o anual en los últimos 6 meses (2 años para las anuales), que no sean ya un recurrente.
 */
object Subscriptions {
    fun detect(txs: List<Tx>, recurring: List<Recurring>, today: String = Day.today): List<SubscriptionGuess> {
        val known = recurring.map { norm(it.name) }.toSet()
        // 25 meses: dos cargos anuales
        val since = Day.addMonths(today, -25)
        val groups = txs.asSequence()
            .filter { it.type == TxType.EXPENSE && it.recurringId == null && it.title.isNotBlank() && it.date >= since && it.date <= today }
            .groupBy { norm(it.title) }
            .filterKeys { it.length >= 2 && it !in known }
        val out = mutableListOf<SubscriptionGuess>()
        for ((_, list0) in groups) {
            val list = list0.sortedBy { it.date }
            if (list.size < 2) continue
            val last = list.last()
            // importes parecidos al último (±10 %)
            val all = list.filter { abs(it.amount - last.amount) <= (last.amount * 0.10).roundToLong().coerceAtLeast(1) }
            // semanal y mensual: solo los últimos 6 meses; anual: 13 meses
            val recent = all.filter { it.date >= Day.addMonths(today, -6) }
            val freq = listOf(recent, all).firstNotNullOfOrNull { cand ->
                if (cand.size < 2) null else cadence(cand.zipWithNext { a, b -> ChronoUnit.DAYS.between(Day.date(a.date), Day.date(b.date)) })
                    ?.takeIf { f -> (f == Freq.YEARLY) == (cand === all) || f != Freq.YEARLY && cand === recent }
            } ?: continue
            val similar = if (freq == Freq.YEARLY) all else recent
            // las semanales y mensuales tienen que seguir vivas (último cargo reciente)
            val window = when (freq) { Freq.WEEKLY -> Day.addDays(today, -21); Freq.MONTHLY -> Day.addMonths(today, -2); Freq.YEARLY -> Day.addMonths(today, -13) }
            if (last.date < window) continue
            val next = when (freq) { Freq.WEEKLY -> Day.addDays(last.date, 7); Freq.MONTHLY -> Day.addMonths(last.date, 1); Freq.YEARLY -> Day.addMonths(last.date, 12) }
            out += SubscriptionGuess(last.title.trim(), last.amount, freq, last.accountId, last.categoryId, last.date, next, similar.size)
        }
        return out.sortedBy { it.next }
    }

    /** semanal (6–8 días), mensual (27–33) o anual (355–375): todas las distancias en el mismo rango */
    private fun cadence(gaps: List<Long>): Freq? = when {
        gaps.all { it in 6..8 } -> Freq.WEEKLY
        gaps.all { it in 27..33 } -> Freq.MONTHLY
        gaps.all { it in 355..375 } -> Freq.YEARLY
        else -> null
    }

    private fun norm(s: String) = Ledger.fold(s).replace(Regex("[^a-z0-9 ]"), " ").replace(Regex("\\s+"), " ").trim()
}
