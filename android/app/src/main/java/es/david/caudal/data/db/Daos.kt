package es.david.caudal.data.db

import androidx.paging.PagingSource
import androidx.room.Dao
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

/** total de un día en la lista de movimientos */
data class DayTotal(val date: String, val total: Long)

/** gastos e ingresos de lo filtrado */
data class FilterSums(val spent: Long?, val earned: Long?)

@Dao
interface FinanceDao {
    @Query("SELECT * FROM accounts") fun accounts(): Flow<List<AccountEntity>>
    @Query("SELECT * FROM categories ORDER BY position") fun categories(): Flow<List<CategoryEntity>>
    @Query("SELECT * FROM txs") fun txs(): Flow<List<TxEntity>>
    @Query("SELECT * FROM recurring") fun recurring(): Flow<List<RecurringEntity>>
    @Query("SELECT * FROM assets") fun assets(): Flow<List<AssetEntity>>
    @Query("SELECT * FROM asset_ops") fun assetOps(): Flow<List<AssetOpEntity>>
    @Query("SELECT * FROM goals") fun goals(): Flow<List<GoalEntity>>
    @Query("SELECT * FROM quotes") fun quotes(): Flow<List<QuoteEntity>>
    @Query("SELECT * FROM people") fun people(): Flow<List<PersonEntity>>
    @Query("SELECT * FROM debts") fun debts(): Flow<List<DebtEntity>>
    @Query("SELECT * FROM companies") fun companies(): Flow<List<CompanyEntity>>
    @Query("SELECT * FROM shifts") fun shifts(): Flow<List<ShiftEntity>>

    @Query("SELECT * FROM accounts") suspend fun accountsNow(): List<AccountEntity>
    @Query("SELECT * FROM categories ORDER BY position") suspend fun categoriesNow(): List<CategoryEntity>
    @Query("SELECT * FROM txs") suspend fun txsNow(): List<TxEntity>
    @Query("SELECT * FROM recurring") suspend fun recurringNow(): List<RecurringEntity>
    @Query("SELECT * FROM assets") suspend fun assetsNow(): List<AssetEntity>
    @Query("SELECT * FROM asset_ops") suspend fun assetOpsNow(): List<AssetOpEntity>
    @Query("SELECT * FROM goals") suspend fun goalsNow(): List<GoalEntity>
    @Query("SELECT * FROM quotes") suspend fun quotesNow(): List<QuoteEntity>
    @Query("SELECT * FROM people") suspend fun peopleNow(): List<PersonEntity>
    @Query("SELECT * FROM debts") suspend fun debtsNow(): List<DebtEntity>
    @Query("SELECT * FROM companies") suspend fun companiesNow(): List<CompanyEntity>
    @Query("SELECT * FROM shifts") suspend fun shiftsNow(): List<ShiftEntity>

    @Upsert suspend fun upsertAccounts(v: List<AccountEntity>)
    @Upsert suspend fun upsertCategories(v: List<CategoryEntity>)
    @Upsert suspend fun upsertTxs(v: List<TxEntity>)
    @Upsert suspend fun upsertRecurring(v: List<RecurringEntity>)
    @Upsert suspend fun upsertAssets(v: List<AssetEntity>)
    @Upsert suspend fun upsertAssetOps(v: List<AssetOpEntity>)
    @Upsert suspend fun upsertGoals(v: List<GoalEntity>)
    @Upsert suspend fun upsertQuotes(v: List<QuoteEntity>)
    @Upsert suspend fun upsertPeople(v: List<PersonEntity>)
    @Upsert suspend fun upsertDebts(v: List<DebtEntity>)
    @Upsert suspend fun upsertCompanies(v: List<CompanyEntity>)
    @Upsert suspend fun upsertShifts(v: List<ShiftEntity>)

    @Query("DELETE FROM accounts WHERE id = :id") suspend fun deleteAccount(id: String)
    @Query("DELETE FROM txs WHERE accountId = :id OR toAccountId = :id") suspend fun deleteTxsOfAccount(id: String)
    @Query("DELETE FROM txs WHERE id = :id") suspend fun deleteTx(id: String)
    @Query("DELETE FROM categories WHERE id = :id") suspend fun deleteCategory(id: String)
    @Query("UPDATE txs SET categoryId = NULL WHERE categoryId = :id") suspend fun clearCategory(id: String)
    @Query("DELETE FROM recurring WHERE id = :id") suspend fun deleteRecurring(id: String)
    @Query("DELETE FROM assets WHERE id = :id") suspend fun deleteAsset(id: String)
    @Query("DELETE FROM asset_ops WHERE id = :id") suspend fun deleteAssetOp(id: String)
    @Query("DELETE FROM goals WHERE id = :id") suspend fun deleteGoal(id: String)
    @Query("DELETE FROM people WHERE id = :id") suspend fun deletePerson(id: String)
    @Query("DELETE FROM debts WHERE personId = :id") suspend fun deleteDebtsOf(id: String)
    @Query("DELETE FROM debts WHERE id = :id") suspend fun deleteDebt(id: String)
    @Query("DELETE FROM companies WHERE id = :id") suspend fun deleteCompany(id: String)
    @Query("DELETE FROM shifts WHERE companyId = :id") suspend fun deleteShiftsOf(id: String)
    @Query("DELETE FROM shifts WHERE id = :id") suspend fun deleteShift(id: String)

    @Query("DELETE FROM accounts") suspend fun clearAccounts()
    @Query("DELETE FROM categories") suspend fun clearCategories()
    @Query("DELETE FROM txs") suspend fun clearTxs()
    @Query("DELETE FROM recurring") suspend fun clearRecurring()
    @Query("DELETE FROM assets") suspend fun clearAssets()
    @Query("DELETE FROM asset_ops") suspend fun clearAssetOps()
    @Query("DELETE FROM goals") suspend fun clearGoals()
    @Query("DELETE FROM quotes") suspend fun clearQuotes()
    @Query("DELETE FROM people") suspend fun clearPeople()
    @Query("DELETE FROM debts") suspend fun clearDebts()
    @Query("DELETE FROM companies") suspend fun clearCompanies()
    @Query("DELETE FROM shifts") suspend fun clearShifts()

    @Transaction
    suspend fun clearAll() {
        clearAssetOps(); clearAssets(); clearTxs(); clearAccounts(); clearCategories(); clearRecurring()
        clearGoals(); clearQuotes(); clearDebts(); clearPeople(); clearShifts(); clearCompanies()
    }

    // MARK: lista de movimientos (paginada) con los mismos filtros que en iPhone

    @Query(
        """
        SELECT t.* FROM txs t LEFT JOIN categories c ON c.id = t.categoryId
        WHERE (:q = '' AND substr(t.date, 1, 7) = :month OR :q != '' AND (
                t.title LIKE '%' || :q || '%' OR t.note LIKE '%' || :q || '%' OR c.name LIKE '%' || :q || '%'
                OR replace(printf('%.2f', abs(t.amount) / 100.0), '.', ',') LIKE '%' || :q || '%'))
          AND (:type IS NULL OR t.type = :type)
          AND (:account IS NULL OR t.accountId = :account OR t.toAccountId = :account)
        ORDER BY t.date DESC, t.time DESC, t.id DESC
        """,
    )
    fun pagedTxs(q: String, month: String, type: String?, account: String?): PagingSource<Int, TxEntity>

    @Query(
        """
        SELECT t.date AS date, SUM(CASE t.type
            WHEN 'expense' THEN -t.amount
            WHEN 'income' THEN t.amount
            WHEN 'adjust' THEN t.amount
            ELSE CASE WHEN :account IS NULL THEN 0 WHEN t.toAccountId = :account THEN t.amount ELSE -t.amount END END) AS total
        FROM txs t LEFT JOIN categories c ON c.id = t.categoryId
        WHERE (:q = '' AND substr(t.date, 1, 7) = :month OR :q != '' AND (
                t.title LIKE '%' || :q || '%' OR t.note LIKE '%' || :q || '%' OR c.name LIKE '%' || :q || '%'
                OR replace(printf('%.2f', abs(t.amount) / 100.0), '.', ',') LIKE '%' || :q || '%'))
          AND (:type IS NULL OR t.type = :type)
          AND (:account IS NULL OR t.accountId = :account OR t.toAccountId = :account)
        GROUP BY t.date
        """,
    )
    fun dayTotals(q: String, month: String, type: String?, account: String?): Flow<List<DayTotal>>

    @Query(
        """
        SELECT SUM(CASE WHEN t.type = 'expense' AND t.excluded = 0 THEN t.amount ELSE 0 END) AS spent,
               SUM(CASE WHEN t.type = 'income' AND t.excluded = 0 THEN t.amount ELSE 0 END) AS earned
        FROM txs t LEFT JOIN categories c ON c.id = t.categoryId
        WHERE (:q = '' AND substr(t.date, 1, 7) = :month OR :q != '' AND (
                t.title LIKE '%' || :q || '%' OR t.note LIKE '%' || :q || '%' OR c.name LIKE '%' || :q || '%'
                OR replace(printf('%.2f', abs(t.amount) / 100.0), '.', ',') LIKE '%' || :q || '%'))
          AND (:type IS NULL OR t.type = :type)
          AND (:account IS NULL OR t.accountId = :account OR t.toAccountId = :account)
        """,
    )
    fun filterSums(q: String, month: String, type: String?, account: String?): Flow<FilterSums>

    @Query("SELECT DISTINCT substr(date, 1, 7) FROM txs ORDER BY 1")
    fun months(): Flow<List<String>>

    @Query("SELECT * FROM txs WHERE accountId = :id OR toAccountId = :id ORDER BY date DESC, time DESC")
    fun pagedTxsOfAccount(id: String): PagingSource<Int, TxEntity>
}
