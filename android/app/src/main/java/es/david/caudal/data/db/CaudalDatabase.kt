package es.david.caudal.data.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        AccountEntity::class, CategoryEntity::class, TxEntity::class, RecurringEntity::class,
        AssetEntity::class, AssetOpEntity::class, GoalEntity::class, QuoteEntity::class,
        PersonEntity::class, DebtEntity::class, CompanyEntity::class, ShiftEntity::class,
    ],
    version = 1,
    exportSchema = true,
)
abstract class CaudalDatabase : RoomDatabase() {
    abstract fun finance(): FinanceDao
}
