package es.david.caudal

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import es.david.caudal.core.Day
import es.david.caudal.data.backup.BackupCodec
import es.david.caudal.data.db.CaudalDatabase
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.data.repo.TxFilter
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

/** el repositorio con Room de verdad (en memoria) */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class RepositoryTest {
    private lateinit var db: CaudalDatabase
    private lateinit var repo: FinanceRepository
    private lateinit var settings: SettingsRepository
    private val ios = javaClass.classLoader!!.getResource("ios-backup.json")!!.readText()

    @Before fun setUp() {
        Day.clock = Clock.fixed(LocalDate.parse("2026-10-20").atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant(), ZoneId.systemDefault())
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(ctx, CaudalDatabase::class.java).allowMainThreadQueries().build()
        settings = SettingsRepository(ctx)
        repo = FinanceRepository(db, settings, ctx)
    }

    @After fun tearDown() = db.close()

    @Test fun importarYExportarSinPerderNada() = runBlocking {
        repo.importBackup(ios)
        val d = repo.snapshot()
        assertEquals(4, d.accounts.size)
        assertEquals(5, d.txs.size)
        // el recurrente del día 31 está en el futuro: no apunta nada
        assertEquals(0, d.txs.count { it.recurringId != null })
        val l = Ledger(d, settings.current().monthStart)
        assertEquals(1843.0, l.netWorth, 1e-9)
        val again = BackupCodec.decode(repo.exportBackup())
        assertEquals(d.copy(txs = d.txs.sortedBy { it.sortKey }), again.data.copy(txs = again.data.txs.sortedBy { it.sortKey }))
        assertTrue(again.topExtra.contains("campoNuevoDeIphone"))
        assertEquals("Ana", settings.current().name)
    }

    @Test fun borrarYDeshacer() = runBlocking {
        repo.save(Account(id = "a", name = "Banco"))
        val t = Tx(id = "t", type = TxType.EXPENSE, amount = 1250, accountId = "a", date = "2026-10-20")
        repo.save(t)
        repo.delete(t)
        assertTrue(repo.snapshot().txs.isEmpty())
        repo.undoDelete()
        assertEquals(listOf("t"), repo.snapshot().txs.map { it.id })
        assertNull(repo.lastDeleted.value)
    }

    @Test fun borrarCuentaQuitaSusMovimientos() = runBlocking {
        repo.save(Account(id = "a", name = "A"))
        repo.save(Account(id = "b", name = "B"))
        repo.save(Tx(type = TxType.TRANSFER, amount = 100, accountId = "b", toAccountId = "a", date = "2026-10-01"))
        repo.save(Tx(type = TxType.EXPENSE, amount = 100, accountId = "b", date = "2026-10-01"))
        repo.deleteAccount(repo.snapshot().accounts.first { it.id == "a" })
        assertEquals(1, repo.snapshot().txs.size)
        // las cuentas nuevas van al final
        repo.save(Account(id = "c", name = "C"))
        assertEquals(listOf("b", "c"), repo.snapshot().accounts.sortedBy { it.order }.map { it.id })
    }

    @Test fun recurrentesYAjuste() = runBlocking {
        repo.save(Account(id = "a", name = "A", initial = 10_000))
        repo.save(Recurring(name = "Gym", amount = 2990, accountId = "a", day = 5, next = "2026-09-05"))
        val d = repo.snapshot()
        assertEquals(listOf("2026-09-05", "2026-10-05"), d.txs.map { it.date }.sorted())
        assertEquals("2026-11-05", d.recurring.single().next)
        repo.adjust(d.accounts.single(), 50.0)
        assertEquals(50.0, Ledger(repo.snapshot()).balance(repo.snapshot().accounts.single()), 1e-9)
    }

    @Test fun listaFiltradaPorMesYBusqueda() = runBlocking {
        repo.save(Account(id = "a", name = "A"))
        repo.save(Tx(type = TxType.EXPENSE, amount = 1729, accountId = "a", date = "2026-10-03", title = "Mercadona"))
        repo.save(Tx(type = TxType.INCOME, amount = 100_000, accountId = "a", date = "2026-10-01", title = "Nómina"))
        repo.save(Tx(type = TxType.EXPENSE, amount = 500, accountId = "a", date = "2026-09-03", title = "Café"))
        val oct = repo.filterSums(TxFilter(month = "2026-10")).first()
        assertEquals(1729L, oct.spent)
        assertEquals(100_000L, oct.earned)
        assertEquals(mapOf("2026-10-03" to -1729L, "2026-10-01" to 100_000L), repo.dayTotals(TxFilter(month = "2026-10")).first().associate { it.date to it.total })
        // buscando no importa el mes; también por importe («17,29»)
        assertEquals(1729L, repo.filterSums(TxFilter(query = "17,29", month = "2026-01")).first().spent)
        assertEquals(500L, repo.filterSums(TxFilter(query = "caf", month = "2026-01")).first().spent)
        assertEquals(listOf("2026-09", "2026-10"), repo.months.first())
    }

    @Test fun operacionesQuitadasSeBorran() = runBlocking {
        repo.save(Account(id = "a", name = "A"))
        val op1 = AssetOp(side = es.david.caudal.domain.model.OpSide.BUY, qty = 1.0, price = 10.0, date = "2026-10-01")
        val op2 = op1.copy(id = "op2", qty = 2.0)
        val asset = es.david.caudal.domain.model.Asset(symbol = "X", ySymbol = "X", name = "X", ops = listOf(op1, op2))
        repo.save(asset)
        repo.save(asset.copy(ops = listOf(op2)))
        assertEquals(listOf("op2"), repo.snapshot().assets.single().ops.map { it.id })
    }

    @Test fun empezarDeCeroDejaLasCategorias() = runBlocking {
        repo.importBackup(ios)
        repo.eraseAll { null }
        val d = repo.snapshot()
        assertTrue(d.accounts.isEmpty() && d.txs.isEmpty())
        assertEquals(20, d.categories.count { it.kind == CatKind.EXPENSE })
    }
}
