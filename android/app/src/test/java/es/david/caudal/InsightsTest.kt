package es.david.caudal

import es.david.caudal.core.Day
import es.david.caudal.domain.calc.Insights
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.calc.MonthMood
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

class InsightsTest {
    @Before fun setUp() {
        Day.clock = Clock.fixed(LocalDate.parse("2026-10-21").atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant(), ZoneId.systemDefault())
    }

    private fun g(date: String, cents: Long, cat: String? = "c", title: String = "") = Tx(type = TxType.EXPENSE, amount = cents, accountId = "a", categoryId = cat, date = date, title = title)

    @Test fun disponibleConPresupuesto() {
        val d = FinanceData(
            categories = listOf(Category(id = "c", name = "Súper", budget = 62_000)),
            // el alquiler no tiene presupuesto: no cuenta
            txs = listOf(g("2026-10-05", 20_000), g("2026-10-03", 65_000, cat = "alquiler")),
            recurring = listOf(Recurring(name = "Gym", amount = 3000, accountId = "a", categoryId = "c", day = 25, next = "2026-10-25")),
        )
        val a = Insights.allowance(Ledger(d, 1), "2026-10-21")
        // 620 − 200 − 30 (gimnasio el 25) = 390 € entre 11 días (del 21 al 31)
        assertEquals(390.0, a.left, 1e-9)
        assertEquals(11, a.daysLeft)
        assertEquals(390.0 / 11, a.perDay, 1e-9)
        assertEquals(true, a.fromBudget)
    }

    @Test fun disponibleSinPresupuestoUsaLoIngresado() {
        val d = FinanceData(txs = listOf(Tx(type = TxType.INCOME, amount = 100_000, accountId = "a", date = "2026-10-01"), g("2026-10-02", 40_000)))
        val a = Insights.allowance(Ledger(d, 1), "2026-10-21")
        assertEquals(600.0, a.left, 1e-9)
        assertEquals(false, a.fromBudget)
    }

    @Test fun prevision() {
        val d = FinanceData(txs = listOf(g("2026-10-01", 10_000), g("2026-10-10", 11_000)))
        // 210 € en 21 días → 10 €/día × 31
        assertEquals(310.0, Insights.forecast(Ledger(d, 1), "2026-10-21")!!, 1e-9)
        assertNull(Insights.forecast(Ledger(d, 1), "2026-10-02"))
    }

    @Test fun racha() {
        val txs = listOf(g("2026-10-21", 100), g("2026-10-20", 100), g("2026-10-19", 100), g("2026-10-17", 100))
        assertEquals(3, Insights.streak(txs, "2026-10-21"))
        assertEquals(2, Insights.streak(txs.drop(1), "2026-10-21")) // hoy aún no: cuenta desde ayer
        assertEquals(0, Insights.streak(listOf(g("2026-10-15", 100)), "2026-10-21"))
    }

    @Test fun cambiosPorCategoria() {
        val cats = listOf(Category(id = "r", name = "Restaurantes"), Category(id = "s", name = "Súper"))
        val txs = listOf(
            g("2026-09-05", 10_000, "r"), g("2026-10-05", 4_000, "r"), // 60 % menos
            g("2026-09-06", 10_000, "s"), g("2026-10-06", 10_500, "s"), // 5 %: no cuenta
            g("2026-09-28", 50_000, "r"), // después del 21 de septiembre: no entra
        )
        val i = Insights.categoryChanges(Ledger(FinanceData(categories = cats, txs = txs), 1), "2026-10-21")
        assertEquals(listOf("r"), i.map { it.category.id })
        assertEquals(-60.0, i.single().pct, 1e-9)
    }

    @Test fun humorYFrecuentes() {
        val cats = listOf(Category(id = "c", name = "Súper", budget = 31_000))
        assertEquals(MonthMood.GREAT, Insights.mood(Ledger(FinanceData(categories = cats, txs = listOf(g("2026-10-02", 10_000))), 1), "2026-10-21"))
        assertEquals(MonthMood.OVER, Insights.mood(Ledger(FinanceData(categories = cats, txs = listOf(g("2026-10-02", 40_000))), 1), "2026-10-21"))
        val f = Insights.frequent(listOf(g("2026-10-01", 150, title = "Café"), g("2026-10-03", 150, title = "café "), g("2026-10-04", 900, title = "Cine")), "2026-10-21")
        assertEquals(1, f.size)
        assertEquals(2, f.single().times)
    }
}
