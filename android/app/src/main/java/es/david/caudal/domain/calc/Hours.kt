package es.david.caudal.domain.calc

import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.Company
import es.david.caudal.domain.model.PayStatus
import es.david.caudal.domain.model.Shift
import kotlin.math.max
import kotlin.math.min

data class ShiftCalc(val normalMin: Int, val nightMin: Int, val gross: Double) {
    val totalMin get() = normalMin + nightMin
}

data class WorkSummary(
    val normalMin: Int = 0,
    val nightMin: Int = 0,
    val gross: Double = 0.0,
    val net: Double = 0.0,
    val paidNet: Double = 0.0,
    val pendingNet: Double = 0.0,
    val days: Int = 0,
) {
    val totalMin get() = normalMin + nightMin
}

/** Horas trabajadas: igual que Work.swift */
object Hours {
    /** «16:00» */
    fun hm(m: Int): String = "%02d:%02d".format((m / 60) % 24, m % 60)

    /** reparte el turno en minutos normales y nocturnos (puede pasar de medianoche) */
    fun calc(s: Shift, c: Company): ShiftCalc {
        val a = s.start
        var b = s.end
        if (b <= a) b += 1440
        var night = 0
        for (k in -1..1) {
            val ns = c.nightStart + 1440 * k
            val ne = if (c.nightEnd > c.nightStart) c.nightEnd + 1440 * k else c.nightEnd + 1440 * (k + 1)
            night += max(0, min(b, ne) - max(a, ns))
        }
        var normal = (b - a) - night
        // el descanso se quita primero de las horas normales
        var br = max(0, s.breakMin)
        val fromNormal = min(br, normal)
        normal -= fromNormal
        br -= fromNormal
        night = max(0, night - br)
        val gross = normal / 60.0 * (s.normalRate ?: c.normalRate) + night / 60.0 * (s.nightRate ?: c.nightRate)
        return ShiftCalc(normal, night, Money.round2(gross))
    }

    fun net(gross: Double, c: Company): Double = Money.round2(gross * (1 - (c.ssPct + c.irpfPct) / 100))

    fun summary(list: List<Shift>, companies: List<Company>): WorkSummary {
        val byId = companies.associateBy { it.id }
        var w = WorkSummary(days = list.map { it.date }.toSet().size)
        for (s in list) {
            val c = byId[s.companyId] ?: continue
            val r = calc(s, c)
            val n = net(r.gross, c)
            w = w.copy(
                normalMin = w.normalMin + r.normalMin, nightMin = w.nightMin + r.nightMin,
                gross = w.gross + r.gross, net = w.net + n,
                paidNet = w.paidNet + if (s.status == PayStatus.PAGADO) n else 0.0,
                pendingNet = w.pendingNet + if (s.status == PayStatus.PAGADO) 0.0 else n,
            )
        }
        return w
    }

    /** turnos de un mes (yyyy-MM), del más reciente al más antiguo */
    fun shifts(all: List<Shift>, month: String, company: String? = null): List<Shift> =
        all.filter { Day.monthKey(it.date) == month && (company == null || it.companyId == company) }
            .sortedWith(compareByDescending<Shift> { it.date }.thenByDescending { it.start })
}
