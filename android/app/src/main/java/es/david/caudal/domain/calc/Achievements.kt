package es.david.caudal.domain.calc

import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.data.backup.DefaultCategories
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType

/** un logro: se calcula siempre a partir de los datos (no se guarda nada) */
data class Achievement(
    val id: String,
    val emoji: String,
    val current: Int,
    val goal: Int,
    /** día en que se consiguió (yyyy-MM-dd) si se puede deducir */
    val date: String? = null,
    /** complemento de Gotita que desbloquea */
    val unlocks: String? = null,
) {
    val done: Boolean get() = current >= goal
    val progress: Float get() = if (goal <= 0) 1f else (current.toFloat() / goal).coerceIn(0f, 1f)
}

/**
 * Logros de Caudal (gamificación cariñosa, sin castigos).
 *
 * Complementos de Gotita que desbloquean:
 * | complemento  | logro                          |
 * |--------------|--------------------------------|
 * | nada         | siempre                        |
 * | gorro        | racha3 (3 días seguidos)       |
 * | gafas        | mes_ahorro (un mes ahorrando)  |
 * | lazo         | mes_presupuesto (mes dentro)   |
 * | corona       | racha30 (30 días seguidos)     |
 * | auriculares  | objetivo_cumplido              |
 * | flor         | valio_pena (primer «¿valió…?») |
 */
object Achievements {
    val HAT_REQUIREMENTS: Map<String, String> = linkedMapOf(
        "gorro" to "racha3",
        "gafas" to "mes_ahorro",
        "lazo" to "mes_presupuesto",
        "corona" to "racha30",
        "auriculares" to "objetivo_cumplido",
        "flor" to "valio_pena",
    )

    /** en este orden se enseñan */
    val IDS = listOf(
        "primer_gasto", "diez", "cincuenta", "cien", "quinientos",
        "racha3", "racha7", "racha30",
        "presupuesto", "mes_presupuesto", "objetivo_creado", "objetivo_cumplido",
        "cuenta_extra", "mes_ahorro", "tres_meses_ahorro", "deuda_saldada", "valio_pena", "categoria_propia",
    )

    private fun counted(txs: List<Tx>) = txs.filter { it.type != TxType.ADJUST && it.recurringId == null }

    /** la racha más larga de días seguidos apuntando y el día en que llegó a cada longitud */
    fun longestStreak(txs: List<Tx>): Pair<Int, Map<Int, String>> {
        val days = counted(txs).map { it.date }.toSortedSet()
        var best = 0
        var run = 0
        var prev: String? = null
        val reachedOn = HashMap<Int, String>()
        for (d in days) {
            run = if (prev != null && Day.addDays(prev, 1) == d) run + 1 else 1
            if (run > best) best = run
            reachedOn.putIfAbsent(run, d)
            prev = d
        }
        return best to reachedOn
    }

    fun all(d: FinanceData, monthStart: Int = 1, today: String = Day.today): List<Achievement> {
        val l = Ledger(d, monthStart)
        val txs = counted(d.txs).sortedBy { it.sortKey }
        fun nth(n: Int) = txs.getOrNull(n - 1)?.date
        val firstExpense = txs.firstOrNull { it.type == TxType.EXPENSE }
        val (best, reached) = longestStreak(d.txs)

        // meses ya cerrados (hasta 24 hacia atrás), del más antiguo al más reciente
        val current = l.periodStart(today)
        val closed = (24 downTo 1).map { Day.addMonths(current, -it) }.map { l.periodRange(it) }
            .filter { r -> l.txs(r).isNotEmpty() }
        val budget = l.totalBudget
        val withinBudget = if (budget > 0) closed.lastOrNull { l.spent(it) <= budget && l.spent(it) > 0 } else null
        val saving = closed.filter { val e = l.earned(it); e > 0 && e > l.spent(it) }
        var bestRun = 0
        var run = 0
        var runEnd: String? = null
        for (r in closed) {
            val e = l.earned(r)
            if (e > 0 && e > l.spent(r)) { run++; if (run > bestRun) { bestRun = run; if (run == 3) runEnd = r.end } } else run = 0
        }
        val goalDone = d.goals.firstOrNull { g -> l.saved(g) >= Money.fromCents(g.target) && g.target > 0 }
        val settled = d.people.any { p ->
            val moves = d.debts.filter { it.personId == p.id }
            moves.any { it.kind == DebtKind.PAY || it.kind == DebtKind.IPAY } && Debts.balance(d.debts, p.id) == 0L
        }
        val moodTx = txs.firstOrNull { it.mood.isNotEmpty() }
        val defaultIds = DefaultCategories.defs.map { it.id }.toSet()
        val activeAccounts = d.accounts.count { !it.archived }

        fun a(id: String, emoji: String, cur: Int, goal: Int, date: String? = null) =
            Achievement(id, emoji, cur.coerceAtMost(goal), goal, if (cur >= goal) date else null, HAT_REQUIREMENTS.entries.firstOrNull { it.value == id }?.key)

        return listOf(
            a("primer_gasto", "🌱", if (firstExpense != null) 1 else 0, 1, firstExpense?.date),
            a("diez", "🧾", txs.size, 10, nth(10)),
            a("cincuenta", "📒", txs.size, 50, nth(50)),
            a("cien", "💯", txs.size, 100, nth(100)),
            a("quinientos", "🏆", txs.size, 500, nth(500)),
            a("racha3", "🔥", best, 3, reached[3]),
            a("racha7", "⚡", best, 7, reached[7]),
            a("racha30", "👑", best, 30, reached[30]),
            a("presupuesto", "🎯", if (budget > 0) 1 else 0, 1),
            a("mes_presupuesto", "🛡️", if (withinBudget != null) 1 else 0, 1, withinBudget?.end),
            a("objetivo_creado", "🐷", if (d.goals.isNotEmpty()) 1 else 0, 1),
            a("objetivo_cumplido", "⭐", if (goalDone != null) 1 else 0, 1),
            a("cuenta_extra", "🏦", activeAccounts, 2),
            a("mes_ahorro", "💰", if (saving.isNotEmpty()) 1 else 0, 1, saving.firstOrNull()?.end),
            a("tres_meses_ahorro", "🌈", bestRun, 3, runEnd),
            a("deuda_saldada", "🤝", if (settled) 1 else 0, 1),
            a("valio_pena", "😍", if (moodTx != null) 1 else 0, 1, moodTx?.date),
            a("categoria_propia", "🎨", if (d.categories.any { it.id !in defaultIds }) 1 else 0, 1),
        )
    }

    /** complementos de Gotita que ya se pueden poner */
    fun unlockedHats(list: List<Achievement>): Set<String> {
        val done = list.filter { it.done }.map { it.id }.toSet()
        return setOf("nada") + HAT_REQUIREMENTS.filterValues { it in done }.keys
    }
}
