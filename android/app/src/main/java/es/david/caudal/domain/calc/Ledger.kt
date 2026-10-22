package es.david.caudal.domain.calc

import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.Asset
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Freq
import es.david.caudal.domain.model.Goal
import es.david.caudal.domain.model.OpSide
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import java.text.Normalizer
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

data class Position(val qty: Double, val cost: Double, val realized: Double)
data class CatTotal(val cat: Category, val total: Double)
data class Upcoming(val r: Recurring, val date: String)
data class NWPoint(val date: String, val value: Double)
/** rango de fechas yyyy-MM-dd, los dos extremos incluidos */
data class DateRange(val start: String, val end: String) {
    operator fun contains(d: String) = d >= start && d <= end
}

/**
 * Los cálculos de Caudal, iguales a los de iPhone (Store.swift). Trabaja en euros con Double,
 * como la app de iPhone, para que los resultados coincidan céntimo a céntimo.
 */
class Ledger(val data: FinanceData, private val monthStartDay: Int = 1) {

    private val accountsById = data.accounts.associateBy { it.id }
    private val categoriesById = data.categories.associateBy { it.id }
    private val assetsById = data.assets.associateBy { it.id }

    /** cuentas activas, en su orden */
    val accounts: List<Account> = data.accounts.filter { !it.archived }.sortedBy { it.order }

    fun account(id: String?) = id?.let { accountsById[it] }
    fun category(id: String?) = id?.let { categoriesById[it] }
    fun asset(id: String?) = id?.let { assetsById[it] }
    fun categories(kind: CatKind) = data.categories.filter { it.kind == kind && !it.hidden }.sortedBy { it.position }

    // MARK: saldos

    /** efecto de un movimiento en una cuenta */
    fun effect(t: Tx, accId: String): Double {
        val a = Money.fromCents(t.amount)
        return when (t.type) {
            TxType.EXPENSE -> if (t.accountId == accId) -a else 0.0
            TxType.INCOME, TxType.ADJUST -> if (t.accountId == accId) a else 0.0
            TxType.TRANSFER -> {
                var v = 0.0
                if (t.accountId == accId) v -= a
                if (t.toAccountId == accId) v += a
                v
            }
        }
    }

    fun balance(a: Account, upTo: String? = null): Double {
        var b = Money.fromCents(a.initial)
        for (t in data.txs) {
            if (t.accountId != a.id && t.toAccountId != a.id) continue
            if (upTo != null && t.date > upTo) continue
            b += effect(t, a.id)
        }
        for (asset in data.assets) for (op in asset.ops) {
            if (op.cashAccountId != a.id) continue
            if (upTo != null && op.date > upTo) continue
            when (op.side) {
                OpSide.BUY -> b -= op.qty * op.price + op.fee
                OpSide.SELL -> b += op.qty * op.price - op.fee
                OpSide.REWARD -> Unit
            }
        }
        return b
    }

    /** valor de la cuenta con sus inversiones */
    fun value(a: Account): Double =
        balance(a) + data.assets.filter { it.accountId == a.id && !it.archived }.sumOf { assetValue(it) }

    val netWorth: Double get() = accounts.filter { it.includeInTotal }.sumOf { value(it) }
    val cashTotal: Double get() = accounts.filter { it.includeInTotal }.sumOf { balance(it) }

    /** patrimonio de los últimos días: cuentas con su historia + inversiones al valor de hoy */
    fun netWorthSeries(days: Int = 30): List<NWPoint> {
        val invest = investValue
        val today = Day.today
        return (days downTo 0).map { k ->
            val d = Day.addDays(today, -k)
            NWPoint(d, accounts.filter { it.includeInTotal }.sumOf { balance(it, d) } + invest)
        }
    }

    // MARK: inversiones

    fun price(a: Asset): Double = data.quotes[a.ySymbol]?.price ?: a.manualPrice

    fun dayChange(a: Asset): Double? {
        val q = data.quotes[a.ySymbol] ?: return null
        if (q.previousClose <= 0) return null
        return (q.price / q.previousClose - 1) * 100
    }

    fun position(a: Asset): Position = position(a.ops)

    fun assetValue(a: Asset): Double = position(a).qty * price(a)
    val investValue: Double get() = data.assets.filter { !it.archived }.sumOf { assetValue(it) }
    val investCost: Double get() = data.assets.filter { !it.archived }.sumOf { position(it).cost }

    /** rentabilidad de hoy de la cartera: Σ cantidad × (precio − cierre anterior) */
    val investToday: Double get() = data.assets.filter { !it.archived }.sumOf { a ->
        val q = data.quotes[a.ySymbol]
        if (q == null || q.previousClose <= 0) 0.0 else position(a).qty * (q.price - q.previousClose)
    }

    // MARK: periodos (mes financiero)

    /** inicio del mes que contiene la fecha (respetando el día de inicio) */
    fun periodStart(d: String): String = periodStart(d, monthStartDay)

    fun periodRange(start: String): DateRange = DateRange(start, Day.addDays(Day.addMonths(start, 1), -1))

    fun txs(r: DateRange): List<Tx> = data.txs.filter { it.date in r }

    fun spent(r: DateRange): Double = txs(r).filter { it.type == TxType.EXPENSE && !it.excluded }.sumOf { Money.fromCents(it.amount) }
    fun earned(r: DateRange): Double = txs(r).filter { it.type == TxType.INCOME && !it.excluded }.sumOf { Money.fromCents(it.amount) }

    fun byCategory(r: DateRange, kind: TxType = TxType.EXPENSE): List<CatTotal> {
        val m = LinkedHashMap<String, Double>()
        for (t in txs(r)) if (t.type == kind && !t.excluded) m[t.categoryId ?: ""] = (m[t.categoryId ?: ""] ?: 0.0) + Money.fromCents(t.amount)
        return m.map { (k, v) ->
            val c = category(k) ?: Category(id = NO_CATEGORY, kind = if (kind == TxType.INCOME) CatKind.INCOME else CatKind.EXPENSE, name = "", icon = "❔")
            CatTotal(c, v)
        }.sortedByDescending { it.total }
    }

    /** presupuesto total: la suma de los presupuestos de las categorías de gasto */
    val totalBudget: Double get() = data.categories.filter { it.kind == CatKind.EXPENSE }.sumOf { Money.fromCents(it.budget) }

    /**
     * comparación con el mes pasado al mismo día: % de más (o de menos) gastado.
     * null si no hay con qué comparar (el mes pasado no llegó a 100 €).
     */
    fun monthComparison(today: String = Day.today): Double? {
        val start = periodStart(today)
        val r = periodRange(start)
        val prev = periodRange(Day.addMonths(start, -1))
        val elapsed = Day.daysBetween(start, today).toInt()
        val prevSpent = spent(DateRange(prev.start, minOf(prev.end, Day.addDays(prev.start, elapsed))))
        val prevTotal = spent(prev)
        if (prevSpent <= 0 || prevTotal < 100) return null
        return (spent(r) / prevSpent - 1) * 100
    }

    // MARK: objetivos

    fun saved(g: Goal): Double {
        val a = account(g.accountId)
        return if (g.accountId != null && a != null) value(a) else Money.fromCents(g.saved)
    }

    // MARK: categorías automáticas y conceptos

    /** la primera categoría (en su orden) con una palabra clave contenida en el concepto */
    fun guessCategory(text: String, kind: CatKind): Category? {
        val t = fold(text)
        if (t.length < 3) return null
        for (c in categories(kind)) for (k in c.keywords.split(',')) {
            val kw = fold(k.trim())
            if (kw.length >= 2 && t.contains(kw)) return c
        }
        return null
    }

    /** conceptos usados antes, del más reciente al más antiguo */
    val knownTitles: List<String> by lazy {
        val seen = HashSet<String>()
        data.txs.sortedByDescending { it.sortKey }.mapNotNull { t -> t.title.takeIf { it.isNotEmpty() && seen.add(it) } }
    }

    // MARK: recurrentes

    fun upcoming(days: Int = 14, today: String = Day.today): List<Upcoming> {
        val end = Day.addDays(today, days)
        val out = mutableListOf<Upcoming>()
        for (r in data.recurring) {
            if (!r.active) continue
            var d = r.next
            var n = 0
            while (d <= end && n < 10) { out += Upcoming(r, d); d = nextDate(r, d); n++ }
        }
        return out.sortedBy { it.date }
    }

    companion object {
        const val NO_CATEGORY = "none"

        fun periodStart(d: String, monthStart: Int): String {
            val ms = monthStart.coerceIn(1, 28)
            val day = d.takeLast(2).toIntOrNull() ?: 1
            var base = Day.monthStart(d)
            if (day < ms) base = Day.addMonths(base, -1)
            return base.take(8) + ms.toString().padStart(2, '0')
        }

        fun position(ops: List<AssetOp>): Position {
            var qty = 0.0
            var cost = 0.0
            var realized = 0.0
            for (op in ops.sortedBy { it.date }) when (op.side) {
                OpSide.BUY -> { qty += op.qty; cost += op.qty * op.price + op.fee }
                OpSide.REWARD -> qty += op.qty
                OpSide.SELL -> {
                    val avg = if (qty > 0) cost / qty else 0.0
                    val q = min(op.qty, qty)
                    realized += q * (op.price - avg) - op.fee
                    cost -= q * avg
                    qty -= q
                }
            }
            return Position(qty, cost, realized)
        }

        /** siguiente cargo de un recurrente */
        fun nextDate(r: Recurring, after: String): String = when (r.freq) {
            Freq.WEEKLY -> Day.addDays(after, 7)
            Freq.YEARLY -> Day.addMonths(after, 12)
            Freq.MONTHLY -> {
                val n = Day.addMonths(Day.monthStart(after), 1)
                n.take(8) + min(r.day, Day.daysInMonth(n)).coerceAtLeast(1).toString().padStart(2, '0')
            }
        }

        /** minúsculas y sin tildes */
        fun fold(s: String): String =
            Normalizer.normalize(s.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "")

        /** el % de ahorro: (ingresos − gastos) / ingresos */
        fun savingPct(earned: Double, spent: Double): Double? = if (earned > 0) (earned - spent) / earned * 100 else null

        /** diferencia para dejar el saldo de una cuenta en el indicado (null si no hace falta) */
        fun adjustment(balance: Double, target: Double): Double? {
            val diff = target - balance
            return if (abs(diff) >= 0.005) Money.round2(diff) else null
        }

        fun clampPct(v: Double) = max(0.0, v)
    }
}
