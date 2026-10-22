package es.david.caudal

import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.data.backup.BackupCodec
import es.david.caudal.domain.calc.DateRange
import es.david.caudal.domain.calc.Hours
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.calc.Recurrences
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Company
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Freq
import es.david.caudal.domain.model.OpSide
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Shift
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

/** Los cálculos tienen que dar lo mismo que en iPhone (valores calculados a mano con las fórmulas de Store.swift). */
class LedgerTest {
    private lateinit var data: FinanceData
    private lateinit var ledger: Ledger

    @Before fun setUp() {
        Day.clock = Clock.fixed(LocalDate.parse("2026-10-20").atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant(), ZoneId.systemDefault())
        val text = javaClass.classLoader!!.getResource("ios-backup.json")!!.readText()
        val b = BackupCodec.decode(text)
        data = b.data
        ledger = Ledger(data, b.settings.monthStart)
    }

    private fun acc(id: String) = data.accounts.first { it.id == id }

    @Test fun saldos() {
        // 100,50 − 17,29 + 1200 + 100 (traspaso) − 3,21 (ajuste) − 50 (excluido de estadísticas, pero cuenta en el saldo)
        assertEquals(1330.0, ledger.balance(acc("a_main")), 1e-9)
        // 500 − 100 (traspaso) − (1 × 105 + 1 de comisión)
        assertEquals(294.0, ledger.balance(acc("a_save")), 1e-9)
        // saldo hasta una fecha
        assertEquals(100.5 - 17.29 + 1200, ledger.balance(acc("a_main"), upTo = "2026-10-03"), 1e-9)
    }

    @Test fun inversionesConCosteMedio() {
        val p = ledger.position(data.assets.first())
        assertEquals(2.0, p.qty, 1e-9)
        assertEquals(204.0, p.cost, 1e-9) // 306 − 1 × 102 (coste medio)
        assertEquals(18.0, p.realized, 1e-9) // 1 × (120 − 102)
        assertEquals(219.0, ledger.assetValue(data.assets.first()), 1e-9) // 2 × 109,5 (cotización guardada)
        assertEquals(3.0, ledger.investToday, 1e-9)
        assertEquals((109.5 / 108 - 1) * 100, ledger.dayChange(data.assets.first())!!, 1e-9)
    }

    @Test fun patrimonioSinCuentasArchivadas() {
        assertEquals(1330.0 + 294.0 + 219.0, ledger.netWorth, 1e-9)
        assertEquals(1330.0 + 294.0, ledger.cashTotal, 1e-9)
        assertEquals(3, ledger.accounts.size)
        assertEquals(31, ledger.netWorthSeries(30).size)
    }

    @Test fun mesQueEmpiezaElDia25() {
        assertEquals("2026-09-25", ledger.periodStart("2026-10-20"))
        assertEquals("2026-10-25", ledger.periodStart("2026-10-25"))
        val r = ledger.periodRange("2026-09-25")
        assertEquals(DateRange("2026-09-25", "2026-10-24"), r)
        assertEquals(17.29, ledger.spent(r), 1e-9) // el de 50 € está excluido
        assertEquals(1200.0, ledger.earned(r), 1e-9)
        assertEquals("c_super", ledger.byCategory(r).first().cat.id)
        assertEquals("2026-02-01", Ledger.periodStart("2026-02-10", 1))
        assertEquals("2026-01-28", Ledger.periodStart("2026-02-10", 31)) // como mucho el 28
    }

    @Test fun recurrentesMensualesAjustanElDia() {
        val r = Recurring(name = "x", amount = 100, accountId = "a", freq = Freq.MONTHLY, day = 31, next = "2026-11-30")
        assertEquals("2026-12-31", Ledger.nextDate(r, "2026-11-30"))
        assertEquals("2027-02-28", Ledger.nextDate(r, "2027-01-31"))
        assertEquals("2026-12-07", Ledger.nextDate(r.copy(freq = Freq.WEEKLY), "2026-11-30"))
        assertEquals("2027-11-30", Ledger.nextDate(r.copy(freq = Freq.YEARLY), "2026-11-30"))
    }

    @Test fun recurrentesApuntanLoPendiente() {
        val d = FinanceData(recurring = listOf(Recurring(id = "r", name = "Gym", amount = 2990, accountId = "a", day = 5, next = "2026-08-05")))
        val run = Recurrences.run(d, "2026-10-20")
        assertEquals(listOf("2026-08-05", "2026-09-05", "2026-10-05"), run.txs.map { it.date })
        assertEquals("08:00", run.txs.first().time)
        assertEquals("2026-11-05", run.updated.single().next)
    }

    @Test fun categoriaAutomatica() {
        assertEquals("c_super", ledger.guessCategory("Compra en MERCADONA Coslada", CatKind.EXPENSE)?.id)
        assertEquals("c_super", ledger.guessCategory("Alimentación Pepe", CatKind.EXPENSE)?.id) // sin tildes
        assertNull(ledger.guessCategory("ab", CatKind.EXPENSE))
        assertEquals("i_nomina", ledger.guessCategory("NÓMINA octubre", CatKind.INCOME)?.id)
    }

    @Test fun comparacionConElMesPasado() {
        val txs = listOf(
            Tx(type = TxType.EXPENSE, amount = 20000, accountId = "a", date = "2026-09-03"),
            Tx(type = TxType.EXPENSE, amount = 5000, accountId = "a", date = "2026-09-25"),
            Tx(type = TxType.EXPENSE, amount = 10000, accountId = "a", date = "2026-10-02"),
        )
        val l = Ledger(FinanceData(txs = txs), 1)
        // del 1 al 20 de septiembre: 200 €; este mes: 100 € → un 50 % menos
        assertEquals(-50.0, l.monthComparison("2026-10-20")!!, 1e-9)
        // si el mes pasado no llegó a 100 € no se compara
        assertNull(Ledger(FinanceData(txs = txs.take(0) + Tx(type = TxType.EXPENSE, amount = 500, accountId = "a", date = "2026-09-02")), 1).monthComparison("2026-10-20"))
    }

    @Test fun horasNocturnasYDescanso() {
        val c = Company(name = "ETT")
        val s = Shift(companyId = c.id, date = "2026-10-16", start = 16 * 60, end = 23 * 60, breakMin = 30)
        val r = Hours.calc(s, c)
        assertEquals(330, r.normalMin) // el descanso sale de las normales
        assertEquals(60, r.nightMin) // de 22:00 a 23:00
        assertEquals(90.82, r.gross, 1e-9) // 5,5 × 13,59 + 1 × 16,07 = 90,815 → 90,82
        assertEquals(83.10, Hours.net(r.gross, c), 1e-9)
        // turno que pasa de medianoche: de 20:00 a 04:00
        val n = Hours.calc(s.copy(start = 20 * 60, end = 4 * 60, breakMin = 0), c)
        assertEquals(120, n.normalMin)
        assertEquals(360, n.nightMin)
        // precio propio del turno
        assertEquals(Money.round2(5.5 * 20 + 16.07), Hours.calc(s.copy(normalRate = 20.0), c).gross, 1e-9)
    }

    @Test fun ajusteDeSaldo() {
        assertEquals(-10.5, Ledger.adjustment(100.0, 89.5)!!, 1e-9)
        assertNull(Ledger.adjustment(100.0, 100.004))
    }

    @Test fun ventaSinParticipaciones() {
        val p = Ledger.position(listOf(AssetOp(side = OpSide.SELL, qty = 1.0, price = 10.0, date = "2026-01-01")))
        assertEquals(0.0, p.qty, 1e-9)
        assertEquals(0.0, p.realized, 1e-9)
    }
}
