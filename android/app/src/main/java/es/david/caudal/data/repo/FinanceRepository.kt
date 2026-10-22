package es.david.caudal.data.repo

import android.content.Context
import androidx.paging.Pager
import androidx.paging.PagingConfig
import androidx.paging.PagingData
import androidx.paging.map
import androidx.room.withTransaction
import dagger.hilt.android.qualifiers.ApplicationContext
import es.david.caudal.BuildConfig
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.data.backup.Backup
import es.david.caudal.data.backup.BackupCodec
import es.david.caudal.data.backup.CuentasClarasImport
import es.david.caudal.data.backup.DefaultCategories
import es.david.caudal.data.db.CaudalDatabase
import es.david.caudal.data.db.DayTotal
import es.david.caudal.data.db.FilterSums
import es.david.caudal.data.db.toEntity
import es.david.caudal.data.db.toModel
import es.david.caudal.domain.calc.Debts
import es.david.caudal.domain.calc.Hours
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.calc.Recurrences
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.Asset
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.Company
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Goal
import es.david.caudal.domain.model.PayStatus
import es.david.caudal.domain.model.Person
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Shift
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import es.david.caudal.domain.model.newId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.withContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/** filtros de la lista de movimientos */
data class TxFilter(val query: String = "", val month: String = Day.monthKey(Day.today), val type: TxType? = null, val accountId: String? = null)

/**
 * Todos los datos de Caudal: los lee de Room y los cambia. Es el equivalente al Store de iPhone.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@Singleton
class FinanceRepository @Inject constructor(
    private val db: CaudalDatabase,
    private val settingsRepo: SettingsRepository,
    @ApplicationContext private val context: Context,
) {
    private val dao = db.finance()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    /** avisa cada vez que cambian los datos (para refrescar los widgets) */
    private val _changes = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val changes: SharedFlow<Unit> = _changes

    /** último movimiento borrado, para «Deshacer» */
    private val _lastDeleted = MutableStateFlow<Tx?>(null)
    val lastDeleted: StateFlow<Tx?> = _lastDeleted.asStateFlow()

    private val assetsFlow = combine(dao.assets(), dao.assetOps()) { assets, ops ->
        val byAsset = ops.groupBy { it.assetId }
        assets.map { a -> a.toModel(byAsset[a.id].orEmpty().map { it.toModel() }) }
    }

    /** todo lo guardado, actualizado al momento */
    val data: StateFlow<FinanceData?> = combine(
        listOf(
            dao.accounts(), dao.categories(), dao.txs(), dao.recurring(), assetsFlow, dao.goals(),
            dao.quotes(), dao.people(), dao.debts(), dao.companies(), dao.shifts(),
        ),
    ) { v ->
        @Suppress("UNCHECKED_CAST")
        FinanceData(
            accounts = (v[0] as List<es.david.caudal.data.db.AccountEntity>).map { it.toModel() },
            categories = (v[1] as List<es.david.caudal.data.db.CategoryEntity>).map { it.toModel() },
            txs = (v[2] as List<es.david.caudal.data.db.TxEntity>).map { it.toModel() },
            recurring = (v[3] as List<es.david.caudal.data.db.RecurringEntity>).map { it.toModel() },
            assets = v[4] as List<Asset>,
            goals = (v[5] as List<es.david.caudal.data.db.GoalEntity>).map { it.toModel() },
            quotes = (v[6] as List<es.david.caudal.data.db.QuoteEntity>).associate { it.symbol to it.toModel() },
            people = (v[7] as List<es.david.caudal.data.db.PersonEntity>).map { it.toModel() },
            debts = (v[8] as List<es.david.caudal.data.db.DebtEntity>).map { it.toModel() },
            companies = (v[9] as List<es.david.caudal.data.db.CompanyEntity>).map { it.toModel() },
            shifts = (v[10] as List<es.david.caudal.data.db.ShiftEntity>).map { it.toModel() },
        )
    }.flowOn(Dispatchers.Default).stateIn(scope, SharingStarted.Eagerly, null)

    /** los datos con los cálculos ya preparados (y el día de inicio de mes de los ajustes) */
    val ledger: Flow<Ledger> = combine(data, settingsRepo.settings) { d, s -> d?.let { Ledger(it, s.monthStart) } }
        .map { it ?: Ledger(FinanceData()) }
        .flowOn(Dispatchers.Default)

    suspend fun snapshot(): FinanceData = withContext(Dispatchers.IO) {
        val ops = dao.assetOpsNow().groupBy { it.assetId }
        FinanceData(
            accounts = dao.accountsNow().map { it.toModel() },
            categories = dao.categoriesNow().map { it.toModel() },
            txs = dao.txsNow().map { it.toModel() },
            recurring = dao.recurringNow().map { it.toModel() },
            assets = dao.assetsNow().map { a -> a.toModel(ops[a.id].orEmpty().map { it.toModel() }) },
            goals = dao.goalsNow().map { it.toModel() },
            quotes = dao.quotesNow().associate { it.symbol to it.toModel() },
            people = dao.peopleNow().map { it.toModel() },
            debts = dao.debtsNow().map { it.toModel() },
            companies = dao.companiesNow().map { it.toModel() },
            shifts = dao.shiftsNow().map { it.toModel() },
        )
    }

    private suspend fun write(block: suspend () -> Unit) {
        withContext(Dispatchers.IO) { db.withTransaction { block() } }
        _changes.tryEmit(Unit)
    }

    // MARK: lista de movimientos

    fun pagedTxs(f: TxFilter): Flow<PagingData<Tx>> =
        Pager(PagingConfig(pageSize = 60, enablePlaceholders = false)) {
            dao.pagedTxs(f.query.trim(), f.month, f.type?.raw, f.accountId)
        }.flow.map { p -> p.map { it.toModel() } }

    fun pagedTxsOfAccount(id: String): Flow<PagingData<Tx>> =
        Pager(PagingConfig(pageSize = 60, enablePlaceholders = false)) { dao.pagedTxsOfAccount(id) }.flow.map { p -> p.map { it.toModel() } }

    fun dayTotals(f: TxFilter): Flow<List<DayTotal>> = dao.dayTotals(f.query.trim(), f.month, f.type?.raw, f.accountId)
    fun filterSums(f: TxFilter): Flow<FilterSums> = dao.filterSums(f.query.trim(), f.month, f.type?.raw, f.accountId)
    val months: Flow<List<String>> = dao.months().map { (it + Day.monthKey(Day.today)).distinct().sorted() }

    // MARK: movimientos

    suspend fun save(t: Tx) = write { dao.upsertTxs(listOf(t.toEntity())) }

    suspend fun delete(t: Tx) {
        write { dao.deleteTx(t.id) }
        _lastDeleted.value = t
    }

    suspend fun undoDelete() {
        val t = _lastDeleted.value ?: return
        save(t)
        _lastDeleted.value = null
    }

    fun clearUndo() { _lastDeleted.value = null }

    suspend fun duplicate(t: Tx) = save(t.copy(id = newId(), date = Day.today, time = Day.nowTime()))

    // MARK: cuentas

    suspend fun save(a: Account) = write {
        val existing = dao.accountsNow()
        val n = if (existing.any { it.id == a.id }) a else a.copy(order = (existing.maxOfOrNull { it.sortOrder } ?: -1) + 1)
        dao.upsertAccounts(listOf(n.toEntity()))
    }

    /** borra la cuenta y sus movimientos (siempre después de confirmar) */
    suspend fun deleteAccount(a: Account) = write { dao.deleteTxsOfAccount(a.id); dao.deleteAccount(a.id) }

    /** nuevo orden de las cuentas activas */
    suspend fun reorderAccounts(ids: List<String>) = write {
        val all = dao.accountsNow().associateBy { it.id }
        dao.upsertAccounts(ids.mapIndexedNotNull { i, id -> all[id]?.copy(sortOrder = i) })
    }

    /** apunta un ajuste para que el saldo de la cuenta sea el indicado */
    suspend fun adjust(a: Account, target: Double) {
        val d = snapshot()
        val diff = Ledger.adjustment(Ledger(d).balance(a), target) ?: return
        save(Tx(type = TxType.ADJUST, amount = Money.toCents(diff), currency = a.currency, accountId = a.id, date = Day.today, time = Day.nowTime(), title = ADJUST_TITLE))
    }

    // MARK: categorías

    suspend fun save(c: Category) = write {
        val existing = dao.categoriesNow()
        val n = if (existing.any { it.id == c.id }) c else c.copy(position = (existing.maxOfOrNull { it.position } ?: -1) + 1)
        dao.upsertCategories(listOf(n.toEntity()))
    }

    /** cambia el orden de las categorías de un tipo (las demás no se mueven) */
    suspend fun reorderCategories(kind: CatKind, ids: List<String>) = write {
        val all = dao.categoriesNow()
        val slots = all.filter { it.kind == kind.raw }.map { it.position }.sorted()
        val byId = all.associateBy { it.id }
        dao.upsertCategories(ids.mapIndexedNotNull { i, id -> byId[id]?.copy(position = slots.getOrElse(i) { slots.lastOrNull()?.plus(i) ?: i }) })
    }

    suspend fun deleteCategory(c: Category) = write { dao.clearCategory(c.id); dao.deleteCategory(c.id) }

    // MARK: recurrentes

    suspend fun save(r: Recurring) {
        write { dao.upsertRecurring(listOf(r.toEntity())) }
        runRecurring()
    }

    suspend fun deleteRecurring(r: Recurring) = write { dao.deleteRecurring(r.id) }

    /** apunta los cargos pendientes hasta hoy */
    suspend fun runRecurring(today: String = Day.today) {
        val run = Recurrences.run(snapshot(), today)
        if (run.isEmpty) return
        write {
            dao.upsertTxs(run.txs.map { it.toEntity() })
            dao.upsertAssetOps(run.ops.map { (assetId, op) -> op.toEntity(assetId) })
            dao.upsertRecurring(run.updated.map { it.toEntity() })
        }
    }

    // MARK: objetivos

    suspend fun save(g: Goal) = write { dao.upsertGoals(listOf(g.toEntity())) }
    suspend fun deleteGoal(g: Goal) = write { dao.deleteGoal(g.id) }

    // MARK: inversiones

    /** guarda el activo con sus operaciones (las que ya no están se borran) */
    suspend fun save(a: Asset) = write {
        dao.upsertAssets(listOf(a.toEntity()))
        val keep = a.ops.map { it.id }.toSet()
        dao.assetOpsNow().filter { it.assetId == a.id && it.id !in keep }.forEach { dao.deleteAssetOp(it.id) }
        dao.upsertAssetOps(a.ops.map { it.toEntity(a.id) })
    }

    suspend fun deleteAsset(a: Asset) = write { dao.deleteAsset(a.id) }
    suspend fun saveOp(assetId: String, op: AssetOp) = write { dao.upsertAssetOps(listOf(op.toEntity(assetId))) }
    suspend fun deleteOp(op: AssetOp) = write { dao.deleteAssetOp(op.id) }
    suspend fun setManualPrice(a: Asset, price: Double) = write { dao.upsertAssets(listOf(a.copy(manualPrice = price).toEntity())) }

    // MARK: cuentas claras

    private val photosDir get() = File(context.filesDir, "photos").apply { mkdirs() }
    fun photoFile(name: String): File = File(photosDir, name)

    suspend fun save(p: Person, photo: ByteArray? = null, removePhoto: Boolean = false) {
        var person = p
        withContext(Dispatchers.IO) {
            if (photo != null) {
                val name = "person_${p.id}.jpg"
                photoFile(name).writeBytes(photo)
                person = p.copy(photo = name)
            } else if (removePhoto) {
                p.photo?.let { photoFile(it).delete() }
                person = p.copy(photo = null)
            }
        }
        write { dao.upsertPeople(listOf(person.toEntity())) }
    }

    suspend fun deletePerson(p: Person) {
        write { dao.deleteDebtsOf(p.id); dao.deletePerson(p.id) }
        withContext(Dispatchers.IO) { p.photo?.let { photoFile(it).delete() } }
    }

    suspend fun add(moves: List<DebtMove>) = write { dao.upsertDebts(moves.map { it.toEntity() }) }
    suspend fun deleteDebt(m: DebtMove) = write { dao.deleteDebt(m.id) }

    suspend fun settle(pid: String, amount: Long? = null) {
        val m = Debts.settle(snapshot().debts, pid, amount) ?: return
        add(listOf(m))
    }

    /** importa la copia de la app web Cuentas Claras; devuelve (personas, movimientos) añadidos */
    suspend fun importCuentasClaras(text: String): Pair<Int, Int> {
        val d = snapshot()
        val r = CuentasClarasImport.parse(text, d.people.map { it.id }.toSet(), d.debts.map { it.id }.toSet())
        withContext(Dispatchers.IO) { r.photos.forEach { (name, bytes) -> photoFile(name).writeBytes(bytes) } }
        write {
            dao.upsertPeople(r.people.map { it.toEntity() })
            dao.upsertDebts(r.debts.map { it.toEntity() })
        }
        return r.people.size to r.debts.size
    }

    // MARK: horas trabajadas

    suspend fun save(c: Company) = write { dao.upsertCompanies(listOf(c.toEntity())) }
    suspend fun deleteCompany(c: Company) = write { dao.deleteShiftsOf(c.id); dao.deleteCompany(c.id) }
    suspend fun save(s: Shift) = write { dao.upsertShifts(listOf(s.toEntity())) }
    suspend fun saveShifts(list: List<Shift>) = write { dao.upsertShifts(list.map { it.toEntity() }) }
    suspend fun deleteShift(s: Shift) = write { dao.deleteShift(s.id) }

    suspend fun setPaid(ids: Collection<String>, paid: Boolean) = write {
        val all = dao.shiftsNow().filter { it.id in ids }
        dao.upsertShifts(all.map { it.copy(status = if (paid) PayStatus.PAGADO.raw else PayStatus.PENDIENTE.raw, paidDate = if (paid) Day.today else "") })
    }

    /** marca como pagado lo pendiente del mes y, si se quiere, lo apunta como ingreso */
    suspend fun payMonth(company: Company, month: String, amount: Long, accountId: String?, title: String, note: String) {
        val d = snapshot()
        val pend = Hours.shifts(d.shifts, month, company.id).filter { it.status == PayStatus.PENDIENTE }
        setPaid(pend.map { it.id }, true)
        if (accountId != null && amount > 0) {
            save(Tx(type = TxType.INCOME, amount = amount, accountId = accountId, categoryId = d.categories.firstOrNull { it.id == "i_nomina" }?.id,
                date = Day.today, time = Day.nowTime(), title = title, note = note))
        }
    }

    // MARK: copia de seguridad

    suspend fun exportBackup(): String {
        val d = snapshot()
        val s = settingsRepo.current()
        return withContext(Dispatchers.IO) {
            BackupCodec.encode(
                d, s, photos = { name -> photoFile(name).takeIf { it.exists() }?.readBytes() },
                topExtra = settingsRepo.backupExtra(), settingsExtra = settingsRepo.settingsExtra(), snapshots = settingsRepo.snapshots(),
                appVersion = BuildConfig.VERSION_NAME,
            )
        }
    }

    /** sustituye todo por la copia (la pantalla pide confirmación antes) */
    suspend fun importBackup(text: String): Backup {
        val current = settingsRepo.current()
        val b = withContext(Dispatchers.Default) { BackupCodec.decode(text, current) }
        withContext(Dispatchers.IO) {
            photosDir.listFiles()?.forEach { it.delete() }
            b.photos.forEach { (name, bytes) -> photoFile(name).writeBytes(bytes) }
        }
        replaceAll(b.data)
        settingsRepo.update { b.settings }
        settingsRepo.setBackupExtras(b.topExtra, b.settingsExtra, b.snapshots)
        runRecurring()
        return b
    }

    private suspend fun replaceAll(d: FinanceData) = write {
        dao.clearAll()
        dao.upsertAccounts(d.accounts.map { it.toEntity() })
        dao.upsertCategories(d.categories.map { it.toEntity() })
        dao.upsertTxs(d.txs.map { it.toEntity() })
        dao.upsertRecurring(d.recurring.map { it.toEntity() })
        dao.upsertAssets(d.assets.map { it.toEntity() })
        dao.upsertAssetOps(d.assets.flatMap { a -> a.ops.map { it.toEntity(a.id) } })
        dao.upsertGoals(d.goals.map { it.toEntity() })
        dao.upsertQuotes(d.quotes.values.map { it.toEntity() })
        dao.upsertPeople(d.people.map { it.toEntity() })
        dao.upsertDebts(d.debts.map { it.toEntity() })
        dao.upsertCompanies(d.companies.map { it.toEntity() })
        dao.upsertShifts(d.shifts.map { it.toEntity() })
    }

    /** empezar de cero: todo fuera menos las categorías de partida (después de confirmar) */
    suspend fun eraseAll(categoryNames: (String) -> String?) {
        withContext(Dispatchers.IO) { photosDir.listFiles()?.forEach { it.delete() } }
        replaceAll(FinanceData(categories = DefaultCategories.all(categoryNames)))
        settingsRepo.setBackupExtras("", "", "")
    }

    /** bienvenida: categorías de partida y la primera cuenta */
    suspend fun setUp(categoryNames: (String) -> String?, first: Account?) = write {
        if (dao.categoriesNow().isEmpty()) dao.upsertCategories(DefaultCategories.all(categoryNames).map { it.toEntity() })
        if (first != null) dao.upsertAccounts(listOf(first.copy(order = 0).toEntity()))
    }

    suspend fun isEmpty(): Boolean = withContext(Dispatchers.IO) { dao.accountsNow().isEmpty() && dao.categoriesNow().isEmpty() }

    companion object {
        /** título de los ajustes de saldo (se guarda en los datos, como en iPhone) */
        const val ADJUST_TITLE = "Ajuste de saldo"
    }
}
