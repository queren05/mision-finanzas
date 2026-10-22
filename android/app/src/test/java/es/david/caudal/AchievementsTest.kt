package es.david.caudal

import es.david.caudal.domain.calc.Achievements
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Goal
import es.david.caudal.domain.model.Person
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AchievementsTest {
    private fun g(date: String, cents: Long = 1000, cat: String? = "c_super", mood: String = "") =
        Tx(type = TxType.EXPENSE, amount = cents, accountId = "a", categoryId = cat, date = date, mood = mood)
    private fun i(date: String, cents: Long) = Tx(type = TxType.INCOME, amount = cents, accountId = "a", date = date)

    private fun byId(d: FinanceData) = Achievements.all(d, 1, "2026-10-21").associateBy { it.id }

    @Test fun vacioNoHayNada() {
        val a = byId(FinanceData())
        assertEquals(Achievements.IDS, Achievements.all(FinanceData(), 1, "2026-10-21").map { it.id })
        assertTrue(a.values.none { it.done })
        assertEquals(setOf("nada"), Achievements.unlockedHats(a.values.toList()))
    }

    @Test fun primerGastoYContadores() {
        val txs = (1..12).map { g("2026-10-%02d".format(it)) }
        val a = byId(FinanceData(txs = txs))
        assertTrue(a.getValue("primer_gasto").done)
        assertEquals("2026-10-01", a.getValue("primer_gasto").date)
        assertTrue(a.getValue("diez").done)
        assertEquals("2026-10-10", a.getValue("diez").date)
        assertEquals(12, a.getValue("cincuenta").current)
        assertFalse(a.getValue("cincuenta").done)
    }

    @Test fun rachaMaximaHistorica() {
        // racha de 4 en septiembre, ahora solo 1
        val txs = listOf("2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04", "2026-10-20").map { g(it) }
        val (best, reached) = Achievements.longestStreak(txs)
        assertEquals(4, best)
        assertEquals("2026-09-03", reached[3])
        val a = byId(FinanceData(txs = txs))
        assertTrue(a.getValue("racha3").done)
        assertEquals("2026-09-03", a.getValue("racha3").date)
        assertFalse(a.getValue("racha7").done)
        assertTrue("gorro" in Achievements.unlockedHats(a.values.toList()))
    }

    @Test fun presupuestoYAhorro() {
        val cats = listOf(Category(id = "c_super", name = "Súper", budget = 30_000))
        val txs = listOf(
            i("2026-08-01", 100_000), g("2026-08-05", 20_000),
            i("2026-09-01", 100_000), g("2026-09-05", 25_000),
        )
        val a = byId(FinanceData(categories = cats, txs = txs))
        assertTrue(a.getValue("presupuesto").done)
        assertTrue(a.getValue("mes_presupuesto").done)
        assertEquals("2026-09-30", a.getValue("mes_presupuesto").date)
        assertTrue(a.getValue("mes_ahorro").done)
        assertEquals("2026-08-31", a.getValue("mes_ahorro").date)
        assertEquals(2, a.getValue("tres_meses_ahorro").current)
        assertTrue(Achievements.unlockedHats(a.values.toList()).containsAll(listOf("lazo", "gafas")))
    }

    @Test fun objetivosCuentasDeudasYMas() {
        val d = FinanceData(
            accounts = listOf(Account(id = "a", name = "A", initial = 60_000), Account(id = "b", name = "B")),
            categories = listOf(Category(id = "mia", name = "Gatos")),
            txs = listOf(g("2026-10-01", mood = "😍")),
            goals = listOf(Goal(name = "Viaje", target = 50_000, accountId = "a")),
            people = listOf(Person(id = "p", name = "Lucía")),
            debts = listOf(
                DebtMove(personId = "p", amount = 1250, kind = DebtKind.OWE, date = "2026-10-01"),
                DebtMove(personId = "p", amount = -1250, kind = DebtKind.PAY, date = "2026-10-02"),
            ),
        )
        val a = byId(d)
        assertTrue(a.getValue("objetivo_creado").done)
        assertTrue(a.getValue("objetivo_cumplido").done) // 600 − 10 ≥ 500
        assertTrue(a.getValue("cuenta_extra").done)
        assertTrue(a.getValue("deuda_saldada").done)
        assertTrue(a.getValue("valio_pena").done)
        assertTrue(a.getValue("categoria_propia").done)
        assertTrue(Achievements.unlockedHats(a.values.toList()).containsAll(listOf("auriculares", "flor")))
        assertNull(a.getValue("presupuesto").date)
    }
}
