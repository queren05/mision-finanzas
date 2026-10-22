package es.david.caudal.domain.calc

import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.TxType

/** un aviso de presupuesto: al 80 % o al 100 % de una categoría o del total */
data class BudgetAlert(
    /** clave única en el periodo: «2026-10-01:c_super:80» (sin repetir avisos) */
    val key: String,
    /** null = presupuesto total */
    val category: Category?,
    val level: Int,
    val spent: Double,
    val budget: Double,
)

/** Qué avisos de presupuesto tocan ahora (en el mes financiero de hoy) */
object BudgetAlerts {
    fun check(l: Ledger, today: String = Day.today): List<BudgetAlert> {
        val start = l.periodStart(today)
        val r = l.periodRange(start)
        val spentBy = l.txs(r).filter { it.type == TxType.EXPENSE && !it.excluded }
            .groupBy { it.categoryId }.mapValues { (_, v) -> v.sumOf { Money.fromCents(it.amount) } }
        val out = mutableListOf<BudgetAlert>()
        fun add(cat: Category?, spent: Double, budget: Double) {
            if (budget <= 0) return
            val level = when { spent >= budget -> 100; spent >= budget * 0.8 -> 80; else -> return }
            out += BudgetAlert("$start:${cat?.id ?: "total"}:$level", cat, level, spent, budget)
        }
        val budgeted = l.data.categories.filter { it.budget > 0 }
        budgeted.forEach { c -> add(c, spentBy[c.id] ?: 0.0, Money.fromCents(c.budget)) }
        // el total solo cuenta las categorías con presupuesto (igual que «Disponible hoy»)
        if (budgeted.size > 1) add(null, budgeted.sumOf { spentBy[it.id] ?: 0.0 }, budgeted.sumOf { Money.fromCents(it.budget) })
        return out
    }

    /** cargos recurrentes de mañana (para avisar el día antes) */
    fun chargesTomorrow(l: Ledger, today: String = Day.today) = l.upcoming(1, today).filter { it.date == Day.addDays(today, 1) && it.r.type != "invest" }
}
